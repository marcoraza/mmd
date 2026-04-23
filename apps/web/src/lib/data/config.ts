import 'server-only'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria } from '@/lib/types'

export type CategoriaBreakdown = {
  categoria: Categoria
  items: number
}

export type ConfigHealth = {
  items: number
  serial_numbers: number
  lotes: number
  projetos: number
  rfid_scans: number
  rfid_scans_24h: number
  rfid_readers_ativos: number
  last_scan_at: string | null
}

export type ConfigData = {
  health: ConfigHealth
  taxonomia: CategoriaBreakdown[]
  supabase_url: string | null
  supabase_project_id: string | null
}

async function countRows(table: string): Promise<number> {
  const { count, error } = await supabaseAdmin
    .from(table)
    .select('id', { count: 'exact', head: true })
  if (error) throw error
  return count ?? 0
}

async function countRfidScans24h(): Promise<number> {
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
  const { count, error } = await supabaseAdmin
    .from('rfid_scans')
    .select('id', { count: 'exact', head: true })
    .gte('timestamp', since)
  if (error) throw error
  return count ?? 0
}

async function countReadersAtivos(): Promise<number> {
  const { count, error } = await supabaseAdmin
    .from('rfid_readers')
    .select('id', { count: 'exact', head: true })
    .eq('status', 'ATIVO')
  if (error) throw error
  return count ?? 0
}

async function fetchLastScanTimestamp(): Promise<string | null> {
  const { data, error } = await supabaseAdmin
    .from('rfid_scans')
    .select('timestamp')
    .order('timestamp', { ascending: false })
    .limit(1)
  if (error) throw error
  return data?.[0]?.timestamp ?? null
}

async function fetchTaxonomia(): Promise<CategoriaBreakdown[]> {
  const { data, error } = await supabaseAdmin.from('items').select('categoria')
  if (error) throw error
  const rows = (data ?? []) as Array<{ categoria: Categoria }>
  const counts = new Map<Categoria, number>()
  for (const r of rows) {
    counts.set(r.categoria, (counts.get(r.categoria) ?? 0) + 1)
  }
  const order: Categoria[] = [
    'ILUMINACAO',
    'AUDIO',
    'CABO',
    'ENERGIA',
    'ESTRUTURA',
    'EFEITO',
    'VIDEO',
    'ACESSORIO',
  ]
  return order
    .filter((c) => counts.has(c))
    .map((c) => ({ categoria: c, items: counts.get(c) ?? 0 }))
}

function extractProjectId(url: string | null): string | null {
  if (!url) return null
  const match = url.match(/https:\/\/([^.]+)\.supabase\.co/)
  return match?.[1] ?? null
}

export async function loadConfig(): Promise<ConfigData> {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? null
  const [
    items,
    serial_numbers,
    lotes,
    projetos,
    rfid_scans,
    rfid_scans_24h,
    rfid_readers_ativos,
    last_scan_at,
    taxonomia,
  ] = await Promise.all([
    countRows('items'),
    countRows('serial_numbers'),
    countRows('lotes'),
    countRows('projetos'),
    countRows('rfid_scans'),
    countRfidScans24h(),
    countReadersAtivos(),
    fetchLastScanTimestamp(),
    fetchTaxonomia(),
  ])

  return {
    health: {
      items,
      serial_numbers,
      lotes,
      projetos,
      rfid_scans,
      rfid_scans_24h,
      rfid_readers_ativos,
      last_scan_at,
    },
    taxonomia,
    supabase_url: supabaseUrl,
    supabase_project_id: extractProjectId(supabaseUrl),
  }
}
