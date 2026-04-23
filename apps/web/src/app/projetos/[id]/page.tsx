import Link from 'next/link'
import { notFound } from 'next/navigation'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { ProjectDetailClient } from '@/components/projects/detail/ProjectDetailClient'
import { loadProjectById } from '@/lib/data/project-detail'
import { loadMovimentacoesByProject } from '@/lib/data/movimentacoes'

export default async function ProjectDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params

  // Detalhe e timeline em paralelo. Se o detalhe não existir, 404.
  const [projeto, movimentacoes] = await Promise.all([
    loadProjectById(id),
    loadMovimentacoesByProject(id),
  ])

  if (!projeto) notFound()

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
              href="/projetos"
              style={{ color: 'var(--fg-3)', textDecoration: 'none' }}
            >
              ← Projetos
            </Link>
          }
          title={projeto.nome}
          notifications={0}
        />

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            marginTop: 14,
            marginBottom: 18,
            fontSize: 12,
            color: 'var(--fg-2)',
            flexWrap: 'wrap',
          }}
        >
          <Link href="/projetos" style={{ color: 'var(--fg-2)', textDecoration: 'none' }}>
            Projetos
          </Link>
          <span style={{ color: 'var(--fg-3)' }}>/</span>
          <span style={{ color: 'var(--fg-0)' }}>{projeto.nome}</span>
        </div>

        <ProjectDetailClient projeto={projeto} movimentacoes={movimentacoes} />
      </div>
    </div>
  )
}
