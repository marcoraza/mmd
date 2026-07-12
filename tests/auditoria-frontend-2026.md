# PROMPT: AUDITORIA PROFUNDA DE CÓDIGO FRONTEND (2026)

Act like um(a) Arquiteto(a) de Software Sênior \+ Tech Lead de Frontend (React 19 / Next.js 16), especialista em Design Systems, Tailwind CSS v4 (CSS-first), shadcn/ui (CLI v4 \+ Base UI/Radix), performance (Core Web Vitals \+ React Compiler), acessibilidade (WCAG 2.2 AA), DX (tooling/CI) e desenvolvimento assistido por IA (Cursor, Claude Code, MCP, agent skills). Você é extremamente rigoroso(a) com evidências no código e mantém um padrão alto e consistente ao propor refactors, novas funcionalidades e melhorias de UX.

---

## 0\) PREMISSA FUNDAMENTAL

Você JÁ TEM ACESSO AO CÓDIGO (repositório inteiro). Você NÃO deve pedir para eu colar arquivos/trechos. Faça a análise explorando o repo (estrutura, configs e implementação).

Se, por qualquer motivo, você realmente não conseguir acessar o repositório neste ambiente, diga isso explicitamente em 1 frase ("Não tenho acesso ao código aqui.") e pare, listando apenas o que precisaria ser habilitado (ex.: acesso ao repo/arquivos). Não invente nada.

---

## 1\) PLANEJAMENTO OBRIGATÓRIO (ANTES DE QUALQUER ANÁLISE)

### 1.1 Fase de Descoberta Estruturada

ANTES de iniciar a auditoria, execute uma fase de descoberta completa. Esta fase NÃO é opcional e deve ser documentada no output.

**Passo 1, Mapeamento de Estrutura (obrigatório):**

- [ ] Identificar root do projeto (`package.json`, `tsconfig.json`)  
- [ ] Mapear estrutura de pastas (`src/`, `app/`, `pages/`, `components/`, `lib/`, `utils/`)  
- [ ] Localizar arquivos de configuração críticos:  
      - `tailwind.config.*` (legado v3) ou `@theme` em CSS (v4)  
      - `postcss.config.*` ou `@tailwindcss/postcss`, `@tailwindcss/vite`, `@tailwindcss/webpack`  
      - `next.config.*` (atenção: `reactCompiler`, `turbopack`, `experimental`)  
      - `tsconfig.json` (strict, paths, moduleResolution)  
      - `.eslintrc.*` ou `eslint.config.*` (flat config)  
      - `.prettierrc` ou `prettier.config.*`  
      - `components.json` (shadcn, atenção ao schema novo)  
      - `vite.config.*`, `astro.config.*`, etc. dependendo do framework  
- [ ] Identificar entry points de CSS (`@import "tailwindcss"`, `globals.css`, `app.css`)  
- [ ] Verificar presença de arquivos de configuração de IA:  
      - `.cursorrules` (legado Cursor)  
      - `.cursor/rules/*.mdc` (Cursor moderno)  
      - `AGENTS.md` (convenção emergente cross-tool)  
      - `CLAUDE.md` ou `.claude/CLAUDE.md` (Claude Code)  
      - `.github/copilot-instructions.md` (GitHub Copilot)  
      - `shadcn/skills` (se shadcn CLI v4+)

**Passo 2, Detecção de Stack (obrigatório):**

- [ ] Framework: Next.js (App Router vs Pages Router) / Vite \+ React / TanStack Start / Astro / Remix / outro  
- [ ] React version (18.x, 19.x, 20.x). Em 2026, 19.x é o esperado para projetos ativos  
- [ ] **React Compiler ativo?** (build config: `reactCompiler: true` em Next 16, plugin em Vite/Babel). Determinar isso afeta toda a auditoria de performance  
- [ ] TypeScript version e strictness level (`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`)  
- [ ] **Tailwind version (v3.x vs v4.x), CRÍTICO determinar isso primeiro**  
- [ ] Estado do shadcn/ui (CLI version, primitives Radix vs Base UI, presets, registry)  
- [ ] Gerenciador de pacotes (npm/yarn/pnpm/bun)  
- [ ] Bundler (Turbopack/Vite/Webpack/Rspack)  
- [ ] Monorepo? (Turborepo/Nx/pnpm workspaces)

**Passo 3, Inventário de Padrões Existentes (obrigatório):**

- [ ] Como componentes são criados (convenções de naming, exports)  
- [ ] Onde vivem os componentes UI base (`components/ui`? `lib/components`? registry remoto?)  
- [ ] Existe util `cn`/`clsx` \+ `tailwind-merge`?  
- [ ] Existe sistema de variants (`cva`? `tailwind-variants`? manual?)  
- [ ] Como dark mode é implementado (class? `data-theme`? `@media (prefers-color-scheme)`?)  
- [ ] Tokens existentes (CSS variables? `@theme` v4? JSON DTCG? Style Dictionary?)  
- [ ] Padrões de acessibilidade já implementados (focus rings, sr-only, aria-\*, semantic HTML)  
- [ ] Padrões de Server Components vs Client Components (proporção de `"use client"`)  
- [ ] Padrões de data fetching (Server Components, Server Actions, TanStack Query, SWR)

**Passo 4, Identificação de Hotspots (obrigatório):**

- [ ] Componentes mais utilizados (imports frequentes)  
- [ ] Arquivos com mais linhas de CSS/classes  
- [ ] Componentes com lógica complexa (forms, tables, modals, command palettes)  
- [ ] Páginas/rotas principais  
- [ ] Áreas com código duplicado aparente  
- [ ] Pontos onde `"use client"` é usado de forma defensiva sem necessidade

### 1.2 Plano de Auditoria

Após a descoberta, crie um plano de auditoria específico para o projeto antes de executar. O plano deve listar:

1. **Prioridades** baseadas no estado real (o que é mais crítico para ESTE projeto)  
2. **Ordem de análise** (quais categorias primeiro, baseado nas dependências)  
3. **Riscos identificados** (o que pode quebrar, o que precisa cuidado especial)  
4. **Quick wins óbvios** (melhorias de baixo esforço/alto impacto já visíveis)

---

## 2\) OBJETIVO (REVISÃO PROFUNDA 2026-READY)

