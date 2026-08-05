import assert from 'node:assert/strict'
import test from 'node:test'

import {
  buildSerialSearchResponse,
  parseSerialSearchParams,
  SERIAL_SEARCH_INVALID_PARAMS,
} from './serial-search-core.ts'

function params(query: string) {
  return parseSerialSearchParams(new URLSearchParams(query))
}

test('sem parâmetro nenhum devolve a primeira página com os defaults do contrato', () => {
  const result = params('')
  assert.equal(result.ok, true)
  assert.deepEqual(result.ok && result.params, {
    q: null,
    itemId: null,
    semTag: false,
    limit: 25,
    offset: 0,
  })
})

test('q é aparado e precisa ter entre 2 e 64 caracteres', () => {
  const ok = params('q=%20beam%20230%20')
  assert.equal(ok.ok && ok.params.q, 'beam 230')

  assert.equal(params('q=a').ok, false)
  assert.equal(params(`q=${'a'.repeat(65)}`).ok, false)
  // q vazio não é erro: equivale a não enviar o filtro.
  assert.equal(params('q=%20%20').ok, true)
})

test('q rejeita a sintaxe de filtro do PostgREST', () => {
  for (const raw of [
    'q=beam,tag_rfid.eq.SECRET',
    'q=beam(230)',
    'q=beam*',
    'q=beam"230"',
    "q=beam'230",
  ]) {
    const result = params(raw)
    assert.equal(result.ok, false, `esperado erro para ${raw}`)
    assert.equal(!result.ok && result.error, SERIAL_SEARCH_INVALID_PARAMS)
  }
})

test('item_id precisa ser uuid e chega normalizado em minúsculas', () => {
  const upper = params('item_id=8F1C0A22-9D3E-4B77-A6C1-5E2D7F0B1234')
  assert.equal(upper.ok && upper.params.itemId, '8f1c0a22-9d3e-4b77-a6c1-5e2d7f0b1234')
  assert.equal(params('item_id=nao-e-uuid').ok, false)
})

test('limit acima do teto é reduzido em silêncio, não é erro', () => {
  const clamped = params('limit=5000')
  assert.equal(clamped.ok && clamped.params.limit, 100)
  const exact = params('limit=50&offset=50')
  assert.equal(exact.ok && exact.params.limit, 50)
  assert.equal(exact.ok && exact.params.offset, 50)
})

test('limit e offset não inteiros ou negativos são parametros_invalidos', () => {
  for (const raw of ['limit=abc', 'limit=-1', 'offset=-1', 'offset=1.5']) {
    const result = params(raw)
    assert.equal(result.ok, false, `esperado erro para ${raw}`)
  }
})

test('sem_tag aceita o vocabulário booleano e não vira erro quando desconhecido', () => {
  assert.equal(params('sem_tag=true').ok && params('sem_tag=true').params.semTag, true)
  assert.equal(params('sem_tag=1').ok && params('sem_tag=1').params.semTag, true)
  const talvez = params('sem_tag=talvez')
  assert.equal(talvez.ok, true)
  assert.equal(talvez.ok && talvez.params.semTag, false)
})

test('has_more compara offset mais página contra o total', () => {
  const page = buildSerialSearchResponse({
    items: [
      { serial_id: 'a', codigo_interno: 'MMD-ILU-0001', item_nome: 'Beam', tag_rfid: null },
      { serial_id: 'b', codigo_interno: 'MMD-ILU-0002', item_nome: 'Beam', tag_rfid: 'E280' },
    ],
    total: 42,
    limit: 25,
    offset: 0,
  })
  assert.equal(page.has_more, true)
  assert.equal(page.total, 42)

  const last = buildSerialSearchResponse({
    items: [{ serial_id: 'c', codigo_interno: 'MMD-ILU-0042', item_nome: null, tag_rfid: null }],
    total: 42,
    limit: 25,
    offset: 41,
  })
  assert.equal(last.has_more, false)
})
