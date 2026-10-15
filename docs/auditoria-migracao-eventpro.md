# Auditoria de migração: MMD Estoque (legado) → EventPro

Data: 2026-08-05
Escopo: inventário completo do que precisa ser portado do legado MMD para o EventPro (layout 2.0) — estrutura RFID, SDK Zebra, backend Supabase e regras de negócio. A UI não entra no escopo de porte: o layout 2.0 substitui o design Liquid Glass.

Sumário executivo:

- **O backend Supabase é o maior ativo.** 4 RPCs `SECURITY DEFINER` concentram praticamente toda a regra operacional (check-out, override auditado, check-in com pendência, resolução de pendência). Modelo de dados de 15 tabelas, RLS por role madura e testes de contrato que leem o próprio SQL.
- **A camada `*-core.ts` do web é portável 1:1.** ~20 módulos puros, testados, sem I/O: gate de saída, conferência de retorno, alocação FIFO, cobertura de packing, import de planilha, ficha, comercial, RFID scan, QR público seguro.
- **O SDK Zebra não existe no repositório.** `ZebraRFIDManager.swift` nunca compilou contra o SDK real (está atrás de `#if canImport(ZebraRfidSdkFramework)`, que nunca é verdadeiro). O app iOS sempre rodou com mock e nunca leu uma tag RFID real. O que é portável no iOS é a abstração (`RFIDReaderProtocol`, mock, fachada, models e contratos de API) — o manager Zebra precisa ser reescrito do zero contra headers reais.
- **O loop RFID ↔ operação não fecha no banco.** `rfid_scans` é telemetria paralela; nenhuma RPC lê ou escreve scans. Não existe conferência física "tags lidas × packing list". É o principal gap funcional a resolver no EventPro, não só a portar.
- **3 riscos ativos:** o status `MONTAGEM` não é coberto pelo trigger de transição de status (aborta check-out de eventos importados); `requireActionUser` devolve admin sem login quando auth não é exigida pelo ambiente; todo o caminho web usa service role (RLS não protege o caminho principal).

---

## 1. Backend Supabase — o que portar

Base: `supabase/migrations/` (18 arquivos, ~3.600 linhas). Não há `config.toml`, seed ou Edge Functions no repo. Projeto remoto: `bphmxticdyuctovfumcj`.

### 1.1 Modelo de dados core (portar)

| Grupo | Tabelas | Nota |
|---|---|---|
| Inventário | `items`, `serial_numbers` | `codigo_interno` `MMD-XXX-NNNN` autogerado por trigger com advisory lock; `serial_numbers` carrega `status`, `desgaste` (1–5), `tag_rfid` UNIQUE, `qr_code` UNIQUE, valor |
| Operação | `projetos`, `packing_list`, `packing_templates`, `movimentacoes`, `checkout_overrides`, `retorno_pendencias` | `projetos` acumulou ficha (`ficha_evento` jsonb), comercial (`comercial` jsonb) e metadados de importação |
| RFID | `rfid_readers`, `rfid_scans` | leitores RFD40 (status, bateria, última atividade) + log bruto de leitura com 8 contextos e RSSI |
| Auth | `profiles` | 1:1 com `auth.users`, roles `viewer`/`editor`/`admin`, criada por trigger `handle_new_user` |

Enums de domínio a portar: `categoria_enum` (8 categorias), `status_serial_enum` (8 estados), `estado_enum`, `status_projeto_enum` (com `MONTAGEM` — ver risco 5.1), `tipo_movimentacao_enum`, `metodo_scan_enum` (`RFID|QRCODE|MANUAL`), `contexto_scan_enum`, `user_role_enum`.

### 1.2 RPCs de negócio (o coração do sistema — portar integralmente)

Todas `SECURITY DEFINER`, `search_path=public`, EXECUTE **apenas para `service_role`** (anti-spoofing de `registrado_por` — chamada só via servidor).

