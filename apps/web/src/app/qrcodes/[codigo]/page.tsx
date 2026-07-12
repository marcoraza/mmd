import type { Metadata } from 'next'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import type { ReactNode } from 'react'
import {
  CATEGORIA_ICON,
  CATEGORIA_LABEL,
  CICLO_LABEL,
  SITUACAO_COLOR,
  SITUACAO_LABEL,
  formatBRL,
} from '@/components/catalog/helpers'
import { Icons } from '@/components/mmd/Icons'
import { Caustic, GlassCard, IconBox, StatusDot } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { loadInternalQrFicha, type InternalQrFicha } from '@/lib/data/internal-qr'
import type { CatalogItem, MovimentacaoTimeline, SerialRow } from '@/lib/data/items'

export const dynamic = 'force-dynamic'

export const metadata: Metadata = {
  title: 'Ficha interna QR',
  description: 'Ficha interna autenticada de equipamento da MMD Eventos.',
}

export default async function InternalQrCodePage({
  params,
}: {
  params: Promise<{ codigo: string }>
}) {
  const { codigo } = await params
  const ficha = await loadInternalQrFicha(codigo)
  if (!ficha) notFound()

  if (ficha.kind === 'lote') {
    return (
      <InternalFrame code={ficha.lote.codigo_lote} kind="Lote legado">
        <LoteFicha ficha={ficha} />
      </InternalFrame>
    )
  }

  return (
    <InternalFrame code={ficha.serial.codigo_interno} kind="Unidade">
      <SerialFicha ficha={ficha} />
    </InternalFrame>
  )
}

function InternalFrame({
  children,
  code,
  kind,
}: {
  children: ReactNode
  code: string
  kind: string
}) {
  return (
    <div style={{ position: 'relative', minHeight: '100dvh' }}>
      <Caustic orb3 />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          padding: 'clamp(20px, 3vw, 28px) clamp(20px, 4vw, 48px)',
        }}
      >
        <TopBar
          kicker={
            <Link href="/qrcodes" style={{ color: 'var(--fg-3)', textDecoration: 'none' }}>
              ← QR Codes
            </Link>
          }
          title="Ficha interna QR"
          notifications={0}
        />

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            marginTop: 14,
            marginBottom: 18,
            fontSize: 12,
            color: 'var(--fg-2)',
            flexWrap: 'wrap',
          }}
        >
          <Link href="/qrcodes" style={{ color: 'var(--fg-2)', textDecoration: 'none' }}>
            QR Codes
          </Link>
          <span style={{ color: 'var(--fg-3)' }}>/</span>
          <span>{kind}</span>
          <span style={{ color: 'var(--fg-3)' }}>/</span>
          <span className="mono" style={{ color: 'var(--fg-0)' }}>
            {code}
          </span>
        </div>

        {children}
      </div>
    </div>
  )
}

