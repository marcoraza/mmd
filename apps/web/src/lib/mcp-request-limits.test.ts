import assert from 'node:assert/strict'
import test from 'node:test'

import { NextRequest } from 'next/server'

import {
  asPlainMcpRequest,
  enforceMcpRequestBodyLimit,
  McpRequestTooLargeError,
} from './mcp-request-limits.ts'

test('MCP converts the Next.js request wrapper before protocol parsing', async () => {
  const wrapped = new NextRequest('https://mmd.test/api/mcp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: '{"jsonrpc":"2.0","id":1}',
  })

  const plain = asPlainMcpRequest(wrapped)

  assert.equal(plain.constructor, Request)
  assert.equal(await plain.text(), '{"jsonrpc":"2.0","id":1}')
})

test('MCP body limit rejects chunked requests without Content-Length before JSON parsing', async () => {
  const body = new ReadableStream({
    start(controller) {
      controller.enqueue(new Uint8Array(128 * 1024))
      controller.enqueue(new Uint8Array(1))
      controller.close()
    },
  })
  const request = new Request('https://mmd.test/api/mcp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body,
    duplex: 'half',
  } as RequestInit)

  await assert.rejects(() => enforceMcpRequestBodyLimit(request), McpRequestTooLargeError)
})

test('MCP body limit keeps a bounded body readable by the protocol handler', async () => {
  const request = new Request('https://mmd.test/api/mcp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: '{"jsonrpc":"2.0"}',
  })

  const limited = await enforceMcpRequestBodyLimit(request)
  assert.equal(await limited.text(), '{"jsonrpc":"2.0"}')
})
