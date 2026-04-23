import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { UnderConstruction } from '@/components/mmd/UnderConstruction'

export default function DisponibilidadePage() {
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
          kicker="MMD Eventos"
          title="Disponibilidade"
          notifications={0}
        />

        <UnderConstruction
          phase="stub"
          planned={
            <>
              Calendário de 21 dias com disponibilidade real por item e
              categoria. Mostra janelas ocupadas em barras horizontais, heatmap
              de pressão de estoque, permite abrir o projeto associado a cada
              ocupação.
            </>
          }
        >
          <strong style={{ color: 'var(--fg-1)' }}>Blocos previstos (handoff tela 12):</strong>
          <ul style={{ margin: '8px 0 0', paddingLeft: 20, color: 'var(--fg-2)' }}>
            <li>Grid 21 dias (horizontal) x itens/categorias (vertical)</li>
            <li>Barras por item com janelas ocupadas</li>
            <li>Heatmap de pressão (dias com conflitos previstos)</li>
            <li>Click na janela abre o projeto associado</li>
            <li>Filtros: categoria, texto, mostrar só com conflito</li>
          </ul>
        </UnderConstruction>
      </div>
    </div>
  )
}
