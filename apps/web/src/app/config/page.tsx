import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { ConfigClient } from '@/components/config/ConfigClient'

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
        <TopBar kicker="MMD Eventos" title="Configurações" notifications={0} />
        <div style={{ marginTop: 24 }}>
          <ConfigClient />
        </div>
      </div>
    </div>
  )
}
