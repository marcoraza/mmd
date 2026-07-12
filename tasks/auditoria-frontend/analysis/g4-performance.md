# G4: Performance

## React Compiler

### Status: INATIVO (Alta Severidade)

Verifiquei `apps/web/next.config.ts`:
```typescript
const nextConfig: NextConfig = {
  images: { unoptimized: true },
  turbopack: { root: __dirname },
};
```

`reactCompiler: true` esta AUSENTE. React Compiler nao esta ativo.

Implicacao: os `useMemo`/`useCallback` existentes no codigo nao sao redundantes - eles sao necessarios. Ativar o Compiler e um quick win de alto impacto para este projeto.

### `useMemo`/`useCallback` - Avaliacao sem Compiler

Dado que o Compiler esta inativo, vou avaliar se os usos sao apropriados:

**`CatalogClient.tsx`:**
- `useCallback(handleModeChange, [])` - correto (escrito sem deps que mudam)
- `useCallback(handleCondicaoChange, [items, updateDesgaste])` - questionavel: `items` no array de deps causa re-criacao frequente do callback
- `useCallback(handleQtdChange, [items, updateQuantidade])` - mesmo problema

**`QrCodesClient.tsx`:**
- `useMemo(() => source, [units, lotes, mode])` - correto
- `useMemo(() => filtered, [source, query])` - correto
- `useMemo(() => items, [filtered, selected])` - correto

**`CheckinDialog.tsx`:**
- `useMemo(() => defaultDesgaste, [seriais])` - correto

**`ProjectCalendarView.tsx`:**
- `useMemo(() => days, [cursor])` - correto

**`UnitsTable.tsx`:**
- `useMemo(() => sorted, [...])` - correto
- `useMemo(() => groups, [sorted, groupBy])` - correto

**`ProjectListView.tsx`:**
- `useMemo(() => sortPacking, [projeto.packing, sort])` - correto

Conclusao: a maioria dos `useMemo`/`useCallback` existentes e justificada, exceto `handleCondicaoChange`/`handleQtdChange` em CatalogClient que tem anti-pattern de `items` no dep array causando re-criacao desnecessaria.

## Render Performance

### Keys Instáveis (Media Severidade)

Verifiquei `key={i}` (indice) em:
- `ProjectCalendarView.tsx:117` - dias do calendario (array estatico por cursor)
- `PreviewSheet.tsx:98` - celulas de QR (array de items para impressao)
- `EditableStars.tsx:44` - estrelas 1-5 (array estatico, aceitavel)
- `Stars.tsx:21` - estrelas 1-5 (array estatico, aceitavel)
- `LotesBanner.tsx:66` - items de banner (array que pode mudar)
- `DashboardSkeleton.tsx:33,42` - skeletons (array estatico, aceitavel)
- `QrPlaceholder.tsx:48` - celulas SVG (array estatico, aceitavel)
- `RfidBanner.tsx:70` - items de banner (array que pode mudar)

Critico: `LotesBanner.tsx:66` e `RfidBanner.tsx:70` usam arrays que podem mudar, key por index causa re-renders de itens errados.

### useEffect para Derivar Estado (Media Severidade)

Verifiquei `CatalogClient.tsx` linhas 41-44:
```tsx
const [items, setItems] = useState<CatalogItem[]>(data.items)
useEffect(() => {
  setItems(data.items)
}, [data.items])
```

Este e o anti-pattern classico: estado que deveria ser derivado de props. `data.items` e imutavel (vem de RSC), entao o useEffect e desnecessario. Se `data` mudar, o componente re-monta ou o React faz reconciliacao. Solucao: usar `data.items` diretamente ou inicializar sem o `useEffect`.

### useEffect para Keyboard Events (Menor Impacto)

Multiplos componentes (ConflictModal, CheckinDialog, CheckoutDialog, ItemSidePanel, SerialPicker) usam:
```tsx
useEffect(() => {
  const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
  window.addEventListener('keydown', handler)
  return () => window.removeEventListener('keydown', handler)
}, [onClose])
```

Este padrao e correto (com cleanup), mas adiciona um listener global por dialog aberto. Com focus trap correto, `onKeyDown` no elemento do dialog seria preferivel.

## Bundle

