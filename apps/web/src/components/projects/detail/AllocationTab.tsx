'use client'

import { useState, useTransition } from 'react'
import { GlassCard, StatusDot, Btn } from '@/components/mmd/Primitives'
import type { ProjectDetail, ProjectPackingLine } from '@/lib/data/project-detail'
import type { AvailableSerial } from '@/lib/data/serials'
import {
  addExternalRentalCoverage,
  autoAllocate,
  releaseSerial,
  removeExternalRentalCoverage,
  setAllocation,
  listAvailableSerialsForPacking,
} from '@/lib/actions/projetos'
import { formatProjetoDate } from '../helpers'
import { SerialPicker } from './SerialPicker'

type Props = {
  projeto: ProjectDetail
  onError: (msg: string) => void
  onDone: () => void
}

export function AllocationTab({ projeto, onError, onDone }: Props) {
  const canEdit =
    projeto.status === 'PLANEJAMENTO' ||
    projeto.status === 'CONFIRMADO' ||
    projeto.status === 'MONTAGEM'

  if (projeto.packing.length === 0) {
    return (
      <GlassCard style={{ padding: 32, textAlign: 'center' }}>
        <div style={{ fontSize: 13, color: 'var(--fg-3)' }}>
          Nenhum item no packing. Volte para Eventos para montar o packing list.
        </div>
      </GlassCard>
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      <GlassCard style={{ padding: 14 }}>
        <div
          style={{
            display: 'flex',
            gap: 12,
            alignItems: 'center',
            justifyContent: 'space-between',
            flexWrap: 'wrap',
          }}
        >
          <div>
            <div
              className="mono"
              style={{ color: 'var(--fg-3)', fontSize: 10, letterSpacing: 0.1 }}
            >
              JANELA DO EVENTO
            </div>
            <div style={{ color: 'var(--fg-0)', fontSize: 14, marginTop: 4 }}>
              {formatProjetoDate(projeto.data_inicio)} até {formatProjetoDate(projeto.data_fim)}
            </div>
          </div>
          <div
            style={{
              flex: '1 1 360px',
              border: '1px solid color-mix(in oklch, var(--accent-amber) 35%, transparent)',
              borderRadius: 8,
              background: 'color-mix(in oklch, var(--accent-amber) 10%, transparent)',
              color: 'var(--fg-1)',
              padding: '10px 12px',
              fontSize: 12,
            }}
          >
            Conflito de data alerta a equipe, mas não bloqueia planejamento. Falta pode ser
            resolvida depois com aluguel avulso.
          </div>
        </div>
      </GlassCard>
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
          Alocação travada: Evento em {projeto.status}.
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
  const [rentalOpen, setRentalOpen] = useState(false)
  const [rentalFornecedor, setRentalFornecedor] = useState('')
  const [rentalQuantidade, setRentalQuantidade] = useState(String(Math.max(line.qtd_faltante, 1)))
  const [rentalObservacao, setRentalObservacao] = useState('')

  const missing = line.qtd_faltante

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

  const handleAddRental = () => {
    startTransition(async () => {
      const res = await addExternalRentalCoverage(line.id, {
        fornecedor: rentalFornecedor,
        quantidade: Number(rentalQuantidade),
        observacao: rentalObservacao,
      })
      if (!res.ok) {
        onError(res.error)
        return
      }
      setRentalOpen(false)
      setRentalFornecedor('')
      setRentalQuantidade(String(Math.max(line.qtd_faltante, 1)))
      setRentalObservacao('')
      onDone()
    })
  }

  const handleRemoveRental = (rentalId: string) => {
    startTransition(async () => {
      const res = await removeExternalRentalCoverage(line.id, rentalId)
      if (!res.ok) onError(res.error)
      else onDone()
    })
  }

  const statusColor =
    line.qtd_coberta >= line.qtd_necessaria
      ? 'var(--accent-green)'
      : line.qtd_coberta > 0
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
          marginBottom:
            line.seriais_alocados.length > 0 || line.alugueis_avulsos.length > 0 || rentalOpen
              ? 12
              : 0,
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
              flexWrap: 'wrap',
            }}
          >
            <span>{line.codigo_interno}</span>
            <span>·</span>
            <StatusDot color={statusColor} size={5} />
            <span style={{ color: statusColor }}>
              {line.qtd_coberta}/{line.qtd_necessaria} cobertos
            </span>
            <span>·</span>
            <span>{line.qtd_alocada} próprias</span>
            {line.qtd_alugada_avulsa > 0 && (
              <>
                <span>·</span>
                <span>{line.qtd_alugada_avulsa} avulso</span>
              </>
            )}
          </div>
        </div>

        {canEdit && (
          <div
            className="allocation-actions"
            style={{ display: 'flex', gap: 8, alignItems: 'center', position: 'relative' }}
          >
            {missing > 0 && (
              <Btn variant="ghost" small onClick={handleAuto} disabled={pending}>
                Auto-alocar disponíveis ({missing})
              </Btn>
            )}
            {line.qtd_coberta < line.qtd_necessaria && (
              <Btn variant="ghost" small onClick={handleOpenPicker} disabled={pending}>
                Selecionar unidade
              </Btn>
            )}
            {missing > 0 && (
              <Btn
                variant="ghost"
                small
                onClick={() => setRentalOpen((open) => !open)}
                disabled={pending}
              >
                Registrar aluguel
              </Btn>
            )}
            {picking && (
              <SerialPicker
                candidates={candidates ?? []}
                loading={loadingPicker}
                onPick={handlePick}
                onClose={() => setPicking(false)}
              />
            )}
            <style>{`
              @media (max-width: 720px) {
                .allocation-actions {
                  width: 100%;
                  flex-direction: column;
                  align-items: stretch !important;
                }

                .allocation-actions > button {
                  width: 100%;
                }
              }
            `}</style>
          </div>
        )}
      </div>

      {(line.seriais_alocados.length > 0 || line.alugueis_avulsos.length > 0 || rentalOpen) && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
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

          {(line.alugueis_avulsos.length > 0 || rentalOpen) && (
            <div
              style={{
                border: '1px solid color-mix(in oklch, var(--accent-cyan) 30%, transparent)',
                borderRadius: 8,
                background: 'color-mix(in oklch, var(--accent-cyan) 7%, transparent)',
                padding: 10,
                display: 'flex',
                flexDirection: 'column',
                gap: 8,
              }}
            >
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  gap: 8,
                  flexWrap: 'wrap',
                }}
              >
                <div
                  className="mono"
                  style={{ color: 'var(--fg-3)', fontSize: 10, letterSpacing: 0.08 }}
                >
                  COBERTURA AVULSA
                </div>
                <div
                  className="mono"
                  style={{ color: 'var(--accent-cyan)', fontSize: 10, letterSpacing: 0.06 }}
                >
                  {line.qtd_alugada_avulsa}/{line.qtd_necessaria} via parceiro
                </div>
              </div>

              {line.alugueis_avulsos.length > 0 && (
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  {line.alugueis_avulsos.map((rental) => (
                    <ExternalRentalChip
                      key={rental.id}
                      fornecedor={rental.fornecedor}
                      quantidade={rental.quantidade}
                      observacao={rental.observacao}
                      canRemove={canEdit}
                      onRemove={() => handleRemoveRental(rental.id)}
                    />
                  ))}
                </div>
              )}

              {rentalOpen && (
                <div
                  className="external-rental-form"
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'minmax(160px, 1.2fr) 82px minmax(180px, 1.4fr) auto',
                    gap: 8,
                    alignItems: 'center',
                  }}
                >
                  <input
                    value={rentalFornecedor}
                    onChange={(event) => setRentalFornecedor(event.target.value)}
                    placeholder="Parceiro"
                    aria-label="Parceiro do aluguel avulso"
                    style={rentalInputStyle}
                  />
                  <input
                    value={rentalQuantidade}
                    onChange={(event) => setRentalQuantidade(event.target.value)}
                    type="number"
                    min={1}
                    max={missing || undefined}
                    placeholder="Qtd"
                    aria-label="Quantidade do aluguel avulso"
                    style={rentalInputStyle}
                  />
                  <input
                    value={rentalObservacao}
                    onChange={(event) => setRentalObservacao(event.target.value)}
                    placeholder="Obs mínima"
                    aria-label="Observação do aluguel avulso"
                    style={rentalInputStyle}
                  />
                  <Btn variant="primary" small onClick={handleAddRental} disabled={pending}>
                    Salvar
                  </Btn>
                  <style>{`
                    @media (max-width: 720px) {
                      .external-rental-form {
                        grid-template-columns: 1fr !important;
                      }

                      .external-rental-form > button {
                        width: 100%;
                      }
                    }
                  `}</style>
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </GlassCard>
  )
}

