-- Retorno físico confirma somente Unidades que tiveram saída física aplicada.
-- A mesma chave idempotente devolve o Recibo persistido; uma intenção diferente
-- com a chave reaproveitada falha sem alterar estoque, histórico ou pendência.

CREATE TABLE public.retorno_pendencia_resolucoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pendencia_id uuid NOT NULL REFERENCES public.retorno_pendencias(id) ON DELETE RESTRICT,
  idempotency_key text NOT NULL CHECK (length(btrim(idempotency_key)) >= 8),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  acao text NOT NULL CHECK (acao IN ('ENCONTRADA', 'MANUTENCAO', 'BAIXA', 'COBRANCA')),
  observacao text,
  resolved_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT retorno_pendencia_resolucoes_idempotency_unique
    UNIQUE (pendencia_id, idempotency_key)
);

ALTER TABLE public.retorno_pendencia_resolucoes ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.retorno_pendencia_resolucoes
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT ON TABLE public.retorno_pendencia_resolucoes TO authenticated;

CREATE POLICY retorno_pendencia_resolucoes_read ON public.retorno_pendencia_resolucoes
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE OR REPLACE FUNCTION app_private.retorno_pendencia_recibo(
  p_resolution_id uuid
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'resolution_id', rpr.id,
    'pending_id', rp.id,
    'project_id', rp.projeto_id,
    'serial_id', rp.serial_number_id,
    'code', sn.codigo_interno,
    'action', rpr.acao,
    'observation', rpr.observacao,
    'actor_id', rpr.actor_id,
    'resolved_at', rpr.resolved_at,
    'status_novo', sn.status
  )
  FROM public.retorno_pendencia_resolucoes rpr
  JOIN public.retorno_pendencias rp ON rp.id = rpr.pendencia_id
  JOIN public.serial_numbers sn ON sn.id = rp.serial_number_id
  WHERE rpr.id = p_resolution_id;
$$;

