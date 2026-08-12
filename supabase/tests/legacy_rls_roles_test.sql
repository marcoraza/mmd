BEGIN;

SELECT plan(32);

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
    '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'authenticated',
    'authenticated',
    'viewer-rls@test.local',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '22222222-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
    'authenticated',
    'authenticated',
    'editor-rls@test.local',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(),
    now()
  );

UPDATE public.profiles
SET role = 'editor'
WHERE id = '22222222-bbbb-bbbb-bbbb-bbbbbbbbbbb2';

INSERT INTO public.items (id, nome, categoria, quantidade_total)
VALUES ('33333333-3333-3333-3333-333333333333', 'Item RLS legado', 'ILUMINACAO', 1);

INSERT INTO public.serial_numbers (id, item_id, codigo_interno, qr_code)
VALUES (
  '44444444-4444-4444-4444-444444444444',
  '33333333-3333-3333-3333-333333333333',
  'MMD-ILU-RLS-001',
  'QR-RLS-001'
);

INSERT INTO public.projetos (id, nome, status)
VALUES ('55555555-5555-5555-5555-555555555555', 'Evento RLS legado', 'CONFIRMADO');

INSERT INTO public.packing_list (id, projeto_id, item_id, quantidade)
VALUES (
  '66666666-6666-6666-6666-666666666666',
  '55555555-5555-5555-5555-555555555555',
  '33333333-3333-3333-3333-333333333333',
  1
);

INSERT INTO public.lotes (id, item_id, codigo_lote, quantidade)
VALUES (
  '77777777-7777-7777-7777-777777777777',
  '33333333-3333-3333-3333-333333333333',
  'MMD-LOT-RLS-001',
  1
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN ('items', 'serial_numbers', 'projetos', 'packing_list', 'movimentacoes', 'lotes')
      AND c.relrowsecurity
  ),
  6,
  'RLS está ativa nas seis tabelas legadas'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM (VALUES
      ('items'),
      ('serial_numbers'),
      ('projetos'),
      ('packing_list'),
      ('movimentacoes'),
      ('lotes')
    ) AS tables(table_name)
    CROSS JOIN (VALUES ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE')) AS actions(privilege_type)
    WHERE has_table_privilege('anon', 'public.' || table_name, privilege_type)
  ),
  0,
  'anon não recebe DML nas tabelas legadas'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM (VALUES
      ('items'),
      ('serial_numbers'),
      ('projetos'),
      ('packing_list'),
      ('movimentacoes'),
      ('lotes')
    ) AS tables(table_name)
    CROSS JOIN (VALUES ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE')) AS actions(privilege_type)
    WHERE has_table_privilege('authenticated', 'public.' || table_name, privilege_type)
  ),
  24,
  'authenticated mantém os grants necessários para as policies'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('items', 'serial_numbers', 'projetos', 'packing_list', 'movimentacoes', 'lotes')
      AND roles = ARRAY['authenticated']::name[]
  ),
  24,
  'as seis tabelas mantêm policies explícitas para authenticated'
);

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);

SELECT throws_ok(
  $$SELECT * FROM public.items$$,
  '42501',
  'permission denied for table items',
  'anon não lê catálogo interno'
);

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"11111111-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated"}',
  true
);

SELECT lives_ok(
  $$SELECT * FROM public.items WHERE id = '33333333-3333-3333-3333-333333333333'$$,
  'viewer autenticado lê o catálogo interno'
);

SELECT lives_ok(
  $$SELECT * FROM public.serial_numbers WHERE id = '44444444-4444-4444-4444-444444444444'$$,
  'viewer autenticado lê Unidades'
);

SELECT lives_ok(
  $$SELECT * FROM public.projetos WHERE id = '55555555-5555-5555-5555-555555555555'$$,
  'viewer autenticado lê Eventos'
);

SELECT lives_ok(
  $$SELECT * FROM public.packing_list WHERE id = '66666666-6666-6666-6666-666666666666'$$,
  'viewer autenticado lê packing'
);

SELECT lives_ok(
  $$SELECT * FROM public.movimentacoes WHERE serial_number_id = '44444444-4444-4444-4444-444444444444'$$,
  'viewer autenticado lê auditoria de movimentações'
);

SELECT lives_ok(
  $$SELECT * FROM public.lotes WHERE id = '77777777-7777-7777-7777-777777777777'$$,
  'viewer autenticado lê lotes legados'
);

SELECT lives_ok(
  $$
    UPDATE public.items
    SET notas = 'tentativa viewer'
    WHERE id = '33333333-3333-3333-3333-333333333333'
  $$,
  'tentativa de alteração por viewer não escapa da policy'
);

SELECT is(
  (
    SELECT notas
    FROM public.items
    WHERE id = '33333333-3333-3333-3333-333333333333'
  ),
  NULL::text,
  'viewer não altera catálogo interno'
);

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"22222222-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated"}',
  true
);

SELECT lives_ok(
  $$UPDATE public.items SET notas = 'editor' WHERE id = '33333333-3333-3333-3333-333333333333'$$,
  'editor altera Item'
);

SELECT lives_ok(
  $$UPDATE public.serial_numbers SET localizacao = 'Galpão A' WHERE id = '44444444-4444-4444-4444-444444444444'$$,
  'editor altera Unidade'
);

SELECT set_config('app_private.physical_operation', 'true', true);
SELECT set_config('app_private.rfid_tag_operation', 'true', true);

