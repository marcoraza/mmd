import Link from 'next/link'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { UnderConstruction } from '@/components/mmd/UnderConstruction'

export default async function ItemDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params

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
          kicker={
            <Link
              href="/items"
              style={{ color: 'var(--fg-3)', textDecoration: 'none' }}
            >
              ← Catálogo
            </Link>
          }
          title={`Item ${id}`}
          notifications={0}
        />

        <UnderConstruction
          phase="stub"
          planned={
            <>
              Página dedicada de detalhe de item. Hoje o detalhe só existe como
              side panel em /items, o que limita compartilhamento de link e
              visão completa. Esta rota é pra substituir isso por uma tela full
              com timeline, fotos e ações.
            </>
          }
        >
          <strong style={{ color: 'var(--fg-1)' }}>Blocos previstos (handoff tela 04):</strong>
          <ul style={{ margin: '8px 0 0', paddingLeft: 20, color: 'var(--fg-2)' }}>
            <li>Header: foto, código interno, marca/modelo, ring de condição</li>
            <li>Status: estado, desgaste, depreciação, valor atual</li>
            <li>Timeline de movimentações (check-out, check-in, manutenção, reparo)</li>
            <li>Histórico de projetos (eventos que levou)</li>
            <li>Ações: editar, marcar manutenção, baixar, imprimir QR</li>
          </ul>
        </UnderConstruction>
      </div>
    </div>
  )
}
