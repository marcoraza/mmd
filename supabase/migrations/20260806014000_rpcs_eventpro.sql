-- ============================================================================
-- EventPro delta 5/5: RPCs de negócio na versão EventPro
-- ----------------------------------------------------------------------------
-- Porta para o banco legado as 6 funções de `supabase/reference/0002_rpcs.sql`:
-- as 4 RPCs de negócio que já existiam (agora lendo `packing_allocations` e
-- gravando autoria com FK) e as 2 que o legado nunca teve
-- (`auto_allocate_packing`, `conferencia_rfid_evento`), mais o helper
-- `app_private.resolve_autoria`.
--
-- ----------------------------------------------------------------------------
-- Compatibilidade com o web app legado (mmd), que segue em produção
-- ----------------------------------------------------------------------------
-- 1. ASSINATURA. O parâmetro novo `p_registrado_por_id uuid DEFAULT NULL` entra
--    no FIM da lista. Chamada posicional antiga continua válida, e a chamada
--    por nome que o legado usa (`supabase.rpc('checkin_projeto', {p_projeto_id,
--    p_metodo, p_registrado_por, p_items})`) resolve para a função nova com o
--    autor nulo.
--
-- 2. DROP DAS ASSINATURAS ANTIGAS É OBRIGATÓRIO, não cosmético. `CREATE OR
--    REPLACE` com aridade diferente cria uma SOBRECARGA, não substitui. Com as
--    duas versões vivas, a chamada por nome do legado casa com as duas (a nova
--    via DEFAULT) e o Postgres devolve "function ... is not unique" — ou seja,
--    manter a função antiga quebraria o legado, e removê-la é o que o mantém
--    funcionando. Os DROPs e os CREATEs estão no mesmo arquivo, então rodam na
--    mesma transação: não existe janela sem função.
--
-- 3. DUAL-WRITE. Toda RPC que muta `packing_allocations` reescreve
--    `packing_list.serial_numbers_designados` a partir da tabela, via
--    `app_private.sync_array_from_allocations`. Assim a UI antiga (que lê o
--    array) continua enxergando a alocação real.
--
--    O caminho inverso (array -> tabela) é o trigger instalado em
--    20260806010000. Para os dois não se atropelarem, o helper liga o GUC
--    transacional `eventpro.skip_allocation_sync` durante o seu UPDATE: dentro
--    dessa janela a tabela é a autoridade e o trigger não reconcilia. Como o
--    helper declara `SET search_path`, o Postgres reverte o GUC no retorno da
--    função (AtEOXact_GUC no nest level da função), então o flag não vaza para
--    o resto da transação.
--
--    Não há loop possível: o trigger só escreve em `packing_allocations` e não
--    existe trigger em `packing_allocations`. O guard `pg_trigger_depth() > 1`
--    do trigger é o fail-safe caso isso mude.
--
-- 4. MUDANÇA DE COMPORTAMENTO ASSUMIDA: no legado o check-in não mexia na
--    alocação, e o array continuava cheio depois do Evento fechar. Agora a
--    alocação da unidade que voltou é liberada no check-in (e a da que não
--    voltou, na resolução da pendência), então o array esvazia junto. É o
--    comportamento correto do design alvo (reference §4.1): a unidade fica
--    livre para o próximo Evento assim que o ciclo dela fecha.
--
-- 5. LOTES. O banco legado ainda tem a tabela `lotes` e `rfid_scans.lote_id`.
--    `conferencia_rfid_evento` trata tag de lote como DESCONHECIDA e anota
--    "Lote legado: {codigo}" no scan, espelhando `resolveUnitOnlyRfidLegacy`
--    em `apps/web/src/lib/legacy-lotes-core.ts`. Nada de `lote_id` é gravado:
--    a política unit-only não reconhece lote como alvo operacional. Quando
--    `lotes` for removida, esta função volta a ser exatamente a do reference.
-- ============================================================================


-- ============================================================================
-- 1. app_private.resolve_autoria
-- ============================================================================
-- Ordem de derivação do autor:
--   a) há sessão (auth.uid() não nulo): o autor é o dono da sessão e
--      `p_registrado_por_id` é IGNORADO. Ninguém logado carimba outra pessoa.
--   b) sem sessão (caminho service role, que é como o BFF chama): o autor é
--      `p_registrado_por_id`, quando informado.
--   c) nenhum dos dois: autor nulo. É o caso de toda chamada do web legado
--      hoje, e é aceitável: a coluna é nullable de propósito.
-- Nos casos (a) e (b) o id é validado contra `profiles`: FK quebrada aborta a
-- transação em vez de gravar auditoria órfã.

