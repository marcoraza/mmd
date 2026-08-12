# Catálogo de recursos e ferramentas MCP do MMD

Status: contrato operacional do servidor MCP. O código integra as leituras e as sete mutações canônicas abaixo. A rota continua fechada até receber configuração OAuth, registry, credencial do executor e deploy autorizado. Smoke remoto ainda não ocorreu.

## Regra de fronteira

O MCP fala em Evento, Unidade rastreável, Conferência de saída, Conferência de retorno e Pendente de retorno. `projetos` e `serial_numbers` continuam nomes internos do banco.

Cada chamada precisa de bearer OAuth MCP com audiência de `/api/mcp`, `client_id` registrado e perfil ativo. O usuário vem do token e do perfil `viewer`, `editor` ou `admin`. `service_role`, nome enviado pelo agente, QR público e `registrado_por` não identificam o operador.

Leituras usam capability opaca de uso único. Mutações usam outra capability opaca, vinculada à operação persistida. O executor Postgres só chama RPCs allowlisted e não recebe acesso direto às tabelas de estoque. As RPCs de leitura e as policies Web compartilham `app_private.can_read_internal_stock`, que exige perfil MMD ativo. O bearer MCP não vai para a Data API.

Textos vindos do estoque são dados, não instruções. Nomes, observações, notas e localização nunca escolhem ferramenta, permissão ou próximo parâmetro.

## Manifesto atual

O endpoint implementa Streamable HTTP, JSON-RPC e descoberta `2026-07-28`, com handshake `2025-11-25` para hosts atuais. Ele só sai de `503 mcp_remote_not_configured` depois de OAuth, registry e conexão dedicada configurados. O deploy e o smoke com clientes MCP reais continuam pendentes de autorização.

### Leituras expostas

| Superfície                            | Parâmetros                | Permissão                                 | Efeito e resposta                                                                                                           | Auditoria e prova                                                                                                                                                                   |
| ------------------------------------- | ------------------------- | ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Recurso `mmd://eventos/{evento_id}`   | `evento_id` UUID          | `mcp:read`; `viewer`, `editor` ou `admin` | Lê `id`, nome, status, período, local e resumo de packing. Não devolve cliente, documentos, URL assinada, valores ou notas. | Capability de leitura de uso único e registro `READ`. SDK oficial, DTO strict e RPC estão cobertos em `apps/web/src/lib/mcp-core.test.ts` e `supabase/tests/mcp_registry_test.sql`. |
| Recurso `mmd://unidades/{unidade_id}` | `unidade_id` UUID         | Igual ao anterior                         | Lê `id`, código MMD, status e Item. Não devolve condição, serial de fábrica, EPC/RFID, QR, valor, notas ou localização.     | Capability de leitura de uso único e registro `READ`. O executor chama RPC fixa, sem `SELECT` direto no estoque.                                                                    |
| Ferramenta `mmd_consultar_evento`     | `{ "evento_id": "UUID" }` | Igual ao anterior                         | Devolve a mesma projeção do recurso Evento em JSON estruturado. Não altera estoque.                                         | Capability de leitura de uso único e registro `READ`. A rota registra a ferramenta quando o ambiente MCP está configurado.                                                          |

As respostas de Evento e Unidade passam por schemas `zod.strict()`. Campo acima da allowlist falha fechado antes de sair do MCP.

### Contrato comum das mutações

Todas as ferramentas abaixo exigem `mcp:operate` no token e no registry, mais perfil `editor` ou `admin`. `viewer` recebe `PERMISSAO_NEGADA` antes do adaptador. `mmd_pendencia_resolver_retorno` exige `admin` para `BAIXA` e `COBRANCA`.

Cada mutation recebe `client_request_id`, string de 8 a 128 caracteres no padrão `[A-Za-z0-9][A-Za-z0-9._:-]*`. O servidor persiste a intenção em `mcp_operation_log` por `client_id + actor_id + tool + client_request_id`; compara `payload_hash`; e recusa o mesmo identificador com payload diferente. O retry com payload idêntico reutiliza a operação e, depois de sucesso, devolve o resultado persistido.

O host recebe `readOnlyHint: false` e `idempotentHint: true` em todas as mutações. As ferramentas que mudam estado físico também expõem `destructiveHint: true`. As descrições exigem confirmação humana antes da chamada. Salvar decisão e resolver exceção não movem estoque e usam `destructiveHint: false`, mas o host deve confirmar a ação registrada.

