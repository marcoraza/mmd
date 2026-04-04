'use client'

import { STATUS_COLORS, STATUS_LABELS } from '@/lib/design-tokens'
import type { StatusSerial, StatusLote } from '@/lib/types'

interface StatusBadgeProps {
  status: StatusSerial | StatusLote | string
  className?: string
}

export function StatusBadge({ status, className = '' }: StatusBadgeProps) {
  const color = STATUS_COLORS[status] ?? '#999999'
  const label = STATUS_LABELS[status] ?? status

  return (
    <span
      className={`inline-flex items-center px-2 py-0.5 rounded-full border text-[9px] tracking-[0.1em] ${className}`}
      style={{
        color,
        borderColor: color,
        fontFamily: '"Space Mono", monospace',
        letterSpacing: '0.1em',
      }}
    >
      {label.toUpperCase()}
    </span>
  )
}
