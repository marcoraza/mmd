import 'server-only'

import type { McpEvent, McpIdentity, McpUnit } from '@/lib/mcp-core'

// This module intentionally has no Supabase client. A raw MCP bearer must never
// be forwarded to the Data API. It is enabled only after a dedicated token exchange
// provides a separate, audience-bound downstream credential.
export async function readMcpEvent(_eventoId: string, _identity: McpIdentity): Promise<McpEvent | null> {
  void _eventoId
  void _identity
  throw new Error('MCP_TOKEN_EXCHANGE_REQUIRED')
}

export async function readMcpUnit(_unidadeId: string, _identity: McpIdentity): Promise<McpUnit | null> {
  void _unidadeId
  void _identity
  throw new Error('MCP_TOKEN_EXCHANGE_REQUIRED')
}
