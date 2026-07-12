'use client'

import { useMemo, useRef, useState, useTransition } from 'react'
import { createPortal } from 'react-dom'
import { Btn, StatusDot } from '@/components/mmd/Primitives'
import { useEscapeKey } from '@/hooks/useEscapeKey'
import { useFocusTrap } from '@/hooks/useFocusTrap'
import { useReturnFocus } from '@/hooks/useReturnFocus'
import {
  type ReturnOutcome,
  type ReturnResolutionAction,
} from '@/lib/return-resolution-core'
import type { MetodoScan, StatusSerial } from '@/lib/types'
import {
  checkinProject,
  resolveReturnPending,
  type CheckinItemInput,
} from '@/lib/actions/movimentacoes'
import type { ReturnPendingResolution } from '@/lib/data/project-detail'

type SerialInput = {
  id: string
  codigo_interno: string
  item_nome: string
  desgaste_atual: number
  status: StatusSerial
}

type Props = {
  projetoId: string
  seriais: SerialInput[]
  pendencias: ReturnPendingResolution[]
  onClose: () => void
  onSuccess: () => void
  onError: (msg: string) => void
}

const METODOS: { value: MetodoScan; label: string }[] = [
  { value: 'MANUAL', label: 'Manual' },
  { value: 'QRCODE', label: 'QR Code' },
  { value: 'RFID', label: 'RFID' },
]

const OUTCOMES: { value: ReturnOutcome; label: string; color: string }[] = [
  { value: 'OK', label: 'OK', color: 'var(--accent-green)' },
  { value: 'PROBLEMA', label: 'Problema', color: 'var(--accent-amber)' },
  { value: 'NAO_VOLTOU', label: 'Não voltou', color: 'var(--accent-red)' },
]

const RESOLUTION_ACTIONS: {
  value: ReturnResolutionAction
  label: string
  color: string
  needsObservation: boolean
}[] = [
  { value: 'ENCONTRADA', label: 'Encontrada', color: 'var(--accent-green)', needsObservation: false },
  { value: 'MANUTENCAO', label: 'Manutenção', color: 'var(--accent-amber)', needsObservation: true },
  { value: 'BAIXA', label: 'Baixa', color: 'var(--accent-red)', needsObservation: false },
  { value: 'COBRANCA', label: 'Cobrança', color: 'var(--accent-cyan)', needsObservation: true },
]

type Override = { desgaste: number; resultado: ReturnOutcome; observacao: string }
type ResolutionDraft = { observacao: string }

