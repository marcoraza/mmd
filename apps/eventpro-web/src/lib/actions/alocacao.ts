import 'server-only'

// Alocação de unidade própria a uma linha de packing.
//
// Mudança estrutural em relação ao legado: a alocação é a tabela relacional
// `packing_allocations` (UNIQUE por serial), não a coluna
// `packing_list.serial_numbers_designados uuid[]`. Consequências práticas:
//
//   - `autoAllocate` delega para a RPC `auto_allocate_packing`, que faz
//     `SELECT ... FOR UPDATE SKIP LOCKED`. A race conhecida do legado (dois
//     auto-allocate simultâneos gravando o mesmo uuid em packings diferentes,
//     TODO documentado no código) morre no banco, não na aplicação.
//   - `setAllocation` e `releaseSerial` fazem INSERT/DELETE de linhas. O
//     presence-check manual do legado some: FK e UNIQUE fazem o trabalho.

import { revalidatePath } from 'next/cache'
import { requireActionUser } from '@/lib/action-auth'
import { blockWrite, type ActionResult } from '@/lib/readonly'
import { supabaseAdmin } from '@/lib/supabase-server'
import { sortAllocationCandidates } from '@/lib/allocation-core'
import { allocationSerialIds, type AllocationEmbedRow } from '@/lib/data/allocations'
import { loadAvailableSerials, type AvailableSerial } from '@/lib/data/serials'
import type { StatusSerial } from '@/lib/types'

type PackingContextRow = {
  id: string
  item_id: string
  quantidade: number
  projeto_id: string
  projetos: { data_inicio: string; data_fim: string } | null
  packing_allocations: AllocationEmbedRow[] | null
}

type TakenAllocationRow = {
  serial_id: string
  packing_list:
    | { projetos: { nome: string } | { nome: string }[] | null }
    | { projetos: { nome: string } | { nome: string }[] | null }[]
    | null
}

// PostgREST tipa embed como array quando não consegue provar cardinalidade 1.
function firstRelated<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) return value[0] ?? null
  return value ?? null
}

const PACKING_CONTEXT_SELECT = `id, item_id, quantidade, projeto_id,
     projetos ( data_inicio, data_fim ),
     packing_allocations ( serial_id )`

async function loadPackingContext(packingId: string): Promise<ActionResult<PackingContextRow>> {
  const { data, error } = await supabaseAdmin
    .from('packing_list')
    .select(PACKING_CONTEXT_SELECT)
    .eq('id', packingId)
    .maybeSingle()

  if (error) return { ok: false, error: error.message }
  if (!data) return { ok: false, error: 'Linha de packing não encontrada.' }
  return { ok: true, data: data as unknown as PackingContextRow }
}

export async function listAvailableSerialsForPacking(
  packingId: string,
): Promise<ActionResult<AvailableSerial[]>> {
  const auth = await requireActionUser('viewer')
  if (!auth.ok) return auth

  const packing = await loadPackingContext(packingId)
  if (!packing.ok) return packing
  const row = packing.data

  const candidates = await loadAvailableSerials(row.item_id, {
    excludeIds: allocationSerialIds(row.packing_allocations),
    projetoContext: row.projetos
      ? {
          projeto_id: row.projeto_id,
          data_inicio: row.projetos.data_inicio,
          data_fim: row.projetos.data_fim,
        }
      : undefined,
  })

  return { ok: true, data: sortAllocationCandidates(candidates) }
}

// Idempotente: linha já 100% coberta é no-op, e alocação manual existente nunca
// é sobrescrita. Quem escolhe as unidades é a RPC.
export async function autoAllocate(packingId: string): Promise<ActionResult<{ alocados: number }>> {
  const blocked = blockWrite<{ alocados: number }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const { data, error } = await supabaseAdmin.rpc('auto_allocate_packing', {
    p_packing_id: packingId,
    p_registrado_por: auth.data.registradoPor,
    p_registrado_por_id: auth.data.userId,
  })

  if (error) return { ok: false, error: error.message }

  const rows = (data ?? []) as Array<{ serial_id: string; codigo_interno: string }>

  const packing = await loadPackingContext(packingId)
  if (packing.ok) {
    revalidatePath('/projetos')
    revalidatePath(`/projetos/${packing.data.projeto_id}`)
  }

  return { ok: true, data: { alocados: rows.length } }
}

