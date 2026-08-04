# Handoff: Event Pro 2.0, sessão de 2026-07-28

> **Decisões desta sessão (2026-07-28, sessão nova):** Fase 1 executada, Event Pro
> agora vive em `apps/ios/EventPro/` (commit `fa4d2b1`, build verde, app loga).
> **Material da barra: opção 1, tinta cheia** (pílula `#171718`, texto em `paper`,
> ícone apagado `#85858A`), escolhida pelo Marco. Seção 4 resolvida.
> **Decisão reaberta e substituída em 2026-08-01:** `9A · Paridade`. O dock separa
> três destinos de navegação de um gatilho físico do leitor. Navegação renderizada
> com `236,8 × 58 pt`, ação `58 × 58 pt`, gap de `8 pt`. O gatilho não expande
> "Ler tag" nem abre menu. Ele entra direto na superfície dedicada `Identificar`,
> com conexão e bateria do RFD40, contagem ao vivo e leitura acionada pelo gatilho
> físico ou pelo controle na tela. A superfície reembala, sem descartar, a anatomia
> já construída no legado: contador hero, feed de EPCs, Limpar, Resolver, resultados
> identificados e tag sem cadastro com `Vincular`. `Etiquetar` pertence ao Catálogo
> ou ao resultado de tag desconhecida; `Conferir` pertence ao fluxo do Evento.
> **Round 37 mantém travada a lista 4, `Compact`, junto do scanner `Halo`.** O fluxo
> final
> abre um half-sheet de 72% da altura, preservando parte do Halo em contexto. A lista
> fecha apenas pelo arrasto da pega, sem botão ou seta. O título usa hierarquia leve:
> `Itens identificados` em medium e a contagem como apoio discreto. Cada linha mantém
> nome, área, código MMD e número da tag, organizados em três zonas: estado, identidade
> e tag. Pesos regular/medium, metadados em mono pequeno, separadores finos e espaço
> substituem cards e negrito excessivo.
> **Round 39 trava a `Index Line` da Round 38 como base do gatilho.** Superfície
> plana, duas hairlines e estrutura horizontal não mudam. `Quantity`, `Sentence`,
> `Review`, `Live State` e `Technical Index` exploram somente a hierarquia e a copy
> interna. O sheet agora abre por toque ou arrasto para cima a partir do gatilho. No
> arrasto, a posição acompanha o dedo em relação 1:1, inclusive quando o gesto inverte
> antes de soltar. Distância e velocidade decidem se completa a abertura ou retorna.
> O fechamento mantém a pega como único controle e aplica a mesma manipulação direta
> para baixo, com retorno reversível.
> **Round 40 trava a opção 4, `Live State`, como conteúdo final do gatilho.** O estado
> `Leitura ativa` e o apoio `RFID em andamento` ficam à esquerda. O glifo do ledger
> ocupa uma zona curta de ação e o contador `36` termina a margem direita, sem o
> rótulo redundante `itens`, em SF Pro Display com peso 390. O sheet não usa mais
> fade durante o deslocamento: mantém massa opaca, anima apenas por `translate3d` e
> transfere a profundidade para um backdrop progressivo. A curva de chegada usa
> `cubic-bezier(.22,.78,.18,1)` e a duração considera distância restante e velocidade.
> **Round 41 mantém `Live State` e o motion travados, e explora apenas affordance.**
> `Terminal`, `Count First`, `Direct Open`, `Ledger Key` e `Edge Stack` variam a
> posição do `36`, o glifo de lista e a explicitude do comando. `Ledger Key` é a
> recomendação atual: um endcap fosco reúne glifo e contador como tecla discreta sem
> transformar a Index Line numa cápsula. Nenhuma das cinco foi escolhida ainda. O
> protótipo abre em `Terminal`, com a lista fechada.
> **Round 42 remove todo o texto operacional do gatilho e explora elevação.** As cinco
> opções mantêm apenas chevron para cima, glifo de lista e contador `36`: `Lift Card`,
> `Pull Tab`, `Drawer Lip`, `Split Rise` e `Floating Index`. Sombra em camadas,
> highlight superior e compressão no toque separam o controle do scanner e comunicam
> que a lista sobe. O motion de toque e arrasto continua compartilhado com o
> half-sheet travado. Nenhuma opção foi escolhida ainda; o protótipo abre em
> `Lift Card`, com a lista fechada.
> **Round 43 trava a opção 5 da rodada anterior, `Floating Index`.** O contador sai
> da tecla, que passa a ter `88 × 58 pt` e duas zonas simétricas para chevron e
> glifo de lista. As cinco alternativas agora exploram somente a posição do `36`:
> `Ring Index` no aro do Halo, `Core Footer` dentro do círculo, `Ledger Header` no
> cabeçalho das leituras anteriores, `Ledger Footer` abaixo da lista curta e
> `Margin Index` na margem entre Halo e ledger. Marco travou a opção 3,
> `Ledger Header`: o contador passa a pertencer ao cabeçalho da lista curta, sem
> ocupar o Halo nem voltar para a tecla. O protótipo abre nessa opção, com a lista
> fechada.
> **Round 44 mantém `Ledger Header` travado e retira a abertura do canto.** As cinco
> opções centralizam a área de toque e arrasto na base da tela: `Grabber`, somente
> uma barra com hit area invisível; `Chevron Key`, tecla circular; `Lift Pill`,
> chevron e grabber em cápsula curta; `Lift Notch`, borda elevada; e `Soft Dock`,
> handle sobre material translúcido. Marco travou a opção 1, `Grabber`. A pega do
> half-sheet agora recolhe a lista por arrasto para baixo ou duplo clique. O scanner
> deixa de fechar por wipe circular e desce como uma folha inteira em 520 ms. O
> fechamento limpa `list-open`, estilos de gesto e backdrop antes da transição.
> Também foi removido um `</div>` extra que deixava o dock fora de `.app` e impedia
> as regras `v9a` de definir cápsula, espaçamento e botão RFID quadrado.
> O primeiro duplo clique ainda criava três settles concorrentes: cada clique
> agendava retorno para `0` e o `dblclick` agendava a descida. Um timer antigo
> limpava o `transform` no meio, fazendo o sheet descer, voltar e cair de novo.
> `ligarDrawerDrag()` agora mantém um único `settleTimer`, cancela o anterior no
> novo gesto e preserva o frame corrente. A trajetória medida ficou monotônica até
> os 652 px de saída.
> **Plano da seção 8 executado até o passo 5** (commits `c4c08b4`, `7fcdc77`,
> `8512360`): Tokens.swift na lei clara e a tela do grill implementada (mapa
> ilustrativo com carrossel e pin viajando, agenda, barra opção 1, Ajustes no
> avatar), mais Login reembalado. **Correções do Marco:** a tela do grill é a aba
> EVENTOS (o protótipo abre com `aba = "eventos"`), não a Home; o Início vira
> estado em construção até a Home própria ser desenhada, e o app abre em Eventos.
> A agenda carrega TODOS os eventos cadastrados do horizonte operacional
> (planejamento, confirmado, em campo), ordem fixa por data, destaque inicial no
> próximo confirmado. O EventsListView antigo saiu do target (histórico git
> preserva). Evento sem packing mostra só a data na frase. Validado no simulador
> contra o Supabase real: login, signout, toque na agenda, arrasto do mapa, abas.

