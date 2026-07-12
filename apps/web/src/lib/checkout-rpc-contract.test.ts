import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import test from 'node:test'

function migration(path: string) {
  return readFileSync(join(process.cwd(), '..', '..', 'supabase', 'migrations', path), 'utf8')
}

test('rpc de checkout normal mantém lock, auditoria e atualização atômica', () => {
  const sql = migration('20260623081000_external_rental_coverage.sql')
  const badStatusCheck = sql.indexOf('IF v_bad_status_count > 0 THEN')
  const insertAudit = sql.indexOf('INSERT INTO movimentacoes')
  const updateSerials = sql.indexOf('UPDATE serial_numbers')
  const updateProject = sql.indexOf('UPDATE projetos')

  assert.match(sql, /CREATE OR REPLACE FUNCTION checkout_projeto\(/)
  assert.match(sql, /WHERE id = p_projeto_id\s+FOR UPDATE;/)
  assert.match(sql, /status <> 'DISPONIVEL'/)
  assert.match(
    sql,
    /INSERT INTO movimentacoes \(\s*serial_number_id, projeto_id, tipo,\s*status_anterior, status_novo, registrado_por, metodo_scan\s*\)/s,
  )
  assert.ok(badStatusCheck > 0)
  assert.ok(insertAudit > badStatusCheck)
  assert.ok(updateSerials > insertAudit)
  assert.ok(updateProject > updateSerials)
})

test('rpc de checkout com override audita motivo e mantém execução service_role', () => {
  const sql = migration('20260623083000_checkout_gate_override.sql')
  const checkOverride = sql.indexOf('FROM public.checkout_overrides co')
  const badStatusCheck = sql.indexOf('IF v_bad_status_count > 0 THEN')
  const insertAudit = sql.indexOf('INSERT INTO public.movimentacoes')
  const markOverride = sql.indexOf('SET executado_em = now()')

  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.checkout_projeto_com_override\(/)
  assert.match(sql, /WHERE id = p_projeto_id\s+FOR UPDATE;/)
  assert.match(sql, /Saída forçada por override auditado/)
  assert.ok(checkOverride > 0)
  assert.ok(badStatusCheck > checkOverride)
  assert.ok(insertAudit > badStatusCheck)
  assert.ok(markOverride > insertAudit)
  assert.match(
    sql,
    /REVOKE ALL ON FUNCTION public\.checkout_projeto\(uuid, public\.metodo_scan_enum, text\) FROM authenticated;/,
  )
  assert.match(
    sql,
    /GRANT EXECUTE ON FUNCTION public\.checkout_projeto\(uuid, public\.metodo_scan_enum, text\) TO service_role;/,
  )
  assert.match(
    sql,
    /REVOKE ALL PRIVILEGES ON TABLE public\.checkout_overrides FROM anon;/,
  )
  assert.match(
    sql,
    /GRANT SELECT, INSERT ON TABLE public\.checkout_overrides TO authenticated;/,
  )
  assert.match(
    sql,
    /GRANT SELECT, INSERT, UPDATE ON TABLE public\.checkout_overrides TO service_role;/,
  )
  assert.match(sql, /REVOKE ALL ON FUNCTION public\.checkout_projeto_com_override\(/)
  assert.match(sql, /GRANT EXECUTE ON FUNCTION public\.checkout_projeto_com_override\(/)
  assert.doesNotMatch(
    sql,
    /GRANT EXECUTE ON FUNCTION public\.checkout_projeto_com_override\([^;]+TO authenticated/s,
  )
})

test('rpc de retorno abre pendência sem baixa automática', () => {
  const sql = migration('20260623094805_return_pending_resolution.sql')
  const pendingInsert = sql.indexOf('INSERT INTO public.retorno_pendencias')
  const openPendingCheck = sql.indexOf("rp.status = 'ABERTA'")
  const projectFinalized = sql.indexOf("SET status = 'FINALIZADO'")

  assert.match(sql, /CREATE TABLE IF NOT EXISTS public\.retorno_pendencias/)
  assert.match(sql, /ALTER TABLE public\.retorno_pendencias ENABLE ROW LEVEL SECURITY;/)
  assert.match(
    sql,
    /REVOKE ALL PRIVILEGES ON TABLE public\.retorno_pendencias FROM anon;/,
  )
  assert.match(
    sql,
    /GRANT SELECT, INSERT, UPDATE ON TABLE public\.retorno_pendencias TO authenticated;/,
  )
  assert.match(
    sql,
    /GRANT SELECT, INSERT, UPDATE ON TABLE public\.retorno_pendencias TO service_role;/,
  )
  assert.match(sql, /WHEN parsed\.resultado = 'NAO_VOLTOU' THEN 'RETORNANDO'/)
  assert.doesNotMatch(sql, /WHEN parsed\.resultado = 'NAO_VOLTOU' THEN 'BAIXA'/)
  assert.ok(pendingInsert > 0)
  assert.ok(openPendingCheck > pendingInsert)
  assert.ok(projectFinalized > openPendingCheck)
  assert.match(
    sql,
    /REVOKE ALL ON FUNCTION public\.checkin_projeto\(uuid, public\.metodo_scan_enum, text, jsonb\) FROM authenticated;/,
  )
  assert.match(
    sql,
    /GRANT EXECUTE ON FUNCTION public\.checkin_projeto\(uuid, public\.metodo_scan_enum, text, jsonb\) TO service_role;/,
  )
})

test('rpc de resolução cobre encontrada, manutenção, baixa e cobrança textual', () => {
  const sql = migration('20260623094805_return_pending_resolution.sql')

  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.resolver_retorno_pendencia\(/)
  assert.match(sql, /v_acao NOT IN \('ENCONTRADA', 'MANUTENCAO', 'BAIXA', 'COBRANCA'\)/)
  assert.match(sql, /v_status_novo := 'DISPONIVEL';/)
  assert.match(sql, /v_status_novo := 'MANUTENCAO';/)
  assert.match(sql, /v_status_novo := 'BAIXA';/)
  assert.match(sql, /v_status_novo := v_status_anterior;/)
  assert.match(sql, /Pendência resolvida com nota de cobrança/)
  assert.match(
    sql,
    /REVOKE ALL ON FUNCTION public\.resolver_retorno_pendencia\(uuid, text, text, text\) FROM authenticated;/,
  )
  assert.match(
    sql,
    /GRANT EXECUTE ON FUNCTION public\.resolver_retorno_pendencia\(uuid, text, text, text\) TO service_role;/,
  )
})
