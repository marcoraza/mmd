import { Ring } from '@/components/mmd/Primitives'

type Satellite = {
  value: string | number
  label: string
  color?: string
}

export function ReadinessCluster({
  value,
  size = 300,
  satellites = [],
}: {
  value: number
  size?: number
  satellites?: Satellite[]
}) {
  const innerSize = Math.round(size * 0.72)
  const outerStroke = 1
  const outerRadius = (size - outerStroke * 2) / 2 - 2

  return (
    <div
      style={{
        position: 'relative',
        width: size,
        height: size,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div
        aria-hidden
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: '50%',
          background:
            'radial-gradient(circle at center, var(--accent-cyan-soft) 0%, transparent 62%)',
          filter: 'blur(28px)',
          transform: 'scale(1.05)',
        }}
        className="pulse-soft"
      />

      <svg
        width={size}
        height={size}
        aria-hidden
        className="orbit-slow"
        style={{ position: 'absolute', inset: 0 }}
      >
        <defs>
          <linearGradient id="readiness-outer" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="var(--accent-cyan)" stopOpacity="1" />
            <stop offset="50%" stopColor="var(--accent-violet)" stopOpacity="0.85" />
            <stop offset="100%" stopColor="var(--accent-cyan)" stopOpacity="1" />
          </linearGradient>
        </defs>
        <circle
          cx={size / 2}
          cy={size / 2}
          r={outerRadius}
          fill="none"
          stroke="url(#readiness-outer)"
          strokeWidth={1.5}
          strokeDasharray="3 7"
          strokeLinecap="round"
        />
      </svg>

      <svg
        width={size}
        height={size}
        aria-hidden
        className="orbit-reverse"
        style={{ position: 'absolute', inset: 0 }}
      >
        <circle
          cx={size / 2}
          cy={size / 2}
          r={outerRadius - 14}
          fill="none"
          stroke="var(--accent-cyan)"
          strokeOpacity={0.35}
          strokeWidth={1}
          strokeDasharray="1 9"
        />
      </svg>

      <Ring
        value={value}
        size={innerSize}
        stroke={6}
        label="readiness"
        ariaLabel={`Readiness do evento: ${Math.round(value)} por cento`}
      />

      {satellites.map((s, i) => {
        const total = Math.max(satellites.length, 1)
        const angle = (i / total) * Math.PI * 2 - Math.PI / 2
        const radius = size / 2 + 18
        const x = size / 2 + Math.cos(angle) * radius
        const y = size / 2 + Math.sin(angle) * radius
        const color = s.color ?? 'var(--fg-2)'
        return (
          <div
            key={s.label}
            style={{
              position: 'absolute',
              left: x,
              top: y,
              transform: 'translate(-50%, -50%)',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 3,
              padding: '8px 12px',
              background: 'var(--glass-bg-strong)',
              border: '1px solid var(--glass-border-strong)',
              borderRadius: 'var(--r-sm)',
              backdropFilter: 'blur(20px) saturate(180%)',
              WebkitBackdropFilter: 'blur(20px) saturate(180%)',
              whiteSpace: 'nowrap',
              boxShadow:
                '0 6px 16px rgba(0, 0, 0, 0.12), 0 2px 4px rgba(0, 0, 0, 0.06)',
            }}
          >
            <div
              style={{
                fontSize: 15,
                fontWeight: 600,
                color,
                letterSpacing: -0.2,
                lineHeight: 1,
              }}
            >
              {s.value}
            </div>
            <div
              className="mono"
              style={{
                fontSize: 9,
                color: 'var(--fg-2)',
                letterSpacing: 0.1,
                textTransform: 'uppercase',
                lineHeight: 1,
              }}
            >
              {s.label}
            </div>
          </div>
        )
      })}
    </div>
  )
}
