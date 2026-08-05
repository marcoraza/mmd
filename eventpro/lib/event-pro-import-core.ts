type Categoria =
  | 'ILUMINACAO'
  | 'AUDIO'
  | 'CABO'
  | 'ENERGIA'
  | 'ESTRUTURA'
  | 'EFEITO'
  | 'VIDEO'
  | 'ACESSORIO'

type StatusProjeto =
  | 'PLANEJAMENTO'
  | 'CONFIRMADO'
  | 'MONTAGEM'
  | 'EM_CAMPO'
  | 'FINALIZADO'
  | 'CANCELADO'

export type EventImportReviewStatus =
  | 'IMPORTADO_OFICIAL'
  | 'REVISAO_PENDENTE'
  | 'REVISAO_CONCLUIDA'

export type EventProLineKind = 'empty' | 'section' | 'service' | 'equipment'

export type EventProLineClassification = {
  kind: EventProLineKind
  normalizedName: string
  displayName: string
  categoriaSugerida: Categoria | null
}

const SERVICE_PATTERNS = [
  /\bPRODUTOR\b/,
  /\bPRODUCAO\b/,
  /\bCARREGADOR/,
  /\bLIMPEZA\b/,
  /\bRECEPCIONISTA/,
  /\bGARCOM\b/,
  /\bCUMIM\b/,
  /\bSEGURANCA\b/,
  /\bBOMBEIRO\b/,
  /\bDJ\b/,
  /\bARTISTICO\b/,
  /\bVIDEOMAKER\b/,
  /\bFOTOGRAF/,
  /\bBUFFET\b/,
  /\bALIMENTACAO\b/,
  /\bALIMENTA\b/,
  /\bBAR\b/,
  /\bVINHO/,
  /\bESPUMANTE/,
  /\bBOLO\b/,
  /\bDOCINHO/,
  /\bBEM CASADO\b/,
  /\bDECORACAO\b/,
  /\bTAXA\b/,
  /\bFRETE\b/,
  /\bTRANSPORTE\b/,
]

const SECTION_PATTERNS = [
  /\bSUBTOTAL\b/,
  /\bTOTAL\b/,
  /\bBUDGET\b/,
  /\bORCAMENTO\b/,
  /\bITEM\b/,
  /\bDESCRICAO\b/,
  /\bVALORES?\b/,
  /\bQTD\b/,
  /\bEQUIPE DE PRODUCAO\b/,
  /\bTECNOLOGIA\b/,
]

const CATEGORY_PATTERNS: [Categoria, RegExp[]][] = [
  [
    'AUDIO',
    [
      /\bQSC\b/,
      /\bRCF\b/,
      /\bJBL\b/,
      /\bSHURE\b/,
      /\bSENNHEISER\b/,
      /\bMICROFONE\b/,
      /\bMESA DE SOM\b/,
      /\bCAIXA\b/,
      /\bSUB\b/,
      /\bANTENA\b/,
      /\bIPAD\b/,
      /\bTABLET\b/,
      /\bNOTEBOOK\b/,
    ],
  ],
  [
    'ILUMINACAO',
    [
      /\bLED\b/,
      /\bLUZ\b/,
      /\bMOVING\b/,
      /\bBEAM\b/,
      /\bPAR\b/,
      /\bRIBALTA\b/,
      /\bCOB\b/,
      /\bSTROBO\b/,
      /\bLASER\b/,
    ],
  ],
  ['CABO', [/\bCABO\b/, /\bP10\b/, /\bP2\b/, /\bXLR\b/, /\bHDMI\b/, /\bSDI\b/]],
  ['ENERGIA', [/\bENERGIA\b/, /\bDISTRIBUIDOR\b/, /\bEXTENSAO\b/, /\bREGUA\b/]],
  ['ESTRUTURA', [/\bTRUSS\b/, /\bQ20\b/, /\bBOX\b/, /\bHOUSE\b/, /\bTOTEM\b/]],
  ['VIDEO', [/\bVIDEO\b/, /\bPAINEL\b/, /\bPROJETOR\b/, /\bTV\b/, /\bTELA\b/, /\bCAMERA\b/]],
  ['ACESSORIO', [/\bTRIPE\b/, /\bPEDESTAL\b/, /\bSUPORTE\b/, /\bCAPA\b/]],
]

const MONTHS = new Map([
  ['JAN', '01'],
  ['JANEIRO', '01'],
  ['FEV', '02'],
  ['FEVEREIRO', '02'],
  ['MAR', '03'],
  ['MARCO', '03'],
  ['ABR', '04'],
  ['ABRIL', '04'],
  ['MAI', '05'],
  ['MAIO', '05'],
  ['JUN', '06'],
  ['JUNHO', '06'],
  ['JUL', '07'],
  ['JULHO', '07'],
  ['AGO', '08'],
  ['AGOSTO', '08'],
  ['SET', '09'],
  ['SETEMBRO', '09'],
  ['OUT', '10'],
  ['OUTUBRO', '10'],
  ['NOV', '11'],
  ['NOVEMBRO', '11'],
  ['DEZ', '12'],
  ['DEZEMBRO', '12'],
])

