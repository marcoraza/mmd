-- Move o helper de role para schema privado, fora da API REST exposta.
-- O public.current_user_role antigo fica sem execute para nao virar RPC publica.
CREATE SCHEMA IF NOT EXISTS app_private;

REVOKE ALL ON SCHEMA app_private FROM PUBLIC;
REVOKE ALL ON SCHEMA app_private FROM anon;
GRANT USAGE ON SCHEMA app_private TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION app_private.current_user_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.current_user_role() FROM anon;
GRANT EXECUTE ON FUNCTION app_private.current_user_role() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.current_user_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_user_role() FROM anon;
REVOKE ALL ON FUNCTION public.current_user_role() FROM authenticated;
REVOKE ALL ON FUNCTION public.current_user_role() FROM service_role;

DROP POLICY IF EXISTS profiles_self_read ON public.profiles;
DROP POLICY IF EXISTS profiles_admin_insert ON public.profiles;
DROP POLICY IF EXISTS profiles_admin_update ON public.profiles;
DROP POLICY IF EXISTS profiles_admin_delete ON public.profiles;

CREATE POLICY profiles_self_read ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    id = (SELECT auth.uid())
    OR app_private.current_user_role() = 'admin'
  );

CREATE POLICY profiles_admin_insert ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() = 'admin');

CREATE POLICY profiles_admin_update ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (app_private.current_user_role() = 'admin')
  WITH CHECK (app_private.current_user_role() = 'admin');

CREATE POLICY profiles_admin_delete ON public.profiles
  FOR DELETE
  TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS items_insert ON public.items;
DROP POLICY IF EXISTS items_update ON public.items;
DROP POLICY IF EXISTS items_delete ON public.items;

CREATE POLICY items_insert ON public.items
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY items_update ON public.items
  FOR UPDATE
  TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY items_delete ON public.items
  FOR DELETE
  TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS serial_numbers_insert ON public.serial_numbers;
DROP POLICY IF EXISTS serial_numbers_update ON public.serial_numbers;
DROP POLICY IF EXISTS serial_numbers_delete ON public.serial_numbers;

CREATE POLICY serial_numbers_insert ON public.serial_numbers
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY serial_numbers_update ON public.serial_numbers
  FOR UPDATE
  TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY serial_numbers_delete ON public.serial_numbers
  FOR DELETE
  TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS projetos_insert ON public.projetos;
DROP POLICY IF EXISTS projetos_update ON public.projetos;
DROP POLICY IF EXISTS projetos_delete ON public.projetos;

CREATE POLICY projetos_insert ON public.projetos
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY projetos_update ON public.projetos
  FOR UPDATE
  TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY projetos_delete ON public.projetos
  FOR DELETE
  TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS packing_list_insert ON public.packing_list;
DROP POLICY IF EXISTS packing_list_update ON public.packing_list;
DROP POLICY IF EXISTS packing_list_delete ON public.packing_list;

CREATE POLICY packing_list_insert ON public.packing_list
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_list_update ON public.packing_list
  FOR UPDATE
  TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_list_delete ON public.packing_list
  FOR DELETE
  TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'));

DROP POLICY IF EXISTS movimentacoes_insert ON public.movimentacoes;
DROP POLICY IF EXISTS movimentacoes_update ON public.movimentacoes;
DROP POLICY IF EXISTS movimentacoes_delete ON public.movimentacoes;

CREATE POLICY movimentacoes_insert ON public.movimentacoes
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY movimentacoes_update ON public.movimentacoes
  FOR UPDATE
  TO authenticated
  USING (app_private.current_user_role() = 'admin')
  WITH CHECK (app_private.current_user_role() = 'admin');

CREATE POLICY movimentacoes_delete ON public.movimentacoes
  FOR DELETE
  TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS lotes_insert ON public.lotes;
DROP POLICY IF EXISTS lotes_update ON public.lotes;
DROP POLICY IF EXISTS lotes_delete ON public.lotes;

CREATE POLICY lotes_insert ON public.lotes
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY lotes_update ON public.lotes
  FOR UPDATE
  TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY lotes_delete ON public.lotes
  FOR DELETE
  TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS rfid_readers_insert ON public.rfid_readers;
DROP POLICY IF EXISTS rfid_readers_update ON public.rfid_readers;
DROP POLICY IF EXISTS rfid_readers_delete ON public.rfid_readers;

CREATE POLICY rfid_readers_insert ON public.rfid_readers
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY rfid_readers_update ON public.rfid_readers
  FOR UPDATE
  TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY rfid_readers_delete ON public.rfid_readers
  FOR DELETE
  TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS rfid_scans_insert ON public.rfid_scans;
DROP POLICY IF EXISTS rfid_scans_update ON public.rfid_scans;
DROP POLICY IF EXISTS rfid_scans_delete ON public.rfid_scans;

CREATE POLICY rfid_scans_insert ON public.rfid_scans
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY rfid_scans_update ON public.rfid_scans
  FOR UPDATE
  TO authenticated
  USING (app_private.current_user_role() = 'admin')
  WITH CHECK (app_private.current_user_role() = 'admin');

CREATE POLICY rfid_scans_delete ON public.rfid_scans
  FOR DELETE
  TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS packing_templates_editor_insert ON public.packing_templates;
DROP POLICY IF EXISTS packing_templates_editor_update ON public.packing_templates;
DROP POLICY IF EXISTS packing_templates_admin_delete ON public.packing_templates;

CREATE POLICY packing_templates_editor_insert ON public.packing_templates
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_templates_editor_update ON public.packing_templates
  FOR UPDATE
  TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_templates_admin_delete ON public.packing_templates
  FOR DELETE
  TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS checkout_overrides_read ON public.checkout_overrides;
DROP POLICY IF EXISTS checkout_overrides_insert ON public.checkout_overrides;

CREATE POLICY checkout_overrides_read ON public.checkout_overrides
  FOR SELECT
  TO authenticated
  USING (app_private.current_user_role() IN ('viewer', 'editor', 'admin'));

CREATE POLICY checkout_overrides_insert ON public.checkout_overrides
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS retorno_pendencias_read ON public.retorno_pendencias;
DROP POLICY IF EXISTS retorno_pendencias_insert ON public.retorno_pendencias;
DROP POLICY IF EXISTS retorno_pendencias_update ON public.retorno_pendencias;

CREATE POLICY retorno_pendencias_read ON public.retorno_pendencias
  FOR SELECT
  TO authenticated
  USING (app_private.current_user_role() IN ('viewer', 'editor', 'admin'));

CREATE POLICY retorno_pendencias_insert ON public.retorno_pendencias
  FOR INSERT
  TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY retorno_pendencias_update ON public.retorno_pendencias
  FOR UPDATE
  TO authenticated
  USING (app_private.current_user_role() = 'admin')
  WITH CHECK (app_private.current_user_role() = 'admin');
