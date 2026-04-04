export const COLORS = {
  black: '#000000',
  surface: '#111111',
  surfaceRaised: '#1A1A1A',
  border: '#222222',
  borderVisible: '#333333',
  textDisabled: '#666666',
  textSecondary: '#999999',
  textPrimary: '#E8E8E8',
  textDisplay: '#FFFFFF',
  accent: '#D71921',
  success: '#4A9E5C',
  warning: '#D4A843',
  interactive: '#5B9BF6',
} as const

export const STATUS_COLORS: Record<string, string> = {
  DISPONIVEL: '#4A9E5C',
  PACKED: '#FFFFFF',
  EM_CAMPO: '#D4A843',
  RETORNANDO: '#5B9BF6',
  MANUTENCAO: '#D71921',
  EMPRESTADO: '#999999',
  VENDIDO: '#666666',
  BAIXA: '#666666',
}

export const WEAR_COLORS: Record<number, string> = {
  5: '#4A9E5C',
  4: '#4A9E5C',
  3: '#FFFFFF',
  2: '#D4A843',
  1: '#D71921',
}

export const CATEGORIA_LABELS: Record<string, string> = {
  ILUMINACAO: 'Iluminação',
  AUDIO: 'Áudio',
  CABO: 'Cabo',
  ENERGIA: 'Energia',
  ESTRUTURA: 'Estrutura',
  EFEITO: 'Efeito',
  VIDEO: 'Vídeo',
  ACESSORIO: 'Acessório',
}

export const STATUS_LABELS: Record<string, string> = {
  DISPONIVEL: 'Disponível',
  PACKED: 'Packed',
  EM_CAMPO: 'Em Campo',
  RETORNANDO: 'Retornando',
  MANUTENCAO: 'Manutenção',
  EMPRESTADO: 'Emprestado',
  VENDIDO: 'Vendido',
  BAIXA: 'Baixa',
}

export const ESTADO_LABELS: Record<string, string> = {
  NOVO: 'Novo',
  SEMI_NOVO: 'Semi-Novo',
  USADO: 'Usado',
  RECONDICIONADO: 'Recondicionado',
}

export function formatCurrency(value: number): string {
  if (value >= 1000000) return `R$${(value / 1000000).toFixed(1)}M`
  if (value >= 1000) return `R$${(value / 1000).toFixed(1)}K`
  return `R$${value.toFixed(0)}`
}

export function formatCurrencyFull(value: number): string {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value)
}
