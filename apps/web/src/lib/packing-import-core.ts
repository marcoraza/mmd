import type { Categoria } from './types'

export const PACKING_IMPORT_COLUMNS = [
  'codigo_mmd',
  'categoria',
  'item',
  'subcategoria',
  'marca',
  'modelo',
  'quantidade',
  'observacao',
] as const

export const PACKING_IMPORT_ACCEPT = '.xlsx,.csv,.tsv'
export const PACKING_IMPORT_MAX_FILE_BYTES = 10 * 1024 * 1024

export type PackingImportColumn = (typeof PACKING_IMPORT_COLUMNS)[number]

export type PackingImportCellValue = string | number | boolean | Date | null | undefined

export type PackingImportRowInput = {
  rowNumber: number
} & Partial<Record<PackingImportColumn, PackingImportCellValue>>

export type PackingImportDisplayInput = Record<PackingImportColumn, string>

export type PackingImportCatalogItem = {
  id: string
  codigo_interno: string | null
  nome: string
  categoria: Categoria | string
  subcategoria: string | null
  marca: string | null
  modelo: string | null
  quantidade_total?: number | null
}

export type PackingImportCandidate = {
  id: string
  codigo_interno: string | null
  nome: string
  categoria: string
  subcategoria: string | null
  marca: string | null
  modelo: string | null
  quantidade_total: number | null
}

export type PackingImportMatchReason = 'codigo_mmd' | 'texto'
export type PackingImportRowStatus = 'matched' | 'ambiguous' | 'invalid'

type PackingImportBaseRow = {
  rowNumber: number
  input: PackingImportDisplayInput
  quantidade: number
  observacao: string | null
  errors: string[]
}

export type PackingImportMatchedRow = PackingImportBaseRow & {
  status: 'matched'
  matchReason: PackingImportMatchReason
  match: PackingImportCandidate
  candidates: PackingImportCandidate[]
}

export type PackingImportAmbiguousRow = PackingImportBaseRow & {
  status: 'ambiguous'
  matchReason: 'texto'
  match: null
  candidates: PackingImportCandidate[]
}

export type PackingImportInvalidRow = PackingImportBaseRow & {
  status: 'invalid'
  matchReason: null
  match: PackingImportCandidate | null
  candidates: PackingImportCandidate[]
}

export type PackingImportRow =
  | PackingImportMatchedRow
  | PackingImportAmbiguousRow
  | PackingImportInvalidRow

export type PackingImportSummary = {
  total: number
  matched: number
  ambiguous: number
  invalid: number
  approvedQuantity: number
}

export type PackingImportPreview = {
  fileName: string
  columns: readonly PackingImportColumn[]
  rows: PackingImportRow[]
  summary: PackingImportSummary
}

export type PackingImportResolution = {
  rowNumber: number
  itemId: string
}

export type PackingImportApproval = {
  itemId: string
  quantidade: number
  observacao: string | null
  sourceRowNumbers: number[]
  item: PackingImportCandidate
}

const CATEGORIAS: Categoria[] = [
  'ILUMINACAO',
  'AUDIO',
  'CABO',
  'ENERGIA',
  'ESTRUTURA',
  'EFEITO',
  'VIDEO',
  'ACESSORIO',
]

const CATEGORY_ALIASES = new Map<string, Categoria>([
  ['ILUMINACAO', 'ILUMINACAO'],
  ['ILUMINACAO CENICA', 'ILUMINACAO'],
  ['ILU', 'ILUMINACAO'],
  ['LUZ', 'ILUMINACAO'],
  ['AUDIO', 'AUDIO'],
  ['AUD', 'AUDIO'],
  ['SOM', 'AUDIO'],
  ['CABO', 'CABO'],
  ['CABOS', 'CABO'],
  ['CAB', 'CABO'],
  ['ENERGIA', 'ENERGIA'],
  ['ENE', 'ENERGIA'],
  ['ELETRICA', 'ENERGIA'],
  ['ESTRUTURA', 'ESTRUTURA'],
  ['EST', 'ESTRUTURA'],
  ['TRUSS', 'ESTRUTURA'],
  ['EFEITO', 'EFEITO'],
  ['EFEITOS', 'EFEITO'],
  ['EFE', 'EFEITO'],
  ['VIDEO', 'VIDEO'],
  ['VID', 'VIDEO'],
  ['ACESSORIO', 'ACESSORIO'],
  ['ACESSORIOS', 'ACESSORIO'],
  ['ACE', 'ACESSORIO'],
])

