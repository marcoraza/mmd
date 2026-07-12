'use client'

import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useMemo, useState, useTransition } from 'react'
import { saveEventoFicha } from '@/lib/actions/projetos'
import {
  calculateFichaCompleteness,
  emptyEventoFichaInput,
  STATUS_PROJETO_OPTIONS,
  type EventoChecklistItem,
  type EventoFichaInput,
  type StatusProjeto,
} from '@/lib/evento-ficha-core'
import { Caustic, GlassCard, Ring, StatusDot } from '@/components/mmd/Primitives'
import { TopBar } from '@/components/mmd/TopBar'

const STORAGE_KEY = 'mmd-ficha-evento-v2'

const FIELD_STYLE: React.CSSProperties = {
  width: '100%',
  minHeight: 42,
  border: '1px solid var(--glass-border)',
  borderRadius: 8,
  background: 'color-mix(in oklch, var(--glass-bg) 72%, transparent)',
  color: 'var(--fg-0)',
  padding: '9px 11px',
  fontFamily: 'inherit',
  fontSize: 14,
  outline: 'none',
}

function todayIso() {
  return new Date().toISOString().slice(0, 10)
}

function coerceDraft(raw: unknown): EventoFichaInput {
  const base = emptyEventoFichaInput(todayIso())
  if (!raw || typeof raw !== 'object') return base
  const draft = raw as Partial<EventoFichaInput>
  return {
    ...base,
    ...draft,
    statusInicial: draft.statusInicial ?? base.statusInicial,
    checklist: Array.from({ length: Math.max(8, draft.checklist?.length ?? 0) }, (_, index) => ({
      item: draft.checklist?.[index]?.item ?? '',
      responsavel: draft.checklist?.[index]?.responsavel ?? '',
      ok: Boolean(draft.checklist?.[index]?.ok),
    })),
  }
}

function loadInitialState(): EventoFichaInput {
  if (typeof window === 'undefined') return emptyEventoFichaInput()
  const raw = window.localStorage.getItem(STORAGE_KEY)
  if (!raw) return emptyEventoFichaInput(todayIso())
  try {
    return coerceDraft(JSON.parse(raw))
  } catch {
    window.localStorage.removeItem(STORAGE_KEY)
    return emptyEventoFichaInput(todayIso())
  }
}

function statusLabel(status: StatusProjeto) {
  return STATUS_PROJETO_OPTIONS.find((option) => option.value === status)?.label ?? status
}

function formatRange(form: EventoFichaInput) {
  if (!form.dataInicial && !form.dataFinal) return 'Sem período'
  if (form.dataInicial === form.dataFinal) return form.dataInicial || form.dataFinal
  return `${form.dataInicial || '-'} até ${form.dataFinal || '-'}`
}

