import 'server-only'

import { getItemById, type ItemDetail, type SerialRow } from '@/lib/data/items'
import { normalizeInternalQrLookupCode, type InternalQrLookupField } from '@/lib/internal-qr-core'
import { supabaseAdmin } from '@/lib/supabase-server'

type SerialPointer = {
  id: string
  item_id: string
}

// Sem o ramo de lote do legado: no EventPro só a unidade física carrega QR.
export type InternalQrFicha = {
  kind: 'serial'
  detail: ItemDetail
  serial: SerialRow
  normalizedCode: string
}

export async function loadInternalQrFicha(code: string): Promise<InternalQrFicha | null> {
  const normalized = normalizeInternalQrLookupCode(code)
  if (!normalized) return null

  const pointer = await findSerialPointer(normalized)
  if (!pointer) return null

  const detail = await getItemById(pointer.item_id)
  const serial = detail?.serials.find((row) => row.id === pointer.id) ?? null
  if (!detail || !serial) return null

  return { kind: 'serial', detail, serial, normalizedCode: normalized }
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
