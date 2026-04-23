'use client'

import Link from 'next/link'
import { useMemo } from 'react'
import { Icons } from '@/components/mmd/Icons'
import { StatusDot } from '@/components/mmd/Primitives'
import { CATEGORIA_LABEL } from '@/components/catalog/helpers'
import type { LoteRow } from '@/lib/data/lotes'
import { STATUS_LOTE_COLOR, STATUS_LOTE_LABEL } from './helpers'

export type LotesSortKey =
  | 'codigo'
  | 'item'
  | 'descricao'
  | 'quantidade'
  | 'status'
  | 'atualizado'
export type LotesSortDir = 'asc' | 'desc'
export type LotesGroupBy = 'none' | 'categoria' | 'item' | 'status'

type Props = {
  lotes: LoteRow[]
  sortKey: LotesSortKey
  sortDir: LotesSortDir
  groupBy: LotesGroupBy
  onSort: (key: LotesSortKey) => void
}

const GRID = '150px 120px minmax(200px, 1fr) minmax(180px, 1fr) 100px 130px 110px 110px'

export function LotesTable({ lotes, sortKey, sortDir, groupBy, onSort }: Props) {
  const sorted = useMemo(() => sortLotes(lotes, sortKey, sortDir), [lotes, sortKey, sortDir])
  const groups = useMemo(() => groupLotes(sorted, groupBy), [sorted, groupBy])

  if (lotes.length === 0) {
    return (
      <div
        className="glass"
        style={{
          padding: '40px 24px',
          textAlign: 'center',
          color: 'var(--fg-2)',
        }}
      >
        Nenhum lote encontrado com os filtros atuais.
      </div>
    )
  }

  return (
    <div className="glass" style={{ borderRadius: 'var(--r-lg)', overflow: 'hidden' }}>
      <HeaderRow sortKey={sortKey} sortDir={sortDir} onSort={onSort} />
      <div style={{ maxHeight: 640, overflowY: 'auto' }}>
        {groupBy === 'none'
          ? sorted.map((l) => <LoteRowView key={l.id} lote={l} />)
          : groups.map((g) => (
              <GroupSection key={g.key} title={g.title} count={g.items.length} lotes={g.items} />
            ))}
      </div>
    </div>
  )
}

function HeaderRow({
  sortKey,
  sortDir,
  onSort,
}: {
  sortKey: LotesSortKey
  sortDir: LotesSortDir
  onSort: (k: LotesSortKey) => void
}) {
  return (
    <div
      className="mono"
      style={{
        display: 'grid',
        gridTemplateColumns: GRID,
        padding: '12px 18px',
        borderBottom: '1px solid var(--glass-border-strong)',
        background: 'var(--glass-bg-strong)',
        fontSize: 10,
        color: 'var(--fg-2)',
        letterSpacing: 0.1,
        textTransform: 'uppercase',
        gap: 12,
        alignItems: 'center',
      }}
    >
      <HeaderCell label="Código" k="codigo" sortKey={sortKey} sortDir={sortDir} onSort={onSort} />
      <HeaderCell label="Categoria" k={null} />
      <HeaderCell label="Item" k="item" sortKey={sortKey} sortDir={sortDir} onSort={onSort} />
      <HeaderCell label="Descrição" k="descricao" sortKey={sortKey} sortDir={sortDir} onSort={onSort} />
      <HeaderCell
        label="Qtd"
        k="quantidade"
        sortKey={sortKey}
        sortDir={sortDir}
        onSort={onSort}
        align="right"
      />
      <HeaderCell label="Status" k="status" sortKey={sortKey} sortDir={sortDir} onSort={onSort} />
      <HeaderCell
        label="Atualizado"
        k="atualizado"
        sortKey={sortKey}
        sortDir={sortDir}
        onSort={onSort}
      />
      <HeaderCell label="Identif." k={null} />
    </div>
  )
}

