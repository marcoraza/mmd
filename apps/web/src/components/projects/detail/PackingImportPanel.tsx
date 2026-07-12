'use client'

import { useMemo, useRef, useState, useTransition } from 'react'
import { AlertCircle, CheckCircle2, FileSpreadsheet, Upload, X } from 'lucide-react'
import {
  applyPackingImport,
  previewPackingImport,
  type ApplyPackingImportLineInput,
} from '@/lib/actions/projetos'
import {
  PACKING_IMPORT_ACCEPT,
  PACKING_IMPORT_COLUMNS,
  buildPackingImportApprovals,
  unresolvedPackingImportRows,
  type PackingImportPreview,
  type PackingImportResolution,
  type PackingImportRow,
} from '@/lib/packing-import-core'

const INPUT_STYLE: React.CSSProperties = {
  padding: '8px 10px',
  borderRadius: 8,
  border: '1px solid var(--glass-border)',
  background: 'var(--glass-bg)',
  color: 'var(--fg-0)',
  fontFamily: 'inherit',
  fontSize: 12,
  outline: 'none',
}

const STATUS_META = {
  matched: {
    label: 'Aprovada',
    color: 'var(--accent-green)',
    bg: 'color-mix(in oklch, var(--accent-green) 12%, transparent)',
  },
  ambiguous: {
    label: 'Ambígua',
    color: 'var(--accent-amber)',
    bg: 'color-mix(in oklch, var(--accent-amber) 12%, transparent)',
  },
  invalid: {
    label: 'Com erro',
    color: 'var(--accent-red)',
    bg: 'color-mix(in oklch, var(--accent-red) 12%, transparent)',
  },
} as const

