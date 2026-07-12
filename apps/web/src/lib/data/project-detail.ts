import 'server-only'
import { loadDemoProjectById } from '@/lib/data/demo'
import { withDemoFallback } from '@/lib/data/demo-mode'
import {
  EVENTO_COMERCIAL_BUCKET,
  parseEventoComercialRecord,
  type EventoComercialRecord,
} from '@/lib/evento-comercial-core'
import {
  calculateFichaChecklist,
  calculateFichaRecordCompleteness,
  parseEventoFichaRecord,
  type EventoFichaRecord,
} from '@/lib/evento-ficha-core'
import {
  computePackingCoverage,
  parseExternalRentalCoverages,
  type ExternalRentalCoverage,
} from '@/lib/external-rental-core'
import {
  buildCheckoutGate,
  type CheckoutGate,
  type CheckoutGateFicha,
} from '@/lib/checkout-gate-core'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria, Estado, StatusSerial } from '@/lib/types'
import type { ConflictRef, PackingStatus, StatusProjeto } from '@/lib/data/projects'

// Diferença vs. Projeto (lista): cada linha do packing aqui traz os seriais
// alocados hidratados (não só uuids), pra UI da tab Alocação conseguir
// renderizar chips por serial, e pra Checkin conseguir calcular a média de
// desgaste atual.

export type AllocatedSerialDetail = {
  id: string
  codigo_interno: string
  status: StatusSerial
  estado: Estado
  desgaste: number
}

export type ReturnPendingStatus = 'ABERTA' | 'ENCONTRADA' | 'MANUTENCAO' | 'BAIXA' | 'COBRANCA'

export type ReturnPendingResolution = {
  id: string
  projeto_id: string
  serial_number_id: string
  codigo_interno: string
  item_nome: string
  status_serial: StatusSerial
  status: ReturnPendingStatus
  observacao: string | null
  resolucao_observacao: string | null
  registrado_por: string
  resolvido_por: string | null
  created_at: string
  resolved_at: string | null
}

export type ProjectPackingLine = {
  id: string
  item_id: string
  codigo_interno: string
  item_nome: string
  categoria: Categoria
  notas: string | null
  qtd_necessaria: number
  qtd_alocada: number
  qtd_alugada_avulsa: number
  qtd_coberta: number
  qtd_faltante: number
  status: PackingStatus
  seriais_alocados: AllocatedSerialDetail[]
  alugueis_avulsos: ExternalRentalCoverage[]
  conflicts_with?: ConflictRef[]
}

export type ProjectDetail = {
  id: string
  nome: string
  cliente: string | null
  data_inicio: string
  data_fim: string
  local: string | null
  status: StatusProjeto
  notas: string | null
  comercial: EventoComercialRecord
  ficha_evento: EventoFichaRecord | null
  ficha_readiness: CheckoutGateFicha | null
  checkout_gate: CheckoutGate
  packing: ProjectPackingLine[]
  retorno_pendencias: ReturnPendingResolution[]
  itens_total: number
  itens_alocados: number
  readiness_pct: number
}

type PackingRow = {
  id: string
  item_id: string
  quantidade: number
  notas: string | null
  serial_numbers_designados: string[] | null
  alugueis_avulsos?: unknown
  items: {
    codigo_interno: string | null
    nome: string
    categoria: Categoria
  } | null
}

type ProjetoRow = {
  id: string
  nome: string
  cliente: string | null
  data_inicio: string
  data_fim: string
  local: string | null
  status: StatusProjeto
  notas: string | null
  comercial?: unknown
  ficha_evento?: unknown
  packing_list: PackingRow[]
}

type RetornoPendenciaRow = {
  id: string
  projeto_id: string
  serial_number_id: string
  status: ReturnPendingStatus
  observacao: string | null
  resolucao_observacao: string | null
  registrado_por: string
  resolvido_por: string | null
  created_at: string
  resolved_at: string | null
  serial_numbers:
    | {
        id: string
        codigo_interno: string
        status: StatusSerial
        items: { nome: string } | null
      }
    | null
}

function isMissingComercialColumn(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return message.includes('comercial') || error?.code === 'PGRST204'
}

function isMissingExternalRentalsColumn(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return message.includes('alugueis_avulsos') || error?.code === 'PGRST204'
}

function isMissingFichaColumn(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return message.includes('ficha_evento') || error?.code === 'PGRST204'
}

function isMissingReturnPendencias(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return (
    error?.code === '42P01' ||
    error?.code === 'PGRST205' ||
    message.includes('retorno_pendencias')
  )
}

function projectDetailSelect(
  includeComercial: boolean,
  includeExternalRentals: boolean,
  includeFicha: boolean,
) {
  return `id, nome, cliente, data_inicio, data_fim, local, status, notas,${
    includeComercial ? ' comercial,' : ''
  }${includeFicha ? ' ficha_evento,' : ''}
       packing_list (
         id, item_id, quantidade, notas, serial_numbers_designados${
           includeExternalRentals ? ', alugueis_avulsos' : ''
         },
         items ( codigo_interno, nome, categoria )
       )`
}

