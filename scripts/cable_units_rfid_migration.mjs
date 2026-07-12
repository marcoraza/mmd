#!/usr/bin/env node

import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const ROOT = resolve(import.meta.dirname, '..')
const ENV_PATH = resolve(ROOT, 'apps/web/.env.local')
const DEFAULT_ORIGIN = 'https://mmd-zeta.vercel.app'

function loadEnvFile(path) {
  try {
    const text = readFileSync(path, 'utf8')
    for (const line of text.split(/\r?\n/)) {
      const trimmed = line.trim()
      if (!trimmed || trimmed.startsWith('#')) continue
      const eq = trimmed.indexOf('=')
      if (eq === -1) continue
      const key = trimmed.slice(0, eq).trim()
      const raw = trimmed.slice(eq + 1).trim()
      if (process.env[key]) continue
      process.env[key] = raw.replace(/^["']|["']$/g, '')
    }
  } catch {
    // Env vars may already be present in CI or Vercel shell.
  }
}

function parseArgs(argv) {
  const out = {
    apply: false,
    confirm: false,
    limit: null,
    json: false,
    origin: process.env.MMD_PUBLIC_BASE_URL ?? DEFAULT_ORIGIN,
    allowDivergence: false,
    pilot30: false,
  }

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]
    if (arg === '--apply') out.apply = true
    else if (arg === '--confirm-cable-unit-migration') out.confirm = true
    else if (arg === '--json') out.json = true
    else if (arg === '--limit') out.limit = Number(argv[++i])
    else if (arg === '--origin') out.origin = argv[++i]
    else if (arg === '--allow-divergence') out.allowDivergence = true
    else if (arg === '--pilot-30') out.pilot30 = true
    else if (arg === '--help' || arg === '-h') {
      printHelp()
      process.exit(0)
    } else {
      throw new Error(`Argumento desconhecido: ${arg}`)
    }
  }

  if (out.limit !== null && (!Number.isInteger(out.limit) || out.limit <= 0)) {
    throw new Error('--limit precisa ser um inteiro positivo.')
  }
  if (out.limit !== null && out.pilot30) {
    throw new Error('Use --limit ou --pilot-30, não os dois ao mesmo tempo.')
  }
  return out
}

function printHelp() {
  console.log(`Uso:
  node scripts/cable_units_rfid_migration.mjs
  node scripts/cable_units_rfid_migration.mjs --json
  node scripts/cable_units_rfid_migration.mjs --apply --confirm-cable-unit-migration

Padrão: dry-run. Nenhuma escrita é feita.
--apply exige --confirm-cable-unit-migration.
--limit N aplica só as N primeiras unidades planejadas, útil para piloto físico.
--pilot-30 aplica 30 unidades distribuídas entre XLR, HDMI, DMX, AC, P10 e USB.
--allow-divergence permite aplicar mesmo com divergência entre lotes e catálogo.
--origin URL define o prefixo do QR Code. Default: ${DEFAULT_ORIGIN}`)
}

loadEnvFile(ENV_PATH)
const args = parseArgs(process.argv.slice(2))

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error('Faltam NEXT_PUBLIC_SUPABASE_URL/SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY.')
}

if (args.apply && !args.confirm) {
  throw new Error('--apply exige --confirm-cable-unit-migration.')
}

async function rest(path, init = {}) {
  const url = `${supabaseUrl.replace(/\/$/, '')}/rest/v1/${path}`
  const res = await fetch(url, {
    ...init,
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
      'content-type': 'application/json',
      ...(init.headers ?? {}),
    },
  })

  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(`${res.status} ${res.statusText}: ${text}`)
  }

  if (res.status === 204) return null
  const text = await res.text()
  return text ? JSON.parse(text) : null
}

function qs(params) {
  return new URLSearchParams(params).toString()
}

function groupBy(rows, key) {
  const map = new Map()
  for (const row of rows) {
    const value = row[key]
    const arr = map.get(value) ?? []
    arr.push(row)
    map.set(value, arr)
  }
  return map
}

function statusFromLote(status) {
  if (status === 'EM_CAMPO') return 'EM_CAMPO'
  if (status === 'MANUTENCAO') return 'MANUTENCAO'
  return 'DISPONIVEL'
}

