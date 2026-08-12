import assert from 'node:assert/strict'
import test from 'node:test'

import { mcpOAuthConfiguration, mcpProtectedResourceMetadata } from './mcp-oauth.ts'

test('MCP withholds OAuth protected-resource metadata until token exchange is implemented', () => {
  const previousResource = process.env.MMD_MCP_RESOURCE_URL
  const previousAuthorizationServer = process.env.MMD_MCP_AUTHORIZATION_SERVER
  process.env.MMD_MCP_RESOURCE_URL = 'https://mmd.example.com/api/mcp'
  process.env.MMD_MCP_AUTHORIZATION_SERVER = 'https://mmd-auth.example.com'

  try {
    assert.deepEqual(mcpOAuthConfiguration(), {
      resource: 'https://mmd.example.com/api/mcp',
      authorizationServer: 'https://mmd-auth.example.com/',
      metadataUrl: 'https://mmd.example.com/.well-known/oauth-protected-resource/mcp',
    })
    assert.equal(mcpProtectedResourceMetadata(), null)

    process.env.MMD_MCP_RESOURCE_URL = 'http://mmd.example.com/api/mcp'
    assert.equal(mcpProtectedResourceMetadata(), null)
  } finally {
    if (previousResource === undefined) delete process.env.MMD_MCP_RESOURCE_URL
    else process.env.MMD_MCP_RESOURCE_URL = previousResource
    if (previousAuthorizationServer === undefined) delete process.env.MMD_MCP_AUTHORIZATION_SERVER
    else process.env.MMD_MCP_AUTHORIZATION_SERVER = previousAuthorizationServer
  }
})
