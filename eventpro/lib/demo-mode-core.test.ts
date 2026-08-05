import assert from 'node:assert/strict'
import test from 'node:test'

import { envFlag, resolveDataMode } from './demo-mode-core.ts'

test('resolveDataMode respects explicit data mode', () => {
  assert.equal(resolveDataMode({ VERCEL: '1', MMD_DATA_MODE: 'demo' }), 'demo')
  assert.equal(resolveDataMode({ NODE_ENV: 'production', MMD_DATA_MODE: 'auto' }), 'auto')
  assert.equal(resolveDataMode({ NEXT_PUBLIC_MMD_DATA_MODE: 'real' }), 'real')
})

test('resolveDataMode never defaults production or Vercel to demo', () => {
  assert.equal(resolveDataMode({ VERCEL: '1' }), 'real')
  assert.equal(resolveDataMode({ NODE_ENV: 'production' }), 'real')
  assert.equal(resolveDataMode({ VERCEL: '1', NODE_ENV: 'production' }), 'real')
})

test('resolveDataMode keeps local development fallback automatic', () => {
  assert.equal(resolveDataMode({}), 'auto')
  assert.equal(resolveDataMode({ NODE_ENV: 'development' }), 'auto')
})

test('resolveDataMode preserves legacy explicit fallback flags', () => {
  assert.equal(resolveDataMode({ VERCEL: '1', MMD_DEMO_FALLBACK: 'true' }), 'auto')
  assert.equal(resolveDataMode({ VERCEL: '1', MMD_DEMO_FALLBACK: 'false' }), 'real')
})

test('envFlag parses boolean-like values', () => {
  assert.equal(envFlag(' yes '), true)
  assert.equal(envFlag('OFF'), false)
  assert.equal(envFlag('maybe'), null)
})
