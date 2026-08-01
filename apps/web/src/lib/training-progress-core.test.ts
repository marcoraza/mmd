import assert from 'node:assert/strict'
import test from 'node:test'

import {
  calculateTrainingProgress,
  normalizeCompletedChapterIds,
} from './training-progress-core.ts'
import type { TrainingChapter } from './training-content.ts'

const chapters: TrainingChapter[] = [
  {
    id: 'primeiro',
    title: 'Primeiro',
    summary: 'Primeiro passo.',
    steps: ['Executar'],
    result: 'Executado',
  },
  {
    id: 'segundo',
    title: 'Segundo',
    summary: 'Segundo passo.',
    steps: ['Conferir'],
    result: 'Conferido',
  },
]

test('normalizeCompletedChapterIds removes ids from another track', () => {
  assert.deepEqual(
    normalizeCompletedChapterIds(chapters, ['primeiro', 'inexistente']),
    ['primeiro'],
  )
})

test('normalizeCompletedChapterIds removes duplicate completions', () => {
  assert.deepEqual(normalizeCompletedChapterIds(chapters, ['primeiro', 'primeiro']), ['primeiro'])
})

test('calculateTrainingProgress reports count, rounded percent and completion', () => {
  assert.deepEqual(calculateTrainingProgress(chapters, ['primeiro']), {
    completed: 1,
    total: 2,
    percent: 50,
    isComplete: false,
  })
  assert.equal(calculateTrainingProgress(chapters, ['primeiro', 'segundo']).isComplete, true)
})

test('calculateTrainingProgress keeps an empty track at zero', () => {
  assert.deepEqual(calculateTrainingProgress([], []), {
    completed: 0,
    total: 0,
    percent: 0,
    isComplete: false,
  })
})
