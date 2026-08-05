-- ============================================================================
-- EventPro: schema fundacional
-- Fase 1 do plano de migração (docs/plano-migracao-eventpro.md)
-- ----------------------------------------------------------------------------
-- Este arquivo é o schema base do EventPro. Ele nasce limpo: o legado MMD em
-- `supabase/migrations/` serve como referência de conteúdo, não como base de
-- replay. Aqui não há seed de inventário, não há tabela `lotes`, não há bloco
-- de importação Event Pro e não há `ALTER TYPE ADD VALUE` retroativo.
--
-- Correções estruturais aplicadas em relação ao legado (auditoria §1.4, §4.5,
-- §5.1). Cada uma está comentada no ponto onde aparece:
--
--   1. `MONTAGEM` já nasce oficial em `status_projeto_enum`, na posição correta.
--   2. `packing_allocations` relacional substitui `serial_numbers_designados uuid[]`.
--   3. `packing_list` ganha índice em `projeto_id`, UNIQUE `(projeto_id, item_id)`
--      e colunas de timestamp com trigger de `updated_at`.
--   4. Auditoria com FK real: `registrado_por_id` / `resolvido_por_id` apontam
--      para `profiles`, mantendo a coluna de texto como label de exibição.
--   5. `rfid_readers` ganha o trigger de `updated_at` que faltava.
--   6. Prefixo de código interno é configurável via `app_config`, não hardcoded.
--   7. Máquina de estados do evento já com a matriz completa e `ELSE` fail-closed.
--   8. Storage com policies explícitas (o legado criava bucket sem nenhuma).
--
-- Convenções mantidas do legado: nomes de tabela e coluna em português,
-- `timestamptz` em tudo, `gen_random_uuid()` como PK default (core do Postgres
-- desde a 13, sem necessidade de pgcrypto).
--
-- Validação local: `eventpro/supabase/validation/local-harness.sql` cria os
-- stubs de `auth`, `storage` e roles para aplicar este arquivo num Postgres 16
-- vanilla.
-- ============================================================================


-- ============================================================================
-- 1. SCHEMAS
-- ============================================================================

-- Helper de role vive em schema privado para não ser exposto como RPC na Data
-- API do Supabase (padrão herdado de 20260623181333 do legado).
CREATE SCHEMA IF NOT EXISTS app_private;

REVOKE ALL ON SCHEMA app_private FROM PUBLIC;
REVOKE ALL ON SCHEMA app_private FROM anon;
GRANT USAGE ON SCHEMA app_private TO authenticated, service_role;

COMMENT ON SCHEMA app_private IS
  'Funções internas de autorização. Não exposta na Data API; anon não tem USAGE.';


-- ============================================================================
-- 2. ENUMS DE DOMÍNIO
-- ============================================================================

CREATE TYPE public.categoria_enum AS ENUM (
  'ILUMINACAO',
  'AUDIO',
  'CABO',
  'ENERGIA',
  'ESTRUTURA',
  'EFEITO',
  'VIDEO',
  'ACESSORIO'
);

-- `LOTE` continua no enum apenas para absorver dados históricos na carga da
-- fase 5 sem perder informação. Lotes não são fluxo operacional do EventPro
-- (unit-only desde MAR-187) e não existe tabela `lotes` neste schema.
CREATE TYPE public.tipo_rastreamento_enum AS ENUM (
  'INDIVIDUAL',
  'LOTE',
  'BULK'
);

CREATE TYPE public.status_serial_enum AS ENUM (
  'DISPONIVEL',
  'PACKED',
  'EM_CAMPO',
  'RETORNANDO',
  'MANUTENCAO',
  'EMPRESTADO',
  'VENDIDO',
  'BAIXA'
);

CREATE TYPE public.estado_enum AS ENUM (
  'NOVO',
  'SEMI_NOVO',
  'USADO',
  'RECONDICIONADO'
);

-- MONTAGEM entra aqui, na criação, entre CONFIRMADO e EM_CAMPO. No legado ele
-- só chegou por `ALTER TYPE ... ADD VALUE` numa migration de importação
-- (20260623193758), e a trava de transição criada depois não ganhou o ramo
-- correspondente: qualquer evento em MONTAGEM ficava preso com CASE_NOT_FOUND
-- e o check-out abortava (auditoria §5.1). No EventPro o status é oficial
-- desde o primeiro dia e a matriz de transição já o cobre.
CREATE TYPE public.status_projeto_enum AS ENUM (
  'PLANEJAMENTO',
  'CONFIRMADO',
  'MONTAGEM',
  'EM_CAMPO',
  'FINALIZADO',
  'CANCELADO'
);

CREATE TYPE public.tipo_movimentacao_enum AS ENUM (
  'SAIDA',
  'RETORNO',
  'MANUTENCAO',
  'TRANSFERENCIA',
  'DANO'
);

CREATE TYPE public.metodo_scan_enum AS ENUM (
  'RFID',
  'QRCODE',
  'MANUAL'
);

CREATE TYPE public.status_reader_enum AS ENUM (
  'ATIVO',
  'INATIVO',
  'MANUTENCAO'
);

CREATE TYPE public.contexto_scan_enum AS ENUM (
  'PACKING',
  'CARREGAMENTO',
  'CHECK_IN_EVENTO',
  'CHECK_OUT_EVENTO',
  'RETORNO',
  'CONFERENCIA',
  'INVENTARIO',
  'OUTRO'
);

CREATE TYPE public.user_role_enum AS ENUM (
  'viewer',
  'editor',
  'admin'
);


-- ============================================================================
-- 3. FUNÇÃO GENÉRICA DE updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_updated_at() IS
  'Trigger genérico BEFORE UPDATE: carimba updated_at. Usado por toda tabela que tem a coluna.';