export function PackingImportPanel({
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
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [fileMeta, setFileMeta] = useState<{ name: string; size: number } | null>(null)
  const [preview, setPreview] = useState<PackingImportPreview | null>(null)
  const [resolutions, setResolutions] = useState<Record<number, string>>({})
  const [pending, startTransition] = useTransition()

  const resolutionList = useMemo<PackingImportResolution[]>(
    () =>
      Object.entries(resolutions)
        .filter(([, itemId]) => itemId)
        .map(([rowNumber, itemId]) => ({ rowNumber: Number(rowNumber), itemId })),
    [resolutions],
  )
  const unresolvedRows = preview ? unresolvedPackingImportRows(preview.rows, resolutionList) : []
  const approvals = preview ? buildPackingImportApprovals(preview.rows, resolutionList) : []
  const canApply = Boolean(preview && approvals.length > 0 && unresolvedRows.length === 0 && !pending)

  function handleFile(file: File | null) {
    if (!file) return
    onError(null)
    setFileMeta({ name: file.name, size: file.size })
    setPreview(null)
    setResolutions({})

    const formData = new FormData()
    formData.append('file', file)

    startTransition(async () => {
      const result = await previewPackingImport(formData)
      if (!result.ok) {
        onError(result.error)
        return
      }
      setPreview(result.data)
    })
  }

  function handleApply() {
    if (!preview) return
    if (unresolvedRows.length > 0) {
      onError('Revise as linhas ambíguas antes de aplicar.')
      return
    }
    if (approvals.length === 0) {
      onError('Nenhuma linha aprovada para aplicar.')
      return
    }

    const lines: ApplyPackingImportLineInput[] = approvals.map((approval) => ({
      itemId: approval.itemId,
      quantidade: approval.quantidade,
      observacao: approval.observacao,
    }))

    onError(null)
    startTransition(async () => {
      const result = await applyPackingImport(projetoId, lines)
      if (!result.ok) {
        onError(result.error)
        return
      }
      setPreview(null)
      setFileMeta(null)
      setResolutions({})
      onApplied()
    })
  }

  return (
    <div
      style={{
        padding: 16,
        borderBottom: '1px solid var(--glass-border)',
        background: 'color-mix(in oklch, var(--accent-cyan) 4%, transparent)',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, marginBottom: 12 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ color: 'var(--fg-0)', fontSize: 14, fontWeight: 500 }}>
            Importar planilha
          </div>
          <div className="mono" style={{ marginTop: 4, color: 'var(--fg-3)', fontSize: 10 }}>
            {PACKING_IMPORT_COLUMNS.join(' · ')}
          </div>
        </div>
        <button
          type="button"
          aria-label="Fechar importação"
          onClick={onClose}
          style={iconButtonStyle}
        >
          <X size={16} />
        </button>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'minmax(260px, 1fr) minmax(280px, 1.15fr)',
          gap: 12,
        }}
        className="packing-import-top"
      >
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          disabled={pending}
          style={{
            minHeight: 128,
            borderRadius: 8,
            border: '1px dashed color-mix(in oklch, var(--accent-cyan) 55%, var(--glass-border))',
            background: 'color-mix(in oklch, var(--accent-cyan) 7%, transparent)',
            color: 'var(--fg-0)',
            fontFamily: 'inherit',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
            cursor: pending ? 'wait' : 'pointer',
          }}
        >
          <Upload size={20} color="var(--accent-cyan)" />
          <span style={{ fontSize: 13 }}>Solte a planilha padrão ou selecione arquivo</span>
          <span className="mono" style={{ color: 'var(--fg-3)', fontSize: 10 }}>
            XLSX, CSV, TSV · até 10 MB
          </span>
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept={PACKING_IMPORT_ACCEPT}
          style={{ display: 'none' }}
          onChange={(event) => handleFile(event.currentTarget.files?.[0] ?? null)}
        />

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, minWidth: 0 }}>
          <FileRow fileMeta={fileMeta} pending={pending} />
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
              gap: 8,
            }}
            className="packing-import-summary"
          >
            <SummaryCell
              label="Aprovadas"
              value={preview?.summary.matched ?? 0}
              tone="matched"
            />
            <SummaryCell
              label="Ambíguas"
              value={preview?.summary.ambiguous ?? 0}
              tone="ambiguous"
            />
            <SummaryCell label="Com erro" value={preview?.summary.invalid ?? 0} tone="invalid" />
            <SummaryCell label="Total" value={preview?.summary.total ?? 0} />
          </div>
        </div>
      </div>

      {preview && (
        <div
          style={{
            marginTop: 12,
            border: '1px solid var(--glass-border)',
            borderRadius: 8,
            overflow: 'hidden',
            background: 'var(--bg-0)',
          }}
        >
          <div
            style={{
              padding: '10px 12px',
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              borderBottom: '1px solid var(--glass-border)',
              flexWrap: 'wrap',
            }}
          >
            <div style={{ color: 'var(--fg-0)', fontSize: 13, fontWeight: 500 }}>Preview</div>
            <div className="mono" style={{ color: 'var(--fg-3)', fontSize: 10 }}>
              {approvals.length} linhas aprovadas · {preview.summary.approvedQuantity} unidades
            </div>
            <div style={{ flex: 1 }} />
            {preview.summary.invalid > 0 && (
              <span style={{ color: 'var(--fg-3)', fontSize: 11 }}>
                Linhas com erro não entram na aplicação.
              </span>
            )}
            <button
              type="button"
              onClick={handleApply}
              disabled={!canApply}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 7,
                minHeight: 34,
                padding: '8px 14px',
                borderRadius: 8,
                border: 'none',
                background: canApply ? 'var(--fg-0)' : 'var(--glass-border)',
                color: canApply ? 'var(--bg-0)' : 'var(--fg-3)',
                fontFamily: 'inherit',
                fontSize: 12,
                cursor: canApply ? 'pointer' : 'not-allowed',
              }}
            >
              <CheckCircle2 size={15} />
              {pending ? 'Aplicando' : 'Aplicar ao packing'}
            </button>
          </div>

          <div className="packing-import-table" style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
              <thead>
                <tr style={{ background: 'var(--glass-bg)' }}>
                  <Th>#</Th>
                  <Th mono>Código</Th>
                  <Th>Categoria</Th>
                  <Th>Item</Th>
                  <Th>Subcategoria</Th>
                  <Th>Marca</Th>
                  <Th>Modelo</Th>
                  <Th align="right">Qtd</Th>
                  <Th>Obs</Th>
                  <Th>Status</Th>
                  <Th>Ação</Th>
                </tr>
              </thead>
              <tbody>
                {preview.rows.map((row) => (
                  <PreviewTableRow
                    key={row.rowNumber}
                    row={row}
                    selectedId={resolutions[row.rowNumber] ?? ''}
                    onSelect={(itemId) =>
                      setResolutions((current) => ({ ...current, [row.rowNumber]: itemId }))
                    }
                  />
                ))}
              </tbody>
            </table>
          </div>

          <div className="packing-import-mobile">
            {preview.rows.map((row) => (
              <PreviewMobileRow
                key={row.rowNumber}
                row={row}
                selectedId={resolutions[row.rowNumber] ?? ''}
                onSelect={(itemId) =>
                  setResolutions((current) => ({ ...current, [row.rowNumber]: itemId }))
                }
              />
            ))}
          </div>
        </div>
      )}

      <style>{`
        @media (max-width: 860px) {
          .packing-import-top {
            grid-template-columns: 1fr !important;
          }

          .packing-import-summary {
            grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
          }
        }

        .packing-import-mobile {
          display: none;
        }

        @media (max-width: 760px) {
          .packing-import-table {
            display: none;
          }

          .packing-import-mobile {
            display: flex;
            flex-direction: column;
          }
        }
      `}</style>
    </div>
  )
}