| RPC | Regra encapsulada |
|---|---|
| `checkout_projeto(projeto, metodo, registrado_por)` | Trava evento e seriais `FOR UPDATE`; exige `CONFIRMADO`/`MONTAGEM`; readiness 100% por linha (seriais próprios + aluguéis avulsos); todos os seriais `DISPONIVEL`; grava `movimentacoes SAIDA` antes de mutar; seriais e evento → `EM_CAMPO`. Tolera evento 100% terceirizado |
| `checkout_projeto_com_override(..., override_id)` | Mesmo fluxo sem checagem de readiness; exige registro prévio em `checkout_overrides` (motivo ≥10 chars, snapshot de blockers/warnings/checks, insert restrito a admin por RLS); carimba `executado_em` |
| `checkin_projeto(projeto, metodo, registrado_por, items jsonb)` | Cobertura total obrigatória (sem duplicata/unexpected/missing vs. seriais `EM_CAMPO` do packing); `OK→DISPONIVEL`, `PROBLEMA→MANUTENCAO` (obs ≥3 chars), `NAO_VOLTOU→RETORNANDO` + UPSERT em `retorno_pendencias`; evento só finaliza sem pendência aberta |
| `resolver_retorno_pendencia(pendencia, acao, obs, registrado_por)` | `ENCONTRADA→DISPONIVEL`, `MANUTENCAO`, `BAIXA`, `COBRANCA` (não altera serial); sempre grava movimentação; fecha evento ao zerar pendências |

Também portar: `enforce_projeto_status_transition` (máquina de estados do evento no banco — corrigindo o bug de `MONTAGEM`), padrão `app_private.current_user_role()` + RLS por role, `set_updated_at`, geração de `codigo_interno`.

### 1.3 Padrão de segurança (portar como arquitetura)

- RLS habilitada em todas as tabelas; matriz consistente: leitura para `authenticated`, escrita `editor`/`admin`, delete `admin`; `movimentacoes` e `rfid_scans` só admin edita/apaga (trilha); `checkout_overrides` e `retorno_pendencias` sem DELETE para ninguém (append-only).
- Helper de role em schema privado (`app_private`) para não expor RPC na Data API.
- Auditoria distribuída: `movimentacoes` (estado físico), `checkout_overrides` (exceções), `retorno_pendencias` (perdas), sem tabela `audit_log` central.
- **Corrigir no EventPro:** `registrado_por` é `text` livre (não FK para `profiles`); derivar o autor de `auth.uid()` dentro da RPC ou manter o revoke de EXECUTE como hoje.

### 1.4 Não portar como está

- **Seed de inventário dentro de `00001_initial_schema.sql`** (277 items, 520 seriais, 50 lotes): separar schema de data-load.
- **Prefixo `MMD-` hardcoded** em `generate_item_codigo_interno()`: tornar configurável.
- `lotes` — legado declarado (unit-only desde MAR-187); portar só como dado histórico read-only, se necessário.
- Bloco Event Pro (`event_import_batches`, `event_import_files`, `catalog_item_candidates`, `event_import_issues`, colunas `importacao_*`): importação one-off de planilha. Atenção: o status `MONTAGEM` e as versões atuais das RPCs de checkout "vazaram" dessa importação para o core — decidir se `MONTAGEM` vira status oficial do EventPro (recomendado: sim, já é comportamento de produto).
- `00004_inline_edit_policies.sql` (writes anônimos, já revertidos), `00005` (vazio), `20260623180914` (limpeza de drift): ruído histórico.
- Buckets `mmd-evento-comercial` (10 MB, PDF/DOC/imagens) e `mmd-event-pro-imports` (20 MB, xlsx) criados via `INSERT INTO storage.buckets` **sem policies de storage** — no EventPro, criar policies explícitas ou manter acesso exclusivo via service role + signed URLs conscientemente.

---

## 2. Web app (BFF + regras) — o que portar

Arquitetura atual: Next.js 16 App Router; escrita via Server Actions; rotas `/api/*` existem como BFF para o iOS. Três clients Supabase: browser (anon, quase sem uso), `supabaseAdmin` (service role, todo o caminho server) e cookie client SSR para auth.

### 2.1 Camada pura `*-core.ts` — portar 1:1 (com os testes)

