import 'server-only'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria } from '@/lib/types'

export type StatusProjeto =
  | 'PLANEJAMENTO'
  | 'CONFIRMADO'
  | 'EM_CAMPO'
  | 'FINALIZADO'
  | 'CANCELADO'

export type PackingStatus = 'ok' | 'partial' | 'missing' | 'conflict'

export type PackingItem = {
  id: string
  item_id: string
  codigo_interno: string
  nome: string
  categoria: Categoria
  qtd_necessaria: number
  qtd_alocada: number
  status: PackingStatus
  conflicts_with?: { projeto_id: string; projeto_nome: string }[]
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
  packing_list: PackingRow[]
}

function derivePackingStatus(alocada: number, necessaria: number): PackingStatus {
  if (alocada >= necessaria && necessaria > 0) return 'ok'
  if (alocada > 0) return 'partial'
  return 'missing'
}

function rangesOverlap(aStart: string, aEnd: string, bStart: string, bEnd: string): boolean {
  return aStart <= bEnd && bStart <= aEnd
}

function annotateConflicts(projetos: Projeto[]): Projeto[] {
  const ACTIVE: StatusProjeto[] = ['PLANEJAMENTO', 'CONFIRMADO', 'EM_CAMPO']
  const ativos = projetos.filter((p) => ACTIVE.includes(p.status))

  return projetos.map((projeto) => {
    if (!ACTIVE.includes(projeto.status)) return projeto
    const packing = projeto.packing.map((pi) => {
      const conflicts: { projeto_id: string; projeto_nome: string }[] = []
      for (const other of ativos) {
        if (other.id === projeto.id) continue
        if (!rangesOverlap(projeto.data_inicio, projeto.data_fim, other.data_inicio, other.data_fim)) {
          continue
        }
        const match = other.packing.find((op) => op.item_id === pi.item_id)
        if (match) conflicts.push({ projeto_id: other.id, projeto_nome: other.nome })
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
    const alocada = pl.serial_numbers_designados?.length ?? 0
    return {
      id: pl.id,
      item_id: pl.item_id,
      codigo_interno: pl.items?.codigo_interno ?? '',
      nome: pl.items?.nome ?? 'Item removido',
      categoria: (pl.items?.categoria ?? 'ACESSORIO') as Categoria,
      qtd_necessaria: pl.quantidade,
      qtd_alocada: alocada,
      status: derivePackingStatus(alocada, pl.quantidade),
    }
  })
  const itens_total = packing.reduce((a, p) => a + p.qtd_necessaria, 0)
  const itens_alocados = packing.reduce((a, p) => a + p.qtd_alocada, 0)
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
    readiness_pct: itens_total > 0 ? Math.round((itens_alocados / itens_total) * 100) : 0,
  }
}

export async function loadProjects(): Promise<ProjectsData> {
  const { data, error } = await supabaseAdmin
    .from('projetos')
    .select(
      `id, nome, cliente, data_inicio, data_fim, local, status, notas,
       packing_list (
         id, item_id, quantidade, serial_numbers_designados,
         items ( codigo_interno, nome, categoria )
       )`
    )
    .order('data_inicio', { ascending: true })

  if (error) throw error
  const projetos = ((data ?? []) as unknown as ProjetoRow[]).map(rowToProjeto)
  return { projetos: annotateConflicts(projetos) }
}
