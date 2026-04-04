import type { Metadata } from 'next'
import './globals.css'
import { SidebarWrapper } from '@/components/layout/SidebarWrapper'
import { BottomNav } from '@/components/layout/BottomNav'

export const metadata: Metadata = {
  title: 'MMD Estoque',
  description: 'Sistema de gestão de estoque MMD Eventos',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Doto:wght@400;700&family=Space+Grotesk:wght@300;400;500;700&family=Space+Mono:wght@400;700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body style={{ margin: 0, padding: 0, backgroundColor: '#F5F5F5' }}>
        <div style={{ display: 'flex', height: '100dvh', overflow: 'hidden' }}>
          {/* Dark sidebar — desktop only, hidden on mobile via JS */}
          <SidebarWrapper />

          {/* Light content area */}
          <main
            id="main-content"
            style={{
              flex: 1,
              overflowY: 'auto',
              backgroundColor: '#F5F5F5',
              paddingBottom: 'env(safe-area-inset-bottom)',
            }}
          >
            {children}
          </main>
        </div>

        {/* Bottom nav overlay — mobile only */}
        <BottomNav />
      </body>
    </html>
  )
}
