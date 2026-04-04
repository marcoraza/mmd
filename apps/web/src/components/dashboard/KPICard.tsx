import { CircularGauge } from '@/components/ui/CircularGauge'

interface KPICardProps {
  label: string
  value: string
  delta?: string
  deltaColor?: string
  gauge?: { value: number; label?: string; color?: string }
  segmented?: { filled: number; total: number; suffix?: string }
  borderRight?: boolean
}

export function KPICard({ label, value, delta, deltaColor, gauge, segmented, borderRight }: KPICardProps) {
  return (
    <div
      className="px-6 py-5 flex items-start justify-between"
      style={{ borderRight: borderRight ? '1px solid #E8E8E8' : undefined }}
    >
      <div>
        <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 8 }}>
          {label.toUpperCase()}
        </div>
        <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 32, fontWeight: 700, color: '#000000', lineHeight: 1 }}>
          {value}
        </div>
        {delta && (
          <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 10, color: deltaColor ?? '#4A9E5C', marginTop: 6, letterSpacing: '0.06em' }}>
            {delta}
          </div>
        )}
      </div>
      {gauge && (
        <CircularGauge
          value={gauge.value}
          label={gauge.label}
          color={gauge.color ?? '#D4A843'}
          size={72}
        />
      )}
      {segmented && (
        <div className="flex flex-col items-end gap-1 mt-1">
          <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 13, color: '#999999' }}>
            /{segmented.total}{segmented.suffix ?? ''}
          </span>
          <SegmentedFill filled={segmented.filled} total={segmented.total} />
        </div>
      )}
    </div>
  )
}

function SegmentedFill({ filled, total }: { filled: number; total: number }) {
  const pct = total > 0 ? filled / total : 0
  return (
    <div className="flex items-center gap-[1px]" style={{ width: 80 }}>
      <div style={{ height: 5, width: `${pct * 100}%`, backgroundColor: '#000000', minWidth: pct > 0 ? 2 : 0 }} />
      <div style={{ height: 5, flex: 1, backgroundColor: '#E8E8E8' }} />
    </div>
  )
}
