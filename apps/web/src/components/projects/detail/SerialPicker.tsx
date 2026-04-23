'use client'

import { useEffect, useRef, useState } from 'react'
import type { AvailableSerial } from '@/lib/data/serials'

// Dropdown de seleção de seriais disponíveis. A prop `candidates` vem do
// server (loadAvailableSerials), ordenada por FIFO rotacional + desgaste.
// Chip amarelo aparece quando o serial está em outro projeto ativo com
// overlap de datas (não bloqueia, só sinaliza).

type Props = {
  candidates: AvailableSerial[]
  onPick: (serialId: string) => void
  onClose: () => void
  loading?: boolean
}

export function SerialPicker({ candidates, onPick, onClose, loading }: Props) {
  const [query, setQuery] = useState('')
  const rootRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) {
        onClose()
      }
    }
    const keyHandler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('mousedown', handler)
    document.addEventListener('keydown', keyHandler)
    return () => {
      document.removeEventListener('mousedown', handler)
      document.removeEventListener('keydown', keyHandler)
    }
  }, [onClose])

  const q = query.trim().toLowerCase()
  const filtered = q
    ? candidates.filter((c) => c.codigo_interno.toLowerCase().includes(q))
    : candidates

  return (
    <div
      ref={rootRef}
      style={{
        position: 'absolute',
        top: 'calc(100% + 6px)',
        right: 0,
        width: 'min(420px, calc(100vw - 32px))',
        maxHeight: 360,
        display: 'flex',
        flexDirection: 'column',
        background: 'var(--bg-0)',
        border: '1px solid var(--glass-border-strong)',
        borderRadius: 'var(--r-md)',
        boxShadow: 'var(--glass-shadow-elevated)',
        zIndex: 30,
        overflow: 'hidden',
        animation: 'mmd-reveal 160ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
      }}
    >
      <div
        style={{
          padding: '10px 12px',
          borderBottom: '1px solid var(--glass-border)',
          background: 'var(--glass-bg)',
        }}
      >
        <input
          autoFocus
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Buscar por código…"
          className="mono"
          style={{
            width: '100%',
            padding: '6px 10px',
            fontSize: 12,
            fontFamily: 'inherit',
            borderRadius: 6,
            border: '1px solid var(--glass-border)',
            background: 'var(--bg-0)',
            color: 'var(--fg-0)',
            outline: 'none',
          }}
        />
      </div>

      <div style={{ overflowY: 'auto', flex: 1 }}>
        {loading ? (
          <div style={{ padding: 20, fontSize: 12, color: 'var(--fg-3)', textAlign: 'center' }}>
            Carregando…
          </div>
        ) : filtered.length === 0 ? (
          <div style={{ padding: 20, fontSize: 12, color: 'var(--fg-3)', textAlign: 'center' }}>
            {candidates.length === 0
              ? 'Nenhum serial DISPONIVEL pra este item.'
              : 'Nada bate com a busca.'}
          </div>
        ) : (
          filtered.map((c) => (
            <SerialRow key={c.id} s={c} onPick={() => onPick(c.id)} />
          ))
        )}
      </div>
    </div>
  )
}

function SerialRow({ s, onPick }: { s: AvailableSerial; onPick: () => void }) {
  const hasConflict = s.conflicts_with.length > 0
  return (
    <button
      type="button"
      onClick={onPick}
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 10,
        width: '100%',
        padding: '10px 12px',
        border: 'none',
        borderBottom: '1px solid var(--glass-border)',
        background: 'transparent',
        cursor: 'pointer',
        fontFamily: 'inherit',
        textAlign: 'left',
        color: 'var(--fg-0)',
        transition: 'background var(--motion-fast)',
      }}
      onMouseEnter={(e) => (e.currentTarget.style.background = 'var(--glass-bg)')}
      onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 3, minWidth: 0, flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <span className="mono" style={{ fontSize: 12, color: 'var(--fg-0)' }}>
            {s.codigo_interno}
          </span>
          <DesgasteBadge n={s.desgaste} />
          {hasConflict && (
            <span
              className="mono"
              style={{
                fontSize: 10,
                padding: '2px 6px',
                borderRadius: 4,
                background: 'color-mix(in oklch, var(--accent-amber) 14%, transparent)',
                border: '1px solid color-mix(in oklch, var(--accent-amber) 35%, transparent)',
                color: 'var(--accent-amber)',
                letterSpacing: 0.05,
              }}
            >
              conflito: {s.conflicts_with[0].projeto_nome}
              {s.conflicts_with.length > 1 ? ` +${s.conflicts_with.length - 1}` : ''}
            </span>
          )}
        </div>
        <div
          className="mono"
          style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.05 }}
        >
          {s.last_moved_at
            ? `Último uso ${formatRelative(s.last_moved_at)}`
            : 'Nunca foi usado'}
          {s.localizacao && <span> · {s.localizacao}</span>}
        </div>
      </div>
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
        fontSize: 10,
        padding: '1px 5px',
        borderRadius: 3,
        background: `color-mix(in oklch, ${color} 14%, transparent)`,
        border: `1px solid color-mix(in oklch, ${color} 30%, transparent)`,
        color,
        letterSpacing: 0.05,
      }}
    >
      {n}/5
    </span>
  )
}

function formatRelative(iso: string): string {
  const then = new Date(iso).getTime()
  const diff = Date.now() - then
  const days = Math.floor(diff / 86_400_000)
  if (days < 1) return 'hoje'
  if (days === 1) return 'ontem'
  if (days < 30) return `${days}d atrás`
  const months = Math.floor(days / 30)
  if (months < 12) return `${months}m atrás`
  return `${Math.floor(months / 12)}a atrás`
}
