import { NextResponse } from 'next/server'
import { requireRequestUser } from '@/lib/action-auth'
import { searchSeriais } from '@/lib/data/serial-search'
import { parseSerialSearchParams } from '@/lib/serial-search-core'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

// Contrato §8, endpoint NOVO.
// Substitui a busca client-side do iOS, que baixava o catálogo inteiro e
// filtrava em memória.
//
// Nada de valor, depreciação, localização ou histórico entra na resposta: é
// busca de vínculo, não consulta de patrimônio.
export async function GET(req: Request) {
  const auth = await requireRequestUser(req, 'viewer')
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: 401 })

  const parsed = parseSerialSearchParams(new URL(req.url).searchParams)
  if (!parsed.ok) return NextResponse.json({ error: parsed.error }, { status: 400 })

  try {
    const page = await searchSeriais(parsed.params)
    return NextResponse.json(page, {
      headers: { 'Cache-Control': 'private, no-store' },
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Falha na busca de unidades.'
    return NextResponse.json({ error: message }, { status: 400 })
  }
}
