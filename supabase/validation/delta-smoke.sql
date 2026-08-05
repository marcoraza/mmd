-- ============================================================================
-- EventPro: smoke das migrations delta (convergência do banco legado)
-- ----------------------------------------------------------------------------
-- Pressupõe um banco com:
--   1. o harness local (`validation/local-harness.sql`);
--   2. a cadeia LEGADA completa (`migrations/00001..20260805194500`);
--   3. as deltas (`migrations/202608060*`).
--
-- Rodar:
--   psql -v ON_ERROR_STOP=1 \
--     -f validation/local-harness.sql \
--     -f migrations/00001_initial_schema.sql ... (cadeia legada em ordem) \
--     -f migrations/20260806010000_packing_allocations.sql \
--     -f migrations/20260806011000_app_config_codigo_prefix.sql \
--     -f migrations/20260806012000_colunas_autoria.sql \
--     -f migrations/20260806013000_packing_list_integridade.sql \
--     -f migrations/20260806014000_rpcs_eventpro.sql \
--     -f validation/delta-smoke.sql
--
-- Tudo roda dentro de uma transação que termina em ROLLBACK: o arquivo é
-- re-executável e não deixa resíduo. Cada asserção é um bloco DO com
-- RAISE EXCEPTION, então qualquer falha aborta com ON_ERROR_STOP.
--
-- O que este arquivo cobre (as regras que só existem por causa da convivência
-- com o web app legado, mais as regras novas que ninguém tinha ainda):
--   1. backfill do uuid[] pré-existente, com descarte de órfão;
--   2. UPDATE legado no array refletindo em packing_allocations;
--   3. conflito de alocação: o array não rouba unidade de outra linha;
--   4. check-out lendo a tabela, não o array;
--   5. autoria gravada com FK real;
--   6. dual-write de auto_allocate_packing aparecendo no array;
--   7. conferência RFID com as 4 classificações e tag de lote legado;
--   8. check-in e resolução de pendência liberando alocação e reprojetando o
--      array.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Fixtures mínimas
-- ----------------------------------------------------------------------------

INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES ('11111111-1111-4111-8111-111111111111', 'operador@smoke.test', '{"nome":"Smoke Operador"}'::jsonb);

INSERT INTO public.items (id, nome, categoria, codigo_interno, quantidade_total)
VALUES
  ('22222222-2222-4222-8222-222222222201', 'Moving Head Smoke', 'ILUMINACAO', 'SMK-ILU-0001', 5),
  ('22222222-2222-4222-8222-222222222202', 'Cabo Smoke',        'CABO',       'SMK-CAB-0001', 1);

INSERT INTO public.serial_numbers (id, item_id, codigo_interno, tag_rfid, status, desgaste)
VALUES
  ('33333333-3333-4333-8333-000000000001', '22222222-2222-4222-8222-222222222201', 'SMK-ILU-0001-01', 'TAGS1', 'DISPONIVEL', 3),
  ('33333333-3333-4333-8333-000000000002', '22222222-2222-4222-8222-222222222201', 'SMK-ILU-0001-02', 'TAGS2', 'DISPONIVEL', 3),
  ('33333333-3333-4333-8333-000000000003', '22222222-2222-4222-8222-222222222201', 'SMK-ILU-0001-03', 'TAGS3', 'DISPONIVEL', 3),
  ('33333333-3333-4333-8333-000000000004', '22222222-2222-4222-8222-222222222201', 'SMK-ILU-0001-04', 'TAGS4', 'DISPONIVEL', 3),
  ('33333333-3333-4333-8333-000000000005', '22222222-2222-4222-8222-222222222201', 'SMK-ILU-0001-05', 'TAGS5', 'DISPONIVEL', 3),
  ('33333333-3333-4333-8333-000000000006', '22222222-2222-4222-8222-222222222202', 'SMK-CAB-0001-01', 'TAGS6', 'DISPONIVEL', 3);

