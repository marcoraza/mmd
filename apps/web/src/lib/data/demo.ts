import 'server-only'
import type {
  CatalogData,
  CatalogItem,
  CatalogUnit,
  ItemDetail,
  MovimentacaoTimeline,
  SerialRow,
} from '@/lib/data/items'
import type { LoteRow, LotesData } from '@/lib/data/lotes'
import type { ProjectDetail, ProjectPackingLine } from '@/lib/data/project-detail'
import type { PackingItem, ProjectsData, Projeto } from '@/lib/data/projects'
import type { QrSources } from '@/lib/data/qrcodes'
import type { RfidData, RfidScan } from '@/lib/data/rfid'
import type { EventoComercialRecord } from '@/lib/evento-comercial-core'
import {
  calculateFichaChecklist,
  calculateFichaRecordCompleteness,
  type EventoFichaRecord,
} from '@/lib/evento-ficha-core'
import { computePackingCoverage, type ExternalRentalCoverage } from '@/lib/external-rental-core'
import { buildCheckoutGate } from '@/lib/checkout-gate-core'
import { toUnitOnlyQrLoteState } from '@/lib/legacy-lotes-core'
import type { StockStats } from '@/lib/data/stock'
import type { Categoria, Estado, StatusSerial } from '@/lib/types'

type DemoItemSeed = {
  id: string
  codigo_interno: string
  nome: string
  categoria: Categoria
  subcategoria: string | null
  marca: string | null
  modelo: string | null
  quantidade_total: number
  valor_mercado_unitario: number
}

type DemoSerialSeed = {
  id: string
  item_id: string
  codigo_interno: string
  serial_fabrica: string | null
  tag_rfid: string | null
  qr_code: string
  status: StatusSerial
  estado: Estado
  desgaste: number
  valor_atual: number
  localizacao: string | null
  updated_at: string
}

const NOW = '2026-06-09T15:00:00.000Z'

const demoItems: DemoItemSeed[] = [
  {
    id: 'demo-item-beam-7r',
    codigo_interno: 'MMD-ILU-0001',
    nome: 'Moving Beam 7R 230W',
    categoria: 'ILUMINACAO',
    subcategoria: 'Moving head',
    marca: 'BeamPro',
    modelo: '7R 230W',
    quantidade_total: 8,
    valor_mercado_unitario: 4200,
  },
  {
    id: 'demo-item-par-led',
    codigo_interno: 'MMD-ILU-0002',
    nome: 'PAR LED RGBW Outdoor',
    categoria: 'ILUMINACAO',
    subcategoria: 'PAR LED',
    marca: 'MMD',
    modelo: 'RGBW IP65',
    quantidade_total: 12,
    valor_mercado_unitario: 980,
  },
  {
    id: 'demo-item-caixa-prx',
    codigo_interno: 'MMD-AUD-0001',
    nome: 'Caixa Ativa JBL PRX815',
    categoria: 'AUDIO',
    subcategoria: 'PA ativo',
    marca: 'JBL',
    modelo: 'PRX815',
    quantidade_total: 6,
    valor_mercado_unitario: 6900,
  },
  {
    id: 'demo-item-regua',
    codigo_interno: 'MMD-ENE-0001',
    nome: 'Régua de Energia 12 canais',
    categoria: 'ENERGIA',
    subcategoria: 'Distribuição',
    marca: 'MMD',
    modelo: 'Rack 12CH',
    quantidade_total: 4,
    valor_mercado_unitario: 1800,
  },
]

