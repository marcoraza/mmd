import type { StatusProjeto } from '@/lib/data/projects'

const DATE_FMT = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: 'short' })

export function formatProjetoDate(iso: string): string {
  const [y, m, d] = iso.split('-').map(Number)
  return DATE_FMT.format(new Date(y, m - 1, d)).replace('.', '').toLowerCase()
}

export function statusProjetoLabel(s: StatusProjeto): string {
  switch (s) {
    case 'PLANEJAMENTO': return 'Planejamento'
    case 'CONFIRMADO': return 'Confirmado'
    case 'EM_CAMPO': return 'Em campo'
    case 'FINALIZADO': return 'Finalizado'
    case 'CANCELADO': return 'Cancelado'
  }
}

export function statusProjetoColor(s: StatusProjeto): string {
  switch (s) {
    case 'PLANEJAMENTO': return 'var(--fg-3)'
    case 'CONFIRMADO': return 'var(--accent-cyan)'
    case 'EM_CAMPO': return 'var(--accent-violet)'
    case 'FINALIZADO': return 'var(--fg-3)'
    case 'CANCELADO': return 'var(--accent-red)'
  }
}

export function readinessRingState(pct: number): 'ready' | 'partial' | 'missing' {
  if (pct >= 100) return 'ready'
  if (pct > 0) return 'partial'
  return 'missing'
}
