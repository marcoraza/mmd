-- ============================================================================
-- EventPro: RPCs de negócio
-- Fase 2 do plano de migração (docs/plano-migracao-eventpro.md)
-- ----------------------------------------------------------------------------
-- Este arquivo porta as 4 RPCs que concentram a regra operacional do legado
-- (`checkout_projeto`, `checkout_projeto_com_override`, `checkin_projeto`,
-- `resolver_retorno_pendencia`) e acrescenta as 2 que o EventPro precisa ter e
-- o legado nunca teve (`auto_allocate_packing`, `conferencia_rfid_evento`).
--
-- Referência do legado: `supabase/migrations/00007_loop_operacional.sql`,
-- `20260623081000`, `20260623083000`, `20260623094805` e `20260623193758`
-- (versões finais). O que muda aqui em relação a elas:
--
--   1. Alocação vem de `packing_allocations` (JOIN com `packing_list`), não do
--      array `packing_list.serial_numbers_designados uuid[]`. Toda leitura de
--      "quais seriais saem neste Evento" passou a ser relacional.
--   2. Autoria dupla: além do label `registrado_por text`, cada RPC grava
--      `registrado_por_id` com FK real para `profiles` (auditoria §1.3).
--   3. Check-in remove a alocação da unidade que fechou o ciclo; a unidade que
--      não voltou mantém a alocação até a pendência ser resolvida (seção 5).
--   4. Auto-alocação virou RPC atômica com `FOR UPDATE SKIP LOCKED`, matando a
--      race documentada como TODO em `apps/web/src/lib/actions/projetos.ts`.
--   5. Conferência RFID fecha o loop leitura versus operação (gap §4.1).
--
-- O que NÃO muda: readiness 100% por linha somando seriais próprios com
-- `alugueis_avulsos`, locks `FOR UPDATE` antes de qualquer decisão, ordem
-- auditoria-antes-de-mutação, cobertura total obrigatória no check-in, UPSERT
-- de pendência, regra de status do Evento e execução restrita a `service_role`.
--
-- Validação local:
--   psql -v ON_ERROR_STOP=1 \
--     -f validation/local-harness.sql \
--     -f migrations/0001_initial_schema.sql \
--     -f migrations/0002_rpcs.sql \
--     -f validation/rpc-smoke.sql
-- ============================================================================


