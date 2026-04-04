import Link from 'next/link'
import { CATEGORIA_LABELS, formatCurrencyFull } from '@/lib/design-tokens'
import type { ItemCritico } from '@/lib/types'

interface CriticalItemsProps {
  items: ItemCritico[]
}

const WEAR_COLOR: Record<number, string> = {
  1: '#D71921',
  2: '#D4A843',
}

export function CriticalItems({ items }: CriticalItemsProps) {
  if (items.length === 0) return null

  return (
    <div style={{ padding: '20px 24px' }}>
      <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 16 }}>
        ITENS CRÍTICOS — DESGASTE ≤ 2
      </div>
      <div className="flex flex-col">
        {items.slice(0, 8).map((item, i) => (
          <div
            key={item.codigo_interno}
            className="flex items-center gap-3 py-2"
            style={{ borderBottom: i < items.length - 1 ? '1px solid #E8E8E8' : undefined }}
          >
            <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#CCCCCC', width: 100 }}>
              {item.codigo_interno}
            </span>
            <span style={{ fontFamily: '"Space Grotesk", sans-serif', fontSize: 13, color: '#1A1A1A', flex: 1 }}>
              {item.nome}
            </span>
            <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.06em' }}>
              {(CATEGORIA_LABELS[item.categoria] ?? item.categoria).substring(0, 3).toUpperCase()}
            </span>
            <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 12, fontWeight: 700, color: WEAR_COLOR[item.desgaste] ?? '#666666' }}>
              {item.desgaste}/5
            </span>
            {item.valor_atual !== undefined && (
              <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#666666' }}>
                {formatCurrencyFull(item.valor_atual)}
              </span>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
