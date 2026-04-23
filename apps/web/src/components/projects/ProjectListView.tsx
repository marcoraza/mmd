'use client'

import { useMemo, useState } from 'react'
import { GlassCard, Ring, StatusDot, GhostBtn, PrimaryBtn } from '@/components/mmd/Primitives'
import { EditableQty } from '@/components/catalog/EditableQty'
import { Icons } from '@/components/mmd/Icons'
import type { Projeto, PackingItem, PackingStatus } from '@/lib/data/projects'
import { InlineItemPicker } from './InlineItemPicker'

const DATE_FMT = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: 'short' })

function formatDate(iso: string): string {
  const [y, m, d] = iso.split('-').map(Number)
  return DATE_FMT.format(new Date(y, m - 1, d)).replace('.', '').toLowerCase()
}

function statusLabel(s: Projeto['status']): string {
  switch (s) {
    case 'PLANEJAMENTO': return 'Planejamento'
    case 'CONFIRMADO': return 'Confirmado'
    case 'EM_CAMPO': return 'Em campo'
    case 'FINALIZADO': return 'Finalizado'
    case 'CANCELADO': return 'Cancelado'
  }
}

function statusColor(s: Projeto['status']): string {
  switch (s) {
    case 'PLANEJAMENTO': return 'var(--fg-3)'
    case 'CONFIRMADO': return 'var(--accent-cyan)'
    case 'EM_CAMPO': return 'var(--accent-violet)'
    case 'FINALIZADO': return 'var(--fg-3)'
    case 'CANCELADO': return 'var(--accent-red)'
  }
}

type SortKey = 'nome' | 'codigo' | 'categoria' | 'qtd' | 'alocado' | 'status'
type SortDir = 'asc' | 'desc'

const DEFAULT_SORT: { key: SortKey; dir: SortDir } = { key: 'nome', dir: 'asc' }

export function ProjectListView({
  projetos,
  onAddItem,
  onRemoveItem,
  onUpdateQty,
  pending,
}: {
  projetos: Projeto[]
  onAddItem: (projetoId: string, itemId: string, qtd: number) => void
  onRemoveItem: (packingId: string) => void
  onUpdateQty: (packingId: string, qtd: number) => void
  pending: boolean
}) {
  const ativos = projetos.filter((p) => p.status !== 'FINALIZADO' && p.status !== 'CANCELADO')
  const concluidos = projetos.filter((p) => p.status === 'FINALIZADO' || p.status === 'CANCELADO')
  const [selectedId, setSelectedId] = useState<string>(
    ativos[0]?.id ?? projetos[0]?.id ?? ''
  )
  const selected = projetos.find((p) => p.id === selectedId) ?? projetos[0]

  if (projetos.length === 0) {
    return (
      <GlassCard style={{ padding: 40, textAlign: 'center', color: 'var(--fg-2)' }}>
        <div style={{ fontSize: 13 }}>Nenhum projeto ainda.</div>
        <div className="mono" style={{ fontSize: 10, marginTop: 6, color: 'var(--fg-3)' }}>
          Clique em “+ Novo projeto” para criar o primeiro.
        </div>
      </GlassCard>
    )
  }

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: '320px 1fr',
        gap: 18,
        minHeight: 520,
      }}
    >
      <GlassCard style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <SectionLabel>Ativos · {ativos.length}</SectionLabel>
        {ativos.length === 0 && (
          <div style={{ fontSize: 12, color: 'var(--fg-3)', padding: 8 }}>
            Sem projetos ativos.
          </div>
        )}
        {ativos.map((p) => (
          <ProjectRow
            key={p.id}
            projeto={p}
            active={p.id === selected?.id}
            onClick={() => setSelectedId(p.id)}
          />
        ))}
        {concluidos.length > 0 && (
          <>
            <div style={{ marginTop: 12 }}>
              <SectionLabel>Concluídos · {concluidos.length}</SectionLabel>
            </div>
            {concluidos.map((p) => (
              <button
                key={p.id}
                type="button"
                onClick={() => setSelectedId(p.id)}
                style={{
                  padding: '10px 12px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  opacity: 0.55,
                  background: p.id === selected?.id ? 'var(--glass-bg-strong)' : 'transparent',
                  border: 'none',
                  borderRadius: 10,
                  cursor: 'pointer',
                  fontFamily: 'inherit',
                  textAlign: 'left',
                  color: 'inherit',
                }}
              >
                <StatusDot color="var(--fg-3)" size={6} glow={false} />
                <div style={{ flex: 1, fontSize: 12, color: 'var(--fg-1)' }}>{p.nome}</div>
                <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
                  {formatDate(p.data_inicio)}
                </div>
              </button>
            ))}
          </>
        )}
      </GlassCard>

      {selected && (
        <ProjectDetail
          projeto={selected}
          onAddItem={onAddItem}
          onRemoveItem={onRemoveItem}
          onUpdateQty={onUpdateQty}
          pending={pending}
        />
      )}
    </div>
  )
}

