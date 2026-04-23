'use client'

import Link from 'next/link'
import { GlassCard, StatusDot } from '@/components/mmd/Primitives'
import type { RfidScan } from '@/lib/data/rfid'
import { CONTEXTO_COLOR, CONTEXTO_LABEL, formatRelativeTime, formatScanTime } from './helpers'

export function ScanTimeline({ scans }: { scans: RfidScan[] }) {
  if (scans.length === 0) {
    return (
      <GlassCard style={{ padding: 32, textAlign: 'center' }}>
        <div
          className="mono"
          style={{
            fontSize: 11,
            color: 'var(--fg-3)',
            letterSpacing: 0.12,
            textTransform: 'uppercase',
            marginBottom: 8,
          }}
        >
          Nenhum scan
        </div>
        <div style={{ fontSize: 13, color: 'var(--fg-2)' }}>
          Nenhuma leitura bate com os filtros atuais. Ajuste o banner ou limpe a busca.
        </div>
      </GlassCard>
    )
  }

  return (
    <GlassCard style={{ padding: 0, overflow: 'hidden' }}>
      <div
        role="list"
        style={{
          maxHeight: 'calc(100dvh - 320px)',
          minHeight: 420,
          overflowY: 'auto',
        }}
      >
        {scans.map((s, i) => (
          <ScanRow key={s.id} scan={s} isLast={i === scans.length - 1} />
        ))}
      </div>
    </GlassCard>
  )
}

function ScanRow({ scan, isLast }: { scan: RfidScan; isLast: boolean }) {
  const contextoColor = scan.contexto ? CONTEXTO_COLOR[scan.contexto] : 'var(--fg-3)'
  const contextoLabel = scan.contexto ? CONTEXTO_LABEL[scan.contexto] : 'Sem contexto'

  const resolvedHref = scan.serial_id && scan.item_id
    ? `/items/${scan.item_id}`
    : scan.lote_id
      ? `/lotes/${scan.lote_id}`
      : null

  const resolvedCode = scan.serial_codigo ?? scan.lote_codigo
  const resolvedKind = scan.serial_codigo ? 'Serial' : scan.lote_codigo ? 'Lote' : null

  return (
    <div
      role="listitem"
      style={{
        display: 'grid',
        gridTemplateColumns: 'minmax(110px, 130px) minmax(0, 1fr) minmax(180px, 260px)',
        gap: 16,
        padding: '14px 18px',
        borderBottom: isLast ? 'none' : '1px solid var(--glass-border)',
        alignItems: 'flex-start',
      }}
    >
      {/* Timestamp */}
      <div style={{ minWidth: 0 }}>
        <div
          className="mono"
          style={{
            fontSize: 12,
            color: 'var(--fg-1)',
            letterSpacing: 0.04,
          }}
        >
          {formatRelativeTime(scan.timestamp)}
        </div>
        <div
          className="mono"
          style={{
            fontSize: 10,
            color: 'var(--fg-3)',
            marginTop: 2,
            letterSpacing: 0.08,
          }}
        >
          {formatScanTime(scan.timestamp)}
        </div>
      </div>

      {/* Tag + resolução */}
      <div style={{ minWidth: 0 }}>
        <div
          className="mono"
          style={{
            fontSize: 10,
            color: 'var(--fg-3)',
            letterSpacing: 0.08,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
          title={scan.tag_rfid}
        >
          {scan.tag_rfid}
        </div>
        {resolvedHref ? (
          <Link
            href={resolvedHref}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 8,
              marginTop: 4,
              textDecoration: 'none',
              color: 'inherit',
              minWidth: 0,
              maxWidth: '100%',
            }}
          >
            <span
              className="mono"
              style={{
                fontSize: 12,
                color: 'var(--accent-cyan)',
                fontWeight: 500,
                whiteSpace: 'nowrap',
              }}
            >
              {resolvedCode}
            </span>
            <span
              style={{
                fontSize: 12,
                color: 'var(--fg-1)',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                minWidth: 0,
              }}
            >
              {scan.item_nome ?? resolvedKind}
            </span>
          </Link>
        ) : (
          <div style={{ marginTop: 4, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span
              style={{
                display: 'inline-block',
                fontSize: 10,
                padding: '2px 8px',
                borderRadius: 'var(--r-sm)',
                background: 'color-mix(in oklch, var(--accent-red) 14%, transparent)',
                color: 'var(--accent-red)',
                border: '1px solid color-mix(in oklch, var(--accent-red) 32%, transparent)',
                letterSpacing: 0.08,
                textTransform: 'uppercase',
              }}
            >
              Tag órfã
            </span>
            <span style={{ fontSize: 11, color: 'var(--fg-3)' }}>
              Sem match no catálogo
            </span>
          </div>
        )}
      </div>

      {/* Metadata */}
      <div
        style={{
          minWidth: 0,
          display: 'flex',
          flexDirection: 'column',
          gap: 4,
          alignItems: 'flex-end',
          textAlign: 'right',
        }}
      >
        <span
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
            fontSize: 10,
            padding: '2px 8px',
            borderRadius: 'var(--r-sm)',
            background: `color-mix(in oklch, ${contextoColor} 14%, transparent)`,
            color: contextoColor,
            border: `1px solid color-mix(in oklch, ${contextoColor} 30%, transparent)`,
            letterSpacing: 0.04,
          }}
        >
          <StatusDot color={contextoColor} size={6} />
          {contextoLabel}
        </span>
        <span
          style={{
            fontSize: 11,
            color: 'var(--fg-2)',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            maxWidth: '100%',
          }}
        >
          {[scan.operador, scan.reader_nome].filter(Boolean).join(' · ') || 'Sem operador'}
        </span>
        {scan.localizacao && (
          <span
            className="mono"
            style={{
              fontSize: 10,
              color: 'var(--fg-3)',
              letterSpacing: 0.06,
            }}
          >
            {scan.localizacao}
          </span>
        )}
      </div>
    </div>
  )
}