-- ============================================================================
-- 4. TABELAS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4.1 profiles
-- ----------------------------------------------------------------------------
-- 1:1 com auth.users. É a âncora de autorização (role) e o alvo das FKs de
-- auditoria das demais tabelas.

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  nome text,
  role public.user_role_enum NOT NULL DEFAULT 'viewer',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.profiles IS
  'Perfil de usuário do EventPro, 1:1 com auth.users. Criado pelo trigger handle_new_user.';

CREATE INDEX idx_profiles_email ON public.profiles(email);


-- ----------------------------------------------------------------------------
-- 4.2 app_config
-- ----------------------------------------------------------------------------
-- Configuração de produto que o schema precisa ler em runtime. Nasceu para
-- resolver o prefixo `MMD-` hardcoded dentro de
-- `generate_item_codigo_interno()` no legado (auditoria §1.4): o EventPro pode
-- atender outra operação sem editar função de banco.
--
-- A linha `codigo_prefix` abaixo é bootstrap de configuração, não seed de
-- dados: sem ela a geração de código interno não tem como funcionar.

CREATE TABLE public.app_config (
  key text PRIMARY KEY,
  value text NOT NULL,
  descricao text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT app_config_key_not_blank CHECK (length(btrim(key)) > 0)
);

COMMENT ON TABLE public.app_config IS
  'Configuração de produto lida pelo próprio schema (ex: prefixo do código interno). Leitura para authenticated, escrita só admin.';

INSERT INTO public.app_config (key, value, descricao) VALUES
  ('codigo_prefix', 'MMD', 'Prefixo do código interno de item e unidade, no formato {prefix}-{CAT}-{NNNN}.')
ON CONFLICT (key) DO NOTHING;


-- ----------------------------------------------------------------------------
-- 4.3 items (tipo de equipamento no catálogo)
-- ----------------------------------------------------------------------------

CREATE TABLE public.items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo_interno text UNIQUE NOT NULL,
  nome text NOT NULL,
  categoria public.categoria_enum NOT NULL,
  subcategoria text,
  marca text,
  modelo text,
  tipo_rastreamento public.tipo_rastreamento_enum NOT NULL DEFAULT 'INDIVIDUAL',
  quantidade_total int NOT NULL DEFAULT 1,
  valor_mercado_unitario numeric(10,2),
  foto_url text,
  notas text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT items_nome_not_blank CHECK (length(btrim(nome)) > 0)
);

COMMENT ON TABLE public.items IS
  'Catálogo de tipos de equipamento. A unidade física rastreável é serial_numbers.';

COMMENT ON COLUMN public.items.codigo_interno IS
  'Código humano {prefix}-{CAT}-{NNNN}. Gerado por trigger quando não informado; prefixo vem de app_config.';

-- codigo_interno é NOT NULL e ainda assim opcional no INSERT: o trigger
-- BEFORE INSERT da seção 7 preenche antes de o Postgres checar constraints.
-- No legado a coluna nasceu nullable (herança do backfill) e só virou NOT NULL
-- numa migration seguinte; aqui já nasce fechada.


-- ----------------------------------------------------------------------------
-- 4.4 serial_numbers (unidade física)
-- ----------------------------------------------------------------------------

CREATE TABLE public.serial_numbers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.items(id) ON DELETE CASCADE,
  codigo_interno text UNIQUE NOT NULL,
  serial_fabrica text,
  tag_rfid text UNIQUE,
  qr_code text UNIQUE,
  status public.status_serial_enum NOT NULL DEFAULT 'DISPONIVEL',
  estado public.estado_enum NOT NULL DEFAULT 'USADO',
  desgaste int NOT NULL DEFAULT 3 CHECK (desgaste BETWEEN 1 AND 5),
  depreciacao_pct numeric(5,2),
  valor_atual numeric(10,2),
  localizacao text,
  notas text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.serial_numbers IS
  'Unidade física rastreável. Uma linha por equipamento real, com tag RFID e QR próprios.';

-- Unicidade de tag RFID numa casa só.
--
-- No legado, `tag_rfid` era UNIQUE em `serial_numbers` E em `lotes`, cada uma
-- no seu escopo: nada impedia a mesma tag existir simultaneamente nas duas
-- tabelas, então "tag única" não era verdade no sistema (auditoria §4.2).
-- No EventPro não existe tabela `lotes` (unit-only é decisão de produto), logo
-- `serial_numbers` é a única entidade que carrega tag RFID e o UNIQUE abaixo é
-- a garantia completa. Se algum dia entrar uma segunda entidade taggeável, a
-- unicidade precisa migrar para uma tabela de registro de tags, não ser
-- duplicada como UNIQUE local.
COMMENT ON COLUMN public.serial_numbers.tag_rfid IS
  'EPC da etiqueta RFID. UNIQUE global: serial_numbers é a única entidade taggeável do EventPro.';


-- ----------------------------------------------------------------------------
-- 4.5 projetos (Evento)
-- ----------------------------------------------------------------------------
-- Decisão de orquestração: a tabela continua se chamando `projetos`.
--
-- O produto fala Evento e a UI 2.0 diz Evento em toda superfície visível. O
-- nome físico da tabela fica como está porque a fase 2 porta as 4 RPCs de
-- negócio e a fase 3 porta ~20 módulos `*-core.ts` com suas suítes, todos
-- escritos contra `projeto_id` / `projetos`. Renomear agora transformaria um
-- porte 1:1 verificável num rewrite com superfície de erro grande, sem ganho
-- funcional. A tradução Evento acontece na camada de apresentação, exatamente
-- como já acontece hoje. Um rename futuro é uma migration isolada, com view de
-- compatibilidade, depois que o porte estiver estável.

