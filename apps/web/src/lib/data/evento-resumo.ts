import 'server-only'

import { loadDemoProjectById } from '@/lib/data/demo'
import { getDataMode, isDemoFallbackEnabled } from '@/lib/data/demo-mode'
import { computePackingCoverage, parseExternalRentalCoverages } from '@/lib/external-rental-core'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { EventoFichaRecord } from '@/lib/evento-ficha-core'
import type { StatusProjeto } from '@/lib/types'

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
  serial_numbers_designados: string[] | null
  alugueis_avulsos?: unknown
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
  ficha_evento?: EventoFichaRecord | null
  packing_list: PackingRow[]
}

function isMissingFichaEventoColumn(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return message.includes('ficha_evento') || error?.code === 'PGRST204'
}

function rowToResumo(row: EventoRow): EventoResumo {
  const itensTotal = (row.packing_list ?? []).reduce((acc, line) => acc + line.quantidade, 0)
  const itensAlocados = (row.packing_list ?? []).reduce(
    (acc, line) =>
      acc +
      computePackingCoverage({
        qtdNecessaria: line.quantidade,
        qtdPropria: line.serial_numbers_designados?.length ?? 0,
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
      linhas: row.packing_list?.length ?? 0,
      itens_total: itensTotal,
      itens_alocados: itensAlocados,
      readiness_pct: itensTotal > 0 ? Math.round((itensAlocados / itensTotal) * 100) : 0,
    },
  }
}

function demoResumo(id: string): EventoResumo | null {
  const projeto = loadDemoProjectById(id)
  if (!projeto) return null
  return {
    id: projeto.id,
    nome: projeto.nome,
    cliente: projeto.cliente,
    data_inicio: projeto.data_inicio,
    data_fim: projeto.data_fim,
    local: projeto.local,
    status: projeto.status,
    notas: projeto.notas,
    ficha_evento: null,
    packing: {
      linhas: projeto.packing.length,
      itens_total: projeto.itens_total,
      itens_alocados: projeto.itens_alocados,
      readiness_pct: projeto.readiness_pct,
    },
  }
}

async function queryEventoResumo(
  id: string,
  includeFicha: boolean,
  includeExternalRentals: boolean,
) {
  const packingColumns = `quantidade, serial_numbers_designados${
    includeExternalRentals ? ', alugueis_avulsos' : ''
  }`
  const columns = includeFicha
    ? `id, nome, cliente, data_inicio, data_fim, local, status, notas, ficha_evento,
       packing_list ( ${packingColumns} )`
    : `id, nome, cliente, data_inicio, data_fim, local, status, notas,
       packing_list ( ${packingColumns} )`

  return supabaseAdmin.from('projetos').select(columns).eq('id', id).maybeSingle()
}

function isMissingExternalRentalsColumn(error: { message?: string; code?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return message.includes('alugueis_avulsos') || error?.code === 'PGRST204'
}

export async function loadEventoResumo(id: string): Promise<EventoResumo | null> {
  if (getDataMode() === 'demo') return demoResumo(id)

  try {
    const attempts = [
      { includeFicha: true, includeExternalRentals: true },
      { includeFicha: false, includeExternalRentals: true },
      { includeFicha: true, includeExternalRentals: false },
      { includeFicha: false, includeExternalRentals: false },
    ]

    for (const attempt of attempts) {
      const { data, error } = await queryEventoResumo(
        id,
        attempt.includeFicha,
        attempt.includeExternalRentals,
      )
      if (!error) return data ? rowToResumo(data as unknown as EventoRow) : null
      if (
        (attempt.includeFicha && isMissingFichaEventoColumn(error)) ||
        (attempt.includeExternalRentals && isMissingExternalRentalsColumn(error))
      ) {
        continue
      }
      throw error
    }

    return null
  } catch (error) {
    if (isDemoFallbackEnabled()) return demoResumo(id)
    throw error
  }
}
