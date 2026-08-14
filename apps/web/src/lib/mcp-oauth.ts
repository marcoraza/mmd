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

export function oauthAuthorizationServerMetadataUrl(issuer: URL) {
  const issuerPath = issuer.pathname.replace(/\/$/, '')
  return new URL(`/.well-known/oauth-authorization-server${issuerPath}`, issuer)
}

function stringArrayIncludes(value: unknown, expected: string) {
  return Array.isArray(value) && value.includes(expected)
}

export function mcpAuthorizationServerMetadataIsReady(metadata: unknown, issuer: URL) {
  if (!metadata || typeof metadata !== 'object') return false
  const value = metadata as Record<string, unknown>
  const base = issuer.href.replace(/\/$/, '')
  return (
    value.issuer === base &&
    value.authorization_endpoint === `${base}/oauth/authorize` &&
    value.token_endpoint === `${base}/oauth/token` &&
    value.jwks_uri === `${base}/.well-known/jwks.json` &&
    stringArrayIncludes(value.response_types_supported, 'code') &&
    stringArrayIncludes(value.grant_types_supported, 'authorization_code') &&
    stringArrayIncludes(value.grant_types_supported, 'refresh_token') &&
    stringArrayIncludes(value.code_challenge_methods_supported, 'S256') &&
    stringArrayIncludes(value.token_endpoint_auth_methods_supported, 'none')
  )
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
  return (
    process.env.MMD_MCP_REMOTE_ENABLED === 'true' &&
    mcpOAuthAuthenticationIsReady() &&
    Boolean(mcpDatabaseConfiguration())
  )
}

export function mcpProtectedResourceMetadata() {
  if (!mcpOAuthAuthenticationIsReady()) return null
  const configuration = mcpOAuthConfiguration()
  if (!configuration) return null
  return {
    resource: configuration.resource,
    authorization_servers: [configuration.authorizationServer],
    bearer_methods_supported: ['header'],
  }
}
