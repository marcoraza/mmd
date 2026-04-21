import { Icons } from '@/components/mmd/Icons'
import type { DashboardHeroEvent } from '@/lib/data/dashboard'
import { ReadinessCluster } from './ReadinessCluster'

export function CinematicHero({ event }: { event: DashboardHeroEvent | null }) {
  if (!event) {
    return (
      <section
        className="reveal reveal-0"
        style={{
          marginTop: 36,
          padding: '48px 32px',
          border: '1px dashed var(--glass-border-strong)',
          borderRadius: 'var(--r-lg)',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 12,
          color: 'var(--fg-2)',
        }}
      >
        <div
          style={{
            width: 56,
            height: 56,
            borderRadius: 'var(--r-md)',
            background: 'var(--glass-bg)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'var(--fg-2)',
          }}
        >
          {Icons.calendar}
        </div>
        <div style={{ fontSize: 18, fontWeight: 500, color: 'var(--fg-0)' }}>
          Nenhum evento programado
        </div>
        <div style={{ fontSize: 13, color: 'var(--fg-2)' }}>
          Crie um novo projeto para começar a montar o packing list.
        </div>
      </section>
    )
  }

  return (
    <section
      style={{
        marginTop: 36,
        display: 'flex',
        alignItems: 'center',
        gap: 48,
        flexWrap: 'wrap',
      }}
    >
      <div className="reveal reveal-0" style={{ flex: '1 1 560px', minWidth: 280 }}>
        <div
          className="mono"
          style={{
            fontSize: 11,
            color: 'var(--fg-2)',
            letterSpacing: 0.12,
            textTransform: 'uppercase',
            marginBottom: 16,
          }}
        >
          Próximo evento
        </div>
        <h1
          style={{
            fontSize: 'clamp(40px, 6vw, 56px)',
            fontWeight: 500,
            letterSpacing: -1.5,
            lineHeight: 1.05,
            color: 'var(--fg-0)',
            margin: 0,
          }}
        >
          {event.title_line1}
          <br />
          <span
            style={{
              fontFamily: 'var(--font-serif), Georgia, serif',
              fontStyle: 'italic',
              fontWeight: 400,
              color: 'var(--fg-0)',
              letterSpacing: -1,
              fontSize: '1.15em',
            }}
          >
            {event.title_line2}
          </span>
        </h1>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 24,
            marginTop: 20,
            color: 'var(--fg-1)',
            fontSize: 14,
            flexWrap: 'wrap',
          }}
        >
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
            {Icons.calendar} {event.date}
          </span>
          <span>{event.venue}</span>
        </div>
      </div>

      <div className="reveal reveal-1" style={{ flexShrink: 0 }}>
        <ReadinessCluster value={event.readiness} size={320} satellites={event.satellites} />
      </div>
    </section>
  )
}