const demoSerials: DemoSerialSeed[] = [
  serial('demo-serial-beam-01', 'demo-item-beam-7r', 'MMD-ILU-0001', 1, 'DISPONIVEL', 4, 3360),
  serial('demo-serial-beam-02', 'demo-item-beam-7r', 'MMD-ILU-0002', 2, 'DISPONIVEL', 4, 3360),
  serial('demo-serial-beam-03', 'demo-item-beam-7r', 'MMD-ILU-0003', 3, 'PACKED', 3, 2520),
  serial('demo-serial-beam-04', 'demo-item-beam-7r', 'MMD-ILU-0004', 4, 'PACKED', 3, 2520),
  serial('demo-serial-beam-05', 'demo-item-beam-7r', 'MMD-ILU-0005', 5, 'EM_CAMPO', 4, 3360),
  serial('demo-serial-beam-06', 'demo-item-beam-7r', 'MMD-ILU-0006', 6, 'MANUTENCAO', 2, 1680),
  serial('demo-serial-par-01', 'demo-item-par-led', 'MMD-ILU-0101', 101, 'DISPONIVEL', 5, 980),
  serial('demo-serial-par-02', 'demo-item-par-led', 'MMD-ILU-0102', 102, 'DISPONIVEL', 4, 784),
  serial('demo-serial-par-03', 'demo-item-par-led', 'MMD-ILU-0103', 103, 'DISPONIVEL', 4, 784),
  serial('demo-serial-par-04', 'demo-item-par-led', 'MMD-ILU-0104', 104, 'EM_CAMPO', 3, 588),
  serial('demo-serial-aud-01', 'demo-item-caixa-prx', 'MMD-AUD-0001', 201, 'DISPONIVEL', 4, 5520),
  serial('demo-serial-aud-02', 'demo-item-caixa-prx', 'MMD-AUD-0002', 202, 'DISPONIVEL', 4, 5520),
  serial('demo-serial-aud-03', 'demo-item-caixa-prx', 'MMD-AUD-0003', 203, 'PACKED', 3, 4140),
  serial('demo-serial-aud-04', 'demo-item-caixa-prx', 'MMD-AUD-0004', 204, 'RETORNANDO', 3, 4140),
  serial('demo-serial-regua-01', 'demo-item-regua', 'MMD-ENE-0001', 301, 'DISPONIVEL', 4, 1440),
  serial('demo-serial-regua-02', 'demo-item-regua', 'MMD-ENE-0002', 302, 'MANUTENCAO', 2, 720),
]

const demoLotes: LoteRow[] = [
  {
    id: 'demo-lote-xlr-10m',
    codigo_lote: 'MMD-CAB-010M',
    descricao: 'Cabos XLR 10m revisados por lote',
    quantidade: 48,
    tag_rfid: 'RFID-CAB-010M',
    qr_code: 'MMD-CAB-010M',
    status: 'DISPONIVEL',
    created_at: '2026-05-18T10:00:00.000Z',
    updated_at: NOW,
    item_id: 'demo-item-cabo-xlr',
    item_nome: 'Cabo XLR 10m',
    item_categoria: 'CABO',
    item_subcategoria: 'Áudio balanceado',
    item_marca: 'Santo Angelo',
    item_valor_mercado_unitario: 95,
  },
  {
    id: 'demo-lote-ac-20m',
    codigo_lote: 'MMD-ENE-AC20',
    descricao: 'Extensões AC 20m para palco',
    quantidade: 24,
    tag_rfid: 'RFID-ENE-AC20',
    qr_code: 'MMD-ENE-AC20',
    status: 'EM_CAMPO',
    created_at: '2026-05-18T10:00:00.000Z',
    updated_at: NOW,
    item_id: 'demo-item-extensao-ac',
    item_nome: 'Extensão AC 20m',
    item_categoria: 'ENERGIA',
    item_subcategoria: 'Cabos de força',
    item_marca: 'MMD',
    item_valor_mercado_unitario: 140,
  },
]

const demoMovimentacoes: MovimentacaoTimeline[] = [
  {
    id: 'demo-mov-001',
    tipo: 'SAIDA',
    timestamp: '2026-06-09T11:20:00.000Z',
    status_anterior: 'DISPONIVEL',
    status_novo: 'PACKED',
    registrado_por: 'Marco',
    metodo_scan: 'QRCODE',
    notas: 'Separado para Casamento Santos & Oliveira',
    serial_codigo: 'MMD-ILU-0003',
    projeto_id: 'demo-proj-casamento',
    projeto_nome: 'Casamento Santos & Oliveira',
  },
  {
    id: 'demo-mov-002',
    tipo: 'TRANSFERENCIA',
    timestamp: '2026-06-08T16:45:00.000Z',
    status_anterior: 'DISPONIVEL',
    status_novo: 'MANUTENCAO',
    registrado_por: 'Marcelo',
    metodo_scan: 'RFID',
    notas: 'Ruído no pan, revisar antes de novo evento',
    serial_codigo: 'MMD-ILU-0006',
    projeto_id: null,
    projeto_nome: null,
  },
]

