'use server'

import { revalidatePath } from 'next/cache'
import { requireActionUser } from '@/lib/action-auth'
import { supabaseAdmin } from '@/lib/supabase-server'
import {
  isTrainingTrackId,
  trainingChapterExists,
  type TrainingTrackId,
} from '@/lib/training-content'

export type TrainingProgressActionResult = { ok: true } | { ok: false; error: string }

export async function setTrainingChapterComplete(
  rawTrack: string,
  chapterId: string,
  complete: boolean,
): Promise<TrainingProgressActionResult> {
  if (!isTrainingTrackId(rawTrack) || !trainingChapterExists(rawTrack, chapterId)) {
    return { ok: false, error: 'Capítulo de treinamento inválido.' }
  }

  const auth = await requireActionUser('viewer')
  if (!auth.ok) return auth
  if (!auth.data.userId) {
    return { ok: false, error: 'Entre com um usuário real para salvar o progresso.' }
  }

  const result = complete
    ? await supabaseAdmin.from('training_progress').upsert(
        {
          user_id: auth.data.userId,
          track: rawTrack,
          chapter_id: chapterId,
          completed_at: new Date().toISOString(),
        },
        { onConflict: 'user_id,track,chapter_id' },
      )
    : await supabaseAdmin
        .from('training_progress')
        .delete()
        .eq('user_id', auth.data.userId)
        .eq('track', rawTrack)
        .eq('chapter_id', chapterId)

  if (result.error) return { ok: false, error: result.error.message }
  revalidateTraining(rawTrack)
  return { ok: true }
}

function revalidateTraining(trackId: TrainingTrackId) {
  revalidatePath('/treinamento')
  revalidatePath(`/treinamento/${trackId}`)
}
