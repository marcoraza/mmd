# Contratos de API do EventPro

Versão do documento: 1.0
Data: 2026-08-05
Fase: 4 do plano de migração (`docs/plano-migracao-eventpro.md`), item 4 "congelar os contratos"
Escopo: superfície HTTP consumida pelo app iOS e, a partir do EventPro, também pela UI 2.0

Este documento é a referência única de request, response e erro por endpoint. Endpoints marcados
como **CONGELADO** descrevem o comportamento real do legado (`apps/web/src/app/api/**`) e devem ser
reproduzidos byte a byte no EventPro, para que o app iOS legado consiga apontar para o staging novo
sem alteração de código (gate de saída da fase 4). Endpoints marcados como **NOVO** são proposta,
ainda não implementada, e podem mudar até a aprovação.

Fontes de verdade lidas para escrever este documento:

| Camada | Arquivo |
|---|---|
| Rotas | `apps/web/src/app/api/eventos/[id]/checkout/route.ts`, `.../retorno/route.ts`, `.../resumo/route.ts`, `apps/web/src/app/api/rfid/scans/route.ts`, `apps/web/src/app/api/qr-sheet/route.ts` |
| Regras puras | `apps/web/src/lib/rfid-scan-core.ts`, `return-resolution-core.ts`, `checkout-gate-core.ts`, `checkout-execution-core.ts` |
| Orquestração | `apps/web/src/lib/actions/movimentacoes.ts`, `apps/web/src/lib/actions/rfid-scans.ts`, `apps/web/src/lib/data/evento-resumo.ts` |
| Auth | `apps/web/src/lib/action-auth.ts`, `action-auth-core.ts`, `auth-config.ts` |
| Banco | `supabase/migrations/00007_loop_operacional.sql`, `20260623094805_return_pending_resolution.sql`, `20260623193758_event_pro_import_official.sql`, `20260805194500_projeto_status_montagem_transition.sql` |
| Consumidor iOS | `apps/ios/MMDEstoque/MMDEstoque/Models/Movement.swift`, `Services/APIClient.swift`, `ViewModels/CheckoutViewModel.swift`, `ViewModels/ReturnViewModel.swift` |

---

## 1. Convenções gerais

### 1.1 Transporte

- Base URL: configurada no cliente (`AppConfig.shared.webApiUrl` no iOS). Todas as rotas abaixo são
  relativas a essa base.
- `Content-Type: application/json` no request (exceto onde indicado). O iOS também envia
  `Accept: application/json`.
- Todas as rotas de leitura e escrita rodam com `runtime = 'nodejs'` e `dynamic = 'force-dynamic'`.
- Respostas de sucesso JSON carregam `Cache-Control: private, no-store` (exceto `/api/qr-sheet`, que
  usa `Cache-Control: no-store` e devolve binário).

### 1.2 Formato de erro

Todo erro é um objeto com uma única chave:

```json
{ "error": "invalid_json" }
```

O valor tem dois formatos convivendo no legado, e o congelamento preserva os dois:

1. **Código estável em snake_case**, produzido pela própria rota: `invalid_json`, `metodo_invalido`,
   `items_invalidos`, `tags_invalidas`, `not_found`, `no_items`, `invalid_layout`, `unauthorized`.
   Esses são contrato de máquina.
2. **Frase em português**, produzida pela camada de auth, pelas libs de regra ou repassada do
   Postgres (`error.message` do Supabase). Exemplo: `"Evento não encontrado."`,
   `"Check-out requer Evento CONFIRMADO ou MONTAGEM (atual: PLANEJAMENTO)"`. Essas frases são
   texto de operador, não código de máquina, e não devem ser usadas em `switch` no cliente.

O EventPro deve manter os códigos do grupo 1 idênticos. Frases do grupo 2 podem ser reescritas em
uma versão futura deste documento, desde que o status HTTP permaneça o mesmo.

### 1.3 Autenticação

Implementada em `requireRequestUser(req, requiredRole)` (`apps/web/src/lib/action-auth.ts`):

1. Se `isAuthRequiredForEnv()` é falso, a função devolve **admin local sem nenhuma verificação**
   (`userId: null`, `role: 'admin'`, `registradoPor: process.env.MMD_LOCAL_OPERATOR || 'Marco'`).
   Esse é o risco 5.2 da auditoria. `isAuthRequiredForEnv()` lê `MMD_REQUIRE_AUTH` ou
   `NEXT_PUBLIC_MMD_REQUIRE_AUTH`; sem essas variáveis, cai no modo de dados (`real` exige auth).
2. Havendo `Authorization: Bearer <jwt>`, o token é validado com `supabaseAdmin.auth.getUser(token)`.
3. **Sem header `Authorization`, cai para `requireActionUser`**, que usa o cookie SSR do Supabase.
   Ou seja: a mesma rota aceita Bearer (iOS) e cookie (web) no mesmo caminho de código.
4. Com o usuário verificado, lê `profiles.role` e compara por rank:
   `viewer (0) < editor (1) < admin (2)`. Role ausente ou desconhecida normaliza para `viewer`.

`registradoPor` (gravado em `movimentacoes.registrado_por` e `rfid_scans.operador`) é derivado por
`operatorLabel`: `profiles.nome`, senão `profiles.email`, senão o e-mail do JWT, senão o id, senão
`"Usuário MMD"`.

Mensagens de negativa (`actionDeniedMessage`):

| Role exigida | Mensagem |
|---|---|
| `admin` | `Ação restrita ao usuário admin.` |
| `editor` | `Ação restrita à equipe operacional.` |
| `viewer` | `Acesso interno: faça login novamente.` |

**Congelado com ressalva:** falha de role devolve **401**, não 403. É semanticamente errado mas o
iOS trata qualquer 4xx igual, então mudar isso é mudança de contrato e exige nova versão do
documento.

### 1.4 Ordem de validação

Não é uniforme, e a ordem faz parte do contrato observável:

| Rota | Ordem real |
|---|---|
| `checkout` | JSON, `metodo`, params, **auth**, regra |
| `retorno` | JSON, `metodo`, `items`, params, **auth**, regra |
| `resumo` | **auth**, params, carga |
| `rfid/scans` | **auth**, JSON, payload, regra |
| `qr-sheet` | **auth (cookie)**, JSON, `items`, `layout` |

Consequência: em `checkout` e `retorno`, um chamador não autenticado com corpo inválido recebe
**400**, não 401. Preservar.

### 1.5 Modo somente leitura

`isWriteBlocked()` (`apps/web/src/lib/data/demo-mode.ts`) bloqueia toda escrita quando o modo de
dados é `demo` **ou** quando `MMD_READONLY` não está explicitamente desligada. O default é `true`.
Nessa condição, checkout, retorno e rfid/scans respondem **400** com
`{"error":"Modo somente leitura: alterações não são salvas."}`. É o risco 5.4 da auditoria e a causa
mais provável de um smoke test de staging falhar sem motivo aparente.

---

## 2. POST /api/eventos/[id]/checkout

