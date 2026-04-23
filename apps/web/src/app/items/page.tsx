import { Suspense } from 'react'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { CatalogClient } from '@/components/catalog/CatalogClient'
import { loadCatalog, loadUnits } from '@/lib/data/items'

async function CatalogContent() {
  const [data, units] = await Promise.all([loadCatalog(), loadUnits()])
  return (
    <>
      <TopBar kicker="MMD Eventos" title="Catálogo" notifications={0} />
      <div style={{ marginTop: 24 }}>
        <CatalogClient data={data} units={units} />
      </div>
    </>
  )
}

function CatalogFallback() {
  return (
    <div
      style={{
        padding: '32px 0',
        color: 'var(--fg-2)',
        fontSize: 13,
      }}
    >
      Carregando catálogo…
    </div>
  )
}

export default function ItemsPage() {
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
        <Suspense fallback={<CatalogFallback />}>
          <CatalogContent />
        </Suspense>
      </div>
    </div>
  )
}
