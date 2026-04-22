import 'server-only'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { StatusSerial } from '@/lib/types'

export type StockStats = {
  disponivel: number
  em_campo: number
  retornando: number
  manutencao: number
  criticos: number
  patrimonio_total: number
}

type SerialRow = {
  status: StatusSerial
  desgaste: number
  valor_atual: number | null
}

const ACTIVE_STATUSES: StatusSerial[] = [
  'DISPONIVEL',
  'PACKED',
  'EM_CAMPO',
  'RETORNANDO',
  'MANUTENCAO',
]

export async function loadStockStats(): Promise<StockStats> {
  const { data, error } = await supabaseAdmin
    .from('serial_numbers')
    .select('status, desgaste, valor_atual')

  if (error) throw error

  const rows = (data ?? []) as SerialRow[]

  let disponivel = 0
  let emCampo = 0
  let retornando = 0
  let manutencao = 0
  let criticos = 0
  let patrimonio = 0

  for (const s of rows) {
    const isActive = ACTIVE_STATUSES.includes(s.status)
    if (isActive) {
      patrimonio += s.valor_atual ?? 0
      if (s.desgaste <= 2) criticos += 1
    }
    switch (s.status) {
      case 'DISPONIVEL':
        disponivel += 1
        break
      case 'EM_CAMPO':
      case 'PACKED':
        emCampo += 1
        break
      case 'RETORNANDO':
        retornando += 1
        break
      case 'MANUTENCAO':
        manutencao += 1
        break
    }
  }

  return {
    disponivel,
    em_campo: emCampo,
    retornando,
    manutencao,
    criticos,
    patrimonio_total: patrimonio,
  }
}
