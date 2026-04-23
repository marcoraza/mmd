'use client'

import { useEffect } from 'react'
import { Icons } from '@/components/mmd/Icons'
import { GhostBtn, PrimaryBtn, StatusDot } from '@/components/mmd/Primitives'
import {
  CICLO_LABEL,
  SITUACAO_COLOR,
  SITUACAO_LABEL,
  formatBRL,
} from '@/components/catalog/helpers'
import type { SerialRow } from '@/lib/data/items'
import { formatTimestamp } from './helpers'

type Props = {
  serial: SerialRow | null
  itemName: string
  onClose: () => void
}

export function UnitDrawer({ serial, itemName, onClose }: Props) {
  useEffect(() => {
    if (!serial) return
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [serial, onClose])

  if (!serial) return null

  const statusColor = SITUACAO_COLOR[serial.status]
  const desgastePct = Math.max(0, Math.min(100, (serial.desgaste / 5) * 100))

  return (
    <>
      <button
        aria-label="Fechar"
        onClick={onClose}
        style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(0, 0, 0, 0.35)',
          backdropFilter: 'blur(4px)',
          WebkitBackdropFilter: 'blur(4px)',
          border: 'none',
          cursor: 'pointer',
          zIndex: 40,
          animation: 'mmd-reveal 240ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
        }}
      />
      <aside
        role="dialog"
        aria-label={`Unidade ${serial.codigo_interno}`}
        style={{
          position: 'fixed',
          top: 0,
          right: 0,
          bottom: 0,
          width: 'min(440px, 100vw)',
          background: 'var(--bg-0)',
          borderLeft: '1px solid var(--glass-border-strong)',
          boxShadow: 'var(--glass-shadow-elevated)',
          zIndex: 41,
          overflowY: 'auto',
          animation: 'slide-in-right 280ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
        }}
      >
        <div
          style={{
            position: 'sticky',
            top: 0,
            padding: '18px 22px',
            borderBottom: '1px solid var(--glass-border)',
            background: 'var(--bg-0)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 12,
            zIndex: 1,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
            <StatusDot color={statusColor} size={10} />
            <div style={{ minWidth: 0 }}>
              <div
                className="mono"
                style={{
                  fontSize: 14,
                  fontWeight: 500,
                  color: 'var(--fg-0)',
                  letterSpacing: 0.04,
                }}
              >
                {serial.codigo_interno}
              </div>
              <div
                style={{
                  fontSize: 11,
                  color: 'var(--fg-3)',
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                Unidade de {itemName}
              </div>
            </div>
          </div>
          <button
            onClick={onClose}
            aria-label="Fechar"
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: 28,
              height: 28,
              border: '1px solid var(--glass-border)',
              borderRadius: 'var(--r-sm)',
              background: 'transparent',
              color: 'var(--fg-1)',
              cursor: 'pointer',
            }}
          >
            {Icons.x}
          </button>
        </div>

        <div style={{ padding: 22, display: 'flex', flexDirection: 'column', gap: 22 }}>
          <section
            style={{
              padding: 16,
              borderRadius: 12,
              background: `color-mix(in oklch, ${statusColor} 10%, transparent)`,
              border: `1px solid color-mix(in oklch, ${statusColor} 30%, transparent)`,
            }}
          >
            <div className="mono" style={{ fontSize: 10, color: statusColor, letterSpacing: 0.12 }}>
              STATUS ATUAL
            </div>
            <div
              style={{
                fontSize: 18,
                fontWeight: 500,
                color: 'var(--fg-0)',
                marginTop: 4,
              }}
            >
              {SITUACAO_LABEL[serial.status]}
            </div>
            {serial.localizacao && (
              <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 4 }}>
                em {serial.localizacao}
              </div>
            )}
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', marginTop: 8 }}>
              Atualizado {formatTimestamp(serial.updated_at)}
            </div>
          </section>

          <Section title="Identificação">
            <Row label="Código interno" value={serial.codigo_interno} mono />
            <Row
              label="Serial fábrica"
              value={serial.serial_fabrica ?? '–'}
              mono
            />
            <Row
              label="Tag RFID"
              value={
                serial.tag_rfid ? (
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                    <span style={{ color: 'var(--accent-cyan)' }}>{Icons.rfid}</span>
                    <span className="mono">{serial.tag_rfid}</span>
                  </span>
                ) : (
                  <span style={{ color: 'var(--fg-3)' }}>sem tag</span>
                )
              }
            />
            <Row
              label="QR Code"
              value={
                serial.qr_code ? (
                  <span className="mono">{serial.qr_code}</span>
                ) : (
                  <span style={{ color: 'var(--fg-3)' }}>não gerado</span>
                )
              }
            />
          </Section>

          <Section title="Condição">
            <Row label="Ciclo" value={CICLO_LABEL[serial.estado]} />
            <div style={{ padding: '4px 0' }}>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  marginBottom: 6,
                }}
              >
                <span style={{ fontSize: 12, color: 'var(--fg-2)' }}>Desgaste</span>
                <span className="mono" style={{ fontSize: 13, color: 'var(--fg-0)' }}>
                  {serial.desgaste}/5
                </span>
              </div>
              <div
                style={{
                  height: 8,
                  borderRadius: 4,
                  background: 'var(--glass-border)',
                  overflow: 'hidden',
                }}
              >
                <div
                  style={{
                    width: `${desgastePct}%`,
                    height: '100%',
                    background:
                      serial.desgaste >= 4
                        ? 'var(--accent-green)'
                        : serial.desgaste === 3
                          ? 'var(--accent-amber)'
                          : 'var(--accent-red)',
                  }}
                />
              </div>
            </div>
            <Row label="Valor atual" value={formatBRL(serial.valor_atual)} mono />
          </Section>

          {serial.notas && (
            <Section title="Notas">
              <div
                style={{
                  fontSize: 12,
                  color: 'var(--fg-1)',
                  whiteSpace: 'pre-wrap',
                  lineHeight: 1.5,
                }}
              >
                {serial.notas}
              </div>
            </Section>
          )}

          <div
            style={{
              display: 'flex',
              gap: 8,
              flexWrap: 'wrap',
              paddingTop: 8,
              borderTop: '1px solid var(--glass-border)',
            }}
          >
            <PrimaryBtn small>Imprimir QR</PrimaryBtn>
            <GhostBtn small>Marcar manutenção</GhostBtn>
            <GhostBtn small>Editar</GhostBtn>
          </div>
        </div>

        <style>{`
          @keyframes slide-in-right {
            from { transform: translateX(100%); opacity: 0; }
            to { transform: translateX(0); opacity: 1; }
          }
        `}</style>
      </aside>
    </>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div
        className="mono"
        style={{
          fontSize: 10,
          color: 'var(--fg-2)',
          letterSpacing: 0.1,
          textTransform: 'uppercase',
          paddingBottom: 6,
          borderBottom: '1px solid var(--glass-border)',
        }}
      >
        {title}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>{children}</div>
    </section>
  )
}

function Row({
  label,
  value,
  mono,
}: {
  label: string
  value: React.ReactNode
  mono?: boolean
}) {
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        gap: 12,
        padding: '4px 0',
      }}
    >
      <span style={{ fontSize: 12, color: 'var(--fg-2)' }}>{label}</span>
      <span
        className={mono ? 'mono' : undefined}
        style={{ fontSize: 13, color: 'var(--fg-0)', textAlign: 'right' }}
      >
        {value}
      </span>
    </div>
  )
}