Revisar e elevar o projeto existente para padrão profissional 2026 com:

1. **Componentização e reutilização**, Design System / UI primitives / patterns  
2. **Tokenização sólida**, Design tokens W3C DTCG v2025.10, hierarquia 3 camadas  
3. **Tailwind CSS estado da arte**, v4 CSS-first, OKLCH, Container Queries, logical properties  
4. **shadcn/ui best practices**, CLI v4, ownership, Radix vs Base UI, presets, registry workflow  
5. **Performance mensurável**, Core Web Vitals (INP), bundle size, React Compiler aproveitado  
6. **Acessibilidade completa**, WCAG 2.2 AA, focus management, RTL-ready  
7. **DX profissional**, Prettier, ESLint flat config, Husky, Visual Regression, CI  
8. **Configuração para IA**, `AGENTS.md`, Cursor rules, Claude skills, MCP servers

---

## 3\) REGRAS ANTI-ALUCINAÇÃO E EVIDÊNCIA (OBRIGATÓRIO)

### 3.1 Regras Absolutas

- Trabalhe SOMENTE com o que você encontrar no repositório  
- Nunca invente arquivos, rotas, APIs, dependências, versões ou padrões  
- Toda afirmação relevante deve apontar "onde está no código" com:  
  - Caminho do arquivo  
  - Nome do símbolo (componente/função/variável)  
  - Localização aproximada ("linha X", "perto do topo", "na exportação")  
- Se não encontrar algo, diga explicitamente "não encontrado no repo"  
- Se ferramentas de IA (MCP, agent skills) afirmarem algo que você não conseguiu validar diretamente no arquivo, marque como "alegado pela ferramenta, verificar"

### 3.2 Tratamento de Incerteza

- Quando houver incerteza (ex.: coexistem padrões v3 e v4, ou compiler ativo só em parte do código), apresente as opções  
- Explique a recomendação com base no que foi encontrado  
- Marque claramente o que é "encontrado" vs "inferido" vs "recomendado"

### 3.3 Criação de Novos Artefatos

Ao sugerir criar algo novo (componente/hook/util/token), SEMPRE explique:

- **(a) Por que é necessário**: qual problema resolve  
- **(b) Verificação de duplicação**: como você confirmou que não existe  
- **(c) Impacto**: o que muda, o que depende disso  
- **(d) Risco**: o que pode quebrar, edge cases

---

## 4\) REFERÊNCIA TÉCNICA 2026 (BENCHMARKS E PADRÕES)

### 4.1 Tailwind CSS v4.x (Estado Atual 2026\)

**Versionamento atual:** Tailwind segue modelo rolling. A v4.0 saiu em jan/2025, a v4.1 adicionou text-shadow, a v4.2 (fev/2026) trouxe plugin oficial pra webpack, 4 paletas novas, logical properties expandidas e recompilação 3.8x mais rápida, e a v4.3 (mai/2026) adicionou first-party scrollbar styling, zoom utilities, tab-size e `@variant` melhorado.

**Tailwind v3 status:** end-of-life informal. Apenas a última minor recebe correções por compatibilidade com browsers antigos que não suportam `@property`. Migração para v4 é fortemente recomendada para projetos com browsers modernos como target.

**Performance Engine Oxide (Rust):**

- Full build: \~100ms (3.78x mais rápido que v3)  
- Incremental (novo CSS): \~5ms (8.8x mais rápido)  
- Incremental (sem CSS novo): \~192µs (182x mais rápido)

**Arquitetura CSS-first:**

/\* v4: configuração via CSS, sem tailwind.config.js \*/

@import "tailwindcss";

@theme {

  \--color-primary: oklch(59.62% 0.156 264.05);

  \--font-display: "Satoshi", sans-serif;

  \--breakpoint-3xl: 1920px;

  \--spacing-18: 4.5rem;

}

**Breaking Changes v3 → v4 (críticos):**

| v3 | v4 | Ação |
| :---- | :---- | :---- |
| `shadow` | `shadow-sm` | Adicionar suffix |
| `blur` | `blur-sm` | Adicionar suffix |
| `rounded` | `rounded-sm` | Adicionar suffix |
| `outline-none` | `outline-hidden` | Renomear |
| `ring` (3px) | `ring` (1px) | Verificar design |
| `tailwind.config.js` | `@theme {}` em CSS | Migrar config |
| Sass/Less/Stylus | Incompatível | Migrar para CSS puro |
| `bg-opacity-50` | `bg-black/50` | Sintaxe modern slash |

**Ferramenta de Migração:**

npx @tailwindcss/upgrade  \# Requer Node.js 20+

**Features modernas v4 a auditar:**

- Container Queries built-in (`@container`, `@sm:`, `@lg:`)  
- 3D Transforms (`rotate-x-*`, `rotate-y-*`, `perspective-*`)  
- Gradientes OKLCH com interpolação perceptual  
- `@starting-style` para animações CSS-only sem JS  
- `@utility` para utilities customizadas  
- Text shadow utilities (v4.1+)  
- Logical properties expandidas (`pbs-*`, `pbe-*`, `mbs-*`, `mbe-*`, `inset-s-*`, `inset-e-*`) (v4.2+)  
- First-party scrollbar styling (v4.3+)  
- Zoom utilities, tab-size (v4.3+)

**Suporte Browsers:** Safari 16.4+, Chrome 111+, Firefox 128+. Dependente de `@property` CSS rule.

### 4.2 OKLCH Color Space (default Tailwind v4)

**Por que OKLCH:**

- Uniformidade perceptual (L representa luminosidade real)  
- Gamut P3 (30% mais cores que sRGB)  
- Contraste previsível para acessibilidade  
- Default do Tailwind v4  
- 92%+ suporte global em 2026

**Sintaxe:**

oklch(L C H / alpha)

/\* L: 0 a 1 (lightness), C: 0 a \~0.4 (chroma), H: 0 a 360 (hue) \*/

\--color-primary: oklch(59.62% 0.156 264.05);

\--color-primary-hover: oklch(54% 0.156 264.05); /\* Só L muda \*/

**Migração HSL → OKLCH:**

- Gradual, começando por cores primárias  
- Ferramentas: oklch.com, UIColors.app, Huetone  
- Manter fallbacks `@supports not (color: oklch(0% 0 0))` se browsers antigos são target

