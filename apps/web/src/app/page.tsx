import { supabase } from '@/lib/supabase'
import { PageHeader } from '@/components/layout/PageHeader'
import { KPICard } from '@/components/dashboard/KPICard'
import { BarChart } from '@/components/dashboard/BarChart'
import { StatusDistribution } from '@/components/dashboard/StatusDistribution'
import { ActivityFeed } from '@/components/dashboard/ActivityFeed'
import { CategoryRanking } from '@/components/dashboard/CategoryRanking'
import { WearByCategory } from '@/components/dashboard/WearByCategory'
import { CriticalItems } from '@/components/dashboard/CriticalItems'
import { StatusChips } from '@/components/dashboard/StatusChips'
import { CategoryBadge } from '@/components/ui/CategoryBadge'
import { WearBar } from '@/components/ui/WearBar'
import { formatCurrency, formatCurrencyFull } from '@/lib/design-tokens'
import type { Categoria, CategoriaStats, StatusStats, ItemCritico } from '@/lib/types'

interface TopItem {
  codigo_interno: string
  nome: string
  categoria: Categoria
  valor_original: number
  desgaste: number
  valor_atual: number
}

interface PerdaCategoria {
  categoria: Categoria
  valor_original: number
  valor_atual: number
  perda: number
  deprec_pct: number
}

