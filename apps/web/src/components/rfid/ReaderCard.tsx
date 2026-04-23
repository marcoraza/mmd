'use client'

import { GlassCard, StatusDot } from '@/components/mmd/Primitives'
import type { RfidReader } from '@/lib/data/rfid'
import {
  READER_STATUS_COLOR,
  READER_STATUS_LABEL,
  formatRelativeTime,
} from './helpers'

export function ReaderCard({ reader }: { reader: RfidReader }) {
  const color = READER_STATUS_COLOR[reader.status]
  const battery = reader.bateria
  const batColor =
    battery == null
      ? 'var(--fg-3)'
      : battery > 50
        ? 'var(--accent-green)'
        : battery > 20
          ? 'var(--accent-amber)'
          : 'var(--accent-red)'

  return (
    <GlassCard style={{ padding: 14 }}>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'flex-start',
          gap: 10,
        }}
      >
        <div style={{ minWidth: 0 }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              fontSize: 13,
              fontWeight: 500,
              color: 'var(--fg-0)',
            }}
          >
            <StatusDot color={color} size={7} />
            <span
              style={{
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {reader.nome}
            </span>
          </div>
          <div
            className="mono"
            style={{
              fontSize: 10,
              color: 'var(--fg-3)',
              marginTop: 2,
              letterSpacing: 0.08,
              textTransform: 'uppercase',
            }}
          >
            {reader.modelo}
            {reader.serial_fabrica && (
              <>
                {' · '}
                {reader.serial_fabrica}
              </>
            )}
          </div>
        </div>
        <span
          style={{
            fontSize: 10,
            padding: '2px 8px',
            borderRadius: 'var(--r-sm)',
            background: `color-mix(in oklch, ${color} 14%, transparent)`,
            color,
            border: `1px solid color-mix(in oklch, ${color} 32%, transparent)`,
            whiteSpace: 'nowrap',
          }}
        >
          {READER_STATUS_LABEL[reader.status]}
        </span>
      </div>

      <div
        style={{
          marginTop: 12,
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: 10,
        }}
      >
        <MetaBlock
          label="Operador"
          value={reader.operador ?? 'Não pareado'}
          muted={!reader.operador}
        />
        <MetaBlock
          label="Bateria"
          value={battery != null ? `${battery}%` : 'sem dado'}
          color={batColor}
          mono
        />
      </div>

      <div
        style={{
          marginTop: 10,
          paddingTop: 10,
          borderTop: '1px solid var(--glass-border)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          fontSize: 11,
          color: 'var(--fg-3)',
        }}
      >
        <span>Última atividade</span>
        <span className="mono" style={{ color: 'var(--fg-2)' }}>
          {reader.ultima_atividade ? formatRelativeTime(reader.ultima_atividade) : 'nunca'}
        </span>
      </div>
    </GlassCard>
  )
}

function MetaBlock({
  label,
  value,
  color,
  mono,
  muted,
}: {
  label: string
  value: string
  color?: string
  mono?: boolean
  muted?: boolean
}) {
  return (
    <div>
      <div
        className="mono"
        style={{
          fontSize: 9,
          color: 'var(--fg-3)',
          letterSpacing: 0.12,
          textTransform: 'uppercase',
        }}
      >
        {label}
      </div>
      <div
        className={mono ? 'mono' : undefined}
        style={{
          fontSize: mono ? 13 : 12,
          color: color ?? (muted ? 'var(--fg-3)' : 'var(--fg-0)'),
          marginTop: 2,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
      >
        {value}
      </div>
    </div>
  )
}
