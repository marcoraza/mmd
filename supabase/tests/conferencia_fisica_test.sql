BEGIN;
SELECT plan(63);

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
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'authenticated',
    'authenticated',
    'operador-a@test.local',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
    'authenticated',
    'authenticated',
    'operador-b@test.local',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'cccccccc-cccc-cccc-cccc-ccccccccccc3',
    'authenticated',
    'authenticated',
    'leitor@test.local',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(),
    now()
  );

UPDATE public.profiles
SET role = 'editor'
WHERE id IN (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2'
);

INSERT INTO public.items (id, nome, categoria, quantidade_total)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'Moving Head Teste',
  'ILUMINACAO',
  1
);

INSERT INTO public.serial_numbers (id, item_id, codigo_interno, qr_code)
VALUES
  (
    '22222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'MMD-ILU-T001',
    'QR-TESTE-001'
  ),
  (
    '22222222-2222-2222-2222-222222222223',
    '11111111-1111-1111-1111-111111111111',
    'MMD-ILU-T002',
    'QR-TESTE-002'
  );

INSERT INTO public.projetos (id, nome, status)
VALUES (
  '33333333-3333-3333-3333-333333333333',
  'Evento Conferência Teste',
  'CONFIRMADO'
);

INSERT INTO public.packing_list (
  id,
  projeto_id,
  item_id,
  quantidade,
  serial_numbers_designados
) VALUES (
  '44444444-4444-4444-4444-444444444444',
  '33333333-3333-3333-3333-333333333333',
  '11111111-1111-1111-1111-111111111111',
  2,
  ARRAY[
    '22222222-2222-2222-2222-222222222222'::uuid,
    '22222222-2222-2222-2222-222222222223'::uuid
  ]
);

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated"}',
  true
);

SELECT lives_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '33333333-3333-3333-3333-333333333333',
      'SAIDA',
      '22222222-2222-2222-2222-222222222222',
      'PRESENTE',
      'QRCODE',
      'qr:read-001',
      '2026-08-10T21:00:00Z',
      NULL,
      'Primeira leitura'
    )
  $$,
  'operador A salva uma decisão unitária'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.conferencias
    WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
      AND direcao = 'SAIDA'
  ),
  1,
  'existe uma Conferência de saída por Evento'
);

SELECT is(
  (
    SELECT version
    FROM public.conferencias
    WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
      AND direcao = 'SAIDA'
  ),
  1::bigint,
  'primeira decisão avança a versão do rascunho'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated"}',
  true
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.conferencia_decisoes cd
    JOIN public.conferencias c ON c.id = cd.conferencia_id
    WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
      AND c.direcao = 'SAIDA'
      AND cd.serial_number_id = '22222222-2222-2222-2222-222222222222'
  ),
  1,
  'operador B recupera a decisão salva pelo operador A'
);

SELECT lives_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '33333333-3333-3333-3333-333333333333',
      'SAIDA',
      '22222222-2222-2222-2222-222222222222',
      'PRESENTE',
      'QRCODE',
      'qr:read-002',
      '2026-08-10T21:05:00Z',
      NULL,
      'Revisada pelo segundo operador'
    )
  $$,
  'operador B continua o mesmo rascunho'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.conferencia_decisoes cd
    JOIN public.conferencias c ON c.id = cd.conferencia_id
    WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
      AND c.direcao = 'SAIDA'
  ),
  1,
  'last-write-wins atualiza a decisão sem duplicar a Unidade'
);

SELECT is(
  (
    SELECT version
    FROM public.conferencias
    WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
      AND direcao = 'SAIDA'
  ),
  2::bigint,
  'continuação por outro operador avança a versão'
);

SELECT lives_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (
        SELECT id
        FROM public.conferencias
        WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
          AND direcao = 'SAIDA'
      ),
      ARRAY[
        (
          SELECT cd.id
          FROM public.conferencia_decisoes cd
          JOIN public.conferencias c ON c.id = cd.conferencia_id
          WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
            AND c.direcao = 'SAIDA'
            AND cd.serial_number_id = '22222222-2222-2222-2222-222222222222'
        )
      ],
      2,
      'checkout:test:001',
      'A segunda Unidade ainda está no galpão'
    )
  $$,
  'confirmação parcial aplica somente a Unidade escolhida'
);

