-- Cobertura de falta por aluguel avulso de parceiro.
--
-- O aluguel avulso cobre a necessidade operacional de uma linha do packing,
-- mas não cria item, serial ou patrimônio MMD.

ALTER TABLE public.packing_list
  ADD COLUMN IF NOT EXISTS alugueis_avulsos jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.packing_list
  DROP CONSTRAINT IF EXISTS packing_list_alugueis_avulsos_array;

ALTER TABLE public.packing_list
  ADD CONSTRAINT packing_list_alugueis_avulsos_array
  CHECK (jsonb_typeof(alugueis_avulsos) = 'array');

COMMENT ON COLUMN public.packing_list.alugueis_avulsos IS
  'Coberturas por aluguel avulso de parceiro para este Evento. Não cria unidade própria.';

CREATE OR REPLACE FUNCTION checkout_projeto(
  p_projeto_id uuid,
  p_metodo metodo_scan_enum,
  p_registrado_por text
)
RETURNS TABLE(serial_id uuid, codigo_interno text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_projeto_status status_projeto_enum;
  v_serial_ids uuid[];
  v_bad_status_count int;
  v_packing_missing int;
BEGIN
  SELECT status INTO v_projeto_status
  FROM projetos
  WHERE id = p_projeto_id
  FOR UPDATE;

  IF v_projeto_status IS NULL THEN
    RAISE EXCEPTION 'Projeto % não encontrado', p_projeto_id;
  END IF;

  IF v_projeto_status <> 'CONFIRMADO' THEN
    RAISE EXCEPTION 'Check-out requer status CONFIRMADO (atual: %)', v_projeto_status;
  END IF;

  SELECT count(*) INTO v_packing_missing
  FROM packing_list pl
  WHERE pl.projeto_id = p_projeto_id
    AND (
      coalesce(array_length(pl.serial_numbers_designados, 1), 0) +
      coalesce(
        (
          SELECT sum(greatest((rental->>'quantidade')::int, 0))
          FROM jsonb_array_elements(coalesce(pl.alugueis_avulsos, '[]'::jsonb)) AS rental
          WHERE rental ? 'quantidade'
            AND (rental->>'quantidade') ~ '^[0-9]+$'
        ),
        0
      )
    ) < pl.quantidade;

  IF v_packing_missing > 0 THEN
    RAISE EXCEPTION 'Packing list incompleto em % linha(s). Aloque seriais próprios ou registre aluguel avulso antes do check-out.', v_packing_missing;
  END IF;

  SELECT coalesce(array_agg(DISTINCT s), ARRAY[]::uuid[]) INTO v_serial_ids
  FROM packing_list pl,
       unnest(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[])) AS s
  WHERE pl.projeto_id = p_projeto_id;

  IF coalesce(array_length(v_serial_ids, 1), 0) > 0 THEN
    PERFORM 1 FROM serial_numbers
    WHERE id = ANY(v_serial_ids)
    FOR UPDATE;

    SELECT count(*) INTO v_bad_status_count
    FROM serial_numbers
    WHERE id = ANY(v_serial_ids)
      AND status <> 'DISPONIVEL';

    IF v_bad_status_count > 0 THEN
      RAISE EXCEPTION '% serial(is) não estão DISPONIVEL. Check-out abortado.', v_bad_status_count;
    END IF;

    INSERT INTO movimentacoes (
      serial_number_id, projeto_id, tipo,
      status_anterior, status_novo, registrado_por, metodo_scan
    )
    SELECT id, p_projeto_id, 'SAIDA', 'DISPONIVEL', 'EM_CAMPO', p_registrado_por, p_metodo
    FROM serial_numbers
    WHERE id = ANY(v_serial_ids);

    UPDATE serial_numbers
    SET status = 'EM_CAMPO'
    WHERE id = ANY(v_serial_ids);
  END IF;

  UPDATE projetos
  SET status = 'EM_CAMPO'
  WHERE id = p_projeto_id;

  RETURN QUERY
  SELECT sn.id, sn.codigo_interno
  FROM serial_numbers sn
  WHERE sn.id = ANY(v_serial_ids)
  ORDER BY sn.codigo_interno;
END;
$$;

GRANT EXECUTE ON FUNCTION checkout_projeto(uuid, metodo_scan_enum, text) TO authenticated, service_role;
