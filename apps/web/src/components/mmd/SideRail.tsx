'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import type { ReactNode } from 'react'
import { Icons } from './Icons'
import { ThemeToggle } from './ThemeToggle'

type RailItem = {
  id: string
  href: string
  icon: ReactNode
  label: string
  matches: (pathname: string) => boolean
}

const items: RailItem[] = [
  {
    id: 'dashboard',
    href: '/',
    icon: Icons.dashboard,
    label: 'Dashboard',
    matches: (p) => p === '/',
  },
  {
    id: 'inventory',
    href: '/items',
    icon: Icons.box,
    label: 'Inventário',
    matches: (p) => p.startsWith('/items'),
  },
  {
    id: 'projects',
    href: '/projetos',
    icon: Icons.package,
    label: 'Projetos',
    matches: (p) => p.startsWith('/projetos'),
  },
  {
    id: 'rfid',
    href: '/rfid',
    icon: Icons.rfid,
    label: 'RFID',
    matches: (p) => p.startsWith('/rfid'),
  },
  {
    id: 'qr',
    href: '/qrcodes',
    icon: Icons.qr,
    label: 'QR codes',
    matches: (p) => p.startsWith('/qrcodes'),
  },
  {
    id: 'reports',
    href: '/lotes',
    icon: Icons.chart,
    label: 'Lotes',
    matches: (p) => p.startsWith('/lotes'),
  },
]

export function SideRail({ compact = false }: { compact?: boolean }) {
  const pathname = usePathname()
  const w = compact ? 64 : 80

  return (
    <nav
      aria-label="Navegação principal"
      style={{
        width: w,
        flexShrink: 0,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        padding: '24px 0',
        gap: 10,
        borderRight: '1px solid var(--glass-border)',
        background: 'var(--rail-bg)',
        backdropFilter: 'blur(20px) saturate(160%)',
        WebkitBackdropFilter: 'blur(20px) saturate(160%)',
        position: 'relative',
        zIndex: 2,
      }}
    >
      <Link
        href="/"
        aria-label="Início"
        style={{
          width: 40,
          height: 40,
          borderRadius: 12,
          background: 'linear-gradient(135deg, var(--accent-cyan), var(--accent-violet))',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontFamily: 'var(--font-mono-raw)',
          fontWeight: 700,
          color: '#fff',
          fontSize: 14,
          letterSpacing: -0.5,
          marginBottom: 22,
          boxShadow: '0 4px 12px oklch(0.70 0.17 250 / 0.4)',
          textDecoration: 'none',
        }}
      >
        M
      </Link>

      {items.map((it) => {
        const active = it.matches(pathname)
        return (
          <Link
            key={it.id}
            href={it.href}
            aria-label={it.label}
            aria-current={active ? 'page' : undefined}
            title={it.label}
            style={{
              width: 44,
              height: 44,
              borderRadius: 12,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: active ? 'var(--fg-0)' : 'var(--fg-3)',
              background: active ? 'var(--glass-bg-strong)' : 'transparent',
              border: active ? '1px solid var(--glass-border-strong)' : '1px solid transparent',
              textDecoration: 'none',
              transition: 'all var(--motion-fast)',
            }}
          >
            {it.icon}
          </Link>
        )
      })}

      <div style={{ flex: 1 }} />

      <div style={{ marginBottom: 12 }}>
        <ThemeToggle />
      </div>

      <div
        title="Marcelo Santos"
        style={{
          width: 36,
          height: 36,
          borderRadius: '50%',
          background: 'var(--glass-bg-strong)',
          border: '1px solid var(--glass-border-strong)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 12,
          color: 'var(--fg-1)',
          fontWeight: 600,
          fontFamily: 'var(--font-sans-raw)',
        }}
      >
        MS
      </div>
    </nav>
  )
}
