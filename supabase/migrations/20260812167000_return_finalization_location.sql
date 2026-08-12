-- O fechamento de retorno é uma intenção própria. O cliente só informa o
-- Evento e a versão que revisou; o banco deriva as ausências a partir das
-- saídas físicas ainda esperadas e aplica tudo em uma transação.

CREATE TABLE public.retorno_conferencia_finalizacoes (
  id uuid PRIMARY KEY,
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE RESTRICT,
  conferencia_id uuid NOT NULL REFERENCES public.conferencias(id) ON DELETE RESTRICT,
  idempotency_key text NOT NULL CHECK (length(btrim(idempotency_key)) >= 8),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  derived_absence_count integer NOT NULL CHECK (derived_absence_count >= 0),
  receipt jsonb NOT NULL,
  finalized_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT retorno_conferencia_finalizacoes_idempotency_unique
    UNIQUE (projeto_id, idempotency_key)
);

ALTER TABLE public.retorno_conferencia_finalizacoes ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.retorno_conferencia_finalizacoes
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT ON TABLE public.retorno_conferencia_finalizacoes TO authenticated;

CREATE POLICY retorno_conferencia_finalizacoes_read
  ON public.retorno_conferencia_finalizacoes
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

ALTER TABLE public.retorno_pendencias
  ADD COLUMN IF NOT EXISTS localizacao_confirmada text;

ALTER TABLE public.retorno_pendencia_resolucoes
  ADD COLUMN IF NOT EXISTS localizacao_confirmada text;

ALTER TABLE public.retorno_pendencias
  ADD CONSTRAINT retorno_pendencias_encontrada_localizacao_check
  CHECK (
    status <> 'ENCONTRADA'
    OR length(btrim(coalesce(localizacao_confirmada, ''))) >= 3
  ) NOT VALID;

ALTER TABLE public.retorno_pendencia_resolucoes
  ADD CONSTRAINT retorno_pendencia_resolucoes_encontrada_localizacao_check
  CHECK (
    acao <> 'ENCONTRADA'
    OR length(btrim(coalesce(localizacao_confirmada, ''))) >= 3
  ) NOT VALID;

ALTER FUNCTION public.salvar_decisao_conferencia_retorno(
  uuid,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
  integer,
  text,
  text,
  text
) RENAME TO salvar_decisao_conferencia_retorno_legacy_finalization;

