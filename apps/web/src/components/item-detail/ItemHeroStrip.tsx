'use client'

import { useState } from 'react'
import { Icons } from '@/components/mmd/Icons'
import { GlassCard, Ring } from '@/components/mmd/Primitives'
import {
  CATEGORIA_ICON,
  CATEGORIA_LABEL,
} from '@/components/catalog/helpers'
import type { CatalogItem } from '@/lib/data/items'
import { ESTADO_LABEL, dominantEstado } from './helpers'
import type { Estado } from '@/lib/types'

type Props = {
  item: CatalogItem
  serialsCount: number
  serialEstados: { estado: Estado }[]
}

export function ItemHeroStrip({ item, serialsCount, serialEstados }: Props) {
  const [menuOpen, setMenuOpen] = useState(false)

  const iconKey = CATEGORIA_ICON[item.categoria] as keyof typeof Icons
  const disponivel = item.disponivel_count
  const ativos =
    item.disponivel_count + item.em_campo_count + item.manutencao_count
  const readyPct = ativos > 0 ? (disponivel / ativos) * 100 : 0
  const estado = dominantEstado(serialEstados)

  const ringState: 'ready' | 'partial' | 'missing' =
    readyPct >= 66 ? 'ready' : readyPct >= 33 ? 'partial' : 'missing'

  return (
    <GlassCard
      strong
      style={{
        padding: 20,
        display: 'grid',
        gridTemplateColumns: '120px minmax(0, 1fr) auto',
        gap: 22,
        alignItems: 'center',
        position: 'relative',
      }}
    >
      {/* Foto */}
      <div
        style={{
          width: 120,
          height: 120,
          borderRadius: 16,
          border: '1px solid var(--glass-border)',
          background: 'var(--glass-bg)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          overflow: 'hidden',
          color: 'var(--fg-3)',
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
          <div style={{ opacity: 0.6 }}>{Icons[iconKey]}</div>
        )}
      </div>

      {/* Identidade */}
      <div style={{ minWidth: 0 }}>
        <div
          className="mono"
          style={{
            fontSize: 10,
            color: 'var(--accent-cyan)',
            letterSpacing: 0.12,
            textTransform: 'uppercase',
          }}
        >
          {CATEGORIA_LABEL[item.categoria]}
          {item.subcategoria && (
            <span style={{ color: 'var(--fg-3)' }}>
              {' · '}
              {item.subcategoria}
            </span>
          )}
        </div>

        <div
          style={{
            fontSize: 24,
            fontWeight: 500,
            color: 'var(--fg-0)',
            letterSpacing: -0.4,
            marginTop: 4,
            lineHeight: 1.15,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {item.nome}
        </div>

        <div
          style={{
            fontSize: 13,
            color: 'var(--fg-2)',
            marginTop: 4,
            display: 'flex',
            gap: 10,
            alignItems: 'center',
            flexWrap: 'wrap',
          }}
        >
          {(item.marca || item.modelo) && (
            <span>{[item.marca, item.modelo].filter(Boolean).join(' · ')}</span>
          )}
          {item.codigo_interno && (
            <span
              className="mono"
              style={{
                fontSize: 11,
                color: 'var(--fg-3)',
                padding: '2px 8px',
                borderRadius: 6,
                background: 'var(--glass-bg)',
                border: '1px solid var(--glass-border)',
              }}
            >
              {item.codigo_interno}
            </span>
          )}
          {estado && (
            <span
              className="mono"
              style={{
                fontSize: 10,
                letterSpacing: 0.12,
                padding: '2px 8px',
                borderRadius: 6,
                background: 'color-mix(in oklch, var(--accent-violet) 16%, transparent)',
                color: 'var(--accent-violet)',
                border: '1px solid color-mix(in oklch, var(--accent-violet) 32%, transparent)',
                textTransform: 'uppercase',
              }}
            >
              {ESTADO_LABEL[estado]}
            </span>
          )}
        </div>
      </div>

      {/* Ring de prontidão */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 18,
        }}
      >
        <div style={{ textAlign: 'right' }}>
          <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.12 }}>
            PRONTIDÃO
          </div>
          <div
            style={{
              fontSize: 20,
              fontWeight: 500,
              color: 'var(--fg-0)',
              marginTop: 2,
              fontFamily: 'var(--font-mono-raw)',
            }}
          >
            {disponivel}
            <span style={{ color: 'var(--fg-3)', fontWeight: 400 }}>/{ativos}</span>
          </div>
          <div style={{ fontSize: 11, color: 'var(--fg-3)', marginTop: 2 }}>
            disponíveis agora
          </div>
        </div>
        <Ring value={readyPct} size={88} stroke={7} state={ringState} decorative />

        {/* Menu "..." */}
        <div style={{ position: 'relative', alignSelf: 'flex-start' }}>
          <button
            aria-label="Mais ações"
            onClick={() => setMenuOpen((v) => !v)}
            className="glass"
            style={{
              width: 32,
              height: 32,
              borderRadius: 8,
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'var(--fg-1)',
              cursor: 'pointer',
              padding: 0,
              border: '1px solid var(--glass-border)',
              background: 'var(--glass-bg)',
              fontSize: 16,
              fontWeight: 600,
              lineHeight: 1,
            }}
          >
            ⋯
          </button>
          {menuOpen && (
            <>
              <button
                aria-hidden
                tabIndex={-1}
                onClick={() => setMenuOpen(false)}
                style={{
                  position: 'fixed',
                  inset: 0,
                  background: 'transparent',
                  border: 'none',
                  cursor: 'default',
                  zIndex: 20,
                }}
              />
              <div
                role="menu"
                className="glass glass-strong"
                style={{
                  position: 'absolute',
                  top: 38,
                  right: 0,
                  minWidth: 200,
                  padding: 6,
                  borderRadius: 12,
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 2,
                  zIndex: 21,
                }}
              >
                <MenuItem>Editar tipo</MenuItem>
                <MenuItem>Duplicar</MenuItem>
                <MenuItem>Transferir categoria</MenuItem>
                <MenuItem danger>Arquivar</MenuItem>
              </div>
            </>
          )}
        </div>
      </div>
    </GlassCard>
  )
}

function MenuItem({
  children,
  danger,
}: {
  children: React.ReactNode
  danger?: boolean
}) {
  return (
    <button
      role="menuitem"
      style={{
        textAlign: 'left',
        padding: '8px 10px',
        borderRadius: 8,
        fontSize: 12,
        color: danger ? 'var(--accent-red)' : 'var(--fg-1)',
        background: 'transparent',
        border: 'none',
        cursor: 'pointer',
        fontFamily: 'inherit',
      }}
    >
      {children}
    </button>
  )
}
