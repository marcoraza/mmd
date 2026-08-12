# Fechamento do Event Pro sem iOS: Trava antes do Goal

## Missão

Fechar todas as entregas de banco, segurança, API, contratos server-side, auditoria e testes do plano Event Pro, deixando como pendência apenas trabalho que exige Swift, interface iOS, RFD40 físico ou escolha visual humana.

## Premissa central

*Só uma decisão física persistida por Unidade pode autorizar movimento de estoque. Alocação, leitura bruta, tentativa de envio ou ausência de erro não provam saída nem retorno.*

## Contexto

A Wave 0 e o contrato backend da Wave 1 estão implementados. A migration da Conferência física já foi publicada no Supabase remoto. O restante não iOS está espalhado entre segurança antiga, associação RFID, resolução de exceções, retorno, pendências e hardening de concorrência.

O goal precisa fechar essas fatias sem tocar no WIP iOS mantido por outra sessão, sem declarar hardware validado por mock e sem encerrar tickets mistos enquanto os critérios iOS continuarem abertos.

## Mapa do sistema

- Entrada: operador autenticado, Evento, Unidade, EPC, decisão física, evidência e chave idempotente.
- Processamento: autorização, resolução, lock, validação, transação, auditoria e resposta persistida.
- Saída: estado atual coerente, histórico único, Recibo ou pendência rastreável.
- Fronteira de confiança: Supabase autenticado e suas transações. Cliente, leitura RFID e Alocação são entradas não confiáveis até validação.

## Regras duras

- Não tocar em `apps/ios/**`, projeto Xcode, Swift, protótipos ou evidências visuais iOS.
- Preservar todo WIP existente e trabalhar em worktree isolado.
- Nunca derivar saída ou retorno da Alocação.
- Nunca transformar leitura RFID bruta em movimento sem decisão resolvida.
- Aplicar estado atual, movimentação, auditoria, Recibo e pendência na mesma transação quando pertencem à mesma intenção.
- Toda escrita operacional deve exigir ator autorizado e chave idempotente.
- Retry igual deve retornar o mesmo resultado. Chave igual com intenção diferente deve gerar conflito.
- Falha em qualquer ponto deve preservar o estado anterior completo.
- `anon` não pode ler dados internos nem executar operação de estoque.
- `service_role` não pode virar atalho sem ator para operação física.
- Ativar RLS nas tabelas públicas com policies existentes depois de provar que os consumidores legítimos continuam funcionando.
- Não remover caminho legado enquanto houver caller vivo que ainda depende dele. Não mantê-lo como autoridade concorrente depois que o caller novo estiver comprovado.
- Não criar tela web para substituir o iOS. Alterar Web apenas em API, server action, contrato, teste ou bloqueio necessário para impedir escrita insegura.
- Não marcar RFD40, proximidade, VoiceOver, Reduzir Movimento ou fluxo físico como validados sem a prova correspondente.
- Não fechar issue mista se qualquer critério iOS, visual ou físico continuar aberto.
- Não terminar o goal enquanto houver uma pendência de banco, API, segurança ou teste que o squad possa executar sem iOS.

## Fonte da verdade

- Plano canônico: GitHub issue `#27`.
- Regras de produto: `CONTEXT.md`.
- Invariantes: `docs/adr/0005-physical-conference-authorizes-checkout.md` e `docs/adr/0006-contextual-mobile-capability-parity.md`.
- Estado real: migrations versionadas, histórico do Supabase remoto, schema remoto e testes executáveis.
- Tickets de execução: issues `#9` a `#25`, nas fatias não iOS.

## Papéis obrigatórios

- Supervisor: protege esta trava, integra as fatias, decide dependências e só declara pronto com prova.
- Executor Segurança e Base: corrige RLS, grants, projections e drift de produção.
- Executor RFID e Exceções: fecha associação EPC, Identificar read-only e resoluções de Revisar.
- Executor Retorno e Resiliência: fecha retorno, pendências, idempotência, concorrência e fault injection.
- Review final: agentes independentes cobrem Standards, Spec e risco de produção depois da integração.

## Entregas

- Migration separada que reconcilia RLS e grants antigos sem quebrar consumidores autorizados.
- Contrato read-only para resolver EPC conhecido ou desconhecido sem movimentar estoque.
- Operação atômica, auditada e idempotente para vincular, mover, substituir e desvincular EPC.
- Resolução persistida de exceções do check-out, incluindo Adicionar e Ignorar item fora do packing.
- Conferência de retorno derivada apenas de saídas aplicadas, com `OK`, `PROBLEMA` e `NAO_VOLTOU`.
- Pendências idempotentes com resolução como encontrada, manutenção, baixa ou cobrança conforme permissão.
- Hardening de timeout, retry concorrente, conflito de versão e rollback completo nas escritas operacionais.
- Testes de contrato e integração para todo comportamento novo.
- Migrations aditivas aplicadas e verificadas no Supabase remoto.
- Branch publicada com commits seletivos e relatório exato do que resta por depender de iOS ou hardware.

## Definition of Done

- [ ] As seis tabelas antigas apontadas pelo advisor estão com RLS ativa no banco local e no remoto.
- [ ] Security advisor remoto não apresenta erro novo ou erro relacionado às superfícies tocadas.
- [ ] Perfis legítimos mantêm leitura e escrita permitidas. `anon`, perfil insuficiente e `service_role` sem ator falham fechados.
- [ ] Identificar resolve EPC sem alterar Unidade, Alocação, Conferência ou movimentação.
- [ ] Associação EPC é única, atômica, idempotente e auditada sob retry e concorrência.
- [ ] Item fora do packing permanece em Revisar até Adicionar ou Ignorar, sem movimento implícito.
- [ ] Retorno esperado nasce de saídas aplicadas e de nenhuma outra origem.
- [ ] Retorno `OK`, `PROBLEMA` e `NAO_VOLTOU` produz estado, histórico e Recibo coerentes.
- [ ] Ausência cria uma única pendência e cada resolução respeita permissão e idempotência.
- [ ] Fault injection prova rollback de todas as tabelas alteradas por cada intenção.
- [ ] Timeout antes do commit não cria efeito. Timeout depois do commit retorna o ACK persistido no retry.
- [ ] Retry concorrente não duplica associação, movimento, Recibo ou pendência.
- [ ] Nenhum caller não iOS usa escrita direta por PostgREST para movimento físico.
- [ ] O squad removeu o checkout legado ou registrou que o caller iOS excluído é a única dependência para removê-lo.
- [ ] Reset local, pgTAP, lint, advisors, testes Web e build passam.
- [ ] Reviews independentes de Standards, Spec e risco fecham com zero finding bloqueante.
- [ ] Histórico local e remoto de migrations termina alinhado.
- [ ] Schema e comportamento remoto passam smoke tests read-only e operações controladas quando houver fixture segura.
- [ ] Commits e push contêm o escopo não iOS e nenhum arquivo do WIP iOS.
- [ ] O relatório final lista pendências Swift, visuais, RFD40 físico ou gates que dependem desses itens.

## Frase final de aceite

**O backend pode receber e aplicar qualquer decisão operacional prevista no plano com segurança e prova, mas não pode fingir que o iOS, o visual ou o hardware foram entregues.**