-- Lote legado: existe no banco real e nunca deve ser reconhecido como alvo
-- operacional (política unit-only, MAR-187).
INSERT INTO public.lotes (id, item_id, codigo_lote, quantidade, tag_rfid, status)
VALUES ('66666666-6666-4666-8666-000000000001', '22222222-2222-4222-8222-222222222202', 'LOTE-SMOKE-1', 10, 'TAGLOTE01', 'DISPONIVEL');

INSERT INTO public.projetos (id, nome, cliente, status)
VALUES
  ('44444444-4444-4444-8444-000000000001', 'Evento Smoke 1', 'Cliente Smoke', 'CONFIRMADO'),
  ('44444444-4444-4444-8444-000000000002', 'Evento Smoke 2', 'Cliente Smoke', 'CONFIRMADO'),
  ('44444444-4444-4444-8444-000000000003', 'Evento Smoke 3', 'Cliente Smoke', 'CONFIRMADO');

INSERT INTO public.packing_list (id, projeto_id, item_id, quantidade)
VALUES
  ('55555555-5555-4555-8555-000000000001', '44444444-4444-4444-8444-000000000001', '22222222-2222-4222-8222-222222222201', 2),
  ('55555555-5555-4555-8555-000000000002', '44444444-4444-4444-8444-000000000002', '22222222-2222-4222-8222-222222222201', 2),
  ('55555555-5555-4555-8555-000000000003', '44444444-4444-4444-8444-000000000003', '22222222-2222-4222-8222-222222222201', 1);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = '11111111-1111-4111-8111-111111111111') THEN
    RAISE EXCEPTION 'fixture: profile não foi criado pelo trigger handle_new_user';
  END IF;
  RAISE NOTICE 'fixtures OK';
END $$;


-- ============================================================================
-- 1. Backfill de um uuid[] pré-existente, com descarte de órfão
-- ============================================================================
-- O backfill real roda dentro da migration 20260806010000, antes de existir
-- qualquer fixture. Para exercitar a mesma lógica sobre dado controlado, o
-- bloco abaixo recria a situação "array preenchido, tabela vazia" (desligando
-- o trigger de sincronização, que é o que impede essa situação de existir
-- depois da delta) e reexecuta o MESMO statement de backfill da migration.
--
-- O array recebe um uuid órfão de propósito: é o resíduo clássico do array sem
-- integridade referencial, e o backfill tem que descartá-lo em vez de estourar
-- a FK.

ALTER TABLE public.packing_list DISABLE TRIGGER trg_packing_list_sync_allocations;

UPDATE public.packing_list
SET serial_numbers_designados = ARRAY[
  '33333333-3333-4333-8333-000000000001'::uuid,
  '99999999-9999-4999-8999-999999999999'::uuid  -- órfão: não existe em serial_numbers
]
WHERE id = '55555555-5555-4555-8555-000000000001';

ALTER TABLE public.packing_list ENABLE TRIGGER trg_packing_list_sync_allocations;

-- Statement idêntico ao da migration 20260806010000, seção 3.
INSERT INTO public.packing_allocations (packing_id, serial_id)
SELECT v.packing_id, v.serial_id
FROM (
  SELECT DISTINCT ON (alocado.serial_id)
    alocado.serial_id,
    pl.id AS packing_id
  FROM public.packing_list pl
  CROSS JOIN LATERAL unnest(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[]))
    AS alocado(serial_id)
  JOIN public.serial_numbers sn ON sn.id = alocado.serial_id
  ORDER BY alocado.serial_id, pl.projeto_id, pl.id
) v
ON CONFLICT ON CONSTRAINT packing_allocations_serial_unique DO NOTHING;

DO $$
DECLARE
  v_total int;
  v_s1 int;
  v_orfao int;
