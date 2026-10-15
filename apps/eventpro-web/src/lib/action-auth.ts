import 'server-only'

import type { User } from '@supabase/supabase-js'
import { isDevAuthBypassEnabled } from '@/lib/auth-config'
import {
  actionDeniedMessage,
  extractBearerToken,
  normalizeUserRole,
  operatorLabel,
  roleAllows,
  type UserRole,
} from '@/lib/action-auth-core'
import { getVerifiedUser } from '@/lib/supabase-ssr'
import { supabaseAdmin } from '@/lib/supabase-server'

export type ActionAuthContext = {
  userId: string | null
  email: string | null
  role: UserRole
  registradoPor: string
  authRequired: boolean
}

export type ActionAuthResult = { ok: true; data: ActionAuthContext } | { ok: false; error: string }

type ProfileRow = {
  nome: string | null
  email: string | null
  role: string | null
}

export const UNAUTHENTICATED_ERROR = 'Acesso interno: faça login novamente.'

let bypassWarned = false

// Fallback de admin local. No legado ele era o caminho padrão sempre que
// `MMD_REQUIRE_AUTH` estava ausente ou desligada (risco 5.2 da auditoria): uma
// chamada anônima executava check-out real. Aqui só existe com
// `EVENTPRO_DEV_BYPASS_AUTH=true` E `NODE_ENV=development`, e avisa em log.
function devBypassAuth(): ActionAuthResult {
  if (!bypassWarned) {
    bypassWarned = true
    console.warn(
      '[eventpro-auth] EVENTPRO_DEV_BYPASS_AUTH ativo em desenvolvimento: as rotas estão ' +
        'respondendo como admin local, sem verificar credencial. Nunca use isso fora da máquina de dev.',
    )
  }

  return {
    ok: true,
    data: {
      userId: null,
      email: null,
      role: 'admin',
      registradoPor: process.env.EVENTPRO_LOCAL_OPERATOR?.trim() || 'Dev EventPro',
      authRequired: false,
    },
  }
}

async function authorizeVerifiedUser(
  user: User,
  requiredRole: UserRole,
): Promise<ActionAuthResult> {
  const { data: profile, error } = await supabaseAdmin
    .from('profiles')
    .select('nome, email, role')
    .eq('id', user.id)
    .maybeSingle()

  if (error) return { ok: false, error: error.message }

  const profileRow = (profile ?? null) as ProfileRow | null
  const role = normalizeUserRole(profileRow?.role)
  if (!roleAllows(role, requiredRole)) {
    return { ok: false, error: actionDeniedMessage(requiredRole) }
  }

  return {
    ok: true,
    data: {
      userId: user.id,
      email: profileRow?.email ?? user.email ?? null,
      role,
      registradoPor: operatorLabel({
        nome: profileRow?.nome,
        email: profileRow?.email,
        fallbackEmail: user.email,
        fallbackId: user.id,
      }),
      authRequired: true,
    },
  }
}

// Caminho de cookie SSR (web). Usado direto pelas Server Actions e como fallback
// de `requireRequestUser` quando não vem header Authorization.
export async function requireActionUser(
  requiredRole: UserRole = 'viewer',
): Promise<ActionAuthResult> {
  if (isDevAuthBypassEnabled()) return devBypassAuth()

  const user = await getVerifiedUser()
  if (!user) return { ok: false, error: UNAUTHENTICATED_ERROR }

  return authorizeVerifiedUser(user, requiredRole)
}

// Caminho HTTP: aceita `Authorization: Bearer <jwt>` (iOS) e, na ausência dele,
// cai para o cookie SSR (web). Contrato §1.3.
export async function requireRequestUser(
  req: Request,
  requiredRole: UserRole = 'viewer',
): Promise<ActionAuthResult> {
  if (isDevAuthBypassEnabled()) return devBypassAuth()

  const token = extractBearerToken(req.headers.get('authorization'))
  if (!token) return requireActionUser(requiredRole)

  const {
    data: { user },
    error,
  } = await supabaseAdmin.auth.getUser(token)

  if (error || !user) return { ok: false, error: UNAUTHENTICATED_ERROR }

  return authorizeVerifiedUser(user, requiredRole)
}
