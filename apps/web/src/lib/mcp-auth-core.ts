import { jwtVerify, type JWTVerifyGetKey } from 'jose'

import type { UserRole } from '@/lib/action-auth-core'
import type { McpIdentity } from '@/lib/mcp-core'

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const CLIENT_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{2,127}$/
const MCP_SCOPES = new Set(['mcp:read', 'mcp:operate'])

export type McpTokenConfiguration = {
  issuer: string
  audience: string
}

export type McpTokenIdentity = {
  actorId: string
  clientId: string
  expiresAt: number
  scopes: string[]
}

export async function verifyMcpAccessToken(
  token: string,
  configuration: McpTokenConfiguration,
  getKey: JWTVerifyGetKey,
): Promise<McpTokenIdentity | null> {
  try {
    const { payload } = await jwtVerify(token, getKey, {
      issuer: configuration.issuer,
      audience: configuration.audience,
      algorithms: ['ES256', 'RS256'],
      clockTolerance: 5,
    })
    if (
      !payload.exp ||
      typeof payload.sub !== 'string' ||
      !UUID_PATTERN.test(payload.sub) ||
      payload.user_id !== payload.sub ||
      payload.role !== 'authenticated' ||
      typeof payload.client_id !== 'string' ||
      !CLIENT_ID_PATTERN.test(payload.client_id) ||
      !Array.isArray(payload.mcp_scopes) ||
      !payload.mcp_scopes.length ||
      payload.mcp_scopes.some((scope) => typeof scope !== 'string' || !MCP_SCOPES.has(scope))
    ) {
      return null
    }

    return {
      actorId: payload.sub,
      clientId: payload.client_id,
      expiresAt: payload.exp,
      scopes: payload.mcp_scopes as string[],
    }
  } catch {
    return null
  }
}

export function resolveMcpIdentity(
  token: McpTokenIdentity,
  registration: {
    active: boolean
    revoked_at: string | null
    scopes: unknown
    resource_audience: unknown
  },
  role: unknown,
  expectedAudience: string,
): McpIdentity | null {
  if (
    !registration.active ||
    registration.revoked_at ||
    registration.resource_audience !== expectedAudience ||
    !Array.isArray(registration.scopes)
  )
    return null
  if (role !== 'viewer' && role !== 'editor' && role !== 'admin') return null

  const scopes = registration.scopes.filter(
    (scope): scope is string => typeof scope === 'string' && MCP_SCOPES.has(scope),
  )
  if (!scopes.length || scopes.length !== registration.scopes.length) return null
  if (
    scopes.length !== token.scopes.length ||
    scopes.some((scope) => !token.scopes.includes(scope))
  ) {
    return null
  }

  return {
    actorId: token.actorId,
    clientId: token.clientId,
    role: role as UserRole,
    scopes,
  }
}