// Substitui o conjunto alocado da linha. Revalida cada unidade: precisa estar
// DISPONIVEL, ou já estar nesta mesma linha (realocação é idempotente).
export async function setAllocation(packingId: string, serialIds: string[]): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const uniqueIds = Array.from(new Set(serialIds.map((id) => id.trim().toLowerCase())))

  const packing = await loadPackingContext(packingId)
  if (!packing.ok) return packing
  const row = packing.data

  if (uniqueIds.length > row.quantidade) {
    return {
      ok: false,
      error: `Quantidade pedida (${row.quantidade}) menor que unidades selecionadas (${uniqueIds.length}).`,
    }
  }

  const currentIds = allocationSerialIds(row.packing_allocations).map((id) => id.toLowerCase())
  const currentSet = new Set(currentIds)
  const nextSet = new Set(uniqueIds)

  const addedIds = uniqueIds.filter((id) => !currentSet.has(id))
  const removedIds = currentIds.filter((id) => !nextSet.has(id))

  if (addedIds.length > 0) {
    const { data: serials, error: serialsError } = await supabaseAdmin
      .from('serial_numbers')
      .select('id, item_id, status')
      .in('id', addedIds)
    if (serialsError) return { ok: false, error: serialsError.message }

    const found = new Map(
      (serials ?? []).map((serial) => [
        (serial.id as string).toLowerCase(),
        { item_id: serial.item_id as string, status: serial.status as StatusSerial },
      ]),
    )

    const missingIds = addedIds.filter((id) => !found.has(id))
    if (missingIds.length > 0) {
      return { ok: false, error: `Unidades inexistentes: ${missingIds.join(', ')}.` }
    }

    for (const [id, serial] of found) {
      if (serial.item_id !== row.item_id) {
        return { ok: false, error: `Unidade ${id} não pertence ao item desta linha.` }
      }
      if (serial.status !== 'DISPONIVEL') {
        return { ok: false, error: `Unidade ${id} não está DISPONIVEL (status: ${serial.status}).` }
      }
    }

    // `UNIQUE (serial_id)` já garante a invariante no banco; a checagem aqui
    // existe só para a mensagem dizer em qual Evento a unidade está presa, em
    // vez de devolver uma violação de constraint crua.
    const { data: taken, error: takenError } = await supabaseAdmin
      .from('packing_allocations')
      .select('serial_id, packing_list ( projeto_id, projetos ( nome ) )')
      .in('serial_id', addedIds)
      .neq('packing_id', packingId)
    if (takenError) return { ok: false, error: takenError.message }

    const conflict = ((taken ?? []) as unknown as TakenAllocationRow[])[0]
    if (conflict) {
      const packing = firstRelated(conflict.packing_list)
      const eventoNome = firstRelated(packing?.projetos)?.nome ?? 'outro Evento'
      return {
        ok: false,
        error: `Unidade ${conflict.serial_id} já está alocada em ${eventoNome}.`,
      }
    }
  }

  // Simétrico: remover uma unidade que não está DISPONIVEL deixaria equipamento
  // em campo sem linha de packing responsável.
  if (removedIds.length > 0) {
    const { data: removedSerials, error: removedError } = await supabaseAdmin
      .from('serial_numbers')
      .select('id, status')
      .in('id', removedIds)
    if (removedError) return { ok: false, error: removedError.message }

    for (const serial of removedSerials ?? []) {
      if ((serial.status as StatusSerial) !== 'DISPONIVEL') {
        return {
          ok: false,
          error: `Unidade ${serial.id} em status ${serial.status}, requer retorno antes de sair do packing.`,
        }
      }
    }

    const { error: deleteError } = await supabaseAdmin
      .from('packing_allocations')
      .delete()
      .eq('packing_id', packingId)
      .in('serial_id', removedIds)
    if (deleteError) return { ok: false, error: deleteError.message }
  }

  if (addedIds.length > 0) {
    const { error: insertError } = await supabaseAdmin
      .from('packing_allocations')
      .insert(addedIds.map((serialId) => ({ packing_id: packingId, serial_id: serialId })))
    if (insertError) return { ok: false, error: insertError.message }
  }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${row.projeto_id}`)
  return { ok: true, data: undefined }
}

export async function releaseSerial(packingId: string, serialId: string): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const packing = await loadPackingContext(packingId)
  if (!packing.ok) return packing

  const { data: serial, error: serialError } = await supabaseAdmin
    .from('serial_numbers')
    .select('status')
    .eq('id', serialId)
    .maybeSingle()
  if (serialError) return { ok: false, error: serialError.message }
  if (serial && (serial.status as StatusSerial) !== 'DISPONIVEL') {
    return {
      ok: false,
      error: `Unidade em status ${serial.status}, requer retorno antes de sair do packing.`,
    }
  }

  const { error } = await supabaseAdmin
    .from('packing_allocations')
    .delete()
    .eq('packing_id', packingId)
    .eq('serial_id', serialId)
  if (error) return { ok: false, error: error.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${packing.data.projeto_id}`)
  return { ok: true, data: undefined }
}
