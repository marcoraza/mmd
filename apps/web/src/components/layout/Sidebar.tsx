'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { LayoutDashboard, Package, Layers, FolderOpen, Settings, Bell } from 'lucide-react'
import { WearBar } from '@/components/ui/WearBar'

interface SidebarProps {
  stats?: {
    valorAtual: number
    totalItens: number
    disponiveis: number
    emCampo: number
    desgasteMedio: number
    tendenciaPct?: number
  }
}

const navItems = [
  { href: '/', label: 'Overview', icon: LayoutDashboard },
  { href: '/items', label: 'Inventário', icon: Package },
  { href: '/lotes', label: 'Lotes', icon: Layers },
  { href: '/projetos', label: 'Projetos', icon: FolderOpen },
  { href: '/config', label: 'Config', icon: Settings },
]

export function Sidebar({ stats }: SidebarProps) {
  const pathname = usePathname()

  const valor = stats?.valorAtual ?? 0
  const valorStr = valor >= 1000000
    ? `R$${(valor / 1000000).toFixed(1)}`
    : `R$${(valor / 1000).toFixed(1)}`
  const valorSuffix = valor >= 1000000 ? 'M' : 'K'

  const desgaste = stats?.desgasteMedio ?? 3

  return (
    <aside
      className="relative flex flex-col h-screen overflow-hidden"
      style={{ width: 380, backgroundColor: '#000000', flexShrink: 0 }}
    >
      {/* Dot-grid background */}
      <div className="dot-grid" />

      <div className="relative z-10 flex flex-col h-full">
        {/* Brand + notification */}
        <div className="flex items-center justify-between px-6 pt-6 pb-4" style={{ borderBottom: '1px solid #222222' }}>
          <div className="flex items-center gap-1">
            <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, fontWeight: 700, color: '#FFFFFF', letterSpacing: '0.12em' }}>
              MMD
            </span>
            <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#D71921' }}>·</span>
            <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, fontWeight: 700, color: '#FFFFFF', letterSpacing: '0.12em' }}>
              ESTOQUE
            </span>
          </div>
          <button
            style={{
              width: 30, height: 30,
              border: '1px solid #333333',
              borderRadius: 6,
              background: 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer',
              position: 'relative',
            }}
          >
            <Bell size={13} color="#999999" />
            <span style={{
              position: 'absolute', top: 5, right: 5,
              width: 5, height: 5, borderRadius: '50%',
              backgroundColor: '#D71921',
            }} />
          </button>
        </div>

        {/* Hero metric */}
        <div className="px-6 py-6" style={{ borderBottom: '1px solid #222222' }}>
          <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 10, color: '#666666', letterSpacing: '0.12em', marginBottom: 4 }}>
            VALOR ATUAL DO PATRIMÔNIO
          </div>
          <div className="flex items-end gap-1">
            <span style={{ fontFamily: '"Doto", monospace', fontSize: 64, fontWeight: 700, color: '#FFFFFF', lineHeight: 1 }}>
              {valorStr}
            </span>
            <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 20, color: '#999999', lineHeight: 1, marginBottom: 6 }}>
              {valorSuffix}
            </span>
          </div>
          {stats?.tendenciaPct !== undefined && (
            <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, marginTop: 6 }}>
              <span style={{ color: '#D4A843' }}>▼ −{Math.abs(stats.tendenciaPct).toFixed(1)}%</span>
              {' '}
              <span style={{ color: '#666666' }}>depreciação</span>
            </div>
          )}
        </div>

        {/* Mini-widgets 2x2 */}
        <div
          className="grid grid-cols-2"
          style={{ borderBottom: '1px solid #222222' }}
        >
          <MiniWidget
            label="TOTAL ITENS"
            value={String(stats?.totalItens ?? 0)}
            color="#FFFFFF"
            borderRight borderBottom
          />
          <MiniWidget
            label="DISPONÍVEIS"
            value={String(stats?.disponiveis ?? 0)}
            color="#4A9E5C"
            borderBottom
          />
          <MiniWidget
            label="EM CAMPO"
            value={String(stats?.emCampo ?? 0)}
            color="#999999"
            borderRight
          />
          <div style={{ padding: '16px 16px', borderLeft: 'none' }}>
            <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#666666', letterSpacing: '0.1em', marginBottom: 6 }}>
              DESGASTE MÉDIO
            </div>
            <div className="flex items-center gap-2">
              <span style={{ fontFamily: '"Doto", monospace', fontSize: 28, color: '#FFFFFF', lineHeight: 1 }}>
                {desgaste.toFixed(1)}
              </span>
              <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#999999' }}>/5</span>
            </div>
            <WearBar desgaste={Math.round(desgaste)} className="mt-2" />
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 py-4">
          {navItems.map((item) => {
            const Icon = item.icon
            const active = item.href === '/'
              ? pathname === '/'
              : pathname.startsWith(item.href)

            return (
              <Link
                key={item.href}
                href={item.href}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  padding: '10px 24px',
                  borderLeft: `2px solid ${active ? '#FFFFFF' : 'transparent'}`,
                  backgroundColor: active ? '#111111' : 'transparent',
                  textDecoration: 'none',
                }}
              >
                <Icon size={13} color={active ? '#FFFFFF' : '#999999'} strokeWidth={1.5} />
                <span
                  style={{
                    fontFamily: '"Space Grotesk", sans-serif',
                    fontSize: 13,
                    fontWeight: active ? 500 : 400,
                    color: active ? '#FFFFFF' : '#999999',
                  }}
                >
                  {item.label}
                </span>
              </Link>
            )
          })}
        </nav>

        {/* Footer */}
        <div className="px-6 py-4" style={{ borderTop: '1px solid #222222' }}>
          <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#444444', letterSpacing: '0.08em' }}>
            MMD ESTOQUE v3.0 — SPRINT 3
          </div>
        </div>
      </div>
    </aside>
  )
}

function MiniWidget({
  label, value, color, borderRight = false, borderBottom = false,
}: {
  label: string
  value: string
  color: string
  borderRight?: boolean
  borderBottom?: boolean
}) {
  return (
    <div
      style={{
        padding: '16px',
        borderRight: borderRight ? '1px solid #222222' : undefined,
        borderBottom: borderBottom ? '1px solid #222222' : undefined,
      }}
    >
      <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#666666', letterSpacing: '0.1em', marginBottom: 4 }}>
        {label}
      </div>
      <div style={{ fontFamily: '"Doto", monospace', fontSize: 28, color, lineHeight: 1 }}>
        {value}
      </div>
    </div>
  )
}
