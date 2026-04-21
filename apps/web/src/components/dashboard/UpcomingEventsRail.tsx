'use client'

import Link from 'next/link'
import { useEffect, useRef, useState } from 'react'
import { Icons } from '@/components/mmd/Icons'
import type { DashboardUpcomingEvent, EventStatus, EventType } from '@/lib/data/dashboard'

const typeIcon: Record<EventType, keyof typeof Icons> = {
  wedding: 'event_wedding',
  show: 'event_show',
  corporate: 'event_corporate',
  feira: 'event_feira',
  default: 'event_default',
}

const typeLabel: Record<EventType, string> = {
  wedding: 'CASAMENTO',
  show: 'SHOW',
  corporate: 'CORPORATIVO',
  feira: 'FEIRA',
  default: 'EVENTO',
}

const statusMeta: Record<EventStatus, { label: string; color: string; dot: string }> = {
  pronto: { label: 'pronto', color: 'var(--accent-green)', dot: 'var(--accent-green)' },
  a_verificar: { label: 'a verificar', color: 'var(--accent-amber)', dot: 'var(--accent-amber)' },
  atrasado: { label: 'atrasado', color: 'var(--accent-amber)', dot: 'var(--accent-amber)' },
  critico: { label: 'crítico', color: 'var(--accent-red)', dot: 'var(--accent-red)' },
}

function readinessGradient(value: number) {
  if (value >= 90) return 'linear-gradient(90deg, var(--accent-green), var(--accent-cyan))'
  if (value >= 60) return 'linear-gradient(90deg, var(--accent-cyan), var(--accent-violet))'
  if (value >= 40) return 'linear-gradient(90deg, var(--accent-amber), var(--accent-violet))'
  return 'linear-gradient(90deg, var(--accent-red), var(--accent-amber))'
}