function ProjectDetail({
  projeto,
  onAddItem,
  onRemoveItem,
  onUpdateQty,
  pending,
}: {
  projeto: Projeto
  onAddItem: (projetoId: string, itemId: string, qtd: number) => void
  onRemoveItem: (packingId: string) => void
  onUpdateQty: (packingId: string, qtd: number) => void
  pending: boolean
}) {
  const [sort, setSort] = useState(DEFAULT_SORT)
  const [adding, setAdding] = useState(false)

  const sorted = useMemo(() => sortPacking(projeto.packing, sort), [projeto.packing, sort])

  function toggleSort(key: SortKey) {
    setSort((prev) => {
      if (prev.key !== key) return { key, dir: 'asc' }
      return { key, dir: prev.dir === 'asc' ? 'desc' : 'asc' }
    })
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14, minHeight: 0 }}>
      <GlassCard strong style={{ padding: 20 }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 20, flexWrap: 'wrap' }}>
          <div style={{ flex: 1, minWidth: 240 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4 }}>
              <StatusDot color={statusColor(projeto.status)} size={8} />
              <span
                className="mono"
                style={{
                  fontSize: 10,
                  color: 'var(--fg-2)',
                  letterSpacing: 0.1,
                  textTransform: 'uppercase',
                }}
              >
                {statusLabel(projeto.status)}
              </span>
            </div>
            <div
              style={{
                fontSize: 24,
                fontWeight: 500,
                color: 'var(--fg-0)',
                letterSpacing: -0.5,
              }}
            >
              {projeto.nome}
            </div>
            <div style={{ fontSize: 13, color: 'var(--fg-2)', marginTop: 6 }}>
              {formatDate(projeto.data_inicio)}
              {projeto.data_fim !== projeto.data_inicio
                ? ` até ${formatDate(projeto.data_fim)}`
                : ''}
              {projeto.local ? ` · ${projeto.local}` : ''}
              {projeto.cliente ? ` · ${projeto.cliente}` : ''}
            </div>
            {projeto.notas && (
              <div style={{ fontSize: 12, color: 'var(--fg-3)', marginTop: 8 }}>
                {projeto.notas}
              </div>
            )}
          </div>
          <Ring value={projeto.readiness_pct} size={90} stroke={6} label="readiness" />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            <PrimaryBtn small>Gerar QR codes</PrimaryBtn>
            <GhostBtn small>Exportar PDF</GhostBtn>
          </div>
        </div>
      </GlassCard>

      <GlassCard
        style={{
          padding: 0,
          flex: 1,
          minHeight: 0,
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 16,
            padding: '16px 20px',
            borderBottom: '1px solid var(--glass-border)',
          }}
        >
          <div style={{ fontSize: 14, fontWeight: 500 }}>Packing list</div>
          <div className="mono" style={{ fontSize: 11, color: 'var(--fg-2)' }}>
            {projeto.itens_count} itens · {projeto.itens_alocados}/{projeto.itens_total} alocados
          </div>
          <div style={{ flex: 1 }} />
          <GhostBtn small onClick={() => setAdding((v) => !v)}>
            {adding ? '× Cancelar' : '+ Adicionar item'}
          </GhostBtn>
        </div>

        <div style={{ padding: '6px 12px', overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr>
                <SortTh label="ITEM" col="nome" sort={sort} onClick={toggleSort} />
                <SortTh label="CÓDIGO" col="codigo" sort={sort} onClick={toggleSort} />
                <SortTh label="CATEGORIA" col="categoria" sort={sort} onClick={toggleSort} />
                <SortTh label="QTD" col="qtd" sort={sort} onClick={toggleSort} align="right" />
                <SortTh label="ALOCADO" col="alocado" sort={sort} onClick={toggleSort} />
                <SortTh label="STATUS" col="status" sort={sort} onClick={toggleSort} />
                <th style={{ width: 40 }} />
              </tr>
            </thead>
            <tbody>
              {sorted.map((item) => (
                <PackingRow
                  key={item.id}
                  item={item}
                  pending={pending}
                  onRemove={() => onRemoveItem(item.id)}
                  onQty={(n) => onUpdateQty(item.id, n)}
                />
              ))}
              {adding && (
                <tr>
                  <td colSpan={7} style={{ padding: '12px 12px 16px' }}>
                    <InlineItemPicker
                      onPick={(itemId, qtd) => {
                        onAddItem(projeto.id, itemId, qtd)
                        setAdding(false)
                      }}
                      pending={pending}
                    />
                  </td>
                </tr>
              )}
              {projeto.packing.length === 0 && !adding && (
                <tr>
                  <td
                    colSpan={7}
                    style={{
                      padding: 28,
                      textAlign: 'center',
                      color: 'var(--fg-3)',
                      fontSize: 12,
                    }}
                  >
                    Sem itens no packing list. Clique em “+ Adicionar item”.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </GlassCard>
    </div>
  )
}

function ProjectRow({
  projeto,
  active,
  onClick,
}: {
  projeto: Projeto
  active: boolean
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        padding: 12,
        borderRadius: 14,
        cursor: 'pointer',
        background: active ? 'var(--glass-bg-strong)' : 'transparent',
        border: active ? '1px solid var(--glass-border-strong)' : '1px solid transparent',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        fontFamily: 'inherit',
        color: 'inherit',
        textAlign: 'left',
        width: '100%',
      }}
    >
      <Ring value={projeto.readiness_pct} size={40} stroke={4} decorative />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            fontSize: 13,
            fontWeight: 500,
            color: 'var(--fg-0)',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {projeto.nome}
        </div>
        <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', marginTop: 2 }}>
          {formatDate(projeto.data_inicio)} · {projeto.itens_total} itens
        </div>
      </div>
    </button>
  )
}