export function CheckinDialog({
  projetoId,
  seriais,
  pendencias,
  onClose,
  onSuccess,
  onError,
}: Props) {
  const seriaisEmCampo = useMemo(
    () => seriais.filter((serial) => serial.status === 'EM_CAMPO'),
    [seriais],
  )
  const pendenciasAbertas = useMemo(
    () => pendencias.filter((pendencia) => pendencia.status === 'ABERTA'),
    [pendencias],
  )

  const defaultDesgaste = useMemo(() => {
    if (seriaisEmCampo.length === 0) return 3
    const avg = seriaisEmCampo.reduce((a, s) => a + s.desgaste_atual, 0) / seriaisEmCampo.length
    return Math.max(1, Math.min(5, Math.round(avg)))
  }, [seriaisEmCampo])

  const [metodo, setMetodo] = useState<MetodoScan>('MANUAL')
  const [globalDesgaste, setGlobalDesgaste] = useState(defaultDesgaste)
  const [overrides, setOverrides] = useState<Record<string, Override>>({})
  const [resolutionDrafts, setResolutionDrafts] = useState<Record<string, ResolutionDraft>>({})
  const [pending, startTransition] = useTransition()

  const dialogRef = useRef<HTMLDivElement | null>(null)
  useEscapeKey(true, onClose)
  useReturnFocus(true)
  useFocusTrap(dialogRef, true)

  const resolveSerial = (s: SerialInput): Override => {
    const ov = overrides[s.id]
    return {
      desgaste: ov?.desgaste ?? globalDesgaste,
      resultado: ov?.resultado ?? 'OK',
      observacao: ov?.observacao ?? '',
    }
  }

  const counts = seriaisEmCampo.reduce(
    (acc, serial) => {
      const outcome = resolveSerial(serial).resultado
      if (outcome === 'OK') acc.ok += 1
      else if (outcome === 'PROBLEMA') acc.problema += 1
      else acc.pendente += 1
      acc.total += 1
      return acc
    },
    { ok: 0, problema: 0, pendente: 0, total: 0 },
  )

  const missingProblemObservation = seriaisEmCampo.some((serial) => {
    const resolved = resolveSerial(serial)
    return resolved.resultado === 'PROBLEMA' && resolved.observacao.trim().length < 3
  })

  const confirm = () => {
    const items: CheckinItemInput[] = seriaisEmCampo.map((s) => {
      const r = resolveSerial(s)
      return {
        serial_id: s.id,
        desgaste: r.desgaste,
        resultado: r.resultado,
        observacao: r.observacao,
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
      const current = prev[id] ?? { desgaste: globalDesgaste, resultado: 'OK', observacao: '' }
      return { ...prev, [id]: { ...current, ...patch } }
    })
  }

  const updateResolutionDraft = (id: string, observacao: string) => {
    setResolutionDrafts((prev) => ({ ...prev, [id]: { observacao } }))
  }

  const resolvePending = (pendenciaId: string, acao: ReturnResolutionAction) => {
    const observacao = resolutionDrafts[pendenciaId]?.observacao ?? ''
    startTransition(async () => {
      const res = await resolveReturnPending(pendenciaId, acao, observacao)
      if (!res.ok) onError(res.error)
      else onSuccess()
    })
  }

  if (typeof document === 'undefined') return null

  return createPortal(
    <>
      <button
        type="button"
        aria-label="Fechar"
        onClick={onClose}
        style={{
          position: 'fixed',
          inset: 0,
          background: 'var(--dialog-overlay)',
          backdropFilter: 'blur(6px)',
          WebkitBackdropFilter: 'blur(6px)',
          border: 'none',
          cursor: 'pointer',
          zIndex: 1000,
          animation: 'mmd-reveal 200ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
        }}
      />
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-label="Conferência de retorno"
        tabIndex={-1}
        style={{
          position: 'fixed',
          inset: 0,
          margin: 'auto',
          width: 'min(720px, calc(100vw - 32px))',
          maxHeight: 'calc(100vh - 64px)',
          display: 'flex',
          flexDirection: 'column',
          background: 'var(--bg-0)',
          border: '1px solid var(--glass-border-strong)',
          borderRadius: 'var(--r-lg)',
          boxShadow: 'var(--glass-shadow-elevated)',
          zIndex: 1001,
          overflow: 'hidden',
          animation: 'mmd-reveal 240ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
          outline: 'none',
        }}
      >
        <div style={{ padding: '20px 22px 16px', borderBottom: '1px solid var(--glass-border)' }}>
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
          <div style={{ fontSize: 20, fontWeight: 500, color: 'var(--fg-0)' }}>
            Conferência de retorno
          </div>
          <div className="mono" style={{ fontSize: 11, color: 'var(--fg-2)', marginTop: 4 }}>
            {seriaisEmCampo.length} em campo · {pendenciasAbertas.length} pendente
            {pendenciasAbertas.length === 1 ? '' : 's'} de resolução
          </div>
        </div>

        <div
          style={{
            padding: '16px 22px',
            overflowY: 'auto',
            display: 'flex',
            flexDirection: 'column',
            gap: 16,
            flex: 1,
          }}
        >
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(128px, 1fr))',
              gap: 10,
            }}
          >
            <CountTile label="OK" value={counts.ok} color="var(--accent-green)" />
            <CountTile label="Manutenção" value={counts.problema} color="var(--accent-amber)" />
            <CountTile label="Pendente" value={counts.pendente + pendenciasAbertas.length} color="var(--accent-red)" />
            <CountTile label="Total" value={counts.total} color="var(--fg-2)" />
          </div>

          {(counts.pendente > 0 || pendenciasAbertas.length > 0) && (
            <div
              role="alert"
              style={{
                padding: '12px 14px',
                borderRadius: 'var(--r-sm)',
                border: '1px solid color-mix(in oklch, var(--accent-red) 32%, transparent)',
                background: 'color-mix(in oklch, var(--accent-red) 8%, transparent)',
                color: 'var(--fg-0)',
                fontSize: 13,
              }}
            >
              <strong style={{ color: 'var(--accent-red)', fontWeight: 500 }}>
                Existem unidades pendentes de resolução.
              </strong>{' '}
              O Evento só fecha quando as pendências forem resolvidas ou registradas.
            </div>
          )}

          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <span
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
            </span>
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

          {seriaisEmCampo.length > 0 && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
                <span
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
                </span>
                <span className="mono" style={{ fontSize: 11, color: 'var(--fg-3)' }}>
                  default: média {defaultDesgaste}/5
                </span>
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
                    setOverrides((prev) => {
                      const next: Record<string, Override> = {}
                      for (const [k, ov] of Object.entries(prev)) {
                        if (ov.resultado !== 'OK' || ov.observacao.trim().length > 0) {
                          next[k] = { ...ov, desgaste: v }
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
          )}

          <section
            aria-label="Unidades que saíram"
            style={{
              border: '1px solid var(--glass-border)',
              borderRadius: 'var(--r-sm)',
              background: 'var(--glass-bg)',
              overflow: 'hidden',
            }}
          >
            <SectionHeader label={`Unidades que saíram (${seriaisEmCampo.length})`} />
            {seriaisEmCampo.length === 0 ? (
              <EmptyLine text="Não há unidades em campo para receber agora." />
            ) : (
              seriaisEmCampo.map((serial) => {
                const resolved = resolveSerial(serial)
                return (
                  <div
                    key={serial.id}
                    style={{
                      padding: '12px 14px',
                      borderTop: '1px solid var(--glass-border)',
                      display: 'grid',
                      gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
                      gap: 12,
                      alignItems: 'start',
                    }}
                  >
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 3, minWidth: 0 }}>
                      <span className="mono" style={{ fontSize: 12, color: 'var(--fg-0)' }}>
                        {serial.codigo_interno}
                      </span>
                      <span style={{ fontSize: 12, color: 'var(--fg-2)' }}>{serial.item_nome}</span>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                      <span className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
                        era {serial.desgaste_atual}/5
                      </span>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <input
                          type="range"
                          min={1}
                          max={5}
                          step={1}
                          value={resolved.desgaste}
                          onChange={(e) =>
                            updateOverride(serial.id, { desgaste: Number(e.target.value) })
                          }
                          aria-label={`Desgaste ${serial.codigo_interno}`}
                          style={{ width: 84, accentColor: 'var(--accent-cyan)' }}
                          disabled={resolved.resultado === 'NAO_VOLTOU'}
                        />
                        <DesgasteBadge n={resolved.desgaste} />
                      </div>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                        {OUTCOMES.map((outcome) => (
                          <OutcomeButton
                            key={outcome.value}
                            label={outcome.label}
                            color={outcome.color}
                            active={resolved.resultado === outcome.value}
                            onClick={() => updateOverride(serial.id, { resultado: outcome.value })}
                          />
                        ))}
                      </div>
                      {resolved.resultado === 'PROBLEMA' && (
                        <textarea
                          value={resolved.observacao}
                          onChange={(e) =>
                            updateOverride(serial.id, { observacao: e.target.value })
                          }
                          placeholder="OBS do Evento: problema identificado"
                          aria-label={`Observação de problema ${serial.codigo_interno}`}
                          rows={2}
                          style={textareaStyle}
                        />
                      )}
                      {resolved.resultado === 'NAO_VOLTOU' && (
                        <textarea
                          value={resolved.observacao}
                          onChange={(e) =>
                            updateOverride(serial.id, { observacao: e.target.value })
                          }
                          placeholder="OBS opcional: última informação sobre a unidade"
                          aria-label={`Observação de pendência ${serial.codigo_interno}`}
                          rows={2}
                          style={textareaStyle}
                        />
                      )}
                    </div>
                  </div>
                )
              })
            )}
          </section>

          <section
            aria-label="Pendências de resolução"
            style={{
              border: '1px solid color-mix(in oklch, var(--accent-red) 25%, var(--glass-border))',
              borderRadius: 'var(--r-sm)',
              background: 'color-mix(in oklch, var(--accent-red) 5%, var(--glass-bg))',
              overflow: 'hidden',
            }}
          >
            <SectionHeader label={`Pendências de resolução (${pendenciasAbertas.length})`} />
            {pendenciasAbertas.length === 0 ? (
              <EmptyLine text="Nenhuma pendência aberta." />
            ) : (
              pendenciasAbertas.map((pendencia) => {
                const draft = resolutionDrafts[pendencia.id]?.observacao ?? ''
                return (
                  <div
                    key={pendencia.id}
                    style={{
                      padding: '12px 14px',
                      borderTop: '1px solid var(--glass-border)',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: 10,
                    }}
                  >
                    <div
                      style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        gap: 12,
                        flexWrap: 'wrap',
                      }}
                    >
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
                        <span className="mono" style={{ fontSize: 12, color: 'var(--fg-0)' }}>
                          {pendencia.codigo_interno}
                        </span>
                        <span style={{ fontSize: 12, color: 'var(--fg-2)' }}>
                          {pendencia.item_nome}
                        </span>
                        {pendencia.observacao && (
                          <span style={{ fontSize: 12, color: 'var(--fg-3)' }}>
                            {pendencia.observacao}
                          </span>
                        )}
                      </div>
                      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'start' }}>
                        {RESOLUTION_ACTIONS.map((action) => (
                          <OutcomeButton
                            key={action.value}
                            label={action.label}
                            color={action.color}
                            active={false}
                            onClick={() => resolvePending(pendencia.id, action.value)}
                            disabled={
                              pending ||
                              (action.needsObservation && draft.trim().length < 3)
                            }
                          />
                        ))}
                      </div>
                    </div>
                    <textarea
                      value={draft}
                      onChange={(e) => updateResolutionDraft(pendencia.id, e.target.value)}
                      placeholder="Observação da resolução, obrigatória para manutenção ou cobrança"
                      aria-label={`Observação da resolução ${pendencia.codigo_interno}`}
                      rows={2}
                      style={textareaStyle}
                    />
                  </div>
                )
              })
            )}
          </section>
        </div>

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
          <Btn variant="ghost" onClick={onClose} disabled={pending}>
            Cancelar
          </Btn>
          <Btn
            onClick={confirm}
            disabled={pending || seriaisEmCampo.length === 0 || missingProblemObservation}
          >
            {pending
              ? 'Recebendo'
              : `Confirmar retorno (${counts.total})`}
          </Btn>
        </div>
      </div>
    </>,
    document.body,
  )
}