function FileRow({
  fileMeta,
  pending,
}: {
  fileMeta: { name: string; size: number } | null
  pending: boolean
}) {
  return (
    <div
      style={{
        minHeight: 52,
        borderRadius: 8,
        border: '1px solid var(--glass-border)',
        background: 'var(--glass-bg)',
        padding: '9px 10px',
        display: 'flex',
        alignItems: 'center',
        gap: 10,
      }}
    >
      <FileSpreadsheet size={20} color="var(--accent-green)" />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            color: fileMeta ? 'var(--fg-0)' : 'var(--fg-3)',
            fontSize: 12,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {fileMeta ? fileMeta.name : 'Nenhum arquivo selecionado'}
        </div>
        <div className="mono" style={{ marginTop: 2, color: 'var(--fg-3)', fontSize: 10 }}>
          {pending ? 'Lendo planilha' : fileMeta ? formatBytes(fileMeta.size) : 'Aguardando upload'}
        </div>
      </div>
    </div>
  )
}

function SummaryCell({
  label,
  value,
  tone,
}: {
  label: string
  value: number
  tone?: keyof typeof STATUS_META
}) {
  const meta = tone ? STATUS_META[tone] : null
  return (
    <div
      style={{
        minHeight: 58,
        borderRadius: 8,
        border: '1px solid var(--glass-border)',
        background: meta?.bg ?? 'var(--glass-bg)',
        padding: 10,
      }}
    >
      <div
        className="mono"
        style={{ color: meta?.color ?? 'var(--fg-3)', fontSize: 18, fontWeight: 700 }}
      >
        {value}
      </div>
      <div style={{ color: 'var(--fg-2)', fontSize: 11, marginTop: 2 }}>{label}</div>
    </div>
  )
}

