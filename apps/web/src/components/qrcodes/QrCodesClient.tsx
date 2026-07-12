'use client'

import Link from 'next/link'
import { useMemo, useState } from 'react'
import { CATEGORIA_LABEL } from '@/components/catalog/helpers'
import { Icons } from '@/components/mmd/Icons'
import { Badge, Btn, GlassCard } from '@/components/mmd/Primitives'
import type { QrSources, QrUnit } from '@/lib/data/qrcodes'
import { QR_LAYOUTS, type QrItem, type QrLayoutKey } from './layouts'
import { PreviewSheet } from './PreviewSheet'

export function QrCodesClient({ data }: { data: QrSources }) {
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [layoutKey, setLayoutKey] = useState<QrLayoutKey>('small')
  const [exporting, setExporting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return data.units
    return data.units.filter((unit) => {
      return (
        unit.codigo_interno.toLowerCase().includes(q) ||
        unit.item_nome.toLowerCase().includes(q) ||
        (unit.serial_fabrica ?? '').toLowerCase().includes(q) ||
        (unit.tag_rfid ?? '').toLowerCase().includes(q)
      )
    })
  }, [data.units, query])

  const items: QrItem[] = useMemo(() => {
    const origin = typeof window === 'undefined' ? '' : window.location.origin
    const publicPayload = (code: string) => `${origin}/s/${encodeURIComponent(code)}`

    return data.units
      .filter((unit) => selected.has(unit.id))
      .map((unit) => ({
        payload: publicPayload(unit.codigo_interno),
        title: unit.codigo_interno,
        subtitle: unit.item_nome,
        caption:
          unit.item_categoria === 'CABO' && unit.rfid_pending
            ? `${CATEGORIA_LABEL[unit.item_categoria]} / RFID pendente`
            : CATEGORIA_LABEL[unit.item_categoria],
      }))
  }, [data.units, selected])

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
    const allSelected = filtered.length > 0 && filtered.every((unit) => selected.has(unit.id))
    setSelected((prev) => {
      const next = new Set(prev)
      if (allSelected) {
        for (const unit of filtered) next.delete(unit.id)
      } else {
        for (const unit of filtered) next.add(unit.id)
      }
      return next
    })
  }

  function clearSelection() {
    setSelected(new Set())
  }

  async function exportPdf() {
    if (items.length === 0) return
    setExporting(true)
    setError(null)
    try {
      const res = await fetch('/api/qr-sheet', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ items, layout: layoutKey }),
      })
      if (!res.ok) {
        if (res.status === 504) {
          throw new Error('Seleção grande demais, divida em menos unidades e tente de novo.')
        }
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
      <GlassCard style={{ padding: 0, overflow: 'hidden' }}>
        <div
          style={{
            padding: 14,
            borderBottom: '1px solid var(--glass-border)',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            gap: 12,
          }}
        >
          <div style={{ minWidth: 0 }}>
            <div
              className="mono"
              style={{
                fontSize: 10,
                color: 'var(--fg-2)',
                letterSpacing: 0.12,
                textTransform: 'uppercase',
              }}
            >
              Fonte unit-only
            </div>
            <div style={{ marginTop: 4, color: 'var(--fg-0)', fontSize: 15, fontWeight: 500 }}>
              Unidades físicas
            </div>
          </div>
          <Badge color="var(--accent-cyan)">Unit-only</Badge>
        </div>

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
              placeholder="Buscar por código, item, serial ou RFID"
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
              {filtered.length > 0 && filtered.every((unit) => selected.has(unit.id))
                ? 'Desmarcar visíveis'
                : 'Selecionar todos visíveis'}
            </button>
            <span className="mono">{selected.size} selecionados</span>
          </div>

          {data.legacy_lotes > 0 && (
            <div
              style={{
                marginTop: 10,
                padding: '9px 10px',
                borderRadius: 'var(--r-sm)',
                border: '1px solid var(--glass-border)',
                background: 'var(--glass-bg)',
                color: 'var(--fg-2)',
                fontSize: 11,
                lineHeight: 1.35,
              }}
            >
              {data.legacy_lotes} lotes ficaram fora da geração. QR novo aponta só para unidade
              física. {data.legacy_cable_lotes} são lotes antigos de cabo.
            </div>
          )}
        </div>

        <div style={{ maxHeight: 520, overflowY: 'auto' }}>
          {filtered.length === 0 ? (
            <div style={{ padding: 20, textAlign: 'center', color: 'var(--fg-3)', fontSize: 12 }}>
              Nenhuma unidade encontrada.
            </div>
          ) : (
            filtered.map((unit) => (
              <SourceRow
                key={unit.id}
                selected={selected.has(unit.id)}
                onToggle={() => toggle(unit.id)}
                unit={unit}
              />
            ))
          )}
        </div>
      </GlassCard>

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
            {(Object.keys(QR_LAYOUTS) as QrLayoutKey[]).map((key) => {
              const qrLayout = QR_LAYOUTS[key]
              const active = layoutKey === key
              return (
                <button
                  key={key}
                  role="radio"
                  aria-checked={active}
                  onClick={() => setLayoutKey(key)}
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
                    {qrLayout.label}
                  </div>
                  <div style={{ fontSize: 11, color: 'var(--fg-3)', marginTop: 2 }}>
                    {qrLayout.description}
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
                <Btn variant="ghost" small onClick={clearSelection}>
                  Limpar seleção
                </Btn>
              )}
              <Btn small disabled={items.length === 0 || exporting} onClick={exportPdf}>
                {exporting ? 'Gerando...' : 'Exportar PDF'}
              </Btn>
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
  unit,
}: {
  selected: boolean
  onToggle: () => void
  unit: QrUnit
}) {
  const sub = unit.rfid_pending ? 'RFID pendente' : unit.serial_fabrica || unit.tag_rfid
  const categoria = CATEGORIA_LABEL[unit.item_categoria]

  return (
    <div
      style={{
        width: '100%',
        display: 'grid',
        gridTemplateColumns: '20px minmax(0, 1fr) auto',
        gap: 10,
        alignItems: 'center',
        padding: '10px 14px',
        background: selected
          ? 'color-mix(in oklch, var(--accent-cyan) 8%, transparent)'
          : 'transparent',
        borderBottom: '1px solid var(--glass-border)',
        textAlign: 'left',
        color: 'inherit',
        fontFamily: 'inherit',
      }}
    >
      <button
        type="button"
        onClick={onToggle}
        aria-pressed={selected}
        aria-label={
          selected
            ? `Remover ${unit.codigo_interno} da folha`
            : `Adicionar ${unit.codigo_interno} à folha`
        }
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
          cursor: 'pointer',
        }}
      >
        {selected ? '✓' : ''}
      </button>
      <button
        type="button"
        onClick={onToggle}
        aria-label={
          selected
            ? `Remover ${unit.codigo_interno} da folha`
            : `Adicionar ${unit.codigo_interno} à folha`
        }
        style={{
          minWidth: 0,
          border: 'none',
          background: 'transparent',
          padding: 0,
          color: 'inherit',
          fontFamily: 'inherit',
          textAlign: 'left',
          cursor: 'pointer',
        }}
      >
        <SourceSummary
          code={unit.codigo_interno}
          item={unit.item_nome}
          categoria={categoria}
          sub={sub}
          warn={unit.rfid_pending}
        />
      </button>
      <Link
        href={`/qrcodes/${encodeURIComponent(unit.codigo_interno)}`}
        aria-label={`Abrir ficha interna de ${unit.codigo_interno}`}
        style={{
          minHeight: 30,
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 6,
          padding: '0 10px',
          borderRadius: 8,
          border: '1px solid var(--glass-border)',
          background: 'var(--glass-bg)',
          color: 'var(--fg-1)',
          textDecoration: 'none',
          fontSize: 11,
          whiteSpace: 'nowrap',
        }}
      >
        Ficha
        <span aria-hidden>{Icons.arrow}</span>
      </Link>
    </div>
  )
}

function SourceSummary({
  code,
  item,
  categoria,
  sub,
  warn,
}: {
  code: string
  item: string
  categoria: string
  sub: string | null
  warn?: boolean
}) {
  return (
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
          color: warn ? 'var(--accent-amber)' : 'var(--fg-3)',
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
  )
}
