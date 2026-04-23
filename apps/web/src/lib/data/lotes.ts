import 'server-only'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria } from '@/lib/types'

export type StatusLote = 'DISPONIVEL' | 'EM_CAMPO' | 'MANUTENCAO'

export type LoteRow = {
  id: string
  codigo_lote: string
  descricao: string | null
  quantidade: number
  tag_rfid: string | null
  qr_code: string | null
  status: StatusLote
  created_at: string
  updated_at: string
  item_id: string
  item_nome: string
  item_categoria: Categoria
  item_subcategoria: string | null
  item_marca: string | null
  item_valor_mercado_unitario: number | null
}

export type LotesBannerStats = {
  total: number
  disponivel: number
  em_campo: number
  manutencao: number
  unidades_totais: number
}

export type LotesData = {
  lotes: LoteRow[]
  banner: LotesBannerStats
}

type LoteJoinedRow = {
  id: string
  codigo_lote: string
  descricao: string | null
  quantidade: number
  tag_rfid: string | null
  qr_code: string | null
  status: StatusLote
  created_at: string
  updated_at: string
  items: {
    id: string
    nome: string
    categoria: Categoria
    subcategoria: string | null
    marca: string | null
    valor_mercado_unitario: number | null
  } | null
}

function flatten(r: LoteJoinedRow): LoteRow | null {
  if (!r.items) return null
  return {
    id: r.id,
    codigo_lote: r.codigo_lote,
    descricao: r.descricao,
    quantidade: r.quantidade,
    tag_rfid: r.tag_rfid,
    qr_code: r.qr_code,
    status: r.status,
    created_at: r.created_at,
    updated_at: r.updated_at,
    item_id: r.items.id,
    item_nome: r.items.nome,
    item_categoria: r.items.categoria,
    item_subcategoria: r.items.subcategoria,
    item_marca: r.items.marca,
    item_valor_mercado_unitario: r.items.valor_mercado_unitario,
  }
}

export async function loadLotes(): Promise<LotesData> {
  const { data, error } = await supabaseAdmin
    .from('lotes')
    .select(
      `id, codigo_lote, descricao, quantidade, tag_rfid, qr_code, status,
       created_at, updated_at,
       items!inner (id, nome, categoria, subcategoria, marca, valor_mercado_unitario)`
    )
    .order('codigo_lote', { ascending: true })

  if (error) throw error

  const rows = ((data ?? []) as unknown as LoteJoinedRow[])
    .map(flatten)
    .filter((x): x is LoteRow => x !== null)

  const banner: LotesBannerStats = {
    total: rows.length,
    disponivel: 0,
    em_campo: 0,
    manutencao: 0,
    unidades_totais: 0,
  }
  for (const l of rows) {
    banner.unidades_totais += l.quantidade
    if (l.status === 'DISPONIVEL') banner.disponivel += 1
    else if (l.status === 'EM_CAMPO') banner.em_campo += 1
    else if (l.status === 'MANUTENCAO') banner.manutencao += 1
  }

  return { lotes: rows, banner }
}

export async function getLoteById(id: string): Promise<LoteRow | null> {
  const { data, error } = await supabaseAdmin
    .from('lotes')
    .select(
      `id, codigo_lote, descricao, quantidade, tag_rfid, qr_code, status,
       created_at, updated_at,
       items!inner (id, nome, categoria, subcategoria, marca, valor_mercado_unitario)`
    )
    .eq('id', id)
    .maybeSingle()

  if (error) throw error
  if (!data) return null
  return flatten(data as unknown as LoteJoinedRow)
}

export async function getRelatedLotes(
  itemId: string,
  excludeLoteId: string
): Promise<LoteRow[]> {
  const { data, error } = await supabaseAdmin
    .from('lotes')
    .select(
      `id, codigo_lote, descricao, quantidade, tag_rfid, qr_code, status,
       created_at, updated_at,
       items!inner (id, nome, categoria, subcategoria, marca, valor_mercado_unitario)`
    )
    .eq('item_id', itemId)
    .neq('id', excludeLoteId)
    .order('codigo_lote', { ascending: true })

  if (error) throw error

  return ((data ?? []) as unknown as LoteJoinedRow[])
    .map(flatten)
    .filter((x): x is LoteRow => x !== null)
}
