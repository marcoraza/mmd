import 'server-only'

import {
  buildDashboardData,
  type DashboardProjectSource,
  type DashboardStockSource,
} from '@/lib/dashboard-core'
import { loadProjectById, type ProjectDetail } from '@/lib/data/project-detail'
import { loadProjects, type Projeto } from '@/lib/data/projects'
import { loadStockStats } from '@/lib/data/stock'

export type {
  DashboardCategoryUsage,
  DashboardData,
  DashboardHeroEvent,
  DashboardMaintenanceSignal,
  DashboardStatEntry,
  DashboardUpcomingEvent,
  EventStatus,
  EventType,
  OperationalPulse,
  ReadinessSatellite,
} from '@/lib/dashboard-core'

function projectPackingSource(project: Projeto): DashboardProjectSource['packing'] {
  return project.packing.map((line) => ({
    id: line.id,
    item_nome: line.nome,
    categoria: line.categoria,
    qtd_necessaria: line.qtd_necessaria,
    qtd_alocada: line.qtd_alocada,
    qtd_alugada_avulsa: line.qtd_alugada_avulsa,
    qtd_coberta: line.qtd_coberta,
    qtd_faltante: line.qtd_faltante,
    conflicts_count: line.conflicts_with?.length ?? 0,
  }))
}

function detailPackingSource(detail: ProjectDetail): DashboardProjectSource['packing'] {
  return detail.packing.map((line) => ({
    id: line.id,
    item_nome: line.item_nome,
    categoria: line.categoria,
    qtd_necessaria: line.qtd_necessaria,
    qtd_alocada: line.qtd_alocada,
    qtd_alugada_avulsa: line.qtd_alugada_avulsa,
    qtd_coberta: line.qtd_coberta,
    qtd_faltante: line.qtd_faltante,
    conflicts_count: line.conflicts_with?.length ?? 0,
  }))
}

function dashboardProjectSource(
  project: Projeto,
  detail: ProjectDetail | null,
): DashboardProjectSource {
  if (detail) {
    return {
      id: detail.id,
      nome: detail.nome,
      cliente: detail.cliente,
      data_inicio: detail.data_inicio,
      data_fim: detail.data_fim,
      local: detail.local,
      status: detail.status,
      packing: detailPackingSource(detail),
      readiness_pct: detail.readiness_pct,
      gate_readiness_pct: detail.checkout_gate.readinessPct,
      gate_blockers_count: detail.checkout_gate.blockers.length,
      open_return_pendings: detail.retorno_pendencias.filter(
        (pending) => pending.status === 'ABERTA',
      ).length,
    }
  }

  return {
    id: project.id,
    nome: project.nome,
    cliente: project.cliente,
    data_inicio: project.data_inicio,
    data_fim: project.data_fim,
    local: project.local,
    status: project.status,
    packing: projectPackingSource(project),
    readiness_pct: project.readiness_pct,
  }
}

async function loadDetailMap(projects: Projeto[]) {
  const relevant = projects
    .filter((project) => !['FINALIZADO', 'CANCELADO'].includes(project.status))
    .slice(0, 8)

  const entries = await Promise.all(
    relevant.map(async (project) => {
      try {
        return [project.id, await loadProjectById(project.id)] as const
      } catch (error) {
        console.warn(`[eventpro-dashboard] detalhe indisponível para ${project.id}`, error)
        return [project.id, null] as const
      }
    }),
  )

  return new Map(entries)
}

export async function loadDashboard() {
  const [stock, projectsData] = await Promise.all([loadStockStats(), loadProjects()])
  const details = await loadDetailMap(projectsData.projetos)
  const projects = projectsData.projetos.map((project) =>
    dashboardProjectSource(project, details.get(project.id) ?? null),
  )

  return buildDashboardData({
    stock: stock satisfies DashboardStockSource,
    projects,
  })
}
