# Rodada 0: brief do detalhe do evento

## Pedaço

Detalhe do evento LatBus, da volta `Eventos` até a barra inferior. A agenda, a Home, Catálogo e o RFID histórico ficam fora do corte e não podem regredir.

## Fonte da verdade

- Spec: `/Users/marko/Projects/mmd/docs/specs/mockup-finalizacao-gauntlet.md`
- Barra: `/Users/marko/Projects/mmd/gauntlet/BAR.md`
- Gramática: `/Users/marko/Projects/mmd/gauntlet/GRAMATICA.md`
- Baseline: `/Users/marko/Projects/mmd/gauntlet/rounds/00/detalhe-evento-baseline-390-light.png`
- Cena: `http://127.0.0.1:8933/prototipo-eventpro-c-finalizacao.html?tab=eventos&scene=event-detail`

## Arquivo do dono

O construtor pode editar somente:

`/Users/marko/Projects/mmd/tasks/evidence/home-2.0/prototipo-eventpro-c-finalizacao.html`

A e B são somente leitura. O arquivo base `prototipo-eventpro-b-isolado.html` também é somente leitura.

## Objetivo da primeira rodada

Fazer o detalhe parecer continuação inevitável da Home e de Eventos, sem redesenhar o produto. Primeiro ataque: retirar o excesso de peso tipográfico das linhas operacionais, usando SF Pro Text/system no corpo, e ajustar a proporção entre cabeçalho, menu de ação e lista.

## Não negociar

- barra da Home com quatro abas e sem botão RFID separado;
- LatBus, São Paulo Expo, 11 ago, 24/36 e sete zonas fixos;
- ações `Continuar leitura`, `Ler QR code` e `Adicionar manualmente`;
- estados completo e pendente das zonas;
- volta para a agenda funcionando;
- `Identificar` continua abrindo o RFID histórico;
- nenhum valor novo fora da Identidade e da `GRAMATICA.md`.

## Último veredito

Baseline, sem crítico. Maior gap inicial: as linhas de ação e zonas ainda usam Inter Tight e parecem mais pesadas que o corpo da Home; a tela está correta, mas não totalmente casada.

Ruído herdado conhecido: dois iframes legados invisíveis lançam exceções próprias e o servidor local pede `favicon.ico`. Eles já existem na Rodada 0, não entram no pick visual desta sessão e serão removidos na consolidação global. Nenhum erro novo é aceito.
