export const INTERNAL_QR_LOOKUP_FIELDS = ['codigo_interno', 'qr_code'] as const

export type InternalQrLookupField = (typeof INTERNAL_QR_LOOKUP_FIELDS)[number]

export function normalizeInternalQrLookupCode(raw: string) {
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

export function isInternalQrLookupField(field: string): field is InternalQrLookupField {
  return INTERNAL_QR_LOOKUP_FIELDS.includes(field as InternalQrLookupField)
}