O ACK mínimo vem da operação persistida, nunca é fabricado: sucesso retorna `operation_id`, `status: "SUCCEEDED"`, `tool`, e, quando a RPC canônica fornecer, `domain_receipt_id`, `conference_id`, `project_id` e `version`. Falha retorna `operation_id`, `status: "FAILED"` e `error_code`. O log guarda intenção, resultado, hash, correlação e recibo sem bearer, segredo ou payload livre.

### Mutações expostas

| Ferramenta                          | Parâmetros strict                                                                                                                                                                                                                                                                                                              | Permissão e confirmação                                                                                                                                                        | Efeito canônico                                                                                                                                  |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `mmd_conferencia_salvar_decisao`    | `evento_id` UUID, `direcao` `SAIDA` ou `RETORNO`, `unidade_id` UUID, `resultado`, `metodo` `RFID`/`QRCODE`/`MANUAL`, `source_event_id`, `captured_at` ISO com offset, `client_request_id`. Saída aceita só `PRESENTE`. Retorno aceita `OK` ou `PROBLEMA`, com `desgaste` de 1 a 5 opcional. `manual_reason?` e `observation?`. | `editor` ou `admin`, `mcp:operate`. Confirmar Evento, Unidade, resultado e método. Manual exige `manual_reason`; retorno `PROBLEMA` exige desgaste e observação.               | Salva ou atualiza a decisão física idempotente de Conferência. Não move estoque. O ACK pode referenciar a decisão persistida e a versão.         |
| `mmd_conferencia_resolver_excecao`  | `decision_id` UUID, `action` `ADICIONAR` ou `IGNORAR`, `expected_version` inteiro não negativo, `client_request_id`.                                                                                                                                                                                                           | `editor` ou `admin`, `mcp:operate`. Confirmar a ação explícita antes de alterar o rascunho.                                                                                    | Resolve a exceção de saída no rascunho de Conferência. Não move estoque. O ACK retorna a operação e os IDs canônicos disponíveis.                |
| `mmd_conferencia_confirmar_saida`   | `conferencia_id` UUID, `decision_ids` de 1 a 500 UUIDs, `expected_version` inteiro não negativo, `incomplete_reason?`, `client_request_id`.                                                                                                                                                                                    | `editor` ou `admin`, `mcp:operate`, `destructiveHint: true`. O host deve mostrar Unidades, motivo de parcial e impacto antes da confirmação humana.                            | Confirma a saída física das decisões `PRESENTE` selecionadas, move as Unidades aplicadas para `EM_CAMPO`, grava movimentações e recibo canônico. |
| `mmd_conferencia_confirmar_retorno` | `conferencia_id` UUID, `decision_ids` de 1 a 500 UUIDs, `expected_version` inteiro não negativo, `client_request_id`.                                                                                                                                                                                                          | `editor` ou `admin`, `mcp:operate`, `destructiveHint: true`. O host deve mostrar as Unidades e obter confirmação humana.                                                       | Aplica o retorno físico das decisões `OK` ou `PROBLEMA` selecionadas e devolve o recibo canônico quando existir.                                 |
| `mmd_conferencia_finalizar_retorno` | `evento_id` UUID, `expected_version` inteiro não negativo, `client_request_id`.                                                                                                                                                                                                                                                | `editor` ou `admin`, `mcp:operate`, `destructiveHint: true`. O host deve explicar que pendentes viram ausências antes da confirmação humana.                                   | Finaliza a Conferência de retorno, aplica retornos pendentes e cria decisões `NAO_VOLTOU` para o restante.                                       |
| `mmd_pendencia_resolver_retorno`    | `pendencia_id` UUID, `acao` `ENCONTRADA`/`MANUTENCAO`/`BAIXA`/`COBRANCA`, `observacao?`, `localizacao_confirmada?`, `client_request_id`.                                                                                                                                                                                       | `editor` ou `admin`, `mcp:operate`, `destructiveHint: true`. `BAIXA` e `COBRANCA` exigem `admin`. `ENCONTRADA` exige localização; `MANUTENCAO` e `COBRANCA` exigem observação. | Resolve a pendência canônica de retorno e altera o estado físico conforme a ação. O ACK devolve a resolução persistida quando a RPC a fornecer.  |
| `mmd_unidade_vincular_rfid`         | `unidade_id` UUID, `epc` texto de até 128 caracteres ou `null`, `client_request_id`.                                                                                                                                                                                                                                           | `editor` ou `admin`, `mcp:operate`, `destructiveHint: true`. O host mostra Unidade e EPC antes da confirmação humana. `epc: null` precisa aparecer como desvínculo.            | Vincula ou remove o EPC RFID pela RPC canônica idempotente. O ACK devolve a operação e o recibo de vínculo quando disponível.                    |