async function getDashboardData() {
  const [
    snRes,
    itemsRes,
    statusRes,
    categoriaRes,
    wearCatRes,
    criticalRes,
    movRes,
    lotesRes,
    top10Res,
  ] = await Promise.all([
    supabase.from('serial_numbers').select('valor_atual, desgaste'),
    supabase
      .from('items')
      .select('categoria, valor_mercado_unitario, quantidade_total')
      .not('valor_mercado_unitario', 'is', null),
    supabase.from('serial_numbers').select('status'),
    supabase
      .from('serial_numbers')
      .select('desgaste, items!inner(categoria, valor_mercado_unitario)'),
    supabase
      .from('serial_numbers')
      .select('desgaste, items!inner(categoria)'),
    supabase
      .from('serial_numbers')
      .select('codigo_interno, desgaste, valor_atual, items!inner(nome, categoria)')
      .lte('desgaste', 2)
      .order('desgaste'),
    supabase
      .from('movimentacoes')
      .select('id, tipo, timestamp, notas, serial_numbers!inner(codigo_interno, items!inner(nome))')
      .order('timestamp', { ascending: false })
      .limit(5),
    supabase.from('lotes').select('id', { count: 'exact' }).limit(1),
    supabase
      .from('serial_numbers')
      .select('codigo_interno, desgaste, valor_atual, items!inner(nome, categoria, valor_mercado_unitario)')
      .not('valor_atual', 'is', null)
      .order('valor_atual', { ascending: false })
      .limit(10),
  ])

  // Patrimônio
  const sns = snRes.data ?? []
  const valorAtual = sns.reduce((s, r) => s + (r.valor_atual ?? 0), 0)
  const itensSemValor = sns.filter((r) => !r.valor_atual).length

  const items = itemsRes.data ?? []
  const valorOriginal = items.reduce(
    (s, r) => s + (r.valor_mercado_unitario ?? 0) * r.quantidade_total,
    0,
  )
  const taxaDepreciacao = valorOriginal > 0
    ? ((valorOriginal - valorAtual) / valorOriginal) * 100
    : 0

  // Lotes count
  const lotesCount = lotesRes.count ?? 0

  // Critical count (desgaste <= 2)
  const criticalCount = sns.filter((r) => r.desgaste <= 2).length

  // Status distribution
  const statusMap: Record<string, number> = {}
  for (const sn of snRes.data ?? []) {
    statusMap[(sn as { status?: string }).status ?? 'DISPONIVEL'] =
      (statusMap[(sn as { status?: string }).status ?? 'DISPONIVEL'] ?? 0) + 1
  }

  const allSnRes = await supabase.from('serial_numbers').select('status')
  const statusStats: StatusStats[] = Object.entries(
    (allSnRes.data ?? []).reduce((acc, r) => {
      acc[r.status] = (acc[r.status] ?? 0) + 1
      return acc
    }, {} as Record<string, number>),
  ).map(([status, count]) => ({ status: status as StatusStats['status'], count }))

  const disponiveis = (allSnRes.data ?? []).filter((r) => r.status === 'DISPONIVEL').length
  const emCampo = (allSnRes.data ?? []).filter((r) => r.status === 'EM_CAMPO').length
  const manutencao = (allSnRes.data ?? []).filter((r) => r.status === 'MANUTENCAO').length
  const totalItens = allSnRes.count ?? allSnRes.data?.length ?? 0

  // Categoria stats
  type SnWithItem = { desgaste: number; items: { categoria: string; valor_mercado_unitario?: number } | null }
  const snWithItems = (categoriaRes.data ?? []) as unknown as SnWithItem[]

  const catMap: Record<string, { count: number; valor: number; desgasteSum: number }> = {}
  for (const sn of snWithItems) {
    const cat = sn.items?.categoria ?? 'ACESSORIO'
    if (!catMap[cat]) catMap[cat] = { count: 0, valor: 0, desgasteSum: 0 }
    catMap[cat].count++
    catMap[cat].valor += (sn.items as { valor_mercado_unitario?: number })?.valor_mercado_unitario ?? 0
    catMap[cat].desgasteSum += sn.desgaste
  }
  const categoriaStats: CategoriaStats[] = Object.entries(catMap).map(([cat, v]) => ({
    categoria: cat as CategoriaStats['categoria'],
    count: v.count,
    valor: v.valor,
    desgaste_medio: v.count > 0 ? v.desgasteSum / v.count : 3,
  }))

  // Wear by category
  type SnWear = { desgaste: number; items: { categoria: string } | null }
  const snWear = (wearCatRes.data ?? []) as unknown as SnWear[]
  const wearMap: Record<string, { sum: number; count: number }> = {}
  for (const sn of snWear) {
    const cat = sn.items?.categoria ?? 'ACESSORIO'
    if (!wearMap[cat]) wearMap[cat] = { sum: 0, count: 0 }
    wearMap[cat].sum += sn.desgaste
    wearMap[cat].count++
  }
  const wearStats: CategoriaStats[] = Object.entries(wearMap).map(([cat, v]) => ({
    categoria: cat as CategoriaStats['categoria'],
    count: v.count,
    valor: 0,
    desgaste_medio: v.count > 0 ? v.sum / v.count : 3,
  }))

  // Critical items
  type CritSn = {
    codigo_interno: string
    desgaste: number
    valor_atual?: number
    items: { nome: string; categoria: string } | null
  }
  const criticalItems: ItemCritico[] = ((criticalRes.data ?? []) as unknown as CritSn[]).map((sn) => ({
    codigo_interno: sn.codigo_interno,
    nome: sn.items?.nome ?? '',
    categoria: (sn.items?.categoria ?? 'ACESSORIO') as ItemCritico['categoria'],
    desgaste: sn.desgaste,
    valor_atual: sn.valor_atual,
  }))

  // Activity feed
  type MovRow = {
    id: string
    tipo: string
    timestamp: string
    notas?: string
    serial_numbers: { codigo_interno: string; items: { nome: string } | null } | null
  }
  const activities = ((movRes.data ?? []) as unknown as MovRow[]).map((m) => ({
    id: m.id,
    text: `${m.tipo}: ${m.serial_numbers?.items?.nome ?? m.serial_numbers?.codigo_interno ?? '—'}`,
    timestamp: new Date(m.timestamp).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }),
    color: m.tipo === 'SAIDA' ? '#D4A843' : m.tipo === 'RETORNO' ? '#4A9E5C' : '#D71921',
  }))

  // Top 10 mais valiosos
  type Top10Sn = {
    codigo_interno: string
    desgaste: number
    valor_atual: number
    items: { nome: string; categoria: string; valor_mercado_unitario?: number } | null
  }
  const top10: TopItem[] = ((top10Res.data ?? []) as unknown as Top10Sn[]).map((sn) => ({
    codigo_interno: sn.codigo_interno,
    nome: sn.items?.nome ?? '',
    categoria: (sn.items?.categoria ?? 'ACESSORIO') as Categoria,
    valor_original: sn.items?.valor_mercado_unitario ?? 0,
    desgaste: sn.desgaste,
    valor_atual: sn.valor_atual,
  }))

  // Perda patrimonial por categoria
  const perdaSnRes = await supabase
    .from('serial_numbers')
    .select('valor_atual, items!inner(categoria, valor_mercado_unitario)')
  type PerdaSn = { valor_atual?: number; items: { categoria: string; valor_mercado_unitario?: number } | null }
  const perdaSns = (perdaSnRes.data ?? []) as unknown as PerdaSn[]
  const perdaCatMap: Record<string, { original: number; atual: number }> = {}
  for (const sn of perdaSns) {
    const cat = sn.items?.categoria ?? 'ACESSORIO'
    if (!perdaCatMap[cat]) perdaCatMap[cat] = { original: 0, atual: 0 }
    perdaCatMap[cat].original += sn.items?.valor_mercado_unitario ?? 0
    perdaCatMap[cat].atual += sn.valor_atual ?? 0
  }
  const perdaPatrimonial: PerdaCategoria[] = Object.entries(perdaCatMap)
    .map(([cat, v]) => ({
      categoria: cat as Categoria,
      valor_original: v.original,
      valor_atual: v.atual,
      perda: v.original - v.atual,
      deprec_pct: v.original > 0 ? ((v.original - v.atual) / v.original) * 100 : 0,
    }))
    .sort((a, b) => b.perda - a.perda)

  return {
    valorAtual,
    valorOriginal,
    taxaDepreciacao,
    totalItens,
    itensSemValor,
    disponiveis,
    emCampo,
    manutencao,
    criticalCount,
    lotesCount,
    statusStats,
    categoriaStats,
    wearStats,
    criticalItems,
    activities,
    top10,
    perdaPatrimonial,
  }
}

