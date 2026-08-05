import 'server-only'

// Check-out, retorno e resolução de pendência: toda mutação de estado físico
// passa pelas RPCs service-role-only, que gravam auditoria e mutam status na
// mesma transação.
//
// Diferença em relação ao legado: além de `p_registrado_por` (label de exibição
// congelado no registro), toda RPC recebe `p_registrado_por_id`, o id do profile
// autenticado. No legado a autoria era texto livre sem FK, então "quem fez" não
// era verificável.

import { revalidatePath } from 'next/cache'
import { requireActionUser, type ActionAuthContext } from '@/lib/action-auth'
import { checkoutGateAuditPayload, normalizeCheckoutOverrideReason } from '@/lib/checkout-gate-core'
import { buildCheckoutExecutionPlan } from '@/lib/checkout-execution-core'
import { loadProjectById } from '@/lib/data/project-detail'
import { blockWrite, type ActionResult } from '@/lib/readonly'
import {
  buildReturnConferencePlan,
  normalizeReturnResolution,
  type ReturnOutcome,
  type ReturnResolutionAction,
} from '@/lib/return-resolution-core'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { MetodoScan } from '@/lib/types'

export type { ActionResult }

export type CheckoutResult = {
  count: number
  seriais: Array<{ serial_id: string; codigo_interno: string }>
}

export type CheckoutOptions = {
  overrideReason?: string
  auth?: ActionAuthContext
}

export async function checkoutProject(
  projetoId: string,
  metodo: MetodoScan,
  options: CheckoutOptions = {},
): Promise<ActionResult<CheckoutResult>> {
  const blocked = blockWrite<CheckoutResult>()
  if (blocked) return blocked

  const auth = options.auth
    ? { ok: true as const, data: options.auth }
    : await requireActionUser('editor')
  if (!auth.ok) return auth

  const projeto = await loadProjectById(projetoId)
  if (!projeto) return { ok: false, error: 'Evento não encontrado.' }

  const gate = projeto.checkout_gate
  const executionPlan = buildCheckoutExecutionPlan({
    gate,
    packing: projeto.packing,
    metodo,
    operador: auth.data.registradoPor,
    now: null,
  })

  // Hard blocker aborta antes de qualquer RPC, inclusive com override: unidade
  // fora de DISPONIVEL significa que o equipamento está fisicamente em outro
  // lugar, e override é exceção de processo, não de realidade física.
  if (executionPlan.hardBlockers.length > 0) {
    return { ok: false, error: executionPlan.hardBlockers[0].message }
  }

  let rpcName = 'checkout_projeto'
  let rpcPayload: Record<string, unknown> = {
    p_projeto_id: projetoId,
    p_metodo: metodo,
    p_registrado_por: auth.data.registradoPor,
    p_registrado_por_id: auth.data.userId,
  }

  if (!gate.canCheckout) {
    if (!gate.canOverride) {
      return {
        ok: false,
        error: gate.blockers[0]?.message ?? 'Check-out bloqueado pelo gate de saída.',
      }
    }

    if (auth.data.role !== 'admin') {
      return { ok: false, error: 'Ação restrita ao usuário admin.' }
    }

    const reason = normalizeCheckoutOverrideReason(options.overrideReason)
    if (!reason.ok) return { ok: false, error: reason.error }

    const audit = checkoutGateAuditPayload(gate)
    const { data: override, error: overrideError } = await supabaseAdmin
      .from('checkout_overrides')
      .insert({
        projeto_id: projetoId,
        motivo: reason.value,
        blockers: audit.blockers,
        warnings: audit.warnings,
        checks: audit.checks,
        readiness_pct: audit.readiness_pct,
        registrado_por: auth.data.registradoPor,
        registrado_por_id: auth.data.userId,
      })
      .select('id')
      .single()

    if (overrideError) return { ok: false, error: overrideError.message }

    rpcName = 'checkout_projeto_com_override'
    rpcPayload = { ...rpcPayload, p_override_id: override.id }
  }

  const { data, error } = await supabaseAdmin.rpc(rpcName, rpcPayload)
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
  resultado?: ReturnOutcome
  needs_maintenance?: boolean
  observacao?: string | null
}

export type CheckinResult = {
  count: number
  seriais: Array<{ serial_id: string; codigo_interno: string; novo_status: string }>
}

export async function checkinProject(
  projetoId: string,
  metodo: MetodoScan,
  items: CheckinItemInput[],
  options: { auth?: ActionAuthContext } = {},
): Promise<ActionResult<CheckinResult>> {
  const blocked = blockWrite<CheckinResult>()
  if (blocked) return blocked

  const auth = options.auth
    ? { ok: true as const, data: options.auth }
    : await requireActionUser('editor')
  if (!auth.ok) return auth

  const plan = buildReturnConferencePlan(items)
  if (!plan.ok) return { ok: false, error: plan.error }

  const { data, error } = await supabaseAdmin.rpc('checkin_projeto', {
    p_projeto_id: projetoId,
    p_metodo: metodo,
    p_registrado_por: auth.data.registradoPor,
    p_items: plan.plan.items,
    p_registrado_por_id: auth.data.userId,
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
  const blocked = blockWrite<ResolveReturnPendingResult>()
  if (blocked) return blocked

  const auth = await requireActionUser('admin')
  if (!auth.ok) return auth

  const resolution = normalizeReturnResolution(acao, observacao)
  if (!resolution.ok) return { ok: false, error: resolution.error }

  const { data, error } = await supabaseAdmin.rpc('resolver_retorno_pendencia', {
    p_pendencia_id: pendenciaId,
    p_acao: resolution.resolution.acao,
    p_observacao: resolution.resolution.observacao,
    p_registrado_por: auth.data.registradoPor,
    p_registrado_por_id: auth.data.userId,
  })

  if (error) return { ok: false, error: error.message }

  const row = Array.isArray(data) ? data[0] : null
  if (!row) return { ok: false, error: 'Pendência não retornou resultado.' }

  revalidatePath('/projetos')
  revalidatePath('/items')
  return { ok: true, data: row as ResolveReturnPendingResult }
}
