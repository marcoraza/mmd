'use client'

import { useSyncExternalStore } from 'react'

/**
 * Hook compartilhado pra estado persistido em window.localStorage, compatível
 * com React Compiler (sem useEffect+setState de hidratação, que vira "cascading
 * render"). Usa useSyncExternalStore com server snapshot estável para evitar
 * hydration mismatch no SSR do App Router.
 *
 * Cache em módulo garante estabilidade referencial: getSnapshot retorna o mesmo
 * objeto enquanto o raw do localStorage não muda. Sem isso, React entra em
 * loop achando que o store mudou a cada render.
 */
type CacheEntry = { raw: string | null; value: unknown }
const cache = new Map<string, CacheEntry>()

function readRaw(key: string): string | null {
  if (typeof window === 'undefined') return null
  try {
    return window.localStorage.getItem(key)
  } catch {
    return null
  }
}

function subscribe(key: string, callback: () => void): () => void {
  const handler = (e: StorageEvent) => {
    if (e.key === key || e.key === null) callback()
  }
  window.addEventListener('storage', handler)
  return () => window.removeEventListener('storage', handler)
}

/**
 * Cria um par [snapshot, setter] vinculado a uma chave de localStorage.
 *
 * @param key chave no localStorage.
 * @param defaultValue valor inicial usado no SSR e quando a leitura falha.
 * @param decode parseia o raw string em T. Default: JSON.parse + cast.
 * @param encode serializa T em raw string. Default: JSON.stringify. Use identidade
 *               quando outro código (script inline, etc) já lê em formato cru.
 */
export function useStoredState<T>(
  key: string,
  defaultValue: T,
  decode: (raw: string) => T = (raw) => JSON.parse(raw) as T,
  encode: (value: T) => string = (value) => JSON.stringify(value),
): [T, (next: T) => void] {
  const getSnapshot = (): T => {
    const raw = readRaw(key)
    const cached = cache.get(key)
    if (cached && cached.raw === raw) return cached.value as T

    let value: T
    if (raw === null) {
      value = defaultValue
    } else {
      try {
        value = decode(raw)
      } catch {
        value = defaultValue
      }
    }
    cache.set(key, { raw, value })
    return value
  }

  const getServerSnapshot = (): T => defaultValue

  const value = useSyncExternalStore(
    (callback) => subscribe(key, callback),
    getSnapshot,
    getServerSnapshot,
  )

  const setValue = (next: T): void => {
    if (typeof window === 'undefined') return
    try {
      const raw = encode(next)
      window.localStorage.setItem(key, raw)
      cache.set(key, { raw, value: next })
      // O evento nativo 'storage' só dispara em outras abas. Disparamos manual
      // para que o subscribe da própria aba também receba o update.
      window.dispatchEvent(new StorageEvent('storage', { key }))
    } catch {
      // localStorage cheio, modo privado, etc. Ignora silenciosamente.
    }
  }

  return [value, setValue]
}
