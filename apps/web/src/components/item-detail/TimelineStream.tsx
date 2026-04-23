'use client'

import Link from 'next/link'
import type { MovimentacaoTimeline } from '@/lib/data/items'
import { TIPO_COR, TIPO_LABEL, formatTimestamp } from './helpers'

export function TimelineStream({ events }: { events: MovimentacaoTimeline[] }) {
  if (events.length === 0) {
    return (
      <div
        style={{
          padding: 32,
          textAlign: 'center',
          fontSize: 12,
          color: 'var(--fg-3)',
        }}
      >
        Sem movimentações nesse filtro.
      </div>
    )
  }

  return (
    <div style={{ position: 'relative', paddingLeft: 22 }}>
      <div
        style={{
          position: 'absolute',
          left: 7,
          top: 6,
          bottom: 6,
          width: 1,
          background: 'var(--glass-border-strong)',
        }}
      />
      {events.map((e) => {
        const cor = TIPO_COR[e.tipo]
        return (
          <div key={e.id} style={{ position: 'relative', paddingBottom: 14 }}>
            <div
              style={{
                position: 'absolute',
                left: -19,
                top: 5,
                width: 10,
                height: 10,
                borderRadius: '50%',
                background: cor,
                boxShadow: `0 0 0 3px var(--bg-0), 0 0 8px ${cor}`,
              }}
            />
            <div
              style={{
                display: 'flex',
                alignItems: 'baseline',
                justifyContent: 'space-between',
                gap: 12,
                flexWrap: 'wrap',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, flexWrap: 'wrap', minWidth: 0 }}>
                <span
                  className="mono"
                  style={{
                    fontSize: 10,
                    color: cor,
                    letterSpacing: 0.12,
                    textTransform: 'uppercase',
                    fontWeight: 500,
                  }}
                >
                  {TIPO_LABEL[e.tipo]}
                </span>
                {e.serial_codigo && (
                  <span
                    className="mono"
                    style={{
                      fontSize: 11,
                      color: 'var(--fg-1)',
                      padding: '1px 6px',
                      borderRadius: 4,
                      background: 'var(--glass-bg)',
                      border: '1px solid var(--glass-border)',
                    }}
                  >
                    {e.serial_codigo}
                  </span>
                )}
                {e.projeto_nome && (
                  e.projeto_id ? (
                    <Link
                      href={`/projetos/${e.projeto_id}`}
                      style={{
                        fontSize: 12,
                        color: 'var(--accent-cyan)',
                        textDecoration: 'none',
                      }}
                    >
                      {e.projeto_nome}
                    </Link>
                  ) : (
                    <span style={{ fontSize: 12, color: 'var(--fg-1)' }}>{e.projeto_nome}</span>
                  )
                )}
              </div>
              <span
                className="mono"
                style={{
                  fontSize: 10,
                  color: 'var(--fg-3)',
                  letterSpacing: 0.08,
                  whiteSpace: 'nowrap',
                }}
              >
                {formatTimestamp(e.timestamp)}
                {e.metodo_scan && (
                  <span style={{ marginLeft: 6, color: 'var(--accent-cyan)' }}>
                    · {e.metodo_scan.toLowerCase()}
                  </span>
                )}
              </span>
            </div>
            {(e.notas || e.registrado_por) && (
              <div
                style={{
                  fontSize: 12,
                  color: 'var(--fg-2)',
                  marginTop: 4,
                }}
              >
                {e.notas && <span>{e.notas}</span>}
                {e.notas && e.registrado_por && <span style={{ color: 'var(--fg-3)' }}> · </span>}
                {e.registrado_por && (
                  <span style={{ color: 'var(--fg-3)' }}>por {e.registrado_por}</span>
                )}
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}
