import { Suspense } from 'react'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { ProjectsClient } from '@/components/projects/ProjectsClient'
import { loadProjects } from '@/lib/data/projects'

async function ProjectsContent() {
  const data = await loadProjects()
  return (
    <>
      <TopBar kicker="MMD Eventos" title="Projetos" notifications={0} />
      <div style={{ marginTop: 24 }}>
        <ProjectsClient data={data} />
      </div>
    </>
  )
}

function ProjectsFallback() {
  return (
    <div style={{ padding: '32px 0', color: 'var(--fg-2)', fontSize: 13 }}>
      Carregando projetos…
    </div>
  )
}

export default function ProjetosPage() {
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
        <Suspense fallback={<ProjectsFallback />}>
          <ProjectsContent />
        </Suspense>
      </div>
    </div>
  )
}
