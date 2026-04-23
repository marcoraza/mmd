import 'server-only'
import { supabaseAdmin } from '@/lib/supabase-server'
import type {
  Categoria,
  Estado,
  MetodoScan,
  StatusSerial,
  TipoMovimentacao,
} from '@/lib/types'

export type CatalogItem = {
  id: string
  codigo_interno: string | null
  nome: string
  categoria: Categoria
  subcategoria: string | null
  marca: string | null
  modelo: string | null
  quantidade_total: number
  foto_url: string | null
  valor_mercado_unitario: number | null
  situacao: StatusSerial | 'MISTO'
  ciclo: Estado | 'MISTO' | null
  condicao_media: number
  valor_atual_total: number
  disponivel_count: number
  em_campo_count: number
  manutencao_count: number
  criticos_count: number
  regular_count: number
  otimo_count: number
}

export type CatalogBannerStats = {
  disponivel: number
  em_campo: number
  manutencao: number
  criticos: number
  regular: number
  otimo: number
  utilizacao_pct: number
  total_ativos: number
}

export type CategoryCount = {
  categoria: Categoria
  qtd: number
}

export type CatalogData = {
  items: CatalogItem[]
  banner: CatalogBannerStats
  categories: CategoryCount[]
  total_lotes: number
}

export type CatalogUnit = {
  id: string
  codigo_interno: string
  serial_fabrica: string | null
  tag_rfid: string | null
  qr_code: string | null
  status: StatusSerial
  estado: Estado
  desgaste: number
  valor_atual: number | null
  localizacao: string | null
  updated_at: string
  item_id: string
  item_nome: string
  item_categoria: Categoria
  item_subcategoria: string | null
  item_marca: string | null
  item_modelo: string | null
  item_valor_mercado_unitario: number | null
}

type ItemRow = {
  id: string
  codigo_interno: string | null
  nome: string
  categoria: Categoria
  subcategoria: string | null
  marca: string | null
  modelo: string | null
  quantidade_total: number
  valor_mercado_unitario: number | null
  foto_url: string | null
  serial_numbers: Array<{
    status: StatusSerial
    estado: Estado
    desgaste: number
    valor_atual: number | null
  }>
}

export type SerialRow = {
  id: string
  codigo_interno: string
  serial_fabrica: string | null
  tag_rfid: string | null
  qr_code: string | null
  status: StatusSerial
  estado: Estado
  desgaste: number
  valor_atual: number | null
  localizacao: string | null
  notas: string | null
  updated_at: string
}

export type MovimentacaoTimeline = {
  id: string
  tipo: TipoMovimentacao
  timestamp: string
  status_anterior: string | null
  status_novo: string | null
  registrado_por: string | null
  metodo_scan: MetodoScan | null
  notas: string | null
  serial_codigo: string | null
  projeto_id: string | null
  projeto_nome: string | null
}

export type ItemDetail = {
  item: CatalogItem
  notas: string | null
  serials: SerialRow[]
  timeline: MovimentacaoTimeline[]
}

const ACTIVE_STATUSES: StatusSerial[] = [
  'DISPONIVEL',
  'PACKED',
  'EM_CAMPO',
  'RETORNANDO',
  'MANUTENCAO',
]