SELECT results_eq(
  $$
    SELECT codigo_interno, status::text
    FROM public.serial_numbers
    WHERE id IN (
      '22222222-2222-2222-2222-222222222222',
      '22222222-2222-2222-2222-222222222223'
    )
    ORDER BY codigo_interno
  $$,
  $$VALUES
    ('MMD-ILU-T001'::text, 'EM_CAMPO'::text),
    ('MMD-ILU-T002'::text, 'DISPONIVEL'::text)
  $$,
  'Unidade confirmada sai e Unidade apenas alocada permanece intacta'
);

SELECT is(
  (
    SELECT status::text
    FROM public.projetos
    WHERE id = '33333333-3333-3333-3333-333333333333'
  ),
  'EM_CAMPO',
  'primeira confirmação coloca o Evento em campo'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.movimentacoes
    WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
      AND tipo = 'SAIDA'
  ),
  1,
  'confirmação parcial cria uma movimentação'
);

SELECT lives_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (
        SELECT id
        FROM public.conferencias
        WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
          AND direcao = 'SAIDA'
      ),
      ARRAY[
        (
          SELECT cd.id
          FROM public.conferencia_decisoes cd
          JOIN public.conferencias c ON c.id = cd.conferencia_id
          WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
            AND cd.serial_number_id = '22222222-2222-2222-2222-222222222222'
        )
      ],
      2,
      'checkout:test:001',
      'A segunda Unidade ainda está no galpão'
    )
  $$,
  'retry com a mesma chave e payload retorna o Recibo existente'
);

SELECT is(
  (
    public.confirmar_conferencia_saida(
      (
        SELECT id
        FROM public.conferencias
        WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
          AND direcao = 'SAIDA'
      ),
      ARRAY[
        (
          SELECT cd.id
          FROM public.conferencia_decisoes cd
          JOIN public.conferencias c ON c.id = cd.conferencia_id
          WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
            AND cd.serial_number_id = '22222222-2222-2222-2222-222222222222'
        )
      ],
      2,
      'checkout:test:001',
      'A segunda Unidade ainda está no galpão'
    )->>'confirmation_id'
  )::uuid,
  (
    SELECT id
    FROM public.conferencia_confirmacoes
    WHERE idempotency_key = 'checkout:test:001'
  ),
  'retry devolve o mesmo identificador de Recibo'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (
        SELECT id
        FROM public.conferencias
        WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
          AND direcao = 'SAIDA'
      ),
      ARRAY[
        (
          SELECT cd.id
          FROM public.conferencia_decisoes cd
          JOIN public.conferencias c ON c.id = cd.conferencia_id
          WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
            AND cd.serial_number_id = '22222222-2222-2222-2222-222222222222'
        )
      ],
      2,
      'checkout:test:001',
      'A segunda Unidade ainda está no galpão'
    )
  $$,
  'P0001',
  'IDEMPOTENCY_KEY_CONFLICT',
  'outro operador não recebe Recibo de saída alheio'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated"}',
  true
);

SELECT is(
  public.confirmar_conferencia_saida(
    (
      SELECT id FROM public.conferencias
      WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
        AND direcao = 'SAIDA'
    ),
    ARRAY[
      (
        SELECT cd.id
        FROM public.conferencia_decisoes cd
        JOIN public.conferencias c ON c.id = cd.conferencia_id
        WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
          AND cd.serial_number_id = '22222222-2222-2222-2222-222222222222'
      )
    ],
    2,
    'checkout:test:001',
    'A segunda Unidade ainda está no galpão'
  ) #>> '{units,0,actor_id}',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
  'Recibo preserva o operador que decidiu cada Unidade'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.movimentacoes
    WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
      AND tipo = 'SAIDA'
  ),
  1,
  'retry não duplica movimentação'
);

SELECT throws_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (
        SELECT id
        FROM public.conferencias
        WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
          AND direcao = 'SAIDA'
      ),
      ARRAY[
        (
          SELECT cd.id
          FROM public.conferencia_decisoes cd
          JOIN public.conferencias c ON c.id = cd.conferencia_id
          WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
            AND cd.serial_number_id = '22222222-2222-2222-2222-222222222222'
        )
      ],
      2,
      'checkout:test:001',
      'Payload diferente para a mesma chave'
    )
  $$,
  'P0001',
  'IDEMPOTENCY_KEY_CONFLICT',
  'mesma chave com payload diferente retorna conflito'
);

