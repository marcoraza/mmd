import Link from 'next/link'
import type { CSSProperties, ReactNode } from 'react'
import { GlassCard } from '@/components/mmd/Primitives'
import { ThemeToggle } from '@/components/mmd/ThemeToggle'
import type { ConfigData } from '@/lib/data/config'
import type { Categoria } from '@/lib/types'

const CATEGORIA_LABEL: Record<Categoria, string> = {
  ILUMINACAO: 'Iluminação',
  AUDIO: 'Áudio',
  CABO: 'Cabo',
  ENERGIA: 'Energia',
  ESTRUTURA: 'Estrutura',
  EFEITO: 'Efeito',
  VIDEO: 'Vídeo',
  ACESSORIO: 'Acessório',
}

const CATEGORIA_PREFIX: Record<Categoria, string> = {
  ILUMINACAO: 'ILU',
  AUDIO: 'AUD',
  CABO: 'CAB',
  ENERGIA: 'ENE',
  ESTRUTURA: 'EST',
  EFEITO: 'EFE',
  VIDEO: 'VID',
  ACESSORIO: 'ACE',
}

const APP_VERSION = '0.1.0'
const APP_COMMIT = process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? 'local'

function formatLastScan(iso: string | null): string {
  if (!iso) return 'sem leituras'
  const d = new Date(iso)
  const now = Date.now()
  const diff = now - d.getTime()
  const min = Math.floor(diff / 60000)
  if (min < 1) return 'agora'
  if (min < 60) return `${min}min atrás`
  const hr = Math.floor(min / 60)
  if (hr < 24) return `${hr}h atrás`
  const days = Math.floor(hr / 24)
  return `${days}d atrás`
}

function SectionHeader({ children }: { children: ReactNode }) {
  return (
    <div
      className="mono"
      style={{
        fontSize: 10,
        color: 'var(--fg-2)',
        letterSpacing: 0.14,
        textTransform: 'uppercase',
        marginBottom: 12,
      }}
    >
      {children}
    </div>
  )
}

function KeyValue({
  label,
  value,
  mono = false,
  valueColor,
}: {
  label: string
  value: ReactNode
  mono?: boolean
  valueColor?: string
}) {
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'baseline',
        gap: 12,
        padding: '10px 0',
        borderBottom: '1px solid var(--glass-border)',
      }}
    >
      <span style={{ fontSize: 13, color: 'var(--fg-2)' }}>{label}</span>
      <span
        className={mono ? 'mono' : undefined}
        style={{
          fontSize: mono ? 12 : 13,
          color: valueColor ?? 'var(--fg-0)',
          textAlign: 'right',
        }}
      >
        {value}
      </span>
    </div>
  )
}

function ProfileCard() {
  return (
    <GlassCard style={{ padding: 20 }}>
      <SectionHeader>Operação</SectionHeader>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        <KeyValue label="Empresa" value="MMD Eventos" />
        <KeyValue label="Responsável" value="Marcelo Santos" />
        <KeyValue label="Contrato" value="R$ 3.000/mês · 3 meses" mono />
        <KeyValue label="Foco" value="Estoque inteligente" />
        <KeyValue label="Rastreamento" value="RFID + QR Code" />
      </div>
    </GlassCard>
  )
}

