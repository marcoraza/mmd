# Code Review: Validacao de Evidencias do Rascunho

**Data:** 2026-05-25
**Revisor:** Claude Opus 4.5
**Escopo:** Verificacao de file:line citados no RASCUNHO-RELATORIO.md contra codigo real em apps/web/src/

---

## 1. Arquivos Inventados (Nao Existem)

| Arquivo Citado | Linhas Referenciadas | Secao do Rascunho | Classificacao |
|---|---|---|---|
| `ConflictModal.tsx` | 56, 78 | 4.3 Tokens (overlay), 4.6 A11y (focus trap) | CRITICO |
| `UnitDrawer.tsx` | 44 | 4.3 Tokens (overlay) | CRITICO |
| `LotesBanner.tsx` | 66 | 4.5 Performance (keys instaveis) | CRITICO |
| `RfidBanner.tsx` | 70 | 4.5 Performance (keys instaveis) | CRITICO |

**Impacto:** 4 findings de severidade media/alta baseados em arquivos que nao existem. Remover do relatorio final ou localizar os arquivos corretos antes de publicar.

---

## 2. Caminhos de Arquivo Errados

### ItemSidePanel.tsx

**Rascunho implica:** `/components/item-detail/ItemSidePanel.tsx` (via estrutura de pastas secao 2)
**Local real:** `/components/catalog/ItemSidePanel.tsx`

A estrutura de pastas na secao 2 lista `item-detail/` como diretorio, mas ItemSidePanel.tsx esta em `catalog/`. A referencia a linha 28 (focus trap) e ~120 (img nativo) existe, mas o caminho esta errado.

**Classificacao:** MEDIO

---

## 3. Linhas Erradas

### globals.css - Glass tokens em rgba()

**Rascunho cita:** `globals.css:29-36`
**Local real:** Linhas 47-53

```css
/* Linhas reais 47-53 */
--glass-bg: rgba(255, 255, 255, 0.66);
--glass-bg-strong: rgba(255, 255, 255, 0.82);
--glass-border: rgba(0, 0, 0, 0.14);
--glass-border-strong: rgba(0, 0, 0, 0.20);
--glass-highlight: rgba(255, 255, 255, 0.9);
--glass-shadow: 0 2px 6px rgba(0, 0, 0, 0.06), 0 20px 60px rgba(0, 0, 0, 0.12);
--glass-shadow-elevated: 0 8px 24px rgba(0, 0, 0, 0.12), 0 40px 100px rgba(0, 0, 0, 0.20);
```

**Classificacao:** BAIXO (finding correto, linha errada)

---

### ItemSidePanel.tsx - img nativo

**Rascunho cita:** `ItemSidePanel.tsx:~120`
**Local real:** Linhas 142-147

```tsx
/* Linhas reais 141-147 */
{item.foto_url ? (
  /* eslint-disable-next-line @next/next/no-img-element */
  <img
    src={item.foto_url}
    alt={item.nome}
    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
  />
```

**Classificacao:** BAIXO (finding correto, linha errada por ~22 linhas)

---

## 4. Findings com Evidencia Errada

### UnitsTable.tsx:211 - role="button" sem tabIndex

**Rascunho afirma:** "role='button' em div sem tabIndex confirmado"
**Codigo real (linhas 210-219):**

```tsx
<div
  role="button"
  tabIndex={0}
  onClick={() => onSelectItem(u.item_id)}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault()
      onSelectItem(u.item_id)
    }
  }}
```

**Realidade:** `tabIndex={0}` EXISTE na linha 212. O handler `onKeyDown` tambem EXISTE (linhas 214-219). O componente esta acessivel via teclado.

**Classificacao:** CRITICO (finding completamente errado, deve ser removido)

---

### TopBar.tsx - div em vez de header

