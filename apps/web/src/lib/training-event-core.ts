export const TRAINING_EVENT_CODE = 'TRN-MARCELO-01'
export const TRAINING_EVENT_NAME = 'Treinamento · Marcelo'
export const TRAINING_EVENT_MARKER = '[MMD_TRAINING_EVENT:v1]'
export const TRAINING_SERIAL_COUNT = 5

export function trainingEventCode(runNumber: number) {
  if (!Number.isInteger(runNumber) || runNumber < 1 || runNumber > 99) {
    throw new Error(`Execução de treinamento inválida: ${runNumber}`)
  }
  return `TRN-MARCELO-${String(runNumber).padStart(2, '0')}`
}

export type TrainingSerialCandidate = {
  id: string
  itemId: string
  itemCode: string
  itemName: string
  serialCode: string
  status: string
  tagRfid: string | null
  conflictProjectIds: string[]
}

export type TrainingPackingState = {
  id: string
  itemId: string
  quantity: number
  serialIds: string[]
}

export type ExistingTrainingEvent = {
  id: string
  code: string | null
  name: string
  status: string
  notes: string | null
  startDate: string
  endDate: string
  packing: TrainingPackingState[]
}

export type TrainingPackingLine = {
  itemId: string
  itemCode: string
  itemName: string
  quantity: number
  initialSerialIds: string[]
  completeSerialIds: string[]
  serialCodes: string[]
}

export type TrainingPlanChange = {
  action: 'create' | 'update' | 'remove'
  target: 'event' | 'packing-line'
  label: string
  before: string
  after: string
}

export type TrainingPlan = {
  ready: boolean
  blockers: string[]
  event: {
    code: string
    name: string
    client: string
    startDate: string
    endDate: string
    location: string
    notes: string
    fichaEvento: Record<string, unknown>
  }
  selectedSerials: TrainingSerialCandidate[]
  packing: TrainingPackingLine[]
  scenarios: {
    knownTagSerialCode: string | null
    linkedTagCount: number
    pendingTagSerialCodes: string[]
    unknownTagInstruction: string
    returnOkSerialCode: string | null
    returnProblemSerialCode: string | null
    returnPendingSerialCode: string | null
    packingCompletionSerialCode: string | null
  }
  changes: TrainingPlanChange[]
}

const ACTIVE_TRAINING_STATUS = 'PLANEJAMENTO'

export function buildTrainingEventPlan({
  candidates,
  existingEvent = null,
  today,
  runNumber = 1,
}: {
  candidates: TrainingSerialCandidate[]
  existingEvent?: ExistingTrainingEvent | null
  today: string
  runNumber?: number
}): TrainingPlan {
  const window = existingEvent
    ? { startDate: existingEvent.startDate, endDate: existingEvent.endDate }
    : nextTrainingWindow(today)
  const eventCode = trainingEventCode(runNumber)
  const event = buildEventPayload(window, eventCode, runNumber)
  const eligible = candidates
    .filter(
      (candidate) =>
        candidate.status === 'DISPONIVEL' &&
        candidate.conflictProjectIds.length === 0,
    )
    .sort(compareCandidates)
  const selectedSerials = selectTrainingSerials(eligible)
  const blockers: string[] = []

  if (selectedSerials.length < TRAINING_SERIAL_COUNT) {
    blockers.push(
      `São necessárias ${TRAINING_SERIAL_COUNT} unidades DISPONIVEL e sem conflito ativo. Encontradas: ${selectedSerials.length}.`,
    )
  }

  if (new Set(selectedSerials.map((serial) => serial.itemId)).size < 2) {
    blockers.push('O treino precisa de pelo menos dois tipos de item para diferenciar item e unidade física.')
  }

  const knownTagSerial = selectedSerials.find((serial) => Boolean(serial.tagRfid?.trim()))
  if (!knownTagSerial) {
    blockers.push('O treino precisa de pelo menos uma unidade com RFID já vinculado para o cenário de tag conhecida.')
  }

  if (existingEvent && !isOwnedTrainingEvent(existingEvent, eventCode)) {
    blockers.push('O código de treino já existe, mas o registro não possui nome e marcador exclusivos do treinamento.')
  }

  if (existingEvent && existingEvent.status !== ACTIVE_TRAINING_STATUS) {
    blockers.push(
      `O Evento de treino está em ${existingEvent.status}. A preparação não altera um ciclo iniciado sem reset confirmado.`,
    )
  }

  const packing = buildPackingLines(selectedSerials)
  const changes = blockers.length === 0 ? buildChanges(existingEvent, packing) : []

  return {
    ready: blockers.length === 0,
    blockers,
    event,
    selectedSerials,
    packing,
    scenarios: {
      knownTagSerialCode: knownTagSerial?.serialCode ?? null,
      linkedTagCount: selectedSerials.filter((serial) => Boolean(serial.tagRfid?.trim())).length,
      pendingTagSerialCodes: selectedSerials
        .filter((serial) => !serial.tagRfid?.trim())
        .map((serial) => serial.serialCode),
      unknownTagInstruction: 'Reservar uma tag física sem vínculo e não cadastrá-la antes do take.',
      returnOkSerialCode: selectedSerials[0]?.serialCode ?? null,
      returnProblemSerialCode: selectedSerials[1]?.serialCode ?? null,
      returnPendingSerialCode: selectedSerials[2]?.serialCode ?? null,
      packingCompletionSerialCode: selectedSerials.at(-1)?.serialCode ?? null,
    },
    changes,
  }
}