**Status: CONGELADO**
Arquivo: `apps/web/src/app/api/eventos/[id]/checkout/route.ts`

### 2.1 Identificação

| Campo | Valor |
|---|---|
| Método | `POST` |
| Path | `/api/eventos/{id}/checkout` |
| `{id}` | uuid do evento (`projetos.id`). Não é validado como uuid na rota; um valor inválido só falha na consulta |
| Role mínima | `editor`. Override (evento com blocker) exige `admin` |
| Auth | `Authorization: Bearer <jwt>` (iOS) ou cookie SSR (web) |

### 2.2 Request body

| Campo | Tipo | Obrigatório | Validação |
|---|---|---|---|
| `metodo` | string | sim | Exatamente `RFID`, `QRCODE` ou `MANUAL`. Comparação sensível a maiúsculas, sem trim |
| `overrideReason` | string | não | `readString`: precisa ser string com conteúdo após `trim()`; strings vazias viram `undefined`. Quando o gate bloqueia, o motivo normalizado (`trim` + colapso de espaços) deve ter no mínimo 10 caracteres |

Nota de nomenclatura: `overrideReason` é o único campo camelCase de toda a superfície HTTP. Todo o
resto é snake_case. Congelado por compatibilidade com `CheckoutProjectRequest` do iOS.

```json
{
  "metodo": "RFID",
  "overrideReason": "Cliente aceitou sair com 2 refletores a menos"
}
```

### 2.3 Response 200

```json
{
  "count": 2,
  "seriais": [
    { "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01", "codigo_interno": "MMD-ILU-0001" },
    { "serial_id": "6f3b9d2a-1c44-4a11-b1b7-9a1b2c3d4e5f", "codigo_interno": "MMD-ILU-0002" }
  ]
}
```

`count` é o número de linhas devolvidas pela RPC (`checkout_projeto` ou
`checkout_projeto_com_override`), que retorna `TABLE(serial_id uuid, codigo_interno text)`. Um evento
100 por cento terceirizado retorna `count: 0` com `seriais: []` e isso é sucesso.

### 2.4 Fluxo de decisão do override

1. Carrega o evento e recalcula o gate (`buildCheckoutGate`) e o plano de execução
   (`buildCheckoutExecutionPlan`).
2. `hardBlockers` aborta antes de qualquer RPC, **inclusive com override** (serial alocado fora de
   `DISPONIVEL`, método inválido).
3. Se `gate.canCheckout`, chama `checkout_projeto`.
4. Se não, e `gate.canOverride` e o usuário é `admin` e o motivo tem 10 ou mais caracteres: grava
   `checkout_overrides` (com snapshot de blockers, warnings, checks e `readiness_pct`) e chama
   `checkout_projeto_com_override`.
5. `gate.canOverride` é falso quando o status do evento não é `CONFIRMADO` nem `MONTAGEM`. Nesse
   caso nem admin passa.

### 2.5 Erros

| HTTP | Body | Origem |
|---|---|---|
| 400 | `{"error":"invalid_json"}` | corpo não é JSON parseável |
| 400 | `{"error":"metodo_invalido"}` | `metodo` ausente ou fora de `RFID\|QRCODE\|MANUAL` |
| 401 | `{"error":"Acesso interno: faça login novamente."}` | sem Bearer e sem cookie, token inválido, ou usuário não encontrado |
| 401 | `{"error":"Ação restrita à equipe operacional."}` | autenticado como `viewer` |
| 401 | `{"error":"<mensagem do Supabase>"}` | falha ao consultar `profiles` |
| 400 | `{"error":"Modo somente leitura: alterações não são salvas."}` | `MMD_READONLY` ligada ou modo demo |
| 400 | `{"error":"Evento não encontrado."}` | id inexistente. **Não é 404** |
| 400 | `{"error":"Método de scan inválido."}` | hard blocker do plano de execução |
| 400 | `{"error":"3 seriais próprios não estão DISPONIVEL."}` | hard blocker, nem override libera |
| 400 | `{"error":"Evento precisa estar Confirmado ou em Montagem antes do check-out."}` | gate sem override possível |
| 400 | `{"error":"Ficha incompleta: falta Responsável, Local, Horário."}` | primeiro blocker do gate quando o override não é possível |
| 400 | `{"error":"Ação restrita ao usuário admin."}` | override tentado por `editor`. **400, não 401** |
| 400 | `{"error":"Motivo do override deve ter pelo menos 10 caracteres."}` | override sem motivo suficiente |
| 400 | `{"error":"Check-out requer Evento CONFIRMADO ou MONTAGEM (atual: PLANEJAMENTO)"}` | RPC |
| 400 | `{"error":"Packing list incompleto em 2 linha(s). Aloque seriais próprios ou registre aluguel avulso antes do check-out."}` | RPC |
| 400 | `{"error":"1 serial(is) não estão DISPONIVEL. Check-out abortado."}` | RPC, corrida entre gate e execução |
| 400 | `{"error":"Transição inválida: PLANEJAMENTO -> EM_CAMPO"}` | trigger `enforce_projeto_status_transition` |

Regra de mapeamento de status usada pela rota: `result.error.includes('login') ? 401 : 400`. Ou seja,
qualquer erro cuja frase contenha "login" vira 401; todo o resto vira 400. Preservar essa regra ou
substituí-la por um mapa explícito em versão nova do documento.

### 2.6 Compatibilidade com o iOS

O iOS chama por `APIClient.checkoutProject(projectId:metodoScan:overrideReason:)` e envia:

```json
{ "metodo": "RFID" }
```

- `overrideReason` é `String?` e o `JSONEncoder` sintetizado omite o campo quando é nil, então o
  corpo real do caminho feliz tem só `metodo`.
- `projectId.uuidString` do Swift é **maiúsculo**, então o path chega como
  `/api/eventos/1F2B7C1E-.../checkout`. O Postgres aceita uuid case-insensitive; qualquer comparação
  textual de id no EventPro precisa normalizar.
- A resposta é decodificada em `CheckoutProjectResponse` (`count`, `seriais[].serial_id`,
  `seriais[].codigo_interno`). Campo extra na resposta é ignorado pelo decoder; campo faltante
  quebra o decode. Portanto: **adicionar campo é seguro, remover ou renomear não é**.
- `Authorization` só é enviado se o token colado em Ajustes não estiver vazio (ver seção 9).

---

## 3. POST /api/eventos/[id]/retorno

**Status: CONGELADO**
Arquivo: `apps/web/src/app/api/eventos/[id]/retorno/route.ts`

### 3.1 Identificação

| Campo | Valor |
|---|---|
| Método | `POST` |
| Path | `/api/eventos/{id}/retorno` |
| Role mínima | `editor` |
| Auth | Bearer ou cookie |

### 3.2 Request body

