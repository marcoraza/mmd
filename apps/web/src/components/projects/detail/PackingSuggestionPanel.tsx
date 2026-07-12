'use client'

import { useEffect, useMemo, useState, useTransition } from 'react'
import { Bot, CheckCircle2, History, Layers, Save, Sparkles, Trash2, X } from 'lucide-react'
import {
  applyPackingSuggestion,
  loadPackingSuggestionWorkspace,
  savePackingTemplateFromProject,
  type ApplyPackingSuggestionLineInput,
} from '@/lib/actions/projetos'
import type {
  PackingSuggestionCandidate,
  PackingSuggestionLine,
  PackingSuggestionSource,
  PackingSuggestionWorkspace,
} from '@/lib/packing-suggestion-core'

const SOURCE_META: Record<
  PackingSuggestionSource,
  { label: string; color: string; icon: typeof History }
> = {
  historico: { label: 'Histórico parecido', color: 'var(--accent-green)', icon: History },
  template: { label: 'Template salvo', color: 'var(--accent-cyan)', icon: Layers },
  ia_rascunho: { label: 'IA rascunho', color: 'var(--accent-violet)', icon: Bot },
}

const INPUT_STYLE: React.CSSProperties = {
  minHeight: 34,
  borderRadius: 8,
  border: '1px solid var(--glass-border)',
  background: 'var(--glass-bg)',
  color: 'var(--fg-0)',
  fontFamily: 'inherit',
  fontSize: 12,
  padding: '8px 10px',
  outline: 'none',
}

