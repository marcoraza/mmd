import 'server-only'

import { envFlag } from '@/lib/env-flag'

// Risco 5.4 da auditoria: no legado `isWriteBlocked()` devolvia `true` quando
// `MMD_READONLY` não estava explicitamente desligada, então qualquer deploy sem
// a variável respondia 400 em toda escrita, sem sinal óbvio de causa.
//
// No EventPro o default é `false`: somente leitura é um modo que alguém liga de
// propósito (`EVENTPRO_READONLY=true`, por exemplo durante a janela de migração
// da fase 5), nunca um estado acidental. Não existe modo demo.
export function isReadonlyMode(env: Record<string, string | undefined> = process.env) {
  return envFlag(env.EVENTPRO_READONLY) ?? false
}

export function isWriteBlocked() {
  return isReadonlyMode()
}

export const READONLY_ERROR = 'Modo somente leitura: alterações não são salvas.'

export type ActionResult<T = void> = { ok: true; data: T } | { ok: false; error: string }

export function blockWrite<T = void>(): ActionResult<T> | null {
  if (!isWriteBlocked()) return null
  return { ok: false, error: READONLY_ERROR }
}
