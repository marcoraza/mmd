import type { StatusSerial } from './types'

export type PublicAssetStatus = 'Ativo' | 'Em uso' | 'Indisponível' | 'Falar com EventPro'

export const PUBLIC_QR_FORBIDDEN_LABELS = [
  'Valor atual',
  'Serial fábrica',
  'RFID',
  'Tag RFID',
  'Localização',
  'Desgaste',
  'Estado',
  'Histórico',
]

export function normalizePublicLookupCode(raw: string) {
  let decoded: string

  try {
    decoded = decodeURIComponent(raw).trim()
  } catch {
    return null
  }

  if (!decoded || decoded.length > 80) return null
  if (!/^[A-Za-z0-9._:-]+$/.test(decoded)) return null

  return decoded
}

export function serialStatusToPublicStatus(status: StatusSerial): PublicAssetStatus {
  if (status === 'DISPONIVEL' || status === 'PACKED') return 'Ativo'
  if (status === 'EM_CAMPO' || status === 'RETORNANDO') return 'Em uso'
  if (status === 'MANUTENCAO') return 'Indisponível'
  return 'Falar com EventPro'
}

export function publicStatusColor(status: PublicAssetStatus) {
  if (status === 'Ativo') return 'var(--accent-green)'
  if (status === 'Em uso') return 'var(--accent-amber)'
  if (status === 'Indisponível') return 'var(--accent-red)'
  return 'var(--accent-cyan)'
}

export function getPublicQrContact(env: Record<string, string | undefined> = process.env) {
  const whatsappUrl = env.NEXT_PUBLIC_EVENTPRO_WHATSAPP_URL?.trim() || null
  const phone = env.NEXT_PUBLIC_EVENTPRO_PHONE?.trim() || null

  return {
    whatsappUrl,
    phone,
    hasDirectContact: Boolean(whatsappUrl || phone),
  }
}

export function containsPublicQrForbiddenLabel(text: string) {
  const normalized = text.toLocaleLowerCase('pt-BR')

  return PUBLIC_QR_FORBIDDEN_LABELS.some((label) =>
    normalized.includes(label.toLocaleLowerCase('pt-BR')),
  )
}
