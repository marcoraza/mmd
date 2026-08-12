BEGIN;
SELECT plan(54);

SELECT has_function(
  'public',
  'confirmar_conferencia_retorno',
  ARRAY['uuid', 'uuid[]', 'bigint', 'text'],
  'retorno confirma decisões físicas por RPC própria'
);

SELECT has_function(
  'public',
  'resolver_pendencia_retorno',
  ARRAY['uuid', 'text', 'text', 'text', 'text'],
  'pendência possui resolução idempotente e localização confirmada por RPC própria'
);

SELECT has_function(
  'public',
  'finalizar_conferencia_retorno',
  ARRAY['uuid', 'bigint', 'text'],
  'finalização deriva ausências do retorno por RPC própria'
);

SELECT has_function(
  'public',
  'salvar_decisao_conferencia_retorno',
  ARRAY['uuid', 'uuid', 'public.conferencia_resultado_enum', 'public.metodo_scan_enum', 'text', 'timestamp with time zone', 'integer', 'text', 'text', 'text'],
  'retorno persiste a condição física pela RPC canônica'
);

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES
  ('00000000-0000-0000-0000-000000000000', 'e1111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'return-a@test.local', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'e2222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'return-b@test.local', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'e3333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'return-viewer@test.local', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

UPDATE public.profiles
SET role = CASE id
  WHEN 'e1111111-1111-1111-1111-111111111111'::uuid THEN 'editor'::public.user_role_enum
  WHEN 'e2222222-2222-2222-2222-222222222222'::uuid THEN 'editor'::public.user_role_enum
  ELSE 'viewer'::public.user_role_enum
END
WHERE id IN (
  'e1111111-1111-1111-1111-111111111111'::uuid,
  'e2222222-2222-2222-2222-222222222222'::uuid,
  'e3333333-3333-3333-3333-333333333333'::uuid
);

INSERT INTO public.items (id, nome, categoria, quantidade_total)
VALUES ('e4444444-4444-4444-4444-444444444444', 'Unidade de retorno', 'ILUMINACAO', 4);

INSERT INTO public.serial_numbers (id, item_id, codigo_interno, qr_code)
VALUES
  ('e5555555-5555-5555-5555-555555555551', 'e4444444-4444-4444-4444-444444444444', 'MMD-ILU-RET001', 'QR-RET-001'),
  ('e5555555-5555-5555-5555-555555555552', 'e4444444-4444-4444-4444-444444444444', 'MMD-ILU-RET002', 'QR-RET-002'),
  ('e5555555-5555-5555-5555-555555555553', 'e4444444-4444-4444-4444-444444444444', 'MMD-ILU-RET003', 'QR-RET-003'),
  ('e5555555-5555-5555-5555-555555555554', 'e4444444-4444-4444-4444-444444444444', 'MMD-ILU-RET004', 'QR-RET-004');

INSERT INTO public.projetos (id, nome, status)
VALUES
  ('e6666666-6666-6666-6666-666666666666', 'Evento retorno completo', 'CONFIRMADO'),
  ('e7777777-7777-7777-7777-777777777777', 'Evento retorno com falha', 'CONFIRMADO');

INSERT INTO public.packing_list (id, projeto_id, item_id, quantidade, serial_numbers_designados)
VALUES
  ('e8888888-8888-8888-8888-888888888881', 'e6666666-6666-6666-6666-666666666666', 'e4444444-4444-4444-4444-444444444444', 3, ARRAY['e5555555-5555-5555-5555-555555555551'::uuid, 'e5555555-5555-5555-5555-555555555552'::uuid, 'e5555555-5555-5555-5555-555555555553'::uuid]),
  ('e8888888-8888-8888-8888-888888888882', 'e7777777-7777-7777-7777-777777777777', 'e4444444-4444-4444-4444-444444444444', 1, ARRAY['e5555555-5555-5555-5555-555555555554'::uuid]);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

SELECT lives_ok($$
  SELECT public.salvar_decisao_conferencia('e6666666-6666-6666-6666-666666666666', 'SAIDA', 'e5555555-5555-5555-5555-555555555551', 'PRESENTE', 'QRCODE', 'ret:saida:001', '2026-08-12T18:00:00Z', NULL, NULL, 'ret:saida:001:key')
$$, 'primeira saída física é registrada');

SELECT lives_ok($$
  SELECT public.salvar_decisao_conferencia('e6666666-6666-6666-6666-666666666666', 'SAIDA', 'e5555555-5555-5555-5555-555555555552', 'PRESENTE', 'QRCODE', 'ret:saida:002', '2026-08-12T18:00:01Z', NULL, NULL, 'ret:saida:002:key')
$$, 'segunda saída física é registrada');

SELECT lives_ok($$
  SELECT public.salvar_decisao_conferencia('e6666666-6666-6666-6666-666666666666', 'SAIDA', 'e5555555-5555-5555-5555-555555555553', 'PRESENTE', 'QRCODE', 'ret:saida:003', '2026-08-12T18:00:02Z', NULL, NULL, 'ret:saida:003:key')
$$, 'terceira saída física é registrada');

SELECT lives_ok($$
  SELECT public.confirmar_conferencia_saida(
    (SELECT id FROM public.conferencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666' AND direcao = 'SAIDA'),
    ARRAY(SELECT id FROM public.conferencia_decisoes WHERE conferencia_id = (SELECT id FROM public.conferencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666' AND direcao = 'SAIDA') ORDER BY id),
    3, 'ret:saida:confirm:001', NULL
  )
$$, 'saídas aplicadas alimentam o retorno esperado');

SELECT results_eq(
  $$SELECT codigo_interno FROM public.conferencia_retorno_esperado('e6666666-6666-6666-6666-666666666666') ORDER BY codigo_interno$$,
  $$VALUES ('MMD-ILU-RET001'::text), ('MMD-ILU-RET002'::text), ('MMD-ILU-RET003'::text)$$,
  'retorno esperado vem apenas das saídas aplicadas'
);

SELECT throws_ok($$
  SELECT public.salvar_decisao_conferencia_retorno(
    'e6666666-6666-6666-6666-666666666666',
    'e5555555-5555-5555-5555-555555555551',
    'PROBLEMA',
    'QRCODE',
    'ret:problem:no-condition',
    '2026-08-12T20:00:00Z',
    NULL,
    NULL,
    'Conector danificado',
    'ret:problem:no-condition:key'
  )
$$, '22023', 'Retorno PROBLEMA exige condição e observação', 'problema sem condição não vira decisão');

SELECT throws_ok($$
  SELECT public.salvar_decisao_conferencia_retorno(
    'e6666666-6666-6666-6666-666666666666',
    'e5555555-5555-5555-5555-555555555551',
    'OK',
    'QRCODE',
    'ret:ok:invalid-condition',
    '2026-08-12T20:00:00Z',
    0,
    NULL,
    NULL,
    'ret:ok:invalid-condition:key'
  )
$$, '22023', 'Desgaste de retorno deve estar entre 1 e 5', 'condição fora da faixa não vira decisão');

SELECT throws_ok($$
  SELECT public.salvar_decisao_conferencia_retorno(
    'e6666666-6666-6666-6666-666666666666',
    'e5555555-5555-5555-5555-555555555552',
    'NAO_VOLTOU',
    'QRCODE',
    'ret:missing:client',
    '2026-08-12T20:00:01Z',
    NULL,
    NULL,
    'Não localizado no desmonte',
    'ret:missing:client:key'
  )
$$, '22023', 'Ausência é derivada ao finalizar o retorno', 'cliente não fabrica a ausência da Unidade');

SELECT lives_ok($$
  SELECT public.salvar_decisao_conferencia_retorno(
    'e6666666-6666-6666-6666-666666666666',
    'e5555555-5555-5555-5555-555555555551',
    'OK',
    'QRCODE',
    'ret:ok:001',
    '2026-08-12T20:00:00Z',
    4,
    NULL,
    NULL,
    'ret:ok:001:key'
  )
$$, 'retorno OK registra a condição física');

SELECT lives_ok($$
  SELECT public.salvar_decisao_conferencia_retorno(
    'e6666666-6666-6666-6666-666666666666',
    'e5555555-5555-5555-5555-555555555553',
    'PROBLEMA',
    'QRCODE',
    'ret:problem:001',
    '2026-08-12T20:00:02Z',
    2,
    NULL,
    'Conector danificado',
    'ret:problem:001:key'
  )
$$, 'problema com condição e observação é registrado');

SELECT is(
  public.finalizar_conferencia_retorno(
    'e6666666-6666-6666-6666-666666666666',
    2,
    'ret:finalize:001'
  ) #>> '{receipt,direction}',
  'RETORNO',
  'finalização de retorno devolve o Recibo persistido'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.conferencia_decisoes cd
    JOIN public.conferencias c ON c.id = cd.conferencia_id
    WHERE c.projeto_id = 'e6666666-6666-6666-6666-666666666666'
      AND c.direcao = 'RETORNO'
      AND cd.resultado = 'NAO_VOLTOU'
      AND cd.source_event_id LIKE 'return-finalization:%'
  ),
  1,
  'finalização deriva a ausência sem decisão fabricada pelo cliente'
);

SELECT is(
  (
    SELECT retorno_desgaste
    FROM public.conferencia_decisoes cd
    JOIN public.conferencias c ON c.id = cd.conferencia_id
    WHERE c.projeto_id = 'e6666666-6666-6666-6666-666666666666'
      AND c.direcao = 'RETORNO'
      AND cd.serial_number_id = 'e5555555-5555-5555-5555-555555555553'
  ),
  2,
  'decisão de problema persiste o desgaste informado'
);

SELECT is(
  public.finalizar_conferencia_retorno(
    'e6666666-6666-6666-6666-666666666666',
    2,
    'ret:finalize:001'
  ) #>> '{receipt,units,2,desgaste}',
  '2',
  'Recibo de retorno inclui o desgaste da Unidade'
);

SELECT results_eq(
  $$SELECT codigo_interno, status::text FROM public.serial_numbers WHERE id IN ('e5555555-5555-5555-5555-555555555551'::uuid, 'e5555555-5555-5555-5555-555555555552'::uuid, 'e5555555-5555-5555-5555-555555555553'::uuid) ORDER BY codigo_interno$$,
  $$VALUES ('MMD-ILU-RET001'::text, 'DISPONIVEL'::text), ('MMD-ILU-RET002'::text, 'RETORNANDO'::text), ('MMD-ILU-RET003'::text, 'MANUTENCAO'::text)$$,
  'OK, ausência e problema aplicam estados distintos'
);

SELECT is(
  (SELECT desgaste FROM public.serial_numbers WHERE id = 'e5555555-5555-5555-5555-555555555553'),
  2,
  'problema aplica a condição física no estado atual da Unidade'
);

SELECT results_eq(
  $$SELECT tipo::text, status_novo FROM public.movimentacoes WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666' AND tipo IN ('RETORNO', 'MANUTENCAO') ORDER BY serial_number_id$$,
  $$VALUES ('RETORNO'::text, 'DISPONIVEL'::text), ('RETORNO'::text, 'RETORNANDO'::text), ('MANUTENCAO'::text, 'MANUTENCAO'::text)$$,
  'retorno grava histórico coerente para cada desfecho'
);

SELECT is(
  (SELECT count(*)::integer FROM public.retorno_pendencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666' AND status = 'ABERTA'),
  1,
  'ausência abre uma única pendência'
);

SELECT is(
  public.finalizar_conferencia_retorno(
    'e6666666-6666-6666-6666-666666666666',
    2,
    'ret:finalize:001'
  ) ->> 'finalization_id',
  (SELECT id::text FROM public.retorno_conferencia_finalizacoes WHERE idempotency_key = 'ret:finalize:001'),
  'retry pós-commit devolve o mesmo Recibo de finalização'
);

SELECT set_config('request.jwt.claims', '{"sub":"e2222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

SELECT throws_ok($$
  SELECT public.finalizar_conferencia_retorno(
    'e6666666-6666-6666-6666-666666666666',
    2,
    'ret:finalize:001'
  )
$$, 'P0001', 'IDEMPOTENCY_KEY_CONFLICT', 'outro operador não recebe Recibo de finalização alheio');

SELECT is((SELECT status::text FROM public.projetos WHERE id = 'e6666666-6666-6666-6666-666666666666'), 'EM_CAMPO', 'pendência aberta mantém Evento em campo');

SELECT set_config('request.jwt.claims', '{"sub":"e1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

SELECT throws_ok($$
  SELECT public.resolver_pendencia_retorno(
    (SELECT id FROM public.retorno_pendencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666' AND status = 'ABERTA'),
    'ENCONTRADA', 'Encontrada no case', NULL, 'ret:resolve:no-location'
  )
$$, '22023', 'ENCONTRADA exige localização confirmada', 'unidade encontrada não fecha sem localização confirmada');

SELECT is(
  public.resolver_pendencia_retorno(
    (SELECT id FROM public.retorno_pendencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666' AND status = 'ABERTA'),
    'ENCONTRADA', 'Encontrada no case', 'Case retorno A', 'ret:resolve:001'
  ) ->> 'action',
  'ENCONTRADA',
  'pendência encontrada é resolvida por transação própria'
);

SELECT is((SELECT status::text FROM public.serial_numbers WHERE id = 'e5555555-5555-5555-5555-555555555552'), 'DISPONIVEL', 'resolver encontrada devolve Unidade ao estoque');

SELECT is((SELECT status FROM public.retorno_pendencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666'), 'ENCONTRADA', 'pendência recebe o desfecho persistido');

SELECT is(
  (SELECT localizacao_confirmada FROM public.retorno_pendencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666'),
  'Case retorno A',
  'pendência persiste a localização confirmada da Unidade encontrada'
);

SELECT is(
  public.resolver_pendencia_retorno(
    (SELECT id FROM public.retorno_pendencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666'),
    'ENCONTRADA', 'Encontrada no case', 'Case retorno A', 'ret:resolve:001'
  ) ->> 'confirmed_location',
  'Case retorno A',
  'Recibo de resolução registra a localização confirmada'
);

SELECT is((SELECT status::text FROM public.projetos WHERE id = 'e6666666-6666-6666-6666-666666666666'), 'FINALIZADO', 'última pendência resolvida finaliza Evento');

SELECT is(
  public.resolver_pendencia_retorno(
    (SELECT id FROM public.retorno_pendencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666'),
    'ENCONTRADA', 'Encontrada no case', 'Case retorno A', 'ret:resolve:001'
  ) ->> 'resolution_id',
  (SELECT id::text FROM public.retorno_pendencia_resolucoes WHERE idempotency_key = 'ret:resolve:001'),
  'retry de pendência devolve o mesmo ACK'
);

SELECT set_config('request.jwt.claims', '{"sub":"e2222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

SELECT throws_ok($$
  SELECT public.resolver_pendencia_retorno(
    (SELECT id FROM public.retorno_pendencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666'),
    'ENCONTRADA', 'Encontrada no case', 'Case retorno A', 'ret:resolve:001'
  )
$$, 'P0001', 'IDEMPOTENCY_KEY_CONFLICT', 'outro operador não recebe ACK de pendência alheio');

SELECT throws_ok($$
  SELECT public.resolver_pendencia_retorno(
    (SELECT id FROM public.retorno_pendencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666'),
    'BAIXA', 'Sem recuperação', NULL, 'ret:resolve:admin-only'
  )
$$, '42501', 'Baixa e cobrança exigem usuário admin', 'editor não contorna a permissão administrativa');

SELECT set_config('request.jwt.claims', '{"sub":"e3333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

SELECT throws_ok($$
  SELECT public.resolver_pendencia_retorno(
    (SELECT id FROM public.retorno_pendencias WHERE projeto_id = 'e6666666-6666-6666-6666-666666666666'),
    'ENCONTRADA', 'Encontrada no case', 'Case retorno A', 'ret:resolve:viewer'
  )
$$, '42501', 'Perfil sem permissão para resolver pendência', 'viewer não resolve pendência');

SELECT set_config('request.jwt.claims', '{"sub":"e1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

SELECT lives_ok($$
  SELECT public.salvar_decisao_conferencia('e7777777-7777-7777-7777-777777777777', 'SAIDA', 'e5555555-5555-5555-5555-555555555554', 'PRESENTE', 'QRCODE', 'ret:fail:saida', '2026-08-12T21:00:00Z', NULL, NULL, 'ret:fail:saida:key')
$$, 'fixture de rollback registra saída');

SELECT lives_ok($$
  SELECT public.confirmar_conferencia_saida(
    (SELECT id FROM public.conferencias WHERE projeto_id = 'e7777777-7777-7777-7777-777777777777' AND direcao = 'SAIDA'),
    ARRAY(SELECT id FROM public.conferencia_decisoes WHERE conferencia_id = (SELECT id FROM public.conferencias WHERE projeto_id = 'e7777777-7777-7777-7777-777777777777' AND direcao = 'SAIDA')),
    1, 'ret:fail:saida:confirm', NULL
  )
$$, 'fixture de rollback aplica saída');

RESET ROLE;
SAVEPOINT return_pending_failure;
CREATE OR REPLACE FUNCTION pg_temp.fail_return_pending()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'INJECTED_RETURN_PENDING_FAILURE';
END;
$$;
CREATE TRIGGER trg_test_fail_return_pending
AFTER UPDATE ON public.conferencias
FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_return_pending();

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

DO $$
BEGIN
  PERFORM public.finalizar_conferencia_retorno(
    'e7777777-7777-7777-7777-777777777777',
    0,
    'ret:fail:confirm'
  );
  RAISE EXCEPTION 'A confirmação deveria falhar';
EXCEPTION
  WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM <> 'INJECTED_RETURN_PENDING_FAILURE' THEN
      RAISE;
    END IF;
END;
$$;

ROLLBACK TO SAVEPOINT return_pending_failure;
SELECT pass('falha após a última escrita aborta toda a confirmação de retorno');

SELECT is((SELECT status::text FROM public.serial_numbers WHERE id = 'e5555555-5555-5555-5555-555555555554'), 'EM_CAMPO', 'rollback preserva estado anterior da Unidade');

SELECT is((SELECT count(*)::integer FROM public.conferencia_confirmacoes WHERE idempotency_key = 'ret:fail:confirm'), 0, 'rollback não deixa Recibo parcial');

SELECT is((SELECT count(*)::integer FROM public.movimentacoes WHERE projeto_id = 'e7777777-7777-7777-7777-777777777777' AND tipo IN ('RETORNO', 'MANUTENCAO')), 0, 'rollback não deixa movimentação parcial');

SELECT is((SELECT count(*)::integer FROM public.retorno_pendencias WHERE projeto_id = 'e7777777-7777-7777-7777-777777777777'), 0, 'rollback não deixa pendência parcial');

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.conferencias
    WHERE projeto_id = 'e7777777-7777-7777-7777-777777777777'
      AND direcao = 'RETORNO'
  ),
  0,
  'rollback não deixa Conferência de retorno parcial'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.conferencia_decisoes cd
    JOIN public.conferencias c ON c.id = cd.conferencia_id
    WHERE c.projeto_id = 'e7777777-7777-7777-7777-777777777777'
      AND c.direcao = 'RETORNO'
      AND cd.applied_confirmation_id IS NOT NULL
  ),
  0,
  'rollback não marca decisão de retorno como aplicada'
);

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

SELECT is(
  public.finalizar_conferencia_retorno(
    'e7777777-7777-7777-7777-777777777777',
    0,
    'ret:fail:confirm'
  ) #>> '{receipt,direction}',
  'RETORNO',
  'retry após rollback aplica a mesma finalização sem duplicar pendência'
);

SELECT is(
  (SELECT count(*)::integer FROM public.retorno_pendencias WHERE projeto_id = 'e7777777-7777-7777-7777-777777777777' AND status = 'ABERTA'),
  1,
  'retry após rollback cria uma única pendência'
);

SAVEPOINT return_pending_resolution_fault;
RESET ROLE;
CREATE OR REPLACE FUNCTION pg_temp.fail_pending_resolution()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'INJECTED_PENDING_RESOLUTION_FAILURE';
END;
$$;
CREATE TRIGGER trg_test_fail_pending_resolution
BEFORE UPDATE OF status ON public.retorno_pendencias
FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_pending_resolution();

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

DO $$
BEGIN
  PERFORM public.resolver_pendencia_retorno(
    (SELECT id FROM public.retorno_pendencias WHERE projeto_id = 'e7777777-7777-7777-7777-777777777777' AND status = 'ABERTA'),
    'ENCONTRADA',
    'Encontrada após a conferência.',
    'Case retorno B',
    'ret:fail:resolve'
  );
  RAISE EXCEPTION 'A resolução deveria falhar';
EXCEPTION
  WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM <> 'INJECTED_PENDING_RESOLUTION_FAILURE' THEN
      RAISE;
    END IF;
END;
$$;

ROLLBACK TO SAVEPOINT return_pending_resolution_fault;
SELECT pass('falha tardia aborta a resolução de pendência inteira');

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

SELECT is(
  (SELECT status::text FROM public.serial_numbers WHERE id = 'e5555555-5555-5555-5555-555555555554'),
  'RETORNANDO',
  'rollback da resolução preserva o estado pendente da Unidade'
);

SELECT is(
  (SELECT count(*)::integer FROM public.movimentacoes WHERE projeto_id = 'e7777777-7777-7777-7777-777777777777' AND tipo = 'RETORNO'),
  1,
  'rollback da resolução não adiciona movimentação parcial'
);

SELECT is(
  (SELECT count(*)::integer FROM public.retorno_pendencia_resolucoes WHERE idempotency_key = 'ret:fail:resolve'),
  0,
  'rollback da resolução não deixa ACK persistido'
);

SELECT is(
  (SELECT status FROM public.retorno_pendencias WHERE projeto_id = 'e7777777-7777-7777-7777-777777777777'),
  'ABERTA',
  'rollback da resolução mantém a pendência aberta'
);

SELECT is(
  public.resolver_pendencia_retorno(
    (SELECT id FROM public.retorno_pendencias WHERE projeto_id = 'e7777777-7777-7777-7777-777777777777' AND status = 'ABERTA'),
    'ENCONTRADA',
    'Encontrada após a conferência.',
    'Case retorno B',
    'ret:fail:resolve'
  ) ->> 'action',
  'ENCONTRADA',
  'retry depois do rollback resolve a pendência sem segunda intenção'
);

SELECT is(
  (SELECT status::text FROM public.serial_numbers WHERE id = 'e5555555-5555-5555-5555-555555555554'),
  'DISPONIVEL',
  'retry da resolução aplica o estado final esperado'
);

SELECT * FROM finish();
ROLLBACK;
