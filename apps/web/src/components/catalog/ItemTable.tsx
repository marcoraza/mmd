'use client'

import { useMemo } from 'react'
import type { CatalogItem } from '@/lib/data/items'
import type {
  ColumnKey,
  GroupBy,
  SortDir,
  SortKey,
} from '@/hooks/useCatalogView'
import {
  CATEGORIA_LABEL,
  CICLO_LABEL,
  SITUACAO_COLOR,
  SITUACAO_LABEL,
  formatBRL,
} from './helpers'
import { resolveTipo } from '@/lib/nomenclature'
import { formatItemLabel } from '@/lib/item-label'
import { EditableStars } from './EditableStars'
import { EditableQty } from './EditableQty'
import { HeaderMenu } from './HeaderMenu'

type ColumnDef = {
  key: ColumnKey
  sortKey: SortKey
  label: string
  width: string
  align?: 'left' | 'right'
}

const ALL_COLUMNS: ColumnDef[] = [
  { key: 'codigo', sortKey: 'codigo', label: 'Código', width: '120px' },
  { key: 'tipo', sortKey: 'tipo', label: 'Tipo', width: '170px' },
  { key: 'marca', sortKey: 'marca', label: 'Marca', width: '120px' },
  { key: 'qtd', sortKey: 'qtd', label: 'Qtd', width: '80px', align: 'right' },
  { key: 'situacao', sortKey: 'situacao', label: 'Situação', width: '120px' },
  { key: 'ciclo', sortKey: 'ciclo', label: 'Ciclo', width: '100px' },
  { key: 'condicao', sortKey: 'condicao', label: 'Condição', width: '130px' },
  { key: 'valor', sortKey: 'valor', label: 'Valor', width: '120px', align: 'right' },
]

const ITEM_MIN_WIDTH = '200px'

export function ItemTable({
  items,
  columns,
  groupBy,
  sortKey,
  sortDir,
  onSort,
  onSelect,
  selectedId,
  onCondicaoChange,
  onQtdChange,
  pending,
}: {
  items: CatalogItem[]
  columns: Record<ColumnKey, boolean>
  groupBy: GroupBy
  sortKey: SortKey
  sortDir: SortDir
  onSort: (key: SortKey, dir: SortDir) => void
  onSelect: (item: CatalogItem) => void
  selectedId: string | null
  onCondicaoChange: (itemId: string, desgaste: number) => void
  onQtdChange: (itemId: string, qtd: number) => void
  pending: string | null
}) {
  const activeCols = useMemo(
    () => ALL_COLUMNS.filter((c) => columns[c.key]),
    [columns]
  )

  const itemSlotAfter = useMemo<ColumnKey | null>(() => {
    if (activeCols.some((c) => c.key === 'tipo')) return 'tipo'
    if (activeCols.some((c) => c.key === 'codigo')) return 'codigo'
    return null
  }, [activeCols])

  const gridTemplate = useMemo(() => {
    const parts: string[] = []
    if (itemSlotAfter === null) parts.push(`minmax(${ITEM_MIN_WIDTH}, 1fr)`)
    for (const c of activeCols) {
      parts.push(c.width)
      if (c.key === itemSlotAfter) parts.push(`minmax(${ITEM_MIN_WIDTH}, 1fr)`)
    }
    return parts.join(' ')
  }, [activeCols, itemSlotAfter])

  const groups = useMemo(() => groupItems(items, groupBy), [items, groupBy])

  if (items.length === 0) {
    return (
      <div
        className="glass"
        style={{ padding: '40px 24px', textAlign: 'center', color: 'var(--fg-2)' }}
      >
        Nenhum item encontrado com os filtros atuais.
      </div>
    )
  }

  return (
    <div
      className="glass"
      style={{ borderRadius: 'var(--r-lg)', overflow: 'hidden' }}
    >
      <div role="table" style={{ width: '100%', fontSize: 13 }}>
        <HeaderRow
          activeCols={activeCols}
          itemSlotAfter={itemSlotAfter}
          gridTemplate={gridTemplate}
          sortKey={sortKey}
          sortDir={sortDir}
          onSort={onSort}
        />
        <div style={{ maxHeight: 640, overflowY: 'auto' }}>
          {groupBy === 'none' ? (
            items.map((it) => (
              <ItemRow
                key={it.id}
                item={it}
                activeCols={activeCols}
                itemSlotAfter={itemSlotAfter}
                gridTemplate={gridTemplate}
                selected={it.id === selectedId}
                onSelect={onSelect}
                onCondicaoChange={onCondicaoChange}
                onQtdChange={onQtdChange}
                pending={pending}
              />
            ))
          ) : (
            groups.map((g) => (
              <GroupSection
                key={g.key}
                title={g.title}
                count={g.items.length}
                activeCols={activeCols}
                itemSlotAfter={itemSlotAfter}
                gridTemplate={gridTemplate}
                items={g.items}
                selectedId={selectedId}
                onSelect={onSelect}
                onCondicaoChange={onCondicaoChange}
                onQtdChange={onQtdChange}
                pending={pending}
              />
            ))
          )}
        </div>
      </div>
    </div>
  )
}