const HEADER_ALIASES = new Map<string, PackingImportColumn>([
  ['CODIGO_MMD', 'codigo_mmd'],
  ['CODIGO', 'codigo_mmd'],
  ['CODIGO_INTERNO', 'codigo_mmd'],
  ['COD_MMD', 'codigo_mmd'],
  ['CATEGORIA', 'categoria'],
  ['CAT', 'categoria'],
  ['ITEM', 'item'],
  ['NOME', 'item'],
  ['EQUIPAMENTO', 'item'],
  ['DESCRICAO', 'item'],
  ['SUBCATEGORIA', 'subcategoria'],
  ['TIPO', 'subcategoria'],
  ['MARCA', 'marca'],
  ['MODELO', 'modelo'],
  ['QTD', 'quantidade'],
  ['QTDE', 'quantidade'],
  ['QUANTIDADE', 'quantidade'],
  ['OBS', 'observacao'],
  ['OBSERVACAO', 'observacao'],
  ['OBSERVACOES', 'observacao'],
])

export function normalizePackingImportHeader(value: PackingImportCellValue): PackingImportColumn | null {
  const key = normalizeText(value).replace(/\s+/g, '_')
  return HEADER_ALIASES.get(key) ?? null
}

export function toPackingImportInput(
  rowNumber: number,
  values: Partial<Record<PackingImportColumn, PackingImportCellValue>>,
): PackingImportRowInput {
  return { rowNumber, ...values }
}

export function createPackingImportPreview({
  fileName,
  rows,
  catalog,
}: {
  fileName: string
  rows: PackingImportRowInput[]
  catalog: PackingImportCatalogItem[]
}): PackingImportPreview {
  const matchedRows = matchPackingImportRows(rows, catalog)
  return {
    fileName,
    columns: PACKING_IMPORT_COLUMNS,
    rows: matchedRows,
    summary: summarizePackingImportRows(matchedRows),
  }
}

export function matchPackingImportRows(
  rows: PackingImportRowInput[],
  catalog: PackingImportCatalogItem[],
): PackingImportRow[] {
  const candidates = catalog.map(toCandidate)
  const codeMap = new Map<string, PackingImportCandidate>()
  for (const candidate of candidates) {
    const code = normalizeCode(candidate.codigo_interno)
    if (code && !codeMap.has(code)) codeMap.set(code, candidate)
  }

  return rows.map((row) => matchPackingImportRow(row, candidates, codeMap))
}

export function summarizePackingImportRows(rows: PackingImportRow[]): PackingImportSummary {
  return rows.reduce(
    (acc, row) => {
      acc.total += 1
      if (row.status === 'matched') {
        acc.matched += 1
        acc.approvedQuantity += row.quantidade
      } else if (row.status === 'ambiguous') {
        acc.ambiguous += 1
      } else {
        acc.invalid += 1
      }
      return acc
    },
    { total: 0, matched: 0, ambiguous: 0, invalid: 0, approvedQuantity: 0 },
  )
}

