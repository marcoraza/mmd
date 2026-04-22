import 'server-only'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria, Estado, StatusSerial } from '@/lib/types'

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
}

export type CatalogBannerStats = {
  disponivel: number
  em_campo: number
  manutencao: number
  criticos: number
  condicao_media: number
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
  let desgasteSum = 0
  let ativosCount = 0

  for (const it of items) {
    disponivel += it.disponivel_count
    emCampo += it.em_campo_count
    manutencao += it.manutencao_count
    criticos += it.criticos_count
    const ativos =
      it.disponivel_count + it.em_campo_count + it.manutencao_count
    ativosCount += ativos
    desgasteSum += it.condicao_media * ativos
  }

  const banner: CatalogBannerStats = {
    disponivel,
    em_campo: emCampo,
    manutencao,
    criticos,
    condicao_media: ativosCount > 0 ? desgasteSum / ativosCount : 0,
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
