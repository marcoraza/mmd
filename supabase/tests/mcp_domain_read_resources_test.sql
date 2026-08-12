BEGIN;
SELECT plan(10);

GRANT mmd_mcp_executor TO postgres;

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7',
  'authenticated',
  'authenticated',
  'mcp-read-resources@test.local',
  '',
  now(),
  '{"provider":"email","providers":["email"]}',
  '{}',
  now(),
  now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, role)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7', 'mcp-read-resources@test.local', 'viewer')
ON CONFLICT (id) DO UPDATE SET role = excluded.role;

INSERT INTO public.mcp_clients (client_id, resource_audience, scopes)
VALUES (
  'mcp-read-resources',
  'https://mmd.test/api/mcp',
  ARRAY['mcp:read']::text[]
) ON CONFLICT (client_id) DO UPDATE
SET active = true, revoked_at = NULL, scopes = excluded.scopes, resource_audience = excluded.resource_audience;

INSERT INTO public.items (id, nome, categoria, quantidade_total, valor_mercado_unitario, notas)
VALUES (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7',
  'Moving Head MCP',
  'ILUMINACAO',
  2,
  999.99,
  'NAO_VAZAR_NOTA_DE_CATALOGO'
) ON CONFLICT (id) DO UPDATE
SET nome = excluded.nome, categoria = excluded.categoria, quantidade_total = excluded.quantidade_total,
    valor_mercado_unitario = excluded.valor_mercado_unitario, notas = excluded.notas;

INSERT INTO public.serial_numbers (
  id, item_id, codigo_interno, serial_fabrica, tag_rfid, qr_code, status, localizacao, notas
) VALUES (
  'cccccccc-cccc-4ccc-8ccc-ccccccccccc7',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7',
  'MMD-ILU-9007',
  'SERIAL-FABRICA-VETADO',
  'E2000017221101441890ABCD',
  'QR-VETADO',
  'EM_CAMPO',
  'Galpao secreto',
  'NAO_VAZAR_NOTA_DA_UNIDADE'
) ON CONFLICT (id) DO UPDATE
SET item_id = excluded.item_id, codigo_interno = excluded.codigo_interno,
    serial_fabrica = excluded.serial_fabrica, tag_rfid = excluded.tag_rfid,
    qr_code = excluded.qr_code, status = excluded.status,
    localizacao = excluded.localizacao, notas = excluded.notas;

INSERT INTO public.projetos (id, nome, cliente, data_inicio, data_fim, local, status, notas)
VALUES (
  'dddddddd-dddd-4ddd-8ddd-ddddddddddd7',
  'Evento MCP de Leitura',
  'CLIENTE_NAO_VAZAR',
  '2026-08-20',
  '2026-08-21',
  'Palco A',
  'EM_CAMPO',
  'NAO_VAZAR_NOTA_DO_EVENTO'
) ON CONFLICT (id) DO UPDATE
SET nome = excluded.nome, cliente = excluded.cliente, data_inicio = excluded.data_inicio,
    data_fim = excluded.data_fim, local = excluded.local, status = excluded.status, notas = excluded.notas;

INSERT INTO public.packing_list (
  id, projeto_id, item_id, quantidade, serial_numbers_designados, alugueis_avulsos, notas
) VALUES (
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee7',
  'dddddddd-dddd-4ddd-8ddd-ddddddddddd7',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7',
  2,
  ARRAY['cccccccc-cccc-4ccc-8ccc-ccccccccccc7']::uuid[],
  '[{"quantidade":1}]'::jsonb,
  'NAO_VAZAR_NOTA_DO_PACKING'
) ON CONFLICT (id) DO UPDATE
SET quantidade = excluded.quantidade, serial_numbers_designados = excluded.serial_numbers_designados,
    alugueis_avulsos = excluded.alugueis_avulsos, notas = excluded.notas;

