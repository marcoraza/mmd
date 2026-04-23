import 'server-only'
import { supabaseAdmin } from '@/lib/supabase-server'
import type { MetodoScan, TipoMovimentacao } from '@/lib/types'
import type { MovimentacaoTimeline } from '@/lib/data/items'

type MovRow = {
  id: string
  tipo: TipoMovimentacao
  timestamp: string
  status_anterior: string | null
  status_novo: string | null
  registrado_por: string | null
  metodo_scan: MetodoScan | null
  notas: string | null
  serial_numbers: {
    codigo_interno: string | null
  } | null
  projetos: {
    id: string
    nome: string
  } | null
}

// Timeline de um projeto: consumida pela tab Movimentações via <TimelineStream>.
// Mesmo shape de MovimentacaoTimeline em lib/data/items.ts, pra plugar
// direto no componente existente.
export async function loadMovimentacoesByProject(
  projetoId: string,
  limit = 200
): Promise<MovimentacaoTimeline[]> {
  const { data, error } = await supabaseAdmin
    .from('movimentacoes')
    .select(
      `id, tipo, timestamp, status_anterior, status_novo, registrado_por,
       metodo_scan, notas,
       serial_numbers ( codigo_interno ),
       projetos ( id, nome )`
    )
    .eq('projeto_id', projetoId)
    .order('timestamp', { ascending: false })
    .limit(limit)

  if (error) throw error

  return ((data ?? []) as unknown as MovRow[]).map((m) => ({
    id: m.id,
    tipo: m.tipo,
    timestamp: m.timestamp,
    status_anterior: m.status_anterior,
    status_novo: m.status_novo,
    registrado_por: m.registrado_por,
    metodo_scan: m.metodo_scan,
    notas: m.notas,
    serial_codigo: m.serial_numbers?.codigo_interno ?? null,
    projeto_id: m.projetos?.id ?? null,
    projeto_nome: m.projetos?.nome ?? null,
  }))
}
