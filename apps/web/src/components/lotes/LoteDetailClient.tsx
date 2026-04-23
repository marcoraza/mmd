'use client'

import Link from 'next/link'
import { Icons } from '@/components/mmd/Icons'
import {
  GlassCard,
  GhostBtn,
  PrimaryBtn,
  StatusDot,
} from '@/components/mmd/Primitives'
import {
  CATEGORIA_ICON,
  CATEGORIA_LABEL,
} from '@/components/catalog/helpers'
import type { LoteRow } from '@/lib/data/lotes'
import { STATUS_LOTE_COLOR, STATUS_LOTE_LABEL, formatLoteDate } from './helpers'
import { QrPlaceholder } from './QrPlaceholder'

type Props = {
  lote: LoteRow
  related: LoteRow[]
}

export function LoteDetailClient({ lote, related }: Props) {
  const color = STATUS_LOTE_COLOR[lote.status]
  const iconKey = CATEGORIA_ICON[lote.item_categoria] as keyof typeof Icons
  const valorTotal =
    lote.item_valor_mercado_unitario != null
      ? lote.item_valor_mercado_unitario * lote.quantidade
      : null

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* Hero */}
      <GlassCard
        strong
        style={{
          padding: 20,
          display: 'grid',
          gridTemplateColumns: '216px minmax(0, 1fr) auto',
          gap: 24,
          alignItems: 'center',
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <QrPlaceholder value={lote.codigo_lote} size={200} />
        </div>

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
            Lote de {CATEGORIA_LABEL[lote.item_categoria]}
            {lote.item_subcategoria && (
              <span style={{ color: 'var(--fg-3)' }}>
                {' · '}
                {lote.item_subcategoria}
              </span>
            )}
          </div>

          <div
            className="mono"
            style={{
              fontSize: 28,
              fontWeight: 500,
              color: 'var(--fg-0)',
              letterSpacing: -0.4,
              marginTop: 4,
              lineHeight: 1.15,
            }}
          >
            {lote.codigo_lote}
          </div>

          <div
            style={{
              marginTop: 8,
              display: 'flex',
              gap: 10,
              alignItems: 'center',
              flexWrap: 'wrap',
            }}
          >
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                padding: '4px 10px',
                borderRadius: 'var(--r-sm)',
                fontSize: 12,
                fontWeight: 500,
                background: `color-mix(in oklch, ${color} 14%, transparent)`,
                color,
                border: `1px solid color-mix(in oklch, ${color} 36%, transparent)`,
              }}
            >
              <StatusDot color={color} size={7} />
              {STATUS_LOTE_LABEL[lote.status]}
            </span>

            <Link
              href={`/items/${lote.item_id}`}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 8,
                padding: '4px 10px',
                borderRadius: 'var(--r-sm)',
                background: 'var(--glass-bg)',
                border: '1px solid var(--glass-border)',
                color: 'var(--fg-1)',
                fontSize: 12,
                textDecoration: 'none',
              }}
            >
              <span style={{ color: 'var(--fg-3)', display: 'inline-flex' }}>
                {Icons[iconKey]}
              </span>
              <span>{lote.item_nome}</span>
              <span style={{ color: 'var(--fg-3)' }}>›</span>
            </Link>

            {lote.item_marca && (
              <span
                className="mono"
                style={{
                  fontSize: 10,
                  letterSpacing: 0.12,
                  textTransform: 'uppercase',
                  color: 'var(--fg-3)',
                }}
              >
                {lote.item_marca}
              </span>
            )}
          </div>

          <div
            style={{
              marginTop: 14,
              fontSize: 13,
              color: lote.descricao ? 'var(--fg-1)' : 'var(--fg-3)',
              lineHeight: 1.5,
              maxWidth: 640,
            }}
          >
            {lote.descricao ?? 'Sem descrição cadastrada para este lote.'}
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'flex-end' }}>
          <PrimaryBtn small>Imprimir QR</PrimaryBtn>
          <GhostBtn small>Editar lote</GhostBtn>
          <GhostBtn small>Marcar manutenção</GhostBtn>
        </div>
      </GlassCard>

      {/* Cards de composição + meta */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
          gap: 16,
        }}
      >
        <GlassCard style={{ padding: 18 }}>
          <SectionLabel>Composição</SectionLabel>
          <div
            className="mono"
            style={{
              fontSize: 44,
              fontWeight: 500,
              color: 'var(--fg-0)',
              letterSpacing: -1,
              marginTop: 6,
              lineHeight: 1,
            }}
          >
            {lote.quantidade}
            <span
              style={{
                fontSize: 14,
                color: 'var(--fg-3)',
                marginLeft: 8,
                letterSpacing: 0,
              }}
            >
              unidades
            </span>
          </div>
          <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 8 }}>
            Todas do mesmo tipo ({lote.item_nome}), agrupadas sob um único QR
            code para leitura rápida em campo.
          </div>
          {valorTotal != null && (
            <div
              style={{
                marginTop: 14,
                paddingTop: 12,
                borderTop: '1px solid var(--glass-border)',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
              }}
            >
              <span className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.12, textTransform: 'uppercase' }}>
                Valor estimado
              </span>
              <span className="mono" style={{ fontSize: 14, color: 'var(--fg-0)' }}>
                {formatBRL(valorTotal)}
              </span>
            </div>
          )}
        </GlassCard>

        <GlassCard style={{ padding: 18 }}>
          <SectionLabel>Identificação</SectionLabel>
          <MetaRow label="Tag RFID" value={lote.tag_rfid} mono highlight={lote.tag_rfid ? 'cyan' : undefined} />
          <MetaRow label="QR code" value={lote.qr_code} mono />
          <MetaRow label="ID interno" value={lote.id} mono muted />
        </GlassCard>

        <GlassCard style={{ padding: 18 }}>
          <SectionLabel>Histórico</SectionLabel>
          <MetaRow label="Criado" value={formatLoteDate(lote.created_at)} />
          <MetaRow label="Atualizado" value={formatLoteDate(lote.updated_at)} />
          <MetaRow label="Status atual" value={STATUS_LOTE_LABEL[lote.status]} highlightColor={color} />
        </GlassCard>
      </div>

      {/* Timeline stub */}
      <GlassCard style={{ padding: 18 }}>
        <SectionLabel>Movimentações</SectionLabel>
        <div
          style={{
            marginTop: 10,
            padding: '20px 16px',
            borderRadius: 'var(--r-sm)',
            border: '1px dashed var(--glass-border)',
            background: 'var(--glass-bg)',
            color: 'var(--fg-2)',
            fontSize: 13,
            lineHeight: 1.5,
          }}
        >
          Movimentações por lote ainda não são rastreadas individualmente. No
          momento, o sistema registra movimentações apenas por serial (item
          único). Quando um lote é levado para evento, a leitura do QR marca o
          status do lote inteiro.
        </div>
      </GlassCard>

      {/* Related lotes */}
      {related.length > 0 && (
        <GlassCard style={{ padding: 18 }}>
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: 10,
            }}
          >
            <SectionLabel>Outros lotes de {lote.item_nome}</SectionLabel>
            <Link
              href="/lotes"
              style={{ fontSize: 12, color: 'var(--accent-cyan)', textDecoration: 'none' }}
            >
              Ver todos ›
            </Link>
          </div>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))',
              gap: 12,
            }}
          >
            {related.map((r) => {
              const rc = STATUS_LOTE_COLOR[r.status]
              return (
                <Link
                  key={r.id}
                  href={`/lotes/${r.id}`}
                  style={{
                    display: 'block',
                    padding: 12,
                    borderRadius: 'var(--r-sm)',
                    border: '1px solid var(--glass-border)',
                    background: 'var(--glass-bg)',
                    textDecoration: 'none',
                    color: 'inherit',
                    transition: 'background var(--motion-fast)',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.background = 'var(--glass-bg-strong)'
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = 'var(--glass-bg)'
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <span
                      className="mono"
                      style={{ fontSize: 12, color: 'var(--fg-0)', fontWeight: 500 }}
                    >
                      {r.codigo_lote}
                    </span>
                    <StatusDot color={rc} size={7} />
                  </div>
                  <div
                    className="mono"
                    style={{
                      fontSize: 20,
                      color: 'var(--fg-0)',
                      marginTop: 4,
                      letterSpacing: -0.4,
                    }}
                  >
                    {r.quantidade}
                    <span style={{ fontSize: 11, color: 'var(--fg-3)', marginLeft: 6, letterSpacing: 0 }}>
                      un
                    </span>
                  </div>
                  <div style={{ fontSize: 11, color: 'var(--fg-2)', marginTop: 4 }}>
                    {STATUS_LOTE_LABEL[r.status]}
                  </div>
                </Link>
              )
            })}
          </div>
        </GlassCard>
      )}
    </div>
  )
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <div
      className="mono"
      style={{
        fontSize: 10,
        color: 'var(--fg-2)',
        letterSpacing: 0.12,
        textTransform: 'uppercase',
      }}
    >
      {children}
    </div>
  )
}

function MetaRow({
  label,
  value,
  mono,
  muted,
  highlight,
  highlightColor,
}: {
  label: string
  value: string | null
  mono?: boolean
  muted?: boolean
  highlight?: 'cyan'
  highlightColor?: string
}) {
  const color = highlightColor
    ? highlightColor
    : highlight === 'cyan'
      ? 'var(--accent-cyan)'
      : muted
        ? 'var(--fg-3)'
        : 'var(--fg-0)'
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        gap: 12,
        padding: '10px 0',
        borderBottom: '1px solid var(--glass-border)',
      }}
    >
      <span style={{ fontSize: 12, color: 'var(--fg-2)' }}>{label}</span>
      <span
        className={mono ? 'mono' : undefined}
        style={{
          fontSize: mono ? 12 : 13,
          color: value ? color : 'var(--fg-3)',
          textAlign: 'right',
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          maxWidth: '60%',
        }}
      >
        {value ?? 'Não cadastrado'}
      </span>
    </div>
  )
}

function formatBRL(n: number): string {
  return n.toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  })
}