| Módulo | Regra |
|---|---|
| `checkout-gate-core.ts` | Gate de saída: 5 checks (ficha, packing, cobertura, conflitos, checklist) com severidade, `readinessPct`, `canCheckout`/`canOverride`, motivo de override ≥10 chars |
| `checkout-execution-core.ts` | Plano de execução: recalcula alocação real, `invalid_seriais` como hard blocker (nem override libera), simulação espelho da RPC |
| `return-resolution-core.ts` | Conferência de retorno: clamp de desgaste, outcomes `OK/PROBLEMA/NAO_VOLTOU`, resoluções `ENCONTRADA/MANUTENCAO/BAIXA/COBRANCA` |
| `allocation-core.ts` | FIFO rotacional de seriais (nunca movidos primeiro, depois `last_moved_at` mais antigo), estados de selecionabilidade, auto-alocação |
| `external-rental-core.ts` | `computePackingCoverage` — unidade de verdade de cobertura (próprio + aluguel avulso) usada em todo o produto |
| `packing-import-core.ts` + `packing-import-file.ts` | Import de planilha: aliases de cabeçalho/categoria, match por código MMD ou textual, parser XLSX/CSV robusto |
| `packing-suggestion-core.ts` | Sugestão por similaridade histórica (cliente/nome/local) + templates; rascunho de IA nunca grava sem aplicação manual |
| `evento-ficha-core.ts` | Contrato JSONB versionado da ficha (13 campos obrigatórios), completude e checklist que alimentam o gate |
| `evento-comercial-core.ts` | Funil comercial leve; `statusAllowsEstoque` só a partir de `ORCAMENTO_APROVADO` |
| `rfid-scan-core.ts` | Normalização de tag, validação, plano de scan (tag desconhecida também é gravada), padrão `RfidScanRepository` (port/adapter) |
| `public-qr.ts` + `internal-qr-core.ts` | Sanitização anti-injeção de filtro PostgREST; política de não-vazamento do QR público (invariante testado) |
| `dashboard-core.ts` | Readiness com teto de 50% se há pendência aberta, status de evento, tipo de evento |
| `action-auth-core.ts`, `auth-config.ts`, `demo-mode-core.ts` | Modelo de roles, rotas públicas/protegidas, modos de dados |
| `item-label.ts`, `nomenclature.ts`, `types.ts` | Normalização dos dados sujos da planilha original + enums de domínio |

~20 suítes de teste (`node --test`) acompanham esses módulos de graça — inclusive `checkout-rpc-contract.test.ts`, que lê o SQL das migrations e valida ordem de locks e grants.

### 2.2 Contratos de API — preservar shape durante a transição

Consumidos pelo iOS hoje; manter compatíveis para migrar mobile sem big bang:

- `POST /api/eventos/[id]/checkout` (role `editor`; override exige `admin`)
- `POST /api/eventos/[id]/retorno` (role `editor`)
- `GET /api/eventos/[id]/resumo` (role `viewer`; **hoje não consumido pelo iOS** — economia óbvia no EventPro)
- `POST /api/rfid/scans` (role `editor`; upsert de leitor + resolução de tags + insert de scans; retorna `resolved/unresolved/scan_ids`)
- `POST /api/qr-sheet` (PDF de etiquetas; refatorar para "cliente manda IDs, servidor resolve")

Auth: `requireRequestUser` (Bearer JWT Supabase → `profiles.role`) para iOS; cookie SSR + `proxy.ts` para web.

### 2.3 Portar com refatoração

- `src/lib/actions/*` — regras corretas, mas: quebrar o arquivo de 1.496 linhas; `autoAllocate` tem race conhecida (TODO no código) → virar RPC com `FOR UPDATE SKIP LOCKED`; `setAllocation` faz presence-check manual porque `serial_numbers_designados` é `uuid[]` sem FK → no EventPro, modelar como tabela de junção `packing_allocations`.
- `src/lib/data/*` — agregações valem; **matar o fallback progressivo de colunas** (8 tentativas de select em `project-detail.ts` detectando `PGRST204`), que é débito de migration desalinhada.
- Import Event Pro (`import-event-pro-events.ts` + `event-pro-import-core.ts`) — portar só se o EventPro for herdar os dados históricos importados; o core (parse de datas pt-BR, classificação de linhas, `EVT-AAMMDD-NN`) é reutilizável para qualquer import futuro.

### 2.4 Descartar

- `src/components/**` (Liquid Glass, `Primitives.tsx`) — exceto `components/qrcodes/layouts.ts` (medidas físicas de etiqueta A4 = dado de negócio) e dicionários de label usados por libs.
- `useItemMutation.ts` (escrita client-side com anon key) — eliminar o caminho; toda escrita via action/API auditada.
- `data/demo.ts` (888 linhas de fixture) e `withDemoFallback` — substituir por seeds de ambiente.
- Rotas mock: `/projetos/ficha` (estático), `/config` (só localStorage).

