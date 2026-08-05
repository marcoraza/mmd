import 'server-only'

// RFID: telemetria de leitura, conferência de Evento e vínculo de tag.

import { revalidatePath } from 'next/cache'
import { requireActionUser, type ActionAuthContext } from '@/lib/action-auth'
import {
  buildConferenciaResponse,
  type ConferenciaContexto,
  type ConferenciaPayload,
  type ConferenciaResponse,
  type ConferenciaRpcRow,
} from '@/lib/conferencia-rfid-core'
import { blockWrite, isWriteBlocked, READONLY_ERROR, type ActionResult } from '@/lib/readonly'
import { tagAlreadyBoundError, validateRfidTag } from '@/lib/rfid-bind-core'
import {
  recordRfidScanBatch,
  type RfidScanBatchResult,
  type RfidScanPayload,
  type RfidScanReaderPayload,
  type RfidScanRepository,
  type RfidScanRow,
  type RfidScanSerialMatch,
} from '@/lib/rfid-scan-core'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { StatusProjeto, StatusSerial } from '@/lib/types'

export type RfidScanActionResult =
  { ok: true; data: Omit<RfidScanBatchResult, 'ok'> } | { ok: false; error: string }

type SerialRow = {
  id: string
  codigo_interno: string
  tag_rfid: string | null
  items: { nome: string | null } | { nome: string | null }[] | null
}

function firstRelated<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) return value[0] ?? null
  return value ?? null
}

function messageFromError(error: unknown) {
  return error instanceof Error ? error.message : 'Falha ao registrar leitura RFID.'
}

// ── Leitor ──────────────────────────────────────────────────────────────────

// `serial_fabrica` é a chave do upsert: sem ele o leitor não é gravado e
// `reader_id` fica null nos scans. Comportamento congelado (contrato §5.3).
async function upsertReader(reader: RfidScanReaderPayload, operador: string) {
  const serial = reader.serial_fabrica?.trim()
  if (!serial) throw new Error('Leitor RFID sem serial de fábrica.')

  const now = new Date().toISOString()
  const { data, error } = await supabaseAdmin
    .from('rfid_readers')
    .upsert(
      {
        nome: reader.nome?.trim() || 'Zebra RFD40',
        modelo: reader.modelo?.trim() || 'Zebra RFD40',
        serial_fabrica: serial,
        operador,
        status: 'ATIVO',
        bateria: reader.bateria ?? null,
        ultima_atividade: now,
      },
      { onConflict: 'serial_fabrica' },
    )
    .select('id')
    .single()

  if (error) throw new Error(error.message)
  return { id: data.id as string }
}

// ── POST /api/rfid/scans ────────────────────────────────────────────────────

function createRfidScanRepository(operador: string): RfidScanRepository {
  return {
    async upsertReader(reader: RfidScanReaderPayload) {
      return upsertReader(reader, operador)
    },

    async findSerialsByTags(tags: string[]) {
      if (tags.length === 0) return new Map<string, RfidScanSerialMatch>()

      const { data, error } = await supabaseAdmin
        .from('serial_numbers')
        .select('id, codigo_interno, tag_rfid, items (nome)')
        .in('tag_rfid', tags)

      if (error) throw new Error(error.message)

      const matches = new Map<string, RfidScanSerialMatch>()
      for (const row of (data ?? []) as unknown as SerialRow[]) {
        if (!row.tag_rfid) continue
        matches.set(row.tag_rfid, {
          id: row.id,
          codigo_interno: row.codigo_interno,
          item_nome: firstRelated(row.items)?.nome ?? null,
        })
      }

      return matches
    },

    async insertScans(rows: RfidScanRow[]) {
      const { data, error } = await supabaseAdmin.from('rfid_scans').insert(rows).select('id')
      if (error) throw new Error(error.message)
      return (data ?? []) as Array<{ id: string }>
    },
  }
}

export async function recordAuthenticatedRfidScans(
  payload: RfidScanPayload,
  auth: ActionAuthContext,
): Promise<RfidScanActionResult> {
  if (isWriteBlocked()) return { ok: false, error: READONLY_ERROR }

  try {
    const result = await recordRfidScanBatch(
      { payload, operador: auth.registradoPor },
      createRfidScanRepository(auth.registradoPor),
    )

    revalidatePath('/rfid')
    if (payload.projeto_id) revalidatePath(`/projetos/${payload.projeto_id}`)

    return {
      ok: true,
      data: {
        resolved: result.resolved,
        unresolved: result.unresolved,
        scan_ids: result.scan_ids,
      },
    }
  } catch (error) {
    return { ok: false, error: messageFromError(error) }
  }
}

// ── POST /api/eventos/[id]/conferencia-rfid ─────────────────────────────────

export type ConferenciaActionResult =
  { ok: true; data: ConferenciaResponse } | { ok: false; error: string; notFound?: true }

