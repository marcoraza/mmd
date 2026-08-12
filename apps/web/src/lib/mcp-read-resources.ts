import { z } from 'zod'

export const MCP_DOMAIN_READ_TARGETS = {
  eventos: 'mmd:eventos:list',
  catalogo: 'mmd:catalogo:list',
  packing: 'mmd:packing:read',
  movimentacoes: 'mmd:movimentacoes:list',
  conferencias: 'mmd:conferencias:read',
  retornoEsperado: 'mmd:retorno-esperado:read',
  pendencias: 'mmd:pendencias:list',
} as const

export type McpDomainReadTarget =
  (typeof MCP_DOMAIN_READ_TARGETS)[keyof typeof MCP_DOMAIN_READ_TARGETS]

const PAGE = z.coerce.number().int().min(1).default(1)
const PAGE_SIZE = z.coerce.number().int().min(1).max(50).default(50)
const UUID = z.string().uuid()

const PAGE_ENVELOPE = {
  page: z.number().int().min(1),
  page_size: z.number().int().min(1).max(50),
}
const EVENT_SUMMARY = z
  .object({
    id: UUID,
    nome: z.string(),
    status: z.string(),
    data_inicio: z.string().nullable(),
    data_fim: z.string().nullable(),
    local: z.string().nullable(),
    packing: z
      .object({
        linhas: z.number().int().nonnegative(),
        itens_total: z.number().int().nonnegative(),
        itens_alocados: z.number().int().nonnegative(),
        readiness_pct: z.number().int().min(0).max(100),
      })
      .strict(),
  })
  .strict()

const OUTPUT_SCHEMAS: Record<McpDomainReadTarget, z.ZodType> = {
  [MCP_DOMAIN_READ_TARGETS.eventos]: z
    .object({ items: z.array(EVENT_SUMMARY), ...PAGE_ENVELOPE })
    .strict(),
  [MCP_DOMAIN_READ_TARGETS.catalogo]: z
    .object({
      items: z.array(
        z
          .object({
            id: UUID,
            nome: z.string(),
            categoria: z.string(),
            quantidade_total: z.number().int().nonnegative(),
            unidades: z
              .object({
                disponiveis: z.number().int().nonnegative(),
                em_campo: z.number().int().nonnegative(),
                retornando: z.number().int().nonnegative(),
                manutencao: z.number().int().nonnegative(),
              })
              .strict(),
          })
          .strict(),
      ),
      ...PAGE_ENVELOPE,
    })
    .strict(),
  [MCP_DOMAIN_READ_TARGETS.packing]: z
    .object({
      items: z.array(
        z
          .object({
            id: UUID,
            item: z.object({ id: UUID, nome: z.string(), categoria: z.string() }).strict(),
            quantidade: z.number().int().nonnegative(),
            qtd_propria: z.number().int().nonnegative(),
            alugueis_avulsos: z.number().int().nonnegative(),
            qtd_coberta: z.number().int().nonnegative(),
            qtd_faltante: z.number().int().nonnegative(),
          })
          .strict(),
      ),
      ...PAGE_ENVELOPE,
    })
    .strict(),
  [MCP_DOMAIN_READ_TARGETS.movimentacoes]: z
    .object({
      items: z.array(
        z
          .object({
            id: UUID,
            unidade: z.object({ id: UUID, codigo_interno: z.string() }).strict(),
            tipo: z.string(),
            status_anterior: z.string().nullable(),
            status_novo: z.string(),
            metodo: z.string(),
            timestamp: z.string(),
          })
          .strict(),
      ),
      ...PAGE_ENVELOPE,
    })
    .strict(),
  [MCP_DOMAIN_READ_TARGETS.conferencias]: z
    .object({
      id: UUID,
      direcao: z.enum(['SAIDA', 'RETORNO']),
      version: z.number().int().nonnegative(),
      updated_at: z.string(),
      decisoes: z.array(
        z
          .object({
            id: UUID,
            unidade: z.object({ id: UUID, codigo_interno: z.string() }).strict(),
            resultado: z.string(),
            metodo: z.string(),
            captured_at: z.string(),
            resolution: z.string().nullable(),
            applied: z.boolean(),
          })
          .strict(),
      ),
      recibos: z.array(
        z
          .object({
            id: UUID,
            confirmed_at: z.string(),
            incomplete_reason: z.string().nullable(),
            applied_count: z.number().int().nonnegative(),
          })
          .strict(),
      ),
      ...PAGE_ENVELOPE,
    })
    .strict()
    .nullable(),
  [MCP_DOMAIN_READ_TARGETS.retornoEsperado]: z
    .object({
      items: z.array(
        z
          .object({
            unidade: z.object({ id: UUID, codigo_interno: z.string() }).strict(),
            saida_confirmation_id: UUID,
            saida_confirmed_at: z.string(),
          })
          .strict(),
      ),
      ...PAGE_ENVELOPE,
    })
    .strict(),
  [MCP_DOMAIN_READ_TARGETS.pendencias]: z
    .object({
      items: z.array(
        z
          .object({
            id: UUID,
            unidade: z
              .object({ id: UUID, codigo_interno: z.string(), status: z.string() })
              .strict(),
            status: z.string(),
            observacao: z.string().nullable(),
            localizacao_confirmada: z.string().nullable(),
            created_at: z.string(),
            resolved_at: z.string().nullable(),
          })
          .strict(),
      ),
      ...PAGE_ENVELOPE,
    })
    .strict(),
}

