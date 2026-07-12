# Auditoria de Frontend MMD Eventos - Rascunho do Relatório

**Data:** 2026-05-25
**Stack auditada:** Next.js 16.2.2 + React 19.2.4 + Tailwind v4 + TypeScript 5 + ESLint 9
**Escopo:** apps/web/ (read-only, nenhum código alterado)

---

## 1. Resumo Executivo

### Top 3 Críticos

- **Dialogs sem focus trap**: 5 componentes (ConflictModal, CheckinDialog, CheckoutDialog, ItemSidePanel, UnitDrawer) permitem que o usuário de teclado escape do modal para o conteúdo de fundo. Violação WCAG 2.1.2. Evidência: `ConflictModal.tsx:56`, `CheckinDialog.tsx:50`.
- **CI sem lint nem typecheck**: o pipeline de CI executa apenas build e deploy. Código com erro de TypeScript ou violação de lint chega à produção sem barreira. Evidência: `.github/workflows/pages.yml`.
- **906 inline styles vs 246 classes Tailwind**: o projeto usa CSS vars via `style={{}}` como padrão, subvertendo o modelo de utility classes do Tailwind v4. Purge ineficaz, sem IntelliSense de constraints, sem variantes padronizadas. Evidência: contagem em `apps/web/src/`.

### Top 3 Quick Wins

- **Ativar React Compiler** (1 linha no `next.config.ts`): elimina necessidade de `useMemo`/`useCallback` manuais em todo o projeto sem quebrar nada.
- **Adicionar `tsc --noEmit` e `eslint .` ao CI**: fecha a porta para erros de tipo e lint chegarem à produção. Esforço: 10 minutos.
- **Adicionar skip link em `layout.tsx`**: uma linha de HTML resolve WCAG 2.4.1 (Bypass Blocks) para todos os usuários de teclado.

### Recomendação Geral

**Manter e refinar, não migrar.** A arquitetura RSC + Server Actions + Supabase é correta para o escopo. O design system Liquid Glass está implementado com fidelidade razoável. Os problemas são de tooling e polish, não de arquitetura. Para o contrato R$3k/3 meses com foco operacional, a estratégia é fechar os gaps críticos de acessibilidade e CI esta semana, e endereçar os gaps de Tailwind/tokens de forma incremental.

---

## 2. Mapa do Projeto

### Stack Real (Verifiquei)