function SerialFicha({ ficha }: { ficha: Extract<InternalQrFicha, { kind: 'serial' }> }) {
  const { detail, serial } = ficha
  const item = detail.item
  const latest = detail.timeline
    .filter((entry) => entry.serial_codigo === serial.codigo_interno)
    .slice(0, 3)
  const iconKey = CATEGORIA_ICON[item.categoria] as keyof typeof Icons
  const publicPath = `/s/${encodeURIComponent(serial.codigo_interno)}`

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div
        style={{
          display: 'flex',
          justifyContent: 'flex-end',
          gap: 10,
          flexWrap: 'wrap',
        }}
      >
        <ActionLink href="/qrcodes" variant="ghost">
          Voltar para QR Codes
        </ActionLink>
        <ActionLink href={`/items/${item.id}`}>Abrir item no catálogo</ActionLink>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 420px), 1fr))',
          gap: 16,
          alignItems: 'stretch',
        }}
      >
        <GlassCard style={{ padding: 22 }}>
          <PanelKicker>Identificação da unidade</PanelKicker>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'auto minmax(0, 1fr)',
              gap: 18,
              alignItems: 'center',
              marginTop: 16,
            }}
          >
            <IconBox glyph={Icons[iconKey]} size={112} />
            <div style={{ minWidth: 0 }}>
              <Pill>{CATEGORIA_LABEL[item.categoria]}</Pill>
              <h1
                style={{
                  margin: '12px 0 0',
                  color: 'var(--fg-0)',
                  fontSize: 'clamp(28px, 4vw, 40px)',
                  lineHeight: 1.05,
                  fontWeight: 600,
                }}
              >
                {item.nome}
              </h1>
              <p style={{ margin: '10px 0 0', color: 'var(--fg-2)', fontSize: 14 }}>
                {[item.marca, item.modelo].filter(Boolean).join(' / ') || 'Sem marca ou modelo'}
              </p>
            </div>
          </div>

          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
              gap: 16,
              marginTop: 24,
            }}
          >
            <InfoRow label="Código interno" value={serial.codigo_interno} mono />
            <InfoRow label="Item no catálogo" value={item.codigo_interno ?? 'Sem código'} mono />
            <InfoRow label="Categoria" value={CATEGORIA_LABEL[item.categoria]} />
          </div>

          <div style={{ marginTop: 22 }}>
            <InfoRow label="QR público" value={publicPath} mono />
          </div>
        </GlassCard>

        <GlassCard style={{ padding: 22 }}>
          <PanelKicker>Identificadores e status</PanelKicker>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))',
              gap: 16,
              marginTop: 18,
              paddingBottom: 18,
              borderBottom: '1px solid var(--glass-border)',
            }}
          >
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
                <StatusDot color={SITUACAO_COLOR[serial.status]} size={8} />
                <span style={{ color: 'var(--fg-0)', fontSize: 18 }}>
                  {SITUACAO_LABEL[serial.status]}
                </span>
              </div>
              <div style={{ marginTop: 8, color: 'var(--fg-3)', fontSize: 12 }}>
                Status operacional atual
              </div>
            </div>
            <InfoRow label="Localização" value={serial.localizacao ?? 'Sem localização'} />
            <InfoRow label="Última atualização" value={formatTimestamp(serial.updated_at)} mono />
          </div>

          <div style={{ display: 'grid', gap: 10, marginTop: 18 }}>
            <SensitiveRow label="Serial fábrica" value={serial.serial_fabrica ?? 'Sem serial'} />
            <SensitiveRow label="Tag RFID" value={serial.tag_rfid ?? 'RFID não vinculado'} />
            <SensitiveRow label="QR interno" value={serial.qr_code ?? serial.codigo_interno} />
          </div>

          <div style={{ color: 'var(--fg-3)', fontSize: 12, marginTop: 16, lineHeight: 1.4 }}>
            Dados sensíveis visíveis apenas na área interna autenticada.
          </div>
        </GlassCard>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 360px), 1fr))',
          gap: 16,
        }}
      >
        <ConditionCard item={item} serial={serial} />
        <TimelineCard timeline={latest} serialCode={serial.codigo_interno} />
      </div>
    </div>
  )
}

