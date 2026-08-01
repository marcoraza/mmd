import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { TrainingHubOverview } from '@/components/training/TrainingHubOverview'
import { loadTrainingProgress } from '@/lib/data/training-progress'

export const dynamic = 'force-dynamic'

export default async function TrainingHubPage() {
  const [web, ios] = await Promise.all([loadTrainingProgress('web'), loadTrainingProgress('ios')])

  return (
    <div style={{ position: 'relative', minHeight: '100dvh' }}>
      <Caustic orb3 />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          padding: 'clamp(20px, 3vw, 28px) clamp(18px, 4vw, 48px)',
        }}
      >
        <TopBar
          kicker="MMD Eventos"
          title="Treinamento"
          showSearch={false}
          showNotifications={false}
        />
        <TrainingHubOverview progress={{ web, ios }} />
      </div>
    </div>
  )
}
