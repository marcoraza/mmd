import assert from 'node:assert/strict'
import test from 'node:test'

import { buildDashboardData, type DashboardProjectSource } from './dashboard-core.ts'

const stock = {
  disponivel: 10,
  em_campo: 4,
  retornando: 2,
  manutencao: 3,
  criticos: 1,
  patrimonio_total: 126_400,
  baixas: 2,
  vendidos: 1,
}

function project(overrides: Partial<DashboardProjectSource>): DashboardProjectSource {
  return {
    id: 'proj-default',
    nome: 'Evento Base',
    cliente: 'Cliente Base',
    data_inicio: '2026-07-01T14:00:00.000Z',
    data_fim: '2026-07-02T02:00:00.000Z',
    local: 'Galpão MMD',
    status: 'CONFIRMADO',
    readiness_pct: 0,
    gate_readiness_pct: 0,
    gate_blockers_count: 0,
    open_return_pendings: 0,
    packing: [],
    ...overrides,
  }
}

test('dashboard uses provided projects instead of fixed fixture events', () => {
  const data = buildDashboardData({
    stock,
    projects: [],
    now: new Date('2026-06-23T12:00:00.000Z'),
  })

  assert.equal(data.hero_event, null)
  assert.deepEqual(data.upcoming_events, [])
  assert.equal(data.upcoming_scheduled, 0)
})

test('dashboard readiness uses gate data and return pendings for event risk', () => {
  const data = buildDashboardData({
    stock,
    now: new Date('2026-06-23T12:00:00.000Z'),
    projects: [
      project({
        id: 'proj-ready',
        nome: 'Casamento Lima',
        cliente: 'Lima',
        gate_readiness_pct: 100,
        readiness_pct: 50,
        packing: [
          {
            id: 'pack-light',
            item_nome: 'Moving Beam',
            categoria: 'ILUMINACAO',
            qtd_necessaria: 6,
            qtd_alocada: 4,
            qtd_alugada_avulsa: 2,
            qtd_coberta: 6,
            qtd_faltante: 0,
          },
        ],
      }),
      project({
        id: 'proj-return',
        nome: 'Show Alfa',
        cliente: 'Banda Alfa',
        data_inicio: '2026-07-03T21:00:00.000Z',
        status: 'EM_CAMPO',
        gate_readiness_pct: 86,
        open_return_pendings: 1,
        packing: [
          {
            id: 'pack-audio',
            item_nome: 'Caixa PRX',
            categoria: 'AUDIO',
            qtd_necessaria: 4,
            qtd_alocada: 2,
            qtd_alugada_avulsa: 0,
            qtd_coberta: 2,
            qtd_faltante: 2,
          },
        ],
      }),
    ],
  })

  assert.equal(data.hero_event?.readiness, 100)
  assert.equal(data.upcoming_events[0]?.status, 'pronto')
  assert.equal(data.upcoming_events[1]?.readiness, 50)
  assert.equal(data.upcoming_events[1]?.status, 'critico')
  assert.equal(data.notifications, 1)
})

test('dashboard category usage aggregates own units plus partner rentals', () => {
  const data = buildDashboardData({
    stock,
    now: new Date('2026-06-23T12:00:00.000Z'),
    projects: [
      project({
        id: 'proj-categories',
        packing: [
          {
            id: 'pack-light',
            item_nome: 'Moving Beam',
            categoria: 'ILUMINACAO',
            qtd_necessaria: 6,
            qtd_alocada: 2,
            qtd_alugada_avulsa: 3,
            qtd_coberta: 5,
            qtd_faltante: 1,
          },
          {
            id: 'pack-audio',
            item_nome: 'Caixa PRX',
            categoria: 'AUDIO',
            qtd_necessaria: 4,
            qtd_alocada: 4,
            qtd_alugada_avulsa: 0,
            qtd_coberta: 4,
            qtd_faltante: 0,
          },
        ],
      }),
    ],
  })

  const light = data.category_usage.find((row) => row.categoria === 'ILUMINACAO')
  const audio = data.category_usage.find((row) => row.categoria === 'AUDIO')

  assert.equal(light?.covered, 5)
  assert.equal(light?.required, 6)
  assert.equal(light?.readiness, 83)
  assert.equal(audio?.readiness, 100)
})

test('dashboard keeps date-only events on the intended local day', () => {
  const data = buildDashboardData({
    stock,
    now: new Date('2026-06-23T12:00:00.000Z'),
    projects: [
      project({
        id: 'proj-date-only',
        nome: 'Brasil x Escócia',
        cliente: 'Norte Ventures',
        data_inicio: '2026-06-24',
        data_fim: '2026-06-24',
        local: 'Norte Ventures',
        gate_readiness_pct: 55,
      }),
    ],
  })

  assert.equal(data.hero_event?.date, '24 DE JUN')
  assert.equal(data.upcoming_events[0]?.date, '24 DE JUN')
})

test('dashboard exposes maintenance and loss signals from stock state', () => {
  const data = buildDashboardData({
    stock,
    projects: [],
    now: new Date('2026-06-23T12:00:00.000Z'),
  })

  assert.equal(data.maintenance_signals.find((signal) => signal.id === 'manutencao')?.value, 3)
  assert.equal(data.maintenance_signals.find((signal) => signal.id === 'retornando')?.value, 2)
  assert.equal(data.maintenance_signals.find((signal) => signal.id === 'criticos')?.value, 1)
  assert.equal(data.maintenance_signals.find((signal) => signal.id === 'perdas')?.value, 3)
})
