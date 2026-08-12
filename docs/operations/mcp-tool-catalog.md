# Catálogo de recursos e ferramentas MCP do MMD

Status: contrato de domínio para a primeira entrega do servidor MCP. Este documento não cria uma segunda API e não autoriza expor uma operação antes de ela cumprir os gates abaixo.

## Regra de fronteira

O MCP fala a linguagem do produto: **Evento**, **Unidade rastreável**, **Packing list**, **Conferência de saída**, **Conferência de retorno**, **Movimentação** e **Pendente de resolução**. `projetos` e `serial_numbers` continuam sendo nomes internos do banco.

Cada chamada deve carregar uma sessão Supabase verificável. O ator vem de `auth.uid()` e do perfil `viewer`, `editor` ou `admin`; `service_role`, um nome enviado pelo agente ou um campo `registrado_por` nunca são identidade do cliente. O cliente MCP também precisa ter uma identidade verificável. Dados de QR público, lotes legados e arquivos comerciais assinados ficam fora deste catálogo.

Os valores vindos do estoque, como `nome`, `notas`, `observacao` e `localizacao`, são dados não confiáveis. O servidor os devolve como JSON de domínio, nunca os executa como instrução e nunca permite que eles mudem permissão, ferramenta ou parâmetros da chamada seguinte.

## Estado real do manifesto v0.1

O núcleo de protocolo implementa Streamable HTTP, JSON-RPC e descoberta moderna `2026-07-28`, com handshake `2025-11-25` ainda aceito para hosts atuais. Não há sessão MCP persistente. O endpoint Next está deliberadamente fechado com `503 mcp_token_exchange_required`: não aceita token Supabase do web como token MCP e não faz passthrough desse bearer para a Data API. Portanto nenhum recurso ou ferramenta está disponível remotamente até existir token exchange com emissor, audiência e credencial downstream separados.

| Superfície exposta | Parâmetros | Permissão e autorização | Efeito e resposta | Recibo | Prova |
| --- | --- | --- | --- | --- | --- |
| Recurso `mmd://eventos/{evento_id}` | `evento_id` UUID | Futuro JWT MCP com `aud` do resource, escopo `mcp:read`, perfil ativo e cliente registrado | Só leitura user-bound. Devolve `id`, nome, status, período, local e resumo de packing. | Não se aplica. Grava trilha `READ` sem payload livre. | SDK oficial descobre o servidor, lista o template e lê o JSON em `apps/web/src/lib/mcp-core.test.ts`. Ainda não é exposto pela rota. |
| Recurso `mmd://unidades/{unidade_id}` | `unidade_id` UUID | Igual ao anterior | Só leitura user-bound. Devolve somente `id`, código MMD, status e Item. Não devolve condição, RFID, serial de fábrica, QR, valor, notas nem localização. | Não se aplica. Grava trilha `READ` sem payload livre. | Schema e DTO em `apps/web/src/lib/mcp-core.ts`; o adaptador de Data API continua bloqueado. |
| Ferramenta `mmd_consultar_evento` | `{ "evento_id": "UUID" }` | Igual ao anterior | Mesma projeção autenticada do recurso de Evento, em JSON estruturado no conteúdo da ferramenta. Não muda estoque. | Não se aplica. Grava trilha `READ`. | SDK legado lista a ferramenta em `apps/web/src/lib/mcp-core.test.ts`. Ainda não é exposta pela rota. |

Quando o token exchange existir, o guard falhará fechado quando bearer MCP, cliente, escopo ou perfil não conferirem. `MMD_REQUIRE_AUTH=false` não poderá alterar esse comportamento. Origin enviado e não listado em `MMD_MCP_ALLOWED_ORIGINS` receberá `403` antes da autenticação. Corpo acima de 128 KiB recebe `413`, inclusive sem `Content-Length`. O limite distribuído reserva 60 requisições por minuto por cliente e ator, configurável por `MMD_MCP_RATE_LIMIT_PER_MINUTE`; indisponibilidade do registro recebe `503`, nunca bypass. Limite pré-auth por IP precisa ser imposto pelo WAF/edge antes de habilitar a rota.

