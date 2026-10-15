import test from 'node:test'
import assert from 'node:assert/strict'
import {
  computePackingCoverage,
  normalizeExternalRentalInput,
  parseExternalRentalCoverages,
} from './external-rental-core.ts'

test('normalizes partner rental with minimum operational fields', () => {
  const result = normalizeExternalRentalInput(
    {
      fornecedor: '  LightPro   Eventos  ',
      quantidade: 4,
      observacao: '  Retirar no galpão do parceiro  ',
    },
    { id: 'rent-1', createdAt: '2026-06-23T08:00:00.000Z' },
  )

  assert.equal(result.ok, true)
  if (!result.ok) return
  assert.deepEqual(result.data, {
    id: 'rent-1',
    fornecedor: 'LightPro Eventos',
    quantidade: 4,
    observacao: 'Retirar no galpão do parceiro',
    created_at: '2026-06-23T08:00:00.000Z',
  })
  assert.equal('serial_id' in result.data, false)
  assert.equal('item_id' in result.data, false)
})

test('rejects partner rental without quantity, partner or observation', () => {
  assert.equal(
    normalizeExternalRentalInput(
      { fornecedor: '', quantidade: 2, observacao: 'ok' },
      { id: 'rent-1', createdAt: '2026-06-23T08:00:00.000Z' },
    ).ok,
    false,
  )
  assert.equal(
    normalizeExternalRentalInput(
      { fornecedor: 'Parceiro', quantidade: 0, observacao: 'retirar' },
      { id: 'rent-1', createdAt: '2026-06-23T08:00:00.000Z' },
    ).ok,
    false,
  )
  assert.equal(
    normalizeExternalRentalInput(
      { fornecedor: 'Parceiro', quantidade: 1, observacao: '' },
      { id: 'rent-1', createdAt: '2026-06-23T08:00:00.000Z' },
    ).ok,
    false,
  )
})

test('parses only valid persisted partner rental records', () => {
  const parsed = parseExternalRentalCoverages([
    {
      id: 'rent-1',
      fornecedor: 'LightPro',
      quantidade: 3,
      observacao: 'Mesa de apoio',
      created_at: '2026-06-23T08:00:00.000Z',
    },
    { id: 'bad-1', fornecedor: '', quantidade: 2, observacao: 'sem parceiro' },
    { id: 'bad-2', fornecedor: 'Parceiro', quantidade: 'duas', observacao: 'sem quantidade' },
  ])

  assert.equal(parsed.length, 1)
  assert.equal(parsed[0].fornecedor, 'LightPro')
  assert.equal(parsed[0].quantidade, 3)
})

test('coverage counts own units plus partner rentals for readiness', () => {
  const coverage = computePackingCoverage({
    qtdNecessaria: 6,
    qtdPropria: 2,
    alugueisAvulsos: [
      {
        id: 'rent-1',
        fornecedor: 'LightPro',
        quantidade: 4,
        observacao: 'Retirar 10h',
        created_at: '2026-06-23T08:00:00.000Z',
      },
    ],
  })

  assert.equal(coverage.qtd_propria, 2)
  assert.equal(coverage.qtd_alugada_avulsa, 4)
  assert.equal(coverage.qtd_coberta, 6)
  assert.equal(coverage.qtd_faltante, 0)
  assert.equal(coverage.status, 'ok')
})

test('coverage handles partial and caps over-covered readiness at requested quantity', () => {
  const partial = computePackingCoverage({
    qtdNecessaria: 10,
    qtdPropria: 3,
    alugueisAvulsos: [
      {
        id: 'rent-1',
        fornecedor: 'Parceiro',
        quantidade: 4,
        observacao: 'Retirar 10h',
        created_at: null,
      },
    ],
  })
  assert.equal(partial.qtd_coberta, 7)
  assert.equal(partial.qtd_faltante, 3)
  assert.equal(partial.status, 'partial')

  const over = computePackingCoverage({
    qtdNecessaria: 4,
    qtdPropria: 3,
    alugueisAvulsos: [
      {
        id: 'rent-1',
        fornecedor: 'Parceiro',
        quantidade: 4,
        observacao: 'Reserva extra',
        created_at: null,
      },
    ],
  })
  assert.equal(over.qtd_coberta, 4)
  assert.equal(over.qtd_faltante, 0)
  assert.equal(over.status, 'ok')
})
