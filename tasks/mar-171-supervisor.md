# MAR-171 Supervisor

Data de abertura: 2026-06-23

PRD pai: https://linear.app/marco-os/issue/MAR-171/prd-mvp-operacional-real-do-mmd-estoque

## Estado atual

OBSERVADO:

- MAR-171 está em `In Progress` no Linear.
- Existem 17 issues filhas no Linear, de MAR-172 a MAR-188.
- O repo está com worktree sujo antes desta supervisão, com muitas alterações e deleções preexistentes.
- `tasks/todo.md` aparece como deletado no estado do Git. Este arquivo foi criado separado para não sobrescrever esse estado.

INFERIDO:

- O trabalho não pode ser tratado como implementação pronta. O que existe agora é a estrutura de execução e o controle supervisor.
- A primeira onda deve começar por auth e QR público porque produção real com dados reais depende desses gates.

## Ondas

| Onda | Linear | Objetivo | Gate de saída |
| --- | --- | --- | --- |
| 1 | MAR-172, MAR-173 | Base pública segura | Auth real protege área interna, QR público não vaza dado sensível |
| 2 | MAR-174, MAR-175 | Entrada do Evento | Ficha persistida cria Evento operacional, orçamento/contrato ficam leves no web |
| 3 | MAR-176, MAR-177, MAR-178 | Packing | Manual, planilha padrão e sugestão revisável usando catálogo real |
| 4 | MAR-179, MAR-180, MAR-181, MAR-182 | Alocação e saída | Unidades próprias, aluguel avulso, prontidão e check-out com auditoria |
| 5 | MAR-183, MAR-185, MAR-188 | Mobile de campo | iOS usa regra única do web, RFD40 só aprovado com hardware real |
| 6 | MAR-184, MAR-186, MAR-187 | Retorno, dashboard e unit-only | Pendente de resolução, dashboard real e remoção HITL de lotes |

## Gates globais

- Todo slice precisa anexar evidência no Linear antes de sair de `In Progress`.
- Toda UI ou tela alterada precisa seguir: referência glass existente, imagegen, implementação, screenshot final, comparação anexada ao Linear.
- Nenhum agente pode reconstruir produto paralelo. A regra é adaptar web, iOS e Supabase existentes.
- QR público não pode expor valor, serial de fábrica, RFID, localização ou histórico.
- Mobile não pode manter regra operacional paralela ao web.
- Lotes legados e cabos unit-only são decisão fechada. Delete físico de lotes é HITL.
- RFD40 só conta como pronto com iPhone físico, signing, pareamento e tags reais.

## Evidência local já observada

| Tema | Evidência | Leitura |
| --- | --- | --- |
| Auth parcial | `supabase/migrations/00003_auth_profiles.sql` | Existe tabela `profiles`, trigger de signup e roles técnicos `viewer/editor/admin` |
| Auth incompleto | `apps/web/src/lib/actions/movimentacoes.ts` | Operador ainda hardcoded como `Marco` |
| Auth incompleto | `apps/web/src/lib/supabase-server.ts` | Server usa service role admin, sem boundary de sessão do usuário nas rotas lidas |
| Auth incompleto | `supabase/migrations/00004_inline_edit_policies.sql` | Ainda há política temporária para `anon` em escrita de itens/seriais |
| QR público inseguro | `apps/web/src/app/s/[codigo]/page.tsx` | Busca por `codigo_interno`, `qr_code` ou `tag_rfid` e renderiza valor, serial, desgaste e localização |
| QR source ainda mistura lote | `apps/web/src/lib/data/qrcodes.ts` | Geração ainda inclui `lotes` não cabo, apesar de unit-only ser direção final |
| Design gate possível | `apps/web/public/handoff/styles/glass.css` | Tokens e CSS glass ainda existem no filesystem |
| Design gate com risco | `design_handoff_estoque_mmd/screenshots/*.png` | Screenshots principais aparecem deletados no worktree, mas existem no índice Git e podem ser recuperados por `git show HEAD:path` para referência |

## Onda 1, pré-auditoria

### MAR-172, Auth real e auditoria de operador

Gaps observados:

- Não há rota ou tela de login localizada no scan inicial de `apps/web/src`.
- Não há middleware de proteção de áreas internas localizado no scan inicial.
- Roles do banco ainda estão em vocabulário técnico, não em `Equipe operacional` e `Usuário admin`.
- Escritas operacionais ainda recebem operador por texto fixo.
- Políticas temporárias `anon` precisam ser removidas ou cercadas antes de produção real.
- A migration inicial `supabase/migrations/00001_initial_schema.sql` aparece deletada no worktree, o que torna qualquer reset completo do banco instável até esse estado ser resolvido.
- RPCs operacionais aceitam `p_registrado_por text`, então um caller pode manipular o operador se a action não validar sessão e role antes.
- RLS parcial em `items` e `serial_numbers` não cobre de forma suficiente `projetos`, `packing_list`, `movimentacoes`, `rfid_readers`, `rfid_scans` e `lotes`.

Verificações exigidas:

- Acesso anônimo negado para áreas internas.
- Usuário autenticado operacional acessa áreas de operação permitidas.
- Usuário admin consegue ações destrutivas permitidas.
- Operador real aparece nas movimentações.
- Escrita `anon` não consegue alterar item ou unidade em modo real.
- Reset ou validação de migrations precisa provar que a cadeia de banco está íntegra, incluindo `00001`.

### MAR-173, QR público seguro + ficha interna autenticada

Gaps observados:

- A página pública renderiza dados proibidos pelo PRD: valor atual, serial de fábrica, desgaste e localização.
- Lookup público aceita `tag_rfid`, o que expõe identificador interno como entrada pública.
- Rota pública ainda identifica lotes.
- Falta separar presenter público mínimo de ficha interna autenticada.
- O layout global renderiza navegação interna também em `/s/[codigo]`, expondo links internos na página pública.
- QR público usa código interno previsível em `/s/{codigo}` e ainda não tem token público opaco, escopo separado ou revogação.
- `/api/qr-sheet` aceita payload arbitrário sem auth no scan inicial, então a geração de PDF também precisa entrar no hardening de área interna.
- O filtro PostgREST é montado com `.or()` por string usando input da URL, o que precisa ser substituído por lookup mais controlado.

Verificações exigidas:

- HTML público não contém valor monetário, serial, RFID, localização nem histórico.
- QR público mostra identificação mínima, status público e contato MMD.
- Ficha interna exige auth e pode exibir dados completos.
- Teste cobre explicitamente ausência de campos sensíveis.
- Página pública não renderiza `SideRail`, TopBar interna ou links de área autenticada.
- API de QR sheet exige sessão antes de gerar PDF.

## Gate visual para próximas UI

Referências atuais:

- Tokens glass: `apps/web/public/handoff/tokens/mmd-tokens.css`
- Primitives glass: `apps/web/public/handoff/components/primitives.jsx`
- CSS glass: `apps/web/public/handoff/styles/glass.css`
- Brief atual: `docs/handoff.md`
- Brief histórico: `docs/design-brief.md`

Referências recuperáveis por histórico Git:

- `design_handoff_estoque_mmd/galeria-explorativa.html`
- `design_handoff_estoque_mmd/screenshots/02-dashboard.png`
- `design_handoff_estoque_mmd/screenshots/03-projetos-packing.png`
- `design_handoff_estoque_mmd/screenshots/04-item-detalhe.png`
- `design_handoff_estoque_mmd/screenshots/05-qr-print-sheet.png`
- `design_handoff_estoque_mmd/screenshots/07-rfid-scan.png`
- `design_handoff_estoque_mmd/screenshots/08-checkout.png`

Procedimento obrigatório:

1. Localizar referência glass no filesystem ou recuperar imagem rastreada via histórico Git.
2. Registrar caminho da referência na issue Linear.
3. Usar imagegen para gerar uma variação raster guiada por essa referência.
4. Implementar em cima da imagem gerada, respeitando tokens existentes.
5. Rodar screenshot em desktop e mobile.
6. Anexar ao Linear: referência original, prompt imagegen, imagem gerada, screenshot final e comparação.

## Próximas ações

- Integrar auditorias paralelas dos agentes de Auth, QR e gate visual.
- Atualizar MAR-172 e MAR-173 com comentário de kickoff da Onda 1.
- Publicar status update no projeto MMD do Linear com progresso e riscos.
- Só iniciar código da Onda 1 depois de confirmar o escopo mínimo de Auth e QR contra as auditorias.

## Importação oficial Event Pro

Data: 2026-06-23

Arquivos tocados:

- `supabase/migrations/20260623193758_event_pro_import_official.sql`
- `apps/web/src/lib/event-pro-import-core.ts`
- `apps/web/src/lib/event-pro-import-core.test.ts`
- `apps/web/scripts/import-event-pro-events.ts`
- `apps/web/src/lib/checkout-gate-core.ts`
- `apps/web/src/lib/checkout-gate-core.test.ts`
- status `MONTAGEM` em tipos web, telas de Evento e modelos iOS
- `docs/adr/0004-event-pro-official-import.md`
- `docs/mar-171-agent-brief.md`
- `docs/handoff.md`

Comportamento entregue:

- Status `MONTAGEM` adicionado entre `CONFIRMADO` e `EM_CAMPO`.
- Check-out liberado para evento `CONFIRMADO` ou `MONTAGEM`.
- Tabelas oficiais de importação criadas: lotes, arquivos, candidatos de catálogo e pendências.
- Bucket privado `mmd-event-pro-imports` criado para preservar XLSX original.
- Importador Event Pro com dry-run e aplicação oficial.
- Hash do arquivo impede duplicidade.
- Evento cancelado entra como `CANCELADO`, sem packing e com pendência administrativa.
- Financeiro não entra no sistema neste corte.

Evidência:

- `npm exec tsc -- --noEmit`: passou.
- `npm run lint -- --max-warnings=0`: passou.
- `node --test --experimental-strip-types src/lib/event-pro-import-core.test.ts src/lib/checkout-gate-core.test.ts`: 13 testes passaram.
- `supabase db reset --local --no-seed`: passou.
- `supabase db lint --local`: passou sem erro.
- `supabase db advisors --local`: passou sem achados.
- `supabase db push --linked --yes`: aplicou `20260623193758_event_pro_import_official.sql` no remoto.
- Dry-run final: 11 arquivos, 16 eventos, 65 pendências pré-match.
- Aplicação oficial: lote `902ce07f-32dd-41b9-9ad3-6d1b5886853c`, 11 arquivos, 16 eventos, 1 cancelado, 7 linhas de packing, 89 candidatos únicos e 313 pendências.
- Verificação remota: 11 hashes únicos e 11 originais em Storage.

## MAR-173, corte seguro aplicado

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/app/layout.tsx`
- `apps/web/src/components/mmd/AppShell.tsx`
- `apps/web/src/app/s/[codigo]/page.tsx`
- `apps/web/src/lib/public-qr.ts`
- `apps/web/src/lib/public-qr.test.ts`
- `apps/web/tsconfig.json`
- `tasks/evidence/mar-173/public-qr-safe-imagegen.png`
- `tasks/evidence/mar-173/public-qr-desktop.png`
- `tasks/evidence/mar-173/public-qr-mobile.png`

Comportamento entregue:

- `/s/[codigo]` usa shell público sem `SideRail`.
- HTML público não renderiza valor atual, serial de fábrica, RFID, tag RFID, localização, desgaste, estado interno, histórico ou links internos.
- Lookup público não aceita mais `tag_rfid` como chave.
- Input público com caracteres de filtro PostgREST, como vírgula e parênteses, retorna `404` em vez de montar `.or()` por string.
- Status interno é reduzido para status público: `Ativo`, `Em uso`, `Indisponível` ou `Falar com MMD`.
- Contato público fica via env `NEXT_PUBLIC_MMD_WHATSAPP_URL` e `NEXT_PUBLIC_MMD_PHONE`. Sem env, a tela mostra pendência explícita sem inventar telefone.

Validações executadas:

- `node --test --experimental-strip-types src/lib/public-qr.test.ts`: 4 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint -- --max-warnings=0`: passou.
- `npm run build`: passou.
- `curl http://localhost:3010/s/MMD-ILU-0001`: `200 text/html`.
- `curl http://localhost:3010/s/MMD-ILU-0001,tag_rfid.eq.SECRET`: `404 text/html`.
- `rg` no HTML público por termos proibidos não retornou matches.
- Playwright desktop e mobile capturaram screenshots salvos em `tasks/evidence/mar-173/`.