function HeaderCell({
  label,
  k,
  sortKey,
  sortDir,
  onSort,
  align,
}: {
  label: string
  k: LotesSortKey | null
  sortKey?: LotesSortKey
  sortDir?: LotesSortDir
  onSort?: (k: LotesSortKey) => void
  align?: 'left' | 'right'
}) {
  const sortable = k != null && onSort != null
  const active = sortable && sortKey === k
  const arrow = active ? (sortDir === 'asc' ? '↑' : '↓') : ''
  return (
    <button
      type="button"
      onClick={() => sortable && onSort!(k!)}
      disabled={!sortable}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 4,
        justifyContent: align === 'right' ? 'flex-end' : 'flex-start',
        background: 'transparent',
        border: 'none',
        padding: 0,
        color: active ? 'var(--accent-cyan)' : 'var(--fg-2)',
        fontFamily: 'inherit',
        fontSize: 10,
        letterSpacing: 'inherit',
        textTransform: 'inherit',
        cursor: sortable ? 'pointer' : 'default',
        textAlign: align ?? 'left',
      }}
    >
      <span>{label}</span>
      {arrow && <span style={{ fontSize: 9 }}>{arrow}</span>}
    </button>
  )
}

function LoteRowView({ lote: l }: { lote: LoteRow }) {
  const color = STATUS_LOTE_COLOR[l.status]
  return (
    <Link
      href={`/lotes/${l.id}`}
      prefetch={false}
      style={{
        display: 'grid',
        gridTemplateColumns: GRID,
        padding: '12px 18px',
        borderBottom: '1px solid var(--glass-border)',
        color: 'var(--fg-0)',
        textDecoration: 'none',
        gap: 12,
        alignItems: 'center',
        fontSize: 13,
        transition: 'background var(--motion-fast)',
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.background = 'var(--glass-bg)'
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.background = 'transparent'
      }}
    >
      {/* Código */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
        <StatusDot color={color} size={7} />
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
          {l.codigo_lote}
        </span>
      </div>

      {/* Categoria */}
      <span
        className="mono"
        style={{
          fontSize: 10,
          color: 'var(--fg-2)',
          letterSpacing: 0.12,
          textTransform: 'uppercase',
        }}
      >
        {CATEGORIA_LABEL[l.item_categoria]}
      </span>

      {/* Item */}
      <div style={{ minWidth: 0 }}>
        <div
          style={{
            fontSize: 13,
            color: 'var(--fg-0)',
            fontWeight: 500,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {l.item_nome}
        </div>
        {l.item_subcategoria && (
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
            {l.item_subcategoria}
          </div>
        )}
      </div>

      {/* Descrição */}
      <span
        style={{
          fontSize: 12,
          color: l.descricao ? 'var(--fg-1)' : 'var(--fg-3)',
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
      >
        {l.descricao ?? '–'}
      </span>

      {/* Quantidade */}
      <span
        className="mono"
        style={{
          fontSize: 14,
          color: 'var(--fg-0)',
          fontWeight: 500,
          textAlign: 'right',
        }}
      >
        {l.quantidade}
      </span>

      {/* Status */}
      <span
        style={{
          display: 'inline-block',
          padding: '3px 8px',
          borderRadius: 'var(--r-sm)',
          fontSize: 11,
          fontWeight: 500,
          background: `color-mix(in oklch, ${color} 14%, transparent)`,
          color,
          border: `1px solid color-mix(in oklch, ${color} 36%, transparent)`,
          width: 'fit-content',
        }}
      >
        {STATUS_LOTE_LABEL[l.status]}
      </span>

      {/* Atualizado */}
      <span
        className="mono"
        style={{
          fontSize: 11,
          color: 'var(--fg-2)',
          letterSpacing: 0.06,
          whiteSpace: 'nowrap',
        }}
      >
        {formatRelative(l.updated_at)}
      </span>

      {/* Identif. (RFID/QR icons) */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 8,
        }}
      >
        {l.tag_rfid && (
          <span
            title="Tag RFID"
            style={{ color: 'var(--accent-cyan)', display: 'inline-flex', transform: 'scale(0.8)' }}
          >
            {Icons.rfid}
          </span>
        )}
        {l.qr_code && (
          <span
            title="QR code"
            style={{ color: 'var(--fg-2)', display: 'inline-flex', transform: 'scale(0.8)' }}
          >
            {Icons.qr}
          </span>
        )}
        {!l.tag_rfid && !l.qr_code && (
          <span style={{ fontSize: 11, color: 'var(--fg-3)' }}>sem tag</span>
        )}
      </div>
    </Link>
  )
}

function GroupSection({
  title,
  count,
  lotes,
}: {
  title: string
  count: number
  lotes: LoteRow[]
}) {
  return (
    <div>
      <div
        className="mono"
        style={{
          padding: '10px 18px',
          fontSize: 10,
          color: 'var(--fg-1)',
          letterSpacing: 0.1,
          textTransform: 'uppercase',
          background: 'var(--glass-bg)',
          borderTop: '1px solid var(--glass-border)',
          borderBottom: '1px solid var(--glass-border)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          position: 'sticky',
          top: 0,
          zIndex: 1,
        }}
      >
        <span>{title}</span>
        <span style={{ color: 'var(--fg-2)' }}>{count}</span>
      </div>
      {lotes.map((l) => (
        <LoteRowView key={l.id} lote={l} />
      ))}
    </div>
  )
}

function sortLotes(lotes: LoteRow[], key: LotesSortKey, dir: LotesSortDir): LoteRow[] {
  const factor = dir === 'asc' ? 1 : -1
  return [...lotes].sort((a, b) => {
    switch (key) {
      case 'codigo':
        return a.codigo_lote.localeCompare(b.codigo_lote, 'pt-BR') * factor
      case 'item':
        return a.item_nome.localeCompare(b.item_nome, 'pt-BR') * factor
      case 'descricao':
        return (a.descricao ?? '').localeCompare(b.descricao ?? '', 'pt-BR') * factor
      case 'quantidade':
        return (a.quantidade - b.quantidade) * factor
      case 'status':
        return STATUS_LOTE_LABEL[a.status].localeCompare(STATUS_LOTE_LABEL[b.status], 'pt-BR') * factor
      case 'atualizado':
        return (
          (new Date(a.updated_at).getTime() - new Date(b.updated_at).getTime()) * factor
        )
      default:
        return 0
    }
  })
}

function groupLotes(
  lotes: LoteRow[],
  groupBy: LotesGroupBy
): { key: string; title: string; items: LoteRow[] }[] {
  if (groupBy === 'none') return [{ key: 'all', title: '', items: lotes }]
  const map = new Map<string, { key: string; title: string; items: LoteRow[] }>()
  for (const l of lotes) {
    const { key, title } = groupKey(l, groupBy)
    if (!map.has(key)) map.set(key, { key, title, items: [] })
    map.get(key)!.items.push(l)
  }
  return [...map.values()].sort((a, b) => a.title.localeCompare(b.title, 'pt-BR'))
}

function groupKey(l: LoteRow, groupBy: LotesGroupBy): { key: string; title: string } {
  switch (groupBy) {
    case 'categoria':
      return { key: l.item_categoria, title: CATEGORIA_LABEL[l.item_categoria] }
    case 'item':
      return { key: l.item_id, title: l.item_nome }
    case 'status':
      return { key: l.status, title: STATUS_LOTE_LABEL[l.status] }
    default:
      return { key: 'all', title: '' }
  }
}

function formatRelative(iso: string): string {
  const now = Date.now()
  const then = new Date(iso).getTime()
  const diff = now - then
  const days = Math.floor(diff / (1000 * 60 * 60 * 24))
  if (days <= 0) return 'hoje'
  if (days === 1) return 'ontem'
  if (days < 30) return `${days}d atrás`
  if (days < 365) return `${Math.floor(days / 30)}m atrás`
  return `${Math.floor(days / 365)}a atrás`
}
