BEGIN;
SELECT plan(6);
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

INSERT INTO public.items (id, nome, categoria, codigo_interno)
VALUES (
  'ffffffff-ffff-4fff-8fff-fffffffffff1',
  'Item MCP mutação',
  'AUDIO',
  'MMD-MCP-MUT-ITEM'
);

INSERT INTO public.serial_numbers (id, item_id, codigo_interno)
VALUES (
  'ffffffff-ffff-4fff-8fff-fffffffffff2',
  'ffffffff-ffff-4fff-8fff-fffffffffff1',
  'MMD-MCP-MUT-UNIT'
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

SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true);
SELECT public.issue_mcp_operation_capability(
  encode(extensions.digest('mutation-success-token-1', 'sha256'), 'hex'),
  'mcp-mutation-test',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5',
  'mmd_unidade_vincular_rfid',
  'mutation-request-2',
  jsonb_build_object(
    'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff2',
    'epc', 'E2000017221101441890DCBA'
  ),
  30
);
SET LOCAL ROLE postgres;
SET LOCAL ROLE mmd_mcp_executor;

DO $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := public.execute_mcp_operation(
    'mutation-success-token-1',
    jsonb_build_object(
      'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff2',
      'epc', 'E2000017221101441890DCBA'
    )
  );
  IF v_result->>'ok' <> 'true' OR v_result->'result'->>'operation_id' IS NULL THEN
    RAISE EXCEPTION 'Operação canônica válida não produziu ACK persistido';
  END IF;
END;
$$;

SET LOCAL ROLE postgres;
SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true);

DO $$
DECLARE
  v_retry jsonb;
BEGIN
  v_retry := public.issue_mcp_operation_capability(
    encode(extensions.digest('mutation-success-token-2', 'sha256'), 'hex'),
    'mcp-mutation-test',
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5',
    'mmd_unidade_vincular_rfid',
    'mutation-request-2',
    jsonb_build_object(
      'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff2',
      'epc', 'E2000017221101441890DCBA'
    ),
    30
  );
  IF v_retry->>'completed' <> 'true'
     OR v_retry->'result'->>'operation_id' IS NULL THEN
    RAISE EXCEPTION 'Retry concluído não devolveu o ACK persistido';
  END IF;
END;
$$;

SET LOCAL ROLE postgres;
SELECT pass('Retry concluído devolve o mesmo resultado persistido sem novo efeito');

