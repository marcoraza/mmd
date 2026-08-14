import assert from 'node:assert/strict'
import test from 'node:test'

import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from 'jose'

import { mcpAuditInsert, resolveMcpIdentity, verifyMcpAccessToken } from './mcp-auth-core.ts'

const ACTOR_ID = '22222222-2222-4222-8222-222222222222'
const ISSUER = 'https://project-ref.supabase.co/auth/v1'
const AUDIENCE = 'https://mmd.example.com/api/mcp'

async function token(overrides: Record<string, unknown> = {}, audience = AUDIENCE) {
  const { privateKey, publicKey } = await generateKeyPair('ES256')
  const jwk = await exportJWK(publicKey)
  const getKey = createLocalJWKSet({ keys: [{ ...jwk, kid: 'mcp-test-key', alg: 'ES256' }] })
  const now = Math.floor(Date.now() / 1000)
  const value = await new SignJWT({
    user_id: ACTOR_ID,
    role: 'authenticated',
    client_id: 'claude-code-test',
    mcp_scopes: ['mcp:read'],
    ...overrides,
  })
    .setProtectedHeader({ alg: 'ES256', kid: 'mcp-test-key' })
    .setSubject(ACTOR_ID)
    .setIssuer(ISSUER)
    .setAudience(audience)
    .setIssuedAt(now)
    .setExpirationTime(now + 300)
    .sign(privateKey)
  return { value, getKey }
}

test('MCP validates an audience-bound Supabase OAuth token', async () => {
  const signed = await token()
  const identity = await verifyMcpAccessToken(
    signed.value,
    { issuer: ISSUER, audience: AUDIENCE },
    signed.getKey,
  )
  assert.equal(identity?.actorId, ACTOR_ID)
  assert.equal(identity?.clientId, 'claude-code-test')
  assert.deepEqual(identity?.scopes, ['mcp:read'])
  assert.equal(typeof identity?.expiresAt, 'number')
})

test('MCP rejects a Supabase web session token issued for the Data API', async () => {
  const signed = await token({}, 'authenticated')
  assert.equal(
    await verifyMcpAccessToken(signed.value, { issuer: ISSUER, audience: AUDIENCE }, signed.getKey),
    null,
  )
})

test('MCP rejects OAuth tokens without a registered client identity', async () => {
  const signed = await token({ client_id: undefined })
  assert.equal(
    await verifyMcpAccessToken(signed.value, { issuer: ISSUER, audience: AUDIENCE }, signed.getKey),
    null,
  )
})

test('MCP rejects OAuth tokens without scopes issued by the MCP registry hook', async () => {
  const signed = await token({ mcp_scopes: undefined })
  assert.equal(
    await verifyMcpAccessToken(signed.value, { issuer: ISSUER, audience: AUDIENCE }, signed.getKey),
    null,
  )
})

test('MCP resolves only active registered clients and canonical profile roles', () => {
  const tokenIdentity = {
    actorId: ACTOR_ID,
    clientId: 'claude-code-test',
    expiresAt: 1_800_000_000,
    scopes: ['mcp:read'],
  }
  assert.deepEqual(
    resolveMcpIdentity(
      tokenIdentity,
      {
        active: true,
        revoked_at: null,
        scopes: ['mcp:read'],
        resource_audience: AUDIENCE,
      },
      'viewer',
      AUDIENCE,
    ),
    {
      actorId: ACTOR_ID,
      clientId: 'claude-code-test',
      role: 'viewer',
      scopes: ['mcp:read'],
    },
  )
  assert.equal(
    resolveMcpIdentity(
      tokenIdentity,
      {
        active: false,
        revoked_at: null,
        scopes: ['mcp:read'],
        resource_audience: AUDIENCE,
      },
      'admin',
      AUDIENCE,
    ),
    null,
  )
  assert.equal(
    resolveMcpIdentity(
      tokenIdentity,
      {
        active: true,
        revoked_at: null,
        scopes: ['mcp:root'],
        resource_audience: AUDIENCE,
      },
      'admin',
      AUDIENCE,
    ),
    null,
  )
  assert.equal(
    resolveMcpIdentity(
      tokenIdentity,
      {
        active: true,
        revoked_at: null,
        scopes: ['mcp:operate'],
        resource_audience: AUDIENCE,
      },
      'admin',
      AUDIENCE,
    ),
    null,
  )
  assert.equal(
    resolveMcpIdentity(
      tokenIdentity,
      {
        active: true,
        revoked_at: null,
        scopes: ['mcp:read'],
        resource_audience: 'https://other.example/api/mcp',
      },
      'viewer',
      AUDIENCE,
    ),
    null,
  )
})

test('MCP lets Postgres assign both audit timestamps from the same clock', () => {
  const row = mcpAuditInsert({
    clientId: 'claude-code-test',
    actorId: ACTOR_ID,
    tool: 'mmd:eventos:list',
    clientRequestId: 'read-request-1',
    payloadHash: '0'.repeat(64),
    intent: 'READ',
    outcome: 'SUCCEEDED',
  })

  assert.deepEqual(row, {
    client_id: 'claude-code-test',
    actor_id: ACTOR_ID,
    tool: 'mmd:eventos:list',
    client_request_id: 'read-request-1',
    payload_hash: '0'.repeat(64),
    intent: 'READ',
    outcome: 'SUCCEEDED',
  })
  assert.equal('completed_at' in row, false)
})