function HealthCard({ health }: { health: ConfigData['health'] }) {
  const lastScanColor = (() => {
    if (!health.last_scan_at) return 'var(--fg-3)'
    const diff = Date.now() - new Date(health.last_scan_at).getTime()
    if (diff < 60 * 60 * 1000) return 'var(--accent-green)'
    if (diff < 24 * 60 * 60 * 1000) return 'var(--accent-cyan)'
    return 'var(--accent-amber)'
  })()

  return (
    <GlassCard style={{ padding: 20 }}>
      <SectionHeader>Saúde do Supabase</SectionHeader>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        <KeyValue label="Items (tipos)" value={health.items.toString()} mono />
        <KeyValue label="Serial numbers" value={health.serial_numbers.toString()} mono />
        <KeyValue label="Lotes" value={health.lotes.toString()} mono />
        <KeyValue label="Projetos" value={health.projetos.toString()} mono />
        <KeyValue label="Scans RFID (total)" value={health.rfid_scans.toString()} mono />
        <KeyValue
          label="Scans nas últimas 24h"
          value={health.rfid_scans_24h.toString()}
          mono
          valueColor="var(--accent-cyan)"
        />
        <KeyValue
          label="Leitores ativos"
          value={health.rfid_readers_ativos.toString()}
          mono
          valueColor="var(--accent-green)"
        />
        <KeyValue
          label="Última leitura"
          value={formatLastScan(health.last_scan_at)}
          mono
          valueColor={lastScanColor}
        />
      </div>
    </GlassCard>
  )
}

function TaxonomyCard({ taxonomia }: { taxonomia: ConfigData['taxonomia'] }) {
  const total = taxonomia.reduce((sum, t) => sum + t.items, 0)
  const maxCount = Math.max(...taxonomia.map((t) => t.items), 1)

  return (
    <GlassCard style={{ padding: 20 }}>
      <SectionHeader>Taxonomia em uso</SectionHeader>
      {taxonomia.length === 0 ? (
        <div style={{ fontSize: 13, color: 'var(--fg-3)' }}>Nenhuma categoria cadastrada ainda.</div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {taxonomia.map((t) => {
            const pct = Math.round((t.items / total) * 100)
            const barPct = (t.items / maxCount) * 100
            return (
              <div key={t.categoria} style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
                  <span
                    className="mono"
                    style={{
                      fontSize: 10,
                      color: 'var(--fg-3)',
                      letterSpacing: 0.12,
                      minWidth: 32,
                    }}
                  >
                    {CATEGORIA_PREFIX[t.categoria]}
                  </span>
                  <span style={{ fontSize: 13, color: 'var(--fg-0)', flex: 1 }}>
                    {CATEGORIA_LABEL[t.categoria]}
                  </span>
                  <span className="mono" style={{ fontSize: 12, color: 'var(--fg-1)' }}>
                    {t.items}
                  </span>
                  <span
                    className="mono"
                    style={{ fontSize: 10, color: 'var(--fg-3)', minWidth: 34, textAlign: 'right' }}
                  >
                    {pct}%
                  </span>
                </div>
                <div
                  style={{
                    height: 4,
                    borderRadius: 2,
                    background: 'var(--glass-border)',
                    overflow: 'hidden',
                  }}
                >
                  <div
                    style={{
                      width: `${barPct}%`,
                      height: '100%',
                      background:
                        'linear-gradient(90deg, var(--accent-cyan), var(--accent-violet))',
                    }}
                  />
                </div>
              </div>
            )
          })}
          <div
            style={{
              marginTop: 8,
              paddingTop: 12,
              borderTop: '1px solid var(--glass-border)',
              display: 'flex',
              justifyContent: 'space-between',
              fontSize: 12,
              color: 'var(--fg-2)',
            }}
          >
            <span>Total de tipos cadastrados</span>
            <span className="mono" style={{ color: 'var(--fg-0)' }}>
              {total}
            </span>
          </div>
        </div>
      )}
    </GlassCard>
  )
}

function LinkRow({
  href,
  label,
  hint,
  external = false,
}: {
  href: string
  label: string
  hint?: string
  external?: boolean
}) {
  const content = (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '12px 14px',
        borderRadius: 'var(--r-sm)',
        border: '1px solid var(--glass-border)',
        background: 'var(--glass-bg)',
        transition: 'border-color var(--motion-fast), background var(--motion-fast)',
      }}
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 13, color: 'var(--fg-0)' }}>{label}</span>
        {hint && <span style={{ fontSize: 11, color: 'var(--fg-3)' }}>{hint}</span>}
      </div>
      <span
        className="mono"
        style={{ fontSize: 11, color: 'var(--fg-2)', letterSpacing: 0.08 }}
      >
        {external ? '↗' : '→'}
      </span>
    </div>
  )

  if (external) {
    return (
      <a href={href} target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'none' }}>
        {content}
      </a>
    )
  }
  return (
    <Link href={href} style={{ textDecoration: 'none' }}>
      {content}
    </Link>
  )
}