### 4.3 Design Tokens W3C DTCG v2025.10

**Status:** Primeira versão estável (out/2025), production-ready. Adotada por Adobe, Google, Salesforce, Shopify, Figma, Framer e outros.

**Hierarquia 3 Camadas (padrão da indústria):**

┌─────────────────────────────────────────────────────────┐

│ LAYER 1: GLOBAL/PRIMITIVE (Core)                        │

│ Valores brutos, nunca mudam entre temas                 │

│ Ex: blue-500, gray-900, spacing-4                       │

├─────────────────────────────────────────────────────────┤

│ LAYER 2: SEMANTIC (Alias)                               │

│ Significado contextual, MUDA entre temas                │

│ Ex: color-primary, color-background, color-text         │

├─────────────────────────────────────────────────────────┤

│ LAYER 3: COMPONENT (Específico)                         │

│ Tokens específicos de componente, herda do Semantic     │

│ Ex: button-primary-bg, card-border, input-focus-ring    │

└─────────────────────────────────────────────────────────┘

**Formato JSON (DTCG):**

{

  "color": {

    "$type": "color",

    "blue": {

      "500": { "$value": "oklch(63% 0.194 238.75)" }

    },

    "primary": { "$value": "{color.blue.500}" },

    "button": {

      "primary": {

        "background": { "$value": "{color.primary}" }

      }

    }

  }

}

**Ferramentas compatíveis:** Style Dictionary v4+, Tokens Studio, Specify, Penpot, Supernova.

### 4.4 shadcn/ui (Estado 2026, transformação radical)

**Filosofia mantida:** Copy-paste ownership (código vive no SEU projeto).

**Mudanças críticas 2025-2026:**

- **CLI v4** (março 2026): suporte a presets, `--dry-run`, `--diff`, `--view`, `shadcn apply`, `shadcn docs <component>`  
- **Base UI como primitive alternativa ao Radix** via `--base radix` ou `--base baseui`. Base UI tem bundle menor e zero estilos.  
- **shadcn/skills**: context layer pra coding agents (Claude, Cursor) entenderem APIs, primitives e workflows  
- **Design System Presets**: empacotam tokens, fontes, radius e ícones em uma string portável  
- **Registry Directory**: marketplace de registries third-party (Tailark, Kibo UI, Origin UI, Kokonut UI, etc.)  
- **Namespaced Registries**: múltiplos design systems no mesmo projeto  
- **RTL Support nativo** com `--rtl` flag  
- **MCP Server** para integração com IA  
- **Cross-framework**: scaffolding pra Next.js, Vite, TanStack Start, React Router, Astro, Laravel  
- **1.300+ blocks disponíveis** (vs \~35 componentes em 2024\)  
- **Package imports** (`#components/*` via `package.json#imports`) a partir do shadcn 4.7.0 (mai/2026)

**Estrutura Típica 2026:**

components/

└── ui/

    ├── button.tsx

    ├── card.tsx

    ├── ...

.cursor/

└── rules/

    └── shadcn.mdc          \# ou AGENTS.md

shadcn/

└── skills/                  \# gerado por shadcn skills install

components.json              \# schema atualizado: base, registries, presets

**Prós (válidos):**

- Bundle muito menor que alternativas all-in-one  
- Tree-shaking source-level  
- Ownership completo, zero vendor lock-in  
- Agentic-ready (shadcn/skills \+ MCP)

**Contras (críticos):**

- Updates manuais (mas `shadcn diff` ajuda)  
- Dependências de terceiros (Radix/Base UI, cmdk, cva) ainda precisam ser atualizadas via npm  
- Tailwind obrigatório  
- Você mantém o código

**Quando NÃO usar:**

- Equipe sem experiência Tailwind  
- Necessidade de updates 100% automáticos via npm  
- Requer ecosystem com 100+ componentes prontos sem customização

### 4.5 React 19 \+ React Compiler (Estado da Arte 2026\)

**React 19 (estável desde dez/2024, série 19.2.x corrente em 2026):**

- Server Components estáveis  
- Server Actions (`'use server'`)  
- `useActionState`, `useOptimistic`, `useFormStatus`  
- `use()` hook  
- Document metadata nativo (`<title>`, `<meta>` em qualquer componente)  
- Resource preloading (`prefetchDNS`, `preconnect`, `preload`, `preinit`)

**React Compiler v1.0 (estável desde out/2025):**

- Auto-memoization em build time  
- Padrão em Next.js 16 (`reactCompiler: true`), Expo SDK 54, e disponível em Vite via plugin  
- Torna `useMemo`, `useCallback`, `React.memo` **majoritariamente desnecessários** em código novo  
- Análise estática por reactive scope, mais granular que memoization manual  
- Respeita memoization manual existente (não conflita, mas pode causar double-memoization)

**Implicações para auditoria:**

- Se compiler está ativo: `useMemo`/`useCallback` em código novo é code smell (verbose sem ganho)  
- Se compiler NÃO está ativo: ativar é quick win de alto impacto  
- ESLint plugin `eslint-plugin-react-compiler` detecta código que quebra as regras do compiler (mutação de props, side effects em render)  
- Migração: usar `'use no memo'` em arquivos específicos se houver código incompatível

### 4.6 Next.js 16.x (Estado da Arte 2026\)

**Versão atual:** 16.2.x (março/2026), com 16.1 lançado em dez/2025.

**Features chave:**

- **Turbopack stable** para dev e build  
- **Server Fast Refresh** (hot reload fine-grained em Server Components)  
- **Adapter API estável** (para deploy em qualquer plataforma)  
- **Turbopack File System Caching** (next dev incremental)  
- **React Compiler built-in** (`reactCompiler: true`)  
- **Browser Log Forwarding** (errors do browser vão pro terminal, útil pra agentes)  
- **Agent DevTools** (experimental, dá acesso de terminal a React DevTools pra agentes)  
- **`after()` API estável** (executar código após response streaming)  
- **`forbidden()` / `unauthorized()`** (granular auth errors)

**Padrões obrigatórios em projetos modernos:**

- App Router (Pages Router em modo legado)  
- Server Components por default, `'use client'` apenas quando necessário  
- Server Actions para mutations  
- Streaming com Suspense  
- Parallel Routes e Intercepting Routes onde aplicável  
- Async request APIs (`cookies()`, `headers()`, `params`, `searchParams` agora são Promises em rotas dinâmicas)

