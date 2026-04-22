import type { CatalogBannerStats } from '@/lib/data/items'

export type BannerFilter =
  | 'disponivel'
  | 'em_campo'
  | 'manutencao'
  | 'criticos'
  | 'a_repor'

type Cell = {
  label: string
  value: string
  color: string
  filter: BannerFilter | null
}

export function OperationalBanner({
  stats,
  active,
  onFilter,
}: {
  stats: CatalogBannerStats
  active: BannerFilter | null
  onFilter: (f: BannerFilter) => void
}) {
  const utilizacao = Math.round(stats.utilizacao_pct)
  const utilColor =
    utilizacao >= 70
      ? 'var(--accent-green)'
      : utilizacao >= 40
      ? 'var(--accent-cyan)'
      : 'var(--fg-1)'

  const cells: Cell[] = [
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
    {
      label: 'Críticos',
      value: stats.criticos.toString(),
      color: stats.criticos > 0 ? 'var(--accent-red)' : 'var(--fg-2)',
      filter: 'criticos',
    },
    {
      label: 'Utilização',
      value: `${utilizacao}%`,
      color: utilColor,
      filter: null,
    },
    {
      label: 'A repor',
      value: stats.a_repor.toString(),
      color: stats.a_repor > 0 ? 'var(--accent-amber)' : 'var(--fg-2)',
      filter: 'a_repor',
    },
  ]

  return (
    <div
      className="glass reveal reveal-1 catalog-banner"
      style={{
        marginTop: 16,
        borderRadius: 'var(--r-lg)',
        padding: 0,
        display: 'grid',
        gridTemplateColumns: 'repeat(6, minmax(0, 1fr))',
        overflow: 'hidden',
      }}
    >
      {cells.map((c, i) => {
        const isActive = c.filter !== null && active === c.filter
        const isClickable = c.filter !== null
        const commonStyle: React.CSSProperties = {
          padding: '20px 22px',
          borderLeft: i === 0 ? 'none' : '1px solid var(--glass-border-strong)',
          minWidth: 0,
          textAlign: 'left',
          background: isActive ? 'var(--glass-bg-strong)' : 'transparent',
          color: 'inherit',
          fontFamily: 'inherit',
          position: 'relative',
        }
        const content = (
          <>
            <div
              className="mono"
              style={{
                fontSize: 10,
                color: 'var(--fg-2)',
                letterSpacing: 0.1,
                textTransform: 'uppercase',
              }}
            >
              {c.label}
            </div>
            <div
              style={{
                fontSize: 26,
                fontWeight: 500,
                marginTop: 4,
                color: c.color,
                letterSpacing: -0.5,
              }}
            >
              {c.value}
            </div>
            {isActive && (
              <div
                style={{
                  position: 'absolute',
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 2,
                  background: c.color,
                }}
              />
            )}
          </>
        )
        if (isClickable) {
          return (
            <button
              key={c.label}
              type="button"
              className="catalog-banner__cell"
              onClick={() => onFilter(c.filter as BannerFilter)}
              aria-pressed={isActive}
              title={isActive ? `Limpar filtro: ${c.label}` : `Filtrar por ${c.label.toLowerCase()}`}
              style={{
                ...commonStyle,
                border: 'none',
                cursor: 'pointer',
                transition: 'background var(--motion-fast)',
              }}
            >
              {content}
            </button>
          )
        }
        return (
          <div key={c.label} className="catalog-banner__cell" style={commonStyle}>
            {content}
          </div>
        )
      })}
      <style>{`
        .catalog-banner__cell:hover:not([aria-pressed="true"]) {
          background: var(--glass-bg) !important;
        }
        @media (max-width: 1100px) {
          .catalog-banner { grid-template-columns: repeat(3, minmax(0, 1fr)) !important; }
          .catalog-banner__cell { border-left: none !important; }
          .catalog-banner .catalog-banner__cell:not(:nth-child(3n+1)) {
            border-left: 1px solid var(--glass-border-strong) !important;
          }
          .catalog-banner .catalog-banner__cell:nth-child(n+4) {
            border-top: 1px solid var(--glass-border-strong);
          }
        }
        @media (max-width: 700px) {
          .catalog-banner { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; }
          .catalog-banner__cell { border-left: none !important; }
          .catalog-banner .catalog-banner__cell:nth-child(even) {
            border-left: 1px solid var(--glass-border-strong) !important;
          }
          .catalog-banner .catalog-banner__cell:nth-child(n+3) {
            border-top: 1px solid var(--glass-border-strong);
          }
        }
      `}</style>
    </div>
  )
}
