import { supabase } from '@/lib/supabase'
import { Sidebar } from './Sidebar'

async function getSidebarStats() {
  const [valorRes, totalRes, disponiveisRes, emCampoRes, desgasteRes] = await Promise.all([
    supabase
      .from('serial_numbers')
      .select('valor_atual')
      .not('valor_atual', 'is', null),
    supabase.from('serial_numbers').select('id', { count: 'exact', head: true }),
    supabase
      .from('serial_numbers')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'DISPONIVEL'),
    supabase
      .from('serial_numbers')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'EM_CAMPO'),
    supabase.from('serial_numbers').select('desgaste'),
  ])

  const valorAtual = (valorRes.data ?? []).reduce((s, r) => s + (r.valor_atual ?? 0), 0)
  const totalItens = totalRes.count ?? 0
  const disponiveis = disponiveisRes.count ?? 0
  const emCampo = emCampoRes.count ?? 0

  const desgastes = (desgasteRes.data ?? []).map((r) => r.desgaste)
  const desgasteMedio = desgastes.length > 0
    ? desgastes.reduce((s, d) => s + d, 0) / desgastes.length
    : 3

  const valorOriginalRes = await supabase
    .from('items')
    .select('valor_mercado_unitario, quantidade_total')
    .not('valor_mercado_unitario', 'is', null)

  const valorOriginal = (valorOriginalRes.data ?? []).reduce(
    (s, r) => s + (r.valor_mercado_unitario ?? 0) * r.quantidade_total,
    0,
  )

  const tendenciaPct = valorOriginal > 0
    ? ((valorOriginal - valorAtual) / valorOriginal) * 100
    : 0

  return { valorAtual, totalItens, disponiveis, emCampo, desgasteMedio, tendenciaPct }
}

export async function SidebarWrapper() {
  const stats = await getSidebarStats().catch(() => undefined)

  return (
    <div className="hidden md:block">
      <Sidebar stats={stats} />
    </div>
  )
}
