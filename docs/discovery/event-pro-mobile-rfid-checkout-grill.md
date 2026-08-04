# Grill de UX: RFID, Etiquetar, Localizar e check-out

Status: proposto para aprovação final de Marco antes do plano.

Spec aprovada e publicada: https://github.com/marcoraza/mmd/issues/8
Tickets publicados: https://github.com/marcoraza/mmd/issues/9 até https://github.com/marcoraza/mmd/issues/25

Critério delegado: escolher a resposta mais simples que preserve a operação real, reduza bloqueios e mantenha auditoria.

## Gate visual obrigatório

Toda tela, estado relevante ou componente novo passa pelo mesmo ciclo antes da implementação final:

1. Produzir cinco opções comparáveis para uma única superfície.
2. Marco escolhe uma base.
3. Produzir uma nova rodada de cinco opções derivadas apenas da base escolhida.
4. Iterar até Marco travar a superfície.
5. Avançar para a próxima superfície sem reabrir a anterior.

As cinco opções mantêm função e dados constantes. Elas variam hierarquia, composição, tipografia, peso, espaçamento, gesto, feedback e motion. Não são cinco produtos nem cinco fluxos diferentes.

Backend, contratos, modelos e testes podem avançar em paralelo. Nenhuma escolha técnica pode ser usada para encerrar uma decisão visual ainda não validada. Protótipos usados no corte são evidência de decisão, não uma segunda implementação do app.

## 1. O que significa Etiquetar?

Resposta: gerir a associação entre um EPC já gravado e uma unidade. Inclui vincular, substituir, desvincular, impedir duplicidade e auditar autoria. Não inclui programar nem bloquear a memória física da tag.

Status: aprovado por Marco.

## 2. O que entra em todo o manuseio RFID?

Resposta: conexão do RFD40, bateria, gatilho, falhas, Identificar, Etiquetar, Conferência de saída, Conferência de retorno, Localizar e resolução de tags desconhecidas ou duplicadas. Firmware, Wi-Fi e ajuste manual de antena ficam fora.

Status: aprovado por Marco.

## 3. Item perdido é tela, ação ou estado?

Resposta: separar a ação `Localizar` do estado `Pendente de resolução`. A pendência nasce no retorno ou por marcação humana. Localizar pode ser usado em qualquer unidade etiquetada sem marcá-la como perdida.

Status: aprovado por Marco.

## 4. Como deve funcionar a interface de Localizar?

Resposta: workspace focado em tela cheia, com unidade, última localização, proximidade real, resposta visual, háptica e sonora e ação Encontrei. O componente de sinal do legado é preservado como referência e redesenhado na linguagem atual.

Status: aprovado por Marco.

## 5. O que autoriza o check-out?

Resposta: a lista exata de unidades fisicamente conferidas. Somente elas mudam para `EM_CAMPO`. A alocação não pode fabricar uma saída.

Status: aprovado por Marco.

## 6. Quais métodos de conferência são aceitos?

Resposta: RFID como padrão, QR Code como fallback e confirmação manual por unidade quando tag, QR ou leitor falhar. O método manual exige unidade exata e motivo curto. Não existe Confirmar tudo.

Status: aprovado por Marco.

## 7. A saída precisa modelar cargas ou veículos?

Resposta: não. Existe uma Conferência de saída única e retomável por Evento. O progresso salva automaticamente. Uma saída incompleta pede apenas confirmação e motivo curto, pode ser feita por qualquer operador autenticado e aceita adicionar o restante depois.

Status: aprovado por Marco após simplificação.

## 8. Como tratar uma unidade diferente da alocada?

Resposta: se for do mesmo Item, estiver disponível e sem conflito, substituir automaticamente o serial alocado e auditar a troca. Item fora do packing recebe Adicionar ou Ignorar. Unidade indisponível, conflitante ou desconhecida vai para Revisar. O scanner não pausa.

Status: respondido pelo Codex usando o critério delegado.

## 9. Onde cada operação RFID aparece?

Resposta: Identificar é a única ação global. Etiquetar e Localizar aparecem na ficha da unidade e em exceções relevantes. Conferência aparece no Evento. Conectar leitor aparece apenas quando a operação atual precisa do RFD40. Não existe hub RFID nem tab RFID.

Status: respondido pelo Codex usando o critério delegado.

## 10. Como o leitor conecta sem criar mais uma jornada?

Resposta: ao abrir uma operação RFID, o app tenta reconectar o último RFD40 confiável. Se falhar, mostra uma camada curta com leitores disponíveis. Bateria, erro, trocar leitor e desconectar ficam nessa camada contextual. Não existe leitura RFID em background.

Status: respondido pelo Codex usando o critério delegado.