export default async function DashboardPage() {
  const data = await getDashboardData().catch(() => null)

  const month = new Date().toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })
  const title = `Visão Geral — ${month.charAt(0).toUpperCase() + month.slice(1)}`

  if (!data) {
    return (
      <div>
        <PageHeader title={title} />
        <div style={{ padding: '32px', fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#D71921' }}>
          SUPABASE NÃO CONFIGURADO — ADICIONE .ENV.LOCAL
        </div>
      </div>
    )
  }

  return (
    <div>
      <PageHeader title={title} />

      {/* KPI row 1 — main */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(4, 1fr)',
          borderBottom: '1px solid #E8E8E8',
        }}
      >
        <KPICard
          label="Valor Original"
          value={formatCurrency(data.valorOriginal)}
          borderRight
        />
        <KPICard
          label="Valor Atual"
          value={formatCurrency(data.valorAtual)}
          borderRight
        />
        <KPICard
          label="Depreciação"
          value={`${Math.round(data.taxaDepreciacao)}%`}
          gauge={{ value: data.taxaDepreciacao, label: 'DEPREC.', color: '#D4A843' }}
          borderRight
        />
        <KPICard
          label="Críticos"
          value={String(data.criticalCount)}
          delta={data.criticalCount > 0 ? 'DESGASTE ≤ 2' : undefined}
          deltaColor="#D71921"
        />
      </div>

      {/* KPI row 2 — secondary */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(4, 1fr)',
          borderBottom: '1px solid #E8E8E8',
        }}
      >
        {[
          { label: 'TOTAL ITENS', value: data.totalItens },
          { label: 'DISPONÍVEIS', value: data.disponiveis },
          { label: 'MANUTENÇÃO', value: data.manutencao },
          { label: 'LOTES', value: data.lotesCount },
        ].map((kpi, i) => (
          <div
            key={kpi.label}
            style={{
              padding: '12px 24px',
              borderRight: i < 3 ? '1px solid #E8E8E8' : undefined,
            }}
          >
            <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 4 }}>
              {kpi.label}
            </div>
            <div style={{ fontFamily: '"Doto", sans-serif', fontSize: 32, fontWeight: 700, color: '#000000', lineHeight: 1 }}>
              {kpi.value}
            </div>
          </div>
        ))}
      </div>

      {/* Charts row */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '3fr 2fr',
          borderBottom: '1px solid #E8E8E8',
        }}
      >
        <BarChart data={data.categoriaStats} label="Valor por Categoria" />
        <StatusDistribution data={data.statusStats} />
      </div>

      {/* Activity + Ranking */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          borderBottom: '1px solid #E8E8E8',
        }}
      >
        <ActivityFeed items={data.activities} />
        <CategoryRanking data={data.categoriaStats} />
      </div>

      {/* Saúde patrimonial */}
      <div style={{ borderBottom: '1px solid #E8E8E8' }}>
        <div style={{ padding: '16px 24px 0', fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em' }}>
          SAÚDE PATRIMONIAL
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr' }}>
          <WearByCategory data={data.wearStats} />
          <CriticalItems items={data.criticalItems} />
        </div>
      </div>

      {/* Top 10 mais valiosos */}
      <div style={{ borderBottom: '1px solid #E8E8E8' }}>
        <div style={{ padding: '16px 24px 0', fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em' }}>
          TOP 10 MAIS VALIOSOS
        </div>
        <div style={{ padding: '12px 24px 16px', overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontFamily: '"Space Grotesk", sans-serif', fontSize: 13 }}>
            <thead>
              <tr>
                {['#', 'NOME', 'CATEGORIA', 'VALOR ORIGINAL', 'DESGASTE', 'VALOR ATUAL'].map((h) => (
                  <th
                    key={h}
                    style={{
                      fontFamily: '"Space Mono", monospace',
                      fontSize: 9,
                      color: '#999999',
                      letterSpacing: '0.1em',
                      textAlign: h === '#' ? 'center' : 'left',
                      padding: '8px 8px',
                      borderBottom: '1px solid #E8E8E8',
                      fontWeight: 400,
                    }}
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {data.top10.map((item, i) => (
                <tr key={item.codigo_interno} style={{ borderBottom: '1px solid #F2F2F2' }}>
                  <td style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#999999', textAlign: 'center', padding: '8px' }}>
                    {i + 1}
                  </td>
                  <td style={{ padding: '8px', color: '#000000' }}>
                    <div>{item.nome}</div>
                    <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', marginTop: 2 }}>
                      {item.codigo_interno}
                    </div>
                  </td>
                  <td style={{ padding: '8px' }}>
                    <CategoryBadge categoria={item.categoria} />
                  </td>
                  <td style={{ padding: '8px', fontFamily: '"Space Mono", monospace', fontSize: 13, color: '#000000' }}>
                    {formatCurrencyFull(item.valor_original)}
                  </td>
                  <td style={{ padding: '8px' }}>
                    <WearBar desgaste={item.desgaste} />
                  </td>
                  <td style={{ padding: '8px', fontFamily: '"Space Mono", monospace', fontSize: 13, fontWeight: 700, color: '#000000' }}>
                    {formatCurrencyFull(item.valor_atual)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Perda patrimonial por categoria */}
      <div style={{ borderBottom: '1px solid #E8E8E8' }}>
        <div style={{ padding: '16px 24px 0', fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em' }}>
          PERDA PATRIMONIAL POR CATEGORIA
        </div>
        <div style={{ padding: '12px 24px 16px', overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontFamily: '"Space Grotesk", sans-serif', fontSize: 13 }}>
            <thead>
              <tr>
                {['CATEGORIA', 'VALOR ORIGINAL', 'VALOR ATUAL', 'PERDA (R$)', 'DEPREC. %'].map((h) => (
                  <th
                    key={h}
                    style={{
                      fontFamily: '"Space Mono", monospace',
                      fontSize: 9,
                      color: '#999999',
                      letterSpacing: '0.1em',
                      textAlign: 'left',
                      padding: '8px 8px',
                      borderBottom: '1px solid #E8E8E8',
                      fontWeight: 400,
                    }}
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {data.perdaPatrimonial.map((row) => (
                <tr key={row.categoria} style={{ borderBottom: '1px solid #F2F2F2' }}>
                  <td style={{ padding: '8px' }}>
                    <CategoryBadge categoria={row.categoria} />
                  </td>
                  <td style={{ padding: '8px', fontFamily: '"Space Mono", monospace', fontSize: 13, color: '#000000' }}>
                    {formatCurrencyFull(row.valor_original)}
                  </td>
                  <td style={{ padding: '8px', fontFamily: '"Space Mono", monospace', fontSize: 13, color: '#000000' }}>
                    {formatCurrencyFull(row.valor_atual)}
                  </td>
                  <td style={{ padding: '8px', fontFamily: '"Space Mono", monospace', fontSize: 13, color: '#D71921', fontWeight: 700 }}>
                    {formatCurrencyFull(row.perda)}
                  </td>
                  <td style={{ padding: '8px', fontFamily: '"Space Mono", monospace', fontSize: 13, color: '#D4A843', fontWeight: 700 }}>
                    {row.deprec_pct.toFixed(1)}%
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Status chips */}
      <StatusChips
        chips={[
          { label: 'SUPABASE OK', ok: true },
          { label: `${data.disponiveis} DISPONÍVEIS`, ok: true },
          { label: data.emCampo > 0 ? `${data.emCampo} EM CAMPO` : 'CAMPO VAZIO', ok: data.emCampo === 0 },
          { label: data.itensSemValor > 0 ? `${data.itensSemValor} SEM VALOR` : 'VALORES OK', ok: data.itensSemValor === 0 },
        ]}
      />
    </div>
  )
}