// Fecha o loop RFID versus operação: cruza as tags lidas com
// `packing_allocations` e devolve confirmados/faltantes/extras/desconhecidas.
// Não muta status de unidade nem de Evento; a mutação continua sendo check-out
// e retorno.
export async function runConferenciaRfid(
  projetoId: string,
  payload: ConferenciaPayload,
  auth: ActionAuthContext,
): Promise<ConferenciaActionResult> {
  if (isWriteBlocked()) return { ok: false, error: READONLY_ERROR }

  const { data: evento, error: eventoError } = await supabaseAdmin
    .from('projetos')
    .select('id, nome, status')
    .eq('id', projetoId)
    .maybeSingle()

  if (eventoError) return { ok: false, error: eventoError.message }
  if (!evento) return { ok: false, error: 'not_found', notFound: true }

  let readerId: string | null = null
  if (payload.reader?.serial_fabrica) {
    try {
      readerId = (await upsertReader(payload.reader, auth.registradoPor)).id
    } catch (error) {
      return { ok: false, error: messageFromError(error) }
    }
  }

  const { data, error } = await supabaseAdmin.rpc('conferencia_rfid_evento', {
    p_projeto_id: projetoId,
    p_tags: payload.tags,
    p_contexto: payload.contexto,
    p_operador: auth.registradoPor,
    p_reader_id: readerId,
  })

  if (error) return { ok: false, error: error.message }

  // `localizacao` não é parâmetro da RPC (o cruzamento não depende dela), mas o
  // contrato §7.2 aceita o campo. Carimba as linhas recém gravadas do lote.
  if (payload.localizacao) {
    const scanIds = ((data ?? []) as ConferenciaRpcRow[])
      .map((row) => row.scan_id)
      .filter((id): id is string => typeof id === 'string')
    if (scanIds.length > 0) {
      await supabaseAdmin
        .from('rfid_scans')
        .update({ localizacao: payload.localizacao })
        .in('id', scanIds)
    }
  }

  revalidatePath('/rfid')
  revalidatePath(`/projetos/${projetoId}`)

  return {
    ok: true,
    data: buildConferenciaResponse({
      evento: {
        id: evento.id as string,
        nome: evento.nome as string,
        status: evento.status as StatusProjeto,
      },
      contexto: payload.contexto as ConferenciaContexto,
      tags: payload.tags,
      rows: (data ?? []) as ConferenciaRpcRow[],
    }),
  }
}

// ── Vínculo de tag ──────────────────────────────────────────────────────────

export type SerialForRfidBind = {
  id: string
  codigo_interno: string
  tag_rfid: string | null
  status: StatusSerial
  item_nome: string
  item_subcategoria: string | null
}

type SerialBindRow = {
  id: string
  codigo_interno: string
  tag_rfid: string | null
  status: StatusSerial
  items: { nome: string; subcategoria: string | null } | null
}

// Sem restrição de categoria: no legado a listagem filtrava `categoria = CABO`
// e a ação recusava qualquer unidade fora disso, o que travava o onboarding de
// etiqueta de moving, caixa e estrutura.
export async function searchSerialsForRfidBind(
  query: string,
): Promise<ActionResult<SerialForRfidBind[]>> {
  const auth = await requireActionUser('viewer')
  if (!auth.ok) return auth

  const q = query.trim().toLowerCase()

  const { data, error } = await supabaseAdmin
    .from('serial_numbers')
    .select('id, codigo_interno, tag_rfid, status, items!inner (nome, subcategoria)')
    .order('tag_rfid', { ascending: true, nullsFirst: true })
    .order('codigo_interno', { ascending: true })
    .limit(250)

  if (error) return { ok: false, error: error.message }

  const rows = ((data ?? []) as unknown as SerialBindRow[])
    .filter((row) => row.items != null)
    .filter((row) => {
      if (!q) return true
      return (
        row.codigo_interno.toLowerCase().includes(q) ||
        row.items!.nome.toLowerCase().includes(q) ||
        (row.items!.subcategoria ?? '').toLowerCase().includes(q) ||
        (row.tag_rfid ?? '').toLowerCase().includes(q)
      )
    })
    .slice(0, 30)
    .map((row) => ({
      id: row.id,
      codigo_interno: row.codigo_interno,
      tag_rfid: row.tag_rfid,
      status: row.status,
      item_nome: row.items!.nome,
      item_subcategoria: row.items!.subcategoria,
    }))

  return { ok: true, data: rows }
}

export async function bindRfidTagToSerial(
  serialId: string,
  rawTag: string,
): Promise<ActionResult<{ codigo_interno: string; tag_rfid: string }>> {
  const blocked = blockWrite<{ codigo_interno: string; tag_rfid: string }>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const parsed = validateRfidTag(rawTag)
  if (!parsed.ok) return { ok: false, error: parsed.error }
  const tag = parsed.tag

  const { data: serial, error: serialError } = await supabaseAdmin
    .from('serial_numbers')
    .select('id, codigo_interno')
    .eq('id', serialId)
    .maybeSingle()

  if (serialError) return { ok: false, error: serialError.message }
  if (!serial) return { ok: false, error: 'Unidade não encontrada.' }

  // `serial_numbers` é a única entidade taggeável do EventPro (não existe tabela
  // `lotes`), então este check mais o UNIQUE da coluna cobrem a unicidade
  // inteira. No legado a mesma tag podia existir em `serial_numbers` e `lotes`
  // ao mesmo tempo.
  const { data: existing, error: existingError } = await supabaseAdmin
    .from('serial_numbers')
    .select('id, codigo_interno')
    .eq('tag_rfid', tag)
    .maybeSingle()

  if (existingError) return { ok: false, error: existingError.message }
  if (existing && (existing.id as string) !== serialId) {
    return { ok: false, error: tagAlreadyBoundError(existing.codigo_interno as string) }
  }

  const { data: updated, error: updateError } = await supabaseAdmin
    .from('serial_numbers')
    .update({ tag_rfid: tag })
    .eq('id', serialId)
    .select('codigo_interno, tag_rfid')
    .single()

  if (updateError) return { ok: false, error: updateError.message }

  revalidatePath('/rfid')
  revalidatePath('/qrcodes')
  revalidatePath('/items')

  return {
    ok: true,
    data: {
      codigo_interno: updated.codigo_interno as string,
      tag_rfid: updated.tag_rfid as string,
    },
  }
}