REVOKE ALL ON FUNCTION app_private.retorno_pendencia_recibo(uuid)
FROM PUBLIC, anon, authenticated, service_role;

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
  v_conferencia public.conferencias%ROWTYPE;
  v_projeto_status public.status_projeto_enum;
  v_existing public.conferencia_confirmacoes%ROWTYPE;
  v_confirmation public.conferencia_confirmacoes%ROWTYPE;
  v_decision_ids uuid[];
  v_serial_ids uuid[];
  v_payload_hash text;
  v_decision_count integer;
  v_expected_count integer;
  v_bad_status_count integer;
  v_problem_without_observation_count integer;
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

  IF coalesce(cardinality(p_decision_ids), 0) = 0 THEN
    RAISE EXCEPTION 'Confirmação exige ao menos uma decisão'
      USING ERRCODE = '22023';
  END IF;

  SELECT array_agg(decision_id ORDER BY decision_id)
  INTO v_decision_ids
  FROM unnest(p_decision_ids) AS decision_id;

  IF cardinality(v_decision_ids) <> (
    SELECT count(DISTINCT decision_id)
    FROM unnest(v_decision_ids) AS decision_id
  ) THEN
    RAISE EXCEPTION 'Decisão duplicada no payload'
      USING ERRCODE = '22023';
  END IF;

  SELECT c.*
  INTO v_conferencia
  FROM public.conferencias c
  WHERE c.id = p_conferencia_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conferência % não encontrada', p_conferencia_id
      USING ERRCODE = 'P0002';
  END IF;

  IF v_conferencia.direcao <> 'RETORNO' THEN
    RAISE EXCEPTION 'RPC de retorno exige Conferência RETORNO'
      USING ERRCODE = '22023';
  END IF;

  SELECT p.status
  INTO v_projeto_status
  FROM public.projetos p
  WHERE p.id = v_conferencia.projeto_id
  FOR UPDATE;

  SELECT c.*
  INTO v_conferencia
  FROM public.conferencias c
  WHERE c.id = p_conferencia_id
  FOR UPDATE;

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
    IF v_existing.payload_hash <> v_payload_hash THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN app_private.conferencia_recibo(v_existing.id);
  END IF;

  IF v_conferencia.version <> p_expected_version THEN
    RAISE EXCEPTION 'CONFERENCE_VERSION_CONFLICT'
      USING ERRCODE = '40001';
  END IF;

  IF v_projeto_status <> 'EM_CAMPO' THEN
    RAISE EXCEPTION 'Evento em status % não aceita retorno físico', v_projeto_status
      USING ERRCODE = '55000';
  END IF;

  PERFORM 1
  FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids)
  ORDER BY cd.id
  FOR UPDATE;

  SELECT count(*)::integer
  INTO v_decision_count
  FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids)
    AND cd.conferencia_id = p_conferencia_id
    AND cd.resultado IN ('OK', 'PROBLEMA', 'NAO_VOLTOU')
    AND cd.applied_confirmation_id IS NULL;

  IF v_decision_count <> cardinality(v_decision_ids) THEN
    RAISE EXCEPTION 'Decisão ausente, aplicada ou incompatível com retorno'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*)::integer
  INTO v_expected_count
  FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids)
    AND EXISTS (
      SELECT 1
      FROM public.conferencia_decisoes saida
      JOIN public.conferencias conferencia_saida
        ON conferencia_saida.id = saida.conferencia_id
      WHERE conferencia_saida.projeto_id = v_conferencia.projeto_id
        AND conferencia_saida.direcao = 'SAIDA'
        AND saida.serial_number_id = cd.serial_number_id
        AND saida.applied_confirmation_id IS NOT NULL
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.conferencia_decisoes retorno
      JOIN public.conferencias conferencia_retorno
        ON conferencia_retorno.id = retorno.conferencia_id
      WHERE conferencia_retorno.projeto_id = v_conferencia.projeto_id
        AND conferencia_retorno.direcao = 'RETORNO'
        AND retorno.serial_number_id = cd.serial_number_id
        AND retorno.applied_confirmation_id IS NOT NULL
    );

  IF v_expected_count <> cardinality(v_decision_ids) THEN
    RAISE EXCEPTION 'Unidade não é esperada neste retorno'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*)::integer
  INTO v_problem_without_observation_count
  FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids)
    AND cd.resultado = 'PROBLEMA'
    AND length(btrim(coalesce(cd.observation, ''))) < 3;

  IF v_problem_without_observation_count > 0 THEN
    RAISE EXCEPTION 'Unidade com problema exige condição e observação'
      USING ERRCODE = '22023';
  END IF;

  SELECT array_agg(cd.serial_number_id ORDER BY cd.serial_number_id)
  INTO v_serial_ids
  FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids);

  PERFORM 1
  FROM public.serial_numbers sn
  WHERE sn.id = ANY(v_serial_ids)
  ORDER BY sn.id
  FOR UPDATE;

  SELECT count(*)::integer
  INTO v_bad_status_count
  FROM public.serial_numbers sn
  WHERE sn.id = ANY(v_serial_ids)
    AND sn.status <> 'EM_CAMPO';

  IF v_bad_status_count > 0 THEN
    RAISE EXCEPTION 'Unidade não está EM_CAMPO, confirmação abortada'
      USING ERRCODE = '55000';
  END IF;

  INSERT INTO public.conferencia_confirmacoes (
    conferencia_id,
    idempotency_key,
    payload_hash,
    actor_id
  ) VALUES (
    p_conferencia_id,
    btrim(p_idempotency_key),
    v_payload_hash,
    v_actor_id
  )
  RETURNING * INTO v_confirmation;

  INSERT INTO public.movimentacoes (
    serial_number_id,
    projeto_id,
    tipo,
    status_anterior,
    status_novo,
    registrado_por,
    metodo_scan,
    notas,
    conferencia_confirmacao_id,
    conferencia_decisao_id
  )
  SELECT
    cd.serial_number_id,
    v_conferencia.projeto_id,
    CASE
      WHEN cd.resultado = 'PROBLEMA' THEN 'MANUTENCAO'::public.tipo_movimentacao_enum
      ELSE 'RETORNO'::public.tipo_movimentacao_enum
    END,
    'EM_CAMPO',
    CASE cd.resultado
      WHEN 'OK' THEN 'DISPONIVEL'
      WHEN 'PROBLEMA' THEN 'MANUTENCAO'
      ELSE 'RETORNANDO'
    END,
    v_actor_id::text,
    cd.metodo,
    cd.observation,
    v_confirmation.id,
    cd.id
  FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids);

  UPDATE public.serial_numbers sn
  SET status = CASE cd.resultado
        WHEN 'OK' THEN 'DISPONIVEL'::public.status_serial_enum
        WHEN 'PROBLEMA' THEN 'MANUTENCAO'::public.status_serial_enum
        ELSE 'RETORNANDO'::public.status_serial_enum
      END
  FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids)
    AND sn.id = cd.serial_number_id;

  INSERT INTO public.retorno_pendencias (
    projeto_id,
    serial_number_id,
    status,
    observacao,
    registrado_por
  )
  SELECT
    v_conferencia.projeto_id,
    cd.serial_number_id,
    'ABERTA',
    cd.observation,
    v_actor_id::text
  FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids)
    AND cd.resultado = 'NAO_VOLTOU';

  UPDATE public.conferencia_decisoes cd
  SET applied_confirmation_id = v_confirmation.id,
      updated_at = now()
  WHERE cd.id = ANY(v_decision_ids);

  UPDATE public.conferencias c
  SET version = c.version + 1,
      updated_at = now()
  WHERE c.id = p_conferencia_id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.conferencia_decisoes saida
    JOIN public.conferencias conferencia_saida
      ON conferencia_saida.id = saida.conferencia_id
    WHERE conferencia_saida.projeto_id = v_conferencia.projeto_id
      AND conferencia_saida.direcao = 'SAIDA'
      AND saida.applied_confirmation_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.conferencia_decisoes retorno
        JOIN public.conferencias conferencia_retorno
          ON conferencia_retorno.id = retorno.conferencia_id
        WHERE conferencia_retorno.projeto_id = v_conferencia.projeto_id
          AND conferencia_retorno.direcao = 'RETORNO'
          AND retorno.serial_number_id = saida.serial_number_id
          AND retorno.applied_confirmation_id IS NOT NULL
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.retorno_pendencias rp
    WHERE rp.projeto_id = v_conferencia.projeto_id
      AND rp.status = 'ABERTA'
  ) THEN
    UPDATE public.projetos p
    SET status = 'FINALIZADO'
    WHERE p.id = v_conferencia.projeto_id
      AND p.status = 'EM_CAMPO';
  END IF;

  RETURN app_private.conferencia_recibo(v_confirmation.id);
