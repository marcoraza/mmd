import { createHash } from 'node:crypto'
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { readFile } from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import ExcelJS from 'exceljs'
import {
  buildEventCode,
  classifyEventProLine,
  deriveImportedEventStatus,
  normalizeCandidateName,
  normalizeEventImportText,
  parseEventDate,
  parseQuantityFromText,
  reviewStatusFromIssues,
  sanitizeImportedEventName,
  type EventImportReviewStatus,
} from '../src/lib/event-pro-import-core.ts'

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

type CatalogItem = {
  id: string
  codigo_interno: string | null
  nome: string
  categoria: Categoria
  subcategoria: string | null
  marca: string | null
  modelo: string | null
  quantidade_total: number | null
}

type CatalogSearchItem = CatalogItem & {
  searchText: string
  searchTokens: string[]
}

type Metadata = {
  explicit: boolean
  eventName: string | null
  client: string | null
  local: string | null
  address: string | null
  startDate: string | null
  endDate: string | null
  montagemDate: string | null
  desmontagemDate: string | null
}

type RawLine = {
  sheetName: string
  rowNumber: number
  displayName: string
  normalizedName: string
  quantity: number
  categoriaSugerida: Categoria | null
  kind: 'equipment' | 'service' | 'section'
}

type ImportIssue = {
  issue_type:
    | 'MONTAGEM_PENDENTE'
    | 'PACKING_AMBIGUO'
    | 'CATALOGO_CANDIDATO'
    | 'LINHA_SERVICO_IGNORADA'
    | 'EVENTO_CANCELADO'
    | 'DATA_INCONSISTENTE'
    | 'MULTI_ABA_EVENTO'
  severity: 'INFO' | 'ATENCAO' | 'BLOQUEIO'
  source_sheet?: string
  source_row?: number
  raw_label?: string
  raw_value?: string
  normalized_value?: string
  details?: Record<string, unknown>
  candidate_id?: string
}

type EventDraft = {
  fileName: string
  sheetName: string
  name: string
  client: string | null
  local: string | null
  address: string | null
  dataInicio: string
  dataFim: string
  montagemDate: string | null
  desmontagemDate: string | null
  status: StatusProjeto
  importStatus: EventImportReviewStatus
  lines: RawLine[]
  issues: ImportIssue[]
}

type FileDraft = {
  filePath: string
  fileName: string
  sourceHash: string
  sheetsCount: number
  events: EventDraft[]
}

type Args = {
  input: string
  apply: boolean
  json: boolean
}

const DEFAULT_INPUT = '/Users/marko/Downloads/Eventos Event Pro (1)'
const IMPORT_BUCKET = 'mmd-event-pro-imports'
const XLSX_MIME = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
const NOW_ISO = '2026-06-23'

const STOPWORDS = new Set([
  'A',
  'AS',
  'AO',
  'AOS',
  'COM',
  'DA',
  'DAS',
  'DE',
  'DO',
  'DOS',
  'E',
  'EM',
  'NA',
  'NO',
  'PARA',
  'POR',
])

const METADATA_KEYS = {
  name: ['EVENTO', 'NOME DO EVENTO', 'ACAO'],
  client: ['CLIENTE'],
  local: ['LOCAL'],
  address: ['ENDERECO'],
  start: ['INICIO EVENTO', 'DATA E HORARIO DE INICIO DO EVENTO', 'DATA'],
  end: ['FIM EVENTO', 'DATA E HORARIO DO FIM DO EVENTO'],
  montagem: ['MONTAGEM', 'DATA E HORARIO DA MONTAGEM'],
  desmontagem: ['DESMONTAGEM', 'DATA E HORARIO DA DESMONTAGEM'],
}

const __dirname = path.dirname(fileURLToPath(import.meta.url))
loadEnv(path.join(__dirname, '..', '.env.local'))
loadEnv(path.join(__dirname, '..', '.env'))

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error)
    process.exitCode = 1
  })
}

async function main() {
  const args = parseArgs(process.argv.slice(2))
  const files = readdirSync(args.input)
    .filter((name) => name.toLowerCase().endsWith('.xlsx'))
    .sort((a, b) => a.localeCompare(b, 'pt-BR'))
    .map((name) => path.join(args.input, name))

  if (files.length === 0) throw new Error(`Nenhum XLSX encontrado em ${args.input}`)

  const supabase = createSupabaseClient(args.apply)
  const catalog = supabase ? await loadCatalog(supabase) : []
  const existingCodes = args.apply && supabase ? await loadExistingEventCodes(supabase) : new Set<string>()
  const catalogSearch = catalog.map(toCatalogSearchItem)
  const drafts: FileDraft[] = []

  for (const filePath of files) {
    drafts.push(await buildFileDraft(filePath, catalogSearch))
  }

  const drySummary = summarizeDrafts(drafts)
  if (!args.apply) {
    printSummary({ mode: 'dry-run', ...drySummary }, args.json)
    return
  }

  if (!supabase) throw new Error('Credenciais Supabase ausentes para --apply')
  const applied = await applyDrafts({ supabase, drafts, existingCodes, catalogSearch })
  printSummary({ mode: 'apply', ...applied }, args.json)
}

