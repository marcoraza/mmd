import 'server-only'

import {
  allocationRangesOverlap,
  serialAllocationState,
  sortAllocationCandidates,
  type AllocationTone,
} from '@/lib/allocation-core'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Estado, StatusProjeto, StatusSerial } from '@/lib/types'

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
  // Unidade já alocada em outro Evento ativo com sobreposição de datas. Não
  // bloqueia a alocação, só sinaliza.
  conflicts_with: SerialConflict[]
}

export type AllocatedSerial = {
  id: string
  codigo_interno: string
  status: StatusSerial
  estado: Estado
  desgaste: number
}

const ACTIVE_PROJECT_STATUSES: StatusProjeto[] = [
  'PLANEJAMENTO',
  'CONFIRMADO',
  'MONTAGEM',
  'EM_CAMPO',
]

type ConflictAllocationRow = {
  serial_id: string
  packing_list: {
    projeto_id: string
    projetos: {
      id: string
      nome: string
      data_inicio: string
      data_fim: string
      status: StatusProjeto
    } | null
  } | null
}

// Busca unidades candidatas à alocação de um item, ordenadas por FIFO
// rotacional (quem ficou parado mais tempo primeiro). A UI precisa enxergar as
// bloqueadas para explicar manutenção/campo em vez de sumir com a linha.
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

  const serialIds = (serials ?? []).map((s) => s.id as string)
  if (serialIds.length === 0) return []

  const { data: movs, error: movErr } = await supabaseAdmin
    .from('movimentacoes')
    .select('serial_number_id, timestamp')
    .in('serial_number_id', serialIds)
    .order('timestamp', { ascending: false })

  if (movErr) throw movErr

  const lastMovedMap = new Map<string, string>()
  for (const row of movs ?? []) {
    const sid = row.serial_number_id as string
    if (!lastMovedMap.has(sid)) lastMovedMap.set(sid, row.timestamp as string)
  }

  // Conflito de agenda: a unidade já está alocada em outro Evento ativo cujo
  // período se sobrepõe. Com `packing_allocations` a pergunta é direta (uma
  // linha por unidade), sem varrer arrays de uuid de todo o packing.
  const conflictMap = new Map<string, SerialConflict[]>()
  if (opts.projetoContext) {
    const ctx = opts.projetoContext
    const { data: conflictRows, error: confErr } = await supabaseAdmin
      .from('packing_allocations')
      .select(
        `serial_id,
         packing_list!inner (
           projeto_id,
           projetos!inner ( id, nome, data_inicio, data_fim, status )
         )`,
      )
      .in('serial_id', serialIds)

    if (confErr) throw confErr

    for (const raw of (conflictRows ?? []) as unknown as ConflictAllocationRow[]) {
      const projeto = raw.packing_list?.projetos
      if (!projeto) continue
      if (raw.packing_list?.projeto_id === ctx.projeto_id) continue
      if (!ACTIVE_PROJECT_STATUSES.includes(projeto.status)) continue
      if (
        !allocationRangesOverlap(
          ctx.data_inicio,
          ctx.data_fim,
          projeto.data_inicio,
          projeto.data_fim,
        )
      ) {
        continue
      }

      const arr = conflictMap.get(raw.serial_id) ?? []
      arr.push({
        projeto_id: projeto.id,
        projeto_nome: projeto.nome,
        data_inicio: projeto.data_inicio,
        data_fim: projeto.data_fim,
        status: projeto.status,
      })
      conflictMap.set(raw.serial_id, arr)
    }
  }

  const result: AvailableSerial[] = (serials ?? []).map((s) => {
    const conflicts = conflictMap.get(s.id as string) ?? []
    const state = serialAllocationState(s.status as StatusSerial, conflicts.length)
    return {
      id: s.id as string,
      codigo_interno: s.codigo_interno as string,
      status: s.status as StatusSerial,
      estado: s.estado as Estado,
      desgaste: s.desgaste as number,
      localizacao: (s.localizacao as string | null) ?? null,
      last_moved_at: lastMovedMap.get(s.id as string) ?? null,
      selectable: state.selectable,
      allocation_tone: state.tone,
      allocation_label: state.label,
      allocation_alert: state.alert,
      conflicts_with: conflicts,
    }
  })

  return sortAllocationCandidates(result)
}

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
