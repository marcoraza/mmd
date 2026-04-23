import type { ContextoScan, StatusReader } from '@/lib/data/rfid'

export const CONTEXTO_LABEL: Record<ContextoScan, string> = {
  PACKING: 'Packing',
  CARREGAMENTO: 'Carregamento',
  CHECK_IN_EVENTO: 'Check-in',
  CHECK_OUT_EVENTO: 'Check-out',
  RETORNO: 'Retorno',
  CONFERENCIA: 'Conferência',
  INVENTARIO: 'Inventário',
  OUTRO: 'Outro',
}

export const CONTEXTO_COLOR: Record<ContextoScan, string> = {
  PACKING: 'var(--accent-cyan)',
  CARREGAMENTO: 'var(--accent-violet)',
  CHECK_IN_EVENTO: 'var(--accent-green)',
  CHECK_OUT_EVENTO: 'var(--accent-amber)',
  RETORNO: 'var(--accent-green)',
  CONFERENCIA: 'var(--accent-cyan)',
  INVENTARIO: 'var(--fg-2)',
  OUTRO: 'var(--fg-3)',
}

export const READER_STATUS_LABEL: Record<StatusReader, string> = {
  ATIVO: 'Ativo',
  INATIVO: 'Inativo',
  MANUTENCAO: 'Manutenção',
}

export const READER_STATUS_COLOR: Record<StatusReader, string> = {
  ATIVO: 'var(--accent-green)',
  INATIVO: 'var(--fg-3)',
  MANUTENCAO: 'var(--accent-amber)',
}

export function formatRelativeTime(iso: string): string {
  const now = Date.now()
  const then = new Date(iso).getTime()
  const diffMs = now - then
  if (diffMs < 0) return 'agora'
  const sec = Math.floor(diffMs / 1000)
  if (sec < 60) return `${sec}s atrás`
  const min = Math.floor(sec / 60)
  if (min < 60) return `${min}min atrás`
  const hr = Math.floor(min / 60)
  if (hr < 24) return `${hr}h atrás`
  const days = Math.floor(hr / 24)
  if (days < 30) return `${days}d atrás`
  const months = Math.floor(days / 30)
  if (months < 12) return `${months}m atrás`
  return `${Math.floor(months / 12)}a atrás`
}

const TIME_FMT = new Intl.DateTimeFormat('pt-BR', {
  hour: '2-digit',
  minute: '2-digit',
})

const DATE_FMT = new Intl.DateTimeFormat('pt-BR', {
  day: '2-digit',
  month: 'short',
})

export function formatScanTime(iso: string): string {
  try {
    const d = new Date(iso)
    const today = new Date()
    const sameDay =
      d.getFullYear() === today.getFullYear() &&
      d.getMonth() === today.getMonth() &&
      d.getDate() === today.getDate()
    if (sameDay) return TIME_FMT.format(d)
    return `${DATE_FMT.format(d).replace('.', '')} · ${TIME_FMT.format(d)}`
  } catch {
    return iso
  }
}