O registry persistido tem exatamente `client_id`, `actor_id`, `tool`, `client_request_id`, `payload_hash`, intenção, resultado, correlação e recibo opcional. A chave única não inclui o hash: mesma requisição com hash diferente conflita, em vez de abrir uma segunda operação. A migration é `supabase/migrations/20260812163430_mcp_client_registry_and_operations.sql` e o contrato é travado por `apps/web/src/lib/mcp-registry-contract.test.ts`.

Nenhuma ferramenta de mutação está exposta. Portanto não existe confirmação de hospedeiro nem ACK de saída no manifesto atual. A tabela a seguir é roadmap bloqueado, não capacidade disponível.

## Fontes canônicas observadas

| Domínio | Fonte atual | Estado para MCP |
| --- | --- | --- |
| Evento e packing | `apps/web/src/lib/data/projects.ts`, `apps/web/src/lib/data/project-detail.ts`, `apps/web/src/lib/data/evento-resumo.ts` | A projeção existe, mas hoje é carregada por `supabaseAdmin`. O MCP precisa de uma projeção equivalente sob a sessão do usuário, sem fallback demo. |
| Catálogo e Unidade | `apps/web/src/lib/data/items.ts`, `apps/web/src/lib/data/serials.ts` | A estrutura canônica existe. Não reaplicar agregações ou disponibilidade no MCP. |
| Movimentações e pendências | `apps/web/src/lib/data/movimentacoes.ts`, `apps/web/src/lib/data/project-detail.ts` | Leitura canônica existe; a ação legada de resolução ainda não pode ser exposta. |
| Conferência física | `supabase/migrations/20260810215012_conferencia_fisica.sql` e `supabase/tests/conferencia_fisica_test.sql` | Rascunho, recibo, versão, autenticação de ator e confirmação idempotente já existem no banco. Falta uma fronteira web/MCP que preserve a sessão e o log de protocolo. |
| Leitura RFID | `apps/web/src/lib/rfid-scan-core.ts` e `apps/web/src/app/api/rfid/scans/route.ts` | A gravação atual é autenticada no web, mas persiste via `supabaseAdmin` e não tem idempotência. Fica fora das ferramentas iniciais. |

## Recursos de leitura candidatos

Todos os recursos abaixo são candidatos internos, retornam somente JSON e exigirão ao menos `viewer`. A implementação deve paginar coleções e limitar campos ao necessário. UUIDs, direção e paginação são schemas estritos: UUID válido, `direcao` em `SAIDA` ou `RETORNO`, `page` inteiro de 1 a 1.000 e `page_size` inteiro de 1 a 50. Não existe parâmetro que aceite filtro PostgREST, campo de ordenação, URI arbitrária, SQL ou seleção livre de colunas. Os exemplos usam UUIDs ilustrativos.

