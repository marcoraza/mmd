import { CATEGORIA_LABELS, formatCurrency } from '@/lib/design-tokens'
import type { CategoriaStats } from '@/lib/types'

interface CategoryRankingProps {
  data: CategoriaStats[]
}

export function CategoryRanking({ data }: CategoryRankingProps) {
  const sorted = [...data].sort((a, b) => b.valor - a.valor)
  const max = sorted[0]?.valor ?? 1

  return (
    <div style={{ padding: '20px 24px' }}>
      <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 16 }}>
        TOP CATEGORIAS — VALOR
      </div>
      <div className="flex flex-col gap-3">
        {sorted.map((d, i) => (
          <div key={d.categoria}>
            <div className="flex items-center gap-3 mb-1">
              <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', width: 16 }}>
                {String(i + 1).padStart(2, '0')}
              </span>
              <span style={{ fontFamily: '"Space Grotesk", sans-serif', fontSize: 13, color: '#1A1A1A', flex: 1 }}>
                {CATEGORIA_LABELS[d.categoria] ?? d.categoria}
              </span>
              <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 12, fontWeight: 700, color: '#000000' }}>
                {formatCurrency(d.valor)}
              </span>
            </div>
            <div style={{ height: 3, backgroundColor: '#E8E8E8', marginLeft: 28 }}>
              <div style={{ height: '100%', width: `${(d.valor / max) * 100}%`, backgroundColor: '#000000' }} />
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
