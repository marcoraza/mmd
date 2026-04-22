-- Perfis de usuario e RLS por role
-- Tabela profiles liga auth.users a metadados MMD (role, nome)
-- RLS: authenticated le tudo; edicao de qtd/desgaste exige role >= editor

-- 1. Enum de roles
DO $$ BEGIN
  CREATE TYPE user_role_enum AS ENUM ('viewer', 'editor', 'admin');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2. Tabela profiles
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  nome text,
  role user_role_enum NOT NULL DEFAULT 'viewer',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON profiles;
CREATE TRIGGER trg_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3. Auto-cria profile quando auth.users recebe signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, nome)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'nome', NEW.email));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_auth_user_created ON auth.users;
CREATE TRIGGER trg_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 4. RLS em profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profiles_self_read ON profiles;
CREATE POLICY profiles_self_read ON profiles
  FOR SELECT TO authenticated USING (id = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  ));

DROP POLICY IF EXISTS profiles_admin_write ON profiles;
CREATE POLICY profiles_admin_write ON profiles
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- 5. Helper: checa role do usuario atual
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS user_role_enum AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 6. Refinar RLS de items: leitura pra authenticated, escrita so pra editor/admin
DROP POLICY IF EXISTS authenticated_all_items ON items;

CREATE POLICY items_read ON items
  FOR SELECT TO authenticated USING (true);

CREATE POLICY items_write ON items
  FOR UPDATE TO authenticated
  USING (current_user_role() IN ('editor', 'admin'))
  WITH CHECK (current_user_role() IN ('editor', 'admin'));

CREATE POLICY items_insert ON items
  FOR INSERT TO authenticated
  WITH CHECK (current_user_role() IN ('editor', 'admin'));

CREATE POLICY items_delete ON items
  FOR DELETE TO authenticated
  USING (current_user_role() = 'admin');

-- 7. Mesmo padrao pra serial_numbers
DROP POLICY IF EXISTS authenticated_all_serial_numbers ON serial_numbers;

CREATE POLICY serial_numbers_read ON serial_numbers
  FOR SELECT TO authenticated USING (true);

CREATE POLICY serial_numbers_write ON serial_numbers
  FOR UPDATE TO authenticated
  USING (current_user_role() IN ('editor', 'admin'))
  WITH CHECK (current_user_role() IN ('editor', 'admin'));

CREATE POLICY serial_numbers_insert ON serial_numbers
  FOR INSERT TO authenticated
  WITH CHECK (current_user_role() IN ('editor', 'admin'));

CREATE POLICY serial_numbers_delete ON serial_numbers
  FOR DELETE TO authenticated
  USING (current_user_role() = 'admin');