Risco residual:

- MAR-173 ainda não está completo. Falta ficha interna autenticada, proteger `/qrcodes` e `/api/qr-sheet`, e configurar telefone/WhatsApp real.
- MAR-172 continua bloqueando fechamento de produção real, porque auth/sessão/role/auditoria ainda não foram implementados.
- Playwright em dev registrou `favicon.ico` 404. Esse arquivo já aparece deletado no worktree e não faz parte deste corte.

## MAR-172, corte de auth aplicado

Data: 2026-06-23

Arquivos tocados:

- `apps/web/package.json`
- `apps/web/package-lock.json`
- `apps/web/src/lib/auth-config.ts`
- `apps/web/src/lib/auth-config.test.ts`
- `apps/web/src/lib/supabase-ssr.ts`
- `apps/web/src/lib/auth-actions.ts`
- `apps/web/src/app/login/page.tsx`
- `apps/web/src/proxy.ts`
- `apps/web/src/components/mmd/AppShell.tsx`
- `apps/web/src/app/api/qr-sheet/route.ts`
- `tasks/evidence/mar-172/login-imagegen.png`
- `tasks/evidence/mar-172/login-desktop.png`
- `tasks/evidence/mar-172/login-mobile.png`

Comportamento entregue:

- Auth SSR com `@supabase/ssr`, cookies do Next 16 e verificação por `supabase.auth.getUser()`.
- `proxy.ts` protege `/`, `/items`, `/lotes`, `/projetos`, `/qrcodes`, `/rfid`, `/config` e `/ficha-evento` quando auth está obrigatório.
- `/login` fica público, com tela glass gerada a partir de referência imagegen e sem navegação interna.
- `/s/[codigo]` continua público para QR seguro.
- `next` do login é sanitizado para evitar redirect externo, loop para `/login` ou envio para `/s/...`.
- `/api/qr-sheet` retorna `401` sem sessão quando auth está obrigatório, antes de gerar PDF.
- Falha de config Supabase na verificação de usuário cai como usuário não verificado, em vez de derrubar rota protegida com erro 500.

Validações executadas:

- `node --test --experimental-strip-types src/lib/auth-config.test.ts src/lib/public-qr.test.ts`: 9 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint -- --max-warnings=0`: passou.
- `npm run build`: passou, incluindo `ƒ Proxy (Middleware)`.
- Build de produção local em `http://localhost:3012` com `MMD_REQUIRE_AUTH=true`.
- `GET /items` sem sessão: `307` para `/login?next=%2Fitems`.
- `GET /s/MMD-ILU-0001` sem sessão: `200`.
- `POST /api/qr-sheet` sem sessão: `401 {"error":"unauthorized"}`.
- `GET /login?next=/items`: `200`, contém login, email e senha, não contém navegação interna.
- Playwright desktop e mobile capturaram screenshots salvos em `tasks/evidence/mar-172/`, sem erros de console.

Risco residual:

- MAR-172 ainda não está completo. Falta trocar operador hardcoded por usuário real nas movimentações.
- Falta alinhar roles do produto: `Equipe operacional` e `Usuário admin`.
- Falta remover ou cercar políticas `anon` temporárias no Supabase antes de produção real.
- Falta validar migrations do banco, porque a `00001_initial_schema.sql` aparece deletada no worktree.
- `npm install` reportou 5 vulnerabilidades de audit. Não rodei `npm audit fix` para não mudar dependências fora do escopo.

## MAR-172, corte de actions autenticadas aplicado

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/action-auth-core.ts`
- `apps/web/src/lib/action-auth-core.test.ts`
- `apps/web/src/lib/action-auth.ts`
- `apps/web/src/lib/actions/movimentacoes.ts`
- `apps/web/src/lib/actions/projetos.ts`
- `apps/web/src/lib/actions/rfid.ts`
- `supabase/migrations/00007_loop_operacional.sql`

Comportamento entregue:

- Server actions internas passam por `requireActionUser` quando auth está obrigatório.
- Modo local/demo continua usando fallback seguro para não quebrar desenvolvimento.
- Escritas de projeto, packing, alocação, RFID e check-in/check-out exigem pelo menos `editor`.
- `deleteProjeto` exige `admin`.
- Leituras sensíveis via server action, como busca de itens, seriais disponíveis e cabos para vínculo RFID, exigem usuário autenticado quando auth está obrigatório.
- Check-in e check-out enviam `registradoPor` a partir do profile Supabase do usuário verificado, não mais texto hardcoded.
- Mensagens de role usam linguagem de produto: `equipe operacional` e `usuário admin`.

Validações executadas:

- `node --test --experimental-strip-types src/lib/action-auth-core.test.ts src/lib/auth-config.test.ts src/lib/public-qr.test.ts`: 13 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint -- --max-warnings=0`: passou.
- `npm run build`: passou.
- Smoke de produção local em `http://localhost:3013` com `MMD_REQUIRE_AUTH=true`.

- `GET /projetos` sem sessão: `307` para `/login?next=%2Fprojetos`.
- `GET /s/MMD-ILU-0001` sem sessão: `200`.
- `POST /api/qr-sheet` sem sessão: `401 {"error":"unauthorized"}`.
- `GET /login?next=/projetos`: `200`, contém login e não contém navegação interna.
- Scan em actions confirmou `p_registrado_por: auth.data.registradoPor`.
- Scan em actions e migration operacional não encontrou mais `Marco`, `REGISTRADO_POR`, `hard-coded` ou `auth.user.email`.

Risco residual:

- MAR-172 ainda não está completo. Falta migration/RLS para remover ou cercar políticas `anon`.
- Falta validar contra um usuário real logado no Supabase, com profile `editor` e `admin`.
- Falta alinhar o banco ao vocabulário final de produto, porque a enum atual ainda usa `viewer`, `editor` e `admin`.
- Falta validar a cadeia de migrations, porque `00001_initial_schema.sql` aparece deletada no worktree.
- As RPCs `checkout_projeto` e `checkin_projeto` ainda aceitam `p_registrado_por text`; o web já controla isso, mas o banco ainda não deriva operador por `auth.uid()`.

## MAR-172, corte de RLS/auth aplicado

Data: 2026-06-23

Arquivos tocados:

- `supabase/migrations/20260623050458_harden_auth_rls.sql`

Comportamento entregue:

- Migration criada via `supabase migration new harden_auth_rls`.
- RLS é habilitado explicitamente nas tabelas internas: `items`, `serial_numbers`, `projetos`, `packing_list`, `movimentacoes`, `lotes`, `profiles`, `rfid_readers` e `rfid_scans`.
- `anon` perde privilégios nessas tabelas internas.
- Grants para `authenticated` ficam explícitos para Data API, com RLS decidindo a permissão real.
- Policies temporárias `catalog_update_qtd` e `serials_update_desgaste` são removidas.
- Policies amplas antigas, como `authenticated_all_*` e `rfid_*_read_all`, são removidas e recriadas com `TO authenticated`.
- `current_user_role()` fica com `search_path` travado, execute restrito e leitura de profile por usuário verificado.
- `handle_new_user()` deixa de ser executável por `PUBLIC`, `anon` ou `authenticated`.
- `set_updated_at()`, `item_categoria_prefix()` e `generate_item_codigo_interno()` recebem `search_path` fixo para zerar alerta do Supabase Advisor.
- RPCs `checkout_projeto` e `checkin_projeto` deixam de ser executáveis por `authenticated`, ficando chamadas pelo web via `service_role`. Isso remove spoofing direto de `p_registrado_por` pela Data API.

Validações executadas:

- `supabase --version`: CLI `2.84.2`.
- `supabase migration new --help`, `supabase migration list --help` e `supabase db --help`: comandos conferidos antes do uso.
- Check estático da migration: 36 policies criadas, 0 sem `TO authenticated` e 0 hits proibidos.
- `colima start`: Docker local ficou disponível.
- `supabase start` no repo real: falhou em `00002` porque `00001_initial_schema.sql` está deletada no worktree. Esse resultado confirma o blocker da cadeia real.
- Cópia temporária em `/tmp/mmd-supabase-validate` criada com `00001_initial_schema.sql` recuperada de `HEAD` só para validação, sem restaurar a deleção no worktree.
- `supabase db start` na cópia temporária: aplicou `00001`, `00002`, `00003`, `00004`, `00005`, `00006`, `00007` e `20260623050458_harden_auth_rls.sql`.
- `supabase db reset --local` na cópia temporária: passou após ajuste de `search_path`.
- `supabase db lint --local` na cópia temporária: sem schema errors.
- `supabase db advisors --local` na cópia temporária: no issues found.
- `supabase migration list --local` na cópia temporária: listou `00001` a `00007` e `20260623050458`.
- Query de grants/RLS: as 9 tabelas internas ficaram com RLS ativo, `anon_select/insert/update/delete=false` e `authenticated_select=true`.
- Query de policies: 36 policies finais, 36 com role `{authenticated}`.
- Query de funções: `checkin_projeto` e `checkout_projeto` com `anon_execute=false`, `authenticated_execute=false` e `service_role_execute=true`.
- Query de funções: `current_user_role` com `authenticated_execute=true`; `handle_new_user` com `authenticated_execute=false`.
- Simulação local de profiles: `current_user_role()` resolveu `viewer`, `editor` e `admin` corretamente a partir de `request.jwt.claim.sub`.
- Simulação local de RLS: `viewer` foi bloqueado ao criar Evento, `editor` criou Evento e `admin` deletou o Evento.
- `node --test --experimental-strip-types src/lib/action-auth-core.test.ts src/lib/auth-config.test.ts src/lib/public-qr.test.ts`: 13 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint -- --max-warnings=0`: passou.
- `npm run build`: passou.
- Smoke de produção local em `http://localhost:3014` com `MMD_REQUIRE_AUTH=true`.
- `GET /rfid` sem sessão: `307` para `/login?next=%2Frfid`.
- `GET /s/MMD-ILU-0001` sem sessão: `200`.
- `POST /api/qr-sheet` sem sessão: `401 {"error":"unauthorized"}`.
- `GET /login?next=/rfid`: `200`, contém login e não contém navegação interna.

Validações não executadas:

- A migration ainda não foi aplicada no banco real Supabase.
- Login real pelo app com usuários Supabase `editor` e `admin` ainda não foi executado.

Risco residual:

- MAR-172 ainda não está completo até aplicar a migration no banco real e testar login real com usuários `editor` e `admin`.
- A cadeia de migrations segue instável enquanto `supabase/migrations/00001_initial_schema.sql` aparecer deletada no worktree.
- O banco ainda usa roles técnicas `viewer`, `editor` e `admin`; falta mapear oficialmente para `Equipe operacional` e `Usuário admin` no produto.

## MAR-173, ficha interna autenticada aplicada

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/internal-qr-core.ts`
- `apps/web/src/lib/internal-qr-core.test.ts`
- `apps/web/src/lib/data/internal-qr.ts`
- `apps/web/src/app/qrcodes/[codigo]/page.tsx`
- `apps/web/src/components/qrcodes/QrCodesClient.tsx`
- `tasks/evidence/mar-173/glass-reference-item-detail.png`
- `tasks/evidence/mar-173/glass-reference-qr-sheet.png`
- `tasks/evidence/mar-173/internal-qr-ficha-imagegen.png`
- `tasks/evidence/mar-173/internal-qr-desktop.png`
- `tasks/evidence/mar-173/internal-qr-mobile.png`

Comportamento entregue:

- `/qrcodes/[codigo]` resolve QR ou código interno para ficha interna de unidade.
- A ficha interna mostra dados completos: serial de fábrica, tag RFID, QR interno, localização, desgaste, valor atual, observação e sinal recente.
- A rota interna reaproveita o catálogo como destino completo, via botão `Abrir item no catálogo`, em vez de criar módulo paralelo.
- A listagem `/qrcodes` ganhou ação `Ficha` por unidade ou lote legado, mantendo seleção de PDF separada.
- Lookup interno usa apenas `codigo_interno` e `qr_code`. `tag_rfid` aparece como dado sensível autenticado, não como chave pública de URL.
- Lote legado segue compatível em `/qrcodes/[codigo]`, com aviso de que cabos novos entram como unidades físicas.
- Gate visual executado: referências glass recuperadas do histórico Git, variação raster gerada com imagegen e screenshots finais salvos.

Validações executadas:

- `node --test --experimental-strip-types src/lib/internal-qr-core.test.ts src/lib/action-auth-core.test.ts src/lib/auth-config.test.ts src/lib/public-qr.test.ts`: 16 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint -- --max-warnings=0`: passou.
- `npm run build`: passou e listou `/qrcodes/[codigo]` como rota dinâmica.
- Smoke local com `MMD_REQUIRE_AUTH=false MMD_DATA_MODE=demo`: `/qrcodes/MMD-ILU-0001`, `/qrcodes` e `/s/MMD-ILU-0001` responderam `200`.
- Conteúdo interno contém `Serial fábrica`, `Tag RFID`, `Valor atual`, `Localização`, `SN-` e `E280-MMD`.
- Conteúdo público não contém os termos sensíveis acima.
- Smoke local com `MMD_REQUIRE_AUTH=true MMD_DATA_MODE=demo`: `/qrcodes/MMD-ILU-0001` redirecionou `307` para `/login?next=%2Fqrcodes%2FMMD-ILU-0001`.
- No mesmo smoke com auth obrigatório: `/qrcodes` redirecionou `307`, `/s/MMD-ILU-0001` respondeu `200`, `/api/qr-sheet` respondeu `401`.
- Playwright desktop e mobile capturaram screenshots finais em dark mode, sem erros de console.

