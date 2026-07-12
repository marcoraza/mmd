-- Retorno com pendência de resolução.
--
-- Mantém a conferência física separada da resolução administrativa:
-- - OK volta para DISPONIVEL.
-- - Problema volta para MANUTENCAO com observação.
-- - Não voltou abre pendência e mantém a unidade em RETORNANDO, sem baixa automática.
-- - Admin resolve a pendência depois como encontrada, manutenção, baixa ou cobrança.

CREATE TABLE IF NOT EXISTS public.retorno_pendencias (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE CASCADE,
  serial_number_id uuid NOT NULL REFERENCES public.serial_numbers(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'ABERTA',
  observacao text,
  resolucao_observacao text,
  registrado_por text NOT NULL,
  resolvido_por text,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  CONSTRAINT retorno_pendencias_status_check
    CHECK (status IN ('ABERTA', 'ENCONTRADA', 'MANUTENCAO', 'BAIXA', 'COBRANCA')),
  CONSTRAINT retorno_pendencias_resolution_consistency
    CHECK (
      (status = 'ABERTA' AND resolved_at IS NULL)
      OR (status <> 'ABERTA' AND resolved_at IS NOT NULL)
    ),
  CONSTRAINT retorno_pendencias_unique_serial_evento
    UNIQUE (projeto_id, serial_number_id)
);

COMMENT ON TABLE public.retorno_pendencias IS
  'Pendências abertas quando uma unidade própria não volta na conferência de retorno do Evento.';

CREATE INDEX IF NOT EXISTS retorno_pendencias_projeto_status_idx
  ON public.retorno_pendencias(projeto_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS retorno_pendencias_serial_idx
  ON public.retorno_pendencias(serial_number_id, created_at DESC);

ALTER TABLE public.retorno_pendencias ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.retorno_pendencias FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.retorno_pendencias FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.retorno_pendencias FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.retorno_pendencias FROM service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.retorno_pendencias TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.retorno_pendencias TO service_role;

DROP POLICY IF EXISTS retorno_pendencias_read ON public.retorno_pendencias;
DROP POLICY IF EXISTS retorno_pendencias_insert ON public.retorno_pendencias;
DROP POLICY IF EXISTS retorno_pendencias_update ON public.retorno_pendencias;

CREATE POLICY retorno_pendencias_read ON public.retorno_pendencias
  FOR SELECT
  TO authenticated
  USING (public.current_user_role() IN ('viewer', 'editor', 'admin'));

CREATE POLICY retorno_pendencias_insert ON public.retorno_pendencias
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY retorno_pendencias_update ON public.retorno_pendencias
  FOR UPDATE
  TO authenticated
  USING (public.current_user_role() = 'admin')
  WITH CHECK (public.current_user_role() = 'admin');

CREATE OR REPLACE FUNCTION public.checkin_projeto(
  p_projeto_id uuid,
  p_metodo public.metodo_scan_enum,
  p_registrado_por text,
  p_items jsonb
)
RETURNS TABLE(serial_id uuid, codigo_interno text, novo_status public.status_serial_enum)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_projeto_status public.status_projeto_enum;
  v_expected_ids uuid[];
  v_serial_ids uuid[];
  v_bad_status_count int;
  v_duplicate_count int;
  v_unexpected_count int;
  v_missing_count int;
  v_problem_without_obs_count int;
BEGIN
  SELECT status INTO v_projeto_status
  FROM public.projetos
  WHERE id = p_projeto_id
  FOR UPDATE;

  IF v_projeto_status IS NULL THEN
    RAISE EXCEPTION 'Evento % não encontrado', p_projeto_id;
  END IF;

  IF v_projeto_status <> 'EM_CAMPO' THEN
    RAISE EXCEPTION 'Retorno requer Evento EM_CAMPO (atual: %)', v_projeto_status;
  END IF;

  IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Lista de unidades vazia';
  END IF;

  SELECT coalesce(array_agg(DISTINCT allocated.serial_id), ARRAY[]::uuid[]) INTO v_expected_ids
  FROM public.packing_list pl
  CROSS JOIN LATERAL unnest(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[]))
    AS allocated(serial_id)
  JOIN public.serial_numbers sn ON sn.id = allocated.serial_id
  WHERE pl.projeto_id = p_projeto_id
    AND sn.status = 'EM_CAMPO';

  IF coalesce(array_length(v_expected_ids, 1), 0) = 0 THEN
    RAISE EXCEPTION 'Nenhuma unidade própria em campo para retorno';
  END IF;

  PERFORM 1
  FROM public.serial_numbers
  WHERE id = ANY(v_expected_ids)
  FOR UPDATE;

  SELECT array_agg((elem->>'serial_id')::uuid) INTO v_serial_ids
  FROM jsonb_array_elements(p_items) AS elem;

  SELECT count(*) - count(DISTINCT listed.serial_id) INTO v_duplicate_count
  FROM unnest(v_serial_ids) AS listed(serial_id);

  IF v_duplicate_count > 0 THEN
    RAISE EXCEPTION 'Lista de retorno contém unidade duplicada';
  END IF;

  SELECT count(*) INTO v_unexpected_count
  FROM unnest(v_serial_ids) AS listed(serial_id)
  WHERE NOT (listed.serial_id = ANY(v_expected_ids));

  SELECT count(*) INTO v_missing_count
  FROM unnest(v_expected_ids) AS listed(serial_id)
  WHERE NOT (listed.serial_id = ANY(v_serial_ids));

  IF v_unexpected_count > 0 OR v_missing_count > 0 THEN
    RAISE EXCEPTION 'Lista de retorno não bate com as unidades que saíram neste Evento';
  END IF;

  SELECT count(*) INTO v_bad_status_count
  FROM public.serial_numbers
  WHERE id = ANY(v_expected_ids)
    AND status <> 'EM_CAMPO';

  IF v_bad_status_count > 0 THEN
    RAISE EXCEPTION '% unidade(s) não estão EM_CAMPO. Retorno abortado.', v_bad_status_count;
  END IF;

  SELECT count(*) INTO v_problem_without_obs_count
  FROM (
    SELECT
      upper(coalesce(nullif(elem->>'resultado', ''), CASE
        WHEN coalesce((elem->>'needs_maintenance')::boolean, false) THEN 'PROBLEMA'
        ELSE 'OK'
      END)) AS resultado,
      nullif(btrim(coalesce(elem->>'observacao', '')), '') AS observacao
    FROM jsonb_array_elements(p_items) AS elem
  ) AS input
  WHERE input.resultado = 'PROBLEMA'
    AND length(coalesce(input.observacao, '')) < 3;

  IF v_problem_without_obs_count > 0 THEN
    RAISE EXCEPTION 'Unidade com problema precisa de observação do Evento';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) AS elem
    WHERE upper(coalesce(nullif(elem->>'resultado', ''), CASE
      WHEN coalesce((elem->>'needs_maintenance')::boolean, false) THEN 'PROBLEMA'
      ELSE 'OK'
    END)) NOT IN ('OK', 'PROBLEMA', 'NAO_VOLTOU')
  ) THEN
    RAISE EXCEPTION 'Resultado de retorno inválido';
  END IF;

  INSERT INTO public.movimentacoes (
    serial_number_id, projeto_id, tipo,
    status_anterior, status_novo, registrado_por, metodo_scan, notas
  )
  SELECT
    parsed.serial_id,
    p_projeto_id,
    CASE
      WHEN parsed.resultado = 'PROBLEMA' THEN 'MANUTENCAO'::public.tipo_movimentacao_enum
      ELSE 'RETORNO'::public.tipo_movimentacao_enum
    END,
    'EM_CAMPO',
    CASE
      WHEN parsed.resultado = 'PROBLEMA' THEN 'MANUTENCAO'
      WHEN parsed.resultado = 'NAO_VOLTOU' THEN 'RETORNANDO'
      ELSE 'DISPONIVEL'
    END,
    p_registrado_por,
    p_metodo,
    CASE
      WHEN parsed.resultado = 'PROBLEMA'
        THEN 'Problema no retorno: ' || parsed.observacao
      WHEN parsed.resultado = 'NAO_VOLTOU'
        THEN trim(both ' ' from 'Não voltou no retorno do Evento. ' || coalesce(parsed.observacao, ''))
      ELSE parsed.observacao
    END
  FROM (
    SELECT
      (elem->>'serial_id')::uuid AS serial_id,
      greatest(1, least(5, coalesce(nullif(elem->>'desgaste', '')::int, 3))) AS desgaste,
      upper(coalesce(nullif(elem->>'resultado', ''), CASE
        WHEN coalesce((elem->>'needs_maintenance')::boolean, false) THEN 'PROBLEMA'
        ELSE 'OK'
      END)) AS resultado,
      nullif(btrim(coalesce(elem->>'observacao', '')), '') AS observacao
    FROM jsonb_array_elements(p_items) AS elem
  ) AS parsed;

  UPDATE public.serial_numbers sn
  SET status = CASE
        WHEN parsed.resultado = 'PROBLEMA' THEN 'MANUTENCAO'::public.status_serial_enum
        WHEN parsed.resultado = 'NAO_VOLTOU' THEN 'RETORNANDO'::public.status_serial_enum
        ELSE 'DISPONIVEL'::public.status_serial_enum
      END,
      desgaste = CASE
        WHEN parsed.resultado = 'NAO_VOLTOU' THEN sn.desgaste
        ELSE parsed.desgaste
      END
  FROM (
    SELECT
      (elem->>'serial_id')::uuid AS serial_id,
      greatest(1, least(5, coalesce(nullif(elem->>'desgaste', '')::int, 3))) AS desgaste,
      upper(coalesce(nullif(elem->>'resultado', ''), CASE
        WHEN coalesce((elem->>'needs_maintenance')::boolean, false) THEN 'PROBLEMA'
        ELSE 'OK'
      END)) AS resultado
    FROM jsonb_array_elements(p_items) AS elem
  ) AS parsed
  WHERE sn.id = parsed.serial_id;

  INSERT INTO public.retorno_pendencias (
    projeto_id,
    serial_number_id,
    status,
    observacao,
    registrado_por
  )
  SELECT
    p_projeto_id,
    parsed.serial_id,
    'ABERTA',
    parsed.observacao,
    p_registrado_por
  FROM (
    SELECT
      (elem->>'serial_id')::uuid AS serial_id,
      upper(coalesce(nullif(elem->>'resultado', ''), CASE
        WHEN coalesce((elem->>'needs_maintenance')::boolean, false) THEN 'PROBLEMA'
        ELSE 'OK'
      END)) AS resultado,
      nullif(btrim(coalesce(elem->>'observacao', '')), '') AS observacao
    FROM jsonb_array_elements(p_items) AS elem
  ) AS parsed
  WHERE parsed.resultado = 'NAO_VOLTOU'
  ON CONFLICT (projeto_id, serial_number_id)
  DO UPDATE SET
    status = 'ABERTA',
    observacao = EXCLUDED.observacao,
    resolucao_observacao = NULL,
    registrado_por = EXCLUDED.registrado_por,
    resolvido_por = NULL,
    resolved_at = NULL;

  IF EXISTS (
    SELECT 1
    FROM public.retorno_pendencias rp
    WHERE rp.projeto_id = p_projeto_id
      AND rp.status = 'ABERTA'
  ) THEN
    UPDATE public.projetos
    SET status = 'EM_CAMPO'
    WHERE id = p_projeto_id;
  ELSE
    UPDATE public.projetos
    SET status = 'FINALIZADO'
    WHERE id = p_projeto_id;
  END IF;

  RETURN QUERY
  SELECT sn.id, sn.codigo_interno, sn.status
  FROM public.serial_numbers sn
  WHERE sn.id = ANY(v_serial_ids)
  ORDER BY sn.codigo_interno;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolver_retorno_pendencia(
  p_pendencia_id uuid,
  p_acao text,
  p_observacao text,
  p_registrado_por text
)
RETURNS TABLE(
  pendencia_id uuid,
  serial_id uuid,
  codigo_interno text,
  status_pendencia text,
  novo_status public.status_serial_enum
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pendencia record;
  v_acao text := upper(btrim(coalesce(p_acao, '')));
  v_obs text := nullif(btrim(coalesce(p_observacao, '')), '');
  v_status_anterior public.status_serial_enum;
  v_status_novo public.status_serial_enum;
  v_tipo public.tipo_movimentacao_enum;
  v_notas text;
BEGIN
  IF v_acao NOT IN ('ENCONTRADA', 'MANUTENCAO', 'BAIXA', 'COBRANCA') THEN
    RAISE EXCEPTION 'Ação de resolução inválida';
  END IF;

  IF v_acao IN ('MANUTENCAO', 'COBRANCA') AND length(coalesce(v_obs, '')) < 3 THEN
    RAISE EXCEPTION 'Resolução por % precisa de observação', v_acao;
  END IF;

  SELECT
    rp.id,
    rp.projeto_id,
    rp.serial_number_id,
    rp.status,
    sn.codigo_interno,
    sn.status AS serial_status
  INTO v_pendencia
  FROM public.retorno_pendencias rp
  JOIN public.serial_numbers sn ON sn.id = rp.serial_number_id
  WHERE rp.id = p_pendencia_id
  FOR UPDATE OF rp;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pendência de retorno % não encontrada', p_pendencia_id;
  END IF;

  IF v_pendencia.status <> 'ABERTA' THEN
    RAISE EXCEPTION 'Pendência de retorno já resolvida como %', v_pendencia.status;
  END IF;

  SELECT status INTO v_status_anterior
  FROM public.serial_numbers
  WHERE id = v_pendencia.serial_number_id
  FOR UPDATE;

  IF v_acao = 'ENCONTRADA' THEN
    v_status_novo := 'DISPONIVEL';
    v_tipo := 'RETORNO';
    v_notas := coalesce(v_obs, 'Pendência resolvida: unidade encontrada.');
  ELSIF v_acao = 'MANUTENCAO' THEN
    v_status_novo := 'MANUTENCAO';
    v_tipo := 'MANUTENCAO';
    v_notas := 'Pendência resolvida para manutenção: ' || v_obs;
  ELSIF v_acao = 'BAIXA' THEN
    v_status_novo := 'BAIXA';
    v_tipo := 'DANO';
    v_notas := coalesce(v_obs, 'Pendência resolvida com baixa da unidade.');
  ELSE
    v_status_novo := v_status_anterior;
    v_tipo := 'DANO';
    v_notas := 'Pendência resolvida com nota de cobrança: ' || v_obs;
  END IF;

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
  )
  VALUES (
    v_pendencia.serial_number_id,
    v_pendencia.projeto_id,
    v_tipo,
    v_status_anterior::text,
    v_status_novo::text,
    p_registrado_por,
    'MANUAL',
    v_notas
  );

  UPDATE public.retorno_pendencias
  SET status = v_acao,
      resolucao_observacao = v_obs,
      resolvido_por = p_registrado_por,
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

  RETURN QUERY
  SELECT
    v_pendencia.id,
    v_pendencia.serial_number_id,
    v_pendencia.codigo_interno,
    v_acao,
    v_status_novo;
END;
$$;

REVOKE ALL ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb) FROM anon;
REVOKE ALL ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.resolver_retorno_pendencia(uuid, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.resolver_retorno_pendencia(uuid, text, text, text) FROM anon;
REVOKE ALL ON FUNCTION public.resolver_retorno_pendencia(uuid, text, text, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.resolver_retorno_pendencia(uuid, text, text, text) TO service_role;
