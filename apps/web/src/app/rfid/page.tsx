import { Suspense } from 'react'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { RfidClient } from '@/components/rfid/RfidClient'
import { loadRfid } from '@/lib/data/rfid'

async function RfidContent() {
  const data = await loadRfid()
  return (
    <>
      <TopBar kicker="MMD Eventos" title="RFID" notifications={0} />
      <div style={{ marginTop: 24 }}>
        <RfidClient data={data} />
      </div>
    </>
  )
}

function RfidFallback() {
  return (
    <div style={{ padding: '32px 0', color: 'var(--fg-2)', fontSize: 13 }}>
      Carregando leituras…
    </div>
  )
}

export default function RfidPage() {
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
        <Suspense fallback={<RfidFallback />}>
          <RfidContent />
        </Suspense>
      </div>
    </div>
  )
}
