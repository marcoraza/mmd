export type McpConsentDetails =
  | { state: 'resolved'; redirectUrl: string }
  | {
      state: 'pending'
      userId: string
      clientId: string
    }

type McpConsentDependencies = {
  currentUserId: () => Promise<string | null>
  authorizationDetails: (authorizationId: string) => Promise<McpConsentDetails | null>
  clientIsRegistered: (clientId: string) => Promise<boolean>
  approve: (authorizationId: string) => Promise<string | null>
  deny: (authorizationId: string) => Promise<string | null>
}

function validAuthorizationId(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    value.length >= 8 &&
    value.length <= 2048 &&
    /^[A-Za-z0-9._~-]+$/.test(value)
  )
}

export async function decideMcpAuthorizationCore(
  authorizationId: unknown,
  decision: unknown,
  dependencies: McpConsentDependencies,
) {
  if (!validAuthorizationId(authorizationId) || (decision !== 'approve' && decision !== 'deny')) {
    return '/oauth/consent?error=invalid_request'
  }

  const userId = await dependencies.currentUserId()
  if (!userId) {
    const next = `/oauth/consent?authorization_id=${authorizationId}`
    return `/login?next=${encodeURIComponent(next)}`
  }

  const details = await dependencies.authorizationDetails(authorizationId)
  if (!details) return '/oauth/consent?error=invalid_request'
  if (details.state === 'resolved') return details.redirectUrl
  if (details.userId !== userId) return '/oauth/consent?error=invalid_request'

  if (decision === 'approve' && !(await dependencies.clientIsRegistered(details.clientId))) {
    return '/oauth/consent?error=client_not_registered'
  }

  const redirectUrl =
    decision === 'approve'
      ? await dependencies.approve(authorizationId)
      : await dependencies.deny(authorizationId)
  return redirectUrl ?? '/oauth/consent?error=decision_failed'
}
