'use client'

import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { GlassCard, Ring, StatusDot, Btn } from '@/components/mmd/Primitives'
import type { MovimentacaoTimeline } from '@/lib/data/items'
import type { ProjectDetail } from '@/lib/data/project-detail'
import { comercialStatusLabel, statusAllowsEstoque } from '@/lib/evento-comercial-core'
import {
  formatProjetoDate,
  readinessRingState,
  statusProjetoColor,
  statusProjetoLabel,
} from '../helpers'
import { PackingTab } from './PackingTab'
import { AllocationTab } from './AllocationTab'
import { MovimentacoesTab } from './MovimentacoesTab'
import { CommercialTab } from './CommercialTab'
import { CheckoutDialog } from './CheckoutDialog'
import { CheckinDialog } from './CheckinDialog'

type Tab = 'packing' | 'alocacao' | 'comercial' | 'movimentacoes'

const TABS: { id: Tab; label: string; hint: string }[] = [
  { id: 'packing', label: 'Packing', hint: 'o que leva' },
  { id: 'alocacao', label: 'Alocação', hint: 'quais seriais' },
  { id: 'comercial', label: 'Comercial', hint: 'status e docs' },
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

  const gate = projeto.checkout_gate
  const canCheckout = gate.canCheckout
  const canOverride = gate.canOverride
  const retornoPendencias = projeto.retorno_pendencias ?? []
  const hasOpenReturnPending = retornoPendencias.some(
    (pendencia) => pendencia.status === 'ABERTA',
  )
  const canCheckin = projeto.status === 'EM_CAMPO' || hasOpenReturnPending
  const ringState = readinessRingState(projeto.readiness_pct)
  const commercialAllowsStock = statusAllowsEstoque(projeto.comercial.status)

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
      status: s.status,
    })),
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
                <span style={{ fontSize: 13, color: 'var(--fg-2)' }}>· {projeto.cliente}</span>
              )}
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
                  background: commercialAllowsStock
                    ? 'color-mix(in oklch, var(--accent-green) 12%, transparent)'
                    : 'var(--glass-bg)',
                  border: '1px solid var(--glass-border)',
                  color: commercialAllowsStock ? 'var(--accent-green)' : 'var(--fg-3)',
                }}
              >
                <StatusDot
                  color={commercialAllowsStock ? 'var(--accent-green)' : 'var(--fg-3)'}
                  size={6}
                />
                {comercialStatusLabel(projeto.comercial.status)}
              </span>
            </div>

            <div
              className="mono"
              style={{ fontSize: 12, color: 'var(--fg-2)', letterSpacing: 0.06 }}
            >
              {formatProjetoDate(projeto.data_inicio)} até {formatProjetoDate(projeto.data_fim)}
              {projeto.local && <span style={{ color: 'var(--fg-3)' }}> · {projeto.local}</span>}
            </div>

            <div style={{ fontSize: 13, color: 'var(--fg-1)' }}>
              {projeto.itens_alocados}/{projeto.itens_total} unidades cobertas em{' '}
              {projeto.packing.length} {projeto.packing.length === 1 ? 'linha' : 'linhas'} de
              packing
            </div>
          </div>

          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            {canCheckin ? (
              <Btn onClick={() => setCheckinOpen(true)}>Check-in</Btn>
            ) : (
              <Btn
                onClick={() => setCheckoutOpen(true)}
                disabled={(!canCheckout && !canOverride) || pending}
              >
                {canCheckout ? 'Check-out' : canOverride ? 'Forçar saída' : 'Check-out bloqueado'}
              </Btn>
            )}
          </div>
        </div>
      </GlassCard>

      <CheckoutGatePanel gate={gate} />

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
        aria-label="Seções do Evento"
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
          maxWidth: '100%',
          overflowX: 'auto',
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

      {tab === 'packing' && <PackingTab projeto={projeto} onError={setError} onDone={refresh} />}
      {tab === 'alocacao' && (
        <AllocationTab projeto={projeto} onError={setError} onDone={refresh} />
      )}
      {tab === 'comercial' && <CommercialTab projeto={projeto} onDone={refresh} />}
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
          pendencias={retornoPendencias}
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

const gateColor = {
  pass: 'var(--accent-green)',
  warning: 'var(--accent-amber)',
  blocker: 'var(--accent-red)',
}

function CheckoutGatePanel({ gate }: { gate: ProjectDetail['checkout_gate'] }) {
  const mainIssue = gate.blockers[0] ?? gate.warnings[0] ?? null

  return (
    <GlassCard style={{ padding: 16, marginBottom: 18 }}>
      <div
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          gap: 14,
          alignItems: 'center',
        }}
      >
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 5,
            minWidth: 180,
            flex: '1 1 180px',
          }}
        >
          <div
            className="mono"
            style={{
              fontSize: 10,
              letterSpacing: 0.12,
              textTransform: 'uppercase',
              color: gate.canCheckout ? 'var(--accent-green)' : 'var(--accent-red)',
              fontWeight: 500,
            }}
          >
            Gate de saída
          </div>
          <div style={{ fontSize: 15, color: 'var(--fg-0)', fontWeight: 500 }}>
            {gate.canCheckout ? 'Pronto para check-out' : 'Check-out bloqueado'}
          </div>
          <div className="mono" style={{ fontSize: 11, color: 'var(--fg-3)' }}>
            {gate.resumo.qtdCoberta}/{gate.resumo.qtdNecessaria} cobertos · {gate.resumo.qtdPropria}{' '}
            próprios · {gate.resumo.qtdAvulsa} avulso
          </div>
        </div>

        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', minWidth: 0, flex: '2 1 360px' }}>
          {gate.checks.map((check) => (
            <div
              key={check.id}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 7,
                minHeight: 34,
                padding: '6px 9px',
                borderRadius: 8,
                border: '1px solid var(--glass-border)',
                background: 'var(--glass-bg)',
              }}
            >
              <StatusDot color={gateColor[check.severity]} size={7} />
              <span style={{ fontSize: 12, color: 'var(--fg-1)' }}>{check.label}</span>
              <span className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
                {check.detail}
              </span>
            </div>
          ))}
        </div>

        <div
          style={{
            minWidth: 170,
            flex: '1 1 180px',
            maxWidth: 260,
            color: mainIssue ? gateColor[mainIssue.severity] : 'var(--accent-green)',
            fontSize: 12,
            lineHeight: 1.35,
          }}
        >
          {mainIssue ? (
            <>
              {mainIssue.itemName && (
                <span style={{ color: 'var(--fg-1)' }}>{mainIssue.itemName}: </span>
              )}
              {mainIssue.message}
            </>
          ) : (
            'Sem bloqueios pendentes'
          )}
        </div>
      </div>

      {(gate.blockers.length > 1 || gate.warnings.length > 0) && (
        <div
          style={{
            display: 'flex',
            gap: 8,
            flexWrap: 'wrap',
            marginTop: 12,
            paddingTop: 12,
            borderTop: '1px solid var(--glass-border)',
          }}
        >
          {[...gate.blockers.slice(1, 4), ...gate.warnings.slice(0, 2)].map((item) => (
            <span
              key={item.id}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                padding: '4px 8px',
                borderRadius: 999,
                border: '1px solid var(--glass-border)',
                background: 'var(--glass-bg)',
                fontSize: 11,
                color: gateColor[item.severity],
              }}
            >
              <StatusDot color={gateColor[item.severity]} size={6} />
              {item.itemName ? `${item.itemName}: ${item.message}` : item.message}
            </span>
          ))}
        </div>
      )}
    </GlassCard>
  )
}
