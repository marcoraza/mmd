-- ============================================================================
-- EventPro: smoke test das RPCs de negócio (fase 2)
-- ----------------------------------------------------------------------------
-- Pré-requisito: harness + 0001 + 0002 já aplicados no mesmo banco.
--
--   psql -v ON_ERROR_STOP=1 \
--     -f validation/local-harness.sql \
--     -f migrations/0001_initial_schema.sql \
--     -f migrations/0002_rpcs.sql \
--     -f validation/rpc-smoke.sql
--
-- O script é destrutivo por natureza (cria dados) e idempotente por reset: a
-- seção 0 limpa o que ele mesmo cria, então pode rodar N vezes seguidas no
-- mesmo banco.
--
-- Estilo: cada expectativa é um DO block com RAISE EXCEPTION. Falhou, a
-- transação do bloco aborta e o psql com ON_ERROR_STOP=1 para na hora. Passou,
-- imprime um RAISE NOTICE de progresso.
--
-- UUIDs são fixos para os blocos conversarem entre si sem tabela temporária.
--
-- Simulação de sessão: `set_config('request.jwt.claim.sub', ..., true)` é o
-- equivalente de `SET LOCAL request.jwt.claim.sub`, que é o que o
-- `auth.uid()` do harness lê. Vale só até o fim do bloco, que é exatamente a
-- janela de uma requisição autenticada.
-- ============================================================================


-- ============================================================================
-- 0. RESET
-- ============================================================================

DO $$
BEGIN
  DELETE FROM public.rfid_scans
    WHERE projeto_id IN (
      SELECT id FROM public.projetos WHERE codigo_evento LIKE 'SMOKE-%'
    );
  DELETE FROM public.movimentacoes
    WHERE projeto_id IN (
      SELECT id FROM public.projetos WHERE codigo_evento LIKE 'SMOKE-%'
    );
  DELETE FROM public.retorno_pendencias
    WHERE projeto_id IN (
      SELECT id FROM public.projetos WHERE codigo_evento LIKE 'SMOKE-%'
    );
  DELETE FROM public.packing_allocations
    WHERE serial_id IN (
      SELECT sn.id FROM public.serial_numbers sn
      JOIN public.items i ON i.id = sn.item_id
      WHERE i.nome LIKE 'SMOKE %'
    );
  DELETE FROM public.projetos WHERE codigo_evento LIKE 'SMOKE-%';
  DELETE FROM public.movimentacoes
    WHERE serial_number_id IN (
      SELECT sn.id FROM public.serial_numbers sn
      JOIN public.items i ON i.id = sn.item_id
      WHERE i.nome LIKE 'SMOKE %'
    );
  DELETE FROM public.serial_numbers
    WHERE item_id IN (SELECT id FROM public.items WHERE nome LIKE 'SMOKE %');
  DELETE FROM public.items WHERE nome LIKE 'SMOKE %';
  DELETE FROM auth.users WHERE email LIKE 'smoke+%@eventpro.test';
  RAISE NOTICE '[0] reset concluído';
END $$;


-- ============================================================================
-- 1. DADOS MÍNIMOS
-- ============================================================================
-- Um operador (profile criado pelo trigger handle_new_user e promovido a
-- admin), um item de catálogo, 4 unidades, um Evento CONFIRMADO e uma linha de
-- packing com 3 unidades alocadas.

DO $$
DECLARE
  v_user uuid := '11111111-1111-4111-8111-111111111111';
  v_item uuid;
  v_projeto uuid := '44444444-4444-4444-8444-000000000001';
  v_packing uuid := '55555555-5555-4555-8555-000000000001';
