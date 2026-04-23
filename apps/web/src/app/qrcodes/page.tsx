import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { UnderConstruction } from '@/components/mmd/UnderConstruction'

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
        <TopBar
          kicker="MMD Eventos"
          title="QR Codes"
          notifications={0}
        />

        <UnderConstruction
          phase="stub"
          planned={
            <>
              Gerador de folha de QR pra impressão em adesivo. Seleciona itens
              (ou lotes), escolhe tamanho e layout, vê preview paginado, exporta
              PDF pronto pra imprimir.
            </>
          }
        >
          <strong style={{ color: 'var(--fg-1)' }}>Fluxo previsto:</strong>
          <ul style={{ margin: '8px 0 0', paddingLeft: 20, color: 'var(--fg-2)' }}>
            <li>Seleção de items ou lotes (busca + multi-select)</li>
            <li>Config de layout (tamanho da etiqueta, colunas, margens)</li>
            <li>Preview paginado com QR + código interno + nome curto</li>
            <li>Export PDF vetorial, pronto pra papel adesivo A4</li>
            <li>Ref: tela 05 do handoff (QR Print Sheet)</li>
          </ul>
        </UnderConstruction>
      </div>
    </div>
  )
}
