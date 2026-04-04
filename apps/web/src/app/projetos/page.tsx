import { PageHeader } from '@/components/layout/PageHeader'

export default function ProjetosPage() {
  return (
    <div>
      <PageHeader title="Projetos" subtitle="Sprint 4 — em breve" />
      <div style={{ padding: '48px 32px', textAlign: 'center' }}>
        <div style={{ fontFamily: '"Doto", monospace', fontSize: 48, color: '#CCCCCC', lineHeight: 1 }}>
          4
        </div>
        <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#999999', letterSpacing: '0.12em', marginTop: 12 }}>
          DISPONÍVEL NO SPRINT 4
        </div>
      </div>
    </div>
  )
}
