-- Destino confirmado do Evento (pin operacional).
--
-- Latitude/longitude opcionais para preservar eventos legados sem pin.
-- Par incompleto e faixas geográficas inválidas são rejeitados.
-- A escrita herda projetos_update: authenticated + role editor/admin
-- (USING + WITH CHECK). Leitura herda projetos_read. anon sem acesso extra.

ALTER TABLE public.projetos
  ADD COLUMN IF NOT EXISTS destino_latitude double precision,
  ADD COLUMN IF NOT EXISTS destino_longitude double precision,
  ADD COLUMN IF NOT EXISTS destino_confirmado_em timestamptz;

ALTER TABLE public.projetos
  DROP CONSTRAINT IF EXISTS projetos_destino_par_completo,
  ADD CONSTRAINT projetos_destino_par_completo
  CHECK (
    (
      destino_latitude IS NULL
      AND destino_longitude IS NULL
      AND destino_confirmado_em IS NULL
    )
    OR (
      destino_latitude IS NOT NULL
      AND destino_longitude IS NOT NULL
      AND destino_confirmado_em IS NOT NULL
    )
  );

ALTER TABLE public.projetos
  DROP CONSTRAINT IF EXISTS projetos_destino_latitude_range,
  ADD CONSTRAINT projetos_destino_latitude_range
  CHECK (
    destino_latitude IS NULL
    OR (destino_latitude >= -90 AND destino_latitude <= 90)
  );

ALTER TABLE public.projetos
  DROP CONSTRAINT IF EXISTS projetos_destino_longitude_range,
  ADD CONSTRAINT projetos_destino_longitude_range
  CHECK (
    destino_longitude IS NULL
    OR (destino_longitude >= -180 AND destino_longitude <= 180)
  );

COMMENT ON COLUMN public.projetos.destino_latitude IS
  'Latitude WGS84 do pin de chegada do Evento. Opcional; se preenchida, longitude também deve existir.';

COMMENT ON COLUMN public.projetos.destino_longitude IS
  'Longitude WGS84 do pin de chegada do Evento. Opcional; se preenchida, latitude também deve existir.';

COMMENT ON COLUMN public.projetos.destino_confirmado_em IS
  'Timestamp da última gravação do pin de destino. Null quando o Evento ainda não tem pin.';

-- Garante que o contrato RLS de update continua editor/admin com USING + WITH CHECK.
DO $$
DECLARE
  policy_roles text[];
  policy_cmd text;
  policy_qual text;
  policy_with_check text;
BEGIN
  SELECT roles::text[], cmd, qual, with_check
  INTO policy_roles, policy_cmd, policy_qual, policy_with_check
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'projetos'
    AND policyname = 'projetos_update';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'projetos_update policy missing; destination write would be unguarded';
  END IF;

  IF policy_cmd IS DISTINCT FROM 'UPDATE' THEN
    RAISE EXCEPTION 'projetos_update must be UPDATE, found %', policy_cmd;
  END IF;

  IF policy_qual IS NULL OR policy_with_check IS NULL THEN
    RAISE EXCEPTION 'projetos_update must define both USING and WITH CHECK';
  END IF;

  IF position('editor' in coalesce(policy_qual, '')) = 0
     OR position('admin' in coalesce(policy_qual, '')) = 0 THEN
    RAISE EXCEPTION 'projetos_update USING must restrict to editor/admin';
  END IF;

  IF position('editor' in coalesce(policy_with_check, '')) = 0
     OR position('admin' in coalesce(policy_with_check, '')) = 0 THEN
    RAISE EXCEPTION 'projetos_update WITH CHECK must restrict to editor/admin';
  END IF;
END $$;
