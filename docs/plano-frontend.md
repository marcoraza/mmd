# Plano de Frontend, MMD Estoque Inteligente

## Estratégia

**Construir todo o frontend com mock tipado, depois plugar Supabase no final.**

Não é gambiarra quando a arquitetura respeita separação de camadas. É mais rápido, dá produto navegável pra feedback visual cedo, e valida o contrato de dado antes de gastar tempo em query.

## Por que essa ordem

1. O handoff (`design_handoff_estoque_mmd/`) já fechou o visual. 10 JSX, 13 screenshots. Contrato visual é estável, risco de retrabalho de UX é baixo.
2. O schema Supabase já existe em `supabase/migrations/00001_initial_schema.sql`, desenhado espelhando Rentman. Contrato de dado já está mapeado.
3. Prototype navegável em 2-3 dias vale mais que 1 tela por dia com dado real.
4. Integração tela a tela depois é passe mecânico se o tipo está correto.

## Regras que previnem gambiarra

- **Componentes puros.** Recebem props tipadas. Não fazem fetch. Portados dos JSX do handoff.
- **Data layer isolada.** Cada tela tem um `loadX(): Promise<XData>` em `lib/data/<tela>.ts`. Hoje retorna mock tipado, amanhã chama Supabase. Trocar é substituir função, não tocar UI.
- **Types centralizados.** `lib/types.ts` é contrato único entre front e back. Nunca `any`.
- **Mock bem formado.** Cardinalidade, nulls e edge cases espelham o que Supabase vai devolver. Mock frouxo esconde bug de integração.

## Fases

### Fase 1, Reset

Deletar frontend antigo. Preservar:

- `app/layout.tsx`, `app/globals.css`, `app/favicon.ico`
- `components/mmd/` (Icons, Primitives, SideRail, TopBar)
- `lib/supabase.ts`, `lib/types.ts`
- `hooks/useRealtimeRefresh.ts`

### Fase 2, Port visual

Portar 10 JSX do handoff para TSX. Ordem de entrega:

1. Dashboard: `screen-dashboard.jsx` vira `app/page.tsx`
2. Catálogo: `catalog-calendar.jsx` vira `app/catalogo/page.tsx`
3. Item detalhe: `screen-item-detail.jsx` vira `app/items/[id]/page.tsx`
4. Projetos e packing: `screen-projects.jsx` vira `app/projetos/page.tsx`
5. RFID scan: `screen-rfid-scan.jsx` vira `app/rfid/page.tsx`
6. Checkout: `screen-checkout.jsx` e `screen-checkout-combined.jsx` viram `app/checkout/page.tsx`
7. Conflict resolver: `conflict-resolver.jsx` vira modal/overlay
8. Support screens: `support-screens.jsx` cobre onboarding, QR print sheet, vincular tag, item perdido, modo packing

Cada tela:

- Componente de apresentação puro portado do JSX.
- `lib/data/<tela>.ts` com `loadX()` devolvendo mock tipado.
- Navegação funcional entre telas.

Commits pequenos, um por tela.

### Fase 3, Review visual

Marco revisa o produto navegável. Itera copy, layout, densidade, estados vazios. Sem tocar em backend.

### Fase 4, Plug Supabase

Substituir `loadX()` de cada tela por query Supabase real. Contrato de tipo protege. Realtime onde fizer sentido.

### Fase 5, iOS (Sprint 2)

App nativo SwiftUI com mesma separação: componentes de apresentação mais repositório que hoje usa mock, amanhã usa Supabase iOS SDK e Zebra RFID.

## Regras globais

- Português pt-BR em toda copy.
- Sem em-dash.
- oklch em todo token de cor, nunca hex.
- Inter Tight e JetBrains Mono, já configurados em `app/layout.tsx`.
- Liquid glass e caustic orbs conforme `design_handoff_estoque_mmd/styles/glass.css`.
