# Rodada 2: densidade e motion do detalhe do evento

## Dono e escopo

Edite somente:

- `tasks/evidence/home-2.0/prototipo-eventpro-c-finalizacao.html`
- `gauntlet/rounds/02/notes.md`

A e B são molde congelado. Não edite nenhum arquivo-fonte incorporado, nenhuma Home, nenhum fluxo RFID e nenhuma outra tela.

## Estado que precisa sobreviver

- A Rodada 1 é o melhor atual (`gauntlet/best`).
- LatBus continua Inter Tight 32px/650.
- Volta, ações, zonas e metadados continuam em SF Pro Text/system.
- Cabeçalho, menu e lista continuam na mesma coluna.
- Dock canônica continua exatamente `Início, Eventos, Catálogo, Identificar`.
- Voltar, as quatro abas, a cena determinística e o RFID histórico continuam funcionando.

## Gap medido pelo crítico cego

- passo visual das sete zonas estimado em ~57px, acima do alvo de 48-52px;
- gap entre menu escuro e lista em 20.1px, fora da base de 12 ou 16px;
- a dock ainda declara transição de `color`, enquanto a barra aceita apenas `transform` e `opacity`.

## Missão

1. Feche cada linha da lista em 50-52px sem reduzir a caixa de toque abaixo de 48px.
2. Feche o gap menu-lista em 16px computados, preservando a coluna de 38.8px.
3. Remova a transição de `color` da dock canônica; nenhuma animação nova.
4. Preserve todos os 12 PASS da Rodada 1. O ganho de densidade não pode comprimir a leitura, cortar a última zona ou fazer a dock cobrir conteúdo.

## Prova obrigatória nas notas

- família, tamanho e peso computados de título, ação, zona e metadado;
- altura computada das 7 linhas e das 3 ações;
- gaps cabeçalho-menu, menu-lista e lista-dock;
- `scrollWidth <= clientWidth` em 390x844;
- voltar e quatro destinos da dock exercitados;
- comparação de erros de console contra o baseline herdado;
- capture em 390x844 e 1440x1000 antes de encerrar.

Não faça commit. O orquestrador captura, julga e decide a trava.