CREATE OR REPLACE FUNCTION public.salvar_decisao_conferencia_retorno_legacy_idempotency(
  p_projeto_id uuid,
  p_serial_id uuid,
  p_resultado public.conferencia_resultado_enum,
  p_metodo public.metodo_scan_enum,
  p_source_event_id text,
  p_captured_at timestamptz,
  p_desgaste integer DEFAULT NULL,
  p_manual_reason text DEFAULT NULL,
  p_observation text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_decision jsonb;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória'
      USING ERRCODE = '28000';
  END IF;

  IF app_private.current_user_role() NOT IN ('editor', 'admin') THEN
    RAISE EXCEPTION 'Perfil sem permissão para operar Conferência'
      USING ERRCODE = '42501';
  END IF;

  IF p_resultado IS NULL
     OR p_resultado NOT IN ('OK', 'PROBLEMA', 'NAO_VOLTOU') THEN
    RAISE EXCEPTION 'Conferência de retorno exige OK, PROBLEMA ou NAO_VOLTOU'
      USING ERRCODE = '22023';
  END IF;

  IF p_desgaste IS NOT NULL AND p_desgaste NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'Desgaste de retorno deve estar entre 1 e 5'
      USING ERRCODE = '22023';
  END IF;

  IF p_resultado = 'PROBLEMA'
     AND (
       p_desgaste IS NULL
       OR p_desgaste NOT BETWEEN 1 AND 5
       OR length(btrim(coalesce(p_observation, ''))) < 3
     ) THEN
    RAISE EXCEPTION 'Retorno PROBLEMA exige condição e observação'
      USING ERRCODE = '22023';
  END IF;

  v_decision := public.salvar_decisao_conferencia_legacy_idempotency(
    p_projeto_id,
    'RETORNO',
    p_serial_id,
    p_resultado,
    p_metodo,
    p_source_event_id,
    p_captured_at,
    p_manual_reason,
    p_observation
  );

  UPDATE public.conferencia_decisoes
  SET retorno_desgaste = p_desgaste,
      updated_at = now()
  WHERE id = (v_decision ->> 'decision_id')::uuid;

  RETURN v_decision || jsonb_build_object('desgaste', p_desgaste);
END;
$$;

CREATE OR REPLACE FUNCTION public.salvar_decisao_conferencia_retorno(
  p_projeto_id uuid,
  p_serial_id uuid,
  p_resultado public.conferencia_resultado_enum,
  p_metodo public.metodo_scan_enum,
  p_source_event_id text,
  p_captured_at timestamptz,
  p_desgaste integer DEFAULT NULL,
  p_manual_reason text DEFAULT NULL,
  p_observation text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_resultado = 'NAO_VOLTOU' THEN
    RAISE EXCEPTION 'Ausência é derivada ao finalizar o retorno'
      USING ERRCODE = '22023';
  END IF;

  RETURN public.salvar_decisao_conferencia_retorno_legacy_finalization(
    p_projeto_id,
    p_serial_id,
    p_resultado,
    p_metodo,
    p_source_event_id,
    p_captured_at,
    p_desgaste,
    p_manual_reason,
    p_observation,
    p_idempotency_key
  );
END;
$$;

REVOKE ALL ON FUNCTION public.salvar_decisao_conferencia_retorno_legacy_finalization(
  uuid,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
  integer,
  text,
  text,
  text
) FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.salvar_decisao_conferencia_retorno(
  uuid,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
  integer,
  text,
  text,
  text
) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.salvar_decisao_conferencia_retorno(
  uuid,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
  integer,
  text,
  text,
  text
) TO authenticated;

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
    'confirmed_location', rpr.localizacao_confirmada,
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

CREATE OR REPLACE FUNCTION public.finalizar_conferencia_retorno(
  p_projeto_id uuid,
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
  v_role text;
  v_projeto_status public.status_projeto_enum;
  v_conferencia public.conferencias%ROWTYPE;
  v_existing public.retorno_conferencia_finalizacoes%ROWTYPE;
  v_expected_serial_ids uuid[];
  v_decision_ids uuid[];
  v_expected_count integer;
  v_derived_count integer := 0;
  v_payload_hash text;
  v_key text := btrim(coalesce(p_idempotency_key, ''));
  v_finalization_id uuid := gen_random_uuid();
  v_confirmation_receipt jsonb;
  v_receipt jsonb;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória'
      USING ERRCODE = '28000';
  END IF;

  v_role := app_private.current_user_role();
  IF v_role NOT IN ('editor', 'admin') THEN
    RAISE EXCEPTION 'Perfil sem permissão para finalizar retorno'
      USING ERRCODE = '42501';
  END IF;

  IF length(v_key) < 8 THEN
    RAISE EXCEPTION 'Chave idempotente inválida'
      USING ERRCODE = '22023';
  END IF;

  IF p_expected_version IS NULL OR p_expected_version < 0 THEN
    RAISE EXCEPTION 'Versão da Conferência inválida'
      USING ERRCODE = '22023';
  END IF;

  v_payload_hash := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object(
          'project_id', p_projeto_id,
          'expected_version', p_expected_version
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  PERFORM pg_advisory_xact_lock(
    hashtextextended(
      'return-finalization:' || p_projeto_id::text || ':' || v_key,
      0
    )
  );

  SELECT f.*
  INTO v_existing
  FROM public.retorno_conferencia_finalizacoes f
  WHERE f.projeto_id = p_projeto_id
    AND f.idempotency_key = v_key;

  IF FOUND THEN
    IF v_existing.actor_id <> v_actor_id
       OR v_existing.payload_hash <> v_payload_hash THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_existing.receipt;
  END IF;

  SELECT p.status
  INTO v_projeto_status
  FROM public.projetos p
  WHERE p.id = p_projeto_id
  FOR UPDATE;

  IF v_projeto_status IS NULL THEN
    RAISE EXCEPTION 'Evento % não encontrado', p_projeto_id
      USING ERRCODE = 'P0002';
  END IF;

  IF v_projeto_status <> 'EM_CAMPO' THEN
    RAISE EXCEPTION 'Evento em status % não aceita finalização de retorno', v_projeto_status
      USING ERRCODE = '55000';
  END IF;

  INSERT INTO public.conferencias (projeto_id, direcao)
  VALUES (p_projeto_id, 'RETORNO')
  ON CONFLICT (projeto_id, direcao) DO NOTHING;

  SELECT c.*
  INTO v_conferencia
  FROM public.conferencias c
  WHERE c.projeto_id = p_projeto_id
    AND c.direcao = 'RETORNO'
  FOR UPDATE;

  IF v_conferencia.version <> p_expected_version THEN
    RAISE EXCEPTION 'CONFERENCE_VERSION_CONFLICT'
      USING ERRCODE = '40001';
  END IF;

  SELECT array_agg(expected.serial_id ORDER BY expected.serial_id), count(*)::integer
  INTO v_expected_serial_ids, v_expected_count
  FROM public.conferencia_retorno_esperado(p_projeto_id) expected;

  IF v_expected_count = 0 THEN
    RAISE EXCEPTION 'Nenhuma Unidade ainda é esperada no retorno'
      USING ERRCODE = '55000';
  END IF;

  PERFORM 1
  FROM public.conferencia_decisoes cd
  WHERE cd.conferencia_id = v_conferencia.id
    AND cd.serial_number_id = ANY(v_expected_serial_ids)
  ORDER BY cd.id
  FOR UPDATE;

  INSERT INTO public.conferencia_decisoes (
    conferencia_id,
    serial_number_id,
    resultado,
    metodo,
    source_event_id,
    captured_at,
    actor_id,
    manual_reason,
    observation,
    resolution
  )
  SELECT
    v_conferencia.id,
    expected.serial_id,
    'NAO_VOLTOU'::public.conferencia_resultado_enum,
    'MANUAL'::public.metodo_scan_enum,
    'return-finalization:' || v_finalization_id::text || ':' || expected.serial_id::text,
    now(),
    v_actor_id,
    'Ausência derivada no fechamento',
    'Unidade não retornou até o fechamento do Evento',
    'DESIGNADA'::public.conferencia_resolution_enum
  FROM public.conferencia_retorno_esperado(p_projeto_id) expected
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.conferencia_decisoes cd
    WHERE cd.conferencia_id = v_conferencia.id
      AND cd.serial_number_id = expected.serial_id
      AND cd.applied_confirmation_id IS NULL
  );

  GET DIAGNOSTICS v_derived_count = ROW_COUNT;

  IF v_derived_count > 0 THEN
    UPDATE public.conferencias c
    SET version = c.version + v_derived_count,
        updated_at = now()
    WHERE c.id = v_conferencia.id
    RETURNING c.* INTO v_conferencia;
  END IF;

  SELECT array_agg(cd.id ORDER BY cd.id)
  INTO v_decision_ids
  FROM public.conferencia_decisoes cd
  WHERE cd.conferencia_id = v_conferencia.id
    AND cd.serial_number_id = ANY(v_expected_serial_ids)
    AND cd.applied_confirmation_id IS NULL;

  IF coalesce(cardinality(v_decision_ids), 0) <> v_expected_count THEN
    RAISE EXCEPTION 'Retorno contém decisões incompatíveis com as Unidades esperadas'
      USING ERRCODE = '22023';
  END IF;

  v_confirmation_receipt := public.confirmar_conferencia_retorno(
    v_conferencia.id,
    v_decision_ids,
    v_conferencia.version,
    'return-finalization:' || v_key
  );

  v_receipt := jsonb_build_object(
    'finalization_id', v_finalization_id,
    'project_id', p_projeto_id,
    'conference_id', v_conferencia.id,
    'actor_id', v_actor_id,
    'finalized_at', now(),
    'derived_absence_count', v_derived_count,
    'receipt', v_confirmation_receipt
  );

  INSERT INTO public.retorno_conferencia_finalizacoes (
    id,
    projeto_id,
    conferencia_id,
    idempotency_key,
    payload_hash,
    actor_id,
    derived_absence_count,
    receipt
  ) VALUES (
    v_finalization_id,
    p_projeto_id,
    v_conferencia.id,
    v_key,
    v_payload_hash,
    v_actor_id,
    v_derived_count,
    v_receipt
  );

  RETURN v_receipt;
END;
$$;

REVOKE ALL ON FUNCTION public.finalizar_conferencia_retorno(uuid, bigint, text)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.finalizar_conferencia_retorno(uuid, bigint, text)
TO authenticated;

CREATE OR REPLACE FUNCTION public.resolver_pendencia_retorno(
  p_pendencia_id uuid,
  p_acao text,
  p_observacao text DEFAULT NULL,
  p_localizacao_confirmada text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_role text;
  v_projeto_status public.status_projeto_enum;
  v_pendencia public.retorno_pendencias%ROWTYPE;
  v_existing public.retorno_pendencia_resolucoes%ROWTYPE;
  v_resolution public.retorno_pendencia_resolucoes%ROWTYPE;
  v_acao text := upper(btrim(coalesce(p_acao, '')));
  v_observacao text := nullif(btrim(coalesce(p_observacao, '')), '');
  v_localizacao_confirmada text := nullif(btrim(coalesce(p_localizacao_confirmada, '')), '');
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

  IF v_acao = 'ENCONTRADA'
     AND length(coalesce(v_localizacao_confirmada, '')) < 3 THEN
    RAISE EXCEPTION 'ENCONTRADA exige localização confirmada'
      USING ERRCODE = '22023';
  END IF;

  IF v_acao <> 'ENCONTRADA' THEN
    v_localizacao_confirmada := NULL;
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
  INTO v_pendencia.projeto_id
  FROM public.retorno_pendencias rp
  WHERE rp.id = p_pendencia_id;

  IF v_pendencia.projeto_id IS NULL THEN
    RAISE EXCEPTION 'Pendência % não encontrada', p_pendencia_id
      USING ERRCODE = 'P0002';
  END IF;

  SELECT p.status
  INTO v_projeto_status
  FROM public.projetos p
  WHERE p.id = v_pendencia.projeto_id
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
          'observation', v_observacao,
          'confirmed_location', v_localizacao_confirmada
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
    v_notas := 'Pendência resolvida: unidade encontrada em ' || v_localizacao_confirmada || '. ' || coalesce(v_observacao, '');
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
    observacao,
    localizacao_confirmada
  ) VALUES (
    p_pendencia_id,
    btrim(p_idempotency_key),
    v_payload_hash,
    v_actor_id,
    v_acao,
    v_observacao,
    v_localizacao_confirmada
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
      localizacao_confirmada = v_localizacao_confirmada,
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
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.resolver_pendencia_retorno(uuid, text, text, text, text)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.resolver_pendencia_retorno(uuid, text, text, text, text)
TO authenticated;
