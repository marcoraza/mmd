-- Condição medida no retorno pertence à decisão física, não ao cliente. A coluna
-- fica nula para rascunhos legados já existentes; a confirmação bloqueia
-- PROBLEMA sem condição e observação, e a RPC nova exige o dado desde a captura.
ALTER TABLE public.conferencia_decisoes
  ADD COLUMN retorno_desgaste integer
  CHECK (retorno_desgaste BETWEEN 1 AND 5);

CREATE OR REPLACE FUNCTION public.salvar_decisao_conferencia_retorno(
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

  v_decision := public.salvar_decisao_conferencia(
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

REVOKE ALL ON FUNCTION public.salvar_decisao_conferencia_retorno(
  uuid,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
  integer,
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
  text
) TO authenticated;

CREATE OR REPLACE FUNCTION app_private.conferencia_recibo(
  p_confirmation_id uuid
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'confirmation_id', cc.id,
    'conference_id', cc.conferencia_id,
    'project_id', c.projeto_id,
    'direction', c.direcao,
    'actor_id', cc.actor_id,
    'confirmed_at', cc.confirmed_at,
    'incomplete_reason', cc.incomplete_reason,
    'units', coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'decision_id', cd.id,
            'serial_id', cd.serial_number_id,
            'code', sn.codigo_interno,
            'outcome', cd.resultado,
            'method', cd.metodo,
            'source_event_id', cd.source_event_id,
            'captured_at', cd.captured_at,
            'actor_id', cd.actor_id,
            'manual_reason', cd.manual_reason,
            'observation', cd.observation,
            'desgaste', cd.retorno_desgaste,
            'resolution', cd.resolution,
            'replaced_serial_id', cd.replaced_serial_id
          )
          ORDER BY sn.codigo_interno
        )
        FROM public.conferencia_decisoes cd
        JOIN public.serial_numbers sn ON sn.id = cd.serial_number_id
        WHERE cd.applied_confirmation_id = cc.id
      ),
      '[]'::jsonb
    )
  )
  FROM public.conferencia_confirmacoes cc
  JOIN public.conferencias c ON c.id = cc.conferencia_id
  WHERE cc.id = p_confirmation_id;
$$;

REVOKE ALL ON FUNCTION app_private.conferencia_recibo(uuid)
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
  v_projeto_id uuid;
  v_existing public.conferencia_confirmacoes%ROWTYPE;
  v_decision_ids uuid[];
  v_payload_hash text;
  v_receipt jsonb;
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

  IF EXISTS (
    SELECT 1
    FROM public.conferencia_decisoes cd
    WHERE cd.id = ANY(v_decision_ids)
      AND cd.resultado = 'PROBLEMA'
      AND (
        cd.retorno_desgaste IS NULL
        OR cd.retorno_desgaste NOT BETWEEN 1 AND 5
        OR length(btrim(coalesce(cd.observation, ''))) < 3
      )
  ) THEN
    RAISE EXCEPTION 'Unidade com problema exige condição e observação'
      USING ERRCODE = '22023';
  END IF;

  v_receipt := public.confirmar_conferencia_retorno_legacy_actor_scope(
    p_conferencia_id,
    p_decision_ids,
    p_expected_version,
    p_idempotency_key
  );

  UPDATE public.serial_numbers sn
  SET desgaste = cd.retorno_desgaste
  FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids)
    AND cd.resultado <> 'NAO_VOLTOU'
    AND cd.retorno_desgaste IS NOT NULL
    AND sn.id = cd.serial_number_id;

  RETURN app_private.conferencia_recibo((v_receipt ->> 'confirmation_id')::uuid);
END;
$$;

REVOKE ALL ON FUNCTION public.confirmar_conferencia_retorno(uuid, uuid[], bigint, text)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.confirmar_conferencia_retorno(uuid, uuid[], bigint, text)
TO authenticated;