SELECT lives_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '33333333-3333-3333-3333-333333333333',
      'SAIDA',
      '22222222-2222-2222-2222-222222222223',
      'PRESENTE',
      'QRCODE',
      'qr:read-003',
      '2026-08-10T21:10:00Z',
      NULL,
      'Inclusão posterior'
    )
  $$,
  'a mesma Conferência aceita inclusão posterior'
);

SELECT is(
  (
    SELECT version
    FROM public.conferencias
    WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
      AND direcao = 'SAIDA'
  ),
  4::bigint,
  'confirmação e inclusão posterior avançam a versão'
);

SELECT lives_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (
        SELECT id
        FROM public.conferencias
        WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
          AND direcao = 'SAIDA'
      ),
      ARRAY[
        (
          SELECT cd.id
          FROM public.conferencia_decisoes cd
          JOIN public.conferencias c ON c.id = cd.conferencia_id
          WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
            AND cd.serial_number_id = '22222222-2222-2222-2222-222222222223'
        )
      ],
      4,
      'checkout:test:002',
      NULL
    )
  $$,
  'inclusão posterior aplica a Unidade restante'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.serial_numbers
    WHERE id IN (
      '22222222-2222-2222-2222-222222222222',
      '22222222-2222-2222-2222-222222222223'
    )
      AND status = 'EM_CAMPO'
  ),
  2,
  'as duas Unidades confirmadas ficam em campo'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.movimentacoes
    WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
      AND tipo = 'SAIDA'
  ),
  2,
  'cada Unidade aplicada possui uma única movimentação'
);

SELECT throws_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '33333333-3333-3333-3333-333333333333',
      'SAIDA',
      '22222222-2222-2222-2222-222222222222',
      'PRESENTE',
      'QRCODE',
      'qr:read-applied',
      '2026-08-10T21:20:00Z',
      NULL,
      'Tentativa de reabrir decisão aplicada'
    )
  $$,
  '55000',
  'DECISION_ALREADY_APPLIED',
  'decisão aplicada não volta a rascunho'
);

SELECT results_eq(
  $$
    SELECT codigo_interno
    FROM public.conferencia_retorno_esperado(
      '33333333-3333-3333-3333-333333333333'
    )
    ORDER BY codigo_interno
  $$,
  $$VALUES
    ('MMD-ILU-T001'::text),
    ('MMD-ILU-T002'::text)
  $$,
  'retorno esperado nasce somente das saídas aplicadas'
);

RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-ccccccccccc3","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '33333333-3333-3333-3333-333333333333',
      'SAIDA',
      '22222222-2222-2222-2222-222222222224',
      'PRESENTE',
      'QRCODE',
      'qr:viewer-001',
      '2026-08-10T22:04:00Z',
      NULL,
      NULL
    )
  $$,
  '42501',
  'Perfil sem permissão para operar Conferência',
  'perfil autenticado sem papel operacional não salva decisão'
);

SELECT throws_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (SELECT id FROM public.conferencias WHERE projeto_id = '33333333-3333-3333-3333-333333333333' AND direcao = 'SAIDA'),
      ARRAY['99999999-9999-9999-9999-999999999999'::uuid],
      5,
      'checkout:viewer:001',
      NULL
    )
  $$,
  '42501',
  'Perfil sem permissão para confirmar Conferência',
  'perfil autenticado sem papel operacional não confirma saída'
);

RESET ROLE;

INSERT INTO public.conferencias (id, projeto_id, direcao, version)
VALUES (
  '55555555-5555-5555-5555-555555555555',
  '33333333-3333-3333-3333-333333333333',
  'RETORNO',
  1
);

INSERT INTO public.conferencia_confirmacoes (
  id,
  conferencia_id,
  idempotency_key,
  payload_hash,
  actor_id
) VALUES (
  '66666666-6666-6666-6666-666666666666',
  '55555555-5555-5555-5555-555555555555',
  'return:test:001',
  repeat('a', 64),
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2'
);

INSERT INTO public.conferencia_decisoes (
  conferencia_id,
  serial_number_id,
  resultado,
  metodo,
  source_event_id,
  captured_at,
  actor_id,
  applied_confirmation_id
) VALUES (
  '55555555-5555-5555-5555-555555555555',
  '22222222-2222-2222-2222-222222222222',
  'OK',
  'QRCODE',
  'qr:return-001',
  '2026-08-10T22:00:00Z',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
  '66666666-6666-6666-6666-666666666666'
);

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated"}',
  true
);

