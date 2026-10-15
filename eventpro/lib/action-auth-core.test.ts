import assert from 'node:assert/strict'
import test from 'node:test'

import {
  actionDeniedMessage,
  extractBearerToken,
  normalizeUserRole,
  operatorLabel,
  roleAllows,
} from './action-auth-core.ts'

test('normalizeUserRole falls back to viewer for unknown roles', () => {
  assert.equal(normalizeUserRole('admin'), 'admin')
  assert.equal(normalizeUserRole('editor'), 'editor')
  assert.equal(normalizeUserRole('viewer'), 'viewer')
  assert.equal(normalizeUserRole('owner'), 'viewer')
  assert.equal(normalizeUserRole(null), 'viewer')
})

test('roleAllows applies the MMD write hierarchy', () => {
  assert.equal(roleAllows('admin', 'editor'), true)
  assert.equal(roleAllows('editor', 'viewer'), true)
  assert.equal(roleAllows('viewer', 'editor'), false)
  assert.equal(roleAllows('editor', 'admin'), false)
})

test('operatorLabel prefers profile name then email then stable fallback', () => {
  assert.equal(
    operatorLabel({ nome: ' Marcelo Santos ', email: 'marcelo@mmd.test' }),
    'Marcelo Santos',
  )
  assert.equal(operatorLabel({ email: ' equipe@mmd.test ' }), 'equipe@mmd.test')
  assert.equal(operatorLabel({ fallbackId: 'user-1' }), 'user-1')
  assert.equal(operatorLabel({}), 'Usuário MMD')
})

test('actionDeniedMessage uses product language', () => {
  assert.equal(actionDeniedMessage('admin'), 'Ação restrita ao usuário admin.')
  assert.equal(actionDeniedMessage('editor'), 'Ação restrita à equipe operacional.')
  assert.equal(actionDeniedMessage('viewer'), 'Acesso interno: faça login novamente.')
})

test('extractBearerToken accepts only Authorization bearer tokens', () => {
  assert.equal(extractBearerToken('Bearer user-token'), 'user-token')
  assert.equal(extractBearerToken('bearer user-token'), 'user-token')
  assert.equal(extractBearerToken('Basic user-token'), null)
  assert.equal(extractBearerToken('Bearer '), null)
  assert.equal(extractBearerToken(null), null)
})
