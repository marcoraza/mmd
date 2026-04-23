import { Suspense } from 'react'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { QrCodesClient } from '@/components/qrcodes/QrCodesClient'
import { loadQrSources } from '@/lib/data/qrcodes'

async function QrCodesContent() {
  const data = await loadQrSources()
  return (
    <>
      <TopBar kicker="MMD Eventos" title="QR Codes" notifications={0} />
      <div style={{ marginTop: 24 }}>
        <QrCodesClient data={data} />
      </div>
    </>
  )
}

function QrCodesFallback() {
  return (
    <div style={{ padding: '32px 0', color: 'var(--fg-2)', fontSize: 13 }}>
      Carregando catálogo...
    </div>
  )
}

export default function QrCodesPage() {
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
        <Suspense fallback={<QrCodesFallback />}>
          <QrCodesContent />
        </Suspense>
      </div>
    </div>
  )
}