| Componente | Versão Real | Declarada no CLAUDE.md |
|---|---|---|
| Next.js | 16.2.2 | 14 (DESALINHADO) |
| React | 19.2.4 | - |
| Tailwind CSS | ^4 | - |
| TypeScript | ^5 | correto |
| ESLint | ^9 (flat config) | - |
| shadcn/ui | **NÃO INSTALADO** | citado como stack |
| @radix-ui/* | **AUSENTE** | implícito via shadcn |

Inferência: o CLAUDE.md raiz declara "Next.js 14 + shadcn/ui" mas o projeto evoluiu para Next.js 16 + Tailwind v4 puro sem shadcn. A desatualização cria risco de agentes de IA gerarem código incompatível.

### Estrutura de Pastas

```
apps/web/src/
├── app/                  (rotas App Router, RSC por padrão)
│   ├── api/qr-sheet/     (API Route: geração de PDF QR)
│   ├── items/, lotes/, projetos/, qrcodes/, rfid/, config/
│   ├── globals.css       (tokens, design system, Tailwind entry)
│   └── layout.tsx        (root layout, fonts, tema)
├── components/
│   ├── mmd/              (Primitives.tsx, SideRail, TopBar, Icons)
│   ├── catalog/          (11 arquivos, todos 'use client')
│   ├── dashboard/        (6 arquivos, mix RSC/client)
│   ├── projects/detail/  (7 arquivos, todos 'use client')
│   ├── qrcodes/, rfid/, lotes/, item-detail/
│   └── config/
└── lib/
    ├── actions/          (Server Actions com 'use server')
    ├── data/             (funções de fetch para RSC)
    └── supabase-*.ts     (clients server/browser)
```

### Configs Chave

| Arquivo | Status |
|---|---|
| `next.config.ts` | `images: {unoptimized:true}`, Turbopack em dev, Webpack em build |
| `postcss.config.mjs` | `@tailwindcss/postcss` - correto para v4 |
| `tsconfig.json` | `strict: true`, `target: ES2017` (conservador) |
| `eslint.config.mjs` | flat config, só `next/core-web-vitals` + `next/typescript` |
| `.prettierrc` | AUSENTE |
| `husky` / `lint-staged` | AUSENTE |
| `components.json` (shadcn) | AUSENTE |
| `.cursor/rules/` | AUSENTE |

### Hotspots de Complexidade

| Componente | Motivo |
|---|---|
| `CatalogClient.tsx` | 200+ linhas, múltiplos useMemo/useCallback, anti-pattern de useEffect |
| `CheckinDialog.tsx` | Dialog sem focus trap, slider complexo de desgaste |
| `QrCodesClient.tsx` | 3 useMemos encadeados, geração de PDF |
| `ProjectListView.tsx` | Lógica complexa de sort e filtros |
| `ItemSidePanel.tsx` | Dialog sem focus trap, img nativa com eslint-disable |

---

## 3. Estado do Tailwind e Tema

### Versão e Config

- **Tailwind v4** confirmado: `@import "tailwindcss"`, `@theme {}`, `@tailwindcss/postcss`. Sem `tailwind.config.js` (correto para v4).
- **Uso real**: extremamente limitado. Ratio `style={{}}` vs `className=` = 906:246 (aprox 3.7:1). Tailwind é usado quase só para as classes custom definidas no próprio `globals.css` (`.glass`, `.caustic-bg`, `.skeleton`).

### Tokens (3 Camadas)

**Layer 1 (Primitives, `@theme`):** 5 cores OKLCH, 2 fontes, 4 radii. Esparso: sem escala de spacing, sem escala tipográfica, sem paleta de grays.

**Layer 2 (Semantic, `:root`):** ~30 tokens semanticos OKLCH para bg-*, fg-*, accent-*, glass-*. Dark mode via `.dark` em `<html>` - correto.

**Layer 3 (Component):** INEXISTENTE. Componentes acessam Layer 2 diretamente sem intermediação.

### OKLCH

Verifiquei: todas as cores primitivas e semânticas em OKLCH. Gap: tokens de glass (`--glass-bg`, `--glass-border`) ainda em `rgba()`. Overlays de modal hardcoded em `rgba(0,0,0,0.45)` em 5 componentes.

### Dark Mode

Implementação correta: script inline no `<head>` previne FOUC, `ThemeToggle` usa `mounted` para evitar hydration mismatch. Gap: sem `prefers-color-scheme` listener (OS preference ignorada na primeira visita).

### Inconsistência de Documentação

CLAUDE.md afirma "dark-first" mas CSS implementa light-first (`:root` é light, `:root.dark` é dark). Funciona, mas cria expectativa errada para agentes de IA que lerem a doc.

---

## 4. Diagnóstico por Categoria

### 4.1 Arquitetura React 19 / Next.js 16

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | `useEffect` para sincronizar estado com props em CatalogClient | Média | `CatalogClient.tsx:41-44` | Re-render desnecessário ao montar |
| 2 | `SideRail` como 'use client' para `usePathname` | Baixa | `SideRail.tsx:1` | Hydration de layout completo no cliente |
| 3 | Fallbacks de Suspense sem skeleton real em items/projetos | Baixa | `items/page.tsx`, `projetos/page.tsx` | UX degradada em conexões lentas |
| 4 | `Instrument_Serif` importada mas aparentemente sem uso | Baixa | `layout.tsx:8` | Bundle de fonte desnecessário |
| 5 | Server Actions sem tratamento de erro estruturado para o cliente | Média | `lib/actions/projetos.ts` | Erros silenciosos em mutações |

**Recomendações:**

| # | Ação | Esforço | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Remover `useEffect` + `setItems` de CatalogClient, usar `data.items` diretamente | Baixo | Baixo | `CatalogClient.tsx:41-44` |
| 2 | Adicionar skeleton para pages de items e projetos | Baixo | Baixo | `items/page.tsx`, `projetos/page.tsx` |
| 3 | Verificar e remover Instrument_Serif se não usada | Baixo | Baixo | `layout.tsx` |

### 4.2 Tailwind v4

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | Inline styles dominam (906x vs 246x className) | Alta | Contagem em `src/` | Tailwind ineficaz; purge não funciona para lógica de design |
| 2 | Sem `cn`/`clsx`/`tailwind-merge` | Alta | `package.json` - ausência | Concatenação manual frágil de classes |
| 3 | Sem `cva`/`tailwind-variants` para variantes | Alta | `package.json`, `Primitives.tsx` | PrimaryBtn e GhostBtn duplicados sem sistema de variants |
| 4 | Sem `eslint-plugin-tailwindcss` | Média | `eslint.config.mjs` | Sem detecção de classes conflitantes |
| 5 | Sem `prettier-plugin-tailwindcss` | Média | `.prettierrc` ausente | Ordem de classes inconsistente |
| 6 | Container queries não usadas (v4 built-in) | Baixa | grep sem resultado | Oportunidade perdida de responsividade semântica |

**Recomendações:**

| # | Ação | Esforço | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Instalar `clsx` + `tailwind-merge`, criar `lib/utils.ts` com `cn()` | Baixo | Baixo | `package.json`, `src/lib/utils.ts` (novo) |
| 2 | Instalar `class-variance-authority`, converter PrimaryBtn/GhostBtn para Button com variants | Médio | Baixo | `Primitives.tsx` |
| 3 | Adicionar `eslint-plugin-tailwindcss` ao eslint | Baixo | Baixo | `eslint.config.mjs` |
| 4 | Migração gradual de inline styles para utility classes | Alto | Médio | Todo `src/` |

```typescript
// lib/utils.ts (novo arquivo)
import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

### 4.3 Tokens / Liquid Glass

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | Layer 3 (component tokens) inexistente | Média | `globals.css` - ausência | Refactor de design quebra múltiplos componentes simultaneamente |
| 2 | Glass tokens em `rgba()` em vez de OKLCH | Baixa | `globals.css:29-36` | Inconsistência com padrão OKLCH do projeto |
| 3 | Overlays de modal hardcoded em 5 componentes | Baixa | `ConflictModal.tsx:78`, `CheckinDialog.tsx:100`, `CheckoutDialog.tsx:53`, `ItemSidePanel.tsx:49`, `UnitDrawer.tsx:44` | Sem token semântico unificado para overlay |
| 4 | Radius tokens duplicados (`@theme` vs `:root`) | Baixa | `globals.css` - ambas as seções | Confusão: componentes usam `var(--r-lg)` não `rounded-lg` |
| 5 | `SideRail.tsx:105` `color: '#fff'` hardcoded | Baixa | `SideRail.tsx:105` | Não adapta ao tema |
| 6 | DTCG JSON referenciado mas pipeline ausente | Média | Comentário em `globals.css` | Sem sincronização com Figma, sem versionamento |
| 7 | Sem `prefers-color-scheme` listener | Baixa | `ThemeToggle.tsx` | Preferência de OS ignorada na primeira visita |

**Recomendações:**

| # | Ação | Esforço | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Adicionar `--dialog-overlay: oklch(0 0 0 / 0.45)` e usar nos 5 modais | Baixo | Baixo | `globals.css`, 5 componentes de dialog |
| 2 | Migrar glass tokens para OKLCH | Baixo | Baixo | `globals.css:29-36` |
| 3 | Remover radius duplicados - manter só `@theme`, ajustar componentes para classes `rounded-*` | Médio | Baixo | `globals.css`, componentes |
| 4 | Adicionar `prefers-color-scheme` listener no script de tema | Baixo | Baixo | `layout.tsx` |
| 5 | Criar Layer 3 para button, dialog, input (pós-MVP) | Médio | Médio | `globals.css` |

### 4.4 shadcn/ui

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | shadcn/ui não instalado, CLAUDE.md diz que está | Alta | `package.json`, `components.json` ausente | Agentes de IA geram código shadcn incompatível |
| 2 | Sem `components/ui/` com primitivos acessíveis (Dialog, Popover, etc.) | Alta | Estrutura de pastas | Dialogs manuais sem focus trap, sem Radix accessibility |
| 3 | Sem `cn()` utilitário | Alta | `package.json` - ausência de `clsx`/`tailwind-merge` | Concatenação de classes frágil |

**Recomendações:**

| # | Ação | Esforço | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Decisão arquitetural: instalar shadcn/ui OU documentar que não usa e atualizar CLAUDE.md | Baixo (decisão) | Baixo | `CLAUDE.md`, `apps/web/AGENTS.md` |
| 2 | Se não instalar shadcn: substituir dialogs manuais por Radix Dialog diretamente | Alto | Médio | 5 arquivos de dialog |
| 3 | Se instalar shadcn: `npx shadcn@latest init`, migrar Primitives.tsx para usar Button, Dialog, etc. | Alto | Alto | Todo o design system |

Nota: para o MVP, a recomendação é **não instalar shadcn agora**. O design system Liquid Glass está funcional. A prioridade é adicionar Radix Dialog/Focus scope apenas onde há violações de a11y críticas.

### 4.5 Performance / React Compiler

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | React Compiler inativo | Alta | `next.config.ts` - ausência de `reactCompiler: true` | `useMemo`/`useCallback` manuais necessários em todo o projeto |
| 2 | `images: {unoptimized: true}` | Alta | `next.config.ts:2` | Sem WebP/AVIF, sem lazy loading, sem srcset |
| 3 | `useEffect` para derivar estado (CatalogClient) | Média | `CatalogClient.tsx:41-44` | Re-render extra desnecessário |
| 4 | Keys instáveis (`key={i}`) em listas dinâmicas | Média | `LotesBanner.tsx:66`, `RfidBanner.tsx:70` | Re-renders incorretos ao atualizar lista |
| 5 | Build usa `--webpack`, dev usa Turbopack | Média | `package.json scripts.build` | Comportamento diferente entre dev e prod |
| 6 | Sem `dynamic()` para componentes pesados | Média | Ausência no projeto | PreviewSheet/PDF sempre no bundle inicial |
| 7 | `<img>` nativo com eslint-disable em vez de `next/image` | Média | `ItemSidePanel.tsx:~120` | Code smell + LCP potencialmente pior |
| 8 | Sem instrumentação de Web Vitals | Baixa | Ausência no projeto | Sem dados reais para otimizar |

**Recomendações:**

| # | Ação | Esforço | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Ativar React Compiler: `reactCompiler: true` em next.config.ts | Baixo | Baixo (React 19 + Next 16 suportam) | `next.config.ts` |
| 2 | Remover `images: {unoptimized: true}` se deploy é Vercel (não GitHub Pages) | Baixo | Baixo | `next.config.ts` |
| 3 | Remover `--webpack` do script de build | Baixo | Baixo | `package.json` |
| 4 | Corrigir keys em LotesBanner e RfidBanner | Baixo | Baixo | `LotesBanner.tsx:66`, `RfidBanner.tsx:70` |
| 5 | Dynamic import para PreviewSheet | Baixo | Baixo | `QrCodesClient.tsx` |

```typescript
// next.config.ts - after fix
const nextConfig: NextConfig = {
  reactCompiler: true,
  // images.unoptimized removido (Vercel serve com otimização)
  turbopack: { root: __dirname },
}
```

### 4.6 Acessibilidade WCAG 2.2 AA

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | Dialogs sem focus trap | Alta | `ConflictModal.tsx:56`, `CheckinDialog.tsx:50`, `CheckoutDialog.tsx:26`, `ItemSidePanel.tsx:28` | Violação WCAG 2.1 SC 2.1.2 |
| 2 | Sem skip link para `#main-content` | Alta | `layout.tsx` - ausência | Violação WCAG 2.4.1 (Bypass Blocks) |
| 3 | Contraste fg-2/fg-3 provavelmente insuficiente | Alta (Hipótese) | `globals.css`: `--fg-2 oklch(0.50 0.01 250)`, `--fg-3 oklch(0.65 0.01 250)` | Texto de label secundário abaixo de 4.5:1 |
| 4 | `role="button"` em div sem `tabIndex` confirmado | Média | `catalog/UnitsTable.tsx:211` | Elemento não acessível via teclado |
| 5 | Animações inline não cobertas por `prefers-reduced-motion` | Média | Hipótese - componentes com `style={{animation:}}` | Violação WCAG 2.3.3 (Animation from Interactions) |
| 6 | Sem `aria-describedby` em dialogs | Baixa | ConflictModal, CheckinDialog, CheckoutDialog | Contexto adicional não anunciado por screen reader |
| 7 | Sem `aria-live` para loading states dinâmicos | Baixa | Apenas `role="alert"` para erros | Mudanças de conteúdo não anunciadas |
| 8 | TopBar é `<div>`, não `<header>` | Baixa | `TopBar.tsx` | Landmark ausente |

**Recomendações:**

| # | Ação | Esforço | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Instalar `@radix-ui/react-dialog`, substituir os 5 dialogs manuais | Médio | Médio | ConflictModal, CheckinDialog, CheckoutDialog, ItemSidePanel, UnitDrawer |
| 2 | Adicionar skip link em layout.tsx | Baixo | Zero | `layout.tsx` |
| 3 | Medir contraste de fg-2 e fg-3 com ferramenta (axe/Colour Contrast Analyser) e ajustar se necessário | Baixo | Baixo | `globals.css` |
| 4 | Adicionar `tabIndex={0}` e `onKeyDown` ao role="button" em UnitsTable | Baixo | Baixo | `catalog/UnitsTable.tsx:211` |
| 5 | Adicionar `eslint-plugin-jsx-a11y` ao ESLint | Baixo | Baixo | `eslint.config.mjs` |

```html
<!-- layout.tsx: adicionar antes do SideRail -->
<a
  href="#main-content"
  className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-white focus:text-black focus:rounded"
>
  Ir para conteúdo principal
</a>
```

### 4.7 Tooling / DX / CI

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | CI sem lint nem typecheck | Alta | `.github/workflows/pages.yml` | Erros de TS/lint chegam à produção |
| 2 | Sem Prettier | Média | `package.json` - ausência | Formatação inconsistente entre contribuidores |
| 3 | Sem Husky/lint-staged | Média | `package.json` - ausência | Sem barreira de qualidade no commit |
| 4 | Sem `eslint-plugin-jsx-a11y` | Média | `eslint.config.mjs` | Sem detecção estática de violações a11y |
| 5 | Sem `eslint-plugin-tailwindcss` | Média | `eslint.config.mjs` | Sem detecção de classes conflitantes |
| 6 | Sem `eslint-plugin-react-compiler` | Baixa | `eslint.config.mjs` | Sem aviso antecipado de incompatibilidade com Compiler |
| 7 | Sem `.cursor/rules/` | Baixa | Diretório ausente | Agentes Cursor sem contexto do projeto |
| 8 | Sem visual regression (Lost Pixel, Playwright) | Baixa | Ausência no projeto | Regressões visuais no Liquid Glass não detectadas |

**Recomendações:**

| # | Ação | Esforço | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Adicionar `tsc --noEmit` + `eslint .` ao CI | Baixo | Zero | `.github/workflows/pages.yml` |
| 2 | Instalar Prettier + `prettier-plugin-tailwindcss` | Baixo | Baixo | `package.json`, `.prettierrc` (novo) |
| 3 | Instalar Husky + lint-staged | Baixo | Baixo | `package.json`, `.husky/` (novo), `.lintstagedrc` (novo) |
| 4 | Adicionar `eslint-plugin-jsx-a11y` | Baixo | Baixo | `eslint.config.mjs`, `package.json` |

```yaml
# .github/workflows/pages.yml - adicionar steps antes do build:
- name: Typecheck
  run: npx tsc --noEmit
  working-directory: apps/web

- name: Lint
  run: npm run lint
  working-directory: apps/web
```

### 4.8 Config de IA (AGENTS.md, CLAUDE.md, .cursor/rules)

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | `CLAUDE.md` raiz declara Next.js 14 + shadcn/ui (desatualizado) | Alta | `CLAUDE.md` seção Stack | Agentes geram código Next.js 14 e shadcn incompatível |
| 2 | `apps/web/AGENTS.md` sem instrucões do projeto | Média | `apps/web/AGENTS.md` - só boilerplate Next.js | Agentes sem contexto de Primitives.tsx, padrões, anti-patterns |
| 3 | `apps/web/CLAUDE.md` referencia `@AGENTS.md` sem conteúdo próprio | Média | `apps/web/CLAUDE.md` | Sem instrucões de código para Claude Code |
| 4 | Sem `.cursor/rules/` | Baixa | Diretório ausente | Cursor sem contexto |
| 5 | Stack desalinhada entre CLAUDE.md raiz e código real | Alta | `CLAUDE.md` vs `package.json` | Risco de geração de código incompatível por qualquer agente |

**Recomendações:**

| # | Ação | Esforço | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Atualizar CLAUDE.md raiz: corrigir stack para Next.js 16 + Tailwind v4, remover referência a shadcn | Baixo | Zero | `CLAUDE.md` |
| 2 | Reescrever `apps/web/AGENTS.md` com stack real, Primitives disponíveis, padrões, anti-patterns | Baixo | Zero | `apps/web/AGENTS.md` |
| 3 | Criar `apps/web/CLAUDE.md` com instrucões de código | Baixo | Zero | `apps/web/CLAUDE.md` |

---

## 5. Matriz de Priorização

Ordenada por Impacto Alto + Esforço Baixo primeiro.

| # | Item | Impacto | Esforço | Risco | Categoria | Arquivos |
|---|---|---|---|---|---|---|
| 1 | Ativar React Compiler | Alto | Baixo | Baixo | Performance | `next.config.ts` |
| 2 | Adicionar tsc + lint ao CI | Alto | Baixo | Zero | Tooling/CI | `pages.yml` |
| 3 | Skip link em layout.tsx | Alto | Baixo | Zero | A11y | `layout.tsx` |
| 4 | Adicionar `--dialog-overlay` token e usar nos 5 modais | Médio | Baixo | Baixo | Tokens | `globals.css`, 5 dialogs |
| 5 | Corrigir keys instáveis em LotesBanner e RfidBanner | Médio | Baixo | Baixo | Performance | `LotesBanner.tsx:66`, `RfidBanner.tsx:70` |
| 6 | Instalar `cn()` (`clsx` + `tailwind-merge`) | Médio | Baixo | Baixo | Tailwind/DX | `package.json`, `lib/utils.ts` |
| 7 | Remover `--webpack` do script build | Médio | Baixo | Baixo | Tooling | `package.json` |
| 8 | Remover `useEffect` duplicador de estado em CatalogClient | Médio | Baixo | Baixo | Arquitetura | `CatalogClient.tsx:41-44` |
| 9 | Atualizar CLAUDE.md raiz com stack real | Alto | Baixo | Zero | Config IA | `CLAUDE.md` |
| 10 | Reescrever AGENTS.md com contexto do projeto | Alto | Baixo | Zero | Config IA | `apps/web/AGENTS.md` |
| 11 | Instalar Prettier + `prettier-plugin-tailwindcss` | Médio | Baixo | Baixo | Tooling | `package.json`, `.prettierrc` |
| 12 | Instalar Husky + lint-staged | Médio | Baixo | Baixo | Tooling | `package.json`, `.husky/` |
| 13 | Validar e corrigir contraste fg-2/fg-3 | Alto (se falhar) | Baixo | Baixo | A11y/Tokens | `globals.css` |
| 14 | Substituir dialogs manuais por Radix Dialog | Alto | Médio | Médio | A11y | 5 componentes de dialog |
| 15 | Dynamic import para PreviewSheet | Médio | Baixo | Baixo | Performance | `QrCodesClient.tsx` |
| 16 | Adicionar `eslint-plugin-jsx-a11y` | Médio | Baixo | Baixo | Tooling/A11y | `eslint.config.mjs` |
| 17 | Remover `images: {unoptimized: true}` (se Vercel) | Alto | Baixo | Baixo | Performance | `next.config.ts` |
| 18 | Migrar overlays de modal para OKLCH | Baixo | Baixo | Zero | Tokens | `globals.css`, 5 dialogs |
| 19 | Adicionar `prefers-color-scheme` listener | Baixo | Baixo | Baixo | DX/UX | `layout.tsx` |
| 20 | Converter PrimaryBtn/GhostBtn para Button com cva | Médio | Médio | Baixo | Tailwind/DS | `Primitives.tsx` |
| 21 | Adicionar `tabIndex` + `onKeyDown` ao role="button" em UnitsTable | Médio | Baixo | Baixo | A11y | `catalog/UnitsTable.tsx:211` |
| 22 | Migrar inline styles para Tailwind utility classes | Alto | Alto | Médio | Tailwind | Todo `src/` |
| 23 | Criar Layer 3 de component tokens | Médio | Médio | Baixo | Tokens | `globals.css` |
| 24 | Criar `.cursor/rules/` com contexto | Baixo | Baixo | Zero | Config IA | `.cursor/rules/` |
| 25 | Adicionar Storybook para Primitives.tsx | Baixo | Alto | Baixo | DX | Novo |

---

## 6. Plano de Ação Incremental

### Quick Wins (Esta Semana - W1)

- [ ] Ativar React Compiler: `reactCompiler: true` em `next.config.ts`
- [ ] Adicionar `tsc --noEmit` + `eslint .` ao CI (`.github/workflows/pages.yml`)
- [ ] Adicionar skip link em `layout.tsx`
- [ ] Instalar `clsx` + `tailwind-merge`, criar `lib/utils.ts` com `cn()`
- [ ] Corrigir keys instáveis em `LotesBanner.tsx:66` e `RfidBanner.tsx:70`
- [ ] Remover `useEffect` duplicador de estado em `CatalogClient.tsx:41-44`
- [ ] Remover `--webpack` do script `build` em `package.json`
- [ ] Atualizar `CLAUDE.md` raiz: corrigir stack (Next.js 16, Tailwind v4, sem shadcn)
- [ ] Reescrever `apps/web/AGENTS.md` com stack real, Primitives, padrões, anti-patterns
- [ ] Adicionar `--dialog-overlay: oklch(0 0 0 / 0.45)` ao `globals.css` e usar nos 5 dialogs
- [ ] Verificar contraste de `--fg-2` e `--fg-3` com Colour Contrast Analyser

### Short Term (1-2 Sprints - W2-W3)

- [ ] Substituir dialogs manuais por `@radix-ui/react-dialog` (focus trap automático)
- [ ] Instalar Prettier + `prettier-plugin-tailwindcss`
- [ ] Instalar Husky + lint-staged
- [ ] Adicionar `eslint-plugin-jsx-a11y` ao ESLint
- [ ] Adicionar `eslint-plugin-tailwindcss` ao ESLint
- [ ] Instalar `class-variance-authority`, converter PrimaryBtn/GhostBtn para Button com variants
- [ ] Verificar e remover `images: {unoptimized: true}` se deploy for Vercel
- [ ] Dynamic import para `PreviewSheet` em `QrCodesClient.tsx`
- [ ] Adicionar `tabIndex={0}` e `onKeyDown` ao `role="button"` em `UnitsTable.tsx:211`
- [ ] Criar `apps/web/CLAUDE.md` com instruções de código
- [ ] Migrar glass tokens (`--glass-bg`, `--glass-border`) de `rgba()` para OKLCH

### Medium Term (1-2 Meses - W4+)

- [ ] Migrar inline styles para utility classes Tailwind (incrementalmente por componente)
- [ ] Criar Layer 3 de component tokens em `globals.css`
- [ ] Adicionar `prefers-color-scheme` listener no script de tema em `layout.tsx`
- [ ] Criar `.cursor/rules/` com contexto do projeto
- [ ] Adicionar `eslint-plugin-react-compiler`
- [ ] Resolver duplicação de radius tokens (`@theme` vs `:root`)
- [ ] Adicionar instrumentação de Web Vitals (Vercel Analytics ou similar)

### Long Term (Roadmap - Pós-contrato)

- [ ] Adicionar visual regression testing (Lost Pixel ou Playwright Visual)
- [ ] Storybook para `Primitives.tsx` e componentes do design system
- [ ] Pipeline DTCG JSON para sincronização de tokens com Figma
- [ ] Migração completa de inline styles para Tailwind utility classes
- [ ] Adicionar testes unitários (Vitest) para lógica de negócio em `lib/`

---

## 6.5 Mapeamento W1-W4 + Pós-MVP

### W1 (Esta Semana)

| Item | Esforço (h) | Risco | Arquivos | Dependências |
|---|---|---|---|---|
| Ativar React Compiler | 0.5h | Baixo | `next.config.ts` | Nenhuma (React 19 + Next 16 suportam nativamente) |
| CI: typecheck + lint | 0.5h | Zero | `.github/workflows/pages.yml` | Nenhuma |
| Skip link no layout | 0.5h | Zero | `layout.tsx` | Nenhuma |
| Instalar `cn()` | 1h | Baixo | `package.json`, `lib/utils.ts` | `clsx`, `tailwind-merge` |
| Corrigir keys instáveis | 1h | Baixo | `LotesBanner.tsx`, `RfidBanner.tsx` | Identificar campo ID único em cada array |
| Remover useEffect CatalogClient | 1h | Baixo | `CatalogClient.tsx:41-44` | Verificar que `data.items` não muta |
| Remover `--webpack` do build | 0.5h | Baixo | `package.json` | Verificar que build Turbopack funciona |
| Atualizar CLAUDE.md + AGENTS.md | 1h | Zero | `CLAUDE.md`, `apps/web/AGENTS.md` | Nenhuma |
| Token `--dialog-overlay` + uso nos 5 dialogs | 1h | Zero | `globals.css`, 5 dialogs | Nenhuma |
| Validar contraste fg-2/fg-3 | 1h | Baixo | `globals.css` | Ferramenta de contraste |

**Total W1: ~8 horas**

### W2 (Semana 2)

| Item | Esforço (h) | Risco | Arquivos | Dependências |
|---|---|---|---|---|
| Instalar Prettier + plugin Tailwind | 1h | Baixo | `package.json`, `.prettierrc` | Nenhuma |
| Instalar Husky + lint-staged | 1h | Baixo | `package.json`, `.husky/` | Prettier instalado |
| `eslint-plugin-jsx-a11y` | 1h | Baixo | `eslint.config.mjs` | Nenhuma |
| `eslint-plugin-tailwindcss` | 1h | Baixo | `eslint.config.mjs` | Nenhuma |
| Dynamic import PreviewSheet | 1h | Baixo | `QrCodesClient.tsx` | Nenhuma |
| tabIndex + onKeyDown UnitsTable | 0.5h | Baixo | `catalog/UnitsTable.tsx:211` | Nenhuma |
| CLAUDE.md apps/web (novo) | 1h | Zero | `apps/web/CLAUDE.md` | AGENTS.md atualizado |
| Remover `images: {unoptimized}` (se Vercel) | 0.5h | Baixo | `next.config.ts` | Confirmar deploy target |

**Total W2: ~7 horas**

### W3 (Semana 3)

| Item | Esforço (h) | Risco | Arquivos | Dependências |
|---|---|---|---|---|
| `@radix-ui/react-dialog` para 5 dialogs | 6h | Médio | ConflictModal, CheckinDialog, CheckoutDialog, ItemSidePanel, UnitDrawer | Verificar que foco e animações são preservados |
| Migrar glass tokens para OKLCH | 1h | Baixo | `globals.css` | Verificar visualmente após migração |
| Button com cva (PrimaryBtn + GhostBtn) | 3h | Baixo | `Primitives.tsx`, todos os usos | `class-variance-authority` instalado |

**Total W3: ~10 horas**

### W4 (Semana 4 - Fechamento do Mês 1)

| Item | Esforço (h) | Risco | Arquivos | Dependências |
|---|---|---|---|---|
| Resolver radius duplicados | 1h | Baixo | `globals.css`, componentes que usam `var(--r-*)` | Mapeamento dos usos |
| `prefers-color-scheme` listener | 1h | Baixo | `layout.tsx` | Nenhuma |
| `.cursor/rules/` com contexto | 1h | Zero | `.cursor/rules/` | Nenhuma |
| Início da migração inline styles (1-2 componentes piloto) | 4h | Médio | Dashboard components | Definir escala de tokens em `@theme` |

**Total W4: ~7 horas**

### Pós-MVP (Após 3 meses contratuais)

| Item | Esforço (semanas) | Prioridade |
|---|---|---|
| Migração completa inline styles para Tailwind | 2-3 semanas | Alta |
| Layer 3 de component tokens | 1 semana | Alta |
| Pipeline DTCG JSON (Style Dictionary + Figma) | 1 semana | Média |
| Visual regression testing (Playwright) | 1 semana | Média |
| Storybook para Primitives.tsx | 1 semana | Baixa |
| Testes unitários (Vitest) para lib/ | Contínuo | Alta |
| `noUncheckedIndexedAccess` no tsconfig | 1 dia | Baixa |

---

## 7. Convenções Propostas do Projeto

### Nomenclatura

- Componentes: PascalCase (existente, manter)
- Arquivos de componente: PascalCase.tsx (existente, manter)
- Diretórios: kebab-case (existente, manter)
- Funções de data fetching: `load[Resource]()` em `src/lib/data/` (existente, manter)
- Server Actions: verbos de mutação em `src/lib/actions/` (existente, manter)
- Utilitários: camelCase em `src/lib/utils.ts`

### Padrões de Código

- Usar `cn()` de `lib/utils.ts` para concatenar classes (novo)
- Componentes RSC por padrão; 'use client' só quando necessário (existente, manter)
- Suspense obrigatório em toda page que carrega dados (existente, manter)
- Dialogs: usar Radix Dialog (nova convenção após W3)
- Tokens: usar `var(--token)` dos layers 1-2 do `globals.css` (existente, manter)
- Sem inline styles para valores que têm token equivalente (nova convenção)
- `key` em listas: sempre usar ID de negócio, nunca índice (nova convenção)

### Git

- Branch: `cc/sprint-N-slug` (existente no CLAUDE.md)
- Commit: sem `--no-verify` (após Husky instalado)

---

## 8. Templates Recomendados para IA

### AGENTS.md proposto para `apps/web/`

```markdown
# MMD Eventos - Web App - Guia para Agentes de IA

## Stack Real (não use documentação antiga)

- Next.js **16.2.2** (App Router, RSC, Server Actions)
- React **19.2.4** (sem forwardRef legado)
- Tailwind CSS **v4** (CSS-first, sem tailwind.config.js)
- TypeScript **5** (strict: true)
- ESLint **9** (flat config)
- Supabase (Postgres, Auth, Realtime, Storage)
- **shadcn/ui NÃO está instalado**. Sem @radix-ui/* exceto Dialog (se adicionado em W3).

## Componentes Disponíveis

Design system em `src/components/mmd/Primitives.tsx`:
- `GlassCard` - superfície principal com backdrop-blur
- `GlassPill` - chip/badge com efeito glass
- `PrimaryBtn` / `GhostBtn` - botões (usar cn() para variantes)
- `Ring` - motivo central do Liquid Glass 2030
- `StatusDot` - indicador de estado colorido
- `Badge` - label com cor semântica
- `Caustic` - orb de efeito visual (background decoration)

## Padrões Obrigatórios

- Usar `cn()` de `src/lib/utils.ts` para classes condicionais
- Pages = RSC async + Suspense. Client components = `'use client'` só quando necessário
- Tokens de design via `var(--token-name)` do `globals.css`
- `key` em listas: sempre campo `id` de negócio, nunca índice

## Anti-patterns a Evitar

- NÃO gerar código shadcn/ui (não está instalado)
- NÃO usar `style={{}}` para valores que têm token equivalente
- NÃO usar `key={index}` em listas de dados
- NÃO criar useState/useEffect para sincronizar com props (anti-pattern)
- NÃO usar `<img>` nativo (usar `next/image`)

## Como Rodar

```bash
cd apps/web
npm run dev      # Turbopack
npm run build    # Turbopack (após remover --webpack)
npm run lint     # ESLint
npx tsc --noEmit # Typecheck
```

## Design System

Liquid Glass 2030. Tokens em `globals.css`. Dark mode via `.dark` em `<html>`.
Fontes: Inter Tight (UI) + JetBrains Mono (seriais, timestamps).
Cores: OKLCH. Ver `globals.css` para todos os tokens disponíveis.
```

### .cursor/rules proposto

```markdown
---
description: MMD Eventos Web App - Next.js 16 + React 19 + Tailwind v4
globs: apps/web/**/*.{ts,tsx}
---

