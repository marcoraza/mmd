export type CheckoutGateSeverity = 'pass' | 'warning' | 'blocker'

export type CheckoutGateCheckId = 'ficha' | 'packing' | 'cobertura' | 'conflitos' | 'checklist'

export type CheckoutGateStatusProjeto =
  'PLANEJAMENTO' | 'CONFIRMADO' | 'MONTAGEM' | 'EM_CAMPO' | 'FINALIZADO' | 'CANCELADO'

export type CheckoutGatePackingStatus = 'ok' | 'partial' | 'missing' | 'conflict'

export type CheckoutGateConflictRef = {
  projeto_id: string
  projeto_nome: string
  data_inicio: string
  data_fim: string
  status: CheckoutGateStatusProjeto
  qtd_necessaria: number
  qtd_alocada: number
}

export type CheckoutGateCheck = {
  id: CheckoutGateCheckId
  label: string
  severity: CheckoutGateSeverity
  detail: string
  pct: number
}

export type CheckoutGateIssue = {
  id: string
  severity: Exclude<CheckoutGateSeverity, 'pass'>
  message: string
  itemName?: string
  lineId?: string
}

export type CheckoutGateLine = {
  id: string
  item_nome: string
  qtd_necessaria: number
  qtd_alocada: number
  qtd_alugada_avulsa: number
  qtd_coberta: number
  qtd_faltante: number
  status: CheckoutGatePackingStatus
  conflicts_with?: CheckoutGateConflictRef[]
}

export type CheckoutGateFicha = {
  total: number
  preenchidos: number
  pct: number
  missingLabels: string[]
  checklistTotal: number
  checklistOk: number
  checklistPendentes: number
}

export type CheckoutGate = {
  canCheckout: boolean
  canOverride: boolean
  readinessPct: number
  blockers: CheckoutGateIssue[]
  warnings: CheckoutGateIssue[]
  checks: CheckoutGateCheck[]
  resumo: {
    qtdNecessaria: number
    qtdPropria: number
    qtdAvulsa: number
    qtdCoberta: number
    qtdFaltante: number
  }
}

export type CheckoutGateInput = {
  status: CheckoutGateStatusProjeto
  ficha: CheckoutGateFicha | null
  packing: CheckoutGateLine[]
}

const CHECKOUT_READY_STATUSES: CheckoutGateStatusProjeto[] = ['CONFIRMADO', 'MONTAGEM']

function severityForPct(pct: number): CheckoutGateSeverity {
  if (pct >= 100) return 'pass'
  if (pct > 0) return 'warning'
  return 'blocker'
}

function issue(
  id: string,
  severity: CheckoutGateIssue['severity'],
  message: string,
  extra: Pick<CheckoutGateIssue, 'itemName' | 'lineId'> = {},
): CheckoutGateIssue {
  return { id, severity, message, ...extra }
}

