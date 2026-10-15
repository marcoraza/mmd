import { NextResponse } from 'next/server'
import { requireRequestUser } from '@/lib/action-auth'
import { runConferenciaRfid } from '@/lib/actions/rfid'
import { parseConferenciaPayload } from '@/lib/conferencia-rfid-core'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

// Contrato §7, endpoint NOVO.
// Ordem de validação: auth, JSON, payload, evento, regra (igual a
// /api/rfid/scans, não a checkout).
//
// Fecha o loop RFID versus operação: cruza as tags lidas com
// `packing_allocations` e devolve confirmados/faltantes/extras/desconhecidas.
// Grava uma linha em `rfid_scans` por tag lida e não muta status nenhum.
// Chamada repetida é segura: cada chamada grava um lote novo e recalcula os
// buckets do zero.
export async function POST(req: Request, context: { params: Promise<{ id: string }> }) {
  const auth = await requireRequestUser(req, 'editor')
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: 401 })

  let body: unknown
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'invalid_json' }, { status: 400 })
  }

  const parsed = parseConferenciaPayload(body)
  if (!parsed.ok) return NextResponse.json({ error: parsed.error }, { status: 400 })

  const { id } = await context.params
  const result = await runConferenciaRfid(id, parsed.payload, auth.data)

  if (!result.ok) {
    // Evento inexistente segue `resumo` (404 `not_found`), não `checkout`.
    if (result.notFound) return NextResponse.json({ error: 'not_found' }, { status: 404 })
    return NextResponse.json({ error: result.error }, { status: 400 })
  }

  return NextResponse.json(result.data, {
    headers: { 'Cache-Control': 'private, no-store' },
  })
}
