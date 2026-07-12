import 'server-only'

import { envFlag, resolveDataMode, type DataMode } from '@/lib/data/demo-mode-core'

export { envFlag, type DataMode }

export function getDataMode(): DataMode {
  return resolveDataMode(process.env)
}

export function isDemoFallbackEnabled() {
  const mode = getDataMode()
  return mode === 'auto' || mode === 'demo'
}

export function isWriteBlocked() {
  if (getDataMode() === 'demo') return true
  return envFlag(process.env.MMD_READONLY) ?? true
}

export async function withDemoFallback<T>(
  scope: string,
  loadReal: () => Promise<T>,
  loadDemo: () => T,
): Promise<T> {
  const mode = getDataMode()
  if (mode === 'demo') return loadDemo()

  try {
    return await loadReal()
  } catch (error) {
    if (mode !== 'auto') throw error
    console.warn(`[mmd-demo] ${scope} usando dados demo`, error)
    return loadDemo()
  }
}