BEGIN
  INSERT INTO auth.users (id, email, raw_user_meta_data)
  VALUES (v_user, 'smoke+op@eventpro.test', jsonb_build_object('nome', 'Operador Smoke'));

  UPDATE public.profiles SET role = 'admin' WHERE id = v_user;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user AND role = 'admin') THEN
    RAISE EXCEPTION '[1] trigger handle_new_user não criou o profile do operador';
  END IF;

  INSERT INTO public.items (id, nome, categoria, quantidade_total)
  VALUES ('22222222-2222-4222-8222-000000000001', 'SMOKE Moving Head', 'ILUMINACAO', 4)
  RETURNING id INTO v_item;

  IF (SELECT codigo_interno FROM public.items WHERE id = v_item) <> 'MMD-ILU-0001' THEN
    RAISE EXCEPTION '[1] codigo_interno gerado inesperado: %',
      (SELECT codigo_interno FROM public.items WHERE id = v_item);
  END IF;

  INSERT INTO public.serial_numbers (id, item_id, codigo_interno, tag_rfid, status, desgaste)
  VALUES
    ('33333333-3333-4333-8333-000000000001', v_item, 'SMOKE-SN-0001', 'TAGAAA1111', 'DISPONIVEL', 4),
    ('33333333-3333-4333-8333-000000000002', v_item, 'SMOKE-SN-0002', 'TAGBBB2222', 'DISPONIVEL', 4),
    ('33333333-3333-4333-8333-000000000003', v_item, 'SMOKE-SN-0003', 'TAGCCC3333', 'DISPONIVEL', 4),
    ('33333333-3333-4333-8333-000000000004', v_item, 'SMOKE-SN-0004', NULL, 'MANUTENCAO', 2);

  INSERT INTO public.projetos (id, nome, codigo_evento, status, data_inicio, data_fim)
  VALUES (v_projeto, 'SMOKE Evento Feliz', 'SMOKE-001', 'CONFIRMADO', current_date, current_date + 1);

  INSERT INTO public.packing_list (id, projeto_id, item_id, quantidade)
  VALUES (v_packing, v_projeto, v_item, 3);

  INSERT INTO public.packing_allocations (packing_id, serial_id)
  VALUES
    (v_packing, '33333333-3333-4333-8333-000000000001'),
    (v_packing, '33333333-3333-4333-8333-000000000002'),
    (v_packing, '33333333-3333-4333-8333-000000000003');

  RAISE NOTICE '[1] dados mínimos criados';
END $$;


-- ============================================================================
-- 2. CHECK-OUT FELIZ (com sessão autenticada simulada)
-- ============================================================================
-- Verifica: readiness 100% aceito, 3 unidades para EM_CAMPO, Evento EM_CAMPO,
-- 3 movimentações SAIDA, e autoria derivada de auth.uid() (não do parâmetro).

DO $$
DECLARE
  v_user uuid := '11111111-1111-4111-8111-111111111111';
  v_projeto uuid := '44444444-4444-4444-8444-000000000001';
  v_rows int;
  v_em_campo int;
  v_mov int;
  v_mov_sem_autor int;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', v_user::text, true);

  SELECT count(*) INTO v_rows
  FROM public.checkout_projeto(v_projeto, 'RFID', 'Operador Smoke');

  IF v_rows <> 3 THEN
    RAISE EXCEPTION '[2] check-out devolveu % unidades, esperado 3', v_rows;
  END IF;

  SELECT count(*) INTO v_em_campo
  FROM public.serial_numbers
  WHERE id IN (
    '33333333-3333-4333-8333-000000000001',
    '33333333-3333-4333-8333-000000000002',
    '33333333-3333-4333-8333-000000000003'
  ) AND status = 'EM_CAMPO';

  IF v_em_campo <> 3 THEN
    RAISE EXCEPTION '[2] % unidades EM_CAMPO, esperado 3', v_em_campo;
  END IF;

  IF (SELECT status FROM public.projetos WHERE id = v_projeto) <> 'EM_CAMPO' THEN
    RAISE EXCEPTION '[2] Evento não foi para EM_CAMPO';
  END IF;

  SELECT count(*) INTO v_mov
  FROM public.movimentacoes
  WHERE projeto_id = v_projeto AND tipo = 'SAIDA';

  IF v_mov <> 3 THEN
    RAISE EXCEPTION '[2] % movimentações SAIDA, esperado 3', v_mov;
  END IF;

  SELECT count(*) INTO v_mov_sem_autor
  FROM public.movimentacoes
  WHERE projeto_id = v_projeto AND registrado_por_id IS DISTINCT FROM v_user;

  IF v_mov_sem_autor > 0 THEN
    RAISE EXCEPTION '[2] % movimentações sem registrado_por_id derivado de auth.uid()', v_mov_sem_autor;
  END IF;

  RAISE NOTICE '[2] check-out feliz OK (autoria por auth.uid)';
END $$;


-- ============================================================================
-- 3. CHECK-OUT COM UNIDADE INDISPONÍVEL DEVE FALHAR
-- ============================================================================
-- Evento 2 tem readiness 100% (1 unidade alocada para quantidade 1), mas a
-- unidade está em MANUTENCAO. A saída tem que abortar e não deixar rastro.

