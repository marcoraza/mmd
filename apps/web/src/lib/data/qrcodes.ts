import 'server-only'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria, StatusSerial } from '@/lib/types'
import type { StatusLote } from './lotes'

export type QrUnit = {
  id: string
  codigo_interno: string
  serial_fabrica: string | null
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
}

type UnitJoined = {
  id: string
  codigo_interno: string
  serial_fabrica: string | null
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
  const [unitsRes, lotesRes] = await Promise.all([
    supabaseAdmin
      .from('serial_numbers')
      .select(
        `id, codigo_interno, serial_fabrica, status,
         items!inner (id, nome, categoria, subcategoria)`
      )
      .order('codigo_interno', { ascending: true }),
    supabaseAdmin
      .from('lotes')
      .select(
        `id, codigo_lote, quantidade, status,
         items!inner (id, nome, categoria, subcategoria)`
      )
      .order('codigo_lote', { ascending: true }),
  ])

  if (unitsRes.error) throw unitsRes.error
  if (lotesRes.error) throw lotesRes.error

  const units: QrUnit[] = ((unitsRes.data ?? []) as unknown as UnitJoined[])
    .filter((r) => r.items != null)
    .map((r) => ({
      id: r.id,
      codigo_interno: r.codigo_interno,
      serial_fabrica: r.serial_fabrica,
      status: r.status,
      item_id: r.items!.id,
      item_nome: r.items!.nome,
      item_categoria: r.items!.categoria,
      item_subcategoria: r.items!.subcategoria,
    }))

  const lotes: QrLote[] = ((lotesRes.data ?? []) as unknown as LoteJoined[])
    .filter((r) => r.items != null)
    .map((r) => ({
      id: r.id,
      codigo_lote: r.codigo_lote,
      quantidade: r.quantidade,
      status: r.status,
      item_id: r.items!.id,
      item_nome: r.items!.nome,
      item_categoria: r.items!.categoria,
      item_subcategoria: r.items!.subcategoria,
    }))

  return { units, lotes }
}
