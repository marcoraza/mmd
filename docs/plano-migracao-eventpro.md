# Plano de execução: migração MMD legado → EventPro

Data: 2026-08-05
Base: `docs/auditoria-migracao-eventpro.md` (inventário completo do que é portável, gaps e riscos).

Este documento embala a migração inteira num plano único de 7 fases, com execução detalhada de cada passo: entregáveis, tarefas concretas, gates de validação e dependências. As fases 1 a 4 são sequenciais no backend. A fase 6 (iOS) e a fase 7 (UI 2.0) rodam em paralelo a partir da fase 4, desde que os contratos estejam congelados.

Princípios que valem para o plano inteiro:

- Contrato primeiro. Os shapes de `/api/eventos/*` e `/api/rfid/scans` são congelados no início e só mudam por decisão explícita, para o iOS e a UI 2.0 migrarem sem big bang.
- Nada de porte cego. Cada item portado entra com seu teste; cada dívida marcada na auditoria (race de alocação, `uuid[]` sem FK, fallback de colunas) é resolvida na fase em que o código é tocado, não replicada.
- O legado continua operando durante toda a migração. O corte é por ambiente (projeto Supabase novo + deploy novo), não por branch dentro do produto vivo.

---

## Fase 1: Schema base EventPro

**Objetivo:** projeto Supabase novo com o schema core limpo, sem os vícios estruturais do legado.

**Entregáveis:** conjunto de migrations `0001..000N` do EventPro; `supabase/config.toml` versionado; seed de desenvolvimento separado do schema.

**Execução:**

1. Criar projeto Supabase EventPro (staging primeiro; produção só na fase 5).
2. Portar os enums de domínio, com `MONTAGEM` já oficial em `status_projeto_enum` (decisão registrada na auditoria).
3. Portar as tabelas core: `items`, `serial_numbers`, `projetos` (avaliar rename para `eventos` já que o produto fala Evento), `packing_list`, `packing_templates`, `movimentacoes`, `checkout_overrides`, `retorno_pendencias`, `rfid_readers`, `rfid_scans`, `profiles`.
4. Correções estruturais embutidas no schema novo (não portar o defeito):
   - `packing_allocations` relacional (packing_id, serial_id, UNIQUE por serial ativo) no lugar de `serial_numbers_designados uuid[]`;
   - índices de `packing_list` (`projeto_id`, e UNIQUE `(projeto_id, item_id)`);
   - `registrado_por` como FK para `profiles` nas tabelas de auditoria, mantendo coluna de label para exibição;
   - trigger de `updated_at` em `rfid_readers` (faltava no legado);
   - prefixo do código interno configurável (tabela de config ou GUC), não hardcoded `MMD-`;
   - constraint impedindo a mesma `tag_rfid` em duas entidades (se lotes históricos forem herdados).
5. Portar o padrão de segurança: schema `app_private` + `current_user_role()`, RLS por role em todas as tabelas (matriz da auditoria §1.3), grants explícitos, `handle_new_user`.
6. Portar a máquina de estados do evento já com a matriz corrigida de `20260805194500_projeto_status_montagem_transition.sql` (inclui `MONTAGEM` e `ELSE` fail-closed).
7. Storage: recriar buckets de comercial e imports com policies de storage explícitas (o legado não tinha nenhuma).

**Gate de saída:** `supabase db reset --local` limpo; `db lint` e `db advisors` sem erro; simulação RLS por role (viewer bloqueado em escrita, editor cria, admin apaga) passando.

**Depende de:** nada. É o primeiro passo.

---

## Fase 2: RPCs de negócio

**Objetivo:** as 4 RPCs que concentram a regra operacional, adaptadas ao schema novo.

**Execução:**

1. Portar `checkout_projeto`, `checkout_projeto_com_override`, `checkin_projeto`, `resolver_retorno_pendencia` adaptando leituras de `serial_numbers_designados` para `packing_allocations`.
2. Derivar o autor de `auth.uid()` dentro das RPCs quando houver sessão, mantendo o parâmetro `registrado_por` só como fallback de service role. Manter EXECUTE restrito a `service_role` (padrão anti-spoofing do legado).
3. Nova RPC `auto_allocate_packing(packing_id)` com `SELECT ... FOR UPDATE SKIP LOCKED`, eliminando a race conhecida do `autoAllocate` do legado (TODO documentado no código).
4. Nova RPC (ou função) de conferência RFID: recebe `projeto_id` + lista de tags lidas, resolve contra as alocações e devolve `confirmados / faltantes / extras / desconhecidas`, gravando os scans com contexto. É o fechamento do loop RFID ↔ operação (gap principal da auditoria §4.1).
5. Portar os testes de contrato que leem o SQL (`checkout-rpc-contract`, `projeto-status-guard-contract`) apontando para as migrations novas, incluindo asserts de grants (regressão da ordem de grants do legado, risco §5.5).

