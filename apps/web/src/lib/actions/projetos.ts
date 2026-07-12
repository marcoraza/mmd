'use server'

import { randomUUID } from 'node:crypto'
import { revalidatePath } from 'next/cache'
import { requireActionUser } from '@/lib/action-auth'
import {
  loadDemoCatalog,
  loadDemoProjectById,
  loadDemoProjects,
  loadDemoUnits,
  searchDemoItems,
} from '@/lib/data/demo'
import { getDataMode, isDemoFallbackEnabled, isWriteBlocked } from '@/lib/data/demo-mode'
import { supabaseAdmin } from '@/lib/supabase-server'
import {
  normalizeEventoFichaInput,
  type EventoFichaInput,
  type NormalizedEventoFicha,
} from '@/lib/evento-ficha-core'
import {
  EVENTO_COMERCIAL_BUCKET,
  EVENTO_COMERCIAL_MAX_FILE_BYTES,
  normalizeEventoComercialInput,
  parseEventoComercialRecord,
  safeCommercialFileName,
  type DocumentoComercialTipo,
  type UploadedEventoComercialDocumento,
} from '@/lib/evento-comercial-core'
import type { StatusProjeto } from '@/lib/data/projects'
import { loadAvailableSerials } from '@/lib/data/serials'
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
  type PackingSuggestionLine,
  type PackingSuggestionProject,
  type PackingSuggestionWorkspace,
  type PackingTemplate,
} from '@/lib/packing-suggestion-core'
import {
  pickAutoAllocationCandidates,
  serialAllocationState,
  sortAllocationCandidates,
} from '@/lib/allocation-core'
import {
  computePackingCoverage,
  normalizeExternalRentalInput,
  parseExternalRentalCoverages,
} from '@/lib/external-rental-core'

export type CreateProjetoInput = {
  nome: string
  cliente: string | null
  data_inicio: string
  data_fim: string
  local: string | null
  status: StatusProjeto
  notas: string | null
}

export type ActionResult<T = void> = { ok: true; data: T } | { ok: false; error: string }

function blockWrite<T = void>(): ActionResult<T> | null {
  if (!isWriteBlocked()) return null
  return { ok: false, error: 'Modo somente leitura: alterações não são salvas.' }
}

export async function createProjeto(
  input: CreateProjetoInput,
): Promise<ActionResult<{ id: string }>> {
  const blocked = blockWrite<{ id: string }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const nome = input.nome.trim()
  if (!nome) return { ok: false, error: 'Nome obrigatório.' }
  if (input.data_fim < input.data_inicio) {
    return { ok: false, error: 'Data final antes da inicial.' }
  }

  const { data, error } = await supabaseAdmin
    .from('projetos')
    .insert({
      nome,
      cliente: input.cliente?.trim() || null,
      data_inicio: input.data_inicio,
      data_fim: input.data_fim,
      local: input.local?.trim() || null,
      status: input.status,
      notas: input.notas?.trim() || null,
    })
    .select('id')
    .single()

  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  return { ok: true, data: { id: data.id } }
}

type ProjetoFichaPayload = NormalizedEventoFicha['projeto']

function isMissingFichaEventoColumn(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return message.includes('ficha_evento') || error?.code === 'PGRST204'
}

function isMissingComercialColumn(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return message.includes('comercial') || error?.code === 'PGRST204'
}

function projetoFichaBasePayload(payload: ProjetoFichaPayload) {
  return {
    nome: payload.nome,
    cliente: payload.cliente,
    data_inicio: payload.data_inicio,
    data_fim: payload.data_fim,
    local: payload.local,
    status: payload.status,
    notas: payload.notas,
  }
}

async function persistProjetoFicha(
  projetoId: string | null,
  payload: ProjetoFichaPayload,
): Promise<ActionResult<{ id: string }>> {
  if (projetoId) {
    const { data, error } = await supabaseAdmin
      .from('projetos')
      .update(payload)
      .eq('id', projetoId)
      .select('id')
      .maybeSingle()

    if (error && isMissingFichaEventoColumn(error)) {
      const fallback = await supabaseAdmin
        .from('projetos')
        .update(projetoFichaBasePayload(payload))
        .eq('id', projetoId)
        .select('id')
        .maybeSingle()
      if (fallback.error) return { ok: false, error: fallback.error.message }
      if (!fallback.data) return { ok: false, error: 'Evento não encontrado.' }
      return { ok: true, data: { id: fallback.data.id } }
    }

    if (error) return { ok: false, error: error.message }
    if (!data) return { ok: false, error: 'Evento não encontrado.' }
    return { ok: true, data: { id: data.id } }
  }

  const { data, error } = await supabaseAdmin.from('projetos').insert(payload).select('id').single()

  if (error && isMissingFichaEventoColumn(error)) {
    const fallback = await supabaseAdmin
      .from('projetos')
      .insert(projetoFichaBasePayload(payload))
      .select('id')
      .single()
    if (fallback.error) return { ok: false, error: fallback.error.message }
    return { ok: true, data: { id: fallback.data.id } }
  }

  if (error) return { ok: false, error: error.message }
  return { ok: true, data: { id: data.id } }
}

