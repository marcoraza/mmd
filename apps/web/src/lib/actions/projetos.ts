'use server'

import { revalidatePath } from 'next/cache'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { StatusProjeto } from '@/lib/data/projects'
import { loadAvailableSerials } from '@/lib/data/serials'

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
  // Proteção: projeto EM_CAMPO tem seriais lá fora. Deletar sem check-in
  // deixa estoque em estado inconsistente (serial.status=EM_CAMPO mas
  // projeto sumiu). Bloqueia até ter rotina de cancelamento com devolução.
  //
  // Predicate-in-DELETE pra fechar race com updateProjetoStatus concorrente:
  // Postgres avalia o neq na hora do write, nenhuma janela entre SELECT e DELETE.
  const { data: deleted, error } = await supabaseAdmin
    .from('projetos')
    .delete()
    .eq('id', id)
    .neq('status', 'EM_CAMPO')
    .select('id')
  if (error) return { ok: false, error: error.message }
  if (!deleted || deleted.length === 0) {
    // Ou o projeto não existe, ou está EM_CAMPO. Checa qual caso pra mensagem útil.
    const { data: projeto } = await supabaseAdmin
      .from('projetos')
      .select('status')
      .eq('id', id)
      .maybeSingle()
    if (!projeto) return { ok: false, error: 'Projeto não encontrado.' }
    return { ok: false, error: 'Check-in obrigatório antes de deletar.' }
  }
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

  // Proteção: reduzir qty abaixo do número de seriais já alocados deixa
  // alocação inconsistente. Marco tem que soltar seriais primeiro.
  const { data: existing, error: selErr } = await supabaseAdmin
    .from('packing_list')
    .select('serial_numbers_designados, projeto_id')
    .eq('id', packingId)
    .maybeSingle()
  if (selErr) return { ok: false, error: selErr.message }
  if (!existing) return { ok: false, error: 'Packing não encontrado.' }

  const alocados = existing.serial_numbers_designados?.length ?? 0
  if (quantidade < alocados) {
    return {
      ok: false,
      error: `Remova seriais alocados primeiro (${alocados} alocados, qty pedida ${quantidade}).`,
    }
  }

  const { error } = await supabaseAdmin
    .from('packing_list')
    .update({ quantidade })
    .eq('id', packingId)
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  revalidatePath(`/projetos/${existing.projeto_id}`)
  return { ok: true, data: undefined }
}

export type ItemSearchResult = {
  id: string
  codigo_interno: string | null
  nome: string
  categoria: string
  quantidade_total: number
}

// ─────────────────────────────────────────────────────────────────────────
// Alocação de seriais
// ─────────────────────────────────────────────────────────────────────────

// Helper para o SerialPicker: lista candidatos disponíveis pra um packing
// específico, com conflict detection no contexto do projeto.
export async function listAvailableSerialsForPacking(
  packingId: string
): Promise<ActionResult<Awaited<ReturnType<typeof loadAvailableSerials>>>> {
  const { data: packing, error: pErr } = await supabaseAdmin
    .from('packing_list')
    .select('item_id, serial_numbers_designados, projeto_id, projetos ( data_inicio, data_fim )')
    .eq('id', packingId)
    .maybeSingle()
  if (pErr) return { ok: false, error: pErr.message }
  if (!packing) return { ok: false, error: 'Packing não encontrado.' }

  type Shape = {
    item_id: string
    serial_numbers_designados: string[] | null
    projeto_id: string
    projetos: { data_inicio: string; data_fim: string } | null
  }
  const p = packing as unknown as Shape

  const candidates = await loadAvailableSerials(p.item_id, {
    excludeIds: p.serial_numbers_designados ?? [],
    projetoContext: p.projetos
      ? {
          projeto_id: p.projeto_id,
          data_inicio: p.projetos.data_inicio,
          data_fim: p.projetos.data_fim,
        }
      : undefined,
  })
  return { ok: true, data: candidates }
}


