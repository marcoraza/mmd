'use client'

import { useState } from 'react'
import { Icons } from '@/components/mmd/Icons'
import { roundStars } from './helpers'

export function EditableStars({
  value,
  size = 12,
  pending = false,
  onChange,
}: {
  value: number
  size?: number
  pending?: boolean
  onChange: (next: number) => void
}) {
  const current = roundStars(value)
  const [hover, setHover] = useState<number | null>(null)
  const display = hover ?? current

  const color =
    display <= 2 ? 'var(--accent-red)' : display >= 4 ? 'var(--accent-green)' : 'var(--accent-amber)'

  return (
    <span
      role="radiogroup"
      aria-label={`Condição ${current} de 5, clique para editar`}
      onMouseLeave={() => setHover(null)}
      style={{
        display: 'inline-flex',
        gap: 1,
        color,
        lineHeight: 1,
        opacity: pending ? 0.5 : 1,
        transition: 'opacity var(--motion-fast)',
      }}
    >
      {Array.from({ length: 5 }).map((_, i) => {
        const starIndex = i + 1
        const filled = starIndex <= display
        return (
          <button
            key={i}
            type="button"
            role="radio"
            aria-checked={starIndex === current}
            disabled={pending}
            onClick={(e) => {
              e.stopPropagation()
              onChange(starIndex)
            }}
            onMouseEnter={() => setHover(starIndex)}
            onFocus={() => setHover(starIndex)}
            style={{
              width: size + 4,
              height: size + 4,
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: 0,
              background: 'transparent',
              border: 'none',
              color: 'inherit',
              cursor: pending ? 'wait' : 'pointer',
              borderRadius: 2,
            }}
            title={`Definir condição para ${starIndex}/5`}
          >
            <span style={{ width: size, height: size, display: 'inline-flex' }}>
              {filled ? Icons.star_filled : Icons.star}
            </span>
          </button>
        )
      })}
    </span>
  )
}