DO $$
DECLARE
  v_projeto uuid := '44444444-4444-4444-8444-000000000002';
  v_packing uuid := '55555555-5555-4555-8555-000000000002';
  v_item uuid := '22222222-2222-4222-8222-000000000001';
  v_erro text;
BEGIN
  INSERT INTO public.projetos (id, nome, codigo_evento, status)
  VALUES (v_projeto, 'SMOKE Evento Bloqueado', 'SMOKE-002', 'CONFIRMADO');

  INSERT INTO public.packing_list (id, projeto_id, item_id, quantidade)
  VALUES (v_packing, v_projeto, v_item, 1);

  INSERT INTO public.packing_allocations (packing_id, serial_id)
  VALUES (v_packing, '33333333-3333-4333-8333-000000000004');

  BEGIN
    PERFORM * FROM public.checkout_projeto(
      v_projeto, 'MANUAL', 'Operador Smoke', '11111111-1111-4111-8111-111111111111'
    );
    RAISE EXCEPTION '[3] check-out com unidade em MANUTENCAO deveria ter falhado';
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS v_erro = MESSAGE_TEXT;
      IF v_erro LIKE '[3]%' THEN
        RAISE EXCEPTION '%', v_erro;
      END IF;
      IF v_erro NOT LIKE '%não estão DISPONIVEL%' THEN
        RAISE EXCEPTION '[3] erro inesperado no check-out bloqueado: %', v_erro;
      END IF;
  END;

  IF (SELECT status FROM public.projetos WHERE id = v_projeto) <> 'CONFIRMADO' THEN
    RAISE EXCEPTION '[3] Evento mudou de status apesar da falha';
  END IF;

  IF EXISTS (SELECT 1 FROM public.movimentacoes WHERE projeto_id = v_projeto) THEN
    RAISE EXCEPTION '[3] check-out abortado deixou movimentação gravada';
  END IF;

  RAISE NOTICE '[3] check-out com unidade indisponível bloqueado OK';
END $$;


-- ============================================================================
-- 4. CHECK-OUT DE EVENTO EM PLANEJAMENTO DEVE FALHAR (matriz de status)
-- ============================================================================

DO $$
DECLARE
  v_projeto uuid := '44444444-4444-4444-8444-000000000005';
  v_erro text;
BEGIN
  INSERT INTO public.projetos (id, nome, codigo_evento, status)
  VALUES (v_projeto, 'SMOKE Evento Planejamento', 'SMOKE-005', 'PLANEJAMENTO');

  BEGIN
    PERFORM * FROM public.checkout_projeto(v_projeto, 'MANUAL', 'Operador Smoke');
    RAISE EXCEPTION '[4] check-out de Evento em PLANEJAMENTO deveria ter falhado';
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS v_erro = MESSAGE_TEXT;
      IF v_erro LIKE '[4]%' THEN
        RAISE EXCEPTION '%', v_erro;
      END IF;
      IF v_erro NOT LIKE '%CONFIRMADO ou MONTAGEM%' THEN
        RAISE EXCEPTION '[4] erro inesperado: %', v_erro;
      END IF;
  END;

  RAISE NOTICE '[4] matriz de status do check-out OK';
END $$;


-- ============================================================================
-- 5. CHECK-IN PARCIAL DEVE FALHAR (cobertura total)
-- ============================================================================

DO $$
DECLARE
  v_projeto uuid := '44444444-4444-4444-8444-000000000001';
  v_erro text;
BEGIN
  BEGIN
    PERFORM * FROM public.checkin_projeto(
      v_projeto,
      'RFID',
      'Operador Smoke',
      jsonb_build_array(
        jsonb_build_object('serial_id', '33333333-3333-4333-8333-000000000001', 'resultado', 'OK')
      ),
      '11111111-1111-4111-8111-111111111111'
    );
    RAISE EXCEPTION '[5] check-in parcial deveria ter falhado';
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS v_erro = MESSAGE_TEXT;
      IF v_erro LIKE '[5]%' THEN
        RAISE EXCEPTION '%', v_erro;
      END IF;
      IF v_erro NOT LIKE '%não bate com as unidades que saíram%' THEN
        RAISE EXCEPTION '[5] erro inesperado no check-in parcial: %', v_erro;
      END IF;
  END;

  RAISE NOTICE '[5] cobertura total no check-in OK';
