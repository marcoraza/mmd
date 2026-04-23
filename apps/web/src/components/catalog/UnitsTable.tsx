'use client'

import { useMemo } from 'react'
import { Icons } from '@/components/mmd/Icons'
import { StatusDot } from '@/components/mmd/Primitives'
import type { CatalogUnit } from '@/lib/data/items'
import { resolveTipo } from '@/lib/nomenclature'
import {
  CATEGORIA_LABEL,
  CICLO_LABEL,
  SITUACAO_COLOR,
  SITUACAO_LABEL,
  formatBRL,
} from './helpers'

export type UnitGroupBy = 'none' | 'item' | 'status' | 'estado' | 'categoria'
export type UnitSortKey =
  | 'codigo'
  | 'item'
  | 'status'
  | 'estado'
  | 'desgaste'
  | 'valor'
  | 'local'

export type UnitSortDir = 'asc' | 'desc'

type Props = {
  units: CatalogUnit[]
  groupBy: UnitGroupBy
  sortKey: UnitSortKey
  sortDir: UnitSortDir
  onSort: (key: UnitSortKey) => void
  onSelectItem: (itemId: string) => void
}

export function UnitsTable({
  units,
  groupBy,
  sortKey,
  sortDir,
  onSort,
  onSelectItem,
}: Props) {
  const sorted = useMemo(() => {
    const dir = sortDir === 'asc' ? 1 : -1
    return [...units].sort((a, b) => {
      switch (sortKey) {
        case 'codigo':
          return a.codigo_interno.localeCompare(b.codigo_interno, 'pt-BR') * dir
        case 'item':
          return a.item_nome.localeCompare(b.item_nome, 'pt-BR') * dir
        case 'status':
          return SITUACAO_LABEL[a.status].localeCompare(SITUACAO_LABEL[b.status], 'pt-BR') * dir
        case 'estado':
          return a.estado.localeCompare(b.estado, 'pt-BR') * dir
        case 'desgaste':
          return (a.desgaste - b.desgaste) * dir
        case 'valor':
          return ((a.valor_atual ?? 0) - (b.valor_atual ?? 0)) * dir
        case 'local':
          return (a.localizacao ?? '').localeCompare(b.localizacao ?? '', 'pt-BR') * dir
        default:
          return 0
      }
    })
  }, [units, sortKey, sortDir])

  const groups = useMemo(() => groupUnits(sorted, groupBy), [sorted, groupBy])

  if (units.length === 0) {
    return (
      <div
        className="glass"
        style={{
          padding: '40px 24px',
          textAlign: 'center',
          color: 'var(--fg-2)',
        }}
      >
        Nenhuma unidade encontrada com os filtros atuais.
      </div>
    )
  }

  return (
    <div className="glass" style={{ borderRadius: 'var(--r-lg)', overflow: 'hidden' }}>
      <UnitsHeaderRow sortKey={sortKey} sortDir={sortDir} onSort={onSort} />
      <div style={{ maxHeight: 640, overflowY: 'auto' }}>
        {groupBy === 'none'
          ? sorted.map((u) => <UnitRow key={u.id} unit={u} onSelectItem={onSelectItem} />)
          : groups.map((g) => (
              <UnitsGroupSection
                key={g.key}
                title={g.title}
                count={g.items.length}
                units={g.items}
                onSelectItem={onSelectItem}
              />
            ))}
      </div>
    </div>
  )
}

const GRID = '140px 130px minmax(220px, 1fr) 130px 110px 120px 120px 120px'

