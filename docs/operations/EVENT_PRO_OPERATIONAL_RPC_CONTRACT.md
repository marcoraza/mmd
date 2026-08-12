# Contrato operacional Event Pro

Este é o contrato canônico para MCP, iOS e qualquer agente operacional. Nenhum
cliente move estoque por PostgREST direto, alocação ou leitura RFID bruta.

## Regras transversais

- Todas as RPCs públicas exigem JWT de `authenticated`. `anon` e
  `service_role` sem ator não executam movimento físico.
- `viewer` só lê. `editor` e `admin` operam Conferência, Etiquetar e pendência.
  `BAIXA` e `COBRANCA` exigem `admin`.
- Toda escrita recebe `idempotency_key` com pelo menos oito caracteres. A chave
  pertence ao ator e ao payload: mesmo ator e mesmo hash devolvem o ACK ou
  Recibo persistido; qualquer ator ou payload diferente retorna
  `P0001 IDEMPOTENCY_KEY_CONFLICT`.
- Erro durante uma intenção aborta tudo. Estado de Unidade, movimentação,
  pendência, decisão e Recibo nunca ficam parciais.
- Erros de versão usam `40001 CONFERENCE_VERSION_CONFLICT`. Recarregue a
  Conferência e não repita a intenção com uma versão nova sem decisão humana.

## Conferência de saída

1. `salvar_decisao_conferencia(p_projeto_id, p_direcao, p_serial_id,
   p_resultado, p_metodo, p_source_event_id, p_captured_at,
   p_manual_reason?, p_observation?, p_idempotency_key)`

   Registra ou atualiza uma decisão de rascunho de `SAIDA`. Leitura RFID não
   confirma nada. Manual exige motivo. Uma Unidade fora do packing ou
   indisponível fica `REVISAR`.

2. `resolver_excecao_conferencia_saida(p_decision_id, p_action='ADICIONAR'|
   'IGNORAR', p_expected_version, p_idempotency_key)`

   Resolve `REVISAR` e devolve `resolution_id`, ação, ator e horário. Não move
   estoque. Só `ADICIONAR` habilita a Unidade extra para saída; `IGNORAR` a
   exclui da intenção.

3. `confirmar_conferencia_saida(p_conferencia_id, p_decision_ids,
   p_expected_version, p_idempotency_key, p_incomplete_reason?)`

   Confirma decisões `PRESENTE` resolvidas, troca cada Unidade de `DISPONIVEL`
   para `EM_CAMPO`, grava movimentações e devolve Recibo. Saída incompleta
   exige motivo. Recibo traz `confirmation_id`, Evento, direção, ator, horário,
   motivo e as Unidades aplicadas.

## RFID

- `resolver_epc_rfid(p_epc)` normaliza EPC e retorna `{ known, epc, unit }`.
  `unit` contém id, código, nome, categoria, status, localização e tag. EPC
  desconhecido retorna `known=false`. Esta RPC é estritamente read-only.

- `aplicar_vinculo_rfid(p_serial_id, p_epc, p_idempotency_key)` é a única
  escrita de EPC. `p_epc` vazio ou `null` desvincula. A resposta contém
  `operation_id`, `action` (`VINCULAR`, `MOVER`, `SUBSTITUIR` ou
  `DESVINCULAR`), EPC anterior/novo, Unidade anterior/nova, ator e horário.
  EPC é normalizado e único entre Unidades. EPC ainda ligado a Lote legado
  falha. Alterar `serial_numbers.tag_rfid` por PostgREST falha com
  `42501 RFID_TAG_WRITE_REQUIRES_OPERATION`.

## Conferência de retorno

1. `conferencia_retorno_esperado(p_projeto_id)` lista somente Unidades com
   saída física aplicada e sem retorno aplicado. Alocação não cria retorno.

2. `salvar_decisao_conferencia_retorno(p_projeto_id, p_serial_id,
   p_resultado, p_metodo, p_source_event_id,
   p_captured_at, p_desgaste?, p_manual_reason?, p_observation?,
   p_idempotency_key)`

   Registra o rascunho de retorno. `PROBLEMA` exige desgaste entre 1 e 5 e
   observação de pelo menos três caracteres. A ausência não é enviada pelo
   cliente.

3. `confirmar_conferencia_retorno(p_conferencia_id, p_decision_ids,
   p_expected_version, p_idempotency_key)`

   Aplica um retorno parcial: somente decisões existentes de `OK` ou
   `PROBLEMA`. Não cria ausência, não aceita uma decisão já aplicada e devolve
   o Recibo físico. Use quando o Evento recebe devoluções em levas.

4. `finalizar_conferencia_retorno(p_projeto_id, p_expected_version,
   p_idempotency_key)`

   É a confirmação final canônica. A versão é a da Conferência de retorno
   recém-lida pelo operador. O servidor deriva, para cada Unidade que teve
   saída física e segue sem retorno, uma decisão `NAO_VOLTOU`, muda-a para
   `RETORNANDO` e cria uma só pendência. Decisões `OK` e `PROBLEMA` já
   registradas são aplicadas na mesma transação. O Recibo traz
   `finalization_id`, ator, horário, quantidade de ausências derivadas e o
   Recibo físico com direção `RETORNO` e desgaste quando observado.

5. `resolver_pendencia_retorno(p_pendencia_id, p_acao,
   p_observacao?, p_localizacao_confirmada?, p_idempotency_key)`

   Ações: `ENCONTRADA` leva para `DISPONIVEL`; `MANUTENCAO`, para
   `MANUTENCAO`; `BAIXA`, para `BAIXA`; `COBRANCA` mantém a Unidade e registra
   a cobrança. `ENCONTRADA` exige `p_localizacao_confirmada` com ao menos três
   caracteres. Ela fica persistida na pendência e no Recibo. Manutenção e
   cobrança exigem observação. A resposta contém `resolution_id`, pendência,
   Evento, Unidade, ação, observação, localização confirmada, ator, horário e
   estado novo. A assinatura antiga de quatro parâmetros não tem grant e não
   deve ser integrada.

## Erros que o agente deve tratar

| Erro | Ação do agente |
| --- | --- |
| `28000` | Pedir sessão autenticada. |
| `42501` | Não repetir. Informar que o papel não autoriza a ação. |
| `P0001 IDEMPOTENCY_KEY_CONFLICT` | Não reutilizar a chave. Criar nova chave só para uma nova intenção humana. |
| `40001 CONFERENCE_VERSION_CONFLICT` | Recarregar Conferência e pedir nova confirmação humana. |
| `55000` | Mostrar a regra de estado: item indisponível, decisão aplicada, pendência resolvida ou Evento incompatível. |
| `22023` | Corrigir payload: decisão, motivo, observação ou chave inválida. |

## Aposentado

`checkout_projeto`, `checkout_projeto_com_override`, `checkin_projeto` e
`resolver_retorno_pendencia` não têm mais grant executável. Não integrar nem
criar fallback para eles.
