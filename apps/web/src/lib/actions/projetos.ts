'use server'

import { revalidatePath } from 'next/cache'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { StatusProjeto } from '@/lib/data/projects'

export type CreateProjetoInput = {
  nome: string
  cliente: string | null
  data_inicio: string
  data_fim: string
  local: string | null
  status: StatusProjeto
  notas: string | null
}

export type ActionResult<T = void> =
  | { ok: true; data: T }
  | { ok: false; error: string }

export async function createProjeto(
  input: CreateProjetoInput
): Promise<ActionResult<{ id: string }>> {
  const nome = input.nome.trim()
  if (!nome) return { ok: false, error: 'Nome obrigatório.' }
  if (input.data_fim < input.data_inicio) {
    return { ok: false, error: 'Data final antes da inicial.' }
  }

  const { data, error } = await supabaseAdmin
    .from('projetos')
    .insert({
      nome,
      cliente: input.cliente?.trim() || null,
      data_inicio: input.data_inicio,
      data_fim: input.data_fim,
      local: input.local?.trim() || null,
      status: input.status,
      notas: input.notas?.trim() || null,
    })
    .select('id')
    .single()

  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  return { ok: true, data: { id: data.id } }
}

export async function deleteProjeto(id: string): Promise<ActionResult> {
  const { error } = await supabaseAdmin.from('projetos').delete().eq('id', id)
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  return { ok: true, data: undefined }
}

export async function updateProjetoStatus(
  id: string,
  status: StatusProjeto
): Promise<ActionResult> {
  const { error } = await supabaseAdmin.from('projetos').update({ status }).eq('id', id)
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  return { ok: true, data: undefined }
}

export async function addPackingItem(
  projetoId: string,
  itemId: string,
  quantidade: number
): Promise<ActionResult<{ id: string }>> {
  if (quantidade <= 0) return { ok: false, error: 'Quantidade precisa ser maior que zero.' }

  const { data: existing, error: selectError } = await supabaseAdmin
    .from('packing_list')
    .select('id, quantidade')
    .eq('projeto_id', projetoId)
    .eq('item_id', itemId)
    .maybeSingle()
  if (selectError) return { ok: false, error: selectError.message }

  if (existing) {
    const { error } = await supabaseAdmin
      .from('packing_list')
      .update({ quantidade: existing.quantidade + quantidade })
      .eq('id', existing.id)
    if (error) return { ok: false, error: error.message }
    revalidatePath('/projetos')
    return { ok: true, data: { id: existing.id } }
  }

  const { data, error } = await supabaseAdmin
    .from('packing_list')
    .insert({ projeto_id: projetoId, item_id: itemId, quantidade })
    .select('id')
    .single()
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  return { ok: true, data: { id: data.id } }
}

export async function removePackingItem(packingId: string): Promise<ActionResult> {
  const { error } = await supabaseAdmin.from('packing_list').delete().eq('id', packingId)
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  return { ok: true, data: undefined }
}

export async function updatePackingQty(
  packingId: string,
  quantidade: number
): Promise<ActionResult> {
  if (quantidade <= 0) return { ok: false, error: 'Quantidade inválida.' }
  const { error } = await supabaseAdmin
    .from('packing_list')
    .update({ quantidade })
    .eq('id', packingId)
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  return { ok: true, data: undefined }
}

export type ItemSearchResult = {
  id: string
  codigo_interno: string | null
  nome: string
  categoria: string
  quantidade_total: number
}

export async function searchItems(query: string): Promise<ItemSearchResult[]> {
  const q = query.trim()
  let builder = supabaseAdmin
    .from('items')
    .select('id, codigo_interno, nome, categoria, quantidade_total')
    .order('nome', { ascending: true })
    .limit(12)
  if (q) {
    builder = builder.or(`nome.ilike.%${q}%,codigo_interno.ilike.%${q}%`)
  }
  const { data, error } = await builder
  if (error) throw error
  return (data ?? []) as ItemSearchResult[]
}
