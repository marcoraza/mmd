import 'server-only'

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
import {
  ALLOCATION_DETAIL_EMBED,
  ALLOCATION_ID_EMBED,
  allocationSerialDetails,
  allocationSerialIds,
  type AllocatedSerialDetail,
  type AllocationEmbedRow,
} from '@/lib/data/allocations'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria, PackingStatus, StatusProjeto, StatusSerial } from '@/lib/types'
import type { ConflictRef } from '@/lib/data/projects'

export type { AllocatedSerialDetail }

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
  alugueis_avulsos: unknown
  items: {
    codigo_interno: string | null
    nome: string
    categoria: Categoria
  } | null
  packing_allocations: AllocationEmbedRow[] | null
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
  comercial: unknown
  ficha_evento: unknown
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
  serial_numbers: {
    id: string
    codigo_interno: string
    status: StatusSerial
    items: { nome: string } | null
  } | null
}

const PROJECT_DETAIL_SELECT = `id, nome, cliente, data_inicio, data_fim, local, status, notas, comercial, ficha_evento,
       packing_list (
         id, item_id, quantidade, notas, alugueis_avulsos,
         items ( codigo_interno, nome, categoria ),
         ${ALLOCATION_DETAIL_EMBED}
       )`

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
  const { data, error } = await supabaseAdmin
    .from('projetos')
    .select(PROJECT_DETAIL_SELECT)
    .eq('id', id)
    .maybeSingle()

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

  const conflictMap = await loadProjectConflictMap(row)
  const retorno_pendencias = await loadReturnPendencias(row.id)

  const packing: ProjectPackingLine[] = (row.packing_list ?? []).map((pl) => {
    // Já vem hidratado do embed `packing_allocations -> serial_numbers`; o
    // legado precisava de uma segunda query para resolver os uuids do array.
    const seriais_alocados = allocationSerialDetails(pl.packing_allocations)
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

  if (error) throw error

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

const ACTIVE_PROJECT_STATUSES: StatusProjeto[] = [
  'PLANEJAMENTO',
  'CONFIRMADO',
  'MONTAGEM',
  'EM_CAMPO',
]

function rangesOverlap(aStart: string, aEnd: string, bStart: string, bEnd: string): boolean {
  return aStart <= bEnd && bStart <= aEnd
}

type ConflictRow = {
  item_id: string
  quantidade: number
  packing_allocations: AllocationEmbedRow[] | null
  projetos: {
    id: string
    nome: string
    data_inicio: string
    data_fim: string
    status: StatusProjeto
  } | null
}

async function loadProjectConflictMap(row: ProjetoRow): Promise<Map<string, ConflictRef[]>> {
  const conflictMap = new Map<string, ConflictRef[]>()
  if (!ACTIVE_PROJECT_STATUSES.includes(row.status)) return conflictMap

  const itemIds = Array.from(new Set((row.packing_list ?? []).map((pl) => pl.item_id)))
  if (itemIds.length === 0) return conflictMap

  const { data, error } = await supabaseAdmin
    .from('packing_list')
    .select(
      `item_id, quantidade,
       ${ALLOCATION_ID_EMBED},
       projetos!inner ( id, nome, data_inicio, data_fim, status )`,
    )
    .neq('projeto_id', row.id)
    .in('item_id', itemIds)

  if (error) throw error

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
      qtd_alocada: allocationSerialIds(raw.packing_allocations).length,
    })
    conflictMap.set(raw.item_id, conflicts)
  }

  return conflictMap
}