CREATE OR REPLACE FUNCTION pg_temp.run_mcp_operation(
  p_tool text,
  p_request_id text,
  p_arguments jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_token text := 'token-' || p_request_id;
  v_response jsonb;
BEGIN
  PERFORM set_config('role', 'service_role', true);
  PERFORM set_config('request.jwt.claims', '{"role":"service_role"}', true);
  PERFORM public.issue_mcp_operation_capability(
    encode(extensions.digest(v_token, 'sha256'), 'hex'),
    'mcp-mutation-test',
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5',
    p_tool,
    p_request_id,
    p_arguments,
    30
  );
  PERFORM set_config('role', 'mmd_mcp_executor', true);
  v_response := public.execute_mcp_operation(v_token, p_arguments);
  PERFORM set_config('role', 'postgres', true);
  IF v_response->>'ok' <> 'true' THEN
    RAISE EXCEPTION 'Dispatcher MCP falhou para %: %', p_tool, v_response;
  END IF;
  RETURN v_response;
EXCEPTION WHEN OTHERS THEN
  PERFORM set_config('role', 'postgres', true);
  RAISE;
END;
$$;

INSERT INTO public.items (id, nome, categoria, codigo_interno, quantidade_total)
VALUES (
  'ffffffff-ffff-4fff-8fff-ffffffffffe1',
  'Item MCP dispatcher',
  'AUDIO',
  'MMD-MCP-DISPATCH-ITEM',
  3
);

INSERT INTO public.serial_numbers (id, item_id, codigo_interno)
VALUES
  ('ffffffff-ffff-4fff-8fff-ffffffffffe2', 'ffffffff-ffff-4fff-8fff-ffffffffffe1', 'MMD-MCP-DISPATCH-1'),
  ('ffffffff-ffff-4fff-8fff-ffffffffffe3', 'ffffffff-ffff-4fff-8fff-ffffffffffe1', 'MMD-MCP-DISPATCH-2'),
  ('ffffffff-ffff-4fff-8fff-ffffffffffe4', 'ffffffff-ffff-4fff-8fff-ffffffffffe1', 'MMD-MCP-DISPATCH-3');

INSERT INTO public.projetos (id, nome, status)
VALUES ('ffffffff-ffff-4fff-8fff-ffffffffffe5', 'Evento MCP dispatcher', 'CONFIRMADO');

INSERT INTO public.packing_list (
  id, projeto_id, item_id, quantidade, serial_numbers_designados
) VALUES (
  'ffffffff-ffff-4fff-8fff-ffffffffffe6',
  'ffffffff-ffff-4fff-8fff-ffffffffffe5',
  'ffffffff-ffff-4fff-8fff-ffffffffffe1',
  2,
  ARRAY[
    'ffffffff-ffff-4fff-8fff-ffffffffffe2'::uuid,
    'ffffffff-ffff-4fff-8fff-ffffffffffe3'::uuid
  ]
);

DO $$
DECLARE
  v_conference_id uuid;
  v_return_conference_id uuid;
  v_extra_decision_id uuid;
  v_pending_id uuid;
  v_version bigint;
  v_decision_ids uuid[];
BEGIN
  PERFORM pg_temp.run_mcp_operation(
    'mmd_conferencia_salvar_decisao',
    'dispatch-save-output-1',
    jsonb_build_object(
      'evento_id', 'ffffffff-ffff-4fff-8fff-ffffffffffe5',
      'direcao', 'SAIDA',
      'unidade_id', 'ffffffff-ffff-4fff-8fff-ffffffffffe2',
      'resultado', 'PRESENTE',
      'metodo', 'QRCODE',
      'source_event_id', 'dispatch:output:1',
      'captured_at', '2026-08-12T18:00:00Z'
    )
  );
  PERFORM pg_temp.run_mcp_operation(
    'mmd_conferencia_salvar_decisao',
    'dispatch-save-output-2',
    jsonb_build_object(
      'evento_id', 'ffffffff-ffff-4fff-8fff-ffffffffffe5',
      'direcao', 'SAIDA',
      'unidade_id', 'ffffffff-ffff-4fff-8fff-ffffffffffe3',
      'resultado', 'PRESENTE',
      'metodo', 'RFID',
      'source_event_id', 'dispatch:output:2',
      'captured_at', '2026-08-12T18:00:01Z'
    )
  );
  PERFORM pg_temp.run_mcp_operation(
    'mmd_conferencia_salvar_decisao',
    'dispatch-save-extra-1',
    jsonb_build_object(
      'evento_id', 'ffffffff-ffff-4fff-8fff-ffffffffffe5',
      'direcao', 'SAIDA',
      'unidade_id', 'ffffffff-ffff-4fff-8fff-ffffffffffe4',
      'resultado', 'PRESENTE',
      'metodo', 'MANUAL',
      'source_event_id', 'dispatch:output:extra',
      'captured_at', '2026-08-12T18:00:02Z',
      'manual_reason', 'Unidade extra confirmada pelo operador'
    )
  );

  SELECT conference.id, conference.version
    INTO v_conference_id, v_version
  FROM public.conferencias AS conference
  WHERE conference.projeto_id = 'ffffffff-ffff-4fff-8fff-ffffffffffe5'
    AND conference.direcao = 'SAIDA';
  SELECT decision.id
    INTO v_extra_decision_id
  FROM public.conferencia_decisoes AS decision
  WHERE decision.conferencia_id = v_conference_id
    AND decision.serial_number_id = 'ffffffff-ffff-4fff-8fff-ffffffffffe4';

  PERFORM pg_temp.run_mcp_operation(
    'mmd_conferencia_resolver_excecao',
    'dispatch-resolve-extra-1',
    jsonb_build_object(
      'decision_id', v_extra_decision_id,
      'action', 'ADICIONAR',
      'expected_version', v_version
    )
  );

  SELECT conference.version
    INTO v_version
  FROM public.conferencias AS conference
  WHERE conference.id = v_conference_id;
  SELECT array_agg(decision.id ORDER BY decision.id)
    INTO v_decision_ids
  FROM public.conferencia_decisoes AS decision
  WHERE decision.conferencia_id = v_conference_id;

  PERFORM pg_temp.run_mcp_operation(
    'mmd_conferencia_confirmar_saida',
    'dispatch-confirm-output-1',
    jsonb_build_object(
      'conferencia_id', v_conference_id,
      'decision_ids', to_jsonb(v_decision_ids),
      'expected_version', v_version
    )
  );

  PERFORM pg_temp.run_mcp_operation(
    'mmd_conferencia_salvar_decisao',
    'dispatch-save-return-1',
    jsonb_build_object(
      'evento_id', 'ffffffff-ffff-4fff-8fff-ffffffffffe5',
      'direcao', 'RETORNO',
      'unidade_id', 'ffffffff-ffff-4fff-8fff-ffffffffffe2',
      'resultado', 'OK',
      'metodo', 'QRCODE',
      'source_event_id', 'dispatch:return:1',
      'captured_at', '2026-08-12T20:00:00Z'
    )
  );

  SELECT conference.id, conference.version
    INTO v_return_conference_id, v_version
  FROM public.conferencias AS conference
  WHERE conference.projeto_id = 'ffffffff-ffff-4fff-8fff-ffffffffffe5'
    AND conference.direcao = 'RETORNO';
  SELECT array_agg(decision.id ORDER BY decision.id)
    INTO v_decision_ids
  FROM public.conferencia_decisoes AS decision
  WHERE decision.conferencia_id = v_return_conference_id
    AND decision.applied_confirmation_id IS NULL;

  PERFORM pg_temp.run_mcp_operation(
    'mmd_conferencia_confirmar_retorno',
    'dispatch-confirm-return-1',
    jsonb_build_object(
      'conferencia_id', v_return_conference_id,
      'decision_ids', to_jsonb(v_decision_ids),
      'expected_version', v_version
    )
  );

  SELECT conference.version
    INTO v_version
  FROM public.conferencias AS conference
  WHERE conference.id = v_return_conference_id;
  PERFORM pg_temp.run_mcp_operation(
    'mmd_conferencia_finalizar_retorno',
    'dispatch-finalize-return-1',
    jsonb_build_object(
      'evento_id', 'ffffffff-ffff-4fff-8fff-ffffffffffe5',
      'expected_version', v_version
    )
  );

  SELECT pending.id
    INTO v_pending_id
  FROM public.retorno_pendencias AS pending
  WHERE pending.projeto_id = 'ffffffff-ffff-4fff-8fff-ffffffffffe5'
  ORDER BY pending.id
  LIMIT 1;
  PERFORM pg_temp.run_mcp_operation(
    'mmd_pendencia_resolver_retorno',
    'dispatch-resolve-pending-1',
    jsonb_build_object(
      'pendencia_id', v_pending_id,
      'acao', 'ENCONTRADA',
      'observacao', 'Unidade encontrada após o fechamento',
      'localizacao_confirmada', 'Case B do retorno'
    )
  );
END;
$$;

SELECT is(
  (
    SELECT count(DISTINCT operation.tool)::integer
    FROM public.mcp_operation_log AS operation
    WHERE operation.client_id = 'mcp-mutation-test'
      AND operation.client_request_id LIKE 'dispatch-%'
      AND operation.outcome = 'SUCCEEDED'
  ),
  6,
  'Dispatcher percorre com sucesso as seis branches além de RFID'
);

SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true);
SELECT public.issue_mcp_operation_capability(
  encode(extensions.digest('mutation-timeout-token-1', 'sha256'), 'hex'),
  'mcp-mutation-test',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5',
  'mmd_unidade_vincular_rfid',
  'mutation-timeout-request',
  jsonb_build_object(
    'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff2',
    'epc', 'E2000017221101441890BEEF'
  ),
  30
);
SET LOCAL ROLE postgres;
UPDATE app_private.mcp_operation_capabilities AS capability
SET
  created_at = clock_timestamp() - interval '2 minutes',
  expires_at = clock_timestamp() - interval '1 minute'
