'use client'

import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { GlassCard, Ring, StatusDot, PrimaryBtn, GhostBtn } from '@/components/mmd/Primitives'
import type { MovimentacaoTimeline } from '@/lib/data/items'
import type { ProjectDetail } from '@/lib/data/project-detail'
import {
  formatProjetoDate,
  readinessRingState,
  statusProjetoColor,
  statusProjetoLabel,
} from '../helpers'
import { PackingTab } from './PackingTab'
import { AllocationTab } from './AllocationTab'
import { MovimentacoesTab } from './MovimentacoesTab'
import { CheckoutDialog } from './CheckoutDialog'
import { CheckinDialog } from './CheckinDialog'

type Tab = 'packing' | 'alocacao' | 'movimentacoes'

const TABS: { id: Tab; label: string; hint: string }[] = [
  { id: 'packing', label: 'Packing', hint: 'o que leva' },
  { id: 'alocacao', label: 'Alocação', hint: 'quais seriais' },
  { id: 'movimentacoes', label: 'Movimentações', hint: 'o que aconteceu' },
]

export function ProjectDetailClient({
  projeto,
  movimentacoes,
}: {
  projeto: ProjectDetail
  movimentacoes: MovimentacaoTimeline[]
}) {
  const [tab, setTab] = useState<Tab>('packing')
  const [checkoutOpen, setCheckoutOpen] = useState(false)
  const [checkinOpen, setCheckinOpen] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [pending, startTransition] = useTransition()
  const router = useRouter()

  const canCheckout =
    projeto.status === 'CONFIRMADO' && projeto.readiness_pct >= 100
  const canCheckin = projeto.status === 'EM_CAMPO'
  const ringState = readinessRingState(projeto.readiness_pct)

  const refresh = () => {
    startTransition(() => router.refresh())
  }

  // Todos os seriais alocados, flat, pra passar pro CheckinDialog.
  const allSerials = projeto.packing.flatMap((p) =>
    p.seriais_alocados.map((s) => ({
      id: s.id,
      codigo_interno: s.codigo_interno,
      item_nome: p.item_nome,
      desgaste_atual: s.desgaste,
    }))
  )

  return (
    <>
      {/* Header card */}
      <GlassCard style={{ padding: 22, marginBottom: 18 }}>
        <div
          style={{
            display: 'flex',
            gap: 24,
            alignItems: 'center',
            flexWrap: 'wrap',
          }}
        >
          <Ring
            value={projeto.readiness_pct}
            size={120}
            stroke={9}
            label={`${projeto.readiness_pct}%`}
            subLabel="prontos"
            state={ringState}
            ariaLabel={`Prontidão ${projeto.readiness_pct}%`}
          />

          <div style={{ flex: 1, minWidth: 240, display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
              <span
                className="mono"
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 6,
                  padding: '4px 10px',
                  borderRadius: 999,
                  fontSize: 10,
                  letterSpacing: 0.12,
                  textTransform: 'uppercase',
                  background: 'var(--glass-bg)',
                  border: '1px solid var(--glass-border)',
                  color: statusProjetoColor(projeto.status),
                }}
              >
                <StatusDot color={statusProjetoColor(projeto.status)} size={6} />
                {statusProjetoLabel(projeto.status)}
              </span>
              {projeto.cliente && (
                <span style={{ fontSize: 13, color: 'var(--fg-2)' }}>
                  · {projeto.cliente}
                </span>
              )}
            </div>

            <div
              className="mono"
              style={{ fontSize: 12, color: 'var(--fg-2)', letterSpacing: 0.06 }}
            >
              {formatProjetoDate(projeto.data_inicio)} até {formatProjetoDate(projeto.data_fim)}
              {projeto.local && <span style={{ color: 'var(--fg-3)' }}> · {projeto.local}</span>}
            </div>

            <div style={{ fontSize: 13, color: 'var(--fg-1)' }}>
              {projeto.itens_alocados}/{projeto.itens_total} unidades alocadas em{' '}
              {projeto.packing.length} {projeto.packing.length === 1 ? 'linha' : 'linhas'} de packing
            </div>
          </div>

          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            {canCheckin ? (
              <PrimaryBtn onClick={() => setCheckinOpen(true)}>
                Check-in
              </PrimaryBtn>
            ) : (
              <PrimaryBtn
                onClick={() => setCheckoutOpen(true)}
                disabled={!canCheckout || pending}
              >
                {!canCheckout && projeto.status !== 'CONFIRMADO'
                  ? `Check-out (requer CONFIRMADO)`
                  : !canCheckout
                  ? `Check-out (falta alocar ${projeto.itens_total - projeto.itens_alocados})`
                  : 'Check-out'}
              </PrimaryBtn>
            )}
          </div>
        </div>
      </GlassCard>

      {error && (
        <div
          role="alert"
          style={{
            padding: '10px 14px',
            marginBottom: 14,
            borderRadius: 'var(--r-sm)',
            background: 'color-mix(in oklch, var(--accent-red) 14%, transparent)',
            border: '1px solid color-mix(in oklch, var(--accent-red) 35%, transparent)',
            color: 'var(--accent-red)',
            fontSize: 13,
          }}
        >
          {error}
        </div>
      )}

      {/* Tabs */}
      <div
        role="tablist"
        aria-label="Seções do projeto"
        style={{
          display: 'flex',
          gap: 4,
          marginBottom: 16,
          padding: 4,
          borderRadius: 12,
          background: 'var(--glass-bg)',
          border: '1px solid var(--glass-border)',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          width: 'fit-content',
        }}
      >
        {TABS.map((t) => {
          const active = tab === t.id
          return (
            <button
              key={t.id}
              role="tab"
              aria-selected={active}
              onClick={() => setTab(t.id)}
              style={{
                padding: '8px 16px',
                borderRadius: 8,
                border: 'none',
                background: active ? 'var(--glass-bg-strong)' : 'transparent',
                color: active ? 'var(--fg-0)' : 'var(--fg-2)',
                fontFamily: 'inherit',
                fontSize: 13,
                fontWeight: active ? 500 : 400,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'baseline',
                gap: 8,
                transition: 'background var(--motion-fast), color var(--motion-fast)',
                boxShadow: active ? 'inset 0 0 0 1px var(--glass-border-strong)' : 'none',
              }}
            >
              <span>{t.label}</span>
              <span
                className="mono"
                style={{
                  fontSize: 10,
                  color: active ? 'var(--accent-cyan)' : 'var(--fg-3)',
                  letterSpacing: 0.08,
                }}
              >
                {t.hint}
              </span>
            </button>
          )
        })}
      </div>

      {tab === 'packing' && <PackingTab projeto={projeto} />}
      {tab === 'alocacao' && (
        <AllocationTab
          projeto={projeto}
          onError={setError}
          onDone={refresh}
        />
      )}
      {tab === 'movimentacoes' && <MovimentacoesTab events={movimentacoes} />}

      {checkoutOpen && (
        <CheckoutDialog
          projeto={projeto}
          onClose={() => setCheckoutOpen(false)}
          onSuccess={() => {
            setCheckoutOpen(false)
            refresh()
          }}
          onError={(msg) => {
            setError(msg)
            setCheckoutOpen(false)
          }}
        />
      )}
      {checkinOpen && (
        <CheckinDialog
          projetoId={projeto.id}
          seriais={allSerials}
          onClose={() => setCheckinOpen(false)}
          onSuccess={() => {
            setCheckinOpen(false)
            refresh()
          }}
          onError={(msg) => {
            setError(msg)
            setCheckinOpen(false)
          }}
        />
      )}
    </>
  )
}
