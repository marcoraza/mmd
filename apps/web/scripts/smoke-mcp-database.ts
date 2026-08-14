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

    const capabilityCalls = [
      () =>
        sql`select public.mcp_read_unit('invalid-capability', '00000000-0000-4000-8000-000000000000'::uuid, ${'0'.repeat(64)})`,
      () =>
        sql`select public.mcp_read_event('invalid-capability', '00000000-0000-4000-8000-000000000000'::uuid, ${'0'.repeat(64)})`,
      () => sql`select public.mcp_read_events('invalid-capability', null, null, null, 1, 50)`,
      () => sql`select public.mcp_read_catalog('invalid-capability', null, 1, 50)`,
      () =>
        sql`select public.mcp_read_packing('invalid-capability', '00000000-0000-4000-8000-000000000000'::uuid, 1, 50)`,
      () =>
        sql`select public.mcp_read_movements('invalid-capability', '00000000-0000-4000-8000-000000000000'::uuid, 1, 50)`,
      () =>
        sql`select public.mcp_read_conference('invalid-capability', '00000000-0000-4000-8000-000000000000'::uuid, 'SAIDA', 1, 50)`,
      () =>
        sql`select public.mcp_read_expected_return('invalid-capability', '00000000-0000-4000-8000-000000000000'::uuid, 1, 50)`,
      () =>
        sql`select public.mcp_read_return_pendings('invalid-capability', '00000000-0000-4000-8000-000000000000'::uuid, 1, 50)`,
    ]
    for (const call of capabilityCalls) {
      let databaseError: { message?: string } | null = null
      try {
        await call()
      } catch (error) {
        databaseError = error as { message?: string }
      }
      assert.ok(databaseError, 'capability RPC must reject an invalid token')
      assert.match(
        databaseError.message ?? '',
        /MCP_(COLLECTION_)?CAPABILITY_INVALID/,
        'capability RPC must be reachable and fail closed',
      )
    }

    console.log(
      'MCP database smoke passed: dedicated login, direct table access denied, 9 capability RPCs reachable and fail-closed.',
    )
  } finally {
    await sql.end({ timeout: 1 })
  }
}

void main()