SELECT results_eq(
  $$
    SELECT codigo_interno
    FROM public.conferencia_retorno_esperado(
      '33333333-3333-3333-3333-333333333333'
    )
    ORDER BY codigo_interno
  $$,
  $$VALUES ('MMD-ILU-T002'::text)$$,
  'retorno aplicado remove a Unidade da lista esperada'
);

RESET ROLE;

SELECT ok(
  (
    SELECT relrowsecurity
    FROM pg_class
    WHERE oid = 'public.conferencias'::regclass
  ),
  'RLS está ativa em Conferências'
);

SELECT ok(
  (
    SELECT relrowsecurity
    FROM pg_class
    WHERE oid = 'public.conferencia_decisoes'::regclass
  ),
  'RLS está ativa em decisões'
);

SELECT ok(
  (
    SELECT relrowsecurity
    FROM pg_class
    WHERE oid = 'public.conferencia_confirmacoes'::regclass
  ),
  'RLS está ativa em confirmações'
);

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);

SELECT throws_ok(
  $$SELECT * FROM public.conferencias$$,
  '42501',
  'permission denied for table conferencias',
  'anon não lê Conferências'
);

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
    INSERT INTO public.conferencias (projeto_id, direcao)
    VALUES ('33333333-3333-3333-3333-333333333333', 'RETORNO')
  $$,
  '42501',
  'permission denied for table conferencias',
  'authenticated não contorna a RPC com escrita direta'
);

RESET ROLE;

SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.confirmar_conferencia_saida(uuid,uuid[],bigint,text,text)',
    'EXECUTE'
  ),
  'anon não possui grant da RPC'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.confirmar_conferencia_saida(uuid,uuid[],bigint,text,text)',
    'EXECUTE'
  ),
  'authenticated possui grant explícito da RPC'
);

SELECT ok(
  NOT has_table_privilege(
    'service_role',
    'public.conferencias',
    'INSERT'
  ),
  'service_role não possui atalho de escrita direta na Conferência'
);

SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.confirmar_conferencia_saida(uuid,uuid[],bigint,text,text)',
    'EXECUTE'
  ),
  'service_role sem ator autenticado não executa a confirmação'
);

SELECT throws_ok(
  $$
    UPDATE public.conferencia_confirmacoes
    SET incomplete_reason = 'Tentativa de edição'
    WHERE idempotency_key = 'checkout:test:001'
  $$,
  '55000',
  'CONFIRMATION_IMMUTABLE',
  'Recibo confirmado é imutável'
);

INSERT INTO public.serial_numbers (id, item_id, codigo_interno, qr_code)
VALUES (
  '22222222-2222-2222-2222-222222222224',
  '11111111-1111-1111-1111-111111111111',
  'MMD-ILU-T003',
  'QR-TESTE-003'
);

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '33333333-3333-3333-3333-333333333333',
      'SAIDA',
      '22222222-2222-2222-2222-222222222224',
      'PRESENTE',
      'MANUAL',
      'manual:test-001',
      '2026-08-10T22:05:00Z',
      NULL,
      NULL
    )
  $$,
  '22023',
  'Confirmação manual exige motivo',
  'decisão manual sem motivo é rejeitada'
);

SELECT lives_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '33333333-3333-3333-3333-333333333333',
      'SAIDA',
      '22222222-2222-2222-2222-222222222224',
      'PRESENTE',
      'MANUAL',
      'manual:test-002',
      '2026-08-10T22:06:00Z',
      'QR danificado',
      NULL
    )
  $$,
  'decisão manual com motivo entra no rascunho'
);

SELECT throws_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (
        SELECT id
        FROM public.conferencias
        WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
          AND direcao = 'SAIDA'
      ),
      ARRAY[
        (
          SELECT cd.id
          FROM public.conferencia_decisoes cd
          JOIN public.conferencias c ON c.id = cd.conferencia_id
          WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
            AND c.direcao = 'SAIDA'
            AND cd.serial_number_id = '22222222-2222-2222-2222-222222222224'
        )
      ],
      5,
      'checkout:stale:001',
      NULL
    )
  $$,
  '40001',
  'CONFERENCE_VERSION_CONFLICT',
  'versão antiga não sobrescreve rascunho remoto'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.conferencia_confirmacoes
    WHERE idempotency_key = 'checkout:stale:001'
  ),
  0,
  'conflito de versão não cria Recibo'
);

