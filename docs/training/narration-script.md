# Roteiro de locução do treinamento MMD

Versão: `0.1.0-draft`  
Data: `17/07/2026`  
Status: roteiro anterior ao picture lock, não é transcript final

Este texto acompanha as cenas aprovadas em `shot-log.md`. Instruções entre colchetes não são faladas. A locução final só é gravada depois que a duração de cada take estiver fechada. VTT, transcript e timecodes saem desse corte, nunca de duração estimada.

## Abertura do master

[Mostrar o nome do treinamento e o Evento isolado]

> Este treinamento cobre o ciclo que a MMD executa todo dia: preparar um Evento, conferir o que sai, registrar o retorno e saber o que ficou pendente. Tudo acontece no Evento `Treinamento · Marcelo`, separado de Evento de cliente. A regra é simples: o sistema precisa mostrar o mesmo estado no Web e no iPhone.

> Primeiro vamos fazer o ciclo no Web. Depois repetimos a parte de campo com o iPhone, o RFD40 real e cinco tags físicas. Quando o RFID não estiver disponível, o QR continua a operação sem fingir que houve leitura por rádio.

## Instalação assistida

### `INS-03`, confiar no perfil

[Mostrar o bloqueio do iOS, o gesto nos Ajustes e o primeiro launch]

> O app já está instalado, mas o iPhone bloqueia a primeira abertura até confiar no perfil usado para assinar este build. Em Ajustes, abra Geral, VPN e Gerenciamento de Dispositivo e confira o nome `Marco Rangel`. Confie somente se esse for o perfil combinado para a instalação. Depois volte e abra o MMD Estoque.

> Se o perfil não aparecer, não apague o app por tentativa. Reconecte o iPhone ao Mac e repita a instalação assistida. Uma assinatura pessoal também pode expirar e exigir nova instalação.

### `INS-04`, entrar sem expor credencial

[Começar a captura depois que a senha já estiver preenchida]

> O iPhone usa a mesma conta e o mesmo backend do Web. A senha não entra na gravação. Depois do login, confirme que a sessão abriu e que os Eventos carregam. Se a tela voltar ao login, entre novamente uma vez. Falha repetida é caso de suporte, não de trocar senha no escuro.

### `INS-05`, provar o runtime

[Abrir Ajustes do app]

> Antes de encostar no leitor, confira o modo ativo. O take só continua quando a tela mostra `Zebra SDK`. Se aparecer Simulado ou SDK Zebra indisponível, pare. Esse estado serve para diagnóstico, não serve como prova do RFD40.

## Showcase Web

### `WEB-01`, login e dashboard

> O dashboard é a leitura rápida da operação. Aqui aparecem unidades disponíveis, unidades em campo, manutenção, prontidão e alertas. Antes de movimentar qualquer equipamento, abra o Evento que exige atenção e confirme o motivo.

### `WEB-02`, Item e Serial Number

> Item é o tipo de equipamento. Serial Number é a peça física que recebe código MMD, RFID, QR, condição e histórico. Uma linha do packing pede o Item. A saída movimenta as unidades físicas escolhidas para atender essa linha.

### `WEB-03`, Evento isolado

> Esta execução usa o código `TRN-MARCELO-01`. O nome visível permanece `Treinamento · Marcelo`. Confira ficha, local, datas e status antes de abrir o packing. Nenhum dado de cliente precisa entrar neste ciclo.

### `WEB-04`, packing incompleto

> O packing começa com quatro das cinco unidades cobertas. A linha incompleta explica o bloqueio. O sistema não libera a saída enquanto faltar unidade, existir conflito ativo ou o Evento estiver no status errado.

> Leia o motivo antes de agir. Override não é botão de continuar. É exceção auditada e não faz parte do fluxo normal deste treinamento.

### `WEB-05`, completar a alocação

> A unidade escolhida precisa estar disponível e sem conflito nas datas do Evento. Ao alocar `MMD-AUD-0039`, a cobertura passa de quatro para cinco. Confira a mudança na tela antes de seguir.

### `WEB-06`, check-out e reflexo no painel

> Com o gate liberado, revise o plano de saída e confirme o check-out. Aguarde a resposta do sistema. A prova não termina no botão: o Evento precisa ficar em campo, as unidades precisam mudar de status e o dashboard precisa refletir a saída.

### `WEB-07`, retorno com três resultados

> No retorno, cada unidade recebe o que aconteceu de verdade. A primeira voltou sem problema e fica disponível. A segunda voltou com problema, recebe uma observação e vai para manutenção. A terceira não voltou e cria uma pendência. O sistema não dá baixa silenciosa e não transforma incerteza em estoque disponível.

### `WEB-08`, QR público mínimo

> O QR abre uma ficha pública curta para identificar a unidade. Ela não mostra valor, RFID, serial de fábrica, localização interna ou histórico. Se o código apontar para outra unidade, pare e escale. Não imprima outra etiqueta para esconder a divergência.