function serial(
  id: string,
  item_id: string,
  codigo: string,
  tagSuffix: number,
  status: StatusSerial,
  desgaste: number,
  valor_atual: number,
): DemoSerialSeed {
  return {
    id,
    item_id,
    codigo_interno: codigo,
    serial_fabrica: `SN-${tagSuffix.toString().padStart(5, '0')}`,
    tag_rfid: `E280-MMD-${tagSuffix.toString().padStart(6, '0')}`,
    qr_code: codigo,
    status,
    estado: desgaste >= 5 ? 'SEMI_NOVO' : 'USADO',
    desgaste,
    valor_atual,
    localizacao: status === 'EM_CAMPO' || status === 'PACKED' ? 'Evento em preparo' : 'Galpão MMD',
    updated_at: NOW,
  }
}

function itemById(id: string) {
  return demoItems.find((item) => item.id === id) ?? null
}

function unitsForItem(itemId: string) {
  return demoSerials.filter((serialRow) => serialRow.item_id === itemId)
}

function toCatalogUnit(row: DemoSerialSeed): CatalogUnit {
  const item = itemById(row.item_id)
  if (!item) throw new Error(`Demo item missing for ${row.item_id}`)
  return {
    id: row.id,
    codigo_interno: row.codigo_interno,
    serial_fabrica: row.serial_fabrica,
    tag_rfid: row.tag_rfid,
    qr_code: row.qr_code,
    status: row.status,
    estado: row.estado,
    desgaste: row.desgaste,
    valor_atual: row.valor_atual,
    localizacao: row.localizacao,
    updated_at: row.updated_at,
    item_id: item.id,
    item_nome: item.nome,
    item_categoria: item.categoria,
    item_subcategoria: item.subcategoria,
    item_marca: item.marca,
    item_modelo: item.modelo,
    item_valor_mercado_unitario: item.valor_mercado_unitario,
  }
}

function aggregateDemoItem(item: DemoItemSeed): CatalogItem {
  const units = unitsForItem(item.id)
  const active = units.filter((unit) =>
    ['DISPONIVEL', 'PACKED', 'EM_CAMPO', 'RETORNANDO', 'MANUTENCAO'].includes(unit.status),
  )
  const disponivel = units.filter((unit) => unit.status === 'DISPONIVEL').length
  const emCampo = units.filter(
    (unit) => unit.status === 'EM_CAMPO' || unit.status === 'PACKED',
  ).length
  const manutencao = units.filter((unit) => unit.status === 'MANUTENCAO').length
  const estados = new Set(active.map((unit) => unit.estado))
  const situacoes = new Set(active.map((unit) => unit.status))
  return {
    id: item.id,
    codigo_interno: item.codigo_interno,
    nome: item.nome,
    categoria: item.categoria,
    subcategoria: item.subcategoria,
    marca: item.marca,
    modelo: item.modelo,
    quantidade_total: item.quantidade_total,
    foto_url: null,
    valor_mercado_unitario: item.valor_mercado_unitario,
    situacao:
      situacoes.size === 1 && active[0] ? active[0].status : active.length > 0 ? 'MISTO' : 'BAIXA',
    ciclo: estados.size === 1 && active[0] ? active[0].estado : active.length > 0 ? 'MISTO' : null,
    condicao_media:
      active.length > 0 ? active.reduce((acc, unit) => acc + unit.desgaste, 0) / active.length : 0,
    valor_atual_total: active.reduce((acc, unit) => acc + unit.valor_atual, 0),
    disponivel_count: disponivel,
    em_campo_count: emCampo,
    manutencao_count: manutencao,
    criticos_count: active.filter((unit) => unit.desgaste <= 2).length,
    regular_count: active.filter((unit) => unit.desgaste === 3).length,
    otimo_count: active.filter((unit) => unit.desgaste >= 4).length,
    rfid_tagged_count: active.filter((unit) => unit.tag_rfid?.trim()).length,
    rfid_pending_count: active.filter((unit) => !unit.tag_rfid?.trim()).length,
  }
}

export function loadDemoUnits(): CatalogUnit[] {
  return demoSerials.map(toCatalogUnit)
}

