import { NextResponse } from 'next/server'
import { requireRequestUser } from '@/lib/action-auth'
import { loadEventoResumo } from '@/lib/data/evento-resumo'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function GET(req: Request, context: { params: Promise<{ id: string }> }) {
  const auth = await requireRequestUser(req, 'viewer')
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: 401 })

  const { id } = await context.params
  const resumo = await loadEventoResumo(id)
  if (!resumo) return NextResponse.json({ error: 'not_found' }, { status: 404 })

  return NextResponse.json(resumo, {
    headers: {
      'Cache-Control': 'private, no-store',
    },
  })
}
