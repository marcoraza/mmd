import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { UnderConstruction } from '@/components/mmd/UnderConstruction'

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
        <TopBar kicker="MMD Eventos" title="RFID" notifications={0} />

        <UnderConstruction
          phase="stub"
          planned={
            <>
              Central RFID do web. Mostra histórico de scans feitos pelo app iOS
              (quem escaneou, quando, de qual galpão, projeto associado) e o
              estado dos leitores pareados (Zebra RFD40 por operador, bateria,
              última atividade).
            </>
          }
        >
          <strong style={{ color: 'var(--fg-1)' }}>Blocos previstos:</strong>
          <ul style={{ margin: '8px 0 0', paddingLeft: 20, color: 'var(--fg-2)' }}>
            <li>Timeline de scans (filtro por operador, projeto, intervalo)</li>
            <li>Cards de leitores pareados com status de conexão</li>
            <li>Métricas: scans por dia, taxa de leitura, tags não reconhecidas</li>
            <li>Link para vinculação de tag (fluxo iOS, tela 06 do handoff)</li>
          </ul>
        </UnderConstruction>
      </div>
    </div>
  )
}