FROM public.mcp_operation_log AS operation
WHERE operation.id = capability.operation_id
  AND operation.client_request_id = 'mutation-timeout-request';
SET LOCAL ROLE mmd_mcp_executor;
DO $$
BEGIN
  BEGIN
    PERFORM public.execute_mcp_operation(
      'mutation-timeout-token-1',
      jsonb_build_object(
        'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff2',
        'epc', 'E2000017221101441890BEEF'
      )
    );
    RAISE EXCEPTION 'Capability expirada produziu ACK';
  EXCEPTION WHEN SQLSTATE '28000' THEN
    IF SQLERRM <> 'MCP_CAPABILITY_INVALID' THEN
      RAISE;
    END IF;
  END;
END;
$$;
SET LOCAL ROLE postgres;
SELECT pass('Capability expirada antes do commit não produz ACK');

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.mcp_operation_log AS operation
    WHERE operation.client_request_id = 'mutation-timeout-request'
      AND (
        operation.outcome <> 'IN_PROGRESS'
        OR operation.result IS NOT NULL
        OR operation.receipt_id IS NOT NULL
      )
  ) THEN
    RAISE EXCEPTION 'Timeout antes do commit gravou ACK ou estado final';
  END IF;
END;
$$;

SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true);
SELECT public.issue_mcp_operation_capability(
  encode(extensions.digest('mutation-timeout-token-2', 'sha256'), 'hex'),
  'mcp-mutation-test',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5',
  'mmd_unidade_vincular_rfid',
  'mutation-timeout-request',
  jsonb_build_object(
    'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff2',
    'epc', 'E2000017221101441890BEEF'
  ),
  30
);
SET LOCAL ROLE postgres;
SET LOCAL ROLE mmd_mcp_executor;

DO $$
DECLARE
  v_recovered jsonb;
BEGIN
  v_recovered := public.execute_mcp_operation(
    'mutation-timeout-token-2',
    jsonb_build_object(
      'unidade_id', 'ffffffff-ffff-4fff-8fff-fffffffffff2',
      'epc', 'E2000017221101441890BEEF'
    )
  );
  IF v_recovered->>'ok' <> 'true' THEN
    RAISE EXCEPTION 'Retry após timeout não recuperou a mesma operação';
  END IF;
END;
$$;
SET LOCAL ROLE postgres;

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
