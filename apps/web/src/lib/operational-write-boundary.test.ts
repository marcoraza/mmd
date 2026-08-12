import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import test from 'node:test'

function actionSource(file: string) {
  return readFileSync(join(process.cwd(), 'src', 'lib', 'actions', file), 'utf8')
}

test('Web não mantém caller para RPCs legadas de movimento físico', () => {
  const source = actionSource('movimentacoes.ts')

  assert.doesNotMatch(
    source,
    /\b(?:checkout_projeto|checkout_projeto_com_override|checkin_projeto|resolver_retorno_pendencia)\b/,
  )
})

test('Web não altera EPC por PostgREST direto', () => {
  const source = actionSource('rfid.ts')

  assert.doesNotMatch(source, /\.update\(\{\s*tag_rfid\s*:/)
})
