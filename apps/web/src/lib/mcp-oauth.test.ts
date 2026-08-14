import assert from 'node:assert/strict'
import test from 'node:test'

import {
  mcpOAuthAuthenticationIsReady,
  mcpAuthorizationServerMetadataIsReady,
  mcpOAuthConfiguration,
  mcpProtectedResourceMetadata,
  mcpRemoteAccessIsReady,
  oauthAuthorizationServerMetadataUrl,
} from './mcp-oauth.ts'

test('MCP resolves OAuth discovery from an issuer with a path', () => {
  assert.equal(
    oauthAuthorizationServerMetadataUrl(new URL('https://projectref.supabase.co/auth/v1')).href,
    'https://projectref.supabase.co/.well-known/oauth-authorization-server/auth/v1',
  )
})

test('MCP requires complete OAuth authorization-code metadata before remote activation', () => {
  const issuer = new URL('https://projectref.supabase.co/auth/v1')
  const complete = {
    issuer: issuer.href,
    authorization_endpoint: `${issuer.href}/oauth/authorize`,
    token_endpoint: `${issuer.href}/oauth/token`,
    jwks_uri: `${issuer.href}/.well-known/jwks.json`,
    response_types_supported: ['code'],
    grant_types_supported: ['authorization_code', 'refresh_token'],
    code_challenge_methods_supported: ['S256'],
    token_endpoint_auth_methods_supported: ['none'],
  }

  assert.equal(mcpAuthorizationServerMetadataIsReady(complete, issuer), true)
  assert.equal(mcpAuthorizationServerMetadataIsReady({ issuer: issuer.href }, issuer), false)
  assert.equal(
    mcpAuthorizationServerMetadataIsReady(
      { ...complete, token_endpoint_auth_methods_supported: ['client_secret_basic'] },
      issuer,
    ),
    false,
  )
  assert.equal(
    mcpAuthorizationServerMetadataIsReady(
      { ...complete, token_endpoint: 'http://projectref.supabase.co/auth/v1/oauth/token' },
      issuer,
    ),
    false,
  )
})

test('MCP publishes OAuth metadata only with audience verification and dedicated capability access', () => {
  const previousResource = process.env.MMD_MCP_RESOURCE_URL
  const previousAuthorizationServer = process.env.MMD_MCP_AUTHORIZATION_SERVER
  const previousSupabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const previousServiceRole = process.env.SUPABASE_SERVICE_ROLE_KEY
  const previousDatabaseUrl = process.env.MMD_MCP_DATABASE_URL
  const previousRemoteEnabled = process.env.MMD_MCP_REMOTE_ENABLED
  process.env.MMD_MCP_RESOURCE_URL = 'https://mmd.example.com/api/mcp'
  process.env.NEXT_PUBLIC_SUPABASE_URL = 'https://projectref.supabase.co'
  process.env.MMD_MCP_AUTHORIZATION_SERVER = 'https://projectref.supabase.co/auth/v1'
  process.env.SUPABASE_SERVICE_ROLE_KEY = 'registry-only-test-key'
  process.env.MMD_MCP_DATABASE_URL =
    'postgresql://mmd_mcp_executor.projectref:secret@aws-0-sa-east-1.pooler.supabase.com:6543/postgres'
  delete process.env.MMD_MCP_REMOTE_ENABLED

  try {
    assert.deepEqual(mcpOAuthConfiguration(), {
      resource: 'https://mmd.example.com/api/mcp',
      authorizationServer: 'https://projectref.supabase.co/auth/v1',
      issuer: 'https://projectref.supabase.co/auth/v1',
      jwksUrl: 'https://projectref.supabase.co/auth/v1/.well-known/jwks.json',
      metadataUrl: 'https://mmd.example.com/.well-known/oauth-protected-resource/mcp',
    })
    assert.equal(mcpOAuthAuthenticationIsReady(), true)
    assert.equal(mcpRemoteAccessIsReady(), false)
    assert.deepEqual(mcpProtectedResourceMetadata(), {
      resource: 'https://mmd.example.com/api/mcp',
      authorization_servers: ['https://projectref.supabase.co/auth/v1'],
      bearer_methods_supported: ['header'],
    })

    process.env.MMD_MCP_REMOTE_ENABLED = 'true'
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
    if (previousRemoteEnabled === undefined) delete process.env.MMD_MCP_REMOTE_ENABLED
    else process.env.MMD_MCP_REMOTE_ENABLED = previousRemoteEnabled
  }
})