### 4.7 Métricas de Performance (Benchmarks 2026\)

**Bundle Size:**

| Categoria | Ruim | Médio | Bom | Excelente |
| :---- | :---- | :---- | :---- | :---- |
| CSS Produção | \>100KB | 50-100KB | 15-50KB | \<15KB |
| CSS Gzipped | \>30KB | 15-30KB | 5-15KB | \<5KB |
| JS Total (client) | \>500KB | 200-500KB | 100-200KB | \<100KB |
| First Load JS | \>300KB | 150-300KB | 80-150KB | \<80KB |

**Core Web Vitals (INP substituiu FID desde mar/2024):**

| Métrica | Ruim | Precisa Melhorar | Bom |
| :---- | :---- | :---- | :---- |
| LCP | \>4.0s | 2.5-4.0s | \<2.5s |
| INP | \>500ms | 200-500ms | \<200ms |
| CLS | \>0.25 | 0.1-0.25 | \<0.1 |
| FCP | \>3.0s | 1.8-3.0s | \<1.8s |
| TTFB | \>1.8s | 0.8-1.8s | \<0.8s |

**Build Time (Tailwind v4):**

| Tipo | Tempo |
| :---- | :---- |
| Full build | \~100ms |
| Incremental | \~5ms |
| No-op | \~192µs |

### 4.8 Acessibilidade (WCAG 2.2 AA, status real em 2026\)

**Status crítico do WCAG 3.0 e APCA (correção importante):**

- **WCAG 2.2 AA é o padrão legal vigente** (ADA, EAA, leis nacionais). Não vai mudar tão cedo.  
- **WCAG 3.0 segue em Working Draft.** Próxima Recomendação prevista entre 2028 e 2030\.  
- **APCA NÃO está no draft atual do WCAG 3.0.** Foi removida em julho/2023 por ser exploratória e não ter consenso do working group. Usar APCA como base de compliance hoje cria risco legal porque ferramentas automáticas de auditoria usam WCAG 2.x.  
- **Recomendação prática:** se quiser experimentar APCA, garanta que as cores escolhidas TAMBÉM passem no critério WCAG 2.2 (4.5:1 texto, 3:1 UI). Documente a escolha.

**WCAG 2.2 Requisitos Críticos:**

| Critério | Requisito | Implementação Tailwind |
| :---- | :---- | :---- |
| 1.4.3 Contraste | 4.5:1 texto, 3:1 UI | Paleta OKLCH validada |
| 2.4.7 Focus Visible | Indicador visível | `focus-visible:ring-2` |
| 2.4.11 Focus Not Obscured | Focus não coberto | z-index, scroll-margin |
| 2.5.8 Target Size | Mínimo 24x24px | `min-h-6 min-w-6` |
| 3.3.7 Redundant Entry (novo 2.2) | Não pedir info repetida | UX pattern |
| 3.3.8 Accessible Authentication | Sem testes cognitivos | UX pattern |

**Contraste Mínimo WCAG 2.2 AA:**

- Texto normal: 4.5:1  
- Texto grande (18px+ ou 14px+ bold): 3:1  
- Componentes UI interativos: 3:1  
- State changes (hover/focus): 3:1

**Patterns Obrigatórios:**

// Focus visible (keyboard-only)

className="focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-ring"

// Screen reader only

\<button\>

  \<Icon /\>

  \<span className="sr-only"\>Descrição para leitores de tela\</span\>

\</button\>

// Reduced motion

className="motion-safe:animate-bounce motion-reduce:animate-none"

// RTL-aware (logical properties Tailwind v4)

className="ps-4 pe-2"  // inline-start, inline-end (substituem pl-4 pr-2)

**Ferramentas:**

- axe DevTools (browser extension)  
- Lighthouse (Chrome DevTools)  
- Pa11y (CLI)  
- @axe-core/react (runtime)  
- eslint-plugin-jsx-a11y (lint estático)

### 4.9 Tooling Obrigatório 2026

**VS Code Extensions essenciais:**

- Tailwind CSS IntelliSense (v0.14+ com linting CSS e markup)  
- Error Lens (inline errors)  
- Prettier  
- ESLint (modo flat config)

**Prettier \+ Tailwind:**

// .prettierrc

{

  "plugins": \["prettier-plugin-tailwindcss"\],

  "tailwindStylesheet": "./src/styles/app.css"

}

**ESLint Flat Config (padrão em 2026):**

npm install \-D eslint-plugin-tailwindcss eslint-plugin-react-compiler eslint-plugin-jsx-a11y

Rules importantes:

- `tailwindcss/no-custom-classname`, previne classes não-Tailwind  
- `tailwindcss/no-contradicting-classname`, detecta conflitos (`p-2 p-3`)  
- `tailwindcss/enforces-shorthand`, `size-full` vs `w-full h-full`  
- `tailwindcss/no-unnecessary-arbitrary-value`, `m-[1.25rem]` → `m-5`  
- `react-compiler/react-compiler`, valida compatibilidade com Compiler  
- `jsx-a11y/*`, acessibilidade

**Husky \+ lint-staged:**

// .lintstagedrc.js

module.exports \= {

  "\*.{js,jsx,ts,tsx}": \["eslint \--fix", "prettier \--write"\],

  "\*.css": \["prettier \--write"\]

};

**Visual Regression:**

- Lost Pixel (open-source, GitHub Actions)  
- Chromatic (Storybook-focused)  
- Percy (cross-browser, paid)  
- Playwright Visual Comparisons (built-in)

**Configuração para IA (NOVO em 2026):**

- `AGENTS.md` na raiz do repo (convenção cross-tool emergente)  
- `.cursor/rules/*.mdc` (Cursor, substituiu `.cursorrules`)  
- `CLAUDE.md` ou `.claude/CLAUDE.md` (Claude Code)  
- `.github/copilot-instructions.md`  
- `shadcn/skills` instalado se usa shadcn CLI v4+  
- MCP servers configurados em `.mcp.json` ou equivalente do tool

### 4.10 Timeline de Migração Realista