function parseArgs(argv: string[]): Args {
  const argMap = new Map<string, string>()
  const flags = new Set<string>()

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    if (arg.startsWith('--') && argv[index + 1] && !argv[index + 1].startsWith('--')) {
      argMap.set(arg, argv[index + 1])
      index += 1
    } else if (arg.startsWith('--')) {
      flags.add(arg)
    }
  }

  return {
    input: argMap.get('--input') ?? DEFAULT_INPUT,
    apply: flags.has('--apply'),
    json: flags.has('--json'),
  }
}

function loadEnv(filePath: string) {
  if (!existsSync(filePath)) return
  const content = readFileSync(filePath, 'utf8')
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue
    const match = trimmed.match(/^([A-Z0-9_]+)=(.*)$/)
    if (!match) continue
    const [, key, rawValue] = match
    if (process.env[key]) continue
    process.env[key] = rawValue.replace(/^['"]|['"]$/g, '')
  }
}

function createSupabaseClient(required: boolean): SupabaseClient | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !key) {
    if (required) {
      throw new Error('Faltam NEXT_PUBLIC_SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY')
    }
    return null
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}

async function loadCatalog(supabase: SupabaseClient): Promise<CatalogItem[]> {
  const { data, error } = await supabase
    .from('items')
    .select('id, codigo_interno, nome, categoria, subcategoria, marca, modelo, quantidade_total')
    .order('nome')

  if (error) throw new Error(`Falha ao carregar catálogo: ${error.message}`)
  return (data ?? []) as CatalogItem[]
}

async function loadExistingEventCodes(supabase: SupabaseClient): Promise<Set<string>> {
  const { data, error } = await supabase
    .from('projetos')
    .select('codigo_evento')
    .not('codigo_evento', 'is', null)

  if (error) throw new Error(`Falha ao carregar códigos existentes: ${error.message}`)
  return new Set((data ?? []).map((row) => row.codigo_evento).filter(Boolean) as string[])
}

export async function buildFileDraft(
  filePath: string,
  catalog: CatalogSearchItem[],
): Promise<FileDraft> {
  const fileName = path.basename(filePath)
  const sourceHash = createHash('sha256').update(await readFile(filePath)).digest('hex')
  const workbook = new ExcelJS.Workbook()
  await workbook.xlsx.readFile(filePath)

  const sheetDrafts = workbook.worksheets.map((worksheet) =>
    buildSheetDraft({ worksheet, fileName, catalog }),
  )

  const events: EventDraft[] = []
  const canceled = normalizeEventImportText(fileName).includes('CANCELADO')

  for (const draft of sheetDrafts) {
    const isListSheet = /LISTA|EQUIPAMENTO/i.test(draft.sheetName)
    const hasMetadata = draft.metadata.explicit
    const hasEquipment = draft.lines.some((line) => line.kind === 'equipment')
    const financeOnly = /CUSTO|BUDGET|FINANCEIRO|CRONOGRAMA/i.test(draft.sheetName) && !hasEquipment

    if (financeOnly) continue

    if (isListSheet && events.length > 0) {
      events[events.length - 1].lines.push(...draft.lines)
      events[events.length - 1].issues.push({
        issue_type: 'MULTI_ABA_EVENTO',
        severity: 'INFO',
        source_sheet: draft.sheetName,
        details: { motivo: 'Aba de lista anexada ao evento anterior do arquivo.' },
      })
      continue
    }

    if (hasMetadata || hasEquipment) {
      events.push(toEventDraft({ fileName, sheetName: draft.sheetName, metadata: draft.metadata, lines: draft.lines }))
    }
  }

  if (events.length === 0) {
    const fallback = toEventDraft({
      fileName,
      sheetName: workbook.worksheets[0]?.name ?? 'Planilha',
      metadata: emptyMetadata(),
      lines: [],
    })
    fallback.issues.push({
      issue_type: 'DATA_INCONSISTENTE',
      severity: 'ATENCAO',
      raw_label: 'arquivo',
      raw_value: fileName,
      details: { motivo: 'Nenhum evento claro foi encontrado no arquivo.' },
    })
    events.push(fallback)
  }

  if (canceled) {
    const first = events[0]
    first.status = 'CANCELADO'
    first.lines = []
    first.issues = [
      {
        issue_type: 'EVENTO_CANCELADO',
        severity: 'INFO',
        source_sheet: first.sheetName,
        details: { regra: 'Evento cancelado entra como histórico administrativo, sem packing.' },
      },
    ]
    first.importStatus = reviewStatusFromIssues(first.issues.length)
    events.splice(1)
  }

  return { filePath, fileName, sourceHash, sheetsCount: workbook.worksheets.length, events }
}

