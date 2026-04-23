import { NextResponse } from 'next/server'
import QRCode from 'qrcode'
import { Document, Page, View, Text, Image, StyleSheet, pdf } from '@react-pdf/renderer'
import { createElement } from 'react'
import { MM_TO_PT, QR_LAYOUTS, type QrItem, type QrLayoutKey } from '@/components/qrcodes/layouts'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

type Body = {
  items: QrItem[]
  layout: QrLayoutKey
}

export async function POST(req: Request) {
  let body: Body
  try {
    body = (await req.json()) as Body
  } catch {
    return NextResponse.json({ error: 'invalid_json' }, { status: 400 })
  }

  if (!body?.items?.length) {
    return NextResponse.json({ error: 'no_items' }, { status: 400 })
  }
  const layout = QR_LAYOUTS[body.layout]
  if (!layout) {
    return NextResponse.json({ error: 'invalid_layout' }, { status: 400 })
  }

  // Gera todos os QRs como PNG dataURL
  const qrImages = await Promise.all(
    body.items.map((it) =>
      QRCode.toDataURL(it.payload, {
        errorCorrectionLevel: 'M',
        margin: 0,
        width: 512,
        color: { dark: '#000000', light: '#FFFFFF' },
      })
    )
  )

  // Paginar em folhas de `perSheet` etiquetas
  const pages: { items: QrItem[]; qrs: string[] }[] = []
  for (let i = 0; i < body.items.length; i += layout.perSheet) {
    pages.push({
      items: body.items.slice(i, i + layout.perSheet),
      qrs: qrImages.slice(i, i + layout.perSheet),
    })
  }

  const doc = buildDocument({ pages, layout })
  const stream = await pdf(doc).toBlob()
  const buf = Buffer.from(await stream.arrayBuffer())

  return new NextResponse(buf as unknown as BodyInit, {
    status: 200,
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="qr-sheet-${layout.key}-${Date.now()}.pdf"`,
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
    pages.map((p, pi) =>
      createElement(
        Page,
        {
          key: pi,
          size: [layout.pageWidthMm * MM_TO_PT, layout.pageHeightMm * MM_TO_PT],
          style: pageStyle.page,
        },
        createElement(
          View,
          { style: pageStyle.grid },
          p.items.map((it, i) =>
            createElement(
              View,
              { key: i, style: pageStyle.cell },
              createElement(Image, { src: p.qrs[i], style: pageStyle.qr }),
              createElement(
                View,
                { style: pageStyle.meta },
                createElement(Text, { style: pageStyle.title }, it.title),
                it.subtitle
                  ? createElement(Text, { style: pageStyle.subtitle }, it.subtitle)
                  : null,
                it.caption
                  ? createElement(Text, { style: pageStyle.caption }, it.caption)
                  : null
              )
            )
          )
        )
      )
    )
  )
}
