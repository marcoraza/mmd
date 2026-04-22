import { Icons } from '@/components/mmd/Icons'
import { roundStars } from './helpers'

export function Stars({
  value,
  size = 12,
  color,
}: {
  value: number
  size?: number
  color?: string
}) {
  const n = roundStars(value)
  const c = color ?? (n <= 2 ? 'var(--accent-red)' : n >= 4 ? 'var(--accent-green)' : 'var(--accent-amber)')
  return (
    <span
      aria-label={`Condição ${n} de 5`}
      style={{ display: 'inline-flex', gap: 1, color: c, lineHeight: 1 }}
    >
      {Array.from({ length: 5 }).map((_, i) => (
        <span key={i} style={{ width: size, height: size, display: 'inline-flex' }}>
          {i < n ? Icons.star_filled : Icons.star}
        </span>
      ))}
    </span>
  )
}