END;
$$;

REVOKE ALL ON FUNCTION public.confirmar_conferencia_retorno(uuid, uuid[], bigint, text)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.confirmar_conferencia_retorno(uuid, uuid[], bigint, text)
TO authenticated;

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
  v_role text;
  v_projeto_id uuid;
  v_projeto_status public.status_projeto_enum;
  v_pendencia public.retorno_pendencias%ROWTYPE;
  v_existing public.retorno_pendencia_resolucoes%ROWTYPE;
  v_resolution public.retorno_pendencia_resolucoes%ROWTYPE;
  v_acao text := upper(btrim(coalesce(p_acao, '')));
  v_observacao text := nullif(btrim(coalesce(p_observacao, '')), '');
  v_payload_hash text;
  v_status_anterior public.status_serial_enum;
  v_status_novo public.status_serial_enum;
  v_tipo public.tipo_movimentacao_enum;
  v_notas text;
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

  IF length(btrim(coalesce(p_idempotency_key, ''))) < 8 THEN
    RAISE EXCEPTION 'Chave idempotente inválida'
      USING ERRCODE = '22023';
  END IF;

  IF v_acao NOT IN ('ENCONTRADA', 'MANUTENCAO', 'BAIXA', 'COBRANCA') THEN
    RAISE EXCEPTION 'Resolução de pendência inválida'
      USING ERRCODE = '22023';
  END IF;

  IF v_acao IN ('MANUTENCAO', 'COBRANCA')
     AND length(coalesce(v_observacao, '')) < 3 THEN
    RAISE EXCEPTION 'Manutenção e cobrança exigem observação'
      USING ERRCODE = '22023';
  END IF;

  IF v_acao IN ('BAIXA', 'COBRANCA') AND v_role <> 'admin' THEN
    RAISE EXCEPTION 'Baixa e cobrança exigem usuário admin'
      USING ERRCODE = '42501';
  END IF;

  SELECT rp.projeto_id
  INTO v_projeto_id
  FROM public.retorno_pendencias rp
  WHERE rp.id = p_pendencia_id;

  IF v_projeto_id IS NULL THEN
    RAISE EXCEPTION 'Pendência % não encontrada', p_pendencia_id
      USING ERRCODE = 'P0002';
  END IF;

  SELECT p.status
  INTO v_projeto_status
  FROM public.projetos p
  WHERE p.id = v_projeto_id
  FOR UPDATE;

  SELECT rp.*
  INTO v_pendencia
  FROM public.retorno_pendencias rp
  WHERE rp.id = p_pendencia_id
  FOR UPDATE;

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
    IF v_existing.payload_hash <> v_payload_hash THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN app_private.retorno_pendencia_recibo(v_existing.id);
  END IF;

  IF v_projeto_status <> 'EM_CAMPO' THEN
    RAISE EXCEPTION 'Evento em status % não aceita resolução de retorno', v_projeto_status
      USING ERRCODE = '55000';
  END IF;

  IF v_pendencia.status <> 'ABERTA' THEN
    RAISE EXCEPTION 'PENDENCY_ALREADY_RESOLVED'
      USING ERRCODE = '55000';
  END IF;

  SELECT sn.status
  INTO v_status_anterior
  FROM public.serial_numbers sn
  WHERE sn.id = v_pendencia.serial_number_id
  FOR UPDATE;

  IF v_status_anterior <> 'RETORNANDO' THEN
    RAISE EXCEPTION 'Unidade não está pendente de retorno'
      USING ERRCODE = '55000';
  END IF;

  IF v_acao = 'ENCONTRADA' THEN
    v_status_novo := 'DISPONIVEL';
    v_tipo := 'RETORNO';
    v_notas := 'Pendência resolvida: unidade encontrada. ' || coalesce(v_observacao, '');
  ELSIF v_acao = 'MANUTENCAO' THEN
    v_status_novo := 'MANUTENCAO';
    v_tipo := 'MANUTENCAO';
    v_notas := 'Pendência resolvida para manutenção: ' || v_observacao;
  ELSIF v_acao = 'BAIXA' THEN
    v_status_novo := 'BAIXA';
    v_tipo := 'DANO';
    v_notas := 'Pendência resolvida com baixa. ' || coalesce(v_observacao, '');
  ELSE
    v_status_novo := v_status_anterior;
    v_tipo := 'DANO';
    v_notas := 'Pendência resolvida com nota de cobrança: ' || v_observacao;
  END IF;

  INSERT INTO public.retorno_pendencia_resolucoes (
    pendencia_id,
    idempotency_key,
    payload_hash,
    actor_id,
    acao,
    observacao
  ) VALUES (
    p_pendencia_id,
    btrim(p_idempotency_key),
    v_payload_hash,
    v_actor_id,
    v_acao,
    v_observacao
  )
  RETURNING * INTO v_resolution;

  IF v_acao <> 'COBRANCA' THEN
    UPDATE public.serial_numbers
    SET status = v_status_novo
    WHERE id = v_pendencia.serial_number_id;
  END IF;

  INSERT INTO public.movimentacoes (
    serial_number_id,
    projeto_id,
    tipo,
    status_anterior,
    status_novo,
    registrado_por,
    metodo_scan,
    notas
  ) VALUES (
    v_pendencia.serial_number_id,
    v_pendencia.projeto_id,
    v_tipo,
    v_status_anterior::text,
    v_status_novo::text,
    v_actor_id::text,
    'MANUAL',
    v_notas
  );

  UPDATE public.retorno_pendencias
  SET status = v_acao,
      resolucao_observacao = v_observacao,
      resolvido_por = v_actor_id::text,
      resolved_at = now()
  WHERE id = v_pendencia.id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.retorno_pendencias rp
    WHERE rp.projeto_id = v_pendencia.projeto_id
      AND rp.status = 'ABERTA'
  ) THEN
    UPDATE public.projetos
    SET status = 'FINALIZADO'
    WHERE id = v_pendencia.projeto_id
      AND status = 'EM_CAMPO';
  END IF;

  RETURN app_private.retorno_pendencia_recibo(v_resolution.id);
END;
$$;

REVOKE ALL ON FUNCTION public.resolver_pendencia_retorno(uuid, text, text, text)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.resolver_pendencia_retorno(uuid, text, text, text)
TO authenticated;

-- O Web legada não pode mais fabricar um retorno por service_role. Mantemos as
-- funções para callers iOS ainda não migrados, mas sem uma concessão executável.
REVOKE ALL ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb)
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.resolver_retorno_pendencia(uuid, text, text, text)
FROM PUBLIC, anon, authenticated, service_role;