Documento autocontido para retomar numa sessão nova, sem acesso à conversa anterior.
Este arquivo **supera** `tasks/handoff-event-pro.md`: o que estiver diferente aqui, vale aqui.

Fontes de verdade, nesta ordem:

1. Este arquivo (decisões do grill e lei visual).
2. `tasks/evidence/home-2.0/prototipo-home.html`: protótipo interativo da Home nova,
   fonte de verdade visual com todos os valores exatos. Cópia fiel (checksum conferido)
   do protótipo vivo publicado como Artifact:
   https://claude.ai/code/artifact/7489e5f3-5c77-47e6-bf2c-2bc456581210
   Atenção: `tasks/evidence/` é gitignored; essa cópia existe só nesta máquina.
3. `tasks/inventario-telas-antigas.md`: inventário das 23 superfícies do app antigo.
4. `tasks/lessons.md`: armadilhas de simulador, config e Supabase já pagas.

## 1. Onde estamos

Decisão de produto desta sessão, em duas partes:

1. **O Event Pro é o produto e o app iOS antigo (`apps/ios/MMDEstoque`) é legado**, com
   aposentadoria por critério e sem data definida (seção 7, Fase 2).
2. **O `apps/web` fica e é aproveitado.** Ele não é aposentado: continua sendo a gestão
   e, principalmente, é o backend operacional do app de campo (pendência 9.0). O que
   acontece com ele é **refatoração apenas de layout**, aplicando a mesma lei visual
   clara, sem tocar em lógica, rotas de API, dados ou estrutura. Frente própria, depois
   do iOS.

O Event Pro (app iOS novo em `event-pro/`) tem login funcionando contra o Supabase real
e três telas na lei visual antiga (dark ClickUp):
Home cockpit `964319b`, lista de eventos `bcc4f43` e login. Nesta sessão aconteceu um
grill de design de 23 rodadas sobre a Home, todo verificado em protótipo HTML interativo,
que **substituiu a direção visual**: sai o dark com acentos, entra papel claro com zero
cor de acento e um mapa escuro como única área densa. As decisões abaixo estão travadas
pelo Marco; só o material da barra inferior (seção 4) segue aberto. A Home commitada em
`964319b` continua correta em dados e ViewModel, mas o visual dela foi superado.

### Como rodar

- Simulador desta frente: **iPhone 17 Pro**, udid `CCA2A995-1A46-489F-AA5A-4AB6BA03DE0B`
  (confirmar com `xcrun simctl list devices` se mudou). O Marco usa o iPhone 17 em outra
  sessão: não mexer nele.
- Build via MCP do simulador: project `/Users/marko/Projects/mmd/event-pro/EventPro.xcodeproj`,
  scheme `EventPro`, bundle `com.emdash.eventpro`. Após editar `project.yml` ou
  adicionar/remover arquivo, rodar `xcodegen generate` dentro de `event-pro/`.
- Login do app: usuário `supervisor`, senha `123456` (ver pendência 9.1).
- O working tree tem trabalho **não commitado de outras frentes**: RFID em
  `apps/ios/MMDEstoque/` e treinamento em `apps/web/`. Não tocar, não commitar junto.

