import type { Metadata } from 'next'
import { redirect } from 'next/navigation'

import { Caustic, GlassCard } from '@/components/mmd/Primitives'
import { registeredMcpClient } from '@/lib/mcp-auth'
import { decideMcpAuthorization } from '@/lib/mcp-oauth-actions'
import { createSupabaseCookieClient, getVerifiedUser } from '@/lib/supabase-ssr'

export const dynamic = 'force-dynamic'

export const metadata: Metadata = {
  title: 'Autorizar agente MCP | MMD',
  description: 'Consentimento de acesso de agentes ao estoque MMD.',
}

const errorCopy: Record<string, string> = {
  invalid_request: 'O pedido de autorização expirou ou é inválido.',
  client_not_registered: 'Este agente não está liberado no registro da MMD.',
  decision_failed: 'Não foi possível registrar sua decisão. Tente iniciar a conexão novamente.',
}

export default async function McpConsentPage({
  searchParams,
}: {
  searchParams: Promise<{ authorization_id?: string; error?: string }>
}) {
  const params = await searchParams
  if (params.error) {
    return <ConsentShell error={errorCopy[params.error] ?? errorCopy.invalid_request} />
  }

  const authorizationId = params.authorization_id
  if (!authorizationId) return <ConsentShell error={errorCopy.invalid_request} />

  const user = await getVerifiedUser()
  if (!user) {
    redirect(
      `/login?next=${encodeURIComponent(`/oauth/consent?authorization_id=${authorizationId}`)}`,
    )
  }

  const supabase = await createSupabaseCookieClient()
  const { data: details, error } =
    await supabase.auth.oauth.getAuthorizationDetails(authorizationId)
  if (error || !details) return <ConsentShell error={errorCopy.invalid_request} />
  if (!('authorization_id' in details)) redirect(details.redirect_url)
  if (details.user.id !== user.id) return <ConsentShell error={errorCopy.invalid_request} />

  const registration = await registeredMcpClient(details.client.id)
  if (!registration) return <ConsentShell error={errorCopy.client_not_registered} />

  const requestedIdentityScopes = details.scope.split(' ').filter(Boolean)
  return (
    <ConsentShell>
      <div
        className="mono"
        style={{
          color: 'var(--accent-cyan)',
          fontSize: 11,
          letterSpacing: 0.12,
          textTransform: 'uppercase',
        }}
      >
        Autorização de agente
      </div>
      <h1
        style={{
          margin: '10px 0 0',
          color: 'var(--fg-0)',
          fontSize: 'clamp(34px, 7vw, 50px)',
          lineHeight: 1,
          fontWeight: 600,
        }}
      >
        {details.client.name}
      </h1>
      <p style={{ color: 'var(--fg-1)', fontSize: 17, lineHeight: 1.45, marginTop: 14 }}>
        Este agente quer consultar o estoque em seu nome. A MMD registra cada operação com seu
        usuário e o identificador do agente.
      </p>

      <div style={{ display: 'grid', gap: 10, marginTop: 24 }}>
        <ConsentFact label="Destino verificado" value={details.redirect_uri} />
        <ConsentFact label="Acesso MMD" value={registration.scopes.join(', ')} />
        {requestedIdentityScopes.length > 0 && (
          <ConsentFact label="Dados da conta" value={requestedIdentityScopes.join(', ')} />
        )}
      </div>

      <p style={{ color: 'var(--fg-3)', fontSize: 13, lineHeight: 1.45, marginTop: 20 }}>
        O agente não recebe RFID, serial de fábrica, valor, notas internas ou arquivos comerciais
        pelas consultas iniciais.
      </p>

      <form
        action={decideMcpAuthorization}
        style={{ display: 'flex', gap: 12, marginTop: 26, flexWrap: 'wrap' }}
      >
        <input type="hidden" name="authorization_id" value={authorizationId} />
        <button type="submit" name="decision" value="approve" style={primaryButton}>
          Autorizar
        </button>
        <button type="submit" name="decision" value="deny" style={secondaryButton}>
          Negar
        </button>
      </form>
    </ConsentShell>
  )
}

function ConsentShell({ children, error }: { children?: React.ReactNode; error?: string }) {
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
        <GlassCard style={{ width: 'min(100%, 560px)', padding: 'clamp(24px, 4vw, 38px)' }}>
          {error ? (
            <>
              <div
                className="mono"
                style={{
                  color: 'var(--accent-red)',
                  fontSize: 11,
                  letterSpacing: 0.12,
                  textTransform: 'uppercase',
                }}
              >
                Acesso não liberado
              </div>
              <h1 style={{ color: 'var(--fg-0)', fontSize: 32, margin: '12px 0 0' }}>
                Conexão interrompida
              </h1>
              <p role="alert" style={{ color: 'var(--fg-1)', lineHeight: 1.5, marginTop: 12 }}>
                {error}
              </p>
            </>
          ) : (
            children
          )}
        </GlassCard>
      </div>
    </div>
  )
}

function ConsentFact({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        border: '1px solid var(--glass-border)',
        borderRadius: 14,
        padding: '12px 14px',
        background: 'var(--glass-bg)',
      }}
    >
      <div
        className="mono"
        style={{
          color: 'var(--fg-3)',
          fontSize: 9,
          letterSpacing: 0.1,
          textTransform: 'uppercase',
        }}
      >
        {label}
      </div>
      <div style={{ color: 'var(--fg-1)', fontSize: 13, marginTop: 5, overflowWrap: 'anywhere' }}>
        {value}
      </div>
    </div>
  )
}

const primaryButton = {
  minHeight: 46,
  border: 0,
  borderRadius: 999,
  background: 'var(--fg-0)',
  color: 'var(--bg-0)',
  padding: '0 22px',
  fontSize: 15,
  fontWeight: 600,
  cursor: 'pointer',
} as const

const secondaryButton = {
  ...primaryButton,
  border: '1px solid var(--glass-border-strong)',
  background: 'var(--glass-bg-strong)',
  color: 'var(--fg-1)',
} as const
