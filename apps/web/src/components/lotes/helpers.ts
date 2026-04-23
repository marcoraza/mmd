import type { StatusLote } from '@/lib/data/lotes'

export const STATUS_LOTE_LABEL: Record<StatusLote, string> = {
  DISPONIVEL: 'Disponível',
  EM_CAMPO: 'Em campo',
  MANUTENCAO: 'Manutenção',
}

export const STATUS_LOTE_COLOR: Record<StatusLote, string> = {
  DISPONIVEL: 'var(--accent-green)',
  EM_CAMPO: 'var(--accent-cyan)',
  MANUTENCAO: 'var(--accent-amber)',
}

const DATE_FMT = new Intl.DateTimeFormat('pt-BR', {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
})

export function formatLoteDate(iso: string): string {
  try {
    const d = new Date(iso)
    return DATE_FMT.format(d).replace('.', '').toLowerCase()
  } catch {
    return iso
  }
}
