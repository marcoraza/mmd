import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { UnderConstruction } from '@/components/mmd/UnderConstruction'

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

        <UnderConstruction
          phase="stub"
          planned={
            <>
              Configurações da operação. Perfil da MMD (dados da empresa),
              preferências de exibição, thresholds de alerta, gerenciamento de
              categorias e taxonomia, exportação e backup.
            </>
          }
        >
          <strong style={{ color: 'var(--fg-1)' }}>Blocos previstos:</strong>
          <ul style={{ margin: '8px 0 0', paddingLeft: 20, color: 'var(--fg-2)' }}>
            <li>Perfil da empresa (nome, logo, endereço do galpão)</li>
            <li>Taxonomia: categorias, prefixos, enum de estados</li>
            <li>Alertas: thresholds de desgaste, janela de devolução</li>
            <li>Backup e export de dados</li>
            <li>Auth roles (pós-MVP)</li>
          </ul>
        </UnderConstruction>
      </div>
    </div>
  )
}
