-- Importacao oficial de planilhas Event Pro da MMD.
-- Escopo: Evento, montagem, packing operacional e fila de revisao.
-- Financeiro dos orcamentos fica preservado apenas no arquivo original.

ALTER TYPE public.status_projeto_enum ADD VALUE IF NOT EXISTS 'MONTAGEM' BEFORE 'EM_CAMPO';

ALTER TABLE public.projetos
  ADD COLUMN IF NOT EXISTS codigo_evento text,
  ADD COLUMN IF NOT EXISTS importacao_origem text,
  ADD COLUMN IF NOT EXISTS importacao_status text,
  ADD COLUMN IF NOT EXISTS importacao_file_id uuid;

ALTER TABLE public.projetos
  DROP CONSTRAINT IF EXISTS projetos_codigo_evento_unique,
  ADD CONSTRAINT projetos_codigo_evento_unique UNIQUE (codigo_evento);

ALTER TABLE public.projetos
  DROP CONSTRAINT IF EXISTS projetos_importacao_origem_check,
  ADD CONSTRAINT projetos_importacao_origem_check
    CHECK (importacao_origem IS NULL OR importacao_origem IN ('EVENT_PRO'));

ALTER TABLE public.projetos
  DROP CONSTRAINT IF EXISTS projetos_importacao_status_check,
  ADD CONSTRAINT projetos_importacao_status_check
    CHECK (
      importacao_status IS NULL
      OR importacao_status IN ('IMPORTADO_OFICIAL', 'REVISAO_PENDENTE', 'REVISAO_CONCLUIDA')
    );

CREATE INDEX IF NOT EXISTS idx_projetos_codigo_evento
  ON public.projetos(codigo_evento);

CREATE INDEX IF NOT EXISTS idx_projetos_importacao_status
  ON public.projetos(importacao_status)
  WHERE importacao_status IS NOT NULL;

COMMENT ON COLUMN public.projetos.codigo_evento IS
  'Codigo humano curto do Evento, ex: EVT-260624-01.';

COMMENT ON COLUMN public.projetos.importacao_origem IS
  'Origem oficial da criacao do Evento. EVENT_PRO indica importacao de planilha real MMD.';

COMMENT ON COLUMN public.projetos.importacao_status IS
  'Selo de importacao oficial e revisao: IMPORTADO_OFICIAL, REVISAO_PENDENTE ou REVISAO_CONCLUIDA.';

CREATE TABLE IF NOT EXISTS public.event_import_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  origem text NOT NULL DEFAULT 'EVENT_PRO',
  status text NOT NULL DEFAULT 'IMPORTADO_OFICIAL',
  imported_by text,
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT event_import_batches_origem_check
    CHECK (origem IN ('EVENT_PRO')),
  CONSTRAINT event_import_batches_status_check
    CHECK (status IN ('IMPORTADO_OFICIAL', 'REVISAO_PENDENTE', 'REVISAO_CONCLUIDA'))
);

CREATE TABLE IF NOT EXISTS public.event_import_files (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid NOT NULL REFERENCES public.event_import_batches(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  original_path text,
  source_hash text NOT NULL,
  storage_bucket text,
  storage_path text,
  sheets_count int NOT NULL DEFAULT 0,
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT event_import_files_source_hash_unique UNIQUE (source_hash)
);

CREATE TABLE IF NOT EXISTS public.catalog_item_candidates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  normalized_name text NOT NULL,
  display_name text NOT NULL,
  categoria_sugerida public.categoria_enum,
  status text NOT NULL DEFAULT 'PENDENTE',
  occurrences_count int NOT NULL DEFAULT 1 CHECK (occurrences_count >= 1),
  exemplos jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT catalog_item_candidates_normalized_name_unique UNIQUE (normalized_name),
  CONSTRAINT catalog_item_candidates_status_check
    CHECK (status IN ('PENDENTE', 'APROVADO_ITEM', 'APROVADO_PARCEIRO', 'SERVICO', 'IGNORADO'))
);

