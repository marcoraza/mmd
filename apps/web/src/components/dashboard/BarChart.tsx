import { CATEGORIA_LABELS, formatCurrency } from '@/lib/design-tokens'
import type { CategoriaStats } from '@/lib/types'

interface BarChartProps {
  data: CategoriaStats[]
  label: string
}

export function BarChart({ data, label }: BarChartProps) {
  const max = Math.max(...data.map((d) => d.valor), 1)

  return (
    <div style={{ borderRight: '1px solid #E8E8E8', padding: '20px 24px' }}>
      <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 16 }}>
        {label.toUpperCase()}
      </div>
      <div className="flex items-end gap-3" style={{ height: 120 }}>
        {data.map((d) => {
          const height = Math.max((d.valor / max) * 100, 2)
          return (
            <div key={d.categoria} className="flex flex-col items-center gap-1 flex-1">
              <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 8, color: '#666666' }}>
                {formatCurrency(d.valor)}
              </span>
              <div
                style={{
                  width: '100%',
                  height: `${height}%`,
                  backgroundColor: '#000000',
                }}
              />
              <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 7, color: '#999999', letterSpacing: '0.06em', textAlign: 'center' }}>
                {(CATEGORIA_LABELS[d.categoria] ?? d.categoria).substring(0, 3).toUpperCase()}
              </span>
            </div>
          )
        })}
      </div>
    </div>
  )
}
