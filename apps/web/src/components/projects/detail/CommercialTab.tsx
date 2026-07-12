'use client'

import type { CSSProperties, FormEvent } from 'react'
import { useMemo, useRef, useState, useTransition } from 'react'
import { Btn, GlassCard, Ring, StatusDot } from '@/components/mmd/Primitives'
import { saveEventoComercial } from '@/lib/actions/projetos'
import {
  COMERCIAL_STATUS_OPTIONS,
  comercialReadinessPct,
  comercialStatusLabel,
  statusAllowsEstoque,
  type ComercialStatus,
  type EventoComercialDocumento,
} from '@/lib/evento-comercial-core'
import type { ProjectDetail } from '@/lib/data/project-detail'

const inputStyle: CSSProperties = {
  width: '100%',
  minWidth: 0,
  border: '1px solid var(--glass-border)',
  borderRadius: 8,
  background: 'var(--glass-bg)',
  color: 'var(--fg-0)',
  padding: '10px 12px',
  font: 'inherit',
  outline: 'none',
}

const labelStyle: CSSProperties = {
  display: 'block',
  marginBottom: 7,
  fontSize: 10,
  color: 'var(--fg-3)',
  letterSpacing: 0.1,
  textTransform: 'uppercase',
}

function commercialLink(docs: EventoComercialDocumento[], tipo: EventoComercialDocumento['tipo']) {
  return docs.find((doc) => doc.tipo === tipo && doc.origem === 'LINK')?.url ?? ''
}

function formatBytes(value: number | null) {
  if (!value) return ''
  if (value < 1024) return `${value} B`
  if (value < 1024 * 1024) return `${Math.round(value / 1024)} KB`
  return `${(value / (1024 * 1024)).toFixed(1)} MB`
}

function documentLabel(doc: EventoComercialDocumento) {
  const tipo = doc.tipo === 'ORCAMENTO' ? 'Orçamento' : 'Contrato'
  return doc.filename ?? doc.url ?? tipo
}

