import assert from 'node:assert/strict'
import test from 'node:test'

import {
  buildQrSheetItems,
  chunk,
  paginateQrItems,
  parseQrSheetRequest,
  publicQrPayload,
  qrSheetFileName,
} from './qr-sheet-core.ts'

test('parseQrSheetRequest exige serial_ids e devolve no_items quando falta', () => {
  assert.deepEqual(parseQrSheetRequest({ layout: 'small' }), { ok: false, error: 'no_items' })
  assert.deepEqual(parseQrSheetRequest({ serial_ids: [], layout: 'small' }), {
    ok: false,
    error: 'no_items',
  })
  assert.deepEqual(parseQrSheetRequest(null), { ok: false, error: 'no_items' })
})

test('parseQrSheetRequest valida a chave de layout', () => {
  const ids = ['1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01']
  assert.deepEqual(parseQrSheetRequest({ serial_ids: ids }), {
    ok: false,
    error: 'invalid_layout',
  })
  assert.deepEqual(parseQrSheetRequest({ serial_ids: ids, layout: 'gigante' }), {
    ok: false,
    error: 'invalid_layout',
  })
  for (const layout of ['small', 'medium', 'large']) {
    assert.equal(parseQrSheetRequest({ serial_ids: ids, layout }).ok, true)
  }
})

test('serial_ids são normalizados para minúsculas e deduplicados na ordem', () => {
  const result = parseQrSheetRequest({
    serial_ids: [
      ' 1F2B7C1E-4A63-4F0E-9D70-9C2A1F9F1A01 ',
      '1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01',
      '6f3b9d2a-1c44-4a11-b1b7-9a1b2c3d4e5f',
      42,
    ],
    layout: 'small',
  })

  assert.equal(result.ok, true)
  if (!result.ok) return
  assert.deepEqual(result.request.serialIds, [
    '1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01',
    '6f3b9d2a-1c44-4a11-b1b7-9a1b2c3d4e5f',
  ])
})

test('payload do QR aponta para a ficha pública, com código escapado', () => {
  assert.equal(
    publicQrPayload('https://eventpro.example/', 'MMD-ILU-0001'),
    'https://eventpro.example/s/MMD-ILU-0001',
  )
  assert.equal(
    publicQrPayload('https://eventpro.example', 'MMD ILU 0001'),
    'https://eventpro.example/s/MMD%20ILU%200001',
  )
})

test('itens da folha seguem a ordem pedida e ignoram id inexistente', () => {
  const items = buildQrSheetItems({
    baseUrl: 'https://eventpro.example',
    serialIds: ['serial-b', 'serial-inexistente', 'serial-a'],
    rows: [
      {
        id: 'serial-a',
        codigo_interno: 'MMD-ILU-0001',
        item_nome: 'Moving Head Beam 230',
        item_categoria: 'ILUMINACAO',
      },
      {
        id: 'SERIAL-B',
        codigo_interno: 'MMD-CAB-0044',
        item_nome: null,
        item_categoria: null,
      },
    ],
  })

  assert.equal(items.length, 2)
  assert.equal(items[0].title, 'MMD-CAB-0044')
  assert.equal(items[0].subtitle, undefined)
  assert.equal(items[0].caption, undefined)
  assert.equal(items[1].title, 'MMD-ILU-0001')
  assert.equal(items[1].caption, 'Iluminação')
  assert.equal(items[1].payload, 'https://eventpro.example/s/MMD-ILU-0001')
})

test('chunk divide a geração de QR em blocos e nunca perde item', () => {
  const values = Array.from({ length: 95 }, (_, index) => index)
  const blocks = chunk(values, 40)
  assert.deepEqual(
    blocks.map((block) => block.length),
    [40, 40, 15],
  )
  assert.deepEqual(blocks.flat(), values)
  assert.deepEqual(chunk([], 40), [])
})

test('paginação respeita perSheet do layout', () => {
  const items = Array.from({ length: 31 }, (_, index) => ({
    payload: `p${index}`,
    title: `t${index}`,
  }))
  const qrs = items.map((_, index) => `qr${index}`)
  const pages = paginateQrItems(items, qrs, 30)

  assert.equal(pages.length, 2)
  assert.equal(pages[0].items.length, 30)
  assert.equal(pages[1].items.length, 1)
  assert.equal(pages[1].qrs[0], 'qr30')
})

test('nome do arquivo mantém o formato do contrato', () => {
  assert.equal(qrSheetFileName('small', 1785859200000), 'qr-sheet-small-1785859200000.pdf')
})
