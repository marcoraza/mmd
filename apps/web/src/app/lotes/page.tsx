'use client'

import { useEffect, useState, useCallback } from 'react'
import { Plus, Pencil, Trash2 } from 'lucide-react'
import { supabase } from '@/lib/supabase'
import { PageHeader } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { CategoryBadge } from '@/components/ui/CategoryBadge'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { SearchInput } from '@/components/ui/SearchInput'
import type { Lote, StatusLote } from '@/lib/types'

type LoteWithItem = Lote & {
  items: { nome: string; categoria: string; subcategoria: string | null } | null
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

export default function LotesPage() {
  const [lotes, setLotes] = useState<LoteWithItem[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [editTarget, setEditTarget] = useState<LoteWithItem | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  // Items for select
  const [items, setItems] = useState<{ id: string; nome: string }[]>([])

  const [form, setForm] = useState({
    item_id: '',
    codigo_lote: '',
    descricao: '',
    quantidade: 1,
    status: 'DISPONIVEL' as StatusLote,
    tag_rfid: '',
    qr_code: '',
  })

  useEffect(() => {
    supabase
      .from('items')
      .select('id, nome')
      .order('nome')
      .then(({ data }) => setItems(data ?? []))
  }, [])

  const fetchLotes = useCallback(async () => {
    setLoading(true)
    let query = supabase
      .from('lotes')
      .select('*, items(nome, categoria, subcategoria)', { count: 'exact' })
      .order('created_at', { ascending: false })

    if (search) {
      query = query.or(`codigo_lote.ilike.%${search}%,descricao.ilike.%${search}%`)
    }

    const { data, count } = await query
    setLotes((data ?? []) as LoteWithItem[])
    setTotal(count ?? 0)
    setLoading(false)
  }, [search])

  useEffect(() => { fetchLotes() }, [fetchLotes])

  function openCreate() {
    setForm({ item_id: items[0]?.id ?? '', codigo_lote: '', descricao: '', quantidade: 1, status: 'DISPONIVEL', tag_rfid: '', qr_code: '' })
    setEditTarget(null)
    setShowForm(true)
  }

  function openEdit(lote: LoteWithItem) {
    setForm({
      item_id: lote.item_id,
      codigo_lote: lote.codigo_lote,
      descricao: lote.descricao ?? '',
      quantidade: lote.quantidade,
      status: lote.status,
      tag_rfid: lote.tag_rfid ?? '',
      qr_code: lote.qr_code ?? '',
    })
    setEditTarget(lote)
    setShowForm(true)
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault()
    setSaving(true)
    if (editTarget) {
      await supabase.from('lotes').update({
        descricao: form.descricao || undefined,
        quantidade: form.quantidade,
        status: form.status,
        tag_rfid: form.tag_rfid || null,
        qr_code: form.qr_code || null,
      }).eq('id', editTarget.id)
    } else {
      await supabase.from('lotes').insert({
        item_id: form.item_id,
        codigo_lote: form.codigo_lote,
        descricao: form.descricao || undefined,
        quantidade: form.quantidade,
        status: form.status,
        tag_rfid: form.tag_rfid || null,
        qr_code: form.qr_code || null,
      })
    }
    setSaving(false)
    setShowForm(false)
    setEditTarget(null)
    fetchLotes()
  }

  async function handleDelete() {
    if (!deleteTarget) return
    await supabase.from('lotes').delete().eq('id', deleteTarget)
    setDeleteTarget(null)
    fetchLotes()
  }

  const statuses: StatusLote[] = ['DISPONIVEL', 'EM_CAMPO', 'MANUTENCAO']

  return (
    <div>
      <PageHeader
        title="Lotes"
        subtitle={`${total} lotes`}
        action={
          <button
            onClick={openCreate}
            style={{
              display: 'inline-flex', alignItems: 'center', gap: 6,
              fontFamily: '"Space Mono", monospace', fontSize: 11, letterSpacing: '0.1em',
              color: '#FFFFFF', backgroundColor: '#000000', border: 'none',
              borderRadius: 999, padding: '7px 16px', cursor: 'pointer',
            }}
          >
            <Plus size={12} /> NOVO LOTE
          </button>
        }
      />

      {/* Search */}
      <div style={{ padding: '16px 32px', borderBottom: '1px solid #E8E8E8' }}>
        <SearchInput
          value={search}
          onChange={(v) => setSearch(v)}
          placeholder="Buscar por código ou descrição..."
        />
      </div>

      {/* Form */}
      {showForm && (
        <form onSubmit={handleSave} style={{ margin: '0 32px 16px', padding: 20, border: '1px solid #E8E8E8', backgroundColor: '#FAFAFA', marginTop: 16 }}>
          <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 12 }}>
            {editTarget ? `EDITAR — ${editTarget.codigo_lote}` : 'NOVO LOTE'}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
            {!editTarget && (
              <>
                <div>
                  <label style={labelStyle}>ITEM *</label>
                  <select style={{ ...inputStyle, cursor: 'pointer' }} value={form.item_id} onChange={(e) => setForm((f) => ({ ...f, item_id: e.target.value }))} required>
                    {items.map((i) => <option key={i.id} value={i.id}>{i.nome}</option>)}
                  </select>
                </div>
                <div>
                  <label style={labelStyle}>CÓDIGO DO LOTE *</label>
                  <input style={inputStyle} value={form.codigo_lote} onChange={(e) => setForm((f) => ({ ...f, codigo_lote: e.target.value }))} required placeholder="MMD-CAB-L001" />
                </div>
              </>
            )}
            <div>
              <label style={labelStyle}>QUANTIDADE</label>
              <input style={inputStyle} type="number" min={1} value={form.quantidade} onChange={(e) => setForm((f) => ({ ...f, quantidade: Number(e.target.value) }))} />
            </div>
            <div>
              <label style={labelStyle}>STATUS</label>
              <select style={{ ...inputStyle, cursor: 'pointer' }} value={form.status} onChange={(e) => setForm((f) => ({ ...f, status: e.target.value as StatusLote }))}>
                {statuses.map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
            </div>
            <div style={{ gridColumn: editTarget ? '1 / -1' : 'span 2' }}>
              <label style={labelStyle}>DESCRIÇÃO</label>
              <input style={inputStyle} value={form.descricao} onChange={(e) => setForm((f) => ({ ...f, descricao: e.target.value }))} placeholder="Ex: Kit cabos XLR 5m" />
            </div>
            <div>
              <label style={labelStyle}>TAG RFID</label>
              <input style={inputStyle} value={form.tag_rfid} onChange={(e) => setForm((f) => ({ ...f, tag_rfid: e.target.value }))} placeholder="Ex: E2801170..." />
            </div>
            <div>
              <label style={labelStyle}>QR CODE</label>
              <input style={inputStyle} value={form.qr_code} onChange={(e) => setForm((f) => ({ ...f, qr_code: e.target.value }))} placeholder="Ex: MMD-CAB-L001" />
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <button type="submit" disabled={saving} style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, letterSpacing: '0.1em', color: '#FFFFFF', backgroundColor: '#000000', border: 'none', borderRadius: 999, padding: '6px 16px', cursor: 'pointer' }}>
              {saving ? 'SALVANDO...' : (editTarget ? 'SALVAR' : 'CRIAR')}
            </button>
            <button type="button" onClick={() => { setShowForm(false); setEditTarget(null) }} style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#666666', border: '1px solid #CCCCCC', borderRadius: 999, padding: '6px 16px', background: 'none', cursor: 'pointer' }}>
              CANCELAR
            </button>
          </div>
        </form>
      )}

      {/* Table */}
      {loading ? (
        <div style={{ padding: '32px', fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#CCCCCC', textAlign: 'center' }}>
          CARREGANDO...
        </div>
      ) : (
        <div style={{ overflowX: 'auto', padding: '16px 0' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid #CCCCCC' }}>
                {['Código', 'Item', 'Descrição', 'Qtd', 'Status', 'Tag RFID', 'QR Code', ''].map((col) => (
                  <th key={col} style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', padding: '0 16px 10px', textAlign: 'left' }}>
                    {col.toUpperCase()}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {lotes.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ padding: '24px 16px', fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#CCCCCC', textAlign: 'center' }}>
                    NENHUM LOTE ENCONTRADO
                  </td>
                </tr>
              ) : lotes.map((lote) => (
                <tr key={lote.id} style={{ borderBottom: '1px solid #E8E8E8' }}>
                  <td style={{ padding: '12px 16px', fontFamily: '"Space Mono", monospace', fontSize: 13, color: '#000000', fontWeight: 500 }}>
                    {lote.codigo_lote}
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    <div style={{ fontFamily: '"Space Grotesk", sans-serif', fontSize: 13, color: '#1A1A1A' }}>
                      {lote.items?.nome ?? '—'}
                    </div>
                    {lote.items?.subcategoria && (
                      <div style={{ fontFamily: '"Space Grotesk", sans-serif', fontSize: 11, color: '#999999', marginTop: 2 }}>
                        {lote.items.subcategoria}
                      </div>
                    )}
                    {lote.items?.categoria && <CategoryBadge categoria={lote.items.categoria} className="mt-1" />}
                  </td>
                  <td style={{ padding: '12px 16px', fontFamily: '"Space Grotesk", sans-serif', fontSize: 13, color: '#666666' }}>
                    {lote.descricao ?? '—'}
                  </td>
                  <td style={{ padding: '12px 16px', fontFamily: '"Space Mono", monospace', fontSize: 13, fontWeight: 700, color: '#000000' }}>
                    {lote.quantidade}
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    <StatusBadge status={lote.status} />
                  </td>
                  <td style={{ padding: '12px 16px', fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#1A1A1A', whiteSpace: 'nowrap' }}>
                    {lote.tag_rfid ? (lote.tag_rfid.length > 12 ? lote.tag_rfid.slice(0, 12) + '...' : lote.tag_rfid) : '—'}
                  </td>
                  <td style={{ padding: '12px 16px', fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#1A1A1A', whiteSpace: 'nowrap' }}>
                    {lote.qr_code ? (lote.qr_code.length > 12 ? lote.qr_code.slice(0, 12) + '...' : lote.qr_code) : '—'}
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                      <button onClick={() => openEdit(lote)} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}>
                        <Pencil size={13} color="#999999" />
                      </button>
                      <button onClick={() => setDeleteTarget(lote.id)} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}>
                        <Trash2 size={13} color="#D71921" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <ConfirmDialog
        open={!!deleteTarget}
        title="Excluir lote?"
        description="Esta ação não pode ser desfeita."
        confirmLabel="Excluir"
        danger
        onConfirm={handleDelete}
        onCancel={() => setDeleteTarget(null)}
      />
    </div>
  )
}
