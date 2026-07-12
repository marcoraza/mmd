# E2: Componentes

## Estrutura de Pastas

```
apps/web/src/components/
├── catalog/           (11 arquivos)
├── config/            (1 arquivo)
├── dashboard/         (6 arquivos)
├── item-detail/       (6 arquivos)
├── lotes/             (5 arquivos)
├── mmd/               (6 arquivos - design system)
├── projects/          (7 arquivos + detail/ com 7)
├── qrcodes/           (2 arquivos)
└── rfid/              (4 arquivos)
```

## Inventario Completo

### mmd/ (primitivos do design system)

- `Primitives.tsx` - componentes base: Caustic, GlassCard, GlassPill, StatusDot, Ring, IconBox, Sparkline, PlaceholderImg, PrimaryBtn, GhostBtn, Badge
- `SideRail.tsx` - navegacao lateral (`'use client'` por `usePathname`)
- `ThemeToggle.tsx` - toggle dark/light
- `TopBar.tsx` - barra superior
- `Icons.tsx` - SVGs inline
- `UnderConstruction.tsx` - placeholder

### catalog/ (11 arquivos, todos `'use client'`)

- `CatalogClient.tsx` - container principal do catalogo
- `CatalogToolbar.tsx` - barra de ferramentas (search, view, sort)
- `CategoryNav.tsx` - navegacao por categoria (tablist)
- `EditableQty.tsx` - input editavel de quantidade
- `EditableStars.tsx` - rating editavel (radiogroup)
- `HeaderMenu.tsx` - menu do header
- `ItemSidePanel.tsx` - painel lateral de detalhe de item (dialog)
- `ItemTable.tsx` - tabela de itens
- `LotesCard.tsx` - card de lotes
- `OperationalBanner.tsx` - banner de filtros operacionais
- `Stars.tsx` - rating estatico
- `UnitsTable.tsx` - tabela de unidades
- `ViewModeToggle.tsx` - toggle tipos/unidades

### dashboard/ (6 arquivos)

- `CinematicHero.tsx` - hero principal (Server Component)
- `Countdown.tsx` - contagem regressiva (`'use client'`)
- `DashboardSkeleton.tsx` - skeleton loading (Server Component)
- `MetadataFooter.tsx` - rodape com metadados (Server Component)
- `ReadinessCluster.tsx` - cluster de readiness (Server Component)
- `StatStrip.tsx` - faixa de estatisticas (Server Component)
- `UpcomingEventsRail.tsx` - rail de proximos eventos (`'use client'`)

### projects/ e detail/

- `ConflictModal.tsx` - modal de conflito de alocacao (`'use client'`)
- `InlineItemPicker.tsx` - picker de itens inline (`'use client'`)
- `InlineNewProjectForm.tsx` - formulario novo projeto (`'use client'`)
- `ProjectCalendarView.tsx` - visao calendario (`'use client'`)
- `ProjectKanbanView.tsx` - visao kanban (`'use client'`)
- `ProjectListView.tsx` - visao lista (`'use client'`)
- `ProjectsClient.tsx` - container de projetos (`'use client'`)
- `detail/AllocationTab.tsx` - aba de alocacao (`'use client'`)
- `detail/CheckinDialog.tsx` - dialog check-in (`'use client'`)
- `detail/CheckoutDialog.tsx` - dialog check-out (`'use client'`)
- `detail/MovimentacoesTab.tsx` - aba movimentacoes (`'use client'`)
- `detail/PackingTab.tsx` - aba packing (`'use client'`)
- `detail/ProjectDetailClient.tsx` - container detalhe (`'use client'`)
- `detail/SerialPicker.tsx` - picker de serial (`'use client'`)

### qrcodes/

- `QrCodesClient.tsx` - pagina de QR codes (`'use client'`)
- `PreviewSheet.tsx` - preview de folha de impressao (`'use client'`)

### rfid/

- `ReaderCard.tsx`, `RfidBanner.tsx`, `RfidClient.tsx`, `ScanTimeline.tsx` - todos `'use client'`

## Padroes Identificados

### `'use client'` - Incidencia

- **44 arquivos** com `'use client'`
- Todos os *Client.tsx tem o padrao correto: componente de folha interativo
- POREM: `SideRail.tsx` e `'use client'` por causa de `usePathname` - poderia ser RSC com `pathname` vindo de prop (alternativa: manter, tem justificativa)
- Inferencia: a maioria dos `'use client'` e legitimo, mas alguns componentes como `RfidBanner.tsx`, `LotesBanner.tsx` provavelmente poderiam ser RSC

### Utilities de classe

- **Nenhum uso** de `cn()`, `clsx`, `tailwind-merge`, `cva` encontrado no codigo
- Mistura de `className=` (246 ocorrencias) e `style={{` (906 ocorrencias)
- Predominancia de inline styles sobre Tailwind classes
- O design system usa CSS vars (`var(--*)`) via inline style, nao tokens Tailwind

### forwardRef

- Nao encontrado `forwardRef` no repositorio (correto para React 19 - API simplificada)

### Props typing

- Todos os componentes usam TypeScript com props tipadas localmente
- Sem uso de interfaces compartilhadas entre componentes (cada um define seus tipos inline)

### Naming conventions

- Componentes: PascalCase - consistente
- Arquivos: PascalCase.tsx - consistente
- Diretorios: kebab-case (catalog, item-detail, lotes) - consistente

### Composicao

- Padrao container/presentacional presente em paginas (RSC carrega dados, Client recebe props)
- Sem Compound Components formais
- Sem slots/children pattern em componentes complexos

## Hotspots

| Componente | Motivo |
|---|---|
| `CatalogClient.tsx` | Mais de 200 linhas, multiplos `useMemo`/`useCallback` |
| `ItemSidePanel.tsx` | Dialog sem focus trap real |
| `CheckinDialog.tsx` | Dialog sem focus trap, useEffect para Escape |
| `ProjectListView.tsx` | Logica complexa de sorting e filtros |
| `QrCodesClient.tsx` | Tres `useMemo` encadeados |

## Issues por Severidade

| Issue | Severidade |
|---|---|
| Sem `cn`/`cva` - zero sistema de variants | Alta |
| Inline styles dominam (906x vs 246x className) | Alta |
| Dialogs sem focus trap real (apenas Escape via useEffect) | Alta |
| Ausencia de `components/ui/` (sem shadcn) | Media |
| `useCallback` em CatalogClient com React Compiler inativo | Media |
| Tipos locais repetidos entre componentes | Baixa |
