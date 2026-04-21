# Stitch Prompt: MMD Estoque Inteligente — Full Redesign

## Visual Reference

Use the attached screenshot (Lufia health dashboard) as the design foundation. Adapt the following visual patterns from it:

**Layout structure:**
- Dark textured hero/header area at the top with organic flowing background (dark gradients, wave-like aurora texture, NOT flat black)
- Light content area below (#F5F5F5 or very light gray background)
- Cards with white background, subtle 1px border (#E5E5E5), rounded corners (~12px), no drop shadows
- Generous whitespace between cards and sections

**Typography hierarchy:**
- Primary greeting/title: large serif or italic serif for emphasis, white on dark header
- Date/context line: small sans-serif, muted color, above the title
- Metric values: very large sans-serif bold numbers (40-64px) — the main data point in each card
- Metric units/suffixes: smaller weight, inline with the number (like "kg", "bpm", "kcal")
- Labels above metrics: small (12-13px), gray (#888), regular weight
- Card titles: medium sans-serif (16px), with icon prefix, "..." menu on the right

**Data presentation:**
- Hero number pattern: small gray label on top, giant bold number below, comparison/delta next to it (colored: green for positive, red for negative)
- Sub-metrics in 2x2 or 3-column grids below the main metric inside the same card
- Progress bars with rounded ends and gradient fills
- Bar charts with mostly muted/ghost bars, active period highlighted with accent color
- Tooltip on chart hover showing detail breakdown

**Color approach:**
- Dark header: near-black (#1A1A1A to #2A2A2A) with organic texture
- Content background: off-white (#F5F5F7)
- Cards: pure white
- Text: #1A1A1A for values, #888888 for labels
- Accent: one highlight color per chart/section (purple for charts, green for progress, gold for warnings)
- Status chips: dark pills with icon + label on the header area

**Navigation:**
- Tab bar between header and content (Overview, Vitals, Activity style) — horizontal, underline-style active indicator
- Clean, no heavy borders between tabs

**Interaction patterns:**
- Three-dot menu (...) on each card for actions
- Inline tooltips on data points
- Status/trait chips as pills in the header area

---

## Product Context

MMD Estoque Inteligente — inventory management system for an AV/events equipment rental company. RFID + QR Code tracking, depreciation calculations, project checkout/return flows.

The system manages:
- 262 equipment types (items) with 519 individual serial numbers
- 152 cable/accessory lots
- Projects (events) with packing lists, checkout, and return workflows
- Movement history (dispatch, return, maintenance, damage)

Currency: BRL (R$). Language: Portuguese (pt-BR).

---

## Screens to Generate

### Screen 1: Dashboard

**Header area (dark, textured):**
- Date line: "Sexta-feira, 3 de Abril 2026"
- Greeting: "Bom dia, Marcelo." (italic serif for the name)
- Status chips: "519 Equipamentos", "511 Disponiveis", "Desgaste 2.5/5"

**Tab navigation:**
Overview | Inventario | Lotes | Projetos | Movimentacoes | Config

**Card row 1 — Patrimonio (2 cards side by side):**

Card 1 "Valor do Patrimonio":
- Main metric: "R$ 707.348" (large)
- Subtitle: "Valor Atual" with delta "-11.2% deprec." in gold
- Bar chart below: monthly values, last month highlighted
- Sub-metrics grid: Valor Original R$ 796.323 | Depreciacao R$ 88.974 | Desgaste medio 2.5/5

Card 2 "Saude do Estoque":
- Main metric: "291" (large) — critical items
- Subtitle: "Equipamentos Criticos" with label "desgaste <= 2"
- Progress bar: 291/519 filled (red/warning gradient)
- Sub-metrics: Em Manutencao 0 | Inativos 0 | Lotes 152 | Em Campo 0

**Card row 2 — Analytics (3 cards):**

Card 3 "Valor por Categoria":
- Horizontal bar chart, 8 bars (one per category: ILUMINACAO, AUDIO, CABO, ENERGIA, ESTRUTURA, EFEITO, VIDEO, ACESSORIO)
- Bars proportional to value, accent color on largest
- Value label at end of each bar

Card 4 "Distribuicao de Status":
- Donut or horizontal stacked bar
- Segments: DISPONIVEL (511), PACKED (0), EM_CAMPO (0), MANUTENCAO (0), INATIVO (8)
- Legend with colored dots + count

Card 5 "Perda Patrimonial":
- Compact table rows inside card
- Columns: Categoria | Perda R$ | Deprec %
- Sorted by loss descending
- Loss values in red, depreciation % in gold

**Card row 3 — Activity & Rankings (2 cards):**

Card 6 "Atividade Recente":
- Timeline/feed list, last 10 movements
- Each: colored dot (yellow=SAIDA, green=RETORNO, red=DANO) + description + timestamp
- Empty state: "Nenhuma movimentacao registrada"

Card 7 "Top 10 Mais Valiosos":
- Ranked list: #, equipment name, category chip, wear bar (5 segments), value
- Compact rows

**Card row 4 — Projects preview:**

Card 8 "Projetos Ativos":
- Show active projects (status CONFIRMADO or EM_CAMPO) as mini-cards
- Each: project name, client, date range, progress bar (items dispatched / total)
- Empty state: "Nenhum projeto ativo"

---

### Screen 2: Inventario (Lista)

**Same header area** but with:
- Title: "Inventario"
- Subtitle: "262 itens"
- Action button (top right): "+ Novo Item"

**Search bar** below tabs — full width, clean input with search icon

**Filter chips row:** ILUMINACAO | AUDIO | CABO | ENERGIA | ESTRUTURA | EFEITO | VIDEO | ACESSORIO (toggle multi-select, pill style)

**Table in cards:**
Each item as a card row (NOT traditional table, follow the card-based Lufia style):
- Left: item photo thumbnail (or category icon placeholder)
- Center: Item name (bold), marca + modelo below, subcategoria tag
- Right side metrics: Qtd total, Disponiveis (green number), Valor unitario
- Category badge pill
- Subtle right arrow or chevron for navigation

Pagination at bottom: numbered pages

---

### Screen 3: Item Detalhe

**Header area:**
- Title: item name
- Subtitle: marca + modelo
- Chips: category badge, subcategoria, tipo rastreamento (INDIVIDUAL/LOTE/BULK)
- Action buttons: "Editar" + "Excluir"

**Metrics card row (single card, 6 metrics in grid):**
Quantidade Total | Disponiveis | Em Campo | Manutencao | Valor Unitario | Valor Total Atual
Each as: small label + large number

**Notes block** (if present): light card with item notes text

**Serial Numbers section:**
Card with title "Serial Numbers" + button "+ Adicionar Serial"
Table rows inside card:
- Codigo Interno (mono) + Serial Fabrica below
- Status (badge)
- Estado (NOVO/SEMI_NOVO/USADO/RECONDICIONADO)
- Desgaste (5-segment bar)
- Valor Atual
- Tag RFID (truncated mono)
- QR Code (truncated mono)
- Localizacao
- Actions: edit pencil, delete trash

**Movement History section:**
Card with title "Historico de Movimentacoes"
Timeline list:
- Type (colored badge: SAIDA/RETORNO/MANUTENCAO/TRANSFERENCIA/DANO)
- Serial code
- Status change (anterior -> novo)
- Project name (if linked)
- Who registered + scan method
- Timestamp
- Notes

---

### Screen 4: Lotes

**Header:** Title "Lotes", subtitle "152 lotes", button "+ Novo Lote"

**Search bar** + status filter chips (DISPONIVEL | EM_CAMPO | MANUTENCAO)

**Table card rows:**
- Codigo do lote (mono bold)
- Item vinculado (name + subcategoria below + category badge)
- Descricao
- Quantidade (bold number)
- Status badge
- Tag RFID (truncated)
- QR Code (truncated)
- Actions: edit, delete

**Inline form** (expands when creating/editing):
Fields: Item (select), Codigo do Lote, Descricao, Quantidade, Status, Tag RFID, QR Code

---

### Screen 5: Projetos

**Header:** Title "Projetos", button "+ Novo Projeto"

**Filter chips:** PLANEJAMENTO | CONFIRMADO | EM_CAMPO | FINALIZADO | CANCELADO

**Project cards (grid 2-3 columns):**
Each card:
- Project name (large bold)
- Client name
- Status badge
- Date range: "15 Mar — 18 Mar 2026"
- Location
- Progress bar with label "12/45 itens despachados"
- Three-dot menu

---

### Screen 6: Projeto Detalhe

**Header:** Project name, client, status badge, date range, location

**Metrics row:** Total Itens | Serials Designados | Despachados | Retornados | Pendentes

**Packing List card:**
Title "Packing List" + button "+ Adicionar Item"
Table: Item name | Categoria | Qtd Solicitada | Serials Designados (comma list) | Notas | Actions

**Action buttons area:**
- "Checkout — Despachar Equipamentos" (primary)
- "Retorno — Receber Equipamentos" (secondary)

---

### Screen 7: Movimentacoes

**Header:** Title "Movimentacoes"

**Filters row:** Search + Type filter (SAIDA/RETORNO/MANUTENCAO/TRANSFERENCIA/DANO) + Date range picker + Project filter

**Button:** "+ Nova Movimentacao"

**Table card rows:**
- Type badge (colored)
- Equipment: serial code + item name
- Project name
- Status change: "DISPONIVEL -> EM_CAMPO"
- Registered by + scan method badge (RFID/QRCODE/MANUAL)
- Notes (truncated)
- Timestamp

Pagination at bottom.

---

## Important Notes for Generation

- All text in Portuguese (pt-BR)
- Currency format: R$ 707.348,99 (dot for thousands, comma for decimals)
- Dates: "3 de Abril 2026" format
- The dark header area should feel premium and editorial, not corporate
- Cards should feel spacious, not cramped — let the data breathe
- Metrics should follow the Lufia pattern: small muted label, then giant bold number, then unit/context
- Every screen shares the same header structure (dark textured + tab nav)
- Mobile: tabs become bottom nav, cards stack vertically, table rows become cards
