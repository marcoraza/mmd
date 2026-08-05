import 'server-only'

// Packing list do Evento: linhas de necessidade, importação de planilha,
// sugestão a partir de histórico/template e cobertura por aluguel avulso.
// Alocação de unidade própria fica em `actions/alocacao.ts`.

import { randomUUID } from 'node:crypto'
import { revalidatePath } from 'next/cache'
import { requireActionUser } from '@/lib/action-auth'
import { blockWrite, type ActionResult } from '@/lib/readonly'
import { supabaseAdmin } from '@/lib/supabase-server'
import { allocationSerialIds, type AllocationEmbedRow } from '@/lib/data/allocations'
import {
  createPackingImportPreview,
  type PackingImportCatalogItem,
  type PackingImportPreview,
} from '@/lib/packing-import-core'
import { parsePackingImportFile } from '@/lib/packing-import-file'
import {
  buildPackingTemplatePayload,
  createPackingSuggestionWorkspace,
  normalizeSuggestionLines,
  type PackingSuggestionProject,
  type PackingSuggestionWorkspace,
  type PackingTemplate,
} from '@/lib/packing-suggestion-core'
import {
  computePackingCoverage,
  normalizeExternalRentalInput,
  parseExternalRentalCoverages,
} from '@/lib/external-rental-core'

export type ApplyPackingLineInput = {
  itemId: string
  quantidade: number
  observacao?: string | null
}

export type ItemSearchResult = {
  id: string
  codigo_interno: string | null
  nome: string
  categoria: string
  quantidade_total: number
}

export type ExternalRentalCoverageInput = {
  fornecedor: string
  quantidade: number
  observacao: string
}

// ── Importação de planilha ──────────────────────────────────────────────────

export async function previewPackingImport(
  formData: FormData,
): Promise<ActionResult<PackingImportPreview>> {
  const auth = await requireActionUser('viewer')
  if (!auth.ok) return auth

  const value = formData.get('file')
  const file = !value || typeof value === 'string' ? null : value
  if (!file || file.size === 0) {
    return { ok: false, error: 'Selecione uma planilha para importar.' }
  }

  const catalog = await loadPackingImportCatalog()
  if (!catalog.ok) return catalog

  const parsed = await parsePackingImportFile(file)
  if (!parsed.ok) return parsed

  return {
    ok: true,
    data: createPackingImportPreview({
      fileName: file.name,
      rows: parsed.data,
      catalog: catalog.data,
    }),
  }
}

export async function applyPackingImport(
  projetoId: string,
  lines: ApplyPackingLineInput[],
): Promise<ActionResult<{ linhas: number; unidades: number }>> {
  const blocked = blockWrite<{ linhas: number; unidades: number }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const normalized = normalizeApplyPackingLines(lines)
  if (!normalized.ok) return normalized

  return persistPackingLines(projetoId, normalized.data)
}

async function loadPackingImportCatalog(): Promise<ActionResult<PackingImportCatalogItem[]>> {
  const { data, error } = await supabaseAdmin
    .from('items')
    .select('id, codigo_interno, nome, categoria, subcategoria, marca, modelo, quantidade_total')
    .order('nome', { ascending: true })

  if (error) return { ok: false, error: error.message }
  return { ok: true, data: (data ?? []) as unknown as PackingImportCatalogItem[] }
}

// ── Sugestão de packing ─────────────────────────────────────────────────────

type PackingSuggestionItemRow = {
  codigo_interno: string | null
  nome: string
  categoria: string
}

type PackingSuggestionPackingRow = {
  item_id: string
  quantidade: number
  notas: string | null
  items: PackingSuggestionItemRow | PackingSuggestionItemRow[] | null
}

type PackingSuggestionProjectRow = {
  id: string
  nome: string
  cliente: string | null
  data_inicio: string | null
  data_fim: string | null
  local: string | null
  status: string | null
  notas: string | null
  packing_list?: PackingSuggestionPackingRow[]
}

type PackingTemplateRow = {
  id: string
  nome: string
  descricao: string | null
  origem_projeto_id: string | null
  linhas: unknown
  created_at: string | null
}

