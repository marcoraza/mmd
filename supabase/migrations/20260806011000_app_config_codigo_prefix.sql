-- ============================================================================
-- EventPro delta 2/5: app_config e prefixo de código interno configurável
-- ----------------------------------------------------------------------------
-- Converge para `supabase/reference/0001_initial_schema.sql` §4.2 e §7.
--
-- No legado, `generate_item_codigo_interno()` tem o prefixo `MMD-` hardcoded
-- (auditoria §1.4). Isto cria `app_config` e faz a função ler o prefixo de lá.
--
-- COMPORTAMENTO PRESERVADO: a linha de bootstrap é `codigo_prefix = 'MMD'`,
-- exatamente o valor que estava no código. Nenhum código já emitido muda, e o
-- próximo item gerado continua saindo `MMD-{CAT}-{NNNN}`. As etiquetas físicas
-- já coladas nos equipamentos são o motivo de o prefixo continuar MMD, não uma
-- pendência de renomear.
--
-- A linha em app_config é bootstrap de CONFIGURAÇÃO, não seed de dados: sem
-- ela a geração de código interno não funciona, e a função falha com mensagem
-- explícita em vez de gerar código com prefixo vazio.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Tabela
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.app_config (
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

DROP TRIGGER IF EXISTS trg_app_config_updated_at ON public.app_config;
CREATE TRIGGER trg_app_config_updated_at
  BEFORE UPDATE ON public.app_config
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ----------------------------------------------------------------------------
-- 2. RLS, policies e grants
-- ----------------------------------------------------------------------------
-- Leitura para qualquer usuário logado (o app precisa do prefixo para exibir
-- máscara de código); escrita só admin, porque mudar o prefixo muda a
-- identidade de todo código gerado dali em diante.

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.app_config FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.app_config FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.app_config TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.app_config TO service_role;

DROP POLICY IF EXISTS app_config_read ON public.app_config;
DROP POLICY IF EXISTS app_config_admin_insert ON public.app_config;
DROP POLICY IF EXISTS app_config_admin_update ON public.app_config;
DROP POLICY IF EXISTS app_config_admin_delete ON public.app_config;

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


-- ----------------------------------------------------------------------------
-- 3. generate_item_codigo_interno lendo o prefixo de app_config
-- ----------------------------------------------------------------------------
-- Mesma mecânica do legado (advisory lock por categoria, LIKE do prefixo,
-- LPAD 4 dígitos), trocando o literal 'MMD' pela leitura da config. Ganha
-- `SET search_path = public`, que faltava no legado.
--
-- A função é trigger de INSERT em `items`, executada no contexto do usuário
-- que insere. `app_config` tem RLS com leitura para authenticated e o caminho
-- de escrita do app é service role, então a leitura passa nos dois casos.

CREATE OR REPLACE FUNCTION public.generate_item_codigo_interno()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_app_prefix text;
  v_cat_prefix text;
  v_next       int;
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
