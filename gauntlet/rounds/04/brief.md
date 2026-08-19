# Rodada 4: fecha a hierarquia da contagem

## Dono e escopo

Edite somente:

- `tasks/evidence/home-2.0/prototipo-eventpro-c-finalizacao.html`
- `gauntlet/rounds/04/notes.md`

A e B são moldes congelados. Não edite Home, fontes incorporadas, fluxo RFID, wrapper A/B/C ou qualquer outra tela.

## Estado que precisa sobreviver

- A Rodada 3 é o melhor atual (`gauntlet/best`).
- LatBus continua Inter Tight 32px/650.
- O restante da UI continua SF Pro Text/system.
- A contagem `24/36` continua como uma unidade JetBrains Mono 12px/500 e o `#hdOk` continua vivo.
- As dez linhas continuam com 58px computados e 49.24px renderizados.
- Gaps continuam 16/16; a última zona continua acima da dock.
- Motion continua restrito a transform/opacity e no máximo 300ms.
- Dock continua exatamente `Início, Eventos, Catálogo, Identificar`.
- Voltar e os quatro destinos da dock continuam funcionando.

## Gap medido pelo crítico cego

- o bloco `24/36` virou técnico, mas perdeu hierarquia interna;
- `24`, que representa o realizado, está com o mesmo peso e a mesma cor de `/36`;
- a Home aprovada já resolve esse padrão com o valor atual em 600/ink e o total em 500/sub.

## Missão

1. Faça `24/36` ler de imediato sem aumentar o tamanho nem criar chip, badge, fundo ou uma nova linha.
2. Use a gramática já aprovada da Home: realizado com peso 600 e cor de tinta; total com peso 500 e cor secundária.
3. Preserve a frase `São Paulo Expo · 11 ago · 24/36 conferidas` em uma linha e preserve o `#hdOk` vivo.
4. Preserve todos os 14 PASS da Rodada 3. Esta é uma rodada de fechamento, não de recomposição.

## Prova obrigatória nas notas

- família, tamanho, peso e cor computados de `24` e `/36` separadamente;
- teste de vida do `#hdOk` mudando 24 para 31 e voltando;
- altura renderizada das 10 linhas e gaps 16/16;
- fim da última zona versus topo da dock;
- `scrollWidth <= clientWidth` em 390x844;
- voltar e quatro destinos da dock exercitados;
- comparação de erros de console contra o melhor atual;
- capture em 390x844 e 1440x1000 antes de encerrar.

Não faça commit. O orquestrador captura, julga e decide a trava.
