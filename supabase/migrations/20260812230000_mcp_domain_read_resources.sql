-- Recursos MCP de leitura: cada consulta é fechada por uma capability opaca
-- de uso único. O executor não ganha SELECT nas tabelas de estoque.

CREATE TABLE app_private.mcp_collection_capabilities (
  token_hash text PRIMARY KEY CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  client_id text NOT NULL REFERENCES public.mcp_clients(client_id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target text NOT NULL CHECK (target IN (
    'mmd:eventos:list',
    'mmd:catalogo:list',
    'mmd:packing:read',
    'mmd:movimentacoes:list',
    'mmd:conferencias:read',
    'mmd:retorno-esperado:read',
    'mmd:pendencias:list'
  )),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (expires_at > created_at),
  CHECK (used_at IS NULL OR used_at >= created_at)
);

CREATE INDEX mcp_collection_capabilities_expiry_idx
  ON app_private.mcp_collection_capabilities(expires_at);

REVOKE ALL ON TABLE app_private.mcp_collection_capabilities
  FROM PUBLIC, anon, authenticated, service_role, mmd_mcp_executor;

CREATE OR REPLACE FUNCTION public.issue_mcp_collection_capability(
  p_token_hash text,
  p_client_id text,
  p_actor_id uuid,
  p_target text,
  p_arguments jsonb,
  p_ttl_seconds integer DEFAULT 30
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_payload_hash text;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'MCP_COLLECTION_ISSUER_DENIED' USING ERRCODE = '42501';
  END IF;

  IF p_token_hash !~ '^[0-9a-f]{64}$'
     OR p_target NOT IN (
       'mmd:eventos:list',
       'mmd:catalogo:list',
       'mmd:packing:read',
       'mmd:movimentacoes:list',
       'mmd:conferencias:read',
       'mmd:retorno-esperado:read',
       'mmd:pendencias:list'
     )
     OR jsonb_typeof(p_arguments) <> 'object'
     OR p_ttl_seconds < 1
     OR p_ttl_seconds > 60 THEN
    RAISE EXCEPTION 'MCP_COLLECTION_INVALID' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.mcp_clients AS client
    JOIN public.profiles AS profile ON profile.id = p_actor_id
    WHERE client.client_id = p_client_id
      AND client.active
      AND client.revoked_at IS NULL
      AND client.scopes @> ARRAY['mcp:read']::text[]
      AND profile.role IN ('viewer', 'editor', 'admin')
  ) THEN
    RAISE EXCEPTION 'MCP_COLLECTION_IDENTITY_DENIED' USING ERRCODE = '42501';
  END IF;

  v_payload_hash := encode(
    extensions.digest(convert_to(p_arguments::text, 'UTF8'), 'sha256'),
    'hex'
  );

  DELETE FROM app_private.mcp_collection_capabilities
  WHERE expires_at < clock_timestamp() - interval '1 hour';

  INSERT INTO app_private.mcp_collection_capabilities (
    token_hash, client_id, actor_id, target, payload_hash, expires_at
  ) VALUES (
    p_token_hash,
    p_client_id,
    p_actor_id,
    p_target,
    v_payload_hash,
    clock_timestamp() + make_interval(secs => p_ttl_seconds)
  );
END;
$$;

CREATE OR REPLACE FUNCTION app_private.consume_mcp_collection_capability(
  p_token_hash text,
  p_target text,
  p_payload_hash text
)
RETURNS TABLE(actor_id uuid, client_id text)
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
  UPDATE app_private.mcp_collection_capabilities AS capability
  SET used_at = clock_timestamp()
  FROM public.mcp_clients AS client, public.profiles AS profile
  WHERE capability.token_hash = p_token_hash
    AND capability.target = p_target
    AND capability.payload_hash = p_payload_hash
    AND capability.used_at IS NULL
    AND capability.expires_at > clock_timestamp()
    AND client.client_id = capability.client_id
    AND client.active
    AND client.revoked_at IS NULL
    AND client.scopes @> ARRAY['mcp:read']::text[]
    AND profile.id = capability.actor_id
    AND profile.role IN ('viewer', 'editor', 'admin')
  RETURNING capability.actor_id, capability.client_id;
$$;

CREATE OR REPLACE FUNCTION app_private.require_mcp_collection_capability(
  p_capability_token text,
  p_target text,
  p_arguments jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_payload_hash text := encode(
    extensions.digest(convert_to(p_arguments::text, 'UTF8'), 'sha256'),
    'hex'
  );
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM app_private.consume_mcp_collection_capability(
      encode(extensions.digest(p_capability_token, 'sha256'), 'hex'),
      p_target,
      v_payload_hash
    )
  ) THEN
    RAISE EXCEPTION 'MCP_COLLECTION_CAPABILITY_INVALID' USING ERRCODE = '28000';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION app_private.require_mcp_page(
  p_page integer,
  p_page_size integer
)
RETURNS void
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
BEGIN
  IF p_page IS NULL OR p_page < 1 OR p_page_size IS NULL OR p_page_size NOT BETWEEN 1 AND 50 THEN
    RAISE EXCEPTION 'MCP_PAGE_INVALID' USING ERRCODE = '22023';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.mcp_read_events(
  p_capability_token text,
  p_status text,
  p_date_from date,
  p_date_to date,
  p_page integer,
  p_page_size integer
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_items jsonb;
BEGIN
  IF p_status IS NOT NULL
     AND p_status NOT IN ('PLANEJAMENTO', 'CONFIRMADO', 'MONTAGEM', 'EM_CAMPO', 'FINALIZADO', 'CANCELADO') THEN
    RAISE EXCEPTION 'MCP_EVENT_STATUS_INVALID' USING ERRCODE = '22023';
  END IF;
  IF p_date_from IS NOT NULL AND p_date_to IS NOT NULL AND p_date_from > p_date_to THEN
    RAISE EXCEPTION 'MCP_EVENT_DATE_RANGE_INVALID' USING ERRCODE = '22023';
  END IF;
  PERFORM app_private.require_mcp_page(p_page, p_page_size);
  PERFORM app_private.require_mcp_collection_capability(
    p_capability_token,
    'mmd:eventos:list',
    jsonb_build_object(
      'status', p_status,
      'date_from', p_date_from,
      'date_to', p_date_to,
      'page', p_page,
      'page_size', p_page_size
    )
  );

  SELECT coalesce(jsonb_agg(row.result ORDER BY row.data_inicio NULLS LAST, row.id), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT
      evento.id,
      evento.data_inicio,
      jsonb_build_object(
        'id', evento.id,
        'nome', evento.nome,
        'status', evento.status,
        'data_inicio', evento.data_inicio,
        'data_fim', evento.data_fim,
        'local', evento.local,
        'packing', jsonb_build_object(
          'linhas', coverage.linhas,
          'itens_total', coverage.itens_total,
          'itens_alocados', coverage.itens_alocados,
          'readiness_pct', CASE
            WHEN coverage.itens_total = 0 THEN 0
            ELSE round((coverage.itens_alocados::numeric / coverage.itens_total) * 100)::integer
          END
        )
      ) AS result
    FROM public.projetos AS evento
    CROSS JOIN LATERAL (
      SELECT
        count(*)::integer AS linhas,
        coalesce(sum(packing.quantidade), 0)::integer AS itens_total,
        coalesce(sum(
          cardinality(coalesce(packing.serial_numbers_designados, ARRAY[]::uuid[]))
          + coalesce((
            SELECT sum(greatest((rental->>'quantidade')::integer, 0))
            FROM jsonb_array_elements(packing.alugueis_avulsos) AS rental
            WHERE jsonb_typeof(rental) = 'object'
              AND coalesce(rental->>'quantidade', '') ~ '^[0-9]+$'
          ), 0)
        ), 0)::integer AS itens_alocados
      FROM public.packing_list AS packing
      WHERE packing.projeto_id = evento.id
    ) AS coverage
    WHERE (p_status IS NULL OR evento.status::text = p_status)
      AND (p_date_from IS NULL OR evento.data_inicio >= p_date_from)
      AND (p_date_to IS NULL OR evento.data_fim <= p_date_to)
    ORDER BY evento.data_inicio NULLS LAST, evento.id
    LIMIT p_page_size
    OFFSET (p_page - 1) * p_page_size
  ) AS row;

  RETURN jsonb_build_object('items', v_items, 'page', p_page, 'page_size', p_page_size);
END;
$$;

CREATE OR REPLACE FUNCTION public.mcp_read_catalog(
  p_capability_token text,
  p_categoria text,
  p_page integer,
  p_page_size integer
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_items jsonb;
BEGIN
  IF p_categoria IS NOT NULL
     AND p_categoria NOT IN ('ILUMINACAO', 'AUDIO', 'CABO', 'ENERGIA', 'ESTRUTURA', 'EFEITO', 'VIDEO', 'ACESSORIO') THEN
    RAISE EXCEPTION 'MCP_CATALOG_CATEGORY_INVALID' USING ERRCODE = '22023';
  END IF;
  PERFORM app_private.require_mcp_page(p_page, p_page_size);
  PERFORM app_private.require_mcp_collection_capability(
    p_capability_token,
    'mmd:catalogo:list',
    jsonb_build_object('categoria', p_categoria, 'page', p_page, 'page_size', p_page_size)
  );

  SELECT coalesce(jsonb_agg(row.result ORDER BY row.nome, row.id), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT
      item.id,
      item.nome,
      jsonb_build_object(
        'id', item.id,
        'nome', item.nome,
        'categoria', item.categoria,
        'quantidade_total', item.quantidade_total,
        'unidades', jsonb_build_object(
          'disponiveis', count(*) FILTER (WHERE unidade.status = 'DISPONIVEL'),
          'em_campo', count(*) FILTER (WHERE unidade.status = 'EM_CAMPO'),
          'retornando', count(*) FILTER (WHERE unidade.status = 'RETORNANDO'),
          'manutencao', count(*) FILTER (WHERE unidade.status = 'MANUTENCAO')
        )
      ) AS result
    FROM public.items AS item
    LEFT JOIN public.serial_numbers AS unidade ON unidade.item_id = item.id
    WHERE p_categoria IS NULL OR item.categoria::text = p_categoria
    GROUP BY item.id
    ORDER BY item.nome, item.id
    LIMIT p_page_size
    OFFSET (p_page - 1) * p_page_size
  ) AS row;

  RETURN jsonb_build_object('items', v_items, 'page', p_page, 'page_size', p_page_size);
END;
$$;

CREATE OR REPLACE FUNCTION public.mcp_read_packing(
  p_capability_token text,
  p_evento_id uuid,
  p_page integer,
  p_page_size integer
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_items jsonb;
BEGIN
  PERFORM app_private.require_mcp_page(p_page, p_page_size);
  PERFORM app_private.require_mcp_collection_capability(
    p_capability_token,
    'mmd:packing:read',
    jsonb_build_object('evento_id', p_evento_id, 'page', p_page, 'page_size', p_page_size)
  );

  SELECT coalesce(jsonb_agg(row.result ORDER BY row.id), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT
      packing.id,
      jsonb_build_object(
        'id', packing.id,
        'item', jsonb_build_object('id', item.id, 'nome', item.nome, 'categoria', item.categoria),
        'quantidade', packing.quantidade,
        'qtd_propria', cardinality(coalesce(packing.serial_numbers_designados, ARRAY[]::uuid[])),
        'alugueis_avulsos', coalesce((
          SELECT sum(greatest((rental->>'quantidade')::integer, 0))
          FROM jsonb_array_elements(packing.alugueis_avulsos) AS rental
          WHERE jsonb_typeof(rental) = 'object'
            AND coalesce(rental->>'quantidade', '') ~ '^[0-9]+$'
        ), 0),
        'qtd_coberta', cardinality(coalesce(packing.serial_numbers_designados, ARRAY[]::uuid[])) + coalesce((
          SELECT sum(greatest((rental->>'quantidade')::integer, 0))
          FROM jsonb_array_elements(packing.alugueis_avulsos) AS rental
          WHERE jsonb_typeof(rental) = 'object'
            AND coalesce(rental->>'quantidade', '') ~ '^[0-9]+$'
        ), 0),
        'qtd_faltante', greatest(
          packing.quantidade - cardinality(coalesce(packing.serial_numbers_designados, ARRAY[]::uuid[])) - coalesce((
            SELECT sum(greatest((rental->>'quantidade')::integer, 0))
            FROM jsonb_array_elements(packing.alugueis_avulsos) AS rental
            WHERE jsonb_typeof(rental) = 'object'
              AND coalesce(rental->>'quantidade', '') ~ '^[0-9]+$'
          ), 0),
          0
        )
      ) AS result
    FROM public.packing_list AS packing
    JOIN public.items AS item ON item.id = packing.item_id
    WHERE packing.projeto_id = p_evento_id
    ORDER BY packing.id
    LIMIT p_page_size
    OFFSET (p_page - 1) * p_page_size
  ) AS row;

  RETURN jsonb_build_object('items', v_items, 'page', p_page, 'page_size', p_page_size);
END;
$$;

CREATE OR REPLACE FUNCTION public.mcp_read_movements(
  p_capability_token text,
  p_evento_id uuid,
  p_page integer,
  p_page_size integer
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_items jsonb;
BEGIN
  PERFORM app_private.require_mcp_page(p_page, p_page_size);
  PERFORM app_private.require_mcp_collection_capability(
    p_capability_token,
    'mmd:movimentacoes:list',
    jsonb_build_object('evento_id', p_evento_id, 'page', p_page, 'page_size', p_page_size)
  );

  SELECT coalesce(jsonb_agg(row.result ORDER BY row.timestamp DESC, row.id), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT
      movement.id,
      movement.timestamp,
      jsonb_build_object(
        'id', movement.id,
        'unidade', jsonb_build_object('id', unit.id, 'codigo_interno', unit.codigo_interno),
        'tipo', movement.tipo,
        'status_anterior', movement.status_anterior,
        'status_novo', movement.status_novo,
        'metodo', movement.metodo_scan,
        'timestamp', movement.timestamp
      ) AS result
    FROM public.movimentacoes AS movement
    JOIN public.serial_numbers AS unit ON unit.id = movement.serial_number_id
    WHERE movement.projeto_id = p_evento_id
    ORDER BY movement.timestamp DESC, movement.id
    LIMIT p_page_size
    OFFSET (p_page - 1) * p_page_size
  ) AS row;

  RETURN jsonb_build_object('items', v_items, 'page', p_page, 'page_size', p_page_size);
END;
$$;

CREATE OR REPLACE FUNCTION public.mcp_read_conference(
  p_capability_token text,
  p_evento_id uuid,
  p_direcao text,
  p_page integer,
  p_page_size integer
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_conference public.conferencias%ROWTYPE;
  v_decisions jsonb;
  v_receipts jsonb;
BEGIN
  IF p_direcao NOT IN ('SAIDA', 'RETORNO') THEN
    RAISE EXCEPTION 'MCP_CONFERENCE_DIRECTION_INVALID' USING ERRCODE = '22023';
  END IF;
  PERFORM app_private.require_mcp_page(p_page, p_page_size);
  PERFORM app_private.require_mcp_collection_capability(
    p_capability_token,
    'mmd:conferencias:read',
    jsonb_build_object(
      'evento_id', p_evento_id,
      'direcao', p_direcao,
      'page', p_page,
      'page_size', p_page_size
    )
  );

  SELECT conference.* INTO v_conference
  FROM public.conferencias AS conference
  WHERE conference.projeto_id = p_evento_id
    AND conference.direcao::text = p_direcao;

  IF v_conference.id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT coalesce(jsonb_agg(row.result ORDER BY row.captured_at, row.id), '[]'::jsonb)
  INTO v_decisions
  FROM (
    SELECT
      decision.id,
      decision.captured_at,
      jsonb_build_object(
        'id', decision.id,
        'unidade', jsonb_build_object('id', unit.id, 'codigo_interno', unit.codigo_interno),
        'resultado', decision.resultado,
        'metodo', decision.metodo,
        'captured_at', decision.captured_at,
        'resolution', decision.resolution,
        'applied', decision.applied_confirmation_id IS NOT NULL
      ) AS result
    FROM public.conferencia_decisoes AS decision
    JOIN public.serial_numbers AS unit ON unit.id = decision.serial_number_id
    WHERE decision.conferencia_id = v_conference.id
    ORDER BY decision.captured_at, decision.id
    LIMIT p_page_size
    OFFSET (p_page - 1) * p_page_size
  ) AS row;

  SELECT coalesce(jsonb_agg(receipt_row.result ORDER BY receipt_row.confirmed_at, receipt_row.id), '[]'::jsonb)
  INTO v_receipts
  FROM (
    SELECT
      receipt.id,
      receipt.confirmed_at,
      jsonb_build_object(
        'id', receipt.id,
        'confirmed_at', receipt.confirmed_at,
        'incomplete_reason', receipt.incomplete_reason,
        'applied_count', count(decision.id)
      ) AS result
    FROM public.conferencia_confirmacoes AS receipt
    LEFT JOIN public.conferencia_decisoes AS decision
      ON decision.applied_confirmation_id = receipt.id
    WHERE receipt.conferencia_id = v_conference.id
    GROUP BY receipt.id, receipt.confirmed_at, receipt.incomplete_reason
  ) AS receipt_row;

  RETURN jsonb_build_object(
    'id', v_conference.id,
    'direcao', v_conference.direcao,
    'version', v_conference.version,
    'updated_at', v_conference.updated_at,
    'decisoes', v_decisions,
    'recibos', coalesce(v_receipts, '[]'::jsonb),
    'page', p_page,
    'page_size', p_page_size
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.mcp_read_expected_return(
  p_capability_token text,
  p_evento_id uuid,
  p_page integer,
  p_page_size integer
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_items jsonb;
BEGIN
  PERFORM app_private.require_mcp_page(p_page, p_page_size);
  PERFORM app_private.require_mcp_collection_capability(
    p_capability_token,
    'mmd:retorno-esperado:read',
    jsonb_build_object('evento_id', p_evento_id, 'page', p_page, 'page_size', p_page_size)
  );

  SELECT coalesce(jsonb_agg(row.result ORDER BY row.codigo_interno, row.serial_id), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT
      expected.serial_id,
      expected.codigo_interno,
      jsonb_build_object(
        'unidade', jsonb_build_object('id', expected.serial_id, 'codigo_interno', expected.codigo_interno),
        'saida_confirmation_id', expected.saida_confirmation_id,
        'saida_confirmed_at', expected.saida_confirmed_at
      ) AS result
    FROM public.conferencia_retorno_esperado(p_evento_id) AS expected
    ORDER BY expected.codigo_interno, expected.serial_id
    LIMIT p_page_size
    OFFSET (p_page - 1) * p_page_size
  ) AS row;

  RETURN jsonb_build_object('items', v_items, 'page', p_page, 'page_size', p_page_size);
END;
$$;

CREATE OR REPLACE FUNCTION public.mcp_read_return_pendings(
  p_capability_token text,
  p_evento_id uuid,
  p_page integer,
  p_page_size integer
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_items jsonb;
BEGIN
  PERFORM app_private.require_mcp_page(p_page, p_page_size);
  PERFORM app_private.require_mcp_collection_capability(
    p_capability_token,
    'mmd:pendencias:list',
    jsonb_build_object('evento_id', p_evento_id, 'page', p_page, 'page_size', p_page_size)
  );

  SELECT coalesce(jsonb_agg(row.result ORDER BY row.created_at DESC, row.id), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT
      pending.id,
      pending.created_at,
      jsonb_build_object(
        'id', pending.id,
        'unidade', jsonb_build_object(
          'id', unit.id,
          'codigo_interno', unit.codigo_interno,
          'status', unit.status
        ),
        'status', pending.status,
        'observacao', pending.observacao,
        'localizacao_confirmada', pending.localizacao_confirmada,
        'created_at', pending.created_at,
        'resolved_at', pending.resolved_at
      ) AS result
    FROM public.retorno_pendencias AS pending
    JOIN public.serial_numbers AS unit ON unit.id = pending.serial_number_id
    WHERE pending.projeto_id = p_evento_id
    ORDER BY pending.created_at DESC, pending.id
    LIMIT p_page_size
    OFFSET (p_page - 1) * p_page_size
  ) AS row;

  RETURN jsonb_build_object('items', v_items, 'page', p_page, 'page_size', p_page_size);
END;
$$;

REVOKE ALL ON FUNCTION public.issue_mcp_collection_capability(text, text, uuid, text, jsonb, integer)
  FROM PUBLIC, anon, authenticated, mmd_mcp_executor;
GRANT EXECUTE ON FUNCTION public.issue_mcp_collection_capability(text, text, uuid, text, jsonb, integer)
  TO service_role;

REVOKE ALL ON FUNCTION app_private.consume_mcp_collection_capability(text, text, text)
  FROM PUBLIC, anon, authenticated, service_role, mmd_mcp_executor;
REVOKE ALL ON FUNCTION app_private.require_mcp_collection_capability(text, text, jsonb)
  FROM PUBLIC, anon, authenticated, service_role, mmd_mcp_executor;
REVOKE ALL ON FUNCTION app_private.require_mcp_page(integer, integer)
  FROM PUBLIC, anon, authenticated, service_role, mmd_mcp_executor;

REVOKE ALL ON FUNCTION public.mcp_read_events(text, text, date, date, integer, integer)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.mcp_read_catalog(text, text, integer, integer)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.mcp_read_packing(text, uuid, integer, integer)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.mcp_read_movements(text, uuid, integer, integer)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.mcp_read_conference(text, uuid, text, integer, integer)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.mcp_read_expected_return(text, uuid, integer, integer)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.mcp_read_return_pendings(text, uuid, integer, integer)
  FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.mcp_read_events(text, text, date, date, integer, integer)
  TO mmd_mcp_executor;
GRANT EXECUTE ON FUNCTION public.mcp_read_catalog(text, text, integer, integer)
  TO mmd_mcp_executor;
GRANT EXECUTE ON FUNCTION public.mcp_read_packing(text, uuid, integer, integer)
  TO mmd_mcp_executor;
GRANT EXECUTE ON FUNCTION public.mcp_read_movements(text, uuid, integer, integer)
  TO mmd_mcp_executor;
GRANT EXECUTE ON FUNCTION public.mcp_read_conference(text, uuid, text, integer, integer)
  TO mmd_mcp_executor;
GRANT EXECUTE ON FUNCTION public.mcp_read_expected_return(text, uuid, integer, integer)
  TO mmd_mcp_executor;
GRANT EXECUTE ON FUNCTION public.mcp_read_return_pendings(text, uuid, integer, integer)
  TO mmd_mcp_executor;

REVOKE ALL ON TABLE
  public.conferencias,
  public.conferencia_decisoes,
  public.conferencia_confirmacoes,
  public.retorno_pendencias
FROM mmd_mcp_executor;
