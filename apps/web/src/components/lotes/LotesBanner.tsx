'use client'

import type { LotesBannerStats } from '@/lib/data/lotes'

export type LotesBannerFilter = 'disponivel' | 'em_campo' | 'manutencao'

type Cell = {
  label: string
  value: string
  color: string
  filter: LotesBannerFilter | null
  hint?: string
}

export function LotesBanner({
  stats,
  active,
  onFilter,
}: {
  stats: LotesBannerStats
  active: LotesBannerFilter | null
  onFilter: (f: LotesBannerFilter) => void
}) {
  const cells: Cell[] = [
    {
      label: 'Total de lotes',
      value: stats.total.toString(),
      color: 'var(--fg-0)',
      filter: null,
      hint: `${stats.unidades_totais} unidades agrupadas`,
    },
    {
      label: 'Disponível',
      value: stats.disponivel.toString(),
      color: 'var(--accent-green)',
      filter: 'disponivel',
    },
    {
      label: 'Em campo',
      value: stats.em_campo.toString(),
      color: 'var(--accent-cyan)',
      filter: 'em_campo',
    },
    {
      label: 'Manutenção',
      value: stats.manutencao.toString(),
      color: 'var(--accent-amber)',
      filter: 'manutencao',
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
        const isActive = c.filter !== null && active === c.filter
        const clickable = c.filter !== null
        return (
          <button
            key={i}
            type="button"
            onClick={() => c.filter && onFilter(c.filter)}
            disabled={!clickable}
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
              cursor: clickable ? 'pointer' : 'default',
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
