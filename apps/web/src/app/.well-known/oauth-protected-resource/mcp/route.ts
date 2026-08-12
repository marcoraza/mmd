import { mcpProtectedResourceMetadata } from '@/lib/mcp-oauth'

export const runtime = 'nodejs'

export function GET() {
  const metadata = mcpProtectedResourceMetadata()
  if (!metadata) return new Response(null, { status: 404 })

  return Response.json(metadata, {
    headers: { 'cache-control': 'no-store' },
  })
}