CREATE TABLE public.projetos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  codigo_evento text UNIQUE,
  cliente text,
  data_inicio date,
  data_fim date,
  local text,
  status public.status_projeto_enum NOT NULL DEFAULT 'PLANEJAMENTO',
  ficha_evento jsonb,
  comercial jsonb NOT NULL DEFAULT jsonb_build_object(
    'status', null,
    'documentos', '[]'::jsonb,
    'observacoes', null,
    'atualizado_em', null,
    'permite_operacao_estoque', false,
    'readiness_pct', 0
  ),
  notas text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT projetos_nome_not_blank CHECK (length(btrim(nome)) > 0),
  CONSTRAINT projetos_ficha_evento_object
    CHECK (ficha_evento IS NULL OR jsonb_typeof(ficha_evento) = 'object'),
  CONSTRAINT projetos_comercial_object
    CHECK (jsonb_typeof(comercial) = 'object')
);

COMMENT ON TABLE public.projetos IS
  'Evento de locação. Nome físico mantido por compatibilidade com as RPCs e libs portadas; o produto chama de Evento.';

COMMENT ON COLUMN public.projetos.codigo_evento IS
  'Código humano curto do Evento, ex: EVT-260624-01.';

COMMENT ON COLUMN public.projetos.ficha_evento IS
  'Payload versionado da ficha: endereço, montagem, desmontagem, responsáveis, checklist e observações.';

COMMENT ON COLUMN public.projetos.comercial IS
  'Registro comercial leve: status do funil, documentos, links e anexos. Não é módulo financeiro.';

-- As colunas `importacao_origem`, `importacao_status` e `importacao_file_id`
-- do legado não foram portadas: elas só existem em função das tabelas de
-- importação one-off Event Pro, que a auditoria §1.4 classifica como não
-- portáveis. Se a fase 5 decidir herdar o histórico importado, elas voltam
-- numa migration própria junto com as tabelas de fila de revisão.


-- ----------------------------------------------------------------------------
-- 4.6 packing_list (linha de necessidade do Evento)
-- ----------------------------------------------------------------------------
-- Correção estrutural: no legado esta tabela era a mais consultada do app e
-- não tinha índice nenhum além da PK, nem UNIQUE `(projeto_id, item_id)`
-- (auditoria §4.5). Também não tinha timestamps.
--
-- A coluna `serial_numbers_designados uuid[]` NÃO existe aqui. A alocação
-- virou a tabela relacional `packing_allocations` (4.7).

CREATE TABLE public.packing_list (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES public.items(id) ON DELETE CASCADE,
  quantidade int NOT NULL DEFAULT 1 CHECK (quantidade > 0),
  alugueis_avulsos jsonb NOT NULL DEFAULT '[]'::jsonb,
  notas text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT packing_list_alugueis_avulsos_array
    CHECK (jsonb_typeof(alugueis_avulsos) = 'array'),
  CONSTRAINT packing_list_projeto_item_unique UNIQUE (projeto_id, item_id)
);

COMMENT ON TABLE public.packing_list IS
  'Linha de necessidade do Evento: um tipo de item e a quantidade exigida. Uma linha por (evento, item).';

COMMENT ON COLUMN public.packing_list.alugueis_avulsos IS
  'Coberturas por aluguel avulso de parceiro para esta linha. Não cria unidade própria nem patrimônio.';


-- ----------------------------------------------------------------------------
-- 4.7 packing_allocations (alocação de unidade própria)
-- ----------------------------------------------------------------------------
-- Substitui `packing_list.serial_numbers_designados uuid[]`.
--
-- Problema do legado: array de uuid sem integridade referencial. Serial
-- apagado deixava id órfão no array; `setAllocation` precisava de
-- presence-check manual na aplicação; `autoAllocate` tinha race conhecida
-- (TODO no código) porque não havia linha para travar; e nada impedia o mesmo
-- serial aparecer em dois eventos ao mesmo tempo (auditoria §2.3, §4.5).
--
-- Escolha de unicidade: `UNIQUE (serial_id)` global, não parcial.
--
-- Esta tabela representa alocação ATIVA e só isso: desalocar é DELETE da
-- linha, não mudança de flag. Sem coluna de estado, não existe "alocação
-- histórica" competindo pelo mesmo serial, então o UNIQUE simples já é a
-- invariante inteira: uma unidade física está em no máximo uma linha de
-- packing, de um único evento, em qualquer instante. O histórico de para onde
-- a unidade foi já é responsabilidade de `movimentacoes`, que é a trilha de
-- auditoria do sistema; duplicar isso aqui criaria duas fontes de verdade.
--
-- `UNIQUE (packing_id, serial_id)` seria mais fraco: impediria a duplicata na
-- mesma linha, mas deixaria o mesmo serial ser alocado em dois eventos
-- simultâneos, que é justamente a falha operacional cara (equipamento
-- prometido para dois clientes no mesmo fim de semana). O UNIQUE por
-- `serial_id` implica o par, então nada se perde.
--
-- Ganho adicional: com linha real, a RPC de auto-alocação da fase 2 pode usar
-- `SELECT ... FOR UPDATE SKIP LOCKED` e a race some no banco, não na aplicação.

CREATE TABLE public.packing_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  packing_id uuid NOT NULL REFERENCES public.packing_list(id) ON DELETE CASCADE,
  serial_id uuid NOT NULL REFERENCES public.serial_numbers(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT packing_allocations_serial_unique UNIQUE (serial_id)
);

COMMENT ON TABLE public.packing_allocations IS
  'Alocação ativa de unidade própria a uma linha de packing. Desalocar é DELETE. UNIQUE(serial_id) garante uma unidade em um evento por vez.';

CREATE INDEX idx_packing_allocations_packing ON public.packing_allocations(packing_id);


-- ----------------------------------------------------------------------------
-- 4.8 packing_templates
-- ----------------------------------------------------------------------------