export function buildCheckoutGate(input: CheckoutGateInput): CheckoutGate {
  const blockers: CheckoutGateIssue[] = []
  const warnings: CheckoutGateIssue[] = []
  const packing = input.packing
  const qtdNecessaria = packing.reduce((acc, line) => acc + line.qtd_necessaria, 0)
  const qtdPropria = packing.reduce((acc, line) => acc + line.qtd_alocada, 0)
  const qtdAvulsa = packing.reduce((acc, line) => acc + line.qtd_alugada_avulsa, 0)
  const qtdCoberta = packing.reduce((acc, line) => acc + line.qtd_coberta, 0)
  const qtdFaltante = packing.reduce((acc, line) => acc + line.qtd_faltante, 0)
  const coveragePct = qtdNecessaria > 0 ? Math.round((qtdCoberta / qtdNecessaria) * 100) : 0

  const statusAllowsCheckout = CHECKOUT_READY_STATUSES.includes(input.status)
  if (!statusAllowsCheckout) {
    blockers.push(
      issue(
        'status',
        'blocker',
        'Evento precisa estar Confirmado ou em Montagem antes do check-out.',
      ),
    )
  }

  const fichaPct = input.ficha?.pct ?? 0
  if (!input.ficha) {
    blockers.push(issue('ficha-missing', 'blocker', 'Ficha do evento não preenchida.'))
  } else if (input.ficha.pct < 100) {
    const missing = input.ficha.missingLabels.slice(0, 3).join(', ')
    blockers.push(
      issue(
        'ficha-incomplete',
        'blocker',
        missing ? `Ficha incompleta: falta ${missing}.` : 'Ficha do evento ainda está incompleta.',
      ),
    )
  }

  if (packing.length === 0) {
    blockers.push(issue('packing-empty', 'blocker', 'Packing list ainda não foi criado.'))
  }

  for (const line of packing) {
    if (line.qtd_faltante > 0) {
      blockers.push(
        issue(
          `coverage-${line.id}`,
          'blocker',
          `${line.qtd_faltante} unidade${line.qtd_faltante === 1 ? '' : 's'} sem cobertura.`,
          { itemName: line.item_nome, lineId: line.id },
        ),
      )
    }

    const conflictCount = line.conflicts_with?.length ?? 0
    if (conflictCount > 0) {
      blockers.push(
        issue(
          `conflict-${line.id}`,
          'blocker',
          `${conflictCount} conflito${conflictCount === 1 ? '' : 's'} de data pendente${conflictCount === 1 ? '' : 's'}.`,
          { itemName: line.item_nome, lineId: line.id },
        ),
      )
    }
  }

  const checklistTotal = input.ficha?.checklistTotal ?? 0
  const checklistOk = input.ficha?.checklistOk ?? 0
  const checklistPendentes = input.ficha?.checklistPendentes ?? 0
  const checklistPct = checklistTotal > 0 ? Math.round((checklistOk / checklistTotal) * 100) : 0

  if (input.ficha && checklistTotal === 0) {
    blockers.push(issue('checklist-empty', 'blocker', 'Checklist de saída sem itens confirmados.'))
  } else if (checklistPendentes > 0) {
    blockers.push(
      issue(
        'checklist-pending',
        'blocker',
        `${checklistPendentes} item${checklistPendentes === 1 ? '' : 's'} do checklist pendente${checklistPendentes === 1 ? '' : 's'}.`,
      ),
    )
  }

  const checks: CheckoutGateCheck[] = [
    {
      id: 'ficha',
      label: 'Ficha',
      severity: severityForPct(fichaPct),
      detail: input.ficha ? `${input.ficha.preenchidos}/${input.ficha.total}` : 'não preenchida',
      pct: fichaPct,
    },
    {
      id: 'packing',
      label: 'Packing',
      severity: packing.length > 0 ? 'pass' : 'blocker',
      detail: packing.length > 0 ? `${packing.length} linhas` : 'não criado',
      pct: packing.length > 0 ? 100 : 0,
    },
    {
      id: 'cobertura',
      label: 'Cobertura',
      severity: severityForPct(coveragePct),
      detail: `${qtdCoberta}/${qtdNecessaria}`,
      pct: coveragePct,
    },
    {
      id: 'conflitos',
      label: 'Conflitos',
      severity: packing.some((line) => (line.conflicts_with?.length ?? 0) > 0) ? 'blocker' : 'pass',
      detail: packing.some((line) => (line.conflicts_with?.length ?? 0) > 0) ? 'pendente' : 'limpo',
      pct: packing.some((line) => (line.conflicts_with?.length ?? 0) > 0) ? 0 : 100,
    },
    {
      id: 'checklist',
      label: 'Checklist',
      severity: severityForPct(checklistPct),
      detail: checklistTotal > 0 ? `${checklistOk}/${checklistTotal}` : 'sem itens',
      pct: checklistPct,
    },
  ]

  const readinessPct = Math.round(
    checks.reduce((acc, check) => acc + Math.max(0, Math.min(100, check.pct)), 0) / checks.length,
  )
  const canCheckout = statusAllowsCheckout && blockers.length === 0
  const canOverride = statusAllowsCheckout && blockers.length > 0

  return {
    canCheckout,
    canOverride,
    readinessPct,
    blockers,
    warnings,
    checks,
    resumo: {
      qtdNecessaria,
      qtdPropria,
      qtdAvulsa,
      qtdCoberta,
      qtdFaltante,
    },
  }
}

export function normalizeCheckoutOverrideReason(reason: string | null | undefined) {
  const value = reason?.trim().replace(/\s+/g, ' ') ?? ''
  if (value.length < 10) {
    return {
      ok: false as const,
      error: 'Motivo do override deve ter pelo menos 10 caracteres.',
    }
  }
  return { ok: true as const, value }
}

export function checkoutGateAuditPayload(gate: CheckoutGate) {
  return {
    readiness_pct: gate.readinessPct,
    blockers: gate.blockers,
    warnings: gate.warnings,
    checks: gate.checks,
    resumo: gate.resumo,
  }
}
