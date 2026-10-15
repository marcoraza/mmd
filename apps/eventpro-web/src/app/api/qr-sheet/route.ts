import { NextResponse } from 'next/server'
import QRCode from 'qrcode'
import { Document, Page, View, Text, Image, StyleSheet, pdf } from '@react-pdf/renderer'
import { createElement } from 'react'
import { requireRequestUser } from '@/lib/action-auth'
import { loadSerialsForQrSheet } from '@/lib/data/serial-search'
import { MM_TO_PT, QR_LAYOUTS, type QrItem, type QrLayoutKey } from '@/lib/qr-layouts'
import {
  buildQrSheetItems,
  chunk,
  paginateQrItems,
  parseQrSheetRequest,
  qrSheetFileName,
  QR_SHEET_QR_CHUNK_SIZE,
  type QrSheetSerialRow,
} from '@/lib/qr-sheet-core'
import type { Categoria } from '@/lib/types'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'
export const maxDuration = 60

// Contrato §6, na versão refatorada de §6.6.
//
// Duas mudanças em relação ao legado:
//   1. O cliente manda `serial_ids` mais `layout`; o servidor resolve payload,
//      título, subtítulo e legenda. Antes o conteúdo do QR era texto arbitrário
//      do cliente.
//   2. Os QR são gerados em blocos, não numa única rajada de Promise.all, que
//      era a causa do 504 em seleção grande.
//
// Auth: alinhada ao resto da superfície (`requireRequestUser`, aceita Bearer e
// cookie, exige `viewer`). O código de erro `unauthorized` em inglês é mantido
// exatamente como está no contrato, porque é vocabulário fechado (§10.6).
function firstRelated<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) return value[0] ?? null
  return value ?? null
}

function resolveBaseUrl(req: Request) {
  const configured = process.env.NEXT_PUBLIC_EVENTPRO_PUBLIC_BASE_URL?.trim()
  if (configured) return configured
  return new URL(req.url).origin
}

export async function POST(req: Request) {
  const auth = await requireRequestUser(req, 'viewer')
  if (!auth.ok) return NextResponse.json({ error: 'unauthorized' }, { status: 401 })

  let body: unknown
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'invalid_json' }, { status: 400 })
  }

  const parsed = parseQrSheetRequest(body)
  if (!parsed.ok) return NextResponse.json({ error: parsed.error }, { status: 400 })

  const layout = QR_LAYOUTS[parsed.request.layout]

  const rows = await loadSerialsForQrSheet(parsed.request.serialIds)
  const serialRows: QrSheetSerialRow[] = rows.map((row) => {
    const item = firstRelated(row.items)
    return {
      id: row.id,
      codigo_interno: row.codigo_interno,
      item_nome: item?.nome ?? null,
      item_categoria: (item?.categoria as Categoria | null) ?? null,
    }
  })

  const items = buildQrSheetItems({
    baseUrl: resolveBaseUrl(req),
    serialIds: parsed.request.serialIds,
    rows: serialRows,
  })

  if (items.length === 0) return NextResponse.json({ error: 'no_items' }, { status: 400 })

  // Geração em blocos: mantém o pico de memória e CPU limitado ao tamanho do
  // bloco, em vez de escalar com a seleção inteira.
  const qrImages: string[] = []
  for (const block of chunk(items, QR_SHEET_QR_CHUNK_SIZE)) {
    const rendered = await Promise.all(
      block.map((item) =>
        QRCode.toDataURL(item.payload, {
          errorCorrectionLevel: 'M',
          margin: 0,
          width: 512,
          color: { dark: '#000000', light: '#FFFFFF' },
        }),
      ),
    )
    qrImages.push(...rendered)
  }

  const pages = paginateQrItems(items, qrImages, layout.perSheet)
  const blob = await pdf(buildDocument({ pages, layout })).toBlob()
  const buffer = Buffer.from(await blob.arrayBuffer())

  return new NextResponse(buffer as unknown as BodyInit, {
    status: 200,
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="${qrSheetFileName(layout.key, Date.now())}"`,
      'Cache-Control': 'no-store',
    },
  })
}

type DocProps = {
  pages: { items: QrItem[]; qrs: string[] }[]
  layout: (typeof QR_LAYOUTS)[QrLayoutKey]
}

function buildDocument({ pages, layout }: DocProps) {
  const pageStyle = StyleSheet.create({
    page: {
      paddingTop: layout.marginYMm * MM_TO_PT,
      paddingBottom: layout.marginYMm * MM_TO_PT,
      paddingLeft: layout.marginXMm * MM_TO_PT,
      paddingRight: layout.marginXMm * MM_TO_PT,
      backgroundColor: '#ffffff',
    },
    grid: {
      display: 'flex',
      flexDirection: 'row',
      flexWrap: 'wrap',
    },
    cell: {
      width: layout.cellWidthMm * MM_TO_PT,
      height: layout.cellHeightMm * MM_TO_PT,
      marginRight: layout.gapXMm * MM_TO_PT,
      marginBottom: layout.gapYMm * MM_TO_PT,
      padding: 4,
      display: 'flex',
      flexDirection: 'row',
      alignItems: 'center',
      gap: 6,
    },
    qr: {
      width: layout.qrSizeMm * MM_TO_PT,
      height: layout.qrSizeMm * MM_TO_PT,
    },
    meta: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'center',
      gap: 2,
    },
    title: {
      fontSize: 9,
      fontFamily: 'Courier-Bold',
      color: '#000000',
    },
    subtitle: {
      fontSize: 7,
      color: '#333333',
    },
    caption: {
      fontSize: 6,
      color: '#666666',
      textTransform: 'uppercase',
      letterSpacing: 0.4,
    },
  })

  return createElement(
    Document,
    null,
    pages.map((sheet, sheetIndex) =>
      createElement(
        Page,
        {
          key: sheetIndex,
          size: [layout.pageWidthMm * MM_TO_PT, layout.pageHeightMm * MM_TO_PT],
          style: pageStyle.page,
        },
        createElement(
          View,
          { style: pageStyle.grid },
          sheet.items.map((item, index) =>
            createElement(
              View,
              { key: index, style: pageStyle.cell },
              createElement(Image, { src: sheet.qrs[index], style: pageStyle.qr }),
              createElement(
                View,
                { style: pageStyle.meta },
                createElement(Text, { style: pageStyle.title }, item.title),
                item.subtitle
                  ? createElement(Text, { style: pageStyle.subtitle }, item.subtitle)
                  : null,
                item.caption
                  ? createElement(Text, { style: pageStyle.caption }, item.caption)
                  : null,
              ),
            ),
          ),
        ),
      ),
    ),
  )
}
