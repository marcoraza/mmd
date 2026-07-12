import assert from 'node:assert/strict'
import test from 'node:test'
import {
  applyPackingSuggestionEdits,
  buildPackingTemplatePayload,
  createPackingSuggestionWorkspace,
  normalizeSuggestionLines,
  type PackingSuggestionLine,
  type PackingSuggestionProject,
  type PackingTemplate,
} from './packing-suggestion-core.ts'

const beam: PackingSuggestionLine = {
  itemId: 'item-beam',
  codigoInterno: 'MMD-ILU-0001',
  nome: 'Moving Beam 7R',
  categoria: 'ILUMINACAO',
  quantidade: 6,
  observacao: 'Frente de palco',
}

const caixa: PackingSuggestionLine = {
  itemId: 'item-caixa',
  codigoInterno: 'MMD-AUD-0001',
  nome: 'Caixa ativa',
  categoria: 'AUDIO',
  quantidade: 4,
  observacao: null,
}

function project(overrides: Partial<PackingSuggestionProject>): PackingSuggestionProject {
  return {
    id: 'target',
    nome: 'Casamento Santos',
    cliente: 'Família Santos',
    local: 'Jardim Botânico',
    dataInicio: '2026-06-12',
    dataFim: '2026-06-13',
    status: 'CONFIRMADO',
    notas: 'Cerimônia externa',
    packing: [],
    ...overrides,
  }
}

test('salva packing atual como template normalizado', () => {
  const result = buildPackingTemplatePayload({
    nome: '  Casamento premium   ',
    descricao: '  Cerimônia externa  ',
    projetoId: 'proj-1',
    packing: [beam, { ...beam, quantidade: 2, observacao: 'Backup' }, caixa],
  })

  assert.equal(result.ok, true)
  assert.equal(result.data.nome, 'Casamento premium')
  assert.equal(result.data.descricao, 'Cerimônia externa')
  assert.equal(result.data.linhas.length, 2)
  assert.deepEqual(
    result.data.linhas.map((line) => [line.itemId, line.quantidade]),
    [
      ['item-beam', 8],
      ['item-caixa', 4],
    ],
  )
  assert.equal(result.data.linhas[0]?.observacao, 'Frente de palco\nBackup')
})

test('recusa template sem nome ou sem linhas válidas', () => {
  assert.equal(
    buildPackingTemplatePayload({ nome: ' ', projetoId: 'proj-1', packing: [beam] }).ok,
    false,
  )
  assert.equal(
    buildPackingTemplatePayload({ nome: 'Casamento', projetoId: 'proj-1', packing: [] }).ok,
    false,
  )
})

test('prioriza histórico parecido antes de template salvo', () => {
  const template: PackingTemplate = {
    id: 'tpl-1',
    nome: 'Template geral',
    descricao: null,
    origemProjetoId: null,
    linhas: [caixa],
  }

  const workspace = createPackingSuggestionWorkspace({
    target: project({ id: 'proj-target' }),
    historicalProjects: [
      project({
        id: 'hist-different',
        nome: 'Feira Tech',
        cliente: 'Outro cliente',
        local: 'Expo Center',
        packing: [caixa],
      }),
      project({
        id: 'hist-similar',
        nome: 'Casamento Santos anterior',
        cliente: 'Família Santos',
        local: 'Jardim Botânico',
        packing: [beam],
      }),
    ],
    templates: [template],
  })

  assert.equal(workspace.suggestions[0]?.source, 'historico')
  assert.equal(workspace.suggestions[0]?.id, 'historico:hist-similar')
  assert.equal(workspace.suggestions[1]?.source, 'template')
})

test('ignora histórico sem semelhança e mantém template reutilizável', () => {
  const workspace = createPackingSuggestionWorkspace({
    target: project({ id: 'proj-target' }),
    historicalProjects: [
      project({
        id: 'hist-different',
        nome: 'Congresso médico',
        cliente: 'Hospital',
        local: 'Auditório Central',
        packing: [beam],
      }),
    ],
    templates: [
      {
        id: 'tpl-1',
        nome: 'Casamento padrão',
        descricao: 'Base salva',
        origemProjetoId: 'proj-old',
        linhas: [beam, caixa],
      },
    ],
  })

  assert.equal(workspace.suggestions.length, 1)
  assert.equal(workspace.suggestions[0]?.source, 'template')
  assert.equal(workspace.suggestions[0]?.lines.length, 2)
})

test('edição humana altera proposta antes de gravar', () => {
  const edited = applyPackingSuggestionEdits([beam, caixa], {
    'item-beam': 10,
    'item-caixa': 2,
  })

  assert.deepEqual(
    edited.map((line) => [line.itemId, line.quantidade]),
    [
      ['item-beam', 10],
      ['item-caixa', 2],
    ],
  )
})

test('normaliza duplicados e remove quantidades inválidas', () => {
  const lines = normalizeSuggestionLines([
    beam,
    { ...beam, quantidade: 1, observacao: 'Frente de palco' },
    { ...caixa, quantidade: 0 },
  ])

  assert.equal(lines.length, 1)
  assert.equal(lines[0]?.quantidade, 7)
  assert.equal(lines[0]?.observacao, 'Frente de palco')
})
