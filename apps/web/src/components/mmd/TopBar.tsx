import type { ReactNode } from 'react'
import { Icons } from './Icons'
import { GlassPill } from './Primitives'

export function TopBar({
  kicker,
  title,
  actions,
  notifications = 0,
}: {
  kicker?: ReactNode
  title: ReactNode
  actions?: ReactNode
  notifications?: number
}) {
  return (
    <header
      className="reveal reveal-0"
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 16,
        height: 48,
        position: 'relative',
        zIndex: 1,
      }}
    >
      <div>
        {kicker && (
          <div
            className="mono"
            style={{
              fontSize: 10,
              color: 'var(--fg-3)',
              letterSpacing: 0.12,
              textTransform: 'uppercase',
            }}
          >
            {kicker}
          </div>
        )}
        <div
          style={{
            fontSize: 20,
            fontWeight: 500,
            letterSpacing: -0.3,
            color: 'var(--fg-0)',
            marginTop: 2,
          }}
        >
          {title}
        </div>
      </div>

      <div style={{ flex: 1 }} />

      {actions}

      <label
        className="glass topbar-search"
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          padding: '0 14px',
          height: 36,
          borderRadius: 999,
          color: 'var(--fg-2)',
          fontSize: 13,
          minWidth: 260,
          cursor: 'text',
        }}
      >
        <span aria-hidden>{Icons.search}</span>
        <input
          type="search"
          placeholder="Buscar item, serial, tag…"
          aria-label="Buscar no inventário"
          style={{
            flex: 1,
            border: 'none',
            outline: 'none',
            background: 'transparent',
            color: 'var(--fg-0)',
            fontSize: 13,
            fontFamily: 'var(--font-sans-raw)',
            minWidth: 0,
          }}
        />
        <kbd
          className="mono"
          style={{
            fontSize: 10,
            opacity: 0.6,
            padding: '2px 6px',
            border: '1px solid var(--glass-border)',
            borderRadius: 4,
          }}
        >
          ⌘K
        </kbd>
      </label>

      <GlassPill>
        <span style={{ color: 'var(--fg-1)' }}>{Icons.bell}</span>
        <span className="mono" style={{ fontSize: 11, color: 'var(--accent-cyan)' }}>
          {notifications}
        </span>
      </GlassPill>
      <style>{`
        .topbar-search:focus-within {
          outline: 2px solid var(--accent-cyan);
          outline-offset: 2px;
        }
      `}</style>
    </header>
  )
}
