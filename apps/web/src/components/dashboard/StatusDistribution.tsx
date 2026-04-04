import { STATUS_COLORS, STATUS_LABELS } from '@/lib/design-tokens'
import type { StatusStats } from '@/lib/types'

interface StatusDistributionProps {
  data: StatusStats[]
}

export function StatusDistribution({ data }: StatusDistributionProps) {
  const total = data.reduce((s, d) => s + d.count, 0)

  return (
    <div style={{ padding: '20px 24px' }}>
      <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 16 }}>
        DISTRIBUIÇÃO DE STATUS
      </div>
      <div className="flex flex-col gap-3">
        {data.map((d) => {
          const color = STATUS_COLORS[d.status] ?? '#999999'
          const pct = total > 0 ? (d.count / total) * 100 : 0
          return (
            <div key={d.status}>
              <div className="flex items-center justify-between mb-1">
                <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#666666', letterSpacing: '0.08em' }}>
                  {(STATUS_LABELS[d.status] ?? d.status).toUpperCase()}
                </span>
                <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, fontWeight: 700, color }}>
                  {d.count}
                </span>
              </div>
              <div style={{ height: 4, backgroundColor: '#E8E8E8', position: 'relative' }}>
                <div style={{ position: 'absolute', inset: 0, width: `${pct}%`, backgroundColor: color }} />
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