END $$;


-- ============================================================================
-- 6. CHECK-IN COMPLETO: OK + PROBLEMA + NAO_VOLTOU
-- ============================================================================
-- Sem sessão: caminho service role, autoria pelo parâmetro p_registrado_por_id.
-- Verifica os três destinos de status, o desgaste, a alocação liberada só de
-- quem voltou, a pendência aberta e o Evento ainda EM_CAMPO.

DO $$
DECLARE
  v_user uuid := '11111111-1111-4111-8111-111111111111';
  v_projeto uuid := '44444444-4444-4444-8444-000000000001';
  v_rows int;
  v_pendencias int;
BEGIN
  SELECT count(*) INTO v_rows
  FROM public.checkin_projeto(
    v_projeto,
    'RFID',
    'Operador Smoke',
    jsonb_build_array(
      jsonb_build_object(
        'serial_id', '33333333-3333-4333-8333-000000000001',
        'resultado', 'OK',
        'desgaste', 3
      ),
      jsonb_build_object(
        'serial_id', '33333333-3333-4333-8333-000000000002',
        'resultado', 'PROBLEMA',
        'desgaste', 2,
        'observacao', 'Lente trincada no transporte'
      ),
      jsonb_build_object(
        'serial_id', '33333333-3333-4333-8333-000000000003',
        'resultado', 'NAO_VOLTOU',
        'observacao', 'Não apareceu na conferência do galpão'
      )
    ),
    v_user
  );

  IF v_rows <> 3 THEN
    RAISE EXCEPTION '[6] check-in devolveu % linhas, esperado 3', v_rows;
  END IF;

  IF (SELECT status FROM public.serial_numbers WHERE id = '33333333-3333-4333-8333-000000000001')
     <> 'DISPONIVEL' THEN
    RAISE EXCEPTION '[6] unidade OK não voltou para DISPONIVEL';
  END IF;

  IF (SELECT desgaste FROM public.serial_numbers WHERE id = '33333333-3333-4333-8333-000000000001')
     <> 3 THEN
    RAISE EXCEPTION '[6] desgaste da unidade OK não foi atualizado';
  END IF;

  IF (SELECT status FROM public.serial_numbers WHERE id = '33333333-3333-4333-8333-000000000002')
     <> 'MANUTENCAO' THEN
    RAISE EXCEPTION '[6] unidade com PROBLEMA não foi para MANUTENCAO';
  END IF;

  IF (SELECT status FROM public.serial_numbers WHERE id = '33333333-3333-4333-8333-000000000003')
     <> 'RETORNANDO' THEN
    RAISE EXCEPTION '[6] unidade NAO_VOLTOU não ficou em RETORNANDO';
  END IF;

  IF (SELECT desgaste FROM public.serial_numbers WHERE id = '33333333-3333-4333-8333-000000000003')
     <> 4 THEN
    RAISE EXCEPTION '[6] desgaste da unidade NAO_VOLTOU não deveria mudar';
  END IF;

  -- Alocação: sai quem voltou, fica quem não voltou.
  IF EXISTS (
    SELECT 1 FROM public.packing_allocations
    WHERE serial_id IN (
      '33333333-3333-4333-8333-000000000001',
      '33333333-3333-4333-8333-000000000002'
    )
  ) THEN
    RAISE EXCEPTION '[6] alocação de unidade devolvida não foi liberada';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.packing_allocations
    WHERE serial_id = '33333333-3333-4333-8333-000000000003'
  ) THEN
    RAISE EXCEPTION '[6] alocação da unidade NAO_VOLTOU deveria ficar até a resolução';
  END IF;

  SELECT count(*) INTO v_pendencias
  FROM public.retorno_pendencias
  WHERE projeto_id = v_projeto AND status = 'ABERTA';

  IF v_pendencias <> 1 THEN
    RAISE EXCEPTION '[6] % pendências abertas, esperado 1', v_pendencias;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.retorno_pendencias
    WHERE projeto_id = v_projeto AND registrado_por_id = v_user
  ) THEN
    RAISE EXCEPTION '[6] pendência sem registrado_por_id do service role';
  END IF;

  IF (SELECT status FROM public.projetos WHERE id = v_projeto) <> 'EM_CAMPO' THEN
    RAISE EXCEPTION '[6] Evento com pendência aberta não pode finalizar';
  END IF;

  RAISE NOTICE '[6] check-in OK + PROBLEMA + NAO_VOLTOU OK, Evento segue EM_CAMPO';