| Campo | Tipo | Obrigatório | Validação |
|---|---|---|---|
| `metodo` | string | sim | `RFID`, `QRCODE` ou `MANUAL`, exato |
| `items` | array | sim | Precisa ser array. Array vazio **passa** nesta checagem e falha depois na regra |
| `items[].serial_id` | string | sim | String não vazia após `trim()`. Sem validação de uuid na rota |
| `items[].resultado` | string | sim | `OK`, `PROBLEMA` ou `NAO_VOLTOU`, exato e maiúsculo |
| `items[].desgaste` | number | não | `parseDesgaste`: aceita number ou string numérica, arredonda, default 3 se não finito. A rota **não** limita a faixa; `clampDesgaste` limita a 1..5 depois |
| `items[].observacao` | string ou null | não | `trim()`, vira `null` se vazia. Truncada em 240 caracteres por `normalizeObservation`. Obrigatória com no mínimo 3 caracteres quando `resultado = PROBLEMA` |

Diferença importante entre camadas: `normalizeReturnOutcome` (core) aceita o campo legado
`needs_maintenance: boolean` como fallback, e aceita `resultado` em minúsculas com espaços. **A rota
HTTP não aceita nenhum dos dois**: `parseResultado` exige match exato na lista. Um item que traga só
`needs_maintenance` recebe `items_invalidos`. O contrato HTTP é o estrito.

```json
{
  "metodo": "RFID",
  "items": [
    { "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01", "desgaste": 4, "resultado": "OK" },
    {
      "serial_id": "6f3b9d2a-1c44-4a11-b1b7-9a1b2c3d4e5f",
      "desgaste": 2,
      "resultado": "PROBLEMA",
      "observacao": "Cabo de força com mau contato"
    },
    { "serial_id": "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d", "desgaste": 3, "resultado": "NAO_VOLTOU" }
  ]
}
```

### 3.3 Response 200

```json
{
  "count": 3,
  "seriais": [
    {
      "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01",
      "codigo_interno": "MMD-ILU-0001",
      "novo_status": "DISPONIVEL"
    },
    {
      "serial_id": "6f3b9d2a-1c44-4a11-b1b7-9a1b2c3d4e5f",
      "codigo_interno": "MMD-CAB-0044",
      "novo_status": "MANUTENCAO"
    },
    {
      "serial_id": "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d",
      "codigo_interno": "MMD-AUD-0012",
      "novo_status": "RETORNANDO"
    }
  ]
}
```

Destino por resultado (`returnDestination`, espelhado na RPC `checkin_projeto`):

| `resultado` | `novo_status` | Abre pendência |
|---|---|---|
| `OK` | `DISPONIVEL` | não |
| `PROBLEMA` | `MANUTENCAO` | não |
| `NAO_VOLTOU` | `RETORNANDO` | sim, upsert em `retorno_pendencias` |

O evento só transita para `FINALIZADO` quando não sobra pendência aberta.

### 3.4 Cobertura total obrigatória

A RPC exige que a lista enviada seja **exatamente** o conjunto de seriais próprios `EM_CAMPO`
alocados no evento. Sem duplicata, sem serial de fora, sem faltante. Retorno parcial não existe:
ou a conferência está completa, ou a chamada falha inteira.

### 3.5 Erros

| HTTP | Body | Origem |
|---|---|---|
| 400 | `{"error":"invalid_json"}` | corpo não parseável |
| 400 | `{"error":"metodo_invalido"}` | `metodo` fora do enum |
| 400 | `{"error":"items_invalidos"}` | `items` não é array, ou algum elemento não é objeto, ou `serial_id` vazio, ou `resultado` fora do enum |
| 401 | `{"error":"Acesso interno: faça login novamente."}` | não autenticado |
| 401 | `{"error":"Ação restrita à equipe operacional."}` | role `viewer` |
| 400 | `{"error":"Modo somente leitura: alterações não são salvas."}` | `MMD_READONLY` |
| 400 | `{"error":"Nada pra receber de volta."}` | `items: []` (passa por `items_invalidos`, cai aqui) |
| 400 | `{"error":"Unidade de retorno inválida."}` | `serial_id` vazio visto pelo core |
| 400 | `{"error":"Unidade duplicada no retorno."}` | mesmo `serial_id` duas vezes |
| 400 | `{"error":"Unidade com problema precisa de observação do Evento."}` | `PROBLEMA` sem observação de 3 ou mais caracteres |
| 400 | `{"error":"Evento <uuid> não encontrado"}` | RPC |
| 400 | `{"error":"Retorno requer Evento EM_CAMPO (atual: CONFIRMADO)"}` | RPC |
| 400 | `{"error":"Lista de unidades vazia"}` | RPC |
| 400 | `{"error":"Nenhuma unidade própria em campo para retorno"}` | RPC, evento 100 por cento terceirizado |
| 400 | `{"error":"Lista de retorno contém unidade duplicada"}` | RPC |
| 400 | `{"error":"Lista de retorno não bate com as unidades que saíram neste Evento"}` | RPC, faltante ou extra |
| 400 | `{"error":"2 unidade(s) não estão EM_CAMPO. Retorno abortado."}` | RPC |
| 400 | `{"error":"Resultado de retorno inválido"}` | RPC (inalcançável pela rota, que já filtrou) |

### 3.6 Compatibilidade com o iOS

`APIClient.returnProject(projectId:metodoScan:items:)` com `ReturnProjectRequest`. O corpo real
gerado por `ReturnViewModel.buildReturnProjectItems()`:

```json
{
  "metodo": "RFID",
  "items": [
    { "serial_id": "1F2B7C1E-4A63-4F0E-9D70-9C2A1F9F1A01", "desgaste": 4, "resultado": "OK" }
  ]
}
```

- `serial_id` chega em **maiúsculas** (`UUID.uuidString`).
- `observacao` nil é omitida do JSON.
- O app **nunca envia `NAO_VOLTOU`** e **omite itens ainda pendentes** da conferência. Ver seção 9,
  divergência D1: é uma incompatibilidade real com a cobertura total exigida pela RPC.
- Resposta decodificada em `ReturnProjectResponse` (`count`, `seriais[].serial_id`,
  `seriais[].codigo_interno`, `seriais[].novo_status`), todos obrigatórios no decoder.

---

## 4. GET /api/eventos/[id]/resumo

**Status: CONGELADO**
Arquivo: `apps/web/src/app/api/eventos/[id]/resumo/route.ts`

### 4.1 Identificação

| Campo | Valor |
|---|---|
| Método | `GET` |
| Path | `/api/eventos/{id}/resumo` |
| Role mínima | `viewer` |
| Auth | Bearer ou cookie |
| Query | nenhuma |
| Body | nenhum |

### 4.2 Response 200

Shape exato do tipo `EventoResumo` (`apps/web/src/lib/data/evento-resumo.ts`):

```json
{
  "id": "3c0d2f11-6b8a-4d55-9a10-0b7e2c4f8d31",
  "nome": "Festival Verão 2026",
  "cliente": "Prefeitura de Ilhabela",
  "data_inicio": "2026-08-14",
  "data_fim": "2026-08-16",
  "local": "Praça Central",
  "status": "CONFIRMADO",
  "notas": null,
  "ficha_evento": null,
  "packing": {
    "linhas": 12,
    "itens_total": 87,
    "itens_alocados": 81,
    "readiness_pct": 93
  }
}
```

