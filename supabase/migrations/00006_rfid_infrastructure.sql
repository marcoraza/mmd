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

-- Seed: 3 leitores + ~40 scans recentes pra popular a UI.
INSERT INTO rfid_readers (id, nome, modelo, serial_fabrica, operador, status, bateria, ultima_atividade)
VALUES
  ('11111111-1111-1111-1111-111111110001', 'RFD40 Galpão 1', 'Zebra RFD40', 'RFD40-A1B2C3', 'Marcelo Santos', 'ATIVO', 82, now() - interval '12 minutes'),
  ('11111111-1111-1111-1111-111111110002', 'RFD40 Galpão 2', 'Zebra RFD40', 'RFD40-D4E5F6', 'Rafael Lima', 'ATIVO', 54, now() - interval '2 hours'),
  ('11111111-1111-1111-1111-111111110003', 'RFD40 Reserva', 'Zebra RFD40', 'RFD40-G7H8I9', NULL, 'INATIVO', 18, now() - interval '3 days')
ON CONFLICT (id) DO NOTHING;

-- Seed de scans: pega serials/lotes com tag_rfid não nula e cria leituras espalhadas no tempo.
INSERT INTO rfid_scans (tag_rfid, serial_number_id, reader_id, operador, contexto, timestamp, localizacao)
SELECT
  s.tag_rfid,
  s.id,
  CASE WHEN random() < 0.6
    THEN '11111111-1111-1111-1111-111111110001'::uuid
    ELSE '11111111-1111-1111-1111-111111110002'::uuid
  END,
  CASE WHEN random() < 0.6 THEN 'Marcelo Santos' ELSE 'Rafael Lima' END,
  (ARRAY['PACKING', 'CARREGAMENTO', 'RETORNO', 'CONFERENCIA']::contexto_scan_enum[])
    [1 + floor(random() * 4)::int],
  now() - (random() * interval '72 hours'),
  'Galpão ' || (1 + floor(random() * 2)::int)
FROM serial_numbers s
WHERE s.tag_rfid IS NOT NULL
ORDER BY random()
LIMIT 30
ON CONFLICT DO NOTHING;

INSERT INTO rfid_scans (tag_rfid, lote_id, reader_id, operador, contexto, timestamp, localizacao)
SELECT
  l.tag_rfid,
  l.id,
  '11111111-1111-1111-1111-111111110001'::uuid,
  'Marcelo Santos',
  (ARRAY['PACKING', 'CARREGAMENTO', 'CONFERENCIA']::contexto_scan_enum[])
    [1 + floor(random() * 3)::int],
  now() - (random() * interval '48 hours'),
  'Galpão 1'
FROM lotes l
WHERE l.tag_rfid IS NOT NULL
ORDER BY random()
LIMIT 10
ON CONFLICT DO NOTHING;

-- 3 scans com tag órfã (não bate com nada, pra testar fluxo de reconhecimento)
INSERT INTO rfid_scans (tag_rfid, reader_id, operador, contexto, timestamp, localizacao)
VALUES
  ('E2000017220B01041990E8E4', '11111111-1111-1111-1111-111111110001', 'Marcelo Santos', 'CONFERENCIA', now() - interval '25 minutes', 'Galpão 1'),
  ('E2000017220B01041990F123', '11111111-1111-1111-1111-111111110002', 'Rafael Lima', 'INVENTARIO', now() - interval '4 hours', 'Galpão 2'),
  ('E2000017220B01041990ABCD', '11111111-1111-1111-1111-111111110001', 'Marcelo Santos', 'PACKING', now() - interval '1 hour', 'Galpão 1')
ON CONFLICT DO NOTHING;
