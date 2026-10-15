import assert from 'node:assert/strict'
import test from 'node:test'

import {
  isAuthRequiredForEnv,
  isDevAuthBypassEnabled,
  isProtectedInternalPath,
  isPublicRoute,
  loginRedirectPath,
  normalizeLoginIdentifier,
  sanitizeNextPath,
} from './auth-config.ts'

test('isProtectedInternalPath protects internal surfaces and leaves public QR/login out', () => {
  assert.equal(isProtectedInternalPath('/'), true)
  assert.equal(isProtectedInternalPath('/s/MMD-ILU-0001'), false)
  assert.equal(isProtectedInternalPath('/login'), false)
})

test('isPublicRoute recognizes only login and public QR routes', () => {
  assert.equal(isPublicRoute('/login'), true)
  assert.equal(isPublicRoute('/s/MMD-ILU-0001'), true)
  assert.equal(isPublicRoute('/qrcodes'), false)
})

// Risco 5.2 da auditoria: no legado bastava uma variável de ambiente ausente
// para a API devolver admin sem login. Aqui auth é sempre exigida.
test('isAuthRequiredForEnv exige auth em qualquer ambiente por padrão', () => {
  assert.equal(isAuthRequiredForEnv({}), true)
  assert.equal(isAuthRequiredForEnv({ NODE_ENV: 'production' }), true)
  assert.equal(isAuthRequiredForEnv({ NODE_ENV: 'test' }), true)
  assert.equal(isAuthRequiredForEnv({ NODE_ENV: 'development' }), true)
})

test('isAuthRequiredForEnv só afrouxa com bypass explícito em desenvolvimento', () => {
  assert.equal(
    isAuthRequiredForEnv({ NODE_ENV: 'development', EVENTPRO_DEV_BYPASS_AUTH: 'true' }),
    false,
  )
  // Produção e staging não conseguem ligar o bypass nem com a flag presente.
  assert.equal(
    isAuthRequiredForEnv({ NODE_ENV: 'production', EVENTPRO_DEV_BYPASS_AUTH: 'true' }),
    true,
  )
  assert.equal(isAuthRequiredForEnv({ EVENTPRO_DEV_BYPASS_AUTH: 'true' }), true)
  // Flag presente mas desligada continua exigindo auth.
  assert.equal(
    isAuthRequiredForEnv({ NODE_ENV: 'development', EVENTPRO_DEV_BYPASS_AUTH: 'false' }),
    true,
  )
})

test('isDevAuthBypassEnabled é o espelho positivo da regra de bypass', () => {
  assert.equal(
    isDevAuthBypassEnabled({ NODE_ENV: 'development', EVENTPRO_DEV_BYPASS_AUTH: '1' }),
    true,
  )
  assert.equal(isDevAuthBypassEnabled({ NODE_ENV: 'development' }), false)
  assert.equal(
    isDevAuthBypassEnabled({ NODE_ENV: 'production', EVENTPRO_DEV_BYPASS_AUTH: '1' }),
    false,
  )
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

test('normalizeLoginIdentifier accepts EventPro username aliases', () => {
  assert.equal(normalizeLoginIdentifier(' supervisor '), 'supervisor@eventpro.local')
  assert.equal(normalizeLoginIdentifier('MARCELO@MMD.COM'), 'marcelo@mmd.com')
  assert.equal(normalizeLoginIdentifier(''), '')
  assert.equal(normalizeLoginIdentifier('supervisor', 'mmd.local'), 'supervisor@mmd.local')
})