export async function loadPackingSuggestionWorkspace(
  projetoId: string,
): Promise<ActionResult<PackingSuggestionWorkspace>> {
  const id = projetoId.trim()
  if (!id) return { ok: false, error: 'Evento obrigatório.' }

  const auth = await requireActionUser('viewer')
  if (!auth.ok) return auth

  const { data: target, error: targetError } = await supabaseAdmin
    .from('projetos')
    .select('id, nome, cliente, data_inicio, data_fim, local, status, notas')
    .eq('id', id)
    .maybeSingle()
  if (targetError) return { ok: false, error: targetError.message }
  if (!target) return { ok: false, error: 'Evento não encontrado.' }

  const { data: history, error: historyError } = await supabaseAdmin
    .from('projetos')
    .select(
      `id, nome, cliente, data_inicio, data_fim, local, status, notas,
       packing_list (
         item_id, quantidade, notas,
         items ( codigo_interno, nome, categoria )
       )`,
    )
    .neq('id', id)
    .order('data_inicio', { ascending: false })
    .limit(40)
  if (historyError) return { ok: false, error: historyError.message }

  const templates = await loadPackingTemplates()
  if (!templates.ok) return templates

  return {
    ok: true,
    data: createPackingSuggestionWorkspace({
      target: projectRowToSuggestionProject(target as unknown as PackingSuggestionProjectRow, []),
      historicalProjects: ((history ?? []) as unknown as PackingSuggestionProjectRow[]).map((row) =>
        projectRowToSuggestionProject(row, row.packing_list ?? []),
      ),
      templates: templates.data,
    }),
  }
}

export async function savePackingTemplateFromEvento(
  projetoId: string,
  nome: string,
  descricao?: string | null,
): Promise<ActionResult<{ id: string }>> {
  const blocked = blockWrite<{ id: string }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const id = projetoId.trim()
  if (!id) return { ok: false, error: 'Evento obrigatório.' }

  const { data: projeto, error } = await supabaseAdmin
    .from('projetos')
    .select(
      `id,
       packing_list (
         item_id, quantidade, notas,
         items ( codigo_interno, nome, categoria )
       )`,
    )
    .eq('id', id)
    .maybeSingle()
  if (error) return { ok: false, error: error.message }
  if (!projeto) return { ok: false, error: 'Evento não encontrado.' }

  const payload = buildPackingTemplatePayload({
    nome,
    descricao,
    projetoId: id,
    packing: packingRowsToSuggestionLines(
      (projeto as unknown as { packing_list?: PackingSuggestionPackingRow[] }).packing_list ?? [],
    ),
  })
  if (!payload.ok) return payload

  const { data, error: insertError } = await supabaseAdmin
    .from('packing_templates')
    .insert({
      nome: payload.data.nome,
      descricao: payload.data.descricao,
      origem_projeto_id: payload.data.origemProjetoId,
      linhas: payload.data.linhas,
      criado_por: auth.data.userId,
    })
    .select('id')
    .single()

  if (insertError) return { ok: false, error: insertError.message }
  return { ok: true, data: { id: data.id as string } }
}

export async function applyPackingSuggestion(
  projetoId: string,
  lines: ApplyPackingLineInput[],
): Promise<ActionResult<{ linhas: number; unidades: number }>> {
  const blocked = blockWrite<{ linhas: number; unidades: number }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const normalized = normalizeApplyPackingLines(lines)
  if (!normalized.ok) return normalized

  return persistPackingLines(projetoId, normalized.data)
}

async function loadPackingTemplates(): Promise<ActionResult<PackingTemplate[]>> {
  const { data, error } = await supabaseAdmin
    .from('packing_templates')
    .select('id, nome, descricao, origem_projeto_id, linhas, created_at')
    .order('updated_at', { ascending: false })
    .limit(24)

  if (error) return { ok: false, error: error.message }

  return {
    ok: true,
    data: ((data ?? []) as unknown as PackingTemplateRow[]).map((row) => ({
      id: row.id,
      nome: row.nome,
      descricao: row.descricao,
      origemProjetoId: row.origem_projeto_id,
      linhas: parsePackingTemplateLines(row.linhas),
      createdAt: row.created_at,
    })),
  }
}