| Campo | Tipo | Nota |
|---|---|---|
| `id`, `nome` | string | sempre presentes |
| `cliente`, `local`, `notas` | string ou null | |
| `data_inicio`, `data_fim` | string `YYYY-MM-DD` | coluna `date` do Postgres |
| `status` | enum | `PLANEJAMENTO`, `CONFIRMADO`, `MONTAGEM`, `EM_CAMPO`, `FINALIZADO`, `CANCELADO` |
| `ficha_evento` | objeto jsonb ou null | contrato versionado em `evento-ficha-core.ts` |
| `packing.linhas` | int | número de linhas do packing list |
| `packing.itens_total` | int | soma de `quantidade` |
| `packing.itens_alocados` | int | soma de `computePackingCoverage(...).qtd_coberta`, ou seja próprio mais aluguel avulso |
| `packing.readiness_pct` | int 0..100 | `round(itens_alocados / itens_total * 100)`, 0 quando `itens_total = 0` |

### 4.3 Erros

| HTTP | Body | Origem |
|---|---|---|
| 401 | `{"error":"Acesso interno: faça login novamente."}` | não autenticado |
| 404 | `{"error":"not_found"}` | evento inexistente (aqui sim é 404, ao contrário do checkout) |
| 500 | resposta de erro do Next | exceção não tratada na carga, quando o fallback demo está desligado |

### 4.4 Compatibilidade com o iOS

**Nenhuma. O app iOS nunca chama este endpoint.** A Home agrega tudo client-side via PostgREST
(`fetchProjects`, `fetchPackingList`, `fetchSerialSnapshot` paginado por header `Range`). Passar a
consumir `resumo` é item do plano (fase 6a, passo 6) e economia de rede óbvia, mas não é requisito
do gate de saída da fase 4.

Detalhe herdado a **não** portar: `loadEventoResumo` tenta a mesma query até 4 vezes, removendo
`ficha_evento` e depois `alugueis_avulsos` do select quando o Postgres reclama (`PGRST204`). É débito
de migration desalinhada, não contrato. No EventPro o select é único.

---

## 5. POST /api/rfid/scans

**Status: CONGELADO**
Arquivo: `apps/web/src/app/api/rfid/scans/route.ts`, validação em `parseRfidScanPayload`

### 5.1 Identificação

| Campo | Valor |
|---|---|
| Método | `POST` |
| Path | `/api/rfid/scans` |
| Role mínima | `editor` |
| Auth | Bearer ou cookie. **Auth é verificada antes do parse do corpo** |

### 5.2 Request body

| Campo | Tipo | Obrigatório | Validação |
|---|---|---|---|
| `tags` | string[] | sim | Elementos não string são descartados. Cada tag passa por `normalizeRfidTag`: `trim()`, `toUpperCase()`, remoção de espaços, `:` e `-`. Depois deduplicação preservando a ordem de chegada. O array resultante precisa ser não vazio e **toda** tag precisa casar com `/^[A-Z0-9]+$/` e ter comprimento entre 8 e 96 |
| `contexto` | string | não | Um de `PACKING`, `CARREGAMENTO`, `CHECK_IN_EVENTO`, `CHECK_OUT_EVENTO`, `RETORNO`, `CONFERENCIA`, `INVENTARIO`, `OUTRO`. **Valor ausente ou inválido não é erro: cai silenciosamente em `INVENTARIO`** |
| `projeto_id` | string ou null | não | String com conteúdo após trim, guardada **sem trim** (o valor original é o que vai para o banco). Não é validada como uuid: um valor não uuid só falha no insert, virando erro do Postgres |
| `localizacao` | string ou null | não | `trim()`, vira null se vazia |
| `reader` | objeto ou null | não | Ver 5.3 |

Uma única tag inválida invalida o lote inteiro (`tags_invalidas`). Não há aceite parcial.

### 5.3 Objeto `reader`

| Campo | Tipo | Validação |
|---|---|---|
| `nome` | string | `trim()`, `undefined` se vazio. Default no insert: `Zebra RFD40` |
| `modelo` | string | `trim()`, `undefined` se vazio. Default no insert: `Zebra RFD40` |
| `serial_fabrica` | string ou null | `trim()`, null se vazio. **Chave do upsert**: sem ele, o leitor não é gravado e `reader_id` fica null nos scans |
| `bateria` | number ou null | arredondada e limitada a 0..100. Valor não numérico vira null |

O upsert em `rfid_readers` usa `onConflict: serial_fabrica` e carimba `status: 'ATIVO'`, `operador`,
`ultima_atividade` e `updated_at` com o instante da chamada.

```json
{
  "tags": ["E28011700000020D1A2B3C4D", "E28011700000020D1A2B3C4E"],
  "contexto": "CHECK_OUT_EVENTO",
  "projeto_id": "3c0d2f11-6b8a-4d55-9a10-0b7e2c4f8d31",
  "localizacao": "Galpão 1",
  "reader": {
    "nome": "RFD40 Marcelo",
    "modelo": "Zebra RFD40",
    "serial_fabrica": "RFD4090-ABC123",
    "bateria": 87
  }
}
```

### 5.4 Response 200

```json
{
  "resolved": [
    {
      "tag_rfid": "E28011700000020D1A2B3C4D",
      "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01",
      "codigo_interno": "MMD-ILU-0001",
      "item_nome": "Moving Head Beam 230"
    }
  ],
  "unresolved": ["E28011700000020D1A2B3C4E"],
  "scan_ids": [
    "0a1b2c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d",
    "1b2c3d4e-5f6a-4b7c-9d8e-1f2a3b4c5d6e"
  ]
}
```

- `resolved`: tags que casaram com `serial_numbers.tag_rfid`. `item_nome` pode ser null.
- `unresolved`: tags normalizadas sem serial correspondente.
- `scan_ids`: ids das linhas gravadas em `rfid_scans`, **uma por tag do lote**, resolvida ou não.
  `resolved.length + unresolved.length === scan_ids.length`.
- Tag desconhecida é gravada mesmo assim, com `serial_number_id: null` e
  `notas: "Tag RFID não reconhecida"`. Isso é intencional (onboarding e auditoria).
- `rssi` é sempre gravado como null: o plano de scan suporta `rssiByTag`, mas **o parser HTTP não
  aceita RSSI**. Não há como enviar RSSI por esta API hoje.

Este endpoint é telemetria pura: não altera status de serial, não altera status de evento, nenhuma
RPC lê `rfid_scans`. Fechar esse loop é o endpoint novo da seção 8.

### 5.5 Erros

