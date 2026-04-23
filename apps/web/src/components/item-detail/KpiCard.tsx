import { GlassCard } from '@/components/mmd/Primitives'
import type { ReactNode } from 'react'

type Props = {
  label: string
  value: ReactNode
  hint?: ReactNode
  accent?: string
  trend?: 'up' | 'down' | 'flat' | null
}

export function KpiCard({ label, value, hint, accent, trend }: Props) {
  const accentColor = accent ?? 'var(--accent-cyan)'
  return (
    <GlassCard style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 6 }}>
      <div
        className="mono"
        style={{
          fontSize: 10,
          color: accentColor,
          letterSpacing: 0.12,
          textTransform: 'uppercase',
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontSize: 22,
          fontWeight: 500,
          color: 'var(--fg-0)',
          fontFamily: 'var(--font-mono-raw)',
          letterSpacing: -0.3,
          lineHeight: 1.1,
        }}
      >
        {value}
      </div>
      {hint && (
        <div
          style={{
            fontSize: 11,
            color: trend === 'down' ? 'var(--accent-red)' : trend === 'up' ? 'var(--accent-green)' : 'var(--fg-3)',
            fontFamily: trend ? 'var(--font-mono-raw)' : 'inherit',
          }}
        >
          {trend === 'down' && '↓ '}
          {trend === 'up' && '↑ '}
          {hint}
        </div>
      )}
    </GlassCard>
  )
}
