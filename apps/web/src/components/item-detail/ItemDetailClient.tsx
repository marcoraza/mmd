'use client'

import Link from 'next/link'
import { useMemo, useState } from 'react'
import { GlassCard, Sparkline } from '@/components/mmd/Primitives'
import {
  CICLO_LABEL,
  SITUACAO_COLOR,
  SITUACAO_LABEL,
  formatBRL,
} from '@/components/catalog/helpers'
import type {
  CatalogItem,
  MovimentacaoTimeline,
  SerialRow,
} from '@/lib/data/items'
import { ItemHeroStrip } from './ItemHeroStrip'
import { UnitCard } from './UnitCard'
import { UnitDrawer } from './UnitDrawer'
import { TimelineStream } from './TimelineStream'
import { KpiCard } from './KpiCard'
import { ConditionHistogram } from './ConditionHistogram'
import {
  ESTADO_FATOR,
  ESTADO_LABEL,
  TIPO_COR,
  TIPO_LABEL,
  dominantEstado,
  relativeDays,
} from './helpers'
import type { Estado, StatusSerial, TipoMovimentacao } from '@/lib/types'

type Tab = 'unidades' | 'historico' | 'financas' | 'saude'

type Props = {
  item: CatalogItem
  serials: SerialRow[]
  timeline: MovimentacaoTimeline[]
  notas: string | null
}

const TABS: { id: Tab; label: string; hint: string }[] = [
  { id: 'unidades', label: 'Unidades', hint: 'onde estão' },
  { id: 'historico', label: 'Histórico', hint: 'como foi usado' },
  { id: 'financas', label: 'Finanças', hint: 'quanto vale' },
  { id: 'saude', label: 'Saúde', hint: 'o que precisa atenção' },
]

export function ItemDetailClient({ item, serials, timeline, notas }: Props) {
  const [tab, setTab] = useState<Tab>('unidades')
  const [openSerial, setOpenSerial] = useState<SerialRow | null>(null)

  return (
    <>
      <ItemHeroStrip
        item={item}
        serialsCount={serials.length}
        serialEstados={serials}
      />

      <div
        role="tablist"
        aria-label="Seções do item"
        style={{
          display: 'flex',
          gap: 4,
          marginTop: 18,
          marginBottom: 16,
          padding: 4,
          borderRadius: 12,
          background: 'var(--glass-bg)',
          border: '1px solid var(--glass-border)',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          width: 'fit-content',
        }}
      >
        {TABS.map((t) => {
          const active = tab === t.id
          return (
            <button
              key={t.id}
              role="tab"
              aria-selected={active}
              onClick={() => setTab(t.id)}
              style={{
                padding: '8px 16px',
                borderRadius: 8,
                border: 'none',
                background: active ? 'var(--glass-bg-strong)' : 'transparent',
                color: active ? 'var(--fg-0)' : 'var(--fg-2)',
                fontFamily: 'inherit',
                fontSize: 13,
                fontWeight: active ? 500 : 400,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'baseline',
                gap: 8,
                transition: 'background var(--motion-fast), color var(--motion-fast)',
                boxShadow: active ? 'inset 0 0 0 1px var(--glass-border-strong)' : 'none',
              }}
            >
              <span>{t.label}</span>
              <span
                className="mono"
                style={{
                  fontSize: 10,
                  color: active ? 'var(--accent-cyan)' : 'var(--fg-3)',
                  letterSpacing: 0.08,
                }}
              >
                {t.hint}
              </span>
            </button>
          )
        })}
      </div>

      {tab === 'unidades' && (
        <TabUnits
          serials={serials}
          onOpenSerial={setOpenSerial}
        />
      )}
      {tab === 'historico' && (
        <TabHistory timeline={timeline} />
      )}
      {tab === 'financas' && (
        <TabFinance item={item} serials={serials} />
      )}
      {tab === 'saude' && (
        <TabHealth item={item} serials={serials} timeline={timeline} onOpenSerial={setOpenSerial} />
      )}

      {notas && (
        <div style={{ marginTop: 18 }}>
          <GlassCard style={{ padding: 18 }}>
            <div
              className="mono"
              style={{
                fontSize: 10,
                color: 'var(--accent-cyan)',
                letterSpacing: 0.12,
                textTransform: 'uppercase',
                marginBottom: 8,
              }}
            >
              Notas do tipo
            </div>
            <div
              style={{
                fontSize: 12,
                color: 'var(--fg-1)',
                whiteSpace: 'pre-wrap',
                lineHeight: 1.5,
              }}
            >
              {notas}
            </div>
          </GlassCard>
        </div>
      )}

      <UnitDrawer
        serial={openSerial}
        itemName={item.nome}
        onClose={() => setOpenSerial(null)}
      />
    </>
  )
}

