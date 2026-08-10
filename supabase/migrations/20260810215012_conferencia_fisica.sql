CREATE TYPE public.conferencia_direcao_enum AS ENUM ('SAIDA', 'RETORNO');
CREATE TYPE public.conferencia_resultado_enum AS ENUM (
  'PRESENTE',
  'OK',
  'PROBLEMA',
  'NAO_VOLTOU'
);
CREATE TYPE public.conferencia_resolution_enum AS ENUM (
  'DESIGNADA',
  'SUBSTITUICAO',
  'REVISAR',
  'SEM_PACKING'
);

CREATE TABLE public.conferencias (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE CASCADE,
  direcao public.conferencia_direcao_enum NOT NULL,
  version bigint NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conferencias_projeto_direcao_unique UNIQUE (projeto_id, direcao)
);

CREATE TABLE public.conferencia_decisoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conferencia_id uuid NOT NULL REFERENCES public.conferencias(id) ON DELETE CASCADE,
  serial_number_id uuid NOT NULL REFERENCES public.serial_numbers(id) ON DELETE RESTRICT,
  resultado public.conferencia_resultado_enum NOT NULL,
  metodo public.metodo_scan_enum NOT NULL,
  source_event_id text NOT NULL CHECK (length(btrim(source_event_id)) > 0),
  captured_at timestamptz NOT NULL,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  manual_reason text,
  observation text,
  resolution public.conferencia_resolution_enum NOT NULL DEFAULT 'DESIGNADA',
  replaced_serial_id uuid REFERENCES public.serial_numbers(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conferencia_decisoes_unidade_unique
    UNIQUE (conferencia_id, serial_number_id),
  CONSTRAINT conferencia_decisoes_manual_reason_check CHECK (
    metodo <> 'MANUAL'
    OR length(btrim(coalesce(manual_reason, ''))) >= 3
  )
);

CREATE INDEX conferencia_decisoes_conferencia_idx
  ON public.conferencia_decisoes(conferencia_id, updated_at DESC);

ALTER TABLE public.conferencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conferencia_decisoes ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE
  public.conferencias,
  public.conferencia_decisoes
FROM anon, authenticated, service_role;

GRANT SELECT ON TABLE
  public.conferencias,
  public.conferencia_decisoes
TO authenticated, service_role;

