# Direção visual: tutorial MMD Estoque em 5-6 minutos

Versão: `0.1.0-director-brief`  
Data: `17/07/2026`  
Destino: Claude Design, template Animation  
Status: direção de picture lock visual, voz será produzida depois

## Missão

Criar o sistema visual e o storyboard animado de um tutorial operacional de 5 a 6 minutos para uma pessoa que nunca viu o MMD Estoque.

O vídeo precisa ensinar, não apenas mostrar telas. Em cada passo, o espectador deve entender:

1. onde clicar ou tocar
2. o que aquela ação faz
3. qual resultado precisa aparecer
4. como esse resultado se conecta ao próximo passo

Use os screenshots fornecidos como fonte visual do produto. Não redesenhe a interface. Organize enquadramento, ritmo, zoom, cursor, anéis, sublinhados, textos e transições da forma que produzir a explicação mais clara.

## Público

Operador novo da MMD, sem conhecimento prévio do sistema. Ele conhece a operação física de eventos, mas não precisa conhecer banco de dados, estados internos ou termos de software.

## Entrega visual esperada

- formato principal 16:9, 2560x1440
- duração alvo entre 5:30 e 6:00
- movimento contínuo, sem parecer apresentação de slides
- cursor visível no Web e gesto visível no iPhone
- clique ou toque marcado com pulso
- elemento explicado circulado ou contornado com precisão
- termo importante sublinhado quando a narração o introduzir
- zoom ou recorte para leitura de detalhes
- texto didático curto explicando ação e consequência
- subtítulo pt-BR provisório no padrão Netflix: no máximo 2 linhas, área segura, alto contraste, sem cobrir o clique
- capítulos ou indicador de progresso discretos
- transições que mostrem causa e efeito, principalmente Web para iPhone e iPhone para Web

O layout, o sistema de motion e a hierarquia dos elementos ficam a cargo do Claude Design. Os requisitos acima são funcionais, não uma prescrição de composição.

## Linguagem visual

- respeitar o produto dark-first e o Liquid Glass 2030
- usar laranja como cor didática para clique, foco, anel e sublinhado
- manter cyan, verde e violeta apenas quando já comunicam estado no produto
- tipografia direta, adulta e operacional
- nada de estética de anúncio, mockup flutuante ou slogan
- cada frame precisa ter um assunto visual dominante
- textos devem apontar para o elemento real da interface

## Regras de verdade

- o Evento usado é `Treinamento · Marcelo`, isolado de Eventos de cliente
- Web e iPhone usam o mesmo Evento, o mesmo packing e a mesma fonte de verdade
- Item é o tipo de equipamento; Serial Number é a unidade física
- RFID é a operação principal; QR é fallback explícito
- não tratar mock ou simulador como prova de hardware real
- os screenshots iOS atuais são storyboard e precisam permanecer identificados como tal
- a captura final do mobile será refeita com iPhone, Zebra RFD40 e tags reais do Marcelo
- não mostrar senha, token, chave, cookie, EPC completo ou dado pessoal
- não inventar estados ou ações que não aparecem nos materiais

## Estrutura narrativa

### Cena 01, 00:00-00:20, o mapa do ciclo

**Objetivo:** dar contexto antes do primeiro clique.

**Visual:** abertura curta com o ciclo em quatro verbos: preparar, despachar, receber, auditar. Em seguida, revelar lado a lado Web e iPhone conectados ao mesmo Evento.

**Texto didático na tela:** `Um Evento. Duas ferramentas. Um único estado do estoque.`

**Subtítulo provisório:**

> O MMD Estoque acompanha o equipamento do planejamento ao retorno. A gestão acontece no Web. A conferência física acontece no iPhone. Os dois usam o mesmo Evento e precisam terminar mostrando o mesmo estado.

**Conexão:** aproximar o Web e entrar no dashboard.

### Cena 02, 00:20-00:48, dashboard e Evento de treinamento

**Asset principal:** `web-dashboard.png`

