import assert from 'node:assert/strict'
import test from 'node:test'
import {
  calculateFichaCompleteness,
  emptyEventoFichaInput,
  normalizeEventoFichaInput,
} from './evento-ficha-core.ts'

test('normaliza ficha de evento para payload operacional de projeto', () => {
  const input = {
    ...emptyEventoFichaInput(),
    nomeEvento: ' Casamento Julia e Pedro ',
    cliente: ' Marcelo Santos ',
    dataInicial: '2026-06-23',
    dataFinal: '2026-06-24',
    statusInicial: 'CONFIRMADO' as const,
    local: 'Espaço Villa Toscana',
    endereco: 'Rua das Oliveiras, 500',
    cidadeUf: 'São Paulo SP',
    referenciaAcesso: 'Portão lateral',
    montagemDia: '2026-06-23',
    montagemInicio: '14:00',
    montagemFim: '18:00',
    montagemResponsavel: 'Lucas Oliveira',
    desmontagemDia: '2026-06-24',
    desmontagemInicio: '02:00',
    responsavelPrincipal: 'Marcelo Santos',
    observacoes: 'Cerimônia ao ar livre.',
    checklist: [
      { item: 'Briefing com cliente', responsavel: 'Marcelo', ok: true },
      { item: ' ', responsavel: ' ', ok: false },
    ],
  }

  const result = normalizeEventoFichaInput(input, '2026-06-23T05:50:00.000Z')

  assert.equal(result.ok, true)
  if (!result.ok) return
  assert.equal(result.data.projeto.nome, 'Casamento Julia e Pedro')
  assert.equal(result.data.projeto.cliente, 'Marcelo Santos')
  assert.equal(result.data.projeto.status, 'CONFIRMADO')
  assert.equal(result.data.projeto.local, 'Espaço Villa Toscana')
  assert.equal(result.data.projeto.ficha_evento.endereco.endereco, 'Rua das Oliveiras, 500')
  assert.equal(result.data.projeto.ficha_evento.montagem.inicio, '14:00')
  assert.equal(result.data.projeto.ficha_evento.checklist.length, 1)
  assert.match(result.data.projeto.notas ?? '', /OBS do evento: Cerimônia ao ar livre\./)
})

test('bloqueia data final anterior a inicial', () => {
  const result = normalizeEventoFichaInput({
    ...emptyEventoFichaInput(),
    nomeEvento: 'Evento teste',
    dataInicial: '2026-06-24',
    dataFinal: '2026-06-23',
  })

  assert.deepEqual(result, { ok: false, error: 'Data final antes da inicial.' })
})

test('calcula prontidão da ficha por campos obrigatórios', () => {
  const completeness = calculateFichaCompleteness({
    ...emptyEventoFichaInput(),
    nomeEvento: 'Evento teste',
    cliente: 'Cliente',
    dataInicial: '2026-06-23',
    dataFinal: '2026-06-23',
  })

  assert.equal(completeness.total, 13)
  assert.equal(completeness.preenchidos, 4)
  assert.equal(completeness.pct, 31)
})
