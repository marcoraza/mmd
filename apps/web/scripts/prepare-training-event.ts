import { existsSync, readFileSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import {
  TRAINING_EVENT_CODE,
  buildTrainingEventPlan,
  trainingEventCode,
  type ExistingTrainingEvent,
  type TrainingPackingState,
  type TrainingSerialCandidate,
} from '../src/lib/training-event-core.ts'

type ProjectRow = {
  id: string
  codigo_evento: string | null
  nome: string
  status: string
  notas: string | null
  data_inicio: string
  data_fim: string
}

type PackingRow = {
  id: string
  projeto_id: string
  item_id: string
  quantidade: number
  serial_numbers_designados: string[] | null
  projetos: { id: string; status: string } | null
}

type SerialRow = {
  id: string
  item_id: string
  codigo_interno: string
  tag_rfid: string | null
  status: string
}

type ItemRow = {
  id: string
  codigo_interno: string | null
  nome: string
}

type Args = {
  apply: boolean
  confirm: string | null
  runNumber: number
}

const ACTIVE_PROJECT_STATUSES = new Set(['PLANEJAMENTO', 'CONFIRMADO', 'MONTAGEM', 'EM_CAMPO'])
const __dirname = path.dirname(fileURLToPath(import.meta.url))
loadEnv(path.join(__dirname, '..', '.env.local'))
loadEnv(path.join(__dirname, '..', '.env'))

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error)
    process.exitCode = 1
  })
}

async function main() {
  const args = parseArgs(process.argv.slice(2))
  const eventCode = trainingEventCode(args.runNumber)
  const supabase = createSupabaseClient()
  const existingEvent = await loadExistingEvent(supabase, eventCode)
  const candidates = await loadCandidates(supabase, existingEvent?.id ?? null)
  const plan = buildTrainingEventPlan({
    candidates,
    existingEvent,
    today: new Date().toISOString().slice(0, 10),
    runNumber: args.runNumber,
  })

  if (!args.apply) {
    printResult(plan, args.runNumber, 'probe-read-only', 0)
    if (!plan.ready) process.exitCode = 2
    return
  }

  if (args.confirm !== 'TREINAMENTO-MARCELO') {
    throw new Error('--apply exige --confirm TREINAMENTO-MARCELO e confirmação explícita do Marco no chat.')
  }
  if (!plan.ready) {
    printResult(plan, args.runNumber, 'apply-blocked', 0)
    process.exitCode = 2
    return
  }

  const writesPerformed = await applyPlan(supabase, plan, existingEvent)
  const appliedEvent = await loadExistingEvent(supabase, eventCode)
  const verificationCandidates = await loadCandidates(supabase, appliedEvent?.id ?? null)
  const verification = buildTrainingEventPlan({
    candidates: verificationCandidates,
    existingEvent: appliedEvent,
    today: new Date().toISOString().slice(0, 10),
    runNumber: args.runNumber,
  })
  if (!verification.ready || verification.changes.length > 0) {
    throw new Error('A escrita terminou, mas a verificação idempotente encontrou divergência no estado inicial.')
  }
  printResult(verification, args.runNumber, 'apply-verified', writesPerformed)
}

function parseArgs(argv: string[]): Args {
  let apply = false
  let confirm: string | null = null
  let runNumber = 1

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    if (arg === '--apply') {
      apply = true
      continue
    }
    if (arg === '--confirm' && argv[index + 1]) {
      confirm = argv[index + 1]
      index += 1
      continue
    }
    if (arg === '--run' && argv[index + 1]) {
      runNumber = Number(argv[index + 1])
      index += 1
      continue
    }
    if (arg === '--reset') {
      throw new Error('Reset destrutivo não existe. Use uma nova execução com --run N.')
    }
    throw new Error(`Argumento desconhecido: ${arg}`)
  }
  trainingEventCode(runNumber)
  return { apply, confirm, runNumber }
}

