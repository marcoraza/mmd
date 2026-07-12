import { Suspense } from 'react'
import { LotesLegacyClient } from '@/components/lotes/LotesLegacyClient'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { loadLotes } from '@/lib/data/lotes'

export const dynamic = 'force-dynamic'

async function LotesContent() {
  const data = await loadLotes()
  return (
    <>
      <TopBar kicker="MMD Eventos" title="Lotes legados" notifications={0} />
      <div style={{ marginTop: 24 }}>
        <LotesLegacyClient data={data} />
      </div>
    </>
  )
}

function LotesFallback() {
  return (
    <div style={{ padding: '32px 0', color: 'var(--fg-2)', fontSize: 13 }}>
      Carregando lotes legados
    </div>
  )
}

export default function LotesPage() {
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
        <Suspense fallback={<LotesFallback />}>
          <LotesContent />
        </Suspense>
      </div>
    </div>
  )
}
