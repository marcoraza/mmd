// Regra pura da folha de etiquetas QR (contrato §6, na versão refatorada de
// §6.6).
//
// Inversão em relação ao legado: o cliente manda `serial_ids` mais `layout` e o
// servidor resolve `payload`, `title`, `subtitle` e `caption`. No shape antigo o
// conteúdo do QR vinha como texto arbitrário do cliente, ou seja, qualquer um
// autenticado podia imprimir uma etiqueta apontando para onde quisesse.
//
// A geração dos QR em blocos (`chunk`) é o outro item de §6.6: seleção grande
// deixa de montar centenas de PNG numa única rajada, que era a causa do 504.

import { QR_LAYOUTS, type QrItem, type QrLayoutKey } from './qr-layouts.ts'
import { CATEGORIA_LABEL } from './nomenclature.ts'
import type { Categoria } from './types.ts'

export const QR_SHEET_QR_CHUNK_SIZE = 40
export const QR_SHEET_MAX_ITEMS = 2000

export type QrSheetRequest = {
  serialIds: string[]
  layout: QrLayoutKey
}

export type QrSheetRequestResult =
  { ok: true; request: QrSheetRequest } | { ok: false; error: 'no_items' | 'invalid_layout' }

export type QrSheetSerialRow = {
  id: string
  codigo_interno: string
  item_nome: string | null
  item_categoria: Categoria | null
}

export function isQrLayoutKey(value: unknown): value is QrLayoutKey {
  return typeof value === 'string' && Object.hasOwn(QR_LAYOUTS, value)
}

export function parseQrSheetRequest(raw: unknown): QrSheetRequestResult {
  const body = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {}

  const serialIds = Array.isArray(body.serial_ids)
    ? dedupePreservingOrder(
        body.serial_ids
          .filter((id): id is string => typeof id === 'string')
          // Ids vindos do Swift chegam em maiúsculas (divergência D9).
          .map((id) => id.trim().toLowerCase())
          .filter(Boolean),
      )
    : []

  if (serialIds.length === 0) return { ok: false, error: 'no_items' }
  if (!isQrLayoutKey(body.layout)) return { ok: false, error: 'invalid_layout' }

  return {
    ok: true,
    request: { serialIds: serialIds.slice(0, QR_SHEET_MAX_ITEMS), layout: body.layout },
  }
}

function dedupePreservingOrder(values: string[]) {
  const seen = new Set<string>()
  const result: string[] = []
  for (const value of values) {
    if (seen.has(value)) continue
    seen.add(value)
    result.push(value)
  }
  return result
}

// O QR público aponta para `/s/{codigo}`, que expõe só código, item, categoria e
// status colapsado. Nada de valor, serial de fábrica, RFID, localização ou
// histórico (invariante de produto, coberto por `public-qr`).
export function publicQrPayload(baseUrl: string, codigoInterno: string) {
  const origin = baseUrl.replace(/\/+$/, '')
  return `${origin}/s/${encodeURIComponent(codigoInterno)}`
}

// A ordem final da folha segue a ordem dos ids pedidos; ids que não existem no
// catálogo somem em silêncio, como qualquer seleção obsoleta.
export function buildQrSheetItems(input: {
  baseUrl: string
  serialIds: string[]
  rows: QrSheetSerialRow[]
}): QrItem[] {
  const byId = new Map(input.rows.map((row) => [row.id.toLowerCase(), row]))

  return input.serialIds.flatMap((id) => {
    const row = byId.get(id)
    if (!row) return []
    return [
      {
        payload: publicQrPayload(input.baseUrl, row.codigo_interno),
        title: row.codigo_interno,
        subtitle: row.item_nome ?? undefined,
        caption: row.item_categoria ? CATEGORIA_LABEL[row.item_categoria] : undefined,
      },
    ]
  })
}

export function chunk<T>(items: T[], size: number): T[][] {
  if (size <= 0) return [items]
  const chunks: T[][] = []
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size))
  }
  return chunks
}

export function paginateQrItems(items: QrItem[], qrs: string[], perSheet: number) {
  const pages: { items: QrItem[]; qrs: string[] }[] = []
  for (let index = 0; index < items.length; index += perSheet) {
    pages.push({
      items: items.slice(index, index + perSheet),
      qrs: qrs.slice(index, index + perSheet),
    })
  }
  return pages
}

export function qrSheetFileName(layout: QrLayoutKey, now: number) {
  return `qr-sheet-${layout}-${now}.pdf`
}
