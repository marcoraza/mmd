# Handoff: MMD Estoque Inteligente

Data: 2026-06-23

Fonte operacional atual para agentes: `docs/mar-171-agent-brief.md`

## Estado da entrega

Versão web em Next.js já existe e continua sendo o produto vivo. O trabalho atual do PRD MAR-171 adapta essa base para MVP operacional real: Evento, ficha, packing, alocação, aluguel avulso, check-out, retorno, dashboard, QR seguro, auth real e validação física RFID.

O iOS compila no simulador e já tem contratos de checkout/retorno compartilhados com o web. Produção mobile ainda depende de iPhone físico, signing, Zebra RFD40, tags reais e validação presencial.

Prints em `tasks/evidence/` são evidência, referência visual e QA. Eles não são um novo front-end paralelo.

## URLs

- Produção Vercel: `https://mmd-zeta.vercel.app`, deploy novo em modo demo e somente leitura.
- Deployment final: `https://mmd-ddygma61w-marcos-projects-fcdf4795.vercel.app`, protegido por Vercel Authentication quando acessado direto.
- Inspect Vercel: `https://vercel.com/marcos-projects-fcdf4795/mmd/Fq5JFBNsKTgjLdb6ntMMhR5w5JeG`.
- Preview Vercel seguro anterior: `https://mmd-8vuxcc3le-marcos-projects-fcdf4795.vercel.app`, protegido por Vercel Authentication.
- Supabase: `bphmxticdyuctovfumcj`. Validação local e remota aplicada para a base atual, incluindo importação oficial Event Pro.

## Variáveis de ambiente

Configurar em Vercel e GitHub Actions:

```bash
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
MMD_DATA_MODE=auto
MMD_READONLY=true
NEXT_PUBLIC_MMD_CLIENT_WRITES=false
```

`SUPABASE_SERVICE_ROLE_KEY` nunca entra no cliente. Ela é usada só pelo servidor Next para ler e escrever via Supabase Admin.

Sem env explícita, ambiente Vercel cai em `demo` e bloqueia escrita por padrão. Para operar dados reais em ambiente privado, usar `MMD_DATA_MODE=auto` ou `real` e `MMD_READONLY=false` conscientemente.

## O que está pronto para validar

- Dashboard com KPIs de estoque e painéis consolidados de readiness em modo local/demo.
- Catálogo de itens e unidades.
- Detalhe de item com unidades e timeline.
- Eventos e detalhe de Evento usando internamente rotas antigas de projeto quando necessário.
- Ficha de Evento persistida localmente, pendente de Supabase real.
- Packing manual, importação de planilha e sugestão revisável localmente.
- Alocação por unidade, aluguel avulso, gate de saída e check-out localmente.
- Retorno com OK, manutenção e pendente de resolução localmente.
- QR público seguro em `/s/[codigo]`, sem valor, serial, RFID, localização ou histórico.
- Ficha interna autenticada em `/qrcodes/[codigo]`.
- Geração de folha PDF de QR codes unit-only.
- Tela RFID administrativa para tags e leituras.
- Tela de falha quando Supabase cai.
- Fallback demo no data layer para Preview/local quando Supabase falhar.
- QR PDF codificando URL pública `/s/[codigo]`, mantendo o código visível na etiqueta.
- Modo somente leitura bloqueando Server Actions e mutação client-side do catálogo por padrão.
- Importação oficial Event Pro aplicada no Supabase real: 11 arquivos, 16 eventos, 1 cancelado, 89 candidatos únicos de catálogo e 313 pendências de revisão.
- Status `MONTAGEM` existe no banco, web e iOS, e check-out aceita `CONFIRMADO` ou `MONTAGEM`.

## O que não deve ser prometido como pronto

- Fechamento visual da fila de revisão de importações.
- Aprovação operacional dos 89 candidatos de catálogo.
- RFD40 Zebra real em operação.
- TestFlight ou app instalado em aparelho.
- Realtime comprovado em produção.
- Fluxo mobile validado em aparelho físico.
- Export estático `/nmd`.
- Fechamento de MAR-172 a MAR-186 como `Done`. Elas seguem abertas por dependerem de MAR-189.

## Validações já feitas

