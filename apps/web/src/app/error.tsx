'use client'

import { useEffect } from 'react'
import { Btn, GlassCard } from '@/components/mmd/Primitives'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error(error)
  }, [error])

  return (
    <div
      style={{
        minHeight: '100%',
        display: 'grid',
        placeItems: 'center',
        padding: 'clamp(24px, 5vw, 56px)',
      }}
    >
      <GlassCard style={{ maxWidth: 560, padding: 28 }}>
        <div
          className="mono"
          style={{
            color: 'var(--accent-amber)',
            fontSize: 11,
            letterSpacing: 0.12,
            textTransform: 'uppercase',
            marginBottom: 12,
          }}
        >
          Backend indisponível
        </div>
        <h1
          style={{
            margin: 0,
            color: 'var(--fg-0)',
            fontSize: 'clamp(28px, 5vw, 42px)',
            lineHeight: 1.05,
            fontWeight: 600,
          }}
        >
          Não conseguimos carregar os dados do estoque.
        </h1>
        <p style={{ color: 'var(--fg-2)', fontSize: 14, lineHeight: 1.6, margin: '16px 0 22px' }}>
          O app está de pé, mas o Supabase não respondeu. Confira as variáveis de ambiente e o
          status do projeto antes da demo.
        </p>
        <Btn onClick={reset}>Tentar novamente</Btn>
      </GlassCard>
    </div>
  )
}
