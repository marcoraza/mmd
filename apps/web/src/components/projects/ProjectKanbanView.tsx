'use client'

import { useState } from 'react'
import { Ring, StatusDot } from '@/components/mmd/Primitives'
import type { Projeto, StatusProjeto } from '@/lib/data/projects'

type Lane = {
  status: StatusProjeto
  name: string
  color: string
}

const LANES: Lane[] = [
  { status: 'PLANEJAMENTO', name: 'Planejado', color: 'var(--fg-3)' },
  { status: 'CONFIRMADO', name: 'Confirmado', color: 'var(--accent-cyan)' },
  { status: 'EM_CAMPO', name: 'Em campo', color: 'var(--accent-violet)' },
  { status: 'FINALIZADO', name: 'Finalizado', color: 'var(--accent-amber)' },
]

const DATE_FMT = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: 'short' })

function formatDate(iso: string): string {
  const [y, m, d] = iso.split('-').map(Number)
  return DATE_FMT.format(new Date(y, m - 1, d)).replace('.', '').toLowerCase()
}

export function ProjectKanbanView({
  projetos,
  onStatusChange,
}: {
  projetos: Projeto[]
  onStatusChange?: (projectId: string, status: StatusProjeto) => void
}) {
  const [draggingId, setDraggingId] = useState<string | null>(null)
  const [dragOverLane, setDragOverLane] = useState<StatusProjeto | null>(null)

  function handleDragStart(e: React.DragEvent, projectId: string) {
    setDraggingId(projectId)
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.setData('text/plain', projectId)
  }

  function handleDragEnd() {
    setDraggingId(null)
    setDragOverLane(null)
  }

  function handleDragOver(e: React.DragEvent, lane: StatusProjeto) {
    e.preventDefault()
    e.dataTransfer.dropEffect = 'move'
    if (dragOverLane !== lane) setDragOverLane(lane)
  }

  function handleDragLeave(e: React.DragEvent, lane: StatusProjeto) {
    if ((e.currentTarget as HTMLElement).contains(e.relatedTarget as Node)) return
    if (dragOverLane === lane) setDragOverLane(null)
  }

  function handleDrop(e: React.DragEvent, lane: StatusProjeto) {
    e.preventDefault()
    const id = e.dataTransfer.getData('text/plain') || draggingId
    if (id && onStatusChange) {
      const proj = projetos.find((p) => p.id === id)
      if (proj && proj.status !== lane) onStatusChange(id, lane)
    }
    setDraggingId(null)
    setDragOverLane(null)
  }

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
        gap: 14,
        minHeight: 520,
      }}
    >
      {LANES.map((lane) => {
        const cards = projetos.filter((p) => p.status === lane.status)
        const isDropTarget = dragOverLane === lane.status && draggingId !== null
        return (
          <div
            key={lane.status}
            onDragOver={(e) => handleDragOver(e, lane.status)}
            onDragLeave={(e) => handleDragLeave(e, lane.status)}
            onDrop={(e) => handleDrop(e, lane.status)}
            style={{
              display: 'flex',
              flexDirection: 'column',
              gap: 10,
              minWidth: 0,
              padding: 8,
              borderRadius: 'var(--r-lg)',
              border: isDropTarget
                ? '1px dashed color-mix(in oklch, var(--fg-0) 40%, transparent)'
                : '1px solid transparent',
              background: isDropTarget
                ? 'color-mix(in oklch, var(--fg-0) 4%, transparent)'
                : 'transparent',
              transition: 'background var(--motion-fast), border-color var(--motion-fast)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '0 4px' }}>
              <StatusDot color={lane.color} size={8} />
              <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--fg-0)' }}>
                {lane.name}
              </div>
              <div className="mono" style={{ fontSize: 11, color: 'var(--fg-3)' }}>
                {cards.length}
              </div>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {cards.length === 0 && (
                <div
                  style={{
                    padding: 20,
                    border: '1px dashed var(--glass-border)',
                    borderRadius: 'var(--r-lg)',
                    fontSize: 11,
                    color: 'var(--fg-3)',
                    textAlign: 'center',
                    letterSpacing: 0.1,
                  }}
                >
                  {isDropTarget ? 'Soltar aqui' : 'Vazio'}
                </div>
              )}
              {cards.map((p) => {
                const isDragging = draggingId === p.id
                return (
                  <div
                    key={p.id}
                    draggable
                    onDragStart={(e) => handleDragStart(e, p.id)}
                    onDragEnd={handleDragEnd}
                    style={{
                      padding: 14,
                      borderRadius: 'var(--r-lg)',
                      border: '1px solid var(--glass-border)',
                      background: 'var(--glass-bg)',
                      backdropFilter: 'blur(10px)',
                      WebkitBackdropFilter: 'blur(10px)',
                      cursor: 'grab',
                      opacity: isDragging ? 0.4 : 1,
                      boxShadow: isDragging
                        ? '0 12px 32px color-mix(in oklch, var(--fg-0) 12%, transparent)'
                        : 'none',
                      transform: isDragging ? 'rotate(-1deg)' : 'none',
                      transition: 'opacity var(--motion-fast), box-shadow var(--motion-fast)',
                    }}
                  >
                    <div
                      style={{
                        fontSize: 13,
                        fontWeight: 500,
                        color: 'var(--fg-0)',
                        marginBottom: 4,
                        display: '-webkit-box',
                        WebkitLineClamp: 2,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden',
                      }}
                    >
                      {p.nome}
                    </div>
                    <div
                      className="mono"
                      style={{ fontSize: 10, color: 'var(--fg-2)', marginBottom: 14 }}
                    >
                      {formatDate(p.data_inicio)}
                      {p.cliente ? ` · ${p.cliente}` : ''}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <Ring value={p.readiness_pct} size={34} stroke={3} decorative />
                      <div>
                        <div style={{ fontSize: 10, color: 'var(--fg-3)' }}>itens</div>
                        <div
                          className="mono"
                          style={{ fontSize: 12, color: 'var(--fg-1)', fontWeight: 500 }}
                        >
                          {p.itens_total}
                        </div>
                      </div>
                      <div style={{ flex: 1 }} />
                      <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>
                        {p.readiness_pct}%
                      </div>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        )
      })}
    </div>
  )
}