CREATE TABLE IF NOT EXISTS public.event_import_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid NOT NULL REFERENCES public.event_import_batches(id) ON DELETE CASCADE,
  file_id uuid REFERENCES public.event_import_files(id) ON DELETE SET NULL,
  projeto_id uuid REFERENCES public.projetos(id) ON DELETE CASCADE,
  candidate_id uuid REFERENCES public.catalog_item_candidates(id) ON DELETE SET NULL,
  issue_type text NOT NULL,
  severity text NOT NULL DEFAULT 'INFO',
  status text NOT NULL DEFAULT 'ABERTA',
  source_sheet text,
  source_row int,
  raw_label text,
  raw_value text,
  normalized_value text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT event_import_issues_type_check
    CHECK (
      issue_type IN (
        'MONTAGEM_PENDENTE',
        'PACKING_AMBIGUO',
        'CATALOGO_CANDIDATO',
        'LINHA_SERVICO_IGNORADA',
        'EVENTO_CANCELADO',
        'DATA_INCONSISTENTE',
        'MULTI_ABA_EVENTO'
      )
    ),
  CONSTRAINT event_import_issues_severity_check
    CHECK (severity IN ('INFO', 'ATENCAO', 'BLOQUEIO')),
  CONSTRAINT event_import_issues_status_check
    CHECK (status IN ('ABERTA', 'RESOLVIDA', 'IGNORADA'))
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'projetos_importacao_file_id_fkey'
  ) THEN
    ALTER TABLE public.projetos
      ADD CONSTRAINT projetos_importacao_file_id_fkey
      FOREIGN KEY (importacao_file_id)
      REFERENCES public.event_import_files(id)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.checkout_projeto(
  p_projeto_id uuid,
  p_metodo public.metodo_scan_enum,
  p_registrado_por text
)
RETURNS TABLE(serial_id uuid, codigo_interno text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_projeto_status public.status_projeto_enum;
  v_serial_ids uuid[];
  v_bad_status_count int;
  v_packing_missing int;
BEGIN
  SELECT status INTO v_projeto_status
  FROM public.projetos
  WHERE id = p_projeto_id
  FOR UPDATE;

  IF v_projeto_status IS NULL THEN
    RAISE EXCEPTION 'Evento % não encontrado', p_projeto_id;
  END IF;

  IF v_projeto_status::text NOT IN ('CONFIRMADO', 'MONTAGEM') THEN
    RAISE EXCEPTION 'Check-out requer Evento CONFIRMADO ou MONTAGEM (atual: %)', v_projeto_status;
  END IF;

  SELECT count(*) INTO v_packing_missing
  FROM public.packing_list pl
  WHERE pl.projeto_id = p_projeto_id
    AND (
      coalesce(array_length(pl.serial_numbers_designados, 1), 0) +
      coalesce(
        (
          SELECT sum(greatest((rental->>'quantidade')::int, 0))
          FROM jsonb_array_elements(coalesce(pl.alugueis_avulsos, '[]'::jsonb)) AS rental
          WHERE rental ? 'quantidade'
            AND (rental->>'quantidade') ~ '^[0-9]+$'
        ),
        0
      )
    ) < pl.quantidade;

  IF v_packing_missing > 0 THEN
    RAISE EXCEPTION 'Packing list incompleto em % linha(s). Aloque seriais próprios ou registre aluguel avulso antes do check-out.', v_packing_missing;
  END IF;

  SELECT coalesce(array_agg(DISTINCT s), ARRAY[]::uuid[]) INTO v_serial_ids
  FROM public.packing_list pl,
       unnest(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[])) AS s
  WHERE pl.projeto_id = p_projeto_id;

  IF coalesce(array_length(v_serial_ids, 1), 0) > 0 THEN
    PERFORM 1 FROM public.serial_numbers
    WHERE id = ANY(v_serial_ids)
    FOR UPDATE;

    SELECT count(*) INTO v_bad_status_count
    FROM public.serial_numbers
    WHERE id = ANY(v_serial_ids)
      AND status <> 'DISPONIVEL';

    IF v_bad_status_count > 0 THEN
      RAISE EXCEPTION '% serial(is) não estão DISPONIVEL. Check-out abortado.', v_bad_status_count;
    END IF;

    INSERT INTO public.movimentacoes (
      serial_number_id, projeto_id, tipo,
      status_anterior, status_novo, registrado_por, metodo_scan
    )
    SELECT id, p_projeto_id, 'SAIDA', 'DISPONIVEL', 'EM_CAMPO', p_registrado_por, p_metodo
    FROM public.serial_numbers
    WHERE id = ANY(v_serial_ids);

    UPDATE public.serial_numbers
    SET status = 'EM_CAMPO'
    WHERE id = ANY(v_serial_ids);
  END IF;

  UPDATE public.projetos
  SET status = 'EM_CAMPO'
  WHERE id = p_projeto_id;

  RETURN QUERY
  SELECT sn.id, sn.codigo_interno
  FROM public.serial_numbers sn
  WHERE sn.id = ANY(v_serial_ids)
  ORDER BY sn.codigo_interno;
