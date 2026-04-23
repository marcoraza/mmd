'use client'

import { useMemo, useState } from 'react'
import { Icons } from '@/components/mmd/Icons'
import type { LotesData } from '@/lib/data/lotes'
import type { Categoria } from '@/lib/types'
import { CATEGORIA_LABEL } from '@/components/catalog/helpers'
import {
  LotesTable,
  type LotesGroupBy,
  type LotesSortDir,
  type LotesSortKey,
} from './LotesTable'
import { LotesBanner, type LotesBannerFilter } from './LotesBanner'

export function LotesClient({ data }: { data: LotesData }) {
  const [categoria, setCategoria] = useState<Categoria | 'ALL'>('ALL')
  const [banner, setBanner] = useState<LotesBannerFilter | null>(null)
  const [query, setQuery] = useState('')
  const [sortKey, setSortKey] = useState<LotesSortKey>('codigo')
  const [sortDir, setSortDir] = useState<LotesSortDir>('asc')
  const [groupBy, setGroupBy] = useState<LotesGroupBy>('categoria')

  const categorias = useMemo(() => {
    const set = new Map<Categoria, number>()
    for (const l of data.lotes) {
      set.set(l.item_categoria, (set.get(l.item_categoria) ?? 0) + 1)
    }
    return [...set.entries()].sort((a, b) =>
      CATEGORIA_LABEL[a[0]].localeCompare(CATEGORIA_LABEL[b[0]], 'pt-BR')
    )
  }, [data.lotes])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return data.lotes.filter((l) => {
      if (categoria !== 'ALL' && l.item_categoria !== categoria) return false
      if (banner === 'disponivel' && l.status !== 'DISPONIVEL') return false
      if (banner === 'em_campo' && l.status !== 'EM_CAMPO') return false
      if (banner === 'manutencao' && l.status !== 'MANUTENCAO') return false
      if (q) {
        const haystack = [
          l.codigo_lote,
          l.descricao,
          l.item_nome,
          l.item_subcategoria,
          l.item_marca,
          l.tag_rfid,
          l.qr_code,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase()
        if (!haystack.includes(q)) return false
      }
      return true
    })
  }, [data.lotes, categoria, banner, query])

  function onSort(key: LotesSortKey) {
    setSortKey((prev) => {
      if (prev === key) {
        setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'))
        return prev
      }
      setSortDir('asc')
      return key
    })
  }

  return (
    <>
      {/* Category chips */}
      <div
        role="tablist"
        aria-label="Filtrar por categoria"
        style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 4 }}
      >
        <CategoryPill
          active={categoria === 'ALL'}
          label="Todas"
          count={data.lotes.length}
          onClick={() => setCategoria('ALL')}
        />
        {categorias.map(([cat, count]) => (
          <CategoryPill
            key={cat}
            active={categoria === cat}
            label={CATEGORIA_LABEL[cat]}
            count={count}
            onClick={() => setCategoria(cat)}
          />
        ))}
      </div>

      <LotesBanner
        stats={data.banner}
        active={banner}
        onFilter={(f) => setBanner((prev) => (prev === f ? null : f))}
      />

      {/* Toolbar */}
      <div
        style={{
          marginTop: 20,
          display: 'flex',
          gap: 12,
          alignItems: 'center',
          flexWrap: 'wrap',
          padding: '14px 18px',
          border: '1px solid var(--glass-border)',
          borderRadius: 'var(--r-md)',
          background: 'var(--glass-bg)',
          backdropFilter: 'blur(18px) saturate(160%)',
          WebkitBackdropFilter: 'blur(18px) saturate(160%)',
        }}
      >
        <label
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            flex: '1 1 280px',
            padding: '8px 12px',
            border: '1px solid var(--glass-border)',
            borderRadius: 'var(--r-sm)',
            background: 'var(--bg-0)',
            color: 'var(--fg-2)',
          }}
        >
          {Icons.search}
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Buscar por código, descrição, item..."
            style={{
              flex: 1,
              background: 'transparent',
              border: 'none',
              outline: 'none',
              color: 'var(--fg-0)',
              fontFamily: 'inherit',
              fontSize: 13,
            }}
          />
        </label>

        <GroupBySelect value={groupBy} onChange={setGroupBy} />

        <div
          className="mono"
          style={{
            fontSize: 11,
            color: 'var(--fg-2)',
            letterSpacing: 0.1,
            textTransform: 'uppercase',
          }}
        >
          {filtered.length} / {data.lotes.length}
        </div>
      </div>

      <div style={{ marginTop: 16 }}>
        <LotesTable
          lotes={filtered}
          sortKey={sortKey}
          sortDir={sortDir}
          groupBy={groupBy}
          onSort={onSort}
        />
      </div>
    </>
  )
}

function CategoryPill({
  active,
  label,
  count,
  onClick,
}: {
  active: boolean
  label: string
  count: number
  onClick: () => void
}) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      onClick={onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 8,
        padding: '8px 14px',
        borderRadius: 999,
        border: active ? '1px solid var(--glass-border-strong)' : '1px solid var(--glass-border)',
        background: active ? 'var(--glass-bg-strong)' : 'var(--glass-bg)',
        color: active ? 'var(--fg-0)' : 'var(--fg-2)',
        fontFamily: 'inherit',
        fontSize: 12,
        fontWeight: 500,
        letterSpacing: 0.05,
        cursor: 'pointer',
        whiteSpace: 'nowrap',
        transition: 'background var(--motion-fast), color var(--motion-fast)',
      }}
    >
      <span>{label}</span>
      <span
        className="mono"
        style={{
          fontSize: 10,
          color: active ? 'var(--accent-cyan)' : 'var(--fg-3)',
          letterSpacing: 0.08,
        }}
      >
        {count}
      </span>
    </button>
  )
}

function GroupBySelect({
  value,
  onChange,
}: {
  value: LotesGroupBy
  onChange: (v: LotesGroupBy) => void
}) {
  const options: { key: LotesGroupBy; label: string }[] = [
    { key: 'none', label: 'Sem grupo' },
    { key: 'categoria', label: 'Por categoria' },
    { key: 'item', label: 'Por item' },
    { key: 'status', label: 'Por status' },
  ]
  return (
    <select
      value={value}
      onChange={(e) => onChange(e.target.value as LotesGroupBy)}
      style={{
        padding: '7px 12px',
        borderRadius: 'var(--r-sm)',
        border: '1px solid var(--glass-border)',
        background: 'var(--bg-0)',
        color: 'var(--fg-1)',
        fontFamily: 'inherit',
        fontSize: 12,
        cursor: 'pointer',
      }}
    >
      {options.map((o) => (
        <option key={o.key} value={o.key}>
          {o.label}
        </option>
      ))}
    </select>
  )
}
