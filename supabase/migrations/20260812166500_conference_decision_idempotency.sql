CREATE TABLE public.conferencia_decisao_intencoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE RESTRICT,
  direcao public.conferencia_direcao_enum NOT NULL,
  idempotency_key text NOT NULL CHECK (length(btrim(idempotency_key)) >= 8),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  decision_id uuid NOT NULL REFERENCES public.conferencia_decisoes(id) ON DELETE RESTRICT,
  ack jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conferencia_decisao_intencoes_key_unique
    UNIQUE (projeto_id, direcao, idempotency_key)
);

ALTER TABLE public.conferencia_decisao_intencoes ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.conferencia_decisao_intencoes
FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE public.conferencia_retorno_decisao_intencoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE RESTRICT,
  idempotency_key text NOT NULL CHECK (length(btrim(idempotency_key)) >= 8),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  decision_id uuid NOT NULL REFERENCES public.conferencia_decisoes(id) ON DELETE RESTRICT,
  ack jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conferencia_retorno_decisao_intencoes_key_unique
    UNIQUE (projeto_id, idempotency_key)
);

ALTER TABLE public.conferencia_retorno_decisao_intencoes ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.conferencia_retorno_decisao_intencoes
FROM PUBLIC, anon, authenticated, service_role;

ALTER FUNCTION public.salvar_decisao_conferencia(
  uuid,
  public.conferencia_direcao_enum,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
  text,
  text
) RENAME TO salvar_decisao_conferencia_legacy_idempotency;

