import assert from 'node:assert/strict'
import test from 'node:test'

import {
  isAuthRequiredForEnv,
  isProtectedInternalPath,
  isPublicRoute,
  loginRedirectPath,
  normalizeLoginIdentifier,
  sanitizeNextPath,
} from './auth-config.ts'

test('isProtectedInternalPath protects internal surfaces and leaves public QR/login out', () => {
  assert.equal(isProtectedInternalPath('/'), true)
  assert.equal(isProtectedInternalPath('/items'), true)
  assert.equal(isProtectedInternalPath('/items/abc'), true)
  assert.equal(isProtectedInternalPath('/qrcodes'), true)
  assert.equal(isProtectedInternalPath('/treinamento'), true)
  assert.equal(isProtectedInternalPath('/treinamento/ios'), true)
  assert.equal(isProtectedInternalPath('/s/MMD-ILU-0001'), false)
  assert.equal(isProtectedInternalPath('/login'), false)
})

test('isPublicRoute recognizes only login and public QR routes', () => {
  assert.equal(isPublicRoute('/login'), true)
  assert.equal(isPublicRoute('/s/MMD-ILU-0001'), true)
  assert.equal(isPublicRoute('/qrcodes'), false)
})

test('isAuthRequiredForEnv follows explicit flag before data mode', () => {
  assert.equal(isAuthRequiredForEnv({ MMD_REQUIRE_AUTH: 'true', MMD_DATA_MODE: 'demo' }), true)
  assert.equal(isAuthRequiredForEnv({ MMD_REQUIRE_AUTH: 'false', MMD_DATA_MODE: 'real' }), false)
  assert.equal(isAuthRequiredForEnv({ MMD_DATA_MODE: 'real' }), true)
  assert.equal(isAuthRequiredForEnv({ MMD_DATA_MODE: 'demo' }), false)
})

test('sanitizeNextPath prevents open redirects and public loops', () => {
  assert.equal(sanitizeNextPath('/items'), '/items')
  assert.equal(sanitizeNextPath('//evil.test'), '/')
  assert.equal(sanitizeNextPath('https://evil.test'), '/')
  assert.equal(sanitizeNextPath('/login?next=/items'), '/')
  assert.equal(sanitizeNextPath('/s/MMD-ILU-0001'), '/')
})

test('loginRedirectPath preserves safe internal target', () => {
  assert.equal(
    loginRedirectPath('/items', '?categoria=CABO'),
    '/login?next=%2Fitems%3Fcategoria%3DCABO',
  )
})

test('normalizeLoginIdentifier accepts MMD username aliases', () => {
  assert.equal(normalizeLoginIdentifier(' supervisor '), 'supervisor@mmd.local')
  assert.equal(normalizeLoginIdentifier('MARCELO@MMD.COM'), 'marcelo@mmd.com')
  assert.equal(normalizeLoginIdentifier(''), '')
})