| HTTP | Body | Origem |
|---|---|---|
| 401 | `{"error":"Acesso interno: faça login novamente."}` | não autenticado |
| 401 | `{"error":"Ação restrita à equipe operacional."}` | role `viewer` |
| 400 | `{"error":"invalid_json"}` | corpo não parseável (verificado **depois** da auth) |
| 400 | `{"error":"tags_invalidas"}` | `tags` ausente, vazio, ou com tag fora de `[A-Z0-9]{8,96}` após normalização |
| 400 | `{"error":"Modo somente leitura: alterações não são salvas."}` | `MMD_READONLY` |
| 400 | `{"error":"Leitor RFID sem serial de fábrica."}` | defensivo no repositório, inalcançável pela rota |
| 400 | `{"error":"<mensagem do Supabase>"}` | falha no upsert do leitor, na busca de seriais ou no insert de scans. Inclui `projeto_id` que não é uuid e `contexto` fora do enum do banco |

### 5.6 Compatibilidade com o iOS

`APIClient.recordRfidScans(tags:contexto:projectId:reader:)` monta `RfidScanRequest`:

```json
{
  "tags": ["E28011700000020D1A2B3C4D"],
  "contexto": "CHECK_OUT_EVENTO",
  "projeto_id": "3C0D2F11-6B8A-4D55-9A10-0B7E2C4F8D31",
  "reader": {
    "nome": "RFD40 Marcelo",
    "modelo": "Zebra RFD40",
    "serial_fabrica": "RFD4090-ABC123",
    "bateria": 87
  }
}
```

- **`localizacao` não existe em `RfidScanRequest`.** Todo scan vindo do app grava `localizacao` null.
- Contextos realmente usados pelo app: `CHECK_OUT_EVENTO` (CheckoutViewModel), `RETORNO`
  (ReturnViewModel), `INVENTARIO` (IdentificarFlow). Os outros cinco existem no enum e no banco mas
  nenhuma tela os emite.
- O app envia tags **cruas** do leitor. Ver divergência D2 na seção 9.
- `RfidScanResponse` decodifica `scan_ids` como `[UUID]`: enviar um id que não seja uuid quebra o
  app.

---

## 6. POST /api/qr-sheet

**Status: CONGELADO com refatoração prevista**
Arquivo: `apps/web/src/app/api/qr-sheet/route.ts`

### 6.1 Identificação

| Campo | Valor |
|---|---|
| Método | `POST` |
| Path | `/api/qr-sheet` |
| Role mínima | **nenhuma checagem de role** |
| Auth | **Somente cookie SSR** (`getVerifiedUser`), e só quando `isAuthRequiredForEnv()` é verdadeiro. **Bearer não é aceito**: esta é a única rota que não passa por `requireRequestUser` |
| Resposta | `application/pdf` (binário), não JSON |
| `maxDuration` | 60 s |

### 6.2 Request body

| Campo | Tipo | Obrigatório | Validação |
|---|---|---|---|
| `items` | array de `QrItem` | sim | Precisa existir e ter comprimento maior que zero. **Nenhuma validação por item** |
| `items[].payload` | string | sim de fato | Conteúdo codificado no QR. Usado direto em `QRCode.toDataURL` |
| `items[].title` | string | sim de fato | Linha principal da etiqueta (código) |
| `items[].subtitle` | string | não | Nome do item |
| `items[].caption` | string | não | Chip pequeno (categoria ou status) |
| `layout` | string | sim | Chave existente em `QR_LAYOUTS`: `small`, `medium` ou `large` |

Layouts (`apps/web/src/components/qrcodes/layouts.ts`, medidas físicas são dado de negócio):

| Chave | Rótulo | Por folha | Célula |
|---|---|---|---|
| `small` | Pequena (3x10) | 30 | 63,5 x 38,1 mm |
| `medium` | Média (2x7) | 14 | 99,1 x 38,1 mm |
| `large` | Grande (1x8) | 8 | 190 x 31 mm |

```json
{
  "layout": "small",
  "items": [
    {
      "payload": "https://mmd.example/s/MMD-ILU-0001",
      "title": "MMD-ILU-0001",
      "subtitle": "Moving Head Beam 230",
      "caption": "ILUMINACAO"
    }
  ]
}
```

### 6.3 Response 200

Corpo binário PDF. Headers:

```
Content-Type: application/pdf
Content-Disposition: attachment; filename="qr-sheet-small-1785859200000.pdf"
Cache-Control: no-store
```

QR gerado com `errorCorrectionLevel: 'M'`, `margin: 0`, `width: 512`, preto sobre branco. Paginação
em folhas de `layout.perSheet` etiquetas.

### 6.4 Erros

| HTTP | Body | Origem |
|---|---|---|
| 401 | `{"error":"unauthorized"}` | auth exigida pelo ambiente e sem sessão por cookie. Note o código em inglês, diferente de todas as outras rotas |
| 400 | `{"error":"invalid_json"}` | corpo não parseável |
| 400 | `{"error":"no_items"}` | `items` ausente, null ou vazio |
| 400 | `{"error":"invalid_layout"}` | `layout` fora de `small\|medium\|large` |
| 504 | resposta da plataforma | seleção grande estourando o tempo da função. Tratado no cliente web com mensagem específica |

### 6.5 Compatibilidade com o iOS

Nenhuma: o app iOS não gera etiquetas. E não conseguiria: sem Bearer aceito, qualquer chamada do app
em ambiente com auth exigida recebe 401.

### 6.6 Refatoração prevista (fase 4, item 3)

O contrato atual faz o cliente enviar `payload`, `title`, `subtitle` e `caption` já resolvidos, ou
seja, o servidor confia em texto arbitrário do cliente para o conteúdo do QR. A versão EventPro
deve inverter: cliente manda `serial_ids` mais `layout`, servidor resolve os dados e gera o PDF em
chunks. Essa inversão **quebra o contrato** e por isso entra como versão 2.0 deste documento, com o
shape antigo aceito durante a transição, ou não aceito, mediante decisão explícita.

---

## 7. POST /api/eventos/[id]/conferencia-rfid

**Status: NOVO, proposto, não implementado**
Preenche o gap 4.1 da auditoria (fechar o loop RFID versus operação) e o item 2 da fase 4.

### 7.1 Identificação

| Campo | Valor |
|---|---|
| Método | `POST` |
| Path | `/api/eventos/{id}/conferencia-rfid` |
| Role mínima | `editor` (grava scans) |
| Auth | Bearer ou cookie |
| Ordem de validação proposta | auth, JSON, payload, evento, regra (igual a `/api/rfid/scans`, não a `checkout`) |

### 7.2 Request body

| Campo | Tipo | Obrigatório | Validação |
|---|---|---|---|
| `tags` | string[] | sim | **Exatamente a mesma normalização e validação de `/api/rfid/scans`**: `normalizeRfidTag`, deduplicação com ordem preservada, não vazio, cada tag em `[A-Z0-9]{8,96}` |
| `contexto` | string | sim | Restrito a `CARREGAMENTO`, `RETORNO` ou `CONFERENCIA`. **Diferente de `/api/rfid/scans`, aqui contexto ausente ou inválido é erro, não default** |
| `reader` | objeto ou null | não | Mesmo shape e mesmas regras do `reader` de `/api/rfid/scans` (`nome`, `modelo`, `serial_fabrica`, `bateria` 0..100) |
| `localizacao` | string ou null | não | Aditivo, mesma normalização de `/api/rfid/scans` |

