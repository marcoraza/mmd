-- Adiciona codigo_interno em items no formato MMD-{CAT}-{NNNN}
-- Backfill deterministico por categoria + created_at, trigger auto-gera pra novos.

-- 1. Coluna nullable inicial (pra permitir backfill antes do NOT NULL)
ALTER TABLE items ADD COLUMN IF NOT EXISTS codigo_interno text;

-- 2. Funcao auxiliar: prefixo por categoria
CREATE OR REPLACE FUNCTION item_categoria_prefix(cat categoria_enum)
RETURNS text AS $$
BEGIN
  RETURN CASE cat
    WHEN 'ILUMINACAO' THEN 'ILU'
    WHEN 'AUDIO'      THEN 'AUD'
    WHEN 'CABO'       THEN 'CAB'
    WHEN 'ENERGIA'    THEN 'ENE'
    WHEN 'ESTRUTURA' THEN 'EST'
    WHEN 'EFEITO'     THEN 'EFE'
    WHEN 'VIDEO'      THEN 'VID'
    WHEN 'ACESSORIO' THEN 'ACE'
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 3. Backfill: numera sequencial por categoria ordenado por created_at, id (tiebreak)
WITH ranked AS (
  SELECT id,
         categoria,
         ROW_NUMBER() OVER (PARTITION BY categoria ORDER BY created_at, id) AS seq
  FROM items
  WHERE codigo_interno IS NULL
)
UPDATE items i
SET codigo_interno = 'MMD-' || item_categoria_prefix(ranked.categoria) || '-' || LPAD(ranked.seq::text, 4, '0')
FROM ranked
WHERE i.id = ranked.id;

-- 4. NOT NULL + UNIQUE depois do backfill
ALTER TABLE items ALTER COLUMN codigo_interno SET NOT NULL;
ALTER TABLE items ADD CONSTRAINT items_codigo_interno_unique UNIQUE (codigo_interno);

CREATE INDEX IF NOT EXISTS idx_items_codigo_interno ON items(codigo_interno);

-- 5. Trigger: auto-gera codigo_interno em INSERT se nao foi informado
CREATE OR REPLACE FUNCTION generate_item_codigo_interno()
RETURNS TRIGGER AS $$
DECLARE
  v_prefix text;
  v_next   int;
BEGIN
  IF NEW.codigo_interno IS NOT NULL AND NEW.codigo_interno <> '' THEN
    RETURN NEW;
  END IF;

  v_prefix := item_categoria_prefix(NEW.categoria);

  -- Lock a categoria pra evitar race em inserts concorrentes
  -- (advisory lock por hash da categoria)
  PERFORM pg_advisory_xact_lock(hashtext('item_codigo_' || NEW.categoria::text));

  SELECT COALESCE(MAX(CAST(SUBSTRING(codigo_interno FROM '(\d+)$') AS integer)), 0) + 1
  INTO v_next
  FROM items
  WHERE categoria = NEW.categoria
    AND codigo_interno LIKE 'MMD-' || v_prefix || '-%';

  NEW.codigo_interno := 'MMD-' || v_prefix || '-' || LPAD(v_next::text, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_items_codigo_interno ON items;
CREATE TRIGGER trg_items_codigo_interno
BEFORE INSERT ON items
FOR EACH ROW EXECUTE FUNCTION generate_item_codigo_interno();
