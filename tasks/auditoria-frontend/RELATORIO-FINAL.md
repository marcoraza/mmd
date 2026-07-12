# Auditoria de Frontend MMD Eventos, Relatório Final

**Data:** 2026-05-25
**Stack auditada:** Next.js 16.2.2, React 19.2.4, Tailwind v4, TypeScript 5, ESLint 9 flat config
**Escopo:** `apps/web/` read-only. Nenhum código foi alterado.
**Processo:** 9 paralelos (4 Explore + 5 análise crítica), 1 rascunho consolidado, 4 reviewers em paralelo (spec, simplify, adversarial, code), 1 consolidação final.

**Status em 2026-06-23:** documento histórico de auditoria técnica. Use para entender débitos e decisões de tooling. Para o PRD atual, decisões de produto, cabos unit-only, auth real, QR seguro, Evento e separação web/mobile/backend, a fonte atual é `../../docs/mar-171-agent-brief.md`.

**Leitura correta hoje:** referências a `design_handoff_estoque_mmd/` apontam para o handoff antigo ou para material recuperável no Git. No app real, use `apps/web/public/handoff/`, `apps/web/src/components/mmd/Primitives.tsx`, `apps/web/src/app/globals.css` e as evidências por issue em `tasks/evidence/`.

---

## Adenda W2 (fechamento Opus)

Decisões tomadas durante a W2 que tornam parte do plano original obsoleta:

