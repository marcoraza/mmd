/**
 * Layouts de folhas de etiqueta A4. Dimensões em mm (converter pra pt no PDF:
 * 1 mm = 2.8346 pt). Layouts aproximam padrões Pimaco clássicos.
 */
export type QrLayoutKey = 'small' | 'medium' | 'large'

export type QrLayout = {
  key: QrLayoutKey
  label: string
  description: string
  pageWidthMm: number
  pageHeightMm: number
  marginXMm: number
  marginYMm: number
  cols: number
  rows: number
  cellWidthMm: number
  cellHeightMm: number
  gapXMm: number
  gapYMm: number
  qrSizeMm: number
  perSheet: number
}

export const QR_LAYOUTS: Record<QrLayoutKey, QrLayout> = {
  small: {
    key: 'small',
    label: 'Pequena (3×10)',
    description: '30 por folha · 63,5 × 38,1 mm',
    pageWidthMm: 210,
    pageHeightMm: 297,
    marginXMm: 7.75,
    marginYMm: 10.7,
    cols: 3,
    rows: 10,
    cellWidthMm: 63.5,
    cellHeightMm: 38.1,
    gapXMm: 2.5,
    gapYMm: 0,
    qrSizeMm: 30,
    perSheet: 30,
  },
  medium: {
    key: 'medium',
    label: 'Média (2×7)',
    description: '14 por folha · 99,1 × 38,1 mm',
    pageWidthMm: 210,
    pageHeightMm: 297,
    marginXMm: 4.65,
    marginYMm: 15,
    cols: 2,
    rows: 7,
    cellWidthMm: 99.1,
    cellHeightMm: 38.1,
    gapXMm: 2.5,
    gapYMm: 0,
    qrSizeMm: 32,
    perSheet: 14,
  },
  large: {
    key: 'large',
    label: 'Grande (1×8)',
    description: '8 por folha · 190 × 31 mm',
    pageWidthMm: 210,
    pageHeightMm: 297,
    marginXMm: 10,
    marginYMm: 20,
    cols: 1,
    rows: 8,
    cellWidthMm: 190,
    cellHeightMm: 31,
    gapXMm: 0,
    gapYMm: 2,
    qrSizeMm: 26,
    perSheet: 8,
  },
}

export type QrItem = {
  /** conteúdo do QR (código único do item ou lote) */
  payload: string
  /** texto principal da etiqueta (código) */
  title: string
  /** texto secundário (nome do item) */
  subtitle?: string
  /** chip pequeno (categoria/status) */
  caption?: string
}

export const MM_TO_PT = 2.8346456693