CREATE TABLE public.packing_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  descricao text,
  origem_projeto_id uuid REFERENCES public.projetos(id) ON DELETE SET NULL,
  linhas jsonb NOT NULL DEFAULT '[]'::jsonb,
  criado_por uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT packing_templates_nome_not_blank CHECK (length(btrim(nome)) > 0),
  CONSTRAINT packing_templates_linhas_array CHECK (jsonb_typeof(linhas) = 'array')
);

COMMENT ON TABLE public.packing_templates IS
  'Templates reutilizáveis de packing. Cada linha referencia item de catálogo e quantidade sugerida.';

COMMENT ON COLUMN public.packing_templates.linhas IS
  'Array JSON com itemId, codigoInterno, nome, categoria, quantidade e observacao.';

-- No legado `criado_por` apontava direto para auth.users. Aqui aponta para
-- profiles, que é a entidade de domínio do EventPro e a mesma referência usada
-- pelas colunas de auditoria.


-- ----------------------------------------------------------------------------
-- 4.9 movimentacoes (trilha de estado físico)
-- ----------------------------------------------------------------------------
-- Correção estrutural: `registrado_por` era text livre, sem FK (auditoria
-- §1.3). Aqui a autoria ganha `registrado_por_id` com FK real para profiles, e
-- `registrado_por` permanece como label de exibição congelado no momento do
-- registro (o nome mostrado na timeline não deve mudar retroativamente se a
-- pessoa trocar de nome, nem sumir se o perfil for removido).

CREATE TABLE public.movimentacoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  serial_number_id uuid NOT NULL REFERENCES public.serial_numbers(id) ON DELETE CASCADE,
  projeto_id uuid REFERENCES public.projetos(id) ON DELETE SET NULL,
  tipo public.tipo_movimentacao_enum NOT NULL,
  status_anterior text,
  status_novo text,
  registrado_por text,
  registrado_por_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  metodo_scan public.metodo_scan_enum,
  timestamp timestamptz NOT NULL DEFAULT now(),
  notas text
);

COMMENT ON TABLE public.movimentacoes IS
  'Trilha append-only de movimento físico de unidade. Update e delete só admin.';

COMMENT ON COLUMN public.movimentacoes.registrado_por IS
  'Label de exibição do autor, congelado no registro.';

COMMENT ON COLUMN public.movimentacoes.registrado_por_id IS
  'Autor real do registro. FK para profiles; as RPCs da fase 2 derivam de auth.uid() quando há sessão.';


-- ----------------------------------------------------------------------------
-- 4.10 checkout_overrides (exceção auditada no gate de saída)
-- ----------------------------------------------------------------------------

CREATE TABLE public.checkout_overrides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE CASCADE,
  motivo text NOT NULL CHECK (char_length(btrim(motivo)) >= 10),
  blockers jsonb NOT NULL DEFAULT '[]'::jsonb,
  warnings jsonb NOT NULL DEFAULT '[]'::jsonb,
  checks jsonb NOT NULL DEFAULT '[]'::jsonb,
  readiness_pct integer NOT NULL DEFAULT 0 CHECK (readiness_pct BETWEEN 0 AND 100),
  registrado_por text NOT NULL,
  registrado_por_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  executado_em timestamptz,
  CONSTRAINT checkout_overrides_blockers_array CHECK (jsonb_typeof(blockers) = 'array'),
  CONSTRAINT checkout_overrides_warnings_array CHECK (jsonb_typeof(warnings) = 'array'),
  CONSTRAINT checkout_overrides_checks_array CHECK (jsonb_typeof(checks) = 'array')
);

COMMENT ON TABLE public.checkout_overrides IS
  'Registro append-only de saída forçada com motivo e snapshot do gate. Insert só admin, sem DELETE para ninguém.';

CREATE INDEX idx_checkout_overrides_projeto_created
  ON public.checkout_overrides(projeto_id, created_at DESC);


-- ----------------------------------------------------------------------------
-- 4.11 retorno_pendencias (unidade que não voltou)
-- ----------------------------------------------------------------------------

