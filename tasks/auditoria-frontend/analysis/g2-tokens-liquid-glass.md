# G2: Tokens e Design System - Liquid Glass 2030

## Estado Atual

Verifiquei: o projeto tem um sistema de tokens parcialmente implementado, funcional para o MVP, com gaps estruturais em relacao ao benchmark DTCG 2026.

## Hierarquia 3 Camadas - Avaliacao

### Layer 1 - Global/Primitive

`@theme {}` em `globals.css` define:
- 5 cores acento (oklch): correto
- 2 fontes: correto
- 4 radii: correto

Problema: camada muito esparsa. Nao ha escala de spacing, nao ha escala tipografica, nao ha paleta de grays numerada (blue-100, blue-200...).

### Layer 2 - Semantic

`:root {}` define ~30 tokens semanticos com nomes significativos:
- bg-0, bg-1, bg-2: backgrounds (correto)
- fg-0, fg-1, fg-2, fg-3: foregrounds (correto)
- accent-cyan, accent-violet etc.: acentos (correto)
- glass-bg, glass-border etc.: tokens de superficie (correto conceitualmente)

Muda corretamente entre light (`:root`) e dark (`:root.dark`): correto.

### Layer 3 - Component

NAO EXISTE. Nenhum token especifico de componente como:
- `--btn-primary-bg`
- `--dialog-overlay`
- `--input-border`
- `--card-bg`

Componentes acessam Layer 2 diretamente. Isso funciona para MVP, mas torna refactor de design mais trabalhoso.

## DTCG JSON

NAO EXISTE. O `design_handoff_estoque_mmd/tokens/mmd-tokens.json` e referenciado no comentario do globals.css, mas o pipeline Style Dictionary nao esta configurado. Tokens vivem apenas no CSS, nao em formato DTCG.

Impacto: sem sincronizacao com Figma, sem geracao automatica de tokens, sem versioning de tokens.

## OKLCH - Avaliacao

Pontos corretos:
- Todas as cores semanticas (bg-*, fg-*, accent-*) usam oklch
- Interpolacao OKLCH nos gradientes dos orbs
- Ring component em Primitives.tsx usa oklch hardcoded para gradientes

Gaps:
- `--glass-bg: rgba(255, 255, 255, 0.66)` - poderia ser `oklch(1 0 0 / 0.66)`
- `--glass-border: rgba(0, 0, 0, 0.14)` - poderia ser `oklch(0 0 0 / 0.14)`
- Overlays de modal: `rgba(0, 0, 0, 0.45)` em ConflictModal.tsx:78, CheckinDialog.tsx:100, CheckoutDialog.tsx:53, ItemSidePanel.tsx:49
- PreviewSheet.tsx: `#ffffff`, `#000`, `#999` - justificado (impressao em papel)
- SideRail.tsx:105 `color: '#fff'` - deveria ser token

## Dark Mode

Implementacao: correto e funcional.
- Script inline no `<head>` previne FOUC (flash of unstyled content)
- `:root.dark {}` redefine todos os semanticos
- ThemeToggle usa `mounted` state para evitar hydration mismatch
- Sistema preference detection: NAO implementado (sem `prefers-color-scheme` listener)

Nota: usuario que preferir dark mode via OS nao tera o tema aplicado automaticamente na primeira visita.

## Alinhamento com Liquid Glass 2030

Baseado no que foi possivel verificar no CSS e componentes:

Implementado corretamente:
- Superficies vitrosas com `backdrop-filter: blur(24px) saturate(180%)`
- Caustic orbs ciano/violeta com `mix-blend-mode`
- Radii flat/craft (4-18px)
- OKLCH nas cores primarias
- Inter Tight + JetBrains Mono

Divergencias:
- CLAUDE.md local diz "dark-first" mas CSS e light-first (divergencia de doc, nao de codigo)
- Glass tokens ainda em rgba (nao oklch)
- Layer 3 inexistente

## Issues

| # | Issue | Severidade | Evidencia |
|---|---|---|---|
| 1 | Layer 3 (component tokens) inexistente | Media | globals.css - ausencia |
| 2 | DTCG JSON nao existe (referenciado mas sem pipeline) | Media | Comentario globals.css, ausencia de mmd-tokens.json funcional |
| 3 | Glass tokens em rgba em vez de oklch | Baixa | globals.css linhas 29-36 |
| 4 | Overlays de modal hardcoded, sem token semantico | Baixa | ConflictModal.tsx:78, CheckinDialog.tsx:100 |
| 5 | Sem system preference detection para dark mode | Baixa | ThemeToggle.tsx - sem prefers-color-scheme |
| 6 | Radius tokens duplicados (@theme vs :root) | Baixa | globals.css @theme e :root |
| 7 | SideRail color '#fff' hardcoded | Baixa | SideRail.tsx:105 |

## Recomendacoes

| # | Acao | Esforco | Risco |
|---|---|---|---|
| 1 | Adicionar `--dialog-overlay: oklch(0 0 0 / 0.45)` e usar em todos os modais | Baixo | Baixo |
| 2 | Remover radius duplicados - manter apenas @theme, usar classes geradas | Baixo | Baixo |
| 3 | Adicionar `prefers-color-scheme` listener no script de tema | Baixo | Baixo |
| 4 | Migrar glass tokens para oklch | Baixo | Baixo |
| 5 | Criar Layer 3 para button, dialog, input em pós-MVP | Medio | Medio |