export function loadDemoCatalog(): CatalogData {
  const items = demoItems.map(aggregateDemoItem)
  const banner = items.reduce(
    (acc, item) => {
      acc.disponivel += item.disponivel_count
      acc.em_campo += item.em_campo_count
      acc.manutencao += item.manutencao_count
      acc.criticos += item.criticos_count
      acc.regular += item.regular_count
      acc.otimo += item.otimo_count
      acc.total_ativos += item.disponivel_count + item.em_campo_count + item.manutencao_count
      return acc
    },
    {
      disponivel: 0,
      em_campo: 0,
      manutencao: 0,
      criticos: 0,
      regular: 0,
      otimo: 0,
      utilizacao_pct: 0,
      total_ativos: 0,
    },
  )
  banner.utilizacao_pct =
    banner.total_ativos > 0 ? (banner.em_campo / banner.total_ativos) * 100 : 0

  const categoryMap = new Map<Categoria, number>()
  for (const item of items) {
    categoryMap.set(
      item.categoria,
      (categoryMap.get(item.categoria) ?? 0) +
        item.disponivel_count +
        item.em_campo_count +
        item.manutencao_count,
    )
  }

  return {
    items,
    banner,
    categories: [...categoryMap.entries()].map(([categoria, qtd]) => ({ categoria, qtd })),
    total_lotes: demoLotes.length,
  }
}

export function loadDemoStockStats(): StockStats {
  const units = loadDemoUnits()
  return {
    disponivel: units.filter((unit) => unit.status === 'DISPONIVEL').length,
    em_campo: units.filter((unit) => unit.status === 'EM_CAMPO' || unit.status === 'PACKED').length,
    retornando: units.filter((unit) => unit.status === 'RETORNANDO').length,
    manutencao: units.filter((unit) => unit.status === 'MANUTENCAO').length,
    criticos: units.filter((unit) => unit.desgaste <= 2).length,
    patrimonio_total: units.reduce((acc, unit) => acc + (unit.valor_atual ?? 0), 0),
    baixas: units.filter((unit) => unit.status === 'BAIXA').length,
    vendidos: units.filter((unit) => unit.status === 'VENDIDO').length,
  }
}

export function getDemoItemById(id: string): ItemDetail | null {
  const item = itemById(id)
  if (!item) return null
  const serials: SerialRow[] = unitsForItem(id)
    .map((unit) => ({
      id: unit.id,
      codigo_interno: unit.codigo_interno,
      serial_fabrica: unit.serial_fabrica,
      tag_rfid: unit.tag_rfid,
      qr_code: unit.qr_code,
      status: unit.status,
      estado: unit.estado,
      desgaste: unit.desgaste,
      valor_atual: unit.valor_atual,
      localizacao: unit.localizacao,
      notas: null,
      updated_at: unit.updated_at,
    }))
    .sort((a, b) => a.codigo_interno.localeCompare(b.codigo_interno))
  return {
    item: aggregateDemoItem(item),
    notas: 'Registro demo enquanto Supabase MMD não responde.',
    serials,
    timeline: demoMovimentacoes.filter((mov) =>
      serials.some((serialRow) => serialRow.codigo_interno === mov.serial_codigo),
    ),
  }
}

function demoPacking(): PackingItem[] {
  return [
    packingLine('demo-pack-beam', 'demo-item-beam-7r', 6, [
      'demo-serial-beam-03',
      'demo-serial-beam-04',
    ]),
    packingLine('demo-pack-audio', 'demo-item-caixa-prx', 4, ['demo-serial-aud-03']),
    packingLine('demo-pack-regua', 'demo-item-regua', 2, ['demo-serial-regua-01']),
    packingLine('demo-pack-cabo', 'demo-item-cabo-xlr', 40, []),
  ]
}

function demoExternalRentals(lineId: string): ExternalRentalCoverage[] {
  if (lineId !== 'demo-pack-beam') return []
  return [
    {
      id: 'demo-rental-beam-lightpro',
      fornecedor: 'LightPro Eventos',
      quantidade: 4,
      observacao: 'Retirar no parceiro às 10h. Não entra no patrimônio MMD.',
      created_at: '2026-06-11T13:00:00.000Z',
    },
  ]
}