export function CommercialTab({
  projeto,
  onDone,
}: {
  projeto: ProjectDetail
  onDone: () => void
}) {
  const formRef = useRef<HTMLFormElement>(null)
  const comercial = projeto.comercial
  const initialStatus = comercial.status ?? 'ORCAMENTO_ENVIADO'
  const [status, setStatus] = useState<ComercialStatus>(initialStatus)
  const [orcamentoUrl, setOrcamentoUrl] = useState(commercialLink(comercial.documentos, 'ORCAMENTO'))
  const [contratoUrl, setContratoUrl] = useState(commercialLink(comercial.documentos, 'CONTRATO'))
  const [observacoes, setObservacoes] = useState(comercial.observacoes ?? '')
  const [feedback, setFeedback] = useState<{ tone: 'ok' | 'error'; text: string } | null>(null)
  const [pending, startTransition] = useTransition()

  const readiness = comercialReadinessPct(status)
  const allowsStock = statusAllowsEstoque(status)
  const statusIndex = COMERCIAL_STATUS_OPTIONS.findIndex((option) => option.value === status)

  const docsByType = useMemo(
    () => ({
      orcamento: comercial.documentos.filter((doc) => doc.tipo === 'ORCAMENTO'),
      contrato: comercial.documentos.filter((doc) => doc.tipo === 'CONTRATO'),
    }),
    [comercial.documentos],
  )

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!formRef.current) return
    const formData = new FormData(formRef.current)
    formData.set('projetoId', projeto.id)
    formData.set('status', status)
    formData.set('orcamentoUrl', orcamentoUrl)
    formData.set('contratoUrl', contratoUrl)
    formData.set('observacoes', observacoes)

    setFeedback(null)
    startTransition(() => {
      void saveEventoComercial(formData).then((result) => {
        if (!result.ok) {
          setFeedback({ tone: 'error', text: result.error })
          return
        }
        setFeedback({ tone: 'ok', text: 'Comercial salvo no Evento.' })
        onDone()
      })
    })
  }

  return (
    <form ref={formRef} onSubmit={handleSubmit} style={{ display: 'grid', gap: 16 }}>
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 520px), 1fr))',
          gap: 16,
          alignItems: 'start',
        }}
      >
        <div style={{ display: 'grid', gap: 16, minWidth: 0 }}>
          <GlassCard style={{ padding: 20 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
              <div>
                <div style={{ fontSize: 15, color: 'var(--fg-0)', marginBottom: 4 }}>
                  Status comercial
                </div>
                <div style={{ fontSize: 12, color: 'var(--fg-3)' }}>
                  Orçamento aprovado libera preparação de estoque.
                </div>
              </div>
              <label style={{ minWidth: 220 }}>
                <span style={labelStyle}>Status atual</span>
                <select
                  name="status"
                  value={status}
                  onChange={(event) => setStatus(event.target.value as ComercialStatus)}
                  style={inputStyle}
                >
                  {COMERCIAL_STATUS_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>
            </div>

            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 160px), 1fr))',
                gap: 10,
                marginTop: 20,
              }}
            >
              {COMERCIAL_STATUS_OPTIONS.map((option, index) => {
                const done = index <= statusIndex
                return (
                  <div
                    key={option.value}
                    style={{
                      border: '1px solid var(--glass-border)',
                      borderRadius: 8,
                      padding: 12,
                      background: done
                        ? 'color-mix(in oklch, var(--accent-green) 10%, transparent)'
                        : 'var(--glass-bg)',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <StatusDot color={done ? 'var(--accent-green)' : 'var(--fg-3)'} size={7} />
                      <span style={{ fontSize: 13, color: done ? 'var(--fg-0)' : 'var(--fg-2)' }}>
                        {option.label}
                      </span>
                    </div>
                    <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', marginTop: 7 }}>
                      etapa {index + 1} de 4
                    </div>
                  </div>
                )
              })}
            </div>
          </GlassCard>

          <GlassCard style={{ padding: 20 }}>
            <div style={{ fontSize: 15, color: 'var(--fg-0)', marginBottom: 16 }}>
              Documentos e links
            </div>
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 280px), 1fr))',
                gap: 14,
              }}
            >
              <DocumentField
                label="Link orçamento"
                name="orcamentoUrl"
                value={orcamentoUrl}
                onChange={setOrcamentoUrl}
              />
              <FileField label="Anexar orçamento" name="orcamentoFile" />
              <DocumentField
                label="Link contrato"
                name="contratoUrl"
                value={contratoUrl}
                onChange={setContratoUrl}
              />
              <FileField label="Anexar contrato" name="contratoFile" />
            </div>

            <DocumentList title="Documentos salvos" docs={[...docsByType.orcamento, ...docsByType.contrato]} />
          </GlassCard>

          <GlassCard style={{ padding: 20 }}>
            <label>
              <span style={labelStyle}>Observações comerciais</span>
              <textarea
                name="observacoes"
                value={observacoes}
                onChange={(event) => setObservacoes(event.target.value)}
                rows={5}
                style={{ ...inputStyle, resize: 'vertical', lineHeight: 1.45 }}
              />
            </label>
          </GlassCard>
        </div>

        <GlassCard style={{ padding: 20, position: 'sticky', top: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 18 }}>
            <Ring
              value={readiness}
              size={96}
              stroke={8}
              label="comercial"
              state={allowsStock ? 'ready' : 'partial'}
              ariaLabel={`Prontidão comercial ${readiness}%`}
            />
            <div>
              <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.1 }}>
                STATUS ATUAL
              </div>
              <div style={{ marginTop: 6, color: 'var(--fg-0)', fontSize: 16 }}>
                {comercialStatusLabel(status)}
              </div>
              <div style={{ marginTop: 4, fontSize: 12, color: allowsStock ? 'var(--accent-green)' : 'var(--fg-2)' }}>
                {allowsStock ? 'Estoque pode ser preparado.' : 'Aguardando aprovação.'}
              </div>
            </div>
          </div>

          <div
            style={{
              borderTop: '1px solid var(--glass-border)',
              paddingTop: 14,
              display: 'grid',
              gap: 10,
            }}
          >
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.1 }}>
              DOCUMENTOS
            </div>
            {comercial.documentos.length === 0 ? (
              <div style={{ fontSize: 12, color: 'var(--fg-3)' }}>Nenhum documento salvo.</div>
            ) : (
              comercial.documentos.slice(0, 4).map((doc) => <DocumentChip key={doc.id} doc={doc} />)
            )}
          </div>

          <div
            style={{
              borderTop: '1px solid var(--glass-border)',
              marginTop: 16,
              paddingTop: 14,
              display: 'grid',
              gap: 10,
            }}
          >
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.1 }}>
              PRÓXIMO PASSO
            </div>
            <div
              style={{
                border: '1px solid var(--glass-border)',
                borderRadius: 8,
                padding: 12,
                background: allowsStock
                  ? 'color-mix(in oklch, var(--accent-violet) 18%, transparent)'
                  : 'var(--glass-bg)',
              }}
            >
              <div style={{ color: 'var(--fg-0)', fontSize: 14 }}>
                {allowsStock ? 'Preparar estoque' : 'Aprovar orçamento'}
              </div>
              <div style={{ color: 'var(--fg-3)', fontSize: 12, marginTop: 4 }}>
                {allowsStock
                  ? 'Packing e alocação podem avançar.'
                  : 'Sem aprovação, estoque não deve sair da preparação.'}
              </div>
            </div>
          </div>

          {feedback && (
            <div
              role={feedback.tone === 'error' ? 'alert' : 'status'}
              style={{
                marginTop: 14,
                padding: '10px 12px',
                borderRadius: 8,
                border: `1px solid ${
                  feedback.tone === 'error'
                    ? 'color-mix(in oklch, var(--accent-red) 35%, transparent)'
                    : 'color-mix(in oklch, var(--accent-green) 35%, transparent)'
                }`,
                color: feedback.tone === 'error' ? 'var(--accent-red)' : 'var(--accent-green)',
                background:
                  feedback.tone === 'error'
                    ? 'color-mix(in oklch, var(--accent-red) 10%, transparent)'
                    : 'color-mix(in oklch, var(--accent-green) 10%, transparent)',
                fontSize: 12,
              }}
            >
              {feedback.text}
            </div>
          )}

          <Btn type="submit" disabled={pending} style={{ width: '100%', marginTop: 14 }}>
            {pending ? 'Salvando' : 'Salvar comercial'}
          </Btn>
        </GlassCard>
      </div>
    </form>
  )
}