**Onde apontar:** resumo operacional do estoque e card `Treinamento · Marcelo`.

**Ação visual:** circular o resumo. Destacar disponíveis, em campo e manutenção em sequência. Mover o cursor até o card do Evento e marcar o clique.

**Texto didático na tela:** `Primeiro leia a operação. Depois abra o Evento que precisa de ação.`

**Subtítulo provisório:**

> O dashboard é a leitura rápida do estoque. Aqui você confere o que está disponível, o que está em campo e o que foi para manutenção. Para treinar sem tocar Evento de cliente, procure Treinamento Marcelo e clique no card.

**Resultado esperado:** ficha do Evento aberta.

### Cena 03, 00:48-01:12, Item e unidade física

**Asset principal:** `web-catalogo.png`

**Onde apontar:** busca, filtro por categoria e controle de tipo de visualização.

**Ação visual:** digitar ou simular a busca. Alternar o foco entre tipo de Item e unidades físicas. Conectar visualmente uma linha de packing a uma unidade com código MMD.

**Texto didático na tela:** `Item = tipo de equipamento` e `Serial Number = peça física`.

**Subtítulo provisório:**

> Antes do packing, guarde esta diferença. Item é o tipo de equipamento pedido pelo Evento. Serial Number é a peça física que recebe código MMD, RFID, QR, condição e histórico. O packing pede o Item. A saída movimenta as unidades escolhidas.

**Conexão:** voltar ao Evento com a diferença já estabelecida.

### Cena 04, 01:12-01:42, ficha do Evento e gate bloqueado

**Asset principal:** `web-evento.png`

**Onde apontar:** nome, datas, prontidão e Gate de saída.

**Ação visual:** revelar o cabeçalho do Evento. Circular nome e período. Descer para o Gate e sublinhar o motivo do bloqueio.

**Texto didático na tela:** `O gate impede uma saída incompleta.`

**Subtítulo provisório:**

> Confira nome, local, datas e status antes de movimentar qualquer unidade. O Gate de saída explica se o Evento pode sair. Neste estado, ele está bloqueado porque o packing ainda não cobre tudo o que foi planejado.

**Resultado esperado:** operador sabe por que não deve tentar o check-out ainda.

### Cena 05, 01:42-02:08, packing 4 de 5

**Asset principal:** `web-packing.png`

**Onde apontar:** cobertura quatro de cinco, linha incompleta e próximo passo.

**Ação visual:** fazer zoom na contagem. Percorrer as linhas até a unidade faltante. Circular a linha e conectar por seta ao próximo passo `Alocação`.

**Texto didático na tela:** `Necessário: 5. Coberto: 4. Falta resolver 1 unidade.`

**Subtítulo provisório:**

> O packing compara o que o Evento precisa com o que já está coberto. Aqui existem cinco unidades planejadas e apenas quatro cobertas. A linha incompleta mostra qual Item falta. O próximo passo seguro é abrir Alocação.

**Conexão:** cursor viaja até a aba Alocação.

### Cena 06, 02:08-02:42, selecionar a unidade correta

**Asset principal:** `web-alocacao.png`

**Onde apontar:** linha sem cobertura, botão de selecionar unidade, disponibilidade e conflito.

**Ação visual:** clicar em Alocação, circular a linha faltante, abrir o seletor e percorrer os campos que provam disponibilidade. O clique final de confirmação pode ficar suspenso se o material ainda for read-only.

**Texto didático na tela:** `Escolha uma unidade disponível e sem conflito nas datas.`

**Subtítulo provisório:**

> Na Alocação, você escolhe a peça física que vai atender a linha. Antes de confirmar, confira o código MMD, a condição e se existe conflito nas datas do Evento. Aluguel e override são exceções. Não use esses caminhos para esconder uma unidade própria disponível.

**Resultado esperado:** packing passa para cinco de cinco e o gate é liberado.

### Cena 07, 02:42-03:08, check-out e prova no sistema

**Assets principais:** `web-evento.png` e `web-dashboard.png`

