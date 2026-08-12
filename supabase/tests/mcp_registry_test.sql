BEGIN;
DO $$ BEGIN
  CREATE TYPE public.categoria_enum AS ENUM ('AUDIO');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE public.user_role_enum AS ENUM ('viewer', 'editor', 'admin');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  role public.user_role_enum NOT NULL DEFAULT 'viewer'
);
CREATE TABLE IF NOT EXISTS public.items (
  id uuid PRIMARY KEY,
  nome text NOT NULL,
  categoria public.categoria_enum NOT NULL
);
CREATE TABLE IF NOT EXISTS public.serial_numbers (
  id uuid PRIMARY KEY,
  item_id uuid NOT NULL REFERENCES public.items(id),
  codigo_interno text UNIQUE NOT NULL,
  status text NOT NULL
);
CREATE TABLE IF NOT EXISTS public.projetos (
  id uuid PRIMARY KEY,
  nome text NOT NULL,
  status text NOT NULL,
  data_inicio date,
  data_fim date,
  local text
);
CREATE TABLE IF NOT EXISTS public.packing_list (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id),
  item_id uuid NOT NULL REFERENCES public.items(id),
  quantidade integer NOT NULL DEFAULT 1,
  serial_numbers_designados uuid[],
  alugueis_avulsos jsonb NOT NULL DEFAULT '[]'::jsonb
);
CREATE TABLE IF NOT EXISTS public.conferencia_confirmacoes (
  id uuid PRIMARY KEY
);
CREATE SCHEMA IF NOT EXISTS app_private;
DO $outer$
BEGIN
  IF to_regprocedure('app_private.current_user_role()') IS NULL THEN
    EXECUTE $function$
      CREATE FUNCTION app_private.current_user_role()
      RETURNS text
      LANGUAGE sql
      STABLE
      AS 'SELECT ''viewer''::text'
    $function$;
  END IF;
END;
$outer$;
\ir ../migrations/20260812163430_mcp_client_registry_and_operations.sql
\ir ../migrations/20260812210000_mcp_oauth_and_read_capabilities.sql
GRANT mmd_mcp_executor TO postgres;

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'dddddddd-dddd-dddd-dddd-ddddddddddd4',
  'authenticated',
  'authenticated',
  'mcp-registry-test@test.local',
  '',
  now(),
  '{"provider":"email","providers":["email"]}',
  '{}',
  now(),
  now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, role)
VALUES (
  'dddddddd-dddd-dddd-dddd-ddddddddddd4',
  'mcp-registry-test@test.local',
  'viewer'
) ON CONFLICT (id) DO UPDATE SET role = excluded.role;

INSERT INTO public.mcp_clients (client_id, resource_audience)
VALUES ('mcp-registry-test', 'https://mmd.test/api/mcp');