| Recurso MCP | Parâmetros | Conteúdo canônico | Permissão | Exemplo |
| --- | --- | --- | --- | --- |
| `mmd://eventos` | `status?` em enum, `inicio_de?` e `inicio_ate?` ISO-8601, `page`, `page_size` | DTO de Evento com `id`, nome, status, período, local, resumo de readiness e contagens de packing | viewer | `mmd://eventos?status=CONFIRMADO&page=1&page_size=20` |
| `mmd://eventos/{evento_id}` | `evento_id` UUID | DTO allowlist de Evento: identificação operacional, período, local, status, gate de saída, packing hidratado e pendências de retorno. Exclui cliente, notas, ficha, comercial, documentos e URLs assinadas. | viewer | `mmd://eventos/11111111-1111-1111-1111-111111111111` |
| `mmd://eventos/{evento_id}/packing` | `evento_id` UUID | Linhas, quantidades necessárias, alocadas, avulsas, faltantes, seriais designados e conflitos | viewer | `mmd://eventos/11111111-1111-1111-1111-111111111111/packing` |
| `mmd://catalogo` | `categoria?` em enum, `page`, `page_size` | Tipos de equipamento, estado consolidado, condição e cobertura RFID. Valor patrimonial fica fora do DTO inicial. | viewer | `mmd://catalogo?categoria=ILUMINACAO&page=1&page_size=20` |
| `mmd://unidades/{unidade_id}` | `unidade_id` UUID | DTO allowlist da Unidade: `id`, código MMD, Item e status. Exclui condição, serial de fábrica, tag RFID, QR, notas, localização, valores e atualização por padrão. | viewer | `mmd://unidades/22222222-2222-2222-2222-222222222222` |
| `mmd://eventos/{evento_id}/movimentacoes` | `evento_id` UUID, paginação | Trilha de SAIDA, RETORNO, MANUTENCAO, TRANSFERENCIA e DANO do Evento | viewer | `mmd://eventos/11111111-1111-1111-1111-111111111111/movimentacoes` |
| `mmd://eventos/{evento_id}/conferencias/{direcao}` | `evento_id` UUID, `direcao` igual a `SAIDA` ou `RETORNO` | Conferência única, versão, decisões, método, evidência, resolução e recibos existentes | viewer | `mmd://eventos/11111111-1111-1111-1111-111111111111/conferencias/SAIDA` |
| `mmd://eventos/{evento_id}/retorno-esperado` | `evento_id` UUID | Unidades que saíram fisicamente e ainda não receberam confirmação de retorno, via `conferencia_retorno_esperado` | viewer | `mmd://eventos/11111111-1111-1111-1111-111111111111/retorno-esperado` |
| `mmd://eventos/{evento_id}/pendencias-retorno` | `evento_id` UUID | Pendentes de resolução e seu estado, sem criar baixa automática | viewer | `mmd://eventos/11111111-1111-1111-1111-111111111111/pendencias-retorno` |

As coleções não devem materializar a projeção dos loaders no servidor MCP. Em especial, `loadProjectById` não é adaptador MCP porque cria URLs assinadas de documentos comerciais. O backend paralelo precisa oferecer DTOs com allowlist usando o JWT do usuário ou uma credencial técnica limitada que preserve o ator e aplique as permissões de `profiles`.

## Ferramentas candidatas

Uma ferramenta só aparece no manifesto MCP como disponível quando todos estes pontos passarem: validação de argumentos, sessão de ator, permissão, idempotência, recibo persistido e log de protocolo sem segredo. `Confirmação do hospedeiro` significa que o cliente MCP deve mostrar o impacto antes de enviar a mutação quando suportar essa capacidade.