## 2. A lei visual (substitui o Tokens.swift atual)

O `event-pro/EventPro/Design/Tokens.swift` de hoje é dark-first com acentos de estado
(verde, âmbar, vermelho, ciano) e oito cores de categoria. **Tudo isso sai.** A lei nova,
família "Ponte de cinza": papel quente, mapa frio, cinzas neutros servindo de ponte.
Regra dura: paleta clara, ZERO cor de acento. Nada de verde, âmbar ou vermelho como
semáforo em lugar nenhum. Estado é codificado por posição, peso, rótulo, forma ou
densidade, nunca por cor.

Sobrevive do Tokens.swift atual: escala de espaço base 4 (s1 a s12), raios, `touchMin`
44pt, fontes Inter Tight e JetBrains Mono (já em `Resources/Fonts/`), `EPPressStyle`
(escala + haptic). Sai: toda a seção de cor (rampa dark bg0-bg3, hairlines brancas,
fg0-fg3, stateReady/Field/Critical/Info, catX, selectionHalo).

### Papel e tinta

| Token | Valor | Contraste s/ papel | Uso |
|---|---|---|---|
| `paper` | `#F6F4F1` | (fundo) | fundo do app, papel quente |
| `paper2` | `#ECEBE9` | 1,09:1 | superfície selecionada: evento aberto na agenda, canto 14px |
| `linha` | `#E2E1DE` | | hairline 1px entre linhas de lista |
| `ink` | `#171718` | 16,32:1 | tinta: títulos, valores fortes |
| `ink2` | `#4A4A4C` | 8,05:1 | corpo |
| `ink3` | `#7B7B7E` | 3,84:1 | terciário: estrutura, kicker, texto grande apagado. Nunca em texto pequeno |
| `sub` | `#6F6F72` | 4,56:1 | texto secundário pequeno (calculado para o piso 4,5:1) |
| `vidro` | `rgba(255,255,255,.68)` | | vidro leitoso branco (opção 2 da barra), blur 26px saturate 1.7 |
| `balao` | `rgba(18,21,26,.5)` | | balão de distância no mapa, blur 14px saturate 1.4 |

Escada completa da família, do papel à tinta (para estados futuros usarem degraus, não
cores novas): `#F6F4F1 · #ECEBE9 · #E2E1DE · #DCDBD8 · #CBCAC6 · #B6B5B2 · #7B7B7E ·
#4A4A4C · #171718`.

Pisos de contraste (verificados no protótipo com a fórmula WCAG): texto pequeno 4,5:1,
texto grande 3:1, ícone de aba apagada 3:1. Superfície clara precisa de 1,35:1 sobre o
papel para existir sem depender de sombra.

### Mapa (frio)

| Token | Valor | Uso |
|---|---|---|
| `mapBase` | `#14161A` | fundo do mapa |
| `mapAgua` | `#171A20` | água |
| `mapParque` | `#161920` | parque |
| `mapQuarteirao` | `#1B1F25` | quarteirões (retângulos r3) |
| `mapViaPrincipal` | `#232830` | vias principais, stroke 9 |
| `mapViaSecundaria` | `#1E222A` | vias secundárias, stroke 3.5 |

Rota: stroke 3, pontas redondas, gradiente branco de 18% de opacidade na origem para 80%
no meio e 100% no destino. Origem: círculo r 4,5 preenchido em `mapBase` com aro branco
de 2,5. Destino: círculo branco r 5 com halo branco r 11 a 14%.

### Tipografia (Inter Tight; números sempre tabulares)

| Papel | Spec |
|---|---|
| Display (nome do evento) | 34px semibold, line-height 1.04, tracking -0.045em |
| Local no display | mesma escala, cor `ink3`, linha logo abaixo |
| Kicker (linha de contexto) | 12px medium, `ink3` |
| Frase de dados | 14px regular `ink2`; valores em semibold `ink` |
| Section header | 12px medium `ink3`; contagem à direita 12px medium `sub` |
| Agenda: data | 13px medium `ink3`, coluna de 50px |
| Agenda: nome | 15px medium `ink`; aberto: semibold; não confirmado: regular `ink2` |
| Agenda: local | 13px regular `sub`, encostado à direita |
| Balão do mapa | 11px semibold branco; unidade "km" regular a 72% |
| Rótulo de aba ativa | 14px semibold |
| Status bar | 15px semibold, tabular |

### Motion (durações medidas no protótipo)

| Movimento | Spec |
|---|---|
| Snap do carrossel do mapa | 340ms `cubic-bezier(.25,.9,.25,1)`; gatilho: deslocamento > 90px ou velocidade > 0,55px/ms |
| Pin viaja dentro do mapa | 500ms `cubic-bezier(.4,.05,.2,1)` em posição |
| Cross-fade da rota | 340ms ease |
| Cápsula da aba (largura) | 340ms `cubic-bezier(.3,.9,.25,1)`; fundo/cor 280ms ease; rótulo opacity 220ms ease |
| Fundo da linha da agenda | 220ms ease |
| Troca de conteúdo pós-animação | 320ms |

## 3. Anatomia da Home 2.0, de cima pra baixo

O protótipo tem andaime de demonstração (moldura de iPhone, painel seletor no canto).
A verdade visual é o que renderiza dentro da moldura de 402x874.

