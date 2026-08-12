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
  if (!resource || !authorizationServer) return null
  if (resource.pathname !== '/api/mcp') return null

  return {
    resource: resource.href,
    authorizationServer: authorizationServer.href,
    metadataUrl: new URL('/.well-known/oauth-protected-resource/mcp', resource).href,
  }
}

export function mcpRemoteAccessIsReady() {
  return false
}

export function mcpProtectedResourceMetadata() {
  if (!mcpRemoteAccessIsReady()) return null
  const configuration = mcpOAuthConfiguration()
  if (!configuration) return null
  return {
    resource: configuration.resource,
    authorization_servers: [configuration.authorizationServer],
    scopes_supported: ['mcp:read', 'mcp:operate'],
    bearer_methods_supported: ['header'],
  }
}
