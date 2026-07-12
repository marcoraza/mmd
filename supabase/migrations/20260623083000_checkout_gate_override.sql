-- Gate de saída com override admin auditável.

CREATE TABLE IF NOT EXISTS public.checkout_overrides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE CASCADE,
  motivo text NOT NULL CHECK (char_length(btrim(motivo)) >= 10),
  blockers jsonb NOT NULL DEFAULT '[]'::jsonb,
  warnings jsonb NOT NULL DEFAULT '[]'::jsonb,
  checks jsonb NOT NULL DEFAULT '[]'::jsonb,
  readiness_pct integer NOT NULL DEFAULT 0 CHECK (readiness_pct BETWEEN 0 AND 100),
  registrado_por text NOT NULL,
  profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  executado_em timestamptz
);

ALTER TABLE public.checkout_overrides
  DROP CONSTRAINT IF EXISTS checkout_overrides_blockers_array;

ALTER TABLE public.checkout_overrides
  ADD CONSTRAINT checkout_overrides_blockers_array
  CHECK (jsonb_typeof(blockers) = 'array');

ALTER TABLE public.checkout_overrides
  DROP CONSTRAINT IF EXISTS checkout_overrides_warnings_array;

ALTER TABLE public.checkout_overrides
  ADD CONSTRAINT checkout_overrides_warnings_array
  CHECK (jsonb_typeof(warnings) = 'array');

ALTER TABLE public.checkout_overrides
  DROP CONSTRAINT IF EXISTS checkout_overrides_checks_array;

ALTER TABLE public.checkout_overrides
  ADD CONSTRAINT checkout_overrides_checks_array
  CHECK (jsonb_typeof(checks) = 'array');

CREATE INDEX IF NOT EXISTS checkout_overrides_projeto_created_idx
  ON public.checkout_overrides(projeto_id, created_at DESC);

ALTER TABLE public.checkout_overrides ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.checkout_overrides FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.checkout_overrides FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.checkout_overrides FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.checkout_overrides FROM service_role;
GRANT SELECT, INSERT ON TABLE public.checkout_overrides TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.checkout_overrides TO service_role;

DROP POLICY IF EXISTS checkout_overrides_read ON public.checkout_overrides;
DROP POLICY IF EXISTS checkout_overrides_insert ON public.checkout_overrides;

CREATE POLICY checkout_overrides_read ON public.checkout_overrides
  FOR SELECT
  TO authenticated
  USING (public.current_user_role() IN ('viewer', 'editor', 'admin'));

CREATE POLICY checkout_overrides_insert ON public.checkout_overrides
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() = 'admin');

CREATE OR REPLACE FUNCTION public.checkout_projeto_com_override(
  p_projeto_id uuid,
  p_metodo public.metodo_scan_enum,
  p_registrado_por text,
  p_override_id uuid
)
RETURNS TABLE(serial_id uuid, codigo_interno text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_projeto_status public.status_projeto_enum;
  v_serial_ids uuid[];
  v_bad_status_count int;
BEGIN
  SELECT status INTO v_projeto_status
  FROM public.projetos
  WHERE id = p_projeto_id
  FOR UPDATE;

  IF v_projeto_status IS NULL THEN
    RAISE EXCEPTION 'Projeto % não encontrado', p_projeto_id;
  END IF;

  IF v_projeto_status <> 'CONFIRMADO' THEN
    RAISE EXCEPTION 'Check-out requer status CONFIRMADO (atual: %)', v_projeto_status;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.checkout_overrides co
    WHERE co.id = p_override_id
      AND co.projeto_id = p_projeto_id
  ) THEN
    RAISE EXCEPTION 'Override % não encontrado para o projeto %', p_override_id, p_projeto_id;
  END IF;

  SELECT coalesce(array_agg(DISTINCT s), ARRAY[]::uuid[]) INTO v_serial_ids
  FROM public.packing_list pl,
       unnest(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[])) AS s
  WHERE pl.projeto_id = p_projeto_id;

  IF coalesce(array_length(v_serial_ids, 1), 0) > 0 THEN
    PERFORM 1 FROM public.serial_numbers
    WHERE id = ANY(v_serial_ids)
    FOR UPDATE;

    SELECT count(*) INTO v_bad_status_count
    FROM public.serial_numbers
    WHERE id = ANY(v_serial_ids)
      AND status <> 'DISPONIVEL';

    IF v_bad_status_count > 0 THEN
      RAISE EXCEPTION '% serial(is) não estão DISPONIVEL. Check-out abortado.', v_bad_status_count;
    END IF;

    INSERT INTO public.movimentacoes (
      serial_number_id, projeto_id, tipo,
      status_anterior, status_novo, registrado_por, metodo_scan, notas
    )
    SELECT
      id,
      p_projeto_id,
      'SAIDA',
      'DISPONIVEL',
      'EM_CAMPO',
      p_registrado_por,
      p_metodo,
      'Saída forçada por override auditado: ' || p_override_id::text
    FROM public.serial_numbers
    WHERE id = ANY(v_serial_ids);

    UPDATE public.serial_numbers
    SET status = 'EM_CAMPO'
    WHERE id = ANY(v_serial_ids);
  END IF;

  UPDATE public.projetos
  SET status = 'EM_CAMPO'
  WHERE id = p_projeto_id;

  UPDATE public.checkout_overrides
  SET executado_em = now()
  WHERE id = p_override_id;

  RETURN QUERY
  SELECT sn.id, sn.codigo_interno
  FROM public.serial_numbers sn
  WHERE sn.id = ANY(v_serial_ids)
  ORDER BY sn.codigo_interno;
END;
$$;

REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) FROM anon;
REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) TO service_role;

REVOKE ALL ON FUNCTION public.checkout_projeto_com_override(
  uuid,
  public.metodo_scan_enum,
  text,
  uuid
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkout_projeto_com_override(
  uuid,
  public.metodo_scan_enum,
  text,
  uuid
) FROM anon;
REVOKE ALL ON FUNCTION public.checkout_projeto_com_override(
  uuid,
  public.metodo_scan_enum,
  text,
  uuid
) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.checkout_projeto_com_override(
  uuid,
  public.metodo_scan_enum,
  text,
  uuid
) TO service_role;
