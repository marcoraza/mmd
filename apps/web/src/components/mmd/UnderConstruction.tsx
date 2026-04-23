import type { ReactNode } from 'react'
import { GlassCard } from './Primitives'

type Phase = 'stub' | 'em-desenvolvimento' | 'planejado'

export function UnderConstruction({
  phase = 'stub',
  planned,
  children,
}: {
  phase?: Phase
  planned: ReactNode
  children?: ReactNode
}) {
  const label =
    phase === 'stub'
      ? 'Em construção'
      : phase === 'em-desenvolvimento'
        ? 'Em desenvolvimento'
        : 'Planejado'

  return (
    <GlassCard
      style={{
        marginTop: 24,
        padding: '28px 32px',
        display: 'flex',
        flexDirection: 'column',
        gap: 20,
        maxWidth: 720,
      }}
    >
      <div
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 10,
          alignSelf: 'flex-start',
          padding: '6px 12px',
          borderRadius: 999,
          fontSize: 12,
          fontFamily: 'var(--font-mono-raw)',
          letterSpacing: 0.5,
          textTransform: 'uppercase',
          color: 'var(--accent-amber)',
          background: 'oklch(0.75 0.15 75 / 0.12)',
          border: '1px solid oklch(0.75 0.15 75 / 0.25)',
        }}
      >
        <span
          aria-hidden
          style={{
            width: 6,
            height: 6,
            borderRadius: '50%',
            background: 'var(--accent-amber)',
            boxShadow: '0 0 8px var(--accent-amber)',
          }}
        />
        {label}
      </div>

      <div>
        <div
          style={{
            fontSize: 13,
            color: 'var(--fg-2)',
            marginBottom: 10,
            fontWeight: 500,
          }}
        >
          O que vai entrar aqui
        </div>
        <div style={{ fontSize: 15, color: 'var(--fg-1)', lineHeight: 1.6 }}>
          {planned}
        </div>
      </div>

      {children && (
        <div
          style={{
            borderTop: '1px solid var(--glass-border)',
            paddingTop: 16,
            fontSize: 13,
            color: 'var(--fg-2)',
            lineHeight: 1.6,
          }}
        >
          {children}
        </div>
      )}
    </GlassCard>
  )
}
