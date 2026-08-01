import 'server-only'
import { getVerifiedUser } from '@/lib/supabase-ssr'
import { supabaseAdmin } from '@/lib/supabase-server'
import { getTrainingTrack, type TrainingTrackId } from '@/lib/training-content'
import { normalizeCompletedChapterIds } from '@/lib/training-progress-core'

export type TrainingProgressState = {
  available: boolean
  completedChapterIds: string[]
  message: string | null
}

function isMissingTrainingProgress(error: { code?: string; message?: string } | null) {
  const message = error?.message?.toLowerCase() ?? ''
  return (
    error?.code === '42P01' || error?.code === 'PGRST205' || message.includes('training_progress')
  )
}

export async function loadTrainingProgress(
  trackId: TrainingTrackId,
): Promise<TrainingProgressState> {
  const user = await getVerifiedUser()
  if (!user) {
    return {
      available: false,
      completedChapterIds: [],
      message: 'Entre com um usuário real para salvar o progresso.',
    }
  }

  const { data, error } = await supabaseAdmin
    .from('training_progress')
    .select('chapter_id')
    .eq('user_id', user.id)
    .eq('track', trackId)

  if (error && isMissingTrainingProgress(error)) {
    return {
      available: false,
      completedChapterIds: [],
      message: 'Progresso aguardando a migration do hub.',
    }
  }
  if (error) throw new Error(`Falha ao carregar progresso do treinamento: ${error.message}`)

  return {
    available: true,
    completedChapterIds: normalizeCompletedChapterIds(
      getTrainingTrack(trackId).chapters,
      (data ?? []).map((row) => row.chapter_id as string),
    ),
    message: null,
  }
}
