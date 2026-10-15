import { supabaseAdmin } from '@/lib/supabase-server'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

type Health = { ok: boolean; detalhe: string }

// Ping barato no Supabase: `head: true` com `count: exact` não traz linha
// nenhuma, só confirma que credencial, rede e schema respondem.
async function checkSupabase(): Promise<Health> {
  try {
    const { error } = await supabaseAdmin
      .from('projetos')
      .select('id', { count: 'exact', head: true })
    if (error) return { ok: false, detalhe: error.message }
    return { ok: true, detalhe: 'conectado' }
  } catch (error) {
    return { ok: false, detalhe: error instanceof Error ? error.message : 'falha desconhecida' }
  }
}

export default async function HomePage() {
  const supabase = await checkSupabase()

  return (
    <main>
      <h1 style={{ margin: 0 }}>EventPro API</h1>
      <p>
        BFF do EventPro. A interface de produto (design 2.0) é a fase 7 do plano de migração; nesta
        fase o app expõe apenas rotas de API.
      </p>

      <h2>Saúde</h2>
      <ul style={{ fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace' }}>
        <li>
          supabase: {supabase.ok ? 'ok' : 'erro'} ({supabase.detalhe})
        </li>
      </ul>

      <h2>Endpoints</h2>
      <ul style={{ fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace' }}>
        <li>POST /api/eventos/[id]/checkout</li>
        <li>POST /api/eventos/[id]/retorno</li>
        <li>GET /api/eventos/[id]/resumo</li>
        <li>POST /api/eventos/[id]/conferencia-rfid</li>
        <li>POST /api/rfid/scans</li>
        <li>GET /api/seriais/busca</li>
        <li>POST /api/qr-sheet</li>
      </ul>
    </main>
  )
}
