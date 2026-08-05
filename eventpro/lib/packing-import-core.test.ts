import assert from 'node:assert/strict'
import test from 'node:test'
import {
  buildPackingImportApprovals,
  createPackingImportPreview,
  matchPackingImportRows,
  normalizePackingImportHeader,
  unresolvedPackingImportRows,
  type PackingImportCatalogItem,
  type PackingImportRowInput,
} from './packing-import-core.ts'

const catalog: PackingImportCatalogItem[] = [
  {
    id: 'item-audio-pga52',
    codigo_interno: 'MMD-AUD-0001',
    nome: 'Kit para bateria Shure PGA52 cardioid polar pattern',
    categoria: 'AUDIO',
    subcategoria: 'Microfones',
    marca: 'Shure',
    modelo: 'PGA52',
    quantidade_total: 2,
  },
  {
    id: 'item-par-rgb',
    codigo_interno: 'MMD-ILU-0008',
    nome: 'LED PAR 64 Slim RGB',
    categoria: 'ILUMINACAO',
    subcategoria: 'PAR LED',
    marca: null,
    modelo: 'RGB',
    quantidade_total: 16,
  },
  {
    id: 'item-caixa-prx',
    codigo_interno: 'MMD-AUD-0100',
    nome: 'Caixa JBL PRX ativa',
    categoria: 'AUDIO',
    subcategoria: 'Caixa som',
    marca: 'JBL',
    modelo: 'PRX',
    quantidade_total: 4,
  },
  {
    id: 'item-caixa-eon',
    codigo_interno: 'MMD-AUD-0101',
    nome: 'Caixa JBL EON ativa',
    categoria: 'AUDIO',
    subcategoria: 'Caixa som',
    marca: 'JBL',
    modelo: 'EON',
    quantidade_total: 4,
  },
]

test('matches by codigo_mmd before textual fields', () => {
  const rows = matchPackingImportRows(
    [
      {
        rowNumber: 2,
        codigo_mmd: 'mmd aud 0001',
        categoria: 'ILUMINACAO',
        item: 'texto divergente',
        quantidade: 1,
      },
    ],
    catalog,
  )

  assert.equal(rows[0]?.status, 'matched')
  if (rows[0]?.status !== 'matched') return
  assert.equal(rows[0].matchReason, 'codigo_mmd')
  assert.equal(rows[0].match.id, 'item-audio-pga52')
})

test('matches by textual fallback with category and optional model', () => {
  const rows = matchPackingImportRows(
    [
      {
        rowNumber: 3,
        categoria: 'Iluminação',
        item: 'PAR LED RGB',
        subcategoria: 'Par Led',
        modelo: 'RGB',
        quantidade: '16',
      },
    ],
    catalog,
  )

  assert.equal(rows[0]?.status, 'matched')
  if (rows[0]?.status !== 'matched') return
  assert.equal(rows[0].matchReason, 'texto')
  assert.equal(rows[0].match.id, 'item-par-rgb')
})

test('marks textual fallback as ambiguous when more than one catalog item fits', () => {
  const rows = matchPackingImportRows(
    [{ rowNumber: 4, categoria: 'AUDIO', item: 'Caixa JBL', quantidade: 2 }],
    catalog,
  )

  assert.equal(rows[0]?.status, 'ambiguous')
  if (rows[0]?.status !== 'ambiguous') return
  assert.deepEqual(
    rows[0].candidates.map((candidate) => candidate.id),
    ['item-caixa-prx', 'item-caixa-eon'],
  )
})

test('invalid rows keep row-level errors without silent fallback', () => {
  const rows = matchPackingImportRows(
    [
      {
        rowNumber: 5,
        codigo_mmd: 'MMD-AUD-9999',
        categoria: 'AUDIO',
        item: 'Kit para bateria Shure PGA52',
        quantidade: 1,
      },
      { rowNumber: 6, categoria: 'AUDIO', item: 'Caixa JBL', quantidade: 'zero' },
    ],
    catalog,
  )

  assert.equal(rows[0]?.status, 'invalid')
  assert.match(rows[0]?.errors[0] ?? '', /Código MMD/)
  assert.equal(rows[1]?.status, 'invalid')
  assert.match(rows[1]?.errors[0] ?? '', /Quantidade/)
})

test('builds approvals from matched and resolved ambiguous rows with quantity aggregation', () => {
  const matchedRows = matchPackingImportRows(
    [
      { rowNumber: 2, codigo_mmd: 'MMD-AUD-0001', quantidade: 1, observacao: 'Base' },
      { rowNumber: 3, codigo_mmd: 'MMD-AUD-0001', quantidade: 3, observacao: 'Extra' },
      { rowNumber: 4, categoria: 'AUDIO', item: 'Caixa JBL', quantidade: 2 },
    ],
    catalog,
  )

  assert.equal(unresolvedPackingImportRows(matchedRows).length, 1)

  const approvals = buildPackingImportApprovals(matchedRows, [
    { rowNumber: 4, itemId: 'item-caixa-eon' },
  ])

  assert.equal(approvals.length, 2)
  assert.equal(approvals[0]?.itemId, 'item-audio-pga52')
  assert.equal(approvals[0]?.quantidade, 4)
  assert.equal(approvals[0]?.observacao, 'Base; Extra')
  assert.equal(approvals[1]?.itemId, 'item-caixa-eon')
  assert.equal(approvals[1]?.quantidade, 2)
})

test('creates a preview summary and recognizes standard headers', () => {
  const input: PackingImportRowInput[] = [
    { rowNumber: 2, codigo_mmd: 'MMD-AUD-0001', quantidade: 1 },
    { rowNumber: 3, categoria: 'AUDIO', item: 'Caixa JBL', quantidade: 1 },
    { rowNumber: 4, codigo_mmd: 'MMD-INV-9999', quantidade: 1 },
  ]

  const preview = createPackingImportPreview({
    fileName: 'packing.xlsx',
    rows: input,
    catalog,
  })

  assert.equal(normalizePackingImportHeader('Código MMD'), 'codigo_mmd')
  assert.equal(normalizePackingImportHeader('Observação'), 'observacao')
  assert.deepEqual(preview.summary, {
    total: 3,
    matched: 1,
    ambiguous: 1,
    invalid: 1,
    approvedQuantity: 1,
  })
})