1. **Status bar**: 54px, texto 15px semibold tabular em `ink`, degradê do `paper` (60%)
   para transparente.
2. **Topo tipográfico** (padding lateral 22px): kicker "Próximo evento, em 15 dias"
   (ou "Sai em N dias" quando faltam 2 dias ou menos); nome do evento em display 34px
   semibold tracking -0.045em; local logo abaixo na mesma escala em `ink3`. À direita,
   **avatar** de 34px (círculo `ink`, letra em `paper`, 13px semibold): é onde vive
   Ajustes agora. Ajustes saiu da barra.
3. **Frase única de dados**, sem rótulos: `11 ago · 38 de 61 itens prontos`. 14px `ink2`,
   valores em semibold `ink`, tabular, 12px abaixo do display. A distância NÃO fica aqui.
4. **Mapa full bleed**, 212px de altura, 16px abaixo da frase. Mapa escuro (paleta fria
   da seção 2) com **rota própria desenhada por evento**. KPIs de estoque foram
   **removidos** da Home.
   - **Balão de distância** ancorado no ponto de destino (translate(-50%,-100%),
     9px acima do ponto): fundo `rgba(18,21,26,.5)`, blur 14px saturação 1.4, raio 8px,
     padding 4px 8px, texto 11px semibold branco ("38 km", unidade a 72%), fio de luz
     interno de 0,5px a 26% de branco, sombra externa `0 3px 10px rgba(0,0,0,.3)`,
     bico de 7px rotacionado 45° no mesmo material.
   - **Navegação por dois caminhos.** (a) Arrastar o mapa: carrossel de 3 slots
     (largura da tela cada) que segue o dedo; ao soltar, encaixa no vizinho se o
     deslocamento passou de 90px ou a velocidade de 0,55px/ms, transição de 340ms;
     senão volta. Trocar de slot também troca o evento destacado na agenda.
     (b) Tocar na agenda: o mapa NÃO desliza; o **pin de destino viaja dentro dele**
     (500ms, `cubic-bezier(.4,.05,.2,1)`), o texto do balão troca e a rota faz
     cross-fade (340ms).
   - **Nenhum chevron**: nem no mapa, nem nas linhas da lista.
5. **Agenda** (section header "Agenda" + "7 eventos" à direita, 20px acima da lista):
   - Ordem **fixa** dos 7 eventos: a lista nunca se reorganiza, só muda quem está em
     destaque.
   - Linha: data (coluna de 50px) + nome + local à direita. Padding 13px vertical e
     12px horizontal, gap 15px, hairline superior de 1px `linha`, sangria de -12px nas
     laterais, raio 14px.
   - **Evento aberto**: fundo `#ECEBE9`, canto 14px, nome em semibold, hairline da
     própria linha e da seguinte somem. Marcado por um **ícone de pin de localização**
     (20px, `ink2`) na borda direita da linha. É a única marcação; sem chevron.
   - Evento não confirmado: nome em regular e `ink2` (peso e cor carregam o estado,
     não cor de acento).
6. **Barra inferior**: 4 abas, **Início, Eventos, Catálogo, Ler tag** (glifos de 20px,
   stroke 1.6: casa, calendário, caixa, moldura de scan). Dock com padding inferior de
   26px e fade de 104px do transparente ao `paper`. Aba: 46px de altura, pílula; a ativa
   **expande mostrando ícone mais nome** (rótulo 14px semibold entra por
   grid-template-columns 0fr para 1fr, 340ms). Material da cápsula: EM ABERTO, seção 4.
7. **Alvo de toque de 44pt em tudo**, mesmo quando o visual é menor.
8. Scroll da tela com padding-bottom de 116px para a barra.

Dados: o `HomeViewModel` atual já entrega o que a tela precisa (próximo evento, agenda
de confirmados, prontidão X de Y). A distância em km e a rota precisam da pendência 9.2.

## 4. Ponto em aberto: o material da barra inferior

Rodada 23 apresentou cinco opções. O Marco ainda não escolheu. Medidas verificadas na
fórmula do próprio protótipo (abrir o arquivo e navegar com as setas para ver ao vivo):

| # | Material | Ativo | Texto no ativo | Ícone apagado | Cápsula destaca do papel |
|---|---|---|---|---|---|
| 1 | Sem cápsula | tinta cheia `#171718`, texto em `paper` | 16,32:1 | `#85858A`, 3,34:1 | não depende: é tinta |
| 2 | Vidro branco 68%, blur 26 saturate 1.7 | `#F6F4F1` (cor do papel) | 16,32:1 | `#6F6F74`, 4,79:1 | 1,05:1, o vidro + sombra seguram |
| 3 | Sem cápsula | `#ECEBE9`, o mesmo cinza do evento aberto na agenda | 15,04:1 | `ink3`, 3,84:1 | **1,09:1** |
| 4 | Sem cápsula | `#DCDBD8` | 12,94:1 | `ink3`, 3,84:1 | **1,26:1** |
| 5 | Sem cápsula | `#CBCAC6` | 10,92:1 | `ink3`, 3,84:1 | **1,49:1** |

