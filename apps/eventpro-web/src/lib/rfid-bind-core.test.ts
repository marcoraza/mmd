import assert from 'node:assert/strict'
import test from 'node:test'

import { tagAlreadyBoundError, validateRfidTag } from './rfid-bind-core.ts'
import { normalizeRfidTag } from './rfid-scan-core.ts'

test('validateRfidTag normaliza igual ao caminho de leitura', () => {
  const result = validateRfidTag(' e280-1170:0000 020d1a2b3c4d ')
  assert.equal(result.ok, true)
  assert.equal(result.ok && result.tag, 'E28011700000020D1A2B3C4D')
  // Mesma normalização de /api/rfid/scans: sem isso a tag gravada não casaria
  // com a tag lida (divergência D2).
  assert.equal(result.ok && result.tag, normalizeRfidTag(' e280-1170:0000 020d1a2b3c4d '))
})

test('validateRfidTag recusa tag curta, longa ou com caractere fora do EPC', () => {
  assert.deepEqual(validateRfidTag('ABC'), { ok: false, error: 'RFID curto demais.' })
  assert.deepEqual(validateRfidTag('A'.repeat(97)), { ok: false, error: 'RFID longo demais.' })
  assert.deepEqual(validateRfidTag('E2801170#000020D'), {
    ok: false,
    error: 'RFID deve conter apenas letras e números.',
  })
  assert.deepEqual(validateRfidTag(null), { ok: false, error: 'RFID curto demais.' })
})

test('mensagem de tag duplicada aponta a unidade que já usa a etiqueta', () => {
  assert.equal(tagAlreadyBoundError('MMD-ILU-0001'), 'RFID já vinculado à unidade MMD-ILU-0001.')
})