BEGIN
  SELECT count(*) INTO v_total
  FROM public.packing_allocations
  WHERE packing_id = '55555555-5555-4555-8555-000000000001';

  SELECT count(*) INTO v_s1
  FROM public.packing_allocations
  WHERE packing_id = '55555555-5555-4555-8555-000000000001'
    AND serial_id = '33333333-3333-4333-8333-000000000001';

  SELECT count(*) INTO v_orfao
  FROM public.packing_allocations
  WHERE serial_id = '99999999-9999-4999-8999-999999999999';

  IF v_total <> 1 THEN
    RAISE EXCEPTION 'smoke 1: esperava 1 alocação backfilled, veio %', v_total;
  END IF;
  IF v_s1 <> 1 THEN
    RAISE EXCEPTION 'smoke 1: serial válido do array não foi backfilled';
  END IF;
  IF v_orfao <> 0 THEN
    RAISE EXCEPTION 'smoke 1: uuid órfão foi backfilled, deveria ter sido descartado';
  END IF;

  RAISE NOTICE 'smoke 1 OK: backfill do uuid[] com descarte de órfão';
END $$;


-- ============================================================================
-- 2. UPDATE legado no array reflete na tabela
-- ============================================================================
-- É exatamente o que `setAllocation`, `autoAllocate` e `releaseSerial` do web
-- legado fazem: UPDATE direto do array inteiro.

UPDATE public.packing_list
SET serial_numbers_designados = ARRAY[
  '33333333-3333-4333-8333-000000000001'::uuid,
  '33333333-3333-4333-8333-000000000002'::uuid
]
WHERE id = '55555555-5555-4555-8555-000000000001';

DO $$
DECLARE v_ids uuid[];
BEGIN
  SELECT array_agg(pa.serial_id ORDER BY pa.serial_id) INTO v_ids
  FROM public.packing_allocations pa
  WHERE pa.packing_id = '55555555-5555-4555-8555-000000000001';

  IF v_ids IS DISTINCT FROM ARRAY[
    '33333333-3333-4333-8333-000000000001'::uuid,
    '33333333-3333-4333-8333-000000000002'::uuid
  ] THEN
    RAISE EXCEPTION 'smoke 2a: inserção pelo array não sincronizou. Tabela: %', v_ids;
  END IF;
  RAISE NOTICE 'smoke 2a OK: array -> tabela (inserção)';
END $$;

-- Remoção pelo array, com um órfão junto: o trigger tem que tolerar o lixo em
-- vez de quebrar a escrita do app legado (que não sabe tratar esse erro).
UPDATE public.packing_list
SET serial_numbers_designados = ARRAY[
  '33333333-3333-4333-8333-000000000002'::uuid,
  '99999999-9999-4999-8999-999999999999'::uuid
]
WHERE id = '55555555-5555-4555-8555-000000000001';

DO $$
DECLARE v_ids uuid[];
BEGIN
  SELECT array_agg(pa.serial_id) INTO v_ids
  FROM public.packing_allocations pa
  WHERE pa.packing_id = '55555555-5555-4555-8555-000000000001';

  IF v_ids IS DISTINCT FROM ARRAY['33333333-3333-4333-8333-000000000002'::uuid] THEN
    RAISE EXCEPTION 'smoke 2b: remoção pelo array não sincronizou. Tabela: %', v_ids;
  END IF;
  RAISE NOTICE 'smoke 2b OK: array -> tabela (remoção e tolerância a órfão)';
END $$;


-- ============================================================================
-- 3. Conflito: o array não rouba unidade alocada em outra linha
-- ============================================================================
-- A UNIQUE (serial_id) é a invariante que impede prometer o mesmo equipamento
-- para dois clientes. Quando o array legado tenta furá-la, a alocação vigente
-- vence e o trigger avisa (WARNING), sem quebrar a escrita.

UPDATE public.packing_list
SET serial_numbers_designados = ARRAY['33333333-3333-4333-8333-000000000002'::uuid]
WHERE id = '55555555-5555-4555-8555-000000000003';

