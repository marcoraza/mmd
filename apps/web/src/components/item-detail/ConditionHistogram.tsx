import type { SerialRow } from '@/lib/data/items'

const BUCKET_LABEL: Record<number, string> = {
  1: 'Crítico',
  2: 'Desgastado',
  3: 'Regular',
  4: 'Bom',
  5: 'Excelente',
}

const BUCKET_COLOR: Record<number, string> = {
  1: 'var(--accent-red)',
  2: 'var(--accent-red)',
  3: 'var(--accent-amber)',
  4: 'var(--accent-green)',
  5: 'var(--accent-green)',
}

export function ConditionHistogram({ serials }: { serials: SerialRow[] }) {
  const buckets: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
  for (const s of serials) {
    const b = Math.max(1, Math.min(5, Math.round(s.desgaste)))
    buckets[b] = (buckets[b] ?? 0) + 1
  }
  const max = Math.max(1, ...Object.values(buckets))

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {[5, 4, 3, 2, 1].map((b) => {
        const count = buckets[b]
        const pct = (count / max) * 100
        return (
          <div key={b} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div
              style={{
                width: 70,
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                flexShrink: 0,
              }}
            >
              <span
                className="mono"
                style={{ fontSize: 10, color: BUCKET_COLOR[b], fontWeight: 500 }}
              >
                {b}/5
              </span>
              <span style={{ fontSize: 11, color: 'var(--fg-3)' }}>
                {BUCKET_LABEL[b]}
              </span>
            </div>
            <div
              style={{
                flex: 1,
                height: 10,
                borderRadius: 5,
                background: 'var(--glass-border)',
                overflow: 'hidden',
                position: 'relative',
              }}
            >
              <div
                style={{
                  width: `${pct}%`,
                  height: '100%',
                  background: BUCKET_COLOR[b],
                  opacity: count > 0 ? 1 : 0.15,
                  transition: 'width var(--motion-slow)',
                }}
              />
            </div>
            <span
              className="mono"
              style={{
                fontSize: 11,
                color: count > 0 ? 'var(--fg-0)' : 'var(--fg-3)',
                width: 28,
                textAlign: 'right',
                flexShrink: 0,
              }}
            >
              {count}
            </span>
          </div>
        )
      })}
    </div>
  )
}