```json
{
  "tags": ["E28011700000020D1A2B3C4D", "E28011700000020D1A2B3C4E", "E28011700000020DFFFFFFFF"],
  "contexto": "CARREGAMENTO",
  "reader": {
    "modelo": "Zebra RFD40",
    "serial_fabrica": "RFD4090-ABC123",
    "bateria": 71
  }
}
```

### 7.3 Semântica

Universo esperado: os seriais alocados ao evento, ou seja, a união de
`packing_list.serial_numbers_designados` das linhas do evento (no EventPro, as linhas de
`packing_allocations`). Aluguel avulso não entra: não tem tag da MMD.

| Bucket | Definição |
|---|---|
| `confirmados` | tag lida que resolve para um serial alocado neste evento |
| `faltantes` | serial alocado ao evento que não apareceu na leitura |
| `extras` | tag lida que resolve para um serial conhecido, mas **não** alocado a este evento |
| `desconhecidas` | tag lida que não resolve para nenhum serial |

Efeitos colaterais: grava uma linha em `rfid_scans` por tag lida, com `projeto_id = {id}`,
`contexto` do request, `operador = registradoPor` e `reader_id` do upsert, exatamente com a mesma
semântica de `/api/rfid/scans` (tag desconhecida também é gravada, com
`notas: "Tag RFID não reconhecida"`). **Não muta status de serial nem status de evento.** Conferência
é leitura mais telemetria; a mutação continua sendo checkout e retorno.

Chamadas repetidas são seguras: cada chamada grava um novo lote de scans e recalcula os buckets do
zero. Não é idempotente no log, é idempotente no resultado.

### 7.4 Response 200

Campos obrigatórios do contrato proposto (`confirmados`, `faltantes`, `extras`, `desconhecidas`)
mais campos aditivos (`evento`, `contexto`, `resumo`, `scan_ids`) que o cliente pode ignorar:

```json
{
  "evento": {
    "id": "3c0d2f11-6b8a-4d55-9a10-0b7e2c4f8d31",
    "nome": "Festival Verão 2026",
    "status": "MONTAGEM"
  },
  "contexto": "CARREGAMENTO",
  "confirmados": [
    {
      "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01",
      "codigo_interno": "MMD-ILU-0001",
      "item_nome": "Moving Head Beam 230",
      "tag_rfid": "E28011700000020D1A2B3C4D"
    }
  ],
  "faltantes": [
    {
      "serial_id": "6f3b9d2a-1c44-4a11-b1b7-9a1b2c3d4e5f",
      "codigo_interno": "MMD-AUD-0012",
      "item_nome": "Caixa Ativa 15\"",
      "tag_rfid": null
    }
  ],
  "extras": [
    {
      "serial_id": "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d",
      "codigo_interno": "MMD-CAB-0044",
      "item_nome": "Cabo XLR 10m",
      "tag_rfid": "E28011700000020D1A2B3C4E"
    }
  ],
  "desconhecidas": ["E28011700000020DFFFFFFFF"],
  "resumo": {
    "esperados": 2,
    "confirmados": 1,
    "faltantes": 1,
    "extras": 1,
    "desconhecidas": 1,
    "cobertura_pct": 50
  },
  "scan_ids": [
    "0a1b2c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d",
    "1b2c3d4e-5f6a-4b7c-9d8e-1f2a3b4c5d6e",
    "2c3d4e5f-6a7b-4c8d-9e0f-2a3b4c5d6e7f"
  ]
}
```

| Campo | Tipo | Nota |
|---|---|---|
| `confirmados[]`, `extras[]` | objeto | `serial_id`, `codigo_interno`, `item_nome` (pode ser null), `tag_rfid` (a tag normalizada que foi lida) |
| `faltantes[]` | objeto | mesmos campos, `tag_rfid` é a tag cadastrada no serial e é **null quando o serial não tem tag vinculada**, que é justamente o caso a destacar na UI |
| `desconhecidas` | string[] | tags normalizadas, na ordem de leitura |
| `resumo.cobertura_pct` | int 0..100 | `round(confirmados / esperados * 100)`, 0 quando `esperados = 0` |
| `scan_ids` | uuid[] | uma entrada por tag lida, mesma garantia de `/api/rfid/scans` |

Invariantes: `confirmados.length + extras.length + desconhecidas.length === tags.length` (tags já
deduplicadas) e `confirmados.length + faltantes.length === resumo.esperados`.

### 7.5 Erros propostos

| HTTP | Body | Quando |
|---|---|---|
| 401 | `{"error":"Acesso interno: faça login novamente."}` | não autenticado |
| 401 | `{"error":"Ação restrita à equipe operacional."}` | role `viewer` |
| 400 | `{"error":"invalid_json"}` | corpo não parseável |
| 400 | `{"error":"tags_invalidas"}` | mesma regra de `/api/rfid/scans` |
| 400 | `{"error":"contexto_invalido"}` | ausente ou fora de `CARREGAMENTO\|RETORNO\|CONFERENCIA` |
| 404 | `{"error":"not_found"}` | evento inexistente. Segue `resumo`, não `checkout` |
| 400 | `{"error":"Modo somente leitura: alterações não são salvas."}` | `MMD_READONLY` |
| 400 | `{"error":"<mensagem do Supabase>"}` | falha no upsert do leitor ou no insert de scans |

Ponto em aberto para aprovação: evento sem nenhum serial alocado responde **200** com
`esperados: 0` e todas as leituras em `extras` ou `desconhecidas` (proposta), ou 400 com
`evento_sem_alocacao`. A proposta é 200: conferência de evento vazio é informação válida, não erro.

---

## 8. GET /api/seriais/busca

**Status: NOVO, proposto, não implementado**
Substitui a busca client-side em memória do iOS (`FindSerialStep` em
`apps/ios/.../Views/Liquid/LiquidVincularTagView.swift`, que hoje baixa **todo** o catálogo por
`fetchItems()` e filtra em memória por código, nome, marca e modelo, depois baixa os seriais do item
escolhido). Não escala e não é a fronteira certa.

### 8.1 Identificação

| Campo | Valor |
|---|---|
| Método | `GET` |
| Path | `/api/seriais/busca` |
| Role mínima | `viewer` |
| Auth | Bearer ou cookie |
| Body | nenhum |

### 8.2 Query params

| Param | Tipo | Obrigatório | Validação |
|---|---|---|---|
| `q` | string | não | `trim()`. Se presente, 2 a 64 caracteres. Precisa passar pela sanitização anti-injeção de filtro PostgREST, no mesmo espírito de `normalizeInternalQrLookupCode` (`/^[A-Za-z0-9._:\- ]+$/`, sem vírgula, parêntese, aspas ou `*`). Busca case-insensitive em `codigo_interno`, `serial_fabrica`, `items.nome`, `items.marca` e `items.modelo` |
| `item_id` | uuid | não | Precisa ser uuid válido. Restringe ao tipo de item |
| `sem_tag` | boolean | não | `true` devolve só seriais com `tag_rfid` null. Aditivo, para o fluxo de vincular tag |
| `limit` | int | não | Default 25, máximo 100 |
| `offset` | int | não | Default 0, mínimo 0 |