function packingLine(id: string, itemId: string, qtd: number, allocatedIds: string[]): PackingItem {
  const item = itemById(itemId)
  const fallback =
    itemId === 'demo-item-cabo-xlr'
      ? { codigo_interno: 'MMD-CAB-010M', nome: 'Cabo XLR 10m', categoria: 'CABO' as Categoria }
      : { codigo_interno: '', nome: 'Item demo', categoria: 'ACESSORIO' as Categoria }
  const itemInfo = item ?? fallback
  const coverage = computePackingCoverage({
    qtdNecessaria: qtd,
    qtdPropria: allocatedIds.length,
    alugueisAvulsos: demoExternalRentals(id),
  })
  return {
    id,
    item_id: itemId,
    codigo_interno: itemInfo.codigo_interno,
    nome: itemInfo.nome,
    categoria: itemInfo.categoria,
    qtd_necessaria: qtd,
    qtd_alocada: coverage.qtd_propria,
    qtd_alugada_avulsa: coverage.qtd_alugada_avulsa,
    qtd_coberta: coverage.qtd_coberta,
    qtd_faltante: coverage.qtd_faltante,
    status: coverage.status,
  }
}

function demoComercial(projectId: string): EventoComercialRecord {
  if (projectId !== 'demo-proj-casamento') {
    return {
      status: null,
      documentos: [],
      observacoes: null,
      atualizado_em: null,
      permite_operacao_estoque: false,
      readiness_pct: 0,
    }
  }

  return {
    status: 'ORCAMENTO_APROVADO',
    documentos: [
      {
        id: 'demo-orcamento-link',
        tipo: 'ORCAMENTO',
        origem: 'LINK',
        titulo: 'Orçamento linkado',
        url: 'https://drive.google.com/file/d/orcamento-demo',
        href: 'https://drive.google.com/file/d/orcamento-demo',
        storage_path: null,
        filename: null,
        mime_type: null,
        tamanho_bytes: null,
        atualizado_em: '2026-06-10T12:00:00.000Z',
      },
      {
        id: 'demo-contrato-upload',
        tipo: 'CONTRATO',
        origem: 'UPLOAD',
        titulo: 'Contrato anexado',
        url: null,
        href: null,
        storage_path: 'demo-proj-casamento/contrato/contrato-demo.pdf',
        filename: 'contrato-demo.pdf',
        mime_type: 'application/pdf',
        tamanho_bytes: 152000,
        atualizado_em: '2026-06-11T12:00:00.000Z',
      },
    ],
    observacoes: 'Orçamento aprovado por e-mail. Contrato em revisão final.',
    atualizado_em: '2026-06-11T12:00:00.000Z',
    permite_operacao_estoque: true,
    readiness_pct: 50,
  }
}

function demoFicha(projectId: string): EventoFichaRecord | null {
  if (projectId !== 'demo-proj-casamento') return null

  return {
    versao: 1,
    atualizadoEm: '2026-06-11T13:00:00.000Z',
    evento: {
      nome: 'Casamento Santos & Oliveira',
      cliente: 'Santos & Oliveira',
      dataInicial: '2026-06-12',
      dataFinal: '2026-06-13',
      statusInicial: 'CONFIRMADO',
    },
    endereco: {
      local: 'Jardim Botânico, SP',
      endereco: 'Av. Miguel Estéfano, 3031',
      cidadeUf: 'São Paulo, SP',
      referenciaAcesso: 'Entrada técnica pelo portão de serviço.',
    },
    montagem: {
      dia: '2026-06-12',
      inicio: '10:00',
      fim: '14:00',
      equipe: 'Equipe MMD',
      responsavel: 'Marcelo Santos',
      telefone: '(11) 99999-0000',
    },
    desmontagem: {
      dia: '2026-06-13',
      inicio: '23:30',
      fim: '01:30',
      equipe: 'Equipe MMD',
      responsavel: 'Marcelo Santos',
      telefone: '(11) 99999-0000',
    },
    responsaveis: {
      principal: 'Marcelo Santos',
      principalTelefone: '(11) 99999-0000',
      checklist: 'Admin MMD',
      checklistTelefone: '(11) 98888-0000',
    },
    checklist: [
      { item: 'Mapa de palco validado', responsavel: 'Marcelo', ok: true },
      { item: 'Parceiro de avulso confirmou retirada', responsavel: 'Admin', ok: false },
    ],
    observacoes: 'OBS do evento: retirada de avulsos precisa confirmação final.',
  }
}

