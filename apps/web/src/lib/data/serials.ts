import 'server-only'
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
  estado: Estado
  desgaste: number
  localizacao: string | null
  last_moved_at: string | null
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

const ACTIVE_PROJECT_STATUSES: StatusProjeto[] = [
  'PLANEJAMENTO',
  'CONFIRMADO',
  'EM_CAMPO',
]

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
  } = {}
): Promise<AvailableSerial[]> {
  const excludeIds = opts.excludeIds ?? []
  const limit = opts.limit ?? 50

  // Seriais DISPONIVEL do item, já excluindo os que queremos esconder.
  let builder = supabaseAdmin
    .from('serial_numbers')
    .select('id, codigo_interno, estado, desgaste, localizacao')
    .eq('item_id', itemId)
    .eq('status', 'DISPONIVEL')
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
         projetos!inner ( id, nome, data_inicio, data_fim, status )`
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
      if (!rangesOverlap(ctx.data_inicio, ctx.data_fim, p.data_inicio, p.data_fim)) {
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

  const result: AvailableSerial[] = (serials ?? []).map((s) => ({
    id: s.id,
    codigo_interno: s.codigo_interno,
    estado: s.estado,
    desgaste: s.desgaste,
    localizacao: s.localizacao,
    last_moved_at: lastMovedMap.get(s.id) ?? null,
    conflicts_with: conflictMap.get(s.id) ?? [],
  }))

  // FIFO rotacional: last_moved_at ASC (nulls first = nunca se moveu), depois
  // desgaste ASC (desgastados primeiro, pra emparelhar rotação com reparo).
  result.sort((a, b) => {
    if (a.last_moved_at === null && b.last_moved_at !== null) return -1
    if (a.last_moved_at !== null && b.last_moved_at === null) return 1
    if (a.last_moved_at !== null && b.last_moved_at !== null) {
      const cmp = a.last_moved_at.localeCompare(b.last_moved_at)
      if (cmp !== 0) return cmp
    }
    return a.desgaste - b.desgaste
  })

  return result
}

function rangesOverlap(aStart: string, aEnd: string, bStart: string, bEnd: string): boolean {
  return aStart <= bEnd && bStart <= aEnd
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
