# G1: Tailwind CSS - Estado da Arte

## Versao Detectada

Verifiquei: Tailwind v4 (`"tailwindcss": "^4"` em `package.json`, `@tailwindcss/postcss` no postcss, `@import "tailwindcss"` e `@theme {}` no globals.css)

## Configuracao v4

Correto:
- `@import "tailwindcss"` como entry point
- `@theme {}` para configuracao de tokens
- `@tailwindcss/postcss` como PostCSS plugin
- Sem `tailwind.config.js` (correto para v4 pure CSS-first)

## Anti-Patterns Detectados

### 1. Uso Minimo de Classes Tailwind (Alta Severidade)

Verifiquei: o projeto usa predominantemente inline styles (`style={{...}}`) em vez de classes Tailwind.

Contagem:
- `className=`: 246 ocorrencias
- `style={{`: 906 ocorrencias

Ratio aproximado de 1:3.7. O projeto nasceu "CSS vars + inline styles" em vez de "utility classes". As classes Tailwind aparecem apenas para:
- Utility classes do design system custom: `.glass`, `.caustic-bg`, `.reveal`, `.skeleton`, `.mono`
- Algumas classes responsivas em `CinematicHero.tsx`

Impacto: perde-se o beneficio do Tailwind (purge CSS, IntelliSense, constraint enforcement). O resultado e um CSS nao purgado efetivamente porque as utilities relevantes nao sao geradas.

### 2. Ausencia de `cn`/`clsx`/`tailwind-merge` (Alta Severidade)

Verifiquei: nenhuma ocorrencia de `cn(`, `clsx(`, `twMerge(` ou `tailwind-merge` no src/.

Isso significa:
- Sem protecao contra conflitos de classe quando se combina strings
- Sem padrao de variantes condicionais
- Cada componente faz concatenacao manual: `` `glass${strong ? ' glass-strong' : ''}` `` (`Primitives.tsx` linha ~23)

### 3. Classes Dinamicas Potencialmente Quebradas (Media Severidade)

Inferencia: Nao encontrei interpolacao de classe do tipo `` `text-${color}-500` `` que quebraria o Tailwind. Os poucos pontos de classe dinamica usam concatenacao de string completa (ex: `Primitives.tsx`). Risco baixo atual, mas ausencia de `cn` torna isso fragil.

### 4. Ausencia de `cva` para Variants (Alta Severidade)

Verifiquei: sem `class-variance-authority` nem `tailwind-variants` no projeto.

Primitives.tsx define `PrimaryBtn` e `GhostBtn` como componentes separados em vez de um `Button` com variants. Isso e duplicacao: ambos compartilham estrutura quase identica.

Impacto: dificuldade de manter consistencia de hover/focus/disabled entre variantes.

### 5. `@apply` - Status

Verifiquei: nao ha uso de `@apply` no projeto. As classes CSS custom sao definidas diretamente (`.glass { ... }`). Isso e correto - o anti-pattern de `@apply` excessivo nao esta presente.

### 6. Container Queries

Verifiquei: nao ha uso de `@container` ou container query modifiers (`@sm:`, `@lg:`) em nenhum componente. Tailwind v4 tem isso built-in mas o projeto nao aproveita.

### 7. Logical Properties

Verifiquei: nao ha uso de `ps-`, `pe-`, `ms-`, `me-` (logical properties v4). O projeto usa `style={{ paddingLeft: X }}` inline.

### 8. Sintaxe Slash de Opacidade

Verifiquei: `--accent-cyan-soft: oklch(0.72 0.14 210 / 0.22)` no globals.css usa sintaxe moderna CSS. Mas `background-opacity-*` nao aparece no codigo (v3 pattern ausente). Parcialmente correto.

### 9. Renames v3 → v4 Nao Aplicaveis

Verifiquei: como o projeto usa inline styles e nao classes Tailwind para maioria dos casos, os renames criticos de v4 (`shadow` → `shadow-sm`, `blur` → `blur-sm`, `rounded` → `rounded-sm`, `outline-none` → `outline-hidden`) nao sao aplicaveis. Poucas classes Tailwind existem para verificar.

Excecao encontrada: `globals.css` usa `.skeleton`, `.reveal` etc. mas sao classes CSS custom, nao classes Tailwind.

### 10. `tailwindStylesheet` no Prettier

Verifiquei: `.prettierrc` ausente. Sem `prettier-plugin-tailwindcss`, as classes existentes nao sao ordenadas automaticamente.

### 11. `eslint-plugin-tailwindcss` Ausente

Verifiquei: nao ha `eslint-plugin-tailwindcss` no `eslint.config.mjs`. Sem:
- `no-contradicting-classname`
- `enforces-shorthand`
- `no-unnecessary-arbitrary-value`

### 12. Arbitrary Values

Verifiquei: poucos arbitrary values detectados no codigo. O projeto usa inline styles em vez de `mt-[47px]`, entao este anti-pattern nao se aplica diretamente. O problema e estrutural (inline vs utility), nao de arbitrary values.

## Responsividade

Inferencia: o layout usa `clamp()` e `flexWrap: 'wrap'` para responsividade via inline styles. Container queries e breakpoints Tailwind nao sao usados.

## Estados Interativos

Verifiquei: `.card-interactive` em globals.css define hover via CSS puro (nao classes Tailwind). `focus-visible` e definido globalmente em globals.css:

```css
:focus-visible {
  outline: 2px solid var(--accent-cyan);
  outline-offset: 2px;
  border-radius: var(--r-sm);
}
```

Isso funciona globalmente mas nao e exposto como classe Tailwind `focus-visible:ring-2`.

## Resumo de Issues

| # | Issue | Severidade | Evidencia |
|---|---|---|---|
| 1 | Inline styles dominam (906x) vs Tailwind (246x) | Alta | Contagem no src/ |
| 2 | Sem cn/clsx/tailwind-merge | Alta | grep sem resultado |
| 3 | Sem cva/tailwind-variants para variants | Alta | package.json, Primitives.tsx |
| 4 | Sem eslint-plugin-tailwindcss | Media | eslint.config.mjs |
| 5 | Sem prettier-plugin-tailwindcss | Media | .prettierrc ausente |
| 6 | Container queries nao aproveitadas | Baixa | grep sem resultado |
| 7 | Logical properties nao usadas | Baixa | grep sem resultado |