CREATE OR REPLACE FUNCTION public.salvar_decisao_conferencia(
  p_projeto_id uuid,
  p_direcao public.conferencia_direcao_enum,
  p_serial_id uuid,
  p_resultado public.conferencia_resultado_enum,
  p_metodo public.metodo_scan_enum,
  p_source_event_id text,
  p_captured_at timestamptz,
  p_manual_reason text DEFAULT NULL,
  p_observation text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
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
  v_existing public.conferencia_decisao_intencoes%ROWTYPE;
  v_ack jsonb;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória'
      USING ERRCODE = '28000';
  END IF;

  IF app_private.current_user_role() NOT IN ('editor', 'admin') THEN
    RAISE EXCEPTION 'Perfil sem permissão para operar Conferência'
      USING ERRCODE = '42501';
  END IF;

  IF p_direcao <> 'SAIDA' THEN
    RAISE EXCEPTION 'Use a RPC de retorno para decisões de retorno'
      USING ERRCODE = '22023';
  END IF;

  IF length(v_key) < 8 THEN
    RAISE EXCEPTION 'Chave idempotente inválida'
      USING ERRCODE = '22023';
  END IF;

  v_payload_hash := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object(
          'project_id', p_projeto_id,
          'direction', p_direcao,
          'serial_id', p_serial_id,
          'outcome', p_resultado,
          'method', p_metodo,
          'source_event_id', p_source_event_id,
          'captured_at', p_captured_at,
          'manual_reason', nullif(btrim(coalesce(p_manual_reason, '')), ''),
          'observation', nullif(btrim(coalesce(p_observation, '')), '')
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  PERFORM pg_advisory_xact_lock(
    hashtextextended(
      'conference-decision-idempotency:' || p_projeto_id::text || ':' || p_direcao::text || ':' || v_key,
      0
    )
  );

  SELECT intent.*
  INTO v_existing
  FROM public.conferencia_decisao_intencoes intent
  WHERE intent.projeto_id = p_projeto_id
    AND intent.direcao = p_direcao
    AND intent.idempotency_key = v_key;

  IF FOUND THEN
    IF v_existing.actor_id <> v_actor_id
       OR v_existing.payload_hash <> v_payload_hash THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_existing.ack;
  END IF;

  v_ack := public.salvar_decisao_conferencia_legacy_idempotency(
    p_projeto_id,
    p_direcao,
    p_serial_id,
    p_resultado,
    p_metodo,
    p_source_event_id,
    p_captured_at,
    p_manual_reason,
    p_observation
  );

  INSERT INTO public.conferencia_decisao_intencoes (
    projeto_id,
    direcao,
    idempotency_key,
    payload_hash,
    actor_id,
    decision_id,
    ack
  ) VALUES (
    p_projeto_id,
    p_direcao,
    v_key,
    v_payload_hash,
    v_actor_id,
    (v_ack ->> 'decision_id')::uuid,
    v_ack
  );

  RETURN v_ack;
END;
$$;

REVOKE ALL ON FUNCTION public.salvar_decisao_conferencia_legacy_idempotency(
  uuid,
  public.conferencia_direcao_enum,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
  text,
  text
) FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.salvar_decisao_conferencia(
  uuid,
  public.conferencia_direcao_enum,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
  text,
  text,
  text
) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.salvar_decisao_conferencia(
  uuid,
  public.conferencia_direcao_enum,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
  text,
  text,
  text
) TO authenticated;

ALTER FUNCTION public.salvar_decisao_conferencia_retorno(
  uuid,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
  integer,
  text,
  text
) RENAME TO salvar_decisao_conferencia_retorno_legacy_idempotency;

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
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_key text := btrim(coalesce(p_idempotency_key, ''));
  v_payload_hash text;
  v_existing public.conferencia_retorno_decisao_intencoes%ROWTYPE;
  v_decision jsonb;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória'
      USING ERRCODE = '28000';
  END IF;

  IF length(v_key) < 8 THEN
    RAISE EXCEPTION 'Chave idempotente inválida'
      USING ERRCODE = '22023';
  END IF;

  IF p_resultado NOT IN ('OK', 'PROBLEMA', 'NAO_VOLTOU') THEN
    RAISE EXCEPTION 'Conferência de retorno exige OK, PROBLEMA ou NAO_VOLTOU'
      USING ERRCODE = '22023';
  END IF;

  IF p_desgaste IS NOT NULL AND p_desgaste NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'Desgaste de retorno deve estar entre 1 e 5'
      USING ERRCODE = '22023';
  END IF;

  IF p_resultado = 'NAO_VOLTOU' AND p_desgaste IS NOT NULL THEN
    RAISE EXCEPTION 'Retorno NAO_VOLTOU não recebe condição física'
      USING ERRCODE = '22023';
  END IF;

  IF p_resultado = 'PROBLEMA'
     AND (
       p_desgaste IS NULL
       OR length(btrim(coalesce(p_observation, ''))) < 3
     ) THEN
    RAISE EXCEPTION 'Retorno PROBLEMA exige condição e observação'
      USING ERRCODE = '22023';
  END IF;

  v_payload_hash := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object(
          'project_id', p_projeto_id,
          'serial_id', p_serial_id,
          'outcome', p_resultado,
          'method', p_metodo,
          'source_event_id', p_source_event_id,
          'captured_at', p_captured_at,
          'desgaste', p_desgaste,
          'manual_reason', nullif(btrim(coalesce(p_manual_reason, '')), ''),
          'observation', nullif(btrim(coalesce(p_observation, '')), '')
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  PERFORM pg_advisory_xact_lock(
    hashtextextended('return-decision-idempotency:' || p_projeto_id::text || ':' || v_key, 0)
  );

  SELECT intent.*
  INTO v_existing
  FROM public.conferencia_retorno_decisao_intencoes intent
  WHERE intent.projeto_id = p_projeto_id
    AND intent.idempotency_key = v_key;

  IF FOUND THEN
    IF v_existing.actor_id <> v_actor_id
       OR v_existing.payload_hash <> v_payload_hash THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_existing.ack;
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
  WHERE id = (v_decision ->> 'decision_id')::uuid
    AND retorno_desgaste IS DISTINCT FROM p_desgaste;

  v_decision := v_decision || jsonb_build_object('desgaste', p_desgaste);

  INSERT INTO public.conferencia_retorno_decisao_intencoes (
    projeto_id,
    idempotency_key,
    payload_hash,
    actor_id,
    decision_id,
    ack
  ) VALUES (
    p_projeto_id,
    v_key,
    v_payload_hash,
    v_actor_id,
    (v_decision ->> 'decision_id')::uuid,
    v_decision
  );

  RETURN v_decision;
END;
$$;

REVOKE ALL ON FUNCTION public.salvar_decisao_conferencia_retorno_legacy_idempotency(
  uuid,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
  integer,
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
