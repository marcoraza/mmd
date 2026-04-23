'use client'

import { useEffect, useRef, useState } from 'react'
import { searchItems, type ItemSearchResult } from '@/lib/actions/projetos'

const FIELD_STYLE: React.CSSProperties = {
  padding: '8px 12px',
  borderRadius: 8,
  border: '1px solid var(--glass-border)',
  background: 'var(--glass-bg)',
  color: 'var(--fg-0)',
  fontFamily: 'inherit',
  fontSize: 13,
  outline: 'none',
}

export function InlineItemPicker({
  onPick,
  pending,
}: {
  onPick: (itemId: string, qtd: number) => void
  pending: boolean
}) {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<ItemSearchResult[]>([])
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [qtd, setQtd] = useState(1)
  const [loading, setLoading] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    const t = setTimeout(async () => {
      try {
        const list = await searchItems(query)
        if (!cancelled) {
          setResults(list)
          if (list.length > 0 && !list.some((r) => r.id === selectedId)) {
            setSelectedId(list[0].id)
          }
        }
      } finally {
        if (!cancelled) setLoading(false)
      }
    }, 180)
    return () => {
      cancelled = true
      clearTimeout(t)
    }
  }, [query, selectedId])

  function handleConfirm() {
    if (!selectedId || qtd <= 0) return
    onPick(selectedId, qtd)
  }

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
        padding: 14,
        border: '1px solid var(--glass-border-strong)',
        borderRadius: 12,
        background: 'var(--glass-bg-strong)',
      }}
    >
      <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
        <input
          ref={inputRef}
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Buscar por nome ou código…"
          style={{ ...FIELD_STYLE, flex: 1 }}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault()
              handleConfirm()
            }
          }}
        />
        <input
          type="number"
          min={1}
          value={qtd}
          onChange={(e) => setQtd(Math.max(1, Number(e.target.value) || 1))}
          style={{ ...FIELD_STYLE, width: 80, textAlign: 'right' }}
          aria-label="Quantidade"
        />
        <button
          type="button"
          onClick={handleConfirm}
          disabled={pending || !selectedId}
          style={{
            padding: '8px 16px',
            borderRadius: 999,
            border: 'none',
            background: 'var(--fg-0)',
            color: 'var(--bg-0)',
            fontFamily: 'inherit',
            fontSize: 12,
            fontWeight: 500,
            cursor: pending || !selectedId ? 'not-allowed' : 'pointer',
            opacity: pending || !selectedId ? 0.5 : 1,
          }}
        >
          {pending ? 'Adicionando…' : 'Adicionar'}
        </button>
      </div>

      <div
        style={{
          maxHeight: 220,
          overflowY: 'auto',
          border: '1px solid var(--glass-border)',
          borderRadius: 8,
        }}
      >
        {loading && results.length === 0 && (
          <div style={{ padding: 14, fontSize: 12, color: 'var(--fg-3)' }}>
            Buscando…
          </div>
        )}
        {!loading && results.length === 0 && (
          <div style={{ padding: 14, fontSize: 12, color: 'var(--fg-3)' }}>
            Nenhum item encontrado.
          </div>
        )}
        {results.map((item) => {
          const active = item.id === selectedId
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => setSelectedId(item.id)}
              onDoubleClick={() => {
                setSelectedId(item.id)
                onPick(item.id, qtd)
              }}
              style={{
                width: '100%',
                padding: '10px 12px',
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                border: 'none',
                borderBottom: '1px solid var(--glass-border)',
                background: active ? 'var(--glass-bg-strong)' : 'transparent',
                color: 'inherit',
                fontFamily: 'inherit',
                cursor: 'pointer',
                textAlign: 'left',
              }}
            >
              <span
                className="mono"
                style={{
                  fontSize: 10,
                  color: 'var(--fg-3)',
                  minWidth: 96,
                }}
              >
                {item.codigo_interno ?? '·'}
              </span>
              <span style={{ flex: 1, fontSize: 13, color: 'var(--fg-0)' }}>
                {item.nome}
              </span>
              <span className="mono" style={{ fontSize: 10, color: 'var(--fg-2)' }}>
                {item.categoria}
              </span>
              <span className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
                {item.quantidade_total} un
              </span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
