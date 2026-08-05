import assert from 'node:assert/strict'
import test from 'node:test'
import {
  INTERNAL_QR_LOOKUP_FIELDS,
  isInternalQrLookupField,
  normalizeInternalQrLookupCode,
} from './internal-qr-core.ts'

test('normalizeInternalQrLookupCode accepts public QR codes', () => {
  assert.equal(normalizeInternalQrLookupCode(' MMD-ILU-0001 '), 'MMD-ILU-0001')
  assert.equal(normalizeInternalQrLookupCode('MMD%2DILU%2D0001'), 'MMD-ILU-0001')
})

test('normalizeInternalQrLookupCode rejects filter-shaped input', () => {
  assert.equal(normalizeInternalQrLookupCode('MMD-ILU-0001,tag_rfid.eq.SECRET'), null)
  assert.equal(normalizeInternalQrLookupCode('MMD-ILU-0001(or(tag.eq.SECRET))'), null)
})

test('internal QR lookup fields do not include RFID tag', () => {
  assert.deepEqual(INTERNAL_QR_LOOKUP_FIELDS, ['codigo_interno', 'qr_code'])
  assert.equal(isInternalQrLookupField('codigo_interno'), true)
  assert.equal(isInternalQrLookupField('qr_code'), true)
  assert.equal(isInternalQrLookupField('tag_rfid'), false)
})
