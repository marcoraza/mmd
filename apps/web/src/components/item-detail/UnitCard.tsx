'use client'

import { Icons } from '@/components/mmd/Icons'
import { StatusDot } from '@/components/mmd/Primitives'
import {
  SITUACAO_COLOR,
  SITUACAO_LABEL,
  formatBRL,
} from '@/components/catalog/helpers'
import type { SerialRow } from '@/lib/data/items'
import { ESTADO_SHORT } from './helpers'

type Props = {
  serial: SerialRow
  onOpen: () => void
  onPrintQr: () => void
}

export function UnitCard({ serial: s, onOpen, onPrintQr }: Props) {
  const statusColor = SITUACAO_COLOR[s.status]
  const desgastePct = Math.max(0, Math.min(100, (s.desgaste / 5) * 100))
  const desgasteColor =
    s.desgaste >= 4
      ? 'var(--accent-green)'
      : s.desgaste === 3
        ? 'var(--accent-amber)'
        : 'var(--accent-red)'

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={onOpen}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          onOpen()
        }
      }}
      className="glass"
      style={{
        padding: 14,
        borderRadius: 14,
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
        cursor: 'pointer',
        border: '1px solid var(--glass-border)',
        background: 'var(--glass-bg)',
        transition: 'transform var(--motion-fast), border-color var(--motion-fast)',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
          <StatusDot color={statusColor} size={8} />
          <span
            className="mono"
            style={{
              fontSize: 12,
              color: 'var(--fg-0)',
              fontWeight: 500,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {s.codigo_interno}
          </span>
        </div>
        <button
          aria-label="Imprimir QR"
          onClick={(e) => {
            e.stopPropagation()
            onPrintQr()
          }}
          style={{
            width: 26,
            height: 26,
            borderRadius: 6,
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            border: '1px solid var(--glass-border)',
            background: 'transparent',
            color: 'var(--fg-2)',
            cursor: 'pointer',
            padding: 0,
            flexShrink: 0,
          }}
        >
          <span style={{ transform: 'scale(0.8)' }}>{Icons.qr}</span>
        </button>
      </div>

      <div
        className="mono"
        style={{
          fontSize: 10,
          color: statusColor,
          letterSpacing: 0.1,
          textTransform: 'uppercase',
        }}
      >
        {SITUACAO_LABEL[s.status]}
      </div>

      <div>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: 4,
          }}
        >
          <span
            className="mono"
            style={{
              fontSize: 9,
              color: 'var(--fg-3)',
              letterSpacing: 0.08,
              textTransform: 'uppercase',
            }}
          >
            Desgaste
          </span>
          <span className="mono" style={{ fontSize: 10, color: desgasteColor }}>
            {s.desgaste}/5
          </span>
        </div>
        <div
          style={{
            height: 4,
            borderRadius: 2,
            background: 'var(--glass-border)',
            overflow: 'hidden',
          }}
        >
          <div
            style={{
              width: `${desgastePct}%`,
              height: '100%',
              background: desgasteColor,
            }}
          />
        </div>
      </div>

      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 6,
          paddingTop: 6,
          borderTop: '1px solid var(--glass-border)',
        }}
      >
        <span
          className="mono"
          style={{
            fontSize: 9,
            color: 'var(--fg-3)',
            letterSpacing: 0.08,
            textTransform: 'uppercase',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
          title={s.localizacao ?? undefined}
        >
          {s.localizacao ?? '–'}
        </span>
        <span
          className="mono"
          style={{
            fontSize: 10,
            color: ESTADO_SHORT[s.estado] === 'NOVO' ? 'var(--accent-green)' : 'var(--fg-2)',
            letterSpacing: 0.08,
          }}
        >
          {ESTADO_SHORT[s.estado]}
        </span>
      </div>

      <div
        className="mono"
        style={{
          fontSize: 11,
          color: 'var(--fg-1)',
          textAlign: 'right',
        }}
      >
        {formatBRL(s.valor_atual)}
      </div>
    </div>
  )
}
