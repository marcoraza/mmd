import type { Estado, StatusSerial, TipoMovimentacao } from '@/lib/types'

export const ESTADO_FATOR: Record<Estado, number> = {
  NOVO: 1.0,
  SEMI_NOVO: 0.85,
  USADO: 0.65,
  RECONDICIONADO: 0.5,
}

export const ESTADO_LABEL: Record<Estado, string> = {
  NOVO: 'Novo',
  SEMI_NOVO: 'Semi-novo',
  USADO: 'Usado',
  RECONDICIONADO: 'Recond.',
}

export const ESTADO_SHORT: Record<Estado, string> = {
  NOVO: 'NOVO',
  SEMI_NOVO: 'SEMI',
  USADO: 'USADO',
  RECONDICIONADO: 'RECOND.',
}

export const TIPO_COR: Record<TipoMovimentacao, string> = {
  SAIDA: 'var(--accent-violet)',
  RETORNO: 'var(--accent-green)',
  MANUTENCAO: 'var(--accent-amber)',
  TRANSFERENCIA: 'var(--accent-cyan)',
  DANO: 'var(--accent-red)',
}

export const TIPO_LABEL: Record<TipoMovimentacao, string> = {
  SAIDA: 'Saída',
  RETORNO: 'Retorno',
  MANUTENCAO: 'Manutenção',
  TRANSFERENCIA: 'Transferência',
  DANO: 'Dano',
}

export function avaliacao(cond: number): { label: string; color: string } {
  if (cond >= 4.5) return { label: 'Excelente', color: 'var(--accent-green)' }
  if (cond >= 3.5) return { label: 'Bom', color: 'var(--accent-green)' }
  if (cond >= 2.5) return { label: 'Regular', color: 'var(--accent-amber)' }
  if (cond >= 1.5) return { label: 'Desgastado', color: 'var(--accent-amber)' }
  return { label: 'Crítico', color: 'var(--accent-red)' }
}

export function dominantEstado(serials: { estado: Estado }[]): Estado | null {
  if (serials.length === 0) return null
  const counts = new Map<Estado, number>()
  for (const s of serials) counts.set(s.estado, (counts.get(s.estado) ?? 0) + 1)
  let best: Estado | null = null
  let n = 0
  for (const [k, v] of counts) {
    if (v > n) {
      best = k
      n = v
    }
  }
  return best
}

export function formatTimestamp(iso: string): string {
  const d = new Date(iso)
  const now = new Date()
  const sameDay =
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate()
  const time = d.toLocaleTimeString('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
  })
  if (sameDay) return `Hoje, ${time}`
  const dayMonth = d.toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: 'short',
  })
  return `${dayMonth}, ${time}`
}

export function relativeDays(iso: string): string {
  const then = new Date(iso).getTime()
  const now = Date.now()
  const diffMs = now - then
  const days = Math.floor(diffMs / (1000 * 60 * 60 * 24))
  if (days <= 0) return 'hoje'
  if (days === 1) return 'ontem'
  if (days < 30) return `há ${days} dias`
  const months = Math.floor(days / 30)
  if (months === 1) return 'há 1 mês'
  if (months < 12) return `há ${months} meses`
  const years = Math.floor(months / 12)
  return years === 1 ? 'há 1 ano' : `há ${years} anos`
}

export function statusDotColor(s: StatusSerial): string {
  switch (s) {
    case 'DISPONIVEL':
      return 'var(--accent-green)'
    case 'EM_CAMPO':
    case 'PACKED':
      return 'var(--accent-cyan)'
    case 'RETORNANDO':
      return 'var(--accent-violet)'
    case 'MANUTENCAO':
      return 'var(--accent-amber)'
    case 'EMPRESTADO':
      return 'var(--accent-violet)'
    case 'VENDIDO':
    case 'BAIXA':
      return 'var(--fg-3)'
    default:
      return 'var(--fg-2)'
  }
}
