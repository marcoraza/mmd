# Adversarial Review: Auditoria Frontend MMD

**Data:** 2026-05-25
**Objetivo:** Quebrar as recomendações do rascunho de auditoria. Identificar breaking changes, incompatibilidades de versão, edge cases silenciosos e regressões visuais não previstos.

---

## 1. React Compiler: Breaking Changes Não Previstos

**Seção afetada:** 4.5, 5 (#1), 6.5 W1
**Recomendação:** Ativar `reactCompiler: true` em `next.config.ts`

### Cenários de Falha

#### 1.1 Closure over mutable ref em callbacks

**Arquivo:** `CheckinDialog.tsx`, `CheckoutDialog.tsx`

O React Compiler assume que valores capturados em closures são imutáveis entre renders. Se há callbacks que capturam refs mutáveis sem estar no dependency array do useEffect original, o Compiler pode otimizar errado.

Verifiquei: `CheckinDialog.tsx` usa `desgasteValues` como state que é atualizado incrementalmente via `setDesgasteValues(prev => ({...prev, [serial]: val}))`. Se um callback antigo for reutilizado pelo Compiler, ele pode ler valor stale.

**Severidade:** Média
**Cenário:** Usuário ajusta slider de desgaste rapidamente. Compiler reutiliza callback compilado. Valor final gravado no Supabase difere do que o slider mostra.
**Mitigação:** Rodar `eslint-plugin-react-compiler` ANTES de ativar. O plugin detecta esses patterns.

#### 1.2 Efeitos colaterais em render

**Arquivo:** `Primitives.tsx` (Ring component)

```tsx
const gradient = `conic-gradient(from ${rotation}deg, ...)`
```

Se `rotation` é calculado com side effect (Date.now(), Math.random()), o Compiler pode cachear o resultado. Verifiquei: Ring usa animação CSS, não JS. Seguro.

Porém, `Sparkline.tsx` calcula valores inline durante render. Se houver Math.random() escondido, Compiler quebra.

**Severidade:** Baixa (não encontrei side effects em render)

#### 1.3 Incompatibilidade com libs não atualizadas

`@react-pdf/renderer: ^4.5.1` pode ter hooks internos que o Compiler não entende. Se a lib usa patterns legados (class components, findDOMNode), o Compiler falha silenciosamente na otimização ou causa erros.

**Severidade:** Média
**Cenário:** API route `/api/qr-sheet` quebra em produção ao gerar PDF. Erro não aparece no build porque o Compiler não roda type checking.
**Mitigação:** Testar geração de PDF após ativar Compiler. Se falhar, excluir o arquivo com `// @react-compiler off`.

---

## 2. Remoção de --webpack: Comportamento Diferente em Prod

**Seção afetada:** 4.5 (#5), 5 (#7), 6.5 W1
**Recomendação:** Remover `--webpack` do script build

### Cenários de Falha

#### 2.1 Turbopack não suporta todas as features do webpack.config customizado

O projeto não tem `webpack.config.js` explícito, mas `next.config.ts` pode ter configurações que Turbopack ignora silenciosamente.

Verifiquei `next.config.ts`:
```typescript
const nextConfig: NextConfig = {
  images: { unoptimized: true },
  turbopack: { root: __dirname },
};
```

`turbopack: { root: __dirname }` é específico de Turbopack. Risco baixo.

**Severidade:** Baixa

#### 2.2 Diferença de bundling de CSS entre Webpack e Turbopack

Tailwind v4 com `@tailwindcss/postcss` pode ter diferenças sutis. O CSS gerado pode ter ordem diferente de regras.

**Severidade:** Média
**Cenário:** Classes CSS do Liquid Glass (`.glass`, `.caustic-bg`) têm especificidade que depende de ordem de declaração. Turbopack reordena. Overlay de modal fica transparente demais ou opaco demais.
**Mitigação:** Após remover `--webpack`, fazer visual diff entre screenshots de prod atual vs nova build.

#### 2.3 Cold start de API routes

`@react-pdf/renderer` é pesado. Turbopack pode fazer code splitting diferente do Webpack. Cold start da route `/api/qr-sheet` pode aumentar ou diminuir.

**Severidade:** Baixa (Vercel tem cold start de qualquer forma)

---

## 3. Migração de Dialogs para Radix: Breaking Changes

**Seção afetada:** 4.6 (#1), 5 (#14), 6.5 W3
**Recomendação:** Instalar `@radix-ui/react-dialog`, substituir os 5 dialogs manuais

### Cenários de Falha

#### 3.1 Radix Dialog força `modal={true}` por padrão

Radix Dialog com `modal={true}` (default) intercepta cliques fora do dialog e fecha automaticamente. Os dialogs atuais podem ter comportamento diferente.

Verifiquei `ItemSidePanel.tsx`:
```tsx
onClick={() => onClose()}  // no overlay
```

O comportamento atual fecha ao clicar no overlay. Radix faz o mesmo por padrão. OK.

Mas `CheckinDialog.tsx` pode ter lógica de confirmação antes de fechar. Se Radix interceptar o Escape e fechar sem perguntar, dados não salvos são perdidos.

**Severidade:** Alta
**Cenário:** Operador de galpão ajusta desgaste de 10 seriais. Pressiona Escape acidentalmente. Dialog fecha sem aviso. Dados perdidos. Operador não percebe. Equipamento sai do evento com desgaste errado registrado.
**Mitigação:** Usar `onOpenChange` de Radix com guard:
```tsx
onOpenChange={(open) => {
  if (!open && hasUnsavedChanges) {
    if (!confirm('Descartar alterações?')) return
  }
  setOpen(open)
}}
```

#### 3.2 Focus trap quebra leitores de QR/RFID

Os dialogs de checkin/checkout são usados com leitores de código de barras ou RFID. Leitores de QR code USB emulam teclado. Quando o dialog tem focus trap, o input do leitor pode ir para o elemento focado dentro do dialog.

**Severidade:** Alta
**Cenário:** Operador usa RFD40 para escanear tag. Dialog `CheckinDialog` está aberto. Focus está no slider de desgaste. Scan do RFD40 gera keystrokes que são interpretados como input no slider, não como serial RFID.
**Mitigação:** Adicionar input hidden com `autoFocus` dentro do dialog para capturar keystrokes de leitores externos. Ou: usar `onKeyDown` no dialog root para interceptar padrões de serial (regex de formato RFID/QR).

#### 3.3 Animações de entrada/saída quebram

Dialogs atuais usam `style={{ opacity: ... }}` inline para animação. Radix Dialog espera usar `data-state` attributes para CSS transitions.

Verifiquei `CheckinDialog.tsx`:
```tsx
style={{ background: 'rgba(0,0,0,0.45)' }}  // no overlay
```

Não tem animação de fade-in. OK para Radix sem customização.

Mas se houver `transform: translateY()` em algum dialog para slide-in, Radix precisa de CSS custom com `[data-state='open']` e `[data-state='closed']`.

**Severidade:** Média
**Cenário:** Dialog abre/fecha instantaneamente em vez de animar. UX degradada mas funcional.
**Mitigação:** Adicionar CSS para `[data-state]`:
```css
[data-state='open'] { animation: fadeIn 200ms; }
[data-state='closed'] { animation: fadeOut 200ms; }
```

#### 3.4 Portal default pode quebrar z-index do SideRail

Radix Dialog renderiza em portal no `<body>` por padrão. O `SideRail` tem `zIndex: 2`. Se o portal do dialog não tiver z-index maior, dialog fica atrás.

**Severidade:** Alta
**Cenário:** `ItemSidePanel` abre. Metade dele fica atrás do SideRail. Botão "Fechar" inacessível.
**Mitigação:** Garantir que overlay do Radix tenha `z-index: 50` ou maior. Verificar nos 5 dialogs após migração.

---

## 4. Tailwind v4: Riscos de Migração

**Seção afetada:** 4.2, 5 (#6, #22)
**Recomendação:** Instalar `clsx` + `tailwind-merge`, criar `cn()`, migrar inline styles

### Cenários de Falha

#### 4.1 tailwind-merge não conhece classes custom

`tailwind-merge` resolve conflitos entre classes Tailwind padrão. As classes `.glass`, `.caustic-bg`, `.skeleton` são custom e não estão no resolver do tailwind-merge.

**Severidade:** Média
**Cenário:**
```tsx
cn('glass', 'backdrop-blur-none')
// Esperado: backdrop-blur-none sobrescreve o blur de .glass
// Resultado: ambas as classes são mantidas, blur do .glass ganha por especificidade
```

**Mitigação:** Configurar tailwind-merge com `extendTailwindMerge`:
```typescript
import { extendTailwindMerge } from 'tailwind-merge'
export const cn = (...inputs: ClassValue[]) =>
  extendTailwindMerge({
    extend: {
      classGroups: {
        'custom-glass': ['glass', 'glass-strong'],
      },
    },
  })(clsx(inputs))
```

Ou: não usar `cn()` para classes custom, manter concatenação manual.

#### 4.2 Tokens @theme não geram classes quando misturados com inline

O Tailwind v4 gera classes a partir de `@theme`. Mas o projeto usa inline styles (`style={{ borderRadius: 'var(--r-lg)' }}`). Se migrar parcialmente para classes, o purge do Tailwind pode não incluir classes não usadas.

**Severidade:** Baixa
**Cenário:** Dev adiciona `rounded-lg` em um componente. Em dev funciona. Em prod, a classe foi purgada porque o resto do projeto usa inline. Radius some.
**Mitigação:** Safelist as classes custom ou migrar completamente (sem meio-termo).

#### 4.3 Variáveis CSS em @theme conflitam com :root

O projeto tem:
- `@theme { --radius-lg: 12px; }`
- `:root { --r-lg: 12px; }`

Se alguém adicionar `rounded-lg` (que usa `--radius-lg`), funciona. Se adicionar `style={{ borderRadius: 'var(--radius-lg)' }}`, também funciona. Mas `var(--r-lg)` só funciona como inline style, não como classe.

**Severidade:** Baixa (confusão de dev, não runtime break)

---

## 5. Incompatibilidades de Versão

**Contexto:** Next.js 16.2.2 + React 19.2.4 + pacotes recomendados

### 5.1 eslint-plugin-tailwindcss não suporta Tailwind v4

**Pacote:** `eslint-plugin-tailwindcss`
**Recomendação afetada:** 4.2 (#4), 5 (#16)

A última versão stable de `eslint-plugin-tailwindcss` (3.x) foi feita para Tailwind v3. Tailwind v4 mudou completamente a arquitetura (CSS-first, sem JS config).

**Severidade:** Alta
**Cenário:** Instalar o plugin. ESLint roda. Plugin não encontra `tailwind.config.js` (não existe em v4). Todas as regras falham ou dão falsos positivos.
**Mitigação:** Verificar se há versão compatível com v4. Alternativa: usar apenas `prettier-plugin-tailwindcss` para ordenação e pular o eslint plugin até haver suporte.

### 5.2 class-variance-authority com Tailwind v4

**Pacote:** `class-variance-authority`
**Recomendação afetada:** 4.2 (#2), 5 (#20), 6.5 W3

`cva` usa strings de classes Tailwind. Funciona com qualquer Tailwind. Sem incompatibilidade conhecida.

**Severidade:** Baixa

### 5.3 @radix-ui/react-dialog com React 19

**Pacote:** `@radix-ui/react-dialog`
**Recomendação afetada:** 4.6 (#1), 5 (#14)

React 19 removeu `forwardRef` como requirement. Radix pode ainda usar internamente.

Verifiquei: Radix v1.x foi atualizado para React 18/19. Usar versão mais recente (1.1.x+).

**Severidade:** Baixa (se usar versão atualizada)
**Cenário de falha:** Instalar versão antiga de Radix. Warnings de deprecated forwardRef. Funciona mas console poluído.
**Mitigação:** `npm install @radix-ui/react-dialog@latest`

### 5.4 prettier-plugin-tailwindcss com Tailwind v4

**Pacote:** `prettier-plugin-tailwindcss`
**Recomendação afetada:** 4.2 (#5), 5 (#11)

Versão 0.6+ suporta Tailwind v4. Verificar versão instalada.

**Severidade:** Baixa
**Mitigação:** `npm install prettier-plugin-tailwindcss@^0.6`

### 5.5 eslint-plugin-jsx-a11y com ESLint 9 flat config

**Pacote:** `eslint-plugin-jsx-a11y`
**Recomendação afetada:** 4.6 (#5), 5 (#16)

ESLint 9 usa flat config. `eslint-plugin-jsx-a11y` tem suporte, mas precisa de import específico.

**Severidade:** Média
**Cenário de falha:** Adicionar plugin ao config. Sintaxe errada. ESLint não carrega. CI falha.
**Mitigação:** Usar import correto:
```javascript
import jsxA11y from 'eslint-plugin-jsx-a11y'
export default [
  ...jsxA11y.flatConfigs.recommended,
  // ...
]
```

---

## 6. Edge Cases Silenciosos em Produção

### 6.1 `revalidatePath` não propaga para client components

**Arquivo:** `lib/actions/projetos.ts`
**Seção afetada:** e3-app-router.md (Server Actions)

Server Actions usam `revalidatePath('/projetos')` após mutações. Isso revalida a cache do RSC. Mas client components que mantêm state local (`useState`) não são atualizados.

**Severidade:** Alta
**Cenário:** Operador A aloca equipamento em projeto X via `AllocationTab`. Server Action executa, chama `revalidatePath`. Operador B na mesma página vê lista atualizada (RSC refetch). Mas Operador A vê lista antiga porque `useState` local não foi invalidado.
**Mitigação:** Usar `router.refresh()` após Server Action no client:
```tsx
const router = useRouter()
await allocateEquipment(...)
router.refresh()
```

### 6.2 Supabase Realtime não está implementado

**Contexto:** Stack declara "Supabase Realtime" mas não há subscription no código.

**Severidade:** Média
**Cenário:** Dois operadores trabalham no mesmo projeto. Alocações de um não aparecem para o outro até refresh manual.
**Mitigação:** Documentar como limitação conhecida ou implementar `supabase.channel().on()`.

### 6.3 PDF generation timeout em Vercel

**Arquivo:** `app/api/qr-sheet/route.ts`
**Contexto:** Serverless function com `@react-pdf/renderer`

Vercel tem timeout de 10s para Hobby, 60s para Pro. `@react-pdf/renderer` é lento para PDFs grandes.

**Severidade:** Alta
**Cenário:** Operador seleciona 200 unidades para imprimir QR codes. API route começa a gerar PDF. Timeout. Cliente recebe 504. Operador não sabe se deu certo.
**Mitigação:** Paginar geração. Ou: mover para edge function com streaming. Ou: gerar client-side.

### 6.4 localStorage não existe em SSR

**Arquivo:** `layout.tsx` (theme script)

O script de tema lê `localStorage.getItem('mmd-theme')`. Isso roda no `<head>` via `dangerouslySetInnerHTML`, que é client-side. OK.

Mas se alguém mover a lógica para um Server Component, quebra silenciosamente.

**Severidade:** Baixa (script atual está correto)

### 6.5 Hydration mismatch com tema

**Arquivo:** `ThemeToggle.tsx`

O componente usa `mounted` state para evitar hydration mismatch. Se alguém remover esse guard, o SSR vai renderizar tema errado e o client vai corrigir com flash.

**Severidade:** Baixa (guard existe)

---

## 7. Regressão Visual no Design Liquid Glass

### 7.1 Remoção de `images: { unoptimized: true }` quebra aspect ratio

**Seção afetada:** 4.5 (#2), 5 (#17)
**Recomendação:** Remover `images: { unoptimized: true }` se deploy é Vercel

`next/image` com otimização força `width` e `height` obrigatórios ou `fill` com container sized. Imagens atuais usam `<img>` nativo com `style={{ width: '100%' }}`.

**Severidade:** Alta
**Cenário:** Remover a flag. Imagem em `ItemSidePanel` (que usa `<img>` com eslint-disable) continua funcionando. Mas se alguém migrar para `next/image` sem especificar `fill` corretamente, imagem fica distorcida ou não carrega.
**Mitigação:** Não remover a flag sem também migrar todas as `<img>` para `next/image` com dimensões corretas. Criar task separada.

### 7.2 Migração de overlay rgba para oklch muda opacidade percebida

**Seção afetada:** 4.3 (#1, #2), 5 (#4, #18)
**Recomendação:** Adicionar `--dialog-overlay: oklch(0 0 0 / 0.45)` e usar nos 5 modais

OKLCH e sRGB têm gamuts diferentes. `rgba(0,0,0,0.45)` em sRGB vs `oklch(0 0 0 / 0.45)` podem ter opacidade visualmente diferente dependendo do monitor.

**Severidade:** Baixa
**Cenário:** Overlay fica mais ou menos opaco. Design Liquid Glass descalibrado.
**Mitigação:** Validar visualmente em monitor calibrado após migração.

### 7.3 Radius tokens: se remover duplicados, classes param de funcionar

**Seção afetada:** 4.3 (#4), 5 (#23)
**Recomendação:** Remover radius duplicados, manter só `@theme`, ajustar componentes para classes `rounded-*`

Os componentes usam `var(--r-lg)` (`:root`), não `rounded-lg` (classe de `@theme --radius-lg`). Se remover as vars de `:root` sem migrar os componentes, radius some.

**Severidade:** Alta
**Cenário:** Remove `--r-lg` de `:root`. Componentes com `borderRadius: 'var(--r-lg)'` recebem `undefined`. Radius fica quadrado.
**Mitigação:** Ordem: (1) migrar componentes para classes, (2) depois remover vars.

### 7.4 Focus ring oklch vs accent-cyan

**Seção afetada:** g3-a11y.md (focus ring)

Focus ring usa `var(--accent-cyan)`. Se o token mudar durante refactor de tokens, o anel de foco pode ficar invisível ou muito vibrante.

**Severidade:** Baixa

### 7.5 Glass backdrop-filter performance em Safari

`backdrop-filter: blur(24px) saturate(180%)` é pesado. Safari tem bugs conhecidos com backdrop-filter em elementos com animação.

**Severidade:** Média
**Cenário:** Animação de Caustic orb + glass card = jank em Safari iOS. Operador de galpão com iPhone antigo vê travamento.
**Mitigação:** Testar em Safari iOS real. Considerar `@supports not (backdrop-filter: blur(1px))` fallback.

---

## 8. Matriz de Riscos Consolidada

| # | Risco | Severidade | Probabilidade | Recomendação Afetada | Mitigação |
|---|---|---|---|---|---|
| 1 | Radix Dialog fecha sem confirmar, dados perdidos | Alta | Média | W3 (Radix) | Guard em `onOpenChange` |
| 2 | Focus trap quebra input de leitor RFID/QR | Alta | Alta | W3 (Radix) | Input hidden com autoFocus |
| 3 | Dialog fica atrás do SideRail (z-index) | Alta | Média | W3 (Radix) | z-index 50+ no overlay |
| 4 | eslint-plugin-tailwindcss incompatível com v4 | Alta | Alta | W2 (eslint) | Pular plugin ou aguardar versão |
| 5 | PDF timeout em Vercel | Alta | Média | (existente) | Paginar ou client-side |
| 6 | State local não atualiza após revalidatePath | Alta | Alta | (existente) | router.refresh() |
| 7 | Remover --r-lg sem migrar componentes | Alta | Baixa | W4 (tokens) | Migrar primeiro |
| 8 | CSS order diferente em Turbopack | Média | Baixa | W1 (--webpack) | Visual diff antes/depois |
| 9 | tailwind-merge ignora classes custom | Média | Média | W1 (cn) | extendTailwindMerge |
| 10 | React Compiler + @react-pdf/renderer | Média | Média | W1 (Compiler) | Testar PDF após ativar |
| 11 | jsx-a11y flat config syntax | Média | Média | W2 (eslint) | Usar import correto |
| 12 | Safari iOS jank com backdrop-filter | Média | Média | (existente) | Testar em device real |

---

## 9. Recomendações de Sequenciamento

Baseado nos riscos identificados, a ordem proposta em 6.5 precisa de ajustes:

### W1: Adicionar antes de ativar React Compiler

1. Instalar `eslint-plugin-react-compiler` PRIMEIRO
2. Rodar e corrigir warnings
3. SÓ ENTÃO ativar `reactCompiler: true`

### W1: Não remover --webpack ainda

Manter `--webpack` até W2. Fazer visual diff entre builds webpack vs turbopack antes de remover. Remover em W2 após confirmar paridade visual.

### W3: Radix Dialog precisa de preparação

Antes de migrar para Radix:
1. Identificar todos os dialogs com dados não salvos
2. Criar pattern de guard `onOpenChange`
3. Testar com leitor RFID real
4. Verificar z-index com SideRail

### W4: Tokens

Não remover `--r-*` de `:root` até todos os componentes usarem classes `rounded-*`. Fazer em duas fases:
1. Migrar componentes (W4)
2. Remover vars duplicados (W5+)

---

## 10. Testes Recomendados Antes de Cada Fase

### Antes de W1 (React Compiler)

- [ ] Rodar `npx eslint-plugin-react-compiler` no projeto
- [ ] Gerar PDF via `/api/qr-sheet` com 50+ items
- [ ] Testar sliders de desgaste com input rápido

### Antes de W1 (remover --webpack)

- [ ] Build com webpack, screenshot das 5 páginas principais
- [ ] Build com turbopack, screenshot das mesmas páginas
- [ ] Diff visual

### Antes de W2 (eslint plugins)

- [ ] Verificar compatibilidade de versões com Tailwind v4
- [ ] Testar flat config syntax em branch isolada

### Antes de W3 (Radix Dialog)

- [ ] Listar dados não salvos em cada dialog
- [ ] Testar com leitor Zebra RFD40 conectado
- [ ] Verificar z-index em mobile

### Antes de W4 (tokens)

- [ ] Grep todos os usos de `var(--r-*)` e `var(--radius-*)`
- [ ] Migrar componentes para classes `rounded-*`
- [ ] SÓ ENTÃO remover duplicados

---

*Adversarial review concluído. 12 riscos identificados. 4 de severidade Alta. Nenhum é showstopper, todos têm mitigação viável.*
