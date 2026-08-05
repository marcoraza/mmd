import assert from 'node:assert/strict'
import test from 'node:test'
import {
  buildReturnConferencePlan,
  normalizeReturnResolution,
  returnDestination,
} from './return-resolution-core.ts'

test('retorno OK volta unidade para disponível e permite finalizar evento', () => {
  const result = buildReturnConferencePlan([
    { serial_id: 'serial-1', desgaste: 4, resultado: 'OK' },
  ])

  assert.equal(result.ok, true)
  if (!result.ok) return
  assert.equal(result.plan.counts.ok, 1)
  assert.equal(result.plan.canFinalizeEvent, true)
  assert.deepEqual(returnDestination(result.plan.items[0].resultado), {
    outcome: 'OK',
    status_novo: 'DISPONIVEL',
    opensPending: false,
  })
})

test('retorno com problema exige observação do evento e manda para manutenção', () => {
  const missingObs = buildReturnConferencePlan([
    { serial_id: 'serial-1', desgaste: 2, resultado: 'PROBLEMA' },
  ])
  const withObs = buildReturnConferencePlan([
    {
      serial_id: 'serial-1',
      desgaste: 2,
      resultado: 'PROBLEMA',
      observacao: 'Lente com risco profundo.',
    },
  ])

  assert.equal(missingObs.ok, false)
  if (missingObs.ok) return
  assert.match(missingObs.error, /observação/)
  assert.equal(withObs.ok, true)
  if (!withObs.ok) return
  assert.equal(withObs.plan.counts.problema, 1)
  assert.deepEqual(returnDestination(withObs.plan.items[0].resultado), {
    outcome: 'PROBLEMA',
    status_novo: 'MANUTENCAO',
    opensPending: false,
  })
})

test('não voltou abre pendência e não dá baixa automática', () => {
  const result = buildReturnConferencePlan([
    { serial_id: 'serial-1', desgaste: 3, resultado: 'NAO_VOLTOU' },
  ])

  assert.equal(result.ok, true)
  if (!result.ok) return
  assert.equal(result.plan.hasPending, true)
  assert.equal(result.plan.canFinalizeEvent, false)
  assert.deepEqual(returnDestination(result.plan.items[0].resultado), {
    outcome: 'NAO_VOLTOU',
    status_novo: 'RETORNANDO',
    opensPending: true,
  })
})

test('resolução posterior cobre encontrada, manutenção, baixa e cobrança textual', () => {
  const found = normalizeReturnResolution('ENCONTRADA', null)
  const maintenance = normalizeReturnResolution('MANUTENCAO', 'Voltou depois com trinca.')
  const writeOff = normalizeReturnResolution('BAIXA', null)
  const charge = normalizeReturnResolution('COBRANCA', 'Cobrar reposição no fechamento.')

  assert.equal(found.ok, true)
  assert.equal(maintenance.ok, true)
  assert.equal(writeOff.ok, true)
  assert.equal(charge.ok, true)
  if (!found.ok || !maintenance.ok || !writeOff.ok || !charge.ok) return

  assert.equal(found.resolution.status_novo, 'DISPONIVEL')
  assert.equal(maintenance.resolution.status_novo, 'MANUTENCAO')
  assert.equal(writeOff.resolution.status_novo, 'BAIXA')
  assert.equal(charge.resolution.status_novo, 'UNCHANGED')
})

test('cobrança textual exige observação', () => {
  const result = normalizeReturnResolution('COBRANCA', '')

  assert.equal(result.ok, false)
  if (result.ok) return
  assert.match(result.error, /observação/)
})