RESET ROLE;

UPDATE public.conferencia_decisoes cd
SET resolution = 'SEM_PACKING',
    replaced_serial_id = NULL
FROM public.conferencias c
WHERE c.id = cd.conferencia_id
  AND c.projeto_id = '33333333-3333-3333-3333-333333333333'
  AND cd.serial_number_id = '22222222-2222-2222-2222-222222222224';

CREATE OR REPLACE FUNCTION pg_temp.fail_conferencia_movement()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'INJECTED_MOVEMENT_FAILURE';
END;
$$;

CREATE TRIGGER trg_test_fail_conferencia_movement
BEFORE INSERT ON public.movimentacoes
FOR EACH ROW
WHEN (NEW.conferencia_confirmacao_id IS NOT NULL)
EXECUTE FUNCTION pg_temp.fail_conferencia_movement();

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (
        SELECT id
        FROM public.conferencias
        WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
          AND direcao = 'SAIDA'
      ),
      ARRAY[
        (
          SELECT cd.id
          FROM public.conferencia_decisoes cd
          JOIN public.conferencias c ON c.id = cd.conferencia_id
          WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
            AND c.direcao = 'SAIDA'
            AND cd.serial_number_id = '22222222-2222-2222-2222-222222222224'
        )
      ],
      6,
      'checkout:test:003',
      NULL
    )
  $$,
  'P0001',
  'INJECTED_MOVEMENT_FAILURE',
  'falha após iniciar confirmação aborta a transação'
);

RESET ROLE;
DROP TRIGGER trg_test_fail_conferencia_movement ON public.movimentacoes;

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated"}',
  true
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.conferencia_confirmacoes
    WHERE idempotency_key = 'checkout:test:003'
  ),
  0,
  'rollback remove o Recibo iniciado'
);

SELECT is(
  (
    SELECT status::text
    FROM public.serial_numbers
    WHERE id = '22222222-2222-2222-2222-222222222224'
  ),
  'DISPONIVEL',
  'rollback preserva o estado da Unidade'
);

SELECT is(
  (
    SELECT applied_confirmation_id
    FROM public.conferencia_decisoes cd
    JOIN public.conferencias c ON c.id = cd.conferencia_id
    WHERE c.projeto_id = '33333333-3333-3333-3333-333333333333'
      AND c.direcao = 'SAIDA'
      AND cd.serial_number_id = '22222222-2222-2222-2222-222222222224'
  ),
  NULL::uuid,
  'rollback mantém a decisão como rascunho'
);

SELECT is(
  (
    SELECT version
    FROM public.conferencias
    WHERE projeto_id = '33333333-3333-3333-3333-333333333333'
      AND direcao = 'SAIDA'
  ),
  6::bigint,
  'rollback preserva a versão anterior da Conferência'
);

RESET ROLE;

INSERT INTO public.projetos (id, nome, status)
VALUES (
  '77777777-7777-7777-7777-777777777777',
  'Evento sem packing',
  'CONFIRMADO'
);

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2","role":"authenticated"}',
  true
);

SELECT lives_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '77777777-7777-7777-7777-777777777777',
      'SAIDA',
      '22222222-2222-2222-2222-222222222224',
      'PRESENTE',
      'MANUAL',
      'manual:no-packing-001',
      '2026-08-10T22:10:00Z',
      'Saída emergencial',
      NULL
    )
  $$,
  'Evento sem packing ainda pode registrar presença física'
);

SELECT throws_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (
        SELECT id
        FROM public.conferencias
        WHERE projeto_id = '77777777-7777-7777-7777-777777777777'
          AND direcao = 'SAIDA'
      ),
      ARRAY[
        (
          SELECT cd.id
          FROM public.conferencia_decisoes cd
          JOIN public.conferencias c ON c.id = cd.conferencia_id
          WHERE c.projeto_id = '77777777-7777-7777-7777-777777777777'
            AND c.direcao = 'SAIDA'
        )
      ],
      1,
      'checkout:no-packing:001',
      NULL
    )
  $$,
  '22023',
  'Saída incompleta exige motivo',
  'Evento sem packing não confirma em silêncio'
);