export async function saveEventoFicha(
  input: EventoFichaInput,
): Promise<ActionResult<{ id: string; completenessPct: number }>> {
  const normalized = normalizeEventoFichaInput(input, new Date().toISOString())
  if (!normalized.ok) return normalized

  const blocked = blockWrite<{ id: string; completenessPct: number }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const result = await persistProjetoFicha(normalized.data.projetoId, normalized.data.projeto)
  if (!result.ok) return result

  revalidatePath('/ficha-evento')
  revalidatePath('/projetos')
  revalidatePath(`/projetos/${result.data.id}`)
  return {
    ok: true,
    data: {
      id: result.data.id,
      completenessPct: normalized.data.completeness.pct,
    },
  }
}

function formText(formData: FormData, key: string) {
  const value = formData.get(key)
  return typeof value === 'string' ? value : ''
}

function formFile(formData: FormData, key: string): File | null {
  const value = formData.get(key)
  if (!value || typeof value === 'string') return null
  return value.size > 0 ? value : null
}

function commercialMimeType(file: File) {
  if (file.type) return file.type
  const name = file.name.toLowerCase()
  if (name.endsWith('.pdf')) return 'application/pdf'
  if (name.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  }
  if (name.endsWith('.doc')) return 'application/msword'
  if (name.endsWith('.png')) return 'image/png'
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg'
  return 'application/octet-stream'
}

const COMERCIAL_ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/msword',
  'image/png',
  'image/jpeg',
])

async function uploadEventoComercialFile(
  projetoId: string,
  tipo: DocumentoComercialTipo,
  file: File,
): Promise<ActionResult<UploadedEventoComercialDocumento>> {
  if (file.size > EVENTO_COMERCIAL_MAX_FILE_BYTES) {
    return { ok: false, error: 'Anexo comercial precisa ter no máximo 10 MB.' }
  }

  const mimeType = commercialMimeType(file)
  if (!COMERCIAL_ALLOWED_MIME_TYPES.has(mimeType)) {
    return { ok: false, error: 'Anexo comercial precisa ser PDF, DOC, DOCX, PNG ou JPG.' }
  }

  const filename = safeCommercialFileName(file.name)
  const storagePath = `${projetoId}/${tipo.toLowerCase()}/${randomUUID()}-${filename}`
  const bytes = new Uint8Array(await file.arrayBuffer())

  const { error } = await supabaseAdmin.storage
    .from(EVENTO_COMERCIAL_BUCKET)
    .upload(storagePath, bytes, {
      contentType: mimeType,
      upsert: false,
    })

  if (error) return { ok: false, error: error.message }

  return {
    ok: true,
    data: {
      tipo,
      filename,
      storage_path: storagePath,
      mime_type: mimeType,
      tamanho_bytes: file.size,
    },
  }
}

