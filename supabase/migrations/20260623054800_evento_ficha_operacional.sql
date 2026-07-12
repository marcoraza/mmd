-- Ficha de evento persistida no Evento operacional.
--
-- Mantem a tabela projetos como fonte unica de operacao e adiciona um payload
-- estruturado para campos que nao justificam tabelas proprias no MVP.

ALTER TABLE projetos
  ADD COLUMN IF NOT EXISTS ficha_evento jsonb;

CREATE INDEX IF NOT EXISTS idx_projetos_ficha_evento_gin
  ON projetos USING gin (ficha_evento);

COMMENT ON COLUMN projetos.ficha_evento IS
  'Payload estruturado da ficha do evento: endereco, montagem, desmontagem, responsaveis, checklist e observacoes.';