// Lê o packing_list (com projeto contexto), chama loadAvailableSerials com
// exclude = já alocados, pega os N primeiros (N = quantidade - alocados), e
// faz UPDATE union.
//
// Idempotente: se já está 100%, no-op. Nunca sobrescreve alocação manual.
//
// TODO(concurrency): SELECT pool + UPDATE são 3 round-trips não-atômicos. Dois
// autoAllocate simultâneos em packings do mesmo item podem ver o mesmo serial
// DISPONIVEL e ambos gravar o mesmo UUID em packings diferentes. Mitigar quando
// volume crescer: mover pra RPC plpgsql com SELECT ... FOR UPDATE SKIP LOCKED,
// ou adicionar exclusion constraint via trigger em unnest(serial_numbers_designados).
// Hoje, single-operator (Marco), risco baixo.
export async function autoAllocate(packingId: string): Promise<ActionResult<{ alocados: number }>> {
  const { data: packing, error: pErr } = await supabaseAdmin
    .from('packing_list')
    .select('id, item_id, quantidade, serial_numbers_designados, projeto_id, projetos ( data_inicio, data_fim )')
    .eq('id', packingId)
    .maybeSingle()
  if (pErr) return { ok: false, error: pErr.message }
  if (!packing) return { ok: false, error: 'Packing não encontrado.' }

  type PackingShape = {
    id: string
    item_id: string
    quantidade: number
    serial_numbers_designados: string[] | null
    projeto_id: string
    projetos: { data_inicio: string; data_fim: string } | null
  }
  const p = packing as unknown as PackingShape

  const existing = p.serial_numbers_designados ?? []
  const missing = p.quantidade - existing.length
  if (missing <= 0) return { ok: true, data: { alocados: 0 } }

  const candidates = await loadAvailableSerials(p.item_id, {
    excludeIds: existing,
    projetoContext: p.projetos
      ? {
          projeto_id: p.projeto_id,
          data_inicio: p.projetos.data_inicio,
          data_fim: p.projetos.data_fim,
        }
      : undefined,
    limit: missing,
  })

  if (candidates.length === 0) return { ok: true, data: { alocados: 0 } }

  const novoArray = [...existing, ...candidates.map((c) => c.id)]
  const { error: upErr } = await supabaseAdmin
    .from('packing_list')
    .update({ serial_numbers_designados: novoArray })
    .eq('id', packingId)
  if (upErr) return { ok: false, error: upErr.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${p.projeto_id}`)
  return { ok: true, data: { alocados: candidates.length } }
}

// Substitui o array de alocação inteiro. Revalida cada serial: deve estar
// DISPONIVEL, ou já neste mesmo packing (re-alocação é idempotente). Bloqueia
// se algum serial está em outro status (EM_CAMPO, MANUTENCAO, etc).
export async function setAllocation(
  packingId: string,
  serialIds: string[]
): Promise<ActionResult> {
  const uniqueIds = Array.from(new Set(serialIds))

  const { data: packing, error: pErr } = await supabaseAdmin
    .from('packing_list')
    .select('id, item_id, quantidade, serial_numbers_designados, projeto_id')
    .eq('id', packingId)
    .maybeSingle()
  if (pErr) return { ok: false, error: pErr.message }
  if (!packing) return { ok: false, error: 'Packing não encontrado.' }

  if (uniqueIds.length > packing.quantidade) {
    return {
      ok: false,
      error: `Quantidade pedida (${packing.quantidade}) menor que seriais selecionados (${uniqueIds.length}).`,
    }
  }

  const currentSet = new Set<string>((packing.serial_numbers_designados ?? []) as string[])
  const newSet = new Set<string>(uniqueIds)

  if (uniqueIds.length > 0) {
    const { data: serials, error: sErr } = await supabaseAdmin
      .from('serial_numbers')
      .select('id, item_id, status')
      .in('id', uniqueIds)
    if (sErr) return { ok: false, error: sErr.message }

    // Presence check: UUIDs que não existem em serial_numbers devem ser rejeitados.
    // packing_list.serial_numbers_designados é uuid[] sem FK por elemento, então o
    // UPDATE aceitaria lixo silenciosamente e inflaria readiness_pct.
    const gotSet = new Set((serials ?? []).map((s) => s.id))
    const missingIds = uniqueIds.filter((id) => !gotSet.has(id))
    if (missingIds.length > 0) {
      return { ok: false, error: `Seriais inexistentes: ${missingIds.join(', ')}.` }
    }

    for (const s of serials ?? []) {
      if (s.item_id !== packing.item_id) {
        return { ok: false, error: `Serial ${s.id} não pertence ao item do packing.` }
      }
      if (s.status !== 'DISPONIVEL' && !currentSet.has(s.id)) {
        return { ok: false, error: `Serial ${s.id} não está DISPONIVEL (status: ${s.status}).` }
      }
    }
  }

  // Symmetric check: seriais sendo REMOVIDOS devem estar DISPONIVEL. Remover
  // um EM_CAMPO via setAllocation deixa serial fora do packing mas com status
  // em campo, que é o mesmo estado inconsistente que deleteProjeto bloqueia.
  const removedIds = Array.from(currentSet).filter((id) => !newSet.has(id))
  if (removedIds.length > 0) {
    const { data: removedSerials, error: rErr } = await supabaseAdmin
      .from('serial_numbers')
      .select('id, status')
      .in('id', removedIds)
    if (rErr) return { ok: false, error: rErr.message }
    for (const s of removedSerials ?? []) {
      if (s.status !== 'DISPONIVEL') {
        return {
          ok: false,
          error: `Serial ${s.id} em status ${s.status}, requer check-in antes de remover do packing.`,
        }
      }
    }
  }

  const { error: upErr } = await supabaseAdmin
    .from('packing_list')
    .update({ serial_numbers_designados: uniqueIds })
    .eq('id', packingId)
  if (upErr) return { ok: false, error: upErr.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${packing.projeto_id}`)
  return { ok: true, data: undefined }
}

// Remove um serial do array de alocação do packing. Usado pelo X da chip.
export async function releaseSerial(
  packingId: string,
  serialId: string
): Promise<ActionResult> {
  const { data: packing, error: pErr } = await supabaseAdmin
    .from('packing_list')
    .select('serial_numbers_designados, projeto_id')
    .eq('id', packingId)
    .maybeSingle()
  if (pErr) return { ok: false, error: pErr.message }
  if (!packing) return { ok: false, error: 'Packing não encontrado.' }

  // Bloqueia release de serial que não está DISPONIVEL. Se está EM_CAMPO/MANUTENCAO,
  // o operador tem que passar pelo fluxo de check-in, não pela chip-X.
  const { data: serial, error: sErr } = await supabaseAdmin
    .from('serial_numbers')
    .select('status')
    .eq('id', serialId)
    .maybeSingle()
  if (sErr) return { ok: false, error: sErr.message }
  if (serial && serial.status !== 'DISPONIVEL') {
    return {
      ok: false,
      error: `Serial em status ${serial.status}, requer check-in antes de remover do packing.`,
    }
  }

  const novoArray = (packing.serial_numbers_designados ?? []).filter((id: string) => id !== serialId)
  const { error: upErr } = await supabaseAdmin
    .from('packing_list')
    .update({ serial_numbers_designados: novoArray })
    .eq('id', packingId)
  if (upErr) return { ok: false, error: upErr.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${packing.projeto_id}`)
  return { ok: true, data: undefined }
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
