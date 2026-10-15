export const LOGIN_PATH = '/login'

type DataMode = 'real' | 'auto' | 'demo'

function envFlag(value: string | undefined) {
  if (!value) return null
  const normalized = value.trim().toLowerCase()
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false
  return null
}

function resolveDataMode(env: Record<string, string | undefined>): DataMode {
  const raw = env.MMD_DATA_MODE ?? env.NEXT_PUBLIC_MMD_DATA_MODE
  if (raw === 'real' || raw === 'auto' || raw === 'demo') return raw

  const legacy = envFlag(env.MMD_DEMO_FALLBACK)
  if (legacy === true) return 'auto'
  if (legacy === false) return 'real'

  if (env.VERCEL === '1' || env.NODE_ENV === 'production') return 'real'
  return 'auto'
}

const protectedPrefixes = [
  '/config',
  '/ficha-evento',
  '/items',
  '/projetos',
  '/qrcodes',
  '/rfid',
]

export function isPublicRoute(pathname: string) {
  return pathname === LOGIN_PATH || pathname.startsWith('/s/')
}

export function isProtectedInternalPath(pathname: string) {
  if (pathname === '/') return true
  return protectedPrefixes.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
  )
}

export function isAuthRequiredForEnv(env: Record<string, string | undefined> = process.env) {
  const explicit = env.MMD_REQUIRE_AUTH ?? env.NEXT_PUBLIC_MMD_REQUIRE_AUTH
  const parsed = envFlag(explicit)
  if (parsed != null) return parsed

  return resolveDataMode(env) === 'real'
}

export function sanitizeNextPath(raw: string | null | undefined) {
  if (!raw || !raw.startsWith('/') || raw.startsWith('//')) return '/'
  if (raw.startsWith('/login') || raw.startsWith('/s/')) return '/'
  return raw
}

export function normalizeLoginIdentifier(raw: string | null | undefined) {
  const identifier = String(raw ?? '').trim().toLowerCase()
  if (!identifier) return ''
  if (identifier.includes('@')) return identifier
  if (!/^[a-z0-9._-]+$/.test(identifier)) return identifier
  return `${identifier}@mmd.local`
}

export function loginRedirectPath(pathname: string, search = '') {
  const next = sanitizeNextPath(`${pathname}${search}`)
  return `${LOGIN_PATH}?next=${encodeURIComponent(next)}`
}
