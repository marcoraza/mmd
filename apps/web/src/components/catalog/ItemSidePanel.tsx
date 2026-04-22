'use client'

import { useEffect } from 'react'
import { Icons } from '@/components/mmd/Icons'
import type { CatalogItem } from '@/lib/data/items'
import {
  CATEGORIA_ICON,
  CATEGORIA_LABEL,
  CICLO_LABEL,
  SITUACAO_COLOR,
  SITUACAO_LABEL,
  formatBRL,
} from './helpers'
import { EditableStars } from './EditableStars'

export function ItemSidePanel({
  item,
  onClose,
  onCondicaoChange,
  pending,
}: {
  item: CatalogItem | null
  onClose: () => void
  onCondicaoChange?: (itemId: string, desgaste: number) => void
  pending?: string | null
}) {
  useEffect(() => {
    if (!item) return
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [item, onClose])

  if (!item) return null

  const iconKey = CATEGORIA_ICON[item.categoria] as keyof typeof Icons

  return (
    <>
      <button
        aria-label="Fechar painel"
        onClick={onClose}
        style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(0, 0, 0, 0.35)',
          backdropFilter: 'blur(4px)',
          WebkitBackdropFilter: 'blur(4px)',
          border: 'none',
          cursor: 'pointer',
          zIndex: 40,
          animation: 'mmd-reveal 240ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
        }}
      />
      <aside
        role="dialog"
        aria-label={`Detalhes de ${item.nome}`}
        style={{
          position: 'fixed',
          top: 0,
          right: 0,
          bottom: 0,
          width: 'min(480px, 100vw)',
          background: 'var(--bg-0)',
          borderLeft: '1px solid var(--glass-border-strong)',
          boxShadow: 'var(--glass-shadow-elevated)',
          zIndex: 41,
          overflowY: 'auto',
          animation: 'slide-in-right 280ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
        }}
      >
        <div
          style={{
            position: 'sticky',
            top: 0,
            padding: '18px 22px',
            borderBottom: '1px solid var(--glass-border)',
            background: 'var(--bg-0)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 12,
            zIndex: 1,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
            <span style={{ display: 'inline-flex', color: 'var(--accent-cyan)' }}>
              {Icons[iconKey]}
            </span>
            <span
              className="mono"
              style={{
                fontSize: 10,
                color: 'var(--fg-2)',
                letterSpacing: 0.1,
                textTransform: 'uppercase',
              }}
            >
              {CATEGORIA_LABEL[item.categoria]}
            </span>
          </div>
          <button
            onClick={onClose}
            aria-label="Fechar"
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: 28,
              height: 28,
              border: '1px solid var(--glass-border)',
              borderRadius: 'var(--r-sm)',
              background: 'transparent',
              color: 'var(--fg-1)',
              cursor: 'pointer',
            }}
          >
            {Icons.x}
          </button>
        </div>

        <div style={{ padding: 22, display: 'flex', flexDirection: 'column', gap: 22 }}>
          <div
            style={{
              aspectRatio: '4 / 3',
              width: '100%',
              borderRadius: 'var(--r-md)',
              border: '1px solid var(--glass-border)',
              background: 'var(--glass-bg)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'var(--fg-3)',
              position: 'relative',
              overflow: 'hidden',
            }}
          >
            {item.foto_url ? (
              /* eslint-disable-next-line @next/next/no-img-element */
              <img
                src={item.foto_url}
                alt={item.nome}
                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
              />
            ) : (
              <div style={{ textAlign: 'center' }}>
                <div style={{ opacity: 0.5, marginBottom: 8 }}>{Icons[iconKey]}</div>
                <div className="mono" style={{ fontSize: 10, letterSpacing: 0.1, textTransform: 'uppercase' }}>
                  Sem foto
                </div>
              </div>
            )}
          </div>

          <section>
            <div style={{ fontSize: 22, fontWeight: 500, letterSpacing: -0.3, color: 'var(--fg-0)' }}>
              {item.nome}
            </div>
            {(item.marca || item.modelo) && (
              <div style={{ fontSize: 13, color: 'var(--fg-2)', marginTop: 4 }}>
                {[item.marca, item.modelo].filter(Boolean).join(' · ')}
              </div>
            )}
            {item.subcategoria && (
              <div className="mono" style={{ fontSize: 11, color: 'var(--fg-2)', marginTop: 8, letterSpacing: 0.1, textTransform: 'uppercase' }}>
                {item.subcategoria}
              </div>
            )}
          </section>

          <Section title="Identificação">
            <Row label="Código interno" value={item.id.slice(0, 8)} mono />
            <Row
              label="Rastreamento"
              value={
                <span style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                  <span style={{ display: 'inline-flex', color: 'var(--fg-2)' }}>{Icons.rfid}</span>
                  <span style={{ color: 'var(--fg-3)', fontSize: 12 }}>RFID via iOS</span>
                  <span style={{ display: 'inline-flex', color: 'var(--fg-2)' }}>{Icons.qr}</span>
                  <span style={{ color: 'var(--fg-3)', fontSize: 12 }}>QR gerado</span>
                </span>
              }
            />
          </Section>

          <Section title="Condição">
            <Row
              label="Situação"
              value={
                <span
                  style={{
                    display: 'inline-block',
                    padding: '3px 10px',
                    borderRadius: 'var(--r-sm)',
                    fontSize: 11,
                    fontWeight: 500,
                    background: 'var(--glass-bg-strong)',
                    color: SITUACAO_COLOR[item.situacao],
                    border: `1px solid ${SITUACAO_COLOR[item.situacao]}40`,
                  }}
                >
                  {SITUACAO_LABEL[item.situacao]}
                </span>
              }
            />
            <Row label="Ciclo" value={item.ciclo ? CICLO_LABEL[item.ciclo] : '–'} />
            <Row
              label="Condição"
              value={
                <EditableStars
                  value={item.condicao_media}
                  size={14}
                  pending={pending === `condicao:${item.id}`}
                  onChange={(n) => onCondicaoChange?.(item.id, n)}
                />
              }
            />
            <Row label="Qtd total" value={item.quantidade_total.toString()} mono />
          </Section>

          <Section title="Distribuição">
            <Row label="Disponível" value={item.disponivel_count.toString()} mono color="var(--accent-green)" />
            <Row label="Em campo" value={item.em_campo_count.toString()} mono color="var(--accent-cyan)" />
            <Row label="Manutenção" value={item.manutencao_count.toString()} mono color="var(--accent-amber)" />
            <Row label="Críticos" value={item.criticos_count.toString()} mono color={item.criticos_count > 0 ? 'var(--accent-red)' : 'var(--fg-2)'} />
          </Section>

          <Section title="Valor">
            <Row label="Valor mercado (unid.)" value={formatBRL(item.valor_mercado_unitario)} mono />
            <Row label="Valor atual (total)" value={formatBRL(item.valor_atual_total)} mono />
          </Section>

          <div
            style={{
              display: 'flex',
              gap: 8,
              flexWrap: 'wrap',
              paddingTop: 8,
              borderTop: '1px solid var(--glass-border)',
            }}
          >
            <ActionButton disabled>Editar</ActionButton>
            <ActionButton disabled>Marcar manutenção</ActionButton>
            <ActionButton disabled>Imprimir etiqueta</ActionButton>
          </div>
        </div>

        <style>{`
          @keyframes slide-in-right {
            from { transform: translateX(100%); opacity: 0; }
            to { transform: translateX(0); opacity: 1; }
          }
        `}</style>
      </aside>
    </>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div
        className="mono"
        style={{
          fontSize: 10,
          color: 'var(--fg-2)',
          letterSpacing: 0.1,
          textTransform: 'uppercase',
          paddingBottom: 6,
          borderBottom: '1px solid var(--glass-border)',
        }}
      >
        {title}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>{children}</div>
    </section>
  )
}

function Row({
  label,
  value,
  mono,
  color,
}: {
  label: string
  value: React.ReactNode
  mono?: boolean
  color?: string
}) {
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        gap: 12,
        padding: '4px 0',
      }}
    >
      <span style={{ fontSize: 12, color: 'var(--fg-2)' }}>{label}</span>
      <span
        className={mono ? 'mono' : undefined}
        style={{ fontSize: 13, color: color ?? 'var(--fg-0)', textAlign: 'right' }}
      >
        {value}
      </span>
    </div>
  )
}

function ActionButton({
  children,
  disabled,
}: {
  children: React.ReactNode
  disabled?: boolean
}) {
  return (
    <button
      disabled={disabled}
      style={{
        padding: '8px 12px',
        border: '1px solid var(--glass-border)',
        borderRadius: 'var(--r-sm)',
        background: 'var(--glass-bg)',
        color: disabled ? 'var(--fg-3)' : 'var(--fg-1)',
        fontFamily: 'inherit',
        fontSize: 12,
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.6 : 1,
      }}
    >
      {children}
    </button>
  )
}
