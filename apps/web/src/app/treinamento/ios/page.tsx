import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { TrainingTrackView } from '@/components/training/TrainingTrackView'
import { loadTrainingProgress } from '@/lib/data/training-progress'
import { getTrainingTrack } from '@/lib/training-content'

export const dynamic = 'force-dynamic'

export default async function IosTrainingPage() {
  const progress = await loadTrainingProgress('ios')
  return (
    <div style={{ position: 'relative', minHeight: '100dvh' }}>
      <Caustic />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          padding: 'clamp(20px, 3vw, 28px) clamp(18px, 4vw, 48px)',
        }}
      >
        <TopBar
          kicker="Treinamento"
          title="Trilha iOS"
          showSearch={false}
          showNotifications={false}
        />
        <TrainingTrackView track={getTrainingTrack('ios')} progress={progress} />
      </div>
    </div>
  )
}