/* ══════════════════════════════════════════════════════════════
   Tab: Unidades
   ══════════════════════════════════════════════════════════════ */

type UnitFilter = 'todos' | 'disponivel' | 'campo' | 'manutencao' | 'criticos'

function TabUnits({
  serials,
  onOpenSerial,
}: {
  serials: SerialRow[]
  onOpenSerial: (s: SerialRow) => void
}) {
  const [filter, setFilter] = useState<UnitFilter>('todos')

  const filtered = useMemo(() => {
    switch (filter) {
      case 'disponivel':
        return serials.filter((s) => s.status === 'DISPONIVEL')
      case 'campo':
        return serials.filter((s) => s.status === 'EM_CAMPO' || s.status === 'PACKED')
      case 'manutencao':
        return serials.filter((s) => s.status === 'MANUTENCAO')
      case 'criticos':
        return serials.filter((s) => s.desgaste <= 2)
      default:
        return serials
    }
  }, [serials, filter])

  const counts = useMemo(() => {
    return {
      todos: serials.length,
      disponivel: serials.filter((s) => s.status === 'DISPONIVEL').length,
      campo: serials.filter((s) => s.status === 'EM_CAMPO' || s.status === 'PACKED').length,
      manutencao: serials.filter((s) => s.status === 'MANUTENCAO').length,
      criticos: serials.filter((s) => s.desgaste <= 2).length,
    }
  }, [serials])

  const chips: { id: UnitFilter; label: string; color?: string }[] = [
    { id: 'todos', label: 'Todos' },
    { id: 'disponivel', label: 'Disponíveis', color: 'var(--accent-green)' },
    { id: 'campo', label: 'Em campo', color: 'var(--accent-cyan)' },
    { id: 'manutencao', label: 'Manutenção', color: 'var(--accent-amber)' },
    { id: 'criticos', label: 'Críticos', color: 'var(--accent-red)' },
  ]

  return (
    <div>
      <div
        style={{
          display: 'flex',
          gap: 8,
          marginBottom: 14,
          flexWrap: 'wrap',
        }}
      >
        {chips.map((c) => {
          const active = filter === c.id
          const count = counts[c.id]
          return (
            <button
              key={c.id}
              onClick={() => setFilter(c.id)}
              disabled={count === 0 && c.id !== 'todos'}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 8,
                padding: '6px 12px',
                borderRadius: 8,
                border: '1px solid',
                borderColor: active
                  ? (c.color ?? 'var(--accent-cyan)')
                  : 'var(--glass-border)',
                background: active
                  ? `color-mix(in oklch, ${c.color ?? 'var(--accent-cyan)'} 16%, transparent)`
                  : 'var(--glass-bg)',
                color: active ? (c.color ?? 'var(--accent-cyan)') : 'var(--fg-1)',
                fontFamily: 'inherit',
                fontSize: 12,
                fontWeight: 500,
                cursor: count === 0 && c.id !== 'todos' ? 'not-allowed' : 'pointer',
                opacity: count === 0 && c.id !== 'todos' ? 0.4 : 1,
              }}
            >
              <span>{c.label}</span>
              <span
                className="mono"
                style={{
                  fontSize: 10,
                  color: active ? 'inherit' : 'var(--fg-3)',
                  opacity: 0.8,
                }}
              >
                {count}
              </span>
            </button>
          )
        })}
      </div>

      {filtered.length === 0 ? (
        <GlassCard style={{ padding: 32, textAlign: 'center' }}>
          <div style={{ fontSize: 13, color: 'var(--fg-3)' }}>
            Nenhuma unidade nesse filtro.
          </div>
        </GlassCard>
      ) : (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))',
            gap: 12,
          }}
        >
          {filtered.map((s) => (
            <UnitCard
              key={s.id}
              serial={s}
              onOpen={() => onOpenSerial(s)}
              onPrintQr={() => {
                // QR print stub; integrate real flow later
              }}
            />
          ))}
        </div>
      )}
    </div>
  )
}

