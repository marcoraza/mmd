// Regra pura do vínculo de tag RFID a uma unidade.
//
// Mudança em relação ao legado: o vínculo deixa de ser restrito a cabos. No MMD
// a ação recusava qualquer unidade fora da categoria CABO
// ("Vínculo rápido de RFID está limitado a cabos."), o que travava o onboarding
// de etiqueta de moving, caixa e estrutura. As validações que valem (formato e
// unicidade da tag) continuam iguais.
//
// A normalização é exatamente a de `normalizeRfidTag` em `rfid-scan-core`, para
// a tag gravada aqui casar com a tag lida por /api/rfid/scans.

import { normalizeRfidTag } from './rfid-scan-core.ts'

export const RFID_TAG_MIN_LENGTH = 8
export const RFID_TAG_MAX_LENGTH = 96

export type RfidTagValidation = { ok: true; tag: string } | { ok: false; error: string }

export function validateRfidTag(raw: string | null | undefined): RfidTagValidation {
  const tag = normalizeRfidTag(String(raw ?? ''))
  if (tag.length < RFID_TAG_MIN_LENGTH) return { ok: false, error: 'RFID curto demais.' }
  if (tag.length > RFID_TAG_MAX_LENGTH) return { ok: false, error: 'RFID longo demais.' }
  if (!/^[A-Z0-9]+$/.test(tag)) {
    return { ok: false, error: 'RFID deve conter apenas letras e números.' }
  }
  return { ok: true, tag }
}

export function tagAlreadyBoundError(codigoInterno: string) {
  return `RFID já vinculado à unidade ${codigoInterno}.`
}