CREATE TABLE public.retorno_pendencias (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE CASCADE,
  serial_number_id uuid NOT NULL REFERENCES public.serial_numbers(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'ABERTA',
  observacao text,
  resolucao_observacao text,
  registrado_por text NOT NULL,
  registrado_por_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolvido_por text,
  resolvido_por_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  CONSTRAINT retorno_pendencias_status_check
    CHECK (status IN ('ABERTA', 'ENCONTRADA', 'MANUTENCAO', 'BAIXA', 'COBRANCA')),
  CONSTRAINT retorno_pendencias_resolution_consistency
    CHECK (
      (status = 'ABERTA' AND resolved_at IS NULL)
      OR (status <> 'ABERTA' AND resolved_at IS NOT NULL)
    ),
  CONSTRAINT retorno_pendencias_unique_serial_evento
    UNIQUE (projeto_id, serial_number_id)
);

COMMENT ON TABLE public.retorno_pendencias IS
  'Pendências abertas quando uma unidade própria não volta na conferência de retorno. Append-only: sem DELETE para ninguém.';

CREATE INDEX idx_retorno_pendencias_projeto_status
  ON public.retorno_pendencias(projeto_id, status, created_at DESC);

CREATE INDEX idx_retorno_pendencias_serial
  ON public.retorno_pendencias(serial_number_id, created_at DESC);


-- ----------------------------------------------------------------------------
-- 4.12 rfid_readers (leitores RFD40 pareados)
-- ----------------------------------------------------------------------------

CREATE TABLE public.rfid_readers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  modelo text NOT NULL DEFAULT 'Zebra RFD40',
  serial_fabrica text UNIQUE,
  operador text,
  status public.status_reader_enum NOT NULL DEFAULT 'ATIVO',
  bateria int CHECK (bateria IS NULL OR (bateria BETWEEN 0 AND 100)),
  ultima_atividade timestamptz,
  notas text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.rfid_readers IS
  'Leitores RFID pareados. updated_at tem trigger (faltava no legado).';


-- ----------------------------------------------------------------------------
-- 4.13 rfid_scans (log bruto de leitura)
-- ----------------------------------------------------------------------------
-- Sem `lote_id`: não existe tabela `lotes` no EventPro. Tag não reconhecida
-- continua sendo gravada com `serial_number_id` nulo, que é o comportamento
-- necessário para onboarding e depuração de etiqueta nova.

CREATE TABLE public.rfid_scans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tag_rfid text NOT NULL,
  serial_number_id uuid REFERENCES public.serial_numbers(id) ON DELETE SET NULL,
  reader_id uuid REFERENCES public.rfid_readers(id) ON DELETE SET NULL,
  projeto_id uuid REFERENCES public.projetos(id) ON DELETE SET NULL,
  operador text,
  contexto public.contexto_scan_enum,
  rssi int,
  localizacao text,
  notas text,
  timestamp timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.rfid_scans IS
  'Log bruto de leitura RFID, incluindo tags não resolvidas. Trilha: update e delete só admin.';


-- ============================================================================
-- 5. ÍNDICES
-- ============================================================================
-- Espelham os do legado, menos os de `lotes`.

CREATE INDEX idx_items_categoria ON public.items(categoria);
CREATE INDEX idx_items_nome ON public.items(nome);
CREATE INDEX idx_items_codigo_interno ON public.items(codigo_interno);

CREATE INDEX idx_serial_numbers_codigo_interno ON public.serial_numbers(codigo_interno);
CREATE INDEX idx_serial_numbers_tag_rfid ON public.serial_numbers(tag_rfid);
CREATE INDEX idx_serial_numbers_qr_code ON public.serial_numbers(qr_code);
CREATE INDEX idx_serial_numbers_status ON public.serial_numbers(status);
CREATE INDEX idx_serial_numbers_item_id ON public.serial_numbers(item_id);

CREATE INDEX idx_projetos_status ON public.projetos(status);
CREATE INDEX idx_projetos_codigo_evento ON public.projetos(codigo_evento);
CREATE INDEX idx_projetos_ficha_evento_gin ON public.projetos USING gin (ficha_evento);
CREATE INDEX idx_projetos_comercial_gin ON public.projetos USING gin (comercial);

-- Índice de `projeto_id` que faltava no legado na tabela mais consultada do app.
CREATE INDEX idx_packing_list_projeto ON public.packing_list(projeto_id);
CREATE INDEX idx_packing_list_item ON public.packing_list(item_id);

CREATE INDEX idx_packing_templates_nome ON public.packing_templates(nome);
CREATE INDEX idx_packing_templates_origem_projeto ON public.packing_templates(origem_projeto_id);
CREATE INDEX idx_packing_templates_linhas_gin ON public.packing_templates USING gin (linhas);

CREATE INDEX idx_movimentacoes_projeto_timestamp
  ON public.movimentacoes(projeto_id, timestamp DESC);
CREATE INDEX idx_movimentacoes_serial_timestamp
  ON public.movimentacoes(serial_number_id, timestamp DESC);
CREATE INDEX idx_movimentacoes_registrado_por_id
  ON public.movimentacoes(registrado_por_id);

-- Os 7 índices de rfid_scans. O do legado em `lote_id` não tem contraparte
-- aqui (sem tabela lotes); no lugar entra `contexto`, que é o filtro que a
-- conferência RFID da fase 2 usa para separar telemetria de operação.
CREATE INDEX idx_rfid_scans_timestamp ON public.rfid_scans(timestamp DESC);
CREATE INDEX idx_rfid_scans_tag ON public.rfid_scans(tag_rfid);
CREATE INDEX idx_rfid_scans_reader ON public.rfid_scans(reader_id);
CREATE INDEX idx_rfid_scans_serial ON public.rfid_scans(serial_number_id);
CREATE INDEX idx_rfid_scans_projeto ON public.rfid_scans(projeto_id);
CREATE INDEX idx_rfid_scans_operador ON public.rfid_scans(operador);
CREATE INDEX idx_rfid_scans_contexto ON public.rfid_scans(contexto);


-- ============================================================================
-- 6. TRIGGERS DE updated_at
-- ============================================================================
-- Toda tabela com a coluna, inclusive rfid_readers (esquecido no legado).

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_app_config_updated_at
  BEFORE UPDATE ON public.app_config
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_items_updated_at
  BEFORE UPDATE ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_serial_numbers_updated_at
  BEFORE UPDATE ON public.serial_numbers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_projetos_updated_at
  BEFORE UPDATE ON public.projetos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_packing_list_updated_at
  BEFORE UPDATE ON public.packing_list
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_packing_templates_updated_at
  BEFORE UPDATE ON public.packing_templates
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_rfid_readers_updated_at
  BEFORE UPDATE ON public.rfid_readers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 7. CÓDIGO INTERNO DE ITEM
-- ============================================================================

CREATE OR REPLACE FUNCTION public.item_categoria_prefix(cat public.categoria_enum)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
BEGIN
  RETURN CASE cat
    WHEN 'ILUMINACAO' THEN 'ILU'
    WHEN 'AUDIO'      THEN 'AUD'
    WHEN 'CABO'       THEN 'CAB'
    WHEN 'ENERGIA'    THEN 'ENE'
    WHEN 'ESTRUTURA'  THEN 'EST'
    WHEN 'EFEITO'     THEN 'EFE'
    WHEN 'VIDEO'      THEN 'VID'
    WHEN 'ACESSORIO'  THEN 'ACE'
  END;
END;
$$;

COMMENT ON FUNCTION public.item_categoria_prefix(public.categoria_enum) IS
  'Sigla de 3 letras por categoria, usada no código interno.';

-- Prefixo lido de app_config em vez de hardcoded `MMD-` como no legado
-- (auditoria §1.4). O advisory lock por categoria continua igual: serializa
-- inserts concorrentes da mesma categoria dentro da transação, sem travar
-- categorias diferentes.
CREATE OR REPLACE FUNCTION public.generate_item_codigo_interno()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_app_prefix text;
  v_cat_prefix  text;
  v_next        int;
BEGIN
  IF NEW.codigo_interno IS NOT NULL AND btrim(NEW.codigo_interno) <> '' THEN
    RETURN NEW;
  END IF;

  SELECT btrim(value) INTO v_app_prefix
  FROM public.app_config
  WHERE key = 'codigo_prefix';

  IF v_app_prefix IS NULL OR v_app_prefix = '' THEN
    RAISE EXCEPTION 'app_config.codigo_prefix ausente ou vazio: não é possível gerar código interno';
  END IF;

  v_cat_prefix := public.item_categoria_prefix(NEW.categoria);

  -- Trava a categoria para evitar race em inserts concorrentes.
  PERFORM pg_advisory_xact_lock(hashtext('item_codigo_' || NEW.categoria::text));

  SELECT COALESCE(MAX(CAST(SUBSTRING(codigo_interno FROM '(\d+)$') AS integer)), 0) + 1
  INTO v_next
  FROM public.items
  WHERE categoria = NEW.categoria
    AND codigo_interno LIKE v_app_prefix || '-' || v_cat_prefix || '-%';

  NEW.codigo_interno := v_app_prefix || '-' || v_cat_prefix || '-' || LPAD(v_next::text, 4, '0');
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.generate_item_codigo_interno() IS
  'Gera codigo_interno {prefix}-{CAT}-{NNNN} lendo o prefixo de app_config, com advisory lock por categoria.';

CREATE TRIGGER trg_items_codigo_interno
  BEFORE INSERT ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.generate_item_codigo_interno();


-- ============================================================================
-- 8. MÁQUINA DE ESTADOS DO EVENTO
-- ============================================================================
-- Matriz completa, já com MONTAGEM e com ELSE fail-closed. É a versão corrigida
-- de 20260805194500 do legado, aplicada de origem.
--
--   PLANEJAMENTO -> CONFIRMADO, CANCELADO
--   CONFIRMADO   -> MONTAGEM, EM_CAMPO (via checkout_projeto), PLANEJAMENTO, CANCELADO
--   MONTAGEM     -> EM_CAMPO (via checkout_projeto), CONFIRMADO, CANCELADO
--   EM_CAMPO     -> FINALIZADO (via checkin_projeto)
--   FINALIZADO   -> terminal
--   CANCELADO    -> terminal
--
-- O ELSE existe porque CASE de PL/pgSQL sem ramo correspondente levanta
-- CASE_NOT_FOUND, que foi exatamente o modo de falha do legado quando MONTAGEM
-- entrou no enum sem entrar na matriz. Se um valor novo aparecer no enum sem
-- ganhar ramo aqui, o erro aponta a causa em vez de um código genérico.
--
-- Consequência assumida: FINALIZADO e CANCELADO são terminais. Reabrir evento
-- finalizado por engano exige intervenção administrativa explícita.

CREATE OR REPLACE FUNCTION public.enforce_projeto_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  CASE OLD.status
    WHEN 'PLANEJAMENTO' THEN
      IF NEW.status NOT IN ('CONFIRMADO', 'CANCELADO') THEN
        RAISE EXCEPTION 'Transição inválida: % -> %', OLD.status, NEW.status;
      END IF;
    WHEN 'CONFIRMADO' THEN
      IF NEW.status NOT IN ('MONTAGEM', 'EM_CAMPO', 'PLANEJAMENTO', 'CANCELADO') THEN
        RAISE EXCEPTION 'Transição inválida: % -> %', OLD.status, NEW.status;
      END IF;
    WHEN 'MONTAGEM' THEN
      IF NEW.status NOT IN ('EM_CAMPO', 'CONFIRMADO', 'CANCELADO') THEN
        RAISE EXCEPTION 'Transição inválida: % -> %', OLD.status, NEW.status;
      END IF;
    WHEN 'EM_CAMPO' THEN
      IF NEW.status <> 'FINALIZADO' THEN
        RAISE EXCEPTION 'EM_CAMPO só transita para FINALIZADO via check-in';
      END IF;
    WHEN 'FINALIZADO' THEN
      RAISE EXCEPTION 'FINALIZADO é terminal, não aceita transição';
    WHEN 'CANCELADO' THEN
      RAISE EXCEPTION 'CANCELADO é terminal, não aceita transição';
    ELSE
      RAISE EXCEPTION 'Status % sem ramo na matriz de transição: atualize enforce_projeto_status_transition', OLD.status;
  END CASE;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.enforce_projeto_status_transition() IS
  'Máquina de estados do Evento no banco. Matriz completa com MONTAGEM e ELSE fail-closed.';

CREATE TRIGGER trg_projeto_status_transition
  BEFORE UPDATE OF status ON public.projetos
  FOR EACH ROW EXECUTE FUNCTION public.enforce_projeto_status_transition();


-- ============================================================================
-- 9. AUTH: criação automática de profile
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, nome)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'nome', NEW.email)
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user() IS
  'Cria o profile correspondente quando auth.users recebe signup. Role inicial é viewer.';

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM anon;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM authenticated;

