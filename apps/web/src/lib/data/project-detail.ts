import 'server-only'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria, Estado, StatusSerial } from '@/lib/types'
import type {
  PackingStatus,
  StatusProjeto,
} from '@/lib/data/projects'

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

export type ProjectPackingLine = {
  id: string
  item_id: string
  codigo_interno: string
  item_nome: string
  categoria: Categoria
  qtd_necessaria: number
  qtd_alocada: number
  status: PackingStatus
  seriais_alocados: AllocatedSerialDetail[]
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
  packing: ProjectPackingLine[]
  itens_total: number
  itens_alocados: number
  readiness_pct: number
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

export async function loadProjectById(id: string): Promise<ProjectDetail | null> {
  const { data, error } = await supabaseAdmin
    .from('projetos')
    .select(
      `id, nome, cliente, data_inicio, data_fim, local, status, notas,
       packing_list (
         id, item_id, quantidade, serial_numbers_designados,
         items ( codigo_interno, nome, categoria )
       )`
    )
    .eq('id', id)
    .maybeSingle()

  if (error) throw error
  if (!data) return null

  const row = data as unknown as ProjetoRow

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
      ])
    )
  }

  const packing: ProjectPackingLine[] = (row.packing_list ?? []).map((pl) => {
    const seriais_alocados = (pl.serial_numbers_designados ?? [])
      .map((sid) => serialMap.get(sid))
      .filter((s): s is AllocatedSerialDetail => s !== undefined)
      .sort((a, b) => a.codigo_interno.localeCompare(b.codigo_interno))

    const alocada = seriais_alocados.length
    return {
      id: pl.id,
      item_id: pl.item_id,
      codigo_interno: pl.items?.codigo_interno ?? '',
      item_nome: pl.items?.nome ?? 'Item removido',
      categoria: (pl.items?.categoria ?? 'ACESSORIO') as Categoria,
      qtd_necessaria: pl.quantidade,
      qtd_alocada: alocada,
      status: derivePackingStatus(alocada, pl.quantidade),
      seriais_alocados,
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
    itens_total,
    itens_alocados,
    readiness_pct: itens_total > 0 ? Math.round((itens_alocados / itens_total) * 100) : 0,
  }
}