export function PackingSuggestionPanel({
  projetoId,
  onError,
  onApplied,
  onClose,
}: {
  projetoId: string
  onError: (message: string | null) => void
  onApplied: () => void
  onClose: () => void
}) {
  const [workspace, setWorkspace] = useState<PackingSuggestionWorkspace | null>(null)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [draftLines, setDraftLines] = useState<PackingSuggestionLine[]>([])
  const [templateName, setTemplateName] = useState('')
  const [templateDescription, setTemplateDescription] = useState('')
  const [notice, setNotice] = useState<string | null>(null)
  const [pending, startTransition] = useTransition()

  useEffect(() => {
    let cancelled = false
    startTransition(async () => {
      const result = await loadPackingSuggestionWorkspace(projetoId)
      if (cancelled) return
      if (!result.ok) {
        onError(result.error)
        return
      }
      setWorkspace(result.data)
      const first = result.data.suggestions[0] ?? null
      setSelectedId(first?.id ?? null)
      setDraftLines(first?.lines ?? [])
    })
    return () => {
      cancelled = true
    }
  }, [projetoId, onError])

  const selected = useMemo(
    () => workspace?.suggestions.find((candidate) => candidate.id === selectedId) ?? null,
    [workspace, selectedId],
  )

  function selectCandidate(candidate: PackingSuggestionCandidate) {
    setSelectedId(candidate.id)
    setDraftLines(candidate.lines)
    setNotice(null)
  }

  function updateQty(itemId: string, quantidade: number) {
    setDraftLines((current) =>
      current.map((line) => (line.itemId === itemId ? { ...line, quantidade } : line)),
    )
  }

  function removeLine(itemId: string) {
    setDraftLines((current) => current.filter((line) => line.itemId !== itemId))
  }

  function handleSaveTemplate() {
    onError(null)
    setNotice(null)
    startTransition(async () => {
      const result = await savePackingTemplateFromProject(
        projetoId,
        templateName,
        templateDescription,
      )
      if (!result.ok) {
        onError(result.error)
        return
      }
      setTemplateName('')
      setTemplateDescription('')
      setNotice('Template salvo.')
      const refresh = await loadPackingSuggestionWorkspace(projetoId)
      if (refresh.ok) setWorkspace(refresh.data)
    })
  }

  function handleApply() {
    const lines: ApplyPackingSuggestionLineInput[] = draftLines
      .filter((line) => Number.isInteger(line.quantidade) && line.quantidade > 0)
      .map((line) => ({
        itemId: line.itemId,
        quantidade: line.quantidade,
        observacao: line.observacao,
      }))

    if (lines.length === 0) {
      onError('Proposta precisa ter pelo menos uma linha válida.')
      return
    }

    onError(null)
    setNotice(null)
    startTransition(async () => {
      const result = await applyPackingSuggestion(projetoId, lines)
      if (!result.ok) {
        onError(result.error)
        return
      }
      onApplied()
    })
  }

  return (
    <div
      style={{
        padding: 16,
        borderBottom: '1px solid var(--glass-border)',
        background: 'color-mix(in oklch, var(--accent-violet) 5%, transparent)',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, marginBottom: 12 }}>
        <Sparkles size={18} color="var(--accent-violet)" />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ color: 'var(--fg-0)', fontSize: 14, fontWeight: 500 }}>
            Templates e sugestão
          </div>
          <div style={{ color: 'var(--fg-3)', fontSize: 12, marginTop: 3 }}>
            Proposta revisável: histórico primeiro, template salvo depois.
          </div>
        </div>
        <button type="button" aria-label="Fechar templates" onClick={onClose} style={iconButtonStyle}>
          <X size={16} />
        </button>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'minmax(260px, 0.8fr) minmax(420px, 1.4fr)',
          gap: 12,
        }}
        className="packing-suggestion-grid"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, minWidth: 0 }}>
          <div
            style={{
              border: '1px solid var(--glass-border)',
              borderRadius: 8,
              overflow: 'hidden',
              background: 'var(--bg-0)',
            }}
          >
            <PanelHeader title="Propostas" meta={`${workspace?.suggestions.length ?? 0} fontes`} />
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              {workspace?.suggestions.map((candidate) => (
                <SuggestionButton
                  key={candidate.id}
                  candidate={candidate}
                  active={candidate.id === selectedId}
                  onClick={() => selectCandidate(candidate)}
                />
              ))}
              {!workspace && <EmptyState text="Carregando sugestões" />}
              {workspace && workspace.suggestions.length === 0 && (
                <EmptyState text="Sem histórico ou template ainda." />
              )}
            </div>
          </div>

          <div
            style={{
              border: '1px solid var(--glass-border)',
              borderRadius: 8,
              padding: 12,
              background: 'var(--bg-0)',
              display: 'flex',
              flexDirection: 'column',
              gap: 8,
            }}
          >
            <div style={{ color: 'var(--fg-0)', fontSize: 13, fontWeight: 500 }}>
              Salvar packing atual
            </div>
            <input
              value={templateName}
              onChange={(event) => setTemplateName(event.currentTarget.value)}
              placeholder="Nome do template"
              style={INPUT_STYLE}
            />
            <input
              value={templateDescription}
              onChange={(event) => setTemplateDescription(event.currentTarget.value)}
              placeholder="Descrição curta"
              style={INPUT_STYLE}
            />
            <button
              type="button"
              onClick={handleSaveTemplate}
              disabled={pending}
              style={{
                ...primaryButtonStyle,
                background: 'var(--fg-0)',
                color: 'var(--bg-0)',
              }}
            >
              <Save size={14} />
              Salvar template
            </button>
            {notice && <div style={{ color: 'var(--accent-green)', fontSize: 12 }}>{notice}</div>}
          </div>
        </div>

        <div
          style={{
            border: '1px solid var(--glass-border)',
            borderRadius: 8,
            overflow: 'hidden',
            background: 'var(--bg-0)',
          }}
        >
          <div
            style={{
              padding: '10px 12px',
              borderBottom: '1px solid var(--glass-border)',
              display: 'flex',
              gap: 10,
              alignItems: 'center',
              flexWrap: 'wrap',
            }}
          >
            <div style={{ flex: 1, minWidth: 180 }}>
              <div style={{ color: 'var(--fg-0)', fontSize: 13, fontWeight: 500 }}>
                Proposta revisável
              </div>
              <div className="mono" style={{ color: 'var(--fg-3)', fontSize: 10, marginTop: 3 }}>
                {selected ? selected.reason : 'Escolha uma fonte para revisar.'}
              </div>
            </div>
            {selected && <SourcePill candidate={selected} />}
            <button
              type="button"
              onClick={handleApply}
              disabled={pending || draftLines.length === 0}
              style={{
                ...primaryButtonStyle,
                background: draftLines.length > 0 ? 'var(--fg-0)' : 'var(--glass-border)',
                color: draftLines.length > 0 ? 'var(--bg-0)' : 'var(--fg-3)',
              }}
            >
              <CheckCircle2 size={14} />
              {pending ? 'Aplicando' : 'Aplicar proposta'}
            </button>
          </div>

          <div className="packing-suggestion-table" style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
              <thead>
                <tr style={{ background: 'var(--glass-bg)' }}>
                  <Th>Item</Th>
                  <Th mono>Código</Th>
                  <Th>Categoria</Th>
                  <Th align="right">Qtd</Th>
                  <Th>Obs</Th>
                  <Th align="right">Ação</Th>
                </tr>
              </thead>
              <tbody>
                {draftLines.map((line) => (
                  <SuggestionTableRow
                    key={line.itemId}
                    line={line}
                    pending={pending}
                    onQty={updateQty}
                    onRemove={removeLine}
                  />
                ))}
                {draftLines.length === 0 && (
                  <tr>
                    <td colSpan={6}>
                      <EmptyState text="Nenhuma linha na proposta." />
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          <div className="packing-suggestion-mobile">
            {draftLines.map((line) => (
              <SuggestionMobileRow
                key={line.itemId}
                line={line}
                pending={pending}
                onQty={updateQty}
                onRemove={removeLine}
              />
            ))}
          </div>
        </div>
      </div>

      <style>{`
        .packing-suggestion-mobile {
          display: none;
        }

        @media (max-width: 920px) {
          .packing-suggestion-grid {
            grid-template-columns: 1fr !important;
          }
        }

        @media (max-width: 760px) {
          .packing-suggestion-table {
            display: none;
          }

          .packing-suggestion-mobile {
            display: flex;
            flex-direction: column;
          }
        }
      `}</style>
    </div>
  )
}

