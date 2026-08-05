import type { Categoria } from './types'

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

export type DashboardCategoryUsage = {
  categoria: Categoria
  label: string
  required: number
  covered: number
  readiness: number
  color: string
}

export type DashboardMaintenanceSignal = {
  id: 'manutencao' | 'retornando' | 'criticos' | 'perdas'
  label: string
  value: number
  detail: string
  color: string
}

export type OperationalPulse = {
  technicians_in_field: number
  events_in_progress: number
  next_checkout_label: string
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
  category_usage: DashboardCategoryUsage[]
  maintenance_signals: DashboardMaintenanceSignal[]
}

export type DashboardStockSource = {
  disponivel: number
  em_campo: number
  retornando: number
  manutencao: number
  criticos: number
  patrimonio_total: number
  baixas?: number
  vendidos?: number
}

export type DashboardPackingSource = {
  id: string
  item_nome: string
  categoria: Categoria
  qtd_necessaria: number
  qtd_alocada: number
  qtd_alugada_avulsa: number
  qtd_coberta: number
  qtd_faltante: number
  conflicts_count?: number
}

export type DashboardProjectSource = {
  id: string
  nome: string
  cliente: string | null
  data_inicio: string
  data_fim: string
  local: string | null
  status: 'PLANEJAMENTO' | 'CONFIRMADO' | 'MONTAGEM' | 'EM_CAMPO' | 'FINALIZADO' | 'CANCELADO'
  packing: DashboardPackingSource[]
  readiness_pct: number
  gate_readiness_pct?: number
  gate_blockers_count?: number
  open_return_pendings?: number
}

export type BuildDashboardInput = {
  stock: DashboardStockSource
  projects: DashboardProjectSource[]
  now?: Date
  user?: { nome: string; iniciais: string }
}

const CATEGORY_LABEL: Record<Categoria, string> = {
  ILUMINACAO: 'Iluminação',
  AUDIO: 'Áudio',
  CABO: 'Cabos',
  ENERGIA: 'Energia',
  ESTRUTURA: 'Estrutura',
  EFEITO: 'Efeito',
  VIDEO: 'Vídeo',
  ACESSORIO: 'Acessório',
}

const CATEGORY_COLOR: Record<Categoria, string> = {
  ILUMINACAO: 'var(--accent-cyan)',
  AUDIO: 'var(--accent-green)',
  CABO: 'var(--accent-amber)',
  ENERGIA: 'var(--accent-violet)',
  ESTRUTURA: 'var(--fg-1)',
  EFEITO: 'var(--accent-red)',
  VIDEO: 'var(--accent-cyan)',
  ACESSORIO: 'var(--fg-2)',
}

const ACTIVE_PROJECT_STATUS: DashboardProjectSource['status'][] = [
  'PLANEJAMENTO',
  'CONFIRMADO',
  'MONTAGEM',
  'EM_CAMPO',
]

function currentGreeting(now: Date): string {
  const h = now.getHours()
  if (h < 12) return 'Bom dia'
  if (h < 18) return 'Boa tarde'
  return 'Boa noite'
}

function formatPatrimonioCompact(v: number): string {
  if (v >= 1_000_000) return `R$ ${(v / 1_000_000).toFixed(1).replace('.', ',')}M`
  if (v >= 1_000) return `R$ ${Math.round(v / 1000)}k`
  return `R$ ${Math.round(v)}`
}

function clampPct(value: number): number {
  if (!Number.isFinite(value)) return 0
  return Math.max(0, Math.min(100, Math.round(value)))
}

function projectReadiness(project: DashboardProjectSource): number {
  const base = clampPct(project.gate_readiness_pct ?? project.readiness_pct)
  if ((project.open_return_pendings ?? 0) > 0) return Math.min(base, 50)
  return base
}

function eventStatus(project: DashboardProjectSource, readiness: number): EventStatus {
  if ((project.open_return_pendings ?? 0) > 0) return 'critico'
  if (readiness >= 100 && (project.gate_blockers_count ?? 0) === 0) return 'pronto'
  if (readiness < 40) return 'critico'
  if (readiness < 70) return 'atrasado'
  return 'a_verificar'
}

