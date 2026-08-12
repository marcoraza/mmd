CREATE TABLE public.rfid_tag_operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL CHECK (length(btrim(idempotency_key)) >= 8),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  action text NOT NULL CHECK (action IN ('VINCULAR', 'MOVER', 'SUBSTITUIR', 'DESVINCULAR')),
  epc text,
  previous_epc text,
  previous_serial_number_id uuid REFERENCES public.serial_numbers(id) ON DELETE RESTRICT,
  next_serial_number_id uuid NOT NULL REFERENCES public.serial_numbers(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT rfid_tag_operations_idempotency_unique UNIQUE (idempotency_key)
);

CREATE INDEX rfid_tag_operations_next_serial_created_idx
  ON public.rfid_tag_operations(next_serial_number_id, created_at DESC);

ALTER TABLE public.rfid_tag_operations ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.rfid_tag_operations
FROM anon, authenticated, service_role;

GRANT SELECT ON TABLE public.rfid_tag_operations
TO authenticated, service_role;

CREATE POLICY rfid_tag_operations_read ON public.rfid_tag_operations
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE TABLE public.conferencia_excecao_resolucoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.conferencia_decisoes(id) ON DELETE RESTRICT,
  idempotency_key text NOT NULL CHECK (length(btrim(idempotency_key)) >= 8),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  action public.conferencia_resolution_enum NOT NULL
    CHECK (action IN ('ADICIONAR', 'IGNORAR')),
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  resolved_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conferencia_excecao_resolucoes_decision_unique UNIQUE (decision_id),
  CONSTRAINT conferencia_excecao_resolucoes_idempotency_unique UNIQUE (idempotency_key)
);

ALTER TABLE public.conferencia_excecao_resolucoes ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.conferencia_excecao_resolucoes
FROM anon, authenticated, service_role;

GRANT SELECT ON TABLE public.conferencia_excecao_resolucoes
TO authenticated, service_role;

CREATE POLICY conferencia_excecao_resolucoes_read ON public.conferencia_excecao_resolucoes
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE UNIQUE INDEX serial_numbers_rfid_epc_normalized_unique
  ON public.serial_numbers ((regexp_replace(upper(tag_rfid), '[^A-Z0-9]', '', 'g')))
  WHERE tag_rfid IS NOT NULL;

