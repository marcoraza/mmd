import type { Metadata } from 'next'
import type { ReactNode } from 'react'

export const metadata: Metadata = {
  title: 'EventPro API',
  description: 'BFF do EventPro: estoque inteligente para locação AV.',
}

// Casca mínima. A UI de produto (design 2.0) é a fase 7 do plano de migração;
// nesta fase o app é só BFF.
export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="pt-BR">
      <body
        style={{
          margin: 0,
          padding: '2rem',
          fontFamily: 'system-ui, -apple-system, Segoe UI, Roboto, sans-serif',
          lineHeight: 1.5,
        }}
      >
        {children}
      </body>
    </html>
  )
}
