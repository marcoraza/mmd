import 'server-only'
import { getDemoItemById, getDemoLoteById, loadDemoLotes, loadDemoUnits } from '@/lib/data/demo'
import { getDataMode, isDemoFallbackEnabled } from '@/lib/data/demo-mode'
import { getItemById, type ItemDetail, type SerialRow } from '@/lib/data/items'
import { getLoteById, type LoteRow } from '@/lib/data/lotes'
import { normalizeInternalQrLookupCode, type InternalQrLookupField } from '@/lib/internal-qr-core'
import { supabaseAdmin } from '@/lib/supabase-server'

type SerialPointer = {
  id: string
  item_id: string
}

type LotePointer = {
  id: string
}

export type InternalQrFicha =
  | {
      kind: 'serial'
      detail: ItemDetail
      serial: SerialRow
      normalizedCode: string
    }
  | {
      kind: 'lote'
      lote: LoteRow
      normalizedCode: string
    }

export async function loadInternalQrFicha(code: string): Promise<InternalQrFicha | null> {
  const normalized = normalizeInternalQrLookupCode(code)
  if (!normalized) return null

  if (getDataMode() === 'demo') return loadDemoInternalQrFicha(normalized)

  try {
    const result = await loadInternalQrFichaFromSupabase(normalized)
    if (result) return result
  } catch (error) {
    const demoResult = isDemoFallbackEnabled() ? loadDemoInternalQrFicha(normalized) : null
    if (demoResult) return demoResult
    console.error('Internal QR lookup failed', error)
    return null
  }

  return isDemoFallbackEnabled() ? loadDemoInternalQrFicha(normalized) : null
}

async function loadInternalQrFichaFromSupabase(
  normalized: string,
): Promise<InternalQrFicha | null> {
  const serialPointer = await findSerialPointer(normalized)
  if (serialPointer) {
    const detail = await getItemById(serialPointer.item_id)
    const serial = detail?.serials.find((row) => row.id === serialPointer.id) ?? null
    if (detail && serial) return { kind: 'serial', detail, serial, normalizedCode: normalized }
  }

  const lotePointer = await findLotePointer(normalized)
  if (lotePointer) {
    const lote = await getLoteById(lotePointer.id)
    if (lote) return { kind: 'lote', lote, normalizedCode: normalized }
  }

  return null
}

async function findSerialPointer(normalized: string) {
  return (
    (await querySerialPointer('codigo_interno', normalized)) ??
    (await querySerialPointer('qr_code', normalized))
  )
}

async function querySerialPointer(field: InternalQrLookupField, normalized: string) {
  const { data, error } = await supabaseAdmin
    .from('serial_numbers')
    .select('id, item_id')
    .eq(field, normalized)
    .maybeSingle()

  if (error) throw error
  return (data ?? null) as SerialPointer | null
}

async function findLotePointer(normalized: string) {
  return (
    (await queryLotePointer('codigo_lote', normalized)) ??
    (await queryLotePointer('qr_code', normalized))
  )
}

async function queryLotePointer(field: 'codigo_lote' | 'qr_code', normalized: string) {
  const { data, error } = await supabaseAdmin
    .from('lotes')
    .select('id')
    .eq(field, normalized)
    .maybeSingle()

  if (error) throw error
  return (data ?? null) as LotePointer | null
}

function loadDemoInternalQrFicha(normalized: string): InternalQrFicha | null {
  const unit = loadDemoUnits().find(
    (row) => row.codigo_interno === normalized || row.qr_code === normalized,
  )

  if (unit) {
    const detail = getDemoItemById(unit.item_id)
    const serial = detail?.serials.find((row) => row.id === unit.id) ?? null
    if (detail && serial) return { kind: 'serial', detail, serial, normalizedCode: normalized }
  }

  const lote = loadDemoLotes().lotes.find(
    (row) => row.codigo_lote === normalized || row.qr_code === normalized,
  )
  if (!lote) return null

  const fullLote = getDemoLoteById(lote.id)
  return fullLote ? { kind: 'lote', lote: fullLote, normalizedCode: normalized } : null
}