function projectRowToSuggestionProject(
  row: PackingSuggestionProjectRow,
  packingRows: PackingSuggestionPackingRow[],
): PackingSuggestionProject {
  return {
    id: row.id,
    nome: row.nome,
    cliente: row.cliente,
    local: row.local,
    dataInicio: row.data_inicio,
    dataFim: row.data_fim,
    status: row.status,
    notas: row.notas,
    packing: packingRowsToSuggestionLines(packingRows),
  }
}

function packingRowItem(
  value: PackingSuggestionPackingRow['items'],
): PackingSuggestionItemRow | null {
  if (Array.isArray(value)) return value[0] ?? null
  return value
}

function packingRowsToSuggestionLines(rows: PackingSuggestionPackingRow[]) {
  return normalizeSuggestionLines(
    rows.map((row) => {
      const item = packingRowItem(row.items)
      return {
        itemId: row.item_id,
        codigoInterno: item?.codigo_interno ?? null,
        nome: item?.nome ?? 'Item removido',
        categoria: item?.categoria ?? 'ACESSORIO',
        quantidade: row.quantidade,
        observacao: row.notas,
      }
    }),
  )
}

function parsePackingTemplateLines(value: unknown) {
  if (!Array.isArray(value)) return []
  return normalizeSuggestionLines(
    value.map((row) => {
      const record = row && typeof row === 'object' ? (row as Record<string, unknown>) : {}
      return {
        itemId: String(record.itemId ?? record.item_id ?? ''),
        codigoInterno:
          typeof record.codigoInterno === 'string'
            ? record.codigoInterno
            : typeof record.codigo_interno === 'string'
              ? record.codigo_interno
              : null,
        nome: typeof record.nome === 'string' ? record.nome : 'Item do catálogo',
        categoria: typeof record.categoria === 'string' ? record.categoria : 'ACESSORIO',
        quantidade: Number(record.quantidade ?? 0),
        observacao: typeof record.observacao === 'string' ? record.observacao : null,
      }
    }),
  )
}

// ── Linhas do packing ───────────────────────────────────────────────────────

function mergePackingNotes(existing: string | null, incoming: string | null) {
  const next = incoming?.trim()
  if (!next) return existing
  if (!existing) return next
  if (existing.includes(next)) return existing
  return `${existing}\n${next}`
}

function normalizeApplyPackingLines(
  lines: ApplyPackingLineInput[],
): ActionResult<ApplyPackingLineInput[]> {
  if (!Array.isArray(lines) || lines.length === 0) {
    return { ok: false, error: 'Nenhuma linha aprovada para aplicar.' }
  }

  const byItem = new Map<string, ApplyPackingLineInput>()
  for (const line of lines) {
    const itemId = line.itemId?.trim()
    const quantidade = Number(line.quantidade)
    if (!itemId) return { ok: false, error: 'Item obrigatório para aplicar packing.' }
    if (!Number.isInteger(quantidade) || quantidade <= 0) {
      return { ok: false, error: 'Quantidade importada inválida.' }
    }

    const existing = byItem.get(itemId)
    if (existing) {
      existing.quantidade += quantidade
      existing.observacao = mergePackingNotes(existing.observacao ?? null, line.observacao ?? null)
      continue
    }

    byItem.set(itemId, { itemId, quantidade, observacao: line.observacao?.trim() || null })
  }

  return { ok: true, data: [...byItem.values()] }
}