function LinksCard({ projectId }: { projectId: string | null }) {
  const supabaseDashboard = projectId
    ? `https://supabase.com/dashboard/project/${projectId}`
    : 'https://supabase.com/dashboard'
  const tableEditor = projectId
    ? `https://supabase.com/dashboard/project/${projectId}/editor`
    : 'https://supabase.com/dashboard'
  const sqlEditor = projectId
    ? `https://supabase.com/dashboard/project/${projectId}/sql/new`
    : 'https://supabase.com/dashboard'

  return (
    <GlassCard style={{ padding: 20 }}>
      <SectionHeader>Atalhos</SectionHeader>
      <div style={{ display: 'grid', gap: 10 }}>
        <LinkRow href="/items" label="Catálogo" hint="Items, seriais e lotes" />
        <LinkRow href="/rfid" label="Leitura RFID" hint="Timeline de scans e leitores" />
        <LinkRow href="/qrcodes" label="Etiquetas QR Code" hint="Geração e impressão" />
        <LinkRow
          href={supabaseDashboard}
          label="Supabase Dashboard"
          hint={projectId ?? 'projeto não identificado'}
          external
        />
        <LinkRow href={tableEditor} label="Table Editor" hint="Inspecionar dados" external />
        <LinkRow href={sqlEditor} label="SQL Editor" hint="Aplicar migrations e queries ad-hoc" external />
      </div>
    </GlassCard>
  )
}

function SystemInfoCard() {
  return (
    <GlassCard style={{ padding: 20 }}>
      <SectionHeader>Sistema</SectionHeader>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        <KeyValue label="App" value="MMD Web" />
        <KeyValue label="Versão" value={`v${APP_VERSION}`} mono />
        <KeyValue label="Commit" value={APP_COMMIT} mono />
        <KeyValue label="Stack" value="Next 16.2 · React 19 · Supabase" />
        <KeyValue label="Base path" value="/nmd" mono />
      </div>
      <div
        style={{
          marginTop: 16,
          paddingTop: 16,
          borderTop: '1px solid var(--glass-border)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span style={{ fontSize: 13, color: 'var(--fg-0)' }}>Tema</span>
          <span style={{ fontSize: 11, color: 'var(--fg-3)' }}>Preferência salva no navegador</span>
        </div>
        <ThemeToggle />
      </div>
    </GlassCard>
  )
}

function Note() {
  const style: CSSProperties = {
    padding: '12px 14px',
    borderRadius: 'var(--r-sm)',
    border: '1px solid color-mix(in oklch, var(--accent-amber) 30%, transparent)',
    background: 'color-mix(in oklch, var(--accent-amber) 10%, transparent)',
    fontSize: 12,
    color: 'var(--fg-1)',
    lineHeight: 1.5,
  }
  return (
    <div style={style}>
      <span
        className="mono"
        style={{
          fontSize: 10,
          color: 'var(--accent-amber)',
          letterSpacing: 0.12,
          textTransform: 'uppercase',
          marginRight: 8,
        }}
      >
        Somente leitura
      </span>
      Este painel mostra o estado da operação. Para alterar catálogo, use /items; para scans e leitores, use /rfid.
    </div>
  )
}

export function ConfigClient({ data }: { data: ConfigData }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      <Note />
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))',
          gap: 20,
        }}
      >
        <ProfileCard />
        <HealthCard health={data.health} />
        <TaxonomyCard taxonomia={data.taxonomia} />
        <SystemInfoCard />
      </div>
      <LinksCard projectId={data.supabase_project_id} />
    </div>
  )
}
