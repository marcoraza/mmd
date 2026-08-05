import 'server-only'

import { supabaseAdmin } from '@/lib/supabase-server'
import {
  buildSerialSearchResponse,
  type SerialSearchItem,
  type SerialSearchParams,
  type SerialSearchResponse,
} from '@/lib/serial-search-core'

type SerialSearchRow = {
  id: string
  codigo_interno: string
  tag_rfid: string | null
  items: { nome: string | null } | { nome: string | null }[] | null
}

function firstRelated<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) return value[0] ?? null
  return value ?? null
}

// A busca cruza colunas da unidade (`codigo_interno`, `serial_fabrica`) com
// colunas do item pai (`nome`, `marca`, `modelo`). PostgREST não faz OR entre
// tabela base e embed na mesma expressão, então os itens que casam com o termo
// são resolvidos primeiro e entram como `item_id.in.(...)` no OR seguinte. Com
// isso a consulta principal continua sendo uma só, com `count: exact` e
// paginação real (nada de filtrar página em memória).
async function itemIdsMatching(term: string): Promise<string[]> {
  const pattern = `%${term}%`
  const { data, error } = await supabaseAdmin
    .from('items')
    .select('id')
    .or(`nome.ilike.${pattern},marca.ilike.${pattern},modelo.ilike.${pattern}`)

  if (error) throw error
  return (data ?? []).map((row) => row.id as string)
}

export async function searchSeriais(params: SerialSearchParams): Promise<SerialSearchResponse> {
  let builder = supabaseAdmin
    .from('serial_numbers')
    .select('id, codigo_interno, tag_rfid, items ( nome )', { count: 'exact' })

  if (params.itemId) builder = builder.eq('item_id', params.itemId)
  if (params.semTag) builder = builder.is('tag_rfid', null)

  if (params.q) {
    const pattern = `%${params.q}%`
    const itemIds = await itemIdsMatching(params.q)
    const filters = [`codigo_interno.ilike.${pattern}`, `serial_fabrica.ilike.${pattern}`]
    if (itemIds.length > 0) filters.push(`item_id.in.(${itemIds.join(',')})`)
    builder = builder.or(filters.join(','))
  }

  // Ordem estável e determinística: sem ela a paginação repete ou pula linha.
  const { data, error, count } = await builder
    .order('codigo_interno', { ascending: true })
    .range(params.offset, params.offset + params.limit - 1)

  if (error) throw error

  const items: SerialSearchItem[] = ((data ?? []) as unknown as SerialSearchRow[]).map((row) => ({
    serial_id: row.id,
    codigo_interno: row.codigo_interno,
    item_nome: firstRelated(row.items)?.nome ?? null,
    tag_rfid: row.tag_rfid,
  }))

  return buildSerialSearchResponse({
    items,
    total: count ?? items.length,
    limit: params.limit,
    offset: params.offset,
  })
}

export type QrSheetSerialLookupRow = {
  id: string
  codigo_interno: string
  items: { nome: string | null; categoria: string | null } | null
}

// Resolução server-side dos dados da etiqueta (contrato §6.6): o cliente manda
// só ids, o servidor decide o que vai impresso.
export async function loadSerialsForQrSheet(ids: string[]) {
  if (ids.length === 0) return []

  const { data, error } = await supabaseAdmin
    .from('serial_numbers')
    .select('id, codigo_interno, items ( nome, categoria )')
    .in('id', ids)

  if (error) throw error
  return (data ?? []) as unknown as QrSheetSerialLookupRow[]
}
