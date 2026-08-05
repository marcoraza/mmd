import 'server-only'

import { supabaseAdmin } from '@/lib/supabase-server'
import type { RfidScanContext } from '@/lib/rfid-scan-core'
import type { Categoria, StatusSerial } from '@/lib/types'

export type StatusReader = 'ATIVO' | 'INATIVO' | 'MANUTENCAO'

export type RfidReader = {
  id: string
  nome: string
  modelo: string
  serial_fabrica: string | null
  operador: string | null
  status: StatusReader
  bateria: number | null
  ultima_atividade: string | null
  notas: string | null
}

// Sem `lote_id`: não existe tabela `lotes` no EventPro. Tag não reconhecida
// continua sendo gravada com `serial_number_id` nulo (onboarding e auditoria).
export type RfidScan = {
  id: string
  tag_rfid: string
  timestamp: string
  operador: string | null
  contexto: RfidScanContext | null
  localizacao: string | null
  rssi: number | null
  notas: string | null
  reader_id: string | null
  reader_nome: string | null
  serial_id: string | null
  serial_codigo: string | null
  serial_status: StatusSerial | null
  projeto_id: string | null
  projeto_nome: string | null
  item_id: string | null
  item_nome: string | null
  item_categoria: Categoria | null
  reconhecido: boolean
}

export type RfidBannerStats = {
  scans_hoje: number
  scans_24h: number
  nao_reconhecidos_24h: number
  leitores_ativos: number
}

export type RfidTagCoverage = {
  total_units: number
  tags_bound: number
  tags_pending: number
}

export type RfidData = {
  readers: RfidReader[]
  scans: RfidScan[]
  banner: RfidBannerStats
  tag_coverage: RfidTagCoverage
}

type ScanJoined = {
  id: string
  tag_rfid: string
  timestamp: string
  operador: string | null
  contexto: RfidScanContext | null
  localizacao: string | null
  rssi: number | null
  notas: string | null
  rfid_readers: { id: string; nome: string } | null
  serial_numbers: {
    id: string
    codigo_interno: string
    status: StatusSerial
    items: { id: string; nome: string; categoria: Categoria } | null
  } | null
  projetos: { id: string; nome: string } | null
}

const SCAN_LIMIT = 200

export async function loadRfid(): Promise<RfidData> {
  const [readersRes, scansRes, tagCoverage] = await Promise.all([
    supabaseAdmin
      .from('rfid_readers')
      .select(
        'id, nome, modelo, serial_fabrica, operador, status, bateria, ultima_atividade, notas',
      )
      .order('nome', { ascending: true }),
    supabaseAdmin
      .from('rfid_scans')
      .select(
        `id, tag_rfid, timestamp, operador, contexto, localizacao, rssi, notas,
         rfid_readers (id, nome),
         serial_numbers (id, codigo_interno, status, items (id, nome, categoria)),
         projetos (id, nome)`,
      )
      .order('timestamp', { ascending: false })
      .limit(SCAN_LIMIT),
    loadRfidTagCoverage(),
  ])

  if (readersRes.error) throw readersRes.error
  if (scansRes.error) throw scansRes.error

  const readers = (readersRes.data ?? []) as unknown as RfidReader[]
  const rawScans = (scansRes.data ?? []) as unknown as ScanJoined[]

  const scans: RfidScan[] = rawScans.map((row) => {
    const serialItem = row.serial_numbers?.items ?? null
    return {
      id: row.id,
      tag_rfid: row.tag_rfid,
      timestamp: row.timestamp,
      operador: row.operador,
      contexto: row.contexto,
      localizacao: row.localizacao,
      rssi: row.rssi,
      notas: row.notas,
      reader_id: row.rfid_readers?.id ?? null,
      reader_nome: row.rfid_readers?.nome ?? null,
      serial_id: row.serial_numbers?.id ?? null,
      serial_codigo: row.serial_numbers?.codigo_interno ?? null,
      serial_status: row.serial_numbers?.status ?? null,
      projeto_id: row.projetos?.id ?? null,
      projeto_nome: row.projetos?.nome ?? null,
      item_id: serialItem?.id ?? null,
      item_nome: serialItem?.nome ?? null,
      item_categoria: serialItem?.categoria ?? null,
      reconhecido: row.serial_numbers?.id != null,
    }
  })

  const now = Date.now()
  const ms24h = 24 * 60 * 60 * 1000
  const startOfDay = new Date()
  startOfDay.setHours(0, 0, 0, 0)
  const startOfDayMs = startOfDay.getTime()

  let scansHoje = 0
  let scans24h = 0
  let naoReconhecidos24h = 0
  for (const scan of scans) {
    const at = new Date(scan.timestamp).getTime()
    if (at >= startOfDayMs) scansHoje += 1
    if (now - at <= ms24h) {
      scans24h += 1
      if (!scan.reconhecido) naoReconhecidos24h += 1
    }
  }

  return {
    readers,
    scans,
    banner: {
      scans_hoje: scansHoje,
      scans_24h: scans24h,
      nao_reconhecidos_24h: naoReconhecidos24h,
      leitores_ativos: readers.filter((reader) => reader.status === 'ATIVO').length,
    },
    tag_coverage: tagCoverage,
  }
}

// Cobertura de etiquetagem do parque inteiro, não só dos cabos: o vínculo de
// tag deixou de ser restrito a cabo no EventPro.
async function loadRfidTagCoverage(): Promise<RfidTagCoverage> {
  const [totalRes, boundRes] = await Promise.all([
    supabaseAdmin.from('serial_numbers').select('*', { count: 'exact', head: true }),
    supabaseAdmin
      .from('serial_numbers')
      .select('*', { count: 'exact', head: true })
      .not('tag_rfid', 'is', null),
  ])

  if (totalRes.error) throw totalRes.error
  if (boundRes.error) throw boundRes.error

  const total = totalRes.count ?? 0
  const bound = boundRes.count ?? 0

  return { total_units: total, tags_bound: bound, tags_pending: Math.max(total - bound, 0) }
}
