import Link from 'next/link'
import { notFound } from 'next/navigation'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { CATEGORIA_LABEL } from '@/components/catalog/helpers'
import { ItemDetailClient } from '@/components/item-detail/ItemDetailClient'
import { getItemById } from '@/lib/data/items'

export default async function ItemDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const detail = await getItemById(id)
  if (!detail) notFound()

  const { item, notas, serials, timeline } = detail

  return (
    <div style={{ position: 'relative', minHeight: '100dvh' }}>
      <Caustic />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          padding: 'clamp(20px, 3vw, 28px) clamp(20px, 4vw, 48px)',
        }}
      >
        <TopBar
          kicker={
            <Link
              href="/items"
              style={{ color: 'var(--fg-3)', textDecoration: 'none' }}
            >
              ← Catálogo
            </Link>
          }
          title={item.nome}
          notifications={0}
        />

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            marginTop: 14,
            marginBottom: 18,
            fontSize: 12,
            color: 'var(--fg-2)',
            flexWrap: 'wrap',
          }}
        >
          <Link href="/items" style={{ color: 'var(--fg-2)', textDecoration: 'none' }}>
            Inventário
          </Link>
          <span style={{ color: 'var(--fg-3)' }}>/</span>
          <span>{CATEGORIA_LABEL[item.categoria]}</span>
          <span style={{ color: 'var(--fg-3)' }}>/</span>
          <span style={{ color: 'var(--fg-0)' }}>{item.nome}</span>
        </div>

        <ItemDetailClient
          item={item}
          serials={serials}
          timeline={timeline}
          notas={notas}
        />
      </div>
    </div>
  )
}