DROP TRIGGER IF EXISTS trg_auth_user_created ON auth.users;
CREATE TRIGGER trg_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================================
-- 10. HELPER DE AUTORIZAÇÃO
-- ============================================================================
-- SECURITY DEFINER para ler profiles sem recursão de RLS, search_path travado,
-- e em schema privado para não virar RPC na Data API.

CREATE OR REPLACE FUNCTION app_private.current_user_role()
RETURNS public.user_role_enum
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.role
  FROM public.profiles p
  WHERE p.id = (SELECT auth.uid());
$$;

COMMENT ON FUNCTION app_private.current_user_role() IS
  'Role do usuário da sessão. Usada por todas as policies. Fora da Data API por estar em app_private.';

REVOKE ALL ON FUNCTION app_private.current_user_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.current_user_role() FROM anon;
GRANT EXECUTE ON FUNCTION app_private.current_user_role() TO authenticated, service_role;


-- ============================================================================
-- 11. RLS
-- ============================================================================
-- Matriz da auditoria §1.3:
--   leitura: authenticated
--   escrita: editor/admin
--   delete: admin
--   movimentacoes e rfid_scans: update/delete só admin (trilha)
--   checkout_overrides e retorno_pendencias: sem DELETE para ninguém (append-only)
--   checkout_overrides: insert só admin