CREATE POLICY conferencias_read ON public.conferencias
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE POLICY conferencia_decisoes_read ON public.conferencia_decisoes
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE OR REPLACE FUNCTION public.salvar_decisao_conferencia(
  p_projeto_id uuid,
  p_direcao public.conferencia_direcao_enum,
  p_serial_id uuid,
  p_resultado public.conferencia_resultado_enum,
  p_metodo public.metodo_scan_enum,
  p_source_event_id text,
  p_captured_at timestamptz,
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
  v_projeto_status public.status_projeto_enum;
  v_conferencia public.conferencias%ROWTYPE;
  v_decisao public.conferencia_decisoes%ROWTYPE;
  v_item_id uuid;
  v_serial_status public.status_serial_enum;
  v_resolution public.conferencia_resolution_enum :=
    'DESIGNADA'::public.conferencia_resolution_enum;
  v_replaced_serial_id uuid;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Sessão autenticada obrigatória'
      USING ERRCODE = '28000';
  END IF;

  IF app_private.current_user_role() NOT IN ('editor', 'admin') THEN
    RAISE EXCEPTION 'Perfil sem permissão para operar Conferência'
      USING ERRCODE = '42501';
  END IF;

  IF p_direcao = 'SAIDA' AND p_resultado <> 'PRESENTE' THEN
    RAISE EXCEPTION 'Conferência de saída aceita somente PRESENTE'
      USING ERRCODE = '22023';
  END IF;

  IF p_direcao = 'RETORNO' AND p_resultado = 'PRESENTE' THEN
    RAISE EXCEPTION 'Conferência de retorno exige OK, PROBLEMA ou NAO_VOLTOU'
      USING ERRCODE = '22023';
  END IF;

  IF p_metodo = 'MANUAL'
     AND length(btrim(coalesce(p_manual_reason, ''))) < 3 THEN
    RAISE EXCEPTION 'Confirmação manual exige motivo'
      USING ERRCODE = '22023';
  END IF;

  IF length(btrim(coalesce(p_source_event_id, ''))) = 0 THEN
    RAISE EXCEPTION 'Referência de evidência obrigatória'
      USING ERRCODE = '22023';
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

  IF v_projeto_status = 'FINALIZADO' THEN
    RAISE EXCEPTION 'Evento FINALIZADO não aceita novas decisões'
      USING ERRCODE = '55000';
  END IF;

  SELECT sn.item_id, sn.status
  INTO v_item_id, v_serial_status
  FROM public.serial_numbers sn
  WHERE sn.id = p_serial_id;

  IF v_item_id IS NULL THEN
    RAISE EXCEPTION 'Unidade % não encontrada', p_serial_id
      USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.conferencias (projeto_id, direcao)
  VALUES (p_projeto_id, p_direcao)
  ON CONFLICT (projeto_id, direcao) DO NOTHING;

  SELECT c.*
  INTO v_conferencia
  FROM public.conferencias c
  WHERE c.projeto_id = p_projeto_id
    AND c.direcao = p_direcao
  FOR UPDATE;

  IF p_direcao = 'SAIDA' THEN
    IF v_serial_status <> 'DISPONIVEL' THEN
      v_resolution := 'REVISAR';
    ELSIF NOT EXISTS (
      SELECT 1 FROM public.packing_list pl
      WHERE pl.projeto_id = p_projeto_id
    ) THEN
      v_resolution := 'SEM_PACKING';
    ELSIF EXISTS (
      SELECT 1
      FROM public.packing_list pl
      WHERE pl.projeto_id = p_projeto_id
        AND p_serial_id = ANY(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[]))
    ) THEN
      IF EXISTS (
        SELECT 1
        FROM public.conferencia_decisoes prior
        WHERE prior.conferencia_id = v_conferencia.id
          AND prior.serial_number_id <> p_serial_id
          AND prior.replaced_serial_id = p_serial_id
          AND prior.applied_confirmation_id IS NULL
      ) THEN
        v_resolution := 'REVISAR';
      ELSE
        v_resolution := 'DESIGNADA';
      END IF;
    ELSE
      SELECT expected_serial_id
      INTO v_replaced_serial_id
      FROM public.packing_list pl
      CROSS JOIN LATERAL unnest(
        coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[])
      ) AS expected_serial_id
      WHERE pl.projeto_id = p_projeto_id
        AND pl.item_id = v_item_id
        AND NOT EXISTS (
          SELECT 1
          FROM public.conferencia_decisoes prior
          WHERE prior.conferencia_id = v_conferencia.id
            AND prior.serial_number_id <> p_serial_id
            AND (
              prior.serial_number_id = expected_serial_id
              OR prior.replaced_serial_id = expected_serial_id
            )
        )
      ORDER BY expected_serial_id
      LIMIT 1;

      IF v_replaced_serial_id IS NULL THEN
        v_resolution := 'REVISAR';
      ELSE
        v_resolution := 'SUBSTITUICAO';
      END IF;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.conferencia_decisoes cd
    WHERE cd.conferencia_id = v_conferencia.id
      AND cd.serial_number_id = p_serial_id
      AND cd.applied_confirmation_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'DECISION_ALREADY_APPLIED'
      USING ERRCODE = '55000';
  END IF;

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
    resolution,
    replaced_serial_id
  ) VALUES (
    v_conferencia.id,
    p_serial_id,
    p_resultado,
    p_metodo,
    btrim(p_source_event_id),
    p_captured_at,
    v_actor_id,
    nullif(btrim(coalesce(p_manual_reason, '')), ''),
    nullif(btrim(coalesce(p_observation, '')), ''),
    v_resolution,
    v_replaced_serial_id
  )
  ON CONFLICT (conferencia_id, serial_number_id) DO UPDATE
  SET resultado = EXCLUDED.resultado,
      metodo = EXCLUDED.metodo,
      source_event_id = EXCLUDED.source_event_id,
      captured_at = EXCLUDED.captured_at,
      actor_id = EXCLUDED.actor_id,
      manual_reason = EXCLUDED.manual_reason,
      observation = EXCLUDED.observation,
      resolution = EXCLUDED.resolution,
      replaced_serial_id = EXCLUDED.replaced_serial_id,
      updated_at = now()
  RETURNING * INTO v_decisao;

  UPDATE public.conferencias c
  SET version = c.version + 1,
      updated_at = now()
  WHERE c.id = v_conferencia.id
  RETURNING c.* INTO v_conferencia;

  RETURN jsonb_build_object(
    'conference_id', v_conferencia.id,
    'decision_id', v_decisao.id,
    'version', v_conferencia.version,
    'updated_at', v_conferencia.updated_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.salvar_decisao_conferencia(
  uuid,
  public.conferencia_direcao_enum,
  uuid,
  public.conferencia_resultado_enum,
  public.metodo_scan_enum,
  text,
  timestamptz,
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
  text
) TO authenticated;

CREATE TABLE public.conferencia_confirmacoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conferencia_id uuid NOT NULL REFERENCES public.conferencias(id) ON DELETE RESTRICT,
  idempotency_key text NOT NULL CHECK (length(btrim(idempotency_key)) >= 8),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  incomplete_reason text,
  confirmed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conferencia_confirmacoes_idempotency_unique
    UNIQUE (conferencia_id, idempotency_key),
  CONSTRAINT conferencia_confirmacoes_incomplete_reason_check CHECK (
    incomplete_reason IS NULL
    OR length(btrim(incomplete_reason)) >= 3
  )
);