const STATUS_META: Record<
  PackingStatus,
  { color: string; label: (i: PackingItem) => string }
> = {
  ok: { color: 'var(--accent-green)', label: () => 'Pronto' },
  partial: {
    color: 'var(--accent-amber)',
    label: (i) => `${i.qtd_alocada}/${i.qtd_necessaria}`,
  },
  missing: { color: 'var(--accent-red)', label: () => 'Faltando' },
  conflict: { color: 'var(--accent-red)', label: () => 'Conflito' },
}

function PackingRow({
  item,
  pending,
  onRemove,
  onQty,
}: {
  item: PackingItem
  pending: boolean
  onRemove: () => void
  onQty: (n: number) => void
}) {
  const meta = STATUS_META[item.status]
  const pct =
    item.qtd_necessaria > 0 ? (item.qtd_alocada / item.qtd_necessaria) * 100 : 0
  const conflictTitle =
    item.status === 'conflict' && item.conflicts_with
      ? `Também em: ${item.conflicts_with.map((c) => c.projeto_nome).join(', ')}`
      : undefined

  return (
    <tr style={{ borderTop: '1px solid var(--glass-border)' }}>
      <td style={{ padding: 12, color: 'var(--fg-0)', fontWeight: 500 }}>{item.nome}</td>
      <td style={{ padding: 12 }} className="mono">
        <span style={{ fontSize: 11, color: 'var(--fg-2)' }}>{item.codigo_interno}</span>
      </td>
      <td style={{ padding: 12, color: 'var(--fg-1)' }}>{item.categoria}</td>
      <td style={{ padding: '8px 12px', textAlign: 'right' }}>
        <EditableQty value={item.qtd_necessaria} pending={pending} onChange={onQty} />
      </td>
      <td style={{ padding: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div
            style={{
              width: 60,
              height: 4,
              borderRadius: 2,
              background: 'var(--glass-border)',
              overflow: 'hidden',
            }}
          >
            <div style={{ width: `${pct}%`, height: '100%', background: meta.color }} />
          </div>
          <span className="mono" style={{ fontSize: 11, color: 'var(--fg-2)' }}>
            {item.qtd_alocada}/{item.qtd_necessaria}
          </span>
        </div>
      </td>
      <td style={{ padding: 12 }}>
        <span
          title={conflictTitle}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
            fontSize: 11,
            color: meta.color,
            fontWeight: 500,
            padding: '3px 10px',
            borderRadius: 999,
            background: `color-mix(in oklch, ${meta.color} 15%, transparent)`,
            border: `1px solid color-mix(in oklch, ${meta.color} 30%, transparent)`,
            cursor: conflictTitle ? 'help' : 'default',
          }}
        >
          <StatusDot color={meta.color} size={6} glow={false} /> {meta.label(item)}
        </span>
      </td>
      <td style={{ padding: 12, color: 'var(--fg-3)', width: 40, textAlign: 'right' }}>
        <button
          type="button"
          aria-label={`Remover ${item.nome}`}
          disabled={pending}
          onClick={onRemove}
          style={{
            background: 'transparent',
            border: 'none',
            color: 'var(--fg-3)',
            fontSize: 16,
            cursor: pending ? 'wait' : 'pointer',
            padding: 4,
          }}
        >
          ×
        </button>
      </td>
    </tr>
  )
}

