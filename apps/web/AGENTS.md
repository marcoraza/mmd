<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes. APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.

<!-- END:nextjs-agent-rules -->

# apps/web, guia pra agente

Web app do MMD Estoque Inteligente. Next.js 16 App Router, React 19 + React Compiler, Tailwind v4, Liquid Glass 2030. A seção acima é gerenciada pelo Next, não edite. O que segue é o contexto do projeto.

Antes de tocar UI do PRD MAR-171, leia `../../docs/mar-171-agent-brief.md`.

## Stack real

| Camada         | Versão        | Notas                                                                                                                                                                                          |
| -------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Next.js        | 16.2.2        | App Router only, Turbopack default (`next build`), sem `pages/`.                                                                                                                               |
| React          | 19.2.4        | Server Components default, Server Actions, React Compiler ativo.                                                                                                                               |
| React Compiler | 19.1.0-rc.2   | `reactCompiler: true` em `next.config.ts` (top-level, não em `experimental`). `babel-plugin-react-compiler` instalado. ESLint rule `react-compiler/react-compiler` enforcing.                  |
| Tailwind       | v4            | CSS-first via `@theme`, sem `tailwind.config.js`. Tokens em `src/app/globals.css`.                                                                                                             |
| TypeScript     | 5.x           | Estrito. `tsc --noEmit` roda no CI antes do build.                                                                                                                                             |
| ESLint         | 9 flat config | `eslint.config.mjs` com `defineConfig` + `globalIgnores`. `eslint-config-next` (core-web-vitals + typescript), `eslint-plugin-jsx-a11y` (recommended), `eslint-plugin-react-compiler` (error). |
| Prettier       | 3.x           | `.prettierrc.json` na raiz de `apps/web`. Scripts `npm run format` e `npm run format:check`. Sem `prettier-plugin-tailwindcss`.                                                                |
| Supabase JS    | 2.x           | Cliente e server helpers em `src/lib/`. RLS e grants fazem parte do gate de produção real. Não mexa em Supabase sem alinhar com o supervisor.                                                   |

Sem shadcn/ui. Sem Radix. Sem cva. Sem framer-motion. Componentes base vivem em `src/components/mmd/Primitives.tsx`.

## Estrutura

```
apps/web/
├── .prettierrc.json         # Prettier (sem plugin Tailwind)
├── eslint.config.mjs        # Flat config, jsx-a11y + react-compiler
├── next.config.ts           # reactCompiler top-level
├── public/handoff/          # Mocks de design (JSX standalone, ignorados pelo lint)
├── src/
│   ├── app/                 # App Router (rotas, layout, globals.css)
│   ├── components/
│   │   ├── mmd/             # Primitives.tsx, SideRail, base do Liquid Glass
│   │   ├── catalog/         # CatalogClient, ItemTable, EditableStars, EditableQty
│   │   ├── config/          # ConfigClient
│   │   ├── dashboard/       # ReadinessCluster, UpcomingEventsRail, KPIs
│   │   ├── item-detail/     # ItemDetailClient, KpiCard, TimelineStream, UnitDrawer
│   │   ├── lotes/           # LotesBanner, LoteDetailClient
│   │   ├── projects/        # ProjectsClient + detail/ (CheckinDialog, CheckoutDialog, AllocationTab)
│   │   ├── qrcodes/         # QrCodesClient, PreviewSheet
│   │   └── rfid/            # RfidClient, ReaderCard, ScanTimeline
│   ├── hooks/               # useStoredState, useCatalogView, useUnitsView, useRealtimeRefresh
│   └── lib/                 # supabase.ts, cn.ts, actions/, data/, item-label.ts, nomenclature.ts
└── package.json
```

Mocks do design ficam em `public/handoff/components/*.jsx`. São referência visual, não fazem parte do build. Estão no `globalIgnores` do ESLint.

Evidências visuais do PRD ficam em `../../tasks/evidence/mar-XXX/`. Esses arquivos são referência, imagegen ou screenshot de QA. Não trate como front-end paralelo.

## Design system

