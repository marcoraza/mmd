import assert from 'node:assert/strict'

import {
  mcpAuthorizationServerMetadataIsReady,
  oauthAuthorizationServerMetadataUrl,
} from '../src/lib/mcp-oauth.ts'

const REMOTE_REQUEST_TIMEOUT_MS = 10_000

function requiredHttpsUrl(name: 'MMD_MCP_RESOURCE_URL') {
  const value = process.env[name]?.trim()
  assert.ok(value, `${name} is required`)
  const url = new URL(value)
  assert.equal(url.protocol, 'https:', `${name} must use HTTPS`)
  assert.equal(url.pathname, '/api/mcp', `${name} must end with /api/mcp`)
  assert.equal(url.search, '', `${name} must not include a query`)
  assert.equal(url.hash, '', `${name} must not include a fragment`)
  return url
}

async function jsonResponse(response: Response, label: string) {
  const text = await response.text()
  assert.equal(response.ok, true, `${label} returned ${response.status}: ${text}`)
  return JSON.parse(text) as Record<string, unknown>
}

async function remoteFetch(url: URL, label: string, init?: RequestInit) {
  try {
    return await fetch(url, {
      ...init,
      signal: AbortSignal.timeout(REMOTE_REQUEST_TIMEOUT_MS),
    })
  } catch (error) {
    const detail = error instanceof Error ? error.message : 'unknown error'
    throw new Error(`${label} request failed: ${detail}`, { cause: error })
  }
}

async function main() {
  const resource = requiredHttpsUrl('MMD_MCP_RESOURCE_URL')
  const expectRemoteEnabled = process.env.MMD_MCP_EXPECT_REMOTE_ENABLED === 'true'
  const metadataUrl = new URL('/.well-known/oauth-protected-resource/mcp', resource)
  const metadataResponse = await remoteFetch(metadataUrl, 'protected resource metadata', {
    cache: 'no-store',
  })
  const metadata = await jsonResponse(metadataResponse, 'protected resource metadata')

  assert.equal(metadata.resource, resource.href)
  assert.deepEqual(metadata.bearer_methods_supported, ['header'])
  assert.ok(Array.isArray(metadata.authorization_servers))
  assert.equal(metadata.authorization_servers.length, 1)

  const authorizationServer = new URL(String(metadata.authorization_servers[0]))
  assert.equal(authorizationServer.protocol, 'https:')
  const authorizationMetadataUrl = oauthAuthorizationServerMetadataUrl(authorizationServer)
  const authorizationMetadataResponse = await remoteFetch(
    authorizationMetadataUrl,
    'authorization server metadata',
    { cache: 'no-store' },
  )
  const authorizationMetadata = await jsonResponse(
    authorizationMetadataResponse,
    'authorization server metadata',
  )
  assert.equal(
    mcpAuthorizationServerMetadataIsReady(authorizationMetadata, authorizationServer),
    true,
    'authorization server metadata must support authorization code, refresh token and PKCE S256',
  )

  const challengeResponse = await remoteFetch(resource, 'MCP challenge', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-mmd-mcp-request-id': `remote-preflight-${crypto.randomUUID()}`,
    },
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: 1,
      method: 'initialize',
      params: {
        protocolVersion: '2025-11-25',
        capabilities: {},
        clientInfo: { name: 'mmd-remote-preflight', version: '1.0.0' },
      },
    }),
  })
  if (!expectRemoteEnabled) {
    assert.equal(challengeResponse.status, 503, 'MCP must stay closed before final activation')
    assert.deepEqual(await challengeResponse.json(), { error: 'mcp_remote_not_configured' })
    console.log(
      'MCP remote preflight passed: OAuth metadata is ready and the MCP endpoint remains closed.',
    )
    return
  }

  assert.equal(challengeResponse.status, 401, 'MCP must challenge an unauthenticated client')
  const authenticate = challengeResponse.headers.get('www-authenticate') ?? ''
  assert.match(authenticate, /^Bearer /)
  assert.ok(authenticate.includes(`resource_metadata="${metadataUrl.href}"`))

  console.log(
    'MCP remote activation smoke passed: protected metadata, authorization server and 401 challenge are ready.',
  )
}

void main()
