import { notFound } from 'next/navigation'
import Link from 'next/link'
import { supabase } from '@/lib/supabase'
import { PageHeader } from '@/components/layout/PageHeader'
import { CategoryBadge } from '@/components/ui/CategoryBadge'
import { SerialNumberList } from '@/components/items/SerialNumberList'
import { formatCurrencyFull } from '@/lib/design-tokens'
import type { Item, SerialNumber, Movimentacao } from '@/lib/types'
import { DeleteItemButton } from './DeleteItemButton'
import { SerialNumberSection } from './SerialNumberSection'

interface Props {
  params: Promise<{ id: string }>
}

async function getItem(id: string) {
  const { data } = await supabase
    .from('items')
    .select('*, serial_numbers(*)')
    .eq('id', id)
    .single()
  return data as (Item & { serial_numbers: SerialNumber[] }) | null
}

async function getMovimentacoes(itemId: string) {
  const { data } = await supabase
    .from('movimentacoes')
    .select('*, serial_numbers!inner(item_id, codigo_interno)')
    .eq('serial_numbers.item_id', itemId)
    .order('timestamp', { ascending: false })
    .limit(10)
  return (data ?? []) as Movimentacao[]
}

const TIPO_COLORS: Record<string, string> = {
  SAIDA: '#D4A843',
  RETORNO: '#4A9E5C',
  MANUTENCAO: '#D71921',
  TRANSFERENCIA: '#5B9BF6',
  DANO: '#D71921',
}

export default async function ItemDetailPage({ params }: Props) {
  const { id } = await params
  const item = await getItem(id)

  if (!item) notFound()

  const movimentacoes = await getMovimentacoes(id)
  const serials = item.serial_numbers ?? []
  const valorTotal = serials.reduce((s, sn) => s + (sn.valor_atual ?? 0), 0)

  return (
    <div>
      <PageHeader
        title={item.nome}
        subtitle={`${item.marca ?? ''}${item.modelo ? ` · ${item.modelo}` : ''}`}
        action={
          <div style={{ display: 'flex', gap: 8 }}>
            <Link
              href={`/items/${item.id}/edit`}
              style={{
                fontFamily: '"Space Mono", monospace',
                fontSize: 11,
                letterSpacing: '0.1em',
                color: '#666666',
                border: '1px solid #CCCCCC',
                borderRadius: 999,
                padding: '6px 14px',
                textDecoration: 'none',
              }}
            >
              EDITAR
            </Link>
            <DeleteItemButton itemId={item.id} hasSerials={serials.length > 0} />
          </div>
        }
      />

      {/* Hero section */}
      <div style={{ padding: '24px 32px', borderBottom: '1px solid #E8E8E8', display: 'flex', gap: 32, alignItems: 'flex-start' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
            <CategoryBadge categoria={item.categoria} />
            {item.subcategoria && (
              <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em' }}>
                {item.subcategoria.toUpperCase()}
              </span>
            )}
            <span style={{
              fontFamily: '"Space Mono", monospace',
              fontSize: 9,
              letterSpacing: '0.1em',
              color: '#666666',
              border: '1px solid #E8E8E8',
              borderRadius: 999,
              padding: '2px 8px',
            }}>
              {item.tipo_rastreamento}
            </span>
          </div>
          <div style={{ marginTop: 16, display: 'flex', gap: 32 }}>
            <Stat label="Total" value={String(item.quantidade_total)} />
            <Stat label="Disponíveis" value={String(serials.filter((s) => s.status === 'DISPONIVEL').length)} valueColor="#4A9E5C" />
            <Stat label="Em Campo" value={String(serials.filter((s) => s.status === 'EM_CAMPO').length)} />
            <Stat label="Valor Unitário" value={item.valor_mercado_unitario ? formatCurrencyFull(item.valor_mercado_unitario) : '—'} />
            <Stat label="Valor Total Atual" value={valorTotal > 0 ? formatCurrencyFull(valorTotal) : '—'} />
          </div>

          {item.notas && (
            <div style={{
              marginTop: 16,
              padding: '10px 14px',
              backgroundColor: '#FAFAFA',
              border: '1px solid #E8E8E8',
            }}>
              <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 4 }}>
                NOTAS
              </div>
              <div style={{ fontFamily: '"Space Grotesk", sans-serif', fontSize: 13, color: '#666666', lineHeight: 1.5 }}>
                {item.notas}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Serial numbers */}
      <div style={{ borderBottom: '1px solid #E8E8E8' }}>
        <div style={{ padding: '20px 32px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em' }}>
            SERIAL NUMBERS ({serials.length})
          </span>
        </div>
        <div style={{ padding: '0 32px 16px' }}>
          <SerialNumberSection item={item} serials={serials} />
        </div>
      </div>

      {/* Histórico */}
      {movimentacoes.length > 0 && (
        <div style={{ padding: '20px 32px' }}>
          <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 16 }}>
            HISTÓRICO DE MOVIMENTAÇÕES
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {movimentacoes.map((m) => (
              <div key={m.id} style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
                <div style={{ width: 5, height: 5, borderRadius: '50%', backgroundColor: TIPO_COLORS[m.tipo] ?? '#999', marginTop: 5, flexShrink: 0 }} />
                <div>
                  <span style={{ fontFamily: '"Space Grotesk", sans-serif', fontSize: 13, color: '#1A1A1A' }}>
                    {m.tipo}{m.notas ? ` — ${m.notas}` : ''}
                  </span>
                  <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', marginTop: 2 }}>
                    {new Date(m.timestamp).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function Stat({ label, value, valueColor }: { label: string; value: string; valueColor?: string }) {
  return (
    <div>
      <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.1em', marginBottom: 4 }}>
        {label.toUpperCase()}
      </div>
      <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 18, fontWeight: 700, color: valueColor ?? '#000000' }}>
        {value}
      </div>
    </div>
  )
}
