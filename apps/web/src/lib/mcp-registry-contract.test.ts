import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import test from 'node:test'

import { MCP_AUDIT_TARGETS } from './mcp-core.ts'

function migration(path: string) {
  return readFileSync(join(process.cwd(), '..', '..', 'supabase', 'migrations', path), 'utf8')
}

test('registro MCP vincula cliente, ator, ferramenta, request e payload sem expor segredo', () => {
  const sql = migration('20260812163430_mcp_client_registry_and_operations.sql')

  assert.match(sql, /CREATE TABLE public\.mcp_clients/)
  assert.match(sql, /secret_hash text NOT NULL/)
  assert.match(sql, /CREATE TABLE public\.mcp_operation_log/)
  assert.match(sql, /client_id text NOT NULL REFERENCES public\.mcp_clients/)
  assert.match(sql, /actor_id uuid NOT NULL REFERENCES auth\.users/)
  assert.match(sql, /tool text NOT NULL/)
  assert.match(sql, /client_request_id text NOT NULL/)
  assert.match(sql, /payload_hash text NOT NULL/)
  assert.match(
    sql,
    /UNIQUE \(\s*client_id,\s*actor_id,\s*tool,\s*client_request_id\s*\)/s,
  )
  assert.doesNotMatch(sql, /client_request_id,\s*payload_hash\s*\)/s)
  assert.match(sql, /REVOKE ALL PRIVILEGES ON TABLE public\.mcp_clients FROM anon, authenticated;/)
  assert.match(sql, /CREATE TABLE public\.mcp_rate_limit_buckets/)
  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.claim_mcp_rate_limit/)
  assert.match(sql, /IF auth\.role\(\) <> 'service_role' THEN/)
  assert.match(sql, /PRIMARY KEY \(client_id, actor_id, window_started_at\)/)
  assert.match(sql, /GRANT EXECUTE ON FUNCTION public\.claim_mcp_rate_limit\(text, uuid, integer\) TO service_role;/)
  assert.doesNotMatch(sql, /bearer_token|authorization(?:_token)?|service_role_key/i)
  for (const target of Object.values(MCP_AUDIT_TARGETS)) {
    assert.match(target, /^[A-Za-z0-9][A-Za-z0-9._:/-]{2,127}$/)
  }
})
