import assert from 'node:assert/strict'
import test from 'node:test'
import {
  buildCheckoutGate,
  normalizeCheckoutOverrideReason,
  type CheckoutGateFicha,
  type CheckoutGateLine,
} from './checkout-gate-core.ts'

const readyFicha: CheckoutGateFicha = {
  total: 13,
  preenchidos: 13,
  pct: 100,
  missingLabels: [],
  checklistTotal: 2,
  checklistOk: 2,
  checklistPendentes: 0,
}

function line(overrides: Partial<CheckoutGateLine> = {}): CheckoutGateLine {
  const qtdNecessaria = overrides.qtd_necessaria ?? 6
  const qtdAlocada = overrides.qtd_alocada ?? 6
  const qtdAlugadaAvulsa = overrides.qtd_alugada_avulsa ?? 0
  const qtdCoberta = overrides.qtd_coberta ?? Math.min(qtdNecessaria, qtdAlocada + qtdAlugadaAvulsa)
  return {
    id: 'line-1',
    item_nome: 'Moving Beam 7R 230W',
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

test('evento pronto passa no gate de saída', () => {
  const gate = buildCheckoutGate({
    status: 'CONFIRMADO',
    ficha: readyFicha,
    packing: [line()],
  })

  assert.equal(gate.canCheckout, true)
  assert.equal(gate.canOverride, false)
  assert.equal(gate.blockers.length, 0)
  assert.equal(gate.readinessPct, 100)
})

test('evento em montagem também pode sair quando está pronto', () => {
  const gate = buildCheckoutGate({
    status: 'MONTAGEM',
    ficha: readyFicha,
    packing: [line()],
  })

  assert.equal(gate.canCheckout, true)
  assert.equal(gate.canOverride, false)
  assert.equal(gate.blockers.length, 0)
})

test('unidade própria faltando bloqueia saída', () => {
  const gate = buildCheckoutGate({
    status: 'CONFIRMADO',
    ficha: readyFicha,
    packing: [
      line({
        qtd_alocada: 2,
        qtd_alugada_avulsa: 0,
        qtd_coberta: 2,
        qtd_faltante: 4,
        status: 'partial',
      }),
    ],
  })

  assert.equal(gate.canCheckout, false)
  assert.equal(gate.canOverride, true)
  assert.match(gate.blockers[0].message, /4 unidades sem cobertura/)
})

test('aluguel avulso resolvendo falta libera cobertura', () => {
  const gate = buildCheckoutGate({
    status: 'CONFIRMADO',
    ficha: readyFicha,
    packing: [
      line({
        qtd_alocada: 2,
        qtd_alugada_avulsa: 4,
        qtd_coberta: 6,
        qtd_faltante: 0,
        status: 'ok',
      }),
    ],
  })

  assert.equal(gate.canCheckout, true)
  assert.equal(gate.resumo.qtdPropria, 2)
  assert.equal(gate.resumo.qtdAvulsa, 4)
})

test('conflito pendente bloqueia check-out', () => {
  const gate = buildCheckoutGate({
    status: 'CONFIRMADO',
    ficha: readyFicha,
    packing: [
      line({
        status: 'conflict',
        conflicts_with: [
          {
            projeto_id: 'other',
            projeto_nome: 'Tech SP 2026',
            data_inicio: '2026-06-12',
            data_fim: '2026-06-13',
            status: 'CONFIRMADO',
            qtd_necessaria: 4,
            qtd_alocada: 2,
          },
        ],
      }),
    ],
  })

  assert.equal(gate.canCheckout, false)
  assert.equal(gate.canOverride, true)
  assert.match(gate.blockers[0].message, /1 conflito de data pendente/)
})

test('override admin exige motivo útil para auditoria', () => {
  const shortReason = normalizeCheckoutOverrideReason('ok')
  const goodReason = normalizeCheckoutOverrideReason('Parceiro confirmou retirada às 10h')

  assert.equal(shortReason.ok, false)
  assert.equal(goodReason.ok, true)
  if (goodReason.ok) {
    assert.equal(goodReason.value, 'Parceiro confirmou retirada às 10h')
  }
})
