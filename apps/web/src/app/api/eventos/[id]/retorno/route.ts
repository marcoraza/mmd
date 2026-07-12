import { NextResponse } from 'next/server'
import { requireRequestUser } from '@/lib/action-auth'
import { checkinProject, type CheckinItemInput } from '@/lib/actions/movimentacoes'
import type { ReturnOutcome } from '@/lib/return-resolution-core'
import type { MetodoScan } from '@/lib/types'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

const METODOS: MetodoScan[] = ['RFID', 'QRCODE', 'MANUAL']
const RESULTADOS: ReturnOutcome[] = ['OK', 'PROBLEMA', 'NAO_VOLTOU']

function parseMetodo(value: unknown): MetodoScan | null {
  return typeof value === 'string' && METODOS.includes(value as MetodoScan)
    ? (value as MetodoScan)
    : null
}

function parseResultado(value: unknown): ReturnOutcome | null {
  return typeof value === 'string' && RESULTADOS.includes(value as ReturnOutcome)
    ? (value as ReturnOutcome)
    : null
}

function readObservation(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : null
}

function parseDesgaste(value: unknown) {
  const numeric = typeof value === 'number' ? value : Number(value)
  return Number.isFinite(numeric) ? Math.round(numeric) : 3
}

function parseItems(value: unknown): CheckinItemInput[] | null {
  if (!Array.isArray(value)) return null

  const items: CheckinItemInput[] = []
  for (const raw of value) {
    if (!raw || typeof raw !== 'object') return null

    const item = raw as Record<string, unknown>
    const serialId = typeof item.serial_id === 'string' ? item.serial_id.trim() : ''
    const resultado = parseResultado(item.resultado)
    if (!serialId || !resultado) return null

    items.push({
      serial_id: serialId,
      desgaste: parseDesgaste(item.desgaste),
      resultado,
      observacao: readObservation(item.observacao),
    })
  }

  return items
}

export async function POST(req: Request, context: { params: Promise<{ id: string }> }) {
  let body: unknown
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'invalid_json' }, { status: 400 })
  }

  const payload = body && typeof body === 'object' ? (body as Record<string, unknown>) : {}
  const metodo = parseMetodo(payload.metodo)
  if (!metodo) return NextResponse.json({ error: 'metodo_invalido' }, { status: 400 })

  const items = parseItems(payload.items)
  if (!items) return NextResponse.json({ error: 'items_invalidos' }, { status: 400 })

  const { id } = await context.params
  const auth = await requireRequestUser(req, 'editor')
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: 401 })

  const result = await checkinProject(id, metodo, items, { auth: auth.data })

  if (!result.ok) {
    const status = result.error.includes('login') ? 401 : 400
    return NextResponse.json({ error: result.error }, { status })
  }

  return NextResponse.json(result.data, {
    headers: {
      'Cache-Control': 'private, no-store',
    },
  })
}