export async function saveEventoComercial(
  formData: FormData,
): Promise<ActionResult<{ id: string; permiteOperacaoEstoque: boolean; readinessPct: number }>> {
  const projetoId = formText(formData, 'projetoId')

  const blocked = blockWrite<{
    id: string
    permiteOperacaoEstoque: boolean
    readinessPct: number
  }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const { data: existing, error: existingError } = await supabaseAdmin
    .from('projetos')
    .select('comercial')
    .eq('id', projetoId)
    .maybeSingle()

  if (existingError && isMissingComercialColumn(existingError)) {
    return {
      ok: false,
      error: 'Migration comercial ainda não aplicada no banco.',
    }
  }
  if (existingError) return { ok: false, error: existingError.message }
  if (!existing) return { ok: false, error: 'Evento não encontrado.' }

  const existingRecord = parseEventoComercialRecord((existing as { comercial?: unknown }).comercial)

  const input = {
    projetoId,
    status: formText(formData, 'status'),
    orcamentoUrl: formText(formData, 'orcamentoUrl'),
    contratoUrl: formText(formData, 'contratoUrl'),
    observacoes: formText(formData, 'observacoes'),
  }

  const preflight = normalizeEventoComercialInput(input, existingRecord.documentos)
  if (!preflight.ok) return preflight

  const uploadedDocs: UploadedEventoComercialDocumento[] = []
  const orcamentoFile = formFile(formData, 'orcamentoFile')
  const contratoFile = formFile(formData, 'contratoFile')

  if (orcamentoFile) {
    const upload = await uploadEventoComercialFile(projetoId, 'ORCAMENTO', orcamentoFile)
    if (!upload.ok) return upload
    uploadedDocs.push(upload.data)
  }

  if (contratoFile) {
    const upload = await uploadEventoComercialFile(projetoId, 'CONTRATO', contratoFile)
    if (!upload.ok) return upload
    uploadedDocs.push(upload.data)
  }

  const normalized = normalizeEventoComercialInput(
    input,
    existingRecord.documentos,
    uploadedDocs,
    new Date().toISOString(),
  )
  if (!normalized.ok) return normalized

  const { error } = await supabaseAdmin
    .from('projetos')
    .update({ comercial: normalized.data.comercial })
    .eq('id', normalized.data.projetoId)

  if (error) return { ok: false, error: error.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${normalized.data.projetoId}`)
  return {
    ok: true,
    data: {
      id: normalized.data.projetoId,
      permiteOperacaoEstoque: normalized.data.comercial.permite_operacao_estoque,
      readinessPct: normalized.data.comercial.readiness_pct,
    },
  }
}

export async function deleteProjeto(id: string): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('admin')
  if (!auth.ok) return auth

  // Proteção: projeto EM_CAMPO tem seriais lá fora. Deletar sem check-in
  // deixa estoque em estado inconsistente (serial.status=EM_CAMPO mas
  // projeto sumiu). Bloqueia até ter rotina de cancelamento com devolução.
  //
  // Predicate-in-DELETE pra fechar race com updateProjetoStatus concorrente:
  // Postgres avalia o neq na hora do write, nenhuma janela entre SELECT e DELETE.
  const { data: deleted, error } = await supabaseAdmin
    .from('projetos')
    .delete()
    .eq('id', id)
    .neq('status', 'EM_CAMPO')
    .select('id')
  if (error) return { ok: false, error: error.message }
  if (!deleted || deleted.length === 0) {
    // Ou o projeto não existe, ou está EM_CAMPO. Checa qual caso pra mensagem útil.
    const { data: projeto } = await supabaseAdmin
      .from('projetos')
      .select('status')
      .eq('id', id)
      .maybeSingle()
    if (!projeto) return { ok: false, error: 'Projeto não encontrado.' }
    return { ok: false, error: 'Check-in obrigatório antes de deletar.' }
  }
  revalidatePath('/projetos')
  return { ok: true, data: undefined }
}

export async function updateProjetoStatus(
  id: string,
  status: StatusProjeto,
): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const { error } = await supabaseAdmin.from('projetos').update({ status }).eq('id', id)
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  return { ok: true, data: undefined }
}

type PackingCatalogRow = {
  id: string
  codigo_interno: string | null
  nome: string
  categoria: string
  subcategoria: string | null
  marca: string | null
  modelo: string | null
  quantidade_total: number | null
}

export type ApplyPackingLineInput = {
  itemId: string
  quantidade: number
  observacao?: string | null
}

export type ApplyPackingImportLineInput = ApplyPackingLineInput
export type ApplyPackingSuggestionLineInput = ApplyPackingLineInput

export async function previewPackingImport(
  formData: FormData,
): Promise<ActionResult<PackingImportPreview>> {
  const file = formFile(formData, 'file')
  if (!file) return { ok: false, error: 'Selecione uma planilha para importar.' }

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
  lines: ApplyPackingImportLineInput[],
): Promise<ActionResult<{ linhas: number; unidades: number }>> {
  const blocked = blockWrite<{ linhas: number; unidades: number }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const normalized = normalizeApplyPackingImportLines(lines)
  if (!normalized.ok) return normalized

  return persistPackingLines(projetoId, normalized.data)
}

export async function loadPackingSuggestionWorkspace(
  projetoId: string,
): Promise<ActionResult<PackingSuggestionWorkspace>> {
  const id = projetoId.trim()
  if (!id) return { ok: false, error: 'Evento obrigatório.' }

  if (getDataMode() === 'demo') {
    return loadDemoPackingSuggestionWorkspace(id)
  }

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

  const templatesResult = await loadPackingTemplates()
  if (!templatesResult.ok) return templatesResult

  return {
    ok: true,
    data: createPackingSuggestionWorkspace({
      target: projectRowToSuggestionProject(target, []),
      historicalProjects: ((history ?? []) as unknown as PackingSuggestionProjectRow[]).map((row) =>
        projectRowToSuggestionProject(row, row.packing_list ?? []),
      ),
      templates: templatesResult.data,
    }),
  }
}

export async function savePackingTemplateFromProject(
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

  if (insertError) {
    if (isMissingPackingTemplatesTable(insertError)) {
      return { ok: false, error: 'Tabela de templates ainda não aplicada no Supabase.' }
    }
    return { ok: false, error: insertError.message }
  }

  return { ok: true, data: { id: data.id as string } }
}

export async function applyPackingSuggestion(
  projetoId: string,
  lines: ApplyPackingSuggestionLineInput[],
): Promise<ActionResult<{ linhas: number; unidades: number }>> {
  const blocked = blockWrite<{ linhas: number; unidades: number }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const normalized = normalizeApplyPackingImportLines(lines)
  if (!normalized.ok) return normalized

  return persistPackingLines(projetoId, normalized.data)
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

type PackingSuggestionPackingRow = {
  item_id: string
  quantidade: number
  notas: string | null
  items: PackingSuggestionItemRow | PackingSuggestionItemRow[] | null
}

type PackingSuggestionItemRow = {
  codigo_interno: string | null
  nome: string
  categoria: string
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

async function loadPackingTemplates(): Promise<ActionResult<PackingTemplate[]>> {
  const { data, error } = await supabaseAdmin
    .from('packing_templates')
    .select('id, nome, descricao, origem_projeto_id, linhas, created_at')
    .order('updated_at', { ascending: false })
    .limit(24)

  if (error) {
    if (isMissingPackingTemplatesTable(error)) return { ok: true, data: [] }
    return { ok: false, error: error.message }
  }

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

function isMissingPackingTemplatesTable(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return message.includes('packing_templates') || error?.code === 'PGRST205'
}

function isMissingExternalRentalsColumn(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return message.includes('alugueis_avulsos') || error?.code === 'PGRST204'
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

function packingRowItem(
  value: PackingSuggestionPackingRow['items'],
): PackingSuggestionItemRow | null {
  if (Array.isArray(value)) return value[0] ?? null
  return value
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

function demoLine(
  itemId: string,
  codigoInterno: string,
  nome: string,
  categoria: string,
  quantidade: number,
  observacao: string | null = null,
): PackingSuggestionLine {
  return { itemId, codigoInterno, nome, categoria, quantidade, observacao }
}

function loadDemoPackingSuggestionWorkspace(
  projetoId: string,
): ActionResult<PackingSuggestionWorkspace> {
  const detail = loadDemoProjectById(projetoId)
  const project = loadDemoProjects().projetos.find((row) => row.id === projetoId)
  if (!detail || !project) return { ok: false, error: 'Evento não encontrado.' }

  const target: PackingSuggestionProject = {
    id: detail.id,
    nome: detail.nome,
    cliente: detail.cliente,
    local: detail.local,
    dataInicio: detail.data_inicio,
    dataFim: detail.data_fim,
    status: detail.status,
    notas: detail.notas,
    packing: detail.packing.map((line) => ({
      itemId: line.item_id,
      codigoInterno: line.codigo_interno,
      nome: line.item_nome,
      categoria: line.categoria,
      quantidade: line.qtd_necessaria,
      observacao: line.notas,
    })),
  }

  const history: PackingSuggestionProject[] = [
    {
      id: 'demo-history-casamento-jardim',
      nome: `${detail.nome} anterior`,
      cliente: detail.cliente,
      local: detail.local,
      dataInicio: '2026-05-02',
      dataFim: '2026-05-03',
      status: 'FINALIZADO',
      notas: 'Histórico demo para sugestão revisável.',
      packing: [
        demoLine('demo-item-beam-7r', 'MMD-ILU-0001', 'Moving Beam 7R 230W', 'ILUMINACAO', 6),
        demoLine('demo-item-par-led', 'MMD-ILU-0002', 'PAR LED RGBW Outdoor', 'ILUMINACAO', 10),
        demoLine('demo-item-caixa-prx', 'MMD-AUD-0001', 'Caixa Ativa JBL PRX815', 'AUDIO', 4),
        demoLine('demo-item-regua', 'MMD-ENE-0001', 'Régua de Energia 12 canais', 'ENERGIA', 2),
      ],
    },
  ]

  const templates: PackingTemplate[] = [
    {
      id: 'demo-template-casamento-padrao',
      nome: 'Casamento padrão MMD',
      descricao: 'Base salva para evento social médio',
      origemProjetoId: 'demo-history-casamento-jardim',
      linhas: [
        demoLine('demo-item-beam-7r', 'MMD-ILU-0001', 'Moving Beam 7R 230W', 'ILUMINACAO', 4),
        demoLine('demo-item-par-led', 'MMD-ILU-0002', 'PAR LED RGBW Outdoor', 'ILUMINACAO', 8),
        demoLine('demo-item-caixa-prx', 'MMD-AUD-0001', 'Caixa Ativa JBL PRX815', 'AUDIO', 2),
      ],
      createdAt: NOW_FOR_DEMO_TEMPLATE,
    },
  ]

  return {
    ok: true,
    data: createPackingSuggestionWorkspace({
      target,
      historicalProjects: history,
      templates,
    }),
  }
}

const NOW_FOR_DEMO_TEMPLATE = '2026-06-23T00:00:00.000Z'

async function loadPackingImportCatalog(): Promise<ActionResult<PackingImportCatalogItem[]>> {
  if (getDataMode() === 'demo') {
    return {
      ok: true,
      data: loadDemoCatalog().items.map((item) => ({
        id: item.id,
        codigo_interno: item.codigo_interno,
        nome: item.nome,
        categoria: item.categoria,
        subcategoria: item.subcategoria,
        marca: item.marca,
        modelo: item.modelo,
        quantidade_total: item.quantidade_total,
      })),
    }
  }

  const auth = await requireActionUser('viewer')
  if (!auth.ok) return auth

  const { data, error } = await supabaseAdmin
    .from('items')
    .select('id, codigo_interno, nome, categoria, subcategoria, marca, modelo, quantidade_total')
    .order('nome', { ascending: true })
  if (error) return { ok: false, error: error.message }

  return { ok: true, data: (data ?? []).map((item) => item as PackingCatalogRow) }
}

function normalizeApplyPackingImportLines(
  lines: ApplyPackingImportLineInput[],
): ActionResult<ApplyPackingImportLineInput[]> {
  if (!Array.isArray(lines) || lines.length === 0) {
    return { ok: false, error: 'Nenhuma linha aprovada para aplicar.' }
  }

  const byItem = new Map<string, ApplyPackingImportLineInput>()
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

    byItem.set(itemId, {
      itemId,
      quantidade,
      observacao: line.observacao?.trim() || null,
    })
  }

  return { ok: true, data: [...byItem.values()] }
}

function mergePackingNotes(existing: string | null, incoming: string | null) {
  const next = incoming?.trim()
  if (!next) return existing
  if (!existing) return next
  if (existing.includes(next)) return existing
  return `${existing}\n${next}`
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
      .update({ quantidade: existing.quantidade + quantidade })
      .eq('id', existing.id)
    if (error) return { ok: false, error: error.message }
    revalidatePath('/projetos')
    return { ok: true, data: { id: existing.id } }
  }

  const { data, error } = await supabaseAdmin
    .from('packing_list')
    .insert({ projeto_id: projetoId, item_id: itemId, quantidade })
    .select('id')
    .single()
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  return { ok: true, data: { id: data.id } }
}

export async function removePackingItem(packingId: string): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

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

  // Proteção: reduzir qty abaixo do número de seriais já alocados deixa
  // alocação inconsistente. O operador precisa soltar seriais primeiro.
  const { data: existing, error: selErr } = await supabaseAdmin
    .from('packing_list')
    .select('serial_numbers_designados, projeto_id')
    .eq('id', packingId)
    .maybeSingle()
  if (selErr) return { ok: false, error: selErr.message }
  if (!existing) return { ok: false, error: 'Packing não encontrado.' }

  const alocados = existing.serial_numbers_designados?.length ?? 0
  if (quantidade < alocados) {
    return {
      ok: false,
      error: `Remova seriais alocados primeiro (${alocados} alocados, qty pedida ${quantidade}).`,
    }
  }

  const { error } = await supabaseAdmin
    .from('packing_list')
    .update({ quantidade })
    .eq('id', packingId)
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  revalidatePath(`/projetos/${existing.projeto_id}`)
  return { ok: true, data: undefined }
}

export type ExternalRentalCoverageInput = {
  fornecedor: string
  quantidade: number
  observacao: string
}

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
    .select('id, quantidade, serial_numbers_designados, alugueis_avulsos, projeto_id')
    .eq('id', packingId)
    .maybeSingle()

  if (packingError) {
    if (isMissingExternalRentalsColumn(packingError)) {
      return { ok: false, error: 'Migration de aluguel avulso ainda não aplicada no banco.' }
    }
    return { ok: false, error: packingError.message }
  }
  if (!packing) return { ok: false, error: 'Packing não encontrado.' }

  const existing = parseExternalRentalCoverages(
    (packing as { alugueis_avulsos?: unknown }).alugueis_avulsos,
  )
  const coverage = computePackingCoverage({
    qtdNecessaria: packing.quantidade as number,
    qtdPropria: ((packing.serial_numbers_designados ?? []) as string[]).length,
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

  const nextRentals = [...existing, normalized.data]
  const { error: updateError } = await supabaseAdmin
    .from('packing_list')
    .update({ alugueis_avulsos: nextRentals })
    .eq('id', packingId)

  if (updateError) return { ok: false, error: updateError.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${packing.projeto_id}`)
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

  if (packingError) {
    if (isMissingExternalRentalsColumn(packingError)) {
      return { ok: false, error: 'Migration de aluguel avulso ainda não aplicada no banco.' }
    }
    return { ok: false, error: packingError.message }
  }
  if (!packing) return { ok: false, error: 'Packing não encontrado.' }

  const existing = parseExternalRentalCoverages(
    (packing as { alugueis_avulsos?: unknown }).alugueis_avulsos,
  )
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
  revalidatePath(`/projetos/${packing.projeto_id}`)
  return { ok: true, data: undefined }
}

