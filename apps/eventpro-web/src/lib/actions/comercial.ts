import 'server-only'

// Registro comercial leve do Evento: status do funil, links e anexos. Não é
// módulo financeiro.

import { randomUUID } from 'node:crypto'
import { revalidatePath } from 'next/cache'
import { requireActionUser } from '@/lib/action-auth'
import { blockWrite, type ActionResult } from '@/lib/readonly'
import { supabaseAdmin } from '@/lib/supabase-server'
import {
  EVENTO_COMERCIAL_BUCKET,
  EVENTO_COMERCIAL_MAX_FILE_BYTES,
  normalizeEventoComercialInput,
  parseEventoComercialRecord,
  safeCommercialFileName,
  type DocumentoComercialTipo,
  type UploadedEventoComercialDocumento,
} from '@/lib/evento-comercial-core'

// Espelha `allowed_mime_types` do bucket `eventpro-comercial` no schema.
const COMERCIAL_ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/msword',
  'image/png',
  'image/jpeg',
])

function formText(formData: FormData, key: string) {
  const value = formData.get(key)
  return typeof value === 'string' ? value : ''
}

function formFile(formData: FormData, key: string): File | null {
  const value = formData.get(key)
  if (!value || typeof value === 'string') return null
  return value.size > 0 ? value : null
}

function commercialMimeType(file: File) {
  if (file.type) return file.type
  const name = file.name.toLowerCase()
  if (name.endsWith('.pdf')) return 'application/pdf'
  if (name.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  }
  if (name.endsWith('.doc')) return 'application/msword'
  if (name.endsWith('.png')) return 'image/png'
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg'
  return 'application/octet-stream'
}

async function uploadEventoComercialFile(
  projetoId: string,
  tipo: DocumentoComercialTipo,
  file: File,
): Promise<ActionResult<UploadedEventoComercialDocumento>> {
  if (file.size > EVENTO_COMERCIAL_MAX_FILE_BYTES) {
    return { ok: false, error: 'Anexo comercial precisa ter no máximo 10 MB.' }
  }

  const mimeType = commercialMimeType(file)
  if (!COMERCIAL_ALLOWED_MIME_TYPES.has(mimeType)) {
    return { ok: false, error: 'Anexo comercial precisa ser PDF, DOC, DOCX, PNG ou JPG.' }
  }

  const filename = safeCommercialFileName(file.name)
  const storagePath = `${projetoId}/${tipo.toLowerCase()}/${randomUUID()}-${filename}`
  const bytes = new Uint8Array(await file.arrayBuffer())

  const { error } = await supabaseAdmin.storage
    .from(EVENTO_COMERCIAL_BUCKET)
    .upload(storagePath, bytes, { contentType: mimeType, upsert: false })

  if (error) return { ok: false, error: error.message }

  return {
    ok: true,
    data: {
      tipo,
      filename,
      storage_path: storagePath,
      mime_type: mimeType,
      tamanho_bytes: file.size,
    },
  }
}

export type SaveEventoComercialResult = {
  id: string
  permiteOperacaoEstoque: boolean
  readinessPct: number
}

export async function saveEventoComercial(
  formData: FormData,
): Promise<ActionResult<SaveEventoComercialResult>> {
  const projetoId = formText(formData, 'projetoId')

  const blocked = blockWrite<SaveEventoComercialResult>()
  if (blocked) return blocked

  const auth = await requireActionUser('editor')
  if (!auth.ok) return auth

  const { data: existing, error: existingError } = await supabaseAdmin
    .from('projetos')
    .select('comercial')
    .eq('id', projetoId)
    .maybeSingle()

  if (existingError) return { ok: false, error: existingError.message }
  if (!existing) return { ok: false, error: 'Evento não encontrado.' }

  const existingRecord = parseEventoComercialRecord((existing as { comercial?: unknown }).comercial)

  const input = {
    projetoId,
    status: formText(formData, 'status'),
    orcamentoUrl: formText(formData, 'orcamentoUrl'),
    contratoUrl: formText(formData, 'contratoUrl'),
    observacoes: formText(formData, 'observacoes'),
  }

  // Validação antes do upload: não sobe arquivo para storage se o payload já é
  // inválido.
  const preflight = normalizeEventoComercialInput(input, existingRecord.documentos)
  if (!preflight.ok) return preflight

  const uploadedDocs: UploadedEventoComercialDocumento[] = []
  const orcamentoFile = formFile(formData, 'orcamentoFile')
  const contratoFile = formFile(formData, 'contratoFile')

  if (orcamentoFile) {
    const upload = await uploadEventoComercialFile(projetoId, 'ORCAMENTO', orcamentoFile)
    if (!upload.ok) return upload
    uploadedDocs.push(upload.data)
  }

  if (contratoFile) {
    const upload = await uploadEventoComercialFile(projetoId, 'CONTRATO', contratoFile)
    if (!upload.ok) return upload
    uploadedDocs.push(upload.data)
  }

  const normalized = normalizeEventoComercialInput(
    input,
    existingRecord.documentos,
    uploadedDocs,
    new Date().toISOString(),
  )
  if (!normalized.ok) return normalized

  const { error } = await supabaseAdmin
    .from('projetos')
    .update({ comercial: normalized.data.comercial })
    .eq('id', normalized.data.projetoId)

  if (error) return { ok: false, error: error.message }

  revalidatePath('/projetos')
  revalidatePath(`/projetos/${normalized.data.projetoId}`)
  return {
    ok: true,
    data: {
      id: normalized.data.projetoId,
      permiteOperacaoEstoque: normalized.data.comercial.permite_operacao_estoque,
      readinessPct: normalized.data.comercial.readiness_pct,
    },
  }
}
