import 'server-only'

import postgres from 'postgres'

import { computePackingCoverage, parseExternalRentalCoverages } from '@/lib/external-rental-core'
import { issueMcpReadCapability } from '@/lib/mcp-auth'
import { mcpDatabaseConfiguration } from '@/lib/mcp-data-core'
import type { McpEvent, McpIdentity, McpUnit } from '@/lib/mcp-core'

const clients = new Map<string, ReturnType<typeof postgres>>()

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
