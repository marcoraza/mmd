'use client'

import { useEffect } from 'react'
import { GhostBtn, StatusDot } from '@/components/mmd/Primitives'
import type { ConflictRef, PackingItem, StatusProjeto } from '@/lib/data/projects'

const DATE_FMT = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: 'short' })

function formatDate(iso: string): string {
  const [y, m, d] = iso.split('-').map(Number)
  return DATE_FMT.format(new Date(y, m - 1, d)).replace('.', '').toLowerCase()
}

function formatRange(inicio: string, fim: string): string {
  if (inicio === fim) return formatDate(inicio)
  return `${formatDate(inicio)} até ${formatDate(fim)}`
}

function statusLabel(s: StatusProjeto): string {
  switch (s) {
    case 'PLANEJAMENTO': return 'Planejamento'
    case 'CONFIRMADO': return 'Confirmado'
    case 'EM_CAMPO': return 'Em campo'
    case 'FINALIZADO': return 'Finalizado'
    case 'CANCELADO': return 'Cancelado'
  }
}

function statusColor(s: StatusProjeto): string {
  switch (s) {
    case 'PLANEJAMENTO': return 'var(--fg-3)'
    case 'CONFIRMADO': return 'var(--accent-cyan)'
    case 'EM_CAMPO': return 'var(--accent-violet)'
    case 'FINALIZADO': return 'var(--fg-3)'
    case 'CANCELADO': return 'var(--accent-red)'
  }
}

type Props = {
  item: PackingItem | null
  projetoAtualNome: string
  projetoAtualDataInicio: string
  projetoAtualDataFim: string
  onClose: () => void
  onGoToProject: (projetoId: string) => void
}

export function ConflictModal({
  item,
  projetoAtualNome,
  projetoAtualDataInicio,
  projetoAtualDataFim,
  onClose,
  onGoToProject,
}: Props) {
  useEffect(() => {
    if (!item) return
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [item, onClose])

  if (!item) return null
  const conflitos = item.conflicts_with ?? []
  const totalAlocadoOutros = conflitos.reduce((acc, c) => acc + c.qtd_alocada, 0)

  return (
    <>
      <button
        type="button"
        aria-label="Fechar"
        onClick={onClose}
        style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(0, 0, 0, 0.45)',
          backdropFilter: 'blur(6px)',
          WebkitBackdropFilter: 'blur(6px)',
          border: 'none',
          cursor: 'pointer',
          zIndex: 50,
          animation: 'mmd-reveal 200ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
        }}
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={`Conflito de alocação: ${item.nome}`}
        style={{
          position: 'fixed',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          width: 'min(560px, calc(100vw - 32px))',
          maxHeight: 'calc(100vh - 64px)',
          display: 'flex',
          flexDirection: 'column',
          background: 'var(--bg-0)',
          border: '1px solid var(--glass-border-strong)',
          borderRadius: 'var(--r-lg)',
          boxShadow: 'var(--glass-shadow-elevated)',
          zIndex: 51,
          overflow: 'hidden',
          animation: 'mmd-reveal 240ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
        }}
      >
        {/* Header */}
        <div
          style={{
            padding: '20px 22px 16px',
            borderBottom: '1px solid var(--glass-border)',
          }}
        >
          <div
            className="mono"
            style={{
              fontSize: 10,
              letterSpacing: 0.12,
              textTransform: 'uppercase',
              color: 'var(--accent-red)',
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              marginBottom: 6,
            }}
          >
            <StatusDot color="var(--accent-red)" size={6} />
            Conflito de alocação
          </div>
          <div
            style={{
              fontSize: 18,
              fontWeight: 500,
              color: 'var(--fg-0)',
              letterSpacing: -0.3,
            }}
          >
            {item.nome}
          </div>
          <div
            className="mono"
            style={{
              fontSize: 11,
              color: 'var(--fg-2)',
              marginTop: 4,
              letterSpacing: 0.08,
            }}
          >
            {item.codigo_interno} · necessário {item.qtd_necessaria} ·{' '}
            {item.qtd_alocada} alocado aqui
          </div>
        </div>

        {/* Body */}
        <div
          style={{
            padding: '16px 22px',
            overflowY: 'auto',
            display: 'flex',
            flexDirection: 'column',
            gap: 14,
            flex: 1,
          }}
        >
          <div style={{ fontSize: 13, color: 'var(--fg-1)', lineHeight: 1.5 }}>
            Também reservado em <strong>{conflitos.length}</strong>{' '}
            {conflitos.length === 1 ? 'projeto que se sobrepõe' : 'projetos que se sobrepõem'} com{' '}
            <strong>{projetoAtualNome}</strong> ({formatRange(projetoAtualDataInicio, projetoAtualDataFim)}).
          </div>

          {totalAlocadoOutros > 0 && (
            <div
              className="mono"
              style={{
                padding: '10px 12px',
                borderRadius: 'var(--r-sm)',
                background: 'color-mix(in oklch, var(--accent-red) 10%, transparent)',
                border: '1px solid color-mix(in oklch, var(--accent-red) 30%, transparent)',
                fontSize: 11,
                color: 'var(--accent-red)',
                letterSpacing: 0.05,
              }}
            >
              {totalAlocadoOutros} unidade{totalAlocadoOutros === 1 ? '' : 's'} já alocada
              {totalAlocadoOutros === 1 ? '' : 's'} em outros projetos neste período
            </div>
          )}

          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {conflitos.map((c) => (
              <ConflictRow key={c.projeto_id} conflict={c} onGoToProject={onGoToProject} />
            ))}
          </div>
        </div>

        {/* Footer */}
        <div
          style={{
            padding: '14px 22px',
            borderTop: '1px solid var(--glass-border)',
            display: 'flex',
            justifyContent: 'flex-end',
            gap: 10,
            background: 'var(--glass-bg)',
          }}
        >
          <GhostBtn small onClick={onClose}>Fechar</GhostBtn>
        </div>
      </div>
    </>
  )
}

