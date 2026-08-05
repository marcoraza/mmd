import 'server-only'

import { computePackingCoverage, parseExternalRentalCoverages } from '@/lib/external-rental-core'
import {
  ALLOCATION_ID_EMBED,
  allocationSerialIds,
  type AllocationEmbedRow,
} from '@/lib/data/allocations'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { EventoFichaRecord } from '@/lib/evento-ficha-core'
import type { StatusProjeto } from '@/lib/types'

// Shape congelado do contrato §4.2. Adicionar campo é aditivo e seguro;
// remover ou renomear quebra o decoder do iOS.
export type EventoResumo = {
  id: string
  nome: string
  cliente: string | null
  data_inicio: string
  data_fim: string
  local: string | null
  status: StatusProjeto
  notas: string | null
  ficha_evento: EventoFichaRecord | null
  packing: {
    linhas: number
    itens_total: number
    itens_alocados: number
    readiness_pct: number
  }
}

type PackingRow = {
  quantidade: number
  alugueis_avulsos: unknown
  packing_allocations: AllocationEmbedRow[] | null
}

type EventoRow = {
  id: string
  nome: string
  cliente: string | null
  data_inicio: string
  data_fim: string
  local: string | null
  status: StatusProjeto
  notas: string | null
  ficha_evento: EventoFichaRecord | null
  packing_list: PackingRow[]
}

// Select único: o fallback progressivo de colunas do legado (quatro tentativas
// removendo `ficha_evento` e `alugueis_avulsos` a cada PGRST204) era débito de
// migration desalinhada, não contrato. Contrato §4.4.
const EVENTO_RESUMO_SELECT = `id, nome, cliente, data_inicio, data_fim, local, status, notas, ficha_evento,
       packing_list (
         quantidade, alugueis_avulsos,
         ${ALLOCATION_ID_EMBED}
       )`

function rowToResumo(row: EventoRow): EventoResumo {
  const linhas = row.packing_list ?? []
  const itensTotal = linhas.reduce((acc, line) => acc + line.quantidade, 0)
  const itensAlocados = linhas.reduce(
    (acc, line) =>
      acc +
      computePackingCoverage({
        qtdNecessaria: line.quantidade,
        qtdPropria: allocationSerialIds(line.packing_allocations).length,
        alugueisAvulsos: parseExternalRentalCoverages(line.alugueis_avulsos),
      }).qtd_coberta,
    0,
  )

  return {
    id: row.id,
    nome: row.nome,
    cliente: row.cliente,
    data_inicio: row.data_inicio,
    data_fim: row.data_fim,
    local: row.local,
    status: row.status,
    notas: row.notas,
    ficha_evento: row.ficha_evento ?? null,
    packing: {
      linhas: linhas.length,
      itens_total: itensTotal,
      itens_alocados: itensAlocados,
      readiness_pct: itensTotal > 0 ? Math.round((itensAlocados / itensTotal) * 100) : 0,
    },
  }
}

export async function loadEventoResumo(id: string): Promise<EventoResumo | null> {
  const { data, error } = await supabaseAdmin
    .from('projetos')
    .select(EVENTO_RESUMO_SELECT)
    .eq('id', id)
    .maybeSingle()

  if (error) throw error
  return data ? rowToResumo(data as unknown as EventoRow) : null
}
