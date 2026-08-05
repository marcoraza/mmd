-- ============================================================================
-- EventPro: harness de validação local
-- ----------------------------------------------------------------------------
-- Objetivo: permitir aplicar `migrations/0001_initial_schema.sql` num Postgres
-- 16 vanilla (sem Supabase), reproduzindo apenas o mínimo de superfície que a
-- migration referencia:
--
--   1. os três roles do Supabase (anon, authenticated, service_role);
--   2. o schema `auth` com `auth.users` e `auth.uid()`;
--   3. o schema `storage` com `storage.buckets` e `storage.objects`.
--
-- Este arquivo NÃO faz parte do schema do produto e nunca deve ser aplicado
-- num projeto Supabase real. Ele existe só para o gate de CI/local rodar
-- `psql -v ON_ERROR_STOP=1 -f local-harness.sql -f 0001_initial_schema.sql`
-- e pegar erro de sintaxe, dependência e ordem antes de tocar num projeto
-- remoto.
--
-- Ordem de execução: harness ANTES da migration.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Roles do Supabase
-- ----------------------------------------------------------------------------
-- No Supabase esses roles já existem. Aqui são criados NOLOGIN: a migration só
-- precisa deles como alvo de GRANT/REVOKE e de policies `TO authenticated`.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
END $$;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Schema auth (stub)
-- ----------------------------------------------------------------------------
-- `auth.users` é referenciada por `profiles.id` (FK) e por
-- `packing_templates.criado_por`, e recebe o trigger `handle_new_user`.
-- Só as colunas que a migration lê estão aqui.

CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text,
  raw_user_meta_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- `auth.uid()` real devolve o `sub` do JWT. No harness, lê a GUC
-- `request.jwt.claim.sub` para permitir simular sessões de role em teste
-- (`SET LOCAL request.jwt.claim.sub = '...'`), com fallback NULL quando não há
-- sessão definida, que é exatamente o comportamento de service role.
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_sub text;
BEGIN
  v_sub := nullif(current_setting('request.jwt.claim.sub', true), '');
  IF v_sub IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN v_sub::uuid;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN NULL;
END;
$$;

GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Schema storage (stub)
-- ----------------------------------------------------------------------------
-- A migration insere o bucket `eventpro-comercial` em `storage.buckets` e cria
-- policies em `storage.objects`. As colunas abaixo são as que as policies e o
-- INSERT do bucket referenciam.

CREATE SCHEMA IF NOT EXISTS storage;

CREATE TABLE IF NOT EXISTS storage.buckets (
  id text PRIMARY KEY,
  name text NOT NULL,
  public boolean NOT NULL DEFAULT false,
  file_size_limit bigint,
  allowed_mime_types text[],
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS storage.objects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id text REFERENCES storage.buckets(id),
  name text,
  owner uuid,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
GRANT SELECT ON storage.buckets TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated, service_role;