DO $$
DECLARE v_packing uuid;
BEGIN
  SELECT pa.packing_id INTO v_packing
  FROM public.packing_allocations pa
  WHERE pa.serial_id = '33333333-3333-4333-8333-000000000002';

  IF v_packing <> '55555555-5555-4555-8555-000000000001' THEN
    RAISE EXCEPTION 'smoke 3: alocação foi roubada por outra linha (packing %)', v_packing;
  END IF;
  RAISE NOTICE 'smoke 3 OK: alocação vigente vence o array conflitante';
END $$;

-- Limpa a tentativa para não poluir os testes seguintes.
UPDATE public.packing_list
SET serial_numbers_designados = ARRAY[]::uuid[]
WHERE id = '55555555-5555-4555-8555-000000000003';


-- ============================================================================
-- 4. Check-out lê packing_allocations, não o array
-- ============================================================================
-- Prova por divergência deliberada: o array fica VAZIO e a tabela fica com as
-- duas unidades. Se o check-out ainda lesse o array, falharia por readiness.

ALTER TABLE public.packing_list DISABLE TRIGGER trg_packing_list_sync_allocations;
UPDATE public.packing_list
SET serial_numbers_designados = ARRAY[]::uuid[]
WHERE id = '55555555-5555-4555-8555-000000000001';
ALTER TABLE public.packing_list ENABLE TRIGGER trg_packing_list_sync_allocations;

INSERT INTO public.packing_allocations (packing_id, serial_id)
VALUES ('55555555-5555-4555-8555-000000000001', '33333333-3333-4333-8333-000000000001')
ON CONFLICT ON CONSTRAINT packing_allocations_serial_unique DO NOTHING;

DO $$
DECLARE
  v_saidas int;
  v_status public.status_projeto_enum;
  v_em_campo int;
BEGIN
  PERFORM public.checkout_projeto(
    '44444444-4444-4444-8444-000000000001',
    'MANUAL',
    'Smoke Operador',
    '11111111-1111-4111-8111-111111111111'
  );

  SELECT count(*) INTO v_saidas
  FROM public.movimentacoes
  WHERE projeto_id = '44444444-4444-4444-8444-000000000001' AND tipo = 'SAIDA';

  SELECT status INTO v_status FROM public.projetos
  WHERE id = '44444444-4444-4444-8444-000000000001';

  SELECT count(*) INTO v_em_campo
  FROM public.serial_numbers
  WHERE id IN ('33333333-3333-4333-8333-000000000001', '33333333-3333-4333-8333-000000000002')
    AND status = 'EM_CAMPO';

  IF v_saidas <> 2 THEN
    RAISE EXCEPTION 'smoke 4: esperava 2 movimentações SAIDA, veio %', v_saidas;
  END IF;
  IF v_status <> 'EM_CAMPO' THEN
    RAISE EXCEPTION 'smoke 4: evento deveria estar EM_CAMPO, está %', v_status;
  END IF;
  IF v_em_campo <> 2 THEN
    RAISE EXCEPTION 'smoke 4: esperava 2 unidades EM_CAMPO, veio %', v_em_campo;
  END IF;

  RAISE NOTICE 'smoke 4 OK: check-out leu packing_allocations com o array vazio';
END $$;


-- ============================================================================
-- 5. Autoria gravada com FK real
-- ============================================================================

DO $$
DECLARE
  v_sem_autor int;
  v_label text;
  v_falhou boolean := false;