function loadEnv(filePath: string) {
  if (!existsSync(filePath)) return
  const content = readFileSync(filePath, 'utf8')
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue
    const match = trimmed.match(/^([A-Z0-9_]+)=(.*)$/)
    if (!match) continue
    const [, key, rawValue] = match
    if (process.env[key]) continue
    process.env[key] = rawValue.replace(/^['"]|['"]$/g, '')
  }
}

function createSupabaseClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !key) {
    throw new Error('Faltam NEXT_PUBLIC_SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY para o probe read-only.')
  }
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } })
}

async function loadExistingEvent(
  supabase: SupabaseClient,
  eventCode = TRAINING_EVENT_CODE,
): Promise<ExistingTrainingEvent | null> {
  const { data, error } = await supabase
    .from('projetos')
    .select('id, codigo_evento, nome, status, notas, data_inicio, data_fim')
    .eq('codigo_evento', eventCode)
    .maybeSingle()
  if (error) throw new Error(`Falha ao consultar Evento de treino: ${error.message}`)
  if (!data) return null

  const event = data as ProjectRow
  const { data: packing, error: packingError } = await supabase
    .from('packing_list')
    .select('id, item_id, quantidade, serial_numbers_designados')
    .eq('projeto_id', event.id)
  if (packingError) throw new Error(`Falha ao consultar packing de treino: ${packingError.message}`)

  return {
    id: event.id,
    code: event.codigo_evento,
    name: event.nome,
    status: event.status,
    notes: event.notas,
    startDate: event.data_inicio,
    endDate: event.data_fim,
    packing: (packing ?? []).map(
      (row): TrainingPackingState => ({
        id: row.id as string,
        itemId: row.item_id as string,
        quantity: row.quantidade as number,
        serialIds: (row.serial_numbers_designados as string[] | null) ?? [],
      }),
    ),
  }
}

async function loadCandidates(
  supabase: SupabaseClient,
  trainingEventId: string | null,
): Promise<TrainingSerialCandidate[]> {
  const { data: serialData, error: serialError } = await supabase
    .from('serial_numbers')
    .select('id, item_id, codigo_interno, tag_rfid, status')
    .eq('status', 'DISPONIVEL')
  if (serialError) throw new Error(`Falha ao consultar unidades elegíveis: ${serialError.message}`)

  const serials = serialData as unknown as SerialRow[]
  const itemIds = [...new Set(serials.map((serial) => serial.item_id))]
  const { data: itemData, error: itemError } = await supabase
    .from('items')
    .select('id, codigo_interno, nome')
    .in('id', itemIds)
  if (itemError) throw new Error(`Falha ao consultar tipos de item: ${itemError.message}`)
  const items = new Map((itemData as ItemRow[]).map((item) => [item.id, item]))
  const serialIds = new Set(serials.map((serial) => serial.id))
  const conflicts = new Map<string, string[]>()

  if (serialIds.size > 0) {
    const { data: packingData, error: packingError } = await supabase
      .from('packing_list')
      .select('id, projeto_id, item_id, quantidade, serial_numbers_designados, projetos!inner(id, status)')
      .not('serial_numbers_designados', 'is', null)
    if (packingError) throw new Error(`Falha ao consultar conflitos ativos: ${packingError.message}`)

    for (const row of packingData as unknown as PackingRow[]) {
      if (row.projeto_id === trainingEventId || !row.projetos) continue
      if (!ACTIVE_PROJECT_STATUSES.has(row.projetos.status)) continue
      for (const serialId of row.serial_numbers_designados ?? []) {
        if (!serialIds.has(serialId)) continue
        const projectIds = conflicts.get(serialId) ?? []
        projectIds.push(row.projetos.id)
        conflicts.set(serialId, projectIds)
      }
    }
  }

  return serials.map((serial) => {
    const item = items.get(serial.item_id)
    return {
      id: serial.id,
      itemId: serial.item_id,
      itemCode: item?.codigo_interno ?? serial.item_id.slice(0, 8),
      itemName: item?.nome.trim() || `Item ${item?.codigo_interno ?? serial.item_id.slice(0, 8)}`,
      serialCode: serial.codigo_interno,
      status: serial.status,
      tagRfid: serial.tag_rfid,
      conflictProjectIds: conflicts.get(serial.id) ?? [],
    }
  })
}