function nextSeq(existingCodes, baseCode) {
  let max = 0
  const prefix = `${baseCode}-`
  for (const code of existingCodes) {
    if (!code.startsWith(prefix)) continue
    const suffix = Number(code.slice(prefix.length))
    if (Number.isInteger(suffix) && suffix > max) max = suffix
  }
  return max + 1
}

function unitCode(baseCode, seq) {
  return `${baseCode}-${String(seq).padStart(3, '0')}`
}

function currentValue(item) {
  const original = Number(item.valor_mercado_unitario ?? 0)
  if (!original) return null
  return Number((original * 0.65 * (3 / 5)).toFixed(2))
}

function normalizeText(text) {
  return String(text ?? '')
    .toUpperCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^A-Z0-9]+/g, ' ')
    .trim()
}

function inferCableItemCode(lote) {
  const currentCode = lote.items?.codigo_interno ?? null
  if (currentCode && currentCode !== 'MMD-CAB-0001') {
    return { codigo: currentCode, confidence: 'EXATO', reason: 'lote já aponta para tipo específico' }
  }

  const desc = normalizeText(lote.descricao)
  if (!desc || /^LOTE [0-9]+X?$/.test(desc)) {
    return { codigo: 'MMD-CAB-0017', confidence: 'REVISAR', reason: 'descrição genérica' }
  }

  const rules = [
    ['MMD-CAB-0007', 'DMX'],
    ['MMD-CAB-0019', 'SPEAK'],
    ['MMD-CAB-0011', 'MIDI'],
    ['MMD-CAB-0002', 'HDMI'],
    ['MMD-CAB-0013', 'MINI DISPLAY'],
    ['MMD-CAB-0013', 'MINI DPPORT'],
    ['MMD-CAB-0003', 'DISPLAY PORT'],
    ['MMD-CAB-0003', 'DPPORT'],
    ['MMD-CAB-0003', 'DVI'],
    ['MMD-CAB-0003', 'VGA'],
    ['MMD-CAB-0018', 'USB'],
    ['MMD-CAB-0005', 'RCA P10'],
    ['MMD-CAB-0014', 'XLR P2'],
    ['MMD-CAB-0020', 'P10 P2'],
    ['MMD-CAB-0012', 'XLRM P10'],
    ['MMD-CAB-0006', 'P10 XLR'],
    ['MMD-CAB-0016', 'XLR P10'],
    ['MMD-CAB-0004', 'RCA'],
    ['MMD-CAB-0008', 'P2'],
    ['MMD-CAB-0010', 'XLR'],
    ['MMD-CAB-0015', 'P10'],
    ['MMD-CAB-0009', 'AC'],
    ['MMD-CAB-0009', 'EXTENSAO'],
    ['MMD-CAB-0009', 'POWERCON'],
    ['MMD-CAB-0009', 'PARALELO'],
  ]

  for (const [codigo, token] of rules) {
    if (desc.includes(token)) {
      return { codigo, confidence: 'INFERIDO', reason: token }
    }
  }

  return { codigo: 'MMD-CAB-0017', confidence: 'REVISAR', reason: 'sem regra específica' }
}

async function loadCurrentState() {
  const items = await rest(
    `items?${qs({
      select:
        'id,codigo_interno,nome,categoria,subcategoria,tipo_rastreamento,quantidade_total,valor_mercado_unitario',
      categoria: 'eq.CABO',
      order: 'codigo_interno.asc',
    })}`,
  )

  const itemIds = items.map((item) => item.id)
  if (itemIds.length === 0) return { items, lotes: [], serials: [] }

  const quotedIds = itemIds.map((id) => `"${id}"`).join(',')
  const [lotes, serials] = await Promise.all([
    rest(
      `lotes?${qs({
        select: 'id,item_id,codigo_lote,descricao,quantidade,status,tag_rfid,qr_code,items(codigo_interno,nome)',
        item_id: `in.(${quotedIds})`,
        order: 'codigo_lote.asc',
      })}`,
    ),
    rest(
      `serial_numbers?${qs({
        select: 'id,item_id,codigo_interno,tag_rfid,status',
        item_id: `in.(${quotedIds})`,
        order: 'codigo_interno.asc',
      })}`,
    ),
  ])

  return { items, lotes, serials }
}