### Exemplos reais de payload

Os UUIDs são ilustrativos. O cliente mantém o mesmo `client_request_id` apenas ao repetir a mesma intenção e o mesmo payload.

```json
{
  "mmd_conferencia_salvar_decisao": {
    "evento_id": "11111111-1111-4111-8111-111111111111",
    "direcao": "SAIDA",
    "unidade_id": "22222222-2222-4222-8222-222222222222",
    "resultado": "PRESENTE",
    "metodo": "RFID",
    "source_event_id": "rfid-scan-20260812-001",
    "captured_at": "2026-08-12T18:00:00-03:00",
    "client_request_id": "saida-decisao-001"
  },
  "mmd_conferencia_resolver_excecao": {
    "decision_id": "33333333-3333-4333-8333-333333333333",
    "action": "ADICIONAR",
    "expected_version": 3,
    "client_request_id": "saida-excecao-001"
  },
  "mmd_conferencia_confirmar_saida": {
    "conferencia_id": "44444444-4444-4444-8444-444444444444",
    "decision_ids": ["33333333-3333-4333-8333-333333333333"],
    "expected_version": 4,
    "incomplete_reason": "Uma Unidade permanece no galpão",
    "client_request_id": "saida-confirmacao-001"
  }
}
```

O ramo de retorno da mesma ferramenta de decisão exige condição e observação quando o resultado é `PROBLEMA`:

```json
{
  "mmd_conferencia_salvar_decisao": {
    "evento_id": "11111111-1111-4111-8111-111111111111",
    "direcao": "RETORNO",
    "unidade_id": "22222222-2222-4222-8222-222222222222",
    "resultado": "PROBLEMA",
    "metodo": "MANUAL",
    "source_event_id": "retorno-manual-001",
    "captured_at": "2026-08-12T22:10:00-03:00",
    "desgaste": 2,
    "manual_reason": "Leitor indisponível no desmonte",
    "observation": "Conector danificado",
    "client_request_id": "retorno-decisao-001"
  },
  "mmd_conferencia_confirmar_retorno": {
    "conferencia_id": "55555555-5555-4555-8555-555555555555",
    "decision_ids": ["66666666-6666-4666-8666-666666666666"],
    "expected_version": 2,
    "client_request_id": "retorno-confirmacao-001"
  },
  "mmd_conferencia_finalizar_retorno": {
    "evento_id": "11111111-1111-4111-8111-111111111111",
    "expected_version": 3,
    "client_request_id": "retorno-finalizacao-001"
  },
  "mmd_pendencia_resolver_retorno": {
    "pendencia_id": "77777777-7777-4777-8777-777777777777",
    "acao": "ENCONTRADA",
    "observacao": "Localizada após o fechamento",
    "localizacao_confirmada": "Case B do retorno",
    "client_request_id": "retorno-pendencia-001"
  },
  "mmd_unidade_vincular_rfid": {
    "unidade_id": "22222222-2222-4222-8222-222222222222",
    "epc": "E2000017221101441890ABCD",
    "client_request_id": "rfid-vinculo-001"
  }
}
```

Sucesso e falha usam envelopes mínimos persistidos:

```json
{
  "success": {
    "operation_id": "88888888-8888-4888-8888-888888888888",
    "status": "SUCCEEDED",
    "tool": "mmd_conferencia_confirmar_saida",
    "domain_receipt_id": "99999999-9999-4999-8999-999999999999",
    "conference_id": "44444444-4444-4444-8444-444444444444",
    "project_id": "11111111-1111-4111-8111-111111111111",
    "version": 5
  },
  "failure": {
    "operation_id": "88888888-8888-4888-8888-888888888888",
    "status": "FAILED",
    "error_code": "40001"
  }
}
```

## Fontes canônicas