export function loadDemoProjects(): ProjectsData {
  const casamentoPacking = demoPacking()
  const casamentoItensTotal = casamentoPacking.reduce((acc, line) => acc + line.qtd_necessaria, 0)
  const casamentoItensCobertos = casamentoPacking.reduce((acc, line) => acc + line.qtd_coberta, 0)
  const projetos: Projeto[] = [
    {
      id: 'demo-proj-casamento',
      nome: 'Casamento Santos & Oliveira',
      cliente: 'Santos & Oliveira',
      data_inicio: '2026-06-12',
      data_fim: '2026-06-13',
      local: 'Jardim Botânico, SP',
      status: 'CONFIRMADO',
      notas: 'Demo operacional para reunião com Marcelo.',
      packing: casamentoPacking,
      itens_count: casamentoPacking.length,
      itens_total: casamentoItensTotal,
      itens_alocados: casamentoItensCobertos,
      readiness_pct:
        casamentoItensTotal > 0
          ? Math.round((casamentoItensCobertos / casamentoItensTotal) * 100)
          : 0,
    },
    {
      id: 'demo-proj-feira',
      nome: 'Tech SP 2026',
      cliente: 'Tech SP',
      data_inicio: '2026-06-18',
      data_fim: '2026-06-20',
      local: 'Expo Center Norte',
      status: 'PLANEJAMENTO',
      notas: 'Projeto demo com conflito de iluminação.',
      packing: [
        {
          ...packingLine('demo-pack-feira-beam', 'demo-item-beam-7r', 4, []),
          status: 'conflict',
          conflicts_with: [
            {
              projeto_id: 'demo-proj-casamento',
              projeto_nome: 'Casamento Santos & Oliveira',
              data_inicio: '2026-06-12',
              data_fim: '2026-06-13',
              status: 'CONFIRMADO',
              qtd_necessaria: 6,
              qtd_alocada: 2,
            },
          ],
        },
      ],
      itens_count: 1,
      itens_total: 4,
      itens_alocados: 0,
      readiness_pct: 0,
    },
  ]
  return { projetos }
}

export function loadDemoProjectById(id: string): ProjectDetail | null {
  const isReturnDemo = id === 'demo-proj-retorno'
  const project = loadDemoProjects().projetos.find((projeto) =>
    isReturnDemo ? projeto.id === 'demo-proj-casamento' : projeto.id === id,
  )
  if (!project) return null
  const projectStatus = isReturnDemo ? 'EM_CAMPO' : project.status
  const packing: ProjectPackingLine[] = project.packing.map((line) => {
    const allocated = demoSerials.filter((serialRow) => {
      if (line.id === 'demo-pack-beam')
        return ['demo-serial-beam-03', 'demo-serial-beam-04'].includes(serialRow.id)
      if (line.id === 'demo-pack-audio') return serialRow.id === 'demo-serial-aud-03'
      if (line.id === 'demo-pack-regua') return serialRow.id === 'demo-serial-regua-01'
      return false
    })
    const alugueisAvulsos = demoExternalRentals(line.id)
    const coverage = computePackingCoverage({
      qtdNecessaria: line.qtd_necessaria,
      qtdPropria: allocated.length,
      alugueisAvulsos,
    })
    return {
      id: line.id,
      item_id: line.item_id,
      codigo_interno: line.codigo_interno,
      item_nome: line.nome,
      categoria: line.categoria,
      notas: null,
      qtd_necessaria: line.qtd_necessaria,
      qtd_alocada: coverage.qtd_propria,
      qtd_alugada_avulsa: coverage.qtd_alugada_avulsa,
      qtd_coberta: coverage.qtd_coberta,
      qtd_faltante: coverage.qtd_faltante,
      status: line.conflicts_with?.length ? 'conflict' : coverage.status,
      seriais_alocados: allocated.map((serialRow) => ({
        id: serialRow.id,
        codigo_interno: serialRow.codigo_interno,
        status: isReturnDemo ? 'EM_CAMPO' : serialRow.status,
        estado: serialRow.estado,
        desgaste: serialRow.desgaste,
      })),
      alugueis_avulsos: alugueisAvulsos,
      conflicts_with: line.conflicts_with,
    }
  })
  const itensTotal = packing.reduce((acc, line) => acc + line.qtd_necessaria, 0)
  const itensCobertos = packing.reduce((acc, line) => acc + line.qtd_coberta, 0)
  const fichaEvento = demoFicha(project.id)
  const fichaReadiness = fichaEvento
    ? {
        ...calculateFichaRecordCompleteness(fichaEvento),
        ...calculateFichaChecklist(fichaEvento),
      }
    : null
  const checkoutGate = buildCheckoutGate({
    status: projectStatus,
    ficha: fichaReadiness,
    packing,
  })
  return {
    id,
    nome: project.nome,
    cliente: project.cliente,
    data_inicio: project.data_inicio,
    data_fim: project.data_fim,
    local: project.local,
    status: projectStatus,
    notas: project.notas,
    comercial: demoComercial(project.id),
    ficha_evento: fichaEvento,
    ficha_readiness: fichaReadiness,
    checkout_gate: checkoutGate,
    packing,
    retorno_pendencias: [],
    itens_total: itensTotal,
    itens_alocados: itensCobertos,
    readiness_pct: checkoutGate.readinessPct,
  }
}