END $$;


-- ============================================================================
-- 7. RESOLUÇÃO DA PENDÊNCIA FINALIZA O EVENTO
-- ============================================================================

DO $$
DECLARE
  v_user uuid := '11111111-1111-4111-8111-111111111111';
  v_projeto uuid := '44444444-4444-4444-8444-000000000001';
  v_pendencia uuid;
  v_status_pendencia text;
  v_status_serial public.status_serial_enum;
BEGIN
  SELECT id INTO v_pendencia
  FROM public.retorno_pendencias
  WHERE projeto_id = v_projeto AND status = 'ABERTA';

  SELECT r.status_pendencia, r.novo_status
  INTO v_status_pendencia, v_status_serial
  FROM public.resolver_retorno_pendencia(
    v_pendencia, 'ENCONTRADA', 'Achada no caminhão na volta', 'Operador Smoke', v_user
  ) r;

  IF v_status_pendencia <> 'ENCONTRADA' THEN
    RAISE EXCEPTION '[7] status de pendência devolvido: %', v_status_pendencia;
  END IF;

  IF v_status_serial <> 'DISPONIVEL' THEN
    RAISE EXCEPTION '[7] unidade encontrada deveria voltar para DISPONIVEL, veio %', v_status_serial;
  END IF;

  IF (SELECT status FROM public.serial_numbers WHERE id = '33333333-3333-4333-8333-000000000003')
     <> 'DISPONIVEL' THEN
    RAISE EXCEPTION '[7] unidade não voltou para DISPONIVEL no banco';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.packing_allocations
    WHERE serial_id = '33333333-3333-4333-8333-000000000003'
  ) THEN
    RAISE EXCEPTION '[7] alocação não foi liberada na resolução da pendência';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.retorno_pendencias
    WHERE id = v_pendencia
      AND status = 'ENCONTRADA'
      AND resolvido_por_id = v_user
      AND resolved_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION '[7] pendência não foi carimbada com resolução e autor';
  END IF;

  IF (SELECT status FROM public.projetos WHERE id = v_projeto) <> 'FINALIZADO' THEN
    RAISE EXCEPTION '[7] Evento sem pendência aberta deveria estar FINALIZADO, está %',
      (SELECT status FROM public.projetos WHERE id = v_projeto);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.movimentacoes
    WHERE serial_number_id = '33333333-3333-4333-8333-000000000003'
      AND tipo = 'RETORNO'
      AND notas = 'Achada no caminhão na volta'
  ) THEN
    RAISE EXCEPTION '[7] resolução não gravou movimentação';
  END IF;

  RAISE NOTICE '[7] resolução de pendência finaliza o Evento OK';
END $$;


-- ============================================================================
-- 8. auto_allocate_packing: ordem FIFO, idempotência e não remoção
-- ============================================================================
-- Item novo com 3 unidades: uma nunca movimentada, uma movimentada há muito
-- tempo, uma movimentada ontem. A linha pede 2. A escolha esperada é a nunca
-- movimentada e a mais antiga, nessa ordem de preferência.

DO $$
DECLARE
  v_item uuid := '22222222-2222-4222-8222-000000000002';
  v_projeto uuid := '44444444-4444-4444-8444-000000000003';
  v_packing uuid := '55555555-5555-4555-8555-000000000003';
  v_nunca uuid := '33333333-3333-4333-8333-000000000011';
  v_antiga uuid := '33333333-3333-4333-8333-000000000012';
  v_recente uuid := '33333333-3333-4333-8333-000000000013';
  v_alocados int;
  v_segunda int;