Limiar prático: **1,35:1** para uma superfície clara existir sem depender de sombra.
Entre as claras sem cápsula de vidro, só a opção 5 passa. A opção 3 aposta em repetir a
regra que a agenda já tem (coerência acima do limiar); a 4 fica no meio do caminho.
As opções 1 e 2 não dependem do limiar (uma é tinta cheia, a outra tem vidro e sombra).
Decisão é do Marco, olhando o protótipo.

## 5. Armadilhas técnicas desta sessão (comprovadas, não repetir)

1. `width: auto` **não interpola em CSS**: animar largura de cápsula trava no meio.
   Usar `grid-template-columns` de `0fr` para `1fr` (é o que o protótipo faz).
2. **Preto translúcido sobre papel claro nunca dá preto**, dá cinza lamacento: 72% de
   preto sobre `#F6F4F1` resulta em `#595653`. Para barra clara, vidro branco, não preto
   diluído.
3. **O navegador headless de verificação congela o relógio de animação**: uma transição
   trivial fica com `currentTime` em zero permanentemente. Dá para verificar estado
   final e disparo de animação, não a suavidade. Suavidade se julga no olho.
4. Cinza escuro médio (`#4A4A4C`) como cápsula sobre papel claro foi **reprovado** por
   parecer sujo. Não reapresentar.
5. Contrastes exigidos: ícone de aba apagada 3:1, texto pequeno 4,5:1, texto grande 3:1.
   O cinza terciário original media 2,5:1 e reprovava; a solução foi **separar tokens
   por uso, não por aparência** (nasceu o `sub #6F6F72` para texto pequeno, mantendo
   `ink3 #7B7B7E` para estrutura e texto grande).

Armadilhas de infra anteriores (suíte de testes envenenando a config do simulador,
`cfprefsd` exigindo device desligado para escrever plist, Supabase hibernando no free
tier, grep não prova código morto): registradas em `tasks/lessons.md`, ler no início.

## 6. Inventário das telas antigas: resumo executivo

Feito por outro agente nesta sessão, com o app real rodando no simulador contra o
Supabase de produção. Completo em `tasks/inventario-telas-antigas.md` (754 linhas,
fichas por tela, mapa de navegação, 15 problemas); capturas em
`tasks/evidence/inventario-telas-antigas/` (16 pngs). Não duplicar, referenciar.

- **23 superfícies** mapeadas: 21 vivas, 2 órfãs (sem rota de entrada), mais
  `LiquidRoot`/`LiquidRouter` como infra de navegação.
- Classificação: **13 REINTERPRETAR** (conteúdo certo, só a roupa muda),
  **8 REPENSAR** (função necessária, formato errado), **2 DESCARTAR** (tour guiado e
  grade de conferência mock).
- **7 superfícies a CRIAR** que o app antigo não tem: detalhe do evento (ficha), mapa e
  rota do evento, recibo do despacho, histórico da unidade, busca global, estado offline
  com fila de sincronização, conferência manual com justificativa.
- As três descobertas mais graves:
  1. **Check-out e retorno esmagam a própria lista durante o scan**: painel de validação
     e hero de scan disputam o mesmo `maxHeight` e o hero vence; com o scan ativo sobra
     uma linha cortada de uma lista de 35 itens. O operador confere sem ver o que falta.
  2. **O medidor de progresso do packing é decoração**: `progress: 0` hardcoded, marca
     `0/N` e `0%` em qualquer evento, sempre.
  3. **Sem conferência manual o fluxo trava**: tag que não lê mais QR rasgado deixam
     `canFinalize` eternamente falso. O `overrideReason` já existe no APIClient e
     nenhuma tela oferece.
- Maior retrabalho sistêmico do redesenho: o semáforo verde/âmbar/vermelho é a única
  codificação de estado em quase toda tela. Com zero acento, cada uso precisa de
  recodificação por posição, peso, rótulo, forma ou densidade. Não é troca de paleta,
  é retrabalho de significado.

## 7. Migração MMD para Event Pro: código, identidade e credenciais

Decisões do Marco nesta sessão, registradas como **decididas**, não como opções:

1. **Event Pro é o produto; o app iOS antigo vira legado.** O Event Pro nasce como o
   produto de verdade, começando pelo iOS. O `apps/ios/MMDEstoque` passa a ser
   referência a ser aposentada, sem data: o gatilho é critério (Fase 2), nunca
   calendário.
2. **O `apps/web` fica e é aproveitado.** Corrige a leitura inicial desta sessão, que
   o tratava como legado a aposentar. Ele permanece por dois motivos: é a gestão e é o
   backend operacional do app de campo, dono dos endpoints de despacho, retorno e scan
   (pendência 9.0).
3. **O web recebe refatoração apenas de layout.** A mesma lei visual clara da seção 2 é
   aplicada ao visual dele, sem tocar em lógica, rotas de API, contratos de dados ou
   estrutura de pastas. Frente própria, depois do iOS. Assumido enquanto o Marco não
   disser o contrário: o iOS vem primeiro, porque a Home 2.0 já está definida e o
   inventário do web ainda não foi feito.

A migração acontece em três fases. Só a Fase 1 é executável imediatamente.

### O que muda de nome e o que não muda

Muda, em fases: o lugar do código iOS novo (Fase 1), o status do MMDEstoque (Fase 2),
a identidade do repositório e do web (Fase 3, ainda não decidida).