export function isOwnedTrainingEvent(
  event: ExistingTrainingEvent,
  expectedCode = TRAINING_EVENT_CODE,
): boolean {
  return (
    event.code === expectedCode &&
    event.name === TRAINING_EVENT_NAME &&
    event.notes?.includes(TRAINING_EVENT_MARKER) === true
  )
}

function nextTrainingWindow(today: string) {
  const start = parseDate(today)
  start.setUTCDate(start.getUTCDate() + 7)
  while (start.getUTCDay() !== 1) start.setUTCDate(start.getUTCDate() + 1)
  const end = new Date(start)
  end.setUTCDate(end.getUTCDate() + 1)
  return { startDate: formatDate(start), endDate: formatDate(end) }
}

function parseDate(value: string) {
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (!match) throw new Error(`Data inválida: ${value}`)
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])))
  if (formatDate(date) !== value) throw new Error(`Data inválida: ${value}`)
  return date
}

function formatDate(value: Date) {
  return value.toISOString().slice(0, 10)
}

function compareCandidates(a: TrainingSerialCandidate, b: TrainingSerialCandidate) {
  return (
    Number(Boolean(b.tagRfid?.trim())) - Number(Boolean(a.tagRfid?.trim())) ||
    a.itemName.localeCompare(b.itemName, 'pt-BR') ||
    a.itemCode.localeCompare(b.itemCode, 'pt-BR') ||
    a.serialCode.localeCompare(b.serialCode, 'pt-BR') ||
    a.id.localeCompare(b.id)
  )
}

function selectTrainingSerials(candidates: TrainingSerialCandidate[]) {
  const groups = new Map<string, TrainingSerialCandidate[]>()
  for (const candidate of candidates) {
    const group = groups.get(candidate.itemId) ?? []
    group.push(candidate)
    groups.set(candidate.itemId, group)
  }

  const orderedGroups = [...groups.values()].sort((a, b) => compareCandidates(a[0], b[0]))
  const anchor = orderedGroups.find((group) => group.length >= 2)
  if (!anchor) return candidates.slice(0, TRAINING_SERIAL_COUNT)

  const selected = anchor.slice(0, 2)
  for (const group of orderedGroups) {
    if (group === anchor || selected.length >= TRAINING_SERIAL_COUNT) continue
    selected.push(group[0])
  }
  for (const candidate of candidates) {
    if (selected.length >= TRAINING_SERIAL_COUNT) break
    if (!selected.some((selectedCandidate) => selectedCandidate.id === candidate.id)) {
      selected.push(candidate)
    }
  }
  return selected.sort(compareCandidates)
}

