import assert from 'node:assert/strict'
import test from 'node:test'
import {
  TRAINING_EVENT_CODE,
  TRAINING_EVENT_MARKER,
  TRAINING_EVENT_NAME,
  buildTrainingEventPlan,
  trainingEventCode,
  type ExistingTrainingEvent,
  type TrainingSerialCandidate,
} from './training-event-core.ts'

function candidate(
  id: string,
  itemId: string,
  itemName: string,
  overrides: Partial<TrainingSerialCandidate> = {},
): TrainingSerialCandidate {
  return {
    id,
    itemId,
    itemCode: `ITEM-${itemId}`,
    itemName,
    serialCode: `SERIAL-${id}`,
    status: 'DISPONIVEL',
    tagRfid: `TAG-${id}`,
    conflictProjectIds: [],
    ...overrides,
  }
}

const candidates = [
  candidate('3', 'audio', 'Áudio'),
  candidate('2', 'luz', 'Luz'),
  candidate('1', 'luz', 'Luz'),
  candidate('5', 'video', 'Vídeo'),
  candidate('4', 'cabos', 'Cabos'),
  candidate('6', 'energia', 'Energia'),
]

test('monta cenário determinístico com packing inicial incompleto e final completo', () => {
  const plan = buildTrainingEventPlan({ candidates, today: '2026-07-17' })

  assert.equal(plan.ready, true)
  assert.deepEqual(
    plan.selectedSerials.map((serial) => serial.id),
    ['3', '4', '6', '1', '2'],
  )
  assert.equal(plan.event.startDate, '2026-07-27')
  assert.equal(plan.event.endDate, '2026-07-28')
  assert.equal(plan.packing.reduce((total, line) => total + line.quantity, 0), 5)
  assert.equal(plan.packing.reduce((total, line) => total + line.initialSerialIds.length, 0), 4)
  assert.equal(plan.packing.reduce((total, line) => total + line.completeSerialIds.length, 0), 5)
  assert.equal(plan.changes[0]?.target, 'event')
  assert.equal(plan.scenarios.packingCompletionSerialCode, 'SERIAL-2')
})

test('aceita unidade sem tag para vínculo físico e ignora indisponível ou em conflito', () => {
  const plan = buildTrainingEventPlan({
    today: '2026-07-17',
    candidates: [
      ...candidates.slice(0, 4),
      candidate('sem-tag', 'extra', 'Extra', { tagRfid: null }),
      candidate('ocupado', 'extra-2', 'Extra 2', { status: 'EM_CAMPO' }),
      candidate('conflito', 'extra-3', 'Extra 3', { conflictProjectIds: ['evento-cliente'] }),
    ],
  })

  assert.equal(plan.ready, true)
  assert.deepEqual(plan.scenarios.pendingTagSerialCodes, ['SERIAL-sem-tag'])
  assert.equal(plan.scenarios.linkedTagCount, 4)
  assert.ok(plan.changes.length > 0)
})

test('bloqueia base sem nenhuma tag conhecida', () => {
  const plan = buildTrainingEventPlan({
    today: '2026-07-17',
    candidates: candidates.slice(0, 5).map((serial) => ({ ...serial, tagRfid: null })),
  })

  assert.equal(plan.ready, false)
  assert.match(plan.blockers.at(-1) ?? '', /tag conhecida/)
})

test('segunda preparação não propõe alteração quando o estado inicial já confere', () => {
  const first = buildTrainingEventPlan({ candidates, today: '2026-07-17' })
  const existing: ExistingTrainingEvent = {
    id: 'event-id',
    code: TRAINING_EVENT_CODE,
    name: TRAINING_EVENT_NAME,
    status: 'PLANEJAMENTO',
    notes: TRAINING_EVENT_MARKER,
    startDate: first.event.startDate,
    endDate: first.event.endDate,
    packing: first.packing.map((line, index) => ({
      id: `packing-${index}`,
      itemId: line.itemId,
      quantity: line.quantity,
      serialIds: line.initialSerialIds,
    })),
  }

  const second = buildTrainingEventPlan({ candidates, existingEvent: existing, today: '2026-08-01' })
  assert.equal(second.ready, true)
  assert.deepEqual(second.changes, [])
  assert.equal(second.event.startDate, first.event.startDate)
})

test('recusa registro sem marcador ou ciclo já iniciado', () => {
  const existing: ExistingTrainingEvent = {
    id: 'event-id',
    code: TRAINING_EVENT_CODE,
    name: TRAINING_EVENT_NAME,
    status: 'EM_CAMPO',
    notes: null,
    startDate: '2026-07-27',
    endDate: '2026-07-28',
    packing: [],
  }

  const plan = buildTrainingEventPlan({ candidates, existingEvent: existing, today: '2026-07-17' })
  assert.equal(plan.ready, false)
  assert.equal(plan.blockers.length, 2)
  assert.equal(plan.changes.length, 0)
})

test('rejeita data impossível', () => {
  assert.throws(
    () => buildTrainingEventPlan({ candidates, today: '2026-02-31' }),
    /Data inválida/,
  )
})

test('numera execuções sem reabrir Evento finalizado', () => {
  const plan = buildTrainingEventPlan({ candidates, today: '2026-07-17', runNumber: 2 })
  assert.equal(plan.event.code, 'TRN-MARCELO-02')
  assert.equal(plan.event.name, TRAINING_EVENT_NAME)
  assert.equal(trainingEventCode(99), 'TRN-MARCELO-99')
  assert.throws(() => trainingEventCode(0), /inválida/)
})

test('restaura o cenário após um ciclo finalizado criando nova execução sem reabrir histórico', () => {
  const finalizedRun: ExistingTrainingEvent = {
    id: 'run-01',
    code: TRAINING_EVENT_CODE,
    name: TRAINING_EVENT_NAME,
    status: 'FINALIZADO',
    notes: TRAINING_EVENT_MARKER,
    startDate: '2026-07-27',
    endDate: '2026-07-28',
    packing: [],
  }

  const sameRun = buildTrainingEventPlan({
    candidates,
    existingEvent: finalizedRun,
    today: '2026-07-29',
    runNumber: 1,
  })
  const restoredRun = buildTrainingEventPlan({
    candidates,
    today: '2026-07-29',
    runNumber: 2,
  })

  assert.equal(sameRun.ready, false)
  assert.match(sameRun.blockers.at(-1) ?? '', /não altera um ciclo iniciado/)
  assert.equal(restoredRun.ready, true)
  assert.equal(restoredRun.event.code, 'TRN-MARCELO-02')
  assert.equal(restoredRun.event.name, TRAINING_EVENT_NAME)
  assert.equal(restoredRun.packing.reduce((total, line) => total + line.initialSerialIds.length, 0), 4)
  assert.equal(restoredRun.packing.reduce((total, line) => total + line.quantity, 0), 5)
  assert.equal(finalizedRun.status, 'FINALIZADO')
})
