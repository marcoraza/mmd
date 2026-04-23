'use client'

import { GlassCard } from '@/components/mmd/Primitives'
import { TimelineStream } from '@/components/item-detail/TimelineStream'
import type { MovimentacaoTimeline } from '@/lib/data/items'

// Plug direto no TimelineStream existente (item-detail). Mesmo shape.
export function MovimentacoesTab({ events }: { events: MovimentacaoTimeline[] }) {
  return (
    <GlassCard style={{ padding: 22 }}>
      {events.length === 0 ? (
        <div
          style={{
            padding: 32,
            textAlign: 'center',
            fontSize: 13,
            color: 'var(--fg-3)',
          }}
        >
          Nada aconteceu ainda. Depois do check-out você vê aqui cada serial que saiu.
        </div>
      ) : (
        <TimelineStream events={events} />
      )}
    </GlassCard>
  )
}
