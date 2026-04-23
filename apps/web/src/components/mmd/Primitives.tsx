import type { CSSProperties, ReactNode } from 'react'

type CommonStyle = { style?: CSSProperties; className?: string }

// ─── Caustic ────────────────────────────────────────────
export function Caustic({ orb3 = false, style }: { orb3?: boolean; style?: CSSProperties }) {
  return (
    <div className="caustic-bg" style={style} aria-hidden="true">
      {orb3 && <div className="orb3" />}
    </div>
  )
}

// ─── Glass Card ─────────────────────────────────────────
export function GlassCard({
  children,
  strong = false,
  style,
  className = '',
  onClick,
}: CommonStyle & { children: ReactNode; strong?: boolean; onClick?: () => void }) {
  const cls = `glass${strong ? ' glass-strong' : ''} ${className}`.trim()
  return (
    <div className={cls} style={style} onClick={onClick}>
      {children}
    </div>
  )
}

// ─── Glass Pill ─────────────────────────────────────────
export function GlassPill({ children, style }: { children: ReactNode; style?: CSSProperties }) {
  return (
    <div
      className="glass"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 8,
        padding: '8px 14px',
        borderRadius: 999,
        fontSize: 13,
        ...style,
      }}
    >
      {children}
    </div>
  )
}

// ─── Status Dot ─────────────────────────────────────────
export function StatusDot({
  color = 'var(--accent-green)',
  glow = true,
  size = 8,
}: {
  color?: string
  glow?: boolean
  size?: number
}) {
  return (
    <span
      aria-hidden="true"
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: color,
        boxShadow: glow ? `0 0 ${size}px ${color}, 0 0 ${size * 2}px ${color}` : 'none',
        display: 'inline-block',
        flexShrink: 0,
      }}
    />
  )
}

// ─── Ring ───────────────────────────────────────────────
type RingState = 'missing' | 'partial' | 'ready'

export function Ring({
  value = 87,
  size = 180,
  stroke = 10,
  label,
  subLabel,
  state,
  ariaLabel,
  decorative = false,
}: {
  value?: number
  size?: number
  stroke?: number
  label?: string
  subLabel?: string
  state?: RingState
  ariaLabel?: string
  decorative?: boolean
}) {
  const r = (size - stroke) / 2
  const c = 2 * Math.PI * r
  const offset = c * (1 - Math.max(0, Math.min(100, value)) / 100)
  const id = `ring-grad-${size}-${value}`

  const gradients: Record<RingState, [string, string, string]> = {
    ready: ['oklch(0.82 0.17 150)', 'oklch(0.78 0.14 180)', 'oklch(0.75 0.14 210)'],
    partial: ['oklch(0.80 0.17 60)', 'oklch(0.77 0.16 95)', 'oklch(0.75 0.14 130)'],
    missing: ['oklch(0.70 0.18 25)', 'oklch(0.72 0.17 5)', 'oklch(0.72 0.15 340)'],
  }
  const defaultStops: [string, string, string] = [
    'oklch(0.80 0.16 210)',
    'oklch(0.75 0.17 250)',
    'oklch(0.72 0.18 295)',
  ]
  const stops = state ? gradients[state] : defaultStops

  const roleProps = decorative
    ? { 'aria-hidden': true as const }
    : {
        role: 'progressbar' as const,
        'aria-valuenow': Math.round(value),
        'aria-valuemin': 0,
        'aria-valuemax': 100,
        'aria-label': ariaLabel ?? label ?? 'Progresso',
      }

  return (
    <div
      style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}
      {...roleProps}
    >
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }} aria-hidden="true">
        <defs>
          <linearGradient id={id} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor={stops[0]} />
            <stop offset="50%" stopColor={stops[1]} />
            <stop offset="100%" stopColor={stops[2]} />
          </linearGradient>
        </defs>
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke="var(--glass-border-strong)"
          strokeWidth={stroke}
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={`url(#${id})`}
          strokeWidth={stroke}
          strokeDasharray={c}
          strokeDashoffset={offset}
          strokeLinecap="round"
        />
      </svg>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <div
          style={{
            fontSize: size * 0.28,
            fontWeight: 600,
            fontFamily: 'var(--font-sans-raw)',
            letterSpacing: -0.03 * size,
            color: 'var(--fg-0)',
            lineHeight: 1,
          }}
        >
          {Math.round(value)}
          <span style={{ fontSize: size * 0.14, opacity: 0.6, fontWeight: 400 }}>%</span>
        </div>
        {label && (
          <div
            className="mono"
            style={{
              fontSize: 10,
              color: 'var(--fg-2)',
              letterSpacing: 0.08,
              textTransform: 'uppercase',
              marginTop: 6,
            }}
          >
            {label}
          </div>
        )}
        {subLabel && (
          <div style={{ fontSize: 11, color: 'var(--fg-3)', marginTop: 2 }}>{subLabel}</div>
        )}
      </div>
    </div>
  )
}

