-- RFID infrastructure: readers (Zebra RFD40 pareados) + scans (leituras individuais).
-- Scans são a fonte de verdade do movimento físico. Cada leitura de tag gera uma linha aqui,
-- independente de ter resolvido pra serial ou lote (tags não reconhecidas também entram,
-- pra depuração e onboarding de novas etiquetas).

DO $$ BEGIN
  CREATE TYPE status_reader_enum AS ENUM ('ATIVO', 'INATIVO', 'MANUTENCAO');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE contexto_scan_enum AS ENUM (
    'PACKING',
    'CARREGAMENTO',
    'CHECK_IN_EVENTO',
    'CHECK_OUT_EVENTO',
    'RETORNO',
    'CONFERENCIA',
    'INVENTARIO',
    'OUTRO'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS rfid_readers (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome text NOT NULL,
  modelo text NOT NULL DEFAULT 'Zebra RFD40',
  serial_fabrica text UNIQUE,
  operador text,
  status status_reader_enum NOT NULL DEFAULT 'ATIVO',
  bateria int CHECK (bateria IS NULL OR (bateria BETWEEN 0 AND 100)),
  ultima_atividade timestamptz,
  notas text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS rfid_scans (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  tag_rfid text NOT NULL,
  serial_number_id uuid REFERENCES serial_numbers(id) ON DELETE SET NULL,
  lote_id uuid REFERENCES lotes(id) ON DELETE SET NULL,
  reader_id uuid REFERENCES rfid_readers(id) ON DELETE SET NULL,
  projeto_id uuid REFERENCES projetos(id) ON DELETE SET NULL,
  operador text,
  contexto contexto_scan_enum,
  rssi int,
  localizacao text,
  notas text,
  timestamp timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rfid_scans_timestamp ON rfid_scans(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_rfid_scans_tag ON rfid_scans(tag_rfid);
CREATE INDEX IF NOT EXISTS idx_rfid_scans_reader ON rfid_scans(reader_id);
CREATE INDEX IF NOT EXISTS idx_rfid_scans_serial ON rfid_scans(serial_number_id);
CREATE INDEX IF NOT EXISTS idx_rfid_scans_lote ON rfid_scans(lote_id);
CREATE INDEX IF NOT EXISTS idx_rfid_scans_projeto ON rfid_scans(projeto_id);
CREATE INDEX IF NOT EXISTS idx_rfid_scans_operador ON rfid_scans(operador);

-- RLS: por enquanto abrir leitura geral (auth não entrou no MVP). Service role ignora RLS.
ALTER TABLE rfid_readers ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfid_scans ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY rfid_readers_read_all ON rfid_readers FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY rfid_scans_read_all ON rfid_scans FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Dados demo de leitores e scans ficam em fixtures locais, nao em migration.
