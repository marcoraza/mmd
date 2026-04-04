'use client'

import { WEAR_COLORS } from '@/lib/design-tokens'

interface WearBarProps {
  desgaste: number
  className?: string
}

export function WearBar({ desgaste, className = '' }: WearBarProps) {
  const color = WEAR_COLORS[desgaste] ?? '#FFFFFF'

  return (
    <div className={`flex items-center gap-[2px] ${className}`}>
      {[1, 2, 3, 4, 5].map((i) => (
        <div
          key={i}
          style={{
            width: 14,
            height: 5,
            backgroundColor: i <= desgaste ? color : '#333333',
          }}
        />
      ))}
    </div>
  )
}
