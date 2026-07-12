'use server'

import { redirect } from 'next/navigation'
import { LOGIN_PATH, normalizeLoginIdentifier, sanitizeNextPath } from '@/lib/auth-config'
import { createSupabaseCookieClient } from '@/lib/supabase-ssr'

function loginErrorPath(error: string, next: string) {
  return `${LOGIN_PATH}?error=${encodeURIComponent(error)}&next=${encodeURIComponent(next)}`
}

export async function signInWithPasswordAction(formData: FormData) {
  const email = normalizeLoginIdentifier(String(formData.get('email') ?? ''))
  const password = String(formData.get('password') ?? '')
  const next = sanitizeNextPath(String(formData.get('next') ?? '/'))

  if (!email || !password) redirect(loginErrorPath('missing', next))

  const supabase = await createSupabaseCookieClient()
  const { error } = await supabase.auth.signInWithPassword({ email, password })

  if (error) redirect(loginErrorPath('invalid', next))
  redirect(next)
}

export async function signOutAction() {
  const supabase = await createSupabaseCookieClient()
  await supabase.auth.signOut()
  redirect(LOGIN_PATH)
}