function CountTile({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div
      style={{
        padding: '12px 10px',
        borderRadius: 'var(--r-sm)',
        background: `color-mix(in oklch, ${color} 9%, var(--glass-bg))`,
        border: `1px solid color-mix(in oklch, ${color} 25%, var(--glass-border))`,
        textAlign: 'center',
      }}
    >
      <div className="mono" style={{ fontSize: 10, color, textTransform: 'uppercase' }}>
        {label}
      </div>
      <div style={{ fontSize: 24, fontWeight: 600, color: 'var(--fg-0)', lineHeight: 1.1 }}>
        {value}
      </div>
      <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
        {value === 1 ? 'unidade' : 'unidades'}
      </div>
    </div>
  )
}

function SectionHeader({ label }: { label: string }) {
  return (
    <div
      className="mono"
      style={{
        padding: '10px 14px',
        fontSize: 10,
        letterSpacing: 0.12,
        textTransform: 'uppercase',
        color: 'var(--fg-3)',
      }}
    >
      {label}
    </div>
  )
}

function EmptyLine({ text }: { text: string }) {
  return (
    <div
      style={{
        padding: '14px',
        borderTop: '1px solid var(--glass-border)',
        color: 'var(--fg-3)',
        fontSize: 13,
      }}
    >
      {text}
    </div>
  )
}

function OutcomeButton({
  label,
  color,
  active,
  disabled,
  onClick,
}: {
  label: string
  color: string
  active: boolean
  disabled?: boolean
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      style={{
        padding: '6px 10px',
        borderRadius: 7,
        border: `1px solid color-mix(in oklch, ${color} 34%, var(--glass-border))`,
        background: active ? color : 'var(--bg-0)',
        color: active ? 'var(--bg-0)' : color,
        fontSize: 11,
        fontFamily: 'inherit',
        fontWeight: 500,
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.5 : 1,
      }}
    >
      {label}
    </button>
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
      }}
    >
      {n}/5
    </span>
  )
}

const textareaStyle = {
  width: '100%',
  resize: 'vertical',
  minHeight: 50,
  padding: '9px 10px',
  borderRadius: 8,
  border: '1px solid var(--glass-border)',
  background: 'var(--bg-0)',
  color: 'var(--fg-0)',
  fontFamily: 'inherit',
  fontSize: 12,
  outline: 'none',
} as const
