-- MAR-175: registro comercial leve no Evento.
-- Guarda status, links e anexos comerciais sem criar módulo financeiro.

ALTER TABLE projetos
  ADD COLUMN IF NOT EXISTS comercial jsonb NOT NULL DEFAULT jsonb_build_object(
    'status', null,
    'documentos', '[]'::jsonb,
    'observacoes', null,
    'atualizado_em', null,
    'permite_operacao_estoque', false,
    'readiness_pct', 0
  );

CREATE INDEX IF NOT EXISTS idx_projetos_comercial_gin
  ON projetos USING gin (comercial);

COMMENT ON COLUMN projetos.comercial IS
  'Registro comercial leve do Evento: orçamento, contrato, links e anexos.';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'storage'
      AND table_name = 'buckets'
  ) THEN
    INSERT INTO storage.buckets (
      id,
      name,
      public,
      file_size_limit,
      allowed_mime_types
    )
    VALUES (
      'mmd-evento-comercial',
      'mmd-evento-comercial',
      false,
      10485760,
      ARRAY[
        'application/pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/msword',
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
