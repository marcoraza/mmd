export const EVENTO_COMERCIAL_BUCKET = 'mmd-evento-comercial'
export const EVENTO_COMERCIAL_MAX_FILE_BYTES = 10 * 1024 * 1024

export const COMERCIAL_STATUS_OPTIONS = [
  { value: 'ORCAMENTO_ENVIADO', label: 'Orçamento enviado' },
  { value: 'ORCAMENTO_APROVADO', label: 'Orçamento aprovado' },
  { value: 'CONTRATO_ENVIADO', label: 'Contrato enviado' },
  { value: 'CONTRATO_ASSINADO', label: 'Contrato assinado' },
] as const

export type ComercialStatus = (typeof COMERCIAL_STATUS_OPTIONS)[number]['value']
export type DocumentoComercialTipo = 'ORCAMENTO' | 'CONTRATO'
export type DocumentoComercialOrigem = 'LINK' | 'UPLOAD'

export type EventoComercialDocumento = {
  id: string
  tipo: DocumentoComercialTipo
  origem: DocumentoComercialOrigem
  titulo: string
  url: string | null
  storage_path: string | null
  filename: string | null
  mime_type: string | null
  tamanho_bytes: number | null
  atualizado_em: string
  href?: string | null
}

export type EventoComercialRecord = {
  status: ComercialStatus | null
  documentos: EventoComercialDocumento[]
  observacoes: string | null
  atualizado_em: string | null
  permite_operacao_estoque: boolean
  readiness_pct: number
}

export type EventoComercialInput = {
  projetoId: string
  status: string | null
  orcamentoUrl?: string | null
  contratoUrl?: string | null
  observacoes?: string | null
}

export type UploadedEventoComercialDocumento = {
  tipo: DocumentoComercialTipo
  filename: string
  storage_path: string
  mime_type: string | null
  tamanho_bytes: number | null
}

export type NormalizedEventoComercial = {
  projetoId: string
  comercial: EventoComercialRecord
}

export type ComercialValidationResult =
  | { ok: true; data: NormalizedEventoComercial }
  | { ok: false; error: string }

const STATUS_VALUES = new Set<string>(COMERCIAL_STATUS_OPTIONS.map((option) => option.value))
const STATUS_INDEX = new Map<string, number>(
  COMERCIAL_STATUS_OPTIONS.map((option, index) => [option.value, index]),
)

const DOCUMENT_TITLES: Record<DocumentoComercialTipo, string> = {
  ORCAMENTO: 'Orçamento',
  CONTRATO: 'Contrato',
}

export function isComercialStatus(value: string | null | undefined): value is ComercialStatus {
  return typeof value === 'string' && STATUS_VALUES.has(value)
}

export function comercialStatusLabel(status: ComercialStatus | null | undefined) {
  return COMERCIAL_STATUS_OPTIONS.find((option) => option.value === status)?.label ?? 'Sem status'
}

export function statusAllowsEstoque(status: ComercialStatus | null | undefined) {
  return (
    status === 'ORCAMENTO_APROVADO' ||
    status === 'CONTRATO_ENVIADO' ||
    status === 'CONTRATO_ASSINADO'
  )
}

export function comercialReadinessPct(status: ComercialStatus | null | undefined) {
  if (!status) return 0
  const index = STATUS_INDEX.get(status)
  if (index === undefined) return 0
  return Math.round(((index + 1) / COMERCIAL_STATUS_OPTIONS.length) * 100)
}

export function emptyEventoComercialRecord(): EventoComercialRecord {
  return {
    status: null,
    documentos: [],
    observacoes: null,
    atualizado_em: null,
    permite_operacao_estoque: false,
    readiness_pct: 0,
  }
}

function trimToNull(value: string | null | undefined) {
  const trimmed = value?.trim()
  return trimmed ? trimmed : null
}

export function normalizeCommercialUrl(value: string | null | undefined, label: string) {
  const raw = trimToNull(value)
  if (!raw) return { ok: true as const, data: null }

  let parsed: URL
  try {
    parsed = new URL(raw)
  } catch {
    return { ok: false as const, error: `${label} precisa ser uma URL válida.` }
  }

  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    return { ok: false as const, error: `${label} precisa começar com http ou https.` }
  }

  return { ok: true as const, data: parsed.toString() }
}

