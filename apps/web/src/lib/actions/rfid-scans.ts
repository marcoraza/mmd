import 'server-only'

import { revalidatePath } from 'next/cache'
import type { ActionAuthContext } from '@/lib/action-auth'
import { isWriteBlocked } from '@/lib/data/demo-mode'
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

export type RfidScanActionResult =
  | { ok: true; data: Omit<RfidScanBatchResult, 'ok'> }
  | { ok: false; error: string }

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

function createRfidScanRepository(operador: string): RfidScanRepository {
  return {
    async upsertReader(reader: RfidScanReaderPayload) {
      const serial = reader.serial_fabrica?.trim()
      if (!serial) throw new Error('Leitor RFID sem serial de fábrica.')

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
            ultima_atividade: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'serial_fabrica' },
        )
        .select('id')
        .single()

      if (error) throw new Error(error.message)
      return { id: data.id as string }
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
        const item = firstRelated(row.items)
        matches.set(row.tag_rfid, {
          id: row.id,
          codigo_interno: row.codigo_interno,
          item_nome: item?.nome ?? null,
        })
      }

      return matches
    },

    async insertScans(rows: RfidScanRow[]) {
      const { data, error } = await supabaseAdmin
        .from('rfid_scans')
        .insert(rows)
        .select('id')

      if (error) throw new Error(error.message)
      return (data ?? []) as Array<{ id: string }>
    },
  }
}

export async function recordAuthenticatedRfidScans(
  payload: RfidScanPayload,
  auth: ActionAuthContext,
): Promise<RfidScanActionResult> {
  if (isWriteBlocked()) return { ok: false, error: 'Modo somente leitura: alterações não são salvas.' }

  try {
    const result = await recordRfidScanBatch(
      {
        payload,
        operador: auth.registradoPor,
      },
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