Liquid Glass 2030. Fonte de verdade atual: `src/components/mmd/Primitives.tsx`, `src/app/globals.css`, `public/handoff/` e o briefing `../../docs/mar-171-agent-brief.md`. Tokens em oklch, definidos em `src/app/globals.css` como CSS custom properties (`--bg-0`, `--fg-0`, `--accent-cyan`, `--glass-bg`, etc). Dark via `:root.dark`. Iniciado por script inline no `layout.tsx` lendo `localStorage['mmd-theme']`.

Primitives oficiais ficam em `src/components/mmd/Primitives.tsx`. Reuse antes de criar variante nova.

## Convenções

- Server Components por padrão. `"use client"` só onde precisa.
- Server Actions pra mutação. Após action, `router.refresh()` no client se a UI depende de dados que o action mudou.
- Componente client com estado de UI: nunca `useEffect` só pra reagir a prop. Set state durante render ou derive em variável.
- Produto fala `Evento`, mesmo que rotas e modelos internos ainda usem `projetos`.
- UI pública de QR não pode exibir valor, serial de fábrica, RFID, localização ou histórico.
- Cabos são unidades rastreáveis. Lotes são legado e não devem voltar como fluxo operacional.
- Não use em-dash (U+2014) em copy, texto de UI, mensagem de erro voltada pro usuário ou commit. Vírgula, parênteses, dois pontos resolvem.
- Imports de tipos: `import type { ... } from '...'`. Mantém bundle limpo.
- Classes Tailwind: combine via `cn()` (clsx + tailwind-merge). Helper em `src/lib/cn.ts`.

## Não faça

- Instalar shadcn/ui, Radix, framer-motion. O design system é próprio.
- Criar um app, layout ou rota paralela para uma função que já existe.
- Transformar screenshot ou imagegen em produto separado.
- Mudar migration, RLS, RPC ou contrato de API como parte de tarefa visual.
- Adicionar `experimental.reactCompiler` em `next.config.ts`. Em Next 16 a flag é top-level.
- Mexer em `public/handoff/` sem uma razão explícita de design handoff. É referência, não código de produção.
- Ignorar warning de `react-compiler/react-compiler`. Padrão incompatível com Compiler é bug, não estilo.
- Skip de hook (`--no-verify`, `--no-gpg-sign`). Resolva o que o hook reclamou.

## CI

`.github/workflows/ci.yml` roda em push pra `main` e em PR pra `main`, na ordem:

1. `npx tsc --noEmit` (type check).
2. `npx eslint . --max-warnings=0` (lint, ativado em W2). Quebra build em erro ou warning.
3. `npx next build` (Turbopack, mesmo bundler do script local).

Deploy é Vercel, configurado fora do repo. O workflow do GitHub Actions só roda gates, não publica nada. Workflow antigo `pages.yml` (que mandava artifact pra GitHub Pages mesmo com SSR ativo, deploy quebrado) foi removido em W2.

Prettier ainda não é gate de CI. Roda local via `npm run format:check`.

Bundler: Turbopack em local e em CI desde W2. Webpack saiu do script depois de visual diff confirmando paridade nas 5 páginas principais (ver `tasks/auditoria-frontend/w2-visual-diff-webpack-turbopack.md`). Se aparecer bug específico do Turbopack, fallback manual: `npx next build --webpack`.

## Dispositivos alvo

- iPhone (campo, galpão). RFID via Zebra RFD40 emulando teclado. Cuidado com focus trap, pode capturar input que é do leitor.
- Mac (gestão, escritório). Layout responsivo, sidebar persistente.

## Onde olhar pra cada coisa

- Componente novo: `src/components/mmd/Primitives.tsx` primeiro, depois pasta do domínio.
- Token de cor, raio, motion: `src/app/globals.css`.
- Schema de banco: `supabase/migrations/`.
- Decisão de produto: `CLAUDE.md` da raiz.
- Briefing operacional do PRD atual: `../../docs/mar-171-agent-brief.md`.
- Tracker supervisor: `../../tasks/mar-171-supervisor.md`.
- Evidências visuais por issue: `../../tasks/evidence/mar-XXX/`.
- Auditoria, débito técnico, roadmap por W: `tasks/auditoria-frontend/RELATORIO-FINAL.md`.
- CI: `.github/workflows/ci.yml`. Deploy: Vercel (fora do repo).
