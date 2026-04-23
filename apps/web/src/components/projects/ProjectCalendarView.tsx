'use client'

import { useMemo, useState } from 'react'
import { GlassCard, GlassPill, Ring, StatusDot } from '@/components/mmd/Primitives'
import { Icons } from '@/components/mmd/Icons'
import type { Projeto } from '@/lib/data/projects'

const WEEKDAY_FMT = new Intl.DateTimeFormat('pt-BR', { weekday: 'short' })
const MONTH_FMT = new Intl.DateTimeFormat('pt-BR', { month: 'short' })
const RANGE_FMT = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: 'short', year: 'numeric' })

const TOTAL_DAYS = 15

function toDate(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number)
  return new Date(y, m - 1, d)
}

function diffDays(a: Date, b: Date): number {
  return Math.round((a.getTime() - b.getTime()) / (1000 * 60 * 60 * 24))
}

function addDays(d: Date, n: number): Date {
  const r = new Date(d)
  r.setDate(d.getDate() + n)
  return r
}

function statusColor(s: Projeto['status']): string {
  switch (s) {
    case 'PLANEJAMENTO': return 'var(--fg-3)'
    case 'CONFIRMADO': return 'var(--accent-cyan)'
    case 'EM_CAMPO': return 'var(--accent-violet)'
    case 'FINALIZADO': return 'var(--accent-amber)'
    case 'CANCELADO': return 'var(--accent-red)'
  }
}

function formatRange(start: Date, end: Date): string {
  return `${RANGE_FMT.format(start).replace('.', '')} a ${RANGE_FMT.format(end).replace('.', '')}`
}

function todayStart(): Date {
  const now = new Date()
  return new Date(now.getFullYear(), now.getMonth(), now.getDate())
}