Stack: Next.js 16.2.2, React 19, Tailwind CSS v4, TypeScript strict.
shadcn/ui NÃO instalado. Sem @radix-ui exceto Dialog (se presente em components/).

Sempre usar cn() de src/lib/utils.ts para classes condicionais.
Componentes de design system em src/components/mmd/Primitives.tsx.
Tokens de cor/espaçamento via CSS vars (var(--token)) de globals.css.
RSC por padrão. 'use client' apenas quando necessário.
key em listas: sempre ID de negócio.
```

### CLAUDE.md proposto para `apps/web/`

```markdown
# apps/web - Instruções de Código

## Stack
Next.js 16.2.2, React 19, Tailwind v4, TypeScript strict, ESLint 9 flat config.
shadcn/ui NÃO instalado.

## Padrões
- cn() de src/lib/utils.ts para classes condicionais
- Componentes primitivos: src/components/mmd/Primitives.tsx
- Tokens: CSS vars em src/app/globals.css
- RSC + Suspense por padrão nas pages

## Testes
- Typecheck: npx tsc --noEmit
- Lint: npm run lint
- Build: npm run build
```

---

## 9. Checklist de Qualidade para Novas Features (PR Template)

```markdown
## Checklist de Qualidade - PR

### Funcional
- [ ] Feature funciona no fluxo principal (happy path)
- [ ] Edge cases cobertos (array vazio, erro de rede, loading state)
- [ ] Server Actions usam `revalidatePath` após mutações

