-- ============================================================================
-- EventPro delta 4/5: índices e constraints defensivos em packing_list
-- ----------------------------------------------------------------------------
-- Auditoria §4.5: `packing_list` é a tabela mais consultada do app e não tem
-- índice nenhum além da PK, nem UNIQUE (projeto_id, item_id). O reference
-- §4.6 traz as duas coisas.
--
-- Esta migration é DEFENSIVA de propósito. Ela roda contra um banco real, com
-- dados que ninguém garantiu que respeitam as invariantes do design alvo. A
-- regra aqui é: nunca mesclar, apagar ou corrigir dado automaticamente. Onde o
-- dado não permite criar a constraint, a migration reporta e segue.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Índice por evento
-- ----------------------------------------------------------------------------
-- Todo carregamento de tela de Evento faz `WHERE projeto_id = ...`. Índice sem
-- risco: não impõe invariante, só acelera.

CREATE INDEX IF NOT EXISTS idx_packing_list_projeto
  ON public.packing_list(projeto_id);


-- ----------------------------------------------------------------------------
-- 2. UNIQUE (projeto_id, item_id), só se o dado permitir
-- ----------------------------------------------------------------------------
-- "Uma linha por (Evento, item)" é a invariante do design alvo. Duplicata
-- significa readiness contado duas vezes e alocação dividida entre linhas
-- irmãs.
--
-- Por que não mesclar: mesclar duas linhas exige decidir se a quantidade final
-- é a soma ou o máximo, o que fazer com `alugueis_avulsos` divergentes e com
-- `notas` de cada linha. Nenhuma dessas decisões é do banco. A migration
-- reporta as duplicatas com projeto_id, item_id e contagem, e NÃO cria a
-- constraint. Depois de o time resolver na aplicação, basta reaplicar este
-- bloco (é idempotente) para a constraint entrar.

DO $$
DECLARE
  v_dups     bigint := 0;
  v_amostra  text;
BEGIN
  SELECT count(*), left(string_agg(format('(projeto=%s, item=%s, linhas=%s)', d.projeto_id, d.item_id, d.n), ', '), 1000)
  INTO v_dups, v_amostra
  FROM (
    SELECT pl.projeto_id, pl.item_id, count(*) AS n
    FROM public.packing_list pl
    GROUP BY pl.projeto_id, pl.item_id
    HAVING count(*) > 1
  ) d;

  IF v_dups > 0 THEN
    RAISE WARNING 'packing_list: % par(es) (projeto_id, item_id) duplicado(s). A constraint packing_list_projeto_item_unique NÃO foi criada e nenhum dado foi mesclado. Resolva na aplicação e reaplique este bloco. Duplicatas: %',
      v_dups, coalesce(v_amostra, '-');
  ELSIF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'packing_list_projeto_item_unique'
      AND conrelid = 'public.packing_list'::regclass
  ) THEN
    RAISE NOTICE 'packing_list: constraint packing_list_projeto_item_unique já existe.';
  ELSE
    ALTER TABLE public.packing_list
      ADD CONSTRAINT packing_list_projeto_item_unique UNIQUE (projeto_id, item_id);
    RAISE NOTICE 'packing_list: constraint packing_list_projeto_item_unique criada.';
  END IF;
END $$;


-- ----------------------------------------------------------------------------
-- 3. Sanidade de quantidade, em duas etapas
-- ----------------------------------------------------------------------------
-- `quantidade` é `int NOT NULL DEFAULT 1` sem CHECK no legado. Linha com
-- quantidade 0 ou negativa deixa o gate de saída com readiness sem sentido
-- (cobertura >= 0 é sempre verdadeira).
--
-- NOT VALID primeiro, VALIDATE depois, e não numa única constraint validada,
-- por dois motivos:
--
--   * NOT VALID já protege TODA escrita nova sem varrer a tabela inteira e sem
--     pegar ACCESS EXCLUSIVE pelo tempo da varredura. Numa janela de produção
--     isso é a diferença entre travar a operação e não travar.
--   * se existir linha histórica ruim, uma constraint validada faria a
--     migration inteira falhar. Aqui a proteção nova entra do mesmo jeito, e
--     o passivo histórico vira aviso em vez de rollback.

ALTER TABLE public.packing_list
  DROP CONSTRAINT IF EXISTS packing_list_quantidade_positiva;

ALTER TABLE public.packing_list
  ADD CONSTRAINT packing_list_quantidade_positiva CHECK (quantidade > 0) NOT VALID;

DO $$
DECLARE
  v_ruins bigint := 0;
BEGIN
  ALTER TABLE public.packing_list VALIDATE CONSTRAINT packing_list_quantidade_positiva;
  RAISE NOTICE 'packing_list: constraint packing_list_quantidade_positiva validada.';
EXCEPTION
  WHEN check_violation THEN
    SELECT count(*) INTO v_ruins FROM public.packing_list WHERE quantidade <= 0;
    RAISE WARNING 'packing_list: % linha(s) com quantidade <= 0. A constraint packing_list_quantidade_positiva fica NOT VALID (protege escrita nova, não bloqueia o histórico). Corrija as linhas e rode VALIDATE CONSTRAINT depois.',
      v_ruins;
END $$;