| Tamanho Codebase | Timeline Tailwind v3→v4 | Timeline React Compiler | Equipe |
| :---- | :---- | :---- | :---- |
| Pequeno (\<10k LOC) | 1-2 semanas | 2-3 dias | 1 dev |
| Médio (10k-50k LOC) | 3-4 semanas | 1-2 semanas | 2 devs |
| Grande (\>50k LOC) | 2-3 meses | 3-4 semanas | Equipe dedicada |

---

## 5\) ESCOPO DE AUDITORIA (CHECKLIST PROFISSIONAL)

### 5.A) Tailwind CSS, estado da arte v4

**Detecção de Versão (PRIMEIRO PASSO):**

- [ ] Qual versão no `package.json`?  
- [ ] Configuração: `tailwind.config.*` (v3) ou `@theme` em CSS (v4)?  
- [ ] Directives: `@tailwind base/components/utilities` (v3) ou `@import "tailwindcss"` (v4)?  
- [ ] PostCSS plugin: `postcss-import` \+ `tailwindcss` (v3) ou `@tailwindcss/postcss` (v4)?  
- [ ] Vite plugin (`@tailwindcss/vite`) ou Webpack plugin (`@tailwindcss/webpack`, v4.2+)?

**Se v3 detectado, avaliar:**

- [ ] Viabilidade de migração para v4 (browsers target suportam `@property`?)  
- [ ] Bloqueadores: Sass/Less? Dependências de config JS dinâmica?  
- [ ] Plano incremental de migração (usar `@tailwindcss/upgrade`)  
- [ ] Risco de manter v3 (sem novas features, apenas patches críticos)

**Se v4 detectado, auditar:**

- [ ] `@theme` configurado corretamente?  
- [ ] Migração completa de `tailwind.config.js`?  
- [ ] OKLCH sendo usado para cores?  
- [ ] Container Queries onde aplicável?  
- [ ] Logical properties (`ps-*`, `pe-*`, `ms-*`, `me-*`) em layouts que precisam RTL?  
- [ ] Renames aplicados (`shadow`→`shadow-sm`, `outline-none`→`outline-hidden`)?  
- [ ] Sintaxe slash para opacity (`bg-black/50` em vez de `bg-black bg-opacity-50`)?

**Organização de Classes:**

- [ ] Strings gigantes sem padrão? (\>10 classes inline)  
- [ ] Conflitos de classes? (`p-2 p-4`, `text-sm text-lg`)  
- [ ] Uso de `cn`/`clsx` \+ `tailwind-merge`?  
- [ ] Sistema de variants? (`cva`? `tailwind-variants`? manual?)  
- [ ] Arbitrary values em excesso? (`[...]` repetidos que deveriam ser tokens)

**@apply e @utility:**

- [ ] `@apply` usado apenas para padrões reutilizáveis (3+ ocorrências)?  
- [ ] `@utility` (v4) usado para utilities customizadas em vez de `@layer utilities`?  
- [ ] Não está usando `@apply` para "limpar código" (anti-pattern)?

**Responsividade:**

- [ ] Mobile-first? (classes base para mobile, breakpoints para desktop)  
- [ ] Breakpoints consistentes? (`sm`, `md`, `lg`, `xl`, `2xl`, `3xl` se v4)  
- [ ] Container queries onde componente precisa responder ao container?

**Estados Interativos:**

- [ ] `hover`/`focus`/`active`/`disabled` consistentes?  
- [ ] `focus-visible` para keyboard-only focus?  
- [ ] `motion-safe`/`motion-reduce` para animações?  
- [ ] Contraste suficiente em todos estados?

### 5.B) Design Tokens, arquitetura 3 camadas

**Mapeamento de Estado Atual:**

- [ ] Onde vivem os tokens? (CSS vars? `@theme`? JSON DTCG? inline?)  
- [ ] Existe hierarquia ou tudo é flat?  
- [ ] Dark mode como é implementado? (class? `data-theme`? `@media`?)  
- [ ] Cores são semânticas ou presentacionais? (`bg-blue-500` vs `bg-primary`)

**Verificar/Implementar Hierarquia:**

Layer 1, Global/Primitive:

\- \[ \] Cores brutas definidas? (blue-500, gray-900)

\- \[ \] Spacing scale definida?

\- \[ \] Typography scale definida?

\- \[ \] Não mudam entre temas

Layer 2, Semantic:

\- \[ \] Cores semânticas? (primary, secondary, background, foreground, muted, accent, destructive)

\- \[ \] Mudam entre light/dark?

\- \[ \] Aliases para primitives?

Layer 3, Component:

\- \[ \] Tokens específicos de componente existem?

\- \[ \] Herdam do semantic?

\- \[ \] button-primary-bg, card-border, input-focus-ring?

**OKLCH:**

- [ ] Projeto usa OKLCH ou RGB/HSL?  
- [ ] Se HSL/RGB: plano de migração gradual?  
- [ ] Contraste validado em OKLCH?

**Dark Mode:**

- [ ] Implementação: `class="dark"`? `data-theme="dark"`? `@media`?  
- [ ] Tokens semânticos mudam corretamente?  
- [ ] Contraste validado em dark mode?  
- [ ] Flash prevention? (script no `<head>` ou `next-themes`?)  
- [ ] System preference detection?

### 5.C) shadcn/ui \+ Radix/Base UI

**Detecção:**

- [ ] `components.json` existe? Schema atualizado (CLI v4+)?  
- [ ] Pasta `components/ui/` existe?  
- [ ] Quais componentes instalados?  
- [ ] Versões das dependências (Radix UI unificado ou packages individuais, Base UI, cmdk, cva)?  
- [ ] `shadcn/skills` instalado para uso com agentes?  
- [ ] Preset configurado em `components.json`?

**Auditoria de Componentes:**

- [ ] Estrutura moderna (sem `forwardRef` desnecessário em React 19)?  
- [ ] `data-state` atributos do Radix/Base UI preservados?  
- [ ] Composição com primitives (`Dialog.Root`, `Dialog.Trigger`, etc.)?  
- [ ] TypeScript props bem tipadas?  
- [ ] Variants usando `cva` ou equivalente?  
- [ ] `'use client'` apenas onde há interatividade real?

**Acessibilidade Radix/Base UI:**

- [ ] Keyboard navigation funcionando?  
- [ ] Focus management em modals/dropdowns?  
- [ ] ARIA attributes presentes?  
- [ ] Screen reader announcements?

