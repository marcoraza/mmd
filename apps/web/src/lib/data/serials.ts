import 'server-only'
import {
  allocationRangesOverlap,
  serialAllocationState,
  sortAllocationCandidates,
  type AllocationTone,
} from '@/lib/allocation-core'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Estado, StatusSerial } from '@/lib/types'
import type { StatusProjeto } from '@/lib/data/projects'

// ─────────────────────────────────────────────────────────────────────────
// Tipos
// ─────────────────────────────────────────────────────────────────────────

export type SerialConflict = {
  projeto_id: string
  projeto_nome: string
  data_inicio: string
  data_fim: string
  status: StatusProjeto
}

export type AvailableSerial = {
  id: string
  codigo_interno: string
  status: StatusSerial
  estado: Estado
  desgaste: number
  localizacao: string | null
  last_moved_at: string | null
  selectable: boolean
  allocation_tone: AllocationTone
  allocation_label: string
  allocation_alert: string | null
  // Quando o serial já está em outro packing_list de projeto ativo com overlap
  // de datas. Não bloqueia a alocação, só sinaliza pra UI.
  conflicts_with: SerialConflict[]
}

export type AllocatedSerial = {
  id: string
  codigo_interno: string
  status: StatusSerial
  estado: Estado
  desgaste: number
}

// ─────────────────────────────────────────────────────────────────────────
// loadAvailableSerials
// ─────────────────────────────────────────────────────────────────────────
// Busca seriais disponíveis para alocação num item, ordenados por FIFO
// rotacional: quem ficou parado há mais tempo vem primeiro, pra forçar
// rotação saudável do estoque e impedir que os "top-tier" apodreçam por
// overuse.
//
// excludeIds: seriais que já estão alocados neste packing_list e não devem
// aparecer no picker (ou devem aparecer marcados como "já alocado aqui" na
// UI, mas essa lógica fica no componente).
//
// projetoContext: se fornecido, anotamos conflicts_with: seriais que
// aparecem em outros packing_list de projetos ativos com datas sobrepostas.

const ACTIVE_PROJECT_STATUSES: StatusProjeto[] = ['PLANEJAMENTO', 'CONFIRMADO', 'MONTAGEM', 'EM_CAMPO']

export async function loadAvailableSerials(
  itemId: string,
  opts: {
    excludeIds?: string[]
    projetoContext?: {
      projeto_id: string
      data_inicio: string
      data_fim: string
    }
    limit?: number
  } = {},
): Promise<AvailableSerial[]> {
  const excludeIds = opts.excludeIds ?? []
  const limit = Math.max(opts.limit ?? 50, 50)

  // Lista unidades do item, já excluindo as alocadas nesta linha.
  // A UI precisa enxergar bloqueadas para explicar manutenção/campo sem tentar
  // alocar em silêncio.
  let builder = supabaseAdmin
    .from('serial_numbers')
    .select('id, codigo_interno, status, estado, desgaste, localizacao')
    .eq('item_id', itemId)
    .limit(limit)

  if (excludeIds.length > 0) {
    builder = builder.not('id', 'in', `(${excludeIds.join(',')})`)
  }

  const { data: serials, error } = await builder
  if (error) throw error

  const serialIds = (serials ?? []).map((s) => s.id)
  if (serialIds.length === 0) return []

  // Busca last_moved_at (max timestamp de movimentações) pra ordenar FIFO.
  const { data: movs, error: movErr } = await supabaseAdmin
    .from('movimentacoes')
    .select('serial_number_id, timestamp')
    .in('serial_number_id', serialIds)
    .order('timestamp', { ascending: false })

  if (movErr) throw movErr

  const lastMovedMap = new Map<string, string>()
  for (const row of movs ?? []) {
    const sid = row.serial_number_id as string
    if (!lastMovedMap.has(sid)) {
      lastMovedMap.set(sid, row.timestamp as string)
    }
  }

  // Conflict detection: seriais alocados em outros projetos ativos com overlap.
  const conflictMap = new Map<string, SerialConflict[]>()
  if (opts.projetoContext) {
    const ctx = opts.projetoContext
    const { data: conflictRows, error: confErr } = await supabaseAdmin
      .from('packing_list')
      .select(
        `serial_numbers_designados,
         projetos!inner ( id, nome, data_inicio, data_fim, status )`,
      )
      .neq('projeto_id', ctx.projeto_id)
      .not('serial_numbers_designados', 'is', null)

    if (confErr) throw confErr

    type ConflictRow = {
      serial_numbers_designados: string[] | null
      projetos: {
        id: string
        nome: string
        data_inicio: string
        data_fim: string
        status: StatusProjeto
      } | null
    }

    for (const raw of (conflictRows ?? []) as unknown as ConflictRow[]) {
      const p = raw.projetos
      if (!p) continue
      if (!ACTIVE_PROJECT_STATUSES.includes(p.status)) continue
      if (!allocationRangesOverlap(ctx.data_inicio, ctx.data_fim, p.data_inicio, p.data_fim)) {
        continue
      }
      for (const sid of raw.serial_numbers_designados ?? []) {
        if (!serialIds.includes(sid)) continue
        const arr = conflictMap.get(sid) ?? []
        arr.push({
          projeto_id: p.id,
          projeto_nome: p.nome,
          data_inicio: p.data_inicio,
          data_fim: p.data_fim,
          status: p.status,
        })
        conflictMap.set(sid, arr)
      }
    }
  }

  const result: AvailableSerial[] = (serials ?? []).map((s) => {
    const conflicts = conflictMap.get(s.id) ?? []
    const state = serialAllocationState(s.status as StatusSerial, conflicts.length)
    return {
      id: s.id,
      codigo_interno: s.codigo_interno,
      status: s.status as StatusSerial,
      estado: s.estado,
      desgaste: s.desgaste,
      localizacao: s.localizacao,
      last_moved_at: lastMovedMap.get(s.id) ?? null,
      selectable: state.selectable,
      allocation_tone: state.tone,
      allocation_label: state.label,
      allocation_alert: state.alert,
      conflicts_with: conflicts,
    }
  })

  return sortAllocationCandidates(result)
}

// ─────────────────────────────────────────────────────────────────────────
// loadSerialsByIds
// ─────────────────────────────────────────────────────────────────────────
// Hidrata uuids de serial_numbers_designados em objetos ricos (para as
// chips mostrarem codigo_interno + desgaste + status).

export async function loadSerialsByIds(ids: string[]): Promise<AllocatedSerial[]> {
  if (ids.length === 0) return []
  const { data, error } = await supabaseAdmin
    .from('serial_numbers')
    .select('id, codigo_interno, status, estado, desgaste')
    .in('id', ids)
    .order('codigo_interno', { ascending: true })
  if (error) throw error
  return (data ?? []) as AllocatedSerial[]
}