CREATE OR REPLACE FUNCTION app_private.normalizar_epc_rfid(p_epc text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  v_epc text := regexp_replace(upper(btrim(coalesce(p_epc, ''))), '[^A-Z0-9]', '', 'g');
BEGIN
  IF length(v_epc) < 8 OR length(v_epc) > 96 OR v_epc !~ '^[A-Z0-9]+$' THEN
    RAISE EXCEPTION 'EPC RFID inválido'
      USING ERRCODE = '22023';
  END IF;

  RETURN v_epc;
END;
$$;

REVOKE ALL ON FUNCTION app_private.normalizar_epc_rfid(text)
FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.resolver_epc_rfid(p_epc text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_epc text := app_private.normalizar_epc_rfid(p_epc);
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória'
      USING ERRCODE = '28000';
  END IF;

  RETURN coalesce(
    (
      SELECT jsonb_build_object(
        'known', true,
        'epc', v_epc,
        'unit', jsonb_build_object(
          'id', sn.id,
          'codigo_interno', sn.codigo_interno,
          'nome', i.nome,
          'categoria', i.categoria,
          'status', sn.status,
          'localizacao', sn.localizacao,
          'tag_rfid', sn.tag_rfid
        )
      )
      FROM public.serial_numbers sn
      JOIN public.items i ON i.id = sn.item_id
      WHERE regexp_replace(upper(sn.tag_rfid), '[^A-Z0-9]', '', 'g') = v_epc
      LIMIT 1
    ),
    jsonb_build_object('known', false, 'epc', v_epc, 'unit', null)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.resolver_epc_rfid(text)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.resolver_epc_rfid(text)
TO authenticated;

CREATE OR REPLACE FUNCTION app_private.rfid_tag_operation_ack(p_operation_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'operation_id', op.id,
    'action', op.action,
    'epc', op.epc,
    'previous_epc', op.previous_epc,
    'previous_serial_number_id', op.previous_serial_number_id,
    'next_serial_number_id', op.next_serial_number_id,
    'next_unit_code', sn.codigo_interno,
    'actor_id', op.actor_id,
    'created_at', op.created_at
  )
  FROM public.rfid_tag_operations op
  JOIN public.serial_numbers sn ON sn.id = op.next_serial_number_id
  WHERE op.id = p_operation_id;
$$;

REVOKE ALL ON FUNCTION app_private.rfid_tag_operation_ack(uuid)
FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.aplicar_vinculo_rfid(
  p_serial_id uuid,
  p_epc text,
  p_idempotency_key text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_epc text := CASE WHEN nullif(btrim(coalesce(p_epc, '')), '') IS NULL THEN NULL
    ELSE app_private.normalizar_epc_rfid(p_epc)
  END;
  v_key text := btrim(coalesce(p_idempotency_key, ''));
  v_payload_hash text;
  v_existing public.rfid_tag_operations%ROWTYPE;
  v_target public.serial_numbers%ROWTYPE;
  v_source public.serial_numbers%ROWTYPE;
  v_previous_epc text;
  v_action text;
  v_operation public.rfid_tag_operations%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória'
      USING ERRCODE = '28000';
  END IF;

  IF app_private.current_user_role() NOT IN ('editor', 'admin') THEN
    RAISE EXCEPTION 'Perfil sem permissão para Etiquetar'
      USING ERRCODE = '42501';
  END IF;

  IF p_serial_id IS NULL OR length(v_key) < 8 THEN
    RAISE EXCEPTION 'Unidade e chave idempotente são obrigatórias'
      USING ERRCODE = '22023';
  END IF;

  v_payload_hash := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object('serial_id', p_serial_id, 'epc', v_epc)::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  PERFORM pg_advisory_xact_lock(hashtextextended('rfid-idempotency:' || v_key, 0));

  SELECT op.*
  INTO v_existing
  FROM public.rfid_tag_operations op
  WHERE op.idempotency_key = v_key;

  IF FOUND THEN
    IF v_existing.payload_hash <> v_payload_hash OR v_existing.actor_id <> v_actor_id THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN app_private.rfid_tag_operation_ack(v_existing.id);
  END IF;

  SELECT sn.*
  INTO v_target
  FROM public.serial_numbers sn
  WHERE sn.id = p_serial_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unidade % não encontrada', p_serial_id
      USING ERRCODE = 'P0002';
  END IF;

  v_previous_epc := nullif(btrim(coalesce(v_target.tag_rfid, '')), '');

  IF v_epc IS NULL THEN
    v_action := 'DESVINCULAR';
  ELSE
    PERFORM pg_advisory_xact_lock(hashtextextended('rfid-epc:' || v_epc, 0));

    IF EXISTS (
      SELECT 1
      FROM public.lotes l
      WHERE regexp_replace(upper(l.tag_rfid), '[^A-Z0-9]', '', 'g') = v_epc
    ) THEN
      RAISE EXCEPTION 'EPC ainda está vinculado a Lote legado'
        USING ERRCODE = '55000';
    END IF;

    SELECT sn.*
    INTO v_source
    FROM public.serial_numbers sn
    WHERE regexp_replace(upper(sn.tag_rfid), '[^A-Z0-9]', '', 'g') = v_epc
    FOR UPDATE;

    IF FOUND AND v_source.id <> v_target.id THEN
      v_action := 'MOVER';
    ELSIF v_previous_epc IS NOT NULL
      AND regexp_replace(upper(v_previous_epc), '[^A-Z0-9]', '', 'g') <> v_epc THEN
      v_action := 'SUBSTITUIR';
    ELSE
      v_action := 'VINCULAR';
    END IF;
  END IF;

  PERFORM set_config('app_private.rfid_tag_operation', 'true', true);

  IF v_action = 'MOVER' THEN
    UPDATE public.serial_numbers
    SET tag_rfid = NULL
    WHERE id = v_source.id;
  END IF;

  IF v_epc IS DISTINCT FROM v_previous_epc THEN
    UPDATE public.serial_numbers
    SET tag_rfid = v_epc
    WHERE id = v_target.id;
  END IF;

  PERFORM set_config('app_private.rfid_tag_operation', 'false', true);

  INSERT INTO public.rfid_tag_operations (
    idempotency_key,
    payload_hash,
    actor_id,
    action,
    epc,
    previous_epc,
    previous_serial_number_id,
    next_serial_number_id
  ) VALUES (
    v_key,
    v_payload_hash,
    v_actor_id,
    v_action,
    v_epc,
    v_previous_epc,
    CASE WHEN v_action = 'MOVER' THEN v_source.id ELSE NULL END,
    v_target.id
  )
  RETURNING * INTO v_operation;

  RETURN app_private.rfid_tag_operation_ack(v_operation.id);
END;
$$;

REVOKE ALL ON FUNCTION public.aplicar_vinculo_rfid(uuid, text, text)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.aplicar_vinculo_rfid(uuid, text, text)
TO authenticated;

CREATE OR REPLACE FUNCTION app_private.conferencia_excecao_ack(p_resolution_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'resolution_id', er.id,
    'decision_id', er.decision_id,
    'action', er.action,
    'actor_id', er.actor_id,
    'resolved_at', er.resolved_at
  )
  FROM public.conferencia_excecao_resolucoes er
  WHERE er.id = p_resolution_id;
$$;

REVOKE ALL ON FUNCTION app_private.conferencia_excecao_ack(uuid)
FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.resolver_excecao_conferencia_saida(
  p_decision_id uuid,
  p_action public.conferencia_resolution_enum,
  p_expected_version bigint,
  p_idempotency_key text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_key text := btrim(coalesce(p_idempotency_key, ''));
  v_payload_hash text;
  v_existing public.conferencia_excecao_resolucoes%ROWTYPE;
  v_decision public.conferencia_decisoes%ROWTYPE;
  v_conferencia public.conferencias%ROWTYPE;
  v_resolution public.conferencia_excecao_resolucoes%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória'
      USING ERRCODE = '28000';
  END IF;

  IF app_private.current_user_role() NOT IN ('editor', 'admin') THEN
    RAISE EXCEPTION 'Perfil sem permissão para resolver Revisar'
      USING ERRCODE = '42501';
  END IF;

  IF p_action NOT IN ('ADICIONAR', 'IGNORAR') OR p_expected_version IS NULL OR length(v_key) < 8 THEN
    RAISE EXCEPTION 'Resolução de Revisar inválida'
      USING ERRCODE = '22023';
  END IF;

  v_payload_hash := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object(
          'decision_id', p_decision_id,
          'action', p_action,
          'expected_version', p_expected_version
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  PERFORM pg_advisory_xact_lock(hashtextextended('conference-exception-idempotency:' || v_key, 0));

  SELECT er.*
  INTO v_existing
  FROM public.conferencia_excecao_resolucoes er
  WHERE er.idempotency_key = v_key;

  IF FOUND THEN
    IF v_existing.payload_hash <> v_payload_hash OR v_existing.actor_id <> v_actor_id THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN app_private.conferencia_excecao_ack(v_existing.id);
  END IF;

  SELECT cd.*
  INTO v_decision
  FROM public.conferencia_decisoes cd
  WHERE cd.id = p_decision_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Decisão % não encontrada', p_decision_id
      USING ERRCODE = 'P0002';
  END IF;

  SELECT c.*
  INTO v_conferencia
  FROM public.conferencias c
  WHERE c.id = v_decision.conferencia_id
  FOR UPDATE;

  IF v_conferencia.direcao <> 'SAIDA' OR v_decision.applied_confirmation_id IS NOT NULL THEN
    RAISE EXCEPTION 'Decisão não aceita resolução de saída'
      USING ERRCODE = '55000';
  END IF;

  IF v_conferencia.version <> p_expected_version THEN
    RAISE EXCEPTION 'CONFERENCE_VERSION_CONFLICT'
      USING ERRCODE = '40001';
  END IF;

  IF v_decision.resolution <> 'REVISAR' THEN
    RAISE EXCEPTION 'DECISION_ALREADY_RESOLVED'
      USING ERRCODE = '55000';
  END IF;

  INSERT INTO public.conferencia_excecao_resolucoes (
    decision_id,
    idempotency_key,
    payload_hash,
    action,
    actor_id
  ) VALUES (
    v_decision.id,
    v_key,
    v_payload_hash,
    p_action,
    v_actor_id
  )
  RETURNING * INTO v_resolution;

  UPDATE public.conferencia_decisoes
  SET resolution = p_action,
      updated_at = now()
  WHERE id = v_decision.id;

  UPDATE public.conferencias
  SET version = version + 1,
      updated_at = now()
  WHERE id = v_conferencia.id;

  RETURN app_private.conferencia_excecao_ack(v_resolution.id);
END;
$$;

REVOKE ALL ON FUNCTION public.resolver_excecao_conferencia_saida(
  uuid,
  public.conferencia_resolution_enum,
  bigint,
  text
) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.resolver_excecao_conferencia_saida(
  uuid,
  public.conferencia_resolution_enum,
  bigint,
  text
) TO authenticated;

CREATE OR REPLACE FUNCTION public.confirmar_conferencia_saida(
  p_conferencia_id uuid,
  p_decision_ids uuid[],
  p_expected_version bigint,
  p_idempotency_key text,
  p_incomplete_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_conferencia public.conferencias%ROWTYPE;
  v_projeto_status public.status_projeto_enum;
  v_existing public.conferencia_confirmacoes%ROWTYPE;
  v_confirmation public.conferencia_confirmacoes%ROWTYPE;
  v_decision_ids uuid[];
  v_serial_ids uuid[];
  v_payload_hash text;
  v_decision_count integer;
  v_bad_status_count integer;
  v_unresolved_count integer;
  v_is_incomplete boolean;
  v_substitution record;
  v_incomplete_reason text := nullif(btrim(coalesce(p_incomplete_reason, '')), '');
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória' USING ERRCODE = '28000';
  END IF;
  IF app_private.current_user_role() NOT IN ('editor', 'admin') THEN
    RAISE EXCEPTION 'Perfil sem permissão para confirmar Conferência' USING ERRCODE = '42501';
  END IF;
  IF length(btrim(coalesce(p_idempotency_key, ''))) < 8 THEN
    RAISE EXCEPTION 'Chave idempotente inválida' USING ERRCODE = '22023';
  END IF;
  IF coalesce(cardinality(p_decision_ids), 0) = 0 THEN
    RAISE EXCEPTION 'Confirmação exige ao menos uma decisão' USING ERRCODE = '22023';
  END IF;

  SELECT array_agg(decision_id ORDER BY decision_id)
  INTO v_decision_ids
  FROM unnest(p_decision_ids) AS decision_id;
  IF cardinality(v_decision_ids) <> (
    SELECT count(DISTINCT decision_id) FROM unnest(v_decision_ids) AS decision_id
  ) THEN
    RAISE EXCEPTION 'Decisão duplicada no payload' USING ERRCODE = '22023';
  END IF;

  SELECT c.* INTO v_conferencia FROM public.conferencias c WHERE c.id = p_conferencia_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conferência % não encontrada', p_conferencia_id USING ERRCODE = 'P0002';
  END IF;
  IF v_conferencia.direcao <> 'SAIDA' THEN
    RAISE EXCEPTION 'RPC de saída exige Conferência SAIDA' USING ERRCODE = '22023';
  END IF;

  SELECT p.status INTO v_projeto_status FROM public.projetos p
  WHERE p.id = v_conferencia.projeto_id FOR UPDATE;
  SELECT c.* INTO v_conferencia FROM public.conferencias c
  WHERE c.id = p_conferencia_id FOR UPDATE;

  v_payload_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'conference_id', p_conferencia_id,
    'decision_ids', to_jsonb(v_decision_ids),
    'expected_version', p_expected_version,
    'incomplete_reason', v_incomplete_reason
  )::text, 'UTF8'), 'sha256'), 'hex');

  PERFORM pg_advisory_xact_lock(
    hashtextextended(
      'conference-confirmation-idempotency:' || p_conferencia_id::text || ':' || btrim(p_idempotency_key),
      0
    )
  );

  SELECT cc.* INTO v_existing FROM public.conferencia_confirmacoes cc
  WHERE cc.conferencia_id = p_conferencia_id AND cc.idempotency_key = btrim(p_idempotency_key);
  IF FOUND THEN
    IF v_existing.payload_hash <> v_payload_hash OR v_existing.actor_id <> v_actor_id THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT' USING ERRCODE = 'P0001';
    END IF;
    RETURN app_private.conferencia_recibo(v_existing.id);
  END IF;
  IF v_conferencia.version <> p_expected_version THEN
    RAISE EXCEPTION 'CONFERENCE_VERSION_CONFLICT' USING ERRCODE = '40001';
  END IF;
  IF v_projeto_status::text NOT IN ('CONFIRMADO', 'MONTAGEM', 'EM_CAMPO') THEN
    RAISE EXCEPTION 'Evento em status % não aceita saída física', v_projeto_status USING ERRCODE = '55000';
  END IF;

  PERFORM 1 FROM public.conferencia_decisoes cd WHERE cd.id = ANY(v_decision_ids)
  ORDER BY cd.id FOR UPDATE;
  SELECT count(*)::integer INTO v_decision_count FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids)
    AND cd.conferencia_id = p_conferencia_id
    AND cd.resultado = 'PRESENTE'
    AND cd.applied_confirmation_id IS NULL
    AND cd.resolution <> 'IGNORAR';
  IF v_decision_count <> cardinality(v_decision_ids) THEN
    RAISE EXCEPTION 'Decisão ausente, aplicada ou incompatível com saída' USING ERRCODE = '22023';
  END IF;
  SELECT count(*)::integer INTO v_unresolved_count FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids) AND cd.resolution = 'REVISAR';
  IF v_unresolved_count > 0 THEN
    RAISE EXCEPTION 'EXTRA_REQUIRES_RESOLUTION' USING ERRCODE = '22023';
  END IF;
  SELECT array_agg(cd.serial_number_id ORDER BY cd.serial_number_id) INTO v_serial_ids
  FROM public.conferencia_decisoes cd WHERE cd.id = ANY(v_decision_ids);
  PERFORM 1 FROM public.serial_numbers sn WHERE sn.id = ANY(v_serial_ids) ORDER BY sn.id FOR UPDATE;
  SELECT count(*)::integer INTO v_bad_status_count FROM public.serial_numbers sn
  WHERE sn.id = ANY(v_serial_ids) AND sn.status <> 'DISPONIVEL';
  IF v_bad_status_count > 0 THEN
    RAISE EXCEPTION 'Unidade indisponível, confirmação abortada' USING ERRCODE = '55000';
  END IF;
  PERFORM 1 FROM public.packing_list pl WHERE pl.projeto_id = v_conferencia.projeto_id
  ORDER BY pl.id FOR UPDATE;
  FOR v_substitution IN SELECT cd.serial_number_id, cd.replaced_serial_id
    FROM public.conferencia_decisoes cd WHERE cd.id = ANY(v_decision_ids)
      AND cd.resolution = 'SUBSTITUICAO' ORDER BY cd.id
  LOOP
    UPDATE public.packing_list pl SET serial_numbers_designados = array_replace(
      pl.serial_numbers_designados, v_substitution.replaced_serial_id, v_substitution.serial_number_id
    ) WHERE pl.projeto_id = v_conferencia.projeto_id
      AND v_substitution.replaced_serial_id = ANY(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[]));
    IF NOT FOUND THEN
      RAISE EXCEPTION 'SUBSTITUTION_TARGET_CHANGED' USING ERRCODE = '40001';
    END IF;
  END LOOP;
  SELECT NOT EXISTS (SELECT 1 FROM public.packing_list pl WHERE pl.projeto_id = v_conferencia.projeto_id)
    OR EXISTS (
      SELECT 1 FROM public.packing_list pl CROSS JOIN LATERAL unnest(
        coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[])
      ) AS expected_serial_id WHERE pl.projeto_id = v_conferencia.projeto_id
      AND NOT EXISTS (
        SELECT 1 FROM public.conferencia_decisoes applied
        WHERE applied.conferencia_id = p_conferencia_id
          AND applied.serial_number_id = expected_serial_id
          AND (applied.applied_confirmation_id IS NOT NULL OR applied.id = ANY(v_decision_ids))
      )
    ) OR EXISTS (
      SELECT 1 FROM public.packing_list pl WHERE pl.projeto_id = v_conferencia.projeto_id
      AND (coalesce(array_length(pl.serial_numbers_designados, 1), 0) + coalesce((
        SELECT sum(greatest((rental->>'quantidade')::integer, 0))
        FROM jsonb_array_elements(coalesce(pl.alugueis_avulsos, '[]'::jsonb)) AS rental
        WHERE rental ? 'quantidade' AND (rental->>'quantidade') ~ '^[0-9]+$'
      ), 0)) < pl.quantidade
    ) INTO v_is_incomplete;
  IF v_is_incomplete AND length(coalesce(v_incomplete_reason, '')) < 3 THEN
    RAISE EXCEPTION 'Saída incompleta exige motivo' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.conferencia_confirmacoes (
    conferencia_id, idempotency_key, payload_hash, actor_id, incomplete_reason
  ) VALUES (
    p_conferencia_id, btrim(p_idempotency_key), v_payload_hash, v_actor_id, v_incomplete_reason
  ) RETURNING * INTO v_confirmation;
  INSERT INTO public.movimentacoes (
    serial_number_id, projeto_id, tipo, status_anterior, status_novo, registrado_por, metodo_scan,
    notas, conferencia_confirmacao_id, conferencia_decisao_id
  ) SELECT cd.serial_number_id, v_conferencia.projeto_id, 'SAIDA', 'DISPONIVEL', 'EM_CAMPO',
    v_actor_id::text, cd.metodo, v_incomplete_reason, v_confirmation.id, cd.id
  FROM public.conferencia_decisoes cd WHERE cd.id = ANY(v_decision_ids);
  UPDATE public.serial_numbers sn SET status = 'EM_CAMPO' WHERE sn.id = ANY(v_serial_ids);
  UPDATE public.conferencia_decisoes cd SET applied_confirmation_id = v_confirmation.id, updated_at = now()
  WHERE cd.id = ANY(v_decision_ids);
  UPDATE public.projetos p SET status = 'EM_CAMPO'
  WHERE p.id = v_conferencia.projeto_id AND p.status <> 'EM_CAMPO';
  UPDATE public.conferencias c SET version = c.version + 1, updated_at = now()
  WHERE c.id = p_conferencia_id;
  RETURN app_private.conferencia_recibo(v_confirmation.id);
END;
$$;

REVOKE ALL ON FUNCTION public.confirmar_conferencia_saida(uuid, uuid[], bigint, text, text)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.confirmar_conferencia_saida(uuid, uuid[], bigint, text, text)
TO authenticated;