INSERT INTO public.conferencias (id, projeto_id, direcao, version)
VALUES ('ffffffff-ffff-4fff-8fff-fffffffffff7', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd7', 'SAIDA', 1)
ON CONFLICT (id) DO UPDATE SET version = excluded.version;

INSERT INTO public.conferencia_decisoes (
  id, conferencia_id, serial_number_id, resultado, metodo, source_event_id,
  captured_at, actor_id, observation, resolution
) VALUES (
  '11111111-1111-4111-8111-111111111117',
  'ffffffff-ffff-4fff-8fff-fffffffffff7',
  'cccccccc-cccc-4ccc-8ccc-ccccccccccc7',
  'PRESENTE',
  'RFID',
  'NAO_VAZAR_SOURCE_EVENT',
  now(),
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7',
  'NAO_VAZAR_OBSERVACAO_DA_DECISAO',
  'DESIGNADA'
) ON CONFLICT (id) DO UPDATE
SET source_event_id = excluded.source_event_id, observation = excluded.observation;

INSERT INTO public.movimentacoes (
  id, serial_number_id, projeto_id, tipo, status_anterior, status_novo, registrado_por, metodo_scan, notas
) VALUES (
  '22222222-2222-4222-8222-222222222227',
  'cccccccc-cccc-4ccc-8ccc-ccccccccccc7',
  'dddddddd-dddd-4ddd-8ddd-ddddddddddd7',
  'SAIDA',
  'DISPONIVEL',
  'EM_CAMPO',
  'NOME_NAO_VAZAR',
  'RFID',
  'NAO_VAZAR_NOTA_DA_MOVIMENTACAO'
) ON CONFLICT (id) DO UPDATE
SET registrado_por = excluded.registrado_por, notas = excluded.notas;

INSERT INTO public.retorno_pendencias (
  id, projeto_id, serial_number_id, status, observacao, registrado_por
) VALUES (
  '33333333-3333-4333-8333-333333333337',
  'dddddddd-dddd-4ddd-8ddd-ddddddddddd7',
  'cccccccc-cccc-4ccc-8ccc-ccccccccccc7',
  'ABERTA',
  'A unidade ainda nao voltou',
  'NOME_NAO_VAZAR'
) ON CONFLICT (id) DO UPDATE
SET status = excluded.status, observacao = excluded.observacao, registrado_por = excluded.registrado_por;

SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true);

CREATE TEMP TABLE mcp_read_tokens (
  target text PRIMARY KEY,
  token text NOT NULL,
  arguments jsonb NOT NULL
);