// ─── Icon Box ───────────────────────────────────────────
export function IconBox({
  glyph,
  size = 44,
  tint = 'var(--accent-cyan-soft)',
  color = 'var(--accent-cyan)',
}: {
  glyph: ReactNode
  size?: number
  tint?: string
  color?: string
}) {
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.28,
        background: tint,
        border: '1px solid var(--glass-border)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color,
        flexShrink: 0,
      }}
    >
      {glyph}
    </div>
  )
}

// ─── Sparkline ──────────────────────────────────────────
export function Sparkline({
  data,
  width = 120,
  height = 32,
  color = 'var(--accent-cyan)',
}: {
  data: number[]
  width?: number
  height?: number
  color?: string
}) {
  if (data.length < 2) return null
  const max = Math.max(...data)
  const min = Math.min(...data)
  const range = max - min || 1
  const pts = data
    .map((v, i) => {
      const x = (i / (data.length - 1)) * width
      const y = height - ((v - min) / range) * (height - 4) - 2
      return `${x},${y}`
    })
    .join(' ')
  return (
    <svg width={width} height={height} aria-hidden="true">
      <polyline
        fill="none"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        points={pts}
      />
    </svg>
  )
}

// ─── Placeholder Image ──────────────────────────────────
export function PlaceholderImg({
  label,
  width = '100%',
  height = 120,
  style,
}: {
  label: string
  width?: number | string
  height?: number | string
  style?: CSSProperties
}) {
  return (
    <div
      style={{
        width,
        height,
        background:
          'repeating-linear-gradient(45deg, rgba(255,255,255,0.04), rgba(255,255,255,0.04) 8px, rgba(255,255,255,0.08) 8px, rgba(255,255,255,0.08) 16px)',
        border: '1px dashed var(--glass-border-strong)',
        borderRadius: 12,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: 'var(--font-mono-raw)',
        fontSize: 10,
        color: 'var(--fg-3)',
        letterSpacing: 0.08,
        textTransform: 'uppercase',
        ...style,
      }}
    >
      {label}
    </div>
  )
}

// ─── Buttons ────────────────────────────────────────────
type BtnProps = {
  children: ReactNode
  small?: boolean
  onClick?: () => void
  type?: 'button' | 'submit' | 'reset'
  disabled?: boolean
  style?: CSSProperties
}

export function PrimaryBtn({ children, small = false, onClick, type = 'button', disabled = false, style }: BtnProps) {
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      style={{
        border: 'none',
        padding: small ? '7px 14px' : '10px 18px',
        borderRadius: small ? 8 : 10,
        fontFamily: 'var(--font-sans-raw)',
        fontWeight: 500,
        fontSize: small ? 12 : 13,
        color: '#fff',
        cursor: disabled ? 'not-allowed' : 'pointer',
        background: 'linear-gradient(180deg, oklch(0.78 0.14 210), oklch(0.68 0.15 220))',
        boxShadow: '0 4px 12px oklch(0.70 0.14 220 / 0.35), inset 0 1px 0 rgba(255,255,255,0.25)',
        transition: 'transform var(--motion-fast), box-shadow var(--motion-fast)',
        opacity: disabled ? 0.5 : 1,
        ...style,
      }}
    >
      {children}
    </button>
  )
}

export function GhostBtn({ children, small = false, onClick, type = 'button', disabled = false, style }: BtnProps) {
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className="glass"
      style={{
        padding: small ? '7px 14px' : '10px 18px',
        borderRadius: small ? 8 : 10,
        fontFamily: 'var(--font-sans-raw)',
        fontWeight: 500,
        fontSize: small ? 12 : 13,
        color: 'var(--fg-0)',
        cursor: disabled ? 'not-allowed' : 'pointer',
        background: 'var(--glass-bg)',
        transition: 'background var(--motion-fast)',
        opacity: disabled ? 0.5 : 1,
        ...style,
      }}
    >
      {children}
    </button>
  )
}

// ─── Badge (status chip) ───────────────────────────────
export function Badge({
  children,
  color = 'var(--accent-cyan)',
  tone = 'soft',
}: {
  children: ReactNode
  color?: string
  tone?: 'soft' | 'solid'
}) {
  const bg =
    tone === 'solid'
      ? color
      : `color-mix(in oklch, ${color} 22%, transparent)`
  const border =
    tone === 'solid'
      ? 'transparent'
      : `color-mix(in oklch, ${color} 40%, transparent)`
  const text = tone === 'solid' ? '#0b0b0b' : color
  return (
    <span
      className="mono"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: '3px 9px',
        borderRadius: 999,
        fontSize: 10,
        letterSpacing: 0.12,
        textTransform: 'uppercase',
        background: bg,
        color: text,
        border: `1px solid ${border}`,
        whiteSpace: 'nowrap',
      }}
    >
      {children}
    </span>
  )
}