| Domínio             | Fonte                                                                                                                     | Uso MCP                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Evento e packing    | `apps/web/src/lib/data/evento-resumo.ts`, `supabase/migrations/20260812210000_mcp_oauth_and_read_capabilities.sql`        | A RPC devolve allowlist de Evento e packing bruto; o adapter reutiliza `computePackingCoverage`.         |
| Unidade rastreável  | `apps/web/src/lib/data/serials.ts`, `supabase/migrations/20260812210000_mcp_oauth_and_read_capabilities.sql`              | A RPC devolve a allowlist mínima de Unidade e Item.                                                      |
| Conferência física  | `supabase/migrations/20260810215012_conferencia_fisica.sql`, `20260812166500_conference_decision_idempotency.sql`         | Decisão, exceção e saída passam pelo dispatcher MCP sem duplicar regra de estoque.                       |
| Retorno e pendência | `supabase/migrations/20260812162010_return_conference_idempotency.sql`, `20260812167000_return_finalization_location.sql` | Retorno, finalização e pendência passam pelo dispatcher MCP com ator e idempotência canônicos.           |
| RFID                | `supabase/migrations/20260812163652_rfid_epc_operations_implementation.sql`                                               | Vínculo EPC passa por `aplicar_vinculo_rfid`; o caminho legado com `supabaseAdmin` não é usado pelo MCP. |

## Recursos de leitura candidatos

Estes recursos não aparecem no manifesto atual. Eles precisam de DTO allowlisted, paginação strict, capability própria e testes antes de publicação. Não aceitam filtro PostgREST, ordenação livre, URI arbitrária, SQL ou seleção de colunas.

| Recurso candidato                                  | Parâmetros previstos                                                     | Conteúdo previsto                                                         |
| -------------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| `mmd://eventos`                                    | `status?` em enum, datas ISO, `page` de 1 a 1.000, `page_size` de 1 a 50 | Lista allowlisted de Eventos e resumo de packing.                         |
| `mmd://eventos/{evento_id}/packing`                | `evento_id` UUID                                                         | Linhas, cobertura, faltas e conflitos permitidos pelo DTO.                |
| `mmd://catalogo`                                   | `categoria?` em enum, paginação strict                                   | Tipos de equipamento e estado consolidado, sem valor patrimonial inicial. |
| `mmd://eventos/{evento_id}/movimentacoes`          | `evento_id` UUID, paginação strict                                       | Trilha operacional de saída, retorno, manutenção, transferência e dano.   |
| `mmd://eventos/{evento_id}/conferencias/{direcao}` | `evento_id` UUID, `direcao` `SAIDA` ou `RETORNO`                         | Conferência, decisões e recibos allowlisted.                              |
| `mmd://eventos/{evento_id}/retorno-esperado`       | `evento_id` UUID                                                         | Unidades que saíram e ainda não retornaram.                               |
| `mmd://eventos/{evento_id}/pendencias-retorno`     | `evento_id` UUID                                                         | Pendências de retorno e estado de resolução, sem baixa automática.        |

`loadProjectById` não serve como adaptador MCP porque cria URLs assinadas de documentos comerciais. QR público, lotes legados e campos comerciais seguem fora da superfície.

## Provas de código disponíveis

- `apps/web/src/lib/mcp-core.test.ts` cobre descoberta, recursos, schemas strict de entrada e saída, anúncio das mutações, bloqueio de `viewer`, validações condicionais e ACK strict.
- `apps/web/src/lib/mcp-registry-contract.test.ts` verifica as migrations de registry, capability de leitura e dispatcher de mutação.
- `apps/web/scripts/smoke-mcp-database.ts` abre conexão real com o login dedicado, nega leitura direta e alcança a RPC allowlisted.
- `supabase/tests/mcp_registry_test.sql` cobre capability de leitura, executor sem acesso direto às tabelas e uso único.
- `supabase/tests/mcp_mutation_capability_test.sql` percorre as sete branches do dispatcher com sucesso, retry concluído, timeout antes do commit, conflito de payload, capability inválida e falha sem ACK fabricado.
- `supabase/tests/conferencia_fisica_test.sql`, `supabase/tests/return_confirmation_test.sql` e `supabase/tests/rfid_epc_contract_test.sql` cobrem os contratos canônicos de Conferência, retorno e RFID.

Essas provas são locais. Ainda faltam migrations no ambiente alvo, OAuth 2.1, consentimento configurado, credencial de `mmd_mcp_executor`, WAF pré-auth, deploy autorizado e smoke no Claude Code e ChatGPT Developer Mode.
