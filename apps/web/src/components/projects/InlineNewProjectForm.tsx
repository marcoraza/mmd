'use client'

import { useEffect, useRef, useState } from 'react'
import { PrimaryBtn, GhostBtn, GlassCard } from '@/components/mmd/Primitives'
import type { StatusProjeto } from '@/lib/data/projects'

const STATUS_OPTIONS: { value: StatusProjeto; label: string }[] = [
  { value: 'PLANEJAMENTO', label: 'Planejamento' },
  { value: 'CONFIRMADO', label: 'Confirmado' },
  { value: 'EM_CAMPO', label: 'Em campo' },
  { value: 'FINALIZADO', label: 'Finalizado' },
  { value: 'CANCELADO', label: 'Cancelado' },
]

const FIELD_STYLE: React.CSSProperties = {
  width: '100%',
  padding: '6px 0',
  borderRadius: 0,
  border: 'none',
  borderBottom: '1px solid var(--glass-border)',
  background: 'transparent',
  color: 'var(--fg-0)',
  fontFamily: 'inherit',
  fontSize: 13,
  outline: 'none',
  transition: 'border-color var(--motion-fast)',
}

export type InlineNewProjectInput = {
  nome: string
  cliente: string | null
  data_inicio: string
  data_fim: string
  local: string | null
  status: StatusProjeto
  notas: string | null
}

export function InlineNewProjectForm({
  onSubmit,
  onCancel,
  pending,
  error,
}: {
  onSubmit: (input: InlineNewProjectInput) => void
  onCancel: () => void
  pending: boolean
  error: string | null
}) {
  const today = new Date().toISOString().slice(0, 10)
  const firstRef = useRef<HTMLInputElement>(null)
  const [nome, setNome] = useState('')
  const [cliente, setCliente] = useState('')
  const [dataInicio, setDataInicio] = useState(today)
  const [dataFim, setDataFim] = useState(today)
  const [local, setLocal] = useState('')
  const [status, setStatus] = useState<StatusProjeto>('PLANEJAMENTO')
  const [notas, setNotas] = useState('')

  useEffect(() => {
    const t = setTimeout(() => firstRef.current?.focus(), 40)
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onCancel()
    }
    window.addEventListener('keydown', handleKey)
    return () => {
      clearTimeout(t)
      window.removeEventListener('keydown', handleKey)
    }
  }, [onCancel])

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    onSubmit({
      nome,
      cliente: cliente || null,
      data_inicio: dataInicio,
      data_fim: dataFim,
      local: local || null,
      status,
      notas: notas || null,
    })
  }

  return (
    <GlassCard
      strong
      style={{
        marginTop: 14,
        padding: '16px 20px',
        animation: 'mmd-reveal 220ms cubic-bezier(0.2, 0.7, 0.2, 1) both',
      }}
    >
      <form onSubmit={handleSubmit}>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'minmax(240px, 2fr) minmax(160px, 1fr) 150px 150px minmax(160px, 1fr) 160px',
            gap: 16,
            alignItems: 'end',
          }}
        >
          <div>
            <div
              className="mono"
              style={{
                fontSize: 9,
                color: 'var(--fg-3)',
                letterSpacing: 0.12,
                textTransform: 'uppercase',
                marginBottom: 4,
              }}
            >
              Nome
            </div>
            <input
              ref={firstRef}
              type="text"
              value={nome}
              onChange={(e) => setNome(e.target.value)}
              placeholder="Ex: Casamento Santos & Oliveira"
              style={{ ...FIELD_STYLE, fontSize: 15, fontWeight: 500 }}
              required
            />
          </div>
          <div>
            <Label>Cliente</Label>
            <input
              type="text"
              value={cliente}
              onChange={(e) => setCliente(e.target.value)}
              placeholder="Opcional"
              style={FIELD_STYLE}
            />
          </div>
          <div>
            <Label>Início</Label>
            <input
              type="date"
              value={dataInicio}
              onChange={(e) => setDataInicio(e.target.value)}
              style={FIELD_STYLE}
              required
            />
          </div>
          <div>
            <Label>Fim</Label>
            <input
              type="date"
              value={dataFim}
              onChange={(e) => setDataFim(e.target.value)}
              style={FIELD_STYLE}
              required
            />
          </div>
          <div>
            <Label>Local</Label>
            <input
              type="text"
              value={local}
              onChange={(e) => setLocal(e.target.value)}
              placeholder="Opcional"
              style={FIELD_STYLE}
            />
          </div>
          <div>
            <Label>Status</Label>
            <select
              value={status}
              onChange={(e) => setStatus(e.target.value as StatusProjeto)}
              style={{ ...FIELD_STYLE, cursor: 'pointer' }}
            >
              {STATUS_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div style={{ marginTop: 14 }}>
          <Label>Notas</Label>
          <input
            type="text"
            value={notas}
            onChange={(e) => setNotas(e.target.value)}
            placeholder="Opcional"
            style={FIELD_STYLE}
          />
        </div>

        <div
          style={{
            marginTop: 16,
            display: 'flex',
            alignItems: 'center',
            gap: 12,
          }}
        >
          {error && (
            <div style={{ fontSize: 12, color: 'var(--accent-red)' }}>{error}</div>
          )}
          <div style={{ flex: 1 }} />
          <GhostBtn small onClick={onCancel}>
            Cancelar
          </GhostBtn>
          <PrimaryBtn small type="submit" disabled={pending || !nome.trim()}>
            {pending ? 'Criando…' : 'Criar projeto'}
          </PrimaryBtn>
        </div>
      </form>
    </GlassCard>
  )
}

function Label({ children }: { children: React.ReactNode }) {
  return (
    <div
      className="mono"
      style={{
        fontSize: 9,
        color: 'var(--fg-3)',
        letterSpacing: 0.12,
        textTransform: 'uppercase',
        marginBottom: 4,
      }}
    >
      {children}
    </div>
  )
}
