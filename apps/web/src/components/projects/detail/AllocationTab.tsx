'use client'

import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { GlassCard, StatusDot, GhostBtn } from '@/components/mmd/Primitives'
import type { ProjectDetail, ProjectPackingLine } from '@/lib/data/project-detail'
import type { AvailableSerial } from '@/lib/data/serials'
import {
  autoAllocate,
  releaseSerial,
  setAllocation,
  listAvailableSerialsForPacking,
} from '@/lib/actions/projetos'
import { SerialPicker } from './SerialPicker'

type Props = {
  projeto: ProjectDetail
  onError: (msg: string) => void
  onDone: () => void
}

export function AllocationTab({ projeto, onError, onDone }: Props) {
  const canEdit = projeto.status === 'PLANEJAMENTO' || projeto.status === 'CONFIRMADO'

  if (projeto.packing.length === 0) {
    return (
      <GlassCard style={{ padding: 32, textAlign: 'center' }}>
        <div style={{ fontSize: 13, color: 'var(--fg-3)' }}>
          Nenhum item no packing. Volte para /projetos para montar o packing list.
        </div>
      </GlassCard>
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      {!canEdit && (
        <div
          className="mono"
          style={{
            padding: '10px 14px',
            borderRadius: 'var(--r-sm)',
            background: 'var(--glass-bg)',
            border: '1px solid var(--glass-border)',
            color: 'var(--fg-3)',
            fontSize: 11,
            letterSpacing: 0.06,
          }}
        >
          Alocação travada: projeto em {projeto.status}.
        </div>
      )}
      {projeto.packing.map((line) => (
        <AllocationRow
          key={line.id}
          line={line}
          canEdit={canEdit}
          onError={onError}
          onDone={onDone}
        />
      ))}
    </div>
  )
}

function AllocationRow({
  line,
  canEdit,
  onError,
  onDone,
}: {
  line: ProjectPackingLine
  canEdit: boolean
  onError: (msg: string) => void
  onDone: () => void
}) {
  const [pending, startTransition] = useTransition()
  const [picking, setPicking] = useState(false)
  const [candidates, setCandidates] = useState<AvailableSerial[] | null>(null)
  const [loadingPicker, setLoadingPicker] = useState(false)

  const missing = line.qtd_necessaria - line.qtd_alocada

  const handleAuto = () => {
    startTransition(async () => {
      const res = await autoAllocate(line.id)
      if (!res.ok) onError(res.error)
      else onDone()
    })
  }

  const handleOpenPicker = async () => {
    setPicking(true)
    if (candidates === null) {
      setLoadingPicker(true)
      const res = await listAvailableSerialsForPacking(line.id)
      setLoadingPicker(false)
      if (!res.ok) {
        onError(res.error)
        setPicking(false)
        return
      }
      setCandidates(res.data)
    }
  }

  const handlePick = (serialId: string) => {
    setPicking(false)
    setCandidates(null) // força refresh no próximo open
    const nextIds = [...line.seriais_alocados.map((s) => s.id), serialId]
    startTransition(async () => {
      const res = await setAllocation(line.id, nextIds)
      if (!res.ok) onError(res.error)
      else onDone()
    })
  }

  const handleRelease = (serialId: string) => {
    setCandidates(null)
    startTransition(async () => {
      const res = await releaseSerial(line.id, serialId)
      if (!res.ok) onError(res.error)
      else onDone()
    })
  }

  const statusColor =
    line.qtd_alocada >= line.qtd_necessaria
      ? 'var(--accent-green)'
      : line.qtd_alocada > 0
      ? 'var(--accent-amber)'
      : 'var(--accent-red)'

  return (
    <GlassCard style={{ padding: 16 }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 16,
          flexWrap: 'wrap',
          marginBottom: line.seriais_alocados.length > 0 ? 12 : 0,
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0, flex: 1 }}>
          <div style={{ fontSize: 14, color: 'var(--fg-0)', fontWeight: 450 }}>
            {line.item_nome}
          </div>
          <div
            className="mono"
            style={{
              fontSize: 11,
              color: 'var(--fg-3)',
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              letterSpacing: 0.06,
            }}
          >
            <span>{line.codigo_interno}</span>
            <span>·</span>
            <StatusDot color={statusColor} size={5} />
            <span style={{ color: statusColor }}>
              {line.qtd_alocada}/{line.qtd_necessaria}
            </span>
          </div>
        </div>

        {canEdit && (
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', position: 'relative' }}>
            {missing > 0 && (
              <GhostBtn small onClick={handleAuto} disabled={pending}>
                Auto-alocar {missing}
              </GhostBtn>
            )}
            {line.qtd_alocada < line.qtd_necessaria && (
              <GhostBtn small onClick={handleOpenPicker} disabled={pending}>
                Adicionar
              </GhostBtn>
            )}
            {picking && (
              <SerialPicker
                candidates={candidates ?? []}
                loading={loadingPicker}
                onPick={handlePick}
                onClose={() => setPicking(false)}
              />
            )}
          </div>
        )}
      </div>

      {line.seriais_alocados.length > 0 && (
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {line.seriais_alocados.map((s) => (
            <SerialChip
              key={s.id}
              codigo={s.codigo_interno}
              desgaste={s.desgaste}
              status={s.status}
              canRemove={canEdit && s.status === 'DISPONIVEL'}
              onRemove={() => handleRelease(s.id)}
            />
          ))}
        </div>
      )}
    </GlassCard>
  )
}

function SerialChip({
  codigo,
  desgaste,
  status,
  canRemove,
  onRemove,
}: {
  codigo: string
  desgaste: number
  status: string
  canRemove: boolean
  onRemove: () => void
}) {
  const wearColor =
    desgaste >= 4 ? 'var(--accent-green)' : desgaste === 3 ? 'var(--accent-amber)' : 'var(--accent-red)'
  const isField = status === 'EM_CAMPO'

  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: '4px 10px',
        borderRadius: 999,
        fontSize: 11,
        background: isField
          ? 'color-mix(in oklch, var(--accent-violet) 14%, transparent)'
          : 'var(--glass-bg)',
        border: isField
          ? '1px solid color-mix(in oklch, var(--accent-violet) 40%, transparent)'
          : '1px solid var(--glass-border)',
      }}
    >
      <span className="mono" style={{ color: 'var(--fg-0)', letterSpacing: 0.05 }}>
        {codigo}
      </span>
      <span className="mono" style={{ color: wearColor, fontSize: 10 }}>
        {desgaste}/5
      </span>
      {isField && (
        <span
          className="mono"
          style={{
            fontSize: 9,
            color: 'var(--accent-violet)',
            textTransform: 'uppercase',
            letterSpacing: 0.1,
          }}
        >
          em campo
        </span>
      )}
      {canRemove && (
        <button
          type="button"
          onClick={onRemove}
          aria-label={`Remover ${codigo}`}
          style={{
            marginLeft: 2,
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            width: 14,
            height: 14,
            padding: 0,
            border: 'none',
            borderRadius: 999,
            background: 'transparent',
            color: 'var(--fg-3)',
            cursor: 'pointer',
            fontSize: 12,
            lineHeight: 1,
            transition: 'background var(--motion-fast), color var(--motion-fast)',
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = 'color-mix(in oklch, var(--accent-red) 16%, transparent)'
            e.currentTarget.style.color = 'var(--accent-red)'
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = 'transparent'
            e.currentTarget.style.color = 'var(--fg-3)'
          }}
        >
          ×
        </button>
      )}
    </span>
  )
}
