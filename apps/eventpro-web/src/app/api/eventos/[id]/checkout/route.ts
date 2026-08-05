import { NextResponse } from 'next/server'
import { requireRequestUser } from '@/lib/action-auth'
import { checkoutProject } from '@/lib/actions/movimentacoes'
import type { MetodoScan } from '@/lib/types'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

const METODOS: MetodoScan[] = ['RFID', 'QRCODE', 'MANUAL']

function parseMetodo(value: unknown): MetodoScan | null {
  return typeof value === 'string' && METODOS.includes(value as MetodoScan)
    ? (value as MetodoScan)
    : null
}

function readString(value: unknown) {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined
}

// Contrato §2, CONGELADO.
//
// Ordem de validação: JSON, metodo, params, auth, regra. A ordem faz parte do
// contrato observável: um chamador não autenticado com corpo inválido recebe
// 400, não 401 (§1.4).
//
// `overrideReason` é o único campo camelCase de toda a superfície HTTP,
// congelado por compatibilidade com `CheckoutProjectRequest` do iOS (D6).
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

  const { id } = await context.params
  const auth = await requireRequestUser(req, 'editor')
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: 401 })

  const result = await checkoutProject(id, metodo, {
    overrideReason: readString(payload.overrideReason),
    auth: auth.data,
  })

  if (!result.ok) {
    // Regra congelada (§2.5): qualquer erro cuja frase contenha "login" vira
    // 401; todo o resto vira 400.
    const status = result.error.includes('login') ? 401 : 400
    return NextResponse.json({ error: result.error }, { status })
  }

  return NextResponse.json(result.data, {
    headers: { 'Cache-Control': 'private, no-store' },
  })
}
