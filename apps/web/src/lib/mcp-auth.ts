import 'server-only'

import { createClient } from '@supabase/supabase-js'

import type { McpAuditInput, McpIdentity } from '@/lib/mcp-core'

function requiredEnv(name: 'NEXT_PUBLIC_SUPABASE_URL' | 'NEXT_PUBLIC_SUPABASE_ANON_KEY') {
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
      target !== 'rpc/claim_mcp_rate_limit'
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

export async function authenticateMcpRequest(request: Request): Promise<McpIdentity | null> {
  void request
  // Do not treat a Supabase web access token as an MCP access token. This is
  // enabled only by the dedicated issuer/audience-validating token-exchange adapter.
  return null
}

export async function recordMcpAudit(input: McpAuditInput): Promise<void> {
  const registry = createRegistryClient()
  const base = {
    client_id: input.clientId,
    actor_id: input.actorId,
    tool: input.tool,
    client_request_id: input.clientRequestId,
    payload_hash: input.payloadHash,
    intent: input.intent,
    outcome: input.outcome,
    completed_at: new Date().toISOString(),
  }

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
