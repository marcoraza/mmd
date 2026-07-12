import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import type { ReactNode } from 'react'
import { CATEGORIA_LABEL } from '@/components/catalog/helpers'
import { Caustic, GlassCard, StatusDot } from '@/components/mmd/Primitives'
import { findDemoPublicCode } from '@/lib/data/demo'
import { getDataMode, isDemoFallbackEnabled } from '@/lib/data/demo-mode'
import {
  getPublicQrContact,
  loteStatusToPublicStatus,
  normalizePublicLookupCode,
  publicStatusColor,
  serialStatusToPublicStatus,
} from '@/lib/public-qr'
import type { Categoria, StatusSerial } from '@/lib/types'
import type { StatusLote } from '@/lib/types'

export const dynamic = 'force-dynamic'

export const metadata: Metadata = {
  title: 'Equipamento MMD',
  description: 'Identificação pública de equipamento da MMD Eventos.',
}

type SerialPublicRow = {
  id: string
  codigo_interno: string
  qr_code: string | null
  status: StatusSerial
  item: PublicItem | null
}

type LotePublicRow = {
  id: string
  codigo_lote: string
  descricao: string
  qr_code: string | null
  status: StatusLote
  item: PublicItem | null
}

type PublicLookup = { kind: 'serial'; row: SerialPublicRow } | { kind: 'lote'; row: LotePublicRow }

type PublicItem = {
  nome: string
  categoria: Categoria
  subcategoria: string | null
  marca: string | null
  modelo: string | null
}

type RawRelation<T> = T | T[] | null

function normalizeCode(code: string) {
  return normalizePublicLookupCode(code)
}

function normalizeItem(item: RawRelation<PublicItem>) {
  if (Array.isArray(item)) return item[0] ?? null
  return item
}

async function loadPublicCode(code: string): Promise<PublicLookup | null> {
  const normalized = normalizeCode(code)
  if (!normalized) return null

  const { supabaseAdmin } = await import('@/lib/supabase-server')

  const serialSelect = `id, codigo_interno, qr_code, status,
    items ( nome, categoria, subcategoria, marca, modelo )`

  const { data: serialByCode, error: serialByCodeError } = await supabaseAdmin
    .from('serial_numbers')
    .select(serialSelect)
    .eq('codigo_interno', normalized)
    .maybeSingle()

  if (serialByCodeError) throw serialByCodeError

  if (serialByCode) {
    const raw = serialByCode as unknown as Omit<SerialPublicRow, 'item'> & {
      items: RawRelation<PublicItem>
    }
    return { kind: 'serial', row: { ...raw, item: normalizeItem(raw.items) } }
  }

  const { data: serialByQr, error: serialByQrError } = await supabaseAdmin
    .from('serial_numbers')
    .select(serialSelect)
    .eq('qr_code', normalized)
    .maybeSingle()

  if (serialByQrError) throw serialByQrError

  if (serialByQr) {
    const raw = serialByQr as unknown as Omit<SerialPublicRow, 'item'> & {
      items: RawRelation<PublicItem>
    }
    return { kind: 'serial', row: { ...raw, item: normalizeItem(raw.items) } }
  }

  const loteSelect = `id, codigo_lote, descricao, qr_code, status,
    items ( nome, categoria, subcategoria, marca, modelo )`

  const { data: loteByCode, error: loteByCodeError } = await supabaseAdmin
    .from('lotes')
    .select(loteSelect)
    .eq('codigo_lote', normalized)
    .maybeSingle()

  if (loteByCodeError) throw loteByCodeError

  if (loteByCode) {
    const raw = loteByCode as unknown as Omit<LotePublicRow, 'item'> & {
      items: RawRelation<PublicItem>
    }
    return { kind: 'lote', row: { ...raw, item: normalizeItem(raw.items) } }
  }

  const { data: loteByQr, error: loteByQrError } = await supabaseAdmin
    .from('lotes')
    .select(loteSelect)
    .eq('qr_code', normalized)
    .maybeSingle()

  if (loteByQrError) throw loteByQrError

  if (loteByQr) {
    const raw = loteByQr as unknown as Omit<LotePublicRow, 'item'> & {
      items: RawRelation<PublicItem>
    }
    return { kind: 'lote', row: { ...raw, item: normalizeItem(raw.items) } }
  }

  return null
}

function demoLookup(code: string): PublicLookup | null {
  const result = findDemoPublicCode(code) as PublicLookup | null
  if (!result) return null

  return {
    kind: result.kind,
    row: {
      ...result.row,
      item: result.row.item,
    },
  } as PublicLookup
}

async function safeLoadPublicCode(code: string) {
  if (!normalizeCode(code)) return { status: 'ok' as const, result: null }

  if (getDataMode() === 'demo') {
    return { status: 'ok' as const, result: demoLookup(code) }
  }

  try {
    const result = await loadPublicCode(code)
    if (result) return { status: 'ok' as const, result }
    const demoResult = isDemoFallbackEnabled() ? demoLookup(code) : null
    return { status: 'ok' as const, result: demoResult }
  } catch (error) {
    const demoResult = isDemoFallbackEnabled() ? demoLookup(code) : null
    if (demoResult) return { status: 'ok' as const, result: demoResult }
    console.error('Public QR lookup failed', error)
    return { status: 'unavailable' as const }
  }
}

function MetaRow({ label, value }: { label: string; value: string | number | null }) {
  return (
    <div>
      <div
        className="mono"
        style={{
          color: 'var(--fg-3)',
          fontSize: 10,
          letterSpacing: 0.12,
          textTransform: 'uppercase',
        }}
      >
        {label}
      </div>
      <div style={{ color: 'var(--fg-0)', fontSize: 15, marginTop: 4 }}>{value ?? 'Sem dado'}</div>
    </div>
  )
}

