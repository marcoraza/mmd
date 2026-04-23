'use client'

import { useMemo, useState } from 'react'
import { Icons } from '@/components/mmd/Icons'
import { GlassCard, GhostBtn, PrimaryBtn } from '@/components/mmd/Primitives'
import { CATEGORIA_LABEL } from '@/components/catalog/helpers'
import type { QrLote, QrSources, QrUnit } from '@/lib/data/qrcodes'
import { QR_LAYOUTS, type QrItem, type QrLayoutKey } from './layouts'
import { PreviewSheet } from './PreviewSheet'

type Mode = 'unidades' | 'lotes'

export function QrCodesClient({ data }: { data: QrSources }) {
  const [mode, setMode] = useState<Mode>('unidades')
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [layoutKey, setLayoutKey] = useState<QrLayoutKey>('small')
  const [exporting, setExporting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const source: Array<{ id: string; row: QrUnit | QrLote; kind: Mode }> = useMemo(() => {
    if (mode === 'unidades') {
      return data.units.map((u) => ({ id: u.id, row: u, kind: 'unidades' as const }))
    }
    return data.lotes.map((l) => ({ id: l.id, row: l, kind: 'lotes' as const }))
  }, [mode, data])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return source
    return source.filter((s) => {
      if (s.kind === 'unidades') {
        const u = s.row as QrUnit
        return (
          u.codigo_interno.toLowerCase().includes(q) ||
          u.item_nome.toLowerCase().includes(q) ||
          (u.serial_fabrica ?? '').toLowerCase().includes(q)
        )
      }
      const l = s.row as QrLote
      return (
        l.codigo_lote.toLowerCase().includes(q) ||
        l.item_nome.toLowerCase().includes(q)
      )
    })
  }, [source, query])

  const items: QrItem[] = useMemo(() => {
    const out: QrItem[] = []
    for (const s of source) {
      if (!selected.has(s.id)) continue
      if (s.kind === 'unidades') {
        const u = s.row as QrUnit
        out.push({
          payload: u.codigo_interno,
          title: u.codigo_interno,
          subtitle: u.item_nome,
          caption: CATEGORIA_LABEL[u.item_categoria],
        })
      } else {
        const l = s.row as QrLote
        out.push({
          payload: l.codigo_lote,
          title: l.codigo_lote,
          subtitle: `${l.item_nome} · ${l.quantidade} un`,
          caption: CATEGORIA_LABEL[l.item_categoria],
        })
      }
    }
    return out
  }, [source, selected])

  const layout = QR_LAYOUTS[layoutKey]
  const totalSheets = items.length > 0 ? Math.ceil(items.length / layout.perSheet) : 0

  function toggle(id: string) {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  function toggleAllVisible() {
    const allSelected = filtered.every((s) => selected.has(s.id))
    setSelected((prev) => {
      const next = new Set(prev)
      if (allSelected) {
        for (const s of filtered) next.delete(s.id)
      } else {
        for (const s of filtered) next.add(s.id)
      }
      return next
    })
  }

  function clearMode() {
    setSelected(new Set())
  }

  async function exportPdf() {
    if (items.length === 0) return
    setExporting(true)
    setError(null)
    try {
      const res = await fetch('/nmd/api/qr-sheet', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ items, layout: layoutKey }),
      })
      if (!res.ok) {
        const text = await res.text().catch(() => '')
        throw new Error(text || `HTTP ${res.status}`)
      }
      const blob = await res.blob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `qr-sheet-${layoutKey}-${Date.now()}.pdf`
      document.body.appendChild(a)
      a.click()
      a.remove()
      setTimeout(() => URL.revokeObjectURL(url), 1000)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro ao gerar PDF')
    } finally {
      setExporting(false)
    }
  }

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: 'minmax(320px, 420px) minmax(0, 1fr)',
        gap: 20,
        alignItems: 'start',
      }}
    >
      {/* Sidebar: seleção */}
      <GlassCard style={{ padding: 0, overflow: 'hidden' }}>
        {/* Tabs Unidades/Lotes */}
        <div
          role="tablist"
          style={{
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            borderBottom: '1px solid var(--glass-border)',
          }}
        >
          {(['unidades', 'lotes'] as Mode[]).map((m) => {
            const active = mode === m
            const count = m === 'unidades' ? data.units.length : data.lotes.length
            return (
              <button
                key={m}
                role="tab"
                aria-selected={active}
                onClick={() => {
                  setMode(m)
                  setSelected(new Set())
                }}
                style={{
                  padding: '12px 14px',
                  background: active ? 'var(--glass-bg-strong)' : 'transparent',
                  color: active ? 'var(--fg-0)' : 'var(--fg-2)',
                  border: 'none',
                  borderBottom: active ? '2px solid var(--accent-cyan)' : '2px solid transparent',
                  fontFamily: 'inherit',
                  fontSize: 12,
                  fontWeight: 500,
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 8,
                }}
              >
                {m === 'unidades' ? 'Unidades' : 'Lotes'}
                <span
                  className="mono"
                  style={{
                    fontSize: 10,
                    color: active ? 'var(--accent-cyan)' : 'var(--fg-3)',
                  }}
                >
                  {count}
                </span>
              </button>
            )
          })}
        </div>

        {/* Search */}
        <div style={{ padding: 12, borderBottom: '1px solid var(--glass-border)' }}>
          <label
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
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
              placeholder={mode === 'unidades' ? 'Buscar por código, item, serial...' : 'Buscar por código do lote...'}
              style={{
                flex: 1,
                background: 'transparent',
                border: 'none',
                outline: 'none',
                color: 'var(--fg-0)',
                fontFamily: 'inherit',
                fontSize: 12,
              }}
            />
          </label>
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginTop: 8,
              fontSize: 11,
              color: 'var(--fg-3)',
            }}
          >
            <button
              type="button"
              onClick={toggleAllVisible}
              style={{
                background: 'transparent',
                border: 'none',
                color: 'var(--accent-cyan)',
                fontFamily: 'inherit',
                fontSize: 11,
                cursor: 'pointer',
                padding: 0,
              }}
            >
              {filtered.every((s) => selected.has(s.id)) && filtered.length > 0
                ? 'Desmarcar visíveis'
                : 'Selecionar todos visíveis'}
            </button>
            <span className="mono">
              {selected.size} selecionados
            </span>
          </div>
        </div>

        {/* Lista */}
        <div style={{ maxHeight: 520, overflowY: 'auto' }}>
          {filtered.length === 0 ? (
            <div style={{ padding: 20, textAlign: 'center', color: 'var(--fg-3)', fontSize: 12 }}>
              Nada encontrado.
            </div>
          ) : (
            filtered.map((s) => (
              <SourceRow
                key={s.id}
                selected={selected.has(s.id)}
                onToggle={() => toggle(s.id)}
                kind={s.kind}
                row={s.row}
              />
            ))
          )}
        </div>
      </GlassCard>

      {/* Main: layout + preview + export */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <GlassCard style={{ padding: 16 }}>
          <div
            className="mono"
            style={{
              fontSize: 10,
              color: 'var(--fg-2)',
              letterSpacing: 0.12,
              textTransform: 'uppercase',
              marginBottom: 10,
            }}
          >
            Formato da folha
          </div>
          <div
            role="radiogroup"
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
              gap: 10,
            }}
          >
            {(Object.keys(QR_LAYOUTS) as QrLayoutKey[]).map((k) => {
              const l = QR_LAYOUTS[k]
              const active = layoutKey === k
              return (
                <button
                  key={k}
                  role="radio"
                  aria-checked={active}
                  onClick={() => setLayoutKey(k)}
                  style={{
                    textAlign: 'left',
                    padding: '12px 14px',
                    borderRadius: 'var(--r-sm)',
                    border: active
                      ? '1px solid color-mix(in oklch, var(--accent-cyan) 50%, transparent)'
                      : '1px solid var(--glass-border)',
                    background: active
                      ? 'color-mix(in oklch, var(--accent-cyan) 10%, transparent)'
                      : 'var(--glass-bg)',
                    color: 'inherit',
                    fontFamily: 'inherit',
                    cursor: 'pointer',
                  }}
                >
                  <div
                    style={{
                      fontSize: 13,
                      fontWeight: 500,
                      color: active ? 'var(--accent-cyan)' : 'var(--fg-0)',
                    }}
                  >
                    {l.label}
                  </div>
                  <div style={{ fontSize: 11, color: 'var(--fg-3)', marginTop: 2 }}>
                    {l.description}
                  </div>
                </button>
              )
            })}
          </div>

          <div
            style={{
              marginTop: 14,
              paddingTop: 12,
              borderTop: '1px solid var(--glass-border)',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              gap: 12,
              flexWrap: 'wrap',
            }}
          >
            <div style={{ fontSize: 12, color: 'var(--fg-2)' }}>
              {items.length === 0 ? (
                <span style={{ color: 'var(--fg-3)' }}>Nenhum código selecionado</span>
              ) : (
                <>
                  <span className="mono" style={{ color: 'var(--fg-0)', fontSize: 14 }}>
                    {items.length}
                  </span>{' '}
                  etiquetas em{' '}
                  <span className="mono" style={{ color: 'var(--fg-0)' }}>
                    {totalSheets}
                  </span>{' '}
                  {totalSheets === 1 ? 'folha' : 'folhas'}
                </>
              )}
            </div>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              {selected.size > 0 && (
                <GhostBtn small onClick={clearMode}>
                  Limpar seleção
                </GhostBtn>
              )}
              <PrimaryBtn
                small
                disabled={items.length === 0 || exporting}
                onClick={exportPdf}
              >
                {exporting ? 'Gerando...' : 'Exportar PDF'}
              </PrimaryBtn>
            </div>
          </div>

          {error && (
            <div
              style={{
                marginTop: 10,
                padding: '8px 12px',
                borderRadius: 'var(--r-sm)',
                background: 'color-mix(in oklch, var(--accent-red) 12%, transparent)',
                border: '1px solid color-mix(in oklch, var(--accent-red) 32%, transparent)',
                color: 'var(--accent-red)',
                fontSize: 12,
              }}
            >
              {error}
            </div>
          )}
        </GlassCard>

        <GlassCard style={{ padding: 18, display: 'flex', justifyContent: 'center' }}>
          <PreviewSheet items={items} layoutKey={layoutKey} />
        </GlassCard>
      </div>
    </div>
  )
}

