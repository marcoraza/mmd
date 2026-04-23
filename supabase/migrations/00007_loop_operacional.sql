-- Loop operacional: check-out e check-in atômicos via RPC.
--
-- Objetivo: fechar o ciclo de locação AV. Hoje /projetos faz planejamento
-- (packing list por tipo+quantidade), mas não toca movimentacoes nem muda
-- status dos seriais. Estas funções são o núcleo operacional: transicionam
-- serial_numbers.status entre DISPONIVEL e EM_CAMPO, registrando cada passo
-- em movimentacoes, dentro de uma transação com FOR UPDATE para impedir
-- alocação dupla em aba dupla.
--
-- Convenções:
-- - Shortcut DISPONIVEL -> EM_CAMPO -> DISPONIVEL (pula PACKED/RETORNANDO).
-- - registrado_por vem do caller (hard-coded 'Marco' hoje, auth.user.email
--   quando auth chegar).
-- - Em erro, RAISE EXCEPTION aborta tudo. Transação garante atomicidade.

-- Índices para acelerar timelines por projeto e por serial.
CREATE INDEX IF NOT EXISTS idx_movimentacoes_projeto_timestamp
  ON movimentacoes(projeto_id, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_movimentacoes_serial_timestamp
  ON movimentacoes(serial_number_id, timestamp DESC);

-- ─────────────────────────────────────────────────────────────────────────
-- checkout_projeto
-- ─────────────────────────────────────────────────────────────────────────
-- Transiciona todos os seriais alocados (packing_list.serial_numbers_designados)
-- de DISPONIVEL para EM_CAMPO. Registra uma movimentação SAIDA por serial.
-- Projeto passa a EM_CAMPO.
--
-- Falha se:
-- - projeto não existe ou status != CONFIRMADO
-- - algum packing_list não tem seriais alocados (readiness < 100)
-- - algum serial não está DISPONIVEL
--
-- Retorna serial_id + codigo_interno de cada serial transicionado, pra
-- feedback na UI.
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
  -- Trava o projeto e valida status.
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

  -- Valida readiness: todo packing line precisa ter qtd alocada >= quantidade.
  SELECT count(*) INTO v_packing_missing
  FROM packing_list
  WHERE projeto_id = p_projeto_id
    AND coalesce(array_length(serial_numbers_designados, 1), 0) < quantidade;

  IF v_packing_missing > 0 THEN
    RAISE EXCEPTION 'Packing list incompleto em % linha(s). Aloque todos os seriais antes do check-out.', v_packing_missing;
  END IF;

  -- Junta todos os uuids alocados.
  SELECT coalesce(array_agg(DISTINCT s), ARRAY[]::uuid[]) INTO v_serial_ids
  FROM packing_list pl,
       unnest(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[])) AS s
  WHERE pl.projeto_id = p_projeto_id;

  IF array_length(v_serial_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'Nenhum serial alocado neste projeto';
  END IF;

  -- Trava os seriais e valida DISPONIVEL.
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

  -- Movimentações primeiro (auditoria precede mutação).
  INSERT INTO movimentacoes (
    serial_number_id, projeto_id, tipo,
    status_anterior, status_novo, registrado_por, metodo_scan
  )
  SELECT id, p_projeto_id, 'SAIDA', 'DISPONIVEL', 'EM_CAMPO', p_registrado_por, p_metodo
  FROM serial_numbers
  WHERE id = ANY(v_serial_ids);

  -- Transição dos seriais.
  UPDATE serial_numbers
  SET status = 'EM_CAMPO'
  WHERE id = ANY(v_serial_ids);

  -- Projeto EM_CAMPO.
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

-- ─────────────────────────────────────────────────────────────────────────
-- checkin_projeto
-- ─────────────────────────────────────────────────────────────────────────
-- Recebe de volta os seriais de um projeto EM_CAMPO. Cada item do payload
-- jsonb traz o novo desgaste e se precisa ir pra MANUTENCAO.
--
-- p_items = '[{"serial_id":"uuid","desgaste":4,"needs_maintenance":false}, ...]'
--
-- Transiciona EM_CAMPO -> DISPONIVEL (ou MANUTENCAO), registra RETORNO ou
-- MANUTENCAO em movimentacoes. Projeto passa a FINALIZADO.
CREATE OR REPLACE FUNCTION checkin_projeto(
  p_projeto_id uuid,
  p_metodo metodo_scan_enum,
  p_registrado_por text,
  p_items jsonb
)
RETURNS TABLE(serial_id uuid, codigo_interno text, novo_status status_serial_enum)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_projeto_status status_projeto_enum;
  v_serial_ids uuid[];
  v_bad_status_count int;
BEGIN
  -- Trava projeto e valida status.
  SELECT status INTO v_projeto_status
  FROM projetos
  WHERE id = p_projeto_id
  FOR UPDATE;

  IF v_projeto_status IS NULL THEN
    RAISE EXCEPTION 'Projeto % não encontrado', p_projeto_id;
  END IF;

  IF v_projeto_status <> 'EM_CAMPO' THEN
    RAISE EXCEPTION 'Check-in requer status EM_CAMPO (atual: %)', v_projeto_status;
  END IF;

  IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Lista de seriais vazia';
  END IF;

  -- Extrai ids do payload.
  SELECT array_agg((elem->>'serial_id')::uuid) INTO v_serial_ids
  FROM jsonb_array_elements(p_items) AS elem;

  -- Trava os seriais.
  PERFORM 1 FROM serial_numbers
  WHERE id = ANY(v_serial_ids)
  FOR UPDATE;

  -- Valida que todos estão EM_CAMPO.
  SELECT count(*) INTO v_bad_status_count
  FROM serial_numbers
  WHERE id = ANY(v_serial_ids)
    AND status <> 'EM_CAMPO';

  IF v_bad_status_count > 0 THEN
    RAISE EXCEPTION '% serial(is) não estão EM_CAMPO. Check-in abortado.', v_bad_status_count;
  END IF;

  -- Movimentações (RETORNO ou MANUTENCAO).
  INSERT INTO movimentacoes (
    serial_number_id, projeto_id, tipo,
    status_anterior, status_novo, registrado_por, metodo_scan, notas
  )
  SELECT
    (elem->>'serial_id')::uuid,
    p_projeto_id,
    CASE WHEN (elem->>'needs_maintenance')::boolean THEN 'MANUTENCAO'::tipo_movimentacao_enum
         ELSE 'RETORNO'::tipo_movimentacao_enum END,
    'EM_CAMPO',
    CASE WHEN (elem->>'needs_maintenance')::boolean THEN 'MANUTENCAO'
         ELSE 'DISPONIVEL' END,
    p_registrado_por,
    p_metodo,
    CASE WHEN (elem->>'needs_maintenance')::boolean
         THEN 'Marcado para manutenção no check-in'
         ELSE NULL END
  FROM jsonb_array_elements(p_items) AS elem;

  -- Atualiza seriais (status + desgaste).
  UPDATE serial_numbers sn
  SET status = CASE WHEN (elem.needs_maintenance) THEN 'MANUTENCAO'::status_serial_enum
                    ELSE 'DISPONIVEL'::status_serial_enum END,
      desgaste = elem.desgaste
  FROM (
    SELECT
      (e->>'serial_id')::uuid AS sid,
      greatest(1, least(5, (e->>'desgaste')::int)) AS desgaste,
      coalesce((e->>'needs_maintenance')::boolean, false) AS needs_maintenance
    FROM jsonb_array_elements(p_items) AS e
  ) AS elem
  WHERE sn.id = elem.sid;

  -- Projeto FINALIZADO.
  UPDATE projetos
  SET status = 'FINALIZADO'
  WHERE id = p_projeto_id;

  RETURN QUERY
  SELECT sn.id, sn.codigo_interno, sn.status
  FROM serial_numbers sn
  WHERE sn.id = ANY(v_serial_ids)
  ORDER BY sn.codigo_interno;
END;
$$;

GRANT EXECUTE ON FUNCTION checkout_projeto(uuid, metodo_scan_enum, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION checkin_projeto(uuid, metodo_scan_enum, text, jsonb) TO authenticated, service_role;
