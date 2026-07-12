import type { CheckoutGate, CheckoutGateIssue } from './checkout-gate-core'
import type { MetodoScan, StatusSerial } from './types'

const METODOS: MetodoScan[] = ['MANUAL', 'QRCODE', 'RFID']
const READY_STATUS: StatusSerial = 'DISPONIVEL'

export type CheckoutExecutionSerial = {
  id: string
  codigo_interno: string
  status: StatusSerial
}

export type CheckoutExecutionRental = {
  id: string
  fornecedor: string
  quantidade: number
}

export type CheckoutExecutionLineInput = {
  id: string
  item_nome: string
  qtd_necessaria: number
  qtd_alocada: number
  qtd_alugada_avulsa: number
  qtd_coberta: number
  qtd_faltante: number
  seriais_alocados: CheckoutExecutionSerial[]
  alugueis_avulsos: CheckoutExecutionRental[]
}

export type CheckoutExecutionLine = CheckoutExecutionLineInput & {
  qtd_extra: number
  invalid_seriais: CheckoutExecutionSerial[]
}

export type CheckoutExecutionPlan = {
  metodo: MetodoScan | null
  operador: string
  timestamp: string | null
  ownSerialCount: number
  externalRentalCount: number
  missingCount: number
  extraCount: number
  hasMissing: boolean
  hasExtras: boolean
  hasInvalidSerialStatus: boolean
  gateBlockers: CheckoutGateIssue[]
  hardBlockers: CheckoutGateIssue[]
  warnings: CheckoutGateIssue[]
  lines: CheckoutExecutionLine[]
  canExecuteStrict: boolean
  canExecuteWithOverride: boolean
}

export type CheckoutTransition = {
  serial_id: string
  codigo_interno: string
  status_anterior: StatusSerial
  status_novo: 'EM_CAMPO'
  registrado_por: string
  metodo_scan: MetodoScan
  timestamp: string
}

export function isMetodoScan(value: unknown): value is MetodoScan {
  return typeof value === 'string' && METODOS.includes(value as MetodoScan)
}

export function normalizeMetodoScan(value: unknown): MetodoScan | null {
  return isMetodoScan(value) ? value : null
}

function issue(
  id: string,
  message: string,
  extra: Pick<CheckoutGateIssue, 'itemName' | 'lineId'> = {},
): CheckoutGateIssue {
  return { id, severity: 'blocker', message, ...extra }
}

export function buildCheckoutExecutionPlan(input: {
  gate: CheckoutGate
  packing: CheckoutExecutionLineInput[]
  metodo: unknown
  operador: string | null | undefined
  now?: Date | string | null
}): CheckoutExecutionPlan {
  const metodo = normalizeMetodoScan(input.metodo)
  const operador = input.operador?.trim() || 'sessão autenticada'
  const timestamp =
    input.now instanceof Date
      ? input.now.toISOString()
      : typeof input.now === 'string'
        ? input.now
        : null

  const lines = input.packing.map((line) => {
    const ownCount = line.seriais_alocados.length
    const externalCount = line.alugueis_avulsos.reduce((acc, rental) => acc + rental.quantidade, 0)
    const qtd_extra = Math.max(0, ownCount + externalCount - line.qtd_necessaria)
    const invalid_seriais = line.seriais_alocados.filter((serial) => serial.status !== READY_STATUS)
    return {
      ...line,
      qtd_alocada: ownCount,
      qtd_alugada_avulsa: externalCount,
      qtd_extra,
      invalid_seriais,
    }
  })

  const ownSerialCount = lines.reduce((acc, line) => acc + line.seriais_alocados.length, 0)
  const externalRentalCount = lines.reduce((acc, line) => acc + line.qtd_alugada_avulsa, 0)
  const missingCount = lines.reduce((acc, line) => acc + line.qtd_faltante, 0)
  const extraCount = lines.reduce((acc, line) => acc + line.qtd_extra, 0)
  const warnings: CheckoutGateIssue[] = [...input.gate.warnings]
  const hardBlockers: CheckoutGateIssue[] = []

  if (!metodo) {
    hardBlockers.push(issue('metodo-invalid', 'Método de scan inválido.'))
  }

  for (const line of lines) {
    if (line.qtd_extra > 0) {
      warnings.push({
        id: `extra-${line.id}`,
        severity: 'warning',
        message: `${line.qtd_extra} unidade${line.qtd_extra === 1 ? '' : 's'} acima do necessário.`,
        itemName: line.item_nome,
        lineId: line.id,
      })
    }

    if (line.invalid_seriais.length > 0) {
      hardBlockers.push(
        issue(
          `serial-status-${line.id}`,
          `${line.invalid_seriais.length} serial${line.invalid_seriais.length === 1 ? '' : 'is'} próprio${line.invalid_seriais.length === 1 ? '' : 's'} não estão DISPONIVEL.`,
          { itemName: line.item_nome, lineId: line.id },
        ),
      )
    }
  }

  const hasInvalidSerialStatus = hardBlockers.some((blocker) =>
    blocker.id.startsWith('serial-status-'),
  )
  const canExecuteStrict = input.gate.canCheckout && hardBlockers.length === 0
  const canExecuteWithOverride = input.gate.canOverride && hardBlockers.length === 0

  return {
    metodo,
    operador,
    timestamp,
    ownSerialCount,
    externalRentalCount,
    missingCount,
    extraCount,
    hasMissing: missingCount > 0,
    hasExtras: extraCount > 0,
    hasInvalidSerialStatus,
    gateBlockers: input.gate.blockers,
    hardBlockers,
    warnings,
    lines,
    canExecuteStrict,
    canExecuteWithOverride,
  }
}

export function simulateAtomicCheckout(
  plan: CheckoutExecutionPlan,
  options: { allowOverride?: boolean; now?: Date | string } = {},
) {
  const timestamp =
    options.now instanceof Date
      ? options.now.toISOString()
      : typeof options.now === 'string'
        ? options.now
        : plan.timestamp

  if (!timestamp || !plan.metodo || plan.hardBlockers.length > 0) {
    return { ok: false as const, transitions: [] as CheckoutTransition[] }
  }

  if (!plan.canExecuteStrict && !(options.allowOverride && plan.canExecuteWithOverride)) {
    return { ok: false as const, transitions: [] as CheckoutTransition[] }
  }

  const transitions = plan.lines.flatMap((line) =>
    line.seriais_alocados.map((serial) => ({
      serial_id: serial.id,
      codigo_interno: serial.codigo_interno,
      status_anterior: serial.status,
      status_novo: 'EM_CAMPO' as const,
      registrado_por: plan.operador,
      metodo_scan: plan.metodo as MetodoScan,
      timestamp,
    })),
  )

  return { ok: true as const, transitions }
}
