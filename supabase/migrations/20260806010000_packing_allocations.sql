-- ============================================================================
-- EventPro delta 1/5: packing_allocations
-- ----------------------------------------------------------------------------
-- Converge o banco legado para o design alvo de
-- `supabase/reference/0001_initial_schema.sql` §4.7: a alocação de unidade
-- própria a uma linha de packing deixa de ser o array
-- `packing_list.serial_numbers_designados uuid[]` e passa a ser uma tabela
-- relacional com UNIQUE (serial_id).
--
-- O que esta migration faz, nesta ordem:
--   1. cria `packing_allocations` (tabela, índice, RLS, policies, grants);
--   2. faz BACKFILL do estado atual dos arrays, descartando uuid órfão
--      (id que não existe em `serial_numbers`, resíduo do array sem FK) e
--      duplicata entre linhas de packing, com relatório em RAISE NOTICE;
--   3. instala o trigger de SINCRONIZAÇÃO array -> tabela.
--
-- ----------------------------------------------------------------------------
-- Por que existe um trigger de sincronização (e quando ele morre)
-- ----------------------------------------------------------------------------
-- O web app legado (mmd) continua rodando contra este mesmo banco durante a
-- transição e escreve alocação com UPDATE direto no array
-- (`setAllocation`, `autoAllocate`, `releaseSerial` em
-- `apps/web/src/lib/actions/projetos.ts`). Sem sincronização, toda alocação
-- feita pela UI antiga ficaria invisível para as RPCs novas, que leem a tabela.
--
-- Direção coberta aqui: ARRAY -> TABELA, por trigger.
-- Direção inversa (TABELA -> ARRAY): fica nas RPCs do EventPro, como
-- dual-write explícito (`app_private.sync_array_from_allocations`, delta 5),
-- NÃO como trigger em `packing_allocations`. Dois triggers espelhados seriam
-- um ciclo: UPDATE no array -> escreve na tabela -> escreve no array -> ...
--
-- Mesmo com um trigger só, a RPC que faz dual-write dispara este trigger de
-- volta. Isso não é loop infinito (o trigger não escreve em packing_list), mas
-- é reentrância desnecessária e uma reconciliação que sobrescreveria a decisão
-- da RPC. Dois guards resolvem, explicitamente:
--
--   a) GUC transacional `eventpro.skip_allocation_sync`: a RPC liga o flag
--      antes do dual-write. Dentro dessa janela a tabela é a autoridade e o
--      trigger não reconcilia. O flag é local à transação e, por ser setado
--      dentro de uma função com cláusula SET, volta ao valor anterior quando
--      a função retorna (AtEOXact_GUC no nest level da função).
--   b) `pg_trigger_depth() > 1`: fail-safe estrutural. Se um dia alguém criar
--      um trigger em `packing_allocations` que escreva em `packing_list`, o
--      ciclo para aqui em vez de estourar a pilha em produção.
--
-- MORTE PROGRAMADA: quando o web legado for aposentado, a coluna
-- `packing_list.serial_numbers_designados`, este trigger, a função
-- `public.sync_packing_allocations_from_array()` e o dual-write das RPCs saem
-- juntos, numa única migration. Até lá, a tabela é a fonte de verdade e o
-- array é uma projeção mantida para compatibilidade.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Tabela
-- ----------------------------------------------------------------------------
-- Idêntica ao reference §4.7. UNIQUE (serial_id) global, não parcial: uma
-- unidade física está em no máximo uma linha de packing, de um único evento,
-- em qualquer instante. Desalocar é DELETE, não flag.

CREATE TABLE IF NOT EXISTS public.packing_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  packing_id uuid NOT NULL REFERENCES public.packing_list(id) ON DELETE CASCADE,
  serial_id uuid NOT NULL REFERENCES public.serial_numbers(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT packing_allocations_serial_unique UNIQUE (serial_id)
);

COMMENT ON TABLE public.packing_allocations IS
  'Alocação ativa de unidade própria a uma linha de packing. Desalocar é DELETE. UNIQUE(serial_id) garante uma unidade em um evento por vez.';

CREATE INDEX IF NOT EXISTS idx_packing_allocations_packing
  ON public.packing_allocations(packing_id);


-- ----------------------------------------------------------------------------
-- 2. RLS, policies e grants
-- ----------------------------------------------------------------------------
-- Mesma matriz de packing_list no legado (20260623181333): leitura para
-- authenticated, escrita e delete para editor/admin. Alocar e desalocar é
-- planejamento, então editor precisa de DELETE.