export default function FichaEventoPage() {
  const router = useRouter()
  const [form, setForm] = useState<EventoFichaInput>(loadInitialState)
  const [isPending, startTransition] = useTransition()
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const completeness = useMemo(() => calculateFichaCompleteness(form), [form])
  const savedProjectId = form.projetoId?.trim() || null

  function commitForm(next: EventoFichaInput) {
    setForm(next)
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next))
    }
    setMessage('Rascunho local atualizado')
  }

  function updateField<K extends keyof EventoFichaInput>(key: K, value: EventoFichaInput[K]) {
    commitForm({ ...form, [key]: value })
  }

  function updateChecklist(index: number, patch: Partial<EventoChecklistItem>) {
    commitForm({
      ...form,
      checklist: form.checklist.map((row, rowIndex) =>
        rowIndex === index ? { ...row, ...patch } : row,
      ),
    })
  }

  function resetForm() {
    const next = emptyEventoFichaInput(todayIso())
    setForm(next)
    setMessage(null)
    setError(null)
    if (typeof window !== 'undefined') window.localStorage.removeItem(STORAGE_KEY)
  }

  function handleSubmit(event: React.FormEvent) {
    event.preventDefault()
    setError(null)
    setMessage(null)

    startTransition(async () => {
      const result = await saveEventoFicha(form)
      if (!result.ok) {
        setError(result.error)
        return
      }
      const next = { ...form, projetoId: result.data.id }
      setForm(next)
      if (typeof window !== 'undefined') {
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next))
      }
      setMessage(`Evento salvo com ${result.data.completenessPct}% da ficha preenchida`)
      router.refresh()
    })
  }

  return (
    <div style={{ position: 'relative', minHeight: '100dvh' }}>
      <Caustic orb3 />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          padding: 'clamp(20px, 3vw, 28px) clamp(20px, 4vw, 48px)',
        }}
      >
        <TopBar kicker="MMD Eventos" title="Ficha do evento" notifications={0} />

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            marginTop: 14,
            marginBottom: 18,
            fontSize: 12,
            color: 'var(--fg-2)',
            flexWrap: 'wrap',
          }}
        >
          <Link href="/projetos" style={{ color: 'var(--fg-2)', textDecoration: 'none' }}>
            Eventos
          </Link>
          <span style={{ color: 'var(--fg-3)' }}>/</span>
          <span style={{ color: 'var(--fg-0)' }}>{savedProjectId ? 'Editar ficha' : 'Nova ficha'}</span>
        </div>

        <form
          onSubmit={handleSubmit}
          style={{
            display: 'grid',
            gridTemplateColumns: 'minmax(0, 1fr) minmax(280px, 360px)',
            gap: 18,
            alignItems: 'start',
          }}
        >
          <div style={{ display: 'grid', gap: 14, minWidth: 0 }}>
            <GlassCard strong style={{ padding: 18 }}>
              <SectionTitle title="Evento no sistema" />
              <div className="event-form-grid two">
                <Field
                  label="Nome do evento"
                  value={form.nomeEvento}
                  onChange={(value) => updateField('nomeEvento', value)}
                  required
                />
                <Field
                  label="Cliente ou empresa"
                  value={form.cliente}
                  onChange={(value) => updateField('cliente', value)}
                  required
                />
                <Field
                  label="Data inicial"
                  type="date"
                  value={form.dataInicial}
                  onChange={(value) => updateField('dataInicial', value)}
                  required
                />
                <Field
                  label="Data final"
                  type="date"
                  value={form.dataFinal}
                  onChange={(value) => updateField('dataFinal', value)}
                  required
                />
                <label style={{ display: 'grid', gap: 6 }}>
                  <Label>Status inicial</Label>
                  <select
                    value={form.statusInicial}
                    onChange={(event) =>
                      updateField('statusInicial', event.target.value as StatusProjeto)
                    }
                    style={FIELD_STYLE}
                  >
                    {STATUS_PROJETO_OPTIONS.map((option) => (
                      <option key={option.value} value={option.value}>
                        {option.label}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
            </GlassCard>

            <GlassCard strong style={{ padding: 18 }}>
              <SectionTitle title="Endereço do evento" />
              <div className="event-form-grid two">
                <Field
                  label="Local, espaço ou salão"
                  value={form.local}
                  onChange={(value) => updateField('local', value)}
                  required
                />
                <Field
                  label="Endereço completo"
                  value={form.endereco}
                  onChange={(value) => updateField('endereco', value)}
                  required
                />
                <Field
                  label="Cidade e UF"
                  value={form.cidadeUf}
                  onChange={(value) => updateField('cidadeUf', value)}
                  required
                />
                <Field
                  label="Referência de acesso"
                  value={form.referenciaAcesso}
                  onChange={(value) => updateField('referenciaAcesso', value)}
                />
              </div>
            </GlassCard>

            <div className="event-form-grid two">
              <GlassCard strong style={{ padding: 18 }}>
                <SectionTitle title="Montagem" />
                <div className="event-form-grid three">
                  <Field
                    label="Dia"
                    type="date"
                    value={form.montagemDia}
                    onChange={(value) => updateField('montagemDia', value)}
                    required
                  />
                  <Field
                    label="Início"
                    type="time"
                    value={form.montagemInicio}
                    onChange={(value) => updateField('montagemInicio', value)}
                    required
                  />
                  <Field
                    label="Fim"
                    type="time"
                    value={form.montagemFim}
                    onChange={(value) => updateField('montagemFim', value)}
                    required
                  />
                </div>
                <div style={{ marginTop: 12, display: 'grid', gap: 12 }}>
                  <Field
                    label="Equipe"
                    value={form.montagemEquipe}
                    onChange={(value) => updateField('montagemEquipe', value)}
                  />
                  <Field
                    label="Responsável"
                    value={form.montagemResponsavel}
                    onChange={(value) => updateField('montagemResponsavel', value)}
                  />
                  <Field
                    label="Telefone"
                    type="tel"
                    value={form.montagemTelefone}
                    onChange={(value) => updateField('montagemTelefone', value)}
                  />
                </div>
              </GlassCard>

              <GlassCard strong style={{ padding: 18 }}>
                <SectionTitle title="Desmontagem" />
                <div className="event-form-grid three">
                  <Field
                    label="Dia"
                    type="date"
                    value={form.desmontagemDia}
                    onChange={(value) => updateField('desmontagemDia', value)}
                    required
                  />
                  <Field
                    label="Início"
                    type="time"
                    value={form.desmontagemInicio}
                    onChange={(value) => updateField('desmontagemInicio', value)}
                    required
                  />
                  <Field
                    label="Fim"
                    type="time"
                    value={form.desmontagemFim}
                    onChange={(value) => updateField('desmontagemFim', value)}
                  />
                </div>
                <div style={{ marginTop: 12, display: 'grid', gap: 12 }}>
                  <Field
                    label="Equipe"
                    value={form.desmontagemEquipe}
                    onChange={(value) => updateField('desmontagemEquipe', value)}
                  />
                  <Field
                    label="Responsável"
                    value={form.desmontagemResponsavel}
                    onChange={(value) => updateField('desmontagemResponsavel', value)}
                  />
                  <Field
                    label="Telefone"
                    type="tel"
                    value={form.desmontagemTelefone}
                    onChange={(value) => updateField('desmontagemTelefone', value)}
                  />
                </div>
              </GlassCard>
            </div>

            <GlassCard strong style={{ padding: 18 }}>
              <SectionTitle title="Responsáveis" />
              <div className="event-form-grid two">
                <Field
                  label="Responsável principal"
                  value={form.responsavelPrincipal}
                  onChange={(value) => updateField('responsavelPrincipal', value)}
                  required
                />
                <Field
                  label="Telefone"
                  type="tel"
                  value={form.responsavelPrincipalTelefone}
                  onChange={(value) => updateField('responsavelPrincipalTelefone', value)}
                />
                <Field
                  label="Responsável pelo checklist"
                  value={form.responsavelChecklist}
                  onChange={(value) => updateField('responsavelChecklist', value)}
                />
                <Field
                  label="Telefone"
                  type="tel"
                  value={form.responsavelChecklistTelefone}
                  onChange={(value) => updateField('responsavelChecklistTelefone', value)}
                />
              </div>
            </GlassCard>

            <GlassCard strong style={{ padding: 18 }}>
              <SectionTitle title="Checklist operacional" />
              <div style={{ display: 'grid', gap: 8 }}>
                {form.checklist.map((row, index) => (
                  <div
                    key={index}
                    className="check-row"
                    style={{
                      display: 'grid',
                      gridTemplateColumns: '32px minmax(0, 1.2fr) minmax(0, 0.8fr) 72px',
                      gap: 8,
                      alignItems: 'center',
                    }}
                  >
                    <span
                      className="mono"
                      style={{
                        display: 'grid',
                        placeItems: 'center',
                        height: 38,
                        borderRadius: 8,
                        color: 'var(--fg-2)',
                        background: 'var(--glass-bg)',
                        border: '1px solid var(--glass-border)',
                        fontSize: 11,
                      }}
                    >
                      {index + 1}
                    </span>
                    <input
                      aria-label={`Item ${index + 1} da checklist`}
                      placeholder="Item da checklist"
                      value={row.item}
                      onChange={(event) => updateChecklist(index, { item: event.target.value })}
                      style={FIELD_STYLE}
                    />
                    <input
                      aria-label={`Responsável pelo item ${index + 1}`}
                      placeholder="Responsável"
                      value={row.responsavel}
                      onChange={(event) =>
                        updateChecklist(index, { responsavel: event.target.value })
                      }
                      style={FIELD_STYLE}
                    />
                    <label
                      style={{
                        height: 38,
                        display: 'inline-flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        gap: 6,
                        borderRadius: 8,
                        border: '1px solid var(--glass-border)',
                        color: row.ok ? 'var(--accent-green)' : 'var(--fg-2)',
                      }}
                    >
                      <input
                        type="checkbox"
                        checked={row.ok}
                        onChange={(event) => updateChecklist(index, { ok: event.target.checked })}
                      />
                      <span style={{ fontSize: 12 }}>OK</span>
                    </label>
                  </div>
                ))}
              </div>
            </GlassCard>

            <GlassCard strong style={{ padding: 18 }}>
              <SectionTitle title="OBS do evento" />
              <textarea
                value={form.observacoes}
                onChange={(event) => updateField('observacoes', event.target.value)}
                rows={4}
                placeholder="Informações importantes para a operação."
                style={{ ...FIELD_STYLE, resize: 'vertical', lineHeight: 1.4 }}
              />
            </GlassCard>
          </div>

          <aside style={{ position: 'sticky', top: 24, display: 'grid', gap: 14, minWidth: 0 }}>
            <GlassCard strong style={{ padding: 20 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                <Ring
                  value={completeness.pct}
                  size={96}
                  stroke={8}
                  label="ficha"
                  state={completeness.pct >= 80 ? 'ready' : completeness.pct > 40 ? 'partial' : 'missing'}
                  ariaLabel={`Prontidão da ficha ${completeness.pct}%`}
                />
                <div style={{ minWidth: 0 }}>
                  <div
                    className="mono"
                    style={{
                      fontSize: 10,
                      color: 'var(--fg-3)',
                      letterSpacing: 0.12,
                      textTransform: 'uppercase',
                      marginBottom: 8,
                    }}
                  >
                    Resumo do evento
                  </div>
                  <h2 style={{ margin: 0, fontSize: 22, lineHeight: 1.05, letterSpacing: 0 }}>
                    {form.nomeEvento.trim() || 'Nova ficha'}
                  </h2>
                  <div style={{ marginTop: 8, fontSize: 13, color: 'var(--fg-2)' }}>
                    {form.cliente.trim() || 'Cliente não informado'}
                  </div>
                </div>
              </div>

              <SummaryRow label="Status" value={statusLabel(form.statusInicial)} />
              <SummaryRow label="Período" value={formatRange(form)} />
              <SummaryRow label="Local" value={form.local.trim() || '-'} />
              <SummaryRow
                label="Próximo passo"
                value={savedProjectId ? 'Abrir packing do evento' : 'Salvar Evento operacional'}
              />

              {message && (
                <div
                  role="status"
                  style={{
                    marginTop: 14,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    color: 'var(--accent-green)',
                    fontSize: 13,
                  }}
                >
                  <StatusDot color="var(--accent-green)" size={7} />
                  {message}
                </div>
              )}

              {error && (
                <div
                  role="alert"
                  style={{
                    marginTop: 14,
                    padding: 10,
                    borderRadius: 8,
                    color: 'var(--accent-red)',
                    background: 'color-mix(in oklch, var(--accent-red) 12%, transparent)',
                    border: '1px solid color-mix(in oklch, var(--accent-red) 36%, transparent)',
                    fontSize: 13,
                  }}
                >
                  {error}
                </div>
              )}

              <div style={{ display: 'grid', gap: 10, marginTop: 18 }}>
                <button
                  type="submit"
                  disabled={isPending}
                  style={{
                    minHeight: 44,
                    borderRadius: 8,
                    border: '1px solid var(--glass-border-strong)',
                    background:
                      'linear-gradient(135deg, var(--accent-cyan-soft), color-mix(in oklch, var(--accent-violet) 30%, transparent))',
                    color: 'var(--fg-0)',
                    fontFamily: 'inherit',
                    fontWeight: 700,
                    cursor: isPending ? 'wait' : 'pointer',
                  }}
                >
                  {isPending ? 'Salvando' : savedProjectId ? 'Atualizar Evento' : 'Salvar Evento'}
                </button>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                  <Link className="event-action-link" href="/projetos">
                    Ver eventos
                  </Link>
                  {savedProjectId ? (
                    <Link className="event-action-link" href={`/projetos/${savedProjectId}`}>
                      Abrir evento
                    </Link>
                  ) : (
                    <button type="button" className="event-action-link" onClick={resetForm}>
                      Limpar
                    </button>
                  )}
                </div>
              </div>
            </GlassCard>
          </aside>
        </form>
      </div>

      <style>{`
        .event-form-grid {
          display: grid;
          gap: 12px;
        }

        .event-form-grid.two {
          grid-template-columns: repeat(2, minmax(0, 1fr));
        }

        .event-form-grid.three {
          grid-template-columns: 1fr 0.78fr 0.78fr;
        }

        .event-action-link {
          min-height: 40px;
          border-radius: 8px;
          border: 1px solid var(--glass-border);
          background: transparent;
          color: var(--fg-1);
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 0 12px;
          text-decoration: none;
          font-family: inherit;
          font-size: 13px;
          cursor: pointer;
        }

        input:focus,
        select:focus,
        textarea:focus {
          border-color: var(--accent-cyan) !important;
          box-shadow: 0 0 0 3px color-mix(in oklch, var(--accent-cyan) 18%, transparent);
        }

        @media (max-width: 1020px) {
          form {
            grid-template-columns: 1fr !important;
          }

          aside {
            position: static !important;
          }
        }

        @media (max-width: 720px) {
          .event-form-grid.two,
          .event-form-grid.three,
          .check-row {
            grid-template-columns: 1fr !important;
          }
        }
      `}</style>
    </div>
  )
}

function SectionTitle({ title }: { title: string }) {
  return (
    <h2
      style={{
        margin: '0 0 14px',
        fontSize: 16,
        lineHeight: 1.1,
        letterSpacing: 0,
        color: 'var(--fg-0)',
      }}
    >
      {title}
    </h2>
  )
}

function Label({ children }: { children: React.ReactNode }) {
  return (
    <span
      className="mono"
      style={{
        color: 'var(--fg-3)',
        fontSize: 10,
        letterSpacing: 0.12,
        textTransform: 'uppercase',
      }}
    >
      {children}
    </span>
  )
}

function Field({
  label,
  value,
  onChange,
  type = 'text',
  required = false,
}: {
  label: string
  value: string
  onChange: (value: string) => void
  type?: string
  required?: boolean
}) {
  return (
    <label style={{ display: 'grid', gap: 6, minWidth: 0 }}>
      <Label>
        {label}
        {required ? ' *' : ''}
      </Label>
      <input
        value={value}
        type={type}
        required={required}
        onChange={(event) => onChange(event.target.value)}
        style={FIELD_STYLE}
      />
    </label>
  )
}

function SummaryRow({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        display: 'grid',
        gap: 4,
        paddingTop: 14,
        marginTop: 14,
        borderTop: '1px solid var(--glass-border)',
      }}
    >
      <div
        className="mono"
        style={{
          fontSize: 10,
          color: 'var(--fg-3)',
          letterSpacing: 0.12,
          textTransform: 'uppercase',
        }}
      >
        {label}
      </div>
      <div style={{ fontSize: 14, color: 'var(--fg-0)' }}>{value}</div>
    </div>
  )
}
