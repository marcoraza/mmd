import { createMcpRequestHandler } from '@/lib/mcp-core'
import { mcpOAuthConfiguration, mcpRemoteAccessIsReady } from '@/lib/mcp-oauth'
import {
  enforceMcpRequestBodyLimit,
  MAX_MCP_BODY_BYTES,
  McpRequestTooLargeError,
} from '@/lib/mcp-request-limits'

export const runtime = 'nodejs'

function allowedOrigins() {
  return (process.env.MMD_MCP_ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean)
}

async function handleMcp(request: Request) {
  const [{ authenticateMcpRequest, enforceMcpRateLimit, recordMcpAudit }, { readMcpEvent, readMcpUnit }] =
    await Promise.all([import('@/lib/mcp-auth'), import('@/lib/mcp-data')])
  const handler = createMcpRequestHandler({
    authenticate: authenticateMcpRequest,
    readEvent: readMcpEvent,
    readUnit: readMcpUnit,
    audit: recordMcpAudit,
    rateLimit: enforceMcpRateLimit,
    allowedOrigins: allowedOrigins(),
    resourceMetadataUrl: () => mcpOAuthConfiguration()?.metadataUrl ?? null,
  })
  return handler(request)
}

function bodyTooLarge(request: Request) {
  const contentLength = Number(request.headers.get('content-length') ?? '0')
  return Number.isFinite(contentLength) && contentLength > MAX_MCP_BODY_BYTES
}

function hasConfiguredMcpHost(request: Request) {
  const resource = mcpOAuthConfiguration()?.resource
  if (!resource) return false
  const expectedHost = new URL(resource).host
  const suppliedHost = (request.headers.get('x-forwarded-host') ?? request.headers.get('host') ?? '')
    .split(',')[0]
    .trim()
  return suppliedHost === expectedHost
}

async function respond(request: Request) {
  if (!mcpRemoteAccessIsReady()) {
    return new Response(JSON.stringify({ error: 'mcp_token_exchange_required' }), {
      status: 503,
      headers: { 'cache-control': 'private, no-store', 'content-type': 'application/json' },
    })
  }
  if (!hasConfiguredMcpHost(request)) {
    return new Response(JSON.stringify({ error: 'mcp_host_not_allowed' }), {
      status: 421,
      headers: { 'cache-control': 'private, no-store', 'content-type': 'application/json' },
    })
  }
  if (bodyTooLarge(request)) {
    return new Response(JSON.stringify({ error: 'request_too_large' }), {
      status: 413,
      headers: { 'cache-control': 'private, no-store', 'content-type': 'application/json' },
    })
  }
  try {
    return handleMcp(await enforceMcpRequestBodyLimit(request))
  } catch (error) {
    if (error instanceof McpRequestTooLargeError) {
      return new Response(JSON.stringify({ error: 'request_too_large' }), {
        status: 413,
        headers: { 'cache-control': 'private, no-store', 'content-type': 'application/json' },
      })
    }
    throw error
  }
}

export const GET = respond
export const POST = respond
