import Link from 'next/link'
import type { CatalogBannerStats } from '@/lib/data/items'
import { Stars } from './Stars'
import { roundStars } from './helpers'

export function OperationalBanner({ stats }: { stats: CatalogBannerStats }) {
  const cells = [
    { label: 'Disponível', value: stats.disponivel.toString(), color: 'var(--accent-green)' },
    { label: 'Em campo', value: stats.em_campo.toString(), color: 'var(--accent-cyan)' },
    { label: 'Manutenção', value: stats.manutencao.toString(), color: 'var(--accent-amber)' },
    {
      label: 'Críticos',
      value: stats.criticos.toString(),
      color: stats.criticos > 0 ? 'var(--accent-red)' : 'var(--fg-2)',
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
        gridTemplateColumns: 'repeat(5, minmax(0, 1fr)) auto',
        overflow: 'hidden',
      }}
    >
      {cells.map((c, i) => (
        <div
          key={c.label}
          className="catalog-banner__cell"
          style={{
            padding: '20px 22px',
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
        </div>
      ))}
      <div
        className="catalog-banner__cell"
        style={{
          padding: '20px 22px',
          borderLeft: '1px solid var(--glass-border-strong)',
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
          Condição média
        </div>
        <div style={{ marginTop: 6, display: 'flex', alignItems: 'center', gap: 8 }}>
          <Stars value={stats.condicao_media} size={14} />
          <span className="mono" style={{ fontSize: 12, color: 'var(--fg-2)' }}>
            {roundStars(stats.condicao_media)}/5
          </span>
        </div>
      </div>
      <Link
        href="/patrimonio"
        className="catalog-banner__link"
        style={{
          padding: '20px 22px',
          borderLeft: '1px solid var(--glass-border-strong)',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          gap: 4,
          color: 'var(--fg-1)',
          textDecoration: 'none',
          whiteSpace: 'nowrap',
          minWidth: 140,
          transition: 'background var(--motion-fast), color var(--motion-fast)',
        }}
      >
        <span
          className="mono"
          style={{
            fontSize: 10,
            color: 'var(--fg-2)',
            letterSpacing: 0.1,
            textTransform: 'uppercase',
          }}
        >
          Financeiro
        </span>
        <span style={{ fontSize: 14, fontWeight: 500, letterSpacing: -0.2 }}>
          Ver patrimônio →
        </span>
      </Link>
      <style>{`
        .catalog-banner__link:hover { background: var(--glass-bg-strong); color: var(--accent-cyan); }
        @media (max-width: 1100px) {
          .catalog-banner { grid-template-columns: repeat(3, minmax(0, 1fr)) !important; }
          .catalog-banner__cell, .catalog-banner__link {
            border-left: none !important;
          }
          .catalog-banner .catalog-banner__cell:not(:nth-child(3n+1)),
          .catalog-banner__link:not(:nth-child(3n+1)) {
            border-left: 1px solid var(--glass-border-strong) !important;
          }
          .catalog-banner .catalog-banner__cell:nth-child(n+4),
          .catalog-banner__link:nth-child(n+4) {
            border-top: 1px solid var(--glass-border-strong);
          }
        }
        @media (max-width: 700px) {
          .catalog-banner { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; }
          .catalog-banner__cell, .catalog-banner__link {
            border-left: none !important;
          }
          .catalog-banner .catalog-banner__cell:nth-child(even),
          .catalog-banner__link:nth-child(even) {
            border-left: 1px solid var(--glass-border-strong) !important;
          }
          .catalog-banner .catalog-banner__cell:nth-child(n+3),
          .catalog-banner__link:nth-child(n+3) {
            border-top: 1px solid var(--glass-border-strong);
          }
        }
      `}</style>
    </div>
  )
}
