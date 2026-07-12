# Validação de timeout em /api/qr-sheet (W2 #22)

Análise estática do risco de timeout quando o deploy for em Vercel. Não inclui teste em runtime de produção; faz a análise de código + recomendações.

## Contexto

CLAUDE.md raiz declara `Deploy web | Vercel`. A auditoria do W2 (#22) pede validação do endpoint `POST /api/qr-sheet` contra os limites de execução serverless da Vercel.

**Limites Vercel por plano** (referência atual):

| Plano | Sync max | Streaming max |
|---|---|---|
| Hobby | 10s | 60s |
| Pro | 60s | 300s |
| Enterprise | 900s | 900s |

A rota atual responde com PDF completo no body (não streaming), então o teto efetivo é o "sync max" do plano.

## Mapeamento da rota

`apps/web/src/app/api/qr-sheet/route.ts`

- Runtime: `nodejs` (correto, `edge` não suportaria `@react-pdf/renderer`).
- `dynamic: force-dynamic` (correto).
- **Não define `export const maxDuration`** → fica no default da Vercel pra cada plano (10s Hobby).
- Sequência de trabalho dentro do handler:
  1. Parse JSON do body.
  2. `Promise.all(items.map(QRCode.toDataURL))` → gera todos os QRs em paralelo. CPU-bound, escala bem.
  3. `pdf(doc).toBlob()` do `@react-pdf/renderer` → constrói o PDF inteiro em memória, single-threaded.
  4. Retorna `NextResponse` com buffer.

**Sem pagination, sem streaming, sem chunking.** O client em `QrCodesClient.tsx:104` envia todos os items selecionados em uma única requisição.

## Estimativas (hipótese)

QR encoding (`QRCode.toDataURL`) em paralelo é rápido. O gargalo real é `@react-pdf/renderer.pdf().toBlob()`, que serializa síncrono.

| Volume | Estimativa de tempo (ordem) | Risco em Hobby (10s) | Risco em Pro (60s) |
|---|---|---|---|
| 30 items (1 folha A4 30-up) | <1s | nenhum | nenhum |
| 100 items | 1-3s | nenhum | nenhum |
| 300 items | 3-7s | borderline | nenhum |
| 500 items | 6-12s | provável estouro | nenhum |
| 1000 items | 12-25s | estouro garantido | borderline |
| 2000 items | 25-50s | estouro garantido | estouro provável |

São estimativas grosseiras (Hipótese, não testadas). Volumes reais dependem de CPU do worker Vercel e complexidade do PDF (multi-página, fontes embedded).

## Riscos identificados

1. **Sem `maxDuration` declarado.** O endpoint herda o default do plano. Em Hobby, 10s é apertado pra qualquer batch > ~300 items.

2. **Geração single-shot.** Nenhum mecanismo de chunking, streaming ou batch async. Se o usuário selecionar todo o catálogo (1500+ seriais), a única recuperação é o client cancelar.

3. **Erro genérico no client.** `QrCodesClient.tsx:122-123` exibe `error.message` ou "Erro ao gerar PDF" sem distinguir timeout (504) de erro de validação (400) ou de servidor (500). Marco e equipe vão tomar timeout como "PDF quebrado".

4. **Sem feedback de progresso.** Sem streaming nem WebSocket, o client fica em "Gerando..." sem indicação de tempo. Em batch grande percebe-se como travado.

5. **PDF inteiro em memória.** `Buffer.from(await stream.arrayBuffer())` carrega o blob completo antes de enviar. Em batches grandes (~2000+) pode estourar limite de memória do worker antes do timeout.

## Recomendações por prioridade

### P1 (aplicar agora, antes do primeiro deploy Vercel)

**1.1 Declarar `maxDuration` explícito.** Adicionar em `route.ts`:

```ts
// Cobre lotes médios (até ~1000 items em Pro).
// Hobby ignora valores > 10s, então em plano free isso vira no-op.
export const maxDuration = 60
```

Comentar deixa claro que o valor real depende do plano. Em Hobby continua 10s; em Pro vai pra 60s.

**1.2 Limitar volume no client.** Em `QrCodesClient.tsx`, antes do POST, validar `items.length`. Se > N (e.g. 300), exibir aviso "Lote grande, gera em batches" e pedir confirmação. Evita o usuário detonar 1500 items de uma vez.

Mais simples ainda: hard cap `MAX_ITEMS_PER_SHEET = 500` no client com mensagem clara, e dividir UI em "Exportar (de X a Y)" via paginação local.

**1.3 Diferenciar 504 no error handling.** Em `QrCodesClient.tsx:122`, detectar `res.status === 504` (timeout) e mostrar mensagem específica ("Lote grande demais, divida em menos seriais"), separada do erro genérico.

### P2 (W3 ou W4, se volume real provar necessidade)

**2.1 Streaming PDF.** Substituir `pdf(doc).toBlob()` por `pdf(doc).toBuffer()` (Node streams) e usar `ReadableStream` na resposta. Vercel suporta streaming até o limite "streaming max" do plano (60s em Hobby, 300s em Pro), bem mais folgado.

**2.2 Chunking server-side.** Quebrar `body.items` em lotes de N items, gerar uma promise por lote, concatenar PDFs com biblioteca externa (e.g. `pdf-lib`). Ganho real só vem com workers paralelos, não com `Promise.all` em um único handler.

**2.3 Background job.** Enviar para fila (Inngest, Trigger.dev, ou Supabase Edge Functions com WebSocket). Cliente recebe URL do PDF pronto via realtime. Solução cara, justifica se batch típico passar de 2000 items.

### P3 (não fazer agora)

- Migrar pra biblioteca PDF mais rápida (pdfkit, puppeteer). `@react-pdf/renderer` é a escolha do projeto, vale manter até prova de gargalo real.
- Cachear PDF gerado por hash do payload. QR codes têm payload por serial, raramente repetem batch idêntico.

## Decisão pendente pra Marco

1. **Volume real esperado.** Quantos seriais o Marcelo costuma imprimir de uma vez? Se típico é 30-50 (uma folha por evento), nada a fazer. Se 500+, P1 vira obrigatório.

2. **Plano Vercel.** Hobby (10s) ou Pro (60s)? Hobby força chunking no client mesmo pra 200 items.

3. **Workflow `pages.yml` ainda relevante?** Resolvido em W2 (fechamento Opus). Marco confirmou Vercel como deploy oficial. `.github/workflows/pages.yml` foi removido e substituído por `.github/workflows/ci.yml`, que só roda gates (tsc, eslint, build) sem publicar artifact. Deploy é responsabilidade da Vercel, configurada fora do repo.

## Critérios verificáveis (após resposta do Marco)

- [x] `maxDuration` explícito na route. Aplicado no fechamento Opus da W2 (`maxDuration = 60`).
- [ ] Cap de items no client com aviso. Aberto pra W3 ou W4 dependendo do volume real.
- [x] Tratamento de 504 no client. Aplicado no fechamento Opus da W2 (mensagem "Lote grande demais, divida em menos seriais").
- [ ] Smoke test em Vercel preview com volume típico do Marcelo. Pendente: depende da Vercel estar conectada.
- [x] Workflow `pages.yml` removido. Substituído por `ci.yml` (só gates, sem deploy). Vercel cuida do deploy.