function ConflictRow({
  conflict,
  onGoToProject,
}: {
  conflict: ConflictRef
  onGoToProject: (projetoId: string) => void
}) {
  const color = statusColor(conflict.status)
  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: '1fr auto',
        gap: 12,
        alignItems: 'center',
        padding: '12px 14px',
        borderRadius: 'var(--r-md)',
        border: '1px solid var(--glass-border)',
        background: 'var(--glass-bg)',
      }}
    >
      <div style={{ minWidth: 0 }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            marginBottom: 4,
          }}
        >
          <StatusDot color={color} size={6} glow={false} />
          <span
            className="mono"
            style={{
              fontSize: 10,
              color,
              letterSpacing: 0.1,
              textTransform: 'uppercase',
            }}
          >
            {statusLabel(conflict.status)}
          </span>
        </div>
        <div
          style={{
            fontSize: 14,
            fontWeight: 500,
            color: 'var(--fg-0)',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {conflict.projeto_nome}
        </div>
        <div
          className="mono"
          style={{
            fontSize: 11,
            color: 'var(--fg-2)',
            marginTop: 2,
            letterSpacing: 0.05,
          }}
        >
          {formatRange(conflict.data_inicio, conflict.data_fim)} · {conflict.qtd_alocada}/
          {conflict.qtd_necessaria} alocado
        </div>
      </div>
      <button
        type="button"
        onClick={() => onGoToProject(conflict.projeto_id)}
        style={{
          padding: '7px 12px',
          borderRadius: 999,
          border: '1px solid var(--glass-border-strong)',
          background: 'var(--glass-bg-strong)',
          color: 'var(--fg-0)',
          fontFamily: 'inherit',
          fontSize: 12,
          fontWeight: 500,
          cursor: 'pointer',
          whiteSpace: 'nowrap',
          transition: 'background var(--motion-fast)',
        }}
      >
        Ver projeto →
      </button>
    </div>
  )
}