**Rascunho afirma:** "TopBar e `<div>`, nao `<header>`" (secao 4.6 A11y, issue #8)
**Codigo real (linha 17):**

```tsx
<header
  className="reveal reveal-0"
  style={{
```

**Realidade:** TopBar USA `<header>`, nao `<div>`. O landmark esta presente.

**Classificacao:** CRITICO (finding completamente errado, deve ser removido)

---

## 5. Overlay Values Inconsistentes

O rascunho cita "overlays de modal hardcoded em rgba(0,0,0,0.45) em 5 componentes". Verificando:

| Componente | Linha | Valor Real |
|---|---|---|
| CheckinDialog.tsx | 100 | `rgba(0, 0, 0, 0.45)` |
| CheckoutDialog.tsx | 53 | `rgba(0, 0, 0, 0.45)` |
| ItemSidePanel.tsx | 49 | `rgba(0, 0, 0, 0.35)` |
| ConflictModal.tsx | - | NAO EXISTE |
| UnitDrawer.tsx | - | NAO EXISTE |

**Observacao:** ItemSidePanel usa 0.35, nao 0.45. Apenas 2 dos 5 componentes citados existem com o valor citado.

**Classificacao:** MEDIO (finding parcialmente correto)

---

## 6. Evidencias Corretas (Validadas)

| Referencia | Status | Observacao |
|---|---|---|
| package.json: Next.js 16.2.2 | CORRETO | Linha 15 |
| package.json: React 19.2.4 | CORRETO | Linha 17 |
| package.json: Tailwind ^4 | CORRETO | Linha 28 |
| package.json: ESLint ^9 | CORRETO | Linha 26 |
| package.json: shadcn/ui ausente | CORRETO | Nao esta em dependencies |
| CatalogClient.tsx:41-44 (useEffect sync) | CORRETO | useEffect seta items de data.items |
| CheckinDialog.tsx:50 (useEffect Escape) | CORRETO | Listener de Escape |
| CheckoutDialog.tsx:26 (useEffect Escape) | CORRETO | Listener de Escape |
| SideRail.tsx:1 ('use client') | CORRETO | Primeira linha |
| SideRail.tsx:105 (color: '#fff') | CORRETO | Hardcoded white |
| next.config.ts:4 (images: unoptimized) | CORRETO | `images: { unoptimized: true }` |
| CI sem tsc/lint | CORRETO | pages.yml so faz `npx next build` |
| layout.tsx: Instrument_Serif importada | CORRETO | Linha 2 |
| Suspense fallbacks sem skeleton | CORRETO | Texto simples, nao skeleton |

---

## 7. Marcacoes Verifiquei/Inferencia Inconsistentes

A secao 2 (Mapa do Projeto) marca "**Stack Real (Verifiquei)**" mas:

1. Cita 5 componentes de dialog (ConflictModal, CheckinDialog, CheckoutDialog, ItemSidePanel, UnitDrawer) onde 2 nao existem
2. Cita LotesBanner e RfidBanner que nao existem
3. Afirma que TopBar e div quando e header
4. Afirma que UnitsTable nao tem tabIndex quando tem

**Inconsistencia:** A marcacao "Verifiquei" nao reflete verificacao real de todos os arquivos citados.

**Classificacao:** CRITICO (afeta confiabilidade do relatorio)

---

## Resumo de Acoes Necessarias

### Remover do Relatorio Final

1. Todas as referencias a `ConflictModal.tsx` (arquivo nao existe)
2. Todas as referencias a `UnitDrawer.tsx` (arquivo nao existe)
3. Todas as referencias a `LotesBanner.tsx:66` (arquivo nao existe)
4. Todas as referencias a `RfidBanner.tsx:70` (arquivo nao existe)
5. Issue 4.6 #4 sobre `UnitsTable.tsx:211` (tabIndex existe)
6. Issue 4.6 #8 sobre TopBar ser div (e header)

### Corrigir no Relatorio Final

1. globals.css linhas 29-36 -> 47-53
2. ItemSidePanel.tsx linha ~120 -> 142-147
3. Caminho de ItemSidePanel.tsx: item-detail/ -> catalog/
4. Contagem de dialogs com overlay hardcoded: 5 -> 3 (CheckinDialog, CheckoutDialog, ItemSidePanel)
5. Valor de overlay de ItemSidePanel: 0.45 -> 0.35

### Investigar Antes de Publicar

1. Os arquivos ConflictModal, UnitDrawer, LotesBanner, RfidBanner existem com outros nomes ou em outros locais?
2. Ha outros componentes com keys instaveis alem dos 2 citados que nao existem?

---

## Contagem Final

| Classificacao | Qtd | Itens |
|---|---|---|
| CRITICO | 8 | 4 arquivos inventados, 2 findings errados (UnitsTable, TopBar), marcacao Verifiquei inconsistente |
| MEDIO | 2 | Caminho ItemSidePanel, overlay values inconsistentes |
| BAIXO | 2 | Linhas erradas (globals.css, ItemSidePanel img) |

**Recomendacao:** Nao publicar o rascunho sem corrigir os 8 itens criticos. O relatorio tem valor, mas precisa de segunda passada para remover evidencias inventadas.