ALTER TABLE public.conferencia_decisoes
  ADD COLUMN applied_confirmation_id uuid
  REFERENCES public.conferencia_confirmacoes(id) ON DELETE RESTRICT;

ALTER TABLE public.movimentacoes
  ADD COLUMN conferencia_confirmacao_id uuid
    REFERENCES public.conferencia_confirmacoes(id) ON DELETE RESTRICT,
  ADD COLUMN conferencia_decisao_id uuid
    REFERENCES public.conferencia_decisoes(id) ON DELETE RESTRICT;

CREATE UNIQUE INDEX movimentacoes_conferencia_transition_unique
  ON public.movimentacoes(
    conferencia_confirmacao_id,
    serial_number_id,
    tipo
  )
  WHERE conferencia_confirmacao_id IS NOT NULL;

CREATE UNIQUE INDEX movimentacoes_conferencia_decisao_unique
  ON public.movimentacoes(conferencia_decisao_id)
  WHERE conferencia_decisao_id IS NOT NULL;

ALTER TABLE public.conferencia_confirmacoes ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.conferencia_confirmacoes
FROM anon, authenticated, service_role;

GRANT SELECT ON TABLE public.conferencia_confirmacoes
TO authenticated, service_role;

CREATE POLICY conferencia_confirmacoes_read ON public.conferencia_confirmacoes
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE OR REPLACE FUNCTION app_private.reject_conferencia_confirmation_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION 'CONFIRMATION_IMMUTABLE'
    USING ERRCODE = '55000';
END;
$$;

CREATE TRIGGER trg_conferencia_confirmacoes_immutable
BEFORE UPDATE OR DELETE ON public.conferencia_confirmacoes
FOR EACH ROW
EXECUTE FUNCTION app_private.reject_conferencia_confirmation_mutation();

