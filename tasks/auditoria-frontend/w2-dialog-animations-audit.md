# Auditoria de animações dos 5 dialogs (W2 #20)

Documento de preparação pra W3 (migração Radix). Faz inventário do que cada dialog anima hoje, onde a animação é definida, qual é o gap pra `prefers-reduced-motion`, e como portar para Radix sem perder visual.

## Resumo executivo

Cinco superfícies modais convivem hoje, divididas em dois padrões visuais:

- **Centro de tela com fade-up** (3 unidades): `ConflictModal`, `CheckinDialog`, `CheckoutDialog`. Backdrop com `mmd-reveal 200ms` + corpo com `mmd-reveal 240ms`. Reaproveitam a keyframe global definida em `globals.css`.
- **Side panel/drawer com slide-in da direita** (2 unidades): `ItemSidePanel`, `UnitDrawer`. Backdrop com `mmd-reveal 240ms` + corpo com `slide-in-right 280ms`. Cada arquivo redefine inline a keyframe `slide-in-right` via `<style>` injetado dentro do componente.

Todos usam o mesmo easing `cubic-bezier(0.2, 0.7, 0.2, 1)` (out-quart-ish), o que dá identidade visual coerente. Nenhum tem animação de saída (entry only com `both`, exit é instantâneo).

**Gap a11y crítico identificado**: o bloco `@media (prefers-reduced-motion: reduce)` em `globals.css:343` cobre apenas as classes `.reveal`, `.orbit-slow`, `.orbit-reverse`, `.pulse-soft`, `.skeleton`. As animações inline dos 5 dialogs **não são cobertas**, viola WCAG 2.3.3.

## Inventário por dialog

### 1. ConflictModal.tsx

Localização: `apps/web/src/components/projects/ConflictModal.tsx`

| Elemento | Animação | Linha |
|---|---|---|
| Backdrop (`<button>` overlay) | `mmd-reveal 200ms cubic-bezier(0.2, 0.7, 0.2, 1) both` | 96 |
| Corpo (`<div role="dialog">`) | `mmd-reveal 240ms cubic-bezier(0.2, 0.7, 0.2, 1) both` | 118 |
| Botão hover interno | `transition: background var(--motion-fast)` | 313 |

Backdrop opaco com blur(6px), `var(--dialog-overlay)`. Centralizado por `position: fixed; top:50%; left:50%; transform: translate(-50%,-50%)`. Sem exit animation, fechamento é abrupto.

### 2. CheckinDialog.tsx

Localização: `apps/web/src/components/projects/detail/CheckinDialog.tsx`

| Elemento | Animação | Linha |
|---|---|---|
| Backdrop | `mmd-reveal 200ms cubic-bezier(0.2, 0.7, 0.2, 1) both` | 106 |
| Corpo (dialog) | `mmd-reveal 240ms cubic-bezier(0.2, 0.7, 0.2, 1) both` | 128 |
| Radio botão de método | `transition: background var(--motion-fast), color var(--motion-fast)` | 224 |

Mesmo padrão visual do ConflictModal. Backdrop + corpo centralizado. Exit instantâneo.

### 3. CheckoutDialog.tsx

Localização: `apps/web/src/components/projects/detail/CheckoutDialog.tsx`

| Elemento | Animação | Linha |
|---|---|---|
| Backdrop | `mmd-reveal 200ms cubic-bezier(0.2, 0.7, 0.2, 1) both` | 59 |
| Corpo (dialog) | `mmd-reveal 240ms cubic-bezier(0.2, 0.7, 0.2, 1) both` | 81 |
| Radio botão de método | `transition: background var(--motion-fast), color var(--motion-fast)` | 174 |

Gêmeo visual do CheckinDialog. Exit instantâneo.

### 4. ItemSidePanel.tsx

Localização: `apps/web/src/components/catalog/ItemSidePanel.tsx`

| Elemento | Animação | Linha |
|---|---|---|
| Backdrop | `mmd-reveal 240ms cubic-bezier(0.2, 0.7, 0.2, 1) both` | 55 |
| Corpo (`<aside role="dialog">`) | `slide-in-right 280ms cubic-bezier(0.2, 0.7, 0.2, 1) both` | 72 |
| Keyframe `slide-in-right` (inline) | `from { transform: translateX(100%); opacity: 0 } to { transform: translateX(0); opacity: 1 }` | 309-313 |

Drawer pela direita, 480px de largura. Backdrop usa `var(--drawer-overlay)` com blur(4px). Keyframe definida via `<style>` no JSX, escopo global mas declarada inline. Exit instantâneo.

### 5. UnitDrawer.tsx

Localização: `apps/web/src/components/item-detail/UnitDrawer.tsx`

| Elemento | Animação | Linha |
|---|---|---|
| Backdrop | `mmd-reveal 240ms cubic-bezier(0.2, 0.7, 0.2, 1) both` | 50 |
| Corpo (`<aside role="dialog">`) | `slide-in-right 280ms cubic-bezier(0.2, 0.7, 0.2, 1) both` | 67 |
| Keyframe `slide-in-right` (inline) | idem ItemSidePanel | 263-266 |

Gêmeo do ItemSidePanel, 440px de largura. Mesma keyframe redeclarada (duplicada com ItemSidePanel). Exit instantâneo.

## Keyframes em jogo

### `mmd-reveal` (global, `globals.css:259`)