function UnitsHeaderRow({
  sortKey,
  sortDir,
  onSort,
}: {
  sortKey: UnitSortKey
  sortDir: UnitSortDir
  onSort: (key: UnitSortKey) => void
}) {
  return (
    <div
      role="row"
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
      <HeaderCell label="Status" k="status" sortKey={sortKey} sortDir={sortDir} onSort={onSort} />
      <HeaderCell label="Estado" k="estado" sortKey={sortKey} sortDir={sortDir} onSort={onSort} />
      <HeaderCell label="Desgaste" k="desgaste" sortKey={sortKey} sortDir={sortDir} onSort={onSort} />
      <HeaderCell label="Local" k="local" sortKey={sortKey} sortDir={sortDir} onSort={onSort} />
      <HeaderCell label="Valor" k="valor" sortKey={sortKey} sortDir={sortDir} onSort={onSort} align="right" />
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
  k: UnitSortKey | null
  sortKey?: UnitSortKey
  sortDir?: UnitSortDir
  onSort?: (key: UnitSortKey) => void
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

function UnitRow({
  unit: u,
  onSelectItem,
}: {
  unit: CatalogUnit
  onSelectItem: (itemId: string) => void
}) {
  const statusColor = SITUACAO_COLOR[u.status]
  const desgasteColor =
    u.desgaste >= 4
      ? 'var(--accent-green)'
      : u.desgaste === 3
        ? 'var(--accent-amber)'
        : 'var(--accent-red)'
  const tipo = resolveTipo(u.item_subcategoria, u.item_categoria)

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={() => onSelectItem(u.item_id)}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          onSelectItem(u.item_id)
        }
      }}
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
        cursor: 'pointer',
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
        <StatusDot color={statusColor} size={7} />
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
          {u.codigo_interno}
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
        {CATEGORIA_LABEL[u.item_categoria]}
      </span>

      {/* Item (tipo + nome) */}
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
          {u.item_nome}
        </div>
        <div
          style={{
            fontSize: 11,
            color: 'var(--fg-3)',
            marginTop: 2,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {tipo}
          {u.item_marca && (
            <>
              {' · '}
              {u.item_marca}
            </>
          )}
        </div>
      </div>

      {/* Status */}
      <span
        style={{
          display: 'inline-block',
          padding: '3px 8px',
          borderRadius: 'var(--r-sm)',
          fontSize: 11,
          fontWeight: 500,
          background: `color-mix(in oklch, ${statusColor} 14%, transparent)`,
          color: statusColor,
          border: `1px solid color-mix(in oklch, ${statusColor} 36%, transparent)`,
          width: 'fit-content',
        }}
      >
        {SITUACAO_LABEL[u.status]}
      </span>

      {/* Estado */}
      <span style={{ fontSize: 12, color: 'var(--fg-1)' }}>
        {CICLO_LABEL[u.estado]}
      </span>

      {/* Desgaste */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, minWidth: 0 }}>
        <div
          style={{
            flex: 1,
            height: 5,
            borderRadius: 3,
            background: 'var(--glass-border)',
            overflow: 'hidden',
            maxWidth: 60,
          }}
        >
          <div
            style={{
              width: `${(u.desgaste / 5) * 100}%`,
              height: '100%',
              background: desgasteColor,
            }}
          />
        </div>
        <span className="mono" style={{ fontSize: 11, color: desgasteColor, flexShrink: 0 }}>
          {u.desgaste}/5
        </span>
      </div>

      {/* Local */}
      <span
        className="mono"
        style={{
          fontSize: 11,
          color: u.localizacao ? 'var(--fg-2)' : 'var(--fg-3)',
          letterSpacing: 0.08,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
      >
        {u.localizacao ?? '–'}
      </span>

      {/* Valor + RFID/QR icons */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'flex-end',
          gap: 8,
        }}
      >
        {u.tag_rfid && (
          <span
            title="Tag RFID"
            style={{ color: 'var(--accent-cyan)', display: 'inline-flex', transform: 'scale(0.8)' }}
          >
            {Icons.rfid}
          </span>
        )}
        {u.qr_code && (
          <span
            title="QR code"
            style={{ color: 'var(--fg-2)', display: 'inline-flex', transform: 'scale(0.8)' }}
          >
            {Icons.qr}
          </span>
        )}
        <span className="mono" style={{ fontSize: 12, color: 'var(--fg-1)' }}>
          {formatBRL(u.valor_atual)}
        </span>
      </div>
    </div>
  )
}

function UnitsGroupSection({
  title,
  count,
  units,
  onSelectItem,
}: {
  title: string
  count: number
  units: CatalogUnit[]
  onSelectItem: (itemId: string) => void
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
      {units.map((u) => (
        <UnitRow key={u.id} unit={u} onSelectItem={onSelectItem} />
      ))}
    </div>
  )
}

function groupUnits(
  units: CatalogUnit[],
  groupBy: UnitGroupBy
): { key: string; title: string; items: CatalogUnit[] }[] {
  if (groupBy === 'none') return [{ key: 'all', title: '', items: units }]

  const map = new Map<string, { key: string; title: string; items: CatalogUnit[] }>()
  for (const u of units) {
    const { key, title } = groupKey(u, groupBy)
    if (!map.has(key)) map.set(key, { key, title, items: [] })
    map.get(key)!.items.push(u)
  }
  return [...map.values()].sort((a, b) => a.title.localeCompare(b.title, 'pt-BR'))
}

function groupKey(u: CatalogUnit, groupBy: UnitGroupBy): { key: string; title: string } {
  switch (groupBy) {
    case 'item':
      return { key: u.item_id, title: u.item_nome }
    case 'status':
      return { key: u.status, title: SITUACAO_LABEL[u.status] }
    case 'estado':
      return { key: u.estado, title: CICLO_LABEL[u.estado] }
    case 'categoria':
      return { key: u.item_categoria, title: CATEGORIA_LABEL[u.item_categoria] }
    default:
      return { key: 'all', title: '' }
  }
}
