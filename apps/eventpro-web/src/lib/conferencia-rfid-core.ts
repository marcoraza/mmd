// Regra pura da conferência RFID de Evento (contrato §7).
//
// A conferência cruza as tags lidas com `packing_allocations` e devolve quatro
// buckets. O cruzamento em si é a RPC `conferencia_rfid_evento`, que também
// grava a telemetria; aqui ficam a validação do payload e a montagem da
// resposta a partir das linhas classificadas que a RPC devolve.

import { normalizeRfidTag, type RfidScanReaderPayload } from './rfid-scan-core.ts'
import type { StatusProjeto } from './types.ts'

// Diferente de /api/rfid/scans, aqui o contexto é obrigatório e restrito.
// Contexto ausente ou inválido é erro, não default silencioso (divergência D8).
export const CONFERENCIA_CONTEXTS = ['CARREGAMENTO', 'RETORNO', 'CONFERENCIA'] as const

export type ConferenciaContexto = (typeof CONFERENCIA_CONTEXTS)[number]

export type ConferenciaPayload = {
  tags: string[]
  contexto: ConferenciaContexto
  localizacao: string | null
  reader: RfidScanReaderPayload | null
}

export type ConferenciaPayloadResult =
  | { ok: true; payload: ConferenciaPayload }
  | { ok: false; error: 'tags_invalidas' | 'contexto_invalido' }

export type ConferenciaClassificacao = 'CONFIRMADO' | 'FALTANTE' | 'EXTRA' | 'DESCONHECIDA'

// Uma linha por resultado da RPC `conferencia_rfid_evento`.
export type ConferenciaRpcRow = {
  classificacao: string
  tag_rfid: string | null
  serial_id: string | null
  codigo_interno: string | null
  item_nome: string | null
  scan_id: string | null
  ordem: number | null
}

export type ConferenciaUnidade = {
  serial_id: string
  codigo_interno: string
  item_nome: string | null
  tag_rfid: string | null
}

export type ConferenciaResponse = {
  evento: { id: string; nome: string; status: StatusProjeto }
  contexto: ConferenciaContexto
  confirmados: ConferenciaUnidade[]
  faltantes: ConferenciaUnidade[]
  extras: ConferenciaUnidade[]
  desconhecidas: string[]
  resumo: {
    esperados: number
    confirmados: number
    faltantes: number
    extras: number
    desconhecidas: number
    cobertura_pct: number
  }
  scan_ids: string[]
}

function isValidTag(tag: string) {
  return tag.length >= 8 && tag.length <= 96 && /^[A-Z0-9]+$/.test(tag)
}

// Mesma normalização e deduplicação de /api/rfid/scans, com a ordem de leitura
// preservada (contrato §7.2).
export function uniqueConferenciaTags(tags: unknown[]): string[] {
  const seen = new Set<string>()
  const normalized: string[] = []

  for (const raw of tags) {
    if (typeof raw !== 'string') continue
    const tag = normalizeRfidTag(raw)
    if (!tag || seen.has(tag)) continue
    seen.add(tag)
    normalized.push(tag)
  }

  return normalized
}

function isConferenciaContexto(value: unknown): value is ConferenciaContexto {
  return typeof value === 'string' && CONFERENCIA_CONTEXTS.includes(value as ConferenciaContexto)
}

function normalizeReaderPayload(reader: Record<string, unknown>): RfidScanReaderPayload {
  const serial =
    typeof reader.serial_fabrica === 'string' && reader.serial_fabrica.trim()
      ? reader.serial_fabrica.trim()
      : null
  const bateria =
    typeof reader.bateria === 'number' && Number.isFinite(reader.bateria)
      ? Math.max(0, Math.min(100, Math.round(reader.bateria)))
      : null

  return {
    nome: typeof reader.nome === 'string' && reader.nome.trim() ? reader.nome.trim() : undefined,
    modelo:
      typeof reader.modelo === 'string' && reader.modelo.trim() ? reader.modelo.trim() : undefined,
    serial_fabrica: serial,
    bateria,
  }
}