**Onde apontar:** gate liberado, botão de check-out, status do Evento e contadores do dashboard.

**Ação visual:** mostrar a mudança 4/5 para 5/5. Pulsar o botão de check-out. Usar transição de causa e efeito até o dashboard atualizado.

**Texto didático na tela:** `O clique inicia a saída. A prova é o estado atualizado.`

**Subtítulo provisório:**

> Com o gate liberado, revise a lista e confirme o check-out. Não pare no botão ou no aviso de sucesso. A prova é o Evento em campo, as unidades com o novo status e o dashboard refletindo a saída.

**Conexão:** a saída feita na gestão vira conferência física no iPhone.

### Cena 08, 03:08-03:30, passagem para o galpão

**Assets principais:** `web-evento.png` e `ios-home.png`

**Ação visual:** manter o Evento visível no Web e revelar o mesmo fluxo no iPhone. Animação deve deixar claro que não são sistemas paralelos.

**Texto didático na tela:** `O iPhone executa no campo a regra preparada no Web.`

**Subtítulo provisório:**

> Agora o trabalho sai da mesa e vai para o galpão. O iPhone não recria o Evento. Ele abre o mesmo packing e registra as mesmas transições na mesma base.

### Cena 09, 03:30-03:58, escolha da tarefa e modo do leitor

**Assets principais:** `ios-home.png` e `ios-runtime.png`

**Onde tocar:** card `Despachar`, engrenagem de configuração e switch do leitor simulado.

**Ação visual:** tocar em Despachar. Mostrar rapidamente onde fica Config. Circular `Leitor simulado`, desligar e sublinhar `Zebra SDK` como resultado obrigatório.

**Texto didático na tela:** `Para operar de verdade, o modo ativo precisa mostrar Zebra SDK.`

**Subtítulo provisório:**

> Na tela inicial, toque em Despachar. Antes da primeira leitura, abra Config e desligue o leitor simulado. Continue somente quando o modo ativo mostrar Zebra SDK. Simulado serve para diagnóstico, não comprova o leitor físico.

### Cena 10, 03:58-04:22, conectar o RFD40

**Asset principal:** `ios-conectar.png`

**Onde tocar:** leitor encontrado, estado conectado e bateria.

**Ação visual:** mostrar o RFD40 fora da lista, descoberta e seleção. Pulsar o toque no leitor. Circular `Conectado`, nome do leitor e bateria.

**Texto didático na tela:** `Leitura só começa depois da conexão confirmada.`

**Subtítulo provisório:**

> Ligue o RFD40, autorize o Bluetooth e selecione o leitor encontrado. Aguarde o estado Conectado. Quando o SDK informar bateria, confira também esse valor. Se o leitor não aparecer, verifique carga e pareamento. Não ative o modo simulado para continuar.

### Cena 11, 04:22-04:50, ler tags e interpretar o resultado

**Asset principal:** `ios-tags.png`

**Onde apontar:** contador de tags, lista de leituras, tag conhecida e tag desconhecida.

**Ação visual:** sincronizar pulso no gatilho com incremento do contador. Destacar uma tag que resolve unidade e outra que permanece sem vínculo. Preservar a lista.

**Texto didático na tela:** `Conhecida: abre a unidade` e `Desconhecida: fica visível para tratamento`.

**Subtítulo provisório:**

> Aperte o gatilho e confira o contador. Uma tag conhecida precisa abrir a unidade correta. Uma tag desconhecida continua visível para tratamento. Ela não desaparece e não vira equipamento por aproximação. No take final, pelo menos cinco tags reais precisam aparecer na mesma leitura.

### Cena 12, 04:50-05:12, check-out no iPhone e reflexo no Web

**Asset principal:** `ios-checkout.png`

**Onde tocar:** botão Escanear, contagem do packing e confirmação da saída.

**Ação visual:** pulsar Escanear. Mostrar o radar e a contagem crescendo. Só revelar a confirmação quando a cobertura estiver completa. Depois, fazer uma passagem curta ao histórico Web.

