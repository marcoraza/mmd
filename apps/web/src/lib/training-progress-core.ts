import type { TrainingChapter } from './training-content'

export function normalizeCompletedChapterIds(chapters: TrainingChapter[], values: string[]) {
  const validIds = new Set(chapters.map((chapter) => chapter.id))
  return [...new Set(values.filter((value) => validIds.has(value)))]
}

export function calculateTrainingProgress(chapters: TrainingChapter[], completedIds: string[]) {
  const completed = normalizeCompletedChapterIds(chapters, completedIds).length
  const total = chapters.length
  return {
    completed,
    total,
    percent: total === 0 ? 0 : Math.round((completed / total) * 100),
    isComplete: total > 0 && completed === total,
  }
}
