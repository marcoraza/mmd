import 'server-only'

import { createHash, randomBytes } from 'node:crypto'

import { createClient } from '@supabase/supabase-js'
import { createRemoteJWKSet } from 'jose'

import { extractBearerToken } from '@/lib/action-auth-core'
import { mcpAuditInsert, resolveMcpIdentity, verifyMcpAccessToken } from '@/lib/mcp-auth-core'
import type { McpAuditInput, McpIdentity, McpMutationTool } from '@/lib/mcp-core'
import { mcpOAuthConfiguration } from '@/lib/mcp-oauth'
import type { McpDomainReadTarget } from '@/lib/mcp-read-resources'

const remoteKeySets = new Map<string, ReturnType<typeof createRemoteJWKSet>>()

function requiredEnv(name: 'NEXT_PUBLIC_SUPABASE_URL') {
  const value = process.env[name]?.trim()
  if (!value) throw new Error(`MCP_${name}_MISSING`)
  return value
}

function createRegistryClient() {
  const url = requiredEnv('NEXT_PUBLIC_SUPABASE_URL')
  const serviceRole = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim()
  if (!serviceRole) throw new Error('MCP_REGISTRY_SERVICE_KEY_MISSING')

  const guardedFetch: typeof fetch = async (input, init) => {
    const inputUrl =
      typeof input === 'string' ? input : input instanceof URL ? input.href : input.url
    const requestUrl = new URL(inputUrl)
    const target = requestUrl.pathname.replace(/^\/rest\/v1\//, '')
    if (
      target !== 'mcp_clients' &&
      target !== 'mcp_operation_log' &&
      target !== 'profiles' &&
      target !== 'rpc/claim_mcp_rate_limit' &&
      target !== 'rpc/issue_mcp_read_capability' &&
      target !== 'rpc/issue_mcp_collection_capability' &&
      target !== 'rpc/issue_mcp_operation_capability'
    ) {
      throw new Error('MCP_REGISTRY_TABLE_DENIED')
    }
    return fetch(input, init)
  }

  return createClient(url, serviceRole, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: guardedFetch },
  })
}

export async function registeredMcpClient(clientId: string) {
  const resource = mcpOAuthConfiguration()?.resource
  if (!resource) return null
  if (!/^[A-Za-z0-9][A-Za-z0-9._:-]{2,127}$/.test(clientId)) return null
  const { data, error } = await createRegistryClient()
    .from('mcp_clients')
    .select('active,revoked_at,scopes,resource_audience')
    .eq('client_id', clientId)
    .maybeSingle()
  if (
    error ||
    !data?.active ||
    data.revoked_at ||
    data.resource_audience !== resource ||
    !Array.isArray(data.scopes)
  )
    return null
  const scopes = data.scopes.filter((scope): scope is string => typeof scope === 'string')
  return scopes.length ? { scopes } : null
}

export async function authenticateMcpRequest(request: Request): Promise<McpIdentity | null> {
  const configuration = mcpOAuthConfiguration()
  const bearer = extractBearerToken(request.headers.get('authorization'))
  if (!configuration || !bearer) return null

  let getKey = remoteKeySets.get(configuration.jwksUrl)
  if (!getKey) {
    getKey = createRemoteJWKSet(new URL(configuration.jwksUrl), {
      timeoutDuration: 5_000,
      cooldownDuration: 30_000,
      cacheMaxAge: 10 * 60_000,
    })
    remoteKeySets.set(configuration.jwksUrl, getKey)
  }

  const token = await verifyMcpAccessToken(
    bearer,
    { issuer: configuration.issuer, audience: configuration.resource },
    getKey,
  )
  if (!token) return null

  const registry = createRegistryClient()
  const [clientResult, profileResult] = await Promise.all([
    registry
      .from('mcp_clients')
      .select('active,revoked_at,scopes,resource_audience')
      .eq('client_id', token.clientId)
      .maybeSingle(),
    registry.from('profiles').select('role').eq('id', token.actorId).maybeSingle(),
  ])
  if (
    clientResult.error ||
    profileResult.error ||
    !clientResult.data ||
    clientResult.data.resource_audience !== configuration.resource ||
    !profileResult.data
  )
    return null

  return resolveMcpIdentity(
    token,
    clientResult.data,
    profileResult.data.role,
    configuration.resource,
  )
}