export type ItemSearchResult = {
  id: string
  codigo_interno: string | null
  nome: string
  categoria: string
  quantidade_total: number
}

// ─────────────────────────────────────────────────────────────────────────
// Alocação de seriais
// ─────────────────────────────────────────────────────────────────────────

// Helper para o SerialPicker: lista candidatos disponíveis pra um packing
// específico, com conflict detection no contexto do projeto.
export async function listAvailableSerialsForPacking(
  packingId: string,
): Promise<ActionResult<Awaited<ReturnType<typeof loadAvailableSerials>>>> {
  if (getDataMode() === 'demo') {
    return listDemoAvailableSerialsForPacking(packingId)
  }

  const auth = await requireActionUser('viewer')
  if (!auth.ok) return auth

  const { data: packing, error: pErr } = await supabaseAdmin
    .from('packing_list')
    .select('item_id, serial_numbers_designados, projeto_id, projetos ( data_inicio, data_fim )')
    .eq('id', packingId)
    .maybeSingle()
  if (pErr) return { ok: false, error: pErr.message }
  if (!packing) return { ok: false, error: 'Packing não encontrado.' }

  type Shape = {
    item_id: string
    serial_numbers_designados: string[] | null
    projeto_id: string
    projetos: { data_inicio: string; data_fim: string } | null
  }
  const p = packing as unknown as Shape

  const candidates = await loadAvailableSerials(p.item_id, {
    excludeIds: p.serial_numbers_designados ?? [],
    projetoContext: p.projetos
      ? {
          projeto_id: p.projeto_id,
          data_inicio: p.projetos.data_inicio,
          data_fim: p.projetos.data_fim,
        }
      : undefined,
  })
  return { ok: true, data: sortAllocationCandidates(candidates) }
}

