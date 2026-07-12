-- MAR-178: templates reutilizáveis e sugestão revisável de packing.

CREATE TABLE IF NOT EXISTS public.packing_templates (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome text NOT NULL,
  descricao text,
  origem_projeto_id uuid REFERENCES public.projetos(id) ON DELETE SET NULL,
  linhas jsonb NOT NULL DEFAULT '[]'::jsonb,
  criado_por uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT packing_templates_nome_not_blank CHECK (length(btrim(nome)) > 0),
  CONSTRAINT packing_templates_linhas_array CHECK (jsonb_typeof(linhas) = 'array')
);

CREATE INDEX IF NOT EXISTS idx_packing_templates_nome
  ON public.packing_templates (nome);

CREATE INDEX IF NOT EXISTS idx_packing_templates_origem_projeto
  ON public.packing_templates (origem_projeto_id);

CREATE INDEX IF NOT EXISTS idx_packing_templates_linhas_gin
  ON public.packing_templates USING gin (linhas);

DROP TRIGGER IF EXISTS trg_packing_templates_updated_at ON public.packing_templates;
CREATE TRIGGER trg_packing_templates_updated_at
BEFORE UPDATE ON public.packing_templates
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.packing_templates ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.packing_templates FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.packing_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.packing_templates TO service_role;

DROP POLICY IF EXISTS packing_templates_authenticated_read ON public.packing_templates;
DROP POLICY IF EXISTS packing_templates_editor_insert ON public.packing_templates;
DROP POLICY IF EXISTS packing_templates_editor_update ON public.packing_templates;
DROP POLICY IF EXISTS packing_templates_admin_delete ON public.packing_templates;

CREATE POLICY packing_templates_authenticated_read ON public.packing_templates
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY packing_templates_editor_insert ON public.packing_templates
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_templates_editor_update ON public.packing_templates
  FOR UPDATE
  TO authenticated
  USING (public.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_templates_admin_delete ON public.packing_templates
  FOR DELETE
  TO authenticated
  USING (public.current_user_role() = 'admin');

COMMENT ON TABLE public.packing_templates IS
  'Templates reutilizáveis de packing. Cada linha referencia item de catálogo e quantidade sugerida.';

COMMENT ON COLUMN public.packing_templates.linhas IS
  'Array JSON com itemId, codigoInterno, nome, categoria, quantidade e observacao.';