const rentalInputStyle: React.CSSProperties = {
  width: '100%',
  border: '1px solid var(--glass-border)',
  borderRadius: 7,
  background: 'var(--bg-0)',
  color: 'var(--fg-0)',
  fontSize: 12,
  padding: '8px 10px',
  outline: 'none',
}

function ExternalRentalChip({
  fornecedor,
  quantidade,
  observacao,
  canRemove,
  onRemove,
}: {
  fornecedor: string
  quantidade: number
  observacao: string
  canRemove: boolean
  onRemove: () => void
}) {
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 8,
        maxWidth: '100%',
        padding: '5px 10px',
        borderRadius: 999,
        fontSize: 11,
        background: 'var(--bg-0)',
        border: '1px solid color-mix(in oklch, var(--accent-cyan) 35%, transparent)',
        color: 'var(--fg-1)',
      }}
    >
      <span className="mono" style={{ color: 'var(--accent-cyan)', letterSpacing: 0.05 }}>
        {quantidade} avulso
      </span>
      <span style={{ color: 'var(--fg-0)', whiteSpace: 'nowrap' }}>{fornecedor}</span>
      <span
        style={{
          color: 'var(--fg-3)',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
          minWidth: 0,
        }}
      >
        {observacao}
      </span>
      {canRemove && (
        <button
          type="button"
          onClick={onRemove}
          aria-label={`Remover aluguel avulso de ${fornecedor}`}
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
            flex: '0 0 auto',
            transition: 'background var(--motion-fast), color var(--motion-fast)',
          }}
          onMouseEnter={(event) => {
            event.currentTarget.style.background =
              'color-mix(in oklch, var(--accent-red) 16%, transparent)'
            event.currentTarget.style.color = 'var(--accent-red)'
          }}
          onMouseLeave={(event) => {
            event.currentTarget.style.background = 'transparent'
            event.currentTarget.style.color = 'var(--fg-3)'
          }}
        >
          ×
        </button>
      )}
    </span>
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
    desgaste >= 4
      ? 'var(--accent-green)'
      : desgaste === 3
        ? 'var(--accent-amber)'
        : 'var(--accent-red)'
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
            e.currentTarget.style.background =
              'color-mix(in oklch, var(--accent-red) 16%, transparent)'
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