END;
$$;

CREATE OR REPLACE FUNCTION public.checkout_projeto_com_override(
  p_projeto_id uuid,
  p_metodo public.metodo_scan_enum,
  p_registrado_por text,
  p_override_id uuid
)
RETURNS TABLE(serial_id uuid, codigo_interno text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_projeto_status public.status_projeto_enum;
  v_serial_ids uuid[];
  v_bad_status_count int;
BEGIN
  SELECT status INTO v_projeto_status
  FROM public.projetos
  WHERE id = p_projeto_id
  FOR UPDATE;

  IF v_projeto_status IS NULL THEN
    RAISE EXCEPTION 'Evento % não encontrado', p_projeto_id;
  END IF;

  IF v_projeto_status::text NOT IN ('CONFIRMADO', 'MONTAGEM') THEN
    RAISE EXCEPTION 'Check-out requer Evento CONFIRMADO ou MONTAGEM (atual: %)', v_projeto_status;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.checkout_overrides co
    WHERE co.id = p_override_id
      AND co.projeto_id = p_projeto_id
  ) THEN
    RAISE EXCEPTION 'Override % não encontrado para o Evento %', p_override_id, p_projeto_id;
  END IF;

  SELECT coalesce(array_agg(DISTINCT s), ARRAY[]::uuid[]) INTO v_serial_ids
  FROM public.packing_list pl,
       unnest(coalesce(pl.serial_numbers_designados, ARRAY[]::uuid[])) AS s
  WHERE pl.projeto_id = p_projeto_id;

  IF coalesce(array_length(v_serial_ids, 1), 0) > 0 THEN
    PERFORM 1 FROM public.serial_numbers
    WHERE id = ANY(v_serial_ids)
    FOR UPDATE;

    SELECT count(*) INTO v_bad_status_count
    FROM public.serial_numbers
    WHERE id = ANY(v_serial_ids)
      AND status <> 'DISPONIVEL';

    IF v_bad_status_count > 0 THEN
      RAISE EXCEPTION '% serial(is) não estão DISPONIVEL. Check-out abortado.', v_bad_status_count;
    END IF;

    INSERT INTO public.movimentacoes (
      serial_number_id, projeto_id, tipo,
      status_anterior, status_novo, registrado_por, metodo_scan, notas
    )
    SELECT
      id,
      p_projeto_id,
      'SAIDA',
      'DISPONIVEL',
      'EM_CAMPO',
      p_registrado_por,
      p_metodo,
      'Saída forçada por override auditado: ' || p_override_id::text
    FROM public.serial_numbers
    WHERE id = ANY(v_serial_ids);

    UPDATE public.serial_numbers
    SET status = 'EM_CAMPO'
    WHERE id = ANY(v_serial_ids);
  END IF;

  UPDATE public.projetos
  SET status = 'EM_CAMPO'
  WHERE id = p_projeto_id;

  UPDATE public.checkout_overrides
  SET executado_em = now()
  WHERE id = p_override_id;

  RETURN QUERY
  SELECT sn.id, sn.codigo_interno
  FROM public.serial_numbers sn
  WHERE sn.id = ANY(v_serial_ids)
  ORDER BY sn.codigo_interno;
END;
$$;

REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) FROM anon;
REVOKE ALL ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.checkout_projeto(uuid, public.metodo_scan_enum, text) TO service_role;

