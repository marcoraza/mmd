import type { Categoria } from './types'

export type PackingSuggestionSource = 'historico' | 'template' | 'ia_rascunho'

export type PackingSuggestionLine = {
  itemId: string
  codigoInterno: string | null
  nome: string
  categoria: Categoria | string
  quantidade: number
  observacao: string | null
}

export type PackingSuggestionProject = {
  id: string
  nome: string
  cliente: string | null
  local: string | null
  dataInicio: string | null
  dataFim: string | null
  status?: string | null
  notas?: string | null
  packing: PackingSuggestionLine[]
}

export type PackingTemplate = {
  id: string
  nome: string
  descricao: string | null
  origemProjetoId: string | null
  linhas: PackingSuggestionLine[]
  createdAt?: string | null
}

export type PackingSuggestionCandidate = {
  id: string
  source: PackingSuggestionSource
  title: string
  subtitle: string
  reason: string
  confidencePct: number
  lines: PackingSuggestionLine[]
  disabled?: boolean
}

export type PackingSuggestionWorkspace = {
  templates: PackingTemplate[]
  suggestions: PackingSuggestionCandidate[]
  aiAvailable: boolean
}

export type PackingTemplatePayload = {
  nome: string
  descricao: string | null
  origemProjetoId: string | null
  linhas: PackingSuggestionLine[]
}

export type PackingSuggestionResult<T> = { ok: true; data: T } | { ok: false; error: string }

export function normalizePackingTemplateName(value: string) {
  return value.trim().replace(/\s+/g, ' ').slice(0, 90)
}

export function normalizePackingTemplateDescription(value: string | null | undefined) {
  const trimmed = value?.trim().replace(/\s+/g, ' ') ?? ''
  return trimmed ? trimmed.slice(0, 180) : null
}

export function buildPackingTemplatePayload({
  nome,
  descricao,
  projetoId,
  packing,
}: {
  nome: string
  descricao?: string | null
  projetoId: string | null
  packing: PackingSuggestionLine[]
}): PackingSuggestionResult<PackingTemplatePayload> {
  const normalizedName = normalizePackingTemplateName(nome)
  if (!normalizedName) return { ok: false, error: 'Nome do template obrigatório.' }

  const lines = normalizeSuggestionLines(packing)
  if (lines.length === 0) {
    return { ok: false, error: 'Packing precisa ter pelo menos uma linha para virar template.' }
  }

  return {
    ok: true,
    data: {
      nome: normalizedName,
      descricao: normalizePackingTemplateDescription(descricao),
      origemProjetoId: projetoId,
      linhas: lines,
    },
  }
}

export function createPackingSuggestionWorkspace({
  target,
  historicalProjects,
  templates,
  aiDraft,
}: {
  target: PackingSuggestionProject
  historicalProjects: PackingSuggestionProject[]
  templates: PackingTemplate[]
  aiDraft?: PackingSuggestionLine[] | null
}): PackingSuggestionWorkspace {
  const historical = historicalProjects
    .filter((project) => project.id !== target.id)
    .map((project) => ({
      project,
      score: scoreHistoricalProject(target, project),
    }))
    .filter(({ project, score }) => score >= 2 && project.packing.length > 0)
    .sort((a, b) => b.score - a.score || a.project.nome.localeCompare(b.project.nome))
    .slice(0, 3)
    .map(({ project, score }): PackingSuggestionCandidate => {
      const confidence = Math.min(92, 55 + score * 7)
      return {
        id: `historico:${project.id}`,
        source: 'historico',
        title: project.nome,
        subtitle: project.cliente ?? project.local ?? 'Histórico parecido',
        reason: historicalReason(target, project, score),
        confidencePct: confidence,
        lines: normalizeSuggestionLines(project.packing),
      }
    })

  const templateSuggestions = templates
    .filter((template) => template.linhas.length > 0)
    .slice(0, 6)
    .map(
      (template): PackingSuggestionCandidate => ({
        id: `template:${template.id}`,
        source: 'template',
        title: template.nome,
        subtitle: template.descricao ?? 'Template salvo',
        reason: template.origemProjetoId
          ? 'Template salvo a partir de um Evento anterior.'
          : 'Template salvo manualmente para reutilização.',
        confidencePct: 68,
        lines: normalizeSuggestionLines(template.linhas),
      }),
    )

  const aiLines = normalizeSuggestionLines(aiDraft ?? [])
  const aiSuggestion: PackingSuggestionCandidate[] =
    aiLines.length > 0
      ? [
          {
            id: 'ia:rascunho',
            source: 'ia_rascunho',
            title: 'IA rascunho',
            subtitle: 'Precisa revisão humana',
            reason: 'Rascunho gerado por IA. Nada é gravado sem revisão e aplicação manual.',
            confidencePct: 40,
            lines: aiLines,
          },
        ]
      : []

  return {
    templates,
    suggestions: [...historical, ...templateSuggestions, ...aiSuggestion],
    aiAvailable: aiSuggestion.length > 0,
  }
}

