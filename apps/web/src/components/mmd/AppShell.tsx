'use client'

import { usePathname } from 'next/navigation'
import type { ReactNode } from 'react'
import { SideRail } from './SideRail'

function isPublicRoute(pathname: string) {
  return pathname === '/login' || pathname === '/s' || pathname.startsWith('/s/')
}

export function AppShell({ children }: { children: ReactNode }) {
  const pathname = usePathname()

  if (isPublicRoute(pathname)) {
    return (
      <main
        id="main-content"
        tabIndex={-1}
        style={{
          minHeight: '100dvh',
          position: 'relative',
          overflowX: 'hidden',
          outline: 'none',
        }}
      >
        {children}
      </main>
    )
  }

  return (
    <div
      style={{
        display: 'flex',
        minHeight: '100dvh',
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      <SideRail />
      <main
        id="main-content"
        tabIndex={-1}
        style={{
          flex: 1,
          position: 'relative',
          overflowY: 'auto',
          overflowX: 'hidden',
          paddingBottom: 'env(safe-area-inset-bottom)',
          outline: 'none',
        }}
      >
        {children}
      </main>
    </div>
  )
}