export function ProjectCalendarView({ projetos }: { projetos: Projeto[] }) {
  const ativos = projetos.filter((p) => p.status !== 'FINALIZADO' && p.status !== 'CANCELADO')
  const [cursor, setCursor] = useState<Date>(() => todayStart())

  const days = useMemo(
    () => Array.from({ length: TOTAL_DAYS }, (_, i) => addDays(cursor, i)),
    [cursor]
  )
  const end = days[TOTAL_DAYS - 1]

  const visibleProjetos = ativos.filter((p) => {
    const ps = toDate(p.data_inicio)
    const pe = toDate(p.data_fim)
    return pe >= cursor && ps <= end
  })

  const rows = visibleProjetos.map((p) => {
    const ps = toDate(p.data_inicio)
    const pe = toDate(p.data_fim)
    const offset = Math.max(0, diffDays(ps, cursor))
    const duration = Math.min(TOTAL_DAYS - offset, diffDays(pe, ps) + 1)
    return { projeto: p, offset, duration }
  })

  const today = todayStart()

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
        <div style={{ fontSize: 14, fontWeight: 500, color: 'var(--fg-0)' }}>Cronograma</div>
        <GlassPill>
          <span className="mono" style={{ fontSize: 11 }}>
            {formatRange(cursor, end)}
          </span>
        </GlassPill>
        <div style={{ flex: 1 }} />
        <NavBtn
          label="Anterior"
          icon={Icons.chevron_left}
          onClick={() => setCursor((c) => addDays(c, -TOTAL_DAYS))}
        />
        <NavBtn
          label="Hoje"
          onClick={() => setCursor(todayStart())}
        />
        <NavBtn
          label="Próximo"
          icon={Icons.chevron_right}
          onClick={() => setCursor((c) => addDays(c, TOTAL_DAYS))}
          iconRight
        />
      </div>

      <GlassCard style={{ padding: 0, overflowX: 'auto' }}>
        <div style={{ minWidth: 900 }}>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: `200px repeat(${TOTAL_DAYS}, 1fr)`,
              borderBottom: '1px solid var(--glass-border)',
            }}
          >
            <div className="mono" style={{ padding: 14, color: 'var(--fg-3)', fontSize: 11 }}>
              PROJETO
            </div>
            {days.map((d, i) => {
              const isToday = d.getTime() === today.getTime()
              return (
                <div
                  key={i}
                  style={{
                    padding: '10px 0',
                    textAlign: 'center',
                    borderLeft: '1px solid var(--glass-border)',
                    background: isToday
                      ? 'color-mix(in oklch, var(--fg-0) 5%, transparent)'
                      : 'transparent',
                  }}
                >
                  <div
                    className="mono"
                    style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.08 }}
                  >
                    {WEEKDAY_FMT.format(d).replace('.', '')}
                  </div>
                  <div
                    style={{
                      fontSize: 15,
                      color: isToday ? 'var(--accent-cyan)' : 'var(--fg-0)',
                      fontWeight: 500,
                      marginTop: 2,
                    }}
                  >
                    {String(d.getDate()).padStart(2, '0')}
                  </div>
                  <div className="mono" style={{ fontSize: 9, color: 'var(--fg-3)' }}>
                    {MONTH_FMT.format(d).replace('.', '')}
                  </div>
                </div>
              )
            })}
          </div>

          {rows.length === 0 && (
            <div style={{ padding: 40, textAlign: 'center', color: 'var(--fg-2)', fontSize: 13 }}>
              Nenhum projeto na janela atual.
            </div>
          )}

          {rows.map(({ projeto, offset, duration }) => {
            const color = statusColor(projeto.status)
            return (
              <div
                key={projeto.id}
                style={{
                  display: 'grid',
                  gridTemplateColumns: `200px repeat(${TOTAL_DAYS}, 1fr)`,
                  borderBottom: '1px solid var(--glass-border)',
                  height: 76,
                  position: 'relative',
                }}
              >
                <div style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 10 }}>
                  <Ring value={projeto.readiness_pct} size={30} stroke={3} decorative />
                  <div style={{ minWidth: 0 }}>
                    <div
                      style={{
                        fontSize: 12,
                        fontWeight: 500,
                        color: 'var(--fg-0)',
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                      }}
                    >
                      {projeto.nome}
                    </div>
                    <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)' }}>
                      {projeto.itens_total} itens
                    </div>
                  </div>
                </div>
                {days.map((_, j) => (
                  <div key={j} style={{ borderLeft: '1px solid var(--glass-border)' }} />
                ))}
                <div
                  style={{
                    position: 'absolute',
                    top: 18,
                    height: 40,
                    left: `calc(200px + (100% - 200px) / ${TOTAL_DAYS} * ${offset})`,
                    width: `calc((100% - 200px) / ${TOTAL_DAYS} * ${duration})`,
                    borderRadius: 12,
                    padding: '0 14px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 10,
                    background: `color-mix(in oklch, ${color} 22%, transparent)`,
                    border: `1px solid color-mix(in oklch, ${color} 40%, transparent)`,
                    backdropFilter: 'blur(10px)',
                    WebkitBackdropFilter: 'blur(10px)',
                    boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.15)',
                    minWidth: 0,
                  }}
                >
                  <StatusDot color={color} size={6} />
                  <span
                    style={{
                      fontSize: 12,
                      color: 'var(--fg-0)',
                      fontWeight: 500,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {projeto.nome}
                  </span>
                </div>
              </div>
            )
          })}
        </div>
      </GlassCard>
    </div>
  )
}

function NavBtn({
  label,
  icon,
  iconRight,
  onClick,
}: {
  label: string
  icon?: React.ReactNode
  iconRight?: boolean
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      title={label}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: icon && !label.includes('Hoje') ? '6px 10px' : '6px 12px',
        borderRadius: 999,
        border: '1px solid var(--glass-border)',
        background: 'transparent',
        color: 'var(--fg-1)',
        fontFamily: 'inherit',
        fontSize: 11,
        cursor: 'pointer',
        transition: 'background var(--motion-fast), color var(--motion-fast)',
      }}
    >
      {icon && !iconRight && icon}
      <span>{label}</span>
      {icon && iconRight && icon}
    </button>
  )
}