/* ══════════════════════════════════════════════════════════════
   Tab: Histórico
   ══════════════════════════════════════════════════════════════ */

type TipoFilter = 'todos' | TipoMovimentacao

function TabHistory({ timeline }: { timeline: MovimentacaoTimeline[] }) {
  const [filter, setFilter] = useState<TipoFilter>('todos')

  const filtered = useMemo(
    () => (filter === 'todos' ? timeline : timeline.filter((e) => e.tipo === filter)),
    [timeline, filter],
  )

  const counts = useMemo(() => {
    const base: Record<TipoFilter, number> = {
      todos: timeline.length,
      SAIDA: 0,
      RETORNO: 0,
      MANUTENCAO: 0,
      TRANSFERENCIA: 0,
      DANO: 0,
    }
    for (const e of timeline) base[e.tipo] = (base[e.tipo] ?? 0) + 1
    return base
  }, [timeline])

  const ultimaManut = useMemo(() => {
    const m = timeline.find((e) => e.tipo === 'MANUTENCAO')
    return m ? relativeDays(m.timestamp) : null
  }, [timeline])

  const chips: { id: TipoFilter; label: string; color?: string }[] = [
    { id: 'todos', label: 'Todos' },
    { id: 'SAIDA', label: TIPO_LABEL.SAIDA, color: TIPO_COR.SAIDA },
    { id: 'RETORNO', label: TIPO_LABEL.RETORNO, color: TIPO_COR.RETORNO },
    { id: 'MANUTENCAO', label: TIPO_LABEL.MANUTENCAO, color: TIPO_COR.MANUTENCAO },
    { id: 'TRANSFERENCIA', label: TIPO_LABEL.TRANSFERENCIA, color: TIPO_COR.TRANSFERENCIA },
    { id: 'DANO', label: TIPO_LABEL.DANO, color: TIPO_COR.DANO },
  ]

  return (
    <div>
      <GlassCard style={{ padding: 16, marginBottom: 14 }}>
        <div
          className="mono"
          style={{
            fontSize: 10,
            color: 'var(--accent-cyan)',
            letterSpacing: 0.12,
            textTransform: 'uppercase',
            marginBottom: 8,
          }}
        >
          Uso acumulado
        </div>
        <div
          style={{
            display: 'flex',
            gap: 18,
            flexWrap: 'wrap',
            alignItems: 'baseline',
            fontSize: 13,
            color: 'var(--fg-1)',
          }}
        >
          <Aggregate color={TIPO_COR.SAIDA} n={counts.SAIDA} label="saídas" />
          <Aggregate color={TIPO_COR.RETORNO} n={counts.RETORNO} label="retornos" />
          <Aggregate color={TIPO_COR.MANUTENCAO} n={counts.MANUTENCAO} label="manutenções" />
          <Aggregate color={TIPO_COR.DANO} n={counts.DANO} label="danos" />
          {ultimaManut && (
            <span style={{ color: 'var(--fg-3)', fontSize: 12 }}>
              última manutenção {ultimaManut}
            </span>
          )}
        </div>
      </GlassCard>

      <div
        style={{
          display: 'flex',
          gap: 6,
          marginBottom: 14,
          flexWrap: 'wrap',
        }}
      >
        {chips.map((c) => {
          const active = filter === c.id
          const count = counts[c.id]
          return (
            <button
              key={c.id}
              onClick={() => setFilter(c.id)}
              disabled={count === 0 && c.id !== 'todos'}
              style={{
                padding: '5px 10px',
                borderRadius: 6,
                border: '1px solid',
                borderColor: active ? (c.color ?? 'var(--accent-cyan)') : 'var(--glass-border)',
                background: active
                  ? `color-mix(in oklch, ${c.color ?? 'var(--accent-cyan)'} 14%, transparent)`
                  : 'transparent',
                color: active ? (c.color ?? 'var(--accent-cyan)') : 'var(--fg-2)',
                fontFamily: 'inherit',
                fontSize: 11,
                cursor: count === 0 && c.id !== 'todos' ? 'not-allowed' : 'pointer',
                opacity: count === 0 && c.id !== 'todos' ? 0.35 : 1,
              }}
            >
              {c.label}
              <span className="mono" style={{ fontSize: 10, marginLeft: 6, opacity: 0.7 }}>
                {count}
              </span>
            </button>
          )
        })}
      </div>

      <GlassCard style={{ padding: 20 }}>
        <TimelineStream events={filtered} />
      </GlassCard>
    </div>
  )
}

