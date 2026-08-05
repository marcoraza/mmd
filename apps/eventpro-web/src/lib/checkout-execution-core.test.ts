import assert from 'node:assert/strict'
import test from 'node:test'
import {
  buildCheckoutGate,
  type CheckoutGateFicha,
  type CheckoutGateLine,
} from './checkout-gate-core.ts'
import {
  buildCheckoutExecutionPlan,
  simulateAtomicCheckout,
  type CheckoutExecutionLineInput,
} from './checkout-execution-core.ts'

const readyFicha: CheckoutGateFicha = {
  total: 13,
  preenchidos: 13,
  pct: 100,
  missingLabels: [],
  checklistTotal: 2,
  checklistOk: 2,
  checklistPendentes: 0,
}

function gateLine(overrides: Partial<CheckoutGateLine> = {}): CheckoutGateLine {
  const qtdNecessaria = overrides.qtd_necessaria ?? 2
  const qtdAlocada = overrides.qtd_alocada ?? 2
  const qtdAlugadaAvulsa = overrides.qtd_alugada_avulsa ?? 0
  const qtdCoberta = overrides.qtd_coberta ?? Math.min(qtdNecessaria, qtdAlocada + qtdAlugadaAvulsa)
  return {
    id: 'line-1',
    item_nome: 'Moving Beam 7R',
    qtd_necessaria: qtdNecessaria,
    qtd_alocada: qtdAlocada,
    qtd_alugada_avulsa: qtdAlugadaAvulsa,
    qtd_coberta: qtdCoberta,
    qtd_faltante: overrides.qtd_faltante ?? Math.max(0, qtdNecessaria - qtdCoberta),
    status: overrides.status ?? 'ok',
    conflicts_with: overrides.conflicts_with ?? [],
    ...overrides,
  }
}

function packingLine(
  overrides: Partial<CheckoutExecutionLineInput> = {},
): CheckoutExecutionLineInput {
  return {
    id: 'line-1',
    item_nome: 'Moving Beam 7R',
    qtd_necessaria: 2,
    qtd_alocada: 2,
    qtd_alugada_avulsa: 0,
    qtd_coberta: 2,
    qtd_faltante: 0,
    seriais_alocados: [
      { id: 'serial-1', codigo_interno: 'MMD-ILU-0001', status: 'DISPONIVEL' },
      { id: 'serial-2', codigo_interno: 'MMD-ILU-0002', status: 'DISPONIVEL' },
    ],
    alugueis_avulsos: [],
    ...overrides,
  }
}

test('checkout feliz move apenas seriais próprios para EM_CAMPO', () => {
  const gate = buildCheckoutGate({
    status: 'CONFIRMADO',
    ficha: readyFicha,
    packing: [gateLine()],
  })
  const plan = buildCheckoutExecutionPlan({
    gate,
    packing: [packingLine()],
    metodo: 'RFID',
    operador: 'Marcelo',
    now: '2026-06-23T12:00:00.000Z',
  })
  const result = simulateAtomicCheckout(plan)

  assert.equal(plan.canExecuteStrict, true)
  assert.equal(result.ok, true)
  assert.equal(result.transitions.length, 2)
  assert.deepEqual(
    result.transitions.map((transition) => transition.status_novo),
    ['EM_CAMPO', 'EM_CAMPO'],
  )
})

test('checkout bloqueado por readiness incompleta não gera transição', () => {
  const gate = buildCheckoutGate({
    status: 'CONFIRMADO',
    ficha: { ...readyFicha, checklistOk: 1, checklistPendentes: 1 },
    packing: [gateLine()],
  })
  const plan = buildCheckoutExecutionPlan({
    gate,
    packing: [packingLine()],
    metodo: 'MANUAL',
    operador: 'Marcelo',
    now: '2026-06-23T12:00:00.000Z',
  })
  const result = simulateAtomicCheckout(plan)

  assert.equal(plan.canExecuteStrict, false)
  assert.equal(plan.canExecuteWithOverride, true)
  assert.equal(result.ok, false)
  assert.equal(result.transitions.length, 0)
})