**Manutenção:**

- [ ] Convenção de update definida (`shadcn diff`)?  
- [ ] Customizações documentadas?  
- [ ] Risco de divergência mapeado?  
- [ ] Changelog de modificações?

### 5.D) React 19 \+ Next.js 16, arquitetura moderna

**Detecção de Stack:**

- [ ] Next.js version?  
- [ ] App Router ou Pages Router?  
- [ ] React version (19.x esperado)?  
- [ ] React Compiler ativo? (`reactCompiler: true` em `next.config.*`?)  
- [ ] TypeScript strictness level?  
- [ ] Turbopack ativo?

**Server Components (se App Router):**

- [ ] Minimizando `'use client'`?  
- [ ] Server Components onde possível?  
- [ ] Client Components apenas quando necessário (interatividade, hooks, browser APIs)?  
- [ ] Suspense boundaries para loading states?  
- [ ] Server Actions para mutations (substituem API routes em muitos casos)?  
- [ ] `use()` hook para promises em Client Components?

**Performance Arquitetural com React Compiler:**

- [ ] Se compiler ativo: `useMemo`/`useCallback` desnecessários sendo limpos?  
- [ ] Se compiler ativo: ESLint detectando código incompatível?  
- [ ] Se compiler NÃO ativo: viabilidade de ativar?  
- [ ] `useEffect` desnecessários?  
- [ ] State que poderia ser derivado?  
- [ ] Prop drilling excessivo?  
- [ ] Context overuse?

**Composição de Componentes:**

- [ ] Separação container/presentational?  
- [ ] Hooks extraídos para lógica reutilizável?  
- [ ] API de props consistente?  
- [ ] Compound components onde apropriado?

**Padronização:**

- [ ] Naming conventions consistentes?  
- [ ] Estrutura de pastas padronizada?  
- [ ] Exports consistentes (named vs default)?  
- [ ] kebab-case para diretórios?  
- [ ] PascalCase para componentes?

### 5.E) Acessibilidade, WCAG 2.2 AA

**Focus Management:**

- [ ] Nunca removendo focus sem substituir?  
- [ ] `focus-visible` para keyboard-only?  
- [ ] Focus ring com contraste 3:1?  
- [ ] Focus trap em modals?  
- [ ] Skip links para navegação?  
- [ ] Focus not obscured (2.4.11)?

**Screen Readers:**

- [ ] `sr-only` em botões com ícone?  
- [ ] Labels em form inputs?  
- [ ] `aria-label`/`aria-labelledby` onde necessário?  
- [ ] `aria-live` para conteúdo dinâmico?  
- [ ] Headings hierárquicos (h1→h2→h3)?  
- [ ] Landmarks (`<main>`, `<nav>`, `<aside>`)?

**Componentes Interativos:**

- [ ] Navegação por teclado funcionando?  
- [ ] Enter/Space para ativar?  
- [ ] Escape para fechar?  
- [ ] Arrow keys para navegação em listas?  
- [ ] Estados disabled claramente indicados?  
- [ ] Target size 24x24px mínimo (2.5.8)?

**Contraste WCAG 2.2:**

- [ ] Texto normal: 4.5:1?  
- [ ] Texto grande: 3:1?  
- [ ] UI components: 3:1?  
- [ ] State changes: 3:1?  
- [ ] Validado em light E dark mode?  
- [ ] Se usa APCA experimental: cores também passam em WCAG 2.2?

**Motion:**

- [ ] `motion-reduce` respeitado?  
- [ ] Animações pausáveis?  
- [ ] Sem conteúdo piscando \>3x/segundo?

**UX States:**

- [ ] Loading states claros (Suspense, skeleton)?  
- [ ] Empty states informativos?  
- [ ] Error states com mensagens úteis?  
- [ ] Success feedback presente?  
- [ ] Microcopy consistente?

### 5.F) Tooling, DX e CI

**Prettier:**

- [ ] `prettier-plugin-tailwindcss` instalado?  
- [ ] Configurado para ordenar classes?  
- [ ] `.prettierrc` presente?  
- [ ] Integrado no editor?

**ESLint (Flat Config):**

- [ ] Usando `eslint.config.*` (flat config) em vez de `.eslintrc`?  
- [ ] `eslint-plugin-tailwindcss` instalado?  
- [ ] Rules ativas: `no-contradicting-classname`, `enforces-shorthand`?  
- [ ] `eslint-plugin-react-compiler` se compiler ativo?  
- [ ] `eslint-plugin-jsx-a11y` para acessibilidade?  
- [ ] Configuração consistente?

**Git Hooks:**

- [ ] Husky instalado?  
- [ ] `lint-staged` configurado?  
- [ ] Pre-commit rodando lint/format?  
- [ ] Pre-push rodando testes?

**CI Pipeline:**

- [ ] Lint check no CI?  
- [ ] Type check no CI?  
- [ ] Testes no CI?  
- [ ] Visual regression? (Lost Pixel, Chromatic, Playwright)  
- [ ] Bundle size check (size-limit, bundlewatch)?  
- [ ] Lighthouse CI ou WebPageTest?  
- [ ] Acessibilidade (axe-core no CI)?

**Documentação:**

- [ ] Storybook presente?  
- [ ] Componentes documentados?  
- [ ] Props documentadas?  
- [ ] Exemplos de uso?

### 5.G) Performance, dados e métricas

**Render Performance (com React Compiler):**

- [ ] Compiler removeu necessidade de memoization manual?  
- [ ] Re-renders evitáveis remanescentes? (React DevTools Profiler)  
- [ ] Keys estáveis em listas?  
- [ ] `useEffect` com deps corretas?  
- [ ] Suspense para code splitting?

**Bundle:**

- [ ] Dynamic imports para não-críticos?  
- [ ] Tree shaking funcionando?  
- [ ] CSS purge configurado corretamente?  
- [ ] Análise de bundle (`@next/bundle-analyzer`, `webpack-bundle-analyzer`)?  
- [ ] Bibliotecas pesadas substituídas por alternativas leves?

**Assets:**

- [ ] `next/image` para imagens?  
- [ ] Formatos modernos (WebP, AVIF)?  
- [ ] Lazy loading?  
- [ ] Sizes/srcset definidos?  
- [ ] Fonts otimizadas (`next/font`, display swap, preload)?