function detectEventType(project: DashboardProjectSource): EventType {
  const haystack = `${project.nome} ${project.cliente ?? ''}`.toLowerCase()
  if (haystack.includes('casamento')) return 'wedding'
  if (haystack.includes('show') || haystack.includes('banda') || haystack.includes('festival')) {
    return 'show'
  }
  if (haystack.includes('feira') || haystack.includes('expo')) return 'feira'
  if (
    haystack.includes('corporativo') ||
    haystack.includes('convenção') ||
    haystack.includes('congresso')
  ) {
    return 'corporate'
  }
  return 'default'
}

function parseDate(value: string): Date {
  const dateOnly = value.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (dateOnly) {
    const [, year, month, day] = dateOnly
    return new Date(Number(year), Number(month) - 1, Number(day))
  }

  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? new Date(0) : date
}

function formatEventDate(value: string): string {
  const date = parseDate(value)
  const dayMonth = new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: 'short',
  })
    .format(date)
    .replace('.', '')
    .toUpperCase()

  if (!value.includes('T')) return dayMonth

  const hour = new Intl.DateTimeFormat('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(date)

  return `${dayMonth} · ${hour}`
}

function splitHeroTitle(
  project: DashboardProjectSource,
): Pick<DashboardHeroEvent, 'title_line1' | 'title_line2'> {
  const name = project.nome.trim()
  const lower = name.toLowerCase()
  for (const prefix of ['casamento', 'show', 'feira', 'convenção', 'evento']) {
    if (lower.startsWith(prefix)) {
      return {
        title_line1: name.slice(0, prefix.length),
        title_line2: name.slice(prefix.length).trim() || project.cliente || name,
      }
    }
  }

  return {
    title_line1: name,
    title_line2: project.cliente?.trim() || project.local?.trim() || 'Evento EventPro',
  }
}

function orderedOperationalProjects(projects: DashboardProjectSource[], now: Date) {
  const today = new Date(now)
  today.setHours(0, 0, 0, 0)

  return projects
    .filter((project) => ACTIVE_PROJECT_STATUS.includes(project.status))
    .sort((a, b) => {
      const aDate = parseDate(a.data_inicio)
      const bDate = parseDate(b.data_inicio)
      const aFuture = aDate >= today
      const bFuture = bDate >= today
      if (aFuture !== bFuture) return aFuture ? -1 : 1
      return aDate.getTime() - bDate.getTime()
    })
}

function buildHeroEvent(project: DashboardProjectSource): DashboardHeroEvent {
  const readiness = projectReadiness(project)
  const qtdNecessaria = project.packing.reduce((acc, line) => acc + line.qtd_necessaria, 0)
  const qtdCoberta = project.packing.reduce((acc, line) => acc + line.qtd_coberta, 0)
  const qtdFaltante = project.packing.reduce((acc, line) => acc + line.qtd_faltante, 0)
  const conflicts = project.packing.reduce((acc, line) => acc + (line.conflicts_count ?? 0), 0)
  const pendings = project.open_return_pendings ?? 0
  const titles = splitHeroTitle(project)

  return {
    projeto_id: project.id,
    ...titles,
    date: formatEventDate(project.data_inicio),
    venue: project.local ?? 'Local a confirmar',
    items_count: qtdNecessaria,
    readiness,
    items_to_check: qtdFaltante + conflicts + pendings + (project.gate_blockers_count ?? 0),
    starts_at: parseDate(project.data_inicio).toISOString(),
    satellites: [
      { value: qtdCoberta, label: 'cobertos', color: 'var(--accent-green)' },
      { value: qtdFaltante, label: 'faltando', color: 'var(--accent-amber)' },
      { value: conflicts + pendings, label: 'pendentes', color: 'var(--accent-red)' },
    ],
  }
}