export function buildPackingImportApprovals(
  rows: PackingImportRow[],
  resolutions: PackingImportResolution[] = [],
): PackingImportApproval[] {
  const resolutionMap = new Map(resolutions.map((resolution) => [resolution.rowNumber, resolution.itemId]))
  const approvalsByItem = new Map<string, PackingImportApproval>()

  for (const row of rows) {
    const item =
      row.status === 'matched'
        ? row.match
        : row.status === 'ambiguous'
          ? row.candidates.find((candidate) => candidate.id === resolutionMap.get(row.rowNumber))
          : null
    if (!item) continue

    const existing = approvalsByItem.get(item.id)
    if (existing) {
      existing.quantidade += row.quantidade
      existing.sourceRowNumbers.push(row.rowNumber)
      existing.observacao = mergeObservacao(existing.observacao, row.observacao)
      continue
    }

    approvalsByItem.set(item.id, {
      itemId: item.id,
      quantidade: row.quantidade,
      observacao: row.observacao,
      sourceRowNumbers: [row.rowNumber],
      item,
    })
  }

  return [...approvalsByItem.values()].sort(
    (a, b) => a.sourceRowNumbers[0] - b.sourceRowNumbers[0],
  )
}

export function unresolvedPackingImportRows(
  rows: PackingImportRow[],
  resolutions: PackingImportResolution[] = [],
): PackingImportAmbiguousRow[] {
  const resolvedRows = new Set(resolutions.map((resolution) => resolution.rowNumber))
  return rows.filter(
    (row): row is PackingImportAmbiguousRow =>
      row.status === 'ambiguous' && !resolvedRows.has(row.rowNumber),
  )
}

function matchPackingImportRow(
  row: PackingImportRowInput,
  catalog: PackingImportCandidate[],
  codeMap: Map<string, PackingImportCandidate>,
): PackingImportRow {
  const input = displayInput(row)
  const quantity = parseQuantity(row.quantidade)
  const observacao = valueText(row.observacao) || null
  const base = {
    rowNumber: row.rowNumber,
    input,
    quantidade: quantity.ok ? quantity.value : 0,
    observacao,
  }
  const errors: string[] = []
  if (!quantity.ok) errors.push(quantity.error)

  const code = normalizeCode(row.codigo_mmd)
  if (code) {
    const match = codeMap.get(code) ?? null
    if (!match) {
      errors.push('Código MMD não encontrado no catálogo.')
      return {
        ...base,
        status: 'invalid',
        matchReason: null,
        match,
        candidates: [],
        errors,
      }
    }
    if (errors.length > 0) {
      return {
        ...base,
        status: 'invalid',
        matchReason: null,
        match,
        candidates: [match],
        errors,
      }
    }
    return {
      ...base,
      status: 'matched',
      matchReason: 'codigo_mmd',
      match,
      candidates: [match],
      errors: [],
    }
  }

  const category = parseCategoria(row.categoria)
  const itemText = normalizeSearchText(row.item)

  if (!valueText(row.categoria)) errors.push('Categoria obrigatória quando não há código MMD.')
  else if (!category) errors.push('Categoria não reconhecida.')
  if (!itemText) errors.push('Item obrigatório quando não há código MMD.')

  if (errors.length > 0 || !category) {
    return {
      ...base,
      status: 'invalid',
      matchReason: null,
      match: null,
      candidates: [],
      errors,
    }
  }

  const textCandidates = findTextCandidates(row, category, catalog)
  if (textCandidates.length === 0) {
    return {
      ...base,
      status: 'invalid',
      matchReason: null,
      match: null,
      candidates: [],
      errors: ['Nenhum item do catálogo bateu com a linha.'],
    }
  }
  if (textCandidates.length === 1) {
    const [match] = textCandidates
    return {
      ...base,
      status: 'matched',
      matchReason: 'texto',
      match,
      candidates: [match],
      errors: [],
    }
  }

  return {
    ...base,
    status: 'ambiguous',
    matchReason: 'texto',
    match: null,
    candidates: textCandidates,
    errors: [],
  }
}