function buildSheetDraft({
  worksheet,
  fileName,
  catalog,
}: {
  worksheet: ExcelJS.Worksheet
  fileName: string
  catalog: CatalogSearchItem[]
}) {
  const rows = worksheetToRows(worksheet)
  const metadata = extractMetadata(rows, worksheet.name, fileName)
  const lines = extractLines(rows, worksheet.name, catalog)
  return { sheetName: worksheet.name, metadata, lines }
}

function worksheetToRows(worksheet: ExcelJS.Worksheet): unknown[][] {
  const rows: unknown[][] = []
  const maxColumn = Math.min(Math.max(worksheet.columnCount, 1), 30)
  const maxRow = Math.min(Math.max(worksheet.rowCount, 1), 1500)

  for (let rowNumber = 1; rowNumber <= maxRow; rowNumber += 1) {
    const row = worksheet.getRow(rowNumber)
    const values: unknown[] = []
    let hasValue = false
    for (let column = 1; column <= maxColumn; column += 1) {
      const value = normalizeExcelCellValue(row.getCell(column).value)
      values.push(value)
      if (cellText(value)) hasValue = true
    }
    if (hasValue) rows[rowNumber - 1] = values
  }

  return rows
}

function extractMetadata(rows: unknown[][], sheetName: string, fileName: string): Metadata {
  const metadata = emptyMetadata()
  const fallbackYear = extractYear(sheetName) ?? extractYear(fileName) ?? 2026

  for (let rowIndex = 0; rowIndex < Math.min(rows.length, 40); rowIndex += 1) {
    const row = rows[rowIndex] ?? []
    for (let column = 0; column < row.length; column += 1) {
      const label = normalizeLabel(row[column])
      if (!label || label.includes('DATA DO ORCAMENTO')) continue
      const value = firstValueToRight(row, column)

      if (!metadata.eventName && matchesAny(label, METADATA_KEYS.name)) {
        metadata.eventName = cellText(value)
        metadata.explicit = true
      }
      if (!metadata.client && matchesAny(label, METADATA_KEYS.client)) {
        metadata.client = cellText(value)
        metadata.explicit = true
      }
      if (!metadata.local && matchesAny(label, METADATA_KEYS.local)) {
        metadata.local = cellText(value)
        metadata.explicit = true
      }
      if (!metadata.address && matchesAny(label, METADATA_KEYS.address)) {
        metadata.address = cellText(value)
        metadata.explicit = true
      }
      if (!metadata.startDate && matchesAny(label, METADATA_KEYS.start)) {
        metadata.startDate = parseEventDate(value, fallbackYear)
        metadata.explicit = true
      }
      if (!metadata.endDate && matchesAny(label, METADATA_KEYS.end)) {
        metadata.endDate = parseEventDate(value, fallbackYear)
        metadata.explicit = true
      }
      if (!metadata.montagemDate && matchesAny(label, METADATA_KEYS.montagem)) {
        metadata.montagemDate = parseEventDate(value, fallbackYear)
        metadata.explicit = true
      }
      if (!metadata.desmontagemDate && matchesAny(label, METADATA_KEYS.desmontagem)) {
        metadata.desmontagemDate = parseEventDate(value, fallbackYear)
        metadata.explicit = true
      }
    }
  }

  if (!metadata.startDate) metadata.startDate = firstDateInRows(rows, fallbackYear)
  if (!metadata.eventName) metadata.eventName = inferTitleFromSheet(rows, sheetName, fileName)
  if (!metadata.startDate) {
    metadata.startDate = parseEventDate(sheetName, fallbackYear) ?? parseEventDate(fileName, fallbackYear)
  }
  if (!metadata.endDate) metadata.endDate = metadata.startDate
  return metadata
}

function emptyMetadata(): Metadata {
  return {
    explicit: false,
    eventName: null,
    client: null,
    local: null,
    address: null,
    startDate: null,
    endDate: null,
    montagemDate: null,
    desmontagemDate: null,
  }
}