## 11. Como o gatilho físico se comporta?

Resposta: o gatilho só age dentro de uma operação RFID ativa. Pressionar começa a leitura e soltar pausa. O controle na tela espelha o mesmo estado. Trocar de operação encerra a leitura anterior e preserva o resultado.

Status: respondido pelo Codex usando o critério delegado.

## 12. Qual é o caminho mínimo de Etiquetar?

Resposta: partindo da unidade, ela fica fixa e o operador lê uma tag. Partindo de uma tag desconhecida, o EPC fica fixo e o operador busca a unidade. Se a tag ou a unidade já tiver associação, uma única confirmação move ou substitui a tag atomicamente. Desvincular fica na ficha da unidade com uma confirmação.

Status: respondido pelo Codex usando o critério delegado.

## 13. Como tratar tag desconhecida ou duplicada durante leitura?

Resposta: a leitura continua. Tag desconhecida aparece em Revisar e abre Etiquetar com EPC preenchido. Uma duplicidade de dados nunca escolhe uma unidade silenciosamente: mostra as associações conflitantes e exige corrigir uma delas antes de movimentar estoque.

Status: respondido pelo Codex usando o critério delegado.

## 14. Como entrar na Conferência?

Resposta: o botão principal do Evento muda pelo estado. Em Confirmado ou Montagem, abre Conferência de saída. Em campo, abre Conferência de retorno. As duas usam o mesmo shell visual, com lista dominante e scanner compacto, mas têm regras de domínio separadas.

Status: respondido pelo Codex usando o critério delegado.

## 15. Como simplificar o retorno?

Resposta: toda unidade lida começa como Voltou OK. O operador só toca nas exceções. Marcar problema pede condição e observação curta. Unidade esperada e não lida vira Pendente de resolução ao finalizar. Unidade de outro Evento entra em Revisar.

Status: respondido pelo Codex usando o critério delegado.

## 16. O que acontece sem internet?

Resposta: a leitura pode continuar e o rascunho de EPCs fica salvo localmente. O app mostra Não enviado e não declara sucesso. Resolução que dependa do servidor e qualquer movimentação final aguardam conexão e confirmação do backend. Não existe promessa de operação offline completa neste corte.

Status: respondido pelo Codex usando o critério delegado.

## 17. Quem pode operar RFID?

Resposta: toda pessoa da Equipe operacional pode conectar leitor, Identificar, Etiquetar, substituir ou desvincular tag, Localizar e Conferir. Alterações de associação pedem uma confirmação e ficam auditadas. Baixa, venda, exclusão e administração de usuários continuam restritas ao admin.

Status: respondido pelo Codex usando o critério delegado.

## 18. Como confirmar sem criar mais uma tela?

Resposta: depois do ACK do backend, o app volta ao Evento ou à unidade de origem e mostra um Recibo operacional compacto e persistente. Não existe overlay genérico de sucesso. Inclusões posteriores aparecem como novos registros dentro da mesma Conferência.

Status: respondido pelo Codex usando o critério delegado.

## 19. O que preservar visualmente do legado?

Resposta: preservar a intenção dos componentes que provaram sua função, especialmente o medidor de proximidade e a conferência por lista. Recriar estrutura, tipografia, espaçamento, gestos e hierarquia na linguagem atual. Não copiar barras, cards, headers ou navegação que repetem informação.

Status: respondido pelo Codex usando o critério delegado.

## 20. O backend realmente fica sem alterações?

Resposta: não. O Supabase e a fronteira web continuam como base, mas três contratos precisam evoluir:

1. Etiquetar precisa de transação atômica para vincular, substituir e desvincular, com unicidade e auditoria.
2. Check-out precisa receber as unidades realmente conferidas, seus métodos e motivos, aceitar confirmação parcial e posteriores adições.
3. Resolver pendência precisa registrar Encontrei e a localização confirmada.

O retorno já recebe unidades e resultados, e o registro de leituras RFID já existe. A proximidade ao vivo pertence ao app e ao SDK Zebra, não ao backend.

Status: respondido pelo Codex a partir do código atual.

## Corte recomendado

O legado não será portado por quantidade de telas. A unidade de paridade é capacidade com consequência persistente. A interface nova mantém três destinos, uma ação global de Identificar e operações contextuais focadas. O backend atual é reaproveitado, mas não está congelado: os contratos acima são necessários para que o RFID deixe de ser demonstração e passe a provar o que fisicamente aconteceu.

O plano de execução deve manter duas trilhas coordenadas: uma trilha visual sequencial, regida pelos Cortes visuais, e uma trilha técnica que pode avançar em paralelo nos contratos já aprovados. Uma superfície visual só entra como final depois de travada por Marco.
