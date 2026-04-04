'use client'

import { CATEGORIA_LABELS } from '@/lib/design-tokens'
import type { Categoria } from '@/lib/types'

interface CategoryBadgeProps {
  categoria: Categoria | string
  className?: string
}

export function CategoryBadge({ categoria, className = '' }: CategoryBadgeProps) {
  const label = CATEGORIA_LABELS[categoria] ?? categoria

  return (
    <span
      className={`inline-flex items-center px-2 py-0.5 rounded-full border border-[#CCCCCC] text-[#666666] text-[9px] ${className}`}
      style={{
        fontFamily: '"Space Mono", monospace',
        letterSpacing: '0.1em',
      }}
    >
      {label.toUpperCase()}
    </span>
  )
}