function extractLines(rows: unknown[][], sheetName: string, catalog: CatalogSearchItem[]): RawLine[] {
  const lines: RawLine[] = []
  const seen = new Set<string>()

  for (let rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
    const row = rows[rowIndex] ?? []
    const header = detectLineHeader(row)
    if (!header) continue

    let blankStreak = 0
    for (let index = rowIndex + 1; index < rows.length; index += 1) {
      const current = rows[index] ?? []
      if (detectLineHeader(current)) break

      const rawDesc = cellText(current[header.descriptionColumn])
      const rawQty = firstQuantity(current, header.quantityColumns)
      const parsed = parseQuantityFromText(rawDesc)
      const quantity = rawQty ?? parsed.quantity
      const displayName = parsed.quantity ? parsed.label : rawDesc

      if (!rawDesc && !quantity) {
        blankStreak += 1
        if (blankStreak >= 15) break
        continue
      }
      blankStreak = 0
      if (!displayName || !quantity || quantity <= 0 || quantity > 500) continue

      const classification = classifyEventProLine(displayName)
      if (classification.kind === 'empty') continue

      const key = `${sheetName}:${index + 1}:${classification.normalizedName}:${quantity}`
      if (seen.has(key)) continue
      seen.add(key)

      const line: RawLine = {
        sheetName,
        rowNumber: index + 1,
        displayName: classification.displayName,
        normalizedName: classification.normalizedName,
        quantity,
        categoriaSugerida: classification.categoriaSugerida,
        kind: classification.kind,
      }

      if (line.kind === 'equipment') {
        const match = matchCatalogLine(line, catalog)
        if (match.kind === 'matched') {
          line.categoriaSugerida = match.item.categoria
        }
      }

      lines.push(line)
    }
  }

  if (lines.length === 0) {
    for (let rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
      const row = rows[rowIndex] ?? []
      const first = cellText(row[0])
      const second = cellText(row[1])
      const quantity = parsePositiveInteger(first)
      const label = quantity ? second : parseQuantityFromText(first).label
      const parsedQuantity = quantity ?? parseQuantityFromText(first).quantity
      if (!label || !parsedQuantity || parsedQuantity > 500) continue
      const classification = classifyEventProLine(label)
      if (classification.kind !== 'equipment') continue
      lines.push({
        sheetName,
        rowNumber: rowIndex + 1,
        displayName: classification.displayName,
        normalizedName: classification.normalizedName,
        quantity: parsedQuantity,
        categoriaSugerida: classification.categoriaSugerida,
        kind: 'equipment',
      })
    }
  }

  return lines
}

function toEventDraft({
  fileName,
  sheetName,
  metadata,
  lines,
}: {
  fileName: string
  sheetName: string
  metadata: Metadata
  lines: RawLine[]
}): EventDraft {
  const issues: ImportIssue[] = []
  const inferredStart = metadata.startDate ?? parseEventDate(fileName) ?? NOW_ISO
  let dataFim = metadata.endDate ?? inferredStart

  if (!metadata.startDate) {
    issues.push({
      issue_type: 'DATA_INCONSISTENTE',
      severity: 'ATENCAO',
      source_sheet: sheetName,
      raw_label: 'data_inicio',
      raw_value: fileName,
      normalized_value: inferredStart,
      details: { motivo: 'Data inicial ausente na planilha. Usado fallback seguro.' },
    })
  }

  if (dataFim < inferredStart) {
    issues.push({
      issue_type: 'DATA_INCONSISTENTE',
      severity: 'ATENCAO',
      source_sheet: sheetName,
      raw_label: 'data_fim',
      raw_value: dataFim,
      normalized_value: inferredStart,
      details: { motivo: 'Data final anterior à inicial. Ajustada para a data inicial.' },
    })
    dataFim = inferredStart
  }

  if (!metadata.montagemDate) {
    issues.push({
      issue_type: 'MONTAGEM_PENDENTE',
      severity: 'ATENCAO',
      source_sheet: sheetName,
      details: {
        sugestao: suggestMontagemDate(inferredStart),
        regra: 'Sugestão não salva automaticamente.',
      },
    })
  }

  for (const line of lines) {
    if (line.kind === 'service') {
      issues.push({
        issue_type: 'LINHA_SERVICO_IGNORADA',
        severity: 'INFO',
        source_sheet: line.sheetName,
        source_row: line.rowNumber,
        raw_value: line.displayName,
        normalized_value: line.normalizedName,
      })
    }
  }

  const name = sanitizeImportedEventName(metadata.eventName ?? sheetName ?? fileName)
  const status = deriveImportedEventStatus({ fileName, eventStartDate: inferredStart })

  return {
    fileName,
    sheetName,
    name,
    client: emptyToNull(metadata.client),
    local: emptyToNull(metadata.local),
    address: emptyToNull(metadata.address),
    dataInicio: inferredStart,
    dataFim,
    montagemDate: metadata.montagemDate,
    desmontagemDate: metadata.desmontagemDate,
    status,
    importStatus: reviewStatusFromIssues(issues.length),
    lines,
    issues,
  }
}