const PAGED_EVENT = z
  .object({ evento_id: UUID, page: PAGE, page_size: PAGE_SIZE })
  .strict()

export const MCP_DOMAIN_RESOURCE_DEFINITIONS = [
  {
    name: 'eventos',
    target: MCP_DOMAIN_READ_TARGETS.eventos,
    uriTemplate: 'mmd://eventos/pagina/{page}/tamanho/{page_size}',
    title: 'Eventos MMD',
    description: 'Coleção paginada de Eventos e prontidão do packing.',
  },
  {
    name: 'catalogo',
    target: MCP_DOMAIN_READ_TARGETS.catalogo,
    uriTemplate: 'mmd://catalogo/pagina/{page}/tamanho/{page_size}',
    title: 'Catálogo MMD',
    description: 'Itens do catálogo e quantidades operacionais agregadas.',
  },
  {
    name: 'packing',
    target: MCP_DOMAIN_READ_TARGETS.packing,
    uriTemplate: 'mmd://eventos/{evento_id}/packing/pagina/{page}/tamanho/{page_size}',
    title: 'Packing do Evento',
    description: 'Cobertura allowlisted do packing de um Evento.',
  },
  {
    name: 'conferencias',
    target: MCP_DOMAIN_READ_TARGETS.conferencias,
    uriTemplate:
      'mmd://eventos/{evento_id}/conferencias/{direcao}/pagina/{page}/tamanho/{page_size}',
    title: 'Conferências do Evento',
    description: 'Decisões e recibos allowlisted das Conferências físicas.',
  },
  {
    name: 'movimentacoes',
    target: MCP_DOMAIN_READ_TARGETS.movimentacoes,
    uriTemplate: 'mmd://eventos/{evento_id}/movimentacoes/pagina/{page}/tamanho/{page_size}',
    title: 'Movimentações do Evento',
    description: 'Histórico paginado de movimentos físicos do Evento.',
  },
  {
    name: 'retorno-esperado',
    target: MCP_DOMAIN_READ_TARGETS.retornoEsperado,
    uriTemplate: 'mmd://eventos/{evento_id}/retorno-esperado/pagina/{page}/tamanho/{page_size}',
    title: 'Retorno esperado do Evento',
    description: 'Unidades com saída confirmada que compõem o retorno esperado.',
  },
  {
    name: 'pendencias',
    target: MCP_DOMAIN_READ_TARGETS.pendencias,
    uriTemplate: 'mmd://eventos/{evento_id}/pendencias/pagina/{page}/tamanho/{page_size}',
    title: 'Pendências de retorno do Evento',
    description: 'Pendências de retorno sem identidade de operadores.',
  },
] as const

export function parseMcpDomainResourceArguments(target: McpDomainReadTarget, uri: URL) {
  const path = uri.pathname.split('/').filter(Boolean)
  if (target === MCP_DOMAIN_READ_TARGETS.eventos) {
    return z
      .object({
        page: PAGE,
        page_size: PAGE_SIZE,
      })
      .strict()
      .parse({ page: path[1], page_size: path[3] })
  }
  if (target === MCP_DOMAIN_READ_TARGETS.catalogo) {
    return z
      .object({ page: PAGE, page_size: PAGE_SIZE })
      .strict()
      .parse({ page: path[1], page_size: path[3] })
  }

  if (target === MCP_DOMAIN_READ_TARGETS.conferencias) {
    return PAGED_EVENT.extend({ direcao: z.enum(['SAIDA', 'RETORNO']) }).parse({
      evento_id: path[0],
      direcao: path[2],
      page: path[4],
      page_size: path[6],
    })
  }
  return PAGED_EVENT.parse({ evento_id: path[0], page: path[3], page_size: path[5] })
}

export function parseMcpDomainResourceOutput(target: McpDomainReadTarget, value: unknown) {
  return OUTPUT_SCHEMAS[target].parse(value)
}