| Ferramenta | Parâmetros | Efeito e contrato canônico | Permissão | Idempotência e auditoria | Situação |
| --- | --- | --- | --- | --- | --- |
| `mmd_conferencia_salvar_decisao` | `evento_id`, `direcao`, `unidade_id`, `resultado`, `metodo`, `source_event_id`, `captured_at`, `manual_reason?`, `observation?`, `client_request_id` | Mapeia para `salvar_decisao_conferencia`. Cria ou atualiza a decisão unitária da Conferência e avança a versão. Saída aceita somente `PRESENTE`; retorno aceita `OK`, `PROBLEMA` ou `NAO_VOLTOU`; manual exige motivo. | editor ou admin | A RPC audita ator, método, evidência e horário, mas ainda não recebe chave idempotente nem cria recibo de comando. | **Bloqueada** até o backend adicionar envelope idempotente e ACK persistido, sem alterar a regra da RPC. |
| `mmd_conferencia_confirmar_saida` | `conferencia_id`, `decision_ids`, `expected_version`, `client_request_id`, `incomplete_reason?` | Mapeia diretamente para `confirmar_conferencia_saida`. Aplica somente decisões PRESENTE selecionadas, registra SAIDA, move somente essas Unidades para `EM_CAMPO`, substitui designação válida quando aplicável e retorna recibo persistido. | editor ou admin | O adaptador deriva e persiste a chave enviada à RPC a partir de `client_id`, `actor_id`, nome da ferramenta e `client_request_id`; ele também vincula o `payload_hash`. Mesmo ator e mesma requisição com o mesmo payload retornam o recibo. Mesma requisição com outro payload ou outra identidade conflita antes de ler qualquer recibo. Movimentações e decisões ficam vinculadas ao recibo. | **Pronta no banco apenas para o núcleo da transação. Bloqueada** até o backend fechar o registro MCP por cliente e ator, e a fronteira autenticada com confirmação do hospedeiro. Ferramenta perigosa. |
| `mmd_conferencia_listar_retorno_esperado` | `evento_id` | Consulta `conferencia_retorno_esperado`. Não muda estoque. | viewer | Não se aplica. Não grava auditoria de negócio. | Recurso preferencial, não expor como ferramenta salvo limitação objetiva do cliente MCP. |
| `mmd_rfid_registrar_leituras` | `tags`, `contexto`, `evento_id?`, `localizacao?`, dados do leitor opcionais, `idempotency_key` | O caminho web atual normaliza EPCs, resolve tags e registra inclusive desconhecidas. | editor ou admin | O caminho atual não recebe chave idempotente e grava com `supabaseAdmin`; o log não identifica cliente MCP, ferramenta ou intenção. | **Não expor** até a consolidação do backend paralelo. |
| `mmd_pendencia_resolver_retorno` | `pendencia_id`, `acao`, `observacao`, `idempotency_key` | O contrato legado pode marcar encontrada, manutenção, baixa ou cobrança textual. | admin | A ação atual chama `resolver_retorno_pendencia` como `service_role`, sem chave idempotente MCP nem recibo por comando. | **Não expor**. Precisa de contrato físico de retorno equivalente ao de saída. |
| `mmd_unidade_vincular_rfid` | `unidade_id`, `tag_rfid`, `idempotency_key` | O atalho web atual limita vínculo a cabos, rejeita tag duplicada e lote legado. | editor ou admin | Falta idempotência e auditoria de mudança de associação. | **Não expor** até existir transação auditada de Etiquetar. |
| `mmd_packing_*` | conforme operação | Criar, editar, alocar ou liberar packing existe como Server Action do web. | editor ou admin | As ações atuais não oferecem o envelope de idempotência e recibo MCP. | **Não expor** na primeira entrega. |

### Exemplo: confirmação física de saída

O cliente deve pedir confirmação visível antes de chamar a ferramenta. O agente não deve resumir o impacto de modo ambíguo: a saída muda o status físico das Unidades escolhidas.

```json
{
  "conferencia_id": "33333333-3333-3333-3333-333333333333",
  "decision_ids": ["44444444-4444-4444-4444-444444444444"],
  "expected_version": 7,
  "client_request_id": "8d31ca49-26a4-4dfd-8b55-4f82dc061425",
  "incomplete_reason": "A segunda Unidade ainda está no galpão"
}
```

O adaptador não encaminha a identificação livre do cliente como `idempotency_key` para o banco. Ele registra a combinação de cliente MCP, ator, ferramenta, `client_request_id` e hash do payload, então deriva a chave interna. O ACK só é sucesso quando vier do recibo persistido. Um retorno mínimo deve conter `confirmation_id`, `conference_id`, `project_id`, `direction`, `actor_id`, `confirmed_at`, `incomplete_reason` e as Unidades efetivamente aplicadas. Timeout, conflito de versão, decisão inválida e falha de persistência retornam erro, nunca ACK fabricado.

## Operações que o MCP não pode reaproveitar