function aggregateItem(row: ItemRow): CatalogItem {
  const serials = row.serial_numbers ?? []
  const active = serials.filter((s) => ACTIVE_STATUSES.includes(s.status))

  const disp = serials.filter((s) => s.status === 'DISPONIVEL').length
  const campo = serials.filter((s) => s.status === 'EM_CAMPO' || s.status === 'PACKED').length
  const manut = serials.filter((s) => s.status === 'MANUTENCAO').length
  const criticos = active.filter((s) => s.desgaste <= 2).length
  const regular = active.filter((s) => s.desgaste === 3).length
  const otimo = active.filter((s) => s.desgaste >= 4).length

  const condicaoMedia =
    active.length > 0
      ? active.reduce((acc, s) => acc + s.desgaste, 0) / active.length
      : 0

  const valorAtualTotal = active.reduce((acc, s) => acc + (s.valor_atual ?? 0), 0)

  let situacao: CatalogItem['situacao']
  if (disp === active.length && disp > 0) situacao = 'DISPONIVEL'
  else if (campo === active.length && campo > 0) situacao = 'EM_CAMPO'
  else if (manut > 0 && manut === active.length) situacao = 'MANUTENCAO'
  else if (active.length === 0) situacao = serials[0]?.status ?? 'BAIXA'
  else situacao = 'MISTO'

  const ciclos = new Set(active.map((s) => s.estado))
  const ciclo: CatalogItem['ciclo'] =
    ciclos.size === 0 ? null : ciclos.size === 1 ? [...ciclos][0] : 'MISTO'

  return {
    id: row.id,
    codigo_interno: row.codigo_interno ?? null,
    nome: row.nome,
    categoria: row.categoria,
    subcategoria: row.subcategoria,
    marca: row.marca,
    modelo: row.modelo,
    quantidade_total: row.quantidade_total,
    foto_url: row.foto_url,
    valor_mercado_unitario: row.valor_mercado_unitario,
    situacao,
    ciclo,
    condicao_media: condicaoMedia,
    valor_atual_total: valorAtualTotal,
    disponivel_count: disp,
    em_campo_count: campo,
    manutencao_count: manut,
    criticos_count: criticos,
    regular_count: regular,
    otimo_count: otimo,
  }
}

export async function loadCatalog(): Promise<CatalogData> {
  const { data: itemsData, error: itemsError } = await supabaseAdmin
    .from('items')
    .select(
      `id, codigo_interno, nome, categoria, subcategoria, marca, modelo, quantidade_total,
       valor_mercado_unitario, foto_url,
       serial_numbers ( status, estado, desgaste, valor_atual )`
    )
    .order('nome', { ascending: true })

  if (itemsError) throw itemsError

  const items = (itemsData as ItemRow[]).map(aggregateItem)

  const { count: lotesCount, error: lotesError } = await supabaseAdmin
    .from('lotes')
    .select('*', { count: 'exact', head: true })
  if (lotesError) throw lotesError

  let disponivel = 0
  let emCampo = 0
  let manutencao = 0
  let criticos = 0
  let regular = 0
  let otimo = 0
  let ativosCount = 0

  for (const it of items) {
    disponivel += it.disponivel_count
    emCampo += it.em_campo_count
    manutencao += it.manutencao_count
    criticos += it.criticos_count
    regular += it.regular_count
    otimo += it.otimo_count
    const ativos =
      it.disponivel_count + it.em_campo_count + it.manutencao_count
    ativosCount += ativos
  }

  const banner: CatalogBannerStats = {
    disponivel,
    em_campo: emCampo,
    manutencao,
    criticos,
    regular,
    otimo,
    utilizacao_pct: ativosCount > 0 ? (emCampo / ativosCount) * 100 : 0,
    total_ativos: ativosCount,
  }

  const catMap = new Map<Categoria, number>()
  for (const it of items) {
    const ativos =
      it.disponivel_count + it.em_campo_count + it.manutencao_count
    catMap.set(it.categoria, (catMap.get(it.categoria) ?? 0) + ativos)
  }
  const categories: CategoryCount[] = [...catMap.entries()]
    .filter(([, qtd]) => qtd > 0)
    .map(([categoria, qtd]) => ({ categoria, qtd }))
    .sort((a, b) => b.qtd - a.qtd)

  return {
    items,
    banner,
    categories,
    total_lotes: lotesCount ?? 0,
  }
}

type UnitFlatRow = {
  id: string
  codigo_interno: string
  serial_fabrica: string | null
  tag_rfid: string | null
  qr_code: string | null
  status: StatusSerial
  estado: Estado
  desgaste: number
  valor_atual: number | null
  localizacao: string | null
  updated_at: string
  items: {
    id: string
    nome: string
    categoria: Categoria
    subcategoria: string | null
    marca: string | null
    modelo: string | null
    valor_mercado_unitario: number | null
  } | null
}