function listDemoAvailableSerialsForPacking(
  packingId: string,
): ActionResult<Awaited<ReturnType<typeof loadAvailableSerials>>> {
  const detail = loadDemoProjects()
    .projetos.map((project) => loadDemoProjectById(project.id))
    .find((project) => project?.packing.some((line) => line.id === packingId))
  const line = detail?.packing.find((packingLine) => packingLine.id === packingId)
  if (!detail || !line) return { ok: false, error: 'Packing não encontrado.' }

  const allocatedIds = new Set(line.seriais_alocados.map((serial) => serial.id))
  const candidates = loadDemoUnits()
    .filter((unit) => unit.item_id === line.item_id && !allocatedIds.has(unit.id))
    .map((unit) => {
      const conflicts =
        unit.id === 'demo-serial-beam-01'
          ? [
              {
                projeto_id: 'demo-proj-feira',
                projeto_nome: 'Tech SP 2026',
                data_inicio: '2026-06-18',
                data_fim: '2026-06-20',
                status: 'PLANEJAMENTO' as StatusProjeto,
              },
            ]
          : []
      const state = serialAllocationState(unit.status, conflicts.length)
      return {
        id: unit.id,
        codigo_interno: unit.codigo_interno,
        status: unit.status,
        estado: unit.estado,
        desgaste: unit.desgaste,
        localizacao: unit.localizacao,
        last_moved_at: unit.updated_at,
        selectable: state.selectable,
        allocation_tone: state.tone,
        allocation_label: state.label,
        allocation_alert: state.alert,
        conflicts_with: conflicts,
      }
    })

  return { ok: true, data: candidates }
}

