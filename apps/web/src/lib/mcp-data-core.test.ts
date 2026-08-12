import assert from 'node:assert/strict'
import test from 'node:test'

import { mcpDatabaseConfiguration } from './mcp-data-core.ts'

test('MCP accepts only its dedicated Supabase database role', () => {
  assert.ok(
    mcpDatabaseConfiguration(
      'postgresql://mmd_mcp_executor.projectref:secret@aws-0-sa-east-1.pooler.supabase.com:6543/postgres',
      false,
      'https://projectref.supabase.co',
    ),
  )
  assert.equal(
    mcpDatabaseConfiguration(
      'postgresql://postgres.projectref:secret@aws-0-sa-east-1.pooler.supabase.com:6543/postgres',
      false,
      'https://projectref.supabase.co',
    ),
    null,
  )
  assert.equal(
    mcpDatabaseConfiguration(
      'postgresql://mmd_mcp_executor:secret@attacker.example:5432/postgres',
      false,
      'https://projectref.supabase.co',
    ),
    null,
  )
  assert.equal(
    mcpDatabaseConfiguration(
      'postgresql://mmd_mcp_executor.otherref:secret@aws-0-sa-east-1.pooler.supabase.com:6543/postgres',
      false,
      'https://projectref.supabase.co',
    ),
    null,
  )
})
