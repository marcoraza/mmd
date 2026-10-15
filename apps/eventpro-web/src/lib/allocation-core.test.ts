import assert from 'node:assert/strict'
import test from 'node:test'
import {
  allocationRangesOverlap,
  pickAutoAllocationCandidates,
  serialAllocationState,
  sortAllocationCandidates,
  type AllocationCandidateLike,
} from './allocation-core.ts'

function candidate(overrides: Partial<AllocationCandidateLike>): AllocationCandidateLike {
  return {
    id: 'serial-1',
    codigo_interno: 'MMD-ILU-0001',
    status: 'DISPONIVEL',
    desgaste: 4,
    last_moved_at: null,
    conflicts_with: [],
    ...overrides,
  }
}

test('detecta sobreposição de datas do Evento', () => {
  assert.equal(
    allocationRangesOverlap('2026-06-10', '2026-06-12', '2026-06-12', '2026-06-14'),
    true,
  )
  assert.equal(
    allocationRangesOverlap('2026-06-10', '2026-06-12', '2026-06-13', '2026-06-14'),
    false,
  )
})

test('status disponível com conflito alerta, mas segue selecionável', () => {
  const state = serialAllocationState('DISPONIVEL', 1)
  assert.equal(state.selectable, true)
  assert.equal(state.tone, 'conflict')
  assert.match(state.alert ?? '', /Conflito de data/)
})

test('manutenção e campo bloqueiam seleção manual', () => {
  assert.equal(serialAllocationState('MANUTENCAO', 0).selectable, false)
  assert.equal(serialAllocationState('EM_CAMPO', 0).selectable, false)
  assert.equal(serialAllocationState('PACKED', 0).selectable, false)
})

test('autoalocação prioriza disponível sem conflito e depois conflito', () => {
  const picked = pickAutoAllocationCandidates(
    [
      candidate({
        id: 'blocked',
        codigo_interno: 'MMD-ILU-0003',
        status: 'MANUTENCAO',
      }),
      candidate({
        id: 'conflict',
        codigo_interno: 'MMD-ILU-0002',
        conflicts_with: [{ projeto_id: 'other' }],
      }),
      candidate({
        id: 'clean',
        codigo_interno: 'MMD-ILU-0001',
      }),
    ],
    2,
  )

  assert.deepEqual(
    picked.map((serial) => serial.id),
    ['clean', 'conflict'],
  )
})

test('ordenação mantém bloqueadas no fim', () => {
  const sorted = sortAllocationCandidates([
    candidate({ id: 'field', codigo_interno: 'MMD-ILU-0004', status: 'EM_CAMPO' }),
    candidate({ id: 'clean', codigo_interno: 'MMD-ILU-0001' }),
    candidate({
      id: 'conflict',
      codigo_interno: 'MMD-ILU-0002',
      conflicts_with: [{ projeto_id: 'other' }],
    }),
  ])

  assert.deepEqual(
    sorted.map((serial) => serial.id),
    ['clean', 'conflict', 'field'],
  )
})