// Lê o packing_list (com projeto contexto), chama loadAvailableSerials com
// exclude = já alocados, pega os N primeiros (N = quantidade - alocados), e
// faz UPDATE union.
//
// Idempotente: se já está 100%, no-op. Nunca sobrescreve alocação manual.
//
// TODO(concurrency): SELECT pool + UPDATE são 3 round-trips não-atômicos. Dois
// autoAllocate simultâneos em packings do mesmo item podem ver o mesmo serial
// DISPONIVEL e ambos gravar o mesmo UUID em packings diferentes. Mitigar quando
// volume crescer: mover pra RPC plpgsql com SELECT ... FOR UPDATE SKIP LOCKED,
// ou adicionar exclusion constraint via trigger em unnest(serial_numbers_designados).
// No MVP, o volume baixo reduz o risco enquanto a RPC atômica não entra.
export async function autoAllocate(packingId: string): Promise<ActionResult<{ alocados: number }>> {
  const blocked = blockWrite<{ alocados: number }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const { data: packing, error: pErr } = await supabaseAdmin
    .from('packing_list')
    .select(
      'id, item_id, quantidade, serial_numbers_designados, projeto_id, projetos ( data_inicio, data_fim )',
    )
    .eq('id', packingId)
    .maybeSingle()
  if (pErr) return { ok: false, error: pErr.message }
  if (!packing) return { ok: false, error: 'Packing não encontrado.' }

  type PackingShape = {
    id: string
    item_id: string
    quantidade: number
    serial_numbers_designados: string[] | null
    projeto_id: string
    projetos: { data_inicio: string; data_fim: string } | null
  }
  const p = packing as unknown as PackingShape

  const existing = p.serial_numbers_designados ?? []
  const missing = p.quantidade - existing.length
  if (missing <= 0) return { ok: true, data: { alocados: 0 } }

  const candidates = await loadAvailableSerials(p.item_id, {
    excludeIds: existing,
    projetoContext: p.projetos
      ? {
          projeto_id: p.projeto_id,
          data_inicio: p.projetos.data_inicio,
          data_fim: p.projetos.data_fim,
        }
      : undefined,
    limit: Math.max(missing * 3, 50),
  })

  const selected = pickAutoAllocationCandidates(candidates, missing)
  if (selected.length === 0) return { ok: true, data: { alocados: 0 } }

  const novoArray = [...existing, ...selected.map((c) => c.id)]
  const { error: upErr } = await supabaseAdmin
    .from('packing_list')
    .update({ serial_numbers_designados: novoArray })
    .eq('id', packingId)
  if (upErr) return { ok: false, error: upErr.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${p.projeto_id}`)
  return { ok: true, data: { alocados: selected.length } }
}

// Substitui o array de alocação inteiro. Revalida cada serial: deve estar
// DISPONIVEL, ou já neste mesmo packing (re-alocação é idempotente). Bloqueia
// se algum serial está em outro status (EM_CAMPO, MANUTENCAO, etc).
export async function setAllocation(packingId: string, serialIds: string[]): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const uniqueIds = Array.from(new Set(serialIds))

  const { data: packing, error: pErr } = await supabaseAdmin
    .from('packing_list')
    .select('id, item_id, quantidade, serial_numbers_designados, projeto_id')
    .eq('id', packingId)
    .maybeSingle()
  if (pErr) return { ok: false, error: pErr.message }
  if (!packing) return { ok: false, error: 'Packing não encontrado.' }

  if (uniqueIds.length > packing.quantidade) {
    return {
      ok: false,
      error: `Quantidade pedida (${packing.quantidade}) menor que seriais selecionados (${uniqueIds.length}).`,
    }
  }

  const currentSet = new Set<string>((packing.serial_numbers_designados ?? []) as string[])
  const newSet = new Set<string>(uniqueIds)

  if (uniqueIds.length > 0) {
    const { data: serials, error: sErr } = await supabaseAdmin
      .from('serial_numbers')
      .select('id, item_id, status')
      .in('id', uniqueIds)
    if (sErr) return { ok: false, error: sErr.message }

    // Presence check: UUIDs que não existem em serial_numbers devem ser rejeitados.
    // packing_list.serial_numbers_designados é uuid[] sem FK por elemento, então o
    // UPDATE aceitaria lixo silenciosamente e inflaria readiness_pct.
    const gotSet = new Set((serials ?? []).map((s) => s.id))
    const missingIds = uniqueIds.filter((id) => !gotSet.has(id))
    if (missingIds.length > 0) {
      return { ok: false, error: `Seriais inexistentes: ${missingIds.join(', ')}.` }
    }

    for (const s of serials ?? []) {
      if (s.item_id !== packing.item_id) {
        return { ok: false, error: `Serial ${s.id} não pertence ao item do packing.` }
      }
      if (s.status !== 'DISPONIVEL' && !currentSet.has(s.id)) {
        return { ok: false, error: `Serial ${s.id} não está DISPONIVEL (status: ${s.status}).` }
      }
    }
  }

  // Symmetric check: seriais sendo REMOVIDOS devem estar DISPONIVEL. Remover
  // um EM_CAMPO via setAllocation deixa serial fora do packing mas com status
  // em campo, que é o mesmo estado inconsistente que deleteProjeto bloqueia.
  const removedIds = Array.from(currentSet).filter((id) => !newSet.has(id))
  if (removedIds.length > 0) {
    const { data: removedSerials, error: rErr } = await supabaseAdmin
      .from('serial_numbers')
      .select('id, status')
      .in('id', removedIds)
    if (rErr) return { ok: false, error: rErr.message }
    for (const s of removedSerials ?? []) {
      if (s.status !== 'DISPONIVEL') {
        return {
          ok: false,
          error: `Serial ${s.id} em status ${s.status}, requer check-in antes de remover do packing.`,
        }
      }
    }
  }

  const { error: upErr } = await supabaseAdmin
    .from('packing_list')
    .update({ serial_numbers_designados: uniqueIds })
    .eq('id', packingId)
  if (upErr) return { ok: false, error: upErr.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${packing.projeto_id}`)
  return { ok: true, data: undefined }
}

