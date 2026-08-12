import 'server-only'

import postgres from 'postgres'

import { computePackingCoverage, parseExternalRentalCoverages } from '@/lib/external-rental-core'
import {
  issueMcpDomainReadCapability,
  issueMcpOperationCapability,
  issueMcpReadCapability,
} from '@/lib/mcp-auth'
import { mcpDatabaseConfiguration } from '@/lib/mcp-data-core'
import type {
  McpEvent,
  McpIdentity,
  McpMutationAck,
  McpMutationTool,
  McpUnit,
} from '@/lib/mcp-core'
import { MCP_DOMAIN_READ_TARGETS, type McpDomainReadTarget } from '@/lib/mcp-read-resources'

const clients = new Map<string, ReturnType<typeof postgres>>()

type MutationEnvelope = {
  ok?: unknown
  operation_id?: unknown
  result?: unknown
  error_code?: unknown
}

function mutationAck(tool: McpMutationTool, envelope: MutationEnvelope): McpMutationAck {
  const operationId = typeof envelope.operation_id === 'string' ? envelope.operation_id : null
  if (!operationId) throw new Error('MCP_OPERATION_RESULT_INVALID')
  if (envelope.ok !== true) {
    return {
      operation_id: operationId,
      status: 'FAILED' as const,
      error_code: typeof envelope.error_code === 'string' ? envelope.error_code : 'MCP_FAILED',
    }
  }

  const result =
    envelope.result && typeof envelope.result === 'object'
      ? (envelope.result as Record<string, unknown>)
      : {}
  const domainReceiptId = [
    result.confirmation_id,
    result.finalization_id,
    result.resolution_id,
    result.operation_id,
    result.decision_id,
  ].find((value): value is string => typeof value === 'string')

  return {
    operation_id: operationId,
    status: 'SUCCEEDED' as const,
    tool,
    domain_receipt_id: domainReceiptId ?? null,
    conference_id: typeof result.conference_id === 'string' ? result.conference_id : null,
    project_id: typeof result.project_id === 'string' ? result.project_id : null,
    version: typeof result.version === 'number' ? result.version : null,
  }
}

function database() {
  const configuration = mcpDatabaseConfiguration()
  if (!configuration) throw new Error('MCP_DATABASE_NOT_CONFIGURED')
  let sql = clients.get(configuration.connectionString)
  if (!sql) {
    sql = postgres(configuration.connectionString, {
      prepare: false,
      max: 5,
      idle_timeout: 20,
      connect_timeout: 5,
      ssl: configuration.local ? false : 'require',
    })
    clients.set(configuration.connectionString, sql)
  }
  return sql
}

export async function readMcpEvent(
  eventoId: string,
  identity: McpIdentity,
): Promise<McpEvent | null> {
  const capability = await issueMcpReadCapability(identity, 'mmd:eventos:read', eventoId)
  const [row] = await database()<
    [
      {
        result: null | {
          id: string
          nome: string
          status: string
          data_inicio: string | null
          data_fim: string | null
          local: string | null
          packing_raw: {
            quantidade: number
            qtd_propria: number
            alugueis_avulsos: unknown
          }[]
        }
      },
    ]
  >`select public.mcp_read_event(
      ${capability.token},
      ${eventoId}::uuid,
      ${capability.payloadHash}
    ) as result`
  if (!row?.result) return null

  const { packing_raw: packing, ...event } = row.result
  const coverage = packing.map((line) =>
    computePackingCoverage({
      qtdNecessaria: line.quantidade,
      qtdPropria: line.qtd_propria,
      alugueisAvulsos: parseExternalRentalCoverages(line.alugueis_avulsos),
    }),
  )
  const itensTotal = packing.reduce((total, line) => total + line.quantidade, 0)
  const itensAlocados = coverage.reduce((total, line) => total + line.qtd_coberta, 0)

  return {
    ...event,
    packing: {
      linhas: packing.length,
      itens_total: itensTotal,
      itens_alocados: itensAlocados,
      readiness_pct: itensTotal ? Math.round((itensAlocados / itensTotal) * 100) : 0,
    },
  }
}

