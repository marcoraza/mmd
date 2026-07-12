# E4: Tokens e CSS

## Localizacao (`apps/web/src/app/globals.css`)

Entry point: `@import "tailwindcss"` (correto para v4)
Tailwind v4 confirmado por: `@tailwindcss/postcss` no postcss.config.mjs e `@theme {}` no CSS.

## Arquitetura de Tokens Atual

### Layer 1 - `@theme {}` (Global/Primitive em Tailwind v4)

```css
@theme {
  --font-sans: var(--font-inter-tight), ...;
  --font-mono: var(--font-jb-mono), ...;
  --color-mmd-cyan: oklch(0.72 0.14 210);
  --color-mmd-violet: oklch(0.62 0.17 295);
  --color-mmd-amber: oklch(0.72 0.15 75);
  --color-mmd-green: oklch(0.70 0.17 150);
  --color-mmd-red: oklch(0.62 0.18 25);
  --radius-sm: 4px; --radius-md: 8px; --radius-lg: 12px; --radius-xl: 18px;
}
```

### Layer 2 - `:root {}` (Semantico - Light)

```css
:root {
  /* Background */
  --bg-0, --bg-1, --bg-2 (oklch)
  /* Foreground */
  --fg-0, --fg-1, --fg-2, --fg-3 (oklch)
  /* Accent */
  --accent-cyan, --accent-cyan-soft, --accent-violet, --accent-violet-soft,
  --accent-amber, --accent-green, --accent-red (oklch)
  /* Glass */
  --glass-bg, --glass-bg-strong, --glass-border, --glass-border-strong,
  --glass-highlight, --glass-shadow, --glass-shadow-elevated (rgba, nao oklch)
  /* Radii redundantes */
  --r-sm, --r-md, --r-lg, --r-xl (duplicam @theme --radius-*)
  /* Motion */
  --motion-instant, --motion-fast, --motion-default, --motion-slow
  /* Font vars raw */
  --font-sans-raw, --font-mono-raw
}
```

### `:root.dark {}` (Semantico - Dark)

Dark mode via classe `.dark` na tag `<html>`, via JavaScript no `layout.tsx`.
Tokens semanticos redefinidos corretamente para dark.

### Layer 3 - Component Tokens

NAO EXISTE camada de component tokens (button-primary-bg, card-border, etc.).
Componentes usam diretamente `var(--accent-cyan)`, `var(--glass-bg)` via inline style.

## OKLCH Status

Verifiquei: extenso uso de OKLCH para:
- Todas as cores primitivas em `@theme`
- Todos os tokens semanticos de cor (bg-*, fg-*, accent-*)
- Gradientes em `globals.css` (orbs do caustic)
- Cores em `Primitives.tsx` (Ring component hardcoda oklch nos gradientes)

Nao usa OKLCH para:
- `--glass-bg`, `--glass-border`, `--glass-highlight`, `--glass-shadow` - usam `rgba()` hardcoded
- Varios componentes usam `rgba(0,0,0,0.45)` para overlay de modais (`ConflictModal.tsx:78`, `CheckinDialog.tsx:100`, `CheckoutDialog.tsx:53`, `ItemSidePanel.tsx:49`, `UnitDrawer.tsx:44`)
- `PreviewSheet.tsx` usa `#ffffff`, `#000`, `#999`, `#333`, `#666` (necessario: e um preview de impressao em papel)

## Dark Mode

Implementacao: classe `.dark` em `<html>`, aplicada via script inline no `<head>` que le `localStorage.getItem('mmd-theme')`.

Avaliacao:
- Flash prevention implementado corretamente com script inline
- `ThemeToggle.tsx` usa `useState(false)` para `mounted` e evita hidration mismatch
- Padrao correto, sem `next-themes` necessario

## Problemas de Token Architecture

### Problema 1: Duplicacao de radius tokens

Em `@theme`: `--radius-sm`, `--radius-md`, `--radius-lg`, `--radius-xl`
Em `:root`: `--r-sm`, `--r-md`, `--r-lg`, `--r-xl`

Ambos existem com os mesmos valores. Componentes usam `var(--r-lg)` (layer 2, nao o @theme). As classes Tailwind `rounded-sm`, `rounded-md` etc. seriam geradas do `@theme`, mas os componentes nao as usam.

### Problema 2: Glass tokens em rgba, nao oklch

`--glass-bg: rgba(255, 255, 255, 0.66)` poderia ser `oklch(1 0 0 / 0.66)`.
Consistencia visual menor, mas nao quebra nada.

### Problema 3: Ausencia de tokens de componente (Layer 3)

Os componentes acessam tokens semanticos diretamente (`var(--accent-cyan)`), sem intermediacao por token de componente. Isso torna refactor de design mais fragil: mudar `--accent-cyan` afeta tudo que o usa, sem granularidade.

### Problema 4: Font vars duplicados

`--font-sans` (no @theme) e `--font-sans-raw` (no :root) apontam para o mesmo valor. O CSS usa `var(--font-sans-raw)` no `body`, nao `var(--font-sans)` do @theme. Provavelmente porque o token @theme gera a classe `font-sans` mas nao pode ser usado diretamente como CSS var em inline styles sem o prefixo `--`.

## Alinhamento com Liquid Glass 2030

Design system `design_handoff_estoque_mmd/README.md` especifica:
- Tokens em oklch: Verifiquei parcialmente (glass tokens ainda em rgba)
- Inter Tight + JetBrains Mono: Verifiquei correto no layout
- Dark-first: DISCREPANCIA - CSS e light-first (`:root {}` e light, `:root.dark {}` e dark). O CLAUDE.md diz "dark-first" mas a implementacao e light-first. Ambos funcionam, mas ha divergencia de documentacao.
- Caustic orbs ciano/violeta: Verifiquei correto no globals.css

## Issues

| Issue | Severidade | Evidencia |
|---|---|---|
| Tokens de radius duplicados (@theme vs :root) | Media | globals.css linhas ~14-17 vs ~48-51 |
| Glass tokens em rgba, nao oklch | Baixa | globals.css linhas ~29-34 |
| Ausencia de Layer 3 (component tokens) | Media | Sem component-specific CSS vars |
| Font vars duplicados (--font-sans vs --font-sans-raw) | Baixa | globals.css |
| CLAUDE.md diz "dark-first" mas CSS e light-first | Baixa | globals.css, CLAUDE.md |
| Overlays de modal hardcoded em rgba | Baixa | ConflictModal.tsx:78, CheckinDialog.tsx:100 |
