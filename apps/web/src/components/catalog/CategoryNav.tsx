'use client'

import { Icons } from '@/components/mmd/Icons'
import type { Categoria } from '@/lib/types'
import { CATEGORIA_ICON, CATEGORIA_LABEL } from './helpers'
import type { CategoryCount } from '@/lib/data/items'

export function CategoryNav({
  categories,
  totalAtivos,
  selected,
  onSelect,
}: {
  categories: CategoryCount[]
  totalAtivos: number
  selected: Categoria | 'ALL'
  onSelect: (c: Categoria | 'ALL') => void
}) {
  return (
    <div
      role="tablist"
      aria-label="Filtrar por categoria"
      style={{
        display: 'flex',
        gap: 8,
        overflowX: 'auto',
        paddingBottom: 4,
      }}
    >
      <Pill
        active={selected === 'ALL'}
        icon={Icons.box}
        label="Todos"
        count={totalAtivos}
        onClick={() => onSelect('ALL')}
      />
      {categories.map((c) => (
        <Pill
          key={c.categoria}
          active={selected === c.categoria}
          icon={Icons[CATEGORIA_ICON[c.categoria] as keyof typeof Icons]}
          label={CATEGORIA_LABEL[c.categoria]}
          count={c.qtd}
          onClick={() => onSelect(c.categoria)}
        />
      ))}
    </div>
  )
}

function Pill({
  active,
  icon,
  label,
  count,
  onClick,
}: {
  active: boolean
  icon: React.ReactNode
  label: string
  count: number
  onClick: () => void
}) {
  return (
    <button
      role="tab"
      aria-selected={active}
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        padding: '10px 14px',
        border: active
          ? '1px solid var(--glass-border-strong)'
          : '1px solid var(--glass-border)',
        borderRadius: 'var(--r-md)',
        background: active ? 'var(--glass-bg-strong)' : 'var(--glass-bg)',
        color: active ? 'var(--fg-0)' : 'var(--fg-1)',
        cursor: 'pointer',
        fontFamily: 'inherit',
        fontSize: 13,
        fontWeight: 500,
        letterSpacing: -0.1,
        whiteSpace: 'nowrap',
        transition: 'background var(--motion-fast), border-color var(--motion-fast), color var(--motion-fast)',
        backdropFilter: 'blur(18px) saturate(160%)',
        WebkitBackdropFilter: 'blur(18px) saturate(160%)',
      }}
    >
      <span style={{ display: 'inline-flex', color: active ? 'var(--accent-cyan)' : 'var(--fg-2)' }}>
        {icon}
      </span>
      <span>{label}</span>
      <span
        className="mono"
        style={{
          fontSize: 10,
          color: 'var(--fg-2)',
          letterSpacing: 0.1,
          padding: '2px 6px',
          borderRadius: 'var(--r-sm)',
          background: active ? 'var(--glass-bg)' : 'transparent',
        }}
      >
        {count}
      </span>
    </button>
  )
}