function buildPlan(state) {
  const itemByCode = new Map(state.items.map((item) => [item.codigo_interno, item]))
  const serialsByItem = groupBy(state.serials, 'item_id')
  const mappedLotes = []
  const unassignedLotes = []

  for (const lote of state.lotes) {
    const inferred = inferCableItemCode(lote)
    const targetItem = itemByCode.get(inferred.codigo)
    if (!targetItem) {
      unassignedLotes.push({ ...lote, target_codigo: inferred.codigo, reason: inferred.reason })
      continue
    }
    mappedLotes.push({
      ...lote,
      target_item_id: targetItem.id,
      target_codigo: targetItem.codigo_interno,
      target_nome: targetItem.nome,
      target_confidence: inferred.confidence,
      target_reason: inferred.reason,
    })
  }

  const lotesByTargetItem = groupBy(mappedLotes, 'target_item_id')
  const units = []
  const byItem = []
  const reviewLotes = []

  for (const item of state.items) {
    const itemLotes = lotesByTargetItem.get(item.id) ?? []
    const itemSerials = serialsByItem.get(item.id) ?? []
    const existingCodes = itemSerials.map((serial) => serial.codigo_interno)
    let seq = nextSeq(existingCodes, item.codigo_interno)
    let planned = 0

    for (const lote of itemLotes) {
      if (lote.target_confidence === 'REVISAR') reviewLotes.push(lote)
      for (let index = 0; index < lote.quantidade; index++) {
        const code = unitCode(item.codigo_interno, seq++)
        units.push({
          item_id: item.id,
          codigo_interno: code,
          serial_fabrica: null,
          tag_rfid: null,
          qr_code: `${args.origin.replace(/\/$/, '')}/s/${encodeURIComponent(code)}`,
          status: statusFromLote(lote.status),
          estado: 'USADO',
          desgaste: 3,
          depreciacao_pct: null,
          valor_atual: currentValue(item),
          localizacao: lote.status === 'EM_CAMPO' ? 'Evento em campo' : 'Galpão MMD',
          notas: `Criado a partir do lote legado ${lote.codigo_lote}. RFID físico pendente.`,
          source_lote_id: lote.id,
          source_lote_codigo: lote.codigo_lote,
          source_lote_descricao: lote.descricao,
          source_item_id: lote.item_id,
          target_confidence: lote.target_confidence,
          target_reason: lote.target_reason,
        })
        planned++
      }
    }

    const loteQty = itemLotes.reduce((acc, lote) => acc + lote.quantidade, 0)
    byItem.push({
      item_id: item.id,
      codigo_interno: item.codigo_interno,
      nome: item.nome,
      tipo_rastreamento: item.tipo_rastreamento,
      quantidade_total: item.quantidade_total,
      lotes: itemLotes.length,
      unidades_em_lotes: loteQty,
      serials_existentes: itemSerials.length,
      unidades_planejadas: planned,
      divergencia_catalogo_vs_lotes: loteQty - item.quantidade_total,
      revisar_lotes: itemLotes.filter((lote) => lote.target_confidence === 'REVISAR').length,
    })
  }

  const divergences = byItem.filter((row) => row.divergencia_catalogo_vs_lotes !== 0)
  return { units, byItem, mappedLotes, reviewLotes, unassignedLotes, divergences }
}

function unitsForApply(plan) {
  if (args.pilot30) {
    const pilotCodes = [
      'MMD-CAB-0010',
      'MMD-CAB-0002',
      'MMD-CAB-0007',
      'MMD-CAB-0009',
      'MMD-CAB-0015',
      'MMD-CAB-0018',
    ]
    const out = []
    for (const code of pilotCodes) {
      out.push(...plan.units.filter((unit) => unit.codigo_interno.startsWith(`${code}-`)).slice(0, 5))
    }
    return out.slice(0, 30)
  }
  return args.limit ? plan.units.slice(0, args.limit) : plan.units
}

