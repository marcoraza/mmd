import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import test from 'node:test'

function migration(path: string) {
  return readFileSync(join(process.cwd(), '..', '..', 'supabase', 'migrations', path), 'utf8')
}

test('saída física usa Conferência autenticada, atômica e sem atalho service_role', () => {
  const sql = migration('20260812163652_rfid_epc_operations_implementation.sql')

  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.confirmar_conferencia_saida\(/)
  assert.match(sql, /pg_advisory_xact_lock\(/)
  assert.match(sql, /IDEMPOTENCY_KEY_CONFLICT/)
  assert.match(sql, /v_existing\.actor_id <> v_actor_id/)
  assert.match(sql, /REVOKE ALL ON FUNCTION public\.confirmar_conferencia_saida\([^;]+FROM PUBLIC, anon, service_role/s)
  assert.match(sql, /GRANT EXECUTE ON FUNCTION public\.confirmar_conferencia_saida\([^;]+TO authenticated/s)
})

test('retorno e pendência usam Confirmação e ACK próprios', () => {
  const sql = migration('20260812162010_return_conference_idempotency.sql')
  const actorScope = migration('20260812163444_conference_idempotency_actor_scope.sql')

  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.confirmar_conferencia_retorno\(/)
  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.resolver_pendencia_retorno\(/)
  assert.match(sql, /INSERT INTO public\.retorno_pendencias/)
  assert.match(sql, /ELSE 'RETORNANDO'/)
  assert.match(sql, /REVOKE ALL ON FUNCTION public\.confirmar_conferencia_retorno\([^;]+FROM PUBLIC, anon, service_role/s)
  assert.match(sql, /REVOKE ALL ON FUNCTION public\.resolver_pendencia_retorno\([^;]+FROM PUBLIC, anon, service_role/s)
  assert.match(actorScope, /v_existing\.actor_id <> v_actor_id/)
  assert.match(actorScope, /Baixa e cobrança exigem usuário admin/)
})

test('ações Web de estoque param no boundary de Conferência', () => {
  const source = readFileSync(join(process.cwd(), 'src', 'lib', 'actions', 'movimentacoes.ts'), 'utf8')

  assert.match(source, /Movimento físico exige Conferência no app operacional/)
  assert.doesNotMatch(source, /\.rpc\(/)
  assert.doesNotMatch(source, /supabaseAdmin/)
})
