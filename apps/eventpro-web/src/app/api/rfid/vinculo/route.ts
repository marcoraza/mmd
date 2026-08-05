import { NextResponse } from 'next/server'
import { requireRequestUser } from '@/lib/action-auth'
import { bindRfidTagAuthenticated } from '@/lib/actions/rfid'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

// Contrato: endpoint NOVO de vínculo de tag RFID a uma unidade (fecha o gap
// 4.2 da auditoria; o iOS legado fazia PATCH direto no PostgREST). Mesma ordem
// de validação de /api/rfid/scans: auth antes do corpo.
//
// Request: { serial_id: uuid, tag: string }
// Sucesso: { codigo_interno, tag_rfid }
// Erros: 401 auth; 400 invalid_json | serial_id_invalido | demais regras como
// mensagem legível (tag inválida, tag já vinculada, unidade não encontrada).
export async function POST(req: Request) {
  const auth = await requireRequestUser(req, 'editor')
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: 401 })

  let body: unknown
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'invalid_json' }, { status: 400 })
  }

  const serialId =
    typeof (body as { serial_id?: unknown }).serial_id === 'string'
      ? ((body as { serial_id: string }).serial_id ?? '').trim().toLowerCase()
      : ''
  const tag = typeof (body as { tag?: unknown }).tag === 'string' ? (body as { tag: string }).tag : ''

  const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
  if (!UUID_RE.test(serialId)) {
    return NextResponse.json({ error: 'serial_id_invalido' }, { status: 400 })
  }

  const result = await bindRfidTagAuthenticated(serialId, tag)
  if (!result.ok) return NextResponse.json({ error: result.error }, { status: 400 })

  return NextResponse.json(result.data, {
    headers: { 'Cache-Control': 'private, no-store' },
  })
}
