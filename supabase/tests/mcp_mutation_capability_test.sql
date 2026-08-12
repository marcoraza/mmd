BEGIN;
SELECT plan(3);
GRANT mmd_mcp_executor TO postgres;

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5',
  'authenticated',
  'authenticated',
  'mcp-mutation-test@test.local',
  '',
  now(),
  '{"provider":"email","providers":["email"]}',
  '{}',
  now(),
  now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, role)
VALUES (
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5',
  'mcp-mutation-test@test.local',
  'editor'
) ON CONFLICT (id) DO UPDATE SET role = excluded.role;

INSERT INTO public.mcp_clients (client_id, resource_audience, scopes)
VALUES (
  'mcp-mutation-test',
  'https://mmd.test/api/mcp',
  ARRAY['mcp:read', 'mcp:operate']::text[]
);

SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true);

SELECT public.issue_mcp_operation_capability(
  encode(extensions.digest('mutation-token-1', 'sha256'), 'hex'),
  'mcp-mutation-test',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5',
  'mmd_unidade_vincular_rfid',
  'mutation-request-1',
  jsonb_build_object(
    'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff6',
    'epc', 'E2000017221101441890ABCD'
  ),
  30
);

SELECT public.issue_mcp_operation_capability(
  encode(extensions.digest('mutation-token-2', 'sha256'), 'hex'),
  'mcp-mutation-test',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5',
  'mmd_unidade_vincular_rfid',
  'mutation-request-1',
  jsonb_build_object(
    'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff6',
    'epc', 'E2000017221101441890ABCD'
  ),
  30
);

DO $$
BEGIN
  IF (
    SELECT count(*)
    FROM public.mcp_operation_log
    WHERE client_id = 'mcp-mutation-test'
      AND actor_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5'
      AND tool = 'mmd_unidade_vincular_rfid'
      AND client_request_id = 'mutation-request-1'
  ) <> 1 THEN
    RAISE EXCEPTION 'Retry criou uma segunda intenção MCP';
  END IF;

  BEGIN
    PERFORM public.issue_mcp_operation_capability(
      encode(extensions.digest('mutation-token-conflict', 'sha256'), 'hex'),
      'mcp-mutation-test',
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5',
      'mmd_unidade_vincular_rfid',
      'mutation-request-1',
      jsonb_build_object(
        'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff6',
        'epc', 'E2000017221101441890FFFF'
      ),
      30
    );
    RAISE EXCEPTION 'Payload diferente reutilizou client_request_id';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM <> 'MCP_REQUEST_PAYLOAD_CONFLICT' THEN
      RAISE;
    END IF;
  END;
END;
$$;
SELECT pass('Claim MCP persiste retry e rejeita payload conflitante');

SET LOCAL ROLE postgres;
SET LOCAL ROLE mmd_mcp_executor;

DO $$
DECLARE
  v_result jsonb;
BEGIN
  BEGIN
    PERFORM public.execute_mcp_operation(
      'invalid-token',
      jsonb_build_object(
        'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff6',
        'epc', 'E2000017221101441890ABCD'
      )
    );
    RAISE EXCEPTION 'Executor aceitou token inválido';
  EXCEPTION WHEN SQLSTATE '28000' THEN
    IF SQLERRM <> 'MCP_CAPABILITY_INVALID' THEN
      RAISE;
    END IF;
  END;

  v_result := public.execute_mcp_operation(
    'mutation-token-2',
    jsonb_build_object(
      'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff6',
      'epc', 'E2000017221101441890ABCD'
    )
  );
  IF v_result->>'ok' <> 'false' OR v_result->>'error_code' IS NULL THEN
    RAISE EXCEPTION 'Falha canônica fabricou ACK MCP';
  END IF;
END;
$$;

SET LOCAL ROLE postgres;
SELECT pass('Executor rejeita capability inválida e não fabrica ACK em falha');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.mcp_operation_log
    WHERE client_id = 'mcp-mutation-test'
      AND client_request_id = 'mutation-request-1'
      AND outcome = 'FAILED'
      AND result IS NULL
      AND error_code IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Falha MCP não ficou auditada sem ACK';
  END IF;
END;
$$;

SELECT pass('Falha canônica persiste resultado FAILED sem ACK');
SELECT * FROM finish();

ROLLBACK;