ALTER TABLE public.profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_config            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.items                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.serial_numbers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projetos              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packing_list          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packing_allocations   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packing_templates     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimentacoes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkout_overrides    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.retorno_pendencias    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rfid_readers          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rfid_scans            ENABLE ROW LEVEL SECURITY;


-- ---- profiles ---------------------------------------------------------------
-- Usuário lê a si mesmo; admin lê e escreve todos.

CREATE POLICY profiles_self_read ON public.profiles
  FOR SELECT TO authenticated
  USING (id = (SELECT auth.uid()) OR app_private.current_user_role() = 'admin');

CREATE POLICY profiles_admin_insert ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() = 'admin');

CREATE POLICY profiles_admin_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() = 'admin')
  WITH CHECK (app_private.current_user_role() = 'admin');

CREATE POLICY profiles_admin_delete ON public.profiles
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');


-- ---- app_config -------------------------------------------------------------
-- Leitura para qualquer usuário logado (o app precisa do prefixo para exibir
-- máscaras); escrita só admin, porque mudar o prefixo muda a identidade dos
-- códigos gerados dali em diante.

CREATE POLICY app_config_read ON public.app_config
  FOR SELECT TO authenticated USING (true);

CREATE POLICY app_config_admin_insert ON public.app_config
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() = 'admin');

CREATE POLICY app_config_admin_update ON public.app_config
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() = 'admin')
  WITH CHECK (app_private.current_user_role() = 'admin');

CREATE POLICY app_config_admin_delete ON public.app_config
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');


-- ---- items ------------------------------------------------------------------

CREATE POLICY items_read ON public.items
  FOR SELECT TO authenticated USING (true);

CREATE POLICY items_insert ON public.items
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY items_update ON public.items
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY items_delete ON public.items
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');


-- ---- serial_numbers ---------------------------------------------------------

CREATE POLICY serial_numbers_read ON public.serial_numbers
  FOR SELECT TO authenticated USING (true);

CREATE POLICY serial_numbers_insert ON public.serial_numbers
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY serial_numbers_update ON public.serial_numbers
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY serial_numbers_delete ON public.serial_numbers
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');


-- ---- projetos ---------------------------------------------------------------

CREATE POLICY projetos_read ON public.projetos
  FOR SELECT TO authenticated USING (true);

CREATE POLICY projetos_insert ON public.projetos
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY projetos_update ON public.projetos
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY projetos_delete ON public.projetos
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');


-- ---- packing_list -----------------------------------------------------------
-- Delete fica com editor: remover linha de packing é operação normal de
-- planejamento, não ato administrativo.

CREATE POLICY packing_list_read ON public.packing_list
  FOR SELECT TO authenticated USING (true);

CREATE POLICY packing_list_insert ON public.packing_list
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_list_update ON public.packing_list
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_list_delete ON public.packing_list
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'));


-- ---- packing_allocations ----------------------------------------------------
-- Mesma matriz de packing_list: alocar e desalocar é operação de planejamento.
-- Desalocar é DELETE, então editor precisa de DELETE.

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


-- ---- packing_templates ------------------------------------------------------

CREATE POLICY packing_templates_read ON public.packing_templates
  FOR SELECT TO authenticated USING (true);

CREATE POLICY packing_templates_insert ON public.packing_templates
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_templates_update ON public.packing_templates
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_templates_delete ON public.packing_templates
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');


-- ---- movimentacoes ----------------------------------------------------------
-- Trilha de auditoria: operação insere, só admin corrige ou apaga.

CREATE POLICY movimentacoes_read ON public.movimentacoes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY movimentacoes_insert ON public.movimentacoes
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY movimentacoes_update ON public.movimentacoes
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() = 'admin')
  WITH CHECK (app_private.current_user_role() = 'admin');

CREATE POLICY movimentacoes_delete ON public.movimentacoes
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');


-- ---- checkout_overrides -----------------------------------------------------
-- Append-only: nenhuma policy de DELETE existe, para nenhum role. Insert só
-- admin (autorizar saída forçada é ato administrativo). Update fica sem policy
-- para authenticated de propósito: quem carimba `executado_em` é a RPC de
-- checkout com override, que roda como service_role.

CREATE POLICY checkout_overrides_read ON public.checkout_overrides
  FOR SELECT TO authenticated
  USING (app_private.current_user_role() IN ('viewer', 'editor', 'admin'));

CREATE POLICY checkout_overrides_insert ON public.checkout_overrides
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() = 'admin');


-- ---- retorno_pendencias -----------------------------------------------------
-- Append-only: nenhuma policy de DELETE. Abertura por editor (é consequência
-- da conferência de retorno); resolução só admin.

CREATE POLICY retorno_pendencias_read ON public.retorno_pendencias
  FOR SELECT TO authenticated
  USING (app_private.current_user_role() IN ('viewer', 'editor', 'admin'));