Risco residual:

- Acesso permitido com login real ainda depende de usuário Supabase real no ambiente MMD. Foi provado o bloqueio sem sessão e a renderização funcional em modo demo.
- Telefone/WhatsApp público segue dependente de env real.
- A migration inicial `00001_initial_schema.sql` continua deletada no worktree preexistente, então validação completa no Supabase real segue pendente de decisão.

## MAR-174, ficha de evento persistida aplicada

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/evento-ficha-core.ts`
- `apps/web/src/lib/evento-ficha-core.test.ts`
- `apps/web/src/lib/actions/projetos.ts`
- `apps/web/src/lib/data/evento-resumo.ts`
- `apps/web/src/app/api/eventos/[id]/resumo/route.ts`
- `apps/web/src/app/ficha-evento/page.tsx`
- `supabase/migrations/20260623054800_evento_ficha_operacional.sql`
- `tasks/evidence/mar-174/ficha-evento-imagegen.png`
- `tasks/evidence/mar-174/ficha-evento-desktop-forced-dark.png`
- `tasks/evidence/mar-174/ficha-evento-mobile-forced-dark.png`

Comportamento entregue:

- `/ficha-evento` deixa de ser ficha isolada só em `localStorage` e passa a ter CTA principal `Salvar Evento`.
- A action `saveEventoFicha` cria ou atualiza registro em `projetos`, com os campos operacionais básicos usados pelo fluxo existente.
- A ficha completa persiste em `projetos.ficha_evento` quando a migration está aplicada.
- Se o banco ainda estiver sem a coluna `ficha_evento`, a action usa fallback e grava o resumo completo em `notas`, mantendo criação do Evento funcional.
- A ficha mantém rascunho local apenas como conveniência de preenchimento, não como fonte de verdade.
- A tela usa o shell interno com `SideRail`, `TopBar`, cards glass, resumo lateral, prontidão da ficha e links para lista/detalhe de Eventos.
- Caminho mobile/API criado em `/api/eventos/[id]/resumo`, lendo o mesmo Evento do web e calculando packing/readiness.
- Gate visual executado: referência glass usada, mock raster criado com imagegen e screenshots finais desktop/mobile salvos.

Validações executadas:

- `node --test --experimental-strip-types src/lib/evento-ficha-core.test.ts src/lib/internal-qr-core.test.ts src/lib/action-auth-core.test.ts src/lib/auth-config.test.ts src/lib/public-qr.test.ts`: 19 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint -- --max-warnings=0`: passou.
- `npm run build`: passou e listou `/api/eventos/[id]/resumo` e `/ficha-evento`.
- Smoke local com `MMD_REQUIRE_AUTH=false MMD_DATA_MODE=demo`: `/ficha-evento` renderizou sem erro de console em desktop e mobile.
- Smoke visual desktop/mobile: CTA `Salvar Evento` visível, texto `Ficha do evento` visível e sem overflow horizontal.
- Smoke API demo: `/api/eventos/demo-proj-casamento/resumo` respondeu `200` com `Casamento Santos & Oliveira` e readiness `8`.
- Smoke com `MMD_REQUIRE_AUTH=true MMD_DATA_MODE=demo`: `/ficha-evento` redirecionou `307` para `/login?next=%2Fficha-evento`.
- Smoke com auth obrigatório: `/api/eventos/demo-proj-casamento/resumo` respondeu `401` sem sessão.

Risco residual:

- MAR-174 segue bloqueada para Done por MAR-172 até validar usuário real e Supabase real.
- A migration `20260623054800_evento_ficha_operacional.sql` ainda não foi aplicada no banco real.
- A cadeia real de migrations continua bloqueada enquanto `supabase/migrations/00001_initial_schema.sql` estiver deletada no worktree.

## MAR-175, orçamento e contrato leves aplicados

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/evento-comercial-core.ts`
- `apps/web/src/lib/evento-comercial-core.test.ts`
- `apps/web/src/lib/actions/projetos.ts`
- `apps/web/src/lib/data/project-detail.ts`
- `apps/web/src/lib/data/demo.ts`
- `apps/web/src/components/projects/detail/ProjectDetailClient.tsx`
- `apps/web/src/components/projects/detail/CommercialTab.tsx`
- `supabase/migrations/20260623060800_evento_comercial_leve.sql`
- `tasks/evidence/mar-175/comercial-evento-imagegen.png`
- `tasks/evidence/mar-175/comercial-evento-desktop.png`
- `tasks/evidence/mar-175/comercial-evento-mobile.png`

Comportamento entregue:

- Detalhe do Evento ganhou tab `Comercial`.
- Evento passa a ter registro comercial leve em `projetos.comercial`.
- Status suportados: `Orçamento enviado`, `Orçamento aprovado`, `Contrato enviado` e `Contrato assinado`.
- `Orçamento aprovado` libera preparação operacional de estoque no contrato da UI e no core.
- Usuário pode salvar links de orçamento/contrato e anexar arquivos comerciais.
- Anexos usam bucket privado `mmd-evento-comercial`, com limite de 10 MB e tipos PDF, DOC, DOCX, PNG e JPG.
- Loader do detalhe cria links assinados de 30 minutos para anexos de Storage quando disponíveis.
- Não foi criado módulo financeiro, cobrança, geração automática de orçamento ou contrato jurídico.
- Gate visual executado: referência MAR-174 usada, mock raster criado com imagegen e screenshots finais desktop/mobile salvos.

Validações executadas:

- `node --test --experimental-strip-types src/lib/evento-comercial-core.test.ts src/lib/evento-ficha-core.test.ts src/lib/internal-qr-core.test.ts src/lib/action-auth-core.test.ts src/lib/auth-config.test.ts src/lib/public-qr.test.ts`: 25 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint -- --max-warnings=0`: passou.
- `npm run build`: passou e manteve `/projetos/[id]`.
- QA browser local com `MMD_REQUIRE_AUTH=false MMD_DATA_MODE=demo`: `/projetos/demo-proj-casamento` abriu, tab `Comercial` renderizou e CTA `Salvar comercial` ficou visível.
- QA browser desktop/mobile: `Selecionar arquivo` aparece em português, `Choose File` não aparece, sem overflow horizontal e sem erros de console.
- Screenshots salvos em `tasks/evidence/mar-175/`.
- Anexados no Linear MAR-175 o mock imagegen e o screenshot final.

Risco residual:

- MAR-175 segue bloqueada para Done por MAR-174, que por sua vez depende de MAR-172.
- A migration `20260623060800_evento_comercial_leve.sql` ainda não foi aplicada no banco real.
- Upload real em Supabase Storage ainda não foi validado contra ambiente real.
- A cadeia real de migrations continua bloqueada enquanto `supabase/migrations/00001_initial_schema.sql` estiver deletada no worktree.