function ConditionCard({ item, serial }: { item: CatalogItem; serial: SerialRow }) {
  const desgastePct = Math.max(0, Math.min(100, (serial.desgaste / 5) * 100))

  return (
    <GlassCard style={{ padding: 22 }}>
      <PanelKicker>Condição e valor</PanelKicker>
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
          gap: 18,
          marginTop: 20,
          alignItems: 'center',
        }}
      >
        <InfoRow label="Estado" value={CICLO_LABEL[serial.estado]} />
        <div>
          <InfoLabel>Desgaste</InfoLabel>
          <div
            className="mono"
            style={{ color: 'var(--fg-0)', fontSize: 34, lineHeight: 1, marginTop: 8 }}
          >
            {serial.desgaste}
            <span style={{ color: 'var(--fg-3)', fontSize: 14 }}>/5</span>
          </div>
          <div
            style={{
              height: 8,
              borderRadius: 999,
              background: 'var(--glass-bg)',
              border: '1px solid var(--glass-border)',
              overflow: 'hidden',
              marginTop: 10,
            }}
          >
            <div
              style={{
                height: '100%',
                width: `${desgastePct}%`,
                background:
                  serial.desgaste >= 4
                    ? 'var(--accent-green)'
                    : serial.desgaste === 3
                      ? 'var(--accent-amber)'
                      : 'var(--accent-red)',
              }}
            />
          </div>
        </div>
        <InfoRow label="Valor atual" value={formatBRL(serial.valor_atual)} mono />
      </div>
      <div
        style={{
          marginTop: 18,
          paddingTop: 16,
          borderTop: '1px solid var(--glass-border)',
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
          gap: 16,
        }}
      >
        <InfoRow label="Valor unitário base" value={formatBRL(item.valor_mercado_unitario)} mono />
        <InfoRow label="Observação da unidade" value={serial.notas ?? 'Sem observação'} />
      </div>
    </GlassCard>
  )
}

function TimelineCard({
  timeline,
  serialCode,
}: {
  timeline: MovimentacaoTimeline[]
  serialCode: string
}) {
  return (
    <GlassCard style={{ padding: 22 }}>
      <PanelKicker>Sinal recente</PanelKicker>
      <div style={{ display: 'grid', gap: 14, marginTop: 18 }}>
        {timeline.length === 0 ? (
          <div style={{ color: 'var(--fg-3)', fontSize: 13, lineHeight: 1.5 }}>
            Nenhum movimento recente registrado para {serialCode}.
          </div>
        ) : (
          timeline.map((entry) => (
            <div
              key={entry.id}
              style={{
                display: 'grid',
                gridTemplateColumns: '10px minmax(0, 1fr)',
                gap: 12,
                alignItems: 'start',
              }}
            >
              <StatusDot color="var(--accent-cyan)" size={7} />
              <div style={{ minWidth: 0 }}>
                <div
                  className="mono"
                  style={{
                    color: 'var(--fg-0)',
                    fontSize: 12,
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}
                >
                  {formatTimestamp(entry.timestamp)} · {entry.tipo}
                </div>
                <div style={{ color: 'var(--fg-2)', fontSize: 13, marginTop: 4 }}>
                  {entry.projeto_nome ?? entry.notas ?? 'Movimentação interna'}
                </div>
                <div style={{ color: 'var(--fg-3)', fontSize: 11, marginTop: 4 }}>
                  {entry.metodo_scan ?? 'Sem método'} por {entry.registrado_por ?? 'equipe'}
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </GlassCard>
  )
}

function LoteFicha({ ficha }: { ficha: Extract<InternalQrFicha, { kind: 'lote' }> }) {
  const lote = ficha.lote
  const publicPath = `/s/${encodeURIComponent(lote.codigo_lote)}`

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, flexWrap: 'wrap' }}>
        <ActionLink href="/qrcodes" variant="ghost">
          Voltar para QR Codes
        </ActionLink>
        <ActionLink href="/lotes">Abrir auditoria legada</ActionLink>
      </div>

      <GlassCard style={{ padding: 22 }}>
        <PanelKicker>Ficha interna de lote legado</PanelKicker>
        <h1
          className="mono"
          style={{
            margin: '12px 0 0',
            color: 'var(--fg-0)',
            fontSize: 'clamp(30px, 5vw, 48px)',
            lineHeight: 1.05,
          }}
        >
          {lote.codigo_lote}
        </h1>
        <div style={{ color: 'var(--fg-2)', marginTop: 10 }}>
          {lote.item_nome} · {CATEGORIA_LABEL[lote.item_categoria]}
        </div>

        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: 16,
            marginTop: 24,
          }}
        >
          <InfoRow label="Quantidade" value={`${lote.quantidade} unidades`} />
          <InfoRow label="Status" value={lote.status} />
          <InfoRow label="Tag RFID" value={lote.tag_rfid ?? 'RFID não vinculado'} mono />
          <InfoRow label="QR público" value={publicPath} mono />
        </div>

        <div
          style={{
            marginTop: 22,
            padding: 14,
            borderRadius: 8,
            border: '1px solid color-mix(in oklch, var(--accent-amber) 35%, transparent)',
            background: 'color-mix(in oklch, var(--accent-amber) 10%, transparent)',
            color: 'var(--fg-1)',
            fontSize: 13,
            lineHeight: 1.45,
          }}
        >
          Lote mantido só para compatibilidade. QR e RFID novos devem entrar como unidades físicas.
        </div>
      </GlassCard>
    </div>
  )
}

