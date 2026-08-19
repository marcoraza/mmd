# Rodada 3: recuperar densidade visual e tratar a contagem

## Dono e escopo

Edite somente:

- `tasks/evidence/home-2.0/prototipo-eventpro-c-finalizacao.html`
- `gauntlet/rounds/03/notes.md`

A e B continuam congelados. Não edite fontes incorporadas nem outra tela.

## Estado que precisa sobreviver

- Melhor atual: Rodada 2 (`gauntlet/best`).
- Tipografia e coluna aceitas na Rodada 1.
- Motion aceito na Rodada 2: somente transform/opacity, máximo 300ms.
- Gaps computados de 16/16.
- Dock canônica e todos os caminhos funcionais.

## Leitura do crítico e do caçador

O crítico aceitou a Rodada 2 por 14/14. O caçador detectou três perdas no PNG:

- linhas renderizadas caíram para cerca de 44-46.5px;
- vazio antes da dock cresceu cerca de 49.5px;
- ações ficaram no limite visual de 44px.

Isso aconteceu porque 52px computados passam pela escala 0.849 do preview. Para a barra visual de 48-52px, a linha precisa voltar a cerca de 58px computados, que rende aproximadamente 49.2px no PNG.

O maior gap restante do crítico: a contagem técnica `24/36` ainda fala SF Pro, enquanto contagens técnicas da Home usam textura mono.

## Missão

1. Recupere ações e zonas em cerca de 49-50px renderizados, sem perder o ritmo de 16/16 e sem voltar ao gap de 19px.
2. Elimine o vazio morto antes da dock por consequência do ritmo, sem mover a dock nem adicionar conteúdo decorativo.
3. Trate o conjunto `24/36` como uma unidade técnica em JetBrains Mono, 12-13px, preservando o `<b id="hdOk">` vivo para futuras atualizações.
4. Preserve os 14 PASS da Rodada 2, sobretudo motion e navegação.

## Prova obrigatória

- alturas computadas e renderizadas das 7 zonas e 3 ações;
- gaps computados e renderizados;
- folga final lista-dock;
- DOM de `24/36` mostrando que `#hdOk` continua presente e atualizável;
- tipografia computada de toda a linha de contagem;
- varredura de motion, overflow, estados e console;
- voltar e quatro destinos da dock;
- captura 390x844 e 1440x1000.

Não faça commit.
