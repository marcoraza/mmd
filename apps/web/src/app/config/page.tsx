import { Suspense } from 'react'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { ConfigClient } from '@/components/config/ConfigClient'
import { loadConfig } from '@/lib/data/config'

async function ConfigContent() {
  const data = await loadConfig()
  return (
    <>
      <TopBar kicker="MMD Eventos" title="Configurações" notifications={0} />
      <div style={{ marginTop: 24 }}>
        <ConfigClient data={data} />
      </div>
    </>
  )
}

function ConfigFallback() {
  return (
    <div style={{ padding: '32px 0', color: 'var(--fg-2)', fontSize: 13 }}>
      Carregando painel da operação…
    </div>
  )
}

export default function ConfigPage() {
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
        <Suspense fallback={<ConfigFallback />}>
          <ConfigContent />
        </Suspense>
      </div>
    </div>
  )
}
