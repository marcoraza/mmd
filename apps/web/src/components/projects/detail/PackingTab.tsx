'use client'

import { GlassCard, StatusDot } from '@/components/mmd/Primitives'
import type { ProjectDetail } from '@/lib/data/project-detail'

// View-only por enquanto: edição de quantidade/linha continua no split-pane
// de /projetos (ProjectListView), onde o fluxo de adicionar item via
// InlineItemPicker já está consolidado. Se Marco pedir inline-edit aqui
// também, extrair PackingTable compartilhado vira o próximo passo.

const STATUS_META = {
  ok: { color: 'var(--accent-green)', label: 'Pronto' },
  partial: { color: 'var(--accent-amber)', label: 'Parcial' },
  missing: { color: 'var(--accent-red)', label: 'Faltando' },
  conflict: { color: 'var(--accent-red)', label: 'Conflito' },
} as const

export function PackingTab({ projeto }: { projeto: ProjectDetail }) {
  if (projeto.packing.length === 0) {
    return (
      <GlassCard style={{ padding: 32, textAlign: 'center' }}>
        <div style={{ fontSize: 13, color: 'var(--fg-3)' }}>
          Nenhum item no packing list. Volte para{' '}
          <a
            href={`/projetos`}
            style={{ color: 'var(--accent-cyan)', textDecoration: 'none' }}
          >
            /projetos
          </a>{' '}
          para adicionar itens.
        </div>
      </GlassCard>
    )
  }

  return (
    <GlassCard style={{ padding: 0, overflow: 'hidden' }}>
      <div style={{ overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
          <thead>
            <tr
              style={{
                background: 'var(--glass-bg)',
                borderBottom: '1px solid var(--glass-border)',
              }}
            >
              <Th>Item</Th>
              <Th mono>Código</Th>
              <Th>Categoria</Th>
              <Th align="right">Qtd</Th>
              <Th align="right">Alocado</Th>
              <Th>Status</Th>
            </tr>
          </thead>
          <tbody>
            {projeto.packing.map((p) => {
              const meta = STATUS_META[p.status]
              const pct = p.qtd_necessaria > 0 ? (p.qtd_alocada / p.qtd_necessaria) * 100 : 0
              return (
                <tr
                  key={p.id}
                  style={{ borderTop: '1px solid var(--glass-border)' }}
                >
                  <td style={{ padding: 12, color: 'var(--fg-0)', fontWeight: 450 }}>
                    {p.item_nome}
                  </td>
                  <td style={{ padding: 12 }} className="mono">
                    <span style={{ fontSize: 11, color: 'var(--fg-2)' }}>{p.codigo_interno}</span>
                  </td>
                  <td style={{ padding: 12, color: 'var(--fg-1)' }}>{p.categoria}</td>
                  <td
                    className="mono"
                    style={{ padding: 12, textAlign: 'right', color: 'var(--fg-1)' }}
                  >
                    {p.qtd_necessaria}
                  </td>
                  <td style={{ padding: 12 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, justifyContent: 'flex-end' }}>
                      <div
                        style={{
                          width: 60,
                          height: 4,
                          borderRadius: 2,
                          background: 'var(--glass-border)',
                          overflow: 'hidden',
                        }}
                      >
                        <div
                          style={{ width: `${pct}%`, height: '100%', background: meta.color }}
                        />
                      </div>
                      <span className="mono" style={{ fontSize: 11, color: 'var(--fg-2)' }}>
                        {p.qtd_alocada}/{p.qtd_necessaria}
                      </span>
                    </div>
                  </td>
                  <td style={{ padding: 12 }}>
                    <span
                      className="mono"
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 6,
                        fontSize: 11,
                        letterSpacing: 0.05,
                        color: meta.color,
                      }}
                    >
                      <StatusDot color={meta.color} size={6} />
                      {meta.label}
                    </span>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </GlassCard>
  )
}

function Th({
  children,
  align = 'left',
  mono = false,
}: {
  children: React.ReactNode
  align?: 'left' | 'right'
  mono?: boolean
}) {
  return (
    <th
      className={mono ? 'mono' : undefined}
      style={{
        padding: 12,
        textAlign: align,
        fontSize: 10,
        letterSpacing: 0.12,
        textTransform: 'uppercase',
        color: 'var(--fg-3)',
        fontWeight: 500,
      }}
    >
      {children}
    </th>
  )
}