### `images: { unoptimized: true }` (Alta Severidade)

`next.config.ts:2`: `images: { unoptimized: true }` desabilita completamente a otimizacao de imagens do Next.js. Isso significa:
- Sem conversao para WebP/AVIF
- Sem lazy loading automatico com blurhash
- Sem srcset/sizes automatico

Justificativa provavel: deploy em GitHub Pages (exportacao estatica). `next/image` com otimizacao requer servidor. Para Vercel (deploy ativo via `.vercel/project.json`), isso nao se aplica - pode ser removido se deploy for no Vercel.

### `@react-pdf/renderer` (Media Severidade)

`package.json` inclui `@react-pdf/renderer: ^4.5.1` como dependencia de producao. Este e um pacote pesado. E usado em `src/app/api/qr-sheet/route.ts` como API Route.

Como API Route server-side, o bundle cliente nao e afetado. Impacto de bundle: baixo. Mas o `route.ts` importa em server-side e o tempo de cold start pode ser elevado.

### `lucide-react: ^1.7.0`

Version 1.7.0 e recente. O projeto importa apenas os icones usados em `Icons.tsx`. Tree-shaking deve funcionar. Verifiquei que Icons.tsx importa individuais, nao `import * from 'lucide-react'`.

### next/image

Verifiquei: `ItemSidePanel.tsx` linha ~120 tem:
```tsx
{/* eslint-disable-next-line @next/next/no-img-element */}
<img src={item.foto_url} alt={item.nome} ... />
```

Usa `<img>` nativo em vez de `next/image`, com eslint-disable para suprimir o aviso. Com `images: { unoptimized: true }`, `next/image` nao oferece vantagem de otimizacao, mas o eslint-disable e um code smell.

### next/font (Verifiquei)

`layout.tsx` usa `next/font/google` corretamente com:
- `subsets: ['latin']`
- `display: 'swap'`
- Variables CSS

Correto.

### Dynamic Imports

Verifiquei: nenhum uso de `dynamic()` do Next.js encontrado. Componentes pesados como `QrCodesClient` (com preview de PDF) sao importados estaticamente.

Potencial quick win: `import dynamic from 'next/dynamic'` para `PreviewSheet` (preview PDF) e componentes de dialog grandes.

## Turbopack vs Webpack

Verifiquei:
- `dev`: usa Turbopack (configurado em next.config.ts)
- `build`: usa `--webpack` explicitamente

Inconsistencia: o projeto tem dois bundlers para dois ambientes. Isso pode causar comportamentos diferentes entre dev e prod. Para producao no Vercel, seria melhor remover `--webpack` e deixar o Turbopack stable fazer o build (Next.js 16 tem Turbopack stable).

## Core Web Vitals

Hipotese: sem dados reais de producao disponiveis.

Riscos identificados no codigo:
- LCP: RSC com Suspense e bom. Mas `images: { unoptimized: true }` pode aumentar LCP se ha imagens grandes
- INP: useEffect para listeners globais de teclado contribui para jank potencial em dispositivos lentos
- CLS: sem `sizes`/`srcset` nas imagens
- Instrumentacao: nao encontrei Vercel Analytics, Web Vitals, Sentry no codigo

## Issues

| # | Issue | Severidade | Evidencia |
|---|---|---|---|
| 1 | React Compiler inativo | Alta | next.config.ts - ausencia de reactCompiler |
| 2 | `images: { unoptimized: true }` | Alta | next.config.ts:2 |
| 3 | `useEffect` para derivar estado em CatalogClient | Media | CatalogClient.tsx linhas 41-44 |
| 4 | Keys instáveis (`key={i}`) em listas dinamicas | Media | LotesBanner.tsx:66, RfidBanner.tsx:70 |
| 5 | Build usa `--webpack` em vez de Turbopack stable | Media | package.json scripts.build |
| 6 | Sem dynamic imports para componentes pesados | Media | Ausencia de next/dynamic |
| 7 | `<img>` em vez de `next/image` com eslint-disable | Media | ItemSidePanel.tsx~120 |
| 8 | Sem instrumentacao de Web Vitals | Baixa | Ausencia no codigo |
| 9 | useCallback com `items` no dep array (CatalogClient) | Baixa | CatalogClient.tsx linhas 63-79 |
