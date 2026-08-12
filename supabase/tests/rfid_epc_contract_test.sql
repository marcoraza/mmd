BEGIN;
SELECT plan(41);

SELECT has_function(
  'public',
  'resolver_epc_rfid',
  ARRAY['text'],
  'Identificar resolve EPC sem transformar leitura em movimento'
);

SELECT has_function(
  'public',
  'aplicar_vinculo_rfid',
  ARRAY['uuid', 'text', 'text'],
  'Etiquetar usa uma única operação idempotente'
);

SELECT has_function(
  'public',
  'resolver_excecao_conferencia_saida',
  ARRAY['uuid', 'public.conferencia_resolution_enum', 'bigint', 'text'],
  'Revisar exige resolução persistida antes da confirmação'
);

SELECT ok(
  pg_get_functiondef(
    'public.resolver_excecao_conferencia_saida(uuid,public.conferencia_resolution_enum,bigint,text)'::regprocedure
  ) ~ 'FROM public\.projetos p[[:space:]]+WHERE p\.id = v_projeto_id[[:space:]]+FOR UPDATE;[[:space:]]+SELECT c\.\*[[:space:]]+INTO v_conferencia[[:space:]]+FROM public\.conferencias c[[:space:]]+WHERE c\.id = v_conferencia_id[[:space:]]+FOR UPDATE;[[:space:]]+SELECT cd\.\*[[:space:]]+INTO v_decision[[:space:]]+FROM public\.conferencia_decisoes cd[[:space:]]+WHERE cd\.id = p_decision_id[[:space:]]+AND cd\.conferencia_id = v_conferencia\.id[[:space:]]+FOR UPDATE;',
  'Revisar trava Evento, Conferência e decisão nessa ordem'
);

INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    'd1111111-1111-1111-1111-111111111111',
    'authenticated',
    'authenticated',
    'rfid-editor@test.local',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'd2222222-2222-2222-2222-222222222222',
    'authenticated',
    'authenticated',
    'rfid-viewer@test.local',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(),
    now()
  );

UPDATE public.profiles
SET role = CASE id
  WHEN 'd1111111-1111-1111-1111-111111111111'::uuid THEN 'editor'::public.user_role_enum
  ELSE 'editor'::public.user_role_enum
END
WHERE id IN (
  'd1111111-1111-1111-1111-111111111111'::uuid,
  'd2222222-2222-2222-2222-222222222222'::uuid
);

INSERT INTO public.items (id, nome, categoria, quantidade_total)
VALUES
  ('d3333333-3333-3333-3333-333333333331', 'Unidade RFID A', 'ILUMINACAO', 1),
  ('d3333333-3333-3333-3333-333333333332', 'Unidade RFID B', 'ILUMINACAO', 1),
  ('d3333333-3333-3333-3333-333333333333', 'Unidade RFID Extra', 'ACESSORIO', 1);

INSERT INTO public.serial_numbers (id, item_id, codigo_interno, qr_code)
VALUES
  ('d4444444-4444-4444-4444-444444444441', 'd3333333-3333-3333-3333-333333333331', 'MMD-ILU-R001', 'QR-RFID-001'),
  ('d4444444-4444-4444-4444-444444444442', 'd3333333-3333-3333-3333-333333333332', 'MMD-ILU-R002', 'QR-RFID-002'),
  ('d4444444-4444-4444-4444-444444444443', 'd3333333-3333-3333-3333-333333333333', 'MMD-ACE-R003', 'QR-RFID-003');

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"d1111111-1111-1111-1111-111111111111","role":"authenticated"}',
  true
);

SELECT is(
  public.resolver_epc_rfid('E28011702000020A5C41FFFF') ->> 'known',
  'false',
  'EPC desconhecido é retornado sem criar associação'
);

SELECT is(
  (SELECT count(*)::integer FROM public.movimentacoes WHERE serial_number_id IN (
    'd4444444-4444-4444-4444-444444444441'::uuid,
    'd4444444-4444-4444-4444-444444444442'::uuid
  )),
  0,
  'Identificar não cria movimentação'
);

SELECT is(
  public.aplicar_vinculo_rfid(
    'd4444444-4444-4444-4444-444444444441',
    ' e280-1170 2000 020a 5c41 a001 ',
    'rfid:bind:0001'
  ) ->> 'action',
  'VINCULAR',
  'EPC livre é vinculado à Unidade'
);