export async function issueMcpReadCapability(
  identity: McpIdentity,
  target: 'mmd:eventos:read' | 'mmd:unidades:read',
  resourceId: string,
) {
  const token = randomBytes(32).toString('base64url')
  const tokenHash = createHash('sha256').update(token).digest('hex')
  const payloadHash = createHash('sha256')
    .update(JSON.stringify({ resource_id: resourceId }))
    .digest('hex')
  const { error } = await createRegistryClient().rpc('issue_mcp_read_capability', {
    p_token_hash: tokenHash,
    p_client_id: identity.clientId,
    p_actor_id: identity.actorId,
    p_target: target,
    p_resource_id: resourceId,
    p_payload_hash: payloadHash,
    p_ttl_seconds: 30,
  })
  if (error) throw new Error('MCP_CAPABILITY_ISSUE_FAILED')
  return { token, payloadHash }
}

export async function issueMcpDomainReadCapability(
  identity: McpIdentity,
  target: McpDomainReadTarget,
  args: Record<string, unknown>,
) {
  const token = randomBytes(32).toString('base64url')
  const tokenHash = createHash('sha256').update(token).digest('hex')
  const { error } = await createRegistryClient().rpc('issue_mcp_collection_capability', {
    p_token_hash: tokenHash,
    p_client_id: identity.clientId,
    p_actor_id: identity.actorId,
    p_target: target,
    p_arguments: args,
    p_ttl_seconds: 30,
  })
  if (error) throw new Error('MCP_CAPABILITY_ISSUE_FAILED')
  return token
}

export async function issueMcpOperationCapability(
  identity: McpIdentity,
  tool: McpMutationTool,
  clientRequestId: string,
  args: Record<string, unknown>,
) {
  const token = randomBytes(32).toString('base64url')
  const tokenHash = createHash('sha256').update(token).digest('hex')
  const { data, error } = await createRegistryClient().rpc('issue_mcp_operation_capability', {
    p_token_hash: tokenHash,
    p_client_id: identity.clientId,
    p_actor_id: identity.actorId,
    p_tool: tool,
    p_client_request_id: clientRequestId,
    p_arguments: args,
    p_ttl_seconds: 30,
  })
  if (error?.code === '42501' || error?.message.includes('MCP_OPERATION_PERMISSION_DENIED')) {
    throw new Error('MCP_OPERATION_DENIED')
  }
  if (error || !data || typeof data !== 'object') {
    throw new Error('MCP_OPERATION_CLAIM_FAILED')
  }
  const claim = data as { completed?: unknown; operation_id?: unknown; result?: unknown }
  if (typeof claim.operation_id !== 'string') throw new Error('MCP_OPERATION_CLAIM_INVALID')
  return claim.completed === true
    ? { completed: true as const, operationId: claim.operation_id, result: claim.result }
    : { completed: false as const, operationId: claim.operation_id, token }
}

export async function recordMcpAudit(input: McpAuditInput): Promise<void> {
  const registry = createRegistryClient()
  const base = mcpAuditInsert(input)

  const { data: previous, error: previousError } = await registry
    .from('mcp_operation_log')
    .select('payload_hash')
    .eq('client_id', input.clientId)
    .eq('actor_id', input.actorId)
    .eq('tool', input.tool)
    .eq('client_request_id', input.clientRequestId)
    .maybeSingle()
  if (previousError) throw new Error('MCP_AUDIT_LOOKUP_FAILED')
  if (previous && previous.payload_hash !== input.payloadHash) {
    throw new Error('MCP_REQUEST_PAYLOAD_CONFLICT')
  }
  if (previous) return

  const { error } = await registry.from('mcp_operation_log').insert(base)
  if (error) {
    const { data: raced } = await registry
      .from('mcp_operation_log')
      .select('payload_hash')
      .eq('client_id', input.clientId)
      .eq('actor_id', input.actorId)
      .eq('tool', input.tool)
      .eq('client_request_id', input.clientRequestId)
      .maybeSingle()
    if (raced?.payload_hash === input.payloadHash) return
    throw new Error('MCP_AUDIT_WRITE_FAILED')
  }
}

function rateLimitPerMinute() {
  const parsed = Number(process.env.MMD_MCP_RATE_LIMIT_PER_MINUTE ?? '60')
  return Number.isSafeInteger(parsed) ? Math.min(Math.max(parsed, 1), 1_000) : 60
}

export async function enforceMcpRateLimit(
  identity: McpIdentity,
  _request: Request,
): Promise<'allowed' | 'limited' | 'unavailable'> {
  void _request
  try {
    const { data, error } = await createRegistryClient().rpc('claim_mcp_rate_limit', {
      p_client_id: identity.clientId,
      p_actor_id: identity.actorId,
      p_limit: rateLimitPerMinute(),
    })
    if (error) return 'unavailable'
    return data === true ? 'allowed' : 'limited'
  } catch {
    return 'unavailable'
  }
}
