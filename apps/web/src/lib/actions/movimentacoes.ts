'use server'

import { requireActionUser, type ActionAuthContext } from '@/lib/action-auth'
import type { ReturnOutcome, ReturnResolutionAction } from '@/lib/return-resolution-core'
import type { MetodoScan } from '@/lib/types'

export type ActionResult<T = void> = { ok: true; data: T } | { ok: false; error: string }

const PHYSICAL_CONFERENCE_REQUIRED =
  'Movimento físico exige Conferência no app operacional. Esta tela não altera estoque.'

function conferenceRequired<T>(): ActionResult<T> {
  return { ok: false, error: PHYSICAL_CONFERENCE_REQUIRED }
}

export type CheckoutResult = {
  count: number
  seriais: Array<{ serial_id: string; codigo_interno: string }>
}

export type CheckoutOptions = {
  overrideReason?: string
  auth?: ActionAuthContext
}

export async function checkoutProject(
  _projetoId: string,
  _metodo: MetodoScan,
  options: CheckoutOptions = {},
): Promise<ActionResult<CheckoutResult>> {
  const auth = options.auth ? { ok: true as const, data: options.auth } : await requireActionUser('editor')
  if (!auth.ok) return auth

  return conferenceRequired()
}

export type CheckinItemInput = {
  serial_id: string
  desgaste: number
  resultado?: ReturnOutcome
  needs_maintenance?: boolean
  observacao?: string | null
}

export type CheckinResult = {
  count: number
  seriais: Array<{ serial_id: string; codigo_interno: string; novo_status: string }>
}

export async function checkinProject(
  _projetoId: string,
  _metodo: MetodoScan,
  _items: CheckinItemInput[],
  options: { auth?: ActionAuthContext } = {},
): Promise<ActionResult<CheckinResult>> {
  const auth = options.auth ? { ok: true as const, data: options.auth } : await requireActionUser('editor')
  if (!auth.ok) return auth

  return conferenceRequired()
}

export type ResolveReturnPendingResult = {
  pendencia_id: string
  serial_id: string
  codigo_interno: string
  status_pendencia: string
  novo_status: string
}

export async function resolveReturnPending(
  pendenciaId: string,
  acao: ReturnResolutionAction,
  observacao?: string | null,
): Promise<ActionResult<ResolveReturnPendingResult>> {
  void pendenciaId
  void acao
  void observacao

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  return conferenceRequired()
}