function PanelKicker({ children }: { children: ReactNode }) {
  return (
    <div
      className="mono"
      style={{
        color: 'var(--fg-2)',
        fontSize: 11,
        letterSpacing: 0.12,
        textTransform: 'uppercase',
      }}
    >
      {children}
    </div>
  )
}

function InfoLabel({ children }: { children: ReactNode }) {
  return (
    <div
      className="mono"
      style={{
        color: 'var(--fg-3)',
        fontSize: 10,
        letterSpacing: 0.12,
        textTransform: 'uppercase',
      }}
    >
      {children}
    </div>
  )
}

function InfoRow({
  label,
  value,
  mono = false,
}: {
  label: string
  value: string | number | null
  mono?: boolean
}) {
  return (
    <div style={{ minWidth: 0 }}>
      <InfoLabel>{label}</InfoLabel>
      <div
        className={mono ? 'mono' : undefined}
        style={{
          color: 'var(--fg-0)',
          fontSize: 14,
          marginTop: 7,
          overflowWrap: 'anywhere',
          lineHeight: 1.35,
        }}
      >
        {value ?? 'Sem dado'}
      </div>
    </div>
  )
}

function SensitiveRow({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))',
        gap: 8,
        alignItems: 'center',
        padding: '10px 12px',
        borderRadius: 8,
        border: '1px solid var(--glass-border)',
        background: 'var(--glass-bg)',
      }}
    >
      <div style={{ color: 'var(--fg-2)', fontSize: 13 }}>{label}</div>
      <div
        className="mono"
        style={{
          color: 'var(--fg-0)',
          fontSize: 13,
          overflowWrap: 'anywhere',
        }}
      >
        {value}
      </div>
    </div>
  )
}

function Pill({ children }: { children: ReactNode }) {
  return (
    <span
      className="mono"
      style={{
        display: 'inline-flex',
        width: 'fit-content',
        borderRadius: 8,
        border: '1px solid color-mix(in oklch, var(--accent-cyan) 35%, transparent)',
        background: 'color-mix(in oklch, var(--accent-cyan) 11%, transparent)',
        color: 'var(--accent-cyan)',
        padding: '5px 8px',
        fontSize: 10,
        letterSpacing: 0.1,
        textTransform: 'uppercase',
      }}
    >
      {children}
    </span>
  )
}

function ActionLink({
  href,
  children,
  variant = 'primary',
}: {
  href: string
  children: ReactNode
  variant?: 'primary' | 'ghost'
}) {
  const primary = variant === 'primary'
  return (
    <Link
      href={href}
      style={{
        minHeight: 38,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        padding: '0 14px',
        borderRadius: 8,
        textDecoration: 'none',
        fontSize: 13,
        fontWeight: 500,
        color: primary ? 'var(--bg-0)' : 'var(--fg-0)',
        background: primary ? 'var(--fg-0)' : 'var(--glass-bg)',
        border: primary ? 'none' : '1px solid var(--glass-border-strong)',
      }}
    >
      {children}
      {primary && <span aria-hidden>{Icons.arrow}</span>}
    </Link>
  )
}

function formatTimestamp(value: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'Sem data'

  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}