async function withCommercialDocumentHrefs(
  comercial: EventoComercialRecord,
): Promise<EventoComercialRecord> {
  const documentos = await Promise.all(
    comercial.documentos.map(async (doc) => {
      if (doc.origem === 'LINK') return { ...doc, href: doc.url }
      if (!doc.storage_path) return { ...doc, href: null }

      try {
        const { data, error } = await supabaseAdmin.storage
          .from(EVENTO_COMERCIAL_BUCKET)
          .createSignedUrl(doc.storage_path, 60 * 30)

        return { ...doc, href: error ? null : data.signedUrl }
      } catch {
        return { ...doc, href: null }
      }
    }),
  )

  return { ...comercial, documentos }
}

export async function loadProjectById(id: string): Promise<ProjectDetail | null> {
  return withDemoFallback(
    `project:${id}`,
    () => loadProjectByIdFromSupabase(id),
    () => loadDemoProjectById(id),
  )
}

async function loadProjectByIdFromSupabase(id: string): Promise<ProjectDetail | null> {
  const attempts = [
    { includeComercial: true, includeExternalRentals: true, includeFicha: true },
    { includeComercial: false, includeExternalRentals: true, includeFicha: true },
    { includeComercial: true, includeExternalRentals: false, includeFicha: true },
    { includeComercial: false, includeExternalRentals: false, includeFicha: true },
    { includeComercial: true, includeExternalRentals: true, includeFicha: false },
    { includeComercial: false, includeExternalRentals: true, includeFicha: false },
    { includeComercial: true, includeExternalRentals: false, includeFicha: false },
    { includeComercial: false, includeExternalRentals: false, includeFicha: false },
  ]

  let data: unknown = null
  let error: { message?: string; code?: string } | null = null

  for (const attempt of attempts) {
    const result = await supabaseAdmin
      .from('projetos')
      .select(
        projectDetailSelect(
          attempt.includeComercial,
          attempt.includeExternalRentals,
          attempt.includeFicha,
        ),
      )
      .eq('id', id)
      .maybeSingle()
    if (!result.error) {
      data = result.data
      error = null
      break
    }

    error = result.error
    if (
      (attempt.includeComercial && isMissingComercialColumn(result.error)) ||
      (attempt.includeExternalRentals && isMissingExternalRentalsColumn(result.error)) ||
      (attempt.includeFicha && isMissingFichaColumn(result.error))
    ) {
      continue
    }
    break
  }

  if (error) throw error
  if (!data) return null

  const row = data as unknown as ProjetoRow
  const comercial = await withCommercialDocumentHrefs(parseEventoComercialRecord(row.comercial))
  const ficha_evento = parseEventoFichaRecord(row.ficha_evento)
  const ficha_readiness = ficha_evento
    ? {
        ...calculateFichaRecordCompleteness(ficha_evento),
        ...calculateFichaChecklist(ficha_evento),
      }
    : null

  // Hidrata todos os serial_numbers_designados de uma vez só.
  const allSerialIds = new Set<string>()
  for (const pl of row.packing_list ?? []) {
    for (const sid of pl.serial_numbers_designados ?? []) {
      allSerialIds.add(sid)
    }
  }

  let serialMap = new Map<string, AllocatedSerialDetail>()
  if (allSerialIds.size > 0) {
    const { data: serials, error: serialErr } = await supabaseAdmin
      .from('serial_numbers')
      .select('id, codigo_interno, status, estado, desgaste')
      .in('id', Array.from(allSerialIds))

    if (serialErr) throw serialErr

    serialMap = new Map(
      (serials ?? []).map((s) => [
        s.id as string,
        {
          id: s.id as string,
          codigo_interno: s.codigo_interno as string,
          status: s.status as StatusSerial,
          estado: s.estado as Estado,
          desgaste: s.desgaste as number,
        },
      ]),
    )
  }

  const conflictMap = await loadProjectConflictMap(row)
  const retorno_pendencias = await loadReturnPendencias(row.id)

  const packing: ProjectPackingLine[] = (row.packing_list ?? []).map((pl) => {
    const seriais_alocados = (pl.serial_numbers_designados ?? [])
      .map((sid) => serialMap.get(sid))
      .filter((s): s is AllocatedSerialDetail => s !== undefined)
      .sort((a, b) => a.codigo_interno.localeCompare(b.codigo_interno))

    const alugueis_avulsos = parseExternalRentalCoverages(pl.alugueis_avulsos)
    const coverage = computePackingCoverage({
      qtdNecessaria: pl.quantidade,
      qtdPropria: seriais_alocados.length,
      alugueisAvulsos: alugueis_avulsos,
    })
    const conflicts_with = conflictMap.get(pl.item_id) ?? []
    return {
      id: pl.id,
      item_id: pl.item_id,
      codigo_interno: pl.items?.codigo_interno ?? '',
      item_nome: pl.items?.nome ?? 'Item removido',
      categoria: (pl.items?.categoria ?? 'ACESSORIO') as Categoria,
      notas: pl.notas ?? null,
      qtd_necessaria: pl.quantidade,
      qtd_alocada: coverage.qtd_propria,
      qtd_alugada_avulsa: coverage.qtd_alugada_avulsa,
      qtd_coberta: coverage.qtd_coberta,
      qtd_faltante: coverage.qtd_faltante,
      status: conflicts_with.length > 0 ? 'conflict' : coverage.status,
      seriais_alocados,
      alugueis_avulsos,
      conflicts_with,
    }
  })

  const itens_total = packing.reduce((a, p) => a + p.qtd_necessaria, 0)
  const itens_alocados = packing.reduce((a, p) => a + p.qtd_coberta, 0)
  const checkout_gate = buildCheckoutGate({
    status: row.status,
    ficha: ficha_readiness,
    packing,
  })

  return {
    id: row.id,
    nome: row.nome,
    cliente: row.cliente,
    data_inicio: row.data_inicio,
    data_fim: row.data_fim,
    local: row.local,
    status: row.status,
    notas: row.notas,
    comercial,
    ficha_evento,
    ficha_readiness,
    checkout_gate,
    packing,
    retorno_pendencias,
    itens_total,
    itens_alocados,
    readiness_pct: checkout_gate.readinessPct,
  }
}

