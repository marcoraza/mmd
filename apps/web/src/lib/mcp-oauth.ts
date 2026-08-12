import { mcpDatabaseConfiguration } from '@/lib/mcp-data-core'

function httpsUrl(value: string | undefined) {
  if (!value?.trim()) return null
  try {
    const url = new URL(value)
    return url.protocol === 'https:' && !url.search && !url.hash ? url : null
  } catch {
    return null
  }
}

export function mcpOAuthConfiguration() {
  const resource = httpsUrl(process.env.MMD_MCP_RESOURCE_URL)
  const authorizationServer = httpsUrl(process.env.MMD_MCP_AUTHORIZATION_SERVER)
  const supabase = httpsUrl(process.env.NEXT_PUBLIC_SUPABASE_URL)
  if (!resource || !authorizationServer || !supabase) return null
  if (resource.pathname !== '/api/mcp') return null
  if (
    authorizationServer.origin !== supabase.origin ||
    authorizationServer.pathname !== '/auth/v1'
  ) {
    return null
  }

  const issuer = authorizationServer.href.replace(/\/$/, '')
  const configuredJwks = process.env.MMD_MCP_JWKS_URL
    ? httpsUrl(process.env.MMD_MCP_JWKS_URL)
    : new URL(`${issuer}/.well-known/jwks.json`)
  if (!configuredJwks || configuredJwks.origin !== authorizationServer.origin) return null

  return {
    resource: resource.href,
    authorizationServer: issuer,
    issuer,
    jwksUrl: configuredJwks.href,
    metadataUrl: new URL('/.well-known/oauth-protected-resource/mcp', resource).href,
  }
}

export function mcpOAuthAuthenticationIsReady() {
  return Boolean(mcpOAuthConfiguration() && process.env.SUPABASE_SERVICE_ROLE_KEY?.trim())
}

export function mcpRemoteAccessIsReady() {
  return mcpOAuthAuthenticationIsReady() && Boolean(mcpDatabaseConfiguration())
}

export function mcpProtectedResourceMetadata() {
  if (!mcpRemoteAccessIsReady()) return null
  const configuration = mcpOAuthConfiguration()
  if (!configuration) return null
  return {
    resource: configuration.resource,
    authorization_servers: [configuration.authorizationServer],
    bearer_methods_supported: ['header'],
  }
}