function SuggestionButton({
  candidate,
  active,
  onClick,
}: {
  candidate: PackingSuggestionCandidate
  active: boolean
  onClick: () => void
}) {
  const meta = SOURCE_META[candidate.source]
  const Icon = meta.icon
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={candidate.disabled}
      style={{
        border: 'none',
        borderTop: '1px solid var(--glass-border)',
        background: active
          ? 'color-mix(in oklch, var(--accent-violet) 12%, transparent)'
          : 'transparent',
        color: 'var(--fg-0)',
        textAlign: 'left',
        padding: 12,
        cursor: candidate.disabled ? 'not-allowed' : 'pointer',
        fontFamily: 'inherit',
      }}
    >
      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
        <Icon size={14} color={meta.color} />
        <span style={{ fontSize: 13, fontWeight: 500 }}>{candidate.title}</span>
      </div>
      <div style={{ color: 'var(--fg-3)', fontSize: 11, marginTop: 5 }}>{candidate.subtitle}</div>
      <div className="mono" style={{ color: meta.color, fontSize: 10, marginTop: 7 }}>
        {meta.label} · {candidate.confidencePct}% confiança · {candidate.lines.length} linhas
      </div>
    </button>
  )
}

function SourcePill({ candidate }: { candidate: PackingSuggestionCandidate }) {
  const meta = SOURCE_META[candidate.source]
  return (
    <span
      className="mono"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        border: '1px solid var(--glass-border)',
        borderRadius: 999,
        padding: '5px 9px',
        color: meta.color,
        fontSize: 10,
        whiteSpace: 'nowrap',
      }}
    >
      {meta.label} · {candidate.confidencePct}%
    </span>
  )
}

function SuggestionTableRow({
  line,
  pending,
  onQty,
  onRemove,
}: {
  line: PackingSuggestionLine
  pending: boolean
  onQty: (itemId: string, quantidade: number) => void
  onRemove: (itemId: string) => void
}) {
  return (
    <tr style={{ borderTop: '1px solid var(--glass-border)' }}>
      <Td strong>{line.nome}</Td>
      <Td mono>{line.codigoInterno ?? '·'}</Td>
      <Td>{line.categoria}</Td>
      <Td align="right">
        <QuantityInput line={line} pending={pending} onQty={onQty} />
      </Td>
      <Td>{line.observacao ?? '·'}</Td>
      <Td align="right">
        <IconRemoveButton pending={pending} label={line.nome} onClick={() => onRemove(line.itemId)} />
      </Td>
    </tr>
  )
}