SELECT is(
  (SELECT tag_rfid FROM public.serial_numbers WHERE id = 'd4444444-4444-4444-4444-444444444441'),
  'E28011702000020A5C41A001',
  'EPC é normalizado e persistido uma única vez'
);

SELECT is(
  public.resolver_epc_rfid('E28011702000020A5C41A001') #>> '{unit,codigo_interno}',
  'MMD-ILU-R001',
  'Identificar resolve EPC conhecido para a Unidade'
);

SELECT throws_ok(
  $$
    UPDATE public.serial_numbers
    SET tag_rfid = 'E28011702000020A5C41BADD'
    WHERE id = 'd4444444-4444-4444-4444-444444444442'
  $$,
  '42501',
  'RFID_TAG_WRITE_REQUIRES_OPERATION',
  'editor autenticado não altera EPC por PostgREST direto'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_index i
    WHERE i.indexrelid = 'public.serial_numbers_rfid_epc_normalized_unique'::regclass
      AND i.indisunique
  ),
  'índice normalizado garante EPC único entre Unidades'
);

SELECT is(
  public.aplicar_vinculo_rfid(
    'd4444444-4444-4444-4444-444444444441',
    'E28011702000020A5C41A001',
    'rfid:bind:0001'
  ) ->> 'operation_id',
  (
    SELECT id::text
    FROM public.rfid_tag_operations
    WHERE idempotency_key = 'rfid:bind:0001'
  ),
  'retry da mesma chave retorna o ACK persistido'
);

SELECT is(
  (SELECT count(*)::integer FROM public.rfid_tag_operations WHERE idempotency_key = 'rfid:bind:0001'),
  1,
  'retry não duplica auditoria de Etiquetar'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"d2222222-2222-2222-2222-222222222222","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
    SELECT public.aplicar_vinculo_rfid(
      'd4444444-4444-4444-4444-444444444441',
      'E28011702000020A5C41A001',
      'rfid:bind:0001'
    )
  $$,
  'P0001',
  'IDEMPOTENCY_KEY_CONFLICT',
  'retry da chave por outro operador falha fechado'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"d1111111-1111-1111-1111-111111111111","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
    SELECT public.aplicar_vinculo_rfid(
      'd4444444-4444-4444-4444-444444444442',
      'E28011702000020A5C41A002',
      'rfid:bind:0001'
    )
  $$,
  'P0001',
  'IDEMPOTENCY_KEY_CONFLICT',
  'mesma chave com outra intenção gera conflito'
);

SELECT is(
  public.aplicar_vinculo_rfid(
    'd4444444-4444-4444-4444-444444444442',
    'E28011702000020A5C41A001',
    'rfid:move:0001'
  ) ->> 'action',
  'MOVER',
  'EPC já associado move em uma única operação'
);

SELECT is(
  (SELECT tag_rfid FROM public.serial_numbers WHERE id = 'd4444444-4444-4444-4444-444444444441'),
  NULL,
  'mover remove EPC da Unidade anterior'
);

SELECT is(
  (SELECT previous_serial_number_id FROM public.rfid_tag_operations WHERE idempotency_key = 'rfid:move:0001'),
  'd4444444-4444-4444-4444-444444444441'::uuid,
  'auditoria registra Unidade anterior no movimento'
);

SELECT is(
  (SELECT next_serial_number_id FROM public.rfid_tag_operations WHERE idempotency_key = 'rfid:move:0001'),
  'd4444444-4444-4444-4444-444444444442'::uuid,
  'auditoria registra Unidade nova no movimento'
);

SELECT is(
  public.aplicar_vinculo_rfid(
    'd4444444-4444-4444-4444-444444444442',
    'E28011702000020A5C41A002',
    'rfid:replace:0001'
  ) ->> 'action',
  'SUBSTITUIR',
  'novo EPC substitui a tag atual da Unidade'
);

SELECT is(
  (SELECT previous_epc FROM public.rfid_tag_operations WHERE idempotency_key = 'rfid:replace:0001'),
  'E28011702000020A5C41A001',
  'auditoria registra EPC removido na substituição'
);

SELECT is(
  public.aplicar_vinculo_rfid(
    'd4444444-4444-4444-4444-444444444442',
    NULL,
    'rfid:unbind:0001'
  ) ->> 'action',
  'DESVINCULAR',
  'desvincular é uma operação explícita e auditada'
);

