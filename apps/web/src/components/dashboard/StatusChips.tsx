interface StatusChip {
  label: string
  ok: boolean
}

interface StatusChipsProps {
  chips: StatusChip[]
}

export function StatusChips({ chips }: StatusChipsProps) {
  return (
    <div className="flex flex-wrap gap-2 px-8 py-4" style={{ borderTop: '1px solid #E8E8E8' }}>
      {chips.map((chip) => (
        <span
          key={chip.label}
          style={{
            fontFamily: '"Space Mono", monospace',
            fontSize: 9,
            letterSpacing: '0.1em',
            color: chip.ok ? '#4A9E5C' : '#D71921',
            border: `1px solid ${chip.ok ? '#4A9E5C' : '#D71921'}`,
            borderRadius: 999,
            padding: '3px 10px',
          }}
        >
          {chip.label.toUpperCase()}
        </span>
      ))}
    </div>
  )
}