async function persistPackingLines(
  projetoId: string,
  lines: ApplyPackingLineInput[],
): Promise<ActionResult<{ linhas: number; unidades: number }>> {
  const id = projetoId.trim()
  if (!id) return { ok: false, error: 'Evento obrigatório.' }

  const { data: projeto, error: projetoError } = await supabaseAdmin
    .from('projetos')
    .select('id')
    .eq('id', id)
    .maybeSingle()
  if (projetoError) return { ok: false, error: projetoError.message }
  if (!projeto) return { ok: false, error: 'Evento não encontrado.' }

  const itemIds = lines.map((line) => line.itemId)
  const { data: items, error: itemsError } = await supabaseAdmin
    .from('items')
    .select('id')
    .in('id', itemIds)
  if (itemsError) return { ok: false, error: itemsError.message }

  const foundIds = new Set((items ?? []).map((item) => item.id as string))
  const missingIds = itemIds.filter((itemId) => !foundIds.has(itemId))
  if (missingIds.length > 0) {
    return { ok: false, error: `Item do catálogo não encontrado: ${missingIds.join(', ')}.` }
  }

  const { data: existingRows, error: existingError } = await supabaseAdmin
    .from('packing_list')
    .select('id, item_id, quantidade, notas')
    .eq('projeto_id', id)
    .in('item_id', itemIds)
  if (existingError) return { ok: false, error: existingError.message }

  const existingByItem = new Map(
    (existingRows ?? []).map((row) => [
      row.item_id as string,
      {
        id: row.id as string,
        quantidade: row.quantidade as number,
        notas: row.notas as string | null,
      },
    ]),
  )

  const inserts: Array<{
    projeto_id: string
    item_id: string
    quantidade: number
    notas: string | null
  }> = []

  for (const line of lines) {
    const existing = existingByItem.get(line.itemId)
    if (!existing) {
      inserts.push({
        projeto_id: id,
        item_id: line.itemId,
        quantidade: line.quantidade,
        notas: line.observacao?.trim() || null,
      })
      continue
    }

    const { error } = await supabaseAdmin
      .from('packing_list')
      .update({
        quantidade: existing.quantidade + line.quantidade,
        notas: mergePackingNotes(existing.notas, line.observacao ?? null),
      })
      .eq('id', existing.id)
    if (error) return { ok: false, error: error.message }
  }

  if (inserts.length > 0) {
    const { error } = await supabaseAdmin.from('packing_list').insert(inserts)
    if (error) return { ok: false, error: error.message }
  }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${id}`)
  return {
    ok: true,
    data: {
      linhas: lines.length,
      unidades: lines.reduce((acc, line) => acc + line.quantidade, 0),
    },
  }
}

export async function addPackingItem(
  projetoId: string,
  itemId: string,
  quantidade: number,
): Promise<ActionResult<{ id: string }>> {
  const blocked = blockWrite<{ id: string }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  if (quantidade <= 0) return { ok: false, error: 'Quantidade precisa ser maior que zero.' }

  const { data: existing, error: selectError } = await supabaseAdmin
    .from('packing_list')
    .select('id, quantidade')
    .eq('projeto_id', projetoId)
    .eq('item_id', itemId)
    .maybeSingle()
  if (selectError) return { ok: false, error: selectError.message }

  if (existing) {
    const { error } = await supabaseAdmin
      .from('packing_list')
      .update({ quantidade: (existing.quantidade as number) + quantidade })
      .eq('id', existing.id)
    if (error) return { ok: false, error: error.message }
    revalidatePath('/projetos')
    revalidatePath(`/projetos/${projetoId}`)
    return { ok: true, data: { id: existing.id as string } }
  }

  const { data, error } = await supabaseAdmin
    .from('packing_list')
    .insert({ projeto_id: projetoId, item_id: itemId, quantidade })
    .select('id')
    .single()
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  revalidatePath(`/projetos/${projetoId}`)
  return { ok: true, data: { id: data.id as string } }
}

export async function removePackingItem(packingId: string): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  // `packing_allocations` cai junto por ON DELETE CASCADE, então remover a
  // linha libera as unidades sem deixar alocação órfã.
  const { error } = await supabaseAdmin.from('packing_list').delete().eq('id', packingId)
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  return { ok: true, data: undefined }
}

export async function updatePackingQty(
  packingId: string,
  quantidade: number,
): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  if (quantidade <= 0) return { ok: false, error: 'Quantidade inválida.' }

  // Reduzir a quantidade abaixo do número de unidades já alocadas deixaria a
  // linha inconsistente: o operador precisa liberar unidades antes.
  const { data: existing, error: selectError } = await supabaseAdmin
    .from('packing_list')
    .select('projeto_id, packing_allocations ( serial_id )')
    .eq('id', packingId)
    .maybeSingle()
  if (selectError) return { ok: false, error: selectError.message }
  if (!existing) return { ok: false, error: 'Linha de packing não encontrada.' }

  const row = existing as unknown as {
    projeto_id: string
    packing_allocations: AllocationEmbedRow[] | null
  }
  const alocados = allocationSerialIds(row.packing_allocations).length
  if (quantidade < alocados) {
    return {
      ok: false,
      error: `Libere unidades alocadas primeiro (${alocados} alocadas, quantidade pedida ${quantidade}).`,
    }
  }

  const { error } = await supabaseAdmin
    .from('packing_list')
    .update({ quantidade })
    .eq('id', packingId)
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  revalidatePath(`/projetos/${row.projeto_id}`)
  return { ok: true, data: undefined }
}

// ── Aluguel avulso ──────────────────────────────────────────────────────────

export async function addExternalRentalCoverage(
  packingId: string,
  input: ExternalRentalCoverageInput,
): Promise<ActionResult<{ id: string }>> {
  const blocked = blockWrite<{ id: string }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const normalized = normalizeExternalRentalInput(input, {
    id: randomUUID(),
    createdAt: new Date().toISOString(),
  })
  if (!normalized.ok) return normalized

  const { data: packing, error: packingError } = await supabaseAdmin
    .from('packing_list')
    .select('id, quantidade, alugueis_avulsos, projeto_id, packing_allocations ( serial_id )')
    .eq('id', packingId)
    .maybeSingle()

  if (packingError) return { ok: false, error: packingError.message }
  if (!packing) return { ok: false, error: 'Linha de packing não encontrada.' }

  const row = packing as unknown as {
    quantidade: number
    alugueis_avulsos: unknown
    projeto_id: string
    packing_allocations: AllocationEmbedRow[] | null
  }

  const existing = parseExternalRentalCoverages(row.alugueis_avulsos)
  const coverage = computePackingCoverage({
    qtdNecessaria: row.quantidade,
    qtdPropria: allocationSerialIds(row.packing_allocations).length,
    alugueisAvulsos: existing,
  })
  if (coverage.qtd_faltante <= 0) {
    return { ok: false, error: 'Linha já coberta. Remova cobertura antes de adicionar outra.' }
  }
  if (normalized.data.quantidade > coverage.qtd_faltante) {
    return {
      ok: false,
      error: `Quantidade avulsa maior que a falta atual (${coverage.qtd_faltante}).`,
    }
  }

  const { error: updateError } = await supabaseAdmin
    .from('packing_list')
    .update({ alugueis_avulsos: [...existing, normalized.data] })
    .eq('id', packingId)

  if (updateError) return { ok: false, error: updateError.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${row.projeto_id}`)
  return { ok: true, data: { id: normalized.data.id } }
}

