# Visual diff webpack vs turbopack (W2 #16)

Validação executada pra decidir se o `--webpack` no script `build` de `apps/web/package.json` pode sair (item #17).

## Setup

- Next.js 16.2.2.
- React Compiler ativo (`reactCompiler: true` em `next.config.ts`).
- Mesma branch, mesmo commit, mesmas env vars.
- Build executado duas vezes na mesma máquina, mesma sessão, alternando o bundler.
- Server rodado via `npx next start -p 3000` após cada build.
- Screenshots via Chrome (extensão Claude in Chrome), viewport 1440x900, em produção (`next start`), com dados Supabase reais.

## Builds

| Métrica | Webpack | Turbopack | Delta |
|---|---|---|---|
| Tempo total (`time`) | 21s | 13s | turbo 38% mais rápido |
| Compile time interno | 8.8s | 6.0s | turbo 32% mais rápido |
| Rotas geradas | 10 | 10 | igual |
| Static / Dynamic | 7 static + 3 dynamic | 7 static + 3 dynamic | igual |
| `.next/static` size | 1.8M | 1.6M | turbo -200K |
| `.next/server` size | 9.9M | 21M | turbo +11M (overhead de server runtime) |
| Chunks em `.next/static/chunks` | 31 | 23 | naming diferente, esperado |

A diferença em `.next/server` é overhead interno do turbopack (mais artifacts pra reload em dev), não vai pro cliente.

## Páginas inspecionadas

5 rotas principais, na mesma ordem em cada bundler:

1. `/` (dashboard, ReadinessCluster + UpcomingEventsRail).
2. `/items` (catálogo, ItemTable + CategoryNav).
3. `/projetos` (lista + detalhe Santos & Oliveira aberto).
4. `/qrcodes` (QrCodesClient + PreviewSheet vazio).
5. `/rfid` (RfidClient + ReaderCard).

## Resultado

**Paridade visual completa em todas as 5 páginas.**

Comparei os pares de screenshot lado a lado:

- Cores idênticas (tokens oklch resolvendo do mesmo CSS).
- Posicionamento de elementos idêntico (mesma DOM serializada, mesmo CSS).
- Tipografia idêntica (mesma fonte, mesmo peso, mesma altura de linha).
- Glass effects (blur, backdrop) idênticos.
- Dados Supabase idênticos (mesma fonte, mesma sessão).
- Sidebar collapsed/expanded comportando igual.
- Theme toggle (dark/light) no rodapé renderizando igual.

Único delta observável: ordem de carregamento de chunks no DevTools (esperado, naming/hashing difere). Não impacta render final.

## Conclusão

O bundler não muda o que chega no DOM. Como esperado: ambos compilam a mesma árvore React, com o mesmo React Compiler, com o mesmo CSS, com o mesmo runtime do Next. O bundler é detalhe de empacotamento, não muda o React tree que vira HTML.

## Implicação pro #17

`--webpack` no script `build` (apps/web/package.json) é legado, sem benefício funcional. Pode sair, alinhando local + CI (CI já usa turbopack via `npx next build` direto no workflow).

Riscos de manter:
- Divergência silenciosa entre local e CI (dev roda webpack, CI roda turbopack, qualquer regressão de bundler pode passar sem ser percebida).
- Tempo de build local 38% maior.
- Confusão de novo contribuidor que rode `npm run build` sem saber por quê tem flag.

Riscos de remover:
- Se aparecer bug específico de turbopack em prod, perde a opção rápida de fallback. Mitigação: rodar `npx next build --webpack` manualmente quando necessário, sem precisar do alias no package.json.

Recomendação: remover. Documentar em commit o motivo (paridade visual confirmada nas 5 páginas principais, turbopack já é default em CI).