**Texto didático na tela:** `Escanear confere. Confirmar saída movimenta.`

**Subtítulo provisório:**

> No check-out, Escanear confere as peças do packing. A confirmação só deve aparecer quando a lista estiver completa. Depois do toque final, confira no Web o Evento em campo, o operador e o horário. Isso prova que a ação foi persistida.

### Cena 13, 05:12-05:38, retorno e pendências

**Asset principal:** `ios-retorno.png`

**Onde tocar:** estados OK, problema, não voltou e pendente; alternância RFID e QR.

**Ação visual:** circular os quatro resultados em sequência. Mostrar uma unidade indo para disponível, outra para manutenção e outra criando pendência. Tocar no seletor QR apenas depois de declarar RFID indisponível.

**Texto didático na tela:** `O retorno registra o que aconteceu de verdade.`

**Subtítulo provisório:**

> No retorno, marque o resultado real de cada unidade. OK volta para disponível. Problema exige observação e vai para manutenção. Não voltou cria uma pendência. Quando o RFID estiver indisponível de forma explícita, use o QR. Isso é fallback por câmera, não leitura por rádio.

### Cena 14, 05:38-05:55, QR público e auditoria

**Assets principais:** `web-qr-publico.png` e `web-auditoria.png`

**Onde apontar:** dados mínimos da ficha pública e histórico de movimentações.

**Ação visual:** abrir a ficha pública pelo QR. Circular apenas identificação e contato. Em seguida, revelar o histórico com operador, horário e unidade.

**Texto didático na tela:** `QR identifica com segurança. Auditoria explica o que aconteceu.`

**Subtítulo provisório:**

> O QR público identifica a unidade sem mostrar valor, RFID, localização ou histórico interno. A auditoria fecha o ciclo com operador, horário, unidade e movimento. Se a tela e o equipamento físico divergirem, preserve a evidência e resolva antes do próximo Evento.

### Cena 15, 05:55-06:00, fecho

**Visual:** ciclo completo volta à tela com os quatro verbos já concluídos.

**Texto didático na tela:** `Preparar. Despachar. Receber. Auditar.`

**Subtítulo provisório:**

> Web e iPhone terminam no mesmo estado. Esse é o ciclo seguro da MMD.

## Assets enviados

### Web

- `web-login.png`
- `web-dashboard.png`
- `web-catalogo.png`
- `web-evento.png`
- `web-packing.png`
- `web-alocacao.png`
- `web-auditoria.png`
- `web-qr-publico.png`

### iPhone

- `ios-home.png`
- `ios-runtime.png`
- `ios-conectar.png`
- `ios-tags.png`
- `ios-checkout.png`
- `ios-retorno.png`

### Referência negativa

- Existe um rough anterior de 56 segundos. Ele mostra a ordem básica, mas é rápido demais, explica pouco e não é referência de qualidade ou ritmo. Não tente preservar sua montagem.

## O que o Claude Design deve decidir

- sistema visual de anel, clique, seta, sublinhado e spotlight
- enquadramentos e zooms de cada screenshot
- posição dos textos sem cobrir a ação
- ritmo interno de cada cena
- transições entre Web e iPhone
- hierarquia entre texto didático e subtítulo provisório
- indicador de capítulo ou progresso
- tratamento de frames iOS identificados como storyboard

## O que precisa voltar para direção

1. uma proposta visual completa para o vídeo 16:9
2. storyboard ou timeline animada das 15 cenas
3. pelo menos três cenas-chave desenvolvidas com motion: dashboard, alocação e leitura RFID
4. sistema reutilizável de callouts e legendas
5. indicação clara de quais pontos ainda dependem da recaptura com RFD40 real

Não produzir voz agora. O picture lock e o timing das legendas vêm primeiro. A voz pt-BR será feita no último passe, com revisão de pronúncia para MMD, RFD40, RFID, packing, check-out, QR, Zebra e Marcelo.