export function loadDemoMovimentacoesByProject(id: string): MovimentacaoTimeline[] {
  return demoMovimentacoes.filter((mov) => mov.projeto_id === id)
}

export function loadDemoLotes(): LotesData {
  return {
    lotes: demoLotes,
    banner: {
      total: demoLotes.length,
      disponivel: demoLotes.filter((lote) => lote.status === 'DISPONIVEL').length,
      em_campo: demoLotes.filter((lote) => lote.status === 'EM_CAMPO').length,
      manutencao: demoLotes.filter((lote) => lote.status === 'MANUTENCAO').length,
      unidades_totais: demoLotes.reduce((acc, lote) => acc + lote.quantidade, 0),
    },
  }
}

export function getDemoLoteById(id: string): LoteRow | null {
  return demoLotes.find((lote) => lote.id === id) ?? null
}

export function getDemoRelatedLotes(itemId: string, excludeLoteId: string): LoteRow[] {
  return demoLotes.filter((lote) => lote.item_id === itemId && lote.id !== excludeLoteId)
}

export function loadDemoQrSources(): QrSources {
  const legacyState = toUnitOnlyQrLoteState(
    demoLotes.map((lote) => ({
      id: lote.id,
      codigo_lote: lote.codigo_lote,
      quantidade: lote.quantidade,
      status: lote.status,
      item_id: lote.item_id,
      item_nome: lote.item_nome,
      item_categoria: lote.item_categoria,
      item_subcategoria: lote.item_subcategoria,
    })),
  )

  return {
    units: loadDemoUnits().map((unit) => ({
      id: unit.id,
      codigo_interno: unit.codigo_interno,
      serial_fabrica: unit.serial_fabrica,
      tag_rfid: unit.tag_rfid,
      rfid_pending: unit.item_categoria === 'CABO' && !unit.tag_rfid?.trim(),
      status: unit.status,
      item_id: unit.item_id,
      item_nome: unit.item_nome,
      item_categoria: unit.item_categoria,
      item_subcategoria: unit.item_subcategoria,
    })),
    lotes: legacyState.operational_lotes,
    legacy_lotes: legacyState.legacy_lotes,
    legacy_cable_lotes: legacyState.legacy_cable_lotes,
  }
}