function buildUpcomingEvents(projects: DashboardProjectSource[]): DashboardUpcomingEvent[] {
  return projects.slice(0, 8).map((project) => {
    const readiness = projectReadiness(project)
    const needed = project.packing.reduce((acc, line) => acc + line.qtd_necessaria, 0)
    return {
      id: project.id,
      title: project.nome,
      type: detectEventType(project),
      date: formatEventDate(project.data_inicio),
      venue: project.local ?? 'Local a confirmar',
      crew: Math.max(1, Math.ceil(needed / 60)),
      readiness,
      items_count: needed,
      status: eventStatus(project, readiness),
    }
  })
}

function buildCategoryUsage(projects: DashboardProjectSource[]): DashboardCategoryUsage[] {
  const rows = new Map<Categoria, { required: number; covered: number }>()

  for (const project of projects) {
    for (const line of project.packing) {
      const row = rows.get(line.categoria) ?? { required: 0, covered: 0 }
      row.required += line.qtd_necessaria
      row.covered += line.qtd_coberta
      rows.set(line.categoria, row)
    }
  }

  return [...rows.entries()]
    .map(([categoria, row]) => ({
      categoria,
      label: CATEGORY_LABEL[categoria],
      required: row.required,
      covered: row.covered,
      readiness: row.required > 0 ? clampPct((row.covered / row.required) * 100) : 0,
      color: CATEGORY_COLOR[categoria],
    }))
    .sort((a, b) => b.required - a.required)
    .slice(0, 6)
}

function buildMaintenanceSignals(stock: DashboardStockSource): DashboardMaintenanceSignal[] {
  const perdas = (stock.baixas ?? 0) + (stock.vendidos ?? 0)
  return [
    {
      id: 'manutencao',
      label: 'Manutenção',
      value: stock.manutencao,
      detail: 'unidades fora de operação',
      color: 'var(--accent-amber)',
    },
    {
      id: 'retornando',
      label: 'Retornando',
      value: stock.retornando,
      detail: 'pendentes de baixa no retorno',
      color: 'var(--accent-violet)',
    },
    {
      id: 'criticos',
      label: 'Críticos',
      value: stock.criticos,
      detail: 'desgaste 1 ou 2',
      color: 'var(--accent-red)',
    },
    {
      id: 'perdas',
      label: 'Perdas e baixas',
      value: perdas,
      detail: `${stock.baixas ?? 0} baixa · ${stock.vendidos ?? 0} vendido`,
      color: 'var(--accent-red)',
    },
  ]
}

function buildStatStrip(stock: DashboardStockSource): DashboardStatEntry[] {
  return [
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
  ]
}

function nextCheckoutLabel(projects: DashboardProjectSource[]): string {
  const next =
    projects.find((project) => project.status === 'MONTAGEM') ??
    projects.find((project) => project.status === 'CONFIRMADO') ??
    projects[0]
  if (!next) return 'SEM EVENTO'
  return formatEventDate(next.data_inicio)
}

export function buildDashboardData(input: BuildDashboardInput): DashboardData {
  const now = input.now ?? new Date()
  const user = input.user ?? { nome: 'Marcelo', iniciais: 'MS' }
  const ordered = orderedOperationalProjects(input.projects, now)
  const hero = ordered[0] ? buildHeroEvent(ordered[0]) : null

  return {
    greeting: currentGreeting(now),
    user,
    hero_event: hero,
    stat_strip: buildStatStrip(input.stock),
    upcoming_events: buildUpcomingEvents(ordered),
    upcoming_scheduled: ordered.length,
    notifications: ordered.filter(
      (project) => eventStatus(project, projectReadiness(project)) !== 'pronto',
    ).length,
    last_sync_at: now.toISOString(),
    operational: {
      technicians_in_field: ordered.filter((project) => project.status === 'EM_CAMPO').length + 1,
      events_in_progress: ordered.filter((project) => project.status === 'EM_CAMPO').length,
      next_checkout_label: nextCheckoutLabel(ordered),
    },
    category_usage: buildCategoryUsage(ordered),
    maintenance_signals: buildMaintenanceSignals(input.stock),
  }
}
