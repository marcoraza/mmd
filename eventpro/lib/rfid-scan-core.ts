export type RfidScanContext =
  | 'PACKING'
  | 'CARREGAMENTO'
  | 'CHECK_IN_EVENTO'
  | 'CHECK_OUT_EVENTO'
  | 'RETORNO'
  | 'CONFERENCIA'
  | 'INVENTARIO'
  | 'OUTRO'

export type RfidScanSerialMatch = {
  id: string
  codigo_interno: string
  item_nome: string | null
}

export type RfidScanResolved = {
  tag_rfid: string
  serial_id: string
  codigo_interno: string
  item_nome: string | null
}

export type RfidScanRow = {
  tag_rfid: string
  serial_number_id: string | null
  reader_id: string | null
  projeto_id: string | null
  operador: string
  contexto: RfidScanContext
  rssi: number | null
  localizacao: string | null
  notas: string | null
}

export type RfidScanPlanInput = {
  tags: string[]
  contexto: RfidScanContext
  projeto_id?: string | null
  operador: string
  reader_id?: string | null
  localizacao?: string | null
  rssiByTag?: Map<string, number>
  serialsByTag: Map<string, RfidScanSerialMatch>
}

export type RfidScanPlan = {
  tags: string[]
  resolved: RfidScanResolved[]
  unresolved: string[]
  scanRows: RfidScanRow[]
}

export type RfidScanReaderPayload = {
  nome?: string
  modelo?: string
  serial_fabrica?: string | null
  bateria?: number | null
}

export type RfidScanPayload = {
  tags: string[]
  contexto: RfidScanContext
  projeto_id: string | null
  localizacao: string | null
  reader: RfidScanReaderPayload | null
}

export type RfidScanPayloadResult =
  | { ok: true; payload: RfidScanPayload }
  | { ok: false; error: string }

export type RfidScanBatchInput = {
  payload: RfidScanPayload
  operador: string
}

export type RfidScanBatchResult = {
  ok: true
  resolved: RfidScanResolved[]
  unresolved: string[]
  scan_ids: string[]
}

export type RfidScanRepository = {
  upsertReader(reader: RfidScanReaderPayload): Promise<{ id: string }>
  findSerialsByTags(tags: string[]): Promise<Map<string, RfidScanSerialMatch>>
  insertScans(rows: RfidScanRow[]): Promise<Array<{ id: string }>>
}

const RFID_CONTEXTS: RfidScanContext[] = [
  'PACKING',
  'CARREGAMENTO',
  'CHECK_IN_EVENTO',
  'CHECK_OUT_EVENTO',
  'RETORNO',
  'CONFERENCIA',
  'INVENTARIO',
  'OUTRO',
]

export function normalizeRfidTag(raw: string) {
  return raw.trim().toUpperCase().replace(/[\s:-]+/g, '')
}

function isRfidScanContext(value: unknown): value is RfidScanContext {
  return typeof value === 'string' && RFID_CONTEXTS.includes(value as RfidScanContext)
}

function isValidTag(tag: string) {
  return tag.length >= 8 && tag.length <= 96 && /^[A-Z0-9]+$/.test(tag)
}

export function uniqueNormalizedTags(tags: string[]) {
  const seen = new Set<string>()
  const normalized: string[] = []

  for (const raw of tags) {
    const tag = normalizeRfidTag(raw)
    if (!tag || seen.has(tag)) continue
    seen.add(tag)
    normalized.push(tag)
  }

  return normalized
}

export function parseRfidScanPayload(raw: unknown): RfidScanPayloadResult {
  const body = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {}
  const tags = Array.isArray(body.tags)
    ? uniqueNormalizedTags(body.tags.filter((tag): tag is string => typeof tag === 'string'))
    : []

  if (tags.length === 0 || tags.some((tag) => !isValidTag(tag))) {
    return { ok: false, error: 'tags_invalidas' }
  }

  const contexto = isRfidScanContext(body.contexto) ? body.contexto : 'INVENTARIO'
  const projeto_id = typeof body.projeto_id === 'string' && body.projeto_id.trim() ? body.projeto_id : null
  const localizacao =
    typeof body.localizacao === 'string' && body.localizacao.trim() ? body.localizacao.trim() : null
  const reader =
    body.reader && typeof body.reader === 'object'
      ? normalizeReaderPayload(body.reader as Record<string, unknown>)
      : null

  return {
    ok: true,
    payload: {
      tags,
      contexto,
      projeto_id,
      localizacao,
      reader,
    },
  }
}

export function buildRfidScanPlan(input: RfidScanPlanInput): RfidScanPlan {
  const tags = uniqueNormalizedTags(input.tags)
  const resolved: RfidScanResolved[] = []
  const unresolved: string[] = []
  const scanRows: RfidScanRow[] = []

  for (const tag of tags) {
    const serial = input.serialsByTag.get(tag) ?? null
    if (serial) {
      resolved.push({
        tag_rfid: tag,
        serial_id: serial.id,
        codigo_interno: serial.codigo_interno,
        item_nome: serial.item_nome,
      })
    } else {
      unresolved.push(tag)
    }

    scanRows.push({
      tag_rfid: tag,
      serial_number_id: serial?.id ?? null,
      reader_id: input.reader_id ?? null,
      projeto_id: input.projeto_id ?? null,
      operador: input.operador,
      contexto: input.contexto,
      rssi: input.rssiByTag?.get(tag) ?? null,
      localizacao: input.localizacao ?? null,
      notas: serial ? null : 'Tag RFID não reconhecida',
    })
  }

  return {
    tags,
    resolved,
    unresolved,
    scanRows,
  }
}

export async function recordRfidScanBatch(
  input: RfidScanBatchInput,
  repository: RfidScanRepository,
): Promise<RfidScanBatchResult> {
  const reader = input.payload.reader?.serial_fabrica
    ? await repository.upsertReader(input.payload.reader)
    : null
  const serialsByTag = await repository.findSerialsByTags(input.payload.tags)
  const plan = buildRfidScanPlan({
    tags: input.payload.tags,
    contexto: input.payload.contexto,
    projeto_id: input.payload.projeto_id,
    operador: input.operador,
    reader_id: reader?.id ?? null,
    localizacao: input.payload.localizacao,
    serialsByTag,
  })
  const scans = await repository.insertScans(plan.scanRows)

  return {
    ok: true,
    resolved: plan.resolved,
    unresolved: plan.unresolved,
    scan_ids: scans.map((scan) => scan.id),
  }
}

function normalizeReaderPayload(reader: Record<string, unknown>): RfidScanReaderPayload {
  const serial =
    typeof reader.serial_fabrica === 'string' && reader.serial_fabrica.trim()
      ? reader.serial_fabrica.trim()
      : null
  const battery = typeof reader.bateria === 'number' && Number.isFinite(reader.bateria)
    ? Math.max(0, Math.min(100, Math.round(reader.bateria)))
    : null

  return {
    nome: typeof reader.nome === 'string' && reader.nome.trim() ? reader.nome.trim() : undefined,
    modelo: typeof reader.modelo === 'string' && reader.modelo.trim() ? reader.modelo.trim() : undefined,
    serial_fabrica: serial,
    bateria: battery,
  }
}