export function safeCommercialFileName(filename: string) {
  const cleaned = filename
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9._-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 96)

  return cleaned || 'documento'
}

function documentId(tipo: DocumentoComercialTipo, origem: DocumentoComercialOrigem, key: string) {
  return `${tipo.toLowerCase()}-${origem.toLowerCase()}-${key}`
}

function linkDocument(tipo: DocumentoComercialTipo, url: string, now: string): EventoComercialDocumento {
  const key = safeCommercialFileName(url).slice(0, 32)
  return {
    id: documentId(tipo, 'LINK', key),
    tipo,
    origem: 'LINK',
    titulo: `${DOCUMENT_TITLES[tipo]} linkado`,
    url,
    storage_path: null,
    filename: null,
    mime_type: null,
    tamanho_bytes: null,
    atualizado_em: now,
  }
}

function uploadDocument(
  upload: UploadedEventoComercialDocumento,
  now: string,
): EventoComercialDocumento {
  return {
    id: documentId(upload.tipo, 'UPLOAD', upload.storage_path.split('/').pop() ?? now),
    tipo: upload.tipo,
    origem: 'UPLOAD',
    titulo: `${DOCUMENT_TITLES[upload.tipo]} anexado`,
    url: null,
    storage_path: upload.storage_path,
    filename: upload.filename,
    mime_type: upload.mime_type,
    tamanho_bytes: upload.tamanho_bytes,
    atualizado_em: now,
  }
}

function normalizeExistingDocuments(docs: unknown): EventoComercialDocumento[] {
  if (!Array.isArray(docs)) return []
  return docs.filter((doc): doc is EventoComercialDocumento => {
    if (!doc || typeof doc !== 'object') return false
    const candidate = doc as Partial<EventoComercialDocumento>
    return (
      (candidate.tipo === 'ORCAMENTO' || candidate.tipo === 'CONTRATO') &&
      (candidate.origem === 'LINK' || candidate.origem === 'UPLOAD') &&
      typeof candidate.id === 'string'
    )
  })
}

export function parseEventoComercialRecord(value: unknown): EventoComercialRecord {
  if (!value || typeof value !== 'object') return emptyEventoComercialRecord()
  const row = value as Partial<EventoComercialRecord>
  const status = isComercialStatus(row.status) ? row.status : null
  return {
    status,
    documentos: normalizeExistingDocuments(row.documentos),
    observacoes: trimToNull(row.observacoes),
    atualizado_em: trimToNull(row.atualizado_em),
    permite_operacao_estoque: statusAllowsEstoque(status),
    readiness_pct: comercialReadinessPct(status),
  }
}

export function normalizeEventoComercialInput(
  input: EventoComercialInput,
  existingDocs: EventoComercialDocumento[] = [],
  uploadedDocs: UploadedEventoComercialDocumento[] = [],
  now = new Date().toISOString(),
): ComercialValidationResult {
  const projetoId = trimToNull(input.projetoId)
  if (!projetoId) return { ok: false, error: 'Evento obrigatório.' }

  const status = trimToNull(input.status)
  if (!isComercialStatus(status)) return { ok: false, error: 'Status comercial inválido.' }

  const orcamentoUrl = normalizeCommercialUrl(input.orcamentoUrl, 'Link do orçamento')
  if (!orcamentoUrl.ok) return orcamentoUrl

  const contratoUrl = normalizeCommercialUrl(input.contratoUrl, 'Link do contrato')
  if (!contratoUrl.ok) return contratoUrl

  const preservedUploads = existingDocs.filter((doc) => doc.origem === 'UPLOAD')
  const documentos: EventoComercialDocumento[] = []

  if (orcamentoUrl.data) documentos.push(linkDocument('ORCAMENTO', orcamentoUrl.data, now))
  if (contratoUrl.data) documentos.push(linkDocument('CONTRATO', contratoUrl.data, now))

  documentos.push(...preservedUploads)
  documentos.push(...uploadedDocs.map((upload) => uploadDocument(upload, now)))

  return {
    ok: true,
    data: {
      projetoId,
      comercial: {
        status,
        documentos,
        observacoes: trimToNull(input.observacoes),
        atualizado_em: now,
        permite_operacao_estoque: statusAllowsEstoque(status),
        readiness_pct: comercialReadinessPct(status),
      },
    },
  }
}