BEGIN
  INSERT INTO public.items (id, nome, categoria, quantidade_total)
  VALUES (v_item, 'SMOKE Caixa Ativa', 'AUDIO', 3);

  INSERT INTO public.serial_numbers (id, item_id, codigo_interno, status, desgaste)
  VALUES
    (v_nunca,   v_item, 'SMOKE-SN-0011', 'DISPONIVEL', 4),
    (v_antiga,  v_item, 'SMOKE-SN-0012', 'DISPONIVEL', 4),
    (v_recente, v_item, 'SMOKE-SN-0013', 'DISPONIVEL', 4);

  INSERT INTO public.movimentacoes (serial_number_id, tipo, registrado_por, timestamp)
  VALUES
    (v_antiga,  'RETORNO', 'Operador Smoke', now() - interval '200 days'),
    (v_recente, 'RETORNO', 'Operador Smoke', now() - interval '1 day');

  INSERT INTO public.projetos (id, nome, codigo_evento, status)
  VALUES (v_projeto, 'SMOKE Evento Auto Alocação', 'SMOKE-003', 'CONFIRMADO');

  INSERT INTO public.packing_list (id, projeto_id, item_id, quantidade)
  VALUES (v_packing, v_projeto, v_item, 2);

  SELECT count(*) INTO v_alocados
  FROM public.auto_allocate_packing(v_packing, 'Operador Smoke', '11111111-1111-4111-8111-111111111111');

  IF v_alocados <> 2 THEN
    RAISE EXCEPTION '[8] auto_allocate alocou %, esperado 2', v_alocados;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.packing_allocations WHERE serial_id = v_nunca) THEN
    RAISE EXCEPTION '[8] unidade nunca movimentada deveria vir primeiro';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.packing_allocations WHERE serial_id = v_antiga) THEN
    RAISE EXCEPTION '[8] unidade movimentada há mais tempo deveria ser a segunda escolha';
  END IF;

  IF EXISTS (SELECT 1 FROM public.packing_allocations WHERE serial_id = v_recente) THEN
    RAISE EXCEPTION '[8] unidade movimentada ontem não deveria ser escolhida';
  END IF;

  -- Idempotência: linha completa, segunda chamada não faz nada e não falha.
  SELECT count(*) INTO v_segunda
  FROM public.auto_allocate_packing(v_packing, 'Operador Smoke', '11111111-1111-4111-8111-111111111111');

  IF v_segunda <> 0 THEN
    RAISE EXCEPTION '[8] segunda chamada alocou % linhas, esperado 0', v_segunda;
  END IF;

  IF (SELECT count(*) FROM public.packing_allocations WHERE packing_id = v_packing) <> 2 THEN
    RAISE EXCEPTION '[8] auto_allocate mexeu nas alocações existentes';
  END IF;

  RAISE NOTICE '[8] auto_allocate_packing OK (FIFO, idempotente, aditivo)';
END $$;


-- ============================================================================
-- 9. conferencia_rfid_evento: as 4 classificações
-- ============================================================================
-- Evento 4 com duas unidades alocadas (uma com tag lida, uma sem leitura), uma
-- unidade conhecida fora do Evento e uma tag sem dono.
--
-- A primeira tag entra suja de propósito ('  tag-aaa:1111  ') para exercitar a
-- normalização (trim, upper, remoção de espaço, dois-pontos e hífen).

DO $$
DECLARE
  v_item uuid := '22222222-2222-4222-8222-000000000001';
  v_projeto uuid := '44444444-4444-4444-8444-000000000004';
  v_packing uuid := '55555555-5555-4555-8555-000000000004';
  v_confirmado uuid := '33333333-3333-4333-8333-000000000001';
  v_faltante uuid := '33333333-3333-4333-8333-000000000002';
  v_extra uuid := '33333333-3333-4333-8333-000000000003';
  v_linha record;
  v_scans int;
  v_scans_desconhecidos int;
  v_total int;
