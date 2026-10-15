export type StatusProjeto =
  | 'PLANEJAMENTO'
  | 'CONFIRMADO'
  | 'MONTAGEM'
  | 'EM_CAMPO'
  | 'FINALIZADO'
  | 'CANCELADO'

export type EventoChecklistItem = {
  item: string
  responsavel: string
  ok: boolean
}

export type EventoFichaInput = {
  projetoId?: string | null
  nomeEvento: string
  cliente: string
  dataInicial: string
  dataFinal: string
  statusInicial: StatusProjeto
  local: string
  endereco: string
  cidadeUf: string
  referenciaAcesso: string
  montagemDia: string
  montagemInicio: string
  montagemFim: string
  montagemEquipe: string
  montagemResponsavel: string
  montagemTelefone: string
  desmontagemDia: string
  desmontagemInicio: string
  desmontagemFim: string
  desmontagemEquipe: string
  desmontagemResponsavel: string
  desmontagemTelefone: string
  responsavelPrincipal: string
  responsavelPrincipalTelefone: string
  responsavelChecklist: string
  responsavelChecklistTelefone: string
  observacoes: string
  checklist: EventoChecklistItem[]
}

export type EventoFichaRecord = {
  versao: 1
  atualizadoEm: string | null
  evento: {
    nome: string
    cliente: string | null
    dataInicial: string
    dataFinal: string
    statusInicial: StatusProjeto
  }
  endereco: {
    local: string | null
    endereco: string | null
    cidadeUf: string | null
    referenciaAcesso: string | null
  }
  montagem: {
    dia: string | null
    inicio: string | null
    fim: string | null
    equipe: string | null
    responsavel: string | null
    telefone: string | null
  }
  desmontagem: {
    dia: string | null
    inicio: string | null
    fim: string | null
    equipe: string | null
    responsavel: string | null
    telefone: string | null
  }
  responsaveis: {
    principal: string | null
    principalTelefone: string | null
    checklist: string | null
    checklistTelefone: string | null
  }
  checklist: EventoChecklistItem[]
  observacoes: string | null
}

export type NormalizedEventoFicha = {
  projetoId: string | null
  projeto: {
    nome: string
    cliente: string | null
    data_inicio: string
    data_fim: string
    local: string | null
    status: StatusProjeto
    notas: string | null
    ficha_evento: EventoFichaRecord
  }
  completeness: {
    total: number
    preenchidos: number
    pct: number
  }
}

export type EventoFichaResult =
  | { ok: true; data: NormalizedEventoFicha }
  | { ok: false; error: string }

const DEFAULT_CHECKLIST_LENGTH = 8

const REQUIRED_FIELDS: (keyof EventoFichaInput)[] = [
  'nomeEvento',
  'cliente',
  'dataInicial',
  'dataFinal',
  'local',
  'endereco',
  'cidadeUf',
  'montagemDia',
  'montagemInicio',
  'montagemFim',
  'desmontagemDia',
  'desmontagemInicio',
  'responsavelPrincipal',
]

const REQUIRED_RECORD_FIELDS: {
  label: string
  read: (record: EventoFichaRecord) => string | null
}[] = [
  { label: 'nome do evento', read: (record) => record.evento.nome },
  { label: 'cliente', read: (record) => record.evento.cliente },
  { label: 'data inicial', read: (record) => record.evento.dataInicial },
  { label: 'data final', read: (record) => record.evento.dataFinal },
  { label: 'local', read: (record) => record.endereco.local },
  { label: 'endereço', read: (record) => record.endereco.endereco },
  { label: 'cidade/UF', read: (record) => record.endereco.cidadeUf },
  { label: 'dia da montagem', read: (record) => record.montagem.dia },
  { label: 'início da montagem', read: (record) => record.montagem.inicio },
  { label: 'fim da montagem', read: (record) => record.montagem.fim },
  { label: 'dia da desmontagem', read: (record) => record.desmontagem.dia },
  { label: 'início da desmontagem', read: (record) => record.desmontagem.inicio },
  { label: 'responsável principal', read: (record) => record.responsaveis.principal },
]

export const STATUS_PROJETO_OPTIONS: { value: StatusProjeto; label: string }[] = [
  { value: 'PLANEJAMENTO', label: 'Planejamento' },
  { value: 'CONFIRMADO', label: 'Confirmado' },
  { value: 'MONTAGEM', label: 'Montagem' },
  { value: 'EM_CAMPO', label: 'Em campo' },
  { value: 'FINALIZADO', label: 'Finalizado' },
  { value: 'CANCELADO', label: 'Cancelado' },
]