- `checkoutProject`, `checkout_projeto` e `checkout_projeto_com_override` movimentam o modelo legado de seriais alocados e usam `service_role`. Eles contrariam a ADR 0005 ao presumir saída por alocação e não aceitam idempotência MCP.
- `checkinProject`, `checkin_projeto` e `resolver_retorno_pendencia` são contratos legados executados por `service_role`; não expor enquanto o retorno físico não tiver Conferência, recibo e idempotência equivalentes.
- `recordAuthenticatedRfidScans` e `bindRfidTagToSerial` não podem ser chamados pelo MCP enquanto o ator e a auditoria dependerem de `supabaseAdmin`.
- Nenhuma ferramenta recebe ou devolve `SUPABASE_SERVICE_ROLE_KEY`, token de sessão, URL assinada de Storage, dados de QR público vetados ou campos de outro Evento.

## Seams de teste

Os seams abaixo guiam a suíte MCP. O núcleo inicial já prova bearer obrigatório, rejeição de Origin antes da autenticação, descoberta pelo SDK oficial e DTO de Evento com allowlist. Os itens dependentes de mutação permanecem bloqueados até a consolidação do backend.

| Seam público | Comportamento que precisa provar | Fonte independente |
| --- | --- | --- |
| Recurso MCP de Evento | Um `viewer` autenticado lê a mesma projeção canônica exibida pelo produto, sem fallback demo, sem URL assinada e sem campos fora da allowlist. Filtro e paginação fora do schema falham sem chegar ao banco. | Fixture do banco com Evento, packing e perfis; comparação com a projeção user-bound aprovada pelo backend. |
| Recurso MCP de Conferência | Decisões e recibos pertencem ao Evento solicitado e textos de estoque são devolvidos somente como dados. | Fixture com duas Conferências e texto contendo instrução maliciosa. |
| Ferramenta de decisão | Argumento inválido, método manual sem motivo, perfil `viewer` e token ausente falham antes de qualquer escrita. | Teste SQL de `salvar_decisao_conferencia` mais chamada MCP autenticada. |
| Ferramenta de confirmação | Confirmação de saída muda apenas as Unidades presentes, produz recibo e envia confirmação do hospedeiro. | `supabase/tests/conferencia_fisica_test.sql`, com teste MCP da adaptação. |
| Retry de confirmação | Mesmo cliente, ator e `client_request_id` com o mesmo payload devolvem o mesmo recibo. Payload diferente, cliente diferente ou ator diferente conflitam. Timeout não cria ACK. | Fixture de Conferência e assert do recibo persistido. |
| Isolamento de segredo | Lista de recursos, resposta, log e documentação não contêm service role, bearer token ou URL assinada. | Snapshot redigido e varredura de logs de teste. |

## Dependências vivas do backend paralelo

1. Criar um adaptador de leitura autenticado que substitua o uso direto de `supabaseAdmin` para o MCP. Os loaders atuais do web podem continuar existindo, mas não são a identidade do cliente MCP. Os DTOs MCP precisam de allowlists específicas e nenhum filtro livre.
2. Encapsular `salvar_decisao_conferencia` com chave idempotente, recibo persistido e campos de auditoria de origem MCP. Não duplicar a regra de substituição, revisão ou condição física.
3. Criar o registro de comando MCP que vincula `client_id`, `actor_id`, ferramenta, `client_request_id` e hash. O adaptador deve gerar a chave interna da RPC a partir desse registro. A unicidade atual por Conferência não pode entregar recibo para outro ator ou cliente.
4. Expor a Conferência física por uma fronteira HTTP/serviço que encaminhe o JWT do usuário ao Supabase. A execução por `service_role` deve continuar incapaz de se passar pelo ator.
5. Definir a Conferência de retorno idempotente antes de publicar retorno, RFID de campo ou resolução de pendência como ferramenta MCP.
6. Incluir no log operacional `cliente MCP`, `ator`, `ferramenta`, `intenção`, `resultado`, identificador de correlação e IDs de recibo, com redaction de segredo.

Enquanto essas dependências não estiverem concluídas, o servidor pode publicar somente recursos aprovados por uma camada user-bound. Não deve anunciar nenhuma mutação como disponível por compatibilidade com o web legado.
