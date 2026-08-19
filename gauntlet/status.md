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

Estado após a Rodada 2:

- candidato venceu o melhor anterior por 14 PASS contra 12;
- ações e zonas agora têm 52px computados e ritmo vertical 16/16;
- motion do detalhe ficou restrito a transform/opacity e abaixo de 300ms;
- evidência de 390x844 e 1440x1000 passou no gate;
- nenhum PASS anterior virou FAIL;
- caçador da Rodada 2 ainda fará a leitura lateral antes do próximo brief.