function DocumentField({
  label,
  name,
  value,
  onChange,
}: {
  label: string
  name: string
  value: string
  onChange: (value: string) => void
}) {
  return (
    <label style={{ minWidth: 0 }}>
      <span style={labelStyle}>{label}</span>
      <input
        name={name}
        type="url"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder="https://"
        style={inputStyle}
      />
    </label>
  )
}

function FileField({ label, name }: { label: string; name: string }) {
  const [fileName, setFileName] = useState('')

  return (
    <label style={{ minWidth: 0 }}>
      <span style={labelStyle}>{label}</span>
      <input
        name={name}
        type="file"
        accept=".pdf,.doc,.docx,image/png,image/jpeg"
        onChange={(event) => setFileName(event.target.files?.[0]?.name ?? '')}
        style={{
          position: 'absolute',
          opacity: 0,
          pointerEvents: 'none',
          width: 1,
          height: 1,
        }}
      />
      <span
        style={{
          ...inputStyle,
          display: 'grid',
          gridTemplateColumns: 'auto minmax(0, 1fr)',
          gap: 10,
          alignItems: 'center',
          cursor: 'pointer',
        }}
      >
        <span
          style={{
            borderRadius: 7,
            padding: '6px 10px',
            background: 'var(--glass-bg-strong)',
            color: 'var(--fg-0)',
            fontSize: 12,
            whiteSpace: 'nowrap',
          }}
        >
          Selecionar arquivo
        </span>
        <span
          style={{
            minWidth: 0,
            color: fileName ? 'var(--fg-1)' : 'var(--fg-3)',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {fileName || 'Nenhum arquivo selecionado'}
        </span>
      </span>
    </label>
  )
}

function DocumentList({ title, docs }: { title: string; docs: EventoComercialDocumento[] }) {
  return (
    <div style={{ marginTop: 18 }}>
      <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.1, marginBottom: 8 }}>
        {title}
      </div>
      {docs.length === 0 ? (
        <div style={{ fontSize: 12, color: 'var(--fg-3)' }}>Nenhum documento salvo ainda.</div>
      ) : (
        <div style={{ display: 'grid', gap: 8 }}>
          {docs.map((doc) => (
            <DocumentChip key={doc.id} doc={doc} />
          ))}
        </div>
      )}
    </div>
  )
}

function DocumentChip({ doc }: { doc: EventoComercialDocumento }) {
  const meta = [doc.origem === 'UPLOAD' ? 'Anexo' : 'Link', formatBytes(doc.tamanho_bytes)]
    .filter(Boolean)
    .join(' · ')

  const content = (
    <>
      <span style={{ color: 'var(--fg-0)', fontSize: 13, overflow: 'hidden', textOverflow: 'ellipsis' }}>
        {documentLabel(doc)}
      </span>
      <span className="mono" style={{ color: 'var(--fg-3)', fontSize: 10 }}>
        {meta || doc.titulo}
      </span>
    </>
  )

  const style: CSSProperties = {
    minWidth: 0,
    display: 'grid',
    gap: 3,
    border: '1px solid var(--glass-border)',
    borderRadius: 8,
    padding: '10px 12px',
    background: 'var(--glass-bg)',
    textDecoration: 'none',
  }

  if (doc.href) {
    return (
      <a href={doc.href} target="_blank" rel="noreferrer" style={style}>
        {content}
      </a>
    )
  }

  return <div style={style}>{content}</div>
}