function PreviewTableRow({
  row,
  selectedId,
  onSelect,
}: {
  row: PackingImportRow
  selectedId: string
  onSelect: (itemId: string) => void
}) {
  return (
    <tr style={{ borderTop: '1px solid var(--glass-border)' }}>
      <Td mono>{row.rowNumber}</Td>
      <Td mono>{row.input.codigo_mmd || '·'}</Td>
      <Td>{row.input.categoria || '·'}</Td>
      <Td strong>{row.input.item || row.match?.nome || '·'}</Td>
      <Td>{row.input.subcategoria || '·'}</Td>
      <Td>{row.input.marca || '·'}</Td>
      <Td>{row.input.modelo || '·'}</Td>
      <Td mono align="right">
        {row.input.quantidade || '·'}
      </Td>
      <Td>{row.input.observacao || '·'}</Td>
      <Td>
        <StatusPill row={row} />
      </Td>
      <Td>
        <RowAction row={row} selectedId={selectedId} onSelect={onSelect} />
      </Td>
    </tr>
  )
}

function PreviewMobileRow({
  row,
  selectedId,
  onSelect,
}: {
  row: PackingImportRow
  selectedId: string
  onSelect: (itemId: string) => void
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
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ color: 'var(--fg-0)', fontSize: 13, fontWeight: 500 }}>
            {row.input.item || row.match?.nome || 'Linha sem item'}
          </div>
          <div className="mono" style={{ color: 'var(--fg-3)', fontSize: 10, marginTop: 4 }}>
            Linha {row.rowNumber} · {row.input.codigo_mmd || 'sem código'} · qtd{' '}
            {row.input.quantidade || '·'}
          </div>
        </div>
        <StatusPill row={row} />
      </div>
      <div style={{ color: 'var(--fg-2)', fontSize: 12 }}>
        {[row.input.categoria, row.input.subcategoria, row.input.marca, row.input.modelo]
          .filter(Boolean)
          .join(' · ') || 'Sem contexto textual'}
      </div>
      {row.input.observacao && (
        <div style={{ color: 'var(--fg-3)', fontSize: 12 }}>{row.input.observacao}</div>
      )}
      <RowAction row={row} selectedId={selectedId} onSelect={onSelect} />
    </div>
  )
}

function RowAction({
  row,
  selectedId,
  onSelect,
}: {
  row: PackingImportRow
  selectedId: string
  onSelect: (itemId: string) => void
}) {
  if (row.status === 'matched') {
    return (
      <span className="mono" style={{ color: 'var(--fg-3)', fontSize: 10 }}>
        {row.match.codigo_interno ?? row.match.nome}
      </span>
    )
  }

  if (row.status === 'invalid') {
    return (
      <span style={{ color: 'var(--accent-red)', fontSize: 11 }}>
        {row.errors[0] ?? 'Linha inválida.'}
      </span>
    )
  }

  return (
    <select
      value={selectedId}
      onChange={(event) => onSelect(event.currentTarget.value)}
      style={{ ...INPUT_STYLE, minWidth: 180, width: '100%' }}
      aria-label={`Escolha do catálogo para linha ${row.rowNumber}`}
    >
      <option value="">Revisar escolha</option>
      {row.candidates.map((candidate) => (
        <option key={candidate.id} value={candidate.id}>
          {candidate.codigo_interno ?? 'Sem código'} · {candidate.nome}
        </option>
      ))}
    </select>
  )
}

function StatusPill({ row }: { row: PackingImportRow }) {
  const meta = STATUS_META[row.status]
  const Icon = row.status === 'invalid' ? AlertCircle : CheckCircle2
  return (
    <span
      className="mono"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        color: meta.color,
        fontSize: 10,
        whiteSpace: 'nowrap',
      }}
    >
      <Icon size={12} />
      {meta.label}
    </span>
  )
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
        maxWidth: strong ? 220 : 160,
      }}
    >
      {children}
    </td>
  )
}

function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`
}

const iconButtonStyle: React.CSSProperties = {
  width: 32,
  height: 32,
  borderRadius: 8,
  border: '1px solid var(--glass-border)',
  background: 'var(--glass-bg)',
  color: 'var(--fg-2)',
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  cursor: 'pointer',
}