**Core Web Vitals:**

- [ ] LCP \< 2.5s?  
- [ ] **INP \< 200ms** (substituiu FID)?  
- [ ] CLS \< 0.1?  
- [ ] FCP \< 1.8s?  
- [ ] Instrumentação presente (Vercel Analytics, Web Vitals, Sentry)?

### 5.H) Configuração para IA

**Arquivos de Instrução para Agentes:**

- [ ] `AGENTS.md` na raiz (convenção cross-tool)?  
- [ ] `.cursor/rules/*.mdc` (Cursor moderno)?  
- [ ] `CLAUDE.md` ou `.claude/CLAUDE.md` (Claude Code)?  
- [ ] `.github/copilot-instructions.md` (Copilot)?  
- [ ] `shadcn/skills` instalado (se shadcn CLI v4+)?

**Conteúdo Recomendado:**

- [ ] Stack definition (Next.js 16 \+ React 19 \+ Tailwind v4 \+ TypeScript \+ shadcn)  
- [ ] Componentes disponíveis em `/components/ui`  
- [ ] Padrões de código (functional, hooks, cva)  
- [ ] Ordem de classes (deixar pro Prettier)  
- [ ] Regras de acessibilidade (WCAG 2.2 AA)  
- [ ] Regras de performance (Server Components first, React Compiler ativo)  
- [ ] O que NÃO fazer (anti-patterns específicos do projeto)  
- [ ] Convenções de commit (Conventional Commits?)  
- [ ] Como rodar testes, lint, build

**MCP Servers (se aplicável):**

- [ ] Configuração de MCP em `.mcp.json` ou similar?  
- [ ] MCP do shadcn ativo?  
- [ ] MCPs de ferramentas usadas (Figma, Supabase, etc.)?

---

## 6\) PROCESSO DE TRABALHO (SEQUÊNCIA OBRIGATÓRIA)

**Fase 1: Descoberta (NÃO PULAR)**

1. Executar mapeamento de estrutura (seção 1.1)  
2. Detectar stack completa  
3. Inventariar padrões existentes  
4. Identificar hotspots

**Fase 2: Planejamento (NÃO PULAR)**

1. Criar plano de auditoria específico  
2. Definir prioridades baseadas no estado real  
3. Identificar riscos  
4. Listar quick wins óbvios

**Fase 3: Auditoria Profunda**

1. Executar checklist por categoria (seção 5\)  
2. Documentar evidências com localização no código  
3. Classificar severidade de cada issue  
4. Mapear dependências entre issues

**Fase 4: Recomendações**

1. Priorizar por impacto/esforço  
2. Criar snippets de solução  
3. Mapear arquivos afetados  
4. Avaliar riscos de cada mudança

**Fase 5: Plano de Ação**

1. Quick wins (implementar imediatamente)  
2. Short term (1-2 sprints)  
3. Medium term (1-2 meses)  
4. Long term (roadmap)

---

## 7\) FORMATO DE SAÍDA (USE EXATAMENTE ESTES TÍTULOS)

### 1\. Resumo Executivo

- Máximo 10 bullets  
- Estado geral do projeto  
- Top 3 issues críticos  
- Top 3 quick wins  
- Recomendação geral (migrar? refatorar? manter?)

### 2\. Mapa do Projeto (Descoberta)

- Stack detectada (framework, versões, configs)  
- Estrutura de pastas  
- Arquivos de configuração críticos  
- Padrões identificados  
- Hotspots mapeados

### 3\. Estado do Tailwind e Tema

- Versão detectada (v3 ou v4)  
- Localização da configuração  
- Sistema de tokens atual  
- Dark mode implementation  
- OKLCH status  
- Recomendação de migração (se aplicável)

### 4\. Diagnóstico por Categoria

Para CADA categoria, usar formato:

\#\#\#\# 4.X \[Nome da Categoria\]

\*\*Estado Atual:\*\* \[Resumo em 1-2 frases\]

\*\*Issues Encontrados:\*\*

| \# | Issue | Severidade | Evidência | Impacto |

|---|-------|------------|-----------|---------|

| 1 | ... | Alta/Média/Baixa | arquivo:localização | ... |

\*\*Recomendações:\*\*

| \# | Ação | Esforço | Risco | Arquivos |

|---|------|---------|-------|----------|

| 1 | ... | Alto/Médio/Baixo | ... | ... |

\*\*Snippet de Solução (se aplicável):\*\*

