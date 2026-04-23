'use client'

import { useEffect, useState, useTransition } from 'react'
import { GhostBtn, PrimaryBtn, StatusDot } from '@/components/mmd/Primitives'
import type { ProjectDetail } from '@/lib/data/project-detail'
import type { MetodoScan } from '@/lib/types'
import { checkoutProject } from '@/lib/actions/movimentacoes'

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
  const [pending, startTransition] = useTransition()

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose])

  const totalSeriais = projeto.packing.reduce((a, p) => a + p.seriais_alocados.length, 0)

  const confirm = () => {
    startTransition(async () => {
      const res = await checkoutProject(projeto.id, metodo)
      if (!res.ok) onError(res.error)
      else onSuccess()
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
        aria-label="Confirmar check-out"
        style={{
          position: 'fixed',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          width: 'min(520px, calc(100vw - 32px))',
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
          }}
        >
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
              Seriais
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
              {projeto.packing.map((p) => (
                <div key={p.id} style={{ padding: '4px 0', borderBottom: '1px solid var(--glass-border)' }}>
                  <div style={{ fontSize: 12, color: 'var(--fg-1)', marginBottom: 3 }}>
                    {p.item_nome}{' '}
                    <span className="mono" style={{ color: 'var(--fg-3)' }}>
                      ({p.seriais_alocados.length}/{p.qtd_necessaria})
                    </span>
                  </div>
                  <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                    {p.seriais_alocados.map((s) => (
                      <span
                        key={s.id}
                        className="mono"
                        style={{
                          fontSize: 10,
                          padding: '1px 6px',
                          borderRadius: 3,
                          background: 'var(--bg-0)',
                          border: '1px solid var(--glass-border)',
                          color: 'var(--fg-1)',
                        }}
                      >
                        {s.codigo_interno}
                      </span>
                    ))}
                  </div>
                </div>
              ))}
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
          }}
        >
          <GhostBtn onClick={onClose} disabled={pending}>
            Cancelar
          </GhostBtn>
          <PrimaryBtn onClick={confirm} disabled={pending}>
            {pending ? 'Saindo…' : `Confirmar saída (${totalSeriais})`}
          </PrimaryBtn>
        </div>
      </div>
    </>
  )
}