// Remove um serial do array de alocação do packing. Usado pelo X da chip.
export async function releaseSerial(packingId: string, serialId: string): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const { data: packing, error: pErr } = await supabaseAdmin
    .from('packing_list')
    .select('serial_numbers_designados, projeto_id')
    .eq('id', packingId)
    .maybeSingle()
  if (pErr) return { ok: false, error: pErr.message }
  if (!packing) return { ok: false, error: 'Packing não encontrado.' }

  // Bloqueia release de serial que não está DISPONIVEL. Se está EM_CAMPO/MANUTENCAO,
  // o operador tem que passar pelo fluxo de check-in, não pela chip-X.
  const { data: serial, error: sErr } = await supabaseAdmin
    .from('serial_numbers')
    .select('status')
    .eq('id', serialId)
    .maybeSingle()
  if (sErr) return { ok: false, error: sErr.message }
  if (serial && serial.status !== 'DISPONIVEL') {
    return {
      ok: false,
      error: `Serial em status ${serial.status}, requer check-in antes de remover do packing.`,
    }
  }

  const novoArray = (packing.serial_numbers_designados ?? []).filter(
    (id: string) => id !== serialId,
  )
  const { error: upErr } = await supabaseAdmin
    .from('packing_list')
    .update({ serial_numbers_designados: novoArray })
    .eq('id', packingId)
  if (upErr) return { ok: false, error: upErr.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${packing.projeto_id}`)
  return { ok: true, data: undefined }
}

export async function searchItems(query: string): Promise<ItemSearchResult[]> {
  if (getDataMode() === 'demo') return searchDemoItems(query)

  const auth = await requireActionUser('viewer')
  if (!auth.ok) return []

  const q = query.trim()
  let builder = supabaseAdmin
    .from('items')
    .select('id, codigo_interno, nome, categoria, quantidade_total')
    .order('nome', { ascending: true })
    .limit(12)
  if (q) {
    builder = builder.or(`nome.ilike.%${q}%,codigo_interno.ilike.%${q}%`)
  }
  const { data, error } = await builder
  if (error) {
    if (isDemoFallbackEnabled()) return searchDemoItems(query)
    throw error
  }
  return (data ?? []) as ItemSearchResult[]
}
