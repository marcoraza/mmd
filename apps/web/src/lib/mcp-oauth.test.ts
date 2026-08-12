import assert from 'node:assert/strict'
import test from 'node:test'

import {
  mcpOAuthAuthenticationIsReady,
  mcpOAuthConfiguration,
  mcpProtectedResourceMetadata,
  mcpRemoteAccessIsReady,
} from './mcp-oauth.ts'

test('MCP publishes OAuth metadata only with audience verification and dedicated capability access', () => {
  const previousResource = process.env.MMD_MCP_RESOURCE_URL
  const previousAuthorizationServer = process.env.MMD_MCP_AUTHORIZATION_SERVER
  const previousSupabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const previousServiceRole = process.env.SUPABASE_SERVICE_ROLE_KEY
  const previousDatabaseUrl = process.env.MMD_MCP_DATABASE_URL
  process.env.MMD_MCP_RESOURCE_URL = 'https://mmd.example.com/api/mcp'
  process.env.NEXT_PUBLIC_SUPABASE_URL = 'https://projectref.supabase.co'
  process.env.MMD_MCP_AUTHORIZATION_SERVER = 'https://projectref.supabase.co/auth/v1'
  process.env.SUPABASE_SERVICE_ROLE_KEY = 'registry-only-test-key'
  process.env.MMD_MCP_DATABASE_URL =
    'postgresql://mmd_mcp_executor.projectref:secret@aws-0-sa-east-1.pooler.supabase.com:6543/postgres'

  try {
    assert.deepEqual(mcpOAuthConfiguration(), {
      resource: 'https://mmd.example.com/api/mcp',
      authorizationServer: 'https://projectref.supabase.co/auth/v1',
      issuer: 'https://projectref.supabase.co/auth/v1',
      jwksUrl: 'https://projectref.supabase.co/auth/v1/.well-known/jwks.json',
      metadataUrl: 'https://mmd.example.com/.well-known/oauth-protected-resource/mcp',
    })
    assert.equal(mcpOAuthAuthenticationIsReady(), true)
    assert.equal(mcpRemoteAccessIsReady(), true)
    assert.deepEqual(mcpProtectedResourceMetadata(), {
      resource: 'https://mmd.example.com/api/mcp',
      authorization_servers: ['https://projectref.supabase.co/auth/v1'],
      bearer_methods_supported: ['header'],
    })

    process.env.MMD_MCP_RESOURCE_URL = 'http://mmd.example.com/api/mcp'
    assert.equal(mcpProtectedResourceMetadata(), null)

    process.env.MMD_MCP_RESOURCE_URL = 'https://mmd.example.com/api/mcp'
    process.env.MMD_MCP_AUTHORIZATION_SERVER = 'https://attacker.example.com/auth/v1'
    assert.equal(mcpOAuthConfiguration(), null)
  } finally {
    if (previousResource === undefined) delete process.env.MMD_MCP_RESOURCE_URL
    else process.env.MMD_MCP_RESOURCE_URL = previousResource
    if (previousAuthorizationServer === undefined) delete process.env.MMD_MCP_AUTHORIZATION_SERVER
    else process.env.MMD_MCP_AUTHORIZATION_SERVER = previousAuthorizationServer
    if (previousSupabaseUrl === undefined) delete process.env.NEXT_PUBLIC_SUPABASE_URL
    else process.env.NEXT_PUBLIC_SUPABASE_URL = previousSupabaseUrl
    if (previousServiceRole === undefined) delete process.env.SUPABASE_SERVICE_ROLE_KEY
    else process.env.SUPABASE_SERVICE_ROLE_KEY = previousServiceRole
    if (previousDatabaseUrl === undefined) delete process.env.MMD_MCP_DATABASE_URL
    else process.env.MMD_MCP_DATABASE_URL = previousDatabaseUrl
  }
})
