import assert from 'node:assert/strict'
import test from 'node:test'

import { GET, POST } from '../app/api/mcp/route.ts'

for (const [method, handle] of [
  ['GET', GET],
  ['POST', POST],
] as const) {
  test(`MCP ${method} stays unavailable until remote OAuth and capability access are configured`, async () => {
    const response = await handle(
      new Request('https://mmd.test/api/mcp', {
        method,
        headers: { authorization: 'Bearer any-token' },
        body:
          method === 'POST'
            ? JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize' })
            : undefined,
      }),
    )

    assert.equal(response.status, 503)
    assert.equal(response.headers.get('cache-control'), 'private, no-store')
    assert.deepEqual(await response.json(), { error: 'mcp_remote_not_configured' })
  })
}