export function emptyEventoFichaInput(today = ''): EventoFichaInput {
  return {
    projetoId: null,
    nomeEvento: '',
    cliente: '',
    dataInicial: today,
    dataFinal: today,
    statusInicial: 'PLANEJAMENTO',
    local: '',
    endereco: '',
    cidadeUf: '',
    referenciaAcesso: '',
    montagemDia: today,
    montagemInicio: '',
    montagemFim: '',
    montagemEquipe: '',
    montagemResponsavel: '',
    montagemTelefone: '',
    desmontagemDia: today,
    desmontagemInicio: '',
    desmontagemFim: '',
    desmontagemEquipe: '',
    desmontagemResponsavel: '',
    desmontagemTelefone: '',
    responsavelPrincipal: '',
    responsavelPrincipalTelefone: '',
    responsavelChecklist: '',
    responsavelChecklistTelefone: '',
    observacoes: '',
    checklist: Array.from({ length: DEFAULT_CHECKLIST_LENGTH }, () => ({
      item: '',
      responsavel: '',
      ok: false,
    })),
  }
}

export function isStatusProjeto(value: string): value is StatusProjeto {
  return STATUS_PROJETO_OPTIONS.some((option) => option.value === value)
}

export function trimToNull(value: string | null | undefined) {
  const trimmed = value?.trim() ?? ''
  return trimmed ? trimmed : null
}

export function normalizeEventoChecklist(rows: EventoChecklistItem[]) {
  return rows
    .map((row) => ({
      item: row.item.trim(),
      responsavel: row.responsavel.trim(),
      ok: Boolean(row.ok),
    }))
    .filter((row) => row.item || row.responsavel || row.ok)
}