---

## 3. iOS — RFID e SDK Zebra

Base: `apps/ios/MMDEstoque` (15.908 linhas Swift, XcodeGen, iOS 16+, iPhone only, sem signing configurado).

### 3.1 Achado crítico: o SDK Zebra nunca esteve no projeto

- `project.yml` só declara `ExternalAccessory.framework` e `CoreBluetooth.framework`. Não há SPM, framework vendorizado, Podfile ou versão fixada do SDK Zebra em lugar nenhum.
- Todo `ZebraRFIDManager.swift` está sob `#if canImport(ZebraRfidSdkFramework)` — **condição nunca verdadeira**; em runtime a factory sempre cai no `MockRFIDManager`.
- O código Zebra usa constantes com prefixo `CYCLOPSEVENT_*` que não correspondem ao SDK real (prefixo `SRFID_*`), tem 14 comentários `TODO: Verify`, data races nos callbacks do delegate, sem `deinit`/desregistro, e **zero configuração de antena/potência/RSSI/bateria** — sem controle de potência, o RFD40 lê o galpão inteiro e a conferência de packing por proximidade não funciona.

**Conclusão: `ZebraRFIDManager.swift` deve ser reescrito do zero contra o SDK oficial. Pré-requisito bloqueante do EventPro mobile: obter o Zebra iOS RFID SDK (versão fixada), iPhone físico, RFD40 e signing.**

### 3.2 O que é portável no iOS

| Ativo | Por quê |
|---|---|
| `RFIDReaderProtocol.swift` | Abstração hardware-agnóstica bem desenhada (`RFIDReaderInfo`, `RFIDConnectionState`, ações discover/connect/inventory) — copiar inteira, é o contrato que a reescrita do manager deve honrar |
| `MockRFIDManager.swift` | Mock completo (leitores falsos, handshake com falha aleatória, EPCs SGTIN-96 realistas) — permite desenvolver a UI do EventPro sem hardware |
| `RFIDManager.swift` | Fachada Combine→SwiftUI com injeção de factory e troca a quente mock/real |
| Models (`SerialNumber`, `Equipment`, `Project`, `PackingListItem`) | Espelham o schema Supabase 1:1 com `CodingKeys` explícitas |
| `Movement.swift` (seção de contratos) | `CheckoutProject*`, `ReturnProject*`, `RfidScan*` — contrato canônico compartilhado com o web; maior ativo do app |
| `QRScanView.swift` (coordinator + view AVFoundation) | Scanner QR puro com debounce 2s; só falta checagem de permissão de câmera |
| `APIClient.swift` (núcleo HTTP) | `URLSession` puro, decode de datas ISO8601 dupla, paginação por header `Range`, erros tipados em pt-BR |
| Lógica dos ViewModels (Checkout/Return/Home) | Casamento packing↔scan, dedupe, `buildReturnProjectItems`, cálculo de prontidão — regras reais |
| `MMDEstoqueTests/` | Rede de segurança pronta (RFIDManager, APIClient, models) |

### 3.3 Corrigir na portagem

- **Auth inexistente no iOS:** o operador cola um JWT manualmente em Ajustes (`UserDefaults`); sem login, sem Keychain, sem refresh. EventPro precisa de auth Supabase real.
- **Aposentar os caminhos legados de escrita direta no PostgREST** (`registerCheckout`/`registerReturn`/`linkTag` via PATCH) — toda mutação via `/api/*`.
- Bug latente: `scannedTags` é publicado ordenado alfabeticamente e a tela de vincular tag usa `.last` como "última lida" — preservar ordem de leitura ou expor `lastReadTag`.
- Consumir `GET /api/eventos/[id]/resumo` em vez de agregar client-side na Home.
- `Info.plist`: `UISupportedExternalAccessoryProtocols` tem só `com.zebra.rfd8x00_easytext` (nunca validado contra RFD40 real); `UIRequiredDeviceCapabilities: armv7` obsoleto (→ `arm64`); remover `NSBluetoothPeripheralUsageDescription` (deprecado) e `NSLocalNetworkUsageDescription` (desnecessário para MFi).
- Limpar acoplamentos de design na camada de dados: `ResolvedItem` importa SwiftUI; `validationColor` retorna tokens do design antigo; código de demo (`-demoScan`) dentro dos ViewModels.
- Descartar: as duas gerações de UI (~2.400 linhas do design "Nothing" morto + toda a pasta `Views/Liquid` e `Onboarding/`), `LiquidItemLostView` (geiger "PRÉVIA" decorativo — virar feature real exige RSSI do SDK).

