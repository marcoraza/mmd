import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'
import { isAuthRequiredForEnv, isProtectedInternalPath, loginRedirectPath } from '@/lib/auth-config'

export async function proxy(request: NextRequest) {
  const pathname = request.nextUrl.pathname

  if (!isAuthRequiredForEnv() || !isProtectedInternalPath(pathname)) {
    return NextResponse.next()
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!url || !anonKey) {
    const loginUrl = new URL(loginRedirectPath(pathname, request.nextUrl.search), request.url)
    return NextResponse.redirect(loginUrl)
  }

  let response = NextResponse.next({ request })
  const supabase = createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
        response = NextResponse.next({ request })
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options),
        )
      },
    },
  })

  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    const loginUrl = new URL(loginRedirectPath(pathname, request.nextUrl.search), request.url)
    return NextResponse.redirect(loginUrl)
  }

  response.headers.set('Cache-Control', 'private, no-store')
  return response
}

// As rotas de API fazem a própria verificação (`requireRequestUser`), aceitando
// Bearer do iOS. O proxy cobre só a superfície navegável, que nesta fase é a
// raiz. A lista cresce junto com a UI 2.0 (fase 7).
export const config = {
  matcher: ['/'],
}