**Gate de saída:** suíte de contrato verde; teste manual das 4 RPCs via SQL com os 3 caminhos de retorno (OK, PROBLEMA, NAO_VOLTOU) e override.

**Depende de:** fase 1.

---

## Fase 3: Libs core + camada de dados

**Objetivo:** o cérebro TypeScript portado com testes, e a camada de I/O reescrita limpa.

**Execução:**

1. Copiar os ~20 módulos `*-core.ts` com suas suítes (lista completa na auditoria §2.1). São puros; a única adaptação esperada é tipo/naming se `projetos` virar `eventos`.
2. Reescrever `src/lib/data/*` contra o schema novo: sem fallback progressivo de colunas (morre o `PGRST204` handling), leituras de alocação via `packing_allocations`.
3. Reescrever `src/lib/actions/*` quebrando o monólito de 1.496 linhas por domínio (evento, packing, alocação, movimentação, rfid, comercial); `autoAllocate` e `setAllocation` passam a delegar às RPCs da fase 2.
4. Decidir e configurar o modelo de acesso: manter service role + autorização na aplicação (como o legado) ou mover leituras para o client autenticado com RLS efetiva. Registrar a decisão em ADR (risco §5.3).
5. Portar `action-auth-core` / `auth-config` com um ajuste: eliminar o fallback de admin sem login, ou restringi-lo a `NODE_ENV=development` explícito (risco §5.2). Definir default de `MMD_READONLY`/equivalente consciente (risco §5.4).

**Gate de saída:** `node --test` completo verde; typecheck e lint zerados; nenhuma referência a fallback de coluna ou `uuid[]` no código novo.

**Depende de:** fases 1 e 2.

---

## Fase 4: BFF e contratos de API

**Objetivo:** superfície HTTP compatível com o iOS atual + endpoints que faltavam.

**Execução:**

1. Recriar preservando shape: `POST /api/eventos/[id]/checkout`, `POST /api/eventos/[id]/retorno`, `GET /api/eventos/[id]/resumo`, `POST /api/rfid/scans`. Mesmos códigos de erro (`invalid_json`, `metodo_invalido`, etc.) e mesma auth Bearer → `profiles.role`.
2. Novos endpoints:
   - `POST /api/eventos/[id]/conferencia-rfid` expondo a RPC de conferência da fase 2;
   - busca de seriais para vínculo de tag (o iOS hoje busca client-side em memória, não escala);
   - vínculo de tag genérico (não restrito a cabo), com validação de unicidade e histórico.
3. `POST /api/qr-sheet` refatorado: cliente manda IDs, servidor resolve dados e gera o PDF em chunks (evita o 504 de seleções grandes).
4. Congelar os contratos: documento curto de contrato por endpoint (request/response/erros) versionado no repo, que passa a ser a referência para iOS e UI 2.0.
5. Smoke test autenticado por endpoint em staging.

**Gate de saída:** app iOS legado apontado para o staging EventPro executa checkout e retorno de um evento de teste sem alteração de código no app.

**Depende de:** fase 3. **Libera:** fases 6 e 7 em paralelo.

---

## Fase 5: Migração de dados

**Objetivo:** o estoque real e o histórico dentro do EventPro, sem carregar lixo.

**Execução:**

1. Script de carga lendo do Supabase legado (não do seed SQL de `00001`): `items`, `serial_numbers` (com tags e QRs), `profiles`.
2. Converter `serial_numbers_designados` dos eventos ativos em linhas de `packing_allocations`.
3. Decisões de escopo a confirmar com Marcelo antes de rodar:
   - histórico Event Pro (16 eventos, issues, candidatos): levar como histórico read-only ou encerrar no legado;
   - lotes legados: levar como consulta histórica ou arquivar;
   - movimentações históricas: levar tudo ou a partir de uma data de corte.
4. Rodar em staging, validar contagens (paridade item a item com o legado), depois rodar em produção com o legado em modo somente leitura durante a janela.
5. Verificação pós-carga: contagens por status, tags únicas, QRs únicos, eventos ativos com alocação íntegra.

**Gate de saída:** relatório de paridade legado × EventPro sem divergência não explicada; smoke das telas principais com dados reais.

**Depende de:** fase 4 estável. É a última fase antes do corte de produção.

---

## Fase 6: iOS (paralela a partir da fase 4)

**Objetivo:** app de campo EventPro com RFID real pela primeira vez.

