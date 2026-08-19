# Rodada 1: notas do construtor

Mudou: as linhas operacionais saíram do Inter Tight e passaram para SF Pro Text/system; volta, ação e zona ficaram em um degrau único de 16px/400, metadado em 13px/400, e o nome LatBus segue Inter Tight 32px/650; a tela caiu de 8 para 4 tamanhos visíveis (32, 16, 13 e 9px).
Mudou também: `.dkHd` ganhou `margin: 0 16px` e perdeu o padding lateral, então cabeçalho, menu e lista dividem a mesma borda esquerda em 38.8px (desvio 0), e a lista passou a 19px de margem para vencer o colapso com `.carga` e fechar o ritmo em 11.9px e 16.1px; linhas seguem em 49.2px, sete zonas, `scrollWidth` igual a `clientWidth` e 8.3px livres até a dock.
Evidência acima do veredito: o gap declarado era só o peso do Inter Tight, mas a medição mostrou também `Iluminação` em JetBrains Mono no menu de ação, o que a Identidade só permite em serial, hora ou caixa alta; troquei por SF Pro Text 13px.

Ficou: as duas exceções herdadas dos iframes legados continuam iguais ao baseline (`getComputedStyle` e `getBoundingClientRect` em null) mais o 404 de `favicon.ico`, sem erro novo; o radius de 24px do menu e da lista renderiza em 20.4px por causa da escala do preview, fora do meu corte; a transição de `color` na dock canônica da Home não foi tocada.
Testado: cena `?tab=eventos&scene=event-detail` capturada em 390x844 e 1440x1000 com gate `--max-blank 0.80` em PASS (0.333 e 0.093); voltar devolve à agenda com Eventos ativa, Início abre a Home aprovada, Catálogo troca a aba e Identificar abre o RFID histórico.