SELECT throws_ok(
  $$UPDATE public.serial_numbers SET status = 'EM_CAMPO' WHERE id = '44444444-4444-4444-4444-444444444444'$$,
  '42501',
  'PHYSICAL_OPERATION_WRITE_REQUIRES_RPC',
  'editor não altera o estado físico da Unidade fora da Conferência'
);

SELECT throws_ok(
  $$UPDATE public.serial_numbers SET tag_rfid = 'E2000017221101441890BEEF' WHERE id = '44444444-4444-4444-4444-444444444444'$$,
  '42501',
  'RFID_TAG_WRITE_REQUIRES_OPERATION',
  'editor não forja autorização RFID com GUC de sessão'
);

SELECT lives_ok(
  $$UPDATE public.projetos SET notas = 'editor' WHERE id = '55555555-5555-5555-5555-555555555555'$$,
  'editor altera Evento'
);

SELECT lives_ok(
  $$UPDATE public.packing_list SET notas = 'editor' WHERE id = '66666666-6666-6666-6666-666666666666'$$,
  'editor altera packing'
);

SELECT lives_ok(
  $$UPDATE public.lotes SET descricao = 'legado' WHERE id = '77777777-7777-7777-7777-777777777777'$$,
  'editor altera lote legado'
);

SELECT throws_ok(
  $$
    INSERT INTO public.movimentacoes (
      serial_number_id,
      projeto_id,
      tipo,
      status_anterior,
      status_novo,
      registrado_por,
      metodo_scan
    ) VALUES (
      '44444444-4444-4444-4444-444444444444',
      '55555555-5555-5555-5555-555555555555',
      'TRANSFERENCIA',
      'DISPONIVEL',
      'DISPONIVEL',
      'editor-rls@test.local',
      'MANUAL'
    )
  $$,
  '42501',
  'PHYSICAL_OPERATION_WRITE_REQUIRES_RPC',
  'editor não registra movimentação física fora da RPC canônica'
);

SELECT throws_ok(
  $$
    INSERT INTO public.retorno_pendencias (
      projeto_id,
      serial_number_id,
      registrado_por
    ) VALUES (
      '55555555-5555-5555-5555-555555555555',
      '44444444-4444-4444-4444-444444444444',
      'editor-rls@test.local'
    )
  $$,
  '42501',
  'PHYSICAL_OPERATION_WRITE_REQUIRES_RPC',
  'editor não abre pendência fora da confirmação de retorno'
);

RESET ROLE;
SET LOCAL ROLE service_role;
SELECT set_config('app_private.physical_operation', 'true', true);
SELECT set_config('app_private.rfid_tag_operation', 'true', true);

SELECT lives_ok(
  $$UPDATE public.serial_numbers SET desgaste = 4 WHERE id = '44444444-4444-4444-4444-444444444444'$$,
  'service_role preserva edição não física da Unidade'
);

SELECT throws_ok(
  $$UPDATE public.serial_numbers SET status = 'EM_CAMPO' WHERE id = '44444444-4444-4444-4444-444444444444'$$,
  '42501',
  'PHYSICAL_OPERATION_WRITE_REQUIRES_RPC',
  'service_role não forja alteração de estado físico com GUC de sessão'
);

SELECT throws_ok(
  $$UPDATE public.serial_numbers SET tag_rfid = 'E2000017221101441890CAFE' WHERE id = '44444444-4444-4444-4444-444444444444'$$,
  '42501',
  'RFID_TAG_WRITE_REQUIRES_OPERATION',
  'service_role não forja alteração RFID com GUC de sessão'
);

SELECT throws_ok(
  $$
    INSERT INTO public.movimentacoes (
      serial_number_id,
      projeto_id,
      tipo,
      status_anterior,
      status_novo,
      registrado_por,
      metodo_scan
    ) VALUES (
      '44444444-4444-4444-4444-444444444444',
      '55555555-5555-5555-5555-555555555555',
      'TRANSFERENCIA',
      'DISPONIVEL',
      'DISPONIVEL',
      'service-role@test.local',
      'MANUAL'
    )
  $$,
  '42501',
  'PHYSICAL_OPERATION_WRITE_REQUIRES_RPC',
  'service_role não forja movimentação física com GUC de sessão'
);

SELECT throws_ok(
  $$
    INSERT INTO public.retorno_pendencias (
      projeto_id,
      serial_number_id,
      registrado_por
    ) VALUES (
      '55555555-5555-5555-5555-555555555555',
      '44444444-4444-4444-4444-444444444444',
      'service-role@test.local'
    )
  $$,
  '42501',
  'PHYSICAL_OPERATION_WRITE_REQUIRES_RPC',
  'service_role não forja pendência com GUC de sessão'
);

RESET ROLE;

SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.confirmar_conferencia_saida(uuid,uuid[],bigint,text,text)',
    'EXECUTE'
  ),
  'service_role sem ator não executa confirmação física'
);

SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.checkout_projeto(uuid,public.metodo_scan_enum,text)',
    'EXECUTE'
  ),
  'service_role não executa checkout legado'
);

SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.checkout_projeto_com_override(uuid,public.metodo_scan_enum,text,uuid)',
    'EXECUTE'
  ),
  'service_role não executa override legado'
);

SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.checkin_projeto(uuid,public.metodo_scan_enum,text,jsonb)',
    'EXECUTE'
  ),
  'service_role não executa retorno legado'
);

SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.resolver_retorno_pendencia(uuid,text,text,text)',
    'EXECUTE'
  ),
  'service_role não executa resolução legada'
);

SELECT * FROM finish();

ROLLBACK;