async function applyPlan(
  supabase: SupabaseClient,
  plan: ReturnType<typeof buildTrainingEventPlan>,
  existingEvent: ExistingTrainingEvent | null,
) {
  if (plan.changes.some((change) => change.action === 'remove')) {
    throw new Error('A preparação recusou remover linha existente. Abra uma nova execução com --run N.')
  }

  let eventId = existingEvent?.id ?? null
  let writesPerformed = 0
  if (!eventId) {
    const { data, error } = await supabase
      .from('projetos')
      .insert({
        codigo_evento: plan.event.code,
        nome: plan.event.name,
        cliente: plan.event.client,
        data_inicio: plan.event.startDate,
        data_fim: plan.event.endDate,
        local: plan.event.location,
        status: 'PLANEJAMENTO',
        notas: plan.event.notes,
        ficha_evento: plan.event.fichaEvento,
      })
      .select('id')
      .single()
    if (error) throw new Error(`Falha ao criar Evento de treino: ${error.message}`)
    eventId = data.id as string
    writesPerformed += 1
  }

  const existingByItem = new Map((existingEvent?.packing ?? []).map((line) => [line.itemId, line]))
  for (const line of plan.packing) {
    const existing = existingByItem.get(line.itemId)
    if (!existing) {
      const { error } = await supabase.from('packing_list').insert({
        projeto_id: eventId,
        item_id: line.itemId,
        quantidade: line.quantity,
        serial_numbers_designados: line.initialSerialIds,
        notas: `${plan.event.code} · cenário inicial do treinamento`,
      })
      if (error) throw new Error(`Falha ao criar packing ${line.itemCode}: ${error.message}`)
      writesPerformed += 1
      continue
    }

    const needsUpdate = plan.changes.some(
      (change) =>
        change.action === 'update' &&
        change.target === 'packing-line' &&
        change.label === `${line.itemCode} · ${line.itemName}`,
    )
    if (!needsUpdate) continue
    const { error } = await supabase
      .from('packing_list')
      .update({
        quantidade: line.quantity,
        serial_numbers_designados: line.initialSerialIds,
        notas: `${plan.event.code} · cenário inicial do treinamento`,
      })
      .eq('id', existing.id)
    if (error) throw new Error(`Falha ao corrigir packing ${line.itemCode}: ${error.message}`)
    writesPerformed += 1
  }
  return writesPerformed
}

function printResult(
  plan: ReturnType<typeof buildTrainingEventPlan>,
  runNumber: number,
  mode: 'probe-read-only' | 'apply-blocked' | 'apply-verified',
  writesPerformed: number,
) {
  const output = {
    mode,
    runNumber,
    ready: plan.ready,
    event: {
      code: plan.event.code,
      name: plan.event.name,
      dates: `${plan.event.startDate} a ${plan.event.endDate}`,
    },
    selectedUnits: plan.selectedSerials.map((serial) => ({
      item: `${serial.itemCode} · ${serial.itemName}`,
      unit: serial.serialCode,
      rfid: serial.tagRfid ? 'vinculado' : 'vínculo físico pendente',
    })),
    packing: plan.packing.map((line) => ({
      item: `${line.itemCode} · ${line.itemName}`,
      initial: `${line.initialSerialIds.length}/${line.quantity}`,
      complete: `${line.completeSerialIds.length}/${line.quantity}`,
    })),
    scenarios: plan.scenarios,
    exactChanges: plan.changes,
    blockers: plan.blockers,
    writesPerformed,
  }
  console.log(JSON.stringify(output, null, 2))
}
