'use client'

import { useState, useTransition } from 'react'
import type { ReactNode } from 'react'
import { useRouter } from 'next/navigation'
import type { Projeto, ProjectsData, StatusProjeto } from '@/lib/data/projects'
import { Icons } from '@/components/mmd/Icons'
import { ProjectListView } from './ProjectListView'
import { ProjectKanbanView } from './ProjectKanbanView'
import { ProjectCalendarView } from './ProjectCalendarView'
import { InlineNewProjectForm } from './InlineNewProjectForm'
import {
  createProjeto,
  updateProjetoStatus,
  addPackingItem,
  removePackingItem,
  updatePackingQty,
} from '@/lib/actions/projetos'

export type ProjectView = 'lista' | 'kanban' | 'calendario'

const VIEW_TABS: { key: ProjectView; label: string; icon: ReactNode }[] = [
  { key: 'lista', label: 'Lista', icon: Icons.list },
  { key: 'kanban', label: 'Kanban', icon: Icons.kanban },
  { key: 'calendario', label: 'Calendário', icon: Icons.calendar },
]

export function ProjectsClient({ data }: { data: ProjectsData }) {
  const router = useRouter()
  const [view, setView] = useState<ProjectView>('lista')
  const [creating, setCreating] = useState(false)
  const [isPending, startTransition] = useTransition()
  const [error, setError] = useState<string | null>(null)

  const projetos = data.projetos
  const ativos = projetos.filter(
    (p) => p.status !== 'FINALIZADO' && p.status !== 'CANCELADO'
  ).length

  function refresh() {
    router.refresh()
  }

  function handleCreate(input: {
    nome: string
    cliente: string | null
    data_inicio: string
    data_fim: string
    local: string | null
    status: StatusProjeto
    notas: string | null
  }) {
    setError(null)
    startTransition(async () => {
      const res = await createProjeto(input)
      if (!res.ok) {
        setError(res.error)
        return
      }
      setCreating(false)
      refresh()
    })
  }

  function handleStatusChange(projectId: string, status: StatusProjeto) {
    startTransition(async () => {
      const res = await updateProjetoStatus(projectId, status)
      if (!res.ok) setError(res.error)
      refresh()
    })
  }

  function handleAddItem(projetoId: string, itemId: string, qtd: number) {
    startTransition(async () => {
      const res = await addPackingItem(projetoId, itemId, qtd)
      if (!res.ok) setError(res.error)
      refresh()
    })
  }

  function handleRemoveItem(packingId: string) {
    startTransition(async () => {
      const res = await removePackingItem(packingId)
      if (!res.ok) setError(res.error)
      refresh()
    })
  }

  function handleUpdateQty(packingId: string, qtd: number) {
    startTransition(async () => {
      const res = await updatePackingQty(packingId, qtd)
      if (!res.ok) setError(res.error)
      refresh()
    })
  }

  return (
    <>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          flexWrap: 'wrap',
        }}
      >
        <div
          style={{
            display: 'inline-flex',
            padding: 3,
            borderRadius: 999,
            gap: 2,
            border: '1px solid var(--glass-border)',
          }}
        >
          {VIEW_TABS.map((t) => {
            const active = view === t.key
            return (
              <button
                key={t.key}
                type="button"
                onClick={() => setView(t.key)}
                aria-pressed={active}
                aria-label={t.label}
                title={t.label}
                style={{
                  width: 32,
                  height: 28,
                  borderRadius: 999,
                  border: 'none',
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  background: active ? 'var(--glass-bg-strong)' : 'transparent',
                  color: active ? 'var(--fg-0)' : 'var(--fg-3)',
                  transition: 'background var(--motion-fast), color var(--motion-fast)',
                }}
              >
                {t.icon}
              </button>
            )
          })}
        </div>

        <div
          className="mono"
          style={{
            fontSize: 11,
            color: 'var(--fg-3)',
            letterSpacing: 0.1,
            textTransform: 'uppercase',
          }}
        >
          {ativos} ativos · {projetos.length} no total
        </div>

        <div style={{ flex: 1 }} />

        <button
          type="button"
          onClick={() => setCreating((v) => !v)}
          aria-expanded={creating}
          style={{
            padding: '8px 16px',
            borderRadius: 999,
            border: '1px solid var(--glass-border-strong)',
            background: creating ? 'var(--glass-bg-strong)' : 'transparent',
            color: 'var(--fg-0)',
            fontFamily: 'inherit',
            fontSize: 12,
            fontWeight: 500,
            cursor: 'pointer',
            transition: 'background var(--motion-fast)',
          }}
        >
          {creating ? '× Cancelar' : '+ Novo projeto'}
        </button>
      </div>

      {creating && (
        <InlineNewProjectForm
          onSubmit={handleCreate}
          onCancel={() => {
            setCreating(false)
            setError(null)
          }}
          pending={isPending}
          error={error}
        />
      )}

      <div style={{ marginTop: 20 }}>
        {view === 'lista' && (
          <ProjectListView
            projetos={projetos}
            onAddItem={handleAddItem}
            onRemoveItem={handleRemoveItem}
            onUpdateQty={handleUpdateQty}
            pending={isPending}
          />
        )}
        {view === 'kanban' && (
          <ProjectKanbanView projetos={projetos} onStatusChange={handleStatusChange} />
        )}
        {view === 'calendario' && <ProjectCalendarView projetos={projetos} />}
      </div>
    </>
  )
}

export type Projeto_ = Projeto
