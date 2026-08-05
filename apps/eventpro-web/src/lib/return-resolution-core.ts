import type { StatusSerial } from './types'

export type ReturnOutcome = 'OK' | 'PROBLEMA' | 'NAO_VOLTOU'
export type ReturnResolutionAction = 'ENCONTRADA' | 'MANUTENCAO' | 'BAIXA' | 'COBRANCA'

export type ReturnConferenceRawItem = {
  serial_id: unknown
  desgaste?: unknown
  resultado?: unknown
  needs_maintenance?: unknown
  observacao?: unknown
}

export type ReturnConferenceItem = {
  serial_id: string
  desgaste: number
  resultado: ReturnOutcome
  observacao: string | null
}

export type ReturnConferenceCounts = {
  ok: number
  problema: number
  pendente: number
  total: number
}

export type ReturnConferencePlan = {
  items: ReturnConferenceItem[]
  counts: ReturnConferenceCounts
  hasPending: boolean
  canFinalizeEvent: boolean
}

export type ReturnDestination = {
  outcome: ReturnOutcome
  status_novo: StatusSerial
  opensPending: boolean
}

export type ReturnResolution = {
  acao: ReturnResolutionAction
  observacao: string | null
  status_novo: StatusSerial | 'UNCHANGED'
  closesPending: boolean
}

const OUTCOMES: ReturnOutcome[] = ['OK', 'PROBLEMA', 'NAO_VOLTOU']
const RESOLUTION_ACTIONS: ReturnResolutionAction[] = [
  'ENCONTRADA',
  'MANUTENCAO',
  'BAIXA',
  'COBRANCA',
]

export function clampDesgaste(value: unknown): number {
  const numeric = typeof value === 'number' ? value : Number(value)
  if (!Number.isFinite(numeric)) return 3
  return Math.max(1, Math.min(5, Math.round(numeric)))
}

export function normalizeObservation(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed.slice(0, 240) : null
}

export function normalizeReturnOutcome(
  value: unknown,
  legacyNeedsMaintenance?: unknown,
): ReturnOutcome | null {
  if (typeof value === 'string') {
    const normalized = value.trim().toUpperCase()
    if (OUTCOMES.includes(normalized as ReturnOutcome)) return normalized as ReturnOutcome
  }

  if (typeof legacyNeedsMaintenance === 'boolean') {
    return legacyNeedsMaintenance ? 'PROBLEMA' : 'OK'
  }

  return null
}

export function returnDestination(outcome: ReturnOutcome): ReturnDestination {
  if (outcome === 'PROBLEMA') {
    return { outcome, status_novo: 'MANUTENCAO', opensPending: false }
  }
  if (outcome === 'NAO_VOLTOU') {
    return { outcome, status_novo: 'RETORNANDO', opensPending: true }
  }
  return { outcome, status_novo: 'DISPONIVEL', opensPending: false }
}

export function buildReturnConferencePlan(
  rawItems: ReturnConferenceRawItem[],
): { ok: true; plan: ReturnConferencePlan } | { ok: false; error: string } {
  if (rawItems.length === 0) {
    return { ok: false, error: 'Nada pra receber de volta.' }
  }

  const seen = new Set<string>()
  const items: ReturnConferenceItem[] = []

  for (const raw of rawItems) {
    const serialId = typeof raw.serial_id === 'string' ? raw.serial_id.trim() : ''
    if (!serialId) return { ok: false, error: 'Unidade de retorno inválida.' }
    if (seen.has(serialId)) return { ok: false, error: 'Unidade duplicada no retorno.' }
    seen.add(serialId)

    const resultado = normalizeReturnOutcome(raw.resultado, raw.needs_maintenance)
    if (!resultado) return { ok: false, error: 'Resultado de retorno inválido.' }

    const observacao = normalizeObservation(raw.observacao)
    if (resultado === 'PROBLEMA' && (!observacao || observacao.length < 3)) {
      return { ok: false, error: 'Unidade com problema precisa de observação do Evento.' }
    }

    items.push({
      serial_id: serialId,
      desgaste: clampDesgaste(raw.desgaste),
      resultado,
      observacao,
    })
  }

  const counts = items.reduce<ReturnConferenceCounts>(
    (acc, item) => {
      if (item.resultado === 'OK') acc.ok += 1
      else if (item.resultado === 'PROBLEMA') acc.problema += 1
      else acc.pendente += 1
      acc.total += 1
      return acc
    },
    { ok: 0, problema: 0, pendente: 0, total: 0 },
  )

  return {
    ok: true,
    plan: {
      items,
      counts,
      hasPending: counts.pendente > 0,
      canFinalizeEvent: counts.pendente === 0,
    },
  }
}

export function normalizeReturnResolution(
  action: unknown,
  observation: unknown,
): { ok: true; resolution: ReturnResolution } | { ok: false; error: string } {
  const normalized = typeof action === 'string' ? action.trim().toUpperCase() : ''

  if (!RESOLUTION_ACTIONS.includes(normalized as ReturnResolutionAction)) {
    return { ok: false, error: 'Resolução de pendência inválida.' }
  }

  const acao = normalized as ReturnResolutionAction
  const observacao = normalizeObservation(observation)
  if ((acao === 'MANUTENCAO' || acao === 'COBRANCA') && (!observacao || observacao.length < 3)) {
    return { ok: false, error: 'Manutenção e cobrança precisam de observação.' }
  }

  const status_novo: ReturnResolution['status_novo'] =
    acao === 'ENCONTRADA'
      ? 'DISPONIVEL'
      : acao === 'MANUTENCAO'
        ? 'MANUTENCAO'
        : acao === 'BAIXA'
          ? 'BAIXA'
          : 'UNCHANGED'

  return {
    ok: true,
    resolution: {
      acao,
      observacao,
      status_novo,
      closesPending: true,
    },
  }
}