REVOKE ALL ON FUNCTION public.checkout_projeto_com_override(
  uuid,
  public.metodo_scan_enum,
  text,
  uuid
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkout_projeto_com_override(
  uuid,
  public.metodo_scan_enum,
  text,
  uuid
) FROM anon;
REVOKE ALL ON FUNCTION public.checkout_projeto_com_override(
  uuid,
  public.metodo_scan_enum,
  text,
  uuid
) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.checkout_projeto_com_override(
  uuid,
  public.metodo_scan_enum,
  text,
  uuid
) TO service_role;

CREATE INDEX IF NOT EXISTS idx_event_import_files_batch
  ON public.event_import_files(batch_id);

CREATE INDEX IF NOT EXISTS idx_event_import_issues_batch_status
  ON public.event_import_issues(batch_id, status, issue_type);

CREATE INDEX IF NOT EXISTS idx_event_import_issues_projeto_status
  ON public.event_import_issues(projeto_id, status);

CREATE INDEX IF NOT EXISTS idx_event_import_issues_candidate_status
  ON public.event_import_issues(candidate_id, status)
  WHERE candidate_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_event_import_batches_updated_at ON public.event_import_batches;
CREATE TRIGGER trg_event_import_batches_updated_at
BEFORE UPDATE ON public.event_import_batches
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_catalog_item_candidates_updated_at ON public.catalog_item_candidates;
CREATE TRIGGER trg_catalog_item_candidates_updated_at
BEFORE UPDATE ON public.catalog_item_candidates
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_event_import_issues_updated_at ON public.event_import_issues;
CREATE TRIGGER trg_event_import_issues_updated_at
BEFORE UPDATE ON public.event_import_issues
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.event_import_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_import_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_item_candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_import_issues ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.event_import_batches TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.event_import_files TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_item_candidates TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.event_import_issues TO authenticated, service_role;

DROP POLICY IF EXISTS event_import_batches_read ON public.event_import_batches;
DROP POLICY IF EXISTS event_import_batches_insert ON public.event_import_batches;
DROP POLICY IF EXISTS event_import_batches_update ON public.event_import_batches;
DROP POLICY IF EXISTS event_import_batches_delete ON public.event_import_batches;

CREATE POLICY event_import_batches_read ON public.event_import_batches
  FOR SELECT TO authenticated
  USING (app_private.current_user_role() IN ('viewer', 'editor', 'admin'));

CREATE POLICY event_import_batches_insert ON public.event_import_batches
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY event_import_batches_update ON public.event_import_batches
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY event_import_batches_delete ON public.event_import_batches
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS event_import_files_read ON public.event_import_files;
DROP POLICY IF EXISTS event_import_files_insert ON public.event_import_files;
DROP POLICY IF EXISTS event_import_files_update ON public.event_import_files;
DROP POLICY IF EXISTS event_import_files_delete ON public.event_import_files;

CREATE POLICY event_import_files_read ON public.event_import_files
  FOR SELECT TO authenticated
  USING (app_private.current_user_role() IN ('viewer', 'editor', 'admin'));

CREATE POLICY event_import_files_insert ON public.event_import_files
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY event_import_files_update ON public.event_import_files
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY event_import_files_delete ON public.event_import_files
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS catalog_item_candidates_read ON public.catalog_item_candidates;
DROP POLICY IF EXISTS catalog_item_candidates_insert ON public.catalog_item_candidates;
DROP POLICY IF EXISTS catalog_item_candidates_update ON public.catalog_item_candidates;
DROP POLICY IF EXISTS catalog_item_candidates_delete ON public.catalog_item_candidates;

CREATE POLICY catalog_item_candidates_read ON public.catalog_item_candidates
  FOR SELECT TO authenticated
  USING (app_private.current_user_role() IN ('viewer', 'editor', 'admin'));

CREATE POLICY catalog_item_candidates_insert ON public.catalog_item_candidates
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY catalog_item_candidates_update ON public.catalog_item_candidates
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY catalog_item_candidates_delete ON public.catalog_item_candidates
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');

DROP POLICY IF EXISTS event_import_issues_read ON public.event_import_issues;
DROP POLICY IF EXISTS event_import_issues_insert ON public.event_import_issues;
DROP POLICY IF EXISTS event_import_issues_update ON public.event_import_issues;
DROP POLICY IF EXISTS event_import_issues_delete ON public.event_import_issues;

CREATE POLICY event_import_issues_read ON public.event_import_issues
  FOR SELECT TO authenticated
  USING (app_private.current_user_role() IN ('viewer', 'editor', 'admin'));

CREATE POLICY event_import_issues_insert ON public.event_import_issues
  FOR INSERT TO authenticated
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY event_import_issues_update ON public.event_import_issues
  FOR UPDATE TO authenticated
  USING (app_private.current_user_role() IN ('editor', 'admin'))
  WITH CHECK (app_private.current_user_role() IN ('editor', 'admin'));

CREATE POLICY event_import_issues_delete ON public.event_import_issues
  FOR DELETE TO authenticated
  USING (app_private.current_user_role() = 'admin');

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
      'mmd-event-pro-imports',
      'mmd-event-pro-imports',
      false,
      20971520,
      ARRAY[
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      ]::text[]
    )
    ON CONFLICT (id) DO UPDATE
      SET public = false,
          file_size_limit = EXCLUDED.file_size_limit,
          allowed_mime_types = EXCLUDED.allowed_mime_types;
  END IF;
END $$;