async function applyDrafts({
  supabase,
  drafts,
  existingCodes,
  catalogSearch,
}: {
  supabase: SupabaseClient
  drafts: FileDraft[]
  existingCodes: Set<string>
  catalogSearch: CatalogSearchItem[]
}) {
  const { data: batch, error: batchError } = await supabase
    .from('event_import_batches')
    .insert({
      origem: 'EVENT_PRO',
      status: 'IMPORTADO_OFICIAL',
      imported_by: 'codex',
      summary: summarizeDrafts(drafts),
    })
    .select('id')
    .single()

  if (batchError) throw new Error(`Falha ao criar lote de importação: ${batchError.message}`)

  const batchId = batch.id as string
  const result = {
    files: 0,
    skippedFiles: 0,
    events: 0,
    packingRows: 0,
    candidates: 0,
    issues: 0,
    batchId,
  }

  for (const draft of drafts) {
    const { data: existingFile, error: existingError } = await supabase
      .from('event_import_files')
      .select('id')
      .eq('source_hash', draft.sourceHash)
      .maybeSingle()
    if (existingError) throw new Error(`Falha ao checar duplicidade: ${existingError.message}`)
    if (existingFile) {
      result.skippedFiles += 1
      continue
    }

    const storagePath = `${batchId}/${safeStorageName(draft.fileName)}`
    const bytes = await readFile(draft.filePath)
    const upload = await supabase.storage
      .from(IMPORT_BUCKET)
      .upload(storagePath, bytes, { contentType: XLSX_MIME, upsert: true })
    if (upload.error) throw new Error(`Falha ao subir ${draft.fileName}: ${upload.error.message}`)

    const { data: fileRow, error: fileError } = await supabase
      .from('event_import_files')
      .insert({
        batch_id: batchId,
        file_name: draft.fileName,
        original_path: draft.filePath,
        source_hash: draft.sourceHash,
        storage_bucket: IMPORT_BUCKET,
        storage_path: storagePath,
        sheets_count: draft.sheetsCount,
        summary: summarizeFileDraft(draft),
      })
      .select('id')
      .single()
    if (fileError) throw new Error(`Falha ao registrar arquivo ${draft.fileName}: ${fileError.message}`)
    const fileId = fileRow.id as string
    result.files += 1

    for (const event of draft.events) {
      const eventCode = nextEventCode(event.dataInicio, existingCodes)
      const eventIssues = [...event.issues]
      const packingByItem = new Map<string, { item: CatalogItem; quantity: number; rows: number[] }>()
      if (event.status !== 'CANCELADO') {
        for (const line of event.lines) {
          if (line.kind !== 'equipment') continue
          const match = matchCatalogLine(line, catalogSearch)
          if (match.kind === 'matched') {
            const existing = packingByItem.get(match.item.id)
            if (existing) {
              existing.quantity += line.quantity
              existing.rows.push(line.rowNumber)
            } else {
              packingByItem.set(match.item.id, {
                item: match.item,
                quantity: line.quantity,
                rows: [line.rowNumber],
              })
            }
            continue
          }

          if (match.kind === 'ambiguous') {
            eventIssues.push({
              issue_type: 'PACKING_AMBIGUO',
              severity: 'ATENCAO',
              source_sheet: line.sheetName,
              source_row: line.rowNumber,
              raw_value: line.displayName,
              normalized_value: line.normalizedName,
              details: {
                candidatos: match.items.map((item) => ({
                  id: item.id,
                  codigo_interno: item.codigo_interno,
                  nome: item.nome,
                })),
              },
            })
            continue
          }

          const candidateId = await upsertCandidate(supabase, line, draft.fileName, event.name)
          eventIssues.push({
            issue_type: 'CATALOGO_CANDIDATO',
            severity: 'ATENCAO',
            source_sheet: line.sheetName,
            source_row: line.rowNumber,
            raw_value: line.displayName,
            normalized_value: line.normalizedName,
            details: { quantidade: line.quantity },
            candidate_id: candidateId,
          })
          result.candidates += 1
        }
      }

      const importStatus = reviewStatusFromIssues(eventIssues.length)
      const { data: projectRow, error: projectError } = await supabase
        .from('projetos')
        .insert({
          codigo_evento: eventCode,
          importacao_origem: 'EVENT_PRO',
          importacao_status: importStatus,
          importacao_file_id: fileId,
          nome: event.name,
          cliente: event.client,
          data_inicio: event.dataInicio,
          data_fim: event.dataFim,
          local: event.local,
          status: event.status,
          notas: buildImportedEventNotes(event, draft.fileName, eventCode),
          ficha_evento: buildFichaEvento(event),
        })
        .select('id')
        .single()
      if (projectError) throw new Error(`Falha ao criar evento ${event.name}: ${projectError.message}`)
      const projetoId = projectRow.id as string
      result.events += 1

      const packingRows = [...packingByItem.values()].map((entry) => ({
        projeto_id: projetoId,
        item_id: entry.item.id,
        quantidade: entry.quantity,
        serial_numbers_designados: [],
        notas: `Importado do Event Pro. Linhas: ${entry.rows.join(', ')}`,
      }))
      if (packingRows.length > 0) {
        const { error: packingError } = await supabase.from('packing_list').insert(packingRows)
        if (packingError) throw new Error(`Falha ao criar packing de ${event.name}: ${packingError.message}`)
        result.packingRows += packingRows.length
      }

      if (eventIssues.length > 0) {
        const { error: issuesError } = await supabase.from('event_import_issues').insert(
          eventIssues.map((issue) => ({
            batch_id: batchId,
            file_id: fileId,
            projeto_id: projetoId,
            candidate_id: issue.candidate_id ?? null,
            issue_type: issue.issue_type,
            severity: issue.severity,
            source_sheet: issue.source_sheet ?? event.sheetName,
            source_row: issue.source_row ?? null,
            raw_label: issue.raw_label ?? null,
            raw_value: issue.raw_value ?? null,
            normalized_value: issue.normalized_value ?? null,
            details: issue.details ?? {},
          })),
        )
        if (issuesError) throw new Error(`Falha ao criar pendências de ${event.name}: ${issuesError.message}`)
        result.issues += eventIssues.length
      }

    }
  }

  const { error: updateError } = await supabase
    .from('event_import_batches')
    .update({ status: result.issues > 0 ? 'REVISAO_PENDENTE' : 'IMPORTADO_OFICIAL', summary: result })
    .eq('id', batchId)
  if (updateError) throw new Error(`Falha ao atualizar lote: ${updateError.message}`)

  return result
}