ALTER TABLE public.packing_allocations ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.packing_allocations FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.packing_allocations FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.packing_allocations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.packing_allocations TO service_role;

DROP POLICY IF EXISTS packing_allocations_read ON public.packing_allocations;
DROP POLICY IF EXISTS packing_allocations_insert ON public.packing_allocations;
DROP POLICY IF EXISTS packing_allocations_update ON public.packing_allocations;
DROP POLICY IF EXISTS packing_allocations_delete ON public.packing_allocations;

CREATE POLICY packing_allocations_read ON public.packing_allocations
  FOR SELECT TO authenticated USING (true);

CREATE POLICY packing_allocations_insert ON public.packing_allocations
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_allocations_update ON public.packing_allocations
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_allocations_delete ON public.packing_allocations
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'));


-- ----------------------------------------------------------------------------
-- 3. BACKFILL a partir de serial_numbers_designados
-- ----------------------------------------------------------------------------
-- Regras, todas conservadoras (a migration nunca inventa nem mescla dado):
--
--   * uuid que não existe em `serial_numbers` é DESCARTADO. É lixo herdado do
--     array sem integridade referencial: o legado apagava um serial e o id
--     continuava no array, inflando readiness. Descartar aqui é a correção,
--     não uma perda.
--   * o mesmo serial em duas linhas de packing (possível no array, impossível
--     na tabela) fica na PRIMEIRA linha em ordem determinística
--     (projeto_id, packing_id). A segunda é reportada e descartada: escolher
--     automaticamente qual evento perde a unidade seria pior que reportar.
--   * o array não é alterado aqui. A conciliação do array com a tabela é
--     responsabilidade do trigger (seção 4) e do dual-write das RPCs.
--
-- Idempotente: ON CONFLICT DO NOTHING, então reaplicar não duplica nem apaga.

DO $$
DECLARE
  v_pares          bigint := 0;
  v_orfaos         bigint := 0;
  v_orfaos_amostra text;
  v_dups           bigint := 0;
  v_dups_amostra   text;
  v_inseridos      bigint := 0;
BEGIN
  SELECT count(*)
  INTO v_pares
  FROM public.packing_list pl
  CROSS JOIN LATERAL unnest(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[]))
    AS alocado(serial_id);

  -- Órfãos: id no array sem linha correspondente em serial_numbers.
  SELECT count(DISTINCT alocado.serial_id),
         left(string_agg(DISTINCT alocado.serial_id::text, ', '), 500)
  INTO v_orfaos, v_orfaos_amostra
  FROM public.packing_list pl
  CROSS JOIN LATERAL unnest(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[]))
    AS alocado(serial_id)
  WHERE NOT EXISTS (SELECT 1 FROM public.serial_numbers sn WHERE sn.id = alocado.serial_id);

  -- Duplicatas: mesmo serial (existente) em mais de uma linha de packing.
  SELECT count(*), left(string_agg(d.serial_id::text, ', '), 500)
  INTO v_dups, v_dups_amostra
  FROM (
    SELECT alocado.serial_id
    FROM public.packing_list pl
    CROSS JOIN LATERAL unnest(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[]))
      AS alocado(serial_id)
    JOIN public.serial_numbers sn ON sn.id = alocado.serial_id
    GROUP BY alocado.serial_id
    HAVING count(DISTINCT pl.id) > 1
  ) d;

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

  GET DIAGNOSTICS v_inseridos = ROW_COUNT;

  RAISE NOTICE 'backfill packing_allocations: % par(es) no array, % linha(s) inserida(s).',
    v_pares, v_inseridos;

  IF v_orfaos > 0 THEN
    RAISE NOTICE 'backfill packing_allocations: % uuid(s) órfão(s) descartado(s) (não existem em serial_numbers). Amostra: %',
      v_orfaos, coalesce(v_orfaos_amostra, '-');
  ELSE
    RAISE NOTICE 'backfill packing_allocations: nenhum uuid órfão encontrado.';
  END IF;

  IF v_dups > 0 THEN
    RAISE WARNING 'backfill packing_allocations: % serial(is) apareciam em mais de uma linha de packing; a alocação ficou na primeira linha (ordem projeto_id, packing_id). Revise manualmente. Amostra: %',
      v_dups, coalesce(v_dups_amostra, '-');
  END IF;
