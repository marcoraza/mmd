-- Hardening de auth/RLS para a Onda 1 do MAR-171.
--
-- Objetivo:
-- - remover writes anon temporários do MVP anterior;
-- - deixar grants explícitos para Data API;
-- - garantir policies por role em tabelas internas;
-- - impedir chamada direta das RPCs operacionais que recebem registrado_por.

-- Garante RLS em todas as tabelas públicas usadas pelo app.
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.serial_numbers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projetos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packing_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimentacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rfid_readers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rfid_scans ENABLE ROW LEVEL SECURITY;

-- O anon key não deve operar tabelas internas. O QR público do web consulta
-- via server action com service role e presenter seguro.
REVOKE ALL PRIVILEGES ON TABLE
  public.items,
  public.serial_numbers,
  public.projetos,
  public.packing_list,
  public.movimentacoes,
  public.lotes,
  public.profiles,
  public.rfid_readers,
  public.rfid_scans
FROM anon;

-- Grants explícitos para o papel autenticado. RLS decide quais operações passam.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.items,
  public.serial_numbers,
  public.projetos,
  public.packing_list,
  public.movimentacoes,
  public.lotes,
  public.profiles,
  public.rfid_readers,
  public.rfid_scans
TO authenticated;

-- Helper usado em policies. Mantém SECURITY DEFINER só para ler profiles sem
-- recursão de RLS, com search_path travado e execute restrito.
ALTER FUNCTION public.set_updated_at() SET search_path = public;
ALTER FUNCTION public.item_categoria_prefix(public.categoria_enum) SET search_path = public;
ALTER FUNCTION public.generate_item_codigo_interno() SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_user_role()
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

REVOKE ALL ON FUNCTION public.current_user_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_user_role() FROM anon;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated, service_role;

-- Trigger function de signup fica callable apenas pelo mecanismo interno.
ALTER FUNCTION public.handle_new_user() SET search_path = public;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM anon;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM authenticated;

-- Remove policies temporárias e policies amplas.
DROP POLICY IF EXISTS "catalog_update_qtd" ON public.items;
DROP POLICY IF EXISTS "serials_update_desgaste" ON public.serial_numbers;

DROP POLICY IF EXISTS authenticated_all_items ON public.items;
DROP POLICY IF EXISTS items_read ON public.items;
DROP POLICY IF EXISTS items_write ON public.items;
DROP POLICY IF EXISTS items_insert ON public.items;
DROP POLICY IF EXISTS items_delete ON public.items;

DROP POLICY IF EXISTS authenticated_all_serial_numbers ON public.serial_numbers;
DROP POLICY IF EXISTS serial_numbers_read ON public.serial_numbers;
DROP POLICY IF EXISTS serial_numbers_write ON public.serial_numbers;
DROP POLICY IF EXISTS serial_numbers_insert ON public.serial_numbers;
DROP POLICY IF EXISTS serial_numbers_delete ON public.serial_numbers;

DROP POLICY IF EXISTS authenticated_all_projetos ON public.projetos;
DROP POLICY IF EXISTS authenticated_all_packing_list ON public.packing_list;
DROP POLICY IF EXISTS authenticated_all_movimentacoes ON public.movimentacoes;
DROP POLICY IF EXISTS authenticated_all_lotes ON public.lotes;

DROP POLICY IF EXISTS profiles_self_read ON public.profiles;
DROP POLICY IF EXISTS profiles_admin_write ON public.profiles;

DROP POLICY IF EXISTS rfid_readers_read_all ON public.rfid_readers;
DROP POLICY IF EXISTS rfid_scans_read_all ON public.rfid_scans;

-- Profiles: usuário lê a si mesmo, admin lê e escreve todos.
CREATE POLICY profiles_self_read ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    id = (SELECT auth.uid())
    OR public.current_user_role() = 'admin'
  );

CREATE POLICY profiles_admin_insert ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() = 'admin');

CREATE POLICY profiles_admin_update ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (public.current_user_role() = 'admin')
  WITH CHECK (public.current_user_role() = 'admin');

CREATE POLICY profiles_admin_delete ON public.profiles
  FOR DELETE
  TO authenticated
  USING (public.current_user_role() = 'admin');