BEGIN
  SELECT count(*) INTO v_sem_autor
  FROM public.movimentacoes
  WHERE projeto_id = '44444444-4444-4444-8444-000000000001'
    AND registrado_por_id IS DISTINCT FROM '11111111-1111-4111-8111-111111111111';

  IF v_sem_autor > 0 THEN
    RAISE EXCEPTION 'smoke 5a: % movimentação(ões) sem registrado_por_id correto', v_sem_autor;
  END IF;

  SELECT DISTINCT registrado_por INTO v_label
  FROM public.movimentacoes
  WHERE projeto_id = '44444444-4444-4444-8444-000000000001';

  IF v_label <> 'Smoke Operador' THEN
    RAISE EXCEPTION 'smoke 5a: label de autoria não foi congelado (veio %)', v_label;
  END IF;

  -- FK: id que não existe em profiles aborta em vez de gravar auditoria órfã.
  BEGIN
    PERFORM public.auto_allocate_packing(
      '55555555-5555-4555-8555-000000000002',
      'Fantasma',
      '99999999-9999-4999-8999-999999999999'
    );
  EXCEPTION WHEN others THEN
    v_falhou := true;
  END;

  IF NOT v_falhou THEN
    RAISE EXCEPTION 'smoke 5b: autor inexistente deveria abortar a RPC';
  END IF;

  RAISE NOTICE 'smoke 5 OK: autoria com FK e label congelado';
END $$;

-- Sessão vence o parâmetro: com auth.uid() presente, o id passado é ignorado.
DO $$
DECLARE
  v_label text;
  v_autor uuid;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);

  SELECT a.label, a.autor_id INTO v_label, v_autor
  FROM app_private.resolve_autoria('Outra Pessoa', '99999999-9999-4999-8999-999999999999') a;

  IF v_autor <> '11111111-1111-4111-8111-111111111111' THEN
    RAISE EXCEPTION 'smoke 5c: auth.uid() deveria vencer o parâmetro, veio %', v_autor;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', '', true);
  RAISE NOTICE 'smoke 5c OK: auth.uid() vence p_registrado_por_id';
END $$;


-- ============================================================================
-- 6. Dual-write: auto_allocate_packing aparece no array legado
-- ============================================================================

DO $$
DECLARE
  v_alocados int;
  v_array uuid[];
  v_tabela uuid[];
BEGIN
  SELECT count(*) INTO v_alocados
  FROM public.auto_allocate_packing(
    '55555555-5555-4555-8555-000000000002',
    'Smoke Operador',
    '11111111-1111-4111-8111-111111111111'
  );

  IF v_alocados <> 2 THEN
    RAISE EXCEPTION 'smoke 6: esperava 2 unidades auto-alocadas, veio %', v_alocados;
  END IF;

  SELECT coalesce(serial_numbers_designados, ARRAY[]::uuid[]) INTO v_array
  FROM public.packing_list WHERE id = '55555555-5555-4555-8555-000000000002';

  SELECT coalesce(array_agg(pa.serial_id ORDER BY pa.serial_id), ARRAY[]::uuid[]) INTO v_tabela
  FROM public.packing_allocations pa
  WHERE pa.packing_id = '55555555-5555-4555-8555-000000000002';

  IF coalesce(array_length(v_array, 1), 0) <> 2 THEN
    RAISE EXCEPTION 'smoke 6: dual-write não escreveu no array legado. Array: %', v_array;
  END IF;

  IF (SELECT array_agg(x ORDER BY x) FROM unnest(v_array) x) IS DISTINCT FROM v_tabela THEN
    RAISE EXCEPTION 'smoke 6: array (%) divergente da tabela (%)', v_array, v_tabela;
  END IF;

  RAISE NOTICE 'smoke 6 OK: dual-write de auto_allocate_packing no array legado';
END $$;


-- ============================================================================
-- 7. Conferência RFID: 4 classificações e tag de lote legado
-- ============================================================================
-- Evento 2 tem 2 unidades alocadas (TAGS3 e TAGS4, escolhidas pela
-- auto-alocação). A leitura traz TAGS3 (CONFIRMADO), TAGS5 (EXTRA: unidade
-- conhecida, não alocada), TAGLOTE01 (DESCONHECIDA, lote legado) e uma tag
-- inexistente (DESCONHECIDA). TAGS4 não é lida, então vira FALTANTE.
--
-- A primeira tag entra com espaço, minúscula e hífen para exercitar a
-- normalização (mesma de `normalizeRfidTag` no web).