function Aggregate({ color, n, label }: { color: string; n: number; label: string }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'baseline', gap: 4 }}>
      <span
        className="mono"
        style={{
          fontSize: 18,
          color,
          fontWeight: 500,
          fontFamily: 'var(--font-mono-raw)',
        }}
      >
        {n}
      </span>
      <span style={{ fontSize: 11, color: 'var(--fg-3)' }}>{label}</span>
    </span>
  )
}

/* ══════════════════════════════════════════════════════════════
   Tab: Finanças
   ══════════════════════════════════════════════════════════════ */

function TabFinance({ item, serials }: { item: CatalogItem; serials: SerialRow[] }) {
  const valorUnit = item.valor_mercado_unitario ?? 0
  const valorOriginalTotal = valorUnit * serials.length
  const valorAtualTotal = item.valor_atual_total
  const perda = valorOriginalTotal - valorAtualTotal
  const perdaPct = valorOriginalTotal > 0 ? (perda / valorOriginalTotal) * 100 : 0
  const valorMedioUnit = serials.length > 0 ? valorAtualTotal / serials.length : 0
  const estado = dominantEstado(serials)
  const fator = estado ? ESTADO_FATOR[estado] : null

  const sparkData = useMemo(() => {
    if (valorOriginalTotal === 0) return []
    const months = 12
    const arr: number[] = []
    const finalValue = valorAtualTotal
    for (let i = 0; i < months; i++) {
      const t = i / (months - 1)
      const easing = 1 - Math.pow(1 - t, 1.4)
      arr.push(valorOriginalTotal + (finalValue - valorOriginalTotal) * easing)
    }
    return arr
  }, [valorOriginalTotal, valorAtualTotal])

  const sortedSerials = useMemo(
    () =>
      [...serials].sort((a, b) => {
        const orig = valorUnit
        const aAtual = a.valor_atual ?? 0
        const bAtual = b.valor_atual ?? 0
        const aDelta = orig > 0 ? (aAtual - orig) / orig : 0
        const bDelta = orig > 0 ? (bAtual - orig) / orig : 0
        return aDelta - bDelta
      }),
    [serials, valorUnit],
  )

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12,
        }}
      >
        <KpiCard
          label="Valor original total"
          value={formatBRL(valorOriginalTotal)}
          hint={`${serials.length} × ${formatBRL(valorUnit)}`}
          accent="var(--fg-2)"
        />
        <KpiCard
          label="Valor atual total"
          value={formatBRL(valorAtualTotal)}
          hint={`média ${formatBRL(valorMedioUnit)} por unidade`}
          accent="var(--accent-cyan)"
        />
        <KpiCard
          label="Perda acumulada"
          value={formatBRL(perda)}
          hint={`${perdaPct.toFixed(1)}%`}
          accent="var(--accent-red)"
          trend="down"
        />
        <KpiCard
          label="Retenção"
          value={`${(100 - perdaPct).toFixed(0)}%`}
          hint={fator != null ? `fator estado ${fator.toFixed(2)}` : 'sem estado dominante'}
          accent="var(--accent-green)"
        />
      </div>

      <GlassCard style={{ padding: 18 }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: 10,
          }}
        >
          <div
            className="mono"
            style={{
              fontSize: 10,
              color: 'var(--accent-cyan)',
              letterSpacing: 0.12,
              textTransform: 'uppercase',
            }}
          >
            Tendência, 12 meses
          </div>
          <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
            simulação linear
          </div>
        </div>
        {sparkData.length > 0 ? (
          <Sparkline data={sparkData} width={720} height={60} color="var(--accent-cyan)" />
        ) : (
          <div style={{ fontSize: 12, color: 'var(--fg-3)' }}>
            Sem valor de referência para calcular tendência.
          </div>
        )}
      </GlassCard>

      <GlassCard style={{ padding: 18 }}>
        <div
          className="mono"
          style={{
            fontSize: 10,
            color: 'var(--accent-cyan)',
            letterSpacing: 0.12,
            textTransform: 'uppercase',
            marginBottom: 10,
          }}
        >
          Valor por unidade
        </div>
        {sortedSerials.length === 0 ? (
          <div style={{ fontSize: 12, color: 'var(--fg-3)' }}>Sem seriais cadastrados.</div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
              <thead>
                <tr style={{ textAlign: 'left', color: 'var(--fg-3)' }}>
                  <Th>Código</Th>
                  <Th>Estado</Th>
                  <Th>Desgaste</Th>
                  <Th align="right">Original</Th>
                  <Th align="right">Atual</Th>
                  <Th align="right">Δ</Th>
                </tr>
              </thead>
              <tbody>
                {sortedSerials.map((s) => {
                  const orig = valorUnit
                  const atual = s.valor_atual ?? 0
                  const delta = orig > 0 ? ((atual - orig) / orig) * 100 : 0
                  const deltaColor =
                    delta < -50
                      ? 'var(--accent-red)'
                      : delta < -20
                        ? 'var(--accent-amber)'
                        : 'var(--fg-2)'
                  return (
                    <tr key={s.id} style={{ borderTop: '1px solid var(--glass-border)' }}>
                      <Td mono>{s.codigo_interno}</Td>
                      <Td>{CICLO_LABEL[s.estado]}</Td>
                      <Td mono>{s.desgaste}/5</Td>
                      <Td mono align="right">{formatBRL(orig || null)}</Td>
                      <Td mono align="right">{formatBRL(atual || null)}</Td>
                      <Td mono align="right" color={deltaColor}>
                        {delta.toFixed(1)}%
                      </Td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </GlassCard>

      {fator != null && estado && (
        <div
          className="mono"
          style={{
            fontSize: 11,
            color: 'var(--fg-3)',
            padding: 14,
            background: 'rgba(0,0,0,0.2)',
            borderRadius: 10,
            lineHeight: 1.6,
            border: '1px solid var(--glass-border)',
          }}
        >
          valor_atual = valor_original × (desgaste / 5) × fator({ESTADO_LABEL[estado]}:{' '}
          {fator.toFixed(2)})
          <br />
          aplicado por unidade, somado para total do tipo.
        </div>
      )}
    </div>
  )
}

/* ══════════════════════════════════════════════════════════════
   Tab: Saúde
   ══════════════════════════════════════════════════════════════ */

function TabHealth({
  item,
  serials,
  timeline,
  onOpenSerial,
}: {
  item: CatalogItem
  serials: SerialRow[]
  timeline: MovimentacaoTimeline[]
  onOpenSerial: (s: SerialRow) => void
}) {
  const criticos = useMemo(
    () => serials.filter((s) => s.desgaste <= 2).sort((a, b) => a.desgaste - b.desgaste),
    [serials],
  )

  const estadoCounts = useMemo(() => {
    const counts: Record<Estado, number> = {
      NOVO: 0,
      SEMI_NOVO: 0,
      USADO: 0,
      RECONDICIONADO: 0,
    }
    for (const s of serials) counts[s.estado] = (counts[s.estado] ?? 0) + 1
    return counts
  }, [serials])

  const ativos = item.disponivel_count + item.em_campo_count + item.manutencao_count
  const utilizacao = ativos > 0 ? (item.em_campo_count / ativos) * 100 : 0

  const ultimaSaida = timeline.find((e) => e.tipo === 'SAIDA')
  const ultimaManut = timeline.find((e) => e.tipo === 'MANUTENCAO')

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr)',
        gap: 14,
      }}
    >
      <GlassCard style={{ padding: 18 }}>
        <div
          className="mono"
          style={{
            fontSize: 10,
            color: 'var(--accent-cyan)',
            letterSpacing: 0.12,
            textTransform: 'uppercase',
            marginBottom: 14,
          }}
        >
          Distribuição de desgaste
        </div>
        <ConditionHistogram serials={serials} />
      </GlassCard>

      <GlassCard style={{ padding: 18 }}>
        <div
          className="mono"
          style={{
            fontSize: 10,
            color: 'var(--accent-cyan)',
            letterSpacing: 0.12,
            textTransform: 'uppercase',
            marginBottom: 14,
          }}
        >
          Ciclo de vida
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {(['NOVO', 'SEMI_NOVO', 'USADO', 'RECONDICIONADO'] as Estado[]).map((e) => {
            const n = estadoCounts[e]
            const pct = serials.length > 0 ? (n / serials.length) * 100 : 0
            return (
              <div key={e} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div
                  style={{
                    width: 90,
                    fontSize: 11,
                    color: 'var(--fg-2)',
                    flexShrink: 0,
                  }}
                >
                  {ESTADO_LABEL[e]}
                </div>
                <div
                  style={{
                    flex: 1,
                    height: 10,
                    borderRadius: 5,
                    background: 'var(--glass-border)',
                    overflow: 'hidden',
                  }}
                >
                  <div
                    style={{
                      width: `${pct}%`,
                      height: '100%',
                      background: 'var(--accent-violet)',
                      opacity: n > 0 ? 1 : 0.15,
                    }}
                  />
                </div>
                <span
                  className="mono"
                  style={{
                    fontSize: 11,
                    color: n > 0 ? 'var(--fg-0)' : 'var(--fg-3)',
                    width: 28,
                    textAlign: 'right',
                    flexShrink: 0,
                  }}
                >
                  {n}
                </span>
              </div>
            )
          })}
        </div>
      </GlassCard>

      <GlassCard style={{ padding: 18, gridColumn: '1 / -1' }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: 12,
          }}
        >
          <div
            className="mono"
            style={{
              fontSize: 10,
              color: 'var(--accent-red)',
              letterSpacing: 0.12,
              textTransform: 'uppercase',
            }}
          >
            Unidades críticas, {criticos.length}
          </div>
          <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
            desgaste ≤ 2
          </div>
        </div>

        {criticos.length === 0 ? (
          <div
            style={{
              padding: 20,
              textAlign: 'center',
              fontSize: 12,
              color: 'var(--accent-green)',
              background: 'color-mix(in oklch, var(--accent-green) 8%, transparent)',
              border: '1px solid color-mix(in oklch, var(--accent-green) 24%, transparent)',
              borderRadius: 10,
            }}
          >
            ✓ Nenhuma unidade crítica. Estoque saudável.
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {criticos.map((s) => (
              <div
                key={s.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: 12,
                  padding: '10px 12px',
                  borderRadius: 8,
                  background: 'var(--glass-bg)',
                  border: '1px solid var(--glass-border)',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
                  <span
                    className="mono"
                    style={{
                      fontSize: 10,
                      color: 'var(--accent-red)',
                      padding: '2px 6px',
                      borderRadius: 4,
                      background: 'color-mix(in oklch, var(--accent-red) 14%, transparent)',
                      border: '1px solid color-mix(in oklch, var(--accent-red) 30%, transparent)',
                    }}
                  >
                    {s.desgaste}/5
                  </span>
                  <span className="mono" style={{ fontSize: 12, color: 'var(--fg-0)' }}>
                    {s.codigo_interno}
                  </span>
                  <span style={{ fontSize: 11, color: SITUACAO_COLOR[s.status as StatusSerial] }}>
                    {SITUACAO_LABEL[s.status as StatusSerial]}
                  </span>
                  {s.localizacao && (
                    <span
                      className="mono"
                      style={{
                        fontSize: 10,
                        color: 'var(--fg-3)',
                        letterSpacing: 0.08,
                      }}
                    >
                      {s.localizacao}
                    </span>
                  )}
                </div>
                <div style={{ display: 'flex', gap: 6 }}>
                  <button
                    onClick={() => onOpenSerial(s)}
                    style={{
                      padding: '5px 10px',
                      borderRadius: 6,
                      border: '1px solid var(--glass-border)',
                      background: 'transparent',
                      color: 'var(--fg-2)',
                      fontSize: 11,
                      fontFamily: 'inherit',
                      cursor: 'pointer',
                    }}
                  >
                    Detalhes
                  </button>
                  <button
                    style={{
                      padding: '5px 10px',
                      borderRadius: 6,
                      border: '1px solid color-mix(in oklch, var(--accent-amber) 40%, transparent)',
                      background: 'color-mix(in oklch, var(--accent-amber) 14%, transparent)',
                      color: 'var(--accent-amber)',
                      fontSize: 11,
                      fontFamily: 'inherit',
                      cursor: 'pointer',
                    }}
                  >
                    Marcar manutenção
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </GlassCard>

      <GlassCard style={{ padding: 18, gridColumn: '1 / -1' }}>
        <div
          className="mono"
          style={{
            fontSize: 10,
            color: 'var(--accent-cyan)',
            letterSpacing: 0.12,
            textTransform: 'uppercase',
            marginBottom: 12,
          }}
        >
          Utilização
        </div>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: 14,
            fontSize: 13,
            color: 'var(--fg-1)',
          }}
        >
          <div>
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
              TAXA ATUAL
            </div>
            <div
              style={{
                fontSize: 20,
                fontFamily: 'var(--font-mono-raw)',
                color: 'var(--fg-0)',
                marginTop: 2,
              }}
            >
              {utilizacao.toFixed(0)}%
            </div>
            <div style={{ fontSize: 11, color: 'var(--fg-3)', marginTop: 2 }}>
              {item.em_campo_count} de {ativos} em campo
            </div>
          </div>
          <div>
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
              ÚLTIMA SAÍDA
            </div>
            <div style={{ fontSize: 14, color: 'var(--fg-0)', marginTop: 4 }}>
              {ultimaSaida ? relativeDays(ultimaSaida.timestamp) : 'sem histórico'}
            </div>
            {ultimaSaida?.projeto_nome && (
              <Link
                href={ultimaSaida.projeto_id ? `/projetos/${ultimaSaida.projeto_id}` : '#'}
                style={{
                  fontSize: 11,
                  color: 'var(--accent-cyan)',
                  textDecoration: 'none',
                  marginTop: 2,
                  display: 'inline-block',
                }}
              >
                {ultimaSaida.projeto_nome}
              </Link>
            )}
          </div>
          <div>
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
              ÚLTIMA MANUTENÇÃO
            </div>
            <div style={{ fontSize: 14, color: 'var(--fg-0)', marginTop: 4 }}>
              {ultimaManut ? relativeDays(ultimaManut.timestamp) : 'sem registro'}
            </div>
          </div>
        </div>
      </GlassCard>
    </div>
  )
}

/* ══════════════════════════════════════════════════════════════
   Table helpers
   ══════════════════════════════════════════════════════════════ */

function Th({
  children,
  align,
}: {
  children: React.ReactNode
  align?: 'left' | 'right'
}) {
  return (
    <th
      className="mono"
      style={{
        fontSize: 10,
        letterSpacing: 0.1,
        textTransform: 'uppercase',
        fontWeight: 500,
        padding: '8px 10px 8px 0',
        color: 'var(--fg-3)',
        textAlign: align ?? 'left',
      }}
    >
      {children}
    </th>
  )
}

function Td({
  children,
  mono,
  align,
  color,
}: {
  children: React.ReactNode
  mono?: boolean
  align?: 'left' | 'right'
  color?: string
}) {
  return (
    <td
      className={mono ? 'mono' : undefined}
      style={{
        padding: '8px 10px 8px 0',
        color: color ?? 'var(--fg-1)',
        fontSize: 12,
        verticalAlign: 'middle',
        textAlign: align ?? 'left',
      }}
    >
      {children}
    </td>
  )
}
