import type { Categoria } from './types'

export type LegacyLoteLike = {
  quantidade: number
  item_categoria: Categoria
}

export type LegacyLoteSummary = {
  total_lotes: number
  cable_lotes: number
  non_cable_lotes: number
  unidades_totais: number
}

export type UnitOnlyQrLoteState<T> = {
  operational_lotes: T[]
  legacy_lotes: number
  legacy_cable_lotes: number
}

export type UnitOnlyRfidLegacyResolution = {
  reconhecido: boolean
  lote_id: null
  lote_codigo: null
  lote_status: null
  notas: string | null
}

export function summarizeLegacyLotes(lotes: readonly LegacyLoteLike[]): LegacyLoteSummary {
  let cableLotes = 0
  let unidadesTotais = 0

  for (const lote of lotes) {
    unidadesTotais += lote.quantidade
    if (lote.item_categoria === 'CABO') cableLotes += 1
  }

  return {
    total_lotes: lotes.length,
    cable_lotes: cableLotes,
    non_cable_lotes: lotes.length - cableLotes,
    unidades_totais: unidadesTotais,
  }
}

export function toUnitOnlyQrLoteState<T extends { item_categoria: Categoria }>(
  lotes: readonly T[],
): UnitOnlyQrLoteState<T> {
  return {
    operational_lotes: [],
    legacy_lotes: lotes.length,
    legacy_cable_lotes: lotes.filter((lote) => lote.item_categoria === 'CABO').length,
  }
}

export function resolveUnitOnlyRfidLegacy(input: {
  serial_id: string | null | undefined
  lote_id: string | null | undefined
  lote_codigo: string | null | undefined
  notas: string | null | undefined
}): UnitOnlyRfidLegacyResolution {
  const legacyLoteNote =
    input.lote_id && input.lote_codigo ? `Lote legado: ${input.lote_codigo}` : null

  return {
    reconhecido: input.serial_id != null,
    lote_id: null,
    lote_codigo: null,
    lote_status: null,
    notas: [input.notas, legacyLoteNote].filter(Boolean).join(' / ') || null,
  }
}
