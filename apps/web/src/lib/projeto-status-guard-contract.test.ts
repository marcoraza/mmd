import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import test from 'node:test'

function migration(path: string) {
  return readFileSync(join(process.cwd(), '..', '..', 'supabase', 'migrations', path), 'utf8')
}

test('trigger de transição de status cobre a matriz completa de estados', () => {
  const sql = migration('20260712191500_projeto_status_transition_guard.sql')

  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.enforce_projeto_status_transition\(\)/)
  assert.match(sql, /BEFORE UPDATE OF status ON public\.projetos/)
  assert.match(sql, /DROP TRIGGER IF EXISTS trg_projeto_status_transition/)

  // Toda origem da matriz precisa de um ramo explícito no CASE.
  for (const estado of ['PLANEJAMENTO', 'CONFIRMADO', 'EM_CAMPO', 'FINALIZADO', 'CANCELADO']) {
    assert.match(sql, new RegExp(`WHEN '${estado}' THEN`))
  }

  // Estados terminais rejeitam qualquer transição.
  assert.match(sql, /FINALIZADO é terminal/)
  assert.match(sql, /CANCELADO é terminal/)

  // EM_CAMPO só sai pra FINALIZADO (caminho do check-in).
  assert.match(sql, /NEW\.status <> 'FINALIZADO'/)

  // Status igual passa sem exceção (UPDATE sem mudança de status não quebra).
  assert.match(sql, /IF OLD\.status = NEW\.status THEN\s+RETURN NEW;/)
})
