import 'server-only'
import { loadDemoProjects } from '@/lib/data/demo'
import { withDemoFallback } from '@/lib/data/demo-mode'
import { buildCheckoutGate } from '@/lib/checkout-gate-core'
import {
  calculateFichaChecklist,
  calculateFichaRecordCompleteness,
  parseEventoFichaRecord,
} from '@/lib/evento-ficha-core'
import { computePackingCoverage, parseExternalRentalCoverages } from '@/lib/external-rental-core'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria } from '@/lib/types'

export type StatusProjeto =
  | 'PLANEJAMENTO'
  | 'CONFIRMADO'
  | 'MONTAGEM'
  | 'EM_CAMPO'
  | 'FINALIZADO'
  | 'CANCELADO'

export type PackingStatus = 'ok' | 'partial' | 'missing' | 'conflict'

export type ConflictRef = {
  projeto_id: string
  projeto_nome: string
  data_inicio: string
  data_fim: string
  status: StatusProjeto
  qtd_necessaria: number
  qtd_alocada: number
}

export type PackingItem = {
  id: string
  item_id: string
  codigo_interno: string
  nome: string
  categoria: Categoria
  qtd_necessaria: number
  qtd_alocada: number
  qtd_alugada_avulsa: number
  qtd_coberta: number
  qtd_faltante: number
  status: PackingStatus
  conflicts_with?: ConflictRef[]
}

export type Projeto = {
  id: string
  nome: string
  cliente: string | null
  data_inicio: string
  data_fim: string
  local: string | null
  status: StatusProjeto
  notas: string | null
  packing: PackingItem[]
  itens_count: number
  itens_total: number
  itens_alocados: number
  readiness_pct: number
}

export type ProjectsData = {
  projetos: Projeto[]
}

type PackingRow = {
  id: string
  item_id: string
  quantidade: number
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
  ficha_evento?: unknown
  packing_list: PackingRow[]
}

function rangesOverlap(aStart: string, aEnd: string, bStart: string, bEnd: string): boolean {
  return aStart <= bEnd && bStart <= aEnd
}

function annotateConflicts(projetos: Projeto[]): Projeto[] {
  const ACTIVE: StatusProjeto[] = ['PLANEJAMENTO', 'CONFIRMADO', 'MONTAGEM', 'EM_CAMPO']
  const ativos = projetos.filter((p) => ACTIVE.includes(p.status))

  return projetos.map((projeto) => {
    if (!ACTIVE.includes(projeto.status)) return projeto
    const packing = projeto.packing.map((pi) => {
      const conflicts: ConflictRef[] = []
      for (const other of ativos) {
        if (other.id === projeto.id) continue
        if (
          !rangesOverlap(projeto.data_inicio, projeto.data_fim, other.data_inicio, other.data_fim)
        ) {
          continue
        }
        const match = other.packing.find((op) => op.item_id === pi.item_id)
        if (match) {
          conflicts.push({
            projeto_id: other.id,
            projeto_nome: other.nome,
            data_inicio: other.data_inicio,
            data_fim: other.data_fim,
            status: other.status,
            qtd_necessaria: match.qtd_necessaria,
            qtd_alocada: match.qtd_alocada,
          })
        }
      }
      if (conflicts.length === 0) return pi
      return {
        ...pi,
        status: 'conflict' as PackingStatus,
        conflicts_with: conflicts,
      }
    })
    return { ...projeto, packing }
  })
}

