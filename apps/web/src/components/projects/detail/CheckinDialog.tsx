'use client'

import { useEffect, useMemo, useState, useTransition } from 'react'
import { GhostBtn, PrimaryBtn, StatusDot } from '@/components/mmd/Primitives'
import type { MetodoScan } from '@/lib/types'
import { checkinProject, type CheckinItemInput } from '@/lib/actions/movimentacoes'

// Retorno de campo: Marco recebe os equipamentos de volta, atualiza desgaste
// e sinaliza quais precisam de manutenção. Slider global define o default
// pra todos, detalhes collapsible permitem ajuste por serial. O default do
// slider é a média arredondada do desgaste atual, não 3 fixo, porque isso
// respeita o histórico e evita que Marco "rebaixe" em bloco sem querer.

type SerialInput = {
  id: string
  codigo_interno: string
  item_nome: string
  desgaste_atual: number
}

type Props = {
  projetoId: string
  seriais: SerialInput[]
  onClose: () => void
  onSuccess: () => void
  onError: (msg: string) => void
}

const METODOS: { value: MetodoScan; label: string }[] = [
  { value: 'MANUAL', label: 'Manual' },
  { value: 'QRCODE', label: 'QR Code' },
  { value: 'RFID', label: 'RFID' },
]

type Override = { desgaste: number; needs_maintenance: boolean }

