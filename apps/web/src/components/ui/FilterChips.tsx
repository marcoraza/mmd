'use client'

interface FilterChipsProps<T extends string> {
  options: { value: T; label: string }[]
  selected: T[]
  onToggle: (value: T) => void
  className?: string
}

export function FilterChips<T extends string>({
  options,
  selected,
  onToggle,
  className = '',
}: FilterChipsProps<T>) {
  return (
    <div className={`flex flex-wrap gap-2 ${className}`}>
      {options.map((opt) => {
        const active = selected.includes(opt.value)
        return (
          <button
            key={opt.value}
            onClick={() => onToggle(opt.value)}
            style={{
              fontFamily: '"Space Mono", monospace',
              fontSize: 9,
              letterSpacing: '0.1em',
              color: active ? '#000000' : '#999999',
              border: `1px solid ${active ? '#000000' : '#CCCCCC'}`,
              background: 'none',
              borderRadius: 999,
              padding: '4px 10px',
              cursor: 'pointer',
            }}
          >
            {opt.label.toUpperCase()}
          </button>
        )
      })}
    </div>
  )
}
