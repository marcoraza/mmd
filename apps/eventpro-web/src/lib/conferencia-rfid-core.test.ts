import assert from 'node:assert/strict'
import test from 'node:test'

import {
  buildConferenciaResponse,
  parseConferenciaPayload,
  uniqueConferenciaTags,
  type ConferenciaRpcRow,
} from './conferencia-rfid-core.ts'

const EVENTO = {
  id: '3c0d2f11-6b8a-4d55-9a10-0b7e2c4f8d31',
  nome: 'Festival Verão 2026',
  status: 'MONTAGEM' as const,
}

test('normalização de tag é a mesma de /api/rfid/scans e preserva ordem de leitura', () => {
  assert.deepEqual(
    uniqueConferenciaTags([' e280-1170:0000 020d1a2b3c4d ', 'E28011700000020D1A2B3C4E', 42]),
    ['E28011700000020D1A2B3C4D', 'E28011700000020D1A2B3C4E'],
  )
  // Dedupe preservando a primeira ocorrência.
  assert.deepEqual(uniqueConferenciaTags(['AAAABBBB', 'aaaabbbb', 'CCCCDDDD']), [
    'AAAABBBB',
    'CCCCDDDD',
  ])
})

test('payload sem tag válida devolve tags_invalidas', () => {
  assert.deepEqual(parseConferenciaPayload({ contexto: 'CARREGAMENTO' }), {
    ok: false,
    error: 'tags_invalidas',
  })
  assert.deepEqual(parseConferenciaPayload({ tags: [], contexto: 'CARREGAMENTO' }), {
    ok: false,
    error: 'tags_invalidas',
  })
  // Uma tag curta invalida o lote inteiro: não existe aceite parcial.
  assert.deepEqual(
    parseConferenciaPayload({ tags: ['E28011700000020D1A2B3C4D', 'ABC'], contexto: 'RETORNO' }),
    { ok: false, error: 'tags_invalidas' },
  )
})

test('contexto ausente ou fora da lista é contexto_invalido, não default', () => {
  const tags = ['E28011700000020D1A2B3C4D']
  assert.deepEqual(parseConferenciaPayload({ tags }), {
    ok: false,
    error: 'contexto_invalido',
  })
  assert.deepEqual(parseConferenciaPayload({ tags, contexto: 'INVENTARIO' }), {
    ok: false,
    error: 'contexto_invalido',
  })
  assert.deepEqual(parseConferenciaPayload({ tags, contexto: 'carregamento' }), {
    ok: false,
    error: 'contexto_invalido',
  })
  for (const contexto of ['CARREGAMENTO', 'RETORNO', 'CONFERENCIA']) {
    assert.equal(parseConferenciaPayload({ tags, contexto }).ok, true)
  }
})

test('reader segue as mesmas regras de /api/rfid/scans e bateria é limitada', () => {
  const result = parseConferenciaPayload({
    tags: ['E28011700000020D1A2B3C4D'],
    contexto: 'CARREGAMENTO',
    localizacao: '  Galpão 1  ',
    reader: { nome: ' RFD40 ', modelo: '', serial_fabrica: ' RFD4090-ABC123 ', bateria: 187.4 },
  })

  assert.equal(result.ok, true)
  if (!result.ok) return
  assert.equal(result.payload.localizacao, 'Galpão 1')
  assert.deepEqual(result.payload.reader, {
    nome: 'RFD40',
    modelo: undefined,
    serial_fabrica: 'RFD4090-ABC123',
    bateria: 100,
  })
})

test('resposta monta os quatro buckets, o resumo e os scan_ids na ordem de leitura', () => {
  const tags = ['E28011700000020D1A2B3C4D', 'E28011700000020D1A2B3C4E', 'E28011700000020DFFFFFFFF']
  const rows: ConferenciaRpcRow[] = [
    {
      classificacao: 'CONFIRMADO',
      tag_rfid: 'E28011700000020D1A2B3C4D',
      serial_id: 'serial-1',
      codigo_interno: 'MMD-ILU-0001',
      item_nome: 'Moving Head Beam 230',
      scan_id: 'scan-1',
      ordem: 1,
    },
    {
      classificacao: 'EXTRA',
      tag_rfid: 'E28011700000020D1A2B3C4E',
      serial_id: 'serial-3',
      codigo_interno: 'MMD-CAB-0044',
      item_nome: 'Cabo XLR 10m',
      scan_id: 'scan-2',
      ordem: 2,
    },
    {
      classificacao: 'DESCONHECIDA',
      tag_rfid: 'E28011700000020DFFFFFFFF',
      serial_id: null,
      codigo_interno: null,
      item_nome: null,
      scan_id: 'scan-3',
      ordem: 3,
    },
    {
      classificacao: 'FALTANTE',
      tag_rfid: null,
      serial_id: 'serial-2',
      codigo_interno: 'MMD-AUD-0012',
      item_nome: 'Caixa Ativa 15"',
      scan_id: null,
      ordem: null,
    },
  ]

  const response = buildConferenciaResponse({
    evento: EVENTO,
    contexto: 'CARREGAMENTO',
    tags,
    rows,
  })

  assert.equal(response.confirmados.length, 1)
  assert.equal(response.confirmados[0].codigo_interno, 'MMD-ILU-0001')
  assert.equal(response.extras.length, 1)
  assert.equal(response.desconhecidas.length, 1)
  assert.equal(response.faltantes.length, 1)
  // Faltante sem etiqueta vinculada mantém tag_rfid null: é o caso a destacar.
  assert.equal(response.faltantes[0].tag_rfid, null)
  assert.deepEqual(response.scan_ids, ['scan-1', 'scan-2', 'scan-3'])
  assert.deepEqual(response.resumo, {
    esperados: 2,
    confirmados: 1,
    faltantes: 1,
    extras: 1,
    desconhecidas: 1,
    cobertura_pct: 50,
  })

  // Invariantes do contrato §7.4.
  assert.equal(
    response.confirmados.length + response.extras.length + response.desconhecidas.length,
    tags.length,
  )
  assert.equal(response.confirmados.length + response.faltantes.length, response.resumo.esperados)
})

test('evento sem alocação responde com esperados 0 e cobertura 0, não erro', () => {
  const response = buildConferenciaResponse({
    evento: EVENTO,
    contexto: 'CONFERENCIA',
    tags: ['E28011700000020DFFFFFFFF'],
    rows: [
      {
        classificacao: 'DESCONHECIDA',
        tag_rfid: 'E28011700000020DFFFFFFFF',
        serial_id: null,
        codigo_interno: null,
        item_nome: null,
        scan_id: 'scan-1',
        ordem: 1,
      },
    ],
  })

  assert.equal(response.resumo.esperados, 0)
  assert.equal(response.resumo.cobertura_pct, 0)
  assert.deepEqual(response.faltantes, [])
})