SELECT is(
  (SELECT tag_rfid FROM public.serial_numbers WHERE id = 'd4444444-4444-4444-4444-444444444442'),
  NULL,
  'desvincular remove a associação atual'
);

SELECT ok(
  pg_get_functiondef('public.aplicar_vinculo_rfid(uuid,text,text)'::regprocedure)
    ~ 'WHERE sn\.id = ANY \(v_lock_serial_ids\)[[:space:]]+ORDER BY sn\.id[[:space:]]+FOR UPDATE',
  'Etiquetar trava origem e destino em ordem estável antes de mover EPC'
);

SELECT is(
  public.aplicar_vinculo_rfid(
    'd4444444-4444-4444-4444-444444444441',
    'E28011702000020A5C41A005',
    'rfid:cross-bind:a'
  ) ->> 'action',
  'VINCULAR',
  'primeira Unidade recebe EPC para regressão de move cruzado'
);

SELECT is(
  public.aplicar_vinculo_rfid(
    'd4444444-4444-4444-4444-444444444442',
    'E28011702000020A5C41A006',
    'rfid:cross-bind:b'
  ) ->> 'action',
  'VINCULAR',
  'segunda Unidade recebe EPC para regressão de move cruzado'
);

SELECT is(
  public.aplicar_vinculo_rfid(
    'd4444444-4444-4444-4444-444444444442',
    'E28011702000020A5C41A005',
    'rfid:cross-move:b'
  ) ->> 'action',
  'MOVER',
  'primeiro move cruzado preserva uma única associação do EPC'
);

SELECT lives_ok(
  $$
    SELECT public.aplicar_vinculo_rfid(
      'd4444444-4444-4444-4444-444444444441',
      'E28011702000020A5C41A006',
      'rfid:cross-move:a'
    )
  $$,
  'segundo move cruzado completa sem depender da ordem de seleção'
);

SELECT results_eq(
  $$
    SELECT codigo_interno, tag_rfid
    FROM public.serial_numbers
    WHERE id IN (
      'd4444444-4444-4444-4444-444444444441'::uuid,
      'd4444444-4444-4444-4444-444444444442'::uuid
    )
    ORDER BY codigo_interno
  $$,
  $$
    VALUES
      ('MMD-ILU-R001'::text, 'E28011702000020A5C41A006'::text),
      ('MMD-ILU-R002'::text, 'E28011702000020A5C41A005'::text)
  $$,
  'move cruzado termina com uma associação única por Unidade'
);

INSERT INTO public.projetos (id, nome, status)
VALUES ('d5555555-5555-5555-5555-555555555555', 'Evento RFID Revisar', 'CONFIRMADO');

INSERT INTO public.packing_list (id, projeto_id, item_id, quantidade, serial_numbers_designados)
VALUES (
  'd6666666-6666-6666-6666-666666666666',
  'd5555555-5555-5555-5555-555555555555',
  'd3333333-3333-3333-3333-333333333331',
  1,
  ARRAY['d4444444-4444-4444-4444-444444444441'::uuid]
);

SELECT lives_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      'd5555555-5555-5555-5555-555555555555',
      'SAIDA',
      'd4444444-4444-4444-4444-444444444443',
      'PRESENTE',
      'RFID',
      'rfid:review:0001',
      '2026-08-12T18:00:00Z'
    )
  $$,
  'item fora do packing entra em Revisar'
);

SELECT is(
  (
    SELECT resolution::text
    FROM public.conferencia_decisoes cd
    JOIN public.conferencias c ON c.id = cd.conferencia_id
    WHERE c.projeto_id = 'd5555555-5555-5555-5555-555555555555'
      AND cd.serial_number_id = 'd4444444-4444-4444-4444-444444444443'
  ),
  'REVISAR',
  'exceção fica em Revisar antes da decisão do operador'
);

SELECT is(
  public.resolver_excecao_conferencia_saida(
    (
      SELECT cd.id
      FROM public.conferencia_decisoes cd
      JOIN public.conferencias c ON c.id = cd.conferencia_id
      WHERE c.projeto_id = 'd5555555-5555-5555-5555-555555555555'
        AND cd.serial_number_id = 'd4444444-4444-4444-4444-444444444443'
    ),
    'ADICIONAR',
    1,
    'review:add:0001'
  ) ->> 'action',
  'ADICIONAR',
  'Adicionar persiste a resolução da exceção'
);

