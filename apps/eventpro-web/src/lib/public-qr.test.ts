import assert from 'node:assert/strict'
import test from 'node:test'

import {
  containsPublicQrForbiddenLabel,
  getPublicQrContact,
  normalizePublicLookupCode,
  serialStatusToPublicStatus,
} from './public-qr.ts'

test('normalizePublicLookupCode accepts only simple public codes', () => {
  assert.equal(normalizePublicLookupCode(' MMD-ILU-0065 '), 'MMD-ILU-0065')
  assert.equal(normalizePublicLookupCode('MMD%2DILU%2D0065'), 'MMD-ILU-0065')
  assert.equal(normalizePublicLookupCode('MMD-ILU-0065,tag_rfid.eq.SECRET'), null)
  assert.equal(normalizePublicLookupCode('MMD-ILU-0065()'), null)
})

test('serialStatusToPublicStatus hides internal operational detail', () => {
  assert.equal(serialStatusToPublicStatus('DISPONIVEL'), 'Ativo')
  assert.equal(serialStatusToPublicStatus('PACKED'), 'Ativo')
  assert.equal(serialStatusToPublicStatus('EM_CAMPO'), 'Em uso')
  assert.equal(serialStatusToPublicStatus('RETORNANDO'), 'Em uso')
  assert.equal(serialStatusToPublicStatus('MANUTENCAO'), 'Indisponível')
  assert.equal(serialStatusToPublicStatus('BAIXA'), 'Falar com EventPro')
})

test('public QR forbidden labels catch sensitive copy', () => {
  assert.equal(containsPublicQrForbiddenLabel('Categoria Iluminação'), false)
  assert.equal(containsPublicQrForbiddenLabel('Valor atual R$ 875,00'), true)
  assert.equal(containsPublicQrForbiddenLabel('Serial fábrica ABC'), true)
  assert.equal(containsPublicQrForbiddenLabel('Localização Galpão 1'), true)
})

test('getPublicQrContact keeps missing contact explicit without inventing data', () => {
  assert.deepEqual(getPublicQrContact({}), {
    whatsappUrl: null,
    phone: null,
    hasDirectContact: false,
  })
  assert.deepEqual(getPublicQrContact({ NEXT_PUBLIC_EVENTPRO_PHONE: '+5511999999999' }), {
    whatsappUrl: null,
    phone: '+5511999999999',
    hasDirectContact: true,
  })
})