-- ============================================================================
-- 1. AUTORIA: label de exibição + FK real
-- ============================================================================
-- No legado `registrado_por` era text livre e a única barreira contra spoofing
-- era o REVOKE de EXECUTE (só service_role chama). O EventPro mantém essa
-- barreira e acrescenta a identidade verificável.
--
-- Regra de derivação, na ordem:
--
--   a) há sessão (`auth.uid()` não nulo): o autor é o dono da sessão, e o
--      parâmetro `p_registrado_por_id` é ignorado. Ninguém logado consegue
--      carimbar outra pessoa como autora.
--   b) não há sessão (caminho service role, que é como o BFF chama hoje): o
--      autor é `p_registrado_por_id`, quando informado.
--   c) nenhum dos dois: autor nulo. A coluna é nullable de propósito, porque
--      job de manutenção e script de carga não têm profile e ainda assim
--      precisam poder registrar movimento.
--
-- Nos casos (a) e (b) o id é validado contra `profiles`: FK quebrada aborta a
-- transação inteira em vez de gravar auditoria órfã.
--
-- O label text continua obrigatório em todas as RPCs, mesmo quando existe id.
-- Ele é congelado no registro: é o nome que a timeline mostra, e não deve mudar
-- retroativamente se a pessoa trocar de nome nem sumir se o perfil for apagado.

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
-- 2. checkout_projeto
-- ============================================================================
-- Saída do Evento pela porta da frente: exige readiness 100%.
--
-- Ordem obrigatória, herdada do legado e verificada por teste de contrato:
--   1. trava o Evento (FOR UPDATE) e valida status;
--   2. valida readiness por linha de packing;
--   3. trava os seriais (FOR UPDATE) e valida que estão DISPONIVEL;
--   4. grava `movimentacoes` (auditoria antes de mutação);
--   5. muta `serial_numbers`;
--   6. muta o status do Evento.
--
-- A auditoria vem antes da mutação porque as duas estão na mesma transação: se
-- o UPDATE falhar, nada fica gravado; se a auditoria falhar, a mutação nem
-- acontece. Não existe janela em que o estado físico mudou sem trilha.
--
-- Evento 100% terceirizado (nenhum serial próprio alocado, cobertura toda por
-- aluguel avulso) é caso válido: o bloco de seriais é pulado e o Evento vai
-- para EM_CAMPO do mesmo jeito.
--
-- CONFIRMADO e MONTAGEM são os dois status que aceitam saída (auditoria §5.1).

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
  -- `computePackingCoverage`, só que a parcela própria agora é contagem de
  -- linhas em packing_allocations, não array_length de uuid[].
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
-- 3. checkout_projeto_com_override
-- ============================================================================
-- Mesma mecânica, sem a checagem de readiness, e só depois de um registro
-- prévio em `checkout_overrides` (motivo com no mínimo 10 caracteres e snapshot
-- do gate, garantidos pela própria tabela e pela policy de insert só admin).
--
-- O que a override NÃO libera: unidade que não está DISPONIVEL. Isso continua
-- sendo hard blocker, porque significa que o equipamento está fisicamente em
-- outro lugar. Override é exceção de processo, não de realidade física.

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
-- 4. checkin_projeto
-- ============================================================================
-- Conferência de retorno. Três resultados por unidade:
--
--   OK          -> DISPONIVEL, desgaste atualizado
--   PROBLEMA    -> MANUTENCAO, exige observação com no mínimo 3 caracteres
--   NAO_VOLTOU  -> RETORNANDO, abre pendência, não dá baixa automática
--
-- Cobertura total é obrigatória: a lista enviada precisa bater exatamente com
-- as unidades EM_CAMPO deste Evento, sem duplicata, sem sobra e sem falta. Um
-- retorno parcial silencioso é pior que um erro, porque deixa unidade EM_CAMPO
-- sem ninguém responsável por ela.
--
-- O Evento só vai para FINALIZADO se não sobrar pendência aberta.

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
  -- alocação, mas não entra no esperado: quem fecha o caso dela é
  -- resolver_retorno_pendencia, não uma segunda conferência.
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

  -- ------------------------------------------------------------------------
  -- 4.1 Liberação da alocação
  -- ------------------------------------------------------------------------
  -- Decisão: a alocação morre quando o ciclo da UNIDADE fecha, não quando o
  -- Evento fecha.
  --
  --   OK e PROBLEMA  -> a unidade voltou fisicamente (DISPONIVEL ou
  --                     MANUTENCAO). DELETE da linha de packing_allocations
  --                     aqui mesmo, liberando a unidade para o próximo Evento
  --                     sem esperar a resolução administrativa de outra
  --                     unidade que nada tem a ver com ela.
  --   NAO_VOLTOU     -> a alocação FICA até a pendência ser resolvida (o
  --                     DELETE acontece em resolver_retorno_pendencia).
  --
  -- Por que manter a alocação da unidade que não voltou: `packing_allocations`
  -- tem UNIQUE (serial_id), então a linha viva é exatamente a trava que impede
  -- prometer para outro cliente um equipamento que ninguém sabe onde está.
  -- Apagar aqui deixaria a unidade formalmente livre enquanto está perdida, e
  -- o único obstáculo passaria a ser o status RETORNANDO, que é uma barreira
  -- mais fraca (auto_allocate filtra por DISPONIVEL, mas alocação manual
  -- futura não precisaria). Além disso, a alocação viva é o que liga a
  -- pendência ao Evento de origem na tela de investigação.
  --
  -- A alternativa (apagar tudo na finalização do Evento) foi descartada por
  -- prender unidade boa: um Evento com uma pendência aberta seguraria todas as
  -- outras unidades já devolvidas, e elas ficariam indisponíveis para alocação
  -- por um motivo administrativo, não físico.
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
  'Conferência de retorno com cobertura total obrigatória. Libera a alocação da unidade que voltou e mantém a da que não voltou até a pendência ser resolvida.';