export function applyPackingSuggestionEdits(
  lines: PackingSuggestionLine[],
  edits: Record<string, number>,
) {
  return normalizeSuggestionLines(
    lines.map((line) => ({
      ...line,
      quantidade: edits[line.itemId] ?? line.quantidade,
    })),
  )
}

export function normalizeSuggestionLines(lines: PackingSuggestionLine[]) {
  const byItem = new Map<string, PackingSuggestionLine>()

  for (const line of lines) {
    const itemId = line.itemId?.trim()
    const quantidade = Number(line.quantidade)
    if (!itemId || !Number.isInteger(quantidade) || quantidade <= 0) continue

    const existing = byItem.get(itemId)
    const observacao = line.observacao?.trim() || null
    if (existing) {
      existing.quantidade += quantidade
      existing.observacao = mergeNotes(existing.observacao, observacao)
      continue
    }

    byItem.set(itemId, {
      itemId,
      codigoInterno: line.codigoInterno ?? null,
      nome: line.nome.trim() || 'Item do catálogo',
      categoria: line.categoria,
      quantidade,
      observacao,
    })
  }

  return [...byItem.values()]
}

function scoreHistoricalProject(target: PackingSuggestionProject, project: PackingSuggestionProject) {
  let score = 0
  const targetClient = normalizeText(target.cliente)
  const projectClient = normalizeText(project.cliente)
  if (targetClient && targetClient === projectClient) score += 4

  const nameOverlap = tokenOverlap(target.nome, project.nome)
  if (nameOverlap > 0) score += Math.min(3, nameOverlap)

  const locationOverlap = tokenOverlap(target.local ?? '', project.local ?? '')
  if (locationOverlap > 0) score += Math.min(2, locationOverlap)

  const notesOverlap = tokenOverlap(target.notas ?? '', project.notas ?? '')
  if (notesOverlap > 0) score += 1

  return score
}

function historicalReason(
  target: PackingSuggestionProject,
  project: PackingSuggestionProject,
  score: number,
) {
  if (normalizeText(target.cliente) && normalizeText(target.cliente) === normalizeText(project.cliente)) {
    return 'Mesmo cliente em Evento anterior, com packing já montado.'
  }
  if (tokenOverlap(target.nome, project.nome) > 0) {
    return 'Nome do Evento parecido com histórico já montado.'
  }
  if (score > 0) return 'Histórico com sinais parecidos de Evento e local.'
  return 'Histórico reaproveitável.'
}

function tokenOverlap(a: string, b: string) {
  const left = new Set(tokenize(a))
  if (left.size === 0) return 0
  let count = 0
  for (const token of tokenize(b)) {
    if (left.has(token)) count += 1
  }
  return count
}

function tokenize(value: string) {
  return normalizeText(value)
    .split(' ')
    .filter((token) => token.length >= 4)
}

function normalizeText(value: string | null | undefined) {
  return (value ?? '')
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, ' ')
    .trim()
}

function mergeNotes(existing: string | null, incoming: string | null) {
  if (!incoming) return existing
  if (!existing) return incoming
  if (existing.includes(incoming)) return existing
  return `${existing}\n${incoming}`
}