## MAR-176, packing manual no detalhe do Evento aplicado

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/components/projects/detail/PackingTab.tsx`
- `apps/web/src/components/projects/detail/ProjectDetailClient.tsx`
- `apps/web/src/components/projects/InlineItemPicker.tsx`
- `apps/web/src/app/projetos/page.tsx`
- `apps/web/src/app/projetos/[id]/page.tsx`
- `apps/web/src/components/mmd/SideRail.tsx`
- `apps/web/src/components/projects/ProjectsClient.tsx`
- `apps/web/src/components/projects/ProjectListView.tsx`
- `apps/web/src/components/projects/InlineNewProjectForm.tsx`
- `apps/web/src/components/projects/ProjectCalendarView.tsx`
- `apps/web/src/components/projects/ConflictModal.tsx`
- `apps/web/src/components/projects/detail/AllocationTab.tsx`
- `apps/web/src/components/projects/detail/SerialPicker.tsx`
- `apps/web/src/components/projects/detail/CheckoutDialog.tsx`
- `apps/web/src/components/projects/detail/CheckinDialog.tsx`
- `tasks/evidence/mar-176/packing-manual-imagegen.png`
- `tasks/evidence/mar-176/packing-evento-desktop.png`
- `tasks/evidence/mar-176/packing-evento-mobile.png`

Comportamento entregue:

- Tab `Packing` da página completa do Evento deixou de ser somente leitura.
- `+ Adicionar item` abre o seletor de catálogo existente dentro do próprio Evento.
- Adicionar item chama `addPackingItem(projeto.id, itemId, qtd)`, mantendo vínculo com o Evento atual.
- Quantidade agora edita inline com `EditableQty` e chama `updatePackingQty`.
- Remover item chama `removePackingItem`.
- Erros de escrita aparecem no alerta já existente do detalhe do Evento.
- Após salvar, a página refresca o detalhe em vez de criar tela ou fluxo paralelo.
- Resumo lateral mostra prontidão do packing, unidades alocadas e próximo passo para Alocação.
- Desktop usa tabela densa; mobile usa cartões por item para não quebrar layout.
- Cópia visível da área mudou de `Projetos` para `Eventos`, mantendo rota interna `/projetos`.
- Gate visual executado: referência MAR-175 usada, mock raster criado com imagegen e screenshots finais desktop/mobile salvos.

Validações executadas:

- `npm run lint`: passou.
- `npm exec tsc -- --noEmit`: passou.
- `npm run build`: passou e manteve `/projetos/[id]`.
- `node --test src/lib/*.test.ts`: 25 testes passaram.
- Scan de caracteres banidos nas telas de Eventos/Packing: sem matches.
- QA browser local em `http://127.0.0.1:3002/projetos/fbc0aab1-106f-454e-84ff-72e9ecbfcd85`: página completa abriu, `Packing do Evento` renderizou, seletor de catálogo abriu dentro da aba, quantidade e remover ficaram acessíveis.
- QA browser desktop e mobile: screenshots salvos em `tasks/evidence/mar-176/`.

Risco residual:

- MAR-176 ainda não deve ir para Done enquanto MAR-174/MAR-172 não fecharem a validação real de Evento e auth.
- Escrita real de add, update e remove no Supabase não foi executada neste corte. O modo demo local bloqueia escrita por design.
- A cadeia real de migrations continua bloqueada enquanto `supabase/migrations/00001_initial_schema.sql` estiver deletada no worktree.

## MAR-177, importação da planilha padrão de packing aplicada

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/packing-import-core.ts`
- `apps/web/src/lib/packing-import-core.test.ts`
- `apps/web/src/lib/packing-import-file.ts`
- `apps/web/src/lib/actions/projetos.ts`
- `apps/web/src/lib/data/project-detail.ts`
- `apps/web/src/lib/data/demo.ts`
- `apps/web/src/components/projects/detail/PackingImportPanel.tsx`
- `apps/web/src/components/projects/detail/PackingTab.tsx`
- `apps/web/package.json`
- `apps/web/package-lock.json`
- `tasks/evidence/mar-177/packing-import-imagegen.png`
- `tasks/evidence/mar-177/packing-import-desktop.png`
- `tasks/evidence/mar-177/packing-import-mobile.png`
- `tasks/evidence/mar-177/packing-import-sample.csv`
- `tasks/evidence/mar-177/packing-import-sample.xlsx`

Comportamento entregue:

- Tab `Packing` do Evento ganhou painel `Importar planilha` dentro da mesma tela de revisão.
- Upload aceita `.xlsx`, `.csv` e `.tsv`, com limite de 10 MB.
- Cabeçalho padrão reconhecido: `codigo_mmd`, `categoria`, `item`, `subcategoria`, `marca`, `modelo`, `quantidade`, `observacao`.
- `codigo_mmd` é o match primário contra `items.codigo_interno`.
- Sem código, o fallback usa categoria + item e refina por subcategoria, marca e modelo.
- Linhas ambíguas ficam em revisão humana, com seletor de candidatos do catálogo.
- Linhas inválidas mostram erro por linha e não entram na aplicação.
- Linhas aprovadas agregam duplicados por item antes de salvar.
- Aplicação soma quantidade em `packing_list` existente ou cria nova linha quando o item ainda não está no Evento.
- Observação da planilha é preservada em `packing_list.notas` e aparece na linha do packing.
- Gate visual executado: mock raster criado com imagegen a partir do packing glass existente, implementação baseada nele e screenshots finais desktop/mobile salvos.

Validações executadas:

- `node --test src/lib/*.test.ts`: 31 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint`: passou.
- `npm run build`: passou e manteve `/projetos/[id]`.
- QA browser local com `MMD_DATA_MODE=demo`: upload de `packing-import-sample.xlsx` abriu preview, exibiu arquivo XLSX, contadores, linha aprovada, linhas com erro e botão `Aplicar ao packing`.
- QA browser desktop/mobile: screenshots salvos em `tasks/evidence/mar-177/`.
- Scan de caracteres banidos nos arquivos tocados de UI/core/tracker: sem matches.
- Supabase docs verificados para `.select`, `.insert` e `.update`; nenhuma migration nova foi criada.

Risco residual:

- Escrita real de `applyPackingImport` no Supabase não foi executada porque o QA rodou em modo demo, que bloqueia writes por design.
- `npm audit --omit=dev` ainda falha: `next@16.2.2` tem alertas altos com correção patch em `16.2.9`, e `exceljs@4.4.0` traz alerta moderado via `uuid`.
- A cadeia real de migrations continua bloqueada enquanto `supabase/migrations/00001_initial_schema.sql` estiver deletada no worktree.

## MAR-178, templates e sugestão revisável de packing aplicada

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/packing-suggestion-core.ts`
- `apps/web/src/lib/packing-suggestion-core.test.ts`
- `apps/web/src/lib/actions/projetos.ts`
- `apps/web/src/components/projects/detail/PackingSuggestionPanel.tsx`
- `apps/web/src/components/projects/detail/PackingTab.tsx`
- `supabase/migrations/20260623073723_packing_templates.sql`
- `tasks/evidence/mar-178/packing-suggestion-imagegen.png`
- `tasks/evidence/mar-178/packing-suggestion-desktop.png`
- `tasks/evidence/mar-178/packing-suggestion-mobile.png`

Comportamento entregue:

- Tab `Packing` do Evento ganhou painel `Templates e sugestão`.
- Usuário vê propostas revisáveis dentro do próprio Evento, sem fluxo paralelo.
- Sugestão usa prioridade: histórico parecido primeiro, template salvo depois.
- Histórico só entra quando há sinal mínimo de semelhança, evitando sugestão fraca por coincidência isolada.
- Proposta pode ser editada antes de aplicar: quantidade por linha e remoção de item.
- Aplicação da proposta reutiliza a mesma regra de soma do `packing_list` já usada pela importação de planilha.
- Usuário pode salvar o packing atual como template reutilizável.
- Migration nova cria `packing_templates` com RLS, grants explícitos para Data API, policies por role e linhas em JSON validado como array.
- IA não decide sozinha. O core aceita fonte `ia_rascunho`, mas o MVP local não chama IA automática.
- Gate visual executado: referência MAR-176 usada, mock raster criado com imagegen e screenshots finais desktop/mobile salvos.

Validações executadas:

- `node --test src/lib/packing-suggestion-core.test.ts`: 6 testes passaram.
- `node --test src/lib/*.test.ts`: 37 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint`: passou.
- `npm run build`: passou e manteve `/projetos/[id]`.
- QA browser local com `MMD_DATA_MODE=demo`: painel abriu, histórico apareceu antes de template, proposta ficou editável, botão `Aplicar proposta` ficou visível e formulário `Salvar template` renderizou.
- QA browser desktop/mobile: screenshots salvos em `tasks/evidence/mar-178/`, sem overflow horizontal.
- Scan de caracteres banidos nos arquivos tocados de UI/core/tracker/migration: sem matches.
- Checagem estática da migration confirmou `CREATE TABLE`, RLS, grants para `authenticated` e policies usando `current_user_role()`.

Risco residual:

- MAR-178 ainda não deve ir para Done enquanto MAR-176/MAR-174/MAR-172 não fecharem a validação real de Evento, auth e Supabase.
- Escrita real de salvar template e aplicar proposta no Supabase não foi executada. O modo demo local bloqueia writes por design.
- A migration `20260623073723_packing_templates.sql` ainda não foi aplicada no banco real.
- A cadeia real de migrations continua bloqueada enquanto `supabase/migrations/00001_initial_schema.sql` estiver deletada no worktree.
- QA desktop registrou 404 de recurso no console, compatível com o `favicon.ico` que já aparece deletado no worktree.

## MAR-179, alocação por unidade com conflitos por data aplicada

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/allocation-core.ts`
- `apps/web/src/lib/allocation-core.test.ts`
- `apps/web/src/lib/data/serials.ts`
- `apps/web/src/lib/actions/projetos.ts`
- `apps/web/src/components/projects/detail/AllocationTab.tsx`
- `apps/web/src/components/projects/detail/SerialPicker.tsx`
- `tasks/evidence/mar-179/glass-reference-disponibilidade.png`
- `tasks/evidence/mar-179/glass-reference-conflito.png`
- `tasks/evidence/mar-179/allocation-date-conflicts-imagegen.png`
- `tasks/evidence/mar-179/allocation-date-conflicts-desktop.png`
- `tasks/evidence/mar-179/allocation-date-conflicts-mobile.png`

Comportamento entregue:

- Aba `Alocação` ganhou faixa com janela do Evento e regra de conflito.
- Conflito de data alerta a equipe, mas não bloqueia planejamento.
- Texto deixa explícito que falta pode ser resolvida depois com aluguel avulso.
- Picker manual passa a mostrar unidades disponíveis, unidades com conflito e unidades bloqueadas.
- Unidades em manutenção, separadas ou em campo aparecem com alerta e não são clicáveis.
- Autoalocação usa só candidatos selecionáveis e prioriza unidades sem conflito antes de conflito.
- Lista de seriais agora carrega status, label operacional, alerta e tom visual por unidade.
- Modo demo passou a devolver candidatos reais do catálogo demo para QA do picker sem escrita.
- Mobile usa picker inline dentro do card, sem overlay confuso.
- Gate visual executado: referências glass recuperadas do histórico Git, mock raster criado com imagegen e screenshots finais desktop/mobile salvos.

Validações executadas:

- `node --test src/lib/allocation-core.test.ts`: 5 testes passaram.
- `node --test src/lib/*.test.ts`: 42 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint`: passou.
- `npm run build`: passou e manteve `/projetos/[id]`.
- QA browser local com `MMD_DATA_MODE=demo`: aba Alocação abriu, picker manual exibiu conflito, disponível, em campo e manutenção.
- QA browser desktop/mobile: screenshots salvos em `tasks/evidence/mar-179/`, sem overflow horizontal.
- Scan de caracteres banidos nos arquivos tocados de UI/core/tracker: sem matches.

Risco residual:

- MAR-179 ainda não deve ir para Done enquanto MAR-176/MAR-174/MAR-172 não fecharem a validação real de Evento, auth e Supabase.
- Escrita real de `autoAllocate` e `setAllocation` no Supabase não foi executada porque o QA rodou em modo demo, que bloqueia writes por design.
- A cadeia real de migrations continua bloqueada enquanto `supabase/migrations/00001_initial_schema.sql` estiver deletada no worktree.
- QA desktop registrou 404 de recurso no console, compatível com o `favicon.ico` já deletado no worktree.

## MAR-180, aluguel avulso cobre falta sem virar patrimônio aplicado

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/external-rental-core.ts`
- `apps/web/src/lib/external-rental-core.test.ts`
- `apps/web/src/lib/data/project-detail.ts`
- `apps/web/src/lib/data/projects.ts`
- `apps/web/src/lib/data/evento-resumo.ts`
- `apps/web/src/lib/data/demo.ts`
- `apps/web/src/lib/actions/projetos.ts`
- `apps/web/src/lib/types.ts`
- `apps/web/src/components/projects/detail/AllocationTab.tsx`
- `apps/web/src/components/projects/detail/PackingTab.tsx`
- `apps/web/src/components/projects/detail/ProjectDetailClient.tsx`
- `apps/web/src/components/projects/detail/CheckoutDialog.tsx`
- `apps/web/src/components/projects/ProjectListView.tsx`
- `supabase/migrations/20260623081000_external_rental_coverage.sql`
- `tasks/evidence/mar-180/external-rental-imagegen.png`
- `tasks/evidence/mar-180/external-rental-desktop.png`
- `tasks/evidence/mar-180/external-rental-mobile.png`
- `tasks/evidence/mar-180/external-rental-form-desktop.png`

Comportamento entregue:

- Linha de packing ganhou cobertura por aluguel avulso de parceiro.
- Registro avulso guarda parceiro, quantidade e obs mínima.
- Cobertura avulsa conta para readiness do Evento junto com unidades próprias.
- `qtd_alocada` continua representando apenas unidade própria, e `qtd_coberta` representa próprio + avulso.
- Aba `Alocação` mostra unidades próprias separadas de `COBERTURA AVULSA`.
- Chips de aluguel avulso mostram quantidade, parceiro e obs, sem parecer serial próprio.
- Linhas faltantes exibem ação `Registrar aluguel` com campos `Parceiro`, `Qtd` e `Obs mínima`.
- Modo demo ganhou aluguel avulso no `Moving Beam 7R 230W`: 2 próprias + 4 avulso = 6/6 cobertos.
- Lista de Eventos, header do detalhe, Packing e Checkout usam unidades cobertas no readiness.
- Check-out atômico no Supabase foi atualizado para validar `serial_numbers_designados + alugueis_avulsos >= quantidade`.
- Check-out continua transicionando somente seriais próprios para `EM_CAMPO`.
- Migration adiciona `packing_list.alugueis_avulsos` como `jsonb` com default `[]`, constraint de array e comentário explícito de que não cria patrimônio.
- Gate visual executado: referência glass da MAR-179 inspecionada, variação raster criada com imagegen e screenshots finais desktop/mobile salvos.

Validações executadas:

- `node --test src/lib/external-rental-core.test.ts src/lib/allocation-core.test.ts`: 10 testes passaram.
- `node --test src/lib/*.test.ts`: 47 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint`: passou.
- `npm run build`: passou e manteve `/projetos/[id]`.
- QA browser local com `MMD_DATA_MODE=demo`: aba Alocação abriu, `COBERTURA AVULSA` apareceu, `LightPro Eventos` apareceu, `6/6 cobertos` apareceu e chip `4 avulso` ficou separado dos seriais próprios.
- QA browser confirmou formulário de aluguel avulso com campos `Parceiro`, `Quantidade`, `Observação` e botão `Salvar`.
- QA browser desktop/mobile: screenshots salvos em `tasks/evidence/mar-180/`, sem overflow horizontal.
- Console do QA só registrou `favicon.ico` 404, compatível com arquivo já deletado no worktree.
- Scan de caracteres banidos nos arquivos tocados de UI/core/tracker/migration: sem matches.
- Checagem estática da migration confirmou coluna `alugueis_avulsos`, `checkout_projeto`, soma via `jsonb_array_elements` e `GRANT EXECUTE`.

Risco residual:

- MAR-180 ainda não deve ir para Done enquanto MAR-176/MAR-174/MAR-172 não fecharem a validação real de Evento, auth e Supabase.
- Escrita real de `addExternalRentalCoverage` e `removeExternalRentalCoverage` no Supabase não foi executada porque o QA rodou em modo demo, que bloqueia writes por design.
- A migration `20260623081000_external_rental_coverage.sql` ainda não foi aplicada no banco real.
- A cadeia real de migrations continua bloqueada enquanto `supabase/migrations/00001_initial_schema.sql` estiver deletada no worktree.
- QA desktop registrou 404 de recurso no console, compatível com o `favicon.ico` já deletado no worktree.

## MAR-181, checklist de saída e prontidão real aplicado

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/checkout-gate-core.ts`
- `apps/web/src/lib/checkout-gate-core.test.ts`
- `apps/web/src/lib/evento-ficha-core.ts`
- `apps/web/src/lib/data/project-detail.ts`
- `apps/web/src/lib/data/demo.ts`
- `apps/web/src/lib/actions/movimentacoes.ts`
- `apps/web/src/components/projects/detail/ProjectDetailClient.tsx`
- `apps/web/src/components/projects/detail/CheckoutDialog.tsx`
- `supabase/migrations/20260623083000_checkout_gate_override.sql`
- `tasks/evidence/mar-181/checkout-gate-imagegen.png`
- `tasks/evidence/mar-181/checkout-gate-desktop.png`
- `tasks/evidence/mar-181/checkout-gate-mobile.png`
- `tasks/evidence/mar-181/checkout-gate-override-modal.png`

Comportamento entregue:

- Detalhe do Evento agora calcula prontidão por gate real: ficha, packing, cobertura, conflitos e checklist.
- Cobertura soma unidades próprias + aluguel avulso antes de decidir se há falta.
- Ficha preenchida é lida de `projetos.ficha_evento` e vira percentual com campos obrigatórios e labels de pendência.
- Checklist da ficha bloqueia check-out quando não tem itens ou quando há item pendente.
- Conflito de data no packing do Evento entra como bloqueador do check-out.
- UI ganhou painel `Gate de saída` com checks compactos, bloqueador principal e chips de pendências.
- Botão de saída usa o gate: `Check-out`, `Forçar saída` ou `Check-out bloqueado`.
- Modal de check-out mostra bloqueadores quando entra em override.
- Override exige motivo mínimo antes de habilitar confirmação.
- Server action permite override apenas para `admin`, grava auditoria e chama RPC separada.
- Migration cria `checkout_overrides` com RLS, grants explícitos, payload auditável e motivo obrigatório.
- Migration cria `checkout_projeto_com_override`, que força saída só com override registrado e movimenta apenas seriais próprios.
- Migration revoga novamente execução direta de `checkout_projeto` por `authenticated`, corrigindo a abertura acidental da MAR-180.
- Modo demo ganhou ficha preenchida e checklist pendente para mostrar bloqueio real no QA.
- Gate visual executado: referência glass da MAR-176/MAR-180 inspecionada, variação raster criada com imagegen e screenshots finais salvos.

Validações executadas:

- `node --test src/lib/checkout-gate-core.test.ts src/lib/evento-ficha-core.test.ts`: 8 testes passaram.
- `node --test src/lib/*.test.ts src/lib/data/*.test.ts`: 57 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint`: passou.
- `npm run build`: passou e manteve `/projetos/[id]`.
- QA browser local com `MMD_DATA_MODE=demo`: painel `Gate de saída` apareceu, botão `Forçar saída` abriu modal, textarea `Motivo do override` foi exigida e confirmação só habilitou depois do motivo.
- QA browser desktop/mobile: screenshots salvos em `tasks/evidence/mar-181/`, sem overflow horizontal e sem erros de console.
- Scan de caracteres banidos nos arquivos tocados de UI/core/tracker/migration: sem matches.

Risco residual:

- MAR-181 ainda não deve ir para Done enquanto MAR-172/MAR-174/MAR-176/MAR-179/MAR-180 não fecharem validação real de auth, ficha, packing, alocação e aluguel avulso.
- Escrita real de `checkout_overrides` e RPC `checkout_projeto_com_override` no Supabase não foi executada porque o QA rodou em modo demo.
- A migration `20260623083000_checkout_gate_override.sql` ainda não foi aplicada no banco real.
- A cadeia real de migrations continua bloqueada enquanto `supabase/migrations/00001_initial_schema.sql` estiver deletada no worktree.

## MAR-182, check-out web com regra única e auditoria aplicado

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/checkout-execution-core.ts`
- `apps/web/src/lib/checkout-execution-core.test.ts`
- `apps/web/src/lib/checkout-rpc-contract.test.ts`
- `apps/web/src/lib/actions/movimentacoes.ts`
- `apps/web/src/components/projects/detail/CheckoutDialog.tsx`
- `tasks/evidence/mar-182/checkout-execution-imagegen.png`
- `tasks/evidence/mar-182/checkout-execution-desktop.png`
- `tasks/evidence/mar-182/checkout-execution-mobile.png`

Comportamento entregue:

- Check-out agora monta um plano de execução único antes da RPC, usando o mesmo gate de saída do MAR-181.
- Plano separa seriais próprios, cobertura por aluguel avulso, faltas, extras, método e operador autenticado.
- Seriais próprios só podem sair quando estão `DISPONIVEL`.
- Falha dura de serial bloqueia antes de gravar override e antes de chamar RPC.
- Override admin continua possível para prontidão incompleta, mas não para unidade própria em status inválido.
- Modal mostra `Conferência de saída` antes da confirmação com próprios, avulso, faltando, extra, método e operador.
- Lista de cobertura mostra faltas por item, aluguel avulso separado e seriais próprios que serão movimentados.
- Modal foi movido para portal no `document.body`, evitando corte pelo layout principal no mobile.
- UI foi ajustada para desktop e mobile com footer fixo, body rolável e sem sobreposição.
- Teste de contrato SQL valida que a RPC faz lock, registra `metodo_scan`, `registrado_por`, timestamp via movimentação, atualiza seriais para `EM_CAMPO` e mantém execução via `service_role`.
- Gate visual executado: mock glass anterior inspecionado, variação raster gerada com imagegen e screenshots finais salvos.

Validações executadas:

- `node --test src/lib/checkout-execution-core.test.ts src/lib/checkout-gate-core.test.ts src/lib/checkout-rpc-contract.test.ts`: 13 testes passaram.
- `node --test src/lib/*.test.ts src/lib/data/*.test.ts`: 65 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint`: passou.
- `npm run build`: passou e manteve `/projetos/[id]`.
- QA browser local com `MMD_DATA_MODE=demo`: modal abriu, métricas apareceram, motivo de override foi aceito, botão permaneceu bloqueado quando havia serial próprio `PACKED`.
- QA browser desktop/mobile: screenshots salvos em `tasks/evidence/mar-182/`, sem corte lateral, sem overflow incoerente e sem erros de console no final.
- Scan de caracteres banidos nos arquivos tocados: sem matches.

Risco residual:

- MAR-182 ainda não deve ir para Done enquanto MAR-172/MAR-174/MAR-176/MAR-179/MAR-180/MAR-181 não fecharem validação real de auth, ficha, packing, alocação, aluguel avulso e gate.
- Execução real da RPC no Supabase não foi rodada porque o QA local está em modo demo e a cadeia de migrations segue bloqueada.
- A migration base `supabase/migrations/00001_initial_schema.sql` continua deletada no worktree, impedindo reset confiável do banco.
- O demo atual usa seriais `PACKED` em algumas alocações e agora isso aparece corretamente como bloqueio duro contra saída.

## MAR-183, mobile com resumo do Evento e fronteira única de checkout aplicado

Data: 2026-06-23

Arquivos tocados:

- `apps/ios/MMDEstoque/MMDEstoque/Config/AppConfig.swift`
- `apps/ios/MMDEstoque/MMDEstoque/Views/ContentView.swift`
- `apps/ios/MMDEstoque/MMDEstoque/Models/Project.swift`
- `apps/ios/MMDEstoque/MMDEstoque/Models/Movement.swift`
- `apps/ios/MMDEstoque/MMDEstoque/Services/APIClient.swift`
- `apps/ios/MMDEstoque/MMDEstoque/ViewModels/CheckoutViewModel.swift`
- `apps/ios/MMDEstoque/MMDEstoque/Views/CheckoutFlowView.swift`
- `apps/ios/MMDEstoque/MMDEstoqueTests/APIClientTests.swift`
- `apps/web/src/app/api/eventos/[id]/checkout/route.ts`
- `tasks/evidence/mar-183/mobile-checkout-imagegen.png`

Comportamento entregue:

- App iOS agora tem configuração separada de `API WEB`, visível para o operador.
- Tela de check-out mostra modo operacional explícito: `API REAL` quando a API Web está configurada, ou `MODO MOCK` quando não está.
- Mobile carrega resumo operacional do Evento via `/api/eventos/:id/resumo`, incluindo ficha, montagem, desmontagem, local, contato e readiness quando disponíveis.
- Tela de check-out ganhou cartão compacto do Evento, ring de readiness, chips de modo, resumo de faltantes e extras antes da confirmação.
- Faltantes, extras e leituras não resolvidas aparecem antes da confirmação.
- Finalização do check-out no iOS deixou de fazer duas escritas diretas no Supabase.
- Check-out real agora chama uma única fronteira web: `POST /api/eventos/:id/checkout`.
- Endpoint web novo valida `metodo` e chama a mesma action `checkoutProject` usada pelo botão web.
- Em modo mock sem API Web, a confirmação fica explícita como simulação local e não grava alteração real.
- Testes do iOS cobrem contrato de resumo e contrato de checkout contra a API Web.
- Gate visual executado: screenshots glass existentes da MAR-176/MAR-181/MAR-182 foram usados como referência, imagegen gerou o mock mobile e o arquivo foi salvo em evidência.

Validações executadas:

- `npm run lint`: passou.
- `npm exec tsc -- --noEmit`: passou.
- `npm run build`: passou e a rota `ƒ /api/eventos/[id]/checkout` apareceu no build.
- `node --test src/lib/checkout-execution-core.test.ts src/lib/checkout-gate-core.test.ts src/lib/checkout-rpc-contract.test.ts`: 13 testes passaram.
- `xcrun swiftc -typecheck ...`: passou para o app iOS.
- `xcodebuild -showdestinations`: listou simuladores disponíveis, incluindo `iPhone 17`.
- Scan de caracteres banidos nos arquivos tocados: sem matches.
- Scan confirmou que `CheckoutViewModel` usa `apiClient.checkoutProject` e não chama mais `registerCheckout` nem `updateProjectStatus(.emCampo)`.

Bloqueio de validação resolvido depois:

- O bloqueio original de fontes do iOS foi removido no corte de estabilizacao MAR-183/MAR-185/MAR-188.
- O projeto deixou de referenciar TTFs ausentes e passou a usar tipografia de sistema.
- Build e testes iOS padrao passaram sem workaround.

Risco residual:

- A API Web do mobile ainda depende do modo de auth do web. Com auth obrigatório, o endpoint usa a action web existente e sessão/cookie do web; bearer mobile real precisa de fechamento na etapa de auth mobile.
- Check-out real no Supabase continua dependente das migrations reais, que seguem bloqueadas pela `00001_initial_schema.sql` deletada no worktree.

## MAR-184, conferência de retorno com pendência aplicada

Data: 2026-06-23

Arquivos tocados:

- `supabase/migrations/20260623094805_return_pending_resolution.sql`
- `apps/web/src/lib/return-resolution-core.ts`
- `apps/web/src/lib/return-resolution-core.test.ts`
- `apps/web/src/lib/checkout-rpc-contract.test.ts`
- `apps/web/src/lib/actions/movimentacoes.ts`
- `apps/web/src/lib/data/project-detail.ts`
- `apps/web/src/lib/data/demo.ts`
- `apps/web/src/components/projects/detail/ProjectDetailClient.tsx`
- `apps/web/src/components/projects/detail/CheckinDialog.tsx`
- `tasks/evidence/mar-184/reference-checkout-glass.png`
- `tasks/evidence/mar-184/return-resolution-imagegen.png`
- `tasks/evidence/mar-184/return-desktop.png`
- `tasks/evidence/mar-184/return-desktop-selected.png`
- `tasks/evidence/mar-184/return-mobile.png`

Comportamento entregue:

- Retorno web agora trabalha com três resultados por unidade própria em campo: OK, Problema e Não voltou.
- OK muda a unidade para `DISPONIVEL`.
- Problema exige OBS do Evento e muda a unidade para `MANUTENCAO`.
- Não voltou muda a unidade para `RETORNANDO`, cria pendência em `retorno_pendencias` e não dá baixa automática.
- Evento permanece `EM_CAMPO` enquanto houver pendência aberta.
- Resolução posterior de pendência roda em action admin-only e aceita: encontrada, manutenção, baixa ou cobrança textual.
- Cobrança textual fecha a pendência administrativa sem mudar o status físico da unidade.
- UI usa modal via portal para ficar acima da navegação no mobile.
- Demo interno `/projetos/demo-proj-retorno` foi criado só para QA visual do retorno, sem alterar o demo principal de checkout.

Validações executadas:

- `node --test --experimental-strip-types src/lib/return-resolution-core.test.ts src/lib/checkout-rpc-contract.test.ts src/lib/checkout-execution-core.test.ts src/lib/checkout-gate-core.test.ts`: 20 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint`: passou.
- `npm run build`: passou.
- Playwright desktop em `http://localhost:3101/projetos/demo-proj-retorno`: modal de retorno abriu, estado com Problema e Não voltou validado visualmente.
- Playwright mobile 390x844: modal abriu acima da SideRail, sem texto cortado no topo visível.
- Scan de caracteres banidos nos arquivos tocados do corte: sem matches.

Linear:

- Issue MAR-184 comentada no Linear com entrega, validações e risco residual: `742f9892-c237-4d89-8a5b-041e885c3428`.
- Anexos no Linear: imagegen reference, desktop final e mobile final em miniatura.
- Status do projeto MMD atualizado em `5d772574-229a-4531-b9f5-17e5d6569d6f`, mantendo health `atRisk`.
- MAR-184 mantida em `In Progress` até validação real de DB/migrations.

Risco residual:

- `supabase migration list --local` não rodou porque o Postgres local em `127.0.0.1:54322` recusou conexão. A validação de banco ficou coberta por contrato estático da migration e build web.
- A cadeia completa de migrations segue com risco preexistente porque `supabase/migrations/00001_initial_schema.sql` aparece deletada no worktree.
- A resolução real de pendência precisa ser validada contra banco aplicado quando o ambiente local ou remoto estiver acessível.

## MAR-185, retorno mobile usando regra compartilhada aplicado

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/app/api/eventos/[id]/retorno/route.ts`
- `apps/ios/MMDEstoque/MMDEstoque/Models/Movement.swift`
- `apps/ios/MMDEstoque/MMDEstoque/Services/APIClient.swift`
- `apps/ios/MMDEstoque/MMDEstoque/ViewModels/ReturnViewModel.swift`
- `apps/ios/MMDEstoque/MMDEstoque/Views/ReturnFlowView.swift`
- `apps/ios/MMDEstoque/MMDEstoqueTests/APIClientTests.swift`
- `tasks/evidence/mar-185/mobile-return-imagegen.png`

Comportamento entregue:

- Mobile de retorno parou de registrar devolução direto no Supabase.
- `ReturnViewModel` agora chama `apiClient.returnProject`, que usa a API Web compartilhada em `/api/eventos/:id/retorno`.
- A rota web valida `metodo`, `items`, `resultado`, `desgaste` e `observacao`, depois chama `checkinProject`, a mesma action usada pelo retorno web.
- Cada unidade em campo termina em um dos três resultados: OK, Problema ou Não voltou.
- Problema exige OBS do Evento antes de confirmar.
- Não voltou entra no payload como `NAO_VOLTOU`, que abre pendência de resolução pelo fluxo entregue na MAR-184.
- Pendente sem decisão bloqueia a confirmação do retorno.
- Tela mobile ganhou contadores de OK, Problema, Não voltou e Pendente, ações por unidade e modal separado para Problema ou Não voltou.
- UI seguiu o gate visual: referência glass existente, imagegen antes de código e artefato salvo em `tasks/evidence/mar-185/mobile-return-imagegen.png`.

Validações executadas:

- `node --test --experimental-strip-types src/lib/return-resolution-core.test.ts src/lib/checkout-rpc-contract.test.ts src/lib/checkout-execution-core.test.ts src/lib/checkout-gate-core.test.ts`: 20 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint`: passou.
- `npm run build`: passou e a rota `ƒ /api/eventos/[id]/retorno` apareceu no build.
- `xcodebuild test -project apps/ios/MMDEstoque/MMDEstoque.xcodeproj -scheme MMDEstoque -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MMDEstoqueTests/APIClientTests EXCLUDED_SOURCE_FILE_NAMES='*.ttf'`: 10 testes passaram.
- Scan de caracteres banidos nos arquivos tocados do corte: sem matches.

Linear:

- Issue MAR-185 comentada no Linear com entrega, validações e blocker: `beec03c8-2e54-4772-92e5-659e7cf4d9cf`.
- Preview imagegen anexado no Linear: `4e8f15d7-4b46-4ee9-a453-0a30bcec7bd8`.
- Status do projeto MMD atualizado em `5d772574-229a-4531-b9f5-17e5d6569d6f`, mantendo health `atRisk`.
- MAR-185 mantida em `In Progress` ate validacao real de retorno contra banco aplicado.

Bloqueio de validação resolvido depois:

- O bloqueio original de fontes do iOS foi removido no corte de estabilizacao MAR-183/MAR-185/MAR-188.
- Build e testes iOS padrao passaram sem `EXCLUDED_SOURCE_FILE_NAMES`.
- Screenshot real do simulador foi salvo em `tasks/evidence/mar-188/ios-standard-build-launch.png`.

Risco residual:

- A API Web mobile ainda depende do fechamento de auth mobile para bearer real quando `MMD_REQUIRE_AUTH=true`.
- Retorno real contra banco aplicado depende da MAR-184 sair do bloqueio de migrations/Supabase local.

## MAR-186, dashboard consolidado com dados reais de prontidão aplicado

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/dashboard-core.ts`
- `apps/web/src/lib/dashboard-core.test.ts`
- `apps/web/src/lib/data/dashboard.ts`
- `apps/web/src/lib/data/stock.ts`
- `apps/web/src/lib/data/demo.ts`
- `apps/web/src/components/dashboard/DashboardConsolidationPanels.tsx`
- `apps/web/src/app/page.tsx`
- `tasks/evidence/mar-186/glass-reference-dashboard.png`
- `tasks/evidence/mar-186/dashboard-real-readiness-imagegen.png`
- `tasks/evidence/mar-186/dashboard-desktop.png`
- `tasks/evidence/mar-186/dashboard-mobile.png`
- `tasks/evidence/mar-186/dashboard-dark-desktop.png`

Comportamento entregue:

- Dashboard deixou de ter próximos Eventos e hero fixos dentro de `loadDashboard`.
- Loader agora usa `loadProjects`, `loadProjectById` e `loadStockStats`, mantendo fixtures só pelo `MMD_DATA_MODE=demo`.
- Prontidão exibida usa gate do Evento quando disponível, incluindo ficha, packing, cobertura própria + avulsa, conflitos e checklist.
- Pendência aberta de retorno entra como risco crítico no dashboard e limita a prontidão exibida.
- Próximos Eventos, hero, notificações e próximo check-out são derivados dos Eventos operacionais.
- Cards de estoque continuam com dados reais e agora contam também baixas e vendidos para painel de perdas.
- Dashboard ganhou painéis `Uso por categoria` e `Manutenção e perdas`.
- Gate visual executado: referência glass antiga recuperada, imagegen gerado antes do código e screenshots finais desktop/mobile salvos.

Validações executadas:

- `node --test --experimental-strip-types src/lib/dashboard-core.test.ts`: 4 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `node --test src/lib/*.test.ts src/lib/data/*.test.ts`: 76 testes passaram.
- `npm run lint`: passou.
- `npm run build`: passou.
- QA browser em build local de produção `http://127.0.0.1:3110`: desktop e mobile renderizaram `Uso por categoria` e `Manutenção e perdas`, sem overflow horizontal e sem erros de console.
- QA dark forçado via `localStorage.mmd-theme=dark`: renderizou os painéis e screenshot final sem overflow.
- Scan visual: screenshot dark final salvo em `tasks/evidence/mar-186/dashboard-dark-desktop.png`.

Linear:

- Issue MAR-186 movida para `In Progress`.
- Comentário de entrega no Linear: `2298144a-77d9-4e33-ad28-6252c8bf4de2`.
- Anexo imagegen no Linear: `10fdd9c1-69df-4d34-885d-f9e3841822a1`.
- Anexo desktop dark no Linear: `2d43d1c7-76e9-424e-8864-f886a982850e`.
- Anexo mobile no Linear: `a85b2658-2ea3-4244-bc69-6cad6aa4b255`.
- Status do projeto MMD atualizado em `5d772574-229a-4531-b9f5-17e5d6569d6f`, mantendo health `atRisk`.

Risco residual:

- MAR-186 não deve ir para Done enquanto MAR-174, MAR-179, MAR-180 e MAR-184 estiverem em `In Progress`.
- Validação contra Supabase real aplicado ainda depende da cadeia de migrations sair do blocker da `00001_initial_schema.sql` deletada no worktree.
- O QA funcional rodou em modo demo explícito para provar UI/renderização sem depender do Supabase real.

## MAR-187, lotes legados e operação unit-only aplicado

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/legacy-lotes-core.ts`
- `apps/web/src/lib/legacy-lotes-core.test.ts`
- `apps/web/src/lib/data/qrcodes.ts`
- `apps/web/src/lib/data/rfid.ts`
- `apps/web/src/lib/data/demo.ts`
- `apps/web/src/components/qrcodes/QrCodesClient.tsx`
- `apps/web/src/components/lotes/LotesLegacyClient.tsx`
- `apps/web/src/app/lotes/page.tsx`
- `apps/web/src/app/lotes/[id]/page.tsx`
- `apps/web/src/components/catalog/LotesCard.tsx`
- `apps/web/src/app/qrcodes/[codigo]/page.tsx`
- `apps/web/src/app/api/qr-sheet/route.ts`
- `apps/web/src/components/qrcodes/layouts.ts`
- `tasks/evidence/mar-187/unit-only-lotes-imagegen.png`
- `tasks/evidence/mar-187/lotes-legacy-dark-desktop.png`
- `tasks/evidence/mar-187/lotes-legacy-dark-mobile.png`
- `tasks/evidence/mar-187/qrcodes-unit-only-dark-desktop.png`

Comportamento entregue:

- QR novo ficou unit-only: a tela de QR usa apenas unidades físicas e não gera etiqueta de lote.
- Lotes ainda são lidos como legado para contagem e auditoria, sem virar fonte operacional futura.
- RFID reconhece alvo ativo só por serial. Scan antigo de lote vira nota `Lote legado`, sem link operacional para lote.
- `/lotes` virou tela de auditoria read-only com estado de migração concluída.
- `/lotes/[id]` redireciona para `/lotes`.
- SideRail e card de catálogo não oferecem `/lotes` como fluxo ativo.
- Delete físico de lote não foi executado.

Validações executadas:

- `node --test src/lib/*.test.ts src/lib/data/*.test.ts`: 80 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint`: passou.
- `npm run build`: passou.
- QA Playwright em build local de produção `http://127.0.0.1:3111`: `/lotes` desktop/mobile dark sem console error ou overflow, `/qrcodes` unit-only, nav sem `/lotes` e `/lotes/demo-lote-xlr-10m` redirecionando para `/lotes`.
- Scan de caracteres banidos nos arquivos tocados: sem em dash ou reticência Unicode.

Linear:

- Issue MAR-187 movida para `Done`.
- Comentário de entrega no Linear: `a541a743-b5a1-4bf5-bbbe-92dbb3721a83`.
- Anexo imagegen no Linear: `81aaaca4-e176-4cc1-adcf-fb5d70bec080`.
- Status do projeto MMD atualizado em `5d772574-229a-4531-b9f5-17e5d6569d6f`, mantendo health `atRisk`.

Risco residual:

- Delete físico dos lotes exige checkpoint humano explícito.
- Validação contra Supabase real aplicado ainda depende da cadeia de migrations sair do blocker da `00001_initial_schema.sql` deletada no worktree.

## MAR-188, gate mobile de produção aplicado e validação física bloqueada

Data: 2026-06-23

Arquivos tocados:

- `apps/ios/MMDEstoque/MMDEstoque/Services/RFIDManager.swift`
- `apps/ios/MMDEstoque/MMDEstoque/Services/MockRFIDManager.swift`
- `apps/ios/MMDEstoque/MMDEstoque/Views/ContentView.swift`
- `apps/ios/MMDEstoque/MMDEstoqueTests/RFIDManagerTests.swift`
- `tasks/evidence/mar-188/mobile-production-gate-imagegen.png`
- `tasks/evidence/mar-188/manual-teste-fisico-rfd40.md`
- `tasks/evidence/mar-188/rfid-manager-tests.log`
- `tasks/evidence/mar-188/ios-full-tests-font-workaround.log`
- `tasks/evidence/mar-188/standard-build-without-font-workaround.log`

Comportamento entregue:

- App iOS ganhou snapshot de gate de producao mobile para separar mock, fallback e Zebra SDK real.
- Tela `Config` agora mostra `GATE DE PRODUCAO` com status geral e checklist de build assinado, iPhone real, RFD40 pareado, 5 tags reais, QR fallback, checkout web e retorno web.
- Mock RFID e fallback do Zebra SDK ficam bloqueados para campo, mesmo que existam tags lidas no modo demo.
- Zebra SDK conectado com 5 tags reais ainda fica `PENDENTE` enquanto QR, checkout, retorno e build assinado nao tiverem evidencia fisica registrada.
- Mock RFID deixou de tornar testes aleatorios: o app ainda pode simular falha em demo, mas os testes injetam conexao deterministica.
- Manual curto de teste fisico RFD40 criado com passos, criterios de falha e evidencias exigidas.
- UI seguiu o gate visual: referencia Liquid Glass existente, imagegen antes de codigo e artefato salvo em `tasks/evidence/mar-188/mobile-production-gate-imagegen.png`.

Validações executadas:

- `xcodebuild test -project apps/ios/MMDEstoque/MMDEstoque.xcodeproj -scheme MMDEstoque -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MMDEstoqueTests/RFIDManagerTests EXCLUDED_SOURCE_FILE_NAMES='*.ttf'`: 14 testes passaram.
- `xcodebuild test -project apps/ios/MMDEstoque/MMDEstoque.xcodeproj -scheme MMDEstoque -destination 'platform=iOS Simulator,name=iPhone 17' EXCLUDED_SOURCE_FILE_NAMES='*.ttf'`: 74 testes passaram.
- `xcodebuild build -project apps/ios/MMDEstoque/MMDEstoque.xcodeproj -scheme MMDEstoque -destination 'platform=iOS Simulator,name=iPhone 17'`: falhou com exit 65 por fontes iOS deletadas no worktree, antes de device/signing.
- `xcodebuild build -project apps/ios/MMDEstoque/MMDEstoque.xcodeproj -scheme MMDEstoque -destination 'platform=iOS Simulator,name=iPhone 17'`: passou depois da remocao das referencias de TTF ausentes.
- `xcodebuild test -project apps/ios/MMDEstoque/MMDEstoque.xcodeproj -scheme MMDEstoque -destination 'platform=iOS Simulator,name=iPhone 17'`: 74 testes passaram sem workaround.
- App iOS abriu no simulador e screenshot foi salvo em `tasks/evidence/mar-188/ios-standard-build-launch.png`.
- Scan de caracteres banidos nos arquivos tocados: sem em dash, reticencia Unicode ou dupla exclamacao.

Bloqueio de produção:

- MAR-188 nao deve ir para Done sem iPhone fisico, Apple signing, Zebra RFD40, tags reais e validacao presencial.
- Build e testes iOS padrao no simulador estao desbloqueados.

Risco residual:

- O gate mostra prontidao tecnica, mas nao substitui evidência real de campo.
- O app ainda depende do Zebra SDK real no ambiente de device para sair de `Simulado (fallback)`.
- QR fallback, checkout e retorno precisam ser provados no evento ou ambiente validado com unidades reais.

## MAR-183/MAR-185/MAR-188, estabilizacao iOS sem TTFs ausentes

Data: 2026-06-23

Arquivos tocados:

- `apps/ios/MMDEstoque/MMDEstoque.xcodeproj/project.pbxproj`
- `apps/ios/MMDEstoque/MMDEstoque/Design/Typography.swift`
- `apps/ios/MMDEstoque/MMDEstoque/Resources/Info.plist`
- `tasks/evidence/mar-188/standard-build-after-font-reference-removal.log`
- `tasks/evidence/mar-188/ios-full-tests-standard.log`
- `tasks/evidence/mar-188/ios-standard-build-launch.png`

Comportamento entregue:

- Projeto iOS deixou de copiar TTFs que estavam ausentes do worktree.
- `Info.plist` deixou de registrar `UIAppFonts` para arquivos inexistentes.
- API de tipografia manteve os mesmos nomes usados pelas telas, mas agora usa fontes de sistema equivalentes.
- Build iOS padrao voltou a funcionar sem excluir recursos manualmente.
- App iOS abre e renderiza no simulador com tipografia de sistema.

Validações executadas:

- `plutil -lint apps/ios/MMDEstoque/MMDEstoque/Resources/Info.plist`: passou.
- Scan de referencias a `SpaceGrotesk`, `SpaceMono`, `Doto[ROND` e `UIAppFonts` nos pontos criticos: sem matches.
- `xcodebuild build -project apps/ios/MMDEstoque/MMDEstoque.xcodeproj -scheme MMDEstoque -destination 'platform=iOS Simulator,name=iPhone 17'`: passou sem workaround.
- `xcodebuild test -project apps/ios/MMDEstoque/MMDEstoque.xcodeproj -scheme MMDEstoque -destination 'platform=iOS Simulator,name=iPhone 17'`: 74 testes passaram sem workaround.
- `xcrun simctl launch booted com.emdash.mmdestoque`: app abriu no simulador.
- `xcrun simctl io booted screenshot tasks/evidence/mar-188/ios-standard-build-launch.png`: screenshot salvo.
- Scan de caracteres banidos nos arquivos tocados: sem em dash, reticencia Unicode ou dupla exclamacao.

Impacto no Linear:

- MAR-183 perdeu o blocker de build/teste/screenshot do simulador.
- MAR-185 perdeu o blocker de build/teste/screenshot do simulador.
- MAR-188 perdeu o blocker local de build padrao, mas continua bloqueada para Done por hardware/signing/RFD40/tags reais.

Risco residual:

- A troca de fontes muda a textura visual fina do app iOS, mas preserva hierarquia, pesos e roles tipograficos.
- Se o time quiser voltar ao Liquid Glass tipografico original, precisa reintroduzir TTFs reais e referencias coerentes.
- Fluxos reais de checkout/retorno ainda dependem da validacao contra Supabase aplicado.

## MAR-171, validação local completa das migrations Supabase

Data: 2026-06-23

Arquivos tocados:

- `supabase/migrations/20260623083000_checkout_gate_override.sql`
- `supabase/migrations/20260623094805_return_pending_resolution.sql`
- `apps/web/src/lib/checkout-rpc-contract.test.ts`
- `tasks/evidence/mar-171/supabase-migration-validation-2026-06-23.md`

Comportamento entregue:

- Cadeia completa de migrations validada em banco Supabase local temporário, usando `00001_initial_schema.sql` recuperada de `HEAD` apenas fora do worktree principal.
- `checkout_overrides` deixou de herdar privilégios para `anon` e ficou com grant mínimo: leitura/criação para `authenticated`, leitura/criação/atualização para `service_role`.
- `retorno_pendencias` deixou de herdar privilégios para `anon` e ficou sem delete direto para `authenticated`.
- Teste de contrato SQL atualizado para proteger esses grants explícitos.

Validações executadas:

- `supabase db start --workdir /tmp/mmd-supabase-validate-v60CxY`: aplicou todas as migrations até `20260623094805`.
- `supabase db reset --local --workdir /tmp/mmd-supabase-validate-v60CxY --no-seed`: passou.
- `supabase db lint --local --workdir /tmp/mmd-supabase-validate-v60CxY`: sem schema errors.
- `supabase db advisors --local --workdir /tmp/mmd-supabase-validate-v60CxY`: no issues found.
- Query de grants/RLS: `checkout_overrides` e `retorno_pendencias` ficaram com `anon_select=false` e `anon_insert=false`.
- Query de funções: RPCs sensíveis ficaram com `anon_execute=false`, `authenticated_execute=false` e `service_role_execute=true`.
- `node --test --experimental-strip-types src/lib/checkout-rpc-contract.test.ts`: 4 testes passaram.
- Scan de caracteres banidos nos arquivos tocados: sem em dash, reticencia Unicode ou dupla exclamacao.

Impacto no Linear:

- MAR-172, MAR-184, MAR-180 e MAR-186 ganham evidência forte de schema local até a última migration.
- O blocker de Supabase real não fecha ainda, porque não há credenciais remotas no ambiente atual.

Risco residual:

- `supabase/migrations/00001_initial_schema.sql` continua deletada no worktree principal. A validação usou uma cópia temporária para não reverter uma alteração preexistente sem autorização explícita.
- Migrations ainda precisam ser aplicadas e testadas no projeto Supabase real com usuários `editor` e `admin`.

## MAR-171, matriz de supervisão Linear publicada

Data: 2026-06-23

Arquivos tocados:

- `tasks/evidence/mar-171/linear-supervisor-matrix-2026-06-23.md`

Comportamento entregue:

- As 17 issues filhas do PRD foram reconferidas no Linear.
- Estado consolidado: MAR-187 em `Done`; MAR-172 a MAR-186 e MAR-188 em `In Progress`.
- Matriz local criada separando evidência local de prova exigida para produção real.
- Documento Linear criado: https://linear.app/marco-os/document/matriz-de-supervisao-mar-171-558c9ee0f7dc
- Status do projeto MMD atualizado no Linear, mantendo health `atRisk`.

Risco residual:

- A matriz não fecha issues sozinha. Ela deixa explícito o que ainda depende de Supabase real, login real, device real e decisão sobre a `00001_initial_schema.sql` deletada.

## MAR-171, tentativa de validação remota Supabase via conector

Data: 2026-06-23

Comportamento entregue:

- Conector Supabase foi localizado na sessão.
- Project-ref local encontrado em `supabase/.temp/project-ref`: `bphmxticdyuctovfumcj`.
- Foram testadas leituras remotas sem DDL e sem escrita.

Validações tentadas:

- `list_projects`: falhou duas vezes com erro interno `-32603`.
- `list_migrations` para `bphmxticdyuctovfumcj`: falhou com erro interno `-32603`.
- `execute_sql` com query mínima de identificação de banco: falhou com erro interno `-32603`.

Risco residual:

- Supabase remoto continua sem validação nesta sessão porque o conector está indisponível na prática.
- Não foi feita nenhuma aplicação de migration, reset, DDL ou escrita remota.

## MAR-189, bloqueador formal de Supabase real criado

Data: 2026-06-23

Comportamento entregue:

- Issue Linear criada: MAR-189, `Desbloquear Supabase real e migration base`.
- MAR-189 foi criada como filha de MAR-172 para não virar uma nova vertical do PRD.
- MAR-172 a MAR-186 receberam label `blocked-prod` e relação de bloqueio com MAR-189 quando dependem de Supabase real, migration base ou login real.
- MAR-188 ficou fora da relação com MAR-189 porque o bloqueio principal dela é físico/hardware, apesar de também continuar com `blocked-prod`.
- Labels originais das issues foram preservados ao adicionar `blocked-prod`.

Evidência Linear:

- MAR-189: https://linear.app/marco-os/issue/MAR-189/desbloquear-supabase-real-e-migration-base
- Matriz de supervisão: https://linear.app/marco-os/document/matriz-de-supervisao-mar-171-558c9ee0f7dc

Risco residual:

- Status superado depois: MAR-189 foi executada, fechada e removida como blocker de produção das verticais dependentes.

## MAR-189, plano de execução preparado

Data: 2026-06-23

Arquivos tocados:

- `tasks/evidence/mar-189/execution-plan-2026-06-23.md`

Comportamento entregue:

- Plano executável de MAR-189 criado sem restaurar `00001_initial_schema.sql` no worktree principal.
- Opção recomendada documentada: restaurar `00001` a partir de `HEAD` com autorização explícita.
- Gates de validação local definidos: `supabase db reset`, `db lint`, `db advisors`, `migration list`, queries de RLS/grants/functions e build web.
- Gates de fechamento real definidos: acesso remoto Supabase, migrations remotas, login `editor/admin` e auditoria real.

Risco residual:

- A restauração da `00001` ainda não foi executada porque isso reverte uma deleção preexistente.

## MAR-171, reconciliação supervisor Linear e Supabase remoto

Data: 2026-06-23

Arquivos tocados:

- `tasks/evidence/mar-171/linear-supervisor-matrix-2026-06-23.md`
- `tasks/mar-171-supervisor.md`

Comportamento entregue:

- MAR-187 foi reconferida no Linear.
- MAR-187 estava `Done`, mas ainda carregava o label `blocked-prod`.
- O label `blocked-prod` foi removido de MAR-187 e os demais labels foram preservados.
- O conector Supabase foi testado novamente em modo somente leitura para tentar reduzir o blocker remoto.
- Documento Linear da matriz atualizado: https://linear.app/marco-os/document/matriz-de-supervisao-mar-171-558c9ee0f7dc
- Status update do projeto MMD atualizado em `5d772574-229a-4531-b9f5-17e5d6569d6f`.
- Comentário de nova tentativa na MAR-189: `2057e931-615d-4ff9-867e-37403920c494`.

Validações executadas:

- `list_projects`: falhou com HTTP 500 retryable.
- `list_migrations` para `bphmxticdyuctovfumcj`: falhou com erro interno `-32603`.
- `execute_sql` com query mínima de identificação de banco: falhou com erro interno `-32603`.
- Nenhum DDL, migration, reset ou escrita remota foi executado.

Risco residual:

- MAR-187 segue Done, sem blocker de produção no painel.
- Supabase remoto continua inacessível pelo conector atual.
- MAR-189 continua sendo o blocker real para Supabase aplicado, login real e auditoria real.

## MAR-171, alinhamento para agentes de front-end em paralelo

Data: 2026-06-23

Arquivos tocados:

- `docs/mar-171-agent-brief.md`
- `docs/handoff.md`
- `docs/design-brief.md`
- `docs/guia-marcelo.md`
- `AGENTS.md`
- `apps/web/AGENTS.md`
- `apps/web/README.md`
- `tasks/mar-171-supervisor.md`

Comportamento entregue:

- Criado briefing operacional único para agentes do PRD MAR-171.
- Separado explicitamente o que fica com o supervisor backend/Supabase e o que pode ir para agentes de front-end.
- Documentado que o web vivo continua sendo `https://mmd-zeta.vercel.app` e o código em `apps/web`.
- Documentado que prints em `tasks/evidence/` são referência, imagegen ou screenshot de QA, não um front-end paralelo.
- Atualizados docs antigos que ainda tratavam auth como fase futura, cabos por lote e design system anterior.
- `apps/web/README.md` deixou de ser README genérico do Next e virou guia útil para agentes web.
- Comentário de alinhamento publicado em MAR-171: `6e3a6fd7-f674-4b63-b1e5-6dda4114f89c`.

Diretriz para paralelização:

- Front-end adapta o produto existente.
- Front-end não muda migrations, RLS, grants, RPCs ou contrato de API sem alinhamento.
- Front-end não marca produção real por screenshot.
- Supervisor segue responsável por MAR-189, Supabase real, login real, auditoria real e fechamento de issues no Linear.

Risco residual:

- A documentação alinha os agentes, mas não fecha MAR-189.
- A execução técnica deve retomar pela simulação RLS local, gates web e tentativa de Supabase real.

## MAR-189, gate local fechado no repo principal

Data: 2026-06-23

Arquivos tocados:

- `tasks/evidence/mar-189/local-gate-2026-06-23.md`
- `tasks/mar-171-supervisor.md`

Comportamento entregue:

- `supabase/migrations/00001_initial_schema.sql` está presente no worktree principal.
- A cadeia real de migrations aplica no repo principal de `00001` até `20260623094805`.
- O blocker local da migration base foi removido.
- O blocker remanescente da MAR-189 agora é acesso/permissão ao Supabase real.

Validações executadas:

- `supabase db reset --local --no-seed`: passou no repo principal.
- `supabase db lint --local`: passou com `No schema errors found`.
- `supabase db advisors --local`: passou com `No issues found`.
- `supabase migration list --local`: listou 14 migrations alinhadas.
- Query de grants e policies: tabelas internas sem grant para `anon`, policies finais em `{authenticated}`.
- Query de funções: RPCs sensíveis sem execute para `anon` ou `authenticated`, com execute para `service_role`.
- Simulação RLS local: `viewer` foi bloqueado ao criar Evento, `editor` criou mas não deletou, `admin` deletou.
- `node --test --experimental-strip-types src/lib/*.test.ts`: 75 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint -- --max-warnings=0`: passou.
- `npm run build`: passou.
- Smoke produção local em `http://127.0.0.1:3015` com auth obrigatório:
  - `/rfid` redirecionou para `/login?next=%2Frfid`.
  - `/s/MMD-ILU-0001` respondeu `200` sem termos sensíveis no HTML.
  - `/api/qr-sheet` respondeu `401` sem sessão.
  - `/login?next=/rfid` respondeu `200`.

Tentativa remota sem escrita:

- `supabase migration list`: falhou com 403 de privilégio da conta e pediu `SUPABASE_DB_PASSWORD`.
- Conector Supabase listou projetos, mas não listou o projeto MMD `bphmxticdyuctovfumcj`.
- `_list_migrations` e `_execute_sql` no projeto MMD falharam com `You do not have permission to perform this action`.
- Nenhum DDL, migration, reset ou escrita remota foi executado.
- Comentário publicado na MAR-189: `4ac1dea6-a626-42e6-8b1c-bc4c5dee102f`.

Autorização posterior:

- Marco autorizou MCP Supabase para Claude Code e Codex.
- `.mcp.json` criado com `supabase` apontando para `https://mcp.supabase.com/mcp?project_ref=bphmxticdyuctovfumcj`.
- `claude mcp list`: `supabase` conectado.
- `codex mcp get supabase`: `supabase` habilitado, OAuth configurado e URL do projeto MMD correta.
- `codex exec` read-only conseguiu listar migrations remotas: `00001`, `00002`, `00003`, `00004`.
- `execute_sql` remoto não rodou porque pediu permissão extra no subprocesso não interativo e a tool foi cancelada. Nenhuma escrita remota foi executada.
- Comentário pós-autorização publicado na MAR-189: `7071b16e-03dc-4889-a806-3bf8e10ef935`.

Risco residual:

- Status superado depois: remoto foi alinhado até `20260623181333`, admin real foi validado e ação auditada real foi provada.

## MAR-189, Supabase real aplicado e hardening remoto

Data: 2026-06-23

Arquivos tocados:

- `supabase/migrations/00005_seed_projetos_demo.sql`
- `supabase/migrations/00006_rfid_infrastructure.sql`
- `supabase/migrations/20260623180914_remote_drift_cleanup.sql`
- `supabase/migrations/20260623181333_private_current_user_role.sql`
- `tasks/evidence/mar-189/local-gate-2026-06-23.md`
- `tasks/mar-171-supervisor.md`

Comportamento entregue:

- Supabase MMD real `bphmxticdyuctovfumcj` foi alinhado do histórico `00001` até `20260623181333`.
- Seed demo foi removido das migrations de produção antes do push remoto.
- `00005_seed_projetos_demo.sql` virou no-op de histórico.
- `00006_rfid_infrastructure.sql` ficou apenas com schema, índices e policies RFID.
- Drift remoto antigo foi limpo: policies `anon_all_*`, leitores RFID fake e scans fake removidos por alvos exatos.
- `current_user_role()` deixou de ser callable como helper público por usuários logados.
- Policies finais usam `app_private.current_user_role()` em schema privado.

Validações executadas:

- `supabase db reset --local --no-seed`: passou.
- `supabase db lint --local`: passou com `No schema errors found`.
- `supabase db advisors --local`: passou com `No issues found`.
- `node --test --experimental-strip-types src/lib/*.test.ts`: 75 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `supabase db push --linked --yes`: aplicou as migrations remotas pendentes.
- `supabase db advisors --linked`: passou com `No issues found`.
- Query remota em `supabase_migrations.schema_migrations`: listou `00001` a `20260623181333`.
- Query remota de drift: `anon_all_policies=0`, `demo_eventos=0`, `demo_readers=0`, `demo_scans=0`.
- Query remota de policies: `public_role_policy_refs=0`, `private_role_policy_refs=36`.

Risco residual:

- `supabase db push --linked --dry-run` e `supabase migration list --linked` ficaram instáveis em uma janela por autenticação temporária do pooler `cli_login_postgres`. A prova final foi feita por queries diretas no remoto.
- Este risco foi resolvido depois com admin real e ação auditada real. Usuário operacional separado foi dispensado pelo Marco nesta rodada.

## MAR-189, admin supervisor criado

Data: 2026-06-23

Arquivos tocados:

- `apps/web/src/lib/auth-config.ts`
- `apps/web/src/lib/auth-config.test.ts`
- `apps/web/src/lib/auth-actions.ts`
- `apps/web/src/app/login/page.tsx`
- `tasks/evidence/mar-189/local-gate-2026-06-23.md`
- `tasks/mar-171-supervisor.md`

Comportamento entregue:

- Usuário admin criado no Supabase Auth MMD.
- Login humano no app: `supervisor`.
- Email interno Supabase: `supervisor@mmd.local`.
- Profile remoto: `nome=supervisor`, `role=admin`.
- Senha não foi registrada em documentação.
- Web agora aceita usuário sem arroba e normaliza para `@mmd.local`.
- Tela de login mostra `Email ou usuário`.

Validações executadas:

- Login via Supabase SDK com o usuário criado: passou.
- Leitura remota do profile confirmou `role=admin`.
- `node --test --experimental-strip-types src/lib/auth-config.test.ts`: 6 testes passaram.
- `npm exec tsc -- --noEmit`: passou.
- `npm run lint -- --max-warnings=0`: passou.
- `npm run build`: passou.
- Smoke HTTP local em `/login?next=/items`: `200`, renderizando `Email ou usuário`.

Risco residual:

- Usuário operacional separado não foi criado porque o Marco dispensou essa exigência nesta rodada.

## MAR-189, ação auditada real provada

Data: 2026-06-23

Comportamento entregue:

- API web foi executada em modo produção local com `MMD_REQUIRE_AUTH=true`, `MMD_DATA_MODE=real` e `MMD_READONLY=false`.
- Sessão real do Supabase foi criada como `supervisor`.
- Evento de teste MAR-189 foi criado com ficha completa, checklist OK e packing de 1 unidade.
- `POST /api/eventos/:id/checkout` executou check-out real.
- `POST /api/eventos/:id/retorno` executou retorno real.
- A unidade `MMD-ILU-0065` voltou para `DISPONIVEL`.
- O Evento de teste ficou `FINALIZADO`.

Evidência remota:

- Evento: `1d146bc8-1492-4b56-b308-5ab9e2af83bf`.
- Movimentação `846abe6a-06ed-481e-84b3-d44e36fe60d5`: `SAIDA`, `DISPONIVEL -> EM_CAMPO`, `registrado_por=supervisor`, `metodo_scan=MANUAL`.
- Movimentação `4274e278-d67c-4a9c-9439-78fec8be042b`: `RETORNO`, `EM_CAMPO -> DISPONIVEL`, `registrado_por=supervisor`, `metodo_scan=MANUAL`.

Validações executadas:

- Checkout API autenticado retornou `count=1`.
- Retorno API autenticado retornou `count=1` e `novo_status=DISPONIVEL`.
- Query final confirmou as duas movimentações com `registrado_por=supervisor`.
- Query final confirmou unidade `MMD-ILU-0065` em `DISPONIVEL`.

Conclusão:

- MAR-189 está fechável: Supabase real aplicado, admin real validado e auditoria real provada.
- Usuário operacional separado foi dispensado pelo Marco nesta rodada.

## MAR-189, fechamento e reconciliação Linear

Data: 2026-06-23

Comportamento entregue:

- MAR-189 movida para `Done` no Linear.
- Evidência final registrada em comentário na MAR-189.
- Comentário de reconciliação registrado na MAR-171.
- Status update publicado no projeto MMD.
- Relação `blocked by MAR-189` removida de MAR-172 a MAR-186.
- Label `blocked-prod` removido de MAR-172 a MAR-186.
- MAR-188 manteve o bloqueio de produção, porque depende de RFD40, signing, iPhone físico e tags reais.

Evidência Linear:

- Comentário final MAR-189: `221ece78-28d8-4c9b-8439-20fd39bfcaaa`.
- Comentário de reconciliação MAR-171: `c5f003cf-ef01-4c22-b64d-4f5437b5156d`.
- Status update do projeto MMD: `aef4b63e-5382-4843-a3a0-509448a1462f`.

Estado operacional:

- Supabase real não bloqueia mais as verticais web/mobile.
- As verticais continuam dependendo dos próprios gates de implementação e QA.
- O blocker real restante do goal é físico/mobile em MAR-188.