test('serial próprio com status inválido bloqueia antes da RPC', () => {
  const gate = buildCheckoutGate({
    status: 'CONFIRMADO',
    ficha: readyFicha,
    packing: [gateLine()],
  })
  const plan = buildCheckoutExecutionPlan({
    gate,
    packing: [
      packingLine({
        seriais_alocados: [
          { id: 'serial-1', codigo_interno: 'MMD-ILU-0001', status: 'DISPONIVEL' },
          { id: 'serial-2', codigo_interno: 'MMD-ILU-0002', status: 'EM_CAMPO' },
        ],
      }),
    ],
    metodo: 'MANUAL',
    operador: 'Marcelo',
    now: '2026-06-23T12:00:00.000Z',
  })
  const result = simulateAtomicCheckout(plan)

  assert.equal(plan.hasInvalidSerialStatus, true)
  assert.match(plan.hardBlockers[0].message, /não estão DISPONIVEL/)
  assert.equal(result.ok, false)
  assert.equal(result.transitions.length, 0)
})

test('auditoria carrega operador, método e timestamp', () => {
  const gate = buildCheckoutGate({
    status: 'CONFIRMADO',
    ficha: readyFicha,
    packing: [gateLine()],
  })
  const plan = buildCheckoutExecutionPlan({
    gate,
    packing: [packingLine()],
    metodo: 'QRCODE',
    operador: 'Admin EventPro',
    now: '2026-06-23T12:00:00.000Z',
  })
  const result = simulateAtomicCheckout(plan)

  assert.equal(result.ok, true)
  assert.equal(result.transitions[0].registrado_por, 'Admin EventPro')
  assert.equal(result.transitions[0].metodo_scan, 'QRCODE')
  assert.equal(result.transitions[0].timestamp, '2026-06-23T12:00:00.000Z')
})

test('falha em um serial invalida o lote inteiro, sem parcial', () => {
  const gate = buildCheckoutGate({
    status: 'CONFIRMADO',
    ficha: readyFicha,
    packing: [gateLine({ qtd_necessaria: 3, qtd_alocada: 3, qtd_coberta: 3 })],
  })
  const plan = buildCheckoutExecutionPlan({
    gate,
    packing: [
      packingLine({
        qtd_necessaria: 3,
        qtd_alocada: 3,
        qtd_coberta: 3,
        seriais_alocados: [
          { id: 'serial-1', codigo_interno: 'MMD-ILU-0001', status: 'DISPONIVEL' },
          { id: 'serial-2', codigo_interno: 'MMD-ILU-0002', status: 'MANUTENCAO' },
          { id: 'serial-3', codigo_interno: 'MMD-ILU-0003', status: 'DISPONIVEL' },
        ],
      }),
    ],
    metodo: 'RFID',
    operador: 'Marcelo',
    now: '2026-06-23T12:00:00.000Z',
  })
  const result = simulateAtomicCheckout(plan)

  assert.equal(result.ok, false)
  assert.equal(result.transitions.length, 0)
})

test('extras e avulsos aparecem no plano antes da confirmação', () => {
  const gate = buildCheckoutGate({
    status: 'CONFIRMADO',
    ficha: readyFicha,
    packing: [
      gateLine({ qtd_necessaria: 2, qtd_alocada: 2, qtd_alugada_avulsa: 1, qtd_coberta: 2 }),
    ],
  })
  const plan = buildCheckoutExecutionPlan({
    gate,
    packing: [
      packingLine({
        qtd_necessaria: 2,
        qtd_alugada_avulsa: 1,
        alugueis_avulsos: [{ id: 'rent-1', fornecedor: 'Parceiro X', quantidade: 1 }],
      }),
    ],
    metodo: 'MANUAL',
    operador: 'Marcelo',
  })

  assert.equal(plan.externalRentalCount, 1)
  assert.equal(plan.extraCount, 1)
  assert.equal(plan.hasExtras, true)
  assert.match(plan.warnings[0].message, /1 unidade acima do necessário/)
})
