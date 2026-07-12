import { NextResponse } from 'next/server'
import { requireRequestUser } from '@/lib/action-auth'
import { recordAuthenticatedRfidScans } from '@/lib/actions/rfid-scans'
import { parseRfidScanPayload } from '@/lib/rfid-scan-core'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function POST(req: Request) {
  const auth = await requireRequestUser(req, 'editor')
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: 401 })

  let body: unknown
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'invalid_json' }, { status: 400 })
  }

  const parsed = parseRfidScanPayload(body)
  if (!parsed.ok) return NextResponse.json({ error: parsed.error }, { status: 400 })

  const result = await recordAuthenticatedRfidScans(parsed.payload, auth.data)
  if (!result.ok) return NextResponse.json({ error: result.error }, { status: 400 })

  return NextResponse.json(result.data, {
    headers: {
      'Cache-Control': 'private, no-store',
    },
  })
}