END $$;


-- ----------------------------------------------------------------------------
-- 4. Trigger de sincronização ARRAY -> TABELA (transitório)
-- ----------------------------------------------------------------------------
-- Reconcilia `packing_allocations` da linha sempre que o legado grava o array:
-- apaga o que saiu, insere o que entrou.
--
-- Duas tolerâncias deliberadas, para que o trigger NUNCA quebre uma escrita do
-- app legado (ele não sabe que esta tabela existe e não tem como tratar o
-- erro):
--
--   * uuid inexistente em `serial_numbers` é ignorado em vez de estourar FK;
--   * serial já alocado em OUTRA linha vira ON CONFLICT DO NOTHING mais
--     RAISE WARNING. A alocação existente vence. Roubar a unidade de outro
--     evento silenciosamente é o pior desfecho possível aqui: é exatamente o
--     "equipamento prometido para dois clientes" que a UNIQUE existe para
--     impedir. O array pode ficar momentaneamente mais otimista que a tabela;
--     a tabela é quem manda.

CREATE OR REPLACE FUNCTION public.sync_packing_allocations_from_array()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ids       uuid[];
  v_conflitos uuid[];
BEGIN
  -- Guard (a): dual-write das RPCs do EventPro. Dentro dessa janela quem manda
  -- é packing_allocations, e reconciliar aqui desfaria a decisão da RPC.
  IF coalesce(current_setting('eventpro.skip_allocation_sync', true), 'off') = 'on' THEN
    RETURN NULL;
  END IF;

  -- Guard (b): reentrância. Nenhum trigger escreve em packing_list hoje; este
  -- teto existe para que um trigger futuro não feche o ciclo.
  IF pg_trigger_depth() > 1 THEN
    RETURN NULL;
  END IF;

  SELECT coalesce(array_agg(DISTINCT alocado.serial_id), ARRAY[]::uuid[])
  INTO v_ids
  FROM unnest(coalesce(NEW.serial_numbers_designados, ARRAY[]::uuid[])) AS alocado(serial_id)
  WHERE EXISTS (SELECT 1 FROM public.serial_numbers sn WHERE sn.id = alocado.serial_id);

  DELETE FROM public.packing_allocations pa
  WHERE pa.packing_id = NEW.id
    AND NOT (pa.serial_id = ANY(v_ids));

  INSERT INTO public.packing_allocations (packing_id, serial_id)
  SELECT NEW.id, s.serial_id
  FROM unnest(v_ids) AS s(serial_id)
  ON CONFLICT ON CONSTRAINT packing_allocations_serial_unique DO NOTHING;

  SELECT array_agg(s.serial_id)
  INTO v_conflitos
  FROM unnest(v_ids) AS s(serial_id)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.packing_allocations pa
    WHERE pa.serial_id = s.serial_id AND pa.packing_id = NEW.id
  );

  IF v_conflitos IS NOT NULL THEN
    RAISE WARNING 'sync_packing_allocations_from_array: packing % não recebeu % serial(is) já alocado(s) em outra linha: %',
      NEW.id, array_length(v_conflitos, 1), v_conflitos;
  END IF;

  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.sync_packing_allocations_from_array() IS
  'Transitório: reconcilia packing_allocations quando o web legado grava packing_list.serial_numbers_designados. Sai junto com a coluna uuid[] quando o legado for aposentado.';

REVOKE ALL ON FUNCTION public.sync_packing_allocations_from_array() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_packing_allocations_from_array() FROM anon;
REVOKE ALL ON FUNCTION public.sync_packing_allocations_from_array() FROM authenticated;

DROP TRIGGER IF EXISTS trg_packing_list_sync_allocations ON public.packing_list;
CREATE TRIGGER trg_packing_list_sync_allocations
  AFTER INSERT OR UPDATE OF serial_numbers_designados ON public.packing_list
  FOR EACH ROW EXECUTE FUNCTION public.sync_packing_allocations_from_array();

COMMENT ON COLUMN public.packing_list.serial_numbers_designados IS
  'LEGADO E TRANSITÓRIO. Fonte de verdade da alocação é public.packing_allocations. Esta coluna é mantida em sincronia (trigger na entrada, dual-write das RPCs na saída) apenas enquanto o web app mmd estiver em produção. Remover junto com o trigger trg_packing_list_sync_allocations.';
