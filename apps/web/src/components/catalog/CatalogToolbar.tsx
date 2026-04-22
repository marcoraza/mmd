'use client'

import { Icons } from '@/components/mmd/Icons'

export function CatalogToolbar({
  query,
  onQueryChange,
  visibleCount,
  totalCount,
}: {
  query: string
  onQueryChange: (v: string) => void
  visibleCount: number
  totalCount: number
}) {
  return (
    <div
      style={{
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
          onChange={(e) => onQueryChange(e.target.value)}
          placeholder="Buscar por código, nome, marca, modelo..."
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

      <div
        className="mono"
        style={{
          marginLeft: 'auto',
          fontSize: 11,
          color: 'var(--fg-2)',
          letterSpacing: 0.1,
          textTransform: 'uppercase',
        }}
      >
        {visibleCount} / {totalCount}
      </div>
    </div>
  )
}