Sem `q` e sem `item_id`, devolve a primeira página ordenada por `codigo_interno` ascendente. Ordem
estável e determinística é requisito, para paginação não repetir nem pular linhas.

```
GET /api/seriais/busca?q=beam%20230&sem_tag=true&limit=25
GET /api/seriais/busca?item_id=8f1c0a22-9d3e-4b77-a6c1-5e2d7f0b1234&limit=50&offset=50
```

### 8.3 Response 200

```json
{
  "items": [
    {
      "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01",
      "codigo_interno": "MMD-ILU-0001",
      "item_nome": "Moving Head Beam 230",
      "tag_rfid": "E28011700000020D1A2B3C4D"
    },
    {
      "serial_id": "2a3b4c5d-6e7f-4a8b-9c0d-1e2f3a4b5c6d",
      "codigo_interno": "MMD-ILU-0002",
      "item_nome": "Moving Head Beam 230",
      "tag_rfid": null
    }
  ],
  "total": 42,
  "limit": 25,
  "offset": 0,
  "has_more": true
}
```

| Campo | Tipo | Nota |
|---|---|---|
| `items[].serial_id` | uuid | `serial_numbers.id` |
| `items[].codigo_interno` | string | `MMD-XXX-NNNN` |
| `items[].item_nome` | string ou null | nome do item pai |
| `items[].tag_rfid` | string ou null | **null quando o serial ainda não tem tag**, que é o caso alvo do fluxo de vínculo |
| `total` | int | total de linhas que casam com o filtro, ignorando paginação |
| `limit`, `offset` | int | ecoam o efetivamente aplicado, já com default e teto |
| `has_more` | boolean | `offset + items.length < total` |

O envelope existe para carregar a paginação. Se a decisão for devolver array puro, isso precisa ser
resolvido **antes** do congelamento: array puro e envelope não são compatíveis de forma aditiva.

Nada de valor, depreciação, localização ou histórico entra nesta resposta. É busca de vínculo, não
consulta de patrimônio.

### 8.4 Erros propostos

| HTTP | Body | Quando |
|---|---|---|
| 401 | `{"error":"Acesso interno: faça login novamente."}` | não autenticado |
| 400 | `{"error":"parametros_invalidos"}` | `q` fora de 2..64 ou com caractere proibido, `item_id` não uuid, `limit` ou `offset` não inteiros ou negativos |
| 400 | `{"error":"<mensagem do Supabase>"}` | falha na consulta |

Nota: `limit` acima de 100 **não** é erro, é silenciosamente reduzido a 100. Igual ao tratamento de
`bateria` em `/api/rfid/scans`, que limita em vez de rejeitar.

---

## 8b. POST /api/rfid/vinculo

Status: **NOVO** (implementado junto com o BFF EventPro). Fecha o gap 4.2 da auditoria: o legado
não tinha endpoint de vínculo e o iOS fazia PATCH direto no PostgREST, caminho aposentado.

- Auth: Bearer ou cookie, role mínima `editor` (mesma regra de `/api/rfid/scans`).
- Ordem de validação: auth antes do corpo (padrão da família `/api/rfid/*`).

Request:

```json
{ "serial_id": "9a1f0c2e-...", "tag": "E28011702000020A5C41B6E0" }
```

- `serial_id`: uuid da unidade (aceito em qualquer caixa, normalizado para minúsculas).
- `tag`: normalizada no servidor (maiúsculas, remove espaço, `:` e `-`), 8 a 96 caracteres `A-Z0-9`.

Sucesso `200`:

```json
{ "codigo_interno": "MMD-CAB-0031", "tag_rfid": "E28011702000020A5C41B6E0" }
```

Erros:

| HTTP | Body | Quando |
|---|---|---|
| 401 | `{ "error": "<mensagem de auth>" }` | sem sessão ou role insuficiente |
| 400 | `{ "error": "invalid_json" }` | corpo não é JSON |
| 400 | `{ "error": "serial_id_invalido" }` | `serial_id` ausente ou fora do formato uuid |
| 400 | `{ "error": "<mensagem legível>" }` | tag inválida, tag já vinculada a outra unidade, unidade não encontrada, modo somente leitura |

Diferenças em relação ao vínculo do web legado (intencionais): sem restrição a cabos
(qualquer unidade é taggeável) e sem checagem de `lotes` (no design EventPro a unicidade
inteira vive no UNIQUE de `serial_numbers.tag_rfid`).

---

## 9. Divergências entre o que o iOS envia e o que o web valida

Achados da leitura cruzada do código. Cada um precisa de decisão antes do gate de saída da fase 4.

### D1. O iOS não consegue completar um retorno que a RPC aceite (bloqueante)

`ReturnViewModel.buildReturnProjectItems()` usa `compactMap` e **descarta itens em `.pending`**, e
não tem nenhum ramo que produza `resultado: "NAO_VOLTOU"` (o caso `.pending` vira nil, os outros dois
viram `OK` e `PROBLEMA`). A RPC `checkin_projeto` exige cobertura total do conjunto de seriais
próprios `EM_CAMPO` do evento. Consequência prática: qualquer conferência com uma unidade não
conferida ou não devolvida falha com
`"Lista de retorno não bate com as unidades que saíram neste Evento"`, e o operador não tem como
resolver pelo app. Todo o mecanismo de `retorno_pendencias`, que é regra central do produto, é
inalcançável pelo mobile. Correção no lado iOS (mapear pendente para `NAO_VOLTOU` na finalização),
não no contrato.

### D2. Normalização de tag só existe no servidor

O app envia as tags cruas do leitor. O servidor normaliza (`toUpperCase`, remoção de espaços, `:` e
`-`) e devolve a versão normalizada em `resolved[].tag_rfid` e `unresolved[]`. O app então casa esses
retornos contra a lista local de tags cruas. Enquanto o EPC vier em hexadecimal maiúsculo sem
separador, os dois conjuntos coincidem; qualquer formatação diferente (o SDK Zebra real pode
entregar com separador) quebra o casamento silenciosamente, sem erro HTTP. Agravante: o caminho de
fallback `APIClient.resolveRfidTags` consulta o PostgREST direto com a tag crua, sem normalização
nenhuma. A normalização precisa ser espelhada no cliente EventPro.

### D3. Ausência de `Authorization` degrada para cookie em vez de recusar

`makeWebApiRequest` só põe o header quando o token colado em Ajustes não está vazio. Sem token, a
requisição sai sem `Authorization`, e `requireRequestUser` cai em `requireActionUser`, que tenta
cookie SSR. Do iOS não há cookie, então o resultado é 401 com frase em português. Mas em ambiente
com `MMD_REQUIRE_AUTH` desligada, `requireRequestUser` devolve **admin sem nenhuma verificação**:
qualquer chamada anônima executa check-out real. É o risco 5.2 da auditoria, exposto pela superfície
HTTP. No EventPro, a ausência de credencial em rota de escrita deve ser 401 sempre.

