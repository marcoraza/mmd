export type ReadinessSatellite = {
  value: string | number
  label: string
  color?: string
}

export type DashboardHeroEvent = {
  projeto_id: string
  title_line1: string
  title_line2: string
  date: string
  venue: string
  items_count: number
  readiness: number
  items_to_check: number
  starts_at: string
  satellites: ReadinessSatellite[]
}

export type DashboardStatEntry = {
  label: string
  value: string
  color: string
  mono?: boolean
}

export type EventType = 'wedding' | 'show' | 'corporate' | 'feira' | 'default'
export type EventStatus = 'pronto' | 'a_verificar' | 'atrasado' | 'critico'

export type DashboardUpcomingEvent = {
  id: string
  title: string
  type: EventType
  date: string
  venue: string
  crew: number
  readiness: number
  items_count: number
  status: EventStatus
}

import { loadStockStats } from '@/lib/data/stock'

export type OperationalPulse = {
  technicians_in_field: number
  events_in_progress: number
  next_checkout_label: string
}

function formatPatrimonioCompact(v: number): string {
  if (v >= 1_000_000) return `R$ ${(v / 1_000_000).toFixed(1).replace('.', ',')}M`
  if (v >= 1_000) return `R$ ${Math.round(v / 1000)}k`
  return `R$ ${Math.round(v)}`
}

export type DashboardData = {
  greeting: string
  user: { nome: string; iniciais: string }
  hero_event: DashboardHeroEvent | null
  stat_strip: DashboardStatEntry[]
  upcoming_events: DashboardUpcomingEvent[]
  upcoming_scheduled: number
  notifications: number
  last_sync_at: string
  operational: OperationalPulse
}

function currentGreeting(): string {
  const h = new Date().getHours()
  if (h < 12) return 'Bom dia'
  if (h < 18) return 'Boa tarde'
  return 'Boa noite'
}

export async function loadDashboard(): Promise<DashboardData> {
  const stock = await loadStockStats()
  return {
    greeting: currentGreeting(),
    user: { nome: 'Marcelo', iniciais: 'MS' },
    hero_event: {
      projeto_id: 'proj-001',
      title_line1: 'Casamento',
      title_line2: 'Santos & Oliveira',
      date: '23.abr · 18h',
      venue: 'Jardim Botânico · SP',
      items_count: 214,
      readiness: 87,
      items_to_check: 28,
      starts_at: new Date(Date.now() + 2 * 24 * 3600 * 1000 + 14 * 3600 * 1000).toISOString(),
      satellites: [
        { value: 186, label: 'prontos', color: 'var(--accent-green)' },
        { value: 28, label: 'a verificar', color: 'var(--accent-amber)' },
        { value: 5, label: 'críticos', color: 'var(--accent-red)' },
      ],
    },
    stat_strip: [
      { label: 'Disponível', value: String(stock.disponivel), color: 'var(--accent-green)' },
      { label: 'Em campo', value: String(stock.em_campo), color: 'var(--accent-cyan)' },
      { label: 'Retornando', value: String(stock.retornando), color: 'var(--accent-violet)' },
      { label: 'Manutenção', value: String(stock.manutencao), color: 'var(--accent-amber)' },
      {
        label: 'Patrimônio',
        value: formatPatrimonioCompact(stock.patrimonio_total),
        color: 'var(--fg-0)',
        mono: true,
      },
    ],
    upcoming_events: [
      {
        id: 'evt-001',
        title: 'Santos & Oliveira',
        type: 'wedding',
        date: '23 ABR · 18H',
        venue: 'Jardim Botânico · SP',
        crew: 4,
        readiness: 87,
        items_count: 214,
        status: 'a_verificar',
      },
      {
        id: 'evt-002',
        title: 'Tech SP 2026',
        type: 'feira',
        date: '28 ABR · 09H',
        venue: 'Expo Center Norte',
        crew: 6,
        readiness: 62,
        items_count: 340,
        status: 'atrasado',
      },
      {
        id: 'evt-003',
        title: 'Banda Neon',
        type: 'show',
        date: '02 MAI · 21H',
        venue: 'Audio Club · SP',
        crew: 3,
        readiness: 100,
        items_count: 128,
        status: 'pronto',
      },
      {
        id: 'evt-004',
        title: 'ABC Anual',
        type: 'corporate',
        date: '05 MAI · 14H',
        venue: 'WTC Events',
        crew: 2,
        readiness: 45,
        items_count: 89,
        status: 'critico',
      },
      {
        id: 'evt-005',
        title: 'Lançamento Nova Linha',
        type: 'corporate',
        date: '12 MAI · 19H',
        venue: 'Rosewood SP',
        crew: 5,
        readiness: 78,
        items_count: 172,
        status: 'a_verificar',
      },
      {
        id: 'evt-006',
        title: 'Verão 2026',
        type: 'show',
        date: '18 MAI · 16H',
        venue: 'Parque Villa Lobos',
        crew: 8,
        readiness: 54,
        items_count: 420,
        status: 'atrasado',
      },
      {
        id: 'evt-007',
        title: 'Pereira & Lima',
        type: 'wedding',
        date: '25 MAI · 17H',
        venue: 'Fazenda 7 Lagoas',
        crew: 4,
        readiness: 100,
        items_count: 198,
        status: 'pronto',
      },
      {
        id: 'evt-008',
        title: 'Convenção Anual',
        type: 'corporate',
        date: '01 JUN · 08H',
        venue: 'Transamérica Expo',
        crew: 7,
        readiness: 32,
        items_count: 295,
        status: 'critico',
      },
    ],
    upcoming_scheduled: 8,
    notifications: 3,
    last_sync_at: new Date(Date.now() - 4 * 60 * 1000).toISOString(),
    operational: {
      technicians_in_field: 3,
      events_in_progress: 2,
      next_checkout_label: 'HOJE 14H',
    },
  }
}