-- ============================================================================
-- 5. resolver_retorno_pendencia
-- ============================================================================
-- Fechamento administrativo do caso aberto pelo check-in.
--
--   ENCONTRADA -> DISPONIVEL
--   MANUTENCAO -> MANUTENCAO (exige observação)
--   BAIXA      -> BAIXA
--   COBRANCA   -> não altera o status da unidade (exige observação); a unidade
--                 segue RETORNANDO, porque cobrar não faz o equipamento
--                 aparecer.
--
-- Em todos os casos grava movimentação e, ao zerar as pendências abertas do
-- Evento, finaliza o Evento.

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

  -- Contraparte do DELETE parcial do check-in (seção 4.1): o ciclo desta
  -- unidade fechou agora, então a alocação sai. Vale inclusive para COBRANCA,
  -- em que a unidade continua RETORNANDO: quem impede realocação a partir daí
  -- é o status, não uma alocação pendurada num Evento já encerrado.
  DELETE FROM public.packing_allocations pa
  WHERE pa.serial_id = v_pendencia.serial_number_id;

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
-- 6. auto_allocate_packing (NOVA)
-- ============================================================================
-- Substitui o `autoAllocate` da aplicação, que tinha race documentada como TODO
-- em `apps/web/src/lib/actions/projetos.ts`: dois auto-allocates simultâneos em
-- packings do mesmo item liam o mesmo serial DISPONIVEL e ambos gravavam o
-- mesmo uuid, em Eventos diferentes.
--
-- Como a race morre aqui:
--   1. a linha de packing é travada com FOR UPDATE, serializando duas chamadas
--      concorrentes para a MESMA linha;
--   2. os candidatos são travados com FOR UPDATE SKIP LOCKED, então uma
--      chamada concorrente para OUTRA linha simplesmente pula a unidade já
--      reservada por uma transação em curso, em vez de disputá-la;
--   3. `packing_allocations` tem UNIQUE (serial_id) e o INSERT usa ON CONFLICT
--      DO NOTHING como segunda barreira. Se as duas primeiras falharem, o banco
--      ainda recusa a alocação dupla.
--
-- Consequência assumida do SKIP LOCKED: sob concorrência, a chamada pode alocar
-- menos que o necessário em vez de esperar. É o comportamento correto para
-- auto-alocação (é sugestão, não promessa), e a linha continua visivelmente
-- incompleta na UI e no gate de saída.
--
-- Ordem de escolha (mesma de `sortAllocationCandidates` em allocation-core.ts):
-- unidade nunca movimentada primeiro, depois a movimentada há mais tempo,
-- depois menor desgaste, depois código interno. `last_moved_at` não é coluna:
-- deriva do MAX(timestamp) de `movimentacoes` da unidade.
--
-- Idempotência: linha já coberta por alocação própria retorna conjunto vazio
-- sem erro. A função NUNCA remove alocação existente, só acrescenta.
--
-- Aluguel avulso não conta para a meta: auto-alocação trata de unidade própria.
-- Quem soma as duas coberturas é o gate de saída (`computePackingCoverage`) e o
-- readiness do `checkout_projeto`.
--
-- Autoria: a alocação não é movimento físico e por isso não gera linha em
-- `movimentacoes` (mesma decisão do legado). Os parâmetros de autor existem
-- para uniformidade de assinatura e são validados: chamada com autor
-- inexistente ou label vazio falha aqui, não lá na frente no check-out.

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
    -- o nome de uma coluna de saída da função, e o inferido por coluna ficaria
    -- ambíguo entre variável de PL/pgSQL e coluna da tabela.
    ON CONFLICT ON CONSTRAINT packing_allocations_serial_unique DO NOTHING
    RETURNING packing_allocations.serial_id
  )
  SELECT i.serial_id, sn.codigo_interno
  FROM inseridos i
  JOIN public.serial_numbers sn ON sn.id = i.serial_id
  ORDER BY sn.codigo_interno;
END;
$$;

COMMENT ON FUNCTION public.auto_allocate_packing(uuid, text, uuid) IS
  'Auto-alocação atômica de unidades DISPONIVEL para uma linha de packing, com FOR UPDATE SKIP LOCKED. Idempotente e nunca remove alocação existente.';


