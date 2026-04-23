import Link from 'next/link'
import { notFound } from 'next/navigation'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { CATEGORIA_LABEL } from '@/components/catalog/helpers'
import { LoteDetailClient } from '@/components/lotes/LoteDetailClient'
import { getLoteById, getRelatedLotes } from '@/lib/data/lotes'

export default async function LoteDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const lote = await getLoteById(id)
  if (!lote) notFound()

  const related = await getRelatedLotes(lote.item_id, lote.id)

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
              href="/lotes"
              style={{ color: 'var(--fg-3)', textDecoration: 'none' }}
            >
              ← Lotes
            </Link>
          }
          title={lote.codigo_lote}
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
          <Link href="/lotes" style={{ color: 'var(--fg-2)', textDecoration: 'none' }}>
            Lotes
          </Link>
          <span style={{ color: 'var(--fg-3)' }}>/</span>
          <span>{CATEGORIA_LABEL[lote.item_categoria]}</span>
          <span style={{ color: 'var(--fg-3)' }}>/</span>
          <span style={{ color: 'var(--fg-0)' }}>{lote.codigo_lote}</span>
        </div>

        <LoteDetailClient lote={lote} related={related} />
      </div>
    </div>
  )
}
