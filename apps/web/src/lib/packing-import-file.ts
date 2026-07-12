import 'server-only'

import { Buffer } from 'node:buffer'
import ExcelJS from 'exceljs'
import {
  PACKING_IMPORT_ACCEPT,
  PACKING_IMPORT_COLUMNS,
  PACKING_IMPORT_MAX_FILE_BYTES,
  normalizePackingImportHeader,
  toPackingImportInput,
  type PackingImportCellValue,
  type PackingImportColumn,
  type PackingImportRowInput,
} from '@/lib/packing-import-core'

export { PACKING_IMPORT_ACCEPT }

type ParsePackingImportFileResult =
  | { ok: true; data: PackingImportRowInput[] }
  | { ok: false; error: string }

export async function parsePackingImportFile(file: File): Promise<ParsePackingImportFileResult> {
  if (file.size > PACKING_IMPORT_MAX_FILE_BYTES) {
    return { ok: false, error: 'Planilha precisa ter no máximo 10 MB.' }
  }

  const extension = fileExtension(file.name)
  if (!extension) return { ok: false, error: 'Arquivo precisa ser XLSX, CSV ou TSV.' }

  const bytes = Buffer.from(await file.arrayBuffer())
  let rows: unknown[][]
  try {
    rows =
      extension === 'xlsx'
        ? await parseXlsxRows(bytes)
        : parseDelimitedRows(new TextDecoder('utf-8').decode(bytes), extension === 'tsv' ? '\t' : ',')
  } catch {
    return {
      ok: false,
      error: 'Não consegui ler a planilha. Confira se o arquivo é XLSX, CSV ou TSV válido.',
    }
  }

  return rowsToPackingImportRows(rows)
}

async function parseXlsxRows(bytes: Buffer): Promise<unknown[][]> {
  const workbook = new ExcelJS.Workbook()
  const input = bytes as unknown as Parameters<typeof workbook.xlsx.load>[0]
  await workbook.xlsx.load(input)
  const worksheet = workbook.worksheets[0]
  if (!worksheet) return []

  const rows: unknown[][] = []
  const maxColumn = Math.max(worksheet.columnCount, 1)
  worksheet.eachRow({ includeEmpty: true }, (row, rowNumber) => {
    const cells: unknown[] = []
    const lastColumn = Math.max(maxColumn, row.cellCount)
    for (let column = 1; column <= lastColumn; column += 1) {
      cells.push(normalizeExcelCellValue(row.getCell(column).value))
    }
    rows[rowNumber - 1] = cells
  })
  return rows
}

function rowsToPackingImportRows(rows: unknown[][]): ParsePackingImportFileResult {
  const headerIndex = rows.findIndex((row) => row.some((cell) => valueText(cell)))
  if (headerIndex < 0) return { ok: false, error: 'Planilha vazia.' }

  const headerRow = rows[headerIndex] ?? []
  const mappedHeaders = headerRow.map((cell, index) =>
    index === 0
      ? normalizePackingImportHeader(stripBom(cell) as PackingImportCellValue)
      : normalizePackingImportHeader(cell as PackingImportCellValue),
  )

  if (!mappedHeaders.some(Boolean)) {
    return {
      ok: false,
      error:
        'Cabeçalho não reconhecido. Use codigo_mmd, categoria, item, subcategoria, marca, modelo, quantidade e observacao.',
    }
  }

  const importRows: PackingImportRowInput[] = []
  for (let index = headerIndex + 1; index < rows.length; index += 1) {
    const row = rows[index] ?? []
    if (!row.some((cell) => valueText(cell))) continue

    const values: Partial<Record<PackingImportColumn, PackingImportCellValue>> = {}
    row.forEach((cell, cellIndex) => {
      const column = mappedHeaders[cellIndex]
      if (!column || !PACKING_IMPORT_COLUMNS.includes(column)) return
      if (values[column] == null) values[column] = cell as PackingImportCellValue
    })
    importRows.push(toPackingImportInput(index + 1, values))
  }

  if (importRows.length === 0) return { ok: false, error: 'Planilha sem linhas para importar.' }
  return { ok: true, data: importRows }
}

function parseDelimitedRows(text: string, delimiter: ',' | '\t'): string[][] {
  const rows: string[][] = []
  let row: string[] = []
  let cell = ''
  let quoted = false

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index]
    const next = text[index + 1]

    if (char === '"') {
      if (quoted && next === '"') {
        cell += '"'
        index += 1
      } else {
        quoted = !quoted
      }
      continue
    }

    if (char === delimiter && !quoted) {
      row.push(cell)
      cell = ''
      continue
    }

    if ((char === '\n' || char === '\r') && !quoted) {
      row.push(cell)
      rows.push(row)
      row = []
      cell = ''
      if (char === '\r' && next === '\n') index += 1
      continue
    }

    cell += char
  }

  if (cell || row.length > 0) {
    row.push(cell)
    rows.push(row)
  }

  return rows
}

function normalizeExcelCellValue(value: unknown): PackingImportCellValue {
  if (value == null) return ''
  if (value instanceof Date) return value
  if (typeof value !== 'object') return value as PackingImportCellValue

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

function fileExtension(name: string) {
  const lower = name.toLowerCase()
  if (lower.endsWith('.xlsx')) return 'xlsx'
  if (lower.endsWith('.csv')) return 'csv'
  if (lower.endsWith('.tsv')) return 'tsv'
  return null
}

function stripBom(value: unknown) {
  return typeof value === 'string' ? value.replace(/^\uFEFF/, '') : value
}

function valueText(value: unknown) {
  if (value == null) return ''
  return String(value).trim()
}
