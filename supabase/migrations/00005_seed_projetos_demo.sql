-- Seed de projetos demo para a aba /projetos
-- 5 projetos com datas relativas a abr/mai 2026, cobrindo os estados ativos e
-- criando um conflito proposital (item compartilhado em janelas sobrepostas).

DELETE FROM packing_list
WHERE projeto_id IN (SELECT id FROM projetos WHERE nome = 'Teste Verificacao Web');
DELETE FROM projetos WHERE nome = 'Teste Verificacao Web';

WITH novos AS (
  INSERT INTO projetos (nome, cliente, data_inicio, data_fim, local, status, notas) VALUES
    ('Casamento Santos & Oliveira', 'Família Santos',   '2026-04-25', '2026-04-27', 'Buffet Villa Lobos',      'CONFIRMADO',    'Cerimônia ao ar livre. Backup de PA necessário.'),
    ('Show Djavan Arena',           'Produtora Opus',   '2026-04-21', '2026-04-24', 'Vibra São Paulo',         'EM_CAMPO',      'Montagem dia 21, show dias 22 e 23.'),
    ('Evento Corporativo Globo',    'Globo Comunicação','2026-04-26', '2026-04-28', 'Centro de Convenções SP', 'CONFIRMADO',    'Apresentação de resultados anuais. 400 convidados.'),
    ('Festa 15 Anos Helena',        'Família Ribeiro',  '2026-05-02', '2026-05-03', 'Salão Royal Pinheiros',   'PLANEJAMENTO',  'Tema anos 80. Pista de LED solicitada.'),
    ('Lançamento Nike Air',         'Nike Brasil',      '2026-05-08', '2026-05-09', 'Allianz Parque',          'PLANEJAMENTO',  'Evento de mídia. Captura ao vivo.')
  RETURNING id, nome
),
links AS (
  SELECT
    (SELECT id FROM novos WHERE nome = 'Casamento Santos & Oliveira') AS projeto_id,
    codigo, qtd FROM (VALUES
      ('MMD-AUD-0001', 1), ('MMD-AUD-0008', 2), ('MMD-ILU-0004', 4)
    ) t(codigo, qtd)
  UNION ALL SELECT
    (SELECT id FROM novos WHERE nome = 'Show Djavan Arena'),
    codigo, qtd FROM (VALUES
      ('MMD-AUD-0007', 2), ('MMD-AUD-0009', 2), ('MMD-AUD-0010', 2)
    ) t(codigo, qtd)
  UNION ALL SELECT
    (SELECT id FROM novos WHERE nome = 'Evento Corporativo Globo'),
    codigo, qtd FROM (VALUES
      ('MMD-AUD-0001', 1), ('MMD-AUD-0003', 1), ('MMD-AUD-0006', 1)
    ) t(codigo, qtd)
  UNION ALL SELECT
    (SELECT id FROM novos WHERE nome = 'Festa 15 Anos Helena'),
    codigo, qtd FROM (VALUES
      ('MMD-ILU-0053', 2), ('MMD-AUD-0011', 1)
    ) t(codigo, qtd)
  UNION ALL SELECT
    (SELECT id FROM novos WHERE nome = 'Lançamento Nike Air'),
    codigo, qtd FROM (VALUES
      ('MMD-AUD-0002', 1), ('MMD-ILU-0183', 2)
    ) t(codigo, qtd)
)
INSERT INTO packing_list (projeto_id, item_id, quantidade)
SELECT l.projeto_id, i.id, l.qtd
FROM links l
JOIN items i ON i.codigo_interno = l.codigo;