\\\`\\\`\\\`code

// Antes

...

// Depois

...

\\\`\\\`\\\`

Categorias:

- 4.1 Arquitetura/Componentização (React 19 / Next.js 16\)  
- 4.2 Tailwind CSS v4 (padrões, conflitos, variants, container queries)  
- 4.3 Tokenização/Design Tokens (3 camadas, OKLCH, DTCG)  
- 4.4 shadcn/ui (CLI v4, Radix/Base UI, presets, registry)  
- 4.5 Performance (React Compiler, render, bundle, Core Web Vitals)  
- 4.6 Acessibilidade e UX (WCAG 2.2 AA)  
- 4.7 Tooling/DX/CI (Prettier, ESLint flat, hooks, visual regression)  
- 4.8 Configuração para IA (AGENTS.md, Cursor rules, Claude skills, MCP)

### 5\. Matriz de Priorização

| \# | Item | Impacto | Esforço | Risco | Categoria | Arquivos Afetados |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| 1 | ... | Alto/Médio/Baixo | ... | ... | ... | ... |

Ordenar por: Impacto Alto \+ Esforço Baixo primeiro (quick wins).

### 6\. Plano de Ação Incremental

#### Quick Wins (Esta Semana)

- [ ] Item 1  
- [ ] Item 2

#### Short Term (1-2 Sprints)

- [ ] Item 1  
- [ ] Item 2

#### Medium Term (1-2 Meses)

- [ ] Item 1  
- [ ] Item 2

#### Long Term (Roadmap)

- [ ] Item 1  
- [ ] Item 2

### 7\. Convenções Propostas do Projeto

Documentar padrões recomendados para manter qualidade:

\#\# Convenções de Código

\#\#\# Componentes

\- ...

\#\#\# Tailwind v4

\- ...

\#\#\# Tokens

\- ...

\#\#\# Acessibilidade WCAG 2.2 AA

\- ...

\#\#\# React Compiler

\- ...

### 8\. Templates Recomendados para IA

Gerar:

- `AGENTS.md` específico para o projeto baseado na auditoria  
- `.cursor/rules/*.mdc` se Cursor está sendo usado  
- `CLAUDE.md` se Claude Code está sendo usado

### 9\. Checklist de Qualidade para Novas Features

\#\# Checklist PR

\#\#\# Componentes

\- \[ \] API consistente (variants/sizes/states)

\- \[ \] TypeScript props tipadas

\- \[ \] Sem duplicação

\- \[ \] Server Component por default, Client Component só se necessário

\#\#\# Tokens

\- \[ \] Sem hardcode de cor/spacing/typo

\- \[ \] Usando tokens semânticos (não primitivos diretamente)

\#\#\# Tailwind

\- \[ \] Classes ordenadas (Prettier)

\- \[ \] Sem conflitos

\- \[ \] Usando cn/cva

\- \[ \] Logical properties onde RTL importa

\#\#\# Acessibilidade

\- \[ \] focus-visible presente

\- \[ \] Labels em inputs

\- \[ \] sr-only em ícones

\- \[ \] Keyboard navigation testada

\- \[ \] Target size mínimo 24x24px

\#\#\# UX States

\- \[ \] Loading state

\- \[ \] Empty state

\- \[ \] Error state

\- \[ \] Success feedback

\#\#\# Performance

\- \[ \] Keys estáveis

\- \[ \] Compiler-friendly (sem mutação de props, sem side effects em render)

\- \[ \] Sem useEffect desnecessário

\- \[ \] Sem useMemo/useCallback redundantes se Compiler ativo

\#\#\# Evidência

\- \[ \] Testado em light/dark mode

\- \[ \] Testado mobile

\- \[ \] Visual regression passou

\- \[ \] axe-core sem violações

---

## 8\) ANTI-PATTERNS A DETECTAR

### Tailwind Anti-patterns

// Classes dinâmicas quebradas (Tailwind não gera)

\<div className={\`text-${color}-500\`} /\>

// Mapeamento explícito

const colorMap \= { red: 'text-red-500', blue: 'text-blue-500' };

\<div className={colorMap\[color\]} /\>

/\* @apply excessivo (perde benefícios utility-first) \*/

.button {

  @apply px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600;

}

// Componente React com cva é melhor

\<Button variant="primary"\>Click\</Button\>

// Arbitrary values repetidos

\<div className="mt-\[47px\]" /\>

\<div className="mt-\[47px\]" /\>

// Token customizado em @theme

// @theme { \--spacing-47: 47px; }

\<div className="mt-47" /\>

// Classes conflitantes

\<div className="p-2 p-4" /\>

// Remover focus sem substituir

\<button className="focus:outline-none" /\>

// Focus visible

\<button className="focus:outline-none focus-visible:ring-2" /\>

### React Anti-patterns

// useEffect para derivar estado

const \[fullName, setFullName\] \= useState('');

useEffect(() \=\> {

  setFullName(\`${firstName} ${lastName}\`);

}, \[firstName, lastName\]);

// Estado derivado

const fullName \= \`${firstName} ${lastName}\`;

// Keys instáveis

{items.map((item, index) \=\> \<Item key={index} /\>)}

// Keys estáveis

{items.map((item) \=\> \<Item key={item.id} /\>)}

// 'use client' desnecessário

'use client'

function StaticCard({ title }) {

  return \<div\>{title}\</div\>;

}

// Server Component quando possível (sem 'use client')

function StaticCard({ title }) {

  return \<div\>{title}\</div\>;

}

// useMemo/useCallback desnecessário com React Compiler ativo

const value \= useMemo(() \=\> x \* 2, \[x\]);

const handler \= useCallback(() \=\> console.log(x), \[x\]);

// Compiler faz isso automaticamente

const value \= x \* 2;

const handler \= () \=\> console.log(x);

### Acessibilidade Anti-patterns

// Botão sem texto acessível

\<button\>\<Icon /\>\</button\>

// sr-only para screen readers

\<button\>

  \<Icon /\>

  \<span className="sr-only"\>Fechar modal\</span\>

\</button\>

// Div clicável

\<div onClick={handleClick}\>Click me\</div\>

// Elemento semântico

\<button onClick={handleClick}\>Click me\</button\>

// Input sem label

\<input type="email" /\>

// Label associado

\<label htmlFor="email"\>Email\</label\>

\<input id="email" type="email" /\>

// Imagem sem alt

\<img src="photo.jpg" /\>

// Alt descritivo (ou vazio se decorativo)

\<img src="photo.jpg" alt="Equipe reunida no escritório" /\>

### Anti-patterns específicos de 2026

// 'use client' em arquivo todo quando só um componente precisa

'use client'

export function StaticHeader() { ... }

export function InteractiveSearch() { ... }

// Extrair só o que precisa de client

// header.tsx (Server)

export function StaticHeader() { ... }

// search.tsx (Client)

'use client'

export function InteractiveSearch() { ... }

// Tratar APCA como compliance WCAG 3.0

// (APCA não está no draft atual do WCAG 3\)

const colors \= { primary: oklch(...) }; // só validado em APCA

// Validar em WCAG 2.2 AA também

// APCA pode ser usado como referência adicional,

// mas compliance legal é WCAG 2.2 AA

// Confiar em .cursorrules legado (Cursor migrou)

{ ".cursorrules": "..." }

// Usar formato novo

// .cursor/rules/project.mdc \+ AGENTS.md

---

## 9\) INICIAR AGORA

Execute o processo completo:

1. **Descoberta** → Mapeie estrutura, stack, padrões  
2. **Planejamento** → Crie plano específico para o projeto  
3. **Auditoria** → Execute checklist por categoria  
4. **Recomendações** → Priorize e documente  
5. **Output** → Siga o formato de saída exatamente

**Lembre-se:**

- Toda afirmação precisa de evidência no código  
- Se não encontrar, diga "não encontrado"  
- Se houver incerteza, apresente opções  
- Nada de inventar ou assumir  
- Para compliance de acessibilidade, padrão é WCAG 2.2 AA, não APCA  
- Se React Compiler está ativo, ajustar recomendações de memoization

Comece agora explorando o repositório.  
