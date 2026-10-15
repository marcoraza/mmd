import assert from 'node:assert/strict'
import test from 'node:test'

import { envFlag } from './env-flag.ts'

test('envFlag parses boolean-like values', () => {
  assert.equal(envFlag(' yes '), true)
  assert.equal(envFlag('OFF'), false)
  assert.equal(envFlag('maybe'), null)
})

test('envFlag treats absent and empty values as unset', () => {
  assert.equal(envFlag(undefined), null)
  assert.equal(envFlag(''), null)
})

test('envFlag accepts the full truthy and falsy vocabulary', () => {
  for (const raw of ['1', 'true', 'yes', 'on', 'TRUE', ' On ']) {
    assert.equal(envFlag(raw), true, `esperado true para ${raw}`)
  }
  for (const raw of ['0', 'false', 'no', 'off', 'FALSE', ' Off ']) {
    assert.equal(envFlag(raw), false, `esperado false para ${raw}`)
  }
})