async function loadReturnPendencias(projetoId: string): Promise<ReturnPendingResolution[]> {
  const { data, error } = await supabaseAdmin
    .from('retorno_pendencias')
    .select(
      `id, projeto_id, serial_number_id, status, observacao, resolucao_observacao,
       registrado_por, resolvido_por, created_at, resolved_at,
       serial_numbers (
         id, codigo_interno, status,
         items ( nome )
       )`,
    )
    .eq('projeto_id', projetoId)
    .order('created_at', { ascending: false })

  if (error) {
    if (isMissingReturnPendencias(error)) return []
    throw error
  }

  return ((data ?? []) as unknown as RetornoPendenciaRow[]).map((row) => ({
    id: row.id,
    projeto_id: row.projeto_id,
    serial_number_id: row.serial_number_id,
    codigo_interno: row.serial_numbers?.codigo_interno ?? 'Unidade removida',
    item_nome: row.serial_numbers?.items?.nome ?? 'Item removido',
    status_serial: row.serial_numbers?.status ?? 'RETORNANDO',
    status: row.status,
    observacao: row.observacao,
    resolucao_observacao: row.resolucao_observacao,
    registrado_por: row.registrado_por,
    resolvido_por: row.resolvido_por,
    created_at: row.created_at,
    resolved_at: row.resolved_at,
  }))
}

const ACTIVE_PROJECT_STATUSES: StatusProjeto[] = ['PLANEJAMENTO', 'CONFIRMADO', 'MONTAGEM', 'EM_CAMPO']

function rangesOverlap(aStart: string, aEnd: string, bStart: string, bEnd: string): boolean {
  return aStart <= bEnd && bStart <= aEnd
}

async function loadProjectConflictMap(row: ProjetoRow): Promise<Map<string, ConflictRef[]>> {
  const conflictMap = new Map<string, ConflictRef[]>()
  if (!ACTIVE_PROJECT_STATUSES.includes(row.status)) return conflictMap

  const itemIds = Array.from(new Set((row.packing_list ?? []).map((pl) => pl.item_id)))
  if (itemIds.length === 0) return conflictMap

  const { data, error } = await supabaseAdmin
    .from('packing_list')
    .select(
      `item_id, quantidade, serial_numbers_designados,
       projetos!inner ( id, nome, data_inicio, data_fim, status )`,
    )
    .neq('projeto_id', row.id)
    .in('item_id', itemIds)

  if (error) throw error

  type ConflictRow = {
    item_id: string
    quantidade: number
    serial_numbers_designados: string[] | null
    projetos: {
      id: string
      nome: string
      data_inicio: string
      data_fim: string
      status: StatusProjeto
    } | null
  }

  for (const raw of (data ?? []) as unknown as ConflictRow[]) {
    const project = raw.projetos
    if (!project) continue
    if (!ACTIVE_PROJECT_STATUSES.includes(project.status)) continue
    if (!rangesOverlap(row.data_inicio, row.data_fim, project.data_inicio, project.data_fim)) {
      continue
    }

    const conflicts = conflictMap.get(raw.item_id) ?? []
    conflicts.push({
      projeto_id: project.id,
      projeto_nome: project.nome,
      data_inicio: project.data_inicio,
      data_fim: project.data_fim,
      status: project.status,
      qtd_necessaria: raw.quantidade,
      qtd_alocada: raw.serial_numbers_designados?.length ?? 0,
    })
    conflictMap.set(raw.item_id, conflicts)
  }

  return conflictMap
}