DO $$
DECLARE
  v_confirmado int;
  v_faltante int;
  v_extra int;
  v_desconhecida int;
  v_alocados uuid[];
  v_nota text;
  v_lote_id uuid;
BEGIN
  SELECT coalesce(array_agg(pa.serial_id ORDER BY pa.serial_id), ARRAY[]::uuid[]) INTO v_alocados
  FROM public.packing_allocations pa
  WHERE pa.packing_id = '55555555-5555-4555-8555-000000000002';

  IF v_alocados IS DISTINCT FROM ARRAY[
    '33333333-3333-4333-8333-000000000003'::uuid,
    '33333333-3333-4333-8333-000000000004'::uuid
  ] THEN
    RAISE EXCEPTION 'smoke 7: pré-condição falhou, alocados = %', v_alocados;
  END IF;

  CREATE TEMP TABLE _conf ON COMMIT DROP AS
  SELECT * FROM public.conferencia_rfid_evento(
    '44444444-4444-4444-8444-000000000002',
    ARRAY[' tag-s3 ', 'TAGS5', 'taglote:01', 'TAGINEXISTENTE'],
    'CONFERENCIA',
    'Smoke Operador',
    NULL
  );

  SELECT
    count(*) FILTER (WHERE classificacao = 'CONFIRMADO'),
    count(*) FILTER (WHERE classificacao = 'FALTANTE'),
    count(*) FILTER (WHERE classificacao = 'EXTRA'),
    count(*) FILTER (WHERE classificacao = 'DESCONHECIDA')
  INTO v_confirmado, v_faltante, v_extra, v_desconhecida
  FROM _conf;

  IF v_confirmado <> 1 THEN RAISE EXCEPTION 'smoke 7: CONFIRMADO = % (esperado 1)', v_confirmado; END IF;
  IF v_faltante <> 1 THEN RAISE EXCEPTION 'smoke 7: FALTANTE = % (esperado 1)', v_faltante; END IF;
  IF v_extra <> 1 THEN RAISE EXCEPTION 'smoke 7: EXTRA = % (esperado 1)', v_extra; END IF;
  IF v_desconhecida <> 2 THEN RAISE EXCEPTION 'smoke 7: DESCONHECIDA = % (esperado 2)', v_desconhecida; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM _conf
    WHERE classificacao = 'CONFIRMADO' AND tag_rfid = 'TAGS3'
      AND serial_id = '33333333-3333-4333-8333-000000000003'
  ) THEN
    RAISE EXCEPTION 'smoke 7: normalização da tag falhou (esperava TAGS3 confirmada)';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM _conf WHERE classificacao = 'FALTANTE' AND tag_rfid = 'TAGS4'
  ) THEN
    RAISE EXCEPTION 'smoke 7: unidade não lida deveria vir como FALTANTE';
  END IF;

  -- Tag de lote legado: DESCONHECIDA, sem serial, com nota de lote no scan e
  -- sem NUNCA preencher rfid_scans.lote_id.
  IF NOT EXISTS (
    SELECT 1 FROM _conf
    WHERE classificacao = 'DESCONHECIDA' AND tag_rfid = 'TAGLOTE01' AND serial_id IS NULL
  ) THEN
    RAISE EXCEPTION 'smoke 7: tag de lote legado deveria ser DESCONHECIDA';
  END IF;

  SELECT s.notas, s.lote_id INTO v_nota, v_lote_id
  FROM public.rfid_scans s
  WHERE s.tag_rfid = 'TAGLOTE01'
  ORDER BY s.timestamp DESC
  LIMIT 1;

  IF v_nota <> 'Tag RFID não reconhecida / Lote legado: LOTE-SMOKE-1' THEN
    RAISE EXCEPTION 'smoke 7: nota de lote legado errada: %', coalesce(v_nota, '<null>');
  END IF;
  IF v_lote_id IS NOT NULL THEN
    RAISE EXCEPTION 'smoke 7: rfid_scans.lote_id foi preenchido, viola unit-only';
  END IF;

  -- Toda leitura vira telemetria, inclusive a desconhecida.
  IF (SELECT count(*) FROM public.rfid_scans WHERE projeto_id = '44444444-4444-4444-8444-000000000002') <> 4 THEN
    RAISE EXCEPTION 'smoke 7: esperava 4 scans gravados';
  END IF;

  -- Conferência não muta status.
  IF (SELECT status FROM public.projetos WHERE id = '44444444-4444-4444-8444-000000000002') <> 'CONFIRMADO' THEN
    RAISE EXCEPTION 'smoke 7: conferência mudou o status do Evento';
  END IF;

  DROP TABLE _conf;
  RAISE NOTICE 'smoke 7 OK: conferência RFID com 4 classificações e lote legado';
