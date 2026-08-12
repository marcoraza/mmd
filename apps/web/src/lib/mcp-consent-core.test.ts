import assert from 'node:assert/strict'
import test from 'node:test'

import { decideMcpAuthorizationCore, type McpConsentDetails } from './mcp-consent-core.ts'

function dependencies(
  overrides: Partial<{
    userId: string | null
    details: McpConsentDetails | null
    registered: boolean
  }> = {},
) {
  const calls: string[] = []
  return {
    calls,
    value: {
      currentUserId: async () => (overrides.userId === undefined ? 'actor-1' : overrides.userId),
      authorizationDetails: async () =>
        overrides.details === undefined
          ? {
              state: 'pending' as const,
              userId: 'actor-1',
              clientId: 'claude-code',
            }
          : overrides.details,
      clientIsRegistered: async () => overrides.registered !== false,
      approve: async () => {
        calls.push('approve')
        return 'https://client.example/callback?approved=1'
      },
      deny: async () => {
        calls.push('deny')
        return 'https://client.example/callback?denied=1'
      },
    },
  }
}

test('MCP consent approves only a pending authorization for the current user', async () => {
  const deps = dependencies()
  assert.equal(
    await decideMcpAuthorizationCore('authorization-1', 'approve', deps.value),
    'https://client.example/callback?approved=1',
  )
  assert.deepEqual(deps.calls, ['approve'])
})

test('MCP consent denial stays available without granting a revoked client', async () => {
  const deps = dependencies({ registered: false })
  assert.equal(
    await decideMcpAuthorizationCore('authorization-1', 'deny', deps.value),
    'https://client.example/callback?denied=1',
  )
  assert.deepEqual(deps.calls, ['deny'])
})

test('MCP consent rejects a different user before deciding', async () => {
  const deps = dependencies({
    details: {
      state: 'pending',
      userId: 'actor-2',
      clientId: 'claude-code',
    },
  })
  assert.equal(
    await decideMcpAuthorizationCore('authorization-1', 'approve', deps.value),
    '/oauth/consent?error=invalid_request',
  )
  assert.deepEqual(deps.calls, [])
})

test('MCP consent follows an authorization already resolved by the server', async () => {
  const deps = dependencies({
    details: { state: 'resolved', redirectUrl: 'https://client.example/already-resolved' },
  })
  assert.equal(
    await decideMcpAuthorizationCore('authorization-1', 'approve', deps.value),
    'https://client.example/already-resolved',
  )
  assert.deepEqual(deps.calls, [])
})

test('MCP consent rejects approval when registry revocation or audience mismatch denies client', async () => {
  const deps = dependencies({ registered: false })
  assert.equal(
    await decideMcpAuthorizationCore('authorization-1', 'approve', deps.value),
    '/oauth/consent?error=client_not_registered',
  )
  assert.deepEqual(deps.calls, [])
})