export function CheckinDialog({ projetoId, seriais, onClose, onSuccess, onError }: Props) {
  const defaultDesgaste = useMemo(() => {
    if (seriais.length === 0) return 3
    const avg = seriais.reduce((a, s) => a + s.desgaste_atual, 0) / seriais.length
    return Math.max(1, Math.min(5, Math.round(avg)))
  }, [seriais])

  const [metodo, setMetodo] = useState<MetodoScan>('MANUAL')
  const [globalDesgaste, setGlobalDesgaste] = useState(defaultDesgaste)
  const [overrides, setOverrides] = useState<Record<string, Override>>({})
  const [detailsOpen, setDetailsOpen] = useState(false)
  const [pending, startTransition] = useTransition()

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose])

  const resolve = (s: SerialInput): Override => {
    const ov = overrides[s.id]
    return {
      desgaste: ov?.desgaste ?? globalDesgaste,
      needs_maintenance: ov?.needs_maintenance ?? false,
    }
  }

  const toMaintain = seriais.filter((s) => resolve(s).needs_maintenance).length

  const confirm = () => {
    const items: CheckinItemInput[] = seriais.map((s) => {
      const r = resolve(s)
      return {
        serial_id: s.id,
        desgaste: r.desgaste,
        needs_maintenance: r.needs_maintenance,
      }
    })
    startTransition(async () => {
      const res = await checkinProject(projetoId, metodo, items)
      if (!res.ok) onError(res.error)
      else onSuccess()
    })
  }

  const updateOverride = (id: string, patch: Partial<Override>) => {
    setOverrides((prev) => {
      const current = prev[id] ?? { desgaste: globalDesgaste, needs_maintenance: false }
      return { ...prev, [id]: { ...current, ...patch } }
    })
  }

  return (
    <>
      <button
        type="button"
        aria-label="Fechar"
        onClick={onClose}
        style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(0, 0, 0, 0.45)',
          backdropFilter: 'blur(6px)',
          WebkitBackdropFilter: 'blur(6px)',
          border: 'none',
          cursor: 'pointer',
          zIndex: 50,
          animation: 'mmd-reveal 200ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
        }}
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label="Confirmar check-in"
        style={{
          position: 'fixed',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          width: 'min(560px, calc(100vw - 32px))',
          maxHeight: 'calc(100vh - 64px)',
          display: 'flex',
          flexDirection: 'column',
          background: 'var(--bg-0)',
          border: '1px solid var(--glass-border-strong)',
          borderRadius: 'var(--r-lg)',
          boxShadow: 'var(--glass-shadow-elevated)',
          zIndex: 51,
          overflow: 'hidden',
          animation: 'mmd-reveal 240ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
        }}
      >
        {/* Header */}
        <div
          style={{
            padding: '20px 22px 16px',
            borderBottom: '1px solid var(--glass-border)',
          }}
        >
          <div
            className="mono"
            style={{
              fontSize: 10,
              letterSpacing: 0.12,
              textTransform: 'uppercase',
              color: 'var(--accent-cyan)',
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              marginBottom: 6,
            }}
          >
            <StatusDot color="var(--accent-cyan)" size={6} />
            Check-in
          </div>
          <div style={{ fontSize: 18, fontWeight: 500, color: 'var(--fg-0)', letterSpacing: -0.3 }}>
            Recebendo {seriais.length} {seriais.length === 1 ? 'serial' : 'seriais'} do campo
          </div>
          <div
            className="mono"
            style={{ fontSize: 11, color: 'var(--fg-2)', marginTop: 4, letterSpacing: 0.06 }}
          >
            {toMaintain > 0
              ? `${toMaintain} para MANUTENÇÃO, ${seriais.length - toMaintain} para DISPONIVEL`
              : 'todos voltam para DISPONIVEL'}
          </div>
        </div>

        {/* Body */}
        <div
          style={{
            padding: '16px 22px',
            overflowY: 'auto',
            display: 'flex',
            flexDirection: 'column',
            gap: 18,
            flex: 1,
          }}
        >
          {/* Método */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <label
              className="mono"
              style={{
                fontSize: 10,
                letterSpacing: 0.12,
                textTransform: 'uppercase',
                color: 'var(--fg-3)',
                fontWeight: 500,
              }}
            >
              Método de scan
            </label>
            <div
              role="radiogroup"
              aria-label="Método de scan"
              style={{
                display: 'inline-flex',
                padding: 3,
                borderRadius: 10,
                background: 'var(--glass-bg)',
                border: '1px solid var(--glass-border)',
                width: 'fit-content',
              }}
            >
              {METODOS.map((m) => {
                const active = metodo === m.value
                return (
                  <button
                    key={m.value}
                    type="button"
                    role="radio"
                    aria-checked={active}
                    onClick={() => setMetodo(m.value)}
                    style={{
                      padding: '6px 14px',
                      borderRadius: 7,
                      border: 'none',
                      fontSize: 12,
                      fontFamily: 'inherit',
                      fontWeight: active ? 500 : 400,
                      cursor: 'pointer',
                      background: active ? 'var(--fg-0)' : 'transparent',
                      color: active ? 'var(--bg-0)' : 'var(--fg-1)',
                      transition: 'background var(--motion-fast), color var(--motion-fast)',
                    }}
                  >
                    {m.label}
                  </button>
                )
              })}
            </div>
          </div>

          {/* Slider global */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'baseline',
                gap: 12,
              }}
            >
              <label
                className="mono"
                style={{
                  fontSize: 10,
                  letterSpacing: 0.12,
                  textTransform: 'uppercase',
                  color: 'var(--fg-3)',
                  fontWeight: 500,
                }}
              >
                Desgaste geral
              </label>
              <div
                className="mono"
                style={{ fontSize: 11, color: 'var(--fg-3)', letterSpacing: 0.05 }}
              >
                default: média {defaultDesgaste}/5
              </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <input
                type="range"
                min={1}
                max={5}
                step={1}
                value={globalDesgaste}
                onChange={(e) => {
                  const v = Number(e.target.value)
                  setGlobalDesgaste(v)
                  // Reset overrides de desgaste quando o global muda,
                  // mantendo apenas needs_maintenance.
                  setOverrides((prev) => {
                    const next: Record<string, Override> = {}
                    for (const [k, ov] of Object.entries(prev)) {
                      if (ov.needs_maintenance) {
                        next[k] = { desgaste: ov.desgaste, needs_maintenance: true }
                      }
                    }
                    return next
                  })
                }}
                aria-label="Desgaste geral"
                style={{ flex: 1, accentColor: 'var(--accent-cyan)' }}
              />
              <DesgasteBadge n={globalDesgaste} />
            </div>
          </div>

          {/* Overrides por serial */}
          <details
            open={detailsOpen}
            onToggle={(e) => setDetailsOpen((e.target as HTMLDetailsElement).open)}
            style={{
              border: '1px solid var(--glass-border)',
              borderRadius: 'var(--r-sm)',
              background: 'var(--glass-bg)',
            }}
          >
            <summary
              style={{
                padding: '10px 14px',
                cursor: 'pointer',
                fontSize: 12,
                color: 'var(--fg-1)',
                listStyle: 'none',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                gap: 8,
              }}
            >
              <span className="mono" style={{ letterSpacing: 0.06 }}>
                Ajustar por serial ({seriais.length})
              </span>
              <span
                className="mono"
                style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.05 }}
              >
                {detailsOpen ? 'fechar' : 'abrir'}
              </span>
            </summary>

            <div
              style={{
                maxHeight: 260,
                overflowY: 'auto',
                borderTop: '1px solid var(--glass-border)',
              }}
            >
              {seriais.map((s) => {
                const r = resolve(s)
                return (
                  <div
                    key={s.id}
                    style={{
                      padding: '10px 14px',
                      borderBottom: '1px solid var(--glass-border)',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: 8,
                    }}
                  >
                    <div
                      style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'baseline',
                        gap: 8,
                        flexWrap: 'wrap',
                      }}
                    >
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 2, minWidth: 0 }}>
                        <span
                          className="mono"
                          style={{ fontSize: 12, color: 'var(--fg-0)', letterSpacing: 0.05 }}
                        >
                          {s.codigo_interno}
                        </span>
                        <span style={{ fontSize: 11, color: 'var(--fg-3)' }}>
                          {s.item_nome}
                        </span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span
                          className="mono"
                          style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.05 }}
                        >
                          era {s.desgaste_atual}/5
                        </span>
                        <DesgasteBadge n={r.desgaste} />
                      </div>
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <input
                        type="range"
                        min={1}
                        max={5}
                        step={1}
                        value={r.desgaste}
                        onChange={(e) =>
                          updateOverride(s.id, { desgaste: Number(e.target.value) })
                        }
                        aria-label={`Desgaste ${s.codigo_interno}`}
                        style={{ flex: 1, accentColor: 'var(--accent-cyan)' }}
                      />
                      <label
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 6,
                          fontSize: 11,
                          color: r.needs_maintenance ? 'var(--accent-amber)' : 'var(--fg-2)',
                          cursor: 'pointer',
                          userSelect: 'none',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        <input
                          type="checkbox"
                          checked={r.needs_maintenance}
                          onChange={(e) =>
                            updateOverride(s.id, { needs_maintenance: e.target.checked })
                          }
                          style={{ accentColor: 'var(--accent-amber)' }}
                        />
                        manutenção
                      </label>
                    </div>
                  </div>
                )
              })}
            </div>
          </details>
        </div>

        {/* Footer */}
        <div
          style={{
            padding: '14px 22px',
            borderTop: '1px solid var(--glass-border)',
            display: 'flex',
            justifyContent: 'flex-end',
            gap: 10,
            background: 'var(--glass-bg)',
          }}
        >
          <GhostBtn onClick={onClose} disabled={pending}>
            Cancelar
          </GhostBtn>
          <PrimaryBtn onClick={confirm} disabled={pending || seriais.length === 0}>
            {pending ? 'Recebendo…' : `Confirmar retorno (${seriais.length})`}
          </PrimaryBtn>
        </div>
      </div>
    </>
  )
}

function DesgasteBadge({ n }: { n: number }) {
  const color =
    n >= 4 ? 'var(--accent-green)' : n === 3 ? 'var(--accent-amber)' : 'var(--accent-red)'
  return (
    <span
      className="mono"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        minWidth: 36,
        fontSize: 11,
        padding: '2px 8px',
        borderRadius: 4,
        background: `color-mix(in oklch, ${color} 14%, transparent)`,
        border: `1px solid color-mix(in oklch, ${color} 35%, transparent)`,
        color,
        letterSpacing: 0.05,
      }}
    >
      {n}/5
    </span>
  )
}