-- ============================================================================
-- 7. conferencia_rfid_evento (NOVA)
-- ============================================================================
-- Fecha o loop RFID versus operação (gap §4.1 da auditoria). No legado
-- `rfid_scans` era telemetria paralela: nenhuma função cruzava leitura com
-- packing, e não existia conferência física.
--
-- O que a função faz:
--   1. normaliza as tags (upper, remove espaço, dois-pontos e hífen), do mesmo
--      jeito que `normalizeRfidTag` em `eventpro/lib/rfid-scan-core.ts`,
--      deduplicando e preservando a ordem de leitura;
--   2. resolve cada tag contra `serial_numbers.tag_rfid`;
--   3. cruza com as unidades alocadas ao Evento (packing_allocations);
--   4. grava TODAS as leituras em `rfid_scans`, inclusive a tag desconhecida,
--      com nota, exatamente como o legado faz em `/api/rfid/scans`;
--   5. devolve uma linha por resultado, classificada.
--
-- Classificações (contrato: eventpro/docs/contratos-api.md §7.3):
--   CONFIRMADO   tag lida que resolve para unidade alocada neste Evento
--   FALTANTE     unidade alocada ao Evento que não apareceu na leitura
--   EXTRA        tag lida, unidade conhecida, não alocada a este Evento
--   DESCONHECIDA tag lida que não resolve para nenhuma unidade
--
-- Aluguel avulso não entra em lugar nenhum: não tem etiqueta da casa.
--
-- Isolamento: read committed simples, sem FOR UPDATE. Conferência é leitura
-- mais telemetria e NÃO muta status de unidade nem de Evento; a mutação
-- continua sendo exclusividade de check-out e check-in. Travar unidade aqui só
-- criaria contenção contra a operação real que está acontecendo ao lado.
--
-- Chamada repetida é segura: cada chamada grava um lote novo de scans e
-- recalcula os buckets do zero. Não é idempotente no log, é idempotente no
-- resultado.
--
-- `p_contexto` aceita qualquer valor do enum. A restrição a CARREGAMENTO,
-- RETORNO e CONFERENCIA é do endpoint (contrato §7.2), não do banco: inventário
-- e conferência avulsa também podem querer o mesmo cruzamento.
--
-- O upsert do leitor e o carimbo de `ultima_atividade` ficam no endpoint, como
-- em `/api/rfid/scans`. Aqui `p_reader_id` só é gravado nos scans.

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
      it.nome AS item_nome
    FROM lidas l
    LEFT JOIN public.serial_numbers sn ON sn.tag_rfid = l.tag
    LEFT JOIN public.items it ON it.id = sn.item_id
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
      CASE WHEN r.serial_id IS NULL THEN 'Tag RFID não reconhecida' ELSE NULL END
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
  'Conferência física do Evento: cruza tags lidas com packing_allocations e devolve CONFIRMADO, FALTANTE, EXTRA e DESCONHECIDA. Grava toda leitura em rfid_scans e não muta status.';


-- ============================================================================
-- 8. GRANTS
-- ============================================================================
-- Padrão anti-spoofing herdado do legado, agora aplicado de origem e num bloco
-- único, no fim do arquivo.
--
-- Por que EXECUTE só para service_role: `registrado_por` e `registrado_por_id`
-- são parâmetros. Se `authenticated` pudesse chamar a RPC direto pela Data API,
-- qualquer usuário logado assinaria uma saída de equipamento com o nome de
-- outra pessoa. A derivação por `auth.uid()` da seção 1 fecha o caso de quem
-- tem sessão, mas o REVOKE continua sendo a barreira principal: a chamada passa
-- obrigatoriamente pelo servidor, que já validou role antes de chamar.
--
-- No legado isso era risco ativo de replay (auditoria §5.5): as migrations
-- `20260623081000` e `20260623083000` davam e tiravam EXECUTE de
-- `authenticated` em ordens diferentes, e um replay fora de ordem reabria a
-- função. Aqui não existe janela: os grants estão todos neste bloco final,
-- REVOKE antes de GRANT, e o teste de contrato
-- `validation/rpc-contract.test.ts` falha se alguém acrescentar `authenticated`.
--
-- REVOKE de PUBLIC é obrigatório e não é redundante: o Postgres concede EXECUTE
-- a PUBLIC por padrão em toda função nova.

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
