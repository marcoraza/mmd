'use client'

import { useRef, useState, useTransition } from 'react'
import { createPortal } from 'react-dom'
import { Btn, StatusDot } from '@/components/mmd/Primitives'
import { useEscapeKey } from '@/hooks/useEscapeKey'
import { useFocusTrap } from '@/hooks/useFocusTrap'
import { useReturnFocus } from '@/hooks/useReturnFocus'
import type { ProjectDetail } from '@/lib/data/project-detail'
import type { MetodoScan } from '@/lib/types'
import { checkoutProject } from '@/lib/actions/movimentacoes'
import { buildCheckoutExecutionPlan } from '@/lib/checkout-execution-core'

type Props = {
  projeto: ProjectDetail
  onClose: () => void
  onSuccess: () => void
  onError: (msg: string) => void
}

const METODOS: { value: MetodoScan; label: string }[] = [
  { value: 'MANUAL', label: 'Manual' },
  { value: 'QRCODE', label: 'QR Code' },
  { value: 'RFID', label: 'RFID' },
]

export function CheckoutDialog({ projeto, onClose, onSuccess, onError }: Props) {
  const [metodo, setMetodo] = useState<MetodoScan>('MANUAL')
  const [overrideReason, setOverrideReason] = useState('')
  const [pending, startTransition] = useTransition()
  const gate = projeto.checkout_gate
  const executionPlan = buildCheckoutExecutionPlan({
    gate,
    packing: projeto.packing,
    metodo,
    operador: 'sessão autenticada',
    now: null,
  })
  const needsOverride = !gate.canCheckout
  const overrideReady = overrideReason.trim().length >= 10
  const confirmDisabled = needsOverride
    ? pending || !executionPlan.canExecuteWithOverride || !overrideReady
    : pending || !executionPlan.canExecuteStrict
  const executionLineById = new Map(executionPlan.lines.map((line) => [line.id, line]))

  const dialogRef = useRef<HTMLDivElement | null>(null)
  useEscapeKey(true, onClose)
  // useReturnFocus antes de useFocusTrap: ordem importa porque o trap move
  // foco pra dentro do dialog, e o snapshot precisa capturar o trigger antes
  // disso. Effects rodam na ordem de declaração.
  useReturnFocus(true)
  useFocusTrap(dialogRef, true)

  const totalSeriais = executionPlan.ownSerialCount
  const totalAvulso = executionPlan.externalRentalCount

  const confirm = () => {
    if (confirmDisabled) return
    startTransition(async () => {
      const res = await checkoutProject(projeto.id, metodo, {
        overrideReason: needsOverride ? overrideReason : undefined,
      })
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
          zIndex: 50,
          animation: 'mmd-reveal 200ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
        }}
      />
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-label="Confirmar check-out"
        tabIndex={-1}
        style={{
          position: 'fixed',
          inset: 16,
          margin: 'auto',
          width: 'min(560px, calc(100vw - 32px))',
          height: 'fit-content',
          maxHeight: 'calc(100dvh - 32px)',
          display: 'flex',
          flexDirection: 'column',
          background: 'var(--bg-0)',
          border: '1px solid var(--glass-border-strong)',
          borderRadius: 'var(--r-lg)',
          boxShadow: 'var(--glass-shadow-elevated)',
          zIndex: 51,
          overflow: 'hidden',
          animation: 'mmd-reveal 240ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
          outline: 'none',
        }}
      >
        {/* Header */}
        <div
          style={{
            padding: '20px 22px 16px',
            borderBottom: '1px solid var(--glass-border)',
            flexShrink: 0,
          }}
        >
          <div
            className="mono"
            style={{
              fontSize: 10,
              letterSpacing: 0.12,
              textTransform: 'uppercase',
              color: 'var(--accent-violet)',
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              marginBottom: 6,
            }}
          >
            <StatusDot color="var(--accent-violet)" size={6} />
            Check-out
          </div>
          <div style={{ fontSize: 18, fontWeight: 500, color: 'var(--fg-0)', letterSpacing: -0.3 }}>
            {projeto.nome}
          </div>
          <div
            className="mono"
            style={{ fontSize: 11, color: 'var(--fg-2)', marginTop: 4, letterSpacing: 0.06 }}
          >
            {totalSeriais} seriais vão para EM_CAMPO
            {totalAvulso > 0 && ` · ${totalAvulso} cobertos por aluguel avulso`}
          </div>
        </div>

        {/* Body */}
        <div
          style={{
            padding: '16px 22px',
            overflowY: 'auto',
            display: 'flex',
            flexDirection: 'column',
            gap: 16,
            flex: 1,
            minHeight: 0,
          }}
        >
          <div
            style={{
              border: '1px solid var(--glass-border)',
              borderRadius: 'var(--r-sm)',
              background: 'var(--glass-bg)',
              padding: 12,
              display: 'flex',
              flexDirection: 'column',
              gap: 10,
            }}
          >
            <div
              className="mono"
              style={{
                fontSize: 10,
                letterSpacing: 0.12,
                textTransform: 'uppercase',
                color: 'var(--fg-3)',
                fontWeight: 500,
              }}
            >
              Conferência de saída
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {[
                ['Próprios', executionPlan.ownSerialCount, 'var(--fg-1)'],
                ['Avulso', executionPlan.externalRentalCount, 'var(--accent-cyan)'],
                [
                  'Faltando',
                  executionPlan.missingCount,
                  executionPlan.missingCount > 0 ? 'var(--accent-red)' : 'var(--fg-1)',
                ],
                [
                  'Extra',
                  executionPlan.extraCount,
                  executionPlan.extraCount > 0 ? 'var(--accent-amber)' : 'var(--fg-1)',
                ],
                ['Método', metodo === 'QRCODE' ? 'QR Code' : metodo, 'var(--fg-1)'],
                ['Operador', 'sessão autenticada', 'var(--fg-1)'],
              ].map(([label, value, color]) => (
                <span
                  key={label}
                  className="mono"
                  style={{
                    fontSize: 10,
                    padding: '4px 7px',
                    borderRadius: 6,
                    background: 'var(--bg-0)',
                    border: '1px solid var(--glass-border)',
                    color: color as string,
                    whiteSpace: 'nowrap',
                  }}
                >
                  {label} {value}
                </span>
              ))}
            </div>
            {(executionPlan.hardBlockers.length > 0 || executionPlan.warnings.length > 0) && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                {executionPlan.hardBlockers.slice(0, 3).map((blocker) => (
                  <div key={blocker.id} style={{ fontSize: 12, color: 'var(--accent-red)' }}>
                    {blocker.itemName && <span>{blocker.itemName}: </span>}
                    {blocker.message}
                  </div>
                ))}
                {executionPlan.warnings.slice(0, 3).map((warning) => (
                  <div key={warning.id} style={{ fontSize: 12, color: 'var(--accent-amber)' }}>
                    {warning.itemName && <span>{warning.itemName}: </span>}
                    {warning.message}
                  </div>
                ))}
              </div>
            )}
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {needsOverride && (
              <div
                style={{
                  border: '1px solid color-mix(in oklch, var(--accent-red) 32%, transparent)',
                  borderRadius: 'var(--r-sm)',
                  background: 'color-mix(in oklch, var(--accent-red) 9%, transparent)',
                  padding: 12,
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 10,
                }}
              >
                <div
                  className="mono"
                  style={{
                    fontSize: 10,
                    letterSpacing: 0.12,
                    textTransform: 'uppercase',
                    color: 'var(--accent-red)',
                    fontWeight: 500,
                  }}
                >
                  Override admin
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  {gate.blockers.slice(0, 4).map((blocker) => (
                    <div key={blocker.id} style={{ fontSize: 12, color: 'var(--fg-1)' }}>
                      {blocker.itemName && (
                        <span style={{ color: 'var(--fg-0)' }}>{blocker.itemName}: </span>
                      )}
                      {blocker.message}
                    </div>
                  ))}
                </div>
                <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  <span
                    className="mono"
                    style={{
                      fontSize: 10,
                      letterSpacing: 0.12,
                      textTransform: 'uppercase',
                      color: 'var(--fg-3)',
                    }}
                  >
                    Motivo do override
                  </span>
                  <textarea
                    value={overrideReason}
                    onChange={(event) => setOverrideReason(event.target.value)}
                    placeholder="Ex: parceiro confirmou retirada e Marcelo autorizou saída parcial"
                    rows={3}
                    style={{
                      width: '100%',
                      resize: 'vertical',
                      borderRadius: 8,
                      border: '1px solid var(--glass-border)',
                      background: 'var(--bg-0)',
                      color: 'var(--fg-0)',
                      padding: '9px 10px',
                      font: 'inherit',
                      fontSize: 13,
                      outline: 'none',
                    }}
                  />
                </label>
                <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
                  Obrigatório para auditoria. Mínimo de 10 caracteres.
                </div>
              </div>
            )}

            {/* Não usa <label>: o radiogroup tem aria-label próprio. */}
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

          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div
              className="mono"
              style={{
                fontSize: 10,
                letterSpacing: 0.12,
                textTransform: 'uppercase',
                color: 'var(--fg-3)',
                fontWeight: 500,
              }}
            >
              Cobertura e seriais
            </div>
            <div
              style={{
                maxHeight: 220,
                overflowY: 'auto',
                border: '1px solid var(--glass-border)',
                borderRadius: 'var(--r-sm)',
                padding: '6px 10px',
                background: 'var(--glass-bg)',
              }}
            >
              {projeto.packing.map((p) => {
                const executionLine = executionLineById.get(p.id)
                return (
                  <div
                    key={p.id}
                    style={{ padding: '4px 0', borderBottom: '1px solid var(--glass-border)' }}
                  >
                    <div style={{ fontSize: 12, color: 'var(--fg-1)', marginBottom: 3 }}>
                      {p.item_nome}{' '}
                      <span className="mono" style={{ color: 'var(--fg-3)' }}>
                        ({p.qtd_coberta}/{p.qtd_necessaria})
                      </span>
                    </div>
                    <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                      {p.qtd_faltante > 0 && (
                        <span
                          className="mono"
                          style={{
                            fontSize: 10,
                            padding: '1px 6px',
                            borderRadius: 3,
                            background: 'color-mix(in oklch, var(--accent-red) 9%, transparent)',
                            border:
                              '1px solid color-mix(in oklch, var(--accent-red) 35%, transparent)',
                            color: 'var(--accent-red)',
                          }}
                        >
                          faltam {p.qtd_faltante}
                        </span>
                      )}
                      {(executionLine?.qtd_extra ?? 0) > 0 && (
                        <span
                          className="mono"
                          style={{
                            fontSize: 10,
                            padding: '1px 6px',
                            borderRadius: 3,
                            background: 'color-mix(in oklch, var(--accent-amber) 10%, transparent)',
                            border:
                              '1px solid color-mix(in oklch, var(--accent-amber) 35%, transparent)',
                            color: 'var(--accent-amber)',
                          }}
                        >
                          extra {executionLine?.qtd_extra}
                        </span>
                      )}
                      {p.seriais_alocados.map((s) => {
                        const invalid = s.status !== 'DISPONIVEL'
                        return (
                          <span
                            key={s.id}
                            className="mono"
                            style={{
                              fontSize: 10,
                              padding: '1px 6px',
                              borderRadius: 3,
                              background: invalid
                                ? 'color-mix(in oklch, var(--accent-red) 9%, transparent)'
                                : 'var(--bg-0)',
                              border: invalid
                                ? '1px solid color-mix(in oklch, var(--accent-red) 35%, transparent)'
                                : '1px solid var(--glass-border)',
                              color: invalid ? 'var(--accent-red)' : 'var(--fg-1)',
                            }}
                          >
                            {s.codigo_interno}
                            {invalid && ` · ${s.status}`}
                          </span>
                        )
                      })}
                      {p.alugueis_avulsos.map((rental) => (
                        <span
                          key={rental.id}
                          className="mono"
                          style={{
                            fontSize: 10,
                            padding: '1px 6px',
                            borderRadius: 3,
                            background: 'color-mix(in oklch, var(--accent-cyan) 9%, transparent)',
                            border:
                              '1px solid color-mix(in oklch, var(--accent-cyan) 35%, transparent)',
                            color: 'var(--accent-cyan)',
                          }}
                        >
                          {rental.quantidade} avulso · {rental.fornecedor}
                        </span>
                      ))}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
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
            flexShrink: 0,
          }}
        >
          <Btn variant="ghost" onClick={onClose} disabled={pending}>
            Cancelar
          </Btn>
          <Btn onClick={confirm} disabled={confirmDisabled}>
            {pending
              ? 'Saindo'
              : needsOverride
                ? `Forçar saída (${totalSeriais})`
                : `Confirmar saída (${totalSeriais})`}
          </Btn>
        </div>
      </div>
    </>,
    document.body,
  )
}
