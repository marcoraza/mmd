BEGIN;
\ir ../migrations/20260812163430_mcp_client_registry_and_operations.sql

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

INSERT INTO public.mcp_clients (client_id, secret_hash)
VALUES ('mcp-registry-test', repeat('a', 64));

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
BEGIN
  IF (SELECT count(*) FROM public.mcp_operation_log) <> 2 THEN
    RAISE EXCEPTION 'Os dois recursos MCP precisam persistir no registry';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.mcp_operation_log WHERE tool = 'mmd:eventos:read') THEN
    RAISE EXCEPTION 'O alvo de Evento não atende a CHECK do registry';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.mcp_operation_log WHERE tool = 'mmd:unidades:read') THEN
    RAISE EXCEPTION 'O alvo de Unidade não atende a CHECK do registry';
  END IF;

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

ROLLBACK;
