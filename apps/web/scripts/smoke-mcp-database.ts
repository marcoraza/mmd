import assert from 'node:assert/strict'

import postgres from 'postgres'

import { mcpDatabaseConfiguration } from '../src/lib/mcp-data-core.ts'

async function main() {
  const configuration = mcpDatabaseConfiguration()
  assert.ok(configuration, 'MMD_MCP_DATABASE_URL must point to the dedicated MCP database role')

  const sql = postgres(configuration.connectionString, {
    prepare: false,
    max: 1,
    idle_timeout: 1,
    connect_timeout: 5,
    ssl: configuration.local ? false : 'require',
  })

  try {
    const [identity] = await sql<[{ current_user: string; session_user: string }]>`
    select current_user, session_user
  `
    assert.equal(identity?.current_user, 'mmd_mcp_executor')
    assert.equal(identity?.session_user, 'mmd_mcp_executor')

    let directTableDenied = false
    try {
      await sql`select id from public.items limit 1`
    } catch (error) {
      directTableDenied = (error as { code?: string }).code === '42501'
    }
    assert.equal(directTableDenied, true, 'dedicated MCP role must not read stock tables directly')

    let capabilityRejected = false
    let capabilityFailure = 'no database error returned'
    try {
      await sql`
      select public.mcp_read_unit(
        'invalid-capability',
        '00000000-0000-4000-8000-000000000000'::uuid,
        ${'0'.repeat(64)}
      )
    `
    } catch (error) {
      const databaseError = error as { code?: string; message?: string }
      capabilityFailure = `${databaseError.code ?? 'no-code'}:${databaseError.message ?? 'no-message'}`
      capabilityRejected = databaseError.message?.includes('MCP_CAPABILITY_INVALID') === true
    }
    assert.equal(
      capabilityRejected,
      true,
      `capability RPC must be reachable and fail closed (${capabilityFailure})`,
    )

    console.log(
      'MCP database smoke passed: dedicated login, direct table access denied, capability RPC reachable and fail-closed.',
    )
  } finally {
    await sql.end({ timeout: 1 })
  }
}

void main()
