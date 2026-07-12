# E3: App Router

## Estrutura de Rotas

```
apps/web/src/app/
├── api/
│   └── qr-sheet/route.ts       (API Route)
├── config/
│   └── page.tsx                (Server Component)
├── items/
│   ├── page.tsx                (Server Component - lista catalogo)
│   └── [id]/page.tsx           (Server Component - detalhe item)
├── lotes/
│   ├── page.tsx                (Server Component)
│   └── [id]/page.tsx           (Server Component)
├── projetos/
│   ├── page.tsx                (Server Component)
│   └── [id]/page.tsx           (Server Component)
├── qrcodes/
│   └── page.tsx                (Server Component)
├── rfid/
│   └── page.tsx                (Server Component)
├── favicon.ico
├── globals.css
├── layout.tsx                  (Root Layout - Server)
└── page.tsx                    (Dashboard - Server Component)
```

## Analise do App Router

### Layout Raiz (`apps/web/src/app/layout.tsx`)

Verifiquei: Server Component correto.
- `next/font/google` - Inter_Tight, JetBrains_Mono, Instrument_Serif com `display: 'swap'`
- Script de tema inline (anti-flash): `dangerouslySetInnerHTML={{ __html: themeInitScript }}` - solucao manual funcional
- `lang="pt-BR"` no html - correto
- `id="main-content"` no main - bom para skip links (mas skip link ausente)
- Inclui `<SideRail />` no layout (Client Component por `usePathname`)

### Paginas como RSC (Verifiquei)

Todas as pages sao Server Components por padrao. Padrao consistente:
1. RSC async carrega dados via funcoes `load*` (ex: `loadDashboard()`, `loadCatalog()`)
2. Passa dados como props para Client Component
3. Wrapa com `<Suspense>` para loading states

Exemplo do padrao (page.tsx padrao):
```tsx
async function DashboardContent() {  // RSC async
  const data = await loadDashboard()
  return <ClientComponent data={data} />
}
export default function Page() {
  return <Suspense fallback={<Skeleton />}><DashboardContent /></Suspense>
}
```

Este padrao e correto e moderno.

### Server Actions (`apps/web/src/lib/actions/`)

Verifiquei dois arquivos:
- `projetos.ts` - `'use server'` correto, usa `revalidatePath` apos mutacoes
- `movimentacoes.ts` - inferido ter o mesmo padrao

Server Actions usadas para:
- `createProjeto`, `deleteProjeto`, `updateProjetoStatus`
- `checkinProject`, `checkoutProject`

Uso correto: chamados via `startTransition` nos Client Components (ex: `CheckinDialog.tsx`, `AllocationTab.tsx`)

### Data Fetching

- Dados buscados em RSC via Supabase server client (`supabase-server.ts` com `server-only`)
- Nao ha TanStack Query nem SWR
- Revalidacao via `revalidatePath` apos Server Actions
- `loadDashboard()`, `loadCatalog()`, `loadProjects()` etc em `src/lib/data/`

### Suspense Boundaries

Verifiquei `Suspense` em todas as pages:
- `page.tsx` (dashboard): `<Suspense fallback={<DashboardSkeleton />}>`
- `items/page.tsx`: `<Suspense fallback={<CatalogFallback />}>`
- `projetos/page.tsx`: `<Suspense fallback={<ProjectsFallback />}>`

CatalogFallback e ProjectsFallback sao apenas texto simples (nao skeleton). Apenas Dashboard tem skeleton real.

### API Routes

- `api/qr-sheet/route.ts` - gera PDF de QR codes via `@react-pdf/renderer`
- Inferencia: endpoint chamado pelo `QrCodesClient.tsx` para exportar

### Streaming

Inferencia: Suspense esta presente mas streaming granular nao esta sendo aproveitado - cada pagina tem apenas um boundary por RSC de dados.

## Issues

| Issue | Severidade | Evidencia |
|---|---|---|
| Fallbacks de loading sao texto simples, nao skeleton | Baixa | `items/page.tsx`, `projetos/page.tsx` |
| Sem Parallel Routes para tabs (ProjectDetail usa state no client) | Baixa | `projects/detail/ProjectDetailClient.tsx` linha 35 |
| Sem Intercepting Routes para modals | Baixa | Modais gerenciados via estado local |
| Skip link presente no `main#main-content` mas sem `<a href="#main-content">` | Media | `layout.tsx` |
| `Instrument_Serif` importada mas aparentemente nao usada no CSS | Baixa | `layout.tsx` linha 8 |
