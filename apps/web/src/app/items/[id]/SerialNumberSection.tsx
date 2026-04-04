'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Plus } from 'lucide-react'
import { supabase } from '@/lib/supabase'
import { SerialNumberList } from '@/components/items/SerialNumberList'
import type { Item, SerialNumber, Estado, StatusSerial } from '@/lib/types'

interface SerialNumberSectionProps {
  item: Item
  serials: SerialNumber[]
}

const inputStyle = {
  fontFamily: '"Space Grotesk", sans-serif',
  fontSize: 14,
  color: '#1A1A1A',
  border: '1px solid #E8E8E8',
  backgroundColor: '#FFFFFF',
  padding: '7px 10px',
  outline: 'none',
  width: '100%',
} as const

const labelStyle = {
  fontFamily: '"Space Mono", monospace',
  fontSize: 9,
  color: '#999999',
  letterSpacing: '0.12em',
  display: 'block',
  marginBottom: 4,
} as const

function generateCodigo(categoria: string, existingCount: number) {
  const prefixes: Record<string, string> = {
    ILUMINACAO: 'ILU', AUDIO: 'AUD', CABO: 'CAB', ENERGIA: 'ENE',
    ESTRUTURA: 'EST', EFEITO: 'EFE', VIDEO: 'VID', ACESSORIO: 'ACE',
  }
  const prefix = prefixes[categoria] ?? 'ACE'
  return `MMD-${prefix}-${String(existingCount + 1).padStart(4, '0')}`
}