function PublicFrame({ children }: { children: ReactNode }) {
  return (
    <div style={{ position: 'relative', minHeight: '100dvh' }}>
      <Caustic />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          minHeight: '100dvh',
          display: 'grid',
          placeItems: 'center',
          padding: 'clamp(20px, 5vw, 64px)',
        }}
      >
        <GlassCard style={{ width: 'min(100%, 720px)', padding: 'clamp(22px, 4vw, 36px)' }}>
          <a
            href="#contato-mmd"
            style={{
              color: 'var(--fg-3)',
              textDecoration: 'none',
              fontSize: 13,
            }}
          >
            MMD Estoque
          </a>
          {children}
        </GlassCard>
      </div>
    </div>
  )
}

function BackendUnavailable({ code }: { code: string }) {
  return (
    <>
      <div
        className="mono"
        style={{
          marginTop: 28,
          color: 'var(--accent-cyan)',
          fontSize: 11,
          letterSpacing: 0.12,
          textTransform: 'uppercase',
        }}
      >
        Consulta indisponível
      </div>

      <h1
        style={{
          margin: '10px 0 0',
          color: 'var(--fg-0)',
          fontSize: 'clamp(34px, 7vw, 56px)',
          lineHeight: 1,
          fontWeight: 600,
        }}
      >
        Backend indisponível
      </h1>

      <p style={{ color: 'var(--fg-1)', fontSize: 18, lineHeight: 1.5, marginTop: 18 }}>
        Não conseguimos consultar o código {normalizeCode(code) ?? 'informado'} agora. O QR está
        válido, mas o servidor de estoque precisa voltar para exibir a ficha.
      </p>
    </>
  )
}

function ContactActions() {
  const contact = getPublicQrContact()

  if (!contact.hasDirectContact) {
    return (
      <p id="contato-mmd" style={{ color: 'var(--fg-2)', fontSize: 14, lineHeight: 1.45 }}>
        Contato público da MMD ainda não configurado neste ambiente.
      </p>
    )
  }

  return (
    <div
      id="contato-mmd"
      style={{ display: 'flex', flexWrap: 'wrap', gap: 12, alignItems: 'center' }}
    >
      {contact.whatsappUrl && (
        <a
          href={contact.whatsappUrl}
          rel="noreferrer"
          target="_blank"
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            minHeight: 42,
            padding: '0 16px',
            borderRadius: 999,
            background: 'var(--fg-0)',
            color: 'var(--bg-0)',
            textDecoration: 'none',
            fontSize: 14,
            fontWeight: 600,
          }}
        >
          Avisar a MMD
        </a>
      )}
      {contact.phone && (
        <a
          href={`tel:${contact.phone}`}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            minHeight: 42,
            padding: '0 16px',
            borderRadius: 999,
            border: '1px solid var(--glass-border-strong)',
            color: 'var(--fg-0)',
            textDecoration: 'none',
            fontSize: 14,
            fontWeight: 600,
          }}
        >
          Ligar
        </a>
      )}
    </div>
  )
}

export default async function PublicCodePage({ params }: { params: Promise<{ codigo: string }> }) {
  const { codigo } = await params
  const lookup = await safeLoadPublicCode(codigo)
  if (lookup.status === 'unavailable') {
    return (
      <PublicFrame>
        <BackendUnavailable code={codigo} />
      </PublicFrame>
    )
  }

  const result = lookup.result
  if (!result) notFound()

  const item = result.row.item
  const code = result.kind === 'serial' ? result.row.codigo_interno : result.row.codigo_lote
  const title =
    item?.nome ?? (result.kind === 'serial' ? result.row.codigo_interno : result.row.descricao)
  const category = item?.categoria ? CATEGORIA_LABEL[item.categoria] : 'Sem categoria'
  const publicStatus =
    result.kind === 'serial'
      ? serialStatusToPublicStatus(result.row.status)
      : loteStatusToPublicStatus(result.row.status)

  return (
    <PublicFrame>
      <div
        className="mono"
        style={{
          marginTop: 28,
          color: 'var(--accent-cyan)',
          fontSize: 11,
          letterSpacing: 0.12,
          textTransform: 'uppercase',
        }}
      >
        Equipamento MMD
      </div>

      <h1
        style={{
          margin: '10px 0 0',
          color: 'var(--fg-0)',
          fontSize: 'clamp(34px, 7vw, 56px)',
          lineHeight: 1,
          fontWeight: 600,
        }}
      >
        {code}
      </h1>

      <div style={{ color: 'var(--fg-1)', fontSize: 20, marginTop: 12 }}>{title}</div>

      <div
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 8,
          marginTop: 18,
          padding: '8px 12px',
          borderRadius: 999,
          border: '1px solid var(--glass-border)',
          background: 'var(--glass-bg)',
          color: 'var(--fg-1)',
          fontSize: 13,
        }}
      >
        <StatusDot color={publicStatusColor(publicStatus)} size={7} />
        <span style={{ textTransform: 'uppercase' }}>{publicStatus}</span>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
          gap: 18,
          marginTop: 30,
          paddingTop: 24,
          borderTop: '1px solid var(--glass-border)',
        }}
      >
        <MetaRow label="Categoria" value={category} />
        <MetaRow
          label="Identificação"
          value={result.kind === 'serial' ? 'Unidade MMD' : 'Registro MMD'}
        />
        <MetaRow label="Contato" value="Falar com a MMD" />
      </div>

      <div style={{ marginTop: 24 }}>
        <ContactActions />
      </div>
    </PublicFrame>
  )
}