**Execução:**

1. **Pré-requisito bloqueante, iniciar já:** obter o Zebra iOS RFID SDK oficial com versão fixada, iPhone físico, RFD40, conta de dev com signing. Sem isso a fase inteira trava (o legado nunca teve o SDK no projeto).
2. Portar em bloco, sem reescrita: `RFIDReaderProtocol`, `MockRFIDManager`, `RFIDManager` (fachada), models (`SerialNumber`, `Equipment`, `Project`, `PackingListItem`), contratos de `Movement.swift`, `QRScanView` (adicionando checagem de permissão de câmera), núcleo HTTP do `APIClient` e a suíte de testes.
3. Reescrever `ZebraRFIDManager` do zero contra os headers reais do SDK (prefixo `SRFID_`, não as constantes `CYCLOPSEVENT_*` inventadas do legado), com: potência de antena configurável (essencial para conferência por proximidade), RSSI e bateria expostos, batch mode, `deinit` limpo com desregistro de delegate, callbacks serializados em fila dedicada.
4. Corrigir o bug de ordenação: preservar ordem de leitura das tags ou expor `lastReadTag` (a tela de vincular tag depende disso).
5. Auth real: login Supabase no app, token em Keychain com refresh, fim do JWT colado em Ajustes.
6. Aposentar os caminhos de escrita direta no PostgREST (`registerCheckout`, `registerReturn`, `linkTag` via PATCH); toda mutação via BFF. Home passa a consumir `GET /api/eventos/[id]/resumo`.
7. Limpezas de projeto: `Info.plist` (`arm64` no lugar de `armv7`, validar strings MFi do RFD40 com a doc do SDK, remover chaves deprecadas), remover código de demo dos ViewModels, remover as duas gerações de UI antigas.
8. Validação física em galpão: parear RFD40, ler tags reais, executar um checkout e um retorno completos de evento de teste.

**Gate de saída:** checkout e retorno reais via RFID em device físico, gravados no Supabase EventPro com operador correto; TestFlight instalável.

**Depende de:** contratos congelados (fase 4) + hardware/SDK (item 1).

---

## Fase 7: UI 2.0 (paralela a partir da fase 4)

**Objetivo:** o layout 2.0 do Claude design consumindo os mesmos contratos, incluindo as telas que o legado nunca teve.

**Execução:**

1. Montar a casca do EventPro (rotas, navegação, auth) sobre a camada de dados da fase 3. Telas core na ordem de valor operacional: dashboard → eventos/detalhe (packing, alocação, checkout, retorno) → catálogo/unidades → QR → RFID.
2. Telas novas (gaps do legado):
   - administração de usuários e roles;
   - fila de revisão de importação (`event_import_issues` / `catalog_item_candidates`, 313 pendências e 89 candidatos sem UI hoje), se o histórico Event Pro for herdado na fase 5;
   - conferência RFID de evento (consome o endpoint da fase 4): lista confirmados/faltantes/extras ao vivo durante carregamento e retorno.
3. Manter os invariantes de produto: QR público continua expondo apenas código, item, categoria e status colapsado (a política e os testes de `public-qr` vêm da fase 3); packing continua usando `computePackingCoverage` como verdade única de cobertura.
4. QA por tela com screenshot desktop + mobile, como no processo atual.

**Gate de saída:** operação completa de um evento (ficha → packing → alocação → checkout → retorno com pendência → resolução) executada só pela UI 2.0 contra staging.

**Depende de:** fase 4. Design independe do backend e pode começar antes; a integração espera os contratos.

---

## Corte final e critérios de aceite

1. Fase 5 aplicada em produção com paridade verificada.
2. Uma semana de operação assistida: legado em somente leitura, EventPro como sistema primário, comparação diária de movimentações.
3. Aceite: um evento real completo (checkout via RFID no galpão pelo iPhone, retorno com pendência resolvida no web) sem tocar no legado.
4. Descomissionar: legado arquivado (banco exportado, repo taggeado), DNS/URLs apontando para o EventPro.

## Riscos monitorados durante o plano

| Risco | Mitigação no plano |
|---|---|
| SDK Zebra/hardware atrasar | Fase 6 item 1 começa junto com a fase 1; mock mantém desenvolvimento destravado |
| Drift de contrato entre web e iOS | Contratos congelados e versionados na fase 4; iOS legado usado como teste de compatibilidade |
| Migração de dados divergente | Dry-run em staging com relatório de paridade antes de produção |
| Config de ambiente abrir admin sem login | Fallback eliminado na fase 3; checklist de env no deploy |
| Replay de grants reabrir RPC para authenticated | Testes de contrato de grants na fase 2 |
