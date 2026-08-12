# Plano de execução: fechamento do Event Pro sem iOS

Trava: `docs/operations/FECHAMENTO_EVENT_PRO_SEM_IOS_GOAL.md`
Spec: GitHub issue `#27`

## Setup e isolamento

1. Registrar branch, HEAD, migrations locais/remotas e worktree sujo.
2. Criar worktree em `/Users/marko/Projects/mmd/.worktrees/event-pro-backend-completo` numa branch `codex/event-pro-backend-completo` baseada no HEAD commitado.
3. Não copiar nem incorporar arquivos não commitados da sessão iOS.
4. Fixar o commit-base do review antes da primeira edição.

## Wave A: segurança e baseline real

1. Reproduzir no banco local o advisor remoto que aponta RLS desligada.
2. Auditar policies e consumidores de `items`, `serial_numbers`, `projetos`, `packing_list`, `movimentacoes` e `lotes`.
3. Criar teste de roles antes da migration.
4. Ativar RLS em migration separada e provar acesso legítimo, bloqueio público e compatibilidade Web.
5. Rodar reset, pgTAP, lint, security advisor e testes Web.
6. Fazer review antes de qualquer aplicação remota.
7. Dry-run, aplicar no remoto e verificar schema, roles e advisor.

## Wave B: RFID server-side e Revisar

1. Mapear contratos existentes de RFID, vínculo de tag, scans e callers não iOS.
2. Entregar resolução read-only de EPC para Identificar.
3. Entregar operação única para vincular, substituir, mover e desvincular EPC.
4. Persistir ator, horário, ação, Unidade anterior e Unidade nova.
5. Provar unicidade, concorrência, retry e rollback.
6. Completar resoluções do check-out para Adicionar e Ignorar item fora do packing.
7. Provar que desconhecido, indisponível ou conflito permanece em Revisar sem movimento.

## Wave C: retorno e pendências

1. Fixar o contrato de retorno sobre saídas aplicadas.
2. Implementar confirmação idempotente para `OK`, `PROBLEMA` e `NAO_VOLTOU`.
3. Exigir condição e observação para problema e encaminhar manutenção na mesma transação.
4. Criar pendência única para Unidade esperada não retornada.
5. Implementar resoluções encontrada, manutenção, baixa e cobrança com permissão explícita.
6. Integrar localização confirmada como dado de resolução sem simular proximidade.
7. Provar histórico de Evento e Unidade, retry e rollback.

## Wave D: resiliência e aposentadoria segura

1. Padronizar chave idempotente, hash, ACK persistido e conflito em toda escrita operacional.
2. Injetar timeout antes e depois do commit.
3. Exercitar retry concorrente e conflito de versão.
4. Localizar todas as escritas diretas e callers dos RPCs legados.
5. Migrar ou bloquear todo caller não iOS inseguro.
6. Remover o caminho legado quando não houver caller vivo. Se o iOS excluído for o único blocker, registrar a dependência exata e não fingir remoção.

## Integração, reviews e produção

1. Integrar por commits pequenos, um domínio por commit.
2. Rodar suíte completa local após cada join.
3. Rodar review independente de Standards e Spec.
4. Rodar `raza-thermo` porque banco, auth, permissões e produção são alto risco.
5. Corrigir findings e repetir review até dois rounds limpos.
6. Publicar migrations aditivas após dry-run e smoke local.
7. Verificar migrations, schema, grants, RLS e advisors no remoto.
8. Push da branch e relatório final separado em entregue, prova e dependências exclusivas de iOS/hardware.

## Autoridade concedida dentro do goal

- Pode criar worktree e branch isoladas nos caminhos definidos acima.
- Pode editar `supabase/**`, testes e código server-side de `apps/web/**` necessário aos contratos.
- Pode criar commits seletivos e fazer push da branch do goal.
- Pode aplicar no projeto Supabase vinculado `bphmxticdyuctovfumcj` migrations novas e aditivas que passaram por dry-run e review limpo.
- Pode executar smoke controlado com fixtures exclusivas de teste e restauração provada.
- Não pode executar `DROP`, `TRUNCATE`, delete de dados reais, backfill destrutivo, force-push, merge ou deploy Web sem nova autorização.
- Não pode tocar em `apps/ios/**` nem incorporar o WIP da outra sessão.

## Condição de parada

O goal termina quando a Definition of Done da trava passar ou quando a única dependência restante exigir código iOS, escolha visual humana ou RFD40 físico. O squad resolve qualquer blocker de banco, API, segurança ou teste que não dependa desses itens.