**Não muda: o projeto Supabase, o banco, os dados, a RLS, as migrations em `supabase/`
e as credenciais permanecem exatamente como estão.** Web e app de campo compartilham o
MESMO projeto Supabase, logo compartilham banco, migrations e credenciais: aposentar o
MMD não pode significar apagar o Supabase, porque o Event Pro nasce em cima do mesmo
banco. Os códigos `MMD-{CAT}-0001` dos itens são dado de catálogo (etiqueta física,
QR), não marca do repositório: ficam. A migração é de identidade e de código, não de
infraestrutura.

### Credenciais: onde vivem hoje e o que acontece com cada uma

Verificado nesta sessão, arquivo por arquivo:

| Credencial | Onde vive hoje | Durante a migração |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` (web) | `apps/web/.env.local`, o único arquivo de segredo do repositório inteiro, não versionado | nada acontece em fase nenhuma antes da 3 |
| `SUPABASE_SERVICE_ROLE_KEY` (web) | mesmo arquivo, uso só server-side | nada acontece. É **chave de serviço, bypassa RLS: não pode vazar para cliente nenhum** (iOS, código `NEXT_PUBLIC_`, log, bundle). Em nenhuma fase ela muda de lugar |
| URL e anon key do iOS | `UserDefaults` do device ou simulador via `AppConfig` (chaves `mmd_supabase_url`, `mmd_supabase_anon_key`), digitadas na tela de Ajustes do app; **sem default embutido e sem arquivo de env**, porque o repo é público. Verificado em `event-pro/EventPro/Config/AppConfig.swift` | nada acontece: UserDefaults pertence ao app instalado, não à pasta do código |
| Senha do usuário `supervisor` | Supabase Auth | independente da migração; trocar é a pendência 9.1 |

Consequência prática, com todas as letras: **mover a pasta do iOS não encosta em
credencial nenhuma.** O Event Pro não usa arquivo de env, e o web não é tocado na
Fase 1. Impacto de credencial da Fase 1: zero.

Notas verificadas: o `apps/web/.env.local.example` também é só local (o `.gitignore`
do web ignora `.env*`, example incluído) e traz três flags não secretas a mais
(`MMD_DATA_MODE`, `MMD_READONLY`, `NEXT_PUBLIC_MMD_CLIENT_WRITES`). Nenhum segredo
está em git (varrido `.env*`, `.pem`, `.p12`, `credentials*`). O deploy web na Vercel
carrega as env vars na configuração do projeto lá; não verifiquei nesta sessão,
conferir antes da Fase 3.

### Fase 1, agora: mover o iOS novo pra dentro do padrão

**Estado real de hoje (verificado):** o Event Pro está em `event-pro/` na raiz,
fora do padrão `apps/` que o projeto usa para web e iOS:

```
mmd/
├── apps/
│   ├── ios/MMDEstoque/     app antigo, legado congelado como referência viva
│   └── web/                fica: gestão + backend do app de campo
└── event-pro/              o produto, no lugar errado
    ├── project.yml
    ├── EventPro/           17 arquivos Swift + fontes + Info.plist
    └── EventPro.xcodeproj  pbxproj commitado; xcuserdata gitignored
