import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import test from 'node:test'

function migration(path: string) {
  return readFileSync(join(process.cwd(), '..', '..', 'supabase', 'migrations', path), 'utf8')
}

test('trigger de transição de status é criado sobre projetos', () => {
  const sql = migration('20260712191500_projeto_status_transition_guard.sql')

  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.enforce_projeto_status_transition\(\)/)
  assert.match(sql, /BEFORE UPDATE OF status ON public\.projetos/)
  assert.match(sql, /DROP TRIGGER IF EXISTS trg_projeto_status_transition/)
})

test('versão vigente da função cobre a matriz completa, incluindo MONTAGEM', () => {
  // 20260805194500 faz CREATE OR REPLACE: é a definição que vale no banco.
  const sql = migration('20260805194500_projeto_status_montagem_transition.sql')

  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.enforce_projeto_status_transition\(\)/)

  // Toda origem da matriz precisa de um ramo explícito no CASE.
  for (const estado of ['PLANEJAMENTO', 'CONFIRMADO', 'MONTAGEM', 'EM_CAMPO', 'FINALIZADO', 'CANCELADO']) {
    assert.match(sql, new RegExp(`WHEN '${estado}' THEN`))
  }

  // CONFIRMADO alcança MONTAGEM, e MONTAGEM alcança EM_CAMPO (caminho do checkout).
  assert.match(sql, /WHEN 'CONFIRMADO' THEN\s+IF NEW\.status NOT IN \('MONTAGEM', 'EM_CAMPO', 'PLANEJAMENTO', 'CANCELADO'\)/)
  assert.match(sql, /WHEN 'MONTAGEM' THEN\s+IF NEW\.status NOT IN \('EM_CAMPO', 'CONFIRMADO', 'CANCELADO'\)/)

  // Estados terminais rejeitam qualquer transição.
  assert.match(sql, /FINALIZADO é terminal/)
  assert.match(sql, /CANCELADO é terminal/)

  // EM_CAMPO só sai pra FINALIZADO (caminho do check-in).
  assert.match(sql, /NEW\.status <> 'FINALIZADO'/)

  // Status igual passa sem exceção (UPDATE sem mudança de status não quebra).
  assert.match(sql, /IF OLD\.status = NEW\.status THEN\s+RETURN NEW;/)

  // Fail-closed: valor novo de enum sem ramo dá erro claro, não CASE_NOT_FOUND.
  assert.match(sql, /ELSE\s+RAISE EXCEPTION 'Status % sem ramo na matriz/)
})
