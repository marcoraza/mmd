-- Envelope MCP para mutações canônicas. O executor só recebe uma capability
-- opaca, curta e presa à operação; ator, cliente, payload e idempotência são
-- resolvidos no banco antes de chamar as RPCs Event Pro já existentes.

ALTER TABLE public.mcp_operation_log
  DROP CONSTRAINT mcp_operation_log_outcome_check,
  DROP CONSTRAINT mcp_operation_log_completion_order,
  ADD CONSTRAINT mcp_operation_log_outcome_check CHECK (
    outcome IN ('IN_PROGRESS', 'SUCCEEDED', 'DENIED', 'FAILED')
  ),
  ALTER COLUMN completed_at DROP NOT NULL,
  ADD CONSTRAINT mcp_operation_log_completion_order CHECK (
    (outcome = 'IN_PROGRESS' AND completed_at IS NULL)
    OR (
      outcome <> 'IN_PROGRESS'
      AND completed_at IS NOT NULL
      AND completed_at >= created_at
    )
  ),
  ADD COLUMN result jsonb,
  ADD COLUMN error_code text CHECK (
    error_code IS NULL OR error_code ~ '^[A-Z0-9_]{4,64}$'
  );

CREATE TABLE app_private.mcp_operation_capabilities (
  token_hash text PRIMARY KEY CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  operation_id uuid NOT NULL REFERENCES public.mcp_operation_log(id) ON DELETE CASCADE,
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (expires_at > created_at),
  CHECK (used_at IS NULL OR used_at >= created_at)
);

CREATE INDEX mcp_operation_capabilities_expiry_idx
  ON app_private.mcp_operation_capabilities(expires_at);

REVOKE ALL ON TABLE app_private.mcp_operation_capabilities
  FROM PUBLIC, anon, authenticated, service_role, mmd_mcp_executor;