export function calculateFichaCompleteness(input: EventoFichaInput) {
  const preenchidos = REQUIRED_FIELDS.filter((field) => {
    const value = input[field]
    return typeof value === 'string' ? value.trim().length > 0 : Boolean(value)
  }).length
  return {
    total: REQUIRED_FIELDS.length,
    preenchidos,
    pct: Math.round((preenchidos / REQUIRED_FIELDS.length) * 100),
  }
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function readString(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null
}

function readObject(value: unknown): Record<string, unknown> {
  return isPlainObject(value) ? value : {}
}

export function parseEventoFichaRecord(value: unknown): EventoFichaRecord | null {
  if (!isPlainObject(value) || value.versao !== 1) return null

  const evento = readObject(value.evento)
  const endereco = readObject(value.endereco)
  const montagem = readObject(value.montagem)
  const desmontagem = readObject(value.desmontagem)
  const responsaveis = readObject(value.responsaveis)
  const statusInicial = readString(evento.statusInicial) ?? 'PLANEJAMENTO'

  return {
    versao: 1,
    atualizadoEm: readString(value.atualizadoEm),
    evento: {
      nome: readString(evento.nome) ?? '',
      cliente: readString(evento.cliente),
      dataInicial: readString(evento.dataInicial) ?? '',
      dataFinal: readString(evento.dataFinal) ?? '',
      statusInicial: isStatusProjeto(statusInicial) ? statusInicial : 'PLANEJAMENTO',
    },
    endereco: {
      local: readString(endereco.local),
      endereco: readString(endereco.endereco),
      cidadeUf: readString(endereco.cidadeUf),
      referenciaAcesso: readString(endereco.referenciaAcesso),
    },
    montagem: {
      dia: readString(montagem.dia),
      inicio: readString(montagem.inicio),
      fim: readString(montagem.fim),
      equipe: readString(montagem.equipe),
      responsavel: readString(montagem.responsavel),
      telefone: readString(montagem.telefone),
    },
    desmontagem: {
      dia: readString(desmontagem.dia),
      inicio: readString(desmontagem.inicio),
      fim: readString(desmontagem.fim),
      equipe: readString(desmontagem.equipe),
      responsavel: readString(desmontagem.responsavel),
      telefone: readString(desmontagem.telefone),
    },
    responsaveis: {
      principal: readString(responsaveis.principal),
      principalTelefone: readString(responsaveis.principalTelefone),
      checklist: readString(responsaveis.checklist),
      checklistTelefone: readString(responsaveis.checklistTelefone),
    },
    checklist: normalizeEventoChecklist(
      Array.isArray(value.checklist)
        ? value.checklist.map((row) => {
            const checklistRow = readObject(row)
            return {
              item: readString(checklistRow.item) ?? '',
              responsavel: readString(checklistRow.responsavel) ?? '',
              ok: Boolean(checklistRow.ok),
            }
          })
        : [],
    ),
    observacoes: readString(value.observacoes),
  }
}

export function calculateFichaRecordCompleteness(record: EventoFichaRecord) {
  const missingLabels: string[] = []
  const preenchidos = REQUIRED_RECORD_FIELDS.filter((field) => {
    const filled = Boolean(field.read(record)?.trim())
    if (!filled) missingLabels.push(field.label)
    return filled
  }).length

  return {
    total: REQUIRED_RECORD_FIELDS.length,
    preenchidos,
    pct: Math.round((preenchidos / REQUIRED_RECORD_FIELDS.length) * 100),
    missingLabels,
  }
}

export function calculateFichaChecklist(record: EventoFichaRecord) {
  const checklistTotal = record.checklist.length
  const checklistOk = record.checklist.filter((row) => row.ok).length
  return {
    checklistTotal,
    checklistOk,
    checklistPendentes: Math.max(0, checklistTotal - checklistOk),
  }
}

export function buildEventoNotas(record: EventoFichaRecord) {
  const lines = [
    'Ficha do evento',
    `Endereço: ${record.endereco.endereco ?? '-'}${record.endereco.cidadeUf ? `, ${record.endereco.cidadeUf}` : ''}`,
    `Referência: ${record.endereco.referenciaAcesso ?? '-'}`,
    `Montagem: ${record.montagem.dia ?? '-'} ${record.montagem.inicio ?? ''}-${record.montagem.fim ?? ''}`,
    `Responsável montagem: ${record.montagem.responsavel ?? '-'}`,
    `Desmontagem: ${record.desmontagem.dia ?? '-'} ${record.desmontagem.inicio ?? ''}-${record.desmontagem.fim ?? ''}`,
    `Responsável principal: ${record.responsaveis.principal ?? '-'}`,
  ]
  if (record.observacoes) lines.push(`OBS do evento: ${record.observacoes}`)
  if (record.checklist.length > 0) {
    lines.push('Checklist:')
    for (const [index, row] of record.checklist.entries()) {
      lines.push(
        `${index + 1}. ${row.item || '-'} | Resp: ${row.responsavel || '-'} | OK: ${row.ok ? 'sim' : 'não'}`,
      )
    }
  }
  return lines.join('\n')
}

export function normalizeEventoFichaInput(
  input: EventoFichaInput,
  atualizadoEm: string | null = null,
): EventoFichaResult {
  const nome = input.nomeEvento.trim()
  if (!nome) return { ok: false, error: 'Nome do evento obrigatório.' }
  if (!isStatusProjeto(input.statusInicial)) return { ok: false, error: 'Status inválido.' }
  if (!input.dataInicial || !input.dataFinal) {
    return { ok: false, error: 'Data inicial e final são obrigatórias.' }
  }
  if (input.dataFinal < input.dataInicial) {
    return { ok: false, error: 'Data final antes da inicial.' }
  }

  const record: EventoFichaRecord = {
    versao: 1,
    atualizadoEm,
    evento: {
      nome,
      cliente: trimToNull(input.cliente),
      dataInicial: input.dataInicial,
      dataFinal: input.dataFinal,
      statusInicial: input.statusInicial,
    },
    endereco: {
      local: trimToNull(input.local),
      endereco: trimToNull(input.endereco),
      cidadeUf: trimToNull(input.cidadeUf),
      referenciaAcesso: trimToNull(input.referenciaAcesso),
    },
    montagem: {
      dia: trimToNull(input.montagemDia),
      inicio: trimToNull(input.montagemInicio),
      fim: trimToNull(input.montagemFim),
      equipe: trimToNull(input.montagemEquipe),
      responsavel: trimToNull(input.montagemResponsavel),
      telefone: trimToNull(input.montagemTelefone),
    },
    desmontagem: {
      dia: trimToNull(input.desmontagemDia),
      inicio: trimToNull(input.desmontagemInicio),
      fim: trimToNull(input.desmontagemFim),
      equipe: trimToNull(input.desmontagemEquipe),
      responsavel: trimToNull(input.desmontagemResponsavel),
      telefone: trimToNull(input.desmontagemTelefone),
    },
    responsaveis: {
      principal: trimToNull(input.responsavelPrincipal),
      principalTelefone: trimToNull(input.responsavelPrincipalTelefone),
      checklist: trimToNull(input.responsavelChecklist),
      checklistTelefone: trimToNull(input.responsavelChecklistTelefone),
    },
    checklist: normalizeEventoChecklist(input.checklist),
    observacoes: trimToNull(input.observacoes),
  }

  return {
    ok: true,
    data: {
      projetoId: trimToNull(input.projetoId),
      projeto: {
        nome,
        cliente: record.evento.cliente,
        data_inicio: input.dataInicial,
        data_fim: input.dataFinal,
        local: record.endereco.local,
        status: input.statusInicial,
        notas: buildEventoNotas(record),
        ficha_evento: record,
      },
      completeness: calculateFichaCompleteness(input),
    },
  }
}
