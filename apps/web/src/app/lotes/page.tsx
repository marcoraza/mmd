import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { UnderConstruction } from '@/components/mmd/UnderConstruction'

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
        <TopBar kicker="MMD Eventos" title="Lotes" notifications={0} />

        <UnderConstruction
          phase="stub"
          planned={
            <>
              Lista dos lotes de cabos genéricos. Cada lote agrupa N cabos
              fisicamente amarrados em kit, com QR único por lote. Alternativa
              ao tagging individual, foco prático pro galpão.
            </>
          }
        >
          <strong style={{ color: 'var(--fg-1)' }}>Blocos previstos:</strong>
          <ul style={{ margin: '8px 0 0', paddingLeft: 20, color: 'var(--fg-2)' }}>
            <li>Grid de lotes: QR, composição resumida, status</li>
            <li>Criar lote: escolhe categoria, define quantidades, gera QR</li>
            <li>Histórico: eventos que usaram o lote, perdas</li>
            <li>Link pra detalhe em /lotes/[id]</li>
          </ul>
        </UnderConstruction>
      </div>
    </div>
  )
}
