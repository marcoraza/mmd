import { signInWithPasswordAction } from '@/lib/auth-actions'
import { sanitizeNextPath } from '@/lib/auth-config'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

const MENSAGENS: Record<string, string> = {
  missing: 'Informe usuário e senha.',
  invalid: 'Usuário ou senha inválidos.',
}

// Formulário sem design system: a UI 2.0 é a fase 7. Aqui basta um caminho de
// login real para o cookie SSR existir.
export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string; error?: string }>
}) {
  const params = await searchParams
  const next = sanitizeNextPath(params.next)
  const erro = params.error ? (MENSAGENS[params.error] ?? 'Não foi possível entrar.') : null

  return (
    <main style={{ maxWidth: '22rem' }}>
      <h1 style={{ margin: 0 }}>EventPro</h1>
      <p>Acesso interno.</p>

      <form action={signInWithPasswordAction} style={{ display: 'grid', gap: '0.75rem' }}>
        <input type="hidden" name="next" value={next} />

        <label style={{ display: 'grid', gap: '0.25rem' }}>
          Usuário ou e-mail
          <input name="email" type="text" autoComplete="username" required />
        </label>

        <label style={{ display: 'grid', gap: '0.25rem' }}>
          Senha
          <input name="password" type="password" autoComplete="current-password" required />
        </label>

        <button type="submit">Entrar</button>
      </form>

      {erro ? <p role="alert">{erro}</p> : null}
    </main>
  )
}