INSERT INTO mcp_read_tokens (target, token, arguments)
VALUES
  ('mmd:eventos:list', 'mcp-events-token', jsonb_build_object('status', 'EM_CAMPO', 'date_from', null, 'date_to', null, 'page', 1, 'page_size', 50)),
  ('mmd:catalogo:list', 'mcp-catalog-token', jsonb_build_object('categoria', 'ILUMINACAO', 'page', 1, 'page_size', 50)),
  ('mmd:packing:read', 'mcp-packing-token', jsonb_build_object('evento_id', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd7', 'page', 1, 'page_size', 50)),
  ('mmd:movimentacoes:list', 'mcp-movements-token', jsonb_build_object('evento_id', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd7', 'page', 1, 'page_size', 50)),
  ('mmd:conferencias:read', 'mcp-conference-token', jsonb_build_object('evento_id', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd7', 'direcao', 'SAIDA', 'page', 1, 'page_size', 50)),
  ('mmd:retorno-esperado:read', 'mcp-expected-token', jsonb_build_object('evento_id', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd7', 'page', 1, 'page_size', 50)),
  ('mmd:pendencias:list', 'mcp-pendings-token', jsonb_build_object('evento_id', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd7', 'page', 1, 'page_size', 50));

SELECT public.issue_mcp_collection_capability(
  encode(extensions.digest(token, 'sha256'), 'hex'),
  'mcp-read-resources',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7',
  target,
  arguments,
  30
)
FROM mcp_read_tokens;

SELECT pass('Issuer aceita somente os sete targets MCP de leitura com cliente, ator e payload presos');

SET LOCAL ROLE postgres;
SET LOCAL ROLE mmd_mcp_executor;

DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.mcp_read_events('mcp-events-token', 'EM_CAMPO', NULL, NULL, 1, 50);
  IF v_result->'items'->0->>'nome' <> 'Evento MCP de Leitura' THEN
    RAISE EXCEPTION 'Eventos MCP não retornou o DTO esperado';
  END IF;
END;
$$;

DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.mcp_read_catalog('mcp-catalog-token', 'ILUMINACAO', 1, 50);
  IF v_result::text ~ '999.99|NAO_VAZAR_NOTA_DE_CATALOGO' THEN
    RAISE EXCEPTION 'Catálogo MCP vazou campo vetado';
  END IF;
END;
$$;

DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.mcp_read_packing('mcp-packing-token', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd7', 1, 50);
  IF v_result::text ~ 'NAO_VAZAR_NOTA_DO_PACKING|SERIAL-FABRICA-VETADO|QR-VETADO' THEN
    RAISE EXCEPTION 'Packing MCP vazou campo vetado';
  END IF;
END;
$$;

DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.mcp_read_movements('mcp-movements-token', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd7', 1, 50);
  IF v_result::text ~ 'NOME_NAO_VAZAR|NAO_VAZAR_NOTA_DA_MOVIMENTACAO' THEN
    RAISE EXCEPTION 'Movimentações MCP vazaram campo vetado';
  END IF;
END;
$$;

DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.mcp_read_conference('mcp-conference-token', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd7', 'SAIDA', 1, 50);
  IF v_result::text ~ 'NAO_VAZAR_SOURCE_EVENT|NAO_VAZAR_OBSERVACAO_DA_DECISAO' THEN
    RAISE EXCEPTION 'Conferência MCP vazou evidência livre';
  END IF;
END;
$$;

DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.mcp_read_expected_return('mcp-expected-token', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd7', 1, 50);
  IF v_result->'items' <> '[]'::jsonb THEN
    RAISE EXCEPTION 'Retorno esperado aceitou decisão não confirmada';
  END IF;
END;
$$;

DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.mcp_read_return_pendings('mcp-pendings-token', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd7', 1, 50);
  IF v_result->'items'->0->>'status' <> 'ABERTA' THEN
    RAISE EXCEPTION 'Pendência MCP não devolveu status canônico';
  END IF;
END;
$$;

DO $$
BEGIN
  BEGIN
    PERFORM public.mcp_read_events('mcp-events-token', 'EM_CAMPO', NULL, NULL, 1, 50);
    RAISE EXCEPTION 'Capability de coleção foi reutilizada';
  EXCEPTION WHEN SQLSTATE '28000' THEN
    IF SQLERRM <> 'MCP_COLLECTION_CAPABILITY_INVALID' THEN
      RAISE;
    END IF;
  END;
END;
$$;

DO $$
BEGIN
  BEGIN
    PERFORM public.mcp_read_catalog('mcp-catalog-token', 'ILUMINACAO', 1, 51);
    RAISE EXCEPTION 'Paginação acima do limite foi aceita';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    IF SQLERRM <> 'MCP_PAGE_INVALID' THEN
      RAISE;
    END IF;
  END;
END;
$$;

SET LOCAL ROLE postgres;
SELECT pass('Eventos aplica filtro enum e devolve DTO allowlisted');
SELECT pass('Catálogo não vaza valor ou notas');
SELECT pass('Packing devolve cobertura allowlisted sem dados vetados da Unidade');
SELECT pass('Movimentações não vazam registrador ou notas livres');
SELECT pass('Conferência devolve decisão e recibo allowlisted sem evidência livre');
SELECT pass('Retorno esperado deriva somente saídas físicas confirmadas, não alocação');
SELECT pass('Pendências de retorno devolvem estado canônico da Unidade');
SELECT pass('Capability de coleção é de uso único');
SELECT pass('Paginação acima de 50 falha fechada');

SELECT * FROM finish();
ROLLBACK;
