'use client'

import type { SortDir, SortKey } from '@/hooks/useCatalogView'

export type HeaderMenuProps = {
  label: string
  sortKey: SortKey
  align: 'left' | 'right'
  currentSortKey: SortKey
  currentSortDir: SortDir
  onSort: (key: SortKey, dir: SortDir) => void
}

export function HeaderMenu({
  label,
  sortKey,
  align,
  currentSortKey,
  currentSortDir,
  onSort,
}: HeaderMenuProps) {
  const active = currentSortKey === sortKey
  const arrow = active ? (currentSortDir === 'asc' ? '↑' : '↓') : ''

  function handleClick() {
    const nextDir: SortDir = active ? (currentSortDir === 'asc' ? 'desc' : 'asc') : 'asc'
    onSort(sortKey, nextDir)
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      title={`Ordenar por ${label.toLowerCase()}`}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: align === 'right' ? 'flex-end' : 'flex-start',
        gap: 4,
        width: '100%',
        background: 'transparent',
        border: 'none',
        padding: '2px 6px',
        borderRadius: 'var(--r-sm)',
        color: active ? 'var(--fg-0)' : 'inherit',
        fontWeight: active ? 600 : 'inherit',
        fontFamily: 'inherit',
        fontSize: 'inherit',
        letterSpacing: 'inherit',
        textTransform: 'inherit',
        cursor: 'pointer',
      }}
    >
      <span>{label}</span>
      {arrow && <span style={{ fontSize: 11, opacity: 0.85 }}>{arrow}</span>}
    </button>
  )
}
