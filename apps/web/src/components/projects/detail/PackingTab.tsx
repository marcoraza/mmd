'use client'

import { useState, useTransition } from 'react'
import { EditableQty } from '@/components/catalog/EditableQty'
import { Btn, GlassCard, Ring, StatusDot } from '@/components/mmd/Primitives'
import { InlineItemPicker } from '@/components/projects/InlineItemPicker'
import { addPackingItem, removePackingItem, updatePackingQty } from '@/lib/actions/projetos'
import type { ProjectDetail } from '@/lib/data/project-detail'
import { PackingImportPanel } from './PackingImportPanel'
import { PackingSuggestionPanel } from './PackingSuggestionPanel'

const STATUS_META = {
  ok: { color: 'var(--accent-green)', label: 'Pronto' },
  partial: { color: 'var(--accent-amber)', label: 'Parcial' },
  missing: { color: 'var(--accent-red)', label: 'Faltando' },
  conflict: { color: 'var(--accent-red)', label: 'Conflito' },
} as const

export function PackingTab({
  projeto,
  onError,
  onDone,
}: {
  projeto: ProjectDetail
  onError: (message: string | null) => void
  onDone: () => void
}) {
  const [adding, setAdding] = useState(projeto.packing.length === 0)
  const [importing, setImporting] = useState(false)
  const [suggesting, setSuggesting] = useState(false)
  const [pending, startTransition] = useTransition()

  function toggleAdding() {
    setAdding((value) => {
      const next = !value
      if (next) {
        setImporting(false)
        setSuggesting(false)
      }
      return next
    })
  }

  function toggleImporting() {
    setImporting((value) => {
      const next = !value
      if (next) {
        setAdding(false)
        setSuggesting(false)
      }
      return next
    })
  }

  function toggleSuggesting() {
    setSuggesting((value) => {
      const next = !value
      if (next) {
        setAdding(false)
        setImporting(false)
      }
      return next
    })
  }

  function handleAddItem(itemId: string, qtd: number) {
    onError(null)
    startTransition(async () => {
      const res = await addPackingItem(projeto.id, itemId, qtd)
      if (!res.ok) {
        onError(res.error)
        return
      }
      setAdding(false)
      onDone()
    })
  }

  function handleUpdateQty(packingId: string, qtd: number) {
    onError(null)
    startTransition(async () => {
      const res = await updatePackingQty(packingId, qtd)
      if (!res.ok) {
        onError(res.error)
        return
      }
      onDone()
    })
  }

  function handleRemoveItem(packingId: string) {
    onError(null)
    startTransition(async () => {
      const res = await removePackingItem(packingId)
      if (!res.ok) {
        onError(res.error)
        return
      }
      onDone()
    })
  }

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 560px), 1fr))',
        gap: 16,
        alignItems: 'start',
      }}
    >
      <GlassCard
        style={{
          padding: 0,
          overflow: 'hidden',
          gridColumn: importing || suggesting ? '1 / -1' : undefined,
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 16,
            padding: '16px 20px',
            borderBottom: '1px solid var(--glass-border)',
            flexWrap: 'wrap',
          }}
        >
          <div>
            <div style={{ fontSize: 15, color: 'var(--fg-0)', fontWeight: 500 }}>
              Packing do Evento
            </div>
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', marginTop: 3 }}>
              {projeto.packing.length} linhas · {projeto.itens_total} unidades ·{' '}
              {projeto.itens_alocados} cobertas
            </div>
          </div>
          <div style={{ flex: 1 }} />
          <Btn variant="ghost" small onClick={toggleSuggesting}>
            {suggesting ? 'Fechar sugestão' : 'Sugerir packing'}
          </Btn>
          <Btn variant="ghost" small onClick={toggleImporting}>
            {importing ? 'Cancelar importação' : 'Importar planilha'}
          </Btn>
          <Btn variant="ghost" small onClick={toggleAdding}>
            {adding ? 'Cancelar' : '+ Adicionar item'}
          </Btn>
        </div>

        {suggesting && (
          <PackingSuggestionPanel
            projetoId={projeto.id}
            onError={onError}
            onClose={() => setSuggesting(false)}
            onApplied={() => {
              setSuggesting(false)
              onDone()
            }}
          />
        )}

        {importing && (
          <PackingImportPanel
            projetoId={projeto.id}
            onError={onError}
            onClose={() => setImporting(false)}
            onApplied={() => {
              setImporting(false)
              onDone()
            }}
          />
        )}

        {adding && (
          <div style={{ padding: 16, borderBottom: '1px solid var(--glass-border)' }}>
            <InlineItemPicker onPick={handleAddItem} pending={pending} />
          </div>
        )}

        <div className="packing-desktop-table" style={{ overflowX: 'auto' }}>
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
                <Th align="right">Coberto</Th>
                <Th>Status</Th>
                <Th align="right">Ações</Th>
              </tr>
            </thead>
            <tbody>
              {projeto.packing.map((p) => {
                const meta = STATUS_META[p.status]
                const pct = p.qtd_necessaria > 0 ? (p.qtd_coberta / p.qtd_necessaria) * 100 : 0
                return (
                  <tr key={p.id} style={{ borderTop: '1px solid var(--glass-border)' }}>
                    <td style={{ padding: 12, color: 'var(--fg-0)', fontWeight: 450 }}>
                      {p.item_nome}
                      {p.notas && (
                        <div
                          style={{
                            marginTop: 5,
                            color: 'var(--fg-3)',
                            fontSize: 11,
                            fontWeight: 400,
                            whiteSpace: 'pre-wrap',
                          }}
                        >
                          {p.notas}
                        </div>
                      )}
                    </td>
                    <td style={{ padding: 12 }} className="mono">
                      <span style={{ fontSize: 11, color: 'var(--fg-2)' }}>{p.codigo_interno}</span>
                    </td>
                    <td style={{ padding: 12, color: 'var(--fg-1)' }}>{p.categoria}</td>
                    <td
                      className="mono"
                      style={{ padding: '8px 12px', textAlign: 'right', color: 'var(--fg-1)' }}
                    >
                      <EditableQty
                        value={p.qtd_necessaria}
                        pending={pending}
                        onChange={(qtd) => handleUpdateQty(p.id, qtd)}
                      />
                    </td>
                    <td style={{ padding: 12 }}>
                      <div
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: 8,
                          justifyContent: 'flex-end',
                        }}
                      >
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
                          {p.qtd_coberta}/{p.qtd_necessaria}
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
                    <td style={{ padding: 12, textAlign: 'right' }}>
                      <button
                        type="button"
                        aria-label={`Remover ${p.item_nome} do Evento`}
                        disabled={pending}
                        onClick={() => handleRemoveItem(p.id)}
                        style={{
                          width: 32,
                          height: 32,
                          borderRadius: 8,
                          border: '1px solid var(--glass-border)',
                          background: 'var(--glass-bg)',
                          color: 'var(--fg-3)',
                          cursor: pending ? 'wait' : 'pointer',
                          fontSize: 18,
                          lineHeight: 1,
                        }}
                      >
                        ×
                      </button>
                    </td>
                  </tr>
                )
              })}
              {projeto.packing.length === 0 && (
                <tr>
                  <td colSpan={7} style={{ padding: 28, textAlign: 'center' }}>
                    <div style={{ fontSize: 13, color: 'var(--fg-2)' }}>
                      Nenhum item no packing do Evento.
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--fg-3)', marginTop: 4 }}>
                      Use o catálogo acima para montar a lista manual.
                    </div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        <div className="packing-mobile-list">
          {projeto.packing.map((p) => {
            const meta = STATUS_META[p.status]
            const pct = p.qtd_necessaria > 0 ? (p.qtd_coberta / p.qtd_necessaria) * 100 : 0
            return (
              <div
                key={p.id}
                style={{
                  padding: 14,
                  borderTop: '1px solid var(--glass-border)',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 12,
                }}
              >
                <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ color: 'var(--fg-0)', fontWeight: 500, fontSize: 13 }}>
                      {p.item_nome}
                    </div>
                    <div
                      className="mono"
                      style={{ color: 'var(--fg-3)', fontSize: 10, marginTop: 4 }}
                    >
                      {p.codigo_interno} · {p.categoria}
                    </div>
                    {p.notas && (
                      <div
                        style={{
                          marginTop: 6,
                          color: 'var(--fg-3)',
                          fontSize: 12,
                          whiteSpace: 'pre-wrap',
                        }}
                      >
                        {p.notas}
                      </div>
                    )}
                  </div>
                  <button
                    type="button"
                    aria-label={`Remover ${p.item_nome} do Evento`}
                    disabled={pending}
                    onClick={() => handleRemoveItem(p.id)}
                    style={{
                      width: 32,
                      height: 32,
                      borderRadius: 8,
                      border: '1px solid var(--glass-border)',
                      background: 'var(--glass-bg)',
                      color: 'var(--fg-3)',
                      cursor: pending ? 'wait' : 'pointer',
                      fontSize: 18,
                      lineHeight: 1,
                      flex: '0 0 32px',
                    }}
                  >
                    ×
                  </button>
                </div>

                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(2, minmax(0, 1fr))',
                    gap: 12,
                  }}
                >
                  <div>
                    <MobileLabel>Qtd</MobileLabel>
                    <EditableQty
                      value={p.qtd_necessaria}
                      pending={pending}
                      onChange={(qtd) => handleUpdateQty(p.id, qtd)}
                    />
                  </div>
                  <div>
                    <MobileLabel>Coberto</MobileLabel>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <div
                        style={{
                          flex: 1,
                          height: 4,
                          borderRadius: 2,
                          background: 'var(--glass-border)',
                          overflow: 'hidden',
                        }}
                      >
                        <div style={{ width: `${pct}%`, height: '100%', background: meta.color }} />
                      </div>
                      <span className="mono" style={{ fontSize: 11, color: 'var(--fg-2)' }}>
                        {p.qtd_coberta}/{p.qtd_necessaria}
                      </span>
                    </div>
                  </div>
                  <div style={{ gridColumn: '1 / -1' }}>
                    <MobileLabel>Status</MobileLabel>
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
                  </div>
                </div>
              </div>
            )
          })}
          {projeto.packing.length === 0 && (
            <div style={{ padding: 24, textAlign: 'center' }}>
              <div style={{ fontSize: 13, color: 'var(--fg-2)' }}>
                Nenhum item no packing do Evento.
              </div>
              <div style={{ fontSize: 12, color: 'var(--fg-3)', marginTop: 4 }}>
                Use o catálogo acima para montar a lista manual.
              </div>
            </div>
          )}
        </div>
      </GlassCard>

      <GlassCard style={{ padding: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 16 }}>
          <Ring
            value={projeto.readiness_pct}
            size={92}
            stroke={8}
            label="packing"
            state={
              projeto.readiness_pct >= 100
                ? 'ready'
                : projeto.readiness_pct > 0
                  ? 'partial'
                  : 'missing'
            }
            ariaLabel={`Prontidão do packing ${projeto.readiness_pct}%`}
          />
          <div>
            <div
              className="mono"
              style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.1 }}
            >
              RESUMO DO PACKING
            </div>
            <div style={{ color: 'var(--fg-0)', fontSize: 15, marginTop: 6 }}>
              {projeto.itens_alocados}/{projeto.itens_total} unidades cobertas
            </div>
            <div style={{ color: 'var(--fg-3)', fontSize: 12, marginTop: 3 }}>
              {projeto.packing.length} {projeto.packing.length === 1 ? 'linha' : 'linhas'}{' '}
              vinculadas ao Evento
            </div>
          </div>
        </div>

        <div style={{ borderTop: '1px solid var(--glass-border)', paddingTop: 14 }}>
          <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.1 }}>
            PRÓXIMO PASSO
          </div>
          <div
            style={{
              marginTop: 10,
              border: '1px solid var(--glass-border)',
              borderRadius: 8,
              padding: 12,
              background: 'color-mix(in oklch, var(--accent-violet) 14%, transparent)',
            }}
          >
            <div style={{ color: 'var(--fg-0)', fontSize: 14 }}>Alocar unidades</div>
            <div style={{ color: 'var(--fg-3)', fontSize: 12, marginTop: 4 }}>
              Depois do packing manual, selecione as unidades físicas na aba Alocação.
            </div>
          </div>
        </div>
      </GlassCard>

      <style>{`
        .packing-mobile-list {
          display: none;
        }

        @media (max-width: 720px) {
          .packing-desktop-table {
            display: none;
          }

          .packing-mobile-list {
            display: flex;
            flex-direction: column;
          }
        }
      `}</style>
    </div>
  )
}

function MobileLabel({ children }: { children: React.ReactNode }) {
  return (
    <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', marginBottom: 6 }}>
      {children}
    </div>
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
