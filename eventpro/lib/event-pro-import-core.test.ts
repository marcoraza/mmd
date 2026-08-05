import assert from 'node:assert/strict'
import test from 'node:test'
import {
  buildEventCode,
  classifyEventProLine,
  deriveImportedEventStatus,
  parseEventDate,
  parseQuantityFromText,
  reviewStatusFromIssues,
  sanitizeImportedEventName,
} from './event-pro-import-core.ts'

test('builds short human event codes from event date and sequence', () => {
  assert.equal(buildEventCode('2026-06-24', 1), 'EVT-260624-01')
  assert.equal(buildEventCode('2026-06-24', 12), 'EVT-260624-12')
})

test('keeps human event name separate from technical file noise', () => {
  assert.equal(
    sanitizeImportedEventName('Orçamento - Casamento Civil Catherine.xlsx'),
    'Casamento Civil Catherine',
  )
  assert.equal(sanitizeImportedEventName('CANCELADO - Door Dash .xlsx'), 'Door Dash')
})

test('derives operational status without mixing review state', () => {
  assert.equal(
    deriveImportedEventStatus({
      fileName: 'CANCELADO - Door Dash.xlsx',
      eventStartDate: '2026-06-16',
    }),
    'CANCELADO',
  )
  assert.equal(
    deriveImportedEventStatus({ fileName: 'Lat Bus Mak.xlsx', eventStartDate: '2026-08-11' }),
    'CONFIRMADO',
  )
  assert.equal(
    deriveImportedEventStatus({ fileName: 'Casamoda.xlsx', eventStartDate: '2025-05-15' }),
    'FINALIZADO',
  )
})

test('parses dates used by Event Pro files and sheet names', () => {
  assert.equal(parseEventDate('2026-06-24'), '2026-06-24')
  assert.equal(parseEventDate('24 Jun'), '2026-06-24')
  assert.equal(parseEventDate('2304'), '2026-04-23')
  assert.equal(parseEventDate('A Definir'), null)
})

test('classifies services apart from equipment candidates', () => {
  assert.equal(classifyEventProLine('Carregadores').kind, 'service')
  assert.equal(classifyEventProLine('Subtotal diario').kind, 'section')

  const line = classifyEventProLine('QSC K12.2')
  assert.equal(line.kind, 'equipment')
  assert.equal(line.categoriaSugerida, 'AUDIO')
})

test('extracts quantity prefix from loose equipment lines', () => {
  assert.deepEqual(parseQuantityFromText('2x Microfones sem fio EW-D'), {
    quantity: 2,
    label: 'Microfones sem fio EW-D',
  })
  assert.deepEqual(parseQuantityFromText('Mesa de som Digital'), {
    quantity: null,
    label: 'Mesa de som Digital',
  })
})

test('review seal goes pending when import creates issues', () => {
  assert.equal(reviewStatusFromIssues(0), 'IMPORTADO_OFICIAL')
  assert.equal(reviewStatusFromIssues(2), 'REVISAO_PENDENTE')
})