function SortTh({
  label,
  col,
  sort,
  onClick,
  align = 'left',
}: {
  label: string
  col: SortKey
  sort: { key: SortKey; dir: SortDir }
  onClick: (k: SortKey) => void
  align?: 'left' | 'right'
}) {
  const active = sort.key === col
  return (
    <th
      style={{
        fontSize: 10,
        fontWeight: 400,
        letterSpacing: 0.08,
        textAlign: align,
        padding: '10px 12px',
        color: 'var(--fg-3)',
      }}
      aria-sort={active ? (sort.dir === 'asc' ? 'ascending' : 'descending') : 'none'}
    >
      <button
        type="button"
        onClick={() => onClick(col)}
        className="mono"
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 4,
          background: 'transparent',
          border: 'none',
          padding: 0,
          color: active ? 'var(--fg-0)' : 'var(--fg-3)',
          fontFamily: 'inherit',
          fontSize: 10,
          letterSpacing: 0.08,
          textTransform: 'uppercase',
          cursor: 'pointer',
          transition: 'color var(--motion-fast)',
        }}
      >
        {label}
        <span
          aria-hidden
          style={{
            display: 'inline-block',
            width: 10,
            opacity: active ? 1 : 0.3,
            fontSize: 9,
            transform:
              active && sort.dir === 'desc' ? 'rotate(180deg)' : 'rotate(0deg)',
            transition: 'transform var(--motion-fast)',
          }}
        >
          {Icons.caretUp}
        </span>
      </button>
    </th>
  )
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <div
      className="mono"
      style={{
        fontSize: 10,
        color: 'var(--fg-3)',
        letterSpacing: 0.1,
        textTransform: 'uppercase',
      }}
    >
      {children}
    </div>
  )
}

function sortPacking(
  items: PackingItem[],
  sort: { key: SortKey; dir: SortDir }
): PackingItem[] {
  const factor = sort.dir === 'asc' ? 1 : -1
  const STATUS_ORDER: Record<PackingStatus, number> = {
    conflict: 0,
    missing: 1,
    partial: 2,
    ok: 3,
  }
  return [...items].sort((a, b) => {
    switch (sort.key) {
      case 'nome':
        return a.nome.localeCompare(b.nome, 'pt-BR') * factor
      case 'codigo':
        return a.codigo_interno.localeCompare(b.codigo_interno, 'pt-BR') * factor
      case 'categoria':
        return a.categoria.localeCompare(b.categoria, 'pt-BR') * factor
      case 'qtd':
        return (a.qtd_necessaria - b.qtd_necessaria) * factor
      case 'alocado':
        return (a.qtd_alocada - b.qtd_alocada) * factor
      case 'status':
        return (STATUS_ORDER[a.status] - STATUS_ORDER[b.status]) * factor
    }
  })
}