### TypeScript
- [ ] Sem `any` novo introduzido
- [ ] Props tipadas (sem `{[key: string]: any}`)
- [ ] `npx tsc --noEmit` passa sem erros novos

### Tailwind / Estilos
- [ ] Usa `cn()` de `lib/utils.ts` para classes condicionais
- [ ] Sem `key={index}` em listas de dados
- [ ] Novos tokens de cor/radius usam CSS vars do `globals.css`

### Acessibilidade (WCAG 2.2 AA)
- [ ] Botões de ícone têm `aria-label`
- [ ] Dialogs usam Radix Dialog (focus trap automático)
- [ ] Interações de teclado testadas (Tab, Escape, Enter)
- [ ] `role="button"` em elementos não-button têm `tabIndex={0}` e `onKeyDown`

### Performance
- [ ] Listas com dados de API usam `key` com campo `id`
- [ ] Sem `useEffect` para sincronizar estado com props
- [ ] Componentes pesados com `dynamic()` se não são críticos para LCP

### CI
- [ ] Build passa (`npm run build`)
- [ ] Typecheck passa (`npx tsc --noEmit`)
- [ ] Lint passa (`npm run lint`)
```

---

*Rascunho gerado para revisão por 4 agentes em paralelo. Versão: draft-v1.*