### `WEB-09`, auditoria

> A auditoria fecha o ciclo. Confira operador, horário, unidade e movimento. Saída, retorno, manutenção e pendência precisam formar uma história coerente. Se a tela disser uma coisa e o equipamento físico disser outra, preserve a evidência e resolva antes do próximo Evento.

## Passagem para a operação no iPhone

[Mostrar o mesmo Evento no Web e no iPhone]

> Agora o trabalho sai da mesa e vai para o galpão. O iPhone não cria uma regra paralela. Ele usa o mesmo Evento, o mesmo packing e as mesmas transições que acabamos de conferir no Web.

## Showcase iOS com RFD40

### `IOS-01`, descobrir o leitor real

[Sincronizar tela do iPhone e câmera externa]

> Este é o RFD40 físico usado no take. O leitor começa desligado e fora da lista. Depois de ligar e autorizar o Bluetooth, o nome real aparece no app. A câmera externa mostra o aparelho e a ação do gatilho. O áudio preserva o beep produzido pelo leitor.

> Se o RFD40 não aparecer, confira carga, Bluetooth e pareamento. Não ligue o modo simulado para continuar a gravação.

### `IOS-02`, conectar

> Selecione o leitor encontrado e aguarde o estado conectado. Quando o SDK informar bateria, confira também esse valor. Leitura antes da conexão não conta como prova.

### `IOS-03`, tag conhecida

> A primeira tag já está vinculada. Ao acionar o gatilho, o EPC resolve a unidade correta no catálogo. O vídeo mostra o código MMD da unidade, sem precisar expor o EPC completo.

### `IOS-04`, tag desconhecida

> Esta segunda tag física ainda não tem vínculo. O app mantém a leitura e abre um tratamento. Tag desconhecida não some da contagem e não vira unidade por aproximação. O vínculo só acontece depois de conferir a peça física.

### `IOS-05`, lote de cinco tags

> Agora lemos pelo menos cinco tags no mesmo ciclo. A conferência separa o que pertence ao packing, o que falta e o que apareceu como extra ou sem vínculo. O resultado precisa bater com as cinco peças colocadas na área de leitura.

### `IOS-06`, check-out no campo

> Com o packing completo, revise a lista e confirme a saída no iPhone. Aguarde a resposta persistida. Um toast sozinho não prova o movimento.

### `IOS-07`, persistência no Web

[Trocar para o Web sem esconder a atualização]

> O Web mostra a mesma saída feita pelo iPhone. Evento em campo, unidades movimentadas, operador e horário vêm do backend. Essa conferência prova que a ação não ficou só na tela do aparelho.

### `IOS-08`, retorno OK

> No retorno OK, a unidade sai de campo e volta para disponível. Confira o resultado antes de ler a próxima peça.

### `IOS-09`, problema ou pendência

> Uma unidade com problema exige observação e vai para manutenção. Uma unidade não devolvida abre pendência. Nenhuma das duas volta para disponível até existir uma resolução segura.

### `IOS-10`, QR como fallback

> Quando o RFID estiver indisponível de forma explícita, use o QR da unidade. O QR resolve a mesma peça física e continua o fluxo. Isso é fallback por câmera, não leitura RFID.

### `IOS-11`, recuperar falhas comuns

> Para leitor desconectado, confira o estado e reconecte. Para leitura vazia, afaste outras tags, aproxime a peça e tente uma vez. Para sessão expirada, entre novamente. Se a ação segura não resolver, preserve a tela e escale. Não apague Evento, unidade ou histórico para limpar o erro.

## Fecho do master

[Mostrar o Evento finalizado, a auditoria e o hub de treinamento]

> O ciclo completo tem uma ordem: abrir o Evento, conferir o packing, resolver o bloqueio, registrar a saída, conferir o retorno e revisar a auditoria. Web e iPhone precisam terminar no mesmo estado.

> O hub de treinamento separa as trilhas Web e iOS, organiza cada passo e mantém a solução segura para cada erro comum. Na primeira operação, Marcelo repete este ciclo usando apenas o material. A entrega termina quando ele consegue fazer isso sem orientação externa.

## Falas que exigem revisão de pronúncia

Gravar uma amostra curta antes da locução final: `MMD`, `RFD40`, `RFID`, `packing`, `check-out`, `QR`, `Zebra`, `Supabase` e `Marcelo`.

## Depois do picture lock

1. Substituir cada código de cena pelo timecode real do corte.
2. Remover frases cobertas pela ação visível para evitar locução redundante.
3. Gerar o transcript literalmente a partir da voz aprovada.
4. Gerar VTT pt-BR e revisar sincronismo, acentos e nomes técnicos.
5. Atualizar os capítulos do hub com os timecodes finais.
