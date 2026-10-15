-- ============================================================================
-- EventPro delta 3/5: colunas de autoria com FK real
-- ----------------------------------------------------------------------------
-- Auditoria §1.3: no legado `registrado_por` é text livre, sem FK para
-- `profiles`. A única barreira contra spoofing é o REVOKE de EXECUTE das RPCs.
-- O EventPro mantém essa barreira e acrescenta a identidade verificável, como
-- em `supabase/reference/0001_initial_schema.sql` §4.9 a §4.11.
--
-- Decisões:
--
--   * as colunas são NULLABLE. Todo o histórico do legado ficou com autor nulo
--     e assim continua: não há como recuperar quem executou uma saída de 2026
--     a partir de um label de texto, e inventar um autor seria pior que
--     assumir "desconhecido". Job de manutenção e script de carga também não
--     têm profile e precisam poder registrar movimento.
--   * FK ON DELETE SET NULL, nunca CASCADE: apagar um perfil não pode apagar
--     trilha de auditoria. O label text continua congelado no registro e é ele
--     que a timeline mostra.
--   * `checkout_overrides` já tinha `profile_id` (criada em 20260623083000,
--     escrita direto pelo web legado). A coluna nova `registrado_por_id` é a
--     que o EventPro usa em todas as tabelas, e nasce com backfill a partir de
--     `profile_id`. As duas convivem enquanto o legado escrever `profile_id`;
--     quando ele sair, `profile_id` é removida.
--
-- Também corrige o trigger de `updated_at` esquecido em `rfid_readers`
-- (reference §6): a coluna existe desde 00006 e nunca foi mantida.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. movimentacoes.registrado_por_id
-- ----------------------------------------------------------------------------

ALTER TABLE public.movimentacoes
  ADD COLUMN IF NOT EXISTS registrado_por_id uuid;

ALTER TABLE public.movimentacoes
  DROP CONSTRAINT IF EXISTS movimentacoes_registrado_por_id_fkey;

ALTER TABLE public.movimentacoes
  ADD CONSTRAINT movimentacoes_registrado_por_id_fkey
  FOREIGN KEY (registrado_por_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.movimentacoes.registrado_por IS
  'Label de exibição do autor, congelado no registro.';

COMMENT ON COLUMN public.movimentacoes.registrado_por_id IS
  'Autor real do registro. FK para profiles; as RPCs derivam de auth.uid() quando há sessão. Nulo no histórico anterior à migração.';


-- ----------------------------------------------------------------------------
-- 2. checkout_overrides.registrado_por_id
-- ----------------------------------------------------------------------------

ALTER TABLE public.checkout_overrides
  ADD COLUMN IF NOT EXISTS registrado_por_id uuid;

ALTER TABLE public.checkout_overrides
  DROP CONSTRAINT IF EXISTS checkout_overrides_registrado_por_id_fkey;

ALTER TABLE public.checkout_overrides
  ADD CONSTRAINT checkout_overrides_registrado_por_id_fkey
  FOREIGN KEY (registrado_por_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Backfill do que o legado já sabia: profile_id é a mesma identidade.
UPDATE public.checkout_overrides
SET registrado_por_id = profile_id
WHERE registrado_por_id IS NULL
  AND profile_id IS NOT NULL;

COMMENT ON COLUMN public.checkout_overrides.registrado_por_id IS
  'Autor do override. FK para profiles. Backfill a partir da coluna legada profile_id, que sai quando o web legado for aposentado.';


-- ----------------------------------------------------------------------------
-- 3. retorno_pendencias.registrado_por_id e resolvido_por_id
-- ----------------------------------------------------------------------------

ALTER TABLE public.retorno_pendencias
  ADD COLUMN IF NOT EXISTS registrado_por_id uuid;

ALTER TABLE public.retorno_pendencias
  ADD COLUMN IF NOT EXISTS resolvido_por_id uuid;

ALTER TABLE public.retorno_pendencias
  DROP CONSTRAINT IF EXISTS retorno_pendencias_registrado_por_id_fkey;

ALTER TABLE public.retorno_pendencias
  ADD CONSTRAINT retorno_pendencias_registrado_por_id_fkey
  FOREIGN KEY (registrado_por_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.retorno_pendencias
  DROP CONSTRAINT IF EXISTS retorno_pendencias_resolvido_por_id_fkey;

ALTER TABLE public.retorno_pendencias
  ADD CONSTRAINT retorno_pendencias_resolvido_por_id_fkey
  FOREIGN KEY (resolvido_por_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.retorno_pendencias.registrado_por_id IS
  'Quem abriu a pendência no check-in. FK para profiles, nula no histórico anterior à migração.';

COMMENT ON COLUMN public.retorno_pendencias.resolvido_por_id IS
  'Quem resolveu a pendência. FK para profiles, nula enquanto a pendência está ABERTA.';


-- ----------------------------------------------------------------------------
-- 4. Trigger de updated_at em rfid_readers
-- ----------------------------------------------------------------------------
-- A coluna existe desde 00006_rfid_infrastructure e nunca teve trigger: o
-- valor ficava congelado no created_at. Nenhum dado histórico é reescrito
-- aqui; a correção vale do próximo UPDATE em diante.

DROP TRIGGER IF EXISTS trg_rfid_readers_updated_at ON public.rfid_readers;
CREATE TRIGGER trg_rfid_readers_updated_at
  BEFORE UPDATE ON public.rfid_readers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