function HeaderRow({
  activeCols,
  itemSlotAfter,
  gridTemplate,
  sortKey,
  sortDir,
  onSort,
}: {
  activeCols: ColumnDef[]
  itemSlotAfter: ColumnKey | null
  gridTemplate: string
  sortKey: SortKey
  sortDir: SortDir
  onSort: (key: SortKey, dir: SortDir) => void
}) {
  const cells = buildCells(
    activeCols,
    itemSlotAfter,
    (col) => (
      <HeaderMenu
        label={col.label}
        sortKey={col.sortKey}
        align={col.align ?? 'left'}
        currentSortKey={sortKey}
        currentSortDir={sortDir}
        onSort={onSort}
      />
    ),
    <HeaderMenu
      label="Item"
      sortKey="nome"
      align="left"
      currentSortKey={sortKey}
      currentSortDir={sortDir}
      onSort={onSort}
    />
  )
  return (
    <div
      role="row"
      className="mono"
      style={{
        display: 'grid',
        gridTemplateColumns: gridTemplate,
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
      {cells}
    </div>
  )
}

function ItemRow({
  item,
  activeCols,
  itemSlotAfter,
  gridTemplate,
  selected,
  onSelect,
  onCondicaoChange,
  onQtdChange,
  pending,
}: {
  item: CatalogItem
  activeCols: ColumnDef[]
  itemSlotAfter: ColumnKey | null
  gridTemplate: string
  selected: boolean
  onSelect: (it: CatalogItem) => void
  onCondicaoChange: (itemId: string, desgaste: number) => void
  onQtdChange: (itemId: string, qtd: number) => void
  pending: string | null
}) {
  const codigo = item.codigo_interno ?? item.id.slice(0, 8)
  const { primary: nomeExibicao, secondary: nomeSubtitle } = formatItemLabel(
    item.nome,
    item.modelo,
    item.marca
  )

  const cells = buildCells(
    activeCols,
    itemSlotAfter,
    (col) => {
      switch (col.key) {
        case 'codigo':
          return (
            <span
              className="mono"
              style={{
                fontSize: 11,
                color: 'var(--fg-2)',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {codigo}
            </span>
          )
        case 'tipo':
          return (
            <span
              style={{
                color: 'var(--fg-0)',
                fontSize: 13,
                fontWeight: 500,
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {resolveTipo(item.subcategoria, item.categoria)}
            </span>
          )
        case 'marca':
          return item.marca ? (
            <span
              className="mono"
              style={{
                fontSize: 11,
                color: 'var(--fg-2)',
                letterSpacing: 0.4,
                textTransform: 'uppercase',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {item.marca}
            </span>
          ) : (
            <span style={{ color: 'var(--fg-3)', fontSize: 12 }}>–</span>
          )
        case 'qtd':
          return (
            <EditableQty
              value={item.quantidade_total}
              pending={pending === `qtd:${item.id}`}
              onChange={(n) => onQtdChange(item.id, n)}
            />
          )
        case 'situacao':
          return (
            <span
              style={{
                display: 'inline-block',
                padding: '3px 8px',
                borderRadius: 'var(--r-sm)',
                fontSize: 11,
                fontWeight: 500,
                background: 'var(--glass-bg-strong)',
                color: SITUACAO_COLOR[item.situacao],
                border: `1px solid ${SITUACAO_COLOR[item.situacao]}40`,
              }}
            >
              {SITUACAO_LABEL[item.situacao]}
            </span>
          )
        case 'ciclo':
          return (
            <span style={{ fontSize: 12, color: 'var(--fg-1)' }}>
              {item.ciclo ? CICLO_LABEL[item.ciclo] : '–'}
            </span>
          )
        case 'condicao':
          return (
            <EditableStars
              value={item.condicao_media}
              size={12}
              pending={pending === `condicao:${item.id}`}
              onChange={(n) => onCondicaoChange(item.id, n)}
            />
          )
        case 'valor':
          return (
            <span
              className="mono"
              style={{ textAlign: 'right', fontSize: 12, color: 'var(--fg-1)' }}
            >
              {formatBRL(item.valor_atual_total)}
            </span>
          )
      }
    },
    <span style={{ minWidth: 0 }}>
      <div
        style={{
          fontWeight: 500,
          letterSpacing: -0.1,
          color: 'var(--fg-0)',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
        }}
      >
        {nomeExibicao}
      </div>
      {nomeSubtitle && (
        <div
          style={{
            fontSize: 11,
            color: 'var(--fg-2)',
            marginTop: 2,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {nomeSubtitle}
        </div>
      )}
    </span>
  )

  return (
    <div
      role="row"
      tabIndex={0}
      aria-selected={selected}
      onClick={() => onSelect(item)}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          onSelect(item)
        }
      }}
      style={{
        display: 'grid',
        gridTemplateColumns: gridTemplate,
        width: '100%',
        padding: '14px 18px',
        borderBottom: '1px solid var(--glass-border)',
        background: selected ? 'var(--glass-bg-strong)' : 'transparent',
        color: 'var(--fg-0)',
        textAlign: 'left',
        fontFamily: 'inherit',
        fontSize: 13,
        cursor: 'pointer',
        transition: 'background var(--motion-fast)',
        gap: 12,
        alignItems: 'center',
        outline: 'none',
      }}
      onMouseEnter={(e) => {
        if (!selected) e.currentTarget.style.background = 'var(--glass-bg)'
      }}
      onMouseLeave={(e) => {
        if (!selected) e.currentTarget.style.background = 'transparent'
      }}
    >
      {cells}
    </div>
  )
}

function GroupSection({
  title,
  count,
  activeCols,
  itemSlotAfter,
  gridTemplate,
  items,
  selectedId,
  onSelect,
  onCondicaoChange,
  onQtdChange,
  pending,
}: {
  title: string
  count: number
  activeCols: ColumnDef[]
  itemSlotAfter: ColumnKey | null
  gridTemplate: string
  items: CatalogItem[]
  selectedId: string | null
  onSelect: (it: CatalogItem) => void
  onCondicaoChange: (itemId: string, desgaste: number) => void
  onQtdChange: (itemId: string, qtd: number) => void
  pending: string | null
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
      {items.map((it) => (
        <ItemRow
          key={it.id}
          item={it}
          activeCols={activeCols}
          itemSlotAfter={itemSlotAfter}
          gridTemplate={gridTemplate}
          selected={it.id === selectedId}
          onSelect={onSelect}
          onCondicaoChange={onCondicaoChange}
          onQtdChange={onQtdChange}
          pending={pending}
        />
      ))}
    </div>
  )
}

function buildCells(
  activeCols: ColumnDef[],
  itemSlotAfter: ColumnKey | null,
  renderCol: (col: ColumnDef) => React.ReactNode,
  itemCell: React.ReactNode
): React.ReactNode[] {
  const out: React.ReactNode[] = []
  if (itemSlotAfter === null) out.push(<div key="__item__">{itemCell}</div>)
  for (const col of activeCols) {
    const align = col.align ?? 'left'
    out.push(
      <div
        key={col.key}
        style={{
          textAlign: align,
          display: 'flex',
          justifyContent: align === 'right' ? 'flex-end' : 'flex-start',
          alignItems: 'center',
          minWidth: 0,
        }}
      >
        {renderCol(col)}
      </div>
    )
    if (col.key === itemSlotAfter) out.push(<div key="__item__">{itemCell}</div>)
  }
  return out
}

function groupItems(items: CatalogItem[], groupBy: GroupBy) {
  if (groupBy === 'none') return [{ key: 'all', title: '', items }]

  const map = new Map<string, { key: string; title: string; items: CatalogItem[] }>()
  for (const it of items) {
    const { key, title } = groupKey(it, groupBy)
    if (!map.has(key)) map.set(key, { key, title, items: [] })
    map.get(key)!.items.push(it)
  }
  return [...map.values()].sort((a, b) => a.title.localeCompare(b.title, 'pt-BR'))
}

function groupKey(it: CatalogItem, groupBy: GroupBy): { key: string; title: string } {
  switch (groupBy) {
    case 'categoria':
      return { key: it.categoria, title: CATEGORIA_LABEL[it.categoria] }
    case 'subcategoria':
      return {
        key: it.subcategoria ?? '__none__',
        title: it.subcategoria
          ? resolveTipo(it.subcategoria, it.categoria)
          : 'Sem tipo',
      }
    case 'situacao':
      return { key: it.situacao, title: SITUACAO_LABEL[it.situacao] }
    case 'ciclo':
      return {
        key: it.ciclo ?? '__none__',
        title: it.ciclo ? CICLO_LABEL[it.ciclo] : 'Sem ciclo',
      }
    default:
      return { key: 'all', title: '' }
  }
}
