'use client'

import { useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { ThemeToggle } from '@/components/mmd/ThemeToggle'

const CATALOG_MODE_KEY = 'mmd.catalog.mode.v1'

const STORAGE_KEYS = [
  'mmd-theme',
  CATALOG_MODE_KEY,
  'mmd.catalog.view.v1',
  'mmd.catalog.units.view.v1',
]

// ─── Building blocks ─────────────────────────────────────

function SettingRow({
  label,
  hint,
  control,
  first = false,
}: {
  label: string
  hint?: string
  control: ReactNode
  first?: boolean
}) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 20,
        padding: '14px 0',
        borderTop: first ? 'none' : '1px solid var(--glass-border)',
      }}
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 3, minWidth: 0, flex: 1 }}>
        <span style={{ fontSize: 13, color: 'var(--fg-0)', fontWeight: 450 }}>{label}</span>
        {hint && (
          <span style={{ fontSize: 12, color: 'var(--fg-3)', lineHeight: 1.45 }}>{hint}</span>
        )}
      </div>
      <div style={{ flexShrink: 0 }}>{control}</div>
    </div>
  )
}

function Section({
  title,
  children,
}: {
  title: string
  children: ReactNode
}) {
  return (
    <section
      style={{
        padding: '28px 0',
        borderBottom: '1px solid var(--glass-border)',
      }}
    >
      <h2
        style={{
          fontSize: 11,
          fontWeight: 500,
          letterSpacing: 0.14,
          textTransform: 'uppercase',
          color: 'var(--fg-3)',
          margin: '0 0 8px',
        }}
        className="mono"
      >
        {title}
      </h2>
      <div>{children}</div>
    </section>
  )
}

// ─── Controls ────────────────────────────────────────────

function SegmentedControl<T extends string>({
  value,
  options,
  onChange,
  ariaLabel,
}: {
  value: T
  options: Array<{ value: T; label: string }>
  onChange: (next: T) => void
  ariaLabel: string
}) {
  return (
    <div
      role="radiogroup"
      aria-label={ariaLabel}
      style={{
        display: 'inline-flex',
        padding: 3,
        borderRadius: 10,
        background: 'var(--glass-bg)',
        border: '1px solid var(--glass-border)',
      }}
    >
      {options.map((opt) => {
        const active = opt.value === value
        return (
          <button
            key={opt.value}
            type="button"
            role="radio"
            aria-checked={active}
            onClick={() => onChange(opt.value)}
            style={{
              padding: '6px 14px',
              borderRadius: 7,
              border: 'none',
              fontSize: 12,
              fontFamily: 'inherit',
              fontWeight: active ? 500 : 400,
              cursor: 'pointer',
              background: active ? 'var(--fg-0)' : 'transparent',
              color: active ? 'var(--bg-0)' : 'var(--fg-1)',
              transition: 'background var(--motion-fast), color var(--motion-fast)',
            }}
          >
            {opt.label}
          </button>
        )
      })}
    </div>
  )
}

function GhostButton({
  onClick,
  disabled,
  children,
  tone = 'neutral',
}: {
  onClick?: () => void
  disabled?: boolean
  children: ReactNode
  tone?: 'neutral' | 'danger'
}) {
  const base = {
    padding: '7px 13px',
    borderRadius: 7,
    fontSize: 12,
    fontFamily: 'inherit',
    fontWeight: 450,
    cursor: disabled ? 'not-allowed' : 'pointer',
    opacity: disabled ? 0.5 : 1,
    transition: 'background var(--motion-fast), border-color var(--motion-fast)',
  }
  const toneStyles =
    tone === 'danger'
      ? {
          background: 'color-mix(in oklch, var(--accent-red) 14%, transparent)',
          border: '1px solid color-mix(in oklch, var(--accent-red) 35%, transparent)',
          color: 'var(--accent-red)',
        }
      : {
          background: 'var(--glass-bg)',
          border: '1px solid var(--glass-border)',
          color: 'var(--fg-1)',
        }
  return (
    <button type="button" onClick={onClick} disabled={disabled} style={{ ...base, ...toneStyles }}>
      {children}
    </button>
  )
}

// ─── Main ────────────────────────────────────────────────

export function ConfigClient() {
  const [catalogMode, setCatalogMode] = useState<'tipos' | 'unidades'>('tipos')
  const [savedCount, setSavedCount] = useState(0)
  const [confirming, setConfirming] = useState(false)
  const [justReset, setJustReset] = useState(false)

  const refreshCount = () => {
    if (typeof window === 'undefined') return
    let n = 0
    for (const k of STORAGE_KEYS) {
      if (window.localStorage.getItem(k) !== null) n += 1
    }
    setSavedCount(n)
  }

  useEffect(() => {
    refreshCount()
    try {
      const raw = window.localStorage.getItem(CATALOG_MODE_KEY)
      if (raw === 'tipos' || raw === 'unidades') setCatalogMode(raw)
    } catch {}
  }, [])

  const handleCatalogMode = (next: 'tipos' | 'unidades') => {
    setCatalogMode(next)
    try {
      window.localStorage.setItem(CATALOG_MODE_KEY, next)
    } catch {}
    refreshCount()
  }

  const doReset = () => {
    for (const k of STORAGE_KEYS) {
      window.localStorage.removeItem(k)
    }
    document.documentElement.classList.remove('dark')
    setCatalogMode('tipos')
    setConfirming(false)
    setJustReset(true)
    refreshCount()
    window.setTimeout(() => setJustReset(false), 2400)
  }

  return (
    <div style={{ maxWidth: 640 }}>
      <Section title="Aparência">
        <SettingRow
          first
          label="Tema"
          hint="Alterna entre claro e escuro."
          control={<ThemeToggle />}
        />
      </Section>

      <Section title="Catálogo">
        <SettingRow
          first
          label="Modo padrão ao abrir /items"
          hint="Tipos mostra produtos agregados. Unidades lista cada serial individualmente."
          control={
            <SegmentedControl
              value={catalogMode}
              onChange={handleCatalogMode}
              ariaLabel="Modo padrão do catálogo"
              options={[
                { value: 'tipos', label: 'Tipos' },
                { value: 'unidades', label: 'Unidades' },
              ]}
            />
          }
        />
      </Section>

      <Section title="Dados locais">
        <SettingRow
          first
          label="Resetar preferências"
          hint={
            savedCount > 0
              ? `${savedCount} ${
                  savedCount === 1 ? 'preferência salva' : 'preferências salvas'
                } neste navegador. Volta tudo ao padrão.`
              : 'Nada pra resetar. Tudo no padrão.'
          }
          control={
            justReset ? (
              <span
                className="mono"
                style={{ fontSize: 11, color: 'var(--accent-green)', letterSpacing: 0.08 }}
              >
                ✓ Resetado
              </span>
            ) : confirming ? (
              <div style={{ display: 'flex', gap: 8 }}>
                <GhostButton onClick={() => setConfirming(false)}>Cancelar</GhostButton>
                <GhostButton tone="danger" onClick={doReset}>
                  Confirmar
                </GhostButton>
              </div>
            ) : (
              <GhostButton
                onClick={() => setConfirming(true)}
                disabled={savedCount === 0}
              >
                Resetar
              </GhostButton>
            )
          }
        />
      </Section>
    </div>
  )
}
