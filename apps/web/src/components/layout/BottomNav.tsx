'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { LayoutDashboard, Package, Layers, FolderOpen, Settings } from 'lucide-react'

const navItems = [
  { href: '/', label: 'Overview', icon: LayoutDashboard },
  { href: '/items', label: 'Inventário', icon: Package },
  { href: '/lotes', label: 'Lotes', icon: Layers },
  { href: '/projetos', label: 'Projetos', icon: FolderOpen },
  { href: '/config', label: 'Config', icon: Settings },
]

export function BottomNav() {
  const pathname = usePathname()

  return (
    <nav
      className="fixed bottom-0 left-0 right-0 z-50 flex items-center"
      style={{ backgroundColor: '#000000', borderTop: '1px solid #222222', height: 56 }}
    >
      {navItems.map((item) => {
        const Icon = item.icon
        const active = item.href === '/'
          ? pathname === '/'
          : pathname.startsWith(item.href)

        return (
          <Link
            key={item.href}
            href={item.href}
            className="flex-1 flex flex-col items-center justify-center h-full"
            style={{ textDecoration: 'none' }}
          >
            <Icon size={16} color={active ? '#FFFFFF' : '#555555'} strokeWidth={1.5} />
            <span
              style={{
                fontFamily: '"Space Mono", monospace',
                fontSize: 9,
                letterSpacing: '0.08em',
                color: active ? '#FFFFFF' : '#555555',
                marginTop: 3,
              }}
            >
              {item.label.toUpperCase()}
            </span>
            {active && (
              <div style={{ width: 4, height: 4, borderRadius: '50%', backgroundColor: '#FFFFFF', marginTop: 2 }} />
            )}
          </Link>
        )
      })}
    </nav>
  )
}
