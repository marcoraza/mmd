'use client'

import Link from 'next/link'
import type { ReactNode } from 'react'
import { CATEGORIA_LABEL } from '@/components/catalog/helpers'
import { Icons } from '@/components/mmd/Icons'
import { Badge, GlassCard, StatusDot } from '@/components/mmd/Primitives'
import type { LotesData, LoteRow } from '@/lib/data/lotes'
import { STATUS_LOTE_COLOR, STATUS_LOTE_LABEL } from './helpers'

export function LotesLegacyClient({ data }: { data: LotesData }) {
  const preview = data.lotes.slice(0, 8)

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <GlassCard strong style={{ padding: 22 }}>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 360px), 1fr))',
            gap: 18,
            alignItems: 'center',
          }}
        >
          <div style={{ minWidth: 0 }}>
            <Badge color="var(--accent-cyan)">Unit-only ativo</Badge>
            <h1
              style={{
                margin: '14px 0 0',
                color: 'var(--fg-0)',
                fontSize: 'clamp(28px, 4vw, 44px)',
                lineHeight: 1.04,
                fontWeight: 600,
              }}
            >
              Lotes viraram histórico
            </h1>
            <p style={{ margin: '12px 0 0', color: 'var(--fg-2)', fontSize: 15, lineHeight: 1.5 }}>
              QR e RFID novos apontam para unidades físicas. Esta área preserva registros antigos
              para auditoria até o checkpoint humano de delete físico.
            </p>
          </div>

          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 120px), 1fr))',
              gap: 10,
            }}
          >
            <Metric label="Lotes legados" value={data.banner.total} color="var(--accent-violet)" />
            <Metric
              label="Unidades antigas"
              value={data.banner.unidades_totais}
              color="var(--fg-0)"
            />
            <Metric label="Delete físico" value="Bloqueado" color="var(--accent-amber)" />
          </div>
        </div>
      </GlassCard>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 260px), 1fr))',
          gap: 10,
        }}
      >
        <ActionLink
          href="/items"
          icon={Icons.box}
          title="Abrir catálogo"
          hint="Unidades individuais"
        />
        <ActionLink
          href="/qrcodes"
          icon={Icons.qr}
          title="Gerar QR de unidades"
          hint="Sem QR de lote"
        />
        <ActionLink
          href="/rfid"
          icon={Icons.rfid}
          title="Vincular RFID"
          hint="Tags por unidade física"
        />
      </div>

      <GlassCard style={{ padding: 0, overflow: 'hidden' }}>
        <div
          style={{
            padding: '14px 16px',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            gap: 12,
            borderBottom: '1px solid var(--glass-border)',
            flexWrap: 'wrap',
          }}
        >
          <div style={{ minWidth: 0 }}>
            <div style={{ color: 'var(--fg-0)', fontSize: 16, fontWeight: 500 }}>
              Registro de lotes legados
            </div>
            <div style={{ color: 'var(--fg-3)', fontSize: 12, marginTop: 3 }}>
              Consulta somente leitura, mantida para rastreabilidade.
            </div>
          </div>
          <Badge color="var(--fg-2)">Read-only</Badge>
        </div>

        {preview.length === 0 ? (
          <div style={{ padding: 24, color: 'var(--fg-3)', fontSize: 13 }}>
            Nenhum lote legado encontrado.
          </div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table
              style={{
                width: '100%',
                minWidth: 720,
                borderCollapse: 'collapse',
                fontSize: 13,
              }}
            >
              <thead>
                <tr style={{ color: 'var(--fg-3)', textAlign: 'left' }}>
                  <Th>Código</Th>
                  <Th>Categoria</Th>
                  <Th>Item</Th>
                  <Th>Quantidade</Th>
                  <Th>Status</Th>
                </tr>
              </thead>
              <tbody>
                {preview.map((lote) => (
                  <LegacyRow key={lote.id} lote={lote} />
                ))}
              </tbody>
            </table>
          </div>
        )}
      </GlassCard>

      <div
        style={{
          padding: '14px 16px',
          border: '1px solid var(--glass-border)',
          borderRadius: 'var(--r-md)',
          background: 'var(--glass-bg)',
          color: 'var(--fg-2)',
          fontSize: 13,
          lineHeight: 1.45,
        }}
      >
        Nenhum novo lote será criado por este fluxo. Delete físico exige confirmação explícita do
        Marco depois de validar que todos os cabos e itens agrupados existem como unidades.
      </div>
    </div>
  )
}