async function upsertCandidate(
  supabase: SupabaseClient,
  line: RawLine,
  fileName: string,
  eventName: string,
): Promise<string> {
  const normalizedName = line.normalizedName
  const example = {
    arquivo: fileName,
    evento: eventName,
    aba: line.sheetName,
    linha: line.rowNumber,
    quantidade: line.quantity,
    valor: line.displayName,
  }

  const { data: existing, error: selectError } = await supabase
    .from('catalog_item_candidates')
    .select('id, occurrences_count, exemplos')
    .eq('normalized_name', normalizedName)
    .maybeSingle()
  if (selectError) throw new Error(`Falha ao buscar candidato ${line.displayName}: ${selectError.message}`)

  if (existing) {
    const examples = Array.isArray(existing.exemplos) ? existing.exemplos : []
    const { error } = await supabase
      .from('catalog_item_candidates')
      .update({
        occurrences_count: Number(existing.occurrences_count ?? 1) + 1,
        exemplos: [...examples, example].slice(-10),
      })
      .eq('id', existing.id)
    if (error) throw new Error(`Falha ao atualizar candidato ${line.displayName}: ${error.message}`)
    return existing.id as string
  }

  const { data, error } = await supabase
    .from('catalog_item_candidates')
    .insert({
      normalized_name: normalizedName,
      display_name: line.displayName,
      categoria_sugerida: line.categoriaSugerida,
      status: 'PENDENTE',
      occurrences_count: 1,
      exemplos: [example],
    })
    .select('id')
    .single()
  if (error) throw new Error(`Falha ao criar candidato ${line.displayName}: ${error.message}`)
  return data.id as string
}

export function matchCatalogLine(
  line: Pick<RawLine, 'normalizedName' | 'categoriaSugerida'>,
  catalog: CatalogSearchItem[],
):
  | { kind: 'matched'; item: CatalogSearchItem; score: number }
  | { kind: 'ambiguous'; items: CatalogSearchItem[]; score: number }
  | { kind: 'candidate' } {
  const lineTokens = tokens(line.normalizedName)
  if (lineTokens.length === 0) return { kind: 'candidate' }

  const scored = catalog
    .map((item) => ({ item, score: scoreCatalogMatch(line.normalizedName, lineTokens, line.categoriaSugerida, item) }))
    .filter((entry) => entry.score >= 0.58)
    .sort((a, b) => b.score - a.score)

  const best = scored[0]
  if (!best) return { kind: 'candidate' }
  const second = scored[1]
  if (best.score >= 0.78 && (!second || best.score - second.score >= 0.08)) {
    return { kind: 'matched', item: best.item, score: best.score }
  }
  return { kind: 'ambiguous', items: scored.slice(0, 5).map((entry) => entry.item), score: best.score }
}

function scoreCatalogMatch(
  lineText: string,
  lineTokens: string[],
  suggestedCategory: Categoria | null,
  item: CatalogSearchItem,
): number {
  const includesFull = item.searchText.includes(lineText) || lineText.includes(normalizeCandidateName(item.nome))
  const lineOverlap =
    lineTokens.filter((token) => item.searchText.includes(token)).length / Math.max(lineTokens.length, 1)
  const itemOverlap =
    item.searchTokens.filter((token) => lineText.includes(token)).length / Math.max(item.searchTokens.length, 1)
  const categoryBonus = suggestedCategory && suggestedCategory === item.categoria ? 0.08 : 0
  const fullBonus = includesFull ? 0.2 : 0
  return Math.min(1, Math.max(lineOverlap, itemOverlap) + categoryBonus + fullBonus)
}

