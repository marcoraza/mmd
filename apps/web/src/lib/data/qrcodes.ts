import 'server-only'
import { loadDemoQrSources } from '@/lib/data/demo'
import { withDemoFallback } from '@/lib/data/demo-mode'
import { toUnitOnlyQrLoteState } from '@/lib/legacy-lotes-core'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria, StatusSerial } from '@/lib/types'
import type { StatusLote } from './lotes'

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

export type QrLote = {
  id: string
  codigo_lote: string
  quantidade: number
  status: StatusLote
  item_id: string
  item_nome: string
  item_categoria: Categoria
  item_subcategoria: string | null
}

export type QrSources = {
  units: QrUnit[]
  lotes: QrLote[]
  legacy_lotes: number
  legacy_cable_lotes: number
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

type LoteJoined = {
  id: string
  codigo_lote: string
  quantidade: number
  status: StatusLote
  items: {
    id: string
    nome: string
    categoria: Categoria
    subcategoria: string | null
  } | null
}

export async function loadQrSources(): Promise<QrSources> {
  return withDemoFallback('qr-sources', loadQrSourcesFromSupabase, loadDemoQrSources)
}

async function loadQrSourcesFromSupabase(): Promise<QrSources> {
  const [unitRows, lotesRes] = await Promise.all([
    loadAllQrUnitRows(),
    supabaseAdmin
      .from('lotes')
      .select(
        `id, codigo_lote, quantidade, status,
         items!inner (id, nome, categoria, subcategoria)`,
      )
      .order('codigo_lote', { ascending: true }),
  ])

  if (lotesRes.error) throw lotesRes.error

  const units: QrUnit[] = unitRows
    .filter((r) => r.items != null)
    .map((r) => ({
      id: r.id,
      codigo_interno: r.codigo_interno,
      serial_fabrica: r.serial_fabrica,
      tag_rfid: r.tag_rfid,
      rfid_pending: r.items!.categoria === 'CABO' && !r.tag_rfid?.trim(),
      status: r.status,
      item_id: r.items!.id,
      item_nome: r.items!.nome,
      item_categoria: r.items!.categoria,
      item_subcategoria: r.items!.subcategoria,
    }))

  const loteRows = ((lotesRes.data ?? []) as unknown as LoteJoined[]).filter((r) => r.items != null)
  const legacyState = toUnitOnlyQrLoteState(
    loteRows.map((r) => ({
      id: r.id,
      codigo_lote: r.codigo_lote,
      quantidade: r.quantidade,
      status: r.status,
      item_id: r.items!.id,
      item_nome: r.items!.nome,
      item_categoria: r.items!.categoria,
      item_subcategoria: r.items!.subcategoria,
    })),
  )

  return {
    units,
    lotes: legacyState.operational_lotes,
    legacy_lotes: legacyState.legacy_lotes,
    legacy_cable_lotes: legacyState.legacy_cable_lotes,
  }
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
