'use client'

import { QR_LAYOUTS, type QrItem, type QrLayout, type QrLayoutKey } from './layouts'
import { QrPlaceholder } from '@/components/lotes/QrPlaceholder'

/**
 * Preview em tela. Reproduz o layout da folha PDF escalado pra caber no card.
 * Usa QrPlaceholder em vez do QR real (o PDF final é que renderiza o QR de
 * verdade via lib `qrcode`). Mostra só a primeira folha.
 */
export function PreviewSheet({
  items,
  layoutKey,
  scale = 0.65,
}: {
  items: QrItem[]
  layoutKey: QrLayoutKey
  scale?: number
}) {
  const layout = QR_LAYOUTS[layoutKey]
  const pageItems = items.slice(0, layout.perSheet)

  const w = layout.pageWidthMm * scale
  const h = layout.pageHeightMm * scale

  return (
    <div
      style={{
        position: 'relative',
        width: `${w}mm`,
        height: `${h}mm`,
        background: '#ffffff',
        color: '#000',
        boxShadow: '0 10px 40px -10px rgba(0, 0, 0, 0.6)',
        borderRadius: 2,
        overflow: 'hidden',
      }}
      aria-label={`Preview da folha ${layout.label}`}
    >
      <SheetGrid layout={layout} items={pageItems} scale={scale} />
      {items.length === 0 && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#999',
            fontSize: 11,
            fontFamily: 'var(--font-ui)',
          }}
        >
          Selecione códigos para ver o preview
        </div>
      )}
      {items.length > layout.perSheet && (
        <div
          style={{
            position: 'absolute',
            bottom: 6,
            right: 8,
            fontSize: 9,
            color: '#999',
            fontFamily: 'var(--font-mono-raw)',
          }}
        >
          Página 1 de {Math.ceil(items.length / layout.perSheet)}
        </div>
      )}
    </div>
  )
}

function SheetGrid({
  layout,
  items,
  scale,
}: {
  layout: QrLayout
  items: QrItem[]
  scale: number
}) {
  const cells: (QrItem | null)[] = Array.from({ length: layout.perSheet }, (_, i) => items[i] ?? null)

  return (
    <div
      style={{
        padding: `${layout.marginYMm * scale}mm ${layout.marginXMm * scale}mm`,
        display: 'grid',
        gridTemplateColumns: `repeat(${layout.cols}, ${layout.cellWidthMm * scale}mm)`,
        gridAutoRows: `${layout.cellHeightMm * scale}mm`,
        columnGap: `${layout.gapXMm * scale}mm`,
        rowGap: `${layout.gapYMm * scale}mm`,
      }}
    >
      {cells.map((c, i) => (
        <Cell key={i} item={c} layout={layout} scale={scale} />
      ))}
    </div>
  )
}

function Cell({
  item,
  layout,
  scale,
}: {
  item: QrItem | null
  layout: QrLayout
  scale: number
}) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 6 * scale,
        padding: 4 * scale,
        border: '1px dashed rgba(0, 0, 0, 0.12)',
        overflow: 'hidden',
      }}
    >
      {item ? (
        <>
          <div
            style={{
              width: `${layout.qrSizeMm * scale}mm`,
              height: `${layout.qrSizeMm * scale}mm`,
              flexShrink: 0,
            }}
          >
            <QrPlaceholder value={item.payload} size={layout.qrSizeMm * scale * 3.78} />
          </div>
          <div
            style={{
              flex: 1,
              minWidth: 0,
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center',
              gap: 2 * scale,
              lineHeight: 1.15,
            }}
          >
            <div
              style={{
                fontSize: 9 * scale,
                fontFamily: 'var(--font-mono-raw)',
                fontWeight: 700,
                color: '#000',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {item.title}
            </div>
            {item.subtitle && (
              <div
                style={{
                  fontSize: 7 * scale,
                  color: '#333',
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                {item.subtitle}
              </div>
            )}
            {item.caption && (
              <div
                style={{
                  fontSize: 6 * scale,
                  color: '#666',
                  textTransform: 'uppercase',
                  letterSpacing: 0.4,
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                {item.caption}
              </div>
            )}
          </div>
        </>
      ) : null}
    </div>
  )
}