```css
@keyframes mmd-reveal {
  from { opacity: 0; transform: translateY(12px); }
  to   { opacity: 1; transform: translateY(0); }
}
```

Fade + lift de 12px. Usado em todos os 5 dialogs (backdrop, e em 3 deles também no corpo).

### `slide-in-right` (inline em 2 arquivos)

```css
@keyframes slide-in-right {
  from { transform: translateX(100%); opacity: 0; }
  to   { transform: translateX(0);    opacity: 1; }
}
```

Slide horizontal + fade. Duplicado em `ItemSidePanel.tsx` e `UnitDrawer.tsx`. **Candidato a promover pra `globals.css`** quando portar pra Radix, evita drift entre os dois arquivos.

## Gaps a11y

1. **prefers-reduced-motion incompleto.** O bloco `@media (prefers-reduced-motion: reduce)` em `globals.css:343-355` cobre apenas classes (`.reveal`, `.orbit-slow`, `.orbit-reverse`, `.pulse-soft`, `.skeleton`). As 10 animações inline dos 5 dialogs continuam tocando mesmo com `reduce`. Tarefa #25 do roadmap (`prefers-reduced-motion` cobre animações em W4) precisa estender o seletor para alcançar `[role="dialog"]`, `[aria-modal="true"]` e os overlays correspondentes.

2. **Sem exit animation.** Fechamento é instantâneo (montagem/desmontagem direta). Não é violação WCAG mas é regressão visual perceptível, especialmente nos drawers. Radix `Dialog` resolve isso via `data-state="open|closed"` + animações condicionais.

3. **Foco não trapado.** Já tracked em #5 (movido pra W3). Animação e focus trap são deliverables irmãos da migração Radix.

## Plano de port pra Radix (W3)

### Estratégia geral

Substituir o padrão atual (`<button overlay/> + <div role="dialog">`) por `Dialog.Root` + `Dialog.Portal` + `Dialog.Overlay` + `Dialog.Content` do `@radix-ui/react-dialog`. Animações migram de `style.animation` inline para CSS targeting `[data-state="open"]` e `[data-state="closed"]`.

### Por padrão visual

**Centro de tela (ConflictModal, CheckinDialog, CheckoutDialog):**

- `Dialog.Overlay` ganha animação de `fadeIn 200ms` (open) e `fadeOut 200ms` (close).
- `Dialog.Content` ganha animação de `mmd-reveal 240ms` (open) e `mmd-reveal-out 200ms` (close). Criar `mmd-reveal-out` em `globals.css` como espelho reverso.
- Posicionamento centralizado fica em CSS de `Dialog.Content`, não em inline style.

**Drawer pela direita (ItemSidePanel, UnitDrawer):**

- `Dialog.Overlay` ganha `fadeIn 240ms` / `fadeOut 200ms`.
- `Dialog.Content` ganha `slide-in-right 280ms` (open) e `slide-out-right 240ms` (close).
- Promover `slide-in-right` e `slide-out-right` pra `globals.css`. Remover as declarações duplicadas inline.

### Tokens novos a criar em `globals.css`

```css
@keyframes mmd-reveal-out {
  from { opacity: 1; transform: translateY(0); }
  to   { opacity: 0; transform: translateY(12px); }
}
@keyframes mmd-fade-in {
  from { opacity: 0; }
  to   { opacity: 1; }
}
@keyframes mmd-fade-out {
  from { opacity: 1; }
  to   { opacity: 0; }
}
@keyframes slide-in-right {
  from { transform: translateX(100%); opacity: 0; }
  to   { transform: translateX(0);    opacity: 1; }
}
@keyframes slide-out-right {
  from { transform: translateX(0);    opacity: 1; }
  to   { transform: translateX(100%); opacity: 0; }
}
```

### Tokens novos a criar (durações)

Considerar promover as durações pra CSS variables pra consistência:

```css
--motion-dialog-enter: 240ms;
--motion-dialog-exit:  200ms;
--motion-drawer-enter: 280ms;
--motion-drawer-exit:  240ms;
--motion-overlay:      200ms;
--motion-curve:        cubic-bezier(0.2, 0.7, 0.2, 1);
```

Evita drift entre arquivos e centraliza ajustes finos.

### Estender `prefers-reduced-motion`

Adicionar ao bloco existente em `globals.css:343`:

```css
@media (prefers-reduced-motion: reduce) {
  [data-radix-dialog-overlay],
  [data-radix-dialog-content] {
    animation: none !important;
  }
}
```

Ou, se preferir alvo agnóstico de bibliotech, atacar `[role="dialog"]` e seu sibling overlay.

## Risco de regressão

- **Visual:** baixo. As keyframes são preservadas (`mmd-reveal`, `slide-in-right`). Só muda o seletor (de inline pra CSS data-state).
- **Funcional:** médio. Radix muda a árvore de DOM (Portal), o que pode quebrar seletor CSS de ancestral em outro componente. Auditar antes.
- **Performance:** desprezível. Radix usa Portal já, sem custo extra de animação.

## Itens a referenciar quando começar W3

- Esse documento.
- `RELATORIO-FINAL.md` linhas 451 e 525 (item original do roadmap).
- `RELATORIO-FINAL.md` linhas 284 e 305 (problema a11y de animação).
- `globals.css:259` (keyframe `mmd-reveal`).
- `globals.css:343` (bloco `prefers-reduced-motion` a estender).
