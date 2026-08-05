import type { PackingStatus } from './types'

export type ExternalRentalCoverage = {
  id: string
  fornecedor: string
  quantidade: number
  observacao: string
  created_at: string | null
}

export type ExternalRentalInput = {
  fornecedor: string
  quantidade: number
  observacao: string
}

export type PackingCoverage = {
  qtd_propria: number
  qtd_alugada_avulsa: number
  qtd_coberta: number
  qtd_faltante: number
  status: PackingStatus
}

export type RentalActionResult<T> = { ok: true; data: T } | { ok: false; error: string }

function cleanText(value: unknown) {
  return typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : ''
}

function positiveInteger(value: unknown) {
  const numberValue = Number(value)
  return Number.isInteger(numberValue) && numberValue > 0 ? numberValue : null
}

export function normalizeExternalRentalInput(
  input: ExternalRentalInput,
  options: { id: string; createdAt: string },
): RentalActionResult<ExternalRentalCoverage> {
  const fornecedor = cleanText(input.fornecedor)
  const observacao = cleanText(input.observacao)
  const quantidade = positiveInteger(input.quantidade)

  if (!fornecedor) return { ok: false, error: 'Parceiro obrigatório.' }
  if (!quantidade) return { ok: false, error: 'Quantidade do aluguel inválida.' }
  if (!observacao || observacao.length < 3) {
    return { ok: false, error: 'Obs do aluguel avulso obrigatória.' }
  }

  return {
    ok: true,
    data: {
      id: options.id,
      fornecedor,
      quantidade,
      observacao,
      created_at: options.createdAt,
    },
  }
}

export function parseExternalRentalCoverages(value: unknown): ExternalRentalCoverage[] {
  if (!Array.isArray(value)) return []

  return value.flatMap((entry) => {
    if (!entry || typeof entry !== 'object') return []
    const record = entry as Record<string, unknown>
    const id = cleanText(record.id)
    const fornecedor = cleanText(record.fornecedor)
    const observacao = cleanText(record.observacao)
    const quantidade = positiveInteger(record.quantidade)
    const createdAt = cleanText(record.created_at)

    if (!id || !fornecedor || !observacao || !quantidade) return []
    return [
      {
        id,
        fornecedor,
        quantidade,
        observacao,
        created_at: createdAt || null,
      },
    ]
  })
}

export function sumExternalRentalQuantity(rentals: ExternalRentalCoverage[]) {
  return rentals.reduce((acc, rental) => acc + rental.quantidade, 0)
}

export function computePackingCoverage(input: {
  qtdNecessaria: number
  qtdPropria: number
  alugueisAvulsos: ExternalRentalCoverage[]
}): PackingCoverage {
  const qtdNecessaria = Math.max(0, Math.floor(Number(input.qtdNecessaria) || 0))
  const qtdPropria = Math.max(0, Math.floor(Number(input.qtdPropria) || 0))
  const qtdAlugadaAvulsa = sumExternalRentalQuantity(input.alugueisAvulsos)
  const qtdCoberta = Math.min(qtdNecessaria, qtdPropria + qtdAlugadaAvulsa)
  const qtdFaltante = Math.max(qtdNecessaria - qtdPropria - qtdAlugadaAvulsa, 0)

  return {
    qtd_propria: qtdPropria,
    qtd_alugada_avulsa: qtdAlugadaAvulsa,
    qtd_coberta: qtdCoberta,
    qtd_faltante: qtdFaltante,
    status:
      qtdCoberta >= qtdNecessaria && qtdNecessaria > 0
        ? 'ok'
        : qtdCoberta > 0
          ? 'partial'
          : 'missing',
  }
}
