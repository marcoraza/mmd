import { envFlag } from './env-flag.ts'

export const LOGIN_PATH = '/login'

// Domínio usado para transformar apelido de operador em e-mail de login.
// Mantido como parâmetro para o dia em que a operação tiver domínio próprio.
export const DEFAULT_LOGIN_DOMAIN = 'eventpro.local'

// No legado a lista refletia as rotas do web. O EventPro ainda não tem UI de
// produto (fase 7), então só `/` e as rotas de API existem; a lista volta a
// crescer junto com a UI 2.0.
const protectedPrefixes: string[] = []

export function isPublicRoute(pathname: string) {
  return pathname === LOGIN_PATH || pathname.startsWith('/s/')
}

export function isProtectedInternalPath(pathname: string) {
  if (pathname === '/') return true
  return protectedPrefixes.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
  )
}

// Risco 5.2 da auditoria: no legado, `MMD_REQUIRE_AUTH=false` (ou simplesmente
// a ausência de configuração fora de produção) devolvia admin local sem
// nenhuma verificação, e qualquer chamada anônima executava check-out real.
//
// No EventPro auth é SEMPRE exigida. A única exceção é o bypass explícito de
// desenvolvimento: `EVENTPRO_DEV_BYPASS_AUTH=true` **e** `NODE_ENV=development`
// juntos. Nem staging nem produção conseguem ligar isso por engano, porque
// `NODE_ENV` é `production` no build do Next.
export function isAuthRequiredForEnv(env: Record<string, string | undefined> = process.env) {
  return !isDevAuthBypassEnabled(env)
}

export function isDevAuthBypassEnabled(env: Record<string, string | undefined> = process.env) {
  if (env.NODE_ENV !== 'development') return false
  return envFlag(env.EVENTPRO_DEV_BYPASS_AUTH) === true
}

export function sanitizeNextPath(raw: string | null | undefined) {
  if (!raw || !raw.startsWith('/') || raw.startsWith('//')) return '/'
  if (raw.startsWith('/login') || raw.startsWith('/s/')) return '/'
  return raw
}

export function normalizeLoginIdentifier(
  raw: string | null | undefined,
  domain: string = DEFAULT_LOGIN_DOMAIN,
) {
  const identifier = String(raw ?? '')
    .trim()
    .toLowerCase()
  if (!identifier) return ''
  if (identifier.includes('@')) return identifier
  if (!/^[a-z0-9._-]+$/.test(identifier)) return identifier
  return `${identifier}@${domain}`
}

export function loginRedirectPath(pathname: string, search = '') {
  const next = sanitizeNextPath(`${pathname}${search}`)
  return `${LOGIN_PATH}?next=${encodeURIComponent(next)}`
}