BEGIN
  INSERT INTO public.projetos (id, nome, codigo_evento, status)
  VALUES (v_projeto, 'SMOKE Evento Conferência', 'SMOKE-004', 'CONFIRMADO');

  INSERT INTO public.packing_list (id, projeto_id, item_id, quantidade)
  VALUES (v_packing, v_projeto, v_item, 2);

  INSERT INTO public.packing_allocations (packing_id, serial_id)
  VALUES (v_packing, v_confirmado), (v_packing, v_faltante);

  CREATE TEMP TABLE smoke_conferencia ON COMMIT DROP AS
  SELECT * FROM public.conferencia_rfid_evento(
    v_projeto,
    ARRAY['  tag-aaa:1111  ', 'TAGCCC3333', 'TAGZZZ9999', 'TAGAAA1111'],
    'CONFERENCIA',
    'Operador Smoke'
  );

  SELECT count(*) INTO v_total FROM smoke_conferencia;
  IF v_total <> 4 THEN
    RAISE EXCEPTION '[9] conferência devolveu % linhas, esperado 4', v_total;
  END IF;

  SELECT * INTO v_linha FROM smoke_conferencia WHERE classificacao = 'CONFIRMADO';
  IF NOT FOUND OR v_linha.serial_id <> v_confirmado OR v_linha.tag_rfid <> 'TAGAAA1111' THEN
    RAISE EXCEPTION '[9] CONFIRMADO incorreto (normalização ou cruzamento falhou)';
  END IF;
  IF v_linha.scan_id IS NULL THEN
    RAISE EXCEPTION '[9] CONFIRMADO sem scan_id';
  END IF;

  SELECT * INTO v_linha FROM smoke_conferencia WHERE classificacao = 'FALTANTE';
  IF NOT FOUND OR v_linha.serial_id <> v_faltante THEN
    RAISE EXCEPTION '[9] FALTANTE incorreto';
  END IF;
  IF v_linha.scan_id IS NOT NULL OR v_linha.ordem IS NOT NULL THEN
    RAISE EXCEPTION '[9] FALTANTE não pode ter scan_id nem ordem de leitura';
  END IF;

  SELECT * INTO v_linha FROM smoke_conferencia WHERE classificacao = 'EXTRA';
  IF NOT FOUND OR v_linha.serial_id <> v_extra THEN
    RAISE EXCEPTION '[9] EXTRA incorreto';
  END IF;

  SELECT * INTO v_linha FROM smoke_conferencia WHERE classificacao = 'DESCONHECIDA';
  IF NOT FOUND OR v_linha.tag_rfid <> 'TAGZZZ9999' OR v_linha.serial_id IS NOT NULL THEN
    RAISE EXCEPTION '[9] DESCONHECIDA incorreta';
  END IF;

  -- Telemetria: 3 tags distintas lidas (a quarta é duplicata normalizada da
  -- primeira), todas gravadas, inclusive a desconhecida com nota.
  SELECT count(*) INTO v_scans
  FROM public.rfid_scans
  WHERE projeto_id = v_projeto AND contexto = 'CONFERENCIA';

  IF v_scans <> 3 THEN
    RAISE EXCEPTION '[9] % scans gravados, esperado 3', v_scans;
  END IF;

  SELECT count(*) INTO v_scans_desconhecidos
  FROM public.rfid_scans
  WHERE projeto_id = v_projeto
    AND serial_number_id IS NULL
    AND notas = 'Tag RFID não reconhecida';

  IF v_scans_desconhecidos <> 1 THEN
    RAISE EXCEPTION '[9] tag desconhecida não foi gravada com nota';
  END IF;

  -- Conferência não muta status de unidade nem de Evento.
  IF (SELECT status FROM public.projetos WHERE id = v_projeto) <> 'CONFIRMADO' THEN
    RAISE EXCEPTION '[9] conferência mudou o status do Evento';
  END IF;

  IF (SELECT status FROM public.serial_numbers WHERE id = v_confirmado) <> 'DISPONIVEL' THEN
    RAISE EXCEPTION '[9] conferência mudou o status da unidade';
  END IF;

  RAISE NOTICE '[9] conferencia_rfid_evento OK (4 classificações, scans gravados, sem mutação)';
END $$;


-- ============================================================================
-- 10. AUTORIA: label obrigatório e id inexistente recusado
-- ============================================================================

DO $$
DECLARE
  v_projeto uuid := '44444444-4444-4444-8444-000000000002';
  v_erro text;
BEGIN
  BEGIN
    PERFORM * FROM public.checkout_projeto(v_projeto, 'MANUAL', '   ');
    RAISE EXCEPTION '[10] label vazio deveria ter falhado';
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS v_erro = MESSAGE_TEXT;
      IF v_erro LIKE '[10]%' THEN RAISE EXCEPTION '%', v_erro; END IF;
      IF v_erro NOT LIKE '%registrado_por é obrigatório%' THEN
        RAISE EXCEPTION '[10] erro inesperado para label vazio: %', v_erro;
      END IF;
  END;

  BEGIN
    PERFORM * FROM public.checkout_projeto(
      v_projeto, 'MANUAL', 'Fantasma', '99999999-9999-4999-8999-999999999999'
    );
    RAISE EXCEPTION '[10] autor inexistente deveria ter falhado';
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS v_erro = MESSAGE_TEXT;
      IF v_erro LIKE '[10]%' THEN RAISE EXCEPTION '%', v_erro; END IF;
      IF v_erro NOT LIKE '%não corresponde a nenhum profile%' THEN
        RAISE EXCEPTION '[10] erro inesperado para autor inexistente: %', v_erro;
      END IF;
  END;

  RAISE NOTICE '[10] autoria validada OK';
