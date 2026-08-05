import 'server-only'

import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria, StatusSerial } from '@/lib/types'

// Lotes não existem no EventPro (unit-only é decisão de produto desde MAR-187),
// então a fonte de etiqueta é sempre a unidade física.
export type QrUnit = {
  id: string
  codigo_interno: string
  serial_fabrica: string | null
  tag_rfid: string | null
  rfid_pending: boolean
  status: StatusSerial
  item_id: string
  item_nome: string
  item_categoria: Categoria
  item_subcategoria: string | null
}

export type QrSources = {
  units: QrUnit[]
}

type UnitJoined = {
  id: string
  codigo_interno: string
  serial_fabrica: string | null
  tag_rfid: string | null
  status: StatusSerial
  items: {
    id: string
    nome: string
    categoria: Categoria
    subcategoria: string | null
  } | null
}

export async function loadQrSources(): Promise<QrSources> {
  const rows = await loadAllQrUnitRows()

  const units: QrUnit[] = rows
    .filter((row) => row.items != null)
    .map((row) => ({
      id: row.id,
      codigo_interno: row.codigo_interno,
      serial_fabrica: row.serial_fabrica,
      tag_rfid: row.tag_rfid,
      // Vínculo de tag deixou de ser exclusivo de cabo: qualquer unidade sem
      // etiqueta é pendência de RFID.
      rfid_pending: !row.tag_rfid?.trim(),
      status: row.status,
      item_id: row.items!.id,
      item_nome: row.items!.nome,
      item_categoria: row.items!.categoria,
      item_subcategoria: row.items!.subcategoria,
    }))

  return { units }
}

async function loadAllQrUnitRows(): Promise<UnitJoined[]> {
  const pageSize = 1000
  const rows: UnitJoined[] = []

  for (let from = 0; ; from += pageSize) {
    const { data, error } = await supabaseAdmin
      .from('serial_numbers')
      .select(
        `id, codigo_interno, serial_fabrica, tag_rfid, status,
         items!inner (id, nome, categoria, subcategoria)`,
      )
      .order('codigo_interno', { ascending: true })
      .range(from, from + pageSize - 1)

    if (error) throw error

    const page = (data ?? []) as unknown as UnitJoined[]
    rows.push(...page)
    if (page.length < pageSize) return rows
  }
}
