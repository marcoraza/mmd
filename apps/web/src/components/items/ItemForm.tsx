'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabase'
import type { Item, Categoria, TipoRastreamento, CreateItem, UpdateItem } from '@/lib/types'

const categorias: Categoria[] = ['ILUMINACAO', 'AUDIO', 'CABO', 'ENERGIA', 'ESTRUTURA', 'EFEITO', 'VIDEO', 'ACESSORIO']
const categoriaLabels: Record<Categoria, string> = {
  ILUMINACAO: 'Iluminação', AUDIO: 'Áudio', CABO: 'Cabo', ENERGIA: 'Energia',
  ESTRUTURA: 'Estrutura', EFEITO: 'Efeito', VIDEO: 'Vídeo', ACESSORIO: 'Acessório',
}

interface ItemFormProps {
  item?: Item
}

const inputStyle = {
  fontFamily: '"Space Grotesk", sans-serif',
  fontSize: 14,
  color: '#1A1A1A',
  border: '1px solid #E8E8E8',
  backgroundColor: '#FFFFFF',
  padding: '8px 12px',
  outline: 'none',
  width: '100%',
  borderRadius: 0,
} as const

const labelStyle = {
  fontFamily: '"Space Mono", monospace',
  fontSize: 9,
  color: '#999999',
  letterSpacing: '0.12em',
  display: 'block',
  marginBottom: 6,
} as const

export function ItemForm({ item }: ItemFormProps) {
  const router = useRouter()
  const isEdit = !!item

  const [form, setForm] = useState({
    nome: item?.nome ?? '',
    categoria: item?.categoria ?? 'ILUMINACAO' as Categoria,
    subcategoria: item?.subcategoria ?? '',
    marca: item?.marca ?? '',
    modelo: item?.modelo ?? '',
    tipo_rastreamento: item?.tipo_rastreamento ?? 'INDIVIDUAL' as TipoRastreamento,
    quantidade_total: item?.quantidade_total ?? 1,
    valor_mercado_unitario: item?.valor_mercado_unitario ?? '',
    notas: item?.notas ?? '',
  })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function set(key: string, value: unknown) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!form.nome.trim()) { setError('Nome é obrigatório'); return }
    setLoading(true)
    setError(null)

    const payload: CreateItem = {
      nome: form.nome.trim(),
      categoria: form.categoria,
      subcategoria: form.subcategoria || undefined,
      marca: form.marca || undefined,
      modelo: form.modelo || undefined,
      tipo_rastreamento: form.tipo_rastreamento,
      quantidade_total: Number(form.quantidade_total),
      valor_mercado_unitario: form.valor_mercado_unitario ? Number(form.valor_mercado_unitario) : undefined,
      notas: form.notas || undefined,
    }

    const { data, error: err } = isEdit
      ? await supabase.from('items').update(payload as UpdateItem).eq('id', item!.id).select().single()
      : await supabase.from('items').insert(payload).select().single()

    setLoading(false)
    if (err) { setError(err.message); return }
    router.push(`/items/${(data as Item).id}`)
  }

  return (
    <form onSubmit={handleSubmit} style={{ maxWidth: 600, padding: '32px' }}>
      {error && (
        <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#D71921', marginBottom: 16, padding: '8px 12px', border: '1px solid #D71921' }}>
          {error}
        </div>
      )}

      <div className="flex flex-col gap-6">
        <Field label="Nome *">
          <input style={inputStyle} value={form.nome} onChange={(e) => set('nome', e.target.value)} required />
        </Field>

        <div className="grid grid-cols-2 gap-6">
          <Field label="Categoria *">
            <select style={{ ...inputStyle, cursor: 'pointer' }} value={form.categoria} onChange={(e) => set('categoria', e.target.value as Categoria)}>
              {categorias.map((c) => <option key={c} value={c}>{categoriaLabels[c]}</option>)}
            </select>
          </Field>
          <Field label="Subcategoria">
            <input style={inputStyle} value={form.subcategoria} onChange={(e) => set('subcategoria', e.target.value)} />
          </Field>
        </div>

        <div className="grid grid-cols-2 gap-6">
          <Field label="Marca">
            <input style={inputStyle} value={form.marca} onChange={(e) => set('marca', e.target.value)} />
          </Field>
          <Field label="Modelo">
            <input style={inputStyle} value={form.modelo} onChange={(e) => set('modelo', e.target.value)} />
          </Field>
        </div>

        <div className="grid grid-cols-2 gap-6">
          <Field label="Tipo de Rastreamento">
            <select style={{ ...inputStyle, cursor: 'pointer' }} value={form.tipo_rastreamento} onChange={(e) => set('tipo_rastreamento', e.target.value as TipoRastreamento)}>
              <option value="INDIVIDUAL">Individual</option>
              <option value="LOTE">Lote</option>
              <option value="BULK">Bulk</option>
            </select>
          </Field>
          <Field label="Quantidade Total">
            <input style={inputStyle} type="number" min={1} value={form.quantidade_total} onChange={(e) => set('quantidade_total', e.target.value)} />
          </Field>
        </div>

        <Field label="Valor de Mercado (unitário, R$)">
          <input style={inputStyle} type="number" step="0.01" min={0} value={form.valor_mercado_unitario} onChange={(e) => set('valor_mercado_unitario', e.target.value)} />
        </Field>

        <Field label="Notas">
          <textarea style={{ ...inputStyle, height: 80, resize: 'vertical' }} value={form.notas} onChange={(e) => set('notas', e.target.value)} />
        </Field>
      </div>

      <div className="flex items-center gap-3 mt-8">
        <button
          type="submit"
          disabled={loading}
          style={{
            fontFamily: '"Space Mono", monospace',
            fontSize: 11,
            letterSpacing: '0.1em',
            color: '#FFFFFF',
            backgroundColor: loading ? '#666666' : '#000000',
            border: 'none',
            borderRadius: 999,
            padding: '8px 24px',
            cursor: loading ? 'not-allowed' : 'pointer',
          }}
        >
          {loading ? 'SALVANDO...' : (isEdit ? 'SALVAR ALTERAÇÕES' : 'CRIAR ITEM')}
        </button>
        <button
          type="button"
          onClick={() => router.back()}
          style={{
            fontFamily: '"Space Mono", monospace',
            fontSize: 11,
            letterSpacing: '0.1em',
            color: '#666666',
            backgroundColor: 'transparent',
            border: '1px solid #CCCCCC',
            borderRadius: 999,
            padding: '8px 24px',
            cursor: 'pointer',
          }}
        >
          CANCELAR
        </button>
      </div>
    </form>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label style={labelStyle}>{label.toUpperCase()}</label>
      {children}
    </div>
  )
}
