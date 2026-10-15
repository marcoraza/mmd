export type DataMode = 'real' | 'auto' | 'demo'

export type DataModeEnv = {
  MMD_DATA_MODE?: string
  NEXT_PUBLIC_MMD_DATA_MODE?: string
  MMD_DEMO_FALLBACK?: string
  VERCEL?: string
  NODE_ENV?: string
}

export function envFlag(value: string | undefined) {
  if (!value) return null
  const normalized = value.trim().toLowerCase()
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false
  return null
}

export function resolveDataMode(env: DataModeEnv): DataMode {
  const raw = env.MMD_DATA_MODE ?? env.NEXT_PUBLIC_MMD_DATA_MODE
  if (raw === 'real' || raw === 'auto' || raw === 'demo') return raw

  const legacy = envFlag(env.MMD_DEMO_FALLBACK)
  if (legacy === true) return 'auto'
  if (legacy === false) return 'real'

  if (env.VERCEL === '1' || env.NODE_ENV === 'production') return 'real'

  return 'auto'
}