```

**Proposta (NADA disto foi executado):** mover para `apps/ios/EventPro/`, espelhando
o irmão `MMDEstoque` (PascalCase é a convenção local de `apps/ios`).

```bash
cd /Users/marko/Projects/mmd
git status --short          # conferir que nada alheio vai junto no commit
git mv event-pro apps/ios/EventPro
# .gitignore: trocar a linha
#   event-pro/EventPro.xcodeproj/xcuserdata/
# por
#   apps/ios/EventPro/EventPro.xcodeproj/xcuserdata/
cd apps/ios/EventPro && xcodegen generate
```

- `project.yml` do EventPro: **zero mudança**. Todos os caminhos são relativos à própria
  pasta (`sources: EventPro`, `INFOPLIST_FILE: EventPro/Resources/Info.plist`, fontes).
  O `xcodegen generate` regenera o pbxproj no lugar novo.
- Caminho de build passa a ser
  `/Users/marko/Projects/mmd/apps/ios/EventPro/EventPro.xcodeproj` (atualizar a chamada
  do MCP do simulador).
- Bundle id não muda (`com.emdash.eventpro`): o app já instalado no simulador segue
  válido, com a config de UserDefaults intacta.
- Docs: o único documento que aponta para `event-pro/` é o handoff antigo, que este
  arquivo supera (verificado por grep). Este handoff usa os caminhos atuais; após o
  move, valem os novos.
- Commit **isolado**: só o rename + `.gitignore`. O working tree tem RFID e treinamento
  não commitados; `git mv` não os toca, mas conferir o staging antes.

### Fase 2, quando o Event Pro cobrir as trilhas de campo: aposentar o MMDEstoque

Sem data. O gatilho é esta lista verificável, nunca calendário:

1. RFID portado para o Event Pro (protocolo + Zebra + mock) e leitor conectando.
2. Check-out ponta a ponta: packing, scan, confirmação gravada no Supabase, com
   evidência em simulador e uma passada em device real com RFD40 antes de campo.
3. Retorno com avaliação de condição gravando movimentações, mesma evidência.
4. Etiquetar (vincular tag) e Identificar funcionando, mesma evidência.
5. As 13 telas REINTERPRETAR portadas e as 8 REPENSAR com formato novo decidido
   (inventário, seção 6).

Com tudo verde, a aposentadoria em si é decisão do Marco na hora: remover o target
`MMDEstoque` em commit próprio (o histórico git preserva tudo). Até lá, o MMDEstoque
fica **intacto** em `apps/ios/MMDEstoque/` como referência viva de conteúdo e lógica
para cada reembalagem.

### Fase 3, ainda sem data: layout do web e identidade do repositório

Decidido: o web **fica** e recebe refatoração **apenas de layout**, com a mesma lei
visual da seção 2, sem tocar em lógica, dados nem rotas de API. **Não decidido:** quando
essa frente abre, por onde ela entra (tokens em `globals.css` e `Primitives.tsx` de uma
vez, ou tela a tela), e se a identidade do repositório muda junto.

Regra dura dessa frente, pelo motivo da pendência 9.0: **`apps/web/src/app/api/` é
território proibido para trabalho de layout.** Ali moram os endpoints de despacho,
retorno e scan que o app de campo consome; quebrar um deles derruba o galpão, não a
tela.

Alcance real da identidade MMD, levantado por grep nesta sessão: **184 arquivos
versionados** citam mmd (case-insensitive), fora o nome da própria pasta raiz
`/Users/marko/Projects/mmd`. Fatias: `apps/web/src` 89 arquivos, `apps/ios` 27,
`supabase/` 7 migrations, `docs/` 6, a pasta legada `design_handoff_estoque_mmd/`
(6 arquivos versionados), `scripts/` 2, os três contratos da raiz (`CLAUDE.md`,
`AGENTS.md`, `CONTEXT.md`) e o próprio Event Pro (chaves `mmd_*` de UserDefaults em
`AppConfig`, mais referências em `APIClient` e `AuthSessionStore`).

Se a identidade mudar um dia, teria que tocar (tudo **não decidido**, nada disto agora):

- nome da pasta raiz e do repositório remoto;
- os três contratos da raiz reescritos para o produto Event Pro;
- web: pasta `components/mmd/`, prefixos `MMD_` e `NEXT_PUBLIC_MMD_` de env, textos;
- iOS: chaves `mmd_*` de UserDefaults. Atenção: renomear essas chaves desconfigura e
  desloga todo app instalado; exigiria migração de chave. Não fazer por estética;
- migrations: **nunca**. São histórico imutável; referência a mmd em migration fica;
- códigos `MMD-{CAT}-0001`: dado de catálogo com etiqueta impressa; mudar é decisão
  de produto separada, provavelmente nunca.

### O que NÃO fazer agora

- Não renomear o repositório nem a pasta raiz.
- Não começar a refatoração de layout do web antes de a Home do iOS estar de pé. Ela
  está decidida (seção 7, decisão 3), mas é a frente seguinte, não esta.
- Não tocar em `apps/web/src/app/api/` em hipótese nenhuma durante trabalho de layout:
  são os endpoints que o app de campo usa (pendência 9.0).
- Não apagar nem mover o `apps/ios/MMDEstoque`.
- Não tocar nas migrations em `supabase/`.
- Não commitar o trabalho solto de RFID e treinamento do working tree.
- Não colocar `SUPABASE_SERVICE_ROLE_KEY` em nenhum lugar novo. Cliente nenhum, nunca.

## 8. Plano de trabalho da próxima sessão

O plano cobre a Fase 1 da migração e o redesenho iOS. Fases 2 e 3 não entram aqui:
os gatilhos delas estão na seção 7. Nada neste plano toca o `apps/web`.

1. **Mover `event-pro/` para `apps/ios/EventPro/`** com os comandos da seção 7
   (Fase 1).
   Verifica: `xcodegen generate` + build verde + app abre no simulador e loga.
   Pequeno e binário, uns 15 minutos.
2. **Marco escolhe o material da barra** (seção 4, protótipo aberto no navegador).
   Verifica: escolha registrada em uma linha no topo deste arquivo.
3. **Reescrever `Design/Tokens.swift`** com a seção 2: paleta Ponte de cinza, zero
   acento, tipografia com display 34, durações do protótipo. Manter espaço, raio,
   touchMin e `EPPressStyle`. Verifica: projeto compila (as telas existentes podem ficar
   visualmente erradas neste passo, é esperado e temporário).
4. **Home 2.0**: reescrever `Views/HomeView.swift` seguindo a seção 3, mantendo o
   `HomeViewModel` como fonte de dados. O mapa entra como superfície ilustrativa (rota
   desenhada, sem dado geográfico real) até a pendência 9.2 ser decidida; o balão de km
   só entra com dado real. Abas Catálogo e Ler tag sem tela: recomendo empty state
   acionável no padrão `NeedsReaderPrompt` do inventário, confirmar com o Marco.
   Verifica: screenshot do simulador lado a lado com o protótipo.
5. **Reroupar `LoginView` e `EventsListView`** na lei clara. Verifica: build +
   screenshot de cada.
6. **Showcase** das telas novas para o Marco (`raza-showcase`).

## 9. Pendências reais

0. **O `apps/web` é backend do app de campo, não só interface.** Levantado no fim da
   sessão, e foi o que fez o Marco corrigir o rumo: o web deixou de ser tratado como
   legado a aposentar e passou a ser aproveitado. Verificado em
   `event-pro/EventPro/Services/APIClient.swift` e em `apps/web/src/app/api/`:

   | Operação | Por onde vai |
   |---|---|
   | Ler evento, catálogo, packing, seriais, movimentações | Supabase direto, PostgREST (`/rest/v1/...`) |
   | Despachar (check-out) | `POST /api/eventos/{id}/checkout` no Next.js do `apps/web` |
   | Receber (retorno) | `POST /api/eventos/{id}/retorno` no mesmo lugar |
   | Registrar scan de RFID | `POST /api/rfid/scans` no mesmo lugar |

   Ou seja: o Event Pro herda o backend do MMD por inteiro (mesmo projeto Supabase,
   mesmas cinco tabelas, models e `APIClient` copiados), mas as três escritas
   operacionais atravessam o web. **Aposentar o `apps/web` sem substituir esses três
   endpoints tira despacho, retorno e registro de scan do app de campo.**

   Agravante: para RFID existe fallback (`resolveRfidTags` lê direto do Supabase quando
   a web API não está configurada), mas **check-out e retorno não têm**. Os caminhos
   diretos existem como `registerCheckout` e `registerReturn`, ambos marcados como
   legacy e fora do fluxo novo, porque o endpoint faz numa transação o que o cliente
   faria em várias chamadas soltas.

   **Resolvido pela decisão 2 da seção 7:** o `apps/web` fica, então esses três
   endpoints continuam de pé e não há nada a substituir. O que sobra desta pendência é
   uma regra de trabalho, não um bloqueio:

   - a refatoração de layout do web **não pode encostar** em `src/app/api/`, porque
     mexer ali quebra o app de campo, não a tela;
   - as telas de despacho e retorno do Event Pro podem ser portadas normalmente,
     falando com os mesmos endpoints;
   - se um dia o web sair do ar, essas três operações precisam de casa nova antes
     (Edge Function no Supabase, ou reativar os caminhos diretos `registerCheckout` e
     `registerReturn`, aceitando escrita não transacional). Não é assunto de agora.

1. **Senha `123456` em Supabase de PRODUÇÃO com dados do cliente.** Usuário
   `supervisor`. Terceira sessão consecutiva registrando; a decisão é do Marco. Trocar
   leva 5 minutos no painel do Supabase e não quebra nada além de exigir novo login.
2. **Modelo de dados de localização bloqueia qualquer mapa real.** Hoje é tudo texto
   livre no Supabase: `Project.local` guarda "São Paulo Expo" e `serial.localizacao`
   guarda "Galpao MMD", sem coordenada nenhuma. O mapa da Home precisa de lat/lng por
   evento. Caminhos: (A) colunas de coordenada no evento + geocoding quando a ficha é
   criada no web; (B) geocoding on-device do texto via MapKit, sem tocar no banco;
   (C) mapa ilustrativo sem dado real até decidir (é o que o plano assume). Decidir
   antes de qualquer pixel de mapa real. O mapa de galpão descartado no inventário
   esbarra no mesmo bloqueio.
3. **Material da barra inferior**: decisão do Marco pendente (seção 4).
4. **Aba Catálogo é destino novo**: não existe tela equivalente direta no MMD (o mais
   próximo é a busca do Etiquetar, que serve a outro propósito e baixa o catálogo
   inteiro pro cliente).
5. **O protótipo não está versionado**: `tasks/evidence/` é gitignored, a cópia em
   `tasks/evidence/home-2.0/prototipo-home.html` vive só nesta máquina (o Artifact é o
   backup vivo). Se quiser no git, precisa de exceção no `.gitignore` ou cópia em
   `docs/`.
6. **Chip aberto**: isolar `AuthSessionStoreTests`, que envenena a config do app no
   simulador (detalhe em `tasks/lessons.md`).
7. **Working tree com duas frentes alheias não commitadas** (RFID no MMDEstoque,
   treinamento no web). Qualquer commit desta frente precisa de staging cirúrgico.
8. Herdada e reenquadrada: as pendências do handoff antigo sobre motion e tema escuro
   do ClickUp ficaram irrelevantes para a Home, o grill definiu durações e paleta
   próprias (seção 2). O dark-first do Event Pro v1 morreu com a lei clara.
9. **Aposentadoria do app iOS antigo, sem data.** O `apps/ios/MMDEstoque` sai quando os
   cinco critérios da Fase 2 (seção 7) estiverem verdes, nunca por calendário. Até lá,
   referência viva. O `apps/web` **não** entra nessa conta: ele fica.
9.5. **Refatoração de layout do web: escopo ainda não levantado.** Decidido que
   acontece e que é só visual (seção 7, decisão 3), mas falta o inventário das telas do
   web, equivalente ao que foi feito para o iOS, e falta decidir se a lei clara entra
   via tokens em `globals.css` e `Primitives.tsx` ou tela a tela. Nada disto começa
   antes de a Home do iOS estar de pé.
10. **Identidade do repositório: não decidida.** Renomear repo, contratos da raiz e
    os restos mmd no código é Fase 3, sem data e sem forma definida. Alcance mapeado
    na seção 7 (184 arquivos versionados). Enquanto isso, o nome mmd fica.
