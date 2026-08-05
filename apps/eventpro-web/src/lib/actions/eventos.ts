import 'server-only'

// Camada de ação do domínio Evento.
//
// Nota de arquitetura: os módulos de `src/lib/actions/*` são `server-only`, não
// `'use server'`. No legado o monólito de 1.496 linhas era um módulo de Server
// Actions e expunha, entre outras, `checkoutProject(id, metodo, { auth })`: como
// toda função exportada de um módulo `'use server'` vira endpoint chamável pelo
// cliente, dava para invocar o check-out passando um contexto de autorização
// forjado. Aqui a camada de ação é interna (rotas de API e, na fase 7, wrappers
// `'use server'` explícitos que nunca aceitam contexto de auth como argumento).

import { revalidatePath } from 'next/cache'
import { requireActionUser } from '@/lib/action-auth'
import { blockWrite, type ActionResult } from '@/lib/readonly'
import { supabaseAdmin } from '@/lib/supabase-server'
import {
  normalizeEventoFichaInput,
  type EventoFichaInput,
  type NormalizedEventoFicha,
} from '@/lib/evento-ficha-core'
import type { StatusProjeto } from '@/lib/types'

export type { ActionResult }

export type CreateProjetoInput = {
  nome: string
  cliente: string | null
  data_inicio: string
  data_fim: string
  local: string | null
  status: StatusProjeto
  notas: string | null
}

export async function createEvento(
  input: CreateProjetoInput,
): Promise<ActionResult<{ id: string }>> {
  const blocked = blockWrite<{ id: string }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

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
  return { ok: true, data: { id: data.id as string } }
}

type ProjetoFichaPayload = NormalizedEventoFicha['projeto']

// Update ou insert direto: sem o fallback de coluna do legado, que existia só
// porque a migration de `ficha_evento` podia não estar aplicada.
async function persistEventoFicha(
  projetoId: string | null,
  payload: ProjetoFichaPayload,
): Promise<ActionResult<{ id: string }>> {
  if (projetoId) {
    const { data, error } = await supabaseAdmin
      .from('projetos')
      .update(payload)
      .eq('id', projetoId)
      .select('id')
      .maybeSingle()

    if (error) return { ok: false, error: error.message }
    if (!data) return { ok: false, error: 'Evento não encontrado.' }
    return { ok: true, data: { id: data.id as string } }
  }

  const { data, error } = await supabaseAdmin.from('projetos').insert(payload).select('id').single()
  if (error) return { ok: false, error: error.message }
  return { ok: true, data: { id: data.id as string } }
}

export async function saveEventoFicha(
  input: EventoFichaInput,
): Promise<ActionResult<{ id: string; completenessPct: number }>> {
  const normalized = normalizeEventoFichaInput(input, new Date().toISOString())
  if (!normalized.ok) return normalized

  const blocked = blockWrite<{ id: string; completenessPct: number }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const result = await persistEventoFicha(normalized.data.projetoId, normalized.data.projeto)
  if (!result.ok) return result

  revalidatePath('/ficha-evento')
  revalidatePath('/projetos')
  revalidatePath(`/projetos/${result.data.id}`)
  return {
    ok: true,
    data: { id: result.data.id, completenessPct: normalized.data.completeness.pct },
  }
}

export async function deleteEvento(id: string): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('admin')
  if (!auth.ok) return auth

  // Evento EM_CAMPO tem unidade lá fora: apagar sem retorno deixa a unidade com
  // status EM_CAMPO e sem Evento dono. O predicado vai dentro do DELETE para
  // fechar a corrida com uma troca de status concorrente.
  const { data: deleted, error } = await supabaseAdmin
    .from('projetos')
    .delete()
    .eq('id', id)
    .neq('status', 'EM_CAMPO')
    .select('id')

  if (error) return { ok: false, error: error.message }
  if (!deleted || deleted.length === 0) {
    const { data: projeto } = await supabaseAdmin
      .from('projetos')
      .select('status')
      .eq('id', id)
      .maybeSingle()
    if (!projeto) return { ok: false, error: 'Evento não encontrado.' }
    return { ok: false, error: 'Retorno obrigatório antes de deletar.' }
  }

  revalidatePath('/projetos')
  return { ok: true, data: undefined }
}

export async function updateEventoStatus(id: string, status: StatusProjeto): Promise<ActionResult> {
  const blocked = blockWrite()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const { error } = await supabaseAdmin.from('projetos').update({ status }).eq('id', id)
  if (error) return { ok: false, error: error.message }
  revalidatePath('/projetos')
  return { ok: true, data: undefined }
}