export async function removeExternalRentalCoverage(
  packingId: string,
  rentalId: string,
): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const { data: packing, error: packingError } = await supabaseAdmin
    .from('packing_list')
    .select('alugueis_avulsos, projeto_id')
    .eq('id', packingId)
    .maybeSingle()

  if (packingError) return { ok: false, error: packingError.message }
  if (!packing) return { ok: false, error: 'Linha de packing não encontrada.' }

  const row = packing as unknown as { alugueis_avulsos: unknown; projeto_id: string }
  const existing = parseExternalRentalCoverages(row.alugueis_avulsos)
  const nextRentals = existing.filter((rental) => rental.id !== rentalId)
  if (nextRentals.length === existing.length) {
    return { ok: false, error: 'Aluguel avulso não encontrado.' }
  }

  const { error: updateError } = await supabaseAdmin
    .from('packing_list')
    .update({ alugueis_avulsos: nextRentals })
    .eq('id', packingId)

  if (updateError) return { ok: false, error: updateError.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${row.projeto_id}`)
  return { ok: true, data: undefined }
}

// ── Catálogo ────────────────────────────────────────────────────────────────

export async function searchItems(query: string): Promise<ActionResult<ItemSearchResult[]>> {
  const auth = await requireActionUser('viewer')
  if (!auth.ok) return auth

  const q = query.trim()
  let builder = supabaseAdmin
    .from('items')
    .select('id, codigo_interno, nome, categoria, quantidade_total')
    .order('nome', { ascending: true })
    .limit(12)

  // Sanitização mínima antes de montar o filtro: vírgula, parêntese e aspas são
  // sintaxe do PostgREST.
  if (q && /^[A-Za-z0-9._:\- ]+$/.test(q)) {
    builder = builder.or(`nome.ilike.%${q}%,codigo_interno.ilike.%${q}%`)
  } else if (q) {
    return { ok: false, error: 'Busca com caractere inválido.' }
  }

  const { data, error } = await builder
  if (error) return { ok: false, error: error.message }
  return { ok: true, data: (data ?? []) as unknown as ItemSearchResult[] }
}