- Web lint: passou.
- Web lint com `--max-warnings=0`: passou.
- Web typecheck: passou.
- Web build: passou.
- Rotas principais em produção local: passaram quando havia dados carregados.
- Com Supabase fora, `/items` mostra erro amigável.
- Com Supabase fora, `/s/MMD-ACE-0001` mostra erro amigável.
- QR PDF pequeno: `200`, `application/pdf`, PDF válido.
- iOS `build-for-testing`: passou no simulador iPhone 17, OS 26.3.1.
- Vercel Preview seguro: deploy novo ficou `Ready`.
- Vercel público: preview responde `401` sem autenticação por causa da proteção da Vercel.
- Supabase REST: respondeu `200` para itens e seriais reais.
- Smoke local real: `/`, `/items`, `/projetos`, `/lotes`, `/qrcodes`, `/rfid`, `/s/MMD-ILU-0065`, detalhe de item, detalhe de projeto e detalhe de lote retornaram `200`.
- Smoke local demo: mesmas telas principais e detalhes fixture retornaram `200` com `MMD_DATA_MODE=demo`.
- Browser: `/s/MMD-ILU-0065` mostrou ficha real, `/qrcodes` mostrou unidades/lotes reais, sem erro de console e sem overflow horizontal.
- Browser: tentativa de editar condição no catálogo mostrou `Modo somente leitura: alterações não são salvas.` e não gerou erro de console.
- Preview Vercel seguro: `/s/MMD-ILU-0001` mostrou fixture `Moving Beam 7R 230W`, provando que não vaza estoque real por default.
- Produção pública: `/`, `/items`, `/projetos`, `/lotes`, `/qrcodes`, `/rfid`, `/config` e `/s/MMD-ILU-0001` retornaram `200`.
- Produção pública: `/items` e `/s/MMD-ILU-0001` carregaram fixture demo, não estoque real.
- Produção pública: `/api/qr-sheet` respondeu `200`, `application/pdf`, PDF `%PDF-1.3`.
- Browser produção: `/s/MMD-ILU-0001` abriu sem erros de console e mostrou `Moving Beam 7R 230W`.
- Browser produção mobile: `/items` abriu sem erros de console e a busca do topo foi corrigida para não vazar da tela.
- Supabase local no repo principal: `supabase db start` passou com todas as migrations.
- Supabase local no repo principal: `supabase db reset --local --no-seed` passou.
- Supabase local no repo principal: `supabase db lint --local` passou.
- Supabase local no repo principal: `supabase db advisors --local` passou.
- Supabase local no repo principal: `supabase migration list --local` listou 14 migrations até `20260623094805`.
- RLS/grants locais: tabelas internas com RLS ativo e `anon` sem acesso.
- Funções sensíveis locais: RPCs de checkout/retorno sem execução para `anon` e `authenticated`, com execução por `service_role`.
- Supabase remoto: migration `20260623193758_event_pro_import_official.sql` aplicada.
- Importação Event Pro: lote `902ce07f-32dd-41b9-9ad3-6d1b5886853c` criado no Supabase oficial.
- Verificação remota pós-importação: 16 eventos, 11 arquivos, 11 hashes únicos, 11 originais em Storage, 89 candidatos únicos, 313 pendências e 7 linhas de packing.
- Web: `npm exec tsc -- --noEmit` passou após importador e status `MONTAGEM`.
- Web: `npm run lint -- --max-warnings=0` passou após importador e status `MONTAGEM`.
- Testes: `node --test --experimental-strip-types src/lib/event-pro-import-core.test.ts src/lib/checkout-gate-core.test.ts` passou com 13 testes.
- Supabase local: `supabase db reset --local --no-seed`, `supabase db lint --local` e `supabase db advisors --local` passaram com a migration Event Pro.

## Blocker atual

MAR-189 deixou de ser o bloqueio transversal de Supabase para este corte. A base real, migration Event Pro e importação oficial foram aplicadas.

MAR-188 segue como bloqueio separado: iPhone físico, signing, RFD40 pareado e tags reais.

Novo foco operacional: transformar a fila de revisão Event Pro em tela para o Marcelo aprovar candidatos, resolver montagem pendente e limpar linhas ambíguas.

## Próximo passo operacional

1. Agente web cria tela de revisão para `event_import_issues` e `catalog_item_candidates`.
2. Marcelo revisa candidatos como item de catálogo, aluguel de parceiro, serviço ou ignorado.
3. Front-end adapta telas existentes no design system atual. Não cria produto paralelo.
4. Mobile segue no simulador até haver iPhone, signing, RFD40 e tags reais.
5. Supervisor mantém migrations, importador e evidência remota sincronizados no Linear.
