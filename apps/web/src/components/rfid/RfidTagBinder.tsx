'use client'

import { useEffect, useMemo, useState, useTransition } from 'react'
import type { CSSProperties, ReactNode } from 'react'
import { Btn, GlassCard, StatusDot } from '@/components/mmd/Primitives'
import {
  bindRfidTagToSerial,
  searchCableUnitsForRfidBind,
  type CableUnitForRfidBind,
} from '@/lib/actions/rfid'

type Props = {
  stats: {
    total_units: number
    tags_bound: number
    tags_pending: number
    legacy_lotes: number
  }
}

export function RfidTagBinder({ stats }: Props) {
  const [tag, setTag] = useState('')
  const [query, setQuery] = useState('')
  const [units, setUnits] = useState<CableUnitForRfidBind[]>([])
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isPending, startTransition] = useTransition()

  useEffect(() => {
    let cancelled = false
    startTransition(async () => {
      const result = await searchCableUnitsForRfidBind(query)
      if (cancelled) return
      if (result.ok) {
        setUnits(result.data)
        setError(null)
        setSelectedId((current) =>
          current && result.data.some((unit) => unit.id === current) ? current : null,
        )
      } else {
        setError(result.error)
      }
    })
    return () => {
      cancelled = true
    }
  }, [query])

  const selected = useMemo(
    () => units.find((unit) => unit.id === selectedId) ?? null,
    [units, selectedId],
  )

  function submit() {
    if (!selectedId) {
      setError('Escolha uma unidade de cabo.')
      return
    }
    setMessage(null)
    setError(null)
    startTransition(async () => {
      const result = await bindRfidTagToSerial(selectedId, tag)
      if (result.ok) {
        setMessage(`${result.data.codigo_interno} vinculado ao RFID ${result.data.tag_rfid}.`)
        setTag('')
        setQuery('')
        setSelectedId(null)
        const refreshed = await searchCableUnitsForRfidBind('')
        if (refreshed.ok) setUnits(refreshed.data)
      } else {
        setError(result.error)
      }
    })
  }

  return (
    <GlassCard style={{ padding: 18, marginTop: 20 }}>
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'minmax(0, 1.1fr) minmax(300px, 0.9fr)',
          gap: 18,
          alignItems: 'start',
        }}
      >
        <div style={{ minWidth: 0 }}>
          <div
            className="mono"
            style={{
              fontSize: 10,
              color: 'var(--fg-2)',
              letterSpacing: 0.12,
              textTransform: 'uppercase',
            }}
          >
            Vincular RFID em cabos
          </div>
          <div style={{ marginTop: 6, fontSize: 13, color: 'var(--fg-2)', lineHeight: 1.45 }}>
            Escaneie a tag UHF do cabo, escolha a unidade física e salve. QR continua como backup
            da mesma unidade.
          </div>

          <div
            style={{
              marginTop: 14,
              display: 'grid',
              gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
              gap: 8,
            }}
          >
            <Stat label="Unidades" value={stats.total_units} color="var(--fg-0)" />
            <Stat label="Com RFID" value={stats.tags_bound} color="var(--accent-green)" />
            <Stat label="Pendentes" value={stats.tags_pending} color="var(--accent-amber)" />
            <Stat label="Lotes legados" value={stats.legacy_lotes} color="var(--fg-2)" />
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, minWidth: 0 }}>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            <span className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
              RFID lido pelo RFD40
            </span>
            <input
              value={tag}
              onChange={(e) => setTag(e.target.value)}
              placeholder="Ex: E2801191A503006625D9..."
              className="mono"
              style={inputStyle}
            />
          </label>

          <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            <span className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
              Buscar cabo
            </span>
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Código, tipo ou RFID atual"
              style={inputStyle}
            />
          </label>

          <div
            style={{
              maxHeight: 210,
              overflowY: 'auto',
              border: '1px solid var(--glass-border)',
              borderRadius: 'var(--r-sm)',
            }}
          >
            {units.length === 0 ? (
              <div style={{ padding: 14, fontSize: 12, color: 'var(--fg-3)' }}>
                Nenhuma unidade de cabo encontrada. Rode o dry-run/migração piloto primeiro.
              </div>
            ) : (
              units.map((unit) => (
                <button
                  key={unit.id}
                  type="button"
                  onClick={() => setSelectedId(unit.id)}
                  aria-pressed={selectedId === unit.id}
                  style={{
                    width: '100%',
                    display: 'flex',
                    justifyContent: 'space-between',
                    gap: 10,
                    padding: '9px 10px',
                    border: 'none',
                    borderBottom: '1px solid var(--glass-border)',
                    background:
                      selectedId === unit.id
                        ? 'color-mix(in oklch, var(--accent-cyan) 12%, transparent)'
                        : 'transparent',
                    color: 'inherit',
                    fontFamily: 'inherit',
                    cursor: 'pointer',
                    textAlign: 'left',
                  }}
                >
                  <span style={{ minWidth: 0 }}>
                    <span className="mono" style={{ fontSize: 12, color: 'var(--fg-0)' }}>
                      {unit.codigo_interno}
                    </span>
                    <span
                      style={{
                        display: 'block',
                        marginTop: 2,
                        fontSize: 11,
                        color: 'var(--fg-2)',
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                      }}
                    >
                      {unit.item_nome}
                      {unit.item_subcategoria ? ` · ${unit.item_subcategoria}` : ''}
                    </span>
                  </span>
                  <span
                    className="mono"
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 5,
                      fontSize: 10,
                      color: unit.tag_rfid ? 'var(--accent-green)' : 'var(--accent-amber)',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    <StatusDot
                      color={unit.tag_rfid ? 'var(--accent-green)' : 'var(--accent-amber)'}
                      size={6}
                    />
                    {unit.tag_rfid ? 'RFID OK' : 'SEM RFID'}
                  </span>
                </button>
              ))
            )}
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
            <Btn small disabled={isPending || !tag.trim() || !selected} onClick={submit}>
              {isPending ? 'Salvando...' : 'Vincular tag'}
            </Btn>
            {selected && (
              <span style={{ fontSize: 11, color: 'var(--fg-2)' }}>
                Selecionado: <span className="mono">{selected.codigo_interno}</span>
              </span>
            )}
          </div>

          {message && <Feedback kind="ok">{message}</Feedback>}
          {error && <Feedback kind="error">{error}</Feedback>}
        </div>
      </div>
    </GlassCard>
  )
}

