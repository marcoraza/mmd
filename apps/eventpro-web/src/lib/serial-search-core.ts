// Regra pura da busca de seriais para vínculo de tag (contrato §8).
//
// Substitui a busca client-side do iOS, que baixava o catálogo inteiro e
// filtrava em memória. Aqui só normalização e validação: a consulta fica na
// camada de dados.

export const SERIAL_SEARCH_DEFAULT_LIMIT = 25
export const SERIAL_SEARCH_MAX_LIMIT = 100
export const SERIAL_SEARCH_MIN_QUERY = 2
export const SERIAL_SEARCH_MAX_QUERY = 64

// Mesmo espírito de `normalizeInternalQrLookupCode`: sem vírgula, parêntese,
// aspas ou `*`, que são a sintaxe de filtro do PostgREST. Sanitizar aqui é o
// que impede injeção de filtro na consulta montada depois.
const SAFE_QUERY = /^[A-Za-z0-9._:\- ]+$/
const UUID = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/

export const SERIAL_SEARCH_INVALID_PARAMS = 'parametros_invalidos'

export type SerialSearchParams = {
  q: string | null
  itemId: string | null
  semTag: boolean
  limit: number
  offset: number
}

export type SerialSearchParamsResult =
  | { ok: true; params: SerialSearchParams }
  | { ok: false; error: typeof SERIAL_SEARCH_INVALID_PARAMS }

export type SerialSearchItem = {
  serial_id: string
  codigo_interno: string
  item_nome: string | null
  tag_rfid: string | null
}

export type SerialSearchResponse = {
  items: SerialSearchItem[]
  total: number
  limit: number
  offset: number
  has_more: boolean
}

function invalid(): SerialSearchParamsResult {
  return { ok: false, error: SERIAL_SEARCH_INVALID_PARAMS }
}

function parseBoolean(raw: string | null): boolean {
  if (raw == null) return false
  const normalized = raw.trim().toLowerCase()
  return normalized === '1' || normalized === 'true' || normalized === 'yes' || normalized === 'on'
}

// `limit` acima do teto não é erro, é silenciosamente reduzido (contrato §8.4,
// mesmo tratamento de `bateria` em /api/rfid/scans). Negativo e não inteiro são
// erro.
function parseInteger(raw: string | null, fallback: number): number | null {
  if (raw == null || raw.trim() === '') return fallback
  const trimmed = raw.trim()
  if (!/^-?\d+$/.test(trimmed)) return null
  const parsed = Number(trimmed)
  if (!Number.isInteger(parsed) || parsed < 0) return null
  return parsed
}

export function parseSerialSearchParams(search: URLSearchParams): SerialSearchParamsResult {
  const rawQ = search.get('q')
  let q: string | null = null
  if (rawQ != null && rawQ.trim() !== '') {
    const trimmed = rawQ.trim()
    if (trimmed.length < SERIAL_SEARCH_MIN_QUERY || trimmed.length > SERIAL_SEARCH_MAX_QUERY) {
      return invalid()
    }
    if (!SAFE_QUERY.test(trimmed)) return invalid()
    q = trimmed
  }

  const rawItemId = search.get('item_id')
  let itemId: string | null = null
  if (rawItemId != null && rawItemId.trim() !== '') {
    const trimmed = rawItemId.trim()
    if (!UUID.test(trimmed)) return invalid()
    // Ids vindos do Swift chegam em maiúsculas (divergência D9). Normalizar
    // aqui evita que qualquer comparação textual adiante erre.
    itemId = trimmed.toLowerCase()
  }

  const parsedLimit = parseInteger(search.get('limit'), SERIAL_SEARCH_DEFAULT_LIMIT)
  if (parsedLimit == null) return invalid()

  const parsedOffset = parseInteger(search.get('offset'), 0)
  if (parsedOffset == null) return invalid()

  return {
    ok: true,
    params: {
      q,
      itemId,
      semTag: parseBoolean(search.get('sem_tag')),
      limit: Math.min(Math.max(parsedLimit, 1), SERIAL_SEARCH_MAX_LIMIT),
      offset: parsedOffset,
    },
  }
}

export function buildSerialSearchResponse(input: {
  items: SerialSearchItem[]
  total: number
  limit: number
  offset: number
}): SerialSearchResponse {
  return {
    items: input.items,
    total: input.total,
    limit: input.limit,
    offset: input.offset,
    has_more: input.offset + input.items.length < input.total,
  }
}