function SourceRow({
  selected,
  onToggle,
  kind,
  row,
}: {
  selected: boolean
  onToggle: () => void
  kind: Mode
  row: QrUnit | QrLote
}) {
  const code = kind === 'unidades' ? (row as QrUnit).codigo_interno : (row as QrLote).codigo_lote
  const item = row.item_nome
  const sub =
    kind === 'unidades'
      ? (row as QrUnit).serial_fabrica
      : `${(row as QrLote).quantidade} un`
  const categoria = CATEGORIA_LABEL[row.item_categoria]

  return (
    <button
      type="button"
      onClick={onToggle}
      aria-pressed={selected}
      style={{
        width: '100%',
        display: 'grid',
        gridTemplateColumns: '20px 1fr',
        gap: 10,
        alignItems: 'center',
        padding: '10px 14px',
        background: selected ? 'color-mix(in oklch, var(--accent-cyan) 8%, transparent)' : 'transparent',
        border: 'none',
        borderBottom: '1px solid var(--glass-border)',
        cursor: 'pointer',
        textAlign: 'left',
        color: 'inherit',
        fontFamily: 'inherit',
      }}
    >
      <div
        aria-hidden
        style={{
          width: 16,
          height: 16,
          borderRadius: 4,
          border: selected
            ? '1px solid var(--accent-cyan)'
            : '1px solid var(--glass-border-strong)',
          background: selected ? 'var(--accent-cyan)' : 'transparent',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: '#000',
          fontSize: 12,
          lineHeight: 1,
        }}
      >
        {selected ? '✓' : ''}
      </div>
      <div style={{ minWidth: 0 }}>
        <div
          className="mono"
          style={{
            fontSize: 12,
            color: 'var(--fg-0)',
            fontWeight: 500,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {code}
        </div>
        <div
          style={{
            fontSize: 11,
            color: 'var(--fg-2)',
            marginTop: 2,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {item}
        </div>
        <div
          className="mono"
          style={{
            fontSize: 9,
            color: 'var(--fg-3)',
            marginTop: 2,
            letterSpacing: 0.1,
            textTransform: 'uppercase',
          }}
        >
          {categoria}
          {sub && (
            <>
              {' · '}
              {sub}
            </>
          )}
        </div>
      </div>
    </button>
  )
}
