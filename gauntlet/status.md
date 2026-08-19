# status.md: finalização do mockup Event Pro

Spec operacional: `docs/specs/mockup-finalizacao-gauntlet.md`

Receita: **4 rodadas por sessão**.

Papéis:

- orquestrador: agente principal desta tarefa;
- construtor: processo Claude novo com `--model opus`, dono único da versão C;
- crítico cego: processo Claude novo com `--model opus`, somente leitura e visão dos PNGs.

O caçador das rodadas 2 e 4 usa um agente novo do papel de crítico, sem criar um quarto papel simultâneo.

Modelo confirmado pelo harness antes da Rodada 1: `claude-opus-5`, contexto 1M, canal Claude Code 2.1.235.

Parada: quatro rodadas; duas rejeições/anulações seguidas; ordem explícita de Marco. A próxima sessão só começa com aprovação de Marco.

Sessões: fundação da barra concluída; **detalhe do evento em execução**; depois conferência de saída; RFID completo; separação por zona; retorno; Catálogo; Mais/Ajustes; consolidação global.

## Registro por rodada: detalhe do evento

| Rodada | pick cego escolheu o novo? | PASS do melhor | maior gap | trava moveu? | modelo real |
|---|---:|---:|---|---|---|
| 00 | baseline | a medir na R1 | tipografia das linhas ainda usa Inter Tight e pesa mais que a Home | baseline gravado | orquestrador atual |
| 01 | sim, candidato B | 12/14 | lista ainda alta: ~57px por passo e gap de 20.1px | sim, `9790d5f` | `claude-opus-5` |
| 02 | sim, candidato B | 14/14 | contagem técnica `24/36` ainda sem textura mono | sim, `3f5852c` | `claude-opus-5` |
| 03 | sim, candidato B | 14/14 | `24/36` ainda tem pouca hierarquia de leitura | sim, `047f211` | `claude-opus-5` |
| 04 | sim, candidato B | 14/14 | escada tipográfica no teto, sem falha de barra | sim, `fa3313e` | `claude-opus-5` |

Estado após a Rodada 2:

- candidato venceu o melhor anterior por 14 PASS contra 12;
- ações e zonas agora têm 52px computados e ritmo vertical 16/16;
- motion do detalhe ficou restrito a transform/opacity e abaixo de 300ms;
- evidência de 390x844 e 1440x1000 passou no gate;
- nenhum PASS anterior virou FAIL;
- caçador da Rodada 2 ainda fará a leitura lateral antes do próximo brief.

Caçador da Rodada 2:

- encontrou perda de cerca de 5px na altura renderizada das linhas;
- encontrou aumento de cerca de 49.5px no vazio antes da dock;
- encontrou alvos de ação visualmente no limite de 44px;
- a Rodada 3 deve manter os ganhos de motion e ritmo, mas recuperar a densidade visual e tratar `24/36` como dado técnico.

Estado após a Rodada 3:

- candidato venceu o melhor anterior por 14 PASS contra 13;
- linhas de ação e zona agora rendem 49.24px no PNG e mantêm 58px de caixa computada;
- a faixa morta antes da dock caiu para 9.11px renderizados;
- `24/36` virou uma unidade técnica em JetBrains Mono sem quebrar o `#hdOk` vivo;
- evidência de 390x844 e 1440x1000 passou no gate;
- nenhum PASS anterior virou FAIL;
- a Rodada 4 deve fechar a hierarquia da contagem sem alterar composição, densidade ou navegação.

Estado após a Rodada 4:

- candidato venceu o melhor anterior no pick cego, com 14 PASS contra 14;
- `24` agora usa JetBrains Mono 12px/600 em tinta e `/36` permanece 12px/500 em cinza secundário;
- composição, densidade, gaps, navegação e motion permaneceram intactos;
- evidência de 390x844 e 1440x1000 passou no gate;
- caçador independente encontrou zero regressões;
- sessão `detalhe do evento` concluiu as quatro rodadas e está pronta para aprovação de Marco.

## Pick final contra a Rodada 0

- mapeamento cego: A = final da Rodada 4; B = baseline da Rodada 0;
- crítico Opus escolheu A por 14 PASS contra 10;
- final terminou com zero regressões listadas;
- ganhos objetivos: coluna única, SF Pro no degrau operacional, mono só em dado técnico, passo visual de 49.24px e motion restrito a transform/opacity;
- comparação A/B/C e showcase local foram capturados com o código servido, ambos passaram no gate de evidência.
