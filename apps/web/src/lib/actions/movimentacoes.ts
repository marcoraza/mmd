'use server'

import { revalidatePath } from 'next/cache'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { MetodoScan } from '@/lib/types'

export type ActionResult<T = void> =
  | { ok: true; data: T }
  | { ok: false; error: string }

// TODO(auth): trocar por auth.user.email quando a camada de auth chegar.
// Por enquanto é hard-coded, porque texto livre poluia a timeline com
// "Marco/marco/M./Aquilino/etc".
const REGISTRADO_POR = 'Marco'

export type CheckoutResult = {
  count: number
  seriais: Array<{ serial_id: string; codigo_interno: string }>
}

export async function checkoutProject(
  projetoId: string,
  metodo: MetodoScan
): Promise<ActionResult<CheckoutResult>> {
  const { data, error } = await supabaseAdmin.rpc('checkout_projeto', {
    p_projeto_id: projetoId,
    p_metodo: metodo,
    p_registrado_por: REGISTRADO_POR,
  })

  if (error) return { ok: false, error: error.message }

  const rows = (data ?? []) as Array<{ serial_id: string; codigo_interno: string }>
  revalidatePath('/projetos')
  revalidatePath(`/projetos/${projetoId}`)
  revalidatePath('/items')
  return { ok: true, data: { count: rows.length, seriais: rows } }
}

export type CheckinItemInput = {
  serial_id: string
  desgaste: number
  needs_maintenance: boolean
}

export type CheckinResult = {
  count: number
  seriais: Array<{ serial_id: string; codigo_interno: string; novo_status: string }>
}

export async function checkinProject(
  projetoId: string,
  metodo: MetodoScan,
  items: CheckinItemInput[]
): Promise<ActionResult<CheckinResult>> {
  if (items.length === 0) return { ok: false, error: 'Nada pra receber de volta.' }

  const payload = items.map((i) => ({
    serial_id: i.serial_id,
    desgaste: Math.max(1, Math.min(5, i.desgaste)),
    needs_maintenance: i.needs_maintenance,
  }))

  const { data, error } = await supabaseAdmin.rpc('checkin_projeto', {
    p_projeto_id: projetoId,
    p_metodo: metodo,
    p_registrado_por: REGISTRADO_POR,
    p_items: payload,
  })

  if (error) return { ok: false, error: error.message }

  const rows = (data ?? []) as Array<{
    serial_id: string
    codigo_interno: string
    novo_status: string
  }>
  revalidatePath('/projetos')
  revalidatePath(`/projetos/${projetoId}`)
  revalidatePath('/items')
  return { ok: true, data: { count: rows.length, seriais: rows } }
}