CREATE POLICY retorno_pendencias_insert ON public.retorno_pendencias
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY retorno_pendencias_update ON public.retorno_pendencias
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() = 'admin')
  WITH CHECK (app_private.current_user_role() = 'admin');


-- ---- rfid_readers -----------------------------------------------------------

CREATE POLICY rfid_readers_read ON public.rfid_readers
  FOR SELECT TO authenticated USING (true);

CREATE POLICY rfid_readers_insert ON public.rfid_readers
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY rfid_readers_update ON public.rfid_readers
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY rfid_readers_delete ON public.rfid_readers
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');


-- ---- rfid_scans -------------------------------------------------------------
-- Trilha: operação insere, só admin corrige ou apaga.

CREATE POLICY rfid_scans_read ON public.rfid_scans
  FOR SELECT TO authenticated USING (true);

CREATE POLICY rfid_scans_insert ON public.rfid_scans
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY rfid_scans_update ON public.rfid_scans
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() = 'admin')
  WITH CHECK (app_private.current_user_role() = 'admin');

CREATE POLICY rfid_scans_delete ON public.rfid_scans
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');


-- ============================================================================
-- 12. GRANTS
-- ============================================================================
-- anon não opera nenhuma tabela interna. O QR público é servido por action
-- server-side com presenter seguro, nunca por leitura direta da Data API.

REVOKE ALL PRIVILEGES ON TABLE
  public.profiles,
  public.app_config,
  public.items,
  public.serial_numbers,
  public.projetos,
  public.packing_list,
  public.packing_allocations,
  public.packing_templates,
  public.movimentacoes,
  public.checkout_overrides,
  public.retorno_pendencias,
  public.rfid_readers,
  public.rfid_scans
FROM PUBLIC, anon;

-- Tabelas de operação normal: authenticated recebe as quatro operações e a RLS
-- decide o que passa.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.profiles,
  public.app_config,
  public.items,
  public.serial_numbers,
  public.projetos,
  public.packing_list,
  public.packing_allocations,
  public.packing_templates,
  public.movimentacoes,
  public.rfid_readers,
  public.rfid_scans
TO authenticated;

-- Append-only: o DELETE não é negado só por policy, é negado por grant também.
-- Duas barreiras, porque uma policy removida por engano numa migration futura
-- não deve destravar exclusão de trilha.
GRANT SELECT, INSERT ON TABLE public.checkout_overrides TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.retorno_pendencias TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.profiles,
  public.app_config,
  public.items,
  public.serial_numbers,
  public.projetos,
  public.packing_list,
  public.packing_allocations,
  public.packing_templates,
  public.movimentacoes,
  public.rfid_readers,
  public.rfid_scans
TO service_role;

GRANT SELECT, INSERT, UPDATE ON TABLE public.checkout_overrides TO service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.retorno_pendencias TO service_role;


-- ============================================================================
-- 13. STORAGE
-- ============================================================================
-- Bucket privado de documentos comerciais do Evento (orçamento, contrato,
-- anexos leves). O legado criava o bucket equivalente sem nenhuma policy de
-- storage (auditoria §1.4): o acesso dependia inteiramente de o caminho web
-- usar service role, sem barreira no banco. Aqui as policies são explícitas.
--
-- O bloco é idempotente e checa a existência de storage.buckets/objects antes
-- de tocar em qualquer coisa, como o legado faz, para o schema poder ser
-- aplicado num Postgres sem a extensão de storage do Supabase.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'storage' AND table_name = 'buckets'
  ) THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      'eventpro-comercial',
      'eventpro-comercial',
      false,
      10485760,
      ARRAY[
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'image/png',
        'image/jpeg'
      ]::text[]
    )
    ON CONFLICT (id) DO UPDATE
      SET public = false,
          file_size_limit = EXCLUDED.file_size_limit,
          allowed_mime_types = EXCLUDED.allowed_mime_types;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'storage' AND table_name = 'objects'
  ) THEN
    RETURN;
  END IF;

  EXECUTE 'DROP POLICY IF EXISTS eventpro_comercial_read ON storage.objects';
  EXECUTE 'DROP POLICY IF EXISTS eventpro_comercial_insert ON storage.objects';
  EXECUTE 'DROP POLICY IF EXISTS eventpro_comercial_update ON storage.objects';
  EXECUTE 'DROP POLICY IF EXISTS eventpro_comercial_delete ON storage.objects';

  -- Leitura: qualquer usuário logado com profile. Documento comercial é
  -- informação interna do Evento, não é público.
  EXECUTE $pol$
    CREATE POLICY eventpro_comercial_read ON storage.objects
      FOR SELECT TO authenticated
      USING (
        bucket_id = 'eventpro-comercial'
        AND app_private.current_user_role() IN ('viewer', 'editor', 'admin')
      )
  $pol$;

  EXECUTE $pol$
    CREATE POLICY eventpro_comercial_insert ON storage.objects
      FOR INSERT TO authenticated
      WITH CHECK (
        bucket_id = 'eventpro-comercial'
        AND app_private.current_user_role() IN ('editor', 'admin')
      )
  $pol$;

  EXECUTE $pol$
    CREATE POLICY eventpro_comercial_update ON storage.objects
      FOR UPDATE TO authenticated
      USING (
        bucket_id = 'eventpro-comercial'
        AND app_private.current_user_role() IN ('editor', 'admin')
      )
      WITH CHECK (
        bucket_id = 'eventpro-comercial'
        AND app_private.current_user_role() IN ('editor', 'admin')
      )
  $pol$;

  -- Apagar documento comercial é ato administrativo.
  EXECUTE $pol$
    CREATE POLICY eventpro_comercial_delete ON storage.objects
      FOR DELETE TO authenticated
      USING (
        bucket_id = 'eventpro-comercial'
        AND app_private.current_user_role() = 'admin'
      )
  $pol$;
END $$;
