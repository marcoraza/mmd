'use client'

import Link from 'next/link'
import { ArrowUpDown } from 'lucide-react'
import { CategoryBadge } from '@/components/ui/CategoryBadge'
import { formatCurrencyFull } from '@/lib/design-tokens'
import type { Item } from '@/lib/types'

interface ItemTableProps {
  items: Item[]
  sortBy?: string
  sortDir?: 'asc' | 'desc'
  onSort?: (col: string) => void
}

const columns = [
  { key: 'nome', label: 'Nome' },
  { key: 'categoria', label: 'Categoria' },
  { key: 'marca', label: 'Marca' },
  { key: 'quantidade_total', label: 'Total', align: 'right' as const },
  { key: 'disponiveis', label: 'Disponíveis', align: 'right' as const },
  { key: 'valor_mercado_unitario', label: 'Valor Unit.', align: 'right' as const },
]

export function ItemTable({ items, sortBy, sortDir, onSort }: ItemTableProps) {
  return (
    <div style={{ overflowX: 'auto' }}>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead>
          <tr style={{ borderBottom: '1px solid #CCCCCC' }}>
            {columns.map((col) => (
              <th
                key={col.key}
                style={{
                  fontFamily: '"Space Mono", monospace',
                  fontSize: 9,
                  color: '#999999',
                  letterSpacing: '0.12em',
                  padding: '0 16px 10px',
                  textAlign: col.align ?? 'left',
                  whiteSpace: 'nowrap',
                  cursor: onSort ? 'pointer' : 'default',
                  userSelect: 'none',
                }}
                onClick={() => onSort?.(col.key)}
              >
                <span className="inline-flex items-center gap-1">
                  {col.label.toUpperCase()}
                  {onSort && sortBy === col.key && (
                    <ArrowUpDown size={9} color={sortDir === 'asc' ? '#000000' : '#999999'} />
                  )}
                </span>
              </th>
            ))}
            <th style={{ width: 40 }} />
          </tr>
        </thead>
        <tbody>
          {items.map((item) => {
            const disponiveis = item.serial_numbers?.filter((s) => s.status === 'DISPONIVEL').length ?? '—'
            return (
              <tr
                key={item.id}
                style={{ borderBottom: '1px solid #E8E8E8', cursor: 'pointer' }}
              >
                <td style={{ padding: '12px 16px' }}>
                  <Link
                    href={`/items/${item.id}`}
                    style={{
                      fontFamily: '"Space Grotesk", sans-serif',
                      fontSize: 14,
                      color: '#1A1A1A',
                      textDecoration: 'none',
                    }}
                  >
                    {item.nome}
                  </Link>
                </td>
                <td style={{ padding: '12px 16px' }}>
                  <CategoryBadge categoria={item.categoria} />
                  {item.subcategoria && (
                    <div style={{ fontFamily: '"Space Grotesk", sans-serif', fontSize: 11, color: '#999999', marginTop: 2 }}>
                      {item.subcategoria}
                    </div>
                  )}
                </td>
                <td style={{ padding: '12px 16px', fontFamily: '"Space Mono", monospace', fontSize: 12, color: '#666666' }}>
                  {item.marca ?? '—'}
                </td>
                <td style={{ padding: '12px 16px', fontFamily: '"Space Mono", monospace', fontSize: 13, color: '#000000', textAlign: 'right', fontWeight: 700 }}>
                  {item.quantidade_total}
                </td>
                <td style={{ padding: '12px 16px', fontFamily: '"Space Mono", monospace', fontSize: 13, textAlign: 'right', color: '#4A9E5C', fontWeight: 700 }}>
                  {disponiveis}
                </td>
                <td style={{ padding: '12px 16px', fontFamily: '"Space Mono", monospace', fontSize: 12, textAlign: 'right', color: '#666666' }}>
                  {item.valor_mercado_unitario
                    ? formatCurrencyFull(item.valor_mercado_unitario)
                    : '—'}
                </td>
                <td style={{ padding: '12px 8px' }}>
                  <Link
                    href={`/items/${item.id}`}
                    style={{
                      fontFamily: '"Space Mono", monospace',
                      fontSize: 9,
                      color: '#999999',
                      letterSpacing: '0.08em',
                      textDecoration: 'none',
                    }}
                  >
                    VER →
                  </Link>
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
