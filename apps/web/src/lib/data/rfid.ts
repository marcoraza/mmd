import 'server-only'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { Categoria, StatusSerial } from '@/lib/types'
import type { StatusLote } from './lotes'

export type StatusReader = 'ATIVO' | 'INATIVO' | 'MANUTENCAO'

export type ContextoScan =
  | 'PACKING'
  | 'CARREGAMENTO'
  | 'CHECK_IN_EVENTO'
  | 'CHECK_OUT_EVENTO'
  | 'RETORNO'
  | 'CONFERENCIA'
  | 'INVENTARIO'
  | 'OUTRO'

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

export type RfidScan = {
  id: string
  tag_rfid: string
  timestamp: string
  operador: string | null
  contexto: ContextoScan | null
  localizacao: string | null
  rssi: number | null
  notas: string | null
  // resolved references (flattened)
  reader_id: string | null
  reader_nome: string | null
  serial_id: string | null
  serial_codigo: string | null
  serial_status: StatusSerial | null
  lote_id: string | null
  lote_codigo: string | null
  lote_status: StatusLote | null
  projeto_id: string | null
  projeto_nome: string | null
  item_id: string | null
  item_nome: string | null
  item_categoria: Categoria | null
  /** derived */
  reconhecido: boolean
}

export type RfidBannerStats = {
  scans_hoje: number
  scans_24h: number
  nao_reconhecidos_24h: number
  leitores_ativos: number
}

export type RfidData = {
  readers: RfidReader[]
  scans: RfidScan[]
  banner: RfidBannerStats
}

type ScanJoined = {
  id: string
  tag_rfid: string
  timestamp: string
  operador: string | null
  contexto: ContextoScan | null
  localizacao: string | null
  rssi: number | null
  notas: string | null
  rfid_readers: { id: string; nome: string } | null
  serial_numbers: {
    id: string
    codigo_interno: string
    status: StatusSerial
    items: {
      id: string
      nome: string
      categoria: Categoria
    } | null
  } | null
  lotes: {
    id: string
    codigo_lote: string
    status: StatusLote
    items: {
      id: string
      nome: string
      categoria: Categoria
    } | null
  } | null
  projetos: { id: string; nome: string } | null
}

const SCAN_LIMIT = 200

export async function loadRfid(): Promise<RfidData> {
  const [readersRes, scansRes] = await Promise.all([
    supabaseAdmin
      .from('rfid_readers')
      .select('id, nome, modelo, serial_fabrica, operador, status, bateria, ultima_atividade, notas')
      .order('nome', { ascending: true }),
    supabaseAdmin
      .from('rfid_scans')
      .select(
        `id, tag_rfid, timestamp, operador, contexto, localizacao, rssi, notas,
         rfid_readers (id, nome),
         serial_numbers (id, codigo_interno, status, items (id, nome, categoria)),
         lotes (id, codigo_lote, status, items (id, nome, categoria)),
         projetos (id, nome)`
      )
      .order('timestamp', { ascending: false })
      .limit(SCAN_LIMIT),
  ])

  if (readersRes.error) throw readersRes.error
  if (scansRes.error) throw scansRes.error

  const readers = (readersRes.data ?? []) as RfidReader[]
  const rawScans = (scansRes.data ?? []) as unknown as ScanJoined[]

  const scans: RfidScan[] = rawScans.map((r) => {
    const serialItem = r.serial_numbers?.items ?? null
    const loteItem = r.lotes?.items ?? null
    const resolvedItem = serialItem ?? loteItem
    return {
      id: r.id,
      tag_rfid: r.tag_rfid,
      timestamp: r.timestamp,
      operador: r.operador,
      contexto: r.contexto,
      localizacao: r.localizacao,
      rssi: r.rssi,
      notas: r.notas,
      reader_id: r.rfid_readers?.id ?? null,
      reader_nome: r.rfid_readers?.nome ?? null,
      serial_id: r.serial_numbers?.id ?? null,
      serial_codigo: r.serial_numbers?.codigo_interno ?? null,
      serial_status: r.serial_numbers?.status ?? null,
      lote_id: r.lotes?.id ?? null,
      lote_codigo: r.lotes?.codigo_lote ?? null,
      lote_status: r.lotes?.status ?? null,
      projeto_id: r.projetos?.id ?? null,
      projeto_nome: r.projetos?.nome ?? null,
      item_id: resolvedItem?.id ?? null,
      item_nome: resolvedItem?.nome ?? null,
      item_categoria: resolvedItem?.categoria ?? null,
      reconhecido: r.serial_numbers != null || r.lotes != null,
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
  for (const s of scans) {
    const t = new Date(s.timestamp).getTime()
    if (t >= startOfDayMs) scansHoje += 1
    if (now - t <= ms24h) {
      scans24h += 1
      if (!s.reconhecido) naoReconhecidos24h += 1
    }
  }

  const leitoresAtivos = readers.filter((r) => r.status === 'ATIVO').length

  return {
    readers,
    scans,
    banner: {
      scans_hoje: scansHoje,
      scans_24h: scans24h,
      nao_reconhecidos_24h: naoReconhecidos24h,
      leitores_ativos: leitoresAtivos,
    },
  }
}