SELECT lives_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (
        SELECT id
        FROM public.conferencias
        WHERE projeto_id = '77777777-7777-7777-7777-777777777777'
          AND direcao = 'SAIDA'
      ),
      ARRAY[
        (
          SELECT cd.id
          FROM public.conferencia_decisoes cd
          JOIN public.conferencias c ON c.id = cd.conferencia_id
          WHERE c.projeto_id = '77777777-7777-7777-7777-777777777777'
            AND c.direcao = 'SAIDA'
        )
      ],
      1,
      'checkout:no-packing:002',
      'Operação emergencial sem packing cadastrado'
    )
  $$,
  'override com motivo permite a saída sem fabricar presença'
);

SELECT is(
  (
    SELECT status::text
    FROM public.serial_numbers
    WHERE id = '22222222-2222-2222-2222-222222222224'
  ),
  'EM_CAMPO',
  'override move somente a Unidade fisicamente confirmada'
);

RESET ROLE;

INSERT INTO public.serial_numbers (id, item_id, codigo_interno, qr_code)
VALUES
  ('22222222-2222-2222-2222-222222222225', '11111111-1111-1111-1111-111111111111', 'MMD-ILU-T004', 'QR-TESTE-004'),
  ('22222222-2222-2222-2222-222222222226', '11111111-1111-1111-1111-111111111111', 'MMD-ILU-T005', 'QR-TESTE-005');

INSERT INTO public.projetos (id, nome, status)
VALUES ('88888888-8888-8888-8888-888888888888', 'Evento Substituição', 'CONFIRMADO');

INSERT INTO public.packing_list (id, projeto_id, item_id, quantidade, serial_numbers_designados)
VALUES (
  '44444444-4444-4444-4444-444444444445',
  '88888888-8888-8888-8888-888888888888',
  '11111111-1111-1111-1111-111111111111',
  1,
  ARRAY['22222222-2222-2222-2222-222222222225'::uuid]
);

UPDATE public.serial_numbers
SET status = 'MANUTENCAO'
WHERE id = '22222222-2222-2222-2222-222222222226';

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated"}',
  true
);

SELECT lives_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '88888888-8888-8888-8888-888888888888',
      'SAIDA',
      '22222222-2222-2222-2222-222222222226',
      'PRESENTE',
      'RFID',
      'rfid:unavailable-001',
      '2026-08-10T22:59:00Z',
      NULL,
      NULL
    )
  $$,
  'Unidade indisponível fica persistida para Revisar'
);

SELECT is(
  (
    SELECT resolution::text
    FROM public.conferencia_decisoes cd
    JOIN public.conferencias c ON c.id = cd.conferencia_id
    WHERE c.projeto_id = '88888888-8888-8888-8888-888888888888'
  ),
  'REVISAR',
  'Unidade indisponível não substitui serial alocado'
);

RESET ROLE;
UPDATE public.serial_numbers
SET status = 'DISPONIVEL'
WHERE id = '22222222-2222-2222-2222-222222222226';
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated"}',
  true
);

SELECT lives_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '88888888-8888-8888-8888-888888888888',
      'SAIDA',
      '22222222-2222-2222-2222-222222222226',
      'PRESENTE',
      'RFID',
      'rfid:substitute-001',
      '2026-08-10T23:00:00Z',
      NULL,
      NULL
    )
  $$,
  'Unidade disponível do mesmo Item entra como substituição'
);

SELECT is(
  (
    SELECT resolution::text
    FROM public.conferencia_decisoes cd
    JOIN public.conferencias c ON c.id = cd.conferencia_id
    WHERE c.projeto_id = '88888888-8888-8888-8888-888888888888'
  ),
  'SUBSTITUICAO',
  'substituição fica persistida antes de confirmar'
);

SELECT lives_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '88888888-8888-8888-8888-888888888888',
      'SAIDA',
      '22222222-2222-2222-2222-222222222226',
      'PRESENTE',
      'RFID',
      'rfid:substitute-replay-001',
      '2026-08-10T23:00:01Z',
      NULL,
      NULL
    )
  $$,
  'replay da mesma Unidade substituta preserva a decisão'
);

SELECT is(
  (
    SELECT replaced_serial_id
    FROM public.conferencia_decisoes cd
    JOIN public.conferencias c ON c.id = cd.conferencia_id
    WHERE c.projeto_id = '88888888-8888-8888-8888-888888888888'
  ),
  '22222222-2222-2222-2222-222222222225'::uuid,
  'replay mantém o mesmo serial substituído'
);

RESET ROLE;
CREATE OR REPLACE FUNCTION pg_temp.fail_substitution_movement()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'INJECTED_SUBSTITUTION_FAILURE';
END;
$$;