export function parseConferenciaPayload(raw: unknown): ConferenciaPayloadResult {
  const body = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {}

  const tags = Array.isArray(body.tags) ? uniqueConferenciaTags(body.tags) : []
  if (tags.length === 0 || tags.some((tag) => !isValidTag(tag))) {
    return { ok: false, error: 'tags_invalidas' }
  }

  if (!isConferenciaContexto(body.contexto)) {
    return { ok: false, error: 'contexto_invalido' }
  }

  const localizacao =
    typeof body.localizacao === 'string' && body.localizacao.trim() ? body.localizacao.trim() : null

  const reader =
    body.reader && typeof body.reader === 'object'
      ? normalizeReaderPayload(body.reader as Record<string, unknown>)
      : null

  return {
    ok: true,
    payload: { tags, contexto: body.contexto, localizacao, reader },
  }
}

function toUnidade(row: ConferenciaRpcRow): ConferenciaUnidade | null {
  if (!row.serial_id || !row.codigo_interno) return null
  return {
    serial_id: row.serial_id,
    codigo_interno: row.codigo_interno,
    item_nome: row.item_nome ?? null,
    tag_rfid: row.tag_rfid ?? null,
  }
}

// Invariantes do contrato §7.4:
//   confirmados + extras + desconhecidas === tags.length (já deduplicadas)
//   confirmados + faltantes === resumo.esperados
export function buildConferenciaResponse(input: {
  evento: { id: string; nome: string; status: StatusProjeto }
  contexto: ConferenciaContexto
  tags: string[]
  rows: ConferenciaRpcRow[]
}): ConferenciaResponse {
  const ordemPorTag = new Map(input.tags.map((tag, index) => [tag, index]))
  const byOrdem = (a: ConferenciaRpcRow, b: ConferenciaRpcRow) =>
    (ordemPorTag.get(a.tag_rfid ?? '') ?? Number.MAX_SAFE_INTEGER) -
    (ordemPorTag.get(b.tag_rfid ?? '') ?? Number.MAX_SAFE_INTEGER)

  const rowsBy = (classificacao: ConferenciaClassificacao) =>
    input.rows.filter((row) => row.classificacao === classificacao)

  const confirmados = rowsBy('CONFIRMADO')
    .sort(byOrdem)
    .map(toUnidade)
    .filter((row): row is ConferenciaUnidade => row != null)

  const extras = rowsBy('EXTRA')
    .sort(byOrdem)
    .map(toUnidade)
    .filter((row): row is ConferenciaUnidade => row != null)

  // `tag_rfid` do faltante é a tag cadastrada na unidade, e é null quando a
  // unidade ainda não tem etiqueta vinculada, que é justamente o caso a
  // destacar na UI.
  const faltantes = rowsBy('FALTANTE')
    .map(toUnidade)
    .filter((row): row is ConferenciaUnidade => row != null)
    .sort((a, b) => a.codigo_interno.localeCompare(b.codigo_interno))

  const desconhecidas = rowsBy('DESCONHECIDA')
    .sort(byOrdem)
    .map((row) => row.tag_rfid)
    .filter((tag): tag is string => typeof tag === 'string')

  // Uma entrada por tag lida, na ordem de leitura, resolvida ou não.
  const scanIdByTag = new Map<string, string>()
  for (const row of input.rows) {
    if (row.scan_id && row.tag_rfid && !scanIdByTag.has(row.tag_rfid)) {
      scanIdByTag.set(row.tag_rfid, row.scan_id)
    }
  }
  const scan_ids = input.tags
    .map((tag) => scanIdByTag.get(tag))
    .filter((id): id is string => typeof id === 'string')

  const esperados = confirmados.length + faltantes.length

  return {
    evento: input.evento,
    contexto: input.contexto,
    confirmados,
    faltantes,
    extras,
    desconhecidas,
    resumo: {
      esperados,
      confirmados: confirmados.length,
      faltantes: faltantes.length,
      extras: extras.length,
      desconhecidas: desconhecidas.length,
      cobertura_pct: esperados > 0 ? Math.round((confirmados.length / esperados) * 100) : 0,
    },
    scan_ids,
  }
}