function buildPackingLines(selected: TrainingSerialCandidate[]): TrainingPackingLine[] {
  const completionSerialId = selected.at(-1)?.id
  const groups = new Map<string, TrainingSerialCandidate[]>()
  for (const serial of selected) {
    const group = groups.get(serial.itemId) ?? []
    group.push(serial)
    groups.set(serial.itemId, group)
  }

  return [...groups.values()]
    .sort((a, b) => compareCandidates(a[0], b[0]))
    .map((group) => ({
      itemId: group[0].itemId,
      itemCode: group[0].itemCode,
      itemName: group[0].itemName,
      quantity: group.length,
      initialSerialIds: group.filter((serial) => serial.id !== completionSerialId).map((serial) => serial.id),
      completeSerialIds: group.map((serial) => serial.id),
      serialCodes: group.map((serial) => serial.serialCode),
    }))
}

function buildChanges(
  existingEvent: ExistingTrainingEvent | null,
  packing: TrainingPackingLine[],
): TrainingPlanChange[] {
  const changes: TrainingPlanChange[] = []
  if (!existingEvent) {
    changes.push({
      action: 'create',
      target: 'event',
      label: TRAINING_EVENT_NAME,
      before: 'ausente',
      after: `${ACTIVE_TRAINING_STATUS}, ${packing.length} linha(s) de packing`,
    })
  }

  const existingByItem = new Map((existingEvent?.packing ?? []).map((line) => [line.itemId, line]))
  for (const line of packing) {
    const existing = existingByItem.get(line.itemId)
    const after = packingStateLabel(line.quantity, line.initialSerialIds.length)
    if (!existing) {
      changes.push({
        action: 'create',
        target: 'packing-line',
        label: `${line.itemCode} · ${line.itemName}`,
        before: 'ausente',
        after,
      })
      continue
    }

    existingByItem.delete(line.itemId)
    if (existing.quantity !== line.quantity || !sameIds(existing.serialIds, line.initialSerialIds)) {
      changes.push({
        action: 'update',
        target: 'packing-line',
        label: `${line.itemCode} · ${line.itemName}`,
        before: packingStateLabel(existing.quantity, existing.serialIds.length),
        after,
      })
    }
  }

  for (const extra of existingByItem.values()) {
    changes.push({
      action: 'remove',
      target: 'packing-line',
      label: extra.itemId,
      before: packingStateLabel(extra.quantity, extra.serialIds.length),
      after: 'ausente',
    })
  }
  return changes
}

function sameIds(a: string[], b: string[]) {
  return [...a].sort().join('|') === [...b].sort().join('|')
}

function packingStateLabel(quantity: number, allocated: number) {
  return `${allocated}/${quantity} unidade(s) alocada(s)`
}

function buildEventPayload(
  { startDate, endDate }: { startDate: string; endDate: string },
  eventCode: string,
  runNumber: number,
) {
  const client = 'MMD Eventos'
  const location = 'Ambiente controlado de treinamento MMD'
  const notes = `${TRAINING_EVENT_MARKER}\nExecução ${String(runNumber).padStart(2, '0')}. Registro exclusivo para treinamento. Não usar em Evento de cliente.`
  return {
    code: eventCode,
    name: TRAINING_EVENT_NAME,
    client,
    startDate,
    endDate,
    location,
    notes,
    fichaEvento: {
      versao: 1,
      atualizadoEm: null,
      evento: {
        nome: TRAINING_EVENT_NAME,
        cliente: client,
        dataInicial: startDate,
        dataFinal: endDate,
        statusInicial: ACTIVE_TRAINING_STATUS,
      },
      endereco: {
        local: location,
        endereco: 'Sem endereço de cliente',
        cidadeUf: 'Não aplicável',
        referenciaAcesso: 'Uso interno e isolado',
      },
      montagem: {
        dia: startDate,
        inicio: '09:00',
        fim: '10:00',
        equipe: 'Treinamento MMD',
        responsavel: 'Marcelo',
        telefone: null,
      },
      desmontagem: {
        dia: endDate,
        inicio: '18:00',
        fim: '19:00',
        equipe: 'Treinamento MMD',
        responsavel: 'Marcelo',
        telefone: null,
      },
      responsaveis: {
        principal: 'Marcelo',
        principalTelefone: null,
        checklist: 'Marcelo',
        checklistTelefone: null,
      },
      checklist: [
        { item: 'Conferir packing antes da saída', responsavel: 'Marcelo', ok: false },
        { item: 'Registrar retorno e pendências', responsavel: 'Marcelo', ok: false },
      ],
      observacoes: `${TRAINING_EVENT_MARKER} Cenário controlado para o tutorial.`,
    },
  }
}
