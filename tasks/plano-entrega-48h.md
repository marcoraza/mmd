# Plano de Entrega 48h: MMD Estoque

Data de corte: 2026-06-09

## Tese

Entregar uma versão web operacional em Vercel runtime. iOS entra como app compilável e demo em mock. RFID real com RFD40 fica fora do compromisso de 48h até existir SDK Zebra, signing e teste em aparelho.

## Decisão de Escopo

- Fazer agora: web com catálogo, projetos, lotes, QR PDF, RFID administrativo e modo público seguro sem auth.
- Fazer agora: deploy Vercel com envs corretas e smoke test em preview seguro.
- Fazer agora: handoff para Marcelo com demo script, limitações honestas e próximos passos.
- Não fazer agora: export estático `/nmd`.
- Não fazer agora: TestFlight, RFD40 real, auth, realtime garantido, dashboard 100% real.

## OBSERVADO

- Web: lint, typecheck e build passam localmente.
- Web: rotas de dados foram convertidas para runtime dinâmico, evitando HTML congelado no build.
- Web: quando Supabase cai, `/items` mostra tela de erro útil em vez de loading infinito.
- Web: QR PDF respondeu `200`, `application/pdf`, arquivo `%PDF-1.3`.
- Web: rota pública `/s/[codigo]` foi criada e entra como dinâmica no build.
- Vercel: preview seguro ficou pronto em `https://mmd-8vuxcc3le-marcos-projects-fcdf4795.vercel.app`.
- Vercel: preview está protegido por Vercel Authentication e responde `401` sem acesso.
- Vercel: as envs `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` existem em Preview, Development e Production.
- Supabase: REST voltou a responder `200` para itens e seriais reais.
- Web: fallback demo foi adicionado para Preview/local quando Supabase falhar.
- Web: QR PDF agora codifica URL pública `/s/[codigo]`, não só o texto do código.
- Web: Vercel sem env explícita cai em dados demo e somente leitura, evitando exposição pública do estoque real.
- Vercel: produção pública `https://mmd-zeta.vercel.app` foi promovida para o deploy novo em modo demo e somente leitura.
- Web: produção pública retornou `200` em `/`, `/items`, `/projetos`, `/lotes`, `/qrcodes`, `/rfid`, `/config` e `/s/MMD-ILU-0001`.
- Web: produção pública gerou QR PDF válido em `/api/qr-sheet`.
- Browser: produção pública abriu `/s/MMD-ILU-0001` sem erro de console.
- Browser: catálogo mobile em produção foi corrigido e validado sem erro de console.
- iOS: `xcodebuild build-for-testing` passou no simulador iPhone 17, OS 26.3.1.
- Supabase connector: a conta conectada não tem permissão no projeto MMD.
- Supabase connector: lista apenas `TurboClaw` e `MARCO OS`.

## INFERIDO

- O maior risco da entrega não é frontend. É exposição pública de dados reais sem auth e falta de permissão no connector Supabase.
- Supabase REST voltou, então o ambiente privado pode usar dados reais. Produção pública fica em demo e somente leitura até auth existir.
- A entrega vendável em 48h é web-first, com iOS/RFID posicionados como próxima etapa técnica.

## Blockers P0

1. Supabase connector sem permissão.
   - Check: connector lista o projeto `bphmxticdyuctovfumcj`.
   - Dono: Marco ou acesso Supabase com permissão no projeto.

2. Secrets Vercel/CI precisam incluir service role.
   - Check: GitHub Actions tem `SUPABASE_SERVICE_ROLE_KEY` real configurada.
   - Dono: Marco com acesso GitHub secrets, ou agente com credencial.

3. Smoke em produção pública precisa passar em modo demo seguro.
   - Check: `/`, `/items`, `/projetos`, `/lotes`, `/qrcodes`, `/rfid`, `/config` retornam 200 e não exibem dados reais.
   - Dono: agente.
   - Status: fechado em `https://mmd-zeta.vercel.app`.

## Dia 1

1. Fechar runtime web.
   - Check: `next build` mostra `/`, `/items`, `/projetos`, `/lotes`, `/qrcodes`, `/rfid` como dinâmicas.

2. Resolver backend.
   - Check: Supabase REST com anon key retorna dados reais.
   - Check: Supabase connector ou dashboard confirma projeto ativo.

3. Preparar deploy.
   - Check: `.env.local.example` documenta todas as envs.
   - Check: CI injeta `SUPABASE_SERVICE_ROLE_KEY`.
   - Check: Vercel Preview sobe.
   - Status: produção pública subiu em `https://mmd-zeta.vercel.app` com dados demo e somente leitura.

4. Handoff mínimo.
   - Check: `docs/handoff.md` existe com URL, escopo, como testar e pendências.
   - Check: `docs/guia-marcelo.md` existe com fluxo de demo.

## Dia 2

1. Smoke público seguro e smoke privado real.
   - Check: produção pública carrega dados demo e somente leitura.
   - Check: ambiente privado carrega dados reais.
   - Check: detalhe de item abre.
   - Check: projetos carrega e detalhe abre.
   - Check: QR PDF gera e baixa.
   - Check: checkout/check-in real só é validado em ambiente privado com `MMD_READONLY=false`.
   - Status: smoke público seguro fechado. Smoke privado real validado localmente.

2. Demo script.
   - Check: roteiro de 10 minutos pronto para Marcelo.
   - Check: frase honesta de RFID/iOS pronta.

3. Fechamento.
   - Check: build verde.
   - Check: lint verde.
   - Check: typecheck verde.
   - Check: evidências salvas no relatório final.

## Delegação

- Web: auditou build, runtime, rotas e UX de falha.
- Supabase/dados: auditou DNS, connector, migrations, seed e RLS.
- iOS: auditou build, mock RFID, QR, signing e RFD40.
- Entrega/handoff: auditou promessa comercial, demo e documentos faltantes.

## Critério de Pronto

A versão está pronta quando:

- Ambiente privado abre com backend real.
- Produção pública, enquanto sem auth, abre em dados demo e somente leitura.
- Rotas principais passam no Browser sem 404.
- QR PDF gera arquivo válido.
- O demo script não promete iOS/RFD40 real sem teste em aparelho.
- O handoff diz exatamente o que está entregue e o que ficou para a próxima etapa.
