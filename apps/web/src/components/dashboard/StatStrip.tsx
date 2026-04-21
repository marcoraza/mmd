import type { DashboardStatEntry } from '@/lib/data/dashboard'

export function StatStrip({ entries }: { entries: DashboardStatEntry[] }) {
  return (
    <div
      className="glass reveal reveal-2 stat-strip"
      style={{
        marginTop: 40,
        borderRadius: 'var(--r-lg)',
        padding: 0,
        display: 'grid',
        gridTemplateColumns: `repeat(${entries.length}, minmax(0, 1fr))`,
        overflow: 'hidden',
      }}
    >
      {entries.map((s, i) => (
        <div
          key={s.label}
          className="stat-strip__cell"
          style={{
            padding: '22px 24px',
            borderLeft: i === 0 ? 'none' : '1px solid var(--glass-border-strong)',
            minWidth: 0,
          }}
        >
          <div
            className="mono"
            style={{
              fontSize: 10,
              color: 'var(--fg-2)',
              letterSpacing: 0.1,
              textTransform: 'uppercase',
            }}
          >
            {s.label}
          </div>
          <div
            style={{
              fontSize: 28,
              fontWeight: 500,
              marginTop: 4,
              color: s.color,
              letterSpacing: -0.5,
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            {s.value}
          </div>
        </div>
      ))}
      <style>{`
        @media (max-width: 900px) {
          .stat-strip { grid-template-columns: repeat(3, minmax(0, 1fr)) !important; }
          .stat-strip .stat-strip__cell:nth-child(4) { border-left: none !important; border-top: 1px solid var(--glass-border-strong); }
          .stat-strip .stat-strip__cell:nth-child(n+4) { border-top: 1px solid var(--glass-border-strong); }
        }
        @media (max-width: 600px) {
          .stat-strip { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; }
          .stat-strip .stat-strip__cell { border-left: none !important; }
          .stat-strip .stat-strip__cell:nth-child(even) { border-left: 1px solid var(--glass-border-strong) !important; }
          .stat-strip .stat-strip__cell:nth-child(n+3) { border-top: 1px solid var(--glass-border-strong); }
        }
      `}</style>
    </div>
  )
}