-- Catálogo e unidades: leitura interna para usuário logado, escrita para equipe
-- operacional, delete só para admin.
CREATE POLICY items_read ON public.items
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY items_insert ON public.items
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY items_update ON public.items
  FOR UPDATE
  TO authenticated
  USING (public.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY items_delete ON public.items
  FOR DELETE
  TO authenticated
  USING (public.current_user_role() = 'admin');

CREATE POLICY serial_numbers_read ON public.serial_numbers
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY serial_numbers_insert ON public.serial_numbers
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY serial_numbers_update ON public.serial_numbers
  FOR UPDATE
  TO authenticated
  USING (public.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY serial_numbers_delete ON public.serial_numbers
  FOR DELETE
  TO authenticated
  USING (public.current_user_role() = 'admin');

-- Eventos e packing: operação normal para equipe operacional, delete de evento
-- só para admin. Packing pode ser ajustado pela equipe operacional.
CREATE POLICY projetos_read ON public.projetos
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY projetos_insert ON public.projetos
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY projetos_update ON public.projetos
  FOR UPDATE
  TO authenticated
  USING (public.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY projetos_delete ON public.projetos
  FOR DELETE
  TO authenticated
  USING (public.current_user_role() = 'admin');

CREATE POLICY packing_list_read ON public.packing_list
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY packing_list_insert ON public.packing_list
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_list_update ON public.packing_list
  FOR UPDATE
  TO authenticated
  USING (public.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY packing_list_delete ON public.packing_list
  FOR DELETE
  TO authenticated
  USING (public.current_user_role() IN ('editor', 'admin'));

-- Movimentações são trilha de auditoria: app pode inserir via operação, mas
-- edição ou exclusão direta ficam restritas ao admin.
CREATE POLICY movimentacoes_read ON public.movimentacoes
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY movimentacoes_insert ON public.movimentacoes
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY movimentacoes_update ON public.movimentacoes
  FOR UPDATE
  TO authenticated
  USING (public.current_user_role() = 'admin')
  WITH CHECK (public.current_user_role() = 'admin');

CREATE POLICY movimentacoes_delete ON public.movimentacoes
  FOR DELETE
  TO authenticated
  USING (public.current_user_role() = 'admin');

-- Lotes ficam legados até MAR-187. Delete físico é admin/HITL.
CREATE POLICY lotes_read ON public.lotes
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY lotes_insert ON public.lotes
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY lotes_update ON public.lotes
  FOR UPDATE
  TO authenticated
  USING (public.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY lotes_delete ON public.lotes
  FOR DELETE
  TO authenticated
  USING (public.current_user_role() = 'admin');

-- RFID: leitura para equipe logada, escrita operacional, edição de histórico
-- de scans só para admin.
CREATE POLICY rfid_readers_read ON public.rfid_readers
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY rfid_readers_insert ON public.rfid_readers
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY rfid_readers_update ON public.rfid_readers
  FOR UPDATE
  TO authenticated
  USING (public.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY rfid_readers_delete ON public.rfid_readers
  FOR DELETE
  TO authenticated
  USING (public.current_user_role() = 'admin');

CREATE POLICY rfid_scans_read ON public.rfid_scans
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY rfid_scans_insert ON public.rfid_scans
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_role() IN ('editor', 'admin'));

CREATE POLICY rfid_scans_update ON public.rfid_scans
  FOR UPDATE
  TO authenticated
  USING (public.current_user_role() = 'admin')
  WITH CHECK (public.current_user_role() = 'admin');

CREATE POLICY rfid_scans_delete ON public.rfid_scans
  FOR DELETE
  TO authenticated
  USING (public.current_user_role() = 'admin');

-- As RPCs operacionais aceitam registrado_por. No web, isso já vem do usuário
-- verificado; bloquear chamada direta por authenticated remove spoofing via Data API.
REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) FROM anon;
REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) TO service_role;

REVOKE ALL ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb) FROM anon;
REVOKE ALL ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.checkin_projeto(uuid, public.metodo_scan_enum, text, jsonb) TO service_role;
