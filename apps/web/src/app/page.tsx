import { Suspense } from 'react'
import { Caustic } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'
import { CinematicHero } from '@/components/dashboard/CinematicHero'
import { StatStrip } from '@/components/dashboard/StatStrip'
import { UpcomingEventsRail } from '@/components/dashboard/UpcomingEventsRail'
import { MetadataFooter } from '@/components/dashboard/MetadataFooter'
import { DashboardSkeleton } from '@/components/dashboard/DashboardSkeleton'
import { loadDashboard } from '@/lib/data/dashboard'

async function DashboardContent() {
  const data = await loadDashboard()
  return (
    <>
      <TopBar
        kicker="MMD Eventos"
        title={
          <>
            <span style={{ fontWeight: 400 }}>{data.greeting},</span>{' '}
            <span style={{ fontWeight: 600 }}>{data.user.nome}</span>
            <span style={{ fontWeight: 400 }}>!</span>
          </>
        }
        notifications={data.notifications}
      />
      <CinematicHero event={data.hero_event} />
      <StatStrip entries={data.stat_strip} />
      <UpcomingEventsRail events={data.upcoming_events} scheduled={data.upcoming_scheduled} />
      <MetadataFooter operational={data.operational} />
    </>
  )
}

export default function DashboardPage() {
  return (
    <div style={{ position: 'relative', minHeight: '100dvh' }}>
      <Caustic orb3 />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          padding: 'clamp(20px, 3vw, 28px) clamp(20px, 4vw, 48px)',
        }}
      >
        <Suspense fallback={<DashboardSkeleton />}>
          <DashboardContent />
        </Suspense>
      </div>
    </div>
  )
}