INSERT INTO public.items (id, nome, categoria)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Item MCP', 'AUDIO')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.serial_numbers (id, item_id, codigo_interno, status)
VALUES (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  'MMD-MCP-0001',
  'DISPONIVEL'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.projetos (id, nome, status)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', 'Evento MCP', 'PLANEJAMENTO')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.packing_list (projeto_id, item_id, quantidade)
VALUES (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  1
);

INSERT INTO public.mcp_operation_log (
  client_id, actor_id, tool, client_request_id, payload_hash, intent, outcome
) VALUES
  (
    'mcp-registry-test',
    'dddddddd-dddd-dddd-dddd-ddddddddddd4',
    'mmd:eventos:read',
    'eventos-read-test',
    repeat('b', 64),
    'READ',
    'SUCCEEDED'
  ),
  (
    'mcp-registry-test',
    'dddddddd-dddd-dddd-dddd-ddddddddddd4',
    'mmd:unidades:read',
    'unidades-read-test',
    repeat('c', 64),
    'READ',
    'SUCCEEDED'
  );

DO $$
DECLARE
  v_hook_result jsonb;
BEGIN
  IF (SELECT count(*) FROM public.mcp_operation_log) <> 2 THEN
    RAISE EXCEPTION 'Os dois recursos MCP precisam persistir no registry';
  END IF;

  v_hook_result := public.mmd_custom_access_token_hook(jsonb_build_object(
    'client_id', 'mcp-registry-test',
    'claims', jsonb_build_object(
      'aud', 'authenticated',
      'client_id', 'mcp-registry-test',
      'sub', 'dddddddd-dddd-dddd-dddd-ddddddddddd4'
    )
  ));
  IF v_hook_result->'claims'->>'aud' <> 'https://mmd.test/api/mcp' THEN
    RAISE EXCEPTION 'Hook não vinculou o token ao resource MCP';
  END IF;
  IF v_hook_result->'claims'->'mcp_scopes' <> '["mcp:read"]'::jsonb THEN
    RAISE EXCEPTION 'Hook não emitiu os escopos do registry';
  END IF;

  BEGIN
    INSERT INTO public.mcp_clients (client_id, resource_audience, scopes)
    VALUES ('mcp-empty-scopes', 'https://mmd.test/api/mcp', ARRAY[]::text[]);
    RAISE EXCEPTION 'Cliente MCP sem escopo passou pela constraint';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  BEGIN
    INSERT INTO public.mcp_operation_log (
      client_id, actor_id, tool, client_request_id, payload_hash, intent, outcome
    ) VALUES (
      'mcp-registry-test',
      'dddddddd-dddd-dddd-dddd-ddddddddddd4',
      'mmd://eventos/{evento_id}',
      'invalid-target-test',
      repeat('d', 64),
      'READ',
      'FAILED'
    );
    RAISE EXCEPTION 'Alvo com template passou silenciosamente pela CHECK';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
END;
$$;

SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true);
SELECT public.issue_mcp_read_capability(
  encode(extensions.digest('event-capability', 'sha256'), 'hex'),
  'mcp-registry-test',
  'dddddddd-dddd-dddd-dddd-ddddddddddd4',
  'mmd:eventos:read',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
  repeat('e', 64),
  30
);
SELECT public.issue_mcp_read_capability(
  encode(extensions.digest('unit-capability', 'sha256'), 'hex'),
  'mcp-registry-test',
  'dddddddd-dddd-dddd-dddd-ddddddddddd4',
  'mmd:unidades:read',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
  repeat('f', 64),
  30
);
SELECT public.issue_mcp_read_capability(
  encode(extensions.digest('revoked-scope-capability', 'sha256'), 'hex'),
  'mcp-registry-test',
  'dddddddd-dddd-dddd-dddd-ddddddddddd4',
  'mmd:eventos:read',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
  repeat('a', 64),
  30
);
UPDATE public.mcp_clients
SET scopes = ARRAY['mcp:operate']::text[]
WHERE client_id = 'mcp-registry-test';
SET LOCAL ROLE postgres;

SET LOCAL ROLE mmd_mcp_executor;
DO $$
DECLARE
  v_event jsonb;
  v_unit jsonb;
BEGIN
  IF pg_has_role('mmd_mcp_executor', 'authenticated', 'MEMBER') THEN
    RAISE EXCEPTION 'Executor MCP ainda pode assumir authenticated';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND rolsuper) THEN
    RAISE EXCEPTION 'Executor MCP virou superuser';
  END IF;

  BEGIN
    PERFORM public.mcp_read_event(
      'revoked-scope-capability',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
      repeat('a', 64)
    );
    RAISE EXCEPTION 'Capability sobreviveu à remoção do escopo de leitura';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'MCP_CAPABILITY_INVALID' THEN
      RAISE;
    END IF;
  END;

  PERFORM set_config('role', 'postgres', true);
  UPDATE public.mcp_clients
  SET scopes = ARRAY['mcp:read']::text[]
  WHERE client_id = 'mcp-registry-test';
  PERFORM set_config('role', 'mmd_mcp_executor', true);

  BEGIN
    PERFORM 1 FROM public.projetos LIMIT 1;
    RAISE EXCEPTION 'Executor MCP leu estoque diretamente';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  v_event := public.mcp_read_event(
    'event-capability',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
    repeat('e', 64)
  );
  IF v_event->>'nome' <> 'Evento MCP' OR jsonb_array_length(v_event->'packing_raw') <> 1 THEN
    RAISE EXCEPTION 'RPC MCP não retornou o Evento allowlisted';
  END IF;

  v_unit := public.mcp_read_unit(
    'unit-capability',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    repeat('f', 64)
  );
  IF v_unit->>'codigo_interno' <> 'MMD-MCP-0001' OR v_unit->'item'->>'nome' <> 'Item MCP' THEN
    RAISE EXCEPTION 'RPC MCP não retornou a Unidade allowlisted';
  END IF;

  BEGIN
    PERFORM public.mcp_read_event(
      'event-capability',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
      repeat('e', 64)
    );
    RAISE EXCEPTION 'Capability MCP foi reutilizada';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'MCP_CAPABILITY_INVALID' THEN
      RAISE;
    END IF;
  END;
END;
$$;
SET LOCAL ROLE postgres;

ROLLBACK;