export async function readMcpUnit(
  unidadeId: string,
  identity: McpIdentity,
): Promise<McpUnit | null> {
  const capability = await issueMcpReadCapability(identity, 'mmd:unidades:read', unidadeId)
  const [row] = await database()<[{ result: McpUnit | null }]>`
    select public.mcp_read_unit(
      ${capability.token},
      ${unidadeId}::uuid,
      ${capability.payloadHash}
    ) as result
  `
  return row?.result ?? null
}

export async function readMcpDomain(
  target: McpDomainReadTarget,
  rawArgs: Record<string, unknown>,
  identity: McpIdentity,
) {
  const page = Number(rawArgs.page)
  const pageSize = Number(rawArgs.page_size)
  const eventoId = typeof rawArgs.evento_id === 'string' ? rawArgs.evento_id : null
  const direcao = typeof rawArgs.direcao === 'string' ? rawArgs.direcao : null
  const args =
    target === MCP_DOMAIN_READ_TARGETS.eventos
      ? { status: null, date_from: null, date_to: null, page, page_size: pageSize }
      : target === MCP_DOMAIN_READ_TARGETS.catalogo
        ? { categoria: null, page, page_size: pageSize }
        : target === MCP_DOMAIN_READ_TARGETS.conferencias
          ? { evento_id: eventoId, direcao, page, page_size: pageSize }
          : { evento_id: eventoId, page, page_size: pageSize }
  const capability = await issueMcpDomainReadCapability(identity, target, args)
  const sql = database()

  switch (target) {
    case MCP_DOMAIN_READ_TARGETS.eventos: {
      const [row] = await sql<[{ result: unknown }]>`
        select public.mcp_read_events(
          ${capability}, null, null, null, ${page}, ${pageSize}
        ) as result
      `
      return row?.result
    }
    case MCP_DOMAIN_READ_TARGETS.catalogo: {
      const [row] = await sql<[{ result: unknown }]>`
        select public.mcp_read_catalog(${capability}, null, ${page}, ${pageSize}) as result
      `
      return row?.result
    }
    case MCP_DOMAIN_READ_TARGETS.packing: {
      const [row] = await sql<[{ result: unknown }]>`
        select public.mcp_read_packing(
          ${capability}, ${eventoId}::uuid, ${page}, ${pageSize}
        ) as result
      `
      return row?.result
    }
    case MCP_DOMAIN_READ_TARGETS.movimentacoes: {
      const [row] = await sql<[{ result: unknown }]>`
        select public.mcp_read_movements(
          ${capability}, ${eventoId}::uuid, ${page}, ${pageSize}
        ) as result
      `
      return row?.result
    }
    case MCP_DOMAIN_READ_TARGETS.conferencias: {
      const [row] = await sql<[{ result: unknown }]>`
        select public.mcp_read_conference(
          ${capability}, ${eventoId}::uuid, ${direcao}, ${page}, ${pageSize}
        ) as result
      `
      return row?.result
    }
    case MCP_DOMAIN_READ_TARGETS.retornoEsperado: {
      const [row] = await sql<[{ result: unknown }]>`
        select public.mcp_read_expected_return(
          ${capability}, ${eventoId}::uuid, ${page}, ${pageSize}
        ) as result
      `
      return row?.result
    }
    case MCP_DOMAIN_READ_TARGETS.pendencias: {
      const [row] = await sql<[{ result: unknown }]>`
        select public.mcp_read_return_pendings(
          ${capability}, ${eventoId}::uuid, ${page}, ${pageSize}
        ) as result
      `
      return row?.result
    }
  }
}

export async function executeMcpMutation(
  tool: McpMutationTool,
  args: Record<string, unknown>,
  identity: McpIdentity,
  clientRequestId: string,
) {
  const claim = await issueMcpOperationCapability(identity, tool, clientRequestId, args)
  if (claim.completed) {
    return mutationAck(tool, {
      ok: true,
      operation_id: claim.operationId,
      result: claim.result,
    })
  }

  const sql = database()
  const [row] = await sql<[{ envelope: MutationEnvelope }]>`
    select public.execute_mcp_operation(
      ${claim.token},
      ${sql.json(args as unknown as postgres.JSONValue)}
    ) as envelope
  `
  if (!row?.envelope) throw new Error('MCP_OPERATION_RESULT_MISSING')
  return mutationAck(tool, row.envelope)
}