function rowToProjeto(row: ProjetoRow): Projeto {
  const packing: PackingItem[] = (row.packing_list ?? []).map((pl) => {
    const alugueisAvulsos = parseExternalRentalCoverages(pl.alugueis_avulsos)
    const coverage = computePackingCoverage({
      qtdNecessaria: pl.quantidade,
      qtdPropria: pl.serial_numbers_designados?.length ?? 0,
      alugueisAvulsos,
    })
    return {
      id: pl.id,
      item_id: pl.item_id,
      codigo_interno: pl.items?.codigo_interno ?? '',
      nome: pl.items?.nome ?? 'Item removido',
      categoria: (pl.items?.categoria ?? 'ACESSORIO') as Categoria,
      qtd_necessaria: pl.quantidade,
      qtd_alocada: coverage.qtd_propria,
      qtd_alugada_avulsa: coverage.qtd_alugada_avulsa,
      qtd_coberta: coverage.qtd_coberta,
      qtd_faltante: coverage.qtd_faltante,
      status: coverage.status,
    }
  })
  const itens_total = packing.reduce((a, p) => a + p.qtd_necessaria, 0)
  const itens_alocados = packing.reduce((a, p) => a + p.qtd_coberta, 0)
  const fichaEvento = parseEventoFichaRecord(row.ficha_evento)
  const fichaReadiness = fichaEvento
    ? {
        ...calculateFichaRecordCompleteness(fichaEvento),
        ...calculateFichaChecklist(fichaEvento),
      }
    : null
  const packingReadiness = itens_total > 0 ? Math.round((itens_alocados / itens_total) * 100) : 0
  const checkoutGate = fichaReadiness
    ? buildCheckoutGate({
        status: row.status,
        ficha: fichaReadiness,
        packing: packing.map((line) => ({
          id: line.id,
          item_nome: line.nome,
          qtd_necessaria: line.qtd_necessaria,
          qtd_alocada: line.qtd_alocada,
          qtd_alugada_avulsa: line.qtd_alugada_avulsa,
          qtd_coberta: line.qtd_coberta,
          qtd_faltante: line.qtd_faltante,
          status: line.status,
          conflicts_with: line.conflicts_with,
        })),
      })
    : null

  return {
    id: row.id,
    nome: row.nome,
    cliente: row.cliente,
    data_inicio: row.data_inicio,
    data_fim: row.data_fim,
    local: row.local,
    status: row.status,
    notas: row.notas,
    packing,
    itens_count: packing.length,
    itens_total,
    itens_alocados,
    readiness_pct: checkoutGate?.readinessPct ?? packingReadiness,
  }
}

export async function loadProjects(): Promise<ProjectsData> {
  return withDemoFallback('projects', loadProjectsFromSupabase, loadDemoProjects)
}

async function loadProjectsFromSupabase(): Promise<ProjectsData> {
  let { data, error } = await queryProjects(true, true)

  if (error && (isMissingExternalRentalsColumn(error) || isMissingFichaEventoColumn(error))) {
    for (const attempt of [
      { includeExternalRentals: false, includeFicha: true },
      { includeExternalRentals: true, includeFicha: false },
      { includeExternalRentals: false, includeFicha: false },
    ]) {
      const fallback = await queryProjects(attempt.includeExternalRentals, attempt.includeFicha)
      data = fallback.data
      error = fallback.error
      if (!error) break
    }
  }

  if (error) throw error
  const projetos = ((data ?? []) as unknown as ProjetoRow[]).map(rowToProjeto)
  return { projetos: annotateConflicts(projetos) }
}

function isMissingExternalRentalsColumn(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return message.includes('alugueis_avulsos') || error?.code === 'PGRST204'
}

function isMissingFichaEventoColumn(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return message.includes('ficha_evento') || error?.code === 'PGRST204'
}

function queryProjects(includeExternalRentals: boolean, includeFicha: boolean) {
  return supabaseAdmin
    .from('projetos')
    .select(
      `id, nome, cliente, data_inicio, data_fim, local, status, notas,${
        includeFicha ? ' ficha_evento,' : ''
      }
       packing_list (
         id, item_id, quantidade, serial_numbers_designados${
           includeExternalRentals ? ', alugueis_avulsos' : ''
         },
         items ( codigo_interno, nome, categoria )
       )`,
    )
    .order('data_inicio', { ascending: true })
}