async function applyPlan(state, plan) {
  if (state.serials.length > 0) {
    throw new Error(
      `Já existem ${state.serials.length} seriais de cabo. Apply bloqueado para evitar duplicidade.`,
    )
  }

  const hasSafetyBlock =
    plan.divergences.length > 0 || plan.reviewLotes.length > 0 || plan.unassignedLotes.length > 0
  if (hasSafetyBlock && !args.allowDivergence) {
    throw new Error(
      'Dry-run tem divergências ou lotes para revisar. Rode sem --apply, valide com Marcelo e use --allow-divergence só depois da aprovação.',
    )
  }

  const units = unitsForApply(plan)
  const insertRows = units.map(
    ({
      source_lote_id,
      source_lote_codigo,
      source_lote_descricao,
      source_item_id,
      target_confidence,
      target_reason,
      ...row
    }) => row,
  )

  if (insertRows.length > 0) {
    await rest('serial_numbers', {
      method: 'POST',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify(insertRows),
    })
  }

  const plannedByItemId = new Map(plan.byItem.map((row) => [row.item_id, row]))

  for (const item of state.items) {
    const planned = plannedByItemId.get(item.id)
    await rest(`items?id=eq.${encodeURIComponent(item.id)}`, {
      method: 'PATCH',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({
        tipo_rastreamento: 'INDIVIDUAL',
        quantidade_total: planned?.unidades_planejadas ?? item.quantidade_total,
      }),
    })
  }

  await rest('items?codigo_interno=eq.MMD-ENE-0019', {
    method: 'PATCH',
    headers: { Prefer: 'return=minimal' },
    body: JSON.stringify({
      tipo_rastreamento: 'INDIVIDUAL',
      quantidade_total: 0,
      notas:
        'Consolidado em MMD-CAB-0009 na migração de cabos por unidade com RFID. Mantido como histórico.',
    }),
  })

  return {
    inserted: insertRows.length,
    updatedItems: state.items.length + 1,
  }
}

function printHuman(state, plan) {
  const totalCatalog = state.items.reduce((acc, item) => acc + item.quantidade_total, 0)
  const totalLotes = state.lotes.reduce((acc, lote) => acc + lote.quantidade, 0)
  const totalExistingSerials = state.serials.length

  console.log('Cabos por unidade com RFID - dry-run')
  console.log(`Tipos de cabo: ${state.items.length}`)
  console.log(`Quantidade no catálogo: ${totalCatalog}`)
  console.log(`Unidades em lotes legados: ${totalLotes}`)
  console.log(`Seriais de cabo existentes: ${totalExistingSerials}`)
  console.log(`Unidades que seriam criadas: ${plan.units.length}`)
  console.log(`Divergência lotes - catálogo: ${totalLotes - totalCatalog}`)
  console.log(`Lotes mapeados por texto: ${plan.mappedLotes.length}`)
  console.log(`Lotes para revisar: ${plan.reviewLotes.length}`)
  console.log(`Lotes sem destino: ${plan.unassignedLotes.length}`)
  console.log('')
  console.log('Por tipo:')
  for (const row of plan.byItem) {
    const markers = []
    if (row.divergencia_catalogo_vs_lotes !== 0) markers.push('divergência')
    if (row.revisar_lotes > 0) markers.push(`${row.revisar_lotes} lote(s) revisar`)
    const marker = markers.length === 0 ? '' : `  <- ${markers.join(', ')}`
    console.log(
      `${row.codigo_interno} | ${row.nome || '(sem nome)'} | catálogo ${row.quantidade_total} | lotes ${row.unidades_em_lotes} | criar ${row.unidades_planejadas}${marker}`,
    )
  }

  if (plan.reviewLotes.length > 0) {
    console.log('')
    console.log('Lotes que precisam de revisão antes da migração completa:')
    for (const lote of plan.reviewLotes.slice(0, 20)) {
      console.log(
        `${lote.codigo_lote} | ${lote.quantidade} un | ${lote.descricao || '(sem descrição)'} -> ${lote.target_codigo}`,
      )
    }
  }

  console.log('')
  console.log('Primeiras unidades planejadas:')
  for (const unit of plan.units.slice(0, 12)) {
    console.log(`${unit.codigo_interno} <- ${unit.source_lote_codigo} | ${unit.status}`)
  }
  console.log('')
  console.log('Nenhuma escrita foi feita.')
  console.log(
    'Para aplicar piloto aprovado: --apply --confirm-cable-unit-migration --pilot-30 --allow-divergence',
  )
}

const state = await loadCurrentState()
const plan = buildPlan(state)

if (args.apply) {
  const result = await applyPlan(state, plan)
  console.log(JSON.stringify({ mode: 'apply', ...result }, null, 2))
} else if (args.json) {
  console.log(
    JSON.stringify(
      {
        mode: 'dry-run',
        summary: plan.byItem,
        review_lotes: plan.reviewLotes,
        unassigned_lotes: plan.unassignedLotes,
        planned_units: plan.units,
      },
      null,
      2,
    ),
  )
} else {
  printHuman(state, plan)
}
