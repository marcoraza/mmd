-- Retry de confirmação pertence ao operador que iniciou a intenção. O lock
-- segue Evento -> Conferência, igual às RPCs internas, para não inverter a
-- ordem e introduzir deadlock com o salvamento de decisões.

ALTER FUNCTION public.confirmar_conferencia_saida(uuid, uuid[], bigint, text, text)
RENAME TO confirmar_conferencia_saida_legacy_actor_scope;

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
  v_projeto_id uuid;
  v_existing public.conferencia_confirmacoes%ROWTYPE;
  v_decision_ids uuid[];
  v_payload_hash text;
  v_incomplete_reason text := nullif(btrim(coalesce(p_incomplete_reason, '')), '');
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória'
      USING ERRCODE = '28000';
  END IF;

  IF app_private.current_user_role() NOT IN ('editor', 'admin') THEN
    RAISE EXCEPTION 'Perfil sem permissão para confirmar Conferência'
      USING ERRCODE = '42501';
  END IF;

  IF length(btrim(coalesce(p_idempotency_key, ''))) < 8 THEN
    RAISE EXCEPTION 'Chave idempotente inválida'
      USING ERRCODE = '22023';
  END IF;

  SELECT c.projeto_id
  INTO v_projeto_id
  FROM public.conferencias c
  WHERE c.id = p_conferencia_id;

  IF v_projeto_id IS NOT NULL THEN
    PERFORM 1
    FROM public.projetos p
    WHERE p.id = v_projeto_id
    FOR UPDATE;

    PERFORM 1
    FROM public.conferencias c
    WHERE c.id = p_conferencia_id
    FOR UPDATE;
  END IF;

  SELECT array_agg(decision_id ORDER BY decision_id)
  INTO v_decision_ids
  FROM unnest(p_decision_ids) AS decision_id;

  v_payload_hash := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object(
          'conference_id', p_conferencia_id,
          'decision_ids', to_jsonb(v_decision_ids),
          'expected_version', p_expected_version,
          'incomplete_reason', v_incomplete_reason
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  SELECT cc.*
  INTO v_existing
  FROM public.conferencia_confirmacoes cc
  WHERE cc.conferencia_id = p_conferencia_id
    AND cc.idempotency_key = btrim(p_idempotency_key);

  IF FOUND THEN
    IF v_existing.actor_id <> v_actor_id
       OR v_existing.payload_hash <> v_payload_hash THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN app_private.conferencia_recibo(v_existing.id);
  END IF;

  RETURN public.confirmar_conferencia_saida_legacy_actor_scope(
    p_conferencia_id,
    p_decision_ids,
    p_expected_version,
    p_idempotency_key,
    p_incomplete_reason
  );
END;
$$;

REVOKE ALL ON FUNCTION public.confirmar_conferencia_saida_legacy_actor_scope(
  uuid, uuid[], bigint, text, text
) FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.confirmar_conferencia_saida(uuid, uuid[], bigint, text, text)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.confirmar_conferencia_saida(uuid, uuid[], bigint, text, text)
TO authenticated;

ALTER FUNCTION public.confirmar_conferencia_retorno(uuid, uuid[], bigint, text)
RENAME TO confirmar_conferencia_retorno_legacy_actor_scope;

CREATE OR REPLACE FUNCTION public.confirmar_conferencia_retorno(
  p_conferencia_id uuid,
  p_decision_ids uuid[],
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
  v_projeto_id uuid;
  v_existing public.conferencia_confirmacoes%ROWTYPE;
  v_decision_ids uuid[];
  v_payload_hash text;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória'
      USING ERRCODE = '28000';
  END IF;

  IF app_private.current_user_role() NOT IN ('editor', 'admin') THEN
    RAISE EXCEPTION 'Perfil sem permissão para confirmar Conferência'
      USING ERRCODE = '42501';
  END IF;

  IF length(btrim(coalesce(p_idempotency_key, ''))) < 8 THEN
    RAISE EXCEPTION 'Chave idempotente inválida'
      USING ERRCODE = '22023';
  END IF;

  SELECT c.projeto_id
  INTO v_projeto_id
  FROM public.conferencias c
  WHERE c.id = p_conferencia_id;

  IF v_projeto_id IS NOT NULL THEN
    PERFORM 1
    FROM public.projetos p
    WHERE p.id = v_projeto_id
    FOR UPDATE;

    PERFORM 1
    FROM public.conferencias c
    WHERE c.id = p_conferencia_id
    FOR UPDATE;
  END IF;

  SELECT array_agg(decision_id ORDER BY decision_id)
  INTO v_decision_ids
  FROM unnest(p_decision_ids) AS decision_id;

  v_payload_hash := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object(
          'conference_id', p_conferencia_id,
          'decision_ids', to_jsonb(v_decision_ids),
          'expected_version', p_expected_version
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  SELECT cc.*
  INTO v_existing
  FROM public.conferencia_confirmacoes cc
  WHERE cc.conferencia_id = p_conferencia_id
    AND cc.idempotency_key = btrim(p_idempotency_key);

  IF FOUND THEN
    IF v_existing.actor_id <> v_actor_id
       OR v_existing.payload_hash <> v_payload_hash THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN app_private.conferencia_recibo(v_existing.id);
  END IF;

  RETURN public.confirmar_conferencia_retorno_legacy_actor_scope(
    p_conferencia_id,
    p_decision_ids,
    p_expected_version,
    p_idempotency_key
  );
END;
$$;

REVOKE ALL ON FUNCTION public.confirmar_conferencia_retorno_legacy_actor_scope(
  uuid, uuid[], bigint, text
) FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.confirmar_conferencia_retorno(uuid, uuid[], bigint, text)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.confirmar_conferencia_retorno(uuid, uuid[], bigint, text)
TO authenticated;

ALTER FUNCTION public.resolver_pendencia_retorno(uuid, text, text, text)
RENAME TO resolver_pendencia_retorno_legacy_actor_scope;

CREATE OR REPLACE FUNCTION public.resolver_pendencia_retorno(
  p_pendencia_id uuid,
  p_acao text,
  p_observacao text,
  p_idempotency_key text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_projeto_id uuid;
  v_existing public.retorno_pendencia_resolucoes%ROWTYPE;
  v_acao text := upper(btrim(coalesce(p_acao, '')));
  v_observacao text := nullif(btrim(coalesce(p_observacao, '')), '');
  v_payload_hash text;
  v_role text;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória'
      USING ERRCODE = '28000';
  END IF;

  v_role := app_private.current_user_role();
  IF v_role NOT IN ('editor', 'admin') THEN
    RAISE EXCEPTION 'Perfil sem permissão para resolver pendência'
      USING ERRCODE = '42501';
  END IF;

  IF v_acao IN ('BAIXA', 'COBRANCA') AND v_role <> 'admin' THEN
    RAISE EXCEPTION 'Baixa e cobrança exigem usuário admin'
      USING ERRCODE = '42501';
  END IF;

  IF length(btrim(coalesce(p_idempotency_key, ''))) < 8 THEN
    RAISE EXCEPTION 'Chave idempotente inválida'
      USING ERRCODE = '22023';
  END IF;

  SELECT rp.projeto_id
  INTO v_projeto_id
  FROM public.retorno_pendencias rp
  WHERE rp.id = p_pendencia_id;

  IF v_projeto_id IS NOT NULL THEN
    PERFORM 1
    FROM public.projetos p
    WHERE p.id = v_projeto_id
    FOR UPDATE;

    PERFORM 1
    FROM public.retorno_pendencias rp
    WHERE rp.id = p_pendencia_id
    FOR UPDATE;
  END IF;

  v_payload_hash := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object(
          'pending_id', p_pendencia_id,
          'action', v_acao,
          'observation', v_observacao
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  SELECT rpr.*
  INTO v_existing
  FROM public.retorno_pendencia_resolucoes rpr
  WHERE rpr.pendencia_id = p_pendencia_id
    AND rpr.idempotency_key = btrim(p_idempotency_key);

  IF FOUND THEN
    IF v_existing.actor_id <> v_actor_id
       OR v_existing.payload_hash <> v_payload_hash THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN app_private.retorno_pendencia_recibo(v_existing.id);
  END IF;

  RETURN public.resolver_pendencia_retorno_legacy_actor_scope(
    p_pendencia_id,
    p_acao,
    p_observacao,
    p_idempotency_key
  );
END;
$$;

REVOKE ALL ON FUNCTION public.resolver_pendencia_retorno_legacy_actor_scope(
  uuid, text, text, text
) FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.resolver_pendencia_retorno(uuid, text, text, text)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.resolver_pendencia_retorno(uuid, text, text, text)
TO authenticated;
