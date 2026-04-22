import type { Categoria, Estado, StatusSerial } from '@/lib/types'

export const CATEGORIA_LABEL: Record<Categoria, string> = {
  ILUMINACAO: 'Iluminação',
  AUDIO: 'Áudio',
  ENERGIA: 'Energia',
  ESTRUTURA: 'Estrutura',
  EFEITO: 'Efeito',
  VIDEO: 'Vídeo',
  ACESSORIO: 'Acessório',
  CABO: 'Cabo',
}

export const CATEGORIA_ICON: Record<Categoria, string> = {
  ILUMINACAO: 'cat_iluminacao',
  AUDIO: 'cat_audio',
  ENERGIA: 'cat_energia',
  ESTRUTURA: 'cat_estrutura',
  EFEITO: 'cat_efeito',
  VIDEO: 'cat_video',
  ACESSORIO: 'cat_acessorio',
  CABO: 'cat_cabo',
}

export const SITUACAO_LABEL: Record<StatusSerial | 'MISTO', string> = {
  DISPONIVEL: 'Disponível',
  PACKED: 'Separado',
  EM_CAMPO: 'Em campo',
  RETORNANDO: 'Retornando',
  MANUTENCAO: 'Manutenção',
  EMPRESTADO: 'Emprestado',
  VENDIDO: 'Vendido',
  BAIXA: 'Baixa',
  MISTO: 'Misto',
}

export const SITUACAO_COLOR: Record<StatusSerial | 'MISTO', string> = {
  DISPONIVEL: 'var(--accent-green)',
  PACKED: 'var(--accent-cyan)',
  EM_CAMPO: 'var(--accent-cyan)',
  RETORNANDO: 'var(--accent-violet)',
  MANUTENCAO: 'var(--accent-amber)',
  EMPRESTADO: 'var(--accent-violet)',
  VENDIDO: 'var(--fg-3)',
  BAIXA: 'var(--fg-3)',
  MISTO: 'var(--fg-2)',
}

export const CICLO_LABEL: Record<Estado | 'MISTO', string> = {
  NOVO: 'Novo',
  SEMI_NOVO: 'Semi-novo',
  USADO: 'Usado',
  RECONDICIONADO: 'Recond.',
  MISTO: 'Misto',
}

export function formatBRL(n: number | null | undefined): string {
  if (n == null) return '–'
  return n.toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  })
}

export function formatBRLCompact(n: number): string {
  if (n >= 1000) return `R$ ${Math.round(n / 1000)}k`
  return `R$ ${Math.round(n)}`
}

export function roundStars(n: number): number {
  return Math.max(0, Math.min(5, Math.round(n)))
}
