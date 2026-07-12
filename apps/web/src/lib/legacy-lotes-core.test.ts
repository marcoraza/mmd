import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import {
  resolveUnitOnlyRfidLegacy,
  summarizeLegacyLotes,
  toUnitOnlyQrLoteState,
} from './legacy-lotes-core.ts'

test('summarizeLegacyLotes keeps lotes as audit data only', () => {
  const summary = summarizeLegacyLotes([
    { quantidade: 10, item_categoria: 'CABO' },
    { quantidade: 4, item_categoria: 'ENERGIA' },
    { quantidade: 2, item_categoria: 'CABO' },
  ])

  assert.deepEqual(summary, {
    total_lotes: 3,
    cable_lotes: 2,
    non_cable_lotes: 1,
    unidades_totais: 16,
  })
})

test('toUnitOnlyQrLoteState blocks every lote as a future QR target', () => {
  const state = toUnitOnlyQrLoteState([
    { id: 'lote-cabo', item_categoria: 'CABO' },
    { id: 'lote-energia', item_categoria: 'ENERGIA' },
  ])

  assert.deepEqual(state.operational_lotes, [])
  assert.equal(state.legacy_lotes, 2)
  assert.equal(state.legacy_cable_lotes, 1)
})

test('resolveUnitOnlyRfidLegacy recognizes only serial targets', () => {
  const legacyOnly = resolveUnitOnlyRfidLegacy({
    serial_id: null,
    lote_id: 'legacy-lote',
    lote_codigo: 'MMD-CAB-010M',
    notas: 'scan antigo',
  })

  assert.equal(legacyOnly.reconhecido, false)
  assert.equal(legacyOnly.lote_id, null)
  assert.equal(legacyOnly.lote_codigo, null)
  assert.equal(legacyOnly.notas, 'scan antigo / Lote legado: MMD-CAB-010M')

  const serial = resolveUnitOnlyRfidLegacy({
    serial_id: 'serial-1',
    lote_id: 'legacy-lote',
    lote_codigo: 'MMD-CAB-010M',
    notas: null,
  })

  assert.equal(serial.reconhecido, true)
  assert.equal(serial.lote_id, null)
})

test('unit-only UI contract removes lotes from active frontend flows', () => {
  const sideRail = readFileSync(new URL('../components/mmd/SideRail.tsx', import.meta.url), 'utf8')
  const catalogLotesCard = readFileSync(
    new URL('../components/catalog/LotesCard.tsx', import.meta.url),
    'utf8',
  )
  const qrCodesClient = readFileSync(
    new URL('../components/qrcodes/QrCodesClient.tsx', import.meta.url),
    'utf8',
  )
  const loteDetailRoute = readFileSync(
    new URL('../app/lotes/[id]/page.tsx', import.meta.url),
    'utf8',
  )

  assert.equal(sideRail.includes("href: '/lotes'"), false)
  assert.equal(sideRail.includes('href="/lotes"'), false)
  assert.equal(catalogLotesCard.includes('href="/lotes"'), false)
  assert.equal(qrCodesClient.includes('codigo_lote'), false)
  assert.match(loteDetailRoute, /redirect\('\/lotes'\)/)
})