CREATE TRIGGER trg_test_fail_substitution_movement
BEFORE INSERT ON public.movimentacoes
FOR EACH ROW
WHEN (NEW.conferencia_confirmacao_id IS NOT NULL)
EXECUTE FUNCTION pg_temp.fail_substitution_movement();

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (SELECT id FROM public.conferencias WHERE projeto_id = '88888888-8888-8888-8888-888888888888' AND direcao = 'SAIDA'),
      ARRAY[(SELECT cd.id FROM public.conferencia_decisoes cd JOIN public.conferencias c ON c.id = cd.conferencia_id WHERE c.projeto_id = '88888888-8888-8888-8888-888888888888')],
      3,
      'checkout:substitute:failure',
      NULL
    )
  $$,
  'P0001',
  'INJECTED_SUBSTITUTION_FAILURE',
  'falha após substituir aborta a confirmação inteira'
);

RESET ROLE;
DROP TRIGGER trg_test_fail_substitution_movement ON public.movimentacoes;

SELECT is(
  (SELECT serial_numbers_designados[1] FROM public.packing_list WHERE projeto_id = '88888888-8888-8888-8888-888888888888'),
  '22222222-2222-2222-2222-222222222225'::uuid,
  'rollback restaura o packing anterior à substituição'
);

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated"}',
  true
);

SELECT lives_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (SELECT id FROM public.conferencias WHERE projeto_id = '88888888-8888-8888-8888-888888888888' AND direcao = 'SAIDA'),
      ARRAY[(SELECT cd.id FROM public.conferencia_decisoes cd JOIN public.conferencias c ON c.id = cd.conferencia_id WHERE c.projeto_id = '88888888-8888-8888-8888-888888888888')],
      3,
      'checkout:substitute:001',
      NULL
    )
  $$,
  'substituição confirmada atualiza a verdade operacional'
);

SELECT is(
  (SELECT serial_numbers_designados[1] FROM public.packing_list WHERE projeto_id = '88888888-8888-8888-8888-888888888888'),
  '22222222-2222-2222-2222-222222222226'::uuid,
  'packing passa a apontar para a Unidade substituta'
);

RESET ROLE;

SELECT is(
  (
    SELECT app_private.conferencia_recibo(id) #>> '{units,0,replaced_serial_id}'
    FROM public.conferencia_confirmacoes
    WHERE idempotency_key = 'checkout:substitute:001'
  ),
  '22222222-2222-2222-2222-222222222225',
  'Recibo audita qual Unidade foi substituída'
);

RESET ROLE;

INSERT INTO public.items (id, nome, categoria, quantidade_total)
VALUES ('11111111-1111-1111-1111-111111111112', 'Caixa fora do packing', 'ACESSORIO', 1);

INSERT INTO public.serial_numbers (id, item_id, codigo_interno, qr_code)
VALUES ('22222222-2222-2222-2222-222222222227', '11111111-1111-1111-1111-111111111112', 'MMD-ACE-T001', 'QR-TESTE-006');

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1","role":"authenticated"}',
  true
);

SELECT lives_ok(
  $$
    SELECT public.salvar_decisao_conferencia(
      '88888888-8888-8888-8888-888888888888',
      'SAIDA',
      '22222222-2222-2222-2222-222222222227',
      'PRESENTE',
      'QRCODE',
      'qr:review-001',
      '2026-08-10T23:05:00Z',
      NULL,
      NULL
    )
  $$,
  'Item fora do packing fica persistido para Revisar'
);

SELECT throws_ok(
  $$
    SELECT public.confirmar_conferencia_saida(
      (SELECT id FROM public.conferencias WHERE projeto_id = '88888888-8888-8888-8888-888888888888' AND direcao = 'SAIDA'),
      ARRAY[(SELECT cd.id FROM public.conferencia_decisoes cd JOIN public.conferencias c ON c.id = cd.conferencia_id WHERE c.projeto_id = '88888888-8888-8888-8888-888888888888' AND cd.serial_number_id = '22222222-2222-2222-2222-222222222227')],
      5,
      'checkout:review:001',
      'Item fora do packing'
    )
  $$,
  '22023',
  'EXTRA_REQUIRES_RESOLUTION',
  'Item fora do packing não sai sem ação Adicionar ou Ignorar'
);

SELECT * FROM finish();
ROLLBACK;
