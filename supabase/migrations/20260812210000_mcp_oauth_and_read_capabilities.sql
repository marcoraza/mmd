-- Migra o registry MCP legado para OAuth e isola leituras de estoque atrás de
-- capabilities opacas, curtas e de uso único. A senha do executor não escolhe
-- ator, cliente, alvo nem argumentos.

ALTER TABLE public.mcp_clients
  ADD COLUMN resource_audience text;

UPDATE public.mcp_clients
SET
  resource_audience = 'https://disabled.invalid/api/mcp',
  active = false,
  revoked_at = coalesce(revoked_at, now())
WHERE resource_audience IS NULL;

ALTER TABLE public.mcp_clients
  ALTER COLUMN resource_audience SET NOT NULL,
  ADD CONSTRAINT mcp_clients_resource_audience_check CHECK (
    resource_audience LIKE 'https://%/api/mcp'
    AND resource_audience NOT LIKE '%?%'
    AND resource_audience NOT LIKE '%#%'
    AND resource_audience !~ '[[:space:]]'
  ),
  DROP CONSTRAINT mcp_clients_scopes_check,
  ADD CONSTRAINT mcp_clients_scopes_check CHECK (
    cardinality(scopes) > 0
    AND scopes <@ ARRAY['mcp:read', 'mcp:operate']::text[]
    AND ('mcp:operate' <> ALL(scopes) OR 'mcp:read' = ANY(scopes))
  ),
  DROP COLUMN secret_hash;

CREATE OR REPLACE FUNCTION public.mmd_custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_claims jsonb := coalesce(event->'claims', '{}'::jsonb);
  v_client_id text := coalesce(event->>'client_id', event->'claims'->>'client_id');
  v_resource_audience text;
  v_scopes text[];
BEGIN
  SELECT client.resource_audience, client.scopes
    INTO v_resource_audience, v_scopes
  FROM public.mcp_clients AS client
  WHERE client.client_id = v_client_id
    AND client.active
    AND client.revoked_at IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('claims', v_claims);
  END IF;

  v_claims := jsonb_set(v_claims, '{aud}', to_jsonb(v_resource_audience), true);
  v_claims := jsonb_set(v_claims, '{mcp_scopes}', to_jsonb(v_scopes), true);
  RETURN jsonb_build_object('claims', v_claims);
END;
$$;

GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
REVOKE ALL ON FUNCTION public.mmd_custom_access_token_hook(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mmd_custom_access_token_hook(jsonb) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.mmd_custom_access_token_hook(jsonb) TO supabase_auth_admin;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mmd_mcp_executor') THEN
    CREATE ROLE mmd_mcp_executor NOLOGIN NOINHERIT NOBYPASSRLS;
  END IF;
END;
$$;

REVOKE authenticated FROM mmd_mcp_executor;
ALTER ROLE mmd_mcp_executor NOLOGIN NOINHERIT NOBYPASSRLS;
ALTER ROLE mmd_mcp_executor SET statement_timeout = '5s';

CREATE SCHEMA IF NOT EXISTS app_private;
REVOKE ALL ON SCHEMA app_private FROM PUBLIC, anon, mmd_mcp_executor;

CREATE TABLE app_private.mcp_read_capabilities (
  token_hash text PRIMARY KEY CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  client_id text NOT NULL REFERENCES public.mcp_clients(client_id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target text NOT NULL CHECK (target IN ('mmd:eventos:read', 'mmd:unidades:read')),
  resource_id uuid NOT NULL,
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (expires_at > created_at),
  CHECK (used_at IS NULL OR used_at >= created_at)
);

CREATE INDEX mcp_read_capabilities_expiry_idx
  ON app_private.mcp_read_capabilities(expires_at);

REVOKE ALL ON TABLE app_private.mcp_read_capabilities FROM PUBLIC;
REVOKE ALL ON TABLE app_private.mcp_read_capabilities FROM anon, authenticated, mmd_mcp_executor;

CREATE OR REPLACE FUNCTION app_private.can_read_internal_stock(p_actor_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = p_actor_id
      AND profile.role IN ('viewer', 'editor', 'admin')
  );
$$;

REVOKE ALL ON FUNCTION app_private.can_read_internal_stock(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.can_read_internal_stock(uuid) FROM anon, mmd_mcp_executor;
GRANT EXECUTE ON FUNCTION app_private.can_read_internal_stock(uuid) TO authenticated;

DROP POLICY IF EXISTS items_read ON public.items;
CREATE POLICY items_read ON public.items
  FOR SELECT TO authenticated
  USING (app_private.can_read_internal_stock((SELECT auth.uid())));

DROP POLICY IF EXISTS serial_numbers_read ON public.serial_numbers;
CREATE POLICY serial_numbers_read ON public.serial_numbers
  FOR SELECT TO authenticated
  USING (app_private.can_read_internal_stock((SELECT auth.uid())));

DROP POLICY IF EXISTS projetos_read ON public.projetos;
CREATE POLICY projetos_read ON public.projetos
  FOR SELECT TO authenticated
  USING (app_private.can_read_internal_stock((SELECT auth.uid())));

DROP POLICY IF EXISTS packing_list_read ON public.packing_list;
CREATE POLICY packing_list_read ON public.packing_list
  FOR SELECT TO authenticated
  USING (app_private.can_read_internal_stock((SELECT auth.uid())));

CREATE OR REPLACE FUNCTION public.issue_mcp_read_capability(
  p_token_hash text,
  p_client_id text,
  p_actor_id uuid,
  p_target text,
  p_resource_id uuid,
  p_payload_hash text,
  p_ttl_seconds integer DEFAULT 30
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'MCP_CAPABILITY_ISSUER_DENIED';
  END IF;
  IF p_token_hash !~ '^[0-9a-f]{64}$'
     OR p_payload_hash !~ '^[0-9a-f]{64}$'
     OR p_target NOT IN ('mmd:eventos:read', 'mmd:unidades:read')
     OR p_ttl_seconds < 1
     OR p_ttl_seconds > 60 THEN
    RAISE EXCEPTION 'MCP_CAPABILITY_INVALID';
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
    RAISE EXCEPTION 'MCP_CAPABILITY_IDENTITY_DENIED';
  END IF;

  DELETE FROM app_private.mcp_read_capabilities
  WHERE expires_at < clock_timestamp() - interval '1 hour';

  INSERT INTO app_private.mcp_read_capabilities (
    token_hash,
    client_id,
    actor_id,
    target,
    resource_id,
    payload_hash,
    expires_at
  ) VALUES (
    p_token_hash,
    p_client_id,
    p_actor_id,
    p_target,
    p_resource_id,
    p_payload_hash,
    clock_timestamp() + make_interval(secs => p_ttl_seconds)
  );
END;
$$;

CREATE OR REPLACE FUNCTION app_private.consume_mcp_read_capability(
  p_token_hash text,
  p_target text,
  p_resource_id uuid,
  p_payload_hash text
)
RETURNS TABLE(actor_id uuid, client_id text)
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
  UPDATE app_private.mcp_read_capabilities AS capability
  SET used_at = clock_timestamp()
  FROM public.mcp_clients AS client, public.profiles AS profile
  WHERE capability.token_hash = p_token_hash
    AND capability.target = p_target
    AND capability.resource_id = p_resource_id
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

CREATE OR REPLACE FUNCTION public.mcp_read_event(
  p_capability_token text,
  p_evento_id uuid,
  p_payload_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid;
  v_client_id text;
  v_event jsonb;
  v_packing jsonb;
BEGIN
  SELECT consumed.actor_id, consumed.client_id
    INTO v_actor_id, v_client_id
  FROM app_private.consume_mcp_read_capability(
    encode(extensions.digest(p_capability_token, 'sha256'), 'hex'),
    'mmd:eventos:read',
    p_evento_id,
    p_payload_hash
  ) AS consumed;
  IF v_actor_id IS NULL OR v_client_id IS NULL THEN
    RAISE EXCEPTION 'MCP_CAPABILITY_INVALID';
  END IF;
  IF NOT app_private.can_read_internal_stock(v_actor_id) THEN
    RAISE EXCEPTION 'MCP_READ_DENIED';
  END IF;

  SELECT jsonb_build_object(
    'id', evento.id::text,
    'nome', evento.nome,
    'status', evento.status::text,
    'data_inicio', evento.data_inicio::text,
    'data_fim', evento.data_fim::text,
    'local', evento.local
  ) INTO v_event
  FROM public.projetos AS evento
  WHERE evento.id = p_evento_id;

  IF v_event IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT coalesce(
    jsonb_agg(jsonb_build_object(
      'quantidade', linha.quantidade,
      'qtd_propria', coalesce(cardinality(linha.serial_numbers_designados), 0),
      'alugueis_avulsos', linha.alugueis_avulsos
    )),
    '[]'::jsonb
  ) INTO v_packing
  FROM public.packing_list AS linha
  WHERE linha.projeto_id = p_evento_id;

  RETURN v_event || jsonb_build_object('packing_raw', v_packing);
END;
$$;

CREATE OR REPLACE FUNCTION public.mcp_read_unit(
  p_capability_token text,
  p_unidade_id uuid,
  p_payload_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid;
  v_client_id text;
  v_unit jsonb;
BEGIN
  SELECT consumed.actor_id, consumed.client_id
    INTO v_actor_id, v_client_id
  FROM app_private.consume_mcp_read_capability(
    encode(extensions.digest(p_capability_token, 'sha256'), 'hex'),
    'mmd:unidades:read',
    p_unidade_id,
    p_payload_hash
  ) AS consumed;
  IF v_actor_id IS NULL OR v_client_id IS NULL THEN
    RAISE EXCEPTION 'MCP_CAPABILITY_INVALID';
  END IF;
  IF NOT app_private.can_read_internal_stock(v_actor_id) THEN
    RAISE EXCEPTION 'MCP_READ_DENIED';
  END IF;

  SELECT jsonb_build_object(
    'id', unidade.id::text,
    'codigo_interno', unidade.codigo_interno,
    'status', unidade.status::text,
    'item', jsonb_build_object(
      'nome', item.nome,
      'categoria', item.categoria::text
    )
  ) INTO v_unit
  FROM public.serial_numbers AS unidade
  JOIN public.items AS item ON item.id = unidade.item_id
  WHERE unidade.id = p_unidade_id;

  RETURN v_unit;
END;
$$;

REVOKE ALL ON FUNCTION public.issue_mcp_read_capability(text, text, uuid, text, uuid, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.issue_mcp_read_capability(text, text, uuid, text, uuid, text, integer) FROM anon, authenticated, mmd_mcp_executor;
GRANT EXECUTE ON FUNCTION public.issue_mcp_read_capability(text, text, uuid, text, uuid, text, integer) TO service_role;

REVOKE ALL ON FUNCTION app_private.consume_mcp_read_capability(text, text, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.consume_mcp_read_capability(text, text, uuid, text) FROM anon, authenticated, mmd_mcp_executor;

REVOKE ALL ON FUNCTION public.mcp_read_event(text, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mcp_read_event(text, uuid, text) FROM anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mcp_read_event(text, uuid, text) TO mmd_mcp_executor;

REVOKE ALL ON FUNCTION public.mcp_read_unit(text, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mcp_read_unit(text, uuid, text) FROM anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mcp_read_unit(text, uuid, text) TO mmd_mcp_executor;

REVOKE ALL ON TABLE public.items, public.serial_numbers, public.projetos, public.packing_list
  FROM mmd_mcp_executor;

COMMENT ON ROLE mmd_mcp_executor IS
  'Executor MCP sem acesso direto ao estoque. Só executa RPCs allowlisted com capability opaca de uso único.';

COMMENT ON TABLE app_private.mcp_read_capabilities IS
  'Capabilities MCP com hash do token, ator, cliente, alvo e argumentos. Nunca guarda o token puro.';