### D4. `not_found` versus frase de erro para evento inexistente

`GET /resumo` responde 404 `{"error":"not_found"}`. `POST /checkout` com o mesmo id inexistente
responde 400 `{"error":"Evento não encontrado."}`, e `POST /retorno` responde 400 com a frase da RPC
(`"Evento <uuid> não encontrado"`, sem ponto final e com o uuid interpolado). Três formas de dizer a
mesma coisa, em dois status diferentes. Congelado como está, mas é candidato número um a uniformizar
na versão 2.0.

### D5. Negativa de role é 401, e override negado é 400

`requireRequestUser` devolve 401 tanto para "não autenticado" quanto para "autenticado sem
permissão". Já o bloqueio de override por falta de role admin acontece dentro da action e sai como
**400** com `"Ação restrita ao usuário admin."`. O mesmo conceito (permissão insuficiente) aparece
com dois status diferentes na mesma rota. O app iOS trata todo 4xx igual, então nada quebra hoje.

### D6. `overrideReason` é o único campo camelCase da API

Todo o resto do contrato é snake_case (`serial_id`, `projeto_id`, `serial_fabrica`, `scan_ids`,
`novo_status`, `codigo_interno`, `item_nome`). `overrideReason` escapou. Renomear quebra o iOS
legado, logo fica congelado; se o EventPro quiser `override_reason`, precisa aceitar os dois durante
a transição e a mudança entra em versão nova do documento.

### D7. O iOS não envia `localizacao` nem RSSI, e não há como enviar RSSI

`RfidScanRequest` não tem campo `localizacao`, então toda leitura do app grava `rfid_scans.localizacao`
null, apesar de a rota aceitar o campo. Pior, `rfid_scans.rssi` é sempre null: `parseRfidScanPayload`
não lê RSSI de lugar nenhum, embora `buildRfidScanPlan` aceite um `rssiByTag`. Sem RSSI persistido,
não existe base de dados para proximidade ou para o "achar item". Adicionar `rssi_por_tag` ao payload
é mudança **aditiva** e cabe dentro da política desta versão.

### D8. `contexto` inválido é aceito silenciosamente

`/api/rfid/scans` transforma qualquer `contexto` desconhecido em `INVENTARIO` em vez de recusar. Um
cliente com typo grava telemetria no bucket errado sem nenhum sinal. O endpoint novo da seção 7
corrige isso com `contexto_invalido`, e a divergência de comportamento entre as duas rotas é
intencional e documentada.

### D9. Ids em maiúsculas vindos do Swift

`UUID.uuidString` gera maiúsculas, então path (`/api/eventos/1F2B...`), `projeto_id` e `serial_id`
chegam em maiúsculas. O Postgres normaliza no cast para `uuid`, mas qualquer comparação textual de
id no BFF (chave de mapa, dedup, cache) precisa normalizar antes. Hoje nenhum caminho depende disso;
é armadilha para código novo.

### D10. `MMD_READONLY` com default `true` derruba o smoke test da fase 4

O gate de saída da fase 4 é o app iOS legado executando checkout e retorno contra o staging
EventPro. Com `MMD_READONLY` não definida, toda escrita responde 400
`"Modo somente leitura: alterações não são salvas."`, e o app mostra só "Erro HTTP 400". Deixar a
variável explícita no ambiente de staging é pré-requisito do smoke, não detalhe de configuração.

### D11. `/api/qr-sheet` está fora do padrão de auth de toda a superfície

É a única rota que não usa `requireRequestUser`, não aceita Bearer, não checa role e usa o código de
erro em inglês (`unauthorized`). Qualquer cliente que não seja o browser autenticado por cookie não
consegue usá-la. Alinhar ao padrão faz parte da refatoração da seção 6.6.

---

## 10. Política de mudança

Este documento é o contrato. Vale para os endpoints marcados como CONGELADO a partir da versão 1.0,
e para os marcados como NOVO a partir da aprovação da especificação.

1. **Contrato congelado só muda com versão nova do documento mais aprovação explícita.** Não existe
   mudança de contrato "junto com" uma tarefa de UI, de refatoração ou de banco. A mudança é a
   tarefa, e ela começa por editar este arquivo, incrementar a versão no topo e registrar a decisão.
   Sem isso, código que altere request, response ou código de erro de endpoint congelado é regressão,
   mesmo que os testes passem.

2. **Campo novo só entra de forma aditiva.** Adicionar campo opcional no request (com default que
   preserve o comportamento anterior) e adicionar campo no response é permitido dentro da mesma
   versão maior, porque o decoder do iOS ignora chave desconhecida. Exemplos já mapeados como
   aditivos aceitáveis: `rssi_por_tag` em `/api/rfid/scans` (D7), `localizacao` no endpoint de
   conferência, `sem_tag` na busca de seriais.

3. **Remover ou renomear campo de response é mudança quebradora.** O `JSONDecoder` do iOS falha o
   request inteiro quando falta uma chave não opcional (`count`, `seriais`, `serial_id`,
   `codigo_interno`, `novo_status`, `resolved`, `unresolved`, `scan_ids`). Essas chaves são
   intocáveis enquanto existir um app legado apontando para o EventPro.

4. **Tornar validação mais estrita é mudança quebradora.** Recusar o que hoje é aceito (por exemplo
   passar a exigir `contexto` em `/api/rfid/scans`, ou passar a validar `projeto_id` como uuid antes
   do banco) muda o comportamento observável e exige versão nova. Afrouxar validação é aditivo.

5. **Mudar status HTTP é mudança quebradora**, inclusive as correções óbvias listadas na seção 9
   (401 que deveria ser 403, 400 que deveria ser 404). Elas ficam registradas como dívida consciente
   e entram todas juntas em uma versão 2.0, não uma de cada vez.

6. **Códigos de erro em snake_case são vocabulário fechado.** `invalid_json`, `metodo_invalido`,
   `items_invalidos`, `tags_invalidas`, `not_found`, `no_items`, `invalid_layout`, `unauthorized`, e
   os propostos `contexto_invalido` e `parametros_invalidos`. Código novo pode ser adicionado; código
   existente não pode ser reaproveitado com outro significado nem removido.

7. **Frases em português são texto de operador, não contrato de máquina.** Podem ser reescritas sem
   nova versão maior, desde que o status HTTP e a condição que as dispara permaneçam idênticos. O
   cliente nunca deve compará-las por igualdade. A única exceção viva é a regra
   `error.includes('login')` da seção 2.5, que é acoplamento a corrigir, não a preservar.

8. **Toda versão nova registra, no topo do documento, o que mudou, por que, e qual é o plano para o
   cliente legado.** Enquanto o app iOS legado for suportado, contrato quebrado precisa de janela de
   convivência, não de corte seco.

9. **Cada endpoint congelado tem smoke test autenticado em staging** (fase 4, item 5). Contrato sem
   teste que o exercite volta a ser documentação, e documentação sozinha não segura regressão.