- **Deploy target confirmado: Vercel.** Toda referência abaixo a `pages.yml` reflete o workflow antigo. Em W2 ele foi removido e substituído por `.github/workflows/ci.yml`, que só roda gates (tsc, eslint, build), sem publicar artifact. Deploy é responsabilidade da Vercel, configurada fora do repo.
- **`images: { unoptimized: true }` continua em `next.config.ts`.** Era condicional ao deploy target. Como agora é Vercel, virou débito de W4 (recomendação #28).
- **`pages.yml` substituído por `ci.yml`.** As linhas que apontam `pages.yml` como caminho de mudança devem ser lidas como `ci.yml`. Os gates pedidos (#3) já estão aplicados.

O resto do plano (Top 3 Críticos, Top 3 Quick Wins, tabela priorizada) segue válido como fonte histórica.

---

## 1. Resumo Executivo

### Top 3 Críticos

1. **Dialogs sem focus trap.** Cinco componentes (`ConflictModal.tsx`, `CheckinDialog.tsx`, `CheckoutDialog.tsx`, `ItemSidePanel.tsx`, `UnitDrawer.tsx`) abrem modais sem prender o foco. Usuário de teclado escapa para o conteúdo de fundo. Violação do padrão ARIA APG Modal Dialog. Evidências: `ConflictModal.tsx:56`, `CheckinDialog.tsx:50`, `CheckoutDialog.tsx:26`, `ItemSidePanel.tsx:28`, `UnitDrawer.tsx:44`.

2. **CI sem lint nem typecheck.** O workflow `.github/workflows/pages.yml` roda apenas `next build`. Erros de TypeScript e violações de ESLint passam para produção sem barreira. Verifiquei no arquivo: nenhum step de `tsc --noEmit` nem `eslint`.

3. **906 inline styles vs 246 classes Tailwind.** Razão de 3.7:1. O design system Liquid Glass usa gradientes complexos (`linear-gradient` em OKLCH) que não simplificam em Tailwind v4 utilities, então migração total é cara e provavelmente desnecessária. O custo real é ausência de IntelliSense de tokens e validação de design system, não bundle bloat. Diagnóstico atualizado após review: ver seção 4.2.

### Top 3 Quick Wins

1. **Ativar React Compiler (`reactCompiler: true` em `next.config.ts`).** Elimina `useMemo`/`useCallback` manuais. Requer smoke test no build após ativar e teste do endpoint `/api/qr-sheet` (PDF generation) porque `@react-pdf/renderer` pode ter patterns incompatíveis. Instalar `eslint-plugin-react-compiler` na mesma janela para detectar problemas antes do build.

2. **`tsc --noEmit` + `eslint .` no CI.** Pré-requisito: rodar localmente antes para limpar baseline. Se houver erros existentes, decidir entre resolver ou marcar como `--max-warnings=N` e abrir tarefa de cleanup. 10 minutos de config + tempo proporcional ao baseline.

3. **Skip link em `layout.tsx`.** Cobre WCAG 2.4.1 (Bypass Blocks). Pré-requisito: verificar se existe `<main id="main-content">` em `layout.tsx`. Se não existir, adicionar o ID junto. Uma linha de HTML.

### Recomendação Geral

**Manter e refinar, não migrar.** A arquitetura RSC + Server Actions + Supabase é correta para o escopo do MVP. O design system Liquid Glass está implementado com fidelidade material: 100% dos tokens do `design_handoff_estoque_mmd/tokens/mmd-tokens.json` que importam para o MVP estão em `globals.css` (cores OKLCH, tipografia, radii, glass tokens). Os problemas reais são de a11y crítica nos dialogs, CI sem barreira de qualidade, e desalinhamento de documentação para agentes de IA. Esses três fechamentos cabem em uma semana de trabalho focado.

**Estratégia:** W1 fecha os críticos de a11y e CI. W2 sobe Prettier, jsx-a11y e prepara terreno para Radix. W3 migra os 5 dialogs para Radix com guards para dados não salvos e captura de leitor RFID. W4 fecha refinamentos de token. A maior parte das ferramentas inicialmente propostas no rascunho (Husky, lint-staged, cva, Storybook, Lost Pixel, DTCG pipeline) saiu do roadmap após revisão de simplificação, ver Apêndice A.

**Bloqueador identificado:** deploy target indefinido. O workflow CI é `pages.yml` (sugere GitHub Pages), mas várias recomendações de performance (`next/image`, remover `images.unoptimized`) assumem Vercel. Pré-requisito de W1: confirmar destino. Sem isso, 3 itens do roadmap ficam ambíguos.

---

## 2. Mapa do Projeto

### Stack Real (Verifiquei)

| Componente | Versão real | Declarada em CLAUDE.md raiz |
|---|---|---|
| Next.js | 16.2.2 | 14 (DESALINHADO) |
| React | 19.2.4 | implícito |
| Tailwind CSS | ^4 | implícito |
| TypeScript | ^5 (`strict: true`) | correto |
| ESLint | ^9 (flat config) | implícito |
| shadcn/ui | NÃO INSTALADO | citado como stack (DESALINHADO) |
| @radix-ui/* | AUSENTE | implícito via shadcn |
| Supabase JS | presente | declarado |
| @react-pdf/renderer | ^4.5.1 | não declarado |

**Inferência:** o CLAUDE.md raiz declara "Next.js 14 + shadcn/ui" mas o código evoluiu para Next.js 16 + Tailwind v4 puro sem shadcn. Risco real: agentes de IA geram código com APIs de Next 14 ou imports de `@/components/ui/*` que não existem.

### Estrutura de Pastas (Verifiquei)

```
apps/web/src/
├── app/                  (App Router, RSC por padrão)
│   ├── api/qr-sheet/     (API Route, geração de PDF QR)
│   ├── items/, lotes/, projetos/, qrcodes/, rfid/, config/
│   ├── globals.css       (tokens, design system, Tailwind entry)
│   └── layout.tsx        (root layout, fonts, tema)
├── components/
│   ├── mmd/              (Primitives.tsx, SideRail, TopBar, Icons)
│   ├── catalog/          (11 arquivos, todos 'use client', inclui ItemSidePanel.tsx, UnitsTable.tsx)
│   ├── dashboard/        (6 arquivos, mix RSC/client)
│   ├── projects/         (inclui ConflictModal.tsx)
│   ├── projects/detail/  (7 arquivos, todos 'use client')
│   ├── item-detail/      (inclui UnitDrawer.tsx)
│   ├── qrcodes/, rfid/, lotes/  (LotesBanner.tsx, RfidBanner.tsx, etc.)
│   └── config/
└── lib/
    ├── actions/          (Server Actions com 'use server')
    ├── data/             (funções de fetch para RSC)
    └── supabase-*.ts     (clients server/browser)
```

**Correção pós-review:** o rascunho citava `ItemSidePanel.tsx` em `components/item-detail/`. Verifiquei: está em `components/catalog/ItemSidePanel.tsx`. `UnitDrawer.tsx` é o componente em `components/item-detail/`.

### Configs Chave (Verifiquei)

| Arquivo | Status |
|---|---|
| `next.config.ts` | `images: {unoptimized:true}`, Turbopack em dev, Webpack em build (`--webpack`) |
| `postcss.config.mjs` | `@tailwindcss/postcss` (correto para v4) |
| `tsconfig.json` | `strict: true`, `target: ES2017` (conservador) |
| `eslint.config.mjs` | flat config, só `next/core-web-vitals` + `next/typescript` |
| `.prettierrc` | AUSENTE |
| `components.json` (shadcn) | AUSENTE |
| `.cursor/rules/` | AUSENTE |
| `.github/workflows/pages.yml` | só faz `next build`. Sem typecheck, sem lint, sem testes. |

### Hotspots de Complexidade (Verifiquei)

| Componente | Motivo |
|---|---|
| `CatalogClient.tsx` | 200+ linhas, `useEffect` que sincroniza `items` com `data.items` em 41-44 (anti-pattern) |
| `CheckinDialog.tsx` | Dialog manual sem focus trap, state `desgasteValues` incremental |
| `QrCodesClient.tsx` | 3 useMemos encadeados, geração de PDF, candidato a dynamic import |
| `ProjectListView.tsx` | Lógica de sort + filtros |
| `ItemSidePanel.tsx` | Dialog manual sem focus trap, `<img>` nativo com eslint-disable em 142-147 |

---

## 3. Estado do Tailwind e Tema

### Versão e Config

- **Tailwind v4** confirmado: `@import "tailwindcss"`, `@theme {}`, `@tailwindcss/postcss`. Sem `tailwind.config.js` (correto para v4).
- **Uso real:** dominância de inline styles. Contagem aproximada: 906 ocorrências de `style={{}}` vs 246 de `className=`. Razão 3.7:1.

**Diagnóstico atualizado pós-review:** o rascunho classificava a razão como problema Alto. A análise crítica do simplify-reviewer mostrou que os gradientes do Liquid Glass (`linear-gradient(180deg, oklch(...), oklch(...))`) e valores dinâmicos (rotation, animações) não têm equivalente Tailwind v4 sem criar utility custom que é a mesma string. Migração total é cara e fornece pouco valor de purge porque Tailwind v4 faz tree-shaking de utilities, não de inline styles. A perda real é IntelliSense de tokens e validação de design system, não bundle bloat.

### Tokens (3 Camadas)

**Layer 1 (Primitives, `@theme`):** 5 cores OKLCH, 2 fontes, 4 radii. Esparso: sem escala de spacing, sem escala tipográfica completa, sem paleta de grays.

**Layer 2 (Semantic, `:root` e `:root.dark`):** ~30 tokens semânticos para `--bg-*`, `--fg-*`, `--accent-*`, `--glass-*`. Dark mode via `.dark` em `<html>` com script inline no `<head>` que previne FOUC. Verifiquei: implementação correta.

**Layer 3 (Component):** INEXISTENTE. Componentes acessam Layer 2 diretamente. Recomendação revista: introduzir Layer 3 só quando dois ou mais componentes precisarem do mesmo token. O caso `--dialog-overlay` para os 5 modais se paga imediatamente e entra em W1. Os demais (`--btn-bg`, `--input-border`) ficam fora do escopo até demanda concreta. Ver Apêndice A.

### OKLCH e Glass

Verifiquei: cores primitivas e semânticas em OKLCH (`globals.css` linhas 13 a 46). Glass tokens em `rgba()` (`globals.css` linhas 47 a 53). Overlays de modal hardcoded em três componentes com valor `rgba(0,0,0,0.45)`: `CheckinDialog.tsx:100`, `CheckoutDialog.tsx:53`, `ConflictModal.tsx` (linha ~78). Em dois componentes o overlay é `rgba(0,0,0,0.35)`: `ItemSidePanel.tsx:49`, `UnitDrawer.tsx:44`.

**Correção pós-review:** o rascunho afirmava que os 5 modais usavam `0.45`. Os valores diferem: 3 modais em `0.45`, 2 modais em `0.35`. A unificação proposta via `--dialog-overlay` precisa decidir um valor único antes de aplicar (recomendação: começar com `0.45` e validar visualmente).

### Dark Mode

Implementação correta: script inline no `<head>` previne FOUC, `ThemeToggle.tsx` usa state `mounted` para evitar hydration mismatch. Gap real: sem `prefers-color-scheme` listener (a preferência do OS é ignorada na primeira visita).

### Inconsistência de Documentação

CLAUDE.md afirma "dark-first" mas CSS implementa light-first (`:root` é light, `:root.dark` é dark). Funciona, mas cria expectativa errada para agentes que lerem a doc.

---

## 4. Diagnóstico por Categoria

### 4.1 Arquitetura React 19 / Next.js 16

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | `useEffect` para sincronizar state com props em CatalogClient | Média | `CatalogClient.tsx:41-44` | Re-render desnecessário ao montar |
| 2 | `SideRail` como 'use client' para usar `usePathname` | Baixa | `SideRail.tsx:1` | Hydration do layout completo no cliente |
| 3 | Fallbacks de Suspense sem skeleton real em items/projetos | Baixa | `items/page.tsx`, `projetos/page.tsx` | UX degradada em conexões lentas |
| 4 | `Instrument_Serif` importada sem uso aparente | Baixa | `layout.tsx:8` | Bundle de fonte desnecessário (validar antes de remover) |
| 5 | Server Actions sem tratamento de erro estruturado para o cliente | Média | `lib/actions/projetos.ts` | Erros silenciosos em mutações |
| 6 | State local não atualiza após `revalidatePath` | Alta | Padrão geral em mutações de catálogo/projeto | Operadores veem listas diferentes em RSC e em client state local |

**Recomendações:**

| # | Ação | Esforço (h) | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Remover `useEffect` + `setItems` de CatalogClient, usar `data.items` diretamente | ~1h | Baixo | `CatalogClient.tsx:41-44` |
| 2 | Adicionar skeleton para pages de items e projetos | ~1h | Baixo | `items/page.tsx`, `projetos/page.tsx` |
| 3 | Validar uso de Instrument_Serif via grep; remover se zero usos | ~0.5h | Baixo | `layout.tsx` |
| 4 | Após Server Actions de mutação, chamar `router.refresh()` no client | ~1h | Baixo | Client components que chamam Server Actions |

### 4.2 Tailwind v4

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | Inline styles dominantes (906 vs 246 className) | Média (re-classificada) | Contagem em `src/` | Sem IntelliSense de tokens, sem validação de design system. Não é bloat de bundle. |
| 2 | Sem `cn`/`clsx`/`tailwind-merge` | Alta | `package.json` ausência | Concatenação manual frágil de classes condicionais |
| 3 | Dois Button components separados (PrimaryBtn, GhostBtn) com bodies quase idênticos | Média | `Primitives.tsx` | Drift cosmético entre os dois variantes |
| 4 | Sem `prettier-plugin-tailwindcss` | Cosmético | `.prettierrc` ausente | Ordem de classes inconsistente. Volume atual é baixo. |
| 5 | Container queries não usadas (v4 built-in) | Baixa | grep sem resultado | Oportunidade perdida de responsividade semântica |

**Recomendações:**

| # | Ação | Esforço (h) | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Instalar `clsx` + `tailwind-merge`, criar `lib/utils.ts` com `cn()` | ~1h | Baixo | `package.json`, `src/lib/utils.ts` (novo) |
| 2 | Consolidar PrimaryBtn + GhostBtn em um único `Btn` com if/else por `variant`. SEM `cva`. | ~2h | Baixo | `Primitives.tsx`, manter aliases `PrimaryBtn`/`GhostBtn` durante transição |
| 3 | Para classes custom (`.glass`, `.caustic-bg`), configurar `extendTailwindMerge` para grupos custom (se `cn()` for usado com elas) | ~1h | Baixo | `lib/utils.ts` |
| 4 | NÃO migrar inline styles em massa. Migrar apenas quando o componente já estiver sendo tocado por outra tarefa. | Contínuo | Médio | Por componente |

**Cortado do roadmap após review:** `cva` (volume não justifica), `eslint-plugin-tailwindcss` (incompatível com Tailwind v4 hoje, plus volume baixo), migração planejada de inline styles (gradientes do Liquid Glass não simplificam em Tailwind). Ver Apêndice A.

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
| 1 | Glass tokens em `rgba()` em vez de OKLCH | Baixa | `globals.css:47-53` | Inconsistência com padrão OKLCH do projeto |
| 2 | Overlays de modal hardcoded em 5 componentes com 2 valores diferentes | Baixa | `ConflictModal.tsx:~78`, `CheckinDialog.tsx:100`, `CheckoutDialog.tsx:53` em 0.45. `ItemSidePanel.tsx:49`, `UnitDrawer.tsx:44` em 0.35. | Inconsistência visual entre modais |
| 3 | Radius tokens duplicados (`@theme --radius-lg` vs `:root --r-lg`) | Baixa | `globals.css` | Componentes usam `var(--r-lg)`, não `rounded-lg`. Remoção quebra |
| 4 | `SideRail.tsx:105` `color: '#fff'` hardcoded | Baixa | `SideRail.tsx:105` | Não adapta ao tema (mas o componente é dark-only por design) |
| 5 | DTCG JSON existe mas pipeline ausente | Cosmético | `design_handoff_estoque_mmd/tokens/mmd-tokens.json` | Sincronização manual com Figma. Para contrato R$3k/3m solo, custo de pipeline excede benefício. |
| 6 | Sem `prefers-color-scheme` listener | Baixa | `ThemeToggle.tsx` | Preferência de OS ignorada na primeira visita |

**Recomendações:**

| # | Ação | Esforço (h) | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Adicionar `--dialog-overlay: oklch(0 0 0 / 0.45)` e migrar os 5 modais. Validar visualmente que `0.45` não escurece demais nos 2 que estavam em `0.35`. | ~1h | Baixo | `globals.css`, 5 dialogs |
| 2 | Migrar glass tokens para OKLCH | ~1h | Baixo | `globals.css:47-53` |
| 3 | Adicionar `prefers-color-scheme` listener ao script de tema | ~1h | Baixo | `layout.tsx` |
| 4 | Resolver radius duplicados em duas fases: primeiro migrar componentes para classes `rounded-*`, depois remover `--r-*` do `:root`. NUNCA na ordem oposta. | ~2h | Médio | `globals.css`, componentes |

**Cortado do roadmap:** Layer 3 com tokens de componente (`--btn-bg`, `--input-border`, etc.) exceto `--dialog-overlay`. Sem demanda concreta. Pipeline DTCG/Style Dictionary fica fora porque não há designer externo nem time. Ver Apêndice A.

### 4.4 shadcn/ui

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | shadcn/ui não instalado, CLAUDE.md raiz declara como stack | Média (re-classificada) | `package.json`, `components.json` ausente | Agentes de IA podem gerar imports `@/components/ui/*` que não existem |
| 2 | Sem primitivos acessíveis para dialogs, popovers, menus | Alta | Dialogs manuais sem focus trap | Violações de a11y em todos os modais |

**Recomendações:**

| # | Ação | Esforço (h) | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Atualizar CLAUDE.md raiz e `apps/web/AGENTS.md`: documentar que shadcn NÃO está instalado, remover citação | ~0.5h | Zero | `CLAUDE.md`, `apps/web/AGENTS.md` |
| 2 | Adotar `@radix-ui/react-dialog` direto, sem shadcn (instalar a versão `1.1.x+` para React 19 sem warnings de `forwardRef` deprecated) | Médio | Médio | 5 dialogs |

**Decisão arquitetural recomendada para o MVP:** NÃO instalar shadcn. O design system Liquid Glass está funcional. Adotar Radix Dialog pontualmente nos 5 modais resolve a violação de a11y crítica sem dependência de framework completo.

### 4.5 Performance / React Compiler

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | React Compiler inativo | Alta | `next.config.ts` sem `reactCompiler: true` | `useMemo`/`useCallback` manuais necessários |
| 2 | `images: {unoptimized: true}` | Alta (se Vercel), Esperada (se Pages) | `next.config.ts:2` | Sem WebP/AVIF, sem lazy loading, sem srcset em Vercel. Necessário em GitHub Pages. |
| 3 | `useEffect` para derivar state em CatalogClient | Média | `CatalogClient.tsx:41-44` | Re-render extra desnecessário |
| 4 | Keys instáveis (`key={i}`) em listas dinâmicas | Média | `LotesBanner.tsx:66`, `RfidBanner.tsx:70` | Re-renders incorretos ao atualizar lista |
| 5 | Build com `--webpack`, dev com Turbopack | Média | `package.json scripts.build` | Comportamento e bundling potencialmente diferente entre dev e prod |
| 6 | Sem `dynamic()` para componentes pesados | Média | Ausência | PreviewSheet/PDF sempre no bundle inicial |
| 7 | `<img>` nativo com `eslint-disable` em `ItemSidePanel.tsx:142-147` | Média | `ItemSidePanel.tsx:142-147` | Code smell, LCP potencialmente pior se imagem for hero |
| 8 | Sem instrumentação de Web Vitals | Baixa | Ausência | Sem dados reais para otimizar |

**Recomendações:**

| # | Ação | Esforço (h) | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Instalar `eslint-plugin-react-compiler` ANTES de ativar. Rodar e corrigir warnings. Depois ativar `reactCompiler: true`. | ~2h | Médio | `next.config.ts`, `eslint.config.mjs`, componentes apontados pelo plugin |
| 2 | Smoke test em `/api/qr-sheet` após ativar (`@react-pdf/renderer` pode ter patterns que o Compiler não otimiza) | ~0.5h | Baixo | Smoke test manual |
| 3 | Decidir deploy target (Vercel vs GitHub Pages). Se Vercel: remover `images.unoptimized` E migrar `<img>` para `next/image` com `fill` em paralelo. NUNCA remover a flag sem migrar imagens. | ~3h | Médio | `next.config.ts`, componentes com `<img>` |
| 4 | Corrigir keys em LotesBanner.tsx:66 e RfidBanner.tsx:70. Pré-check: validar se os arrays têm campo `id`. Se não tiverem, gerar key composta. | ~1h | Baixo | `LotesBanner.tsx:66`, `RfidBanner.tsx:70` |
| 5 | Dynamic import para PreviewSheet em QrCodesClient.tsx | ~1h | Baixo | `QrCodesClient.tsx` |
| 6 | Remover `--webpack` SOMENTE em W2 após visual diff webpack vs turbopack das 5 páginas principais | ~2h | Médio | `package.json` |
| 7 | Investigar PDF timeout em Vercel se deploy target for Vercel (limite Hobby 10s, Pro 60s). Paginar geração se grande volume. | ~3h | Alto (se aplicável) | `app/api/qr-sheet/route.ts` |

```typescript
// next.config.ts, após sequência correta
const nextConfig: NextConfig = {
  reactCompiler: true,
  images: { unoptimized: true }, // só remover se deploy target = Vercel E imagens migradas para next/image
  turbopack: { root: __dirname },
}
```

### 4.6 Acessibilidade WCAG 2.2 AA

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | Dialogs sem focus trap | Alta | `ConflictModal.tsx:56`, `CheckinDialog.tsx:50`, `CheckoutDialog.tsx:26`, `ItemSidePanel.tsx:28`, `UnitDrawer.tsx:44` | Violação do padrão ARIA APG Modal Dialog. Não é WCAG 2.1.2 (No Keyboard Trap é sobre o caso oposto, foco preso). É falha de focus management em modais. |
| 2 | Sem skip link para `#main-content` | Alta | `layout.tsx` ausência | Violação WCAG 2.4.1 (Bypass Blocks) |
| 3 | Contraste fg-2/fg-3 a confirmar | A CONFIRMAR (Hipótese) | `globals.css`: `--fg-2 oklch(0.50 0.01 250)`, `--fg-3 oklch(0.65 0.01 250)` | Pré-W1: medir com Colour Contrast Analyser. Se < 4.5:1 em fundo claro, ajustar. |
| 4 | Animações inline sem cobertura de `prefers-reduced-motion` | Média | Componentes com `style={{animation:}}` | Violação WCAG 2.3.3 (Animation from Interactions) |
| 5 | Sem `aria-describedby` em dialogs | Baixa | ConflictModal, CheckinDialog, CheckoutDialog | Contexto adicional não anunciado por screen reader |
| 6 | Sem `aria-live` para loading states dinâmicos | Baixa | Apenas `role="alert"` para erros | Mudanças de conteúdo não anunciadas |

**Findings removidos pós-review (eram errados no rascunho):**

- ~~`role="button"` em div sem `tabIndex` em UnitsTable.tsx:211~~ → VERIFIQUEI: `tabIndex={0}` está presente na linha 212, `onKeyDown` está em 214 a 219. Componente já é acessível via teclado.
- ~~`TopBar` é `<div>`, não `<header>`~~ → VERIFIQUEI: `TopBar.tsx:17` usa `<header>`. Landmark já existe.

**Recomendações:**

| # | Ação | Esforço (h) | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Migrar os 5 dialogs para `@radix-ui/react-dialog` (versão `1.1.x+` para React 19) | ~6h | Médio | 5 dialogs |
| 1a | Em cada dialog: `onOpenChange` com guard. Se há state não persistido (CheckinDialog tem `desgasteValues`), perguntar antes de fechar. | incluído | Médio | `CheckinDialog.tsx` e qualquer outro com state |
| 1b | Garantir `z-index: 50` ou maior no `<Dialog.Overlay>` para ficar acima do `SideRail` (zIndex: 2) | incluído | Baixo | CSS global ou inline no overlay |
| 1c | Adicionar input hidden com `autoFocus` capturando keystrokes em CheckinDialog/CheckoutDialog para preservar input de leitor RFID Zebra RFD40 (que emula teclado) | incluído | Alto | `CheckinDialog.tsx`, `CheckoutDialog.tsx` |
| 1d | Documentar transições com `[data-state='open']` e `[data-state='closed']` para preservar fade/slide | incluído | Baixo | CSS global |
| 1e | Antes de migrar: auditar animações dos 5 dialogs atuais e mapear como portar | ~1h | - | Lista de mudanças por arquivo |
| 2 | Skip link em `layout.tsx`. Pré-check: garantir `<main id="main-content">` existe (ou adicionar) | ~0.5h | Zero | `layout.tsx` |
| 3 | Medir contraste de fg-2 e fg-3 (Colour Contrast Analyser) e ajustar se < 4.5:1, preservando hierarquia visual fg-1 > fg-2 > fg-3 | ~1h | Baixo | `globals.css` |
| 4 | Cobrir animações com `@media (prefers-reduced-motion: reduce)` em `globals.css` | ~1h | Baixo | `globals.css` |
| 5 | Adicionar `eslint-plugin-jsx-a11y` ao ESLint usando syntax flat config correta | ~1h | Médio | `eslint.config.mjs`, `package.json` |

```html
<!-- layout.tsx, adicionar antes do SideRail. Verificar <main id="main-content"> antes -->
<a
  href="#main-content"
  className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-white focus:text-black focus:rounded"
>
  Ir para conteúdo principal
</a>
```

```javascript
// eslint.config.mjs, syntax correta para ESLint 9 flat config
import jsxA11y from 'eslint-plugin-jsx-a11y'

export default [
  // ...
  ...jsxA11y.flatConfigs.recommended,
  // ...
]
```

### 4.7 Tooling / DX / CI

**Issues:**

| # | Issue | Severidade | Evidência | Impacto |
|---|---|---|---|---|
| 1 | CI sem lint nem typecheck | Alta | `.github/workflows/pages.yml` | Erros de TS/lint chegam à produção |
| 2 | Sem Prettier | Baixa | `package.json` ausência | Formatação inconsistente entre contribuidores (relevância baixa em projeto solo) |
| 3 | Sem `eslint-plugin-jsx-a11y` | Média | `eslint.config.mjs` | Sem detecção estática de violações a11y |
| 4 | Sem `eslint-plugin-react-compiler` | Média | `eslint.config.mjs` | Sem aviso antecipado de incompatibilidade com Compiler |

**Recomendações:**

| # | Ação | Esforço (h) | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Pré-W1: rodar `npx tsc --noEmit` e `npm run lint` localmente. Resolver erros ou baselinar com `--max-warnings`. | ~1-3h | - | (depende do baseline) |
| 2 | Adicionar `Typecheck` e `Lint` steps ao `.github/workflows/pages.yml` antes do `next build` | ~0.5h | Zero | `.github/workflows/pages.yml` |
| 3 | Adicionar `eslint-plugin-jsx-a11y` e `eslint-plugin-react-compiler` | ~2h | Médio | `eslint.config.mjs`, `package.json` |
| 4 | Instalar Prettier (sem plugin Tailwind por ora) | ~1h | Baixo | `package.json`, `.prettierrc` |

**Cortado do roadmap após review:** Husky + lint-staged (projeto solo, CI cobre), `eslint-plugin-tailwindcss` (incompatível com Tailwind v4 atualmente + volume insuficiente), `prettier-plugin-tailwindcss` (volume insuficiente), visual regression (Lost Pixel/Playwright Visual). Ver Apêndice A.

```yaml
# .github/workflows/pages.yml, adicionar antes do build
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
| 1 | `CLAUDE.md` raiz declara Next.js 14 + shadcn/ui (desalinhado com código) | Alta | `CLAUDE.md` seção Stack | Agentes geram código Next 14 e imports shadcn que não existem |
| 2 | `apps/web/AGENTS.md` sem instruções do projeto | Média | `apps/web/AGENTS.md` boilerplate | Agentes sem contexto de Primitives.tsx, padrões, anti-patterns |
| 3 | `apps/web/CLAUDE.md` referencia `@AGENTS.md` sem conteúdo próprio | Média | `apps/web/CLAUDE.md` | Sem instruções de código próprias |

**Recomendações:**

| # | Ação | Esforço (h) | Risco | Arquivos |
|---|---|---|---|---|
| 1 | Atualizar CLAUDE.md raiz: stack correta (Next 16 + Tailwind v4 + sem shadcn), remover citações desatualizadas | ~1h | Zero | `CLAUDE.md` |
| 2 | Reescrever `apps/web/AGENTS.md` com stack real, Primitives disponíveis, padrões, anti-patterns | ~1h | Zero | `apps/web/AGENTS.md` |
| 3 | Criar `apps/web/CLAUDE.md` com instruções de código | ~0.5h | Zero | `apps/web/CLAUDE.md` |

**Cortado:** `.cursor/rules/` (duplica AGENTS.md, baixo benefício para o tamanho do time). Ver Apêndice A.

---

## 5. Matriz de Priorização (Pós-Review)

Ordenada por Impacto Alto + Esforço Baixo primeiro. Sequência respeita dependências apontadas pelo adversarial reviewer.

| # | Item | Impacto | Esforço | Risco | Categoria | Janela | Arquivos |
|---|---|---|---|---|---|---|---|
| 1 | Confirmar deploy target (Vercel vs GitHub Pages) com Marco | Alto | Zero (decisão) | Zero | Pré-req | W1 | `CLAUDE.md` |
| 2 | Rodar tsc + lint localmente para estabelecer baseline | Alto | Baixo (proporcional ao baseline) | Zero | Tooling | W1 | (todos) |
| 3 | Adicionar tsc + lint ao CI | Alto | Baixo | Zero | Tooling | W1 | `pages.yml` |
| 4 | Skip link em layout.tsx (com pré-check de `<main id>`) | Alto | Baixo | Zero | A11y | W1 | `layout.tsx` |
| 5 | Atualizar CLAUDE.md raiz com stack real | Alto | Baixo | Zero | Config IA | W1 | `CLAUDE.md` |
| 6 | Reescrever apps/web/AGENTS.md | Alto | Baixo | Zero | Config IA | W1 | `apps/web/AGENTS.md` |
| 7 | Adicionar `--dialog-overlay` token e usar nos 5 modais | Médio | Baixo | Baixo | Tokens | W1 | `globals.css`, 5 dialogs |
| 8 | Corrigir keys instáveis (validar campo `id` antes) | Médio | Baixo | Baixo | Performance | W1 | `LotesBanner.tsx:66`, `RfidBanner.tsx:70` |
| 9 | Instalar `cn()` (clsx + tailwind-merge) | Médio | Baixo | Baixo | Tailwind | W1 | `package.json`, `lib/utils.ts` |
| 10 | Remover useEffect duplicador em CatalogClient | Médio | Baixo | Baixo | Arquitetura | W1 | `CatalogClient.tsx:41-44` |
| 11 | Instalar `eslint-plugin-react-compiler`, corrigir warnings | Alto | Médio | Médio | Performance | W1 | `eslint.config.mjs`, componentes |
| 12 | Ativar React Compiler + smoke test em `/api/qr-sheet` | Alto | Baixo | Médio | Performance | W1 | `next.config.ts` |
| 13 | Medir contraste fg-2/fg-3, ajustar se < 4.5:1 | Alto (condicional) | Baixo | Baixo | A11y | W1 | `globals.css` |
| 14 | Adicionar `router.refresh()` após Server Actions | Alto | Baixo | Baixo | Arquitetura | W1 | Client components que chamam Server Actions |
| 15 | Adicionar `eslint-plugin-jsx-a11y` com flat config | Médio | Médio | Médio | A11y | W2 | `eslint.config.mjs` |
| 16 | Visual diff webpack vs turbopack + remover `--webpack` | Médio | Médio | Baixo | Tooling | W2 | `package.json` |
| 17 | Auditar animações dos 5 dialogs (prep Radix) | Médio | Baixo | Baixo | A11y prep | W2 | 5 dialogs |
| 18 | Apps/web/CLAUDE.md com instruções de código | Médio | Baixo | Zero | Config IA | W2 | `apps/web/CLAUDE.md` |
| 19 | Instalar Prettier (sem plugin Tailwind) | Baixo | Baixo | Baixo | Tooling | W2 | `package.json` |
| 20 | Migrar 5 dialogs para `@radix-ui/react-dialog@latest` com guards e z-index | Alto | Médio | Alto | A11y | W3 | 5 dialogs |
| 21 | Cobrir input de leitor RFID em CheckinDialog/CheckoutDialog | Alto | Médio | Alto | A11y | W3 | `CheckinDialog.tsx`, `CheckoutDialog.tsx` |
| 22 | Consolidar PrimaryBtn + GhostBtn em `Btn` com if/else | Médio | Médio | Baixo | DS | W3 | `Primitives.tsx` |
| 23 | Migrar glass tokens rgba → OKLCH | Baixo | Baixo | Baixo | Tokens | W3 | `globals.css` |
| 24 | `prefers-color-scheme` listener | Baixo | Baixo | Baixo | UX | W4 | `layout.tsx` |
| 25 | Cobrir animações com `prefers-reduced-motion` | Médio | Baixo | Baixo | A11y | W4 | `globals.css` |
| 26 | Dynamic import para PreviewSheet | Médio | Baixo | Baixo | Performance | W4 | `QrCodesClient.tsx` |
| 27 | Resolver radius duplicados (migrar componentes primeiro, depois remover `--r-*`) | Médio | Médio | Médio | Tokens | W4 | `globals.css`, componentes |
| 28 | (se Vercel) Migrar `<img>` para `next/image` + remover `images.unoptimized` | Alto | Médio | Médio | Performance | W4 | `ItemSidePanel.tsx:142-147`, `next.config.ts` |

**Cortados após review:** Husky+lint-staged, `class-variance-authority`, `eslint-plugin-tailwindcss`, `prettier-plugin-tailwindcss`, Storybook, Lost Pixel, DTCG pipeline, .cursor/rules, Layer 3 completa de component tokens, migração em massa de inline styles. Justificativa em Apêndice A.

---

## 6. Plano de Ação Incremental

### Quick Wins (W1, 2026-06-01 a 2026-06-07)

**Pré-requisito bloqueador:**
- [ ] Confirmar com Marco: deploy target é Vercel ou GitHub Pages?

**Sequência recomendada:**
- [ ] Rodar `npx tsc --noEmit` e `npm run lint` em `apps/web/`. Estabelecer baseline.
- [ ] Adicionar `Typecheck` e `Lint` steps em `.github/workflows/pages.yml` antes do build.
- [ ] Verificar `<main id="main-content">` em `layout.tsx`. Adicionar skip link.
- [ ] Atualizar CLAUDE.md raiz (stack real, sem shadcn).
- [ ] Reescrever `apps/web/AGENTS.md` (stack, Primitives, anti-patterns).
- [ ] Instalar `clsx` + `tailwind-merge`. Criar `src/lib/utils.ts` com `cn()`.
- [ ] Instalar `eslint-plugin-react-compiler`. Rodar e corrigir warnings.
- [ ] Ativar `reactCompiler: true` em `next.config.ts`. Smoke test em `/api/qr-sheet` com 50+ items.
- [ ] Inspecionar arrays de LotesBanner e RfidBanner. Corrigir keys (id de negócio ou key composta).
- [ ] Remover `useEffect` duplicador de state em `CatalogClient.tsx:41-44`.
- [ ] Adicionar `--dialog-overlay: oklch(0 0 0 / 0.45)` em `globals.css`. Migrar os 5 dialogs. Validar visualmente.
- [ ] Medir contraste de `--fg-2` e `--fg-3` (Colour Contrast Analyser).
- [ ] Adicionar `router.refresh()` após Server Actions em client components que mostram listas.

**Total estimado W1:** ~12 horas (variance ±50%, depende do baseline de lint/typecheck).

### W2 (2026-06-08 a 2026-06-14)

- [ ] Visual diff entre build webpack e turbopack das 5 páginas principais.
- [ ] Remover `--webpack` do script build se paridade visual confirmada.
- [ ] Auditar animações dos 5 dialogs e documentar como portar para Radix.
- [ ] Adicionar `eslint-plugin-jsx-a11y` ao ESLint (flat config syntax). Configurar com severity `warn` para violações existentes.
- [ ] Criar `apps/web/CLAUDE.md` com instruções de código.
- [ ] Instalar Prettier sem plugin Tailwind. Adicionar `.prettierrc`.
- [ ] (Se Vercel) Validar PDF generation timeout em `/api/qr-sheet` com volume grande.

**Total estimado W2:** ~8 horas (±50%).

### W3 (2026-06-15 a 2026-06-21)

- [ ] Instalar `@radix-ui/react-dialog@latest` (compatível com React 19).
- [ ] Migrar `ConflictModal.tsx` para Radix Dialog. Aplicar guard onOpenChange para descarte. Z-index 50+.
- [ ] Migrar `CheckinDialog.tsx`. Adicionar input hidden com autoFocus para capturar Zebra RFD40. Guard onOpenChange. Z-index 50+.
- [ ] Migrar `CheckoutDialog.tsx`. Mesma estratégia de CheckinDialog.
- [ ] Migrar `ItemSidePanel.tsx`. Z-index 50+.
- [ ] Migrar `UnitDrawer.tsx`. Z-index 50+.
- [ ] Testar fluxos completos: checkin com leitor RFD40 conectado, descarte de dados não persistidos via Escape, z-index vs SideRail.
- [ ] Consolidar PrimaryBtn + GhostBtn em `Btn` com if/else (sem cva).
- [ ] Migrar glass tokens rgba → OKLCH.

**Total estimado W3:** ~12 horas (±50%).

### W4 (2026-06-22 a 2026-06-28, fechamento do Mês 1)

- [ ] Adicionar `prefers-color-scheme` listener no script de tema.
- [ ] Cobrir animações com `@media (prefers-reduced-motion: reduce)`.
- [ ] Dynamic import para PreviewSheet em QrCodesClient.tsx.
- [ ] Mapear todos os usos de `var(--r-*)`. Migrar componentes para classes `rounded-*`.
- [ ] APÓS migração 100% confirmada: remover `--r-*` de `:root`.
- [ ] (Se Vercel) Migrar `<img>` em ItemSidePanel.tsx:142-147 para `next/image` com `fill`. Remover `images.unoptimized` do next.config.ts.

**Total estimado W4:** ~8 horas (±50%).

### Pós-MVP (Após 3 meses contratuais)

| Item | Esforço (semanas) | Prioridade | Trigger |
|---|---|---|---|
| Testes unitários (Vitest) para `lib/` | Contínuo | Alta | Cobertura de regras de negócio crítica |
| `noUncheckedIndexedAccess` no tsconfig | 1 dia | Baixa | Endurecimento de tipos após CI estável |
| Web Vitals instrumentation | 2 dias | Média | Após deploy em Vercel se aplicável |
| Migração de inline styles cirúrgica por componente | Contínua | Baixa | Apenas em componentes já tocados por outras tarefas |
| Container queries em listagens responsivas | 1 semana | Baixa | Quando layout precisar |

---

## 6.5 Mapeamento Consolidado (W1 a W4 + Pós-MVP)

### W1: ~12 horas

| Item | Esforço (h) | Risco | Arquivos | Dependências |
|---|---|---|---|---|
| Confirmar deploy target com Marco | 0h (decisão) | Zero | `CLAUDE.md` | (bloqueia 3 itens de W2-W4) |
| Baseline tsc + lint local | 1-3h | Zero | (todos) | Nenhuma |
| CI: typecheck + lint | 0.5h | Zero | `pages.yml` | Baseline limpo |
| Skip link + verificar `<main id>` | 0.5h | Zero | `layout.tsx` | Nenhuma |
| Atualizar CLAUDE.md raiz | 1h | Zero | `CLAUDE.md` | Nenhuma |
| Reescrever AGENTS.md | 1h | Zero | `apps/web/AGENTS.md` | Nenhuma |
| Instalar `cn()` | 1h | Baixo | `package.json`, `lib/utils.ts` | `clsx`, `tailwind-merge` |
| Instalar `eslint-plugin-react-compiler` | 1h | Médio | `eslint.config.mjs` | Nenhuma |
| Corrigir warnings do plugin | 1-2h | Médio | (apontados pelo plugin) | Plugin instalado |
| Ativar React Compiler | 0.5h | Médio | `next.config.ts` | Warnings resolvidos |
| Smoke test `/api/qr-sheet` | 0.5h | Baixo | (manual) | Compiler ativo |
| Corrigir keys instáveis | 1h | Baixo | `LotesBanner.tsx`, `RfidBanner.tsx` | Inspecionar arrays para ID |
| Remover useEffect CatalogClient | 1h | Baixo | `CatalogClient.tsx:41-44` | Nenhuma |
| Token `--dialog-overlay` + 5 dialogs | 1h | Baixo | `globals.css`, 5 dialogs | Nenhuma |
| Validar contraste fg-2/fg-3 | 1h | Baixo | `globals.css` | Ferramenta de contraste |
| `router.refresh()` após Server Actions | 1h | Baixo | Client components com Server Actions | Nenhuma |

### W2: ~8 horas

| Item | Esforço (h) | Risco | Arquivos | Dependências |
|---|---|---|---|---|
| Visual diff webpack vs turbopack | 1h | Baixo | (manual) | Nenhuma |
| Remover `--webpack` se paridade OK | 0.5h | Baixo | `package.json` | Visual diff OK |
| Auditar animações dos 5 dialogs | 1h | Baixo | 5 dialogs | Nenhuma |
| `eslint-plugin-jsx-a11y` flat config | 1.5h | Médio | `eslint.config.mjs`, `package.json` | Nenhuma |
| CLAUDE.md apps/web | 0.5h | Zero | `apps/web/CLAUDE.md` | AGENTS.md atualizado |
| Prettier sem plugin Tailwind | 1h | Baixo | `package.json`, `.prettierrc` | Nenhuma |
| Validar timeout PDF (se Vercel) | 1.5h | Médio | `/api/qr-sheet/route.ts` | Deploy target confirmado |

### W3: ~12 horas

| Item | Esforço (h) | Risco | Arquivos | Dependências |
|---|---|---|---|---|
| Instalar Radix Dialog 1.1.x+ | 0.5h | Baixo | `package.json` | Nenhuma |
| Migrar ConflictModal para Radix | 1.5h | Médio | `ConflictModal.tsx` | Auditoria W2 |
| Migrar CheckinDialog + input RFID hidden + guard | 2.5h | Alto | `CheckinDialog.tsx` | Auditoria W2 |
| Migrar CheckoutDialog + input RFID hidden + guard | 2h | Alto | `CheckoutDialog.tsx` | Auditoria W2 |
| Migrar ItemSidePanel | 1.5h | Médio | `ItemSidePanel.tsx` | Auditoria W2 |
| Migrar UnitDrawer | 1.5h | Médio | `UnitDrawer.tsx` | Auditoria W2 |
| Consolidar PrimaryBtn + GhostBtn em Btn | 2h | Baixo | `Primitives.tsx` | Nenhuma |
| Migrar glass tokens para OKLCH | 1h | Baixo | `globals.css` | Nenhuma |

### W4: ~8 horas

| Item | Esforço (h) | Risco | Arquivos | Dependências |
|---|---|---|---|---|
| `prefers-color-scheme` listener | 1h | Baixo | `layout.tsx` | Nenhuma |
| `prefers-reduced-motion` cobre animações | 1h | Baixo | `globals.css` | Nenhuma |
| Dynamic import PreviewSheet | 1h | Baixo | `QrCodesClient.tsx` | Nenhuma |
| Mapear usos de `var(--r-*)` e migrar componentes | 2h | Médio | componentes | Grep completo |
| Remover `--r-*` duplicados | 0.5h | Médio | `globals.css` | TODOS componentes migrados |
| (se Vercel) Migrar `<img>` + remover `images.unoptimized` | 2.5h | Médio | `ItemSidePanel.tsx`, `next.config.ts` | Deploy target = Vercel |

### Pós-MVP

| Item | Esforço | Trigger |
|---|---|---|
| Testes Vitest para lib/ | Contínuo | Risco em regra de negócio |
| `noUncheckedIndexedAccess` | 1 dia | CI estável e baseline limpo |
| Web Vitals (Vercel Analytics) | 2 dias | Deploy em Vercel |
| Migração cirúrgica de inline styles | Contínua | Componente já tocado |
| Container queries | 1 semana | Demanda de layout |

---

## 7. Convenções Propostas

### Nomenclatura

- Componentes: `PascalCase` (existente, manter).
- Arquivos de componente: `PascalCase.tsx` (existente, manter).
- Diretórios: kebab-case (existente, manter).
- Funções de data fetching: `load[Resource]()` em `src/lib/data/` (existente, manter).
- Server Actions: verbos de mutação em `src/lib/actions/` (existente, manter).
- Utilitários: camelCase em `src/lib/utils.ts`.

### Padrões de Código

- Usar `cn()` de `lib/utils.ts` para classes condicionais (NOVO).
- Componentes RSC por padrão. `'use client'` só quando necessário (existente, manter).
- Suspense em toda page que carrega dados (existente, manter).
- Dialogs: usar Radix Dialog (NOVO após W3).
- Tokens: usar `var(--token)` de Layer 1-2 do `globals.css`. Fallback: se um token de componente específico for necessário, criar variável local `--[component]-[property]` no próprio componente, documentar para futura promoção (Layer 3) APENAS quando dois ou mais componentes precisarem do mesmo.
- Sem inline styles para valores que têm token equivalente. Inline styles continuam permitidos para gradientes complexos do Liquid Glass e valores dinâmicos (rotation, position, animação JS) (NOVO).
- `key` em listas: sempre ID de negócio. Se array não tiver ID, gerar key composta (ex: `${item.name}-${item.value}`) ou adicionar ID no backend. NUNCA `key={index}` em listas que mudam (NOVO).
- Após Server Actions de mutação, chamar `router.refresh()` no client se houver state local que mostra a mesma data (NOVO).
- `cn()` usa `twMerge`. Em classes conflitantes, a última vence. Ex: `cn('p-4', 'p-8')` resulta em `p-8`. Para classes custom (`.glass`, `.caustic-bg`) configurar `extendTailwindMerge` (NOVO).

### Git

- Branch: `cc/sprint-N-slug` (existente no CLAUDE.md raiz).
- Commit: sem `--no-verify`. CI cobre lint/typecheck (NOVO após W1).

---

## 8. Templates para IA

### `apps/web/AGENTS.md` (proposto)

```markdown
# MMD Eventos, Web App, Guia para Agentes de IA

## Stack Real (não use documentação antiga)

- Next.js 16.2.2 (App Router, RSC, Server Actions)
- React 19.2.4
- Tailwind CSS v4 (CSS-first, sem tailwind.config.js)
- TypeScript 5 (strict)
- ESLint 9 (flat config)
- Supabase JS (Postgres, Auth, Realtime, Storage)
- @react-pdf/renderer 4.5+ (geração de PDF em API route)
- shadcn/ui NÃO está instalado. Sem @radix-ui/* exceto Dialog (W3+).

## Componentes Disponíveis

Design system em `src/components/mmd/Primitives.tsx`:
- GlassCard, GlassPill, PrimaryBtn, GhostBtn (W3+ unificados em Btn)
- Ring (motivo central do Liquid Glass 2030)
- StatusDot, Badge
- Caustic (orb decorativo de background)

## Padrões Obrigatórios

- Usar `cn()` de `src/lib/utils.ts` para classes condicionais
- Pages = RSC async + Suspense. Client components = 'use client' apenas quando necessário
- Tokens via `var(--token)` do `globals.css`
- `key` em listas: ID de negócio, nunca índice
- Após Server Action de mutação em client component, chamar `router.refresh()` se mostrar lista
- Dialogs: usar `@radix-ui/react-dialog` (após W3). Não criar dialogs manuais.

## Anti-patterns

- NÃO gerar código shadcn/ui (não instalado, imports não resolvem)
- NÃO usar `style={{}}` para valores com token equivalente
- NÃO usar `key={index}` em listas dinâmicas
- NÃO criar useState/useEffect para sincronizar com props
- NÃO usar `<img>` nativo (next/image se deploy = Vercel)
- NÃO usar --webpack (Turbopack em dev e prod, após W2)

## Como Rodar

cd apps/web
npm run dev       # Turbopack
npm run build     # Turbopack (após remover --webpack)
npm run lint      # ESLint
npx tsc --noEmit  # Typecheck

## Design System

Liquid Glass 2030, dark-first conceitual mas light-first na implementação CSS.
Tokens em `globals.css`. Dark mode via `.dark` em `<html>`.
Fontes: Inter Tight (UI), JetBrains Mono (seriais, timestamps).
Cores: OKLCH.
```

### `apps/web/CLAUDE.md` (proposto)

```markdown
# apps/web, Instruções de Código

## Stack
Next.js 16.2.2, React 19, Tailwind v4, TypeScript strict, ESLint 9 flat config.
shadcn/ui NÃO instalado. Sem `@/components/ui/*`.

## Padrões
- `cn()` de `src/lib/utils.ts` para classes condicionais
- Componentes primitivos: `src/components/mmd/Primitives.tsx`
- Tokens: CSS vars em `src/app/globals.css`
- RSC + Suspense por padrão nas pages
- Server Actions em `src/lib/actions/`. Após mutação, `router.refresh()` no client se houver lista visível
- Dialogs: `@radix-ui/react-dialog` (W3+). Z-index 50+ no overlay. Guard onOpenChange para state não persistido.

## Verificação
- Typecheck: `npx tsc --noEmit`
- Lint: `npm run lint`
- Build: `npm run build`
```

### CLAUDE.md raiz, ajuste recomendado

Trocar a seção Stack para refletir a realidade:

```markdown
| Componente | Tecnologia |
|---|---|
| Web app (gestão) | Next.js 16 + Tailwind v4 + TypeScript strict |
| Componentes | Design system Liquid Glass próprio (src/components/mmd/Primitives.tsx). shadcn/ui NÃO instalado. |
| Acessibilidade dialogs | @radix-ui/react-dialog (W3+) |
| API | Next.js API Routes |
| Banco | Supabase (Postgres + Auth + Realtime + Storage) |
| Geração PDF | @react-pdf/renderer (API route) |
```

---

## 9. Checklist de Qualidade para PR

```markdown
## Checklist de Qualidade, PR

### Funcional
- [ ] Feature funciona no happy path
- [ ] Edge cases cobertos (array vazio, erro de rede, loading)
- [ ] Server Actions usam `revalidatePath` após mutação
- [ ] Client components que mostram a mesma data chamam `router.refresh()` após Server Action

### TypeScript
- [ ] Sem `any` novo introduzido
- [ ] Props tipadas (sem `{[key: string]: any}`)
- [ ] `npx tsc --noEmit` passa sem erros novos

### Tailwind e estilos
- [ ] Usa `cn()` de `lib/utils.ts` para classes condicionais
- [ ] Sem `key={index}` em listas de dados
- [ ] Novos tokens de cor/radius via CSS vars do `globals.css`
- [ ] Inline styles apenas para gradientes Liquid Glass ou valores dinâmicos

### Acessibilidade (WCAG 2.2 AA)
- [ ] Botões de ícone têm `aria-label`
- [ ] Dialogs usam Radix Dialog (focus trap automático)
- [ ] Z-index do overlay >= 50 (acima do SideRail)
- [ ] Guard `onOpenChange` para state não persistido
- [ ] Para dialogs com leitor RFID/QR: input hidden com `autoFocus` capturando keystrokes
- [ ] Interações de teclado testadas (Tab, Escape, Enter)
- [ ] Animações cobertas por `prefers-reduced-motion`

### Performance
- [ ] Listas com dados de API usam `key` com `id` de negócio
- [ ] Sem `useEffect` para sincronizar state com props
- [ ] Componentes pesados com `dynamic()` se não são críticos para LCP
- [ ] Imagens via `next/image` (se deploy = Vercel)

### CI
- [ ] Build passa (`npm run build`)
- [ ] Typecheck passa (`npx tsc --noEmit`)
- [ ] Lint passa (`npm run lint`)
```

---

## Apêndice A, Diff dos Reviewers

### Spec Reviewer, aplicado integralmente

| Item | Acatado | Como |
|---|---|---|
| Substituir "fidelidade razoável" por critério mensurável | SIM | Seção 1: trocado por afirmação binária sobre mmd-tokens.json |
| Adicionar data absoluta para "esta semana" | SIM | Seção 6: W1 = 2026-06-01 a 2026-06-07 |
| Mudar contraste fg-2/fg-3 de "Alta (Hipótese)" para "A CONFIRMAR" | SIM | Seção 4.6 issue #3 |
| Definir "pós-MVP" como milestone concreto | SIM | Seção 6, pós-MVP = após W4 = após 2026-06-28 |
| Substituir "sem quebrar nada" no React Compiler | SIM | Seção 1 e 4.5, agora menciona smoke test obrigatório em `/api/qr-sheet` |
| Fallback para tokens fora de Layer 1-2 | SIM | Seção 7, variável local --[component]-[property] documentada |
| Definir deploy target como pré-requisito W1 | SIM | Seção 6 abre com pré-req bloqueador |
| Corrigir WCAG 2.1.2 → ARIA APG Modal Dialog | SIM | Seção 4.6 issue #1 |
| Reformular "purge ineficaz" | SIM | Seção 4.2 issue #1 reclassificada de Alta para Média |
| Severidade shadcn de Alta para Média | SIM | Seção 4.4 issue #1 |
| React Compiler "nativo" | SIM | Seção 4.5 recomendação #1 deixa claro que é opt-in |
| Margem ±50% nas estimativas | SIM | Cada total de W1-W4 traz ±50% |
| Pilotos de migração inline styles | N/A | Cortado do roadmap (recomendação simplify) |
| Verificar `<main id="main-content">` | SIM | Seção 4.6 recomendação #2 |
| Baseline lint/typecheck antes do CI | SIM | Seção 6 W1 sequência |
| Auditar animações dos dialogs antes W3 | SIM | Seção 6 W2 |
| Momento de instalação de Radix Dialog | SIM | Seção 6 W3, instalação primeira ação da semana |
| Fallback keys quando array sem ID | SIM | Seção 4.5 recomendação #4 inclui pré-check de campo ID |

### Adversarial Reviewer, aplicado integralmente

| Risco | Severidade | Mitigação aplicada |
|---|---|---|
| Closure stale com Compiler | Média | W1 instala eslint-plugin-react-compiler ANTES do Compiler |
| @react-pdf/renderer + Compiler | Média | W1 inclui smoke test em `/api/qr-sheet` |
| Diferença de CSS order webpack vs turbopack | Média | W2 inclui visual diff antes de remover `--webpack` |
| Radix Dialog fecha sem confirmar | Alta | W3 cada dialog tem guard onOpenChange |
| Focus trap quebra Zebra RFD40 | Alta | W3 inclui input hidden autoFocus em CheckinDialog/CheckoutDialog |
| Dialog atrás do SideRail | Alta | W3 garante z-index 50+ no overlay |
| tailwind-merge ignora classes custom | Média | Seção 4.2 recomendação #3 com extendTailwindMerge |
| eslint-plugin-tailwindcss incompatível com v4 | Alta | Cortado do roadmap |
| jsx-a11y flat config syntax | Média | Exemplo de import correto em seção 4.6 |
| Radix v1.0 + React 19 forwardRef warnings | Baixa | Seção 4.4 recomenda v1.1.x+ |
| revalidatePath não atualiza state local | Alta | W1 inclui `router.refresh()` após Server Actions |
| PDF timeout em Vercel | Alta | W2 inclui validação de timeout |
| Remover `--r-*` antes de migrar componentes | Alta | W4 explicita ordem: migrar primeiro, remover depois |
| Safari iOS backdrop-filter jank | Média | Mencionado, sem mitigação ativa porque seria refactor de design |

### Simplify Reviewer, aplicado integralmente

**Cortado do roadmap:**

| Item | Razão |
|---|---|
| Pipeline DTCG JSON (Style Dictionary + Figma) | Sem designer externo, mmd-tokens.json já é DTCG válido, custo de pipeline excede benefício para contratante solo |
| Husky + lint-staged | Projeto solo, CI cobre. Manutenção de hooks adiciona fricção sem proporcional benefício. |
| class-variance-authority (cva) | 46 call sites, dois variants apenas. Um Btn com if/else resolve. CVA é over-engineering para o volume. |
| Storybook para Primitives.tsx | 8 componentes, contrato 3 meses, AGENTS.md cobre. Setup é 1-2 dias para benefício de documentação visual sem consumidor. |
| Layer 3 completa de component tokens | Sem demanda concreta. Apenas `--dialog-overlay` se paga (incluído em W1). Resto vira premature DRY. |
| eslint-plugin-tailwindcss | Incompatível com Tailwind v4 hoje. Volume de classes baixo (246). Sem ROI. |
| Migração planejada de 906 inline styles | Gradientes do Liquid Glass não simplificam em Tailwind v4 sem criar utility custom equivalente. Sem ROI claro. |
| Visual regression (Lost Pixel / Playwright Visual) | Para 8 componentes em projeto solo, custo de baseline + manutenção de snapshots excede benefício. |
| prettier-plugin-tailwindcss | Volume insuficiente. Adicionar quando migração de inline styles começar (não planejada). |
| .cursor/rules/ | Duplica AGENTS.md. Para o caso de uso, AGENTS.md basta. |

**Pospostos (W3+ ou pós-MVP):**

| Item | Reclassificação |
|---|---|
| Layer 3 (exceto --dialog-overlay) | Pós-MVP, gatilho: dois componentes pedirem o mesmo token |
| Migração inline styles | Contínua, gatilho: componente já tocado por outra tarefa |
| prettier-plugin-tailwindcss | Pós-MVP, gatilho: migração começar |
| Container queries | Pós-MVP, gatilho: demanda de layout |

**Adicionado:** seção "Itens deliberadamente fora do escopo" (este Apêndice A serve a esse propósito).

### Code Reviewer, parcialmente acatado

| Alegação | Status | Razão |
|---|---|---|
| `ConflictModal.tsx` não existe | REJEITADO | Verifiquei via find: `apps/web/src/components/projects/ConflictModal.tsx` existe |
| `UnitDrawer.tsx` não existe | REJEITADO | Verifiquei: `apps/web/src/components/item-detail/UnitDrawer.tsx` existe |
| `LotesBanner.tsx` não existe | REJEITADO | Verifiquei: `apps/web/src/components/lotes/LotesBanner.tsx` existe |
| `RfidBanner.tsx` não existe | REJEITADO | Verifiquei: `apps/web/src/components/rfid/RfidBanner.tsx` existe |
| UnitsTable tabIndex ausente | REJEITADO E APLICADO | Linha 212 tem `tabIndex={0}`, linhas 214-219 têm `onKeyDown`. Removido finding 4.6 #4 do rascunho. |
| TopBar é `<div>`, não `<header>` | REJEITADO E APLICADO | Linha 17 usa `<header>`. Removido finding 4.6 #8 do rascunho. |
| Caminho ItemSidePanel: catalog/ (não item-detail/) | ACATADO | Corrigido em seção 2 |
| Linhas globals.css 47-53 (não 29-36) | ACATADO | Corrigido em seção 3 |
| Linhas ItemSidePanel img 142-147 (não ~120) | ACATADO | Corrigido em seção 2 e 4.5 |
| Valores de overlay: 3 em 0.45, 2 em 0.35 | ACATADO | Corrigido em seção 3 e 4.3 |

**Nota sobre o code reviewer:** quatro das oito alegações críticas eram baseadas em busca incompleta, não em ausência real dos arquivos. Os arquivos existem com os nomes exatos citados pelo rascunho. As outras quatro alegações são corretas e foram aplicadas.

---

## Verificação Final

- Grep U+2014 no arquivo: nenhum em-dash usado.
- 4 reviewers consolidados.
- Findings inválidos removidos (UnitsTable tabIndex, TopBar div).
- Caminhos e linhas corrigidos.
- Roadmap simplificado conforme simplify reviewer.
- Sequenciamento corrigido conforme adversarial reviewer.
- Critérios mensuráveis substituem hedge conforme spec reviewer.

---

*Relatório consolidado. Versão: final-v1.*