CREATE OR REPLACE FUNCTION public.issue_mcp_operation_capability(
  p_token_hash text,
  p_client_id text,
  p_actor_id uuid,
  p_tool text,
  p_client_request_id text,
  p_arguments jsonb,
  p_ttl_seconds integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_payload_hash text;
  v_role public.user_role_enum;
  v_operation public.mcp_operation_log%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'MCP_OPERATION_ISSUER_DENIED' USING ERRCODE = '42501';
  END IF;
  IF p_token_hash !~ '^[0-9a-f]{64}$'
     OR p_client_request_id !~ '^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$'
     OR p_tool NOT IN (
       'mmd_conferencia_salvar_decisao',
       'mmd_conferencia_resolver_excecao',
       'mmd_conferencia_confirmar_saida',
       'mmd_conferencia_confirmar_retorno',
       'mmd_conferencia_finalizar_retorno',
       'mmd_pendencia_resolver_retorno',
       'mmd_unidade_vincular_rfid'
     )
     OR jsonb_typeof(p_arguments) <> 'object'
     OR p_ttl_seconds < 1
     OR p_ttl_seconds > 60 THEN
    RAISE EXCEPTION 'MCP_OPERATION_INVALID' USING ERRCODE = '22023';
  END IF;

  SELECT profile.role
    INTO v_role
  FROM public.mcp_clients AS client
  JOIN public.profiles AS profile ON profile.id = p_actor_id
  WHERE client.client_id = p_client_id
    AND client.active
    AND client.revoked_at IS NULL
    AND client.scopes @> ARRAY['mcp:operate']::text[];

  IF v_role NOT IN ('editor', 'admin') THEN
    RAISE EXCEPTION 'MCP_OPERATION_PERMISSION_DENIED' USING ERRCODE = '42501';
  END IF;
  IF p_tool = 'mmd_pendencia_resolver_retorno'
     AND upper(coalesce(p_arguments->>'acao', '')) IN ('BAIXA', 'COBRANCA')
     AND v_role <> 'admin' THEN
    RAISE EXCEPTION 'MCP_OPERATION_PERMISSION_DENIED' USING ERRCODE = '42501';
  END IF;

  v_payload_hash := encode(
    extensions.digest(convert_to(p_arguments::text, 'UTF8'), 'sha256'),
    'hex'
  );

  INSERT INTO public.mcp_operation_log (
    client_id,
    actor_id,
    tool,
    client_request_id,
    payload_hash,
    intent,
    outcome,
    completed_at
  ) VALUES (
    p_client_id,
    p_actor_id,
    p_tool,
    p_client_request_id,
    v_payload_hash,
    'MUTATION',
    'IN_PROGRESS',
    NULL
  )
  ON CONFLICT (client_id, actor_id, tool, client_request_id) DO NOTHING;

  SELECT operation.*
    INTO v_operation
  FROM public.mcp_operation_log AS operation
  WHERE operation.client_id = p_client_id
    AND operation.actor_id = p_actor_id
    AND operation.tool = p_tool
    AND operation.client_request_id = p_client_request_id
  FOR UPDATE;

  IF v_operation.payload_hash <> v_payload_hash OR v_operation.intent <> 'MUTATION' THEN
    RAISE EXCEPTION 'MCP_REQUEST_PAYLOAD_CONFLICT' USING ERRCODE = 'P0001';
  END IF;
  IF v_operation.outcome = 'SUCCEEDED' AND v_operation.result IS NOT NULL THEN
    RETURN jsonb_build_object(
      'completed', true,
      'operation_id', v_operation.id,
      'result', v_operation.result
    );
  END IF;

  UPDATE public.mcp_operation_log
  SET outcome = 'IN_PROGRESS', error_code = NULL, completed_at = NULL
  WHERE id = v_operation.id;

  DELETE FROM app_private.mcp_operation_capabilities
  WHERE operation_id = v_operation.id;
  DELETE FROM app_private.mcp_operation_capabilities
  WHERE expires_at < clock_timestamp() - interval '1 hour';

  INSERT INTO app_private.mcp_operation_capabilities (
    token_hash,
    operation_id,
    payload_hash,
    expires_at
  ) VALUES (
    p_token_hash,
    v_operation.id,
    v_payload_hash,
    clock_timestamp() + make_interval(secs => p_ttl_seconds)
  );

  RETURN jsonb_build_object(
    'completed', false,
    'operation_id', v_operation.id,
    'payload_hash', v_payload_hash
  );
END;
$$;

CREATE OR REPLACE FUNCTION app_private.consume_mcp_operation_capability(
  p_token_hash text,
  p_payload_hash text
)
RETURNS TABLE(
  operation_id uuid,
  actor_id uuid,
  client_id text,
  tool text,
  idempotency_key text
)
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
  UPDATE app_private.mcp_operation_capabilities AS capability
  SET used_at = clock_timestamp()
  FROM public.mcp_operation_log AS operation,
       public.mcp_clients AS client,
       public.profiles AS profile
  WHERE capability.token_hash = p_token_hash
    AND capability.payload_hash = p_payload_hash
    AND capability.used_at IS NULL
    AND capability.expires_at > clock_timestamp()
    AND operation.id = capability.operation_id
    AND operation.payload_hash = p_payload_hash
    AND operation.intent = 'MUTATION'
    AND operation.outcome = 'IN_PROGRESS'
    AND client.client_id = operation.client_id
    AND client.active
    AND client.revoked_at IS NULL
    AND client.scopes @> ARRAY['mcp:operate']::text[]
    AND profile.id = operation.actor_id
    AND profile.role IN ('editor', 'admin')
  RETURNING
    operation.id,
    operation.actor_id,
    operation.client_id,
    operation.tool,
    operation.id::text;
$$;

REVOKE ALL ON FUNCTION app_private.consume_mcp_operation_capability(text, text)
  FROM PUBLIC, anon, authenticated, service_role, mmd_mcp_executor;

CREATE OR REPLACE FUNCTION public.execute_mcp_operation(
  p_capability_token text,
  p_arguments jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_payload_hash text := encode(
    extensions.digest(convert_to(p_arguments::text, 'UTF8'), 'sha256'),
    'hex'
  );
  v_operation_id uuid;
  v_actor_id uuid;
  v_client_id text;
  v_tool text;
  v_idempotency_key text;
  v_result jsonb;
  v_receipt_id uuid;
BEGIN
  SELECT consumed.operation_id,
         consumed.actor_id,
         consumed.client_id,
         consumed.tool,
         consumed.idempotency_key
    INTO v_operation_id, v_actor_id, v_client_id, v_tool, v_idempotency_key
  FROM app_private.consume_mcp_operation_capability(
    encode(extensions.digest(p_capability_token, 'sha256'), 'hex'),
    v_payload_hash
  ) AS consumed;

  IF v_operation_id IS NULL THEN
    RAISE EXCEPTION 'MCP_CAPABILITY_INVALID' USING ERRCODE = '28000';
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', v_actor_id,
      'role', 'authenticated',
      'client_id', v_client_id
    )::text,
    true
  );

  BEGIN
    CASE v_tool
      WHEN 'mmd_conferencia_salvar_decisao' THEN
        IF p_arguments->>'direcao' = 'RETORNO' THEN
          v_result := public.salvar_decisao_conferencia_retorno(
            (p_arguments->>'evento_id')::uuid,
            (p_arguments->>'unidade_id')::uuid,
            (p_arguments->>'resultado')::public.conferencia_resultado_enum,
            (p_arguments->>'metodo')::public.metodo_scan_enum,
            p_arguments->>'source_event_id',
            (p_arguments->>'captured_at')::timestamptz,
            nullif(p_arguments->>'desgaste', '')::integer,
            p_arguments->>'manual_reason',
            p_arguments->>'observation',
            v_idempotency_key
          );
        ELSE
          v_result := public.salvar_decisao_conferencia(
            (p_arguments->>'evento_id')::uuid,
            (p_arguments->>'direcao')::public.conferencia_direcao_enum,
            (p_arguments->>'unidade_id')::uuid,
            (p_arguments->>'resultado')::public.conferencia_resultado_enum,
            (p_arguments->>'metodo')::public.metodo_scan_enum,
            p_arguments->>'source_event_id',
            (p_arguments->>'captured_at')::timestamptz,
            p_arguments->>'manual_reason',
            p_arguments->>'observation',
            v_idempotency_key
          );
        END IF;
      WHEN 'mmd_conferencia_resolver_excecao' THEN
        v_result := public.resolver_excecao_conferencia_saida(
          (p_arguments->>'decision_id')::uuid,
          (p_arguments->>'action')::public.conferencia_resolution_enum,
          (p_arguments->>'expected_version')::bigint,
          v_idempotency_key
        );
      WHEN 'mmd_conferencia_confirmar_saida' THEN
        v_result := public.confirmar_conferencia_saida(
          (p_arguments->>'conferencia_id')::uuid,
          ARRAY(SELECT jsonb_array_elements_text(p_arguments->'decision_ids')::uuid),
          (p_arguments->>'expected_version')::bigint,
          v_idempotency_key,
          p_arguments->>'incomplete_reason'
        );
      WHEN 'mmd_conferencia_confirmar_retorno' THEN
        v_result := public.confirmar_conferencia_retorno(
          (p_arguments->>'conferencia_id')::uuid,
          ARRAY(SELECT jsonb_array_elements_text(p_arguments->'decision_ids')::uuid),
          (p_arguments->>'expected_version')::bigint,
          v_idempotency_key
        );
      WHEN 'mmd_conferencia_finalizar_retorno' THEN
        v_result := public.finalizar_conferencia_retorno(
          (p_arguments->>'evento_id')::uuid,
          (p_arguments->>'expected_version')::bigint,
          v_idempotency_key
        );
      WHEN 'mmd_pendencia_resolver_retorno' THEN
        v_result := public.resolver_pendencia_retorno(
          (p_arguments->>'pendencia_id')::uuid,
          p_arguments->>'acao',
          p_arguments->>'observacao',
          p_arguments->>'localizacao_confirmada',
          v_idempotency_key
        );
      WHEN 'mmd_unidade_vincular_rfid' THEN
        v_result := public.aplicar_vinculo_rfid(
          (p_arguments->>'unidade_id')::uuid,
          p_arguments->>'epc',
          v_idempotency_key
        );
      ELSE
        RAISE EXCEPTION 'MCP_OPERATION_NOT_ALLOWED' USING ERRCODE = '42501';
    END CASE;

    IF v_result IS NULL THEN
      RAISE EXCEPTION 'MCP_OPERATION_EMPTY_RESULT' USING ERRCODE = '55000';
    END IF;
    IF v_result ? 'confirmation_id' THEN
      v_receipt_id := (v_result->>'confirmation_id')::uuid;
    END IF;

    UPDATE public.mcp_operation_log
    SET
      outcome = 'SUCCEEDED',
      result = v_result,
      receipt_id = v_receipt_id,
      error_code = NULL,
      completed_at = clock_timestamp()
    WHERE id = v_operation_id;

    RETURN jsonb_build_object(
      'ok', true,
      'operation_id', v_operation_id,
      'result', v_result
    );
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.mcp_operation_log
    SET
      outcome = CASE WHEN SQLSTATE IN ('28000', '42501') THEN 'DENIED' ELSE 'FAILED' END,
      result = NULL,
      error_code = SQLSTATE,
      completed_at = clock_timestamp()
    WHERE id = v_operation_id;

    RETURN jsonb_build_object(
      'ok', false,
      'operation_id', v_operation_id,
      'error_code', SQLSTATE
    );
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.issue_mcp_operation_capability(
  text, text, uuid, text, text, jsonb, integer
) FROM PUBLIC, anon, authenticated, mmd_mcp_executor;
GRANT EXECUTE ON FUNCTION public.issue_mcp_operation_capability(
  text, text, uuid, text, text, jsonb, integer
) TO service_role;

REVOKE ALL ON FUNCTION public.execute_mcp_operation(text, jsonb)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.execute_mcp_operation(text, jsonb)
  TO mmd_mcp_executor;

COMMENT ON FUNCTION public.execute_mcp_operation(text, jsonb) IS
  'Despacha somente mutações Event Pro allowlisted após consumir capability MCP vinculada a cliente, ator, ferramenta, request e payload.';