export function toCatalogSearchItem(item: CatalogItem): CatalogSearchItem {
  const searchText = normalizeCandidateName(
    [item.codigo_interno, item.nome, item.subcategoria, item.marca, item.modelo].filter(Boolean).join(' '),
  )
  return {
    ...item,
    searchText,
    searchTokens: tokens(searchText),
  }
}

function tokens(value: string): string[] {
  return value
    .split(/\s+/)
    .map((token) => token.trim())
    .filter((token) => token.length > 1 && !STOPWORDS.has(token))
}

function detectLineHeader(row: unknown[]): { descriptionColumn: number; quantityColumns: number[] } | null {
  const labels = row.map((cell) => normalizeLabel(cell))
  const quantityColumns = labels
    .map((label, index) => ({ label, index }))
    .filter(({ label }) => ['QTD', 'QTDE', 'QUANTIDADE', 'QUANTIDADES'].includes(label))
    .map(({ index }) => index)

  const descriptionColumns = labels
    .map((label, index) => ({ label, index }))
    .filter(({ label }) => label.includes('DESCRICAO') || label === 'ITEM')
    .map(({ index }) => index)

  if (descriptionColumns.length === 0) return null

  const descriptionColumn =
    descriptionColumns.find((index) => labels[index].includes('DESCRICAO')) ??
    descriptionColumns.find((index) => !quantityColumns.includes(index)) ??
    descriptionColumns[0]

  return { descriptionColumn, quantityColumns }
}

function firstQuantity(row: unknown[], columns: number[]): number | null {
  for (const column of columns) {
    const quantity = parsePositiveInteger(cellText(row[column]))
    if (quantity && quantity > 0) return quantity
  }
  return null
}

function firstValueToRight(row: unknown[], column: number): unknown {
  for (let index = column + 1; index < Math.min(row.length, column + 5); index += 1) {
    if (cellText(row[index])) return row[index]
  }
  return null
}

function inferTitleFromSheet(rows: unknown[][], sheetName: string, fileName: string): string {
  for (let rowIndex = 0; rowIndex < Math.min(rows.length, 4); rowIndex += 1) {
    const row = rows[rowIndex] ?? []
    const longest = row
      .map(cellText)
      .filter((value) => value.length > 4 && !/^(QTD|ITEM|DATA)$/i.test(value))
      .sort((a, b) => b.length - a.length)[0]
    if (longest) return longest
  }
  return sheetName && !/^pagina/i.test(sheetName) ? sheetName : fileName
}

function firstDateInRows(rows: unknown[][], fallbackYear: number): string | null {
  for (let rowIndex = 0; rowIndex < Math.min(rows.length, 15); rowIndex += 1) {
    const row = rows[rowIndex] ?? []
    for (let column = 0; column < row.length; column += 1) {
      const previousLabel = normalizeLabel(row[column - 1])
      if (previousLabel.includes('DATA DO ORCAMENTO')) continue
      const parsed = parseEventDate(row[column], fallbackYear)
      if (parsed) return parsed
    }
  }
  return null
}

function extractYear(value: string): number | null {
  const match = value.match(/\b(20\d{2})\b/)
  if (!match) return null
  return Number(match[1])
}

function matchesAny(label: string, needles: string[]): boolean {
  return needles.some((needle) => label === needle || label.startsWith(`${needle} `))
}

function normalizeLabel(value: unknown): string {
  return normalizeEventImportText(value)
    .replace(/[:：]+$/g, '')
    .replace(/\s+/g, ' ')
    .trim()
}

function normalizeExcelCellValue(value: unknown): unknown {
  if (value == null) return ''
  if (value instanceof Date) return value
  if (typeof value !== 'object') return value

  const record = value as Record<string, unknown>
  if ('result' in record) return normalizeExcelCellValue(record.result)
  if (typeof record.text === 'string') return record.text
  if (typeof record.hyperlink === 'string') return String(record.text ?? record.hyperlink)
  if (typeof record.error === 'string') return record.error
  if (Array.isArray(record.richText)) {
    return record.richText
      .map((part) => (typeof part === 'object' && part ? String((part as { text?: unknown }).text ?? '') : ''))
      .join('')
  }
  return ''
}

function cellText(value: unknown): string {
  if (value == null) return ''
  if (value instanceof Date) return value.toISOString().slice(0, 10)
  return String(value).trim()
}