export function normalizeEventImportText(value: unknown): string {
  if (value == null) return ''
  return String(value)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[\u2013\u2014]/g, '-')
    .replace(/\s+/g, ' ')
    .trim()
    .toUpperCase()
}

export function normalizeCandidateName(value: unknown): string {
  return normalizeEventImportText(value).replace(/[^A-Z0-9]+/g, ' ').trim()
}

export function sanitizeImportedEventName(value: string): string {
  const cleaned = value
    .replace(/\.xlsx$/i, '')
    .replace(/^cancelado\s*[-_]\s*/i, '')
    .replace(/^or[cç]amento\s*[-_]\s*/i, '')
    .replace(/[_]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()

  return cleaned || 'Evento importado'
}

export function buildEventCode(dateIso: string | null, sequence: number): string {
  const date = dateIso && /^\d{4}-\d{2}-\d{2}$/.test(dateIso) ? dateIso : '2026-06-23'
  const match = date.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (!match) return `EVT-260623-${String(sequence).padStart(2, '0')}`
  const [, year, month, day] = match
  return `EVT-${year.slice(2)}${month}${day}-${String(sequence).padStart(2, '0')}`
}

export function deriveImportedEventStatus({
  fileName,
  eventStartDate,
  nowIso = '2026-06-23',
  hasConfirmation = true,
}: {
  fileName: string
  eventStartDate: string | null
  nowIso?: string
  hasConfirmation?: boolean
}): StatusProjeto {
  if (normalizeEventImportText(fileName).includes('CANCELADO')) return 'CANCELADO'
  if (!eventStartDate) return hasConfirmation ? 'CONFIRMADO' : 'PLANEJAMENTO'
  if (eventStartDate < nowIso) return 'FINALIZADO'
  return hasConfirmation ? 'CONFIRMADO' : 'PLANEJAMENTO'
}

export function reviewStatusFromIssues(issueCount: number): EventImportReviewStatus {
  return issueCount > 0 ? 'REVISAO_PENDENTE' : 'IMPORTADO_OFICIAL'
}

export function parseEventDate(value: unknown, fallbackYear = 2026): string | null {
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value.toISOString().slice(0, 10)

  const text = normalizeEventImportText(value)
  if (!text || text.includes('A DEFINIR') || text.includes('N/A')) return null

  const iso = text.match(/\b(20\d{2})-(\d{2})-(\d{2})\b/)
  if (iso) return `${iso[1]}-${iso[2]}-${iso[3]}`

  const slash = text.match(/\b(\d{1,2})[/-](\d{1,2})(?:[/-](20\d{2}))?\b/)
  if (slash) return toIsoDate(Number(slash[1]), Number(slash[2]), Number(slash[3] ?? fallbackYear))

  const monthName = text.match(/\b(\d{1,2})\s*(JAN|JANEIRO|FEV|FEVEREIRO|MAR|MARCO|ABR|ABRIL|MAI|MAIO|JUN|JUNHO|JUL|JULHO|AGO|AGOSTO|SET|SETEMBRO|OUT|OUTUBRO|NOV|NOVEMBRO|DEZ|DEZEMBRO)\b/)
  if (monthName) {
    const month = MONTHS.get(monthName[2])
    if (month) return toIsoDate(Number(monthName[1]), Number(month), fallbackYear)
  }

  const compact = text.match(/^([0-3]\d)([0-1]\d)$/)
  if (compact) return toIsoDate(Number(compact[1]), Number(compact[2]), fallbackYear)

  return null
}

export function parseQuantityFromText(value: unknown): { quantity: number | null; label: string } {
  const raw = String(value ?? '').trim()
  const normalized = raw.replace(/\s+/g, ' ')
  const prefix = normalized.match(/^(\d+)\s*(?:x|X)?\s+(.+)$/)
  if (!prefix) return { quantity: null, label: normalized }
  const quantity = Number(prefix[1])
  return {
    quantity: Number.isInteger(quantity) && quantity > 0 ? quantity : null,
    label: prefix[2].trim(),
  }
}

export function classifyEventProLine(value: unknown): EventProLineClassification {
  const displayName = String(value ?? '').replace(/\s+/g, ' ').trim()
  const normalizedName = normalizeCandidateName(displayName)

  if (!normalizedName) return { kind: 'empty', normalizedName, displayName, categoriaSugerida: null }
  if (SECTION_PATTERNS.some((pattern) => pattern.test(normalizedName))) {
    return { kind: 'section', normalizedName, displayName, categoriaSugerida: null }
  }
  if (SERVICE_PATTERNS.some((pattern) => pattern.test(normalizedName))) {
    return { kind: 'service', normalizedName, displayName, categoriaSugerida: null }
  }

  return {
    kind: 'equipment',
    normalizedName,
    displayName,
    categoriaSugerida: guessCategoriaFromText(normalizedName),
  }
}

function guessCategoriaFromText(normalizedName: string): Categoria | null {
  for (const [categoria, patterns] of CATEGORY_PATTERNS) {
    if (patterns.some((pattern) => pattern.test(normalizedName))) return categoria
  }
  return null
}

function toIsoDate(day: number, month: number, year: number): string | null {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null
  const date = new Date(Date.UTC(year, month - 1, day))
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    return null
  }
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
}