function Stat({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div
      style={{
        padding: '10px 12px',
        borderRadius: 'var(--r-sm)',
        background: 'var(--glass-bg)',
        border: '1px solid var(--glass-border)',
        minWidth: 0,
      }}
    >
      <div
        className="mono"
        style={{ fontSize: 9, color: 'var(--fg-3)', textTransform: 'uppercase' }}
      >
        {label}
      </div>
      <div style={{ marginTop: 3, fontSize: 20, color, fontWeight: 500 }}>{value}</div>
    </div>
  )
}

function Feedback({ kind, children }: { kind: 'ok' | 'error'; children: ReactNode }) {
  const color = kind === 'ok' ? 'var(--accent-green)' : 'var(--accent-red)'
  return (
    <div
      style={{
        padding: '8px 10px',
        borderRadius: 'var(--r-sm)',
        fontSize: 12,
        color,
        background: `color-mix(in oklch, ${color} 12%, transparent)`,
        border: `1px solid color-mix(in oklch, ${color} 32%, transparent)`,
      }}
    >
      {children}
    </div>
  )
}

const inputStyle: CSSProperties = {
  width: '100%',
  padding: '8px 10px',
  borderRadius: 'var(--r-sm)',
  border: '1px solid var(--glass-border)',
  background: 'var(--bg-0)',
  color: 'var(--fg-0)',
  fontFamily: 'inherit',
  fontSize: 12,
  outline: 'none',
}
