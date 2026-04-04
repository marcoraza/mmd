import Link from 'next/link'
import { CategoryBadge } from '@/components/ui/CategoryBadge'
import { formatCurrencyFull } from '@/lib/design-tokens'
import type { Item } from '@/lib/types'

interface ItemCardProps {
  item: Item
}

export function ItemCard({ item }: ItemCardProps) {
  const disponiveis = item.serial_numbers?.filter((s) => s.status === 'DISPONIVEL').length ?? 0

  return (
    <Link
      href={`/items/${item.id}`}
      style={{
        display: 'block',
        padding: '16px',
        border: '1px solid #E8E8E8',
        backgroundColor: '#FFFFFF',
        textDecoration: 'none',
      }}
    >
      <div className="flex items-start justify-between mb-2">
        <span style={{ fontFamily: '"Space Grotesk", sans-serif', fontSize: 16, fontWeight: 500, color: '#1A1A1A' }}>
          {item.nome}
        </span>
        <CategoryBadge categoria={item.categoria} />
      </div>
      {item.marca && (
        <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 10, color: '#999999', letterSpacing: '0.08em', marginBottom: 8 }}>
          {item.marca}{item.modelo ? ` · ${item.modelo}` : ''}
        </div>
      )}
      <div className="flex items-center gap-4">
        <div>
          <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 14, fontWeight: 700, color: '#000000' }}>
            {item.quantidade_total}
          </span>
          <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', marginLeft: 4, letterSpacing: '0.08em' }}>
            TOTAL
          </span>
        </div>
        <div>
          <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 14, fontWeight: 700, color: '#4A9E5C' }}>
            {disponiveis}
          </span>
          <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', marginLeft: 4, letterSpacing: '0.08em' }}>
            DISP.
          </span>
        </div>
        {item.valor_mercado_unitario && (
          <div style={{ marginLeft: 'auto' }}>
            <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 12, color: '#666666' }}>
              {formatCurrencyFull(item.valor_mercado_unitario)}
            </span>
          </div>
        )}
      </div>
    </Link>
  )
}
