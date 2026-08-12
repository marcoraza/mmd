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
  const oauthSql = migration('20260812210000_mcp_oauth_and_read_capabilities.sql')
  const mutationSql = migration('20260812220000_mcp_mutation_capabilities.sql')

  assert.match(sql, /CREATE TABLE public\.mcp_clients/)
  assert.match(oauthSql, /CREATE ROLE mmd_mcp_executor NOLOGIN NOINHERIT NOBYPASSRLS/)
  assert.match(oauthSql, /REVOKE authenticated FROM mmd_mcp_executor/)
  assert.match(oauthSql, /ALTER COLUMN resource_audience SET NOT NULL/)
  assert.match(oauthSql, /DROP COLUMN secret_hash/)
  assert.match(oauthSql, /CREATE OR REPLACE FUNCTION public\.mmd_custom_access_token_hook/)
  assert.match(oauthSql, /jsonb_set\(v_claims, '\{aud\}'/)
  assert.match(oauthSql, /jsonb_set\(v_claims, '\{mcp_scopes\}'/)
  assert.match(oauthSql, /CREATE TABLE app_private\.mcp_read_capabilities/)
  assert.match(oauthSql, /CREATE OR REPLACE FUNCTION public\.mcp_read_event/)
  assert.match(oauthSql, /CREATE OR REPLACE FUNCTION public\.mcp_read_unit/)
  assert.match(oauthSql, /random|digest\(p_capability_token, 'sha256'\)/)
  assert.doesNotMatch(oauthSql, /set_config\('request\.jwt\.claims'|SET ROLE authenticated/i)
  assert.match(sql, /CREATE TABLE public\.mcp_operation_log/)
  assert.match(sql, /client_id text NOT NULL REFERENCES public\.mcp_clients/)
  assert.match(sql, /actor_id uuid NOT NULL REFERENCES auth\.users/)
  assert.match(sql, /tool text NOT NULL/)
  assert.match(sql, /client_request_id text NOT NULL/)
  assert.match(sql, /payload_hash text NOT NULL/)
  assert.match(sql, /UNIQUE \(\s*client_id,\s*actor_id,\s*tool,\s*client_request_id\s*\)/s)
  assert.doesNotMatch(sql, /client_request_id,\s*payload_hash\s*\)/s)
  assert.match(sql, /REVOKE ALL PRIVILEGES ON TABLE public\.mcp_clients FROM anon, authenticated;/)
  assert.match(sql, /CREATE TABLE public\.mcp_rate_limit_buckets/)
  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.claim_mcp_rate_limit/)
  assert.match(sql, /IF auth\.role\(\) <> 'service_role' THEN/)
  assert.match(sql, /PRIMARY KEY \(client_id, actor_id, window_started_at\)/)
  assert.match(
    sql,
    /GRANT EXECUTE ON FUNCTION public\.claim_mcp_rate_limit\(text, uuid, integer\) TO service_role;/,
  )
  assert.doesNotMatch(sql, /bearer_token|authorization(?:_token)?|service_role_key/i)
  assert.doesNotMatch(oauthSql, /bearer_token|authorization(?:_token)?|service_role_key/i)
  assert.match(mutationSql, /CREATE TABLE app_private\.mcp_operation_capabilities/)
  assert.match(mutationSql, /CREATE OR REPLACE FUNCTION public\.execute_mcp_operation/)
  assert.match(mutationSql, /MCP_REQUEST_PAYLOAD_CONFLICT/)
  assert.match(mutationSql, /outcome = 'SUCCEEDED'/)
  assert.match(mutationSql, /outcome = CASE WHEN SQLSTATE/)
  assert.match(mutationSql, /GRANT EXECUTE ON FUNCTION public\.execute_mcp_operation/)
  assert.doesNotMatch(mutationSql, /bearer_token|authorization(?:_token)?|service_role_key/i)
  for (const target of Object.values(MCP_AUDIT_TARGETS)) {
    assert.match(target, /^[A-Za-z0-9][A-Za-z0-9._:/-]{2,127}$/)
  }
})