REVOKE ALL ON FUNCTION app_private.reject_conferencia_confirmation_mutation()
FROM PUBLIC, anon, authenticated, service_role;

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
  v_conferencia public.conferencias%ROWTYPE;
  v_projeto_status public.status_projeto_enum;
  v_existing public.conferencia_confirmacoes%ROWTYPE;
  v_confirmation public.conferencia_confirmacoes%ROWTYPE;
  v_decision_ids uuid[];
  v_serial_ids uuid[];
  v_payload_hash text;
  v_decision_count integer;
  v_bad_status_count integer;
  v_unresolved_count integer;
  v_is_incomplete boolean;
  v_substitution record;
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

  IF v_conferencia.direcao <> 'SAIDA' THEN
    RAISE EXCEPTION 'RPC de saída exige Conferência SAIDA'
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

  IF v_projeto_status::text NOT IN ('CONFIRMADO', 'MONTAGEM', 'EM_CAMPO') THEN
    RAISE EXCEPTION 'Evento em status % não aceita saída física', v_projeto_status
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
    AND cd.resultado = 'PRESENTE'
    AND cd.applied_confirmation_id IS NULL;

  IF v_decision_count <> cardinality(v_decision_ids) THEN
    RAISE EXCEPTION 'Decisão ausente, aplicada ou incompatível com saída'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*)::integer
  INTO v_unresolved_count
  FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids)
    AND cd.resolution = 'REVISAR';

  IF v_unresolved_count > 0 THEN
    RAISE EXCEPTION 'EXTRA_REQUIRES_RESOLUTION'
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
    AND sn.status <> 'DISPONIVEL';

  IF v_bad_status_count > 0 THEN
    RAISE EXCEPTION 'Unidade indisponível, confirmação abortada'
      USING ERRCODE = '55000';
  END IF;

  PERFORM 1
  FROM public.packing_list pl
  WHERE pl.projeto_id = v_conferencia.projeto_id
  ORDER BY pl.id
  FOR UPDATE;

  FOR v_substitution IN
    SELECT cd.serial_number_id, cd.replaced_serial_id
    FROM public.conferencia_decisoes cd
    WHERE cd.id = ANY(v_decision_ids)
      AND cd.resolution = 'SUBSTITUICAO'
    ORDER BY cd.id
  LOOP
    UPDATE public.packing_list pl
    SET serial_numbers_designados = array_replace(
      pl.serial_numbers_designados,
      v_substitution.replaced_serial_id,
      v_substitution.serial_number_id
    )
    WHERE pl.projeto_id = v_conferencia.projeto_id
      AND v_substitution.replaced_serial_id = ANY(
        coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[])
      );

    IF NOT FOUND THEN
      RAISE EXCEPTION 'SUBSTITUTION_TARGET_CHANGED'
        USING ERRCODE = '40001';
    END IF;
  END LOOP;

  SELECT
    NOT EXISTS (
      SELECT 1
      FROM public.packing_list pl
      WHERE pl.projeto_id = v_conferencia.projeto_id
    )
    OR EXISTS (
      SELECT 1
      FROM public.packing_list pl
      CROSS JOIN LATERAL unnest(
        coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[])
      ) AS expected_serial_id
      WHERE pl.projeto_id = v_conferencia.projeto_id
        AND NOT EXISTS (
          SELECT 1
          FROM public.conferencia_decisoes applied
          WHERE applied.conferencia_id = p_conferencia_id
            AND applied.serial_number_id = expected_serial_id
            AND (
              applied.applied_confirmation_id IS NOT NULL
              OR applied.id = ANY(v_decision_ids)
            )
        )
    )
    OR EXISTS (
      SELECT 1
      FROM public.packing_list pl
      WHERE pl.projeto_id = v_conferencia.projeto_id
        AND (
          coalesce(array_length(pl.serial_numbers_designados, 1), 0)
          + coalesce(
              (
                SELECT sum(greatest((rental->>'quantidade')::integer, 0))
                FROM jsonb_array_elements(
                  coalesce(pl.alugueis_avulsos, '[]'::jsonb)
                ) AS rental
                WHERE rental ? 'quantidade'
                  AND (rental->>'quantidade') ~ '^[0-9]+$'
              ),
              0
            )
        ) < pl.quantidade
    )
  INTO v_is_incomplete;

  IF v_is_incomplete
     AND length(coalesce(v_incomplete_reason, '')) < 3 THEN
    RAISE EXCEPTION 'Saída incompleta exige motivo'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.conferencia_confirmacoes (
    conferencia_id,
    idempotency_key,
    payload_hash,
    actor_id,
    incomplete_reason
  ) VALUES (
    p_conferencia_id,
    btrim(p_idempotency_key),
    v_payload_hash,
    v_actor_id,
    v_incomplete_reason
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
    'SAIDA',
    'DISPONIVEL',
    'EM_CAMPO',
    v_actor_id::text,
    cd.metodo,
    v_incomplete_reason,
    v_confirmation.id,
    cd.id
  FROM public.conferencia_decisoes cd
  WHERE cd.id = ANY(v_decision_ids);

  UPDATE public.serial_numbers sn
  SET status = 'EM_CAMPO'
  WHERE sn.id = ANY(v_serial_ids);

  UPDATE public.conferencia_decisoes cd
  SET applied_confirmation_id = v_confirmation.id,
      updated_at = now()
  WHERE cd.id = ANY(v_decision_ids);

  UPDATE public.projetos p
  SET status = 'EM_CAMPO'
  WHERE p.id = v_conferencia.projeto_id
    AND p.status <> 'EM_CAMPO';

  UPDATE public.conferencias c
  SET version = c.version + 1,
      updated_at = now()
  WHERE c.id = p_conferencia_id;

  RETURN app_private.conferencia_recibo(v_confirmation.id);
END;
$$;

REVOKE ALL ON FUNCTION public.confirmar_conferencia_saida(
  uuid,
  uuid[],
  bigint,
  text,
  text
) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.confirmar_conferencia_saida(
  uuid,
  uuid[],
  bigint,
  text,
  text
) TO authenticated;

CREATE OR REPLACE FUNCTION public.conferencia_retorno_esperado(
  p_projeto_id uuid
)
RETURNS TABLE(
  serial_id uuid,
  codigo_interno text,
  saida_confirmation_id uuid,
  saida_confirmed_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT
    saida.serial_number_id,
    sn.codigo_interno,
    saida.applied_confirmation_id,
    saida_confirmation.confirmed_at
  FROM public.conferencia_decisoes saida
  JOIN public.conferencias saida_conference
    ON saida_conference.id = saida.conferencia_id
  JOIN public.conferencia_confirmacoes saida_confirmation
    ON saida_confirmation.id = saida.applied_confirmation_id
  JOIN public.serial_numbers sn
    ON sn.id = saida.serial_number_id
  WHERE saida_conference.projeto_id = p_projeto_id
    AND saida_conference.direcao = 'SAIDA'
    AND saida.applied_confirmation_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.conferencia_decisoes retorno
      JOIN public.conferencias retorno_conference
        ON retorno_conference.id = retorno.conferencia_id
      WHERE retorno_conference.projeto_id = p_projeto_id
        AND retorno_conference.direcao = 'RETORNO'
        AND retorno.serial_number_id = saida.serial_number_id
        AND retorno.applied_confirmation_id IS NOT NULL
    )
  ORDER BY sn.codigo_interno;
$$;

REVOKE ALL ON FUNCTION public.conferencia_retorno_esperado(uuid)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.conferencia_retorno_esperado(uuid)
TO authenticated;