function parsePositiveInteger(value: unknown): number | null {
  const text = String(value ?? '').replace(',', '.').trim()
  if (!/^\d+(?:\.0+)?$/.test(text)) return null
  const numeric = Number(text)
  return Number.isInteger(numeric) && numeric > 0 ? numeric : null
}

function emptyToNull(value: string | null): string | null {
  const trimmed = value?.trim() ?? ''
  return trimmed ? trimmed : null
}

function suggestMontagemDate(eventDate: string): string {
  const date = new Date(`${eventDate}T00:00:00Z`)
  date.setUTCDate(date.getUTCDate() - 1)
  return `${date.toISOString().slice(0, 10)} 09:00`
}

function buildFichaEvento(event: EventDraft) {
  return {
    versao: 1,
    atualizadoEm: new Date().toISOString(),
    evento: {
      nome: event.name,
      cliente: event.client,
      dataInicial: event.dataInicio,
      dataFinal: event.dataFim,
      statusInicial: event.status,
    },
    endereco: {
      local: event.local,
      endereco: event.address,
      cidadeUf: null,
      referenciaAcesso: null,
    },
    montagem: {
      dia: event.montagemDate,
      inicio: null,
      fim: null,
      equipe: null,
      responsavel: null,
      telefone: null,
    },
    desmontagem: {
      dia: event.desmontagemDate,
      inicio: null,
      fim: null,
      equipe: null,
      responsavel: null,
      telefone: null,
    },
    responsaveis: {
      principal: null,
      principalTelefone: null,
      checklist: null,
      checklistTelefone: null,
    },
    checklist: [
      { item: 'Separação física do packing', responsavel: '', ok: false },
      { item: 'Montagem validada no local', responsavel: '', ok: false },
      { item: 'Fotos de montagem anexadas', responsavel: '', ok: false },
    ],
    observacoes: `Importado do Event Pro. Arquivo: ${event.fileName}. Aba: ${event.sheetName}.`,
  }
}

function buildImportedEventNotes(event: EventDraft, fileName: string, eventCode: string): string {
  return [
    `Código: ${eventCode}`,
    `Importado do Event Pro: ${fileName}`,
    `Aba: ${event.sheetName}`,
    event.address ? `Endereço: ${event.address}` : null,
    event.montagemDate ? `Montagem: ${event.montagemDate}` : 'Montagem: pendente de revisão',
  ]
    .filter(Boolean)
    .join('\n')
}

function nextEventCode(dateIso: string, existingCodes: Set<string>): string {
  let sequence = 1
  let code = buildEventCode(dateIso, sequence)
  while (existingCodes.has(code)) {
    sequence += 1
    code = buildEventCode(dateIso, sequence)
  }
  existingCodes.add(code)
  return code
}

function safeStorageName(fileName: string): string {
  return normalizeCandidateName(fileName).replace(/[^A-Z0-9.]+/g, '_') || 'evento.xlsx'
}

function summarizeDrafts(drafts: FileDraft[]) {
  const files = drafts.length
  const events = drafts.reduce((acc, draft) => acc + draft.events.length, 0)
  const issues = drafts.reduce(
    (acc, draft) => acc + draft.events.reduce((sum, event) => sum + event.issues.length, 0),
    0,
  )
  const lines = drafts.reduce(
    (acc, draft) => acc + draft.events.reduce((sum, event) => sum + event.lines.length, 0),
    0,
  )
  const canceled = drafts.reduce(
    (acc, draft) => acc + draft.events.filter((event) => event.status === 'CANCELADO').length,
    0,
  )
  return { files, events, lines, issues, canceled, filesDetail: drafts.map(summarizeFileDraft) }
}

function summarizeFileDraft(draft: FileDraft) {
  return {
    fileName: draft.fileName,
    sheets: draft.sheetsCount,
    events: draft.events.map((event) => ({
      name: event.name,
      sheet: event.sheetName,
      status: event.status,
      date: event.dataInicio,
      importStatus: event.importStatus,
      lines: event.lines.length,
      issues: event.issues.length,
    })),
  }
}

function printSummary(summary: Record<string, unknown>, json: boolean) {
  if (json) {
    console.log(JSON.stringify(summary, null, 2))
    return
  }
  console.log(`Modo: ${summary.mode}`)
  console.log(`Arquivos: ${summary.files}`)
  console.log(`Eventos: ${summary.events}`)
  if ('skippedFiles' in summary) console.log(`Arquivos pulados por duplicidade: ${summary.skippedFiles}`)
  if ('packingRows' in summary) console.log(`Linhas de packing criadas: ${summary.packingRows}`)
  if ('candidates' in summary) console.log(`Candidatos de catálogo: ${summary.candidates}`)
  console.log(`Pendências: ${summary.issues}`)
  if ('batchId' in summary) console.log(`Lote: ${summary.batchId}`)
}
