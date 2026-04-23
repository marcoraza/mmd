import Link from 'next/link'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { UnderConstruction } from '@/components/mmd/UnderConstruction'

export default async function LoteDetailPage({
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
              href="/lotes"
              style={{ color: 'var(--fg-3)', textDecoration: 'none' }}
            >
              ← Lotes
            </Link>
          }
          title={`Lote ${id}`}
          notifications={0}
        />

        <UnderConstruction
          phase="stub"
          planned={
            <>
              Detalhe de um lote individual. Composição completa (quantidade por
              tipo de cabo), QR grande imprimível, histórico de uso em eventos,
              perdas registradas.
            </>
          }
        >
          <strong style={{ color: 'var(--fg-1)' }}>Blocos previstos:</strong>
          <ul style={{ margin: '8px 0 0', paddingLeft: 20, color: 'var(--fg-2)' }}>
            <li>Header com QR grande + código interno do lote</li>
            <li>Composição: lista de cabos por categoria e metragem</li>
            <li>Timeline de uso: eventos que levaram esse lote</li>
            <li>Ações: editar composição, marcar perda, imprimir QR, baixar lote</li>
          </ul>
        </UnderConstruction>
      </div>
    </div>
  )
}
