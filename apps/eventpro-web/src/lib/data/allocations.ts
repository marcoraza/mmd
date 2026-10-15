import 'server-only'

import type { Estado, StatusSerial } from '@/lib/types'

// Alocação no EventPro é a tabela relacional `packing_allocations` (uma linha
// por unidade alocada, UNIQUE por serial), não a coluna `uuid[]`
// `serial_numbers_designados` do legado.
//
// As libs puras portadas (`checkout-execution-core`, `external-rental-core`,
// `checkout-gate-core`) continuam recebendo o mesmo shape em memória:
// `seriais_alocados: AllocatedSerialDetail[]` e, onde só a contagem importa,
// uma lista de ids. Este módulo concentra a tradução linha relacional -> shape
// em memória, para nenhuma outra camada precisar saber do formato do embed.

export type AllocatedSerialDetail = {
  id: string
  codigo_interno: string
  status: StatusSerial
  estado: Estado
  desgaste: number
}

export type AllocationEmbedRow = {
  serial_id: string
  serial_numbers?: AllocatedSerialDetail | AllocatedSerialDetail[] | null
}

export const ALLOCATION_ID_EMBED = 'packing_allocations ( serial_id )'

export const ALLOCATION_DETAIL_EMBED = `packing_allocations (
         serial_id,
         serial_numbers ( id, codigo_interno, status, estado, desgaste )
       )`

function firstRelated<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) return value[0] ?? null
  return value ?? null
}

// Lista de ids alocados numa linha de packing, na ordem em que o PostgREST
// devolveu. Substitui a leitura direta de `serial_numbers_designados`.
export function allocationSerialIds(rows: AllocationEmbedRow[] | null | undefined): string[] {
  return (rows ?? []).map((row) => row.serial_id)
}

// Unidades alocadas já hidratadas, ordenadas por código interno para a UI e os
// planos de execução terem ordem estável.
export function allocationSerialDetails(
  rows: AllocationEmbedRow[] | null | undefined,
): AllocatedSerialDetail[] {
  return (rows ?? [])
    .map((row) => firstRelated(row.serial_numbers))
    .filter((serial): serial is AllocatedSerialDetail => serial != null)
    .sort((a, b) => a.codigo_interno.localeCompare(b.codigo_interno))
}