export function UpcomingEventsRail({
  events,
  scheduled,
}: {
  events: DashboardUpcomingEvent[]
  scheduled: number
}) {
  const scrollerRef = useRef<HTMLDivElement>(null)
  const [pageCount, setPageCount] = useState(1)
  const [activePage, setActivePage] = useState(0)

  useEffect(() => {
    const el = scrollerRef.current
    if (!el) return
    const update = () => {
      const pages = Math.max(1, Math.ceil(el.scrollWidth / el.clientWidth))
      setPageCount(pages)
      const current = Math.round((el.scrollLeft / el.clientWidth) * (pages / pages))
      setActivePage(Math.min(pages - 1, current))
    }
    update()
    el.addEventListener('scroll', update, { passive: true })
    const ro = new ResizeObserver(update)
    ro.observe(el)
    return () => {
      el.removeEventListener('scroll', update)
      ro.disconnect()
    }
  }, [events.length])

  const scrollBy = (dir: 1 | -1) => {
    const el = scrollerRef.current
    if (!el) return
    el.scrollBy({ left: dir * el.clientWidth, behavior: 'smooth' })
  }

  return (
    <div className="reveal reveal-3" style={{ marginTop: 36 }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: 14,
          gap: 12,
        }}
      >
        <div style={{ fontSize: 14, color: 'var(--fg-1)', fontWeight: 500 }}>Próximos eventos</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div className="mono" style={{ fontSize: 11, color: 'var(--fg-3)' }}>
            {scheduled} agendados
          </div>
          <div style={{ display: 'flex', gap: 4 }}>
            <button
              type="button"
              aria-label="Página anterior"
              onClick={() => scrollBy(-1)}
              disabled={activePage === 0}
              className="upcoming-pager-btn"
            >
              {Icons.chevron_left}
            </button>
            <button
              type="button"
              aria-label="Próxima página"
              onClick={() => scrollBy(1)}
              disabled={activePage >= pageCount - 1}
              className="upcoming-pager-btn"
            >
              {Icons.chevron_right}
            </button>
          </div>
        </div>
      </div>

      <div
        ref={scrollerRef}
        className="upcoming-scroller"
        style={{
          display: 'grid',
          gridAutoFlow: 'column',
          gridAutoColumns: 'calc((100% - 42px) / 4)',
          gap: 14,
          overflowX: 'auto',
          scrollSnapType: 'x mandatory',
          paddingBottom: 4,
          scrollbarWidth: 'none',
        }}
      >
        {events.map((e, i) => {
          const st = statusMeta[e.status]
          const iconKey = typeIcon[e.type]
          const label = typeLabel[e.type]
          return (
            <Link
              key={e.id}
              href={`/projetos/detalhe/${e.id}`}
              className={`glass card-interactive reveal reveal-${Math.min(i + 3, 6)} upcoming-card`}
              aria-label={`Abrir evento ${e.title}`}
              style={{
                padding: 0,
                scrollSnapAlign: 'start',
                display: 'flex',
                flexDirection: 'column',
                overflow: 'hidden',
                minHeight: 180,
              }}
            >
              <div
                aria-hidden
                title={`${Math.round(e.items_count * (e.readiness / 100))}/${e.items_count} prontos`}
                style={{
                  height: 3,
                  width: `${Math.max(4, e.readiness)}%`,
                  background: readinessGradient(e.readiness),
                  transition: 'width var(--motion-default)',
                }}
              />
              <div
                style={{
                  padding: '16px 18px 14px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 10,
                  flex: 1,
                }}
              >
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: 10,
                  }}
                >
                  <div
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 6,
                      color: 'var(--fg-2)',
                    }}
                  >
                    <span aria-hidden>{Icons[iconKey]}</span>
                    <span
                      className="mono"
                      style={{
                        fontSize: 10,
                        letterSpacing: 0.12,
                        color: 'var(--fg-2)',
                      }}
                    >
                      {label}
                    </span>
                  </div>
                  <span
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: 6,
                      padding: '3px 10px',
                      borderRadius: 999,
                      background: 'var(--glass-bg-strong)',
                      border: `1px solid ${st.color}`,
                      color: st.color,
                      minWidth: 92,
                    }}
                    title={`${Math.round(e.items_count * (e.readiness / 100))}/${e.items_count} prontos`}
                  >
                    <span
                      aria-hidden
                      style={{
                        width: 6,
                        height: 6,
                        borderRadius: '50%',
                        background: st.dot,
                      }}
                    />
                    <span
                      className="mono"
                      style={{
                        fontSize: 9,
                        letterSpacing: 0.14,
                        textTransform: 'uppercase',
                      }}
                    >
                      {st.label}
                    </span>
                  </span>
                </div>

                <div
                  style={{
                    fontFamily: 'var(--font-serif), Georgia, serif',
                    fontStyle: 'italic',
                    fontWeight: 400,
                    fontSize: 19,
                    letterSpacing: -0.3,
                    color: 'var(--fg-0)',
                    lineHeight: 1.15,
                    overflow: 'hidden',
                    display: '-webkit-box',
                    WebkitLineClamp: 2,
                    WebkitBoxOrient: 'vertical',
                    minHeight: 44,
                  }}
                >
                  {e.title}
                </div>

                <div
                  style={{
                    display: 'flex',
                    flexDirection: 'column',
                    gap: 3,
                    marginTop: 'auto',
                  }}
                >
                  <div
                    className="mono"
                    style={{
                      fontSize: 10,
                      color: 'var(--fg-1)',
                      letterSpacing: 0.1,
                    }}
                  >
                    {e.date}
                  </div>
                  <div
                    style={{
                      fontSize: 11,
                      color: 'var(--fg-2)',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {e.venue}
                  </div>
                </div>

                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    paddingTop: 8,
                    borderTop: '1px solid var(--glass-border)',
                    color: 'var(--fg-3)',
                  }}
                >
                  <span
                    className="mono"
                    style={{ fontSize: 10, letterSpacing: 0.08 }}
                  >
                    {e.items_count} itens
                  </span>
                  <span
                    className="mono"
                    style={{ fontSize: 10, letterSpacing: 0.08 }}
                  >
                    {e.crew} téc
                  </span>
                  <span
                    className="mono"
                    style={{
                      fontSize: 10,
                      letterSpacing: 0.08,
                      color: 'var(--fg-1)',
                    }}
                  >
                    {e.readiness}%
                  </span>
                </div>
              </div>
            </Link>
          )
        })}
      </div>

      {pageCount > 1 && (
        <div
          role="tablist"
          aria-label="Páginas de eventos"
          style={{
            display: 'flex',
            justifyContent: 'center',
            gap: 8,
            marginTop: 14,
          }}
        >
          {Array.from({ length: pageCount }).map((_, p) => (
            <button
              key={p}
              role="tab"
              aria-selected={p === activePage}
              aria-label={`Página ${p + 1}`}
              onClick={() => {
                const el = scrollerRef.current
                if (!el) return
                el.scrollTo({ left: p * el.clientWidth, behavior: 'smooth' })
              }}
              style={{
                width: p === activePage ? 20 : 6,
                height: 6,
                borderRadius: 999,
                border: 'none',
                padding: 0,
                background:
                  p === activePage ? 'var(--fg-1)' : 'var(--glass-border-strong)',
                cursor: 'pointer',
                transition: 'width var(--motion-default), background var(--motion-default)',
              }}
            />
          ))}
        </div>
      )}

      <style>{`
        .upcoming-scroller::-webkit-scrollbar { display: none; }
        .upcoming-card {
          transition: transform var(--motion-fast), box-shadow var(--motion-fast), border-color var(--motion-fast);
        }
        .upcoming-card:hover {
          transform: translateY(-2px);
        }
        .upcoming-pager-btn {
          width: 28px;
          height: 28px;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          border-radius: var(--r-sm);
          background: var(--glass-bg);
          border: 1px solid var(--glass-border);
          color: var(--fg-1);
          cursor: pointer;
          transition: background var(--motion-fast), border-color var(--motion-fast), opacity var(--motion-fast);
        }
        .upcoming-pager-btn:hover:not(:disabled) {
          background: var(--glass-bg-strong);
          border-color: var(--glass-border-strong);
        }
        .upcoming-pager-btn:disabled {
          opacity: 0.4;
          cursor: default;
        }
        @media (max-width: 1100px) {
          .upcoming-scroller { grid-auto-columns: calc((100% - 28px) / 3) !important; }
        }
        @media (max-width: 820px) {
          .upcoming-scroller { grid-auto-columns: calc((100% - 14px) / 2) !important; }
        }
        @media (max-width: 540px) {
          .upcoming-scroller { grid-auto-columns: 85% !important; }
        }
      `}</style>
    </div>
  )
}