export function loadDemoRfid(): RfidData {
  const scans: RfidScan[] = [
    {
      id: 'demo-scan-001',
      tag_rfid: 'E280-MMD-000003',
      timestamp: '2026-06-09T14:46:00.000Z',
      operador: 'Marco',
      contexto: 'CARREGAMENTO',
      localizacao: 'Galpão MMD',
      rssi: -48,
      notas: 'Lido no portal de saída',
      reader_id: 'demo-reader-01',
      reader_nome: 'RFD40 iPhone Marco',
      serial_id: 'demo-serial-beam-03',
      serial_codigo: 'MMD-ILU-0003',
      serial_status: 'PACKED',
      lote_id: null,
      lote_codigo: null,
      lote_status: null,
      projeto_id: 'demo-proj-casamento',
      projeto_nome: 'Casamento Santos & Oliveira',
      item_id: 'demo-item-beam-7r',
      item_nome: 'Moving Beam 7R 230W',
      item_categoria: 'ILUMINACAO',
      reconhecido: true,
    },
    {
      id: 'demo-scan-002',
      tag_rfid: 'E280-MMD-999999',
      timestamp: '2026-06-09T14:42:00.000Z',
      operador: 'Marcelo',
      contexto: 'INVENTARIO',
      localizacao: 'Bancada de teste',
      rssi: -71,
      notas: 'Tag ainda não vinculada',
      reader_id: 'demo-reader-01',
      reader_nome: 'RFD40 iPhone Marco',
      serial_id: null,
      serial_codigo: null,
      serial_status: null,
      lote_id: null,
      lote_codigo: null,
      lote_status: null,
      projeto_id: null,
      projeto_nome: null,
      item_id: null,
      item_nome: null,
      item_categoria: null,
      reconhecido: false,
    },
  ]
  return {
    readers: [
      {
        id: 'demo-reader-01',
        nome: 'RFD40 iPhone Marco',
        modelo: 'Zebra RFD40',
        serial_fabrica: 'RFD40-DEMO-001',
        operador: 'Marco',
        status: 'ATIVO',
        bateria: 82,
        ultima_atividade: '2026-06-09T14:46:00.000Z',
        notas: 'Leitor demo. Integração real depende do SDK Zebra.',
      },
    ],
    scans,
    banner: {
      scans_hoje: scans.length,
      scans_24h: scans.length,
      nao_reconhecidos_24h: scans.filter((scan) => !scan.reconhecido).length,
      leitores_ativos: 1,
    },
    cable_rfid: {
      total_units: demoSerials.filter(
        (serialRow) => itemById(serialRow.item_id)?.categoria === 'CABO',
      ).length,
      tags_bound: demoSerials.filter(
        (serialRow) => itemById(serialRow.item_id)?.categoria === 'CABO' && serialRow.tag_rfid,
      ).length,
      tags_pending: demoSerials.filter(
        (serialRow) => itemById(serialRow.item_id)?.categoria === 'CABO' && !serialRow.tag_rfid,
      ).length,
      legacy_lotes: demoLotes.filter((lote) => lote.item_categoria === 'CABO').length,
    },
  }
}

export function searchDemoItems(query: string) {
  const q = query.trim().toLowerCase()
  return demoItems
    .filter((item) => {
      if (!q) return true
      return item.nome.toLowerCase().includes(q) || item.codigo_interno.toLowerCase().includes(q)
    })
    .slice(0, 12)
    .map((item) => ({
      id: item.id,
      codigo_interno: item.codigo_interno,
      nome: item.nome,
      categoria: item.categoria,
      quantidade_total: item.quantidade_total,
    }))
}

export function findDemoPublicCode(code: string) {
  const normalized = decodeURIComponent(code).trim()
  const unit = demoSerials.find(
    (serialRow) =>
      serialRow.codigo_interno === normalized ||
      serialRow.qr_code === normalized ||
      serialRow.tag_rfid === normalized,
  )
  if (unit) {
    const item = itemById(unit.item_id)
    return {
      kind: 'serial' as const,
      row: {
        id: unit.id,
        codigo_interno: unit.codigo_interno,
        serial_fabrica: unit.serial_fabrica,
        qr_code: unit.qr_code,
        tag_rfid: unit.tag_rfid,
        status: unit.status,
        estado: unit.estado,
        desgaste: unit.desgaste,
        valor_atual: unit.valor_atual,
        localizacao: unit.localizacao,
        item: item
          ? {
              nome: item.nome,
              categoria: item.categoria,
              subcategoria: item.subcategoria,
              marca: item.marca,
              modelo: item.modelo,
            }
          : null,
      },
    }
  }
  const lote = demoLotes.find(
    (row) =>
      row.codigo_lote === normalized || row.qr_code === normalized || row.tag_rfid === normalized,
  )
  if (!lote) return null
  return {
    kind: 'lote' as const,
    row: {
      id: lote.id,
      codigo_lote: lote.codigo_lote,
      descricao: lote.descricao ?? '',
      quantidade: lote.quantidade,
      qr_code: lote.qr_code,
      tag_rfid: lote.tag_rfid,
      status: lote.status,
      item: {
        nome: lote.item_nome,
        categoria: lote.item_categoria,
        subcategoria: lote.item_subcategoria,
        marca: lote.item_marca,
        modelo: null,
      },
    },
  }
}
