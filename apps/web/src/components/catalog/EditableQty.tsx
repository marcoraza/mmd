'use client'

import { useEffect, useRef, useState } from 'react'

export function EditableQty({
  value,
  pending = false,
  onChange,
}: {
  value: number
  pending?: boolean
  onChange: (next: number) => void
}) {
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState(String(value))
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (!editing) setDraft(String(value))
  }, [value, editing])

  useEffect(() => {
    if (editing && inputRef.current) {
      inputRef.current.focus()
      inputRef.current.select()
    }
  }, [editing])

  function commit() {
    const n = Number.parseInt(draft, 10)
    if (Number.isFinite(n) && n !== value) onChange(Math.max(0, n))
    setEditing(false)
  }

  function cancel() {
    setDraft(String(value))
    setEditing(false)
  }

  if (editing) {
    return (
      <input
        ref={inputRef}
        type="number"
        min={0}
        value={draft}
        disabled={pending}
        onChange={(e) => setDraft(e.target.value)}
        onBlur={commit}
        onClick={(e) => e.stopPropagation()}
        onKeyDown={(e) => {
          e.stopPropagation()
          if (e.key === 'Enter') commit()
          if (e.key === 'Escape') cancel()
        }}
        className="mono"
        style={{
          width: '100%',
          textAlign: 'right',
          background: 'var(--bg-0)',
          border: '1px solid var(--fg-0)',
          borderRadius: 'var(--r-sm)',
          padding: '2px 6px',
          color: 'var(--fg-0)',
          fontSize: 13,
          fontFamily: 'inherit',
          outline: 'none',
        }}
      />
    )
  }

  return (
    <button
      type="button"
      disabled={pending}
      onClick={(e) => {
        e.stopPropagation()
        setEditing(true)
      }}
      className="mono"
      title="Clique para editar quantidade"
      style={{
        display: 'block',
        width: '100%',
        textAlign: 'right',
        background: 'transparent',
        border: '1px solid transparent',
        borderRadius: 'var(--r-sm)',
        padding: '2px 6px',
        color: 'var(--fg-0)',
        fontSize: 13,
        fontFamily: 'inherit',
        cursor: pending ? 'wait' : 'pointer',
        opacity: pending ? 0.5 : 1,
        transition: 'background var(--motion-fast), border-color var(--motion-fast)',
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.borderColor = 'var(--glass-border)'
        e.currentTarget.style.background = 'var(--glass-bg)'
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.borderColor = 'transparent'
        e.currentTarget.style.background = 'transparent'
      }}
    >
      {value}
    </button>
  )
}