END $$;


-- ============================================================================
-- 8. Check-in e resolução de pendência: alocação liberada e array reprojetado
-- ============================================================================

DO $$
DECLARE
  v_status_s1 public.status_serial_enum;
  v_status_s2 public.status_serial_enum;
  v_array uuid[];
  v_pend uuid;
  v_autor uuid;
  v_status_projeto public.status_projeto_enum;
BEGIN
  PERFORM public.checkin_projeto(
    '44444444-4444-4444-8444-000000000001',
    'MANUAL',
    'Smoke Operador',
    jsonb_build_array(
      jsonb_build_object('serial_id', '33333333-3333-4333-8333-000000000001', 'desgaste', 4, 'resultado', 'OK'),
      jsonb_build_object('serial_id', '33333333-3333-4333-8333-000000000002', 'resultado', 'NAO_VOLTOU', 'observacao', 'Ficou no caminhão do parceiro')
    ),
    '11111111-1111-4111-8111-111111111111'
  );

  SELECT status INTO v_status_s1 FROM public.serial_numbers WHERE id = '33333333-3333-4333-8333-000000000001';
  SELECT status INTO v_status_s2 FROM public.serial_numbers WHERE id = '33333333-3333-4333-8333-000000000002';

  IF v_status_s1 <> 'DISPONIVEL' THEN RAISE EXCEPTION 'smoke 8: unidade OK deveria estar DISPONIVEL, está %', v_status_s1; END IF;
  IF v_status_s2 <> 'RETORNANDO' THEN RAISE EXCEPTION 'smoke 8: unidade não devolvida deveria estar RETORNANDO, está %', v_status_s2; END IF;

  -- A alocação da unidade que voltou sai; a da que não voltou fica.
  IF EXISTS (SELECT 1 FROM public.packing_allocations WHERE serial_id = '33333333-3333-4333-8333-000000000001') THEN
    RAISE EXCEPTION 'smoke 8: alocação da unidade devolvida não foi liberada';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.packing_allocations WHERE serial_id = '33333333-3333-4333-8333-000000000002') THEN
    RAISE EXCEPTION 'smoke 8: alocação da unidade não devolvida deveria continuar viva';
  END IF;

  -- Dual-write: o array legado passa a refletir a tabela (estava vazio desde o
  -- teste 4, e volta a ficar correto).
  SELECT coalesce(serial_numbers_designados, ARRAY[]::uuid[]) INTO v_array
  FROM public.packing_list WHERE id = '55555555-5555-4555-8555-000000000001';

  IF v_array IS DISTINCT FROM ARRAY['33333333-3333-4333-8333-000000000002'::uuid] THEN
    RAISE EXCEPTION 'smoke 8: dual-write do check-in não reprojetou o array. Array: %', v_array;
  END IF;

  SELECT id, registrado_por_id INTO v_pend, v_autor
  FROM public.retorno_pendencias
  WHERE projeto_id = '44444444-4444-4444-8444-000000000001' AND status = 'ABERTA';

  IF v_pend IS NULL THEN RAISE EXCEPTION 'smoke 8: pendência não foi aberta'; END IF;
  IF v_autor <> '11111111-1111-4111-8111-111111111111' THEN
    RAISE EXCEPTION 'smoke 8: pendência sem registrado_por_id';
  END IF;

  -- Evento continua EM_CAMPO enquanto há pendência aberta.
  SELECT status INTO v_status_projeto FROM public.projetos WHERE id = '44444444-4444-4444-8444-000000000001';
  IF v_status_projeto <> 'EM_CAMPO' THEN
    RAISE EXCEPTION 'smoke 8: com pendência aberta o Evento deveria seguir EM_CAMPO, está %', v_status_projeto;
  END IF;

  -- Resolução: unidade encontrada, alocação sai, array esvazia, Evento fecha.
  PERFORM public.resolver_retorno_pendencia(
    v_pend,
    'ENCONTRADA',
    'Apareceu no galpão do parceiro',
    'Smoke Admin',
    '11111111-1111-4111-8111-111111111111'
  );

  SELECT status INTO v_status_s2 FROM public.serial_numbers WHERE id = '33333333-3333-4333-8333-000000000002';
  IF v_status_s2 <> 'DISPONIVEL' THEN
    RAISE EXCEPTION 'smoke 8: unidade encontrada deveria voltar a DISPONIVEL, está %', v_status_s2;
  END IF;

  IF EXISTS (SELECT 1 FROM public.packing_allocations WHERE serial_id = '33333333-3333-4333-8333-000000000002') THEN
    RAISE EXCEPTION 'smoke 8: resolução deveria liberar a alocação';
  END IF;

  SELECT coalesce(serial_numbers_designados, ARRAY[]::uuid[]) INTO v_array
  FROM public.packing_list WHERE id = '55555555-5555-4555-8555-000000000001';
  IF coalesce(array_length(v_array, 1), 0) <> 0 THEN
    RAISE EXCEPTION 'smoke 8: dual-write da resolução não esvaziou o array. Array: %', v_array;
  END IF;

  SELECT status INTO v_status_projeto FROM public.projetos WHERE id = '44444444-4444-4444-8444-000000000001';
  IF v_status_projeto <> 'FINALIZADO' THEN
    RAISE EXCEPTION 'smoke 8: sem pendência aberta o Evento deveria FINALIZAR, está %', v_status_projeto;
  END IF;

  IF (SELECT resolvido_por_id FROM public.retorno_pendencias WHERE id = v_pend)
     <> '11111111-1111-4111-8111-111111111111' THEN
    RAISE EXCEPTION 'smoke 8: resolvido_por_id não foi gravado';
  END IF;

  RAISE NOTICE 'smoke 8 OK: check-in e resolução liberam alocação e reprojetam o array';
END $$;


-- ============================================================================
-- 9. app_config manda no prefixo do código interno
-- ============================================================================

DO $$
DECLARE v_codigo text;
BEGIN
  IF (SELECT value FROM public.app_config WHERE key = 'codigo_prefix') <> 'MMD' THEN
    RAISE EXCEPTION 'smoke 9: bootstrap de codigo_prefix deveria ser MMD (comportamento atual preservado)';
  END IF;

  INSERT INTO public.items (nome, categoria, quantidade_total)
  VALUES ('Item Smoke Sem Codigo', 'EFEITO', 1)
  RETURNING codigo_interno INTO v_codigo;

  IF v_codigo NOT LIKE 'MMD-EFE-%' THEN
    RAISE EXCEPTION 'smoke 9: código gerado fora do padrão MMD-EFE-NNNN: %', v_codigo;
  END IF;

  RAISE NOTICE 'smoke 9 OK: prefixo lido de app_config, comportamento MMD preservado';
END $$;


DO $$ BEGIN RAISE NOTICE 'DELTA SMOKE: todos os blocos passaram'; END $$;

ROLLBACK;
