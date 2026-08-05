import 'server-only'
import { createClient } from '@supabase/supabase-js'

function createSupabaseAdminClient(url: string, serviceKey: string) {
  return createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}

type SupabaseAdminClient = ReturnType<typeof createSupabaseAdminClient>

let cachedClient: SupabaseAdminClient | null = null

export function getSupabaseAdmin(): SupabaseAdminClient {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

  if (!url || !serviceKey) {
    throw new Error(
      'Supabase server credentials missing: NEXT_PUBLIC_SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY',
    )
  }

  cachedClient ??= createSupabaseAdminClient(url, serviceKey)
  return cachedClient
}

// Proxy preguiçoso: o cliente só é construído na primeira propriedade lida, para
// o build do Next não exigir credencial de service role em tempo de compilação.
export const supabaseAdmin = new Proxy({} as SupabaseAdminClient, {
  get(_target, prop, receiver) {
    const client = getSupabaseAdmin()
    const value = Reflect.get(client, prop, receiver)
    return typeof value === 'function' ? value.bind(client) : value
  },
})
