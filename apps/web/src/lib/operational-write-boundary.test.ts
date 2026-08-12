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

test('vínculo RFID só reutiliza a chave idempotente enquanto a intenção não muda', () => {
  const binder = readFileSync(join(process.cwd(), 'src/components/rfid/RfidTagBinder.tsx'), 'utf8')

  assert.match(binder, /setTag\(e\.target\.value\)\s+setBindRequestId\(null\)/)
  assert.match(
    binder,
    /if \(selectedId !== unit\.id\) \{\s+setSelectedId\(unit\.id\)\s+setBindRequestId\(null\)/,
  )
})
