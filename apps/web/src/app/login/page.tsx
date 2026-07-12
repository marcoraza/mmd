import type { Metadata } from 'next'
import { redirect } from 'next/navigation'
import { Caustic, GlassCard } from '@/components/mmd/Primitives'
import { signInWithPasswordAction } from '@/lib/auth-actions'
import { sanitizeNextPath } from '@/lib/auth-config'
import { getVerifiedUser } from '@/lib/supabase-ssr'

export const dynamic = 'force-dynamic'

export const metadata: Metadata = {
  title: 'Acesso interno MMD',
  description: 'Login interno do MMD Estoque.',
}

const errorCopy: Record<string, string> = {
  missing: 'Preencha email e senha para entrar.',
  invalid: 'Email ou senha não conferem.',
}

type LoginSearchParams = {
  next?: string
  error?: string
}

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<LoginSearchParams>
}) {
  const params = await searchParams
  const next = sanitizeNextPath(params.next)
  const user = await getVerifiedUser()
  if (user) redirect(next)

  const error = params.error ? errorCopy[params.error] : null

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
        <GlassCard style={{ width: 'min(100%, 460px)', padding: 'clamp(24px, 4vw, 38px)' }}>
          <div
            className="mono"
            style={{
              color: 'var(--accent-cyan)',
              fontSize: 11,
              letterSpacing: 0.12,
              textTransform: 'uppercase',
            }}
          >
            Acesso interno
          </div>
          <h1
            style={{
              margin: '10px 0 0',
              color: 'var(--fg-0)',
              fontSize: 'clamp(38px, 7vw, 56px)',
              lineHeight: 1,
              fontWeight: 600,
            }}
          >
            MMD Estoque
          </h1>
          <p style={{ color: 'var(--fg-1)', fontSize: 17, lineHeight: 1.45, marginTop: 14 }}>
            Entre para operar eventos, estoque e QR codes.
          </p>

          <form
            action={signInWithPasswordAction}
            style={{ display: 'grid', gap: 14, marginTop: 28 }}
          >
            <input type="hidden" name="next" value={next} />
            <label style={{ display: 'grid', gap: 7 }}>
              <span
                className="mono"
                style={{
                  color: 'var(--fg-3)',
                  fontSize: 10,
                  letterSpacing: 0.12,
                  textTransform: 'uppercase',
                }}
              >
                Email ou usuário
              </span>
              <input
                name="email"
                type="text"
                autoComplete="username"
                required
                style={{
                  width: '100%',
                  minHeight: 44,
                  borderRadius: 12,
                  border: '1px solid var(--glass-border-strong)',
                  background: 'var(--glass-bg-strong)',
                  color: 'var(--fg-0)',
                  padding: '0 14px',
                  font: 'inherit',
                }}
              />
            </label>

            <label style={{ display: 'grid', gap: 7 }}>
              <span
                className="mono"
                style={{
                  color: 'var(--fg-3)',
                  fontSize: 10,
                  letterSpacing: 0.12,
                  textTransform: 'uppercase',
                }}
              >
                Senha
              </span>
              <input
                name="password"
                type="password"
                autoComplete="current-password"
                required
                style={{
                  width: '100%',
                  minHeight: 44,
                  borderRadius: 12,
                  border: '1px solid var(--glass-border-strong)',
                  background: 'var(--glass-bg-strong)',
                  color: 'var(--fg-0)',
                  padding: '0 14px',
                  font: 'inherit',
                }}
              />
            </label>

            {error && (
              <div role="alert" style={{ color: 'var(--accent-red)', fontSize: 14 }}>
                {error}
              </div>
            )}

            <button
              type="submit"
              style={{
                minHeight: 46,
                border: 0,
                borderRadius: 999,
                background: 'var(--fg-0)',
                color: 'var(--bg-0)',
                fontSize: 15,
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              Entrar
            </button>
          </form>

          <p
            className="mono"
            style={{
              color: 'var(--fg-3)',
              fontSize: 10,
              letterSpacing: 0.08,
              marginTop: 18,
              textTransform: 'uppercase',
            }}
          >
            Acesso restrito à equipe MMD
          </p>
        </GlassCard>
      </div>
    </div>
  )
}
