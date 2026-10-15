export type UserRole = 'viewer' | 'editor' | 'admin'

const ROLE_RANK: Record<UserRole, number> = {
  viewer: 0,
  editor: 1,
  admin: 2,
}

export function normalizeUserRole(role: string | null | undefined): UserRole {
  if (role === 'admin' || role === 'editor' || role === 'viewer') return role
  return 'viewer'
}

export function roleAllows(actual: UserRole, required: UserRole) {
  return ROLE_RANK[actual] >= ROLE_RANK[required]
}

export function actionDeniedMessage(required: UserRole) {
  if (required === 'admin') return 'Ação restrita ao usuário admin.'
  if (required === 'editor') return 'Ação restrita à equipe operacional.'
  return 'Acesso interno: faça login novamente.'
}

export function extractBearerToken(raw: string | null | undefined) {
  const match = raw?.match(/^Bearer\s+(.+)$/i)
  return match?.[1]?.trim() || null
}

export function operatorLabel(profile: {
  nome?: string | null
  email?: string | null
  fallbackEmail?: string | null
  fallbackId?: string | null
}) {
  return (
    profile.nome?.trim() ||
    profile.email?.trim() ||
    profile.fallbackEmail?.trim() ||
    profile.fallbackId?.trim() ||
    'Usuário MMD'
  )
}
