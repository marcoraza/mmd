'use client'

interface CircularGaugeProps {
  value: number
  max?: number
  label?: string
  color?: string
  size?: number
  strokeWidth?: number
  className?: string
}

export function CircularGauge({
  value,
  max = 100,
  label,
  color = '#D4A843',
  size = 72,
  strokeWidth = 4,
  className = '',
}: CircularGaugeProps) {
  const radius = (size - strokeWidth * 2) / 2
  const circumference = 2 * Math.PI * radius
  const pct = Math.min(Math.max(value / max, 0), 1)
  const dashOffset = circumference * (1 - pct)
  const cx = size / 2
  const cy = size / 2

  return (
    <div className={`relative inline-flex items-center justify-center ${className}`} style={{ width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle
          cx={cx}
          cy={cy}
          r={radius}
          fill="none"
          stroke="#333333"
          strokeWidth={strokeWidth}
        />
        <circle
          cx={cx}
          cy={cy}
          r={radius}
          fill="none"
          stroke={color}
          strokeWidth={strokeWidth}
          strokeDasharray={circumference}
          strokeDashoffset={dashOffset}
          strokeLinecap="butt"
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span
          style={{
            fontFamily: '"Space Mono", monospace',
            fontSize: 13,
            fontWeight: 700,
            color,
            lineHeight: 1,
          }}
        >
          {Math.round(value)}%
        </span>
        {label && (
          <span
            style={{
              fontFamily: '"Space Mono", monospace',
              fontSize: 7,
              color: '#666666',
              letterSpacing: '0.08em',
              marginTop: 2,
            }}
          >
            {label.toUpperCase()}
          </span>
        )}
      </div>
    </div>
  )
}
