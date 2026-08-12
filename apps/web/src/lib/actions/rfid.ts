'use server'

import { revalidatePath } from 'next/cache'
import { requireActionUser } from '@/lib/action-auth'
import { isWriteBlocked } from '@/lib/data/demo-mode'
import { createSupabaseCookieClient } from '@/lib/supabase-ssr'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { StatusSerial } from '@/lib/types'

export type ActionResult<T = void> = { ok: true; data: T } | { ok: false; error: string }

export type CableUnitForRfidBind = {
  id: string
  codigo_interno: string
  tag_rfid: string | null
  status: StatusSerial
  item_nome: string
  item_subcategoria: string | null
}

type CableUnitRow = {
  id: string
  codigo_interno: string
  tag_rfid: string | null
  status: StatusSerial
  items: {
    nome: string
    subcategoria: string | null
  } | null
}

function blockWrite<T = void>(): ActionResult<T> | null {
  if (!isWriteBlocked()) return null
  return { ok: false, error: 'Modo somente leitura: alterações não são salvas.' }
}

function normalizeTag(raw: string) {
  return raw.trim().toUpperCase().replace(/[\s:-]+/g, '')
}

function validateTag(raw: string): ActionResult<string> {
  const tag = normalizeTag(raw)
  if (tag.length < 8) return { ok: false, error: 'RFID curto demais.' }
  if (tag.length > 96) return { ok: false, error: 'RFID longo demais.' }
  if (!/^[A-Z0-9]+$/.test(tag)) {
    return { ok: false, error: 'RFID deve conter apenas letras e números.' }
  }
  return { ok: true, data: tag }
}

export async function searchCableUnitsForRfidBind(
  query: string,
): Promise<ActionResult<CableUnitForRfidBind[]>> {
  const auth = await requireActionUser('viewer')
  if (!auth.ok) return auth

  const q = query.trim().toLowerCase()

  const { data, error } = await supabaseAdmin
    .from('serial_numbers')
    .select(
      `id, codigo_interno, tag_rfid, status,
       items!inner (nome, subcategoria, categoria)`,
    )
    .eq('items.categoria', 'CABO')
    .order('tag_rfid', { ascending: true, nullsFirst: true })
    .order('codigo_interno', { ascending: true })
    .limit(250)

  if (error) return { ok: false, error: error.message }

  const rows = ((data ?? []) as unknown as CableUnitRow[])
    .filter((row) => row.items != null)
    .filter((row) => {
      if (!q) return true
      return (
        row.codigo_interno.toLowerCase().includes(q) ||
        row.items!.nome.toLowerCase().includes(q) ||
        (row.items!.subcategoria ?? '').toLowerCase().includes(q) ||
        (row.tag_rfid ?? '').toLowerCase().includes(q)
      )
    })
    .slice(0, 30)
    .map((row) => ({
      id: row.id,
      codigo_interno: row.codigo_interno,
      tag_rfid: row.tag_rfid,
      status: row.status,
      item_nome: row.items!.nome,
      item_subcategoria: row.items!.subcategoria,
    }))

  return { ok: true, data: rows }
}

export async function bindRfidTagToSerial(
  serialId: string,
  rawTag: string,
  idempotencyKey?: string,
): Promise<ActionResult<{ codigo_interno: string; tag_rfid: string }>> {
  const blocked = blockWrite<{ codigo_interno: string; tag_rfid: string }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const parsed = validateTag(rawTag)
  if (!parsed.ok) return parsed
  const tag = parsed.data

  if (!auth.data.authRequired) {
    return { ok: false, error: 'Sessão autenticada obrigatória para Etiquetar.' }
  }

  const key = idempotencyKey?.trim() || crypto.randomUUID()
  const supabase = await createSupabaseCookieClient()
  const { data, error } = await supabase.rpc('aplicar_vinculo_rfid', {
    p_serial_id: serialId,
    p_epc: tag,
    p_idempotency_key: key,
  })

  if (error) return { ok: false, error: error.message }
  const result = data as { next_unit_code?: string; epc?: string } | null
  if (!result?.next_unit_code || !result.epc) {
    return { ok: false, error: 'A associação RFID não foi confirmada.' }
  }

  revalidatePath('/rfid')
  revalidatePath('/qrcodes')
  revalidatePath('/items')

  return {
    ok: true,
    data: {
      codigo_interno: result.next_unit_code,
      tag_rfid: result.epc,
    },
  }
}
