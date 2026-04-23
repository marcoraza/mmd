'use client'

export type CatalogMode = 'tipos' | 'unidades'

type Props = {
  mode: CatalogMode
  onChange: (mode: CatalogMode) => void
  tiposCount: number
  unidadesCount: number
}

export function ViewModeToggle({ mode, onChange, tiposCount, unidadesCount }: Props) {
  return (
    <div
      role="tablist"
      aria-label="Modo de visualização"
      style={{
        display: 'inline-flex',
        padding: 3,
        borderRadius: 'var(--r-md)',
        border: '1px solid var(--glass-border)',
        background: 'var(--glass-bg)',
        gap: 2,
      }}
    >
      <ModeButton
        active={mode === 'tipos'}
        label="Tipos"
        count={tiposCount}
        onClick={() => onChange('tipos')}
      />
      <ModeButton
        active={mode === 'unidades'}
        label="Unidades"
        count={unidadesCount}
        onClick={() => onChange('unidades')}
      />
    </div>
  )
}

function ModeButton({
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
        padding: '6px 14px',
        borderRadius: 'var(--r-sm)',
        border: 'none',
        background: active ? 'var(--glass-bg-strong)' : 'transparent',
        color: active ? 'var(--fg-0)' : 'var(--fg-2)',
        fontFamily: 'inherit',
        fontSize: 12,
        fontWeight: 500,
        letterSpacing: 0.1,
        cursor: 'pointer',
        transition: 'background var(--motion-fast), color var(--motion-fast)',
        boxShadow: active ? 'inset 0 0 0 1px var(--glass-border-strong)' : 'none',
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