END $$;


-- ============================================================================
-- 11. CHECK-OUT COM OVERRIDE: pula readiness, não pula unidade indisponível
-- ============================================================================

DO $$
DECLARE
  v_user uuid := '11111111-1111-4111-8111-111111111111';
  v_item uuid := '22222222-2222-4222-8222-000000000002';
  v_projeto uuid := '44444444-4444-4444-8444-000000000006';
  v_packing uuid := '55555555-5555-4555-8555-000000000006';
  v_serial uuid := '33333333-3333-4333-8333-000000000014';
  v_override uuid;
  v_rows int;
BEGIN
  INSERT INTO public.serial_numbers (id, item_id, codigo_interno, status)
  VALUES (v_serial, v_item, 'SMOKE-SN-0014', 'DISPONIVEL');

  INSERT INTO public.projetos (id, nome, codigo_evento, status)
  VALUES (v_projeto, 'SMOKE Evento Override', 'SMOKE-006', 'MONTAGEM');

  -- Linha pede 3 e só tem 1 alocada: readiness reprova, override libera.
  INSERT INTO public.packing_list (id, projeto_id, item_id, quantidade)
  VALUES (v_packing, v_projeto, v_item, 3);

  INSERT INTO public.packing_allocations (packing_id, serial_id)
  VALUES (v_packing, v_serial);

  INSERT INTO public.checkout_overrides (projeto_id, motivo, readiness_pct, registrado_por, registrado_por_id)
  VALUES (v_projeto, 'Cliente aceitou sair com carga parcial e completar no local', 33, 'Operador Smoke', v_user)
  RETURNING id INTO v_override;

  SELECT count(*) INTO v_rows
  FROM public.checkout_projeto_com_override(v_projeto, 'MANUAL', 'Operador Smoke', v_override, v_user);

  IF v_rows <> 1 THEN
    RAISE EXCEPTION '[11] override devolveu % unidades, esperado 1', v_rows;
  END IF;

  IF (SELECT status FROM public.projetos WHERE id = v_projeto) <> 'EM_CAMPO' THEN
    RAISE EXCEPTION '[11] Evento em MONTAGEM não saiu com override';
  END IF;

  IF (SELECT executado_em FROM public.checkout_overrides WHERE id = v_override) IS NULL THEN
    RAISE EXCEPTION '[11] override não foi carimbado com executado_em';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.movimentacoes
    WHERE serial_number_id = v_serial
      AND notas LIKE 'Saída forçada por override auditado:%'
      AND registrado_por_id = v_user
  ) THEN
    RAISE EXCEPTION '[11] movimentação de override sem nota ou sem autor';
  END IF;

  RAISE NOTICE '[11] check-out com override OK (MONTAGEM aceito, readiness pulado)';
END $$;


-- ============================================================================
-- 12. GRANTS: nenhuma das 6 RPCs executável por anon ou authenticated
-- ============================================================================

DO $$
DECLARE
  v_fn text;
  v_role text;
BEGIN
  FOREACH v_fn IN ARRAY ARRAY[
    'checkout_projeto',
    'checkout_projeto_com_override',
    'checkin_projeto',
    'resolver_retorno_pendencia',
    'auto_allocate_packing',
    'conferencia_rfid_evento'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = v_fn
    ) THEN
      RAISE EXCEPTION '[12] função % não existe', v_fn;
    END IF;

    FOREACH v_role IN ARRAY ARRAY['anon', 'authenticated', 'public'] LOOP
      IF has_function_privilege(v_role, ('public.' || v_fn)::regproc, 'EXECUTE') THEN
        RAISE EXCEPTION '[12] % pode executar public.% (spoofing de registrado_por)', v_role, v_fn;
      END IF;
    END LOOP;

    IF NOT has_function_privilege('service_role', ('public.' || v_fn)::regproc, 'EXECUTE') THEN
      RAISE EXCEPTION '[12] service_role não pode executar public.%', v_fn;
    END IF;
  END LOOP;

  RAISE NOTICE '[12] grants OK (só service_role executa)';
END $$;


DO $$
BEGIN
  RAISE NOTICE '=== SMOKE DAS RPCs: TODOS OS BLOCOS PASSARAM ===';
END $$;
