import type { StatusSerial } from './types'

export type AllocationTone = 'available' | 'conflict' | 'blocked'

export type AllocationCandidateLike = {
  id: string
  codigo_interno: string
  status: StatusSerial
  desgaste: number
  last_moved_at: string | null
  conflicts_with: unknown[]
}

export type AllocationState = {
  selectable: boolean
  tone: AllocationTone
  label: string
  alert: string | null
}

export function allocationRangesOverlap(
  aStart: string,
  aEnd: string,
  bStart: string,
  bEnd: string,
) {
  return aStart <= bEnd && bStart <= aEnd
}

export function serialAllocationState(status: StatusSerial, conflictCount: number): AllocationState {
  if (status === 'DISPONIVEL' && conflictCount > 0) {
    return {
      selectable: true,
      tone: 'conflict',
      label: 'Conflito',
      alert: 'Conflito de data. Pode planejar, mas precisa revisar ou alugar avulso.',
    }
  }

  if (status === 'DISPONIVEL') {
    return {
      selectable: true,
      tone: 'available',
      label: 'Disponível',
      alert: null,
    }
  }

  if (status === 'MANUTENCAO') {
    return {
      selectable: false,
      tone: 'blocked',
      label: 'Manutenção',
      alert: 'Unidade em manutenção não entra na alocação.',
    }
  }

  if (status === 'PACKED' || status === 'EM_CAMPO') {
    return {
      selectable: false,
      tone: 'blocked',
      label: 'Em campo',
      alert: 'Unidade já está separada ou em campo.',
    }
  }

  return {
    selectable: false,
    tone: 'blocked',
    label: 'Indisponível',
    alert: `Status ${status} não pode ser alocado.`,
  }
}

export function sortAllocationCandidates<T extends AllocationCandidateLike>(candidates: T[]): T[] {
  return [...candidates].sort((a, b) => {
    const aState = serialAllocationState(a.status, a.conflicts_with.length)
    const bState = serialAllocationState(b.status, b.conflicts_with.length)
    if (aState.selectable !== bState.selectable) return aState.selectable ? -1 : 1
    if (aState.tone !== bState.tone) {
      if (aState.tone === 'available') return -1
      if (bState.tone === 'available') return 1
      if (aState.tone === 'conflict') return -1
      if (bState.tone === 'conflict') return 1
    }
    if (a.last_moved_at === null && b.last_moved_at !== null) return -1
    if (a.last_moved_at !== null && b.last_moved_at === null) return 1
    if (a.last_moved_at !== null && b.last_moved_at !== null) {
      const moved = a.last_moved_at.localeCompare(b.last_moved_at)
      if (moved !== 0) return moved
    }
    if (a.desgaste !== b.desgaste) return a.desgaste - b.desgaste
    return a.codigo_interno.localeCompare(b.codigo_interno)
  })
}

export function pickAutoAllocationCandidates<T extends AllocationCandidateLike>(
  candidates: T[],
  missing: number,
): T[] {
  if (missing <= 0) return []
  return sortAllocationCandidates(candidates)
    .filter((candidate) =>
      serialAllocationState(candidate.status, candidate.conflicts_with.length).selectable,
    )
    .slice(0, missing)
}
