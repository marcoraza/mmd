import { PageHeader } from '@/components/layout/PageHeader'

export default function ConfigPage() {
  return (
    <div>
      <PageHeader title="Configurações" subtitle="Sistema MMD Estoque" />
      <div style={{ padding: '32px' }}>
        <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 16 }}>
          SISTEMA
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 0, border: '1px solid #E8E8E8' }}>
          {[
            ['Versão', 'Sprint 3 — Web Dashboard'],
            ['Stack', 'Next.js 16 + Supabase + Tailwind 4'],
            ['Design System', 'Nothing Design — Space Grotesk + Doto'],
            ['Banco de Dados', process.env.NEXT_PUBLIC_SUPABASE_URL ?? 'Não configurado'],
          ].map(([label, value], i, arr) => (
            <div
              key={label}
              style={{
                display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                padding: '12px 16px',
                borderBottom: i < arr.length - 1 ? '1px solid #E8E8E8' : undefined,
              }}
            >
              <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 10, color: '#999999', letterSpacing: '0.08em' }}>
                {(label as string).toUpperCase()}
              </span>
              <span style={{ fontFamily: '"Space Grotesk", sans-serif', fontSize: 13, color: '#1A1A1A' }}>
                {value}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