function findTextCandidates(
  row: PackingImportRowInput,
  category: Categoria,
  catalog: PackingImportCandidate[],
) {
  const itemText = normalizeSearchText(row.item)
  const tokens = itemText.split(' ').filter((token) => token.length > 1)
  return catalog
    .filter((candidate) => candidate.categoria === category)
    .filter((candidate) => matchesItemText(candidate, itemText, tokens))
    .filter((candidate) => optionalFieldMatches(row.subcategoria, candidate.subcategoria))
    .filter((candidate) => optionalFieldMatches(row.marca, candidate.marca))
    .filter((candidate) => optionalFieldMatches(row.modelo, candidate.modelo))
    .sort((a, b) => {
      const codeA = a.codigo_interno ?? ''
      const codeB = b.codigo_interno ?? ''
      return codeA.localeCompare(codeB, 'pt-BR') || a.nome.localeCompare(b.nome, 'pt-BR')
    })
}

function matchesItemText(
  candidate: PackingImportCandidate,
  itemText: string,
  tokens: string[],
) {
  const candidateName = normalizeSearchText(candidate.nome)
  const haystack = normalizeSearchText(
    [candidate.nome, candidate.subcategoria, candidate.marca, candidate.modelo].join(' '),
  )
  return (
    haystack.includes(itemText) ||
    itemText.includes(candidateName) ||
    tokens.every((token) => haystack.includes(token))
  )
}

function optionalFieldMatches(input: PackingImportCellValue, candidateValue: string | null) {
  const needle = normalizeSearchText(input)
  if (!needle) return true
  const haystack = normalizeSearchText(candidateValue)
  return haystack.includes(needle) || needle.includes(haystack)
}

function parseQuantity(value: PackingImportCellValue): { ok: true; value: number } | { ok: false; error: string } {
  const raw = valueText(value)
  if (!raw) return { ok: false, error: 'Quantidade obrigatória.' }
  const normalized = raw.replace(',', '.')
  const numeric = Number(normalized)
  if (!Number.isFinite(numeric) || numeric <= 0 || !Number.isInteger(numeric)) {
    return { ok: false, error: 'Quantidade precisa ser um número inteiro maior que zero.' }
  }
  return { ok: true, value: numeric }
}

function parseCategoria(value: PackingImportCellValue): Categoria | null {
  const normalized = normalizeText(value)
  if (!normalized) return null
  if (CATEGORIAS.includes(normalized as Categoria)) return normalized as Categoria
  return CATEGORY_ALIASES.get(normalized) ?? null
}

function toCandidate(item: PackingImportCatalogItem): PackingImportCandidate {
  return {
    id: item.id,
    codigo_interno: item.codigo_interno ?? null,
    nome: item.nome,
    categoria: parseCategoria(item.categoria) ?? String(item.categoria),
    subcategoria: item.subcategoria ?? null,
    marca: item.marca ?? null,
    modelo: item.modelo ?? null,
    quantidade_total: item.quantidade_total ?? null,
  }
}

function displayInput(row: PackingImportRowInput): PackingImportDisplayInput {
  return Object.fromEntries(
    PACKING_IMPORT_COLUMNS.map((column) => [column, valueText(row[column])]),
  ) as PackingImportDisplayInput
}

function mergeObservacao(current: string | null, incoming: string | null) {
  if (!incoming) return current
  if (!current) return incoming
  if (current.includes(incoming)) return current
  return `${current}; ${incoming}`
}

function normalizeCode(value: PackingImportCellValue) {
  return normalizeText(value).replace(/[^A-Z0-9]/g, '')
}

function normalizeSearchText(value: PackingImportCellValue) {
  return normalizeText(value)
    .replace(/[^A-Z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function normalizeText(value: PackingImportCellValue) {
  return valueText(value)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toUpperCase()
}

function valueText(value: PackingImportCellValue) {
  if (value == null) return ''
  if (value instanceof Date) return value.toISOString().slice(0, 10)
  return String(value).trim()
}