export async function loadUnits(): Promise<CatalogUnit[]> {
  const { data, error } = await supabaseAdmin
    .from('serial_numbers')
    .select(
      `id, codigo_interno, serial_fabrica, tag_rfid, qr_code,
       status, estado, desgaste, valor_atual, localizacao, updated_at,
       items!inner (id, nome, categoria, subcategoria, marca, modelo, valor_mercado_unitario)`
    )
    .order('codigo_interno', { ascending: true })

  if (error) throw error

  const rows = (data ?? []) as unknown as UnitFlatRow[]
  return rows
    .filter((r) => r.items != null)
    .map((r) => ({
      id: r.id,
      codigo_interno: r.codigo_interno,
      serial_fabrica: r.serial_fabrica,
      tag_rfid: r.tag_rfid,
      qr_code: r.qr_code,
      status: r.status,
      estado: r.estado,
      desgaste: r.desgaste,
      valor_atual: r.valor_atual,
      localizacao: r.localizacao,
      updated_at: r.updated_at,
      item_id: r.items!.id,
      item_nome: r.items!.nome,
      item_categoria: r.items!.categoria,
      item_subcategoria: r.items!.subcategoria,
      item_marca: r.items!.marca,
      item_modelo: r.items!.modelo,
      item_valor_mercado_unitario: r.items!.valor_mercado_unitario,
    }))
}

type ItemDetailRow = ItemRow & {
  notas: string | null
  serial_numbers_full: SerialRow[]
}

type MovimentacaoRow = {
  id: string
  tipo: TipoMovimentacao
  timestamp: string
  status_anterior: string | null
  status_novo: string | null
  registrado_por: string | null
  metodo_scan: MetodoScan | null
  notas: string | null
  serial_numbers: {
    codigo_interno: string
    item_id: string
  } | null
  projetos: {
    id: string
    nome: string
  } | null
}

export async function getItemById(id: string): Promise<ItemDetail | null> {
  const { data: itemData, error: itemErr } = await supabaseAdmin
    .from('items')
    .select(
      `id, codigo_interno, nome, categoria, subcategoria, marca, modelo,
       quantidade_total, valor_mercado_unitario, foto_url, notas,
       serial_numbers ( id, codigo_interno, serial_fabrica, tag_rfid, qr_code,
                        status, estado, desgaste, valor_atual, localizacao, notas, updated_at )`
    )
    .eq('id', id)
    .maybeSingle()

  if (itemErr) throw itemErr
  if (!itemData) return null

  const row = itemData as unknown as ItemDetailRow
  const serials = (row.serial_numbers ?? []) as unknown as SerialRow[]

  // Reuse aggregate by mapping to ItemRow shape
  const aggregated = aggregateItem({
    id: row.id,
    codigo_interno: row.codigo_interno,
    nome: row.nome,
    categoria: row.categoria,
    subcategoria: row.subcategoria,
    marca: row.marca,
    modelo: row.modelo,
    quantidade_total: row.quantidade_total,
    valor_mercado_unitario: row.valor_mercado_unitario,
    foto_url: row.foto_url,
    serial_numbers: serials.map((s) => ({
      status: s.status,
      estado: s.estado,
      desgaste: s.desgaste,
      valor_atual: s.valor_atual,
    })),
  })

  let timeline: MovimentacaoTimeline[] = []
  const serialIds = serials.map((s) => s.id)
  if (serialIds.length > 0) {
    const { data: movData, error: movErr } = await supabaseAdmin
      .from('movimentacoes')
      .select(
        `id, tipo, timestamp, status_anterior, status_novo, registrado_por,
         metodo_scan, notas,
         serial_numbers!inner ( codigo_interno, item_id ),
         projetos ( id, nome )`
      )
      .in('serial_number_id', serialIds)
      .order('timestamp', { ascending: false })
      .limit(100)

    if (movErr) throw movErr

    timeline = (movData as unknown as MovimentacaoRow[]).map((m) => ({
      id: m.id,
      tipo: m.tipo,
      timestamp: m.timestamp,
      status_anterior: m.status_anterior,
      status_novo: m.status_novo,
      registrado_por: m.registrado_por,
      metodo_scan: m.metodo_scan,
      notas: m.notas,
      serial_codigo: m.serial_numbers?.codigo_interno ?? null,
      projeto_id: m.projetos?.id ?? null,
      projeto_nome: m.projetos?.nome ?? null,
    }))
  }

  // Sort serials by codigo_interno for stable display
  const sortedSerials = [...serials].sort((a, b) =>
    a.codigo_interno.localeCompare(b.codigo_interno)
  )

  return {
    item: aggregated,
    notas: row.notas,
    serials: sortedSerials,
    timeline,
  }
}
