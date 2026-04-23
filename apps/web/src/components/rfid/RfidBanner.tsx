'use client'

import type { RfidBannerStats } from '@/lib/data/rfid'

export type RfidBannerFilter = 'hoje' | '24h' | 'orfas' | null

type Cell = {
  label: string
  value: string
  color: string
  filter: RfidBannerFilter
  hint?: string
  clickable: boolean
}

export function RfidBanner({
  stats,
  active,
  onFilter,
}: {
  stats: RfidBannerStats
  active: RfidBannerFilter
  onFilter: (f: RfidBannerFilter) => void
}) {
  const cells: Cell[] = [
    {
      label: 'Scans hoje',
      value: stats.scans_hoje.toString(),
      color: 'var(--accent-cyan)',
      filter: 'hoje',
      clickable: true,
    },
    {
      label: 'Últimas 24h',
      value: stats.scans_24h.toString(),
      color: 'var(--fg-0)',
      filter: '24h',
      clickable: true,
    },
    {
      label: 'Tags órfãs (24h)',
      value: stats.nao_reconhecidos_24h.toString(),
      color: stats.nao_reconhecidos_24h > 0 ? 'var(--accent-red)' : 'var(--fg-2)',
      filter: 'orfas',
      clickable: true,
      hint: 'Tags lidas sem match no catálogo',
    },
    {
      label: 'Leitores ativos',
      value: stats.leitores_ativos.toString(),
      color: 'var(--accent-green)',
      filter: null,
      clickable: false,
    },
  ]

  return (
    <div
      style={{
        marginTop: 20,
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))',
        gap: 12,
      }}
    >
      {cells.map((c, i) => {
        const isActive = c.filter != null && active === c.filter
        return (
          <button
            key={i}
            type="button"
            onClick={() => c.filter != null && c.clickable && onFilter(c.filter)}
            disabled={!c.clickable}
            style={{
              textAlign: 'left',
              padding: '14px 16px',
              borderRadius: 'var(--r-md)',
              border: isActive
                ? `1px solid color-mix(in oklch, ${c.color} 50%, transparent)`
                : '1px solid var(--glass-border)',
              background: isActive
                ? `color-mix(in oklch, ${c.color} 12%, transparent)`
                : 'var(--glass-bg)',
              backdropFilter: 'blur(18px) saturate(160%)',
              WebkitBackdropFilter: 'blur(18px) saturate(160%)',
              cursor: c.clickable ? 'pointer' : 'default',
              color: 'inherit',
              fontFamily: 'inherit',
              transition: 'background var(--motion-fast), border-color var(--motion-fast)',
            }}
          >
            <div
              className="mono"
              style={{
                fontSize: 10,
                color: 'var(--fg-2)',
                letterSpacing: 0.12,
                textTransform: 'uppercase',
                marginBottom: 6,
              }}
            >
              {c.label}
            </div>
            <div
              className="mono"
              style={{
                fontSize: 26,
                color: c.color,
                fontWeight: 500,
                letterSpacing: -0.5,
              }}
            >
              {c.value}
            </div>
            {c.hint && (
              <div
                style={{
                  fontSize: 11,
                  color: 'var(--fg-3)',
                  marginTop: 4,
                  letterSpacing: 0.05,
                }}
              >
                {c.hint}
              </div>
            )}
          </button>
        )
      })}
    </div>
  )
}