SELECT is(
  (
    SELECT resolution::text
    FROM public.conferencia_decisoes cd
    JOIN public.conferencias c ON c.id = cd.conferencia_id
    WHERE c.projeto_id = 'd5555555-5555-5555-5555-555555555555'
      AND cd.serial_number_id = 'd4444444-4444-4444-4444-444444444443'
  ),
  'ADICIONAR',
  'Adicionar retira a decisão de Revisar sem criar movimentação'
);

SELECT is(
  (SELECT count(*)::integer FROM public.movimentacoes WHERE serial_number_id = 'd4444444-4444-4444-4444-444444444443'),
  0,
  'Adicionar não cria saída implícita'
);

SELECT is(
  public.resolver_excecao_conferencia_saida(
    (
      SELECT cd.id
      FROM public.conferencia_decisoes cd
      JOIN public.conferencias c ON c.id = cd.conferencia_id
      WHERE c.projeto_id = 'd5555555-5555-5555-5555-555555555555'
        AND cd.serial_number_id = 'd4444444-4444-4444-4444-444444444443'
    ),
    'ADICIONAR',
    1,
    'review:add:0001'
  ) ->> 'resolution_id',
  (
    SELECT id::text
    FROM public.conferencia_excecao_resolucoes
    WHERE idempotency_key = 'review:add:0001'
  ),
  'retry de Adicionar retorna a resolução persistida'
);

RESET ROLE;
SAVEPOINT rfid_fault_injection;
CREATE OR REPLACE FUNCTION pg_temp.fail_rfid_audit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'INJECTED_RFID_AUDIT_FAILURE';
END;
$$;

CREATE TRIGGER trg_test_fail_rfid_audit
BEFORE INSERT ON public.rfid_tag_operations
FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_rfid_audit();

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"d1111111-1111-1111-1111-111111111111","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
    SELECT public.aplicar_vinculo_rfid(
      'd4444444-4444-4444-4444-444444444442',
      'E28011702000020A5C41A004',
      'rfid:rollback:0001'
    )
  $$,
  'P0001',
  'INJECTED_RFID_AUDIT_FAILURE',
  'falha tardia aborta a associação EPC inteira'
);

RESET ROLE;
ROLLBACK TO SAVEPOINT rfid_fault_injection;
RELEASE SAVEPOINT rfid_fault_injection;

SELECT is(
  (SELECT tag_rfid FROM public.serial_numbers WHERE id = 'd4444444-4444-4444-4444-444444444442'),
  'E28011702000020A5C41A005',
  'rollback preserva a tag anterior da Unidade'
);

SELECT is(
  (SELECT count(*)::integer FROM public.rfid_tag_operations WHERE idempotency_key = 'rfid:rollback:0001'),
  0,
  'rollback não deixa auditoria RFID parcial'
);

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"d2222222-2222-2222-2222-222222222222","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
    SELECT public.resolver_excecao_conferencia_saida(
      (
        SELECT cd.id
        FROM public.conferencia_decisoes cd
        JOIN public.conferencias c ON c.id = cd.conferencia_id
        WHERE c.projeto_id = 'd5555555-5555-5555-5555-555555555555'
          AND cd.serial_number_id = 'd4444444-4444-4444-4444-444444444443'
      ),
      'ADICIONAR',
      1,
      'review:add:0001'
    )
  $$,
  'P0001',
  'IDEMPOTENCY_KEY_CONFLICT',
  'retry da resolução por outro operador falha fechado'
);

RESET ROLE;

UPDATE public.profiles
SET role = 'viewer'
WHERE id = 'd2222222-2222-2222-2222-222222222222'::uuid;

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"d2222222-2222-2222-2222-222222222222","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
    SELECT public.aplicar_vinculo_rfid(
      'd4444444-4444-4444-4444-444444444441',
      'E28011702000020A5C41A003',
      'rfid:viewer:0001'
    )
  $$,
  '42501',
  'Perfil sem permissão para Etiquetar',
  'viewer não pode alterar associação RFID'
);

RESET ROLE;
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.resolver_epc_rfid(text)',
    'EXECUTE'
  ),
  'anon não executa Identificar interno'
);

SELECT * FROM finish();
ROLLBACK;