export function SerialNumberSection({ item, serials }: SerialNumberSectionProps) {
  const router = useRouter()
  const [showForm, setShowForm] = useState(false)
  const [editTarget, setEditTarget] = useState<SerialNumber | null>(null)
  const [saving, setSaving] = useState(false)

  const [form, setForm] = useState({
    codigo_interno: '',
    serial_fabrica: '',
    estado: 'USADO' as Estado,
    desgaste: 3,
    notas: '',
  })

  const [editForm, setEditForm] = useState({
    status: 'DISPONIVEL' as StatusSerial,
    estado: 'USADO' as Estado,
    desgaste: 3,
    localizacao: '',
    notas: '',
  })

  function openCreate() {
    setForm({
      codigo_interno: generateCodigo(item.categoria, serials.length),
      serial_fabrica: '',
      estado: 'USADO',
      desgaste: 3,
      notas: '',
    })
    setShowForm(true)
    setEditTarget(null)
  }

  function openEdit(sn: SerialNumber) {
    setEditForm({
      status: sn.status,
      estado: sn.estado,
      desgaste: sn.desgaste,
      localizacao: sn.localizacao ?? '',
      notas: sn.notas ?? '',
    })
    setEditTarget(sn)
    setShowForm(false)
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault()
    setSaving(true)
    await supabase.from('serial_numbers').insert({
      item_id: item.id,
      codigo_interno: form.codigo_interno,
      serial_fabrica: form.serial_fabrica || undefined,
      estado: form.estado,
      desgaste: form.desgaste,
      notas: form.notas || undefined,
    })
    setSaving(false)
    setShowForm(false)
    router.refresh()
  }

  async function handleEdit(e: React.FormEvent) {
    e.preventDefault()
    if (!editTarget) return
    setSaving(true)
    await supabase.from('serial_numbers').update({
      status: editForm.status,
      estado: editForm.estado,
      desgaste: editForm.desgaste,
      localizacao: editForm.localizacao || undefined,
      notas: editForm.notas || undefined,
    }).eq('id', editTarget.id)
    setSaving(false)
    setEditTarget(null)
    router.refresh()
  }

  async function handleDelete(id: string) {
    await supabase.from('serial_numbers').delete().eq('id', id)
    router.refresh()
  }

  const statuses: StatusSerial[] = ['DISPONIVEL', 'PACKED', 'EM_CAMPO', 'RETORNANDO', 'MANUTENCAO', 'EMPRESTADO', 'VENDIDO', 'BAIXA']
  const estados: Estado[] = ['NOVO', 'SEMI_NOVO', 'USADO', 'RECONDICIONADO']

  return (
    <div>
      <SerialNumberList
        serials={serials}
        onEdit={openEdit}
        onDelete={handleDelete}
      />

      {/* Add button */}
      <button
        onClick={openCreate}
        style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          fontFamily: '"Space Mono", monospace', fontSize: 11,
          letterSpacing: '0.1em', color: '#000000',
          border: '1px solid #000000', borderRadius: 999,
          padding: '6px 14px', background: 'none', cursor: 'pointer', marginTop: 12,
        }}
      >
        <Plus size={11} /> ADICIONAR SERIAL
      </button>

      {/* Create form */}
      {showForm && (
        <form onSubmit={handleCreate} style={{ marginTop: 16, padding: 16, border: '1px solid #E8E8E8', backgroundColor: '#FAFAFA' }}>
          <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 12 }}>
            NOVO SERIAL NUMBER
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
            <div>
              <label style={labelStyle}>CÓDIGO INTERNO</label>
              <input style={inputStyle} value={form.codigo_interno} onChange={(e) => setForm((f) => ({ ...f, codigo_interno: e.target.value }))} required />
            </div>
            <div>
              <label style={labelStyle}>SERIAL DE FÁBRICA</label>
              <input style={inputStyle} value={form.serial_fabrica} onChange={(e) => setForm((f) => ({ ...f, serial_fabrica: e.target.value }))} />
            </div>
            <div>
              <label style={labelStyle}>ESTADO</label>
              <select style={{ ...inputStyle, cursor: 'pointer' }} value={form.estado} onChange={(e) => setForm((f) => ({ ...f, estado: e.target.value as Estado }))}>
                {estados.map((e) => <option key={e} value={e}>{e}</option>)}
              </select>
            </div>
            <div>
              <label style={labelStyle}>DESGASTE (1–5)</label>
              <input style={inputStyle} type="number" min={1} max={5} value={form.desgaste} onChange={(e) => setForm((f) => ({ ...f, desgaste: Number(e.target.value) }))} />
            </div>
            <div style={{ gridColumn: 'span 2' }}>
              <label style={labelStyle}>NOTAS</label>
              <input style={inputStyle} value={form.notas} onChange={(e) => setForm((f) => ({ ...f, notas: e.target.value }))} />
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <button type="submit" disabled={saving} style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, letterSpacing: '0.1em', color: '#FFFFFF', backgroundColor: '#000000', border: 'none', borderRadius: 999, padding: '6px 16px', cursor: 'pointer' }}>
              {saving ? 'SALVANDO...' : 'CRIAR'}
            </button>
            <button type="button" onClick={() => setShowForm(false)} style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#666666', border: '1px solid #CCCCCC', borderRadius: 999, padding: '6px 16px', background: 'none', cursor: 'pointer' }}>
              CANCELAR
            </button>
          </div>
        </form>
      )}

      {/* Edit form */}
      {editTarget && (
        <form onSubmit={handleEdit} style={{ marginTop: 16, padding: 16, border: '1px solid #E8E8E8', backgroundColor: '#FAFAFA' }}>
          <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 12 }}>
            EDITAR — {editTarget.codigo_interno}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
            <div>
              <label style={labelStyle}>STATUS</label>
              <select style={{ ...inputStyle, cursor: 'pointer' }} value={editForm.status} onChange={(e) => setEditForm((f) => ({ ...f, status: e.target.value as StatusSerial }))}>
                {statuses.map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
            </div>
            <div>
              <label style={labelStyle}>ESTADO</label>
              <select style={{ ...inputStyle, cursor: 'pointer' }} value={editForm.estado} onChange={(e) => setEditForm((f) => ({ ...f, estado: e.target.value as Estado }))}>
                {estados.map((e) => <option key={e} value={e}>{e}</option>)}
              </select>
            </div>
            <div>
              <label style={labelStyle}>DESGASTE (1–5)</label>
              <input style={inputStyle} type="number" min={1} max={5} value={editForm.desgaste} onChange={(e) => setEditForm((f) => ({ ...f, desgaste: Number(e.target.value) }))} />
            </div>
            <div>
              <label style={labelStyle}>LOCALIZAÇÃO</label>
              <input style={inputStyle} value={editForm.localizacao} onChange={(e) => setEditForm((f) => ({ ...f, localizacao: e.target.value }))} />
            </div>
            <div style={{ gridColumn: 'span 2' }}>
              <label style={labelStyle}>NOTAS</label>
              <input style={inputStyle} value={editForm.notas} onChange={(e) => setEditForm((f) => ({ ...f, notas: e.target.value }))} />
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <button type="submit" disabled={saving} style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, letterSpacing: '0.1em', color: '#FFFFFF', backgroundColor: '#000000', border: 'none', borderRadius: 999, padding: '6px 16px', cursor: 'pointer' }}>
              {saving ? 'SALVANDO...' : 'SALVAR'}
            </button>
            <button type="button" onClick={() => setEditTarget(null)} style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#666666', border: '1px solid #CCCCCC', borderRadius: 999, padding: '6px 16px', background: 'none', cursor: 'pointer' }}>
              CANCELAR
            </button>
          </div>
        </form>
      )}
    </div>
  )
}