function Metric({ label, value, color }: { label: string; value: number | string; color: string }) {
  return (
    <div
      style={{
        minHeight: 96,
        padding: '12px 13px',
        border: '1px solid var(--glass-border)',
        borderRadius: 'var(--r-sm)',
        background: 'var(--glass-bg)',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        minWidth: 0,
      }}
    >
      <div
        className="mono"
        style={{
          color: 'var(--fg-3)',
          fontSize: 9,
          textTransform: 'uppercase',
          letterSpacing: 0.1,
        }}
      >
        {label}
      </div>
      <div style={{ color, fontSize: 22, fontWeight: 600, lineHeight: 1.1 }}>{value}</div>
    </div>
  )
}

function ActionLink({
  href,
  icon,
  title,
  hint,
}: {
  href: string
  icon: ReactNode
  title: string
  hint: string
}) {
  return (
    <Link
      href={href}
      className="glass card-interactive"
      style={{
        display: 'grid',
        gridTemplateColumns: '34px minmax(0, 1fr) auto',
        gap: 12,
        alignItems: 'center',
        minHeight: 74,
        padding: '13px 15px',
        borderRadius: 'var(--r-md)',
        color: 'inherit',
        textDecoration: 'none',
      }}
    >
      <span
        style={{
          width: 34,
          height: 34,
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          borderRadius: 10,
          background: 'var(--accent-cyan-soft)',
          color: 'var(--accent-cyan)',
        }}
      >
        {icon}
      </span>
      <span style={{ minWidth: 0 }}>
        <span style={{ display: 'block', color: 'var(--fg-0)', fontSize: 14, fontWeight: 500 }}>
          {title}
        </span>
        <span style={{ display: 'block', color: 'var(--fg-3)', fontSize: 12, marginTop: 2 }}>
          {hint}
        </span>
      </span>
      <span style={{ color: 'var(--fg-3)' }}>{Icons.arrow}</span>
    </Link>
  )
}

function LegacyRow({ lote }: { lote: LoteRow }) {
  return (
    <tr style={{ borderTop: '1px solid var(--glass-border)' }}>
      <Td mono>{lote.codigo_lote}</Td>
      <Td>{CATEGORIA_LABEL[lote.item_categoria]}</Td>
      <Td>{lote.item_nome}</Td>
      <Td mono>{lote.quantidade}</Td>
      <Td>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7 }}>
          <StatusDot color={STATUS_LOTE_COLOR[lote.status]} size={6} />
          {STATUS_LOTE_LABEL[lote.status]}
        </span>
      </Td>
    </tr>
  )
}

function Th({ children }: { children: ReactNode }) {
  return (
    <th
      className="mono"
      style={{
        padding: '11px 16px',
        fontSize: 10,
        fontWeight: 500,
        textTransform: 'uppercase',
        letterSpacing: 0.1,
      }}
    >
      {children}
    </th>
  )
}

function Td({ children, mono = false }: { children: ReactNode; mono?: boolean }) {
  return (
    <td
      className={mono ? 'mono' : undefined}
      style={{
        padding: '12px 16px',
        color: mono ? 'var(--accent-cyan)' : 'var(--fg-1)',
        whiteSpace: 'nowrap',
      }}
    >
      {children}
    </td>
  )
}