function SuggestionMobileRow({
  line,
  pending,
  onQty,
  onRemove,
}: {
  line: PackingSuggestionLine
  pending: boolean
  onQty: (itemId: string, quantidade: number) => void
  onRemove: (itemId: string) => void
}) {
  return (
    <div
      style={{
        padding: 12,
        borderTop: '1px solid var(--glass-border)',
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
      }}
    >
      <div style={{ display: 'flex', gap: 10 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ color: 'var(--fg-0)', fontSize: 13, fontWeight: 500 }}>{line.nome}</div>
          <div className="mono" style={{ color: 'var(--fg-3)', fontSize: 10, marginTop: 4 }}>
            {line.codigoInterno ?? 'sem código'} · {line.categoria}
          </div>
        </div>
        <IconRemoveButton pending={pending} label={line.nome} onClick={() => onRemove(line.itemId)} />
      </div>
      <QuantityInput line={line} pending={pending} onQty={onQty} />
      {line.observacao && <div style={{ color: 'var(--fg-3)', fontSize: 12 }}>{line.observacao}</div>}
    </div>
  )
}

function QuantityInput({
  line,
  pending,
  onQty,
}: {
  line: PackingSuggestionLine
  pending: boolean
  onQty: (itemId: string, quantidade: number) => void
}) {
  return (
    <input
      type="number"
      min={1}
      step={1}
      value={line.quantidade}
      disabled={pending}
      aria-label={`Quantidade sugerida para ${line.nome}`}
      onChange={(event) => onQty(line.itemId, Number(event.currentTarget.value))}
      style={{
        ...INPUT_STYLE,
        width: 76,
        textAlign: 'right',
      }}
    />
  )
}

function IconRemoveButton({
  label,
  pending,
  onClick,
}: {
  label: string
  pending: boolean
  onClick: () => void
}) {
  return (
    <button
      type="button"
      aria-label={`Remover ${label} da proposta`}
      disabled={pending}
      onClick={onClick}
      style={iconButtonStyle}
    >
      <Trash2 size={14} />
    </button>
  )
}

function PanelHeader({ title, meta }: { title: string; meta: string }) {
  return (
    <div
      style={{
        padding: '10px 12px',
        borderBottom: '1px solid var(--glass-border)',
        display: 'flex',
        justifyContent: 'space-between',
        gap: 10,
      }}
    >
      <span style={{ color: 'var(--fg-0)', fontSize: 13, fontWeight: 500 }}>{title}</span>
      <span className="mono" style={{ color: 'var(--fg-3)', fontSize: 10 }}>
        {meta}
      </span>
    </div>
  )
}

function EmptyState({ text }: { text: string }) {
  return <div style={{ padding: 16, color: 'var(--fg-3)', fontSize: 12 }}>{text}</div>
}

function Th({
  children,
  align = 'left',
  mono = false,
}: {
  children: React.ReactNode
  align?: 'left' | 'right'
  mono?: boolean
}) {
  return (
    <th
      className={mono ? 'mono' : undefined}
      style={{
        padding: 10,
        textAlign: align,
        fontSize: 10,
        letterSpacing: 0.12,
        textTransform: 'uppercase',
        color: 'var(--fg-3)',
        fontWeight: 500,
      }}
    >
      {children}
    </th>
  )
}

function Td({
  children,
  align = 'left',
  mono = false,
  strong = false,
}: {
  children: React.ReactNode
  align?: 'left' | 'right'
  mono?: boolean
  strong?: boolean
}) {
  return (
    <td
      className={mono ? 'mono' : undefined}
      style={{
        padding: 10,
        textAlign: align,
        color: strong ? 'var(--fg-0)' : 'var(--fg-2)',
        fontWeight: strong ? 500 : 400,
        verticalAlign: 'top',
        maxWidth: strong ? 260 : 180,
      }}
    >
      {children}
    </td>
  )
}

const primaryButtonStyle: React.CSSProperties = {
  minHeight: 34,
  borderRadius: 8,
  border: 'none',
  padding: '8px 12px',
  fontFamily: 'inherit',
  fontSize: 12,
  cursor: 'pointer',
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  gap: 7,
}

const iconButtonStyle: React.CSSProperties = {
  width: 32,
  height: 32,
  borderRadius: 8,
  border: '1px solid var(--glass-border)',
  background: 'var(--glass-bg)',
  color: 'var(--fg-3)',
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  cursor: 'pointer',
}
