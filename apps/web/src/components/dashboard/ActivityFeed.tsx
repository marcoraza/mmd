import { STATUS_COLORS } from '@/lib/design-tokens'

export interface ActivityItem {
  id: string
  text: string
  timestamp: string
  color?: string
}

interface ActivityFeedProps {
  items: ActivityItem[]
}

export function ActivityFeed({ items }: ActivityFeedProps) {
  return (
    <div style={{ padding: '20px 24px', borderRight: '1px solid #E8E8E8' }}>
      <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 16 }}>
        ATIVIDADE RECENTE
      </div>
      <div className="flex flex-col gap-3">
        {items.length === 0 && (
          <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#CCCCCC' }}>
            Nenhuma atividade registrada.
          </span>
        )}
        {items.map((item) => (
          <div key={item.id} className="flex items-start gap-3">
            <div
              style={{
                width: 5, height: 5,
                borderRadius: '50%',
                backgroundColor: item.color ?? STATUS_COLORS.DISPONIVEL,
                marginTop: 5,
                flexShrink: 0,
              }}
            />
            <div>
              <p style={{ fontFamily: '"Space Grotesk", sans-serif', fontSize: 13, color: '#1A1A1A', margin: 0 }}>
                {item.text}
              </p>
              <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.06em' }}>
                {item.timestamp}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