CREATE OR REPLACE FUNCTION app_private.resolve_autoria(
  p_registrado_por text,
  p_registrado_por_id uuid DEFAULT NULL,
  OUT label text,
  OUT autor_id uuid
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
  v_found uuid;
BEGIN
  label := nullif(btrim(coalesce(p_registrado_por, '')), '');

  IF label IS NULL THEN
    RAISE EXCEPTION 'registrado_por é obrigatório: toda operação precisa de autor identificável';
  END IF;

  v_uid := auth.uid();

  IF v_uid IS NOT NULL THEN
    SELECT p.id INTO v_found FROM public.profiles p WHERE p.id = v_uid;
    IF v_found IS NULL THEN
      RAISE EXCEPTION 'Sessão sem profile correspondente (auth.uid = %)', v_uid;
    END IF;
    autor_id := v_found;
    RETURN;
  END IF;

  IF p_registrado_por_id IS NULL THEN
    autor_id := NULL;
    RETURN;
  END IF;

  SELECT p.id INTO v_found FROM public.profiles p WHERE p.id = p_registrado_por_id;
  IF v_found IS NULL THEN
    RAISE EXCEPTION 'registrado_por_id % não corresponde a nenhum profile', p_registrado_por_id;
  END IF;

  autor_id := v_found;
END;
$$;

COMMENT ON FUNCTION app_private.resolve_autoria(text, uuid) IS
  'Deriva o autor de uma operação: auth.uid() quando há sessão, senão o id passado pelo service role. Valida contra profiles e exige o label text.';

REVOKE ALL ON FUNCTION app_private.resolve_autoria(text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.resolve_autoria(text, uuid) FROM anon;
REVOKE ALL ON FUNCTION app_private.resolve_autoria(text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION app_private.resolve_autoria(text, uuid) TO service_role;


-- ============================================================================
-- 2. app_private.sync_array_from_allocations (dual-write, transitório)
-- ============================================================================
-- Projeta `packing_allocations` de volta em `packing_list.serial_numbers_
-- designados` para as linhas informadas. Sai junto com a coluna uuid[].
--
-- Sem grant nenhum: é helper interno, chamado só de dentro das RPCs
-- SECURITY DEFINER, que executam como dono da função e por isso não precisam
-- de EXECUTE explícito.

CREATE OR REPLACE FUNCTION app_private.sync_array_from_allocations(p_packing_ids uuid[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_packing_ids IS NULL OR coalesce(array_length(p_packing_ids, 1), 0) = 0 THEN
    RETURN;
  END IF;

  -- Desliga o trigger de sincronização para esta transação: aqui quem manda é
  -- packing_allocations. O flag volta sozinho ao sair da função.
  PERFORM set_config('eventpro.skip_allocation_sync', 'on', true);

  UPDATE public.packing_list pl
  SET serial_numbers_designados = coalesce(
    (
      SELECT array_agg(pa.serial_id ORDER BY pa.created_at, pa.serial_id)
      FROM public.packing_allocations pa
      WHERE pa.packing_id = pl.id
    ),
    ARRAY[]::uuid[]
  )
  WHERE pl.id = ANY(p_packing_ids);

  PERFORM set_config('eventpro.skip_allocation_sync', 'off', true);
END;
$$;

COMMENT ON FUNCTION app_private.sync_array_from_allocations(uuid[]) IS
  'Transitório: projeta packing_allocations em packing_list.serial_numbers_designados para o web legado continuar enxergando a alocação. Sai junto com a coluna uuid[].';

REVOKE ALL ON FUNCTION app_private.sync_array_from_allocations(uuid[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.sync_array_from_allocations(uuid[]) FROM anon;
REVOKE ALL ON FUNCTION app_private.sync_array_from_allocations(uuid[]) FROM authenticated;


-- ============================================================================
-- 3. Remoção das assinaturas legadas
-- ============================================================================
-- Ver nota 2 do cabeçalho: sem isto a chamada por nome do web legado fica
-- ambígua e passa a falhar.

DROP FUNCTION IF EXISTS public.checkout_projeto(uuid, public.metodo_scan_enum, text);
DROP FUNCTION IF EXISTS public.checkout_projeto_com_override(uuid, public.metodo_scan_enum, text, uuid);
DROP FUNCTION IF EXISTS public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb);
DROP FUNCTION IF EXISTS public.resolver_retorno_pendencia(uuid, text, text, text);


-- ============================================================================
-- 4. checkout_projeto
-- ============================================================================
-- Ordem obrigatória, herdada do legado e verificada por teste de contrato:
--   1. trava o Evento (FOR UPDATE) e valida status;
--   2. valida readiness por linha de packing;
--   3. trava os seriais (FOR UPDATE) e valida que estão DISPONIVEL;
--   4. grava `movimentacoes` (auditoria antes de mutação);
--   5. muta `serial_numbers`;
--   6. muta o status do Evento.
--
-- Evento 100% terceirizado (cobertura toda por aluguel avulso) é caso válido.
-- CONFIRMADO e MONTAGEM são os dois status que aceitam saída (auditoria §5.1).
-- Não muta alocação, então não faz dual-write.

CREATE OR REPLACE FUNCTION public.checkout_projeto(
  p_projeto_id uuid,
  p_metodo public.metodo_scan_enum,
  p_registrado_por text,
  p_registrado_por_id uuid DEFAULT NULL
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
  v_packing_missing int;
  v_registrado_por text;
  v_autor_id uuid;
BEGIN
  SELECT a.label, a.autor_id INTO v_registrado_por, v_autor_id
  FROM app_private.resolve_autoria(p_registrado_por, p_registrado_por_id) a;

  SELECT status INTO v_projeto_status
  FROM public.projetos
  WHERE id = p_projeto_id
  FOR UPDATE;

  IF v_projeto_status IS NULL THEN
    RAISE EXCEPTION 'Evento % não encontrado', p_projeto_id;
  END IF;

  IF v_projeto_status::text NOT IN ('CONFIRMADO', 'MONTAGEM') THEN
    RAISE EXCEPTION 'Check-out requer Evento CONFIRMADO ou MONTAGEM (atual: %)', v_projeto_status;
  END IF;

  -- Readiness por linha: unidades próprias alocadas mais aluguel avulso
  -- precisam cobrir a quantidade exigida. Mesma conta de
  -- `computePackingCoverage`, com a parcela própria vindo de
  -- packing_allocations em vez de array_length do uuid[].
  SELECT count(*) INTO v_packing_missing
  FROM public.packing_list pl
  WHERE pl.projeto_id = p_projeto_id
    AND (
      (
        SELECT count(*)
        FROM public.packing_allocations pa
        WHERE pa.packing_id = pl.id
      )
      + coalesce(
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

  SELECT coalesce(array_agg(DISTINCT pa.serial_id), ARRAY[]::uuid[]) INTO v_serial_ids
  FROM public.packing_allocations pa
  JOIN public.packing_list pl ON pl.id = pa.packing_id
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
      status_anterior, status_novo, registrado_por, registrado_por_id, metodo_scan
    )
    SELECT id, p_projeto_id, 'SAIDA', 'DISPONIVEL', 'EM_CAMPO',
           v_registrado_por, v_autor_id, p_metodo
    FROM public.serial_numbers
    WHERE id = ANY(v_serial_ids);

    UPDATE public.serial_numbers
    SET status = 'EM_CAMPO'
    WHERE id = ANY(v_serial_ids);
  END IF;

  UPDATE public.projetos
  SET status = 'EM_CAMPO'
  WHERE id = p_projeto_id;

  RETURN QUERY
  SELECT sn.id, sn.codigo_interno
  FROM public.serial_numbers sn
  WHERE sn.id = ANY(v_serial_ids)
  ORDER BY sn.codigo_interno;
END;
$$;

COMMENT ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text, uuid) IS
  'Saída do Evento com readiness 100%. Lê alocação de packing_allocations, trava Evento e unidades, audita antes de mutar.';


-- ============================================================================
-- 5. checkout_projeto_com_override
-- ============================================================================
-- Mesma mecânica sem a checagem de readiness, e só depois de um registro
-- prévio em `checkout_overrides`. O que a override NÃO libera: unidade fora de
-- DISPONIVEL. Isso é realidade física, não exceção de processo.

CREATE OR REPLACE FUNCTION public.checkout_projeto_com_override(
  p_projeto_id uuid,
  p_metodo public.metodo_scan_enum,
  p_registrado_por text,
  p_override_id uuid,
  p_registrado_por_id uuid DEFAULT NULL
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
  v_registrado_por text;
  v_autor_id uuid;
BEGIN
  SELECT a.label, a.autor_id INTO v_registrado_por, v_autor_id
  FROM app_private.resolve_autoria(p_registrado_por, p_registrado_por_id) a;

  SELECT status INTO v_projeto_status
  FROM public.projetos
  WHERE id = p_projeto_id
  FOR UPDATE;

  IF v_projeto_status IS NULL THEN
    RAISE EXCEPTION 'Evento % não encontrado', p_projeto_id;
  END IF;

  IF v_projeto_status::text NOT IN ('CONFIRMADO', 'MONTAGEM') THEN
    RAISE EXCEPTION 'Check-out requer Evento CONFIRMADO ou MONTAGEM (atual: %)', v_projeto_status;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.checkout_overrides co
    WHERE co.id = p_override_id
      AND co.projeto_id = p_projeto_id
  ) THEN
    RAISE EXCEPTION 'Override % não encontrado para o Evento %', p_override_id, p_projeto_id;
  END IF;

  SELECT coalesce(array_agg(DISTINCT pa.serial_id), ARRAY[]::uuid[]) INTO v_serial_ids
  FROM public.packing_allocations pa
  JOIN public.packing_list pl ON pl.id = pa.packing_id
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
      status_anterior, status_novo, registrado_por, registrado_por_id, metodo_scan, notas
    )
    SELECT
      id,
      p_projeto_id,
      'SAIDA',
      'DISPONIVEL',
      'EM_CAMPO',
      v_registrado_por,
      v_autor_id,
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

COMMENT ON FUNCTION public.checkout_projeto_com_override(uuid, public.metodo_scan_enum, text, uuid, uuid) IS
  'Saída forçada com override auditado. Pula readiness, nunca pula a checagem de unidade DISPONIVEL, e carimba executado_em.';


-- ============================================================================
-- 6. checkin_projeto
-- ============================================================================
-- Conferência de retorno. OK -> DISPONIVEL; PROBLEMA -> MANUTENCAO (exige
-- observação); NAO_VOLTOU -> RETORNANDO e abre pendência.
--
-- Cobertura total obrigatória: a lista precisa bater exatamente com as
-- unidades EM_CAMPO deste Evento, sem duplicata, sobra ou falta.
--
-- Liberação de alocação (reference §4.1): OK e PROBLEMA liberam a linha de
-- packing_allocations na hora; NAO_VOLTOU mantém a alocação até a pendência
-- ser resolvida, porque a linha viva é a trava que impede prometer para outro
-- cliente um equipamento que ninguém sabe onde está.

CREATE OR REPLACE FUNCTION public.checkin_projeto(
  p_projeto_id uuid,
  p_metodo public.metodo_scan_enum,
  p_registrado_por text,
  p_items jsonb,
  p_registrado_por_id uuid DEFAULT NULL
)
RETURNS TABLE(serial_id uuid, codigo_interno text, novo_status public.status_serial_enum)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_projeto_status public.status_projeto_enum;
  v_expected_ids uuid[];
  v_serial_ids uuid[];
  v_bad_status_count int;
  v_duplicate_count int;
  v_unexpected_count int;
  v_missing_count int;
  v_problem_without_obs_count int;
  v_registrado_por text;
  v_autor_id uuid;
  v_packings_afetados uuid[];
BEGIN
  SELECT a.label, a.autor_id INTO v_registrado_por, v_autor_id
  FROM app_private.resolve_autoria(p_registrado_por, p_registrado_por_id) a;

  SELECT status INTO v_projeto_status
  FROM public.projetos
  WHERE id = p_projeto_id
  FOR UPDATE;

  IF v_projeto_status IS NULL THEN
    RAISE EXCEPTION 'Evento % não encontrado', p_projeto_id;
  END IF;

  IF v_projeto_status <> 'EM_CAMPO' THEN
    RAISE EXCEPTION 'Retorno requer Evento EM_CAMPO (atual: %)', v_projeto_status;
  END IF;

  IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Lista de unidades vazia';
  END IF;

  -- Universo esperado: unidade alocada a este Evento que está EM_CAMPO. A
  -- unidade em RETORNANDO (pendência aberta de um retorno anterior) mantém a
  -- alocação, mas não entra no esperado.
  SELECT coalesce(array_agg(DISTINCT pa.serial_id), ARRAY[]::uuid[]) INTO v_expected_ids
  FROM public.packing_allocations pa
  JOIN public.packing_list pl ON pl.id = pa.packing_id
  JOIN public.serial_numbers sn ON sn.id = pa.serial_id
  WHERE pl.projeto_id = p_projeto_id
    AND sn.status = 'EM_CAMPO';

  IF coalesce(array_length(v_expected_ids, 1), 0) = 0 THEN
    RAISE EXCEPTION 'Nenhuma unidade própria em campo para retorno';
  END IF;

  PERFORM 1
  FROM public.serial_numbers
  WHERE id = ANY(v_expected_ids)
  FOR UPDATE;

  SELECT array_agg((elem->>'serial_id')::uuid) INTO v_serial_ids
  FROM jsonb_array_elements(p_items) AS elem;

  SELECT count(*) - count(DISTINCT listed.serial_id) INTO v_duplicate_count
  FROM unnest(v_serial_ids) AS listed(serial_id);

  IF v_duplicate_count > 0 THEN
    RAISE EXCEPTION 'Lista de retorno contém unidade duplicada';
  END IF;

  SELECT count(*) INTO v_unexpected_count
  FROM unnest(v_serial_ids) AS listed(serial_id)
  WHERE NOT (listed.serial_id = ANY(v_expected_ids));

  SELECT count(*) INTO v_missing_count
  FROM unnest(v_expected_ids) AS listed(serial_id)
  WHERE NOT (listed.serial_id = ANY(v_serial_ids));

  IF v_unexpected_count > 0 OR v_missing_count > 0 THEN
    RAISE EXCEPTION 'Lista de retorno não bate com as unidades que saíram neste Evento';
  END IF;

  SELECT count(*) INTO v_bad_status_count
  FROM public.serial_numbers
  WHERE id = ANY(v_expected_ids)
    AND status <> 'EM_CAMPO';

  IF v_bad_status_count > 0 THEN
    RAISE EXCEPTION '% unidade(s) não estão EM_CAMPO. Retorno abortado.', v_bad_status_count;
  END IF;

  SELECT count(*) INTO v_problem_without_obs_count
  FROM (
    SELECT
      upper(coalesce(nullif(elem->>'resultado', ''), CASE
        WHEN coalesce((elem->>'needs_maintenance')::boolean, false) THEN 'PROBLEMA'
        ELSE 'OK'
      END)) AS resultado,
      nullif(btrim(coalesce(elem->>'observacao', '')), '') AS observacao
    FROM jsonb_array_elements(p_items) AS elem
  ) AS input
  WHERE input.resultado = 'PROBLEMA'
    AND length(coalesce(input.observacao, '')) < 3;

  IF v_problem_without_obs_count > 0 THEN
    RAISE EXCEPTION 'Unidade com problema precisa de observação do Evento';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) AS elem
    WHERE upper(coalesce(nullif(elem->>'resultado', ''), CASE
      WHEN coalesce((elem->>'needs_maintenance')::boolean, false) THEN 'PROBLEMA'
      ELSE 'OK'
    END)) NOT IN ('OK', 'PROBLEMA', 'NAO_VOLTOU')
  ) THEN
    RAISE EXCEPTION 'Resultado de retorno inválido';
  END IF;

  INSERT INTO public.movimentacoes (
    serial_number_id, projeto_id, tipo,
    status_anterior, status_novo, registrado_por, registrado_por_id, metodo_scan, notas
  )
  SELECT
    parsed.serial_id,
    p_projeto_id,
    CASE
      WHEN parsed.resultado = 'PROBLEMA' THEN 'MANUTENCAO'::public.tipo_movimentacao_enum
      ELSE 'RETORNO'::public.tipo_movimentacao_enum
    END,
    'EM_CAMPO',
    CASE
      WHEN parsed.resultado = 'PROBLEMA' THEN 'MANUTENCAO'
      WHEN parsed.resultado = 'NAO_VOLTOU' THEN 'RETORNANDO'
      ELSE 'DISPONIVEL'
    END,
    v_registrado_por,
    v_autor_id,
    p_metodo,
    CASE
      WHEN parsed.resultado = 'PROBLEMA'
        THEN 'Problema no retorno: ' || parsed.observacao
      WHEN parsed.resultado = 'NAO_VOLTOU'
        THEN btrim('Não voltou no retorno do Evento. ' || coalesce(parsed.observacao, ''))
      ELSE parsed.observacao
    END
  FROM (
    SELECT
      (elem->>'serial_id')::uuid AS serial_id,
      greatest(1, least(5, coalesce(nullif(elem->>'desgaste', '')::int, 3))) AS desgaste,
      upper(coalesce(nullif(elem->>'resultado', ''), CASE
        WHEN coalesce((elem->>'needs_maintenance')::boolean, false) THEN 'PROBLEMA'
        ELSE 'OK'
      END)) AS resultado,
      nullif(btrim(coalesce(elem->>'observacao', '')), '') AS observacao
    FROM jsonb_array_elements(p_items) AS elem
  ) AS parsed;

  UPDATE public.serial_numbers sn
  SET status = CASE
        WHEN parsed.resultado = 'PROBLEMA' THEN 'MANUTENCAO'::public.status_serial_enum
        WHEN parsed.resultado = 'NAO_VOLTOU' THEN 'RETORNANDO'::public.status_serial_enum
        ELSE 'DISPONIVEL'::public.status_serial_enum
      END,
      desgaste = CASE
        WHEN parsed.resultado = 'NAO_VOLTOU' THEN sn.desgaste
        ELSE parsed.desgaste
      END
  FROM (
    SELECT
      (elem->>'serial_id')::uuid AS serial_id,
      greatest(1, least(5, coalesce(nullif(elem->>'desgaste', '')::int, 3))) AS desgaste,
      upper(coalesce(nullif(elem->>'resultado', ''), CASE
        WHEN coalesce((elem->>'needs_maintenance')::boolean, false) THEN 'PROBLEMA'
        ELSE 'OK'
      END)) AS resultado
    FROM jsonb_array_elements(p_items) AS elem
  ) AS parsed
  WHERE sn.id = parsed.serial_id;

  INSERT INTO public.retorno_pendencias (
    projeto_id,
    serial_number_id,
    status,
    observacao,
    registrado_por,
    registrado_por_id
  )
  SELECT
    p_projeto_id,
    parsed.serial_id,
    'ABERTA',
    parsed.observacao,
    v_registrado_por,
    v_autor_id
  FROM (
    SELECT
      (elem->>'serial_id')::uuid AS serial_id,
      upper(coalesce(nullif(elem->>'resultado', ''), CASE
        WHEN coalesce((elem->>'needs_maintenance')::boolean, false) THEN 'PROBLEMA'
        ELSE 'OK'
      END)) AS resultado,
      nullif(btrim(coalesce(elem->>'observacao', '')), '') AS observacao
    FROM jsonb_array_elements(p_items) AS elem
  ) AS parsed
  WHERE parsed.resultado = 'NAO_VOLTOU'
  ON CONFLICT (projeto_id, serial_number_id)
  DO UPDATE SET
    status = 'ABERTA',
    observacao = EXCLUDED.observacao,
    resolucao_observacao = NULL,
    registrado_por = EXCLUDED.registrado_por,
    registrado_por_id = EXCLUDED.registrado_por_id,
    resolvido_por = NULL,
    resolvido_por_id = NULL,
    resolved_at = NULL;

  -- Linhas de packing tocadas: capturadas ANTES do DELETE, porque depois dele
  -- o vínculo alocação -> linha não existe mais.
  SELECT coalesce(array_agg(DISTINCT pa.packing_id), ARRAY[]::uuid[])
  INTO v_packings_afetados
  FROM public.packing_allocations pa
  JOIN public.packing_list pl ON pl.id = pa.packing_id
  WHERE pl.projeto_id = p_projeto_id;

  DELETE FROM public.packing_allocations pa
  USING (
    SELECT
      (elem->>'serial_id')::uuid AS serial_id,
      upper(coalesce(nullif(elem->>'resultado', ''), CASE
        WHEN coalesce((elem->>'needs_maintenance')::boolean, false) THEN 'PROBLEMA'
        ELSE 'OK'
      END)) AS resultado
    FROM jsonb_array_elements(p_items) AS elem
  ) AS parsed
  WHERE pa.serial_id = parsed.serial_id
    AND parsed.resultado <> 'NAO_VOLTOU';

  -- Dual-write para o web legado (ver nota 3 do cabeçalho).
  PERFORM app_private.sync_array_from_allocations(v_packings_afetados);

  IF EXISTS (
    SELECT 1
    FROM public.retorno_pendencias rp
    WHERE rp.projeto_id = p_projeto_id
      AND rp.status = 'ABERTA'
  ) THEN
    UPDATE public.projetos
    SET status = 'EM_CAMPO'
    WHERE id = p_projeto_id;
  ELSE
    UPDATE public.projetos
    SET status = 'FINALIZADO'
    WHERE id = p_projeto_id;
  END IF;

  RETURN QUERY
  SELECT sn.id, sn.codigo_interno, sn.status
  FROM public.serial_numbers sn
  WHERE sn.id = ANY(v_serial_ids)
  ORDER BY sn.codigo_interno;
END;
$$;

COMMENT ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb, uuid) IS
  'Conferência de retorno com cobertura total obrigatória. Libera a alocação da unidade que voltou, mantém a da que não voltou e reprojeta o array legado.';


-- ============================================================================
-- 7. resolver_retorno_pendencia
-- ============================================================================
--   ENCONTRADA -> DISPONIVEL
--   MANUTENCAO -> MANUTENCAO (exige observação)
--   BAIXA      -> BAIXA
--   COBRANCA   -> não altera o status da unidade (exige observação)
-- Em todos os casos grava movimentação, libera a alocação e, ao zerar as
-- pendências abertas, finaliza o Evento.

CREATE OR REPLACE FUNCTION public.resolver_retorno_pendencia(
  p_pendencia_id uuid,
  p_acao text,
  p_observacao text,
  p_registrado_por text,
  p_registrado_por_id uuid DEFAULT NULL
)
RETURNS TABLE(
  pendencia_id uuid,
  serial_id uuid,
  codigo_interno text,
  status_pendencia text,
  novo_status public.status_serial_enum
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pendencia record;
  v_acao text := upper(btrim(coalesce(p_acao, '')));
  v_obs text := nullif(btrim(coalesce(p_observacao, '')), '');
  v_status_anterior public.status_serial_enum;
  v_status_novo public.status_serial_enum;
  v_tipo public.tipo_movimentacao_enum;
  v_notas text;
  v_registrado_por text;
  v_autor_id uuid;
  v_packings_afetados uuid[];
BEGIN
  SELECT a.label, a.autor_id INTO v_registrado_por, v_autor_id
  FROM app_private.resolve_autoria(p_registrado_por, p_registrado_por_id) a;

  IF v_acao NOT IN ('ENCONTRADA', 'MANUTENCAO', 'BAIXA', 'COBRANCA') THEN
    RAISE EXCEPTION 'Ação de resolução inválida';
  END IF;

  IF v_acao IN ('MANUTENCAO', 'COBRANCA') AND length(coalesce(v_obs, '')) < 3 THEN
    RAISE EXCEPTION 'Resolução por % precisa de observação', v_acao;
  END IF;

  SELECT
    rp.id,
    rp.projeto_id,
    rp.serial_number_id,
    rp.status,
    sn.codigo_interno,
    sn.status AS serial_status
  INTO v_pendencia
  FROM public.retorno_pendencias rp
  JOIN public.serial_numbers sn ON sn.id = rp.serial_number_id
  WHERE rp.id = p_pendencia_id
  FOR UPDATE OF rp;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pendência de retorno % não encontrada', p_pendencia_id;
  END IF;

  IF v_pendencia.status <> 'ABERTA' THEN
    RAISE EXCEPTION 'Pendência de retorno já resolvida como %', v_pendencia.status;
  END IF;

  SELECT status INTO v_status_anterior
  FROM public.serial_numbers
  WHERE id = v_pendencia.serial_number_id
  FOR UPDATE;

  IF v_acao = 'ENCONTRADA' THEN
    v_status_novo := 'DISPONIVEL';
    v_tipo := 'RETORNO';
    v_notas := coalesce(v_obs, 'Pendência resolvida: unidade encontrada.');
  ELSIF v_acao = 'MANUTENCAO' THEN
    v_status_novo := 'MANUTENCAO';
    v_tipo := 'MANUTENCAO';
    v_notas := 'Pendência resolvida para manutenção: ' || v_obs;
  ELSIF v_acao = 'BAIXA' THEN
    v_status_novo := 'BAIXA';
    v_tipo := 'DANO';
    v_notas := coalesce(v_obs, 'Pendência resolvida com baixa da unidade.');
  ELSE
    v_status_novo := v_status_anterior;
    v_tipo := 'DANO';
    v_notas := 'Pendência resolvida com nota de cobrança: ' || v_obs;
  END IF;

  IF v_acao <> 'COBRANCA' THEN
    UPDATE public.serial_numbers
    SET status = v_status_novo
    WHERE id = v_pendencia.serial_number_id;
  END IF;

  INSERT INTO public.movimentacoes (
    serial_number_id,
    projeto_id,
    tipo,
    status_anterior,
    status_novo,
    registrado_por,
    registrado_por_id,
    metodo_scan,
    notas
  )
  VALUES (
    v_pendencia.serial_number_id,
    v_pendencia.projeto_id,
    v_tipo,
    v_status_anterior::text,
    v_status_novo::text,
    v_registrado_por,
    v_autor_id,
    'MANUAL',
    v_notas
  );

  UPDATE public.retorno_pendencias
  SET status = v_acao,
      resolucao_observacao = v_obs,
      resolvido_por = v_registrado_por,
      resolvido_por_id = v_autor_id,
      resolved_at = now()
  WHERE id = v_pendencia.id;

  -- Contraparte do DELETE parcial do check-in: o ciclo desta unidade fechou
  -- agora, então a alocação sai. Vale inclusive para COBRANCA, em que quem
  -- impede realocação passa a ser o status, não uma alocação pendurada num
  -- Evento já encerrado.
  SELECT coalesce(array_agg(pa.packing_id), ARRAY[]::uuid[])
  INTO v_packings_afetados
  FROM public.packing_allocations pa
  WHERE pa.serial_id = v_pendencia.serial_number_id;

  DELETE FROM public.packing_allocations pa
  WHERE pa.serial_id = v_pendencia.serial_number_id;

  PERFORM app_private.sync_array_from_allocations(v_packings_afetados);

  IF NOT EXISTS (
    SELECT 1
    FROM public.retorno_pendencias rp
    WHERE rp.projeto_id = v_pendencia.projeto_id
      AND rp.status = 'ABERTA'
  ) THEN
    UPDATE public.projetos
    SET status = 'FINALIZADO'
    WHERE id = v_pendencia.projeto_id
      AND status = 'EM_CAMPO';
  END IF;

  RETURN QUERY
  SELECT
    v_pendencia.id,
    v_pendencia.serial_number_id,
    v_pendencia.codigo_interno,
    v_acao,
    v_status_novo;
END;
$$;

COMMENT ON FUNCTION public.resolver_retorno_pendencia(uuid, text, text, text, uuid) IS
  'Resolve pendência de retorno (ENCONTRADA, MANUTENCAO, BAIXA, COBRANCA), libera a alocação da unidade e finaliza o Evento quando não sobra pendência aberta.';


-- ============================================================================
-- 8. auto_allocate_packing (NOVA)
-- ============================================================================
-- Substitui o `autoAllocate` da aplicação, que tem race documentada como TODO
-- em `apps/web/src/lib/actions/projetos.ts`: dois auto-allocates simultâneos em
-- packings do mesmo item liam o mesmo serial DISPONIVEL e ambos gravavam o
-- mesmo uuid, em Eventos diferentes.
--
-- Como a race morre aqui:
--   1. a linha de packing é travada com FOR UPDATE, serializando duas chamadas
--      concorrentes para a MESMA linha;
--   2. os candidatos são travados com FOR UPDATE SKIP LOCKED, então uma
--      chamada concorrente para OUTRA linha pula a unidade já reservada por
--      uma transação em curso em vez de disputá-la;
--   3. `packing_allocations` tem UNIQUE (serial_id) e o INSERT usa ON CONFLICT
--      DO NOTHING como terceira barreira.
--
-- Consequência assumida do SKIP LOCKED: sob concorrência a chamada pode alocar
-- menos que o necessário em vez de esperar. É o comportamento correto para
-- auto-alocação (é sugestão, não promessa), e a linha continua visivelmente
-- incompleta na UI e no gate de saída.
--
-- Ordem de escolha (mesma de `sortAllocationCandidates` em allocation-core.ts):
-- unidade nunca movimentada primeiro, depois a movimentada há mais tempo,
-- depois menor desgaste, depois código interno.
--
-- Idempotente: linha já coberta retorna vazio. Nunca remove alocação.

CREATE OR REPLACE FUNCTION public.auto_allocate_packing(
  p_packing_id uuid,
  p_registrado_por text,
  p_registrado_por_id uuid DEFAULT NULL
)
RETURNS TABLE(serial_id uuid, codigo_interno text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item_id uuid;
  v_quantidade int;
  v_alocados int;
  v_missing int;
  v_registrado_por text;
  v_autor_id uuid;
BEGIN
  SELECT a.label, a.autor_id INTO v_registrado_por, v_autor_id
  FROM app_private.resolve_autoria(p_registrado_por, p_registrado_por_id) a;

  SELECT pl.item_id, pl.quantidade
  INTO v_item_id, v_quantidade
  FROM public.packing_list pl
  WHERE pl.id = p_packing_id
  FOR UPDATE;

  IF v_item_id IS NULL THEN
    RAISE EXCEPTION 'Linha de packing % não encontrada', p_packing_id;
  END IF;

  SELECT count(*) INTO v_alocados
  FROM public.packing_allocations pa
  WHERE pa.packing_id = p_packing_id;

  v_missing := v_quantidade - v_alocados;

  IF v_missing <= 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH candidatos AS (
    SELECT sn.id
    FROM public.serial_numbers sn
    WHERE sn.item_id = v_item_id
      AND sn.status = 'DISPONIVEL'
      AND NOT EXISTS (
        SELECT 1 FROM public.packing_allocations pa WHERE pa.serial_id = sn.id
      )
    ORDER BY
      (
        SELECT max(m.timestamp)
        FROM public.movimentacoes m
        WHERE m.serial_number_id = sn.id
      ) ASC NULLS FIRST,
      sn.desgaste ASC,
      sn.codigo_interno ASC
    LIMIT v_missing
    FOR UPDATE OF sn SKIP LOCKED
  ),
  inseridos AS (
    INSERT INTO public.packing_allocations (packing_id, serial_id)
    SELECT p_packing_id, c.id
    FROM candidatos c
    -- Conflito nomeado pela constraint, não pela coluna: `serial_id` também é
    -- nome de coluna de saída da função, e o inferido por coluna ficaria
    -- ambíguo entre variável de PL/pgSQL e coluna da tabela.
    ON CONFLICT ON CONSTRAINT packing_allocations_serial_unique DO NOTHING
    RETURNING packing_allocations.serial_id
  )
  SELECT i.serial_id, sn.codigo_interno
  FROM inseridos i
  JOIN public.serial_numbers sn ON sn.id = i.serial_id
  ORDER BY sn.codigo_interno;

  -- RETURN QUERY não encerra a função: o dual-write acontece depois de a
  -- alocação já estar gravada.
  PERFORM app_private.sync_array_from_allocations(ARRAY[p_packing_id]);

  RETURN;
END;
$$;

COMMENT ON FUNCTION public.auto_allocate_packing(uuid, text, uuid) IS
  'Auto-alocação atômica de unidades DISPONIVEL para uma linha de packing, com FOR UPDATE SKIP LOCKED. Idempotente, nunca remove alocação e reprojeta o array legado.';


-- ============================================================================
-- 9. conferencia_rfid_evento (NOVA)
-- ============================================================================
-- Fecha o loop RFID versus operação (gap §4.1 da auditoria). No legado
-- `rfid_scans` era telemetria paralela: nenhuma função cruzava leitura com
-- packing.
--
-- Classificações (contrato: docs/contratos-api.md §7.3):
--   CONFIRMADO   tag lida que resolve para unidade alocada neste Evento
--   FALTANTE     unidade alocada ao Evento que não apareceu na leitura
--   EXTRA        tag lida, unidade conhecida, não alocada a este Evento
--   DESCONHECIDA tag lida que não resolve para nenhuma unidade
--
-- LOTE LEGADO: a tag colada num lote resolve em `lotes`, não em
-- `serial_numbers`. Sob a política unit-only ela é DESCONHECIDA, exatamente
-- como `resolveUnitOnlyRfidLegacy` decide no web. O código do lote entra só na
-- nota do scan, para o operador entender por que a leitura não casou, e
-- `rfid_scans.lote_id` NUNCA é preenchido: reconhecer lote como alvo
-- operacional é o fluxo que MAR-187 aposentou.
--
-- Aluguel avulso não entra em lugar nenhum: não tem etiqueta da casa.
--
-- Isolamento: read committed simples, sem FOR UPDATE. Conferência é leitura
-- mais telemetria e NÃO muta status de unidade nem de Evento.

CREATE OR REPLACE FUNCTION public.conferencia_rfid_evento(
  p_projeto_id uuid,
  p_tags text[],
  p_contexto public.contexto_scan_enum,
  p_operador text,
  p_reader_id uuid DEFAULT NULL
)
RETURNS TABLE(
  classificacao text,
  tag_rfid text,
  serial_id uuid,
  codigo_interno text,
  item_nome text,
  scan_id uuid,
  ordem int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_operador text;
BEGIN
  v_operador := nullif(btrim(coalesce(p_operador, '')), '');

  IF v_operador IS NULL THEN
    RAISE EXCEPTION 'operador é obrigatório na conferência RFID';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.projetos WHERE id = p_projeto_id) THEN
    RAISE EXCEPTION 'Evento % não encontrado', p_projeto_id;
  END IF;

  RETURN QUERY
  WITH normalizadas AS (
    -- Mesma normalização de `normalizeRfidTag` no web: upper, sem espaço,
    -- dois-pontos nem hífen.
    SELECT
      upper(regexp_replace(btrim(t.raw), '[[:space:]:-]+', '', 'g')) AS tag,
      t.ord::int AS ord
    FROM unnest(coalesce(p_tags, ARRAY[]::text[])) WITH ORDINALITY AS t(raw, ord)
  ),
  -- Dedupe preservando a ordem de leitura: a primeira ocorrência manda.
  lidas AS (
    SELECT DISTINCT ON (n.tag) n.tag, n.ord
    FROM normalizadas n
    WHERE n.tag <> ''
    ORDER BY n.tag, n.ord
  ),
  resolvidas AS (
    SELECT
      l.tag,
      l.ord,
      sn.id AS serial_id,
      sn.codigo_interno,
      it.nome AS item_nome,
      lo.codigo_lote AS lote_codigo
    FROM lidas l
    LEFT JOIN public.serial_numbers sn ON sn.tag_rfid = l.tag
    LEFT JOIN public.items it ON it.id = sn.item_id
    LEFT JOIN public.lotes lo ON lo.tag_rfid = l.tag
  ),
  alocadas AS (
    SELECT
      pa.serial_id,
      sn.codigo_interno,
      sn.tag_rfid,
      it.nome AS item_nome
    FROM public.packing_allocations pa
    JOIN public.packing_list pl ON pl.id = pa.packing_id
    JOIN public.serial_numbers sn ON sn.id = pa.serial_id
    LEFT JOIN public.items it ON it.id = sn.item_id
    WHERE pl.projeto_id = p_projeto_id
  ),
  -- Telemetria: uma linha por tag lida, resolvida ou não.
  gravadas AS (
    INSERT INTO public.rfid_scans (
      tag_rfid, serial_number_id, reader_id, projeto_id, operador, contexto, notas
    )
    SELECT
      r.tag,
      r.serial_id,
      p_reader_id,
      p_projeto_id,
      v_operador,
      p_contexto,
      CASE
        WHEN r.serial_id IS NOT NULL THEN NULL
        WHEN r.lote_codigo IS NOT NULL
          THEN 'Tag RFID não reconhecida / Lote legado: ' || r.lote_codigo
        ELSE 'Tag RFID não reconhecida'
      END
    FROM resolvidas r
    RETURNING rfid_scans.id, rfid_scans.tag_rfid
  )
  SELECT
    CASE
      WHEN r.serial_id IS NULL THEN 'DESCONHECIDA'
      WHEN EXISTS (SELECT 1 FROM alocadas a WHERE a.serial_id = r.serial_id) THEN 'CONFIRMADO'
      ELSE 'EXTRA'
    END AS classificacao,
    r.tag AS tag_rfid,
    r.serial_id,
    r.codigo_interno,
    r.item_nome,
    g.id AS scan_id,
    r.ord AS ordem
  FROM resolvidas r
  LEFT JOIN gravadas g ON g.tag_rfid = r.tag

  UNION ALL

  SELECT
    'FALTANTE' AS classificacao,
    a.tag_rfid,
    a.serial_id,
    a.codigo_interno,
    a.item_nome,
    NULL::uuid AS scan_id,
    NULL::int AS ordem
  FROM alocadas a
  WHERE NOT EXISTS (
    SELECT 1 FROM resolvidas r2 WHERE r2.serial_id = a.serial_id
  )

  ORDER BY 1, 7 NULLS LAST, 4;
END;
$$;

COMMENT ON FUNCTION public.conferencia_rfid_evento(uuid, text[], public.contexto_scan_enum, text, uuid) IS
  'Conferência física do Evento: cruza tags lidas com packing_allocations e devolve CONFIRMADO, FALTANTE, EXTRA e DESCONHECIDA. Tag de lote legado é DESCONHECIDA com nota. Grava toda leitura em rfid_scans e não muta status.';


-- ============================================================================
-- 10. GRANTS
-- ============================================================================
-- Padrão anti-spoofing do legado, agora num bloco único no fim do arquivo.
--
-- Por que EXECUTE só para service_role: `registrado_por` e `registrado_por_id`
-- são parâmetros. Se `authenticated` pudesse chamar a RPC direto pela Data
-- API, qualquer usuário logado assinaria uma saída de equipamento com o nome
-- de outra pessoa. A derivação por `auth.uid()` fecha o caso de quem tem
-- sessão, mas o REVOKE continua sendo a barreira principal.
--
-- Risco §5.5 da auditoria (replay fora de ordem reabrindo a função para
-- `authenticated`): aqui não existe janela, todos os grants estão neste bloco,
-- REVOKE antes de GRANT, e `validation/delta-contract.test.ts` falha se alguém
-- acrescentar `authenticated`.
--
-- REVOKE de PUBLIC não é redundante: o Postgres concede EXECUTE a PUBLIC por
-- padrão em toda função nova, inclusive nas recriadas depois do DROP acima.

REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.checkout_projeto_com_override(uuid, public.metodo_scan_enum, text, uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkout_projeto_com_override(uuid, public.metodo_scan_enum, text, uuid, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.checkout_projeto_com_override(uuid, public.metodo_scan_enum, text, uuid, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.checkout_projeto_com_override(uuid, public.metodo_scan_enum, text, uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.resolver_retorno_pendencia(uuid, text, text, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.resolver_retorno_pendencia(uuid, text, text, text, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.resolver_retorno_pendencia(uuid, text, text, text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.resolver_retorno_pendencia(uuid, text, text, text, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.auto_allocate_packing(uuid, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.auto_allocate_packing(uuid, text, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.auto_allocate_packing(uuid, text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.auto_allocate_packing(uuid, text, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.conferencia_rfid_evento(uuid, text[], public.contexto_scan_enum, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.conferencia_rfid_evento(uuid, text[], public.contexto_scan_enum, text, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.conferencia_rfid_evento(uuid, text[], public.contexto_scan_enum, text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.conferencia_rfid_evento(uuid, text[], public.contexto_scan_enum, text, uuid) TO service_role;
