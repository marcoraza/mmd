import 'server-only'

import type { User } from '@supabase/supabase-js'
import { isAuthRequiredForEnv } from '@/lib/auth-config'
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

export type ActionAuthResult =
  | { ok: true; data: ActionAuthContext }
  | { ok: false; error: string }

type ProfileRow = {
  nome: string | null
  email: string | null
  role: string | null
}

function localAdminAuth(): ActionAuthResult {
  return {
    ok: true,
    data: {
      userId: null,
      email: null,
      role: 'admin',
      registradoPor: process.env.MMD_LOCAL_OPERATOR?.trim() || 'Marco',
      authRequired: false,
    },
  }
}

async function authorizeVerifiedUser(user: User, requiredRole: UserRole): Promise<ActionAuthResult> {
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

export async function requireActionUser(requiredRole: UserRole = 'viewer'): Promise<ActionAuthResult> {
  if (!isAuthRequiredForEnv()) return localAdminAuth()

  const user = await getVerifiedUser()
  if (!user) return { ok: false, error: 'Acesso interno: faça login novamente.' }

  return authorizeVerifiedUser(user, requiredRole)
}

export async function requireRequestUser(
  req: Request,
  requiredRole: UserRole = 'viewer',
): Promise<ActionAuthResult> {
  if (!isAuthRequiredForEnv()) return localAdminAuth()

  const token = extractBearerToken(req.headers.get('authorization'))
  if (!token) return requireActionUser(requiredRole)

  const {
    data: { user },
    error,
  } = await supabaseAdmin.auth.getUser(token)

  if (error || !user) return { ok: false, error: 'Acesso interno: faça login novamente.' }

  return authorizeVerifiedUser(user, requiredRole)
}