---

## 4. Gaps funcionais (a construir no EventPro, não a portar)

1. **Fechar o loop RFID ↔ operação.** Hoje `rfid_scans` é telemetria: nenhuma RPC cruza scans com checkout/checkin, e não existe endpoint de conferência física (tags lidas × seriais alocados → faltantes/extras). É a promessa central do produto e não existe no legado.
2. **Vínculo de tag genérico.** O binding RFID web é restrito a cabos (`categoria = 'CABO'`); não há histórico de re-tagueamento nem status de etiqueta. No banco, nada impede a mesma tag em `serial_numbers` e `lotes` simultaneamente.
3. **Tela de administração.** Não existe rota de gestão de usuários/roles nem painel para `event_import_issues`/`catalog_item_candidates` (313 pendências e 89 candidatos sem UI).
4. **RSSI/proximidade ("achar item")** depende de capacidades do SDK real nunca implementadas.
5. **Índices e integridade:** `packing_list` sem índice além da PK (tabela mais consultada do app) e sem UNIQUE `(projeto_id, item_id)`; `serial_numbers_designados uuid[]` sem integridade referencial.

## 5. Riscos ativos levados em conta na migração

1. **Bug: `MONTAGEM` × trigger de transição.** `20260712191500_projeto_status_transition_guard.sql` não cobria `MONTAGEM` no `CASE` (sem `ELSE` → `CASE_NOT_FOUND`). Evento importado em `MONTAGEM` não mudava de status — inclusive o `UPDATE` interno do `checkout_projeto` falhava, abortando o check-out. **Corrigido em `20260805194500_projeto_status_montagem_transition.sql`** (matriz completa + `ELSE` fail-closed); levar a matriz corrigida para o schema do EventPro.
2. **Admin sem login.** `requireActionUser` devolve admin local quando `isAuthRequiredForEnv()` é falso. Config de env divergente no EventPro = acesso irrestrito.
3. **Service role em todo o caminho web.** RLS não protege o caminho principal; a barreira é a checagem de role na aplicação. Decisão consciente a reavaliar no EventPro.
4. **`MMD_READONLY` default `true`** — deploy novo esquece a env e o app fica read-only silenciosamente.
5. **Ordem de grants nas migrations:** replay fora de ordem de `20260623081000`/`083000` reabre `checkout_projeto` para `authenticated` (spoofing de `registrado_por`).

## 6. Ordem recomendada de porte

1. **Schema base EventPro** (novo projeto Supabase): enums + tabelas core + `app_private` + RLS, separando seed/data-load de schema; corrigir `MONTAGEM` na máquina de estados; `packing_allocations` relacional no lugar do `uuid[]`; índices de `packing_list`; `registrado_por` derivado de `auth.uid()`.
2. **RPCs**: portar as 4 RPCs de negócio + trigger de transição, mantendo o padrão service-role-only; adicionar RPC de auto-alocação atômica (`FOR UPDATE SKIP LOCKED`).
3. **Libs core + testes**: copiar os `*-core.ts` e suítes; refazer só a camada `data/` e `actions/` contra o schema novo, sem fallback de colunas.
4. **BFF**: recriar `/api/eventos/*` e `/api/rfid/scans` preservando os shapes atuais (compatibilidade com o iOS durante a transição); adicionar o endpoint de conferência RFID × packing (gap 4.1) e `resumo` para o mobile.
5. **Migração de dados**: script de carga do inventário real (a partir do Supabase legado, não do seed SQL) + decisão sobre histórico Event Pro e lotes legados.
6. **iOS**: portar em bloco protocolo + mock + fachada + models + contratos + testes; obter SDK Zebra oficial, hardware e signing (bloqueante); reescrever `ZebraRFIDManager` com potência de antena, RSSI, bateria e lifecycle limpo; auth real com Keychain.
7. **UI 2.0**: telas novas do EventPro consumindo os mesmos contratos — incluindo as telas que faltam (admin/roles, fila de revisão, conferência RFID).
