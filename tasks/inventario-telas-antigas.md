# Inventário das telas do MMD Estoque (app iOS antigo)

Levantamento completo das superfícies do app antigo para servir de base ao redesenho do
Event Pro. Documento de leitura, não de implementação: nenhum arquivo de código foi
alterado.

- **Fonte primária:** `apps/ios/MMDEstoque/MMDEstoque/Views/Liquid/` (19 arquivos),
  `ViewModels/` (3), `Design/Liquid/` (9), `Onboarding/` (7).
- **Navegação:** um único `NavigationStack` na raiz (`LiquidRoot.swift`), path controlado
  por `LiquidRouter`, destinos declarados no enum `AppRoute`.
- **Evidência visual:** 16 capturas em `tasks/evidence/inventario-telas-antigas/`, feitas
  no simulador iPhone 17 Pro com o app instalado, logado como `supervisor` e lendo o
  Supabase de produção (1.049 unidades disponíveis, 15 eventos ativos). Leitor em modo
  simulado, conectado ao `RFD40+ (Mock)`.
- **Lei visual nova (referência de julgamento):** papel claro `#F6F4F1`, zero cor de
  acento, tipografia grande carregando hierarquia, mapa full bleed com rota, listas de
  linhas simples sem chevron, dock em cápsula escura, alvo de toque de 44pt.

---

## 1. Tabela-resumo

Trilhas operacionais: **entrada** (login), **cockpit** (home, agenda), **catálogo**
(eventos, itens), **despachar** (packing, check-out), **receber** (retorno, condição),
**etiquetar** (vínculo de tag), **identificar** (scan avulso), **hardware** (leitor),
**config**, **compartilhado** (superfícies reusadas por várias trilhas).

| # | Arquivo | Tela | Trilha | Viva? | Rota / entrada |
|---|---|---|---|---|---|
| 1 | `LiquidLoginView.swift` | Entrar | entrada | viva | `fullScreenCover` em `LiquidRoot` e em `LiquidConfigView` |
| 2 | `LiquidHome.swift` | Início (cockpit) | cockpit | viva | tab `.inicio` |
| 3 | `LiquidProjectsListView.swift` | Eventos | catálogo | viva | tab `.eventos` + rota `.projetos(filter)` |
| 4 | `LiquidConfigView.swift` | Ajustes | config | viva | tab `.ajustes` (rota `.config` existe e nunca é empurrada) |
| 5 | `LiquidTabBar.swift` → `QuickActionsSheet` | Ações rápidas | compartilhado | viva | sheet do botão "+" |
| 6 | `LiquidPackingListView.swift` | Packing | despachar | viva | rota `.packing(project)` |
| 7 | `LiquidCheckoutValidationView.swift` | Check-out | despachar | viva | rota `.checkout(project)` |
| 8 | `LiquidReturnValidationView.swift` | Confirmar volta | receber | viva | rota `.retorno(project)` |
| 9 | `LiquidReturnValidationView.swift` → `LiquidConditionAssessment` | Condição do item | receber | viva | overlay quando `pendingAssessmentId != nil` |
| 10 | `IdentificarFlow.swift` | Identificar | identificar | viva | rota `.identificarScan` |
| 11 | `IdentificarFlow.swift` → `NeedsReaderPrompt` | Leitor desconectado | compartilhado | viva | fallback de `IdentificarFlow` e `ScanTagStep` |
| 12 | `LiquidScanResultView.swift` | Resultado | identificar | viva | rota `.scanResult(payload)` |
| 13 | `LiquidVincularTagView.swift` → `FindSerialStep` | Etiquetar, passo 1 | etiquetar | viva | rota `.etiquetar(tag:)` |
| 14 | `LiquidVincularTagView.swift` → `ScanTagStep` | Etiquetar, passo 2 | etiquetar | viva | transição interna de `.findItem` para `.scanTag` |
| 15 | `LiquidConnectReader.swift` | Conectar leitor | hardware | viva | rota `.conectar` (5 pontos de entrada) |
| 16 | `LiquidItemDetailView.swift` | Unidade | catálogo | viva | rota `.itemDetail(serial)` |
| 17 | `LiquidItemLostView.swift` | Item perdido | receber | viva | rota `.itemLost(serial)` |
| 18 | `LiquidQRScannerSheet.swift` | Scanner QR | compartilhado | viva | sheet em check-out e retorno |
| 19 | `Design/Liquid/LiquidComponents.swift` → `LiquidCompletionOverlay` | Fechamento de fluxo | compartilhado | viva | sucesso de check-out, retorno e vínculo |
| 20 | `Design/Liquid/ScanEngine.swift` | Motor de scan | compartilhado | viva | embutido em 4 trilhas |
| 21 | `Onboarding/TourOverlay.swift` | Tour guiado | compartilhado | viva | `overlayPreferenceValue` na raiz, 3 tours |
| 22 | `LiquidCheckoutGridView.swift` | Conferência em grade | despachar | **órfã** | nenhuma. Removida do toggle |
| 23 | `LiquidPackingMapView.swift` | Mapa do galpão | despachar | **órfã** | nenhuma. Removida do toggle |

**23 superfícies. 21 vivas, 2 órfãs.**

As duas órfãs são declaradas como tal em comentário no código que as removeu:
`LiquidCheckoutValidationView.swift:14` ("é mockup com dado de exemplo") e
`LiquidPackingListView.swift:25` ("galpão de exemplo hardcoded").

Não são telas, mas aparecem na tabela por completude de arquivo: `LiquidRoot.swift`
(shell + enum `AppRoute` + gate de auth) e `LiquidRouter.swift` (path).

---

## 2. Fichas por tela

### 1. Entrar (`LiquidLoginView`)

**Propósito.** Trocar usuário e senha por uma sessão Supabase antes de qualquer dado real
aparecer.

**Dados.** `AuthSessionStore.shared.signIn(identifier:password:)`. O identificador aceita
usuário ou e-mail. Sessão guardada no Keychain via `KeychainStore`, modelo binário
(`hasSession`, `sessionEmail`), sem papéis nem permissões: o cliente iOS não conhece
nenhum conceito de role.

**Componentes.** `TechnicalGridCanvas` de fundo, `panelSurface` no card do formulário,
dois campos custom (`TextField` e `SecureField`), botão primário com `ProgressView`
inline.

**Estados.** Carregando (`isLoading` troca o rótulo do botão por spinner), erro
(`errorMessage` vira texto vermelho abaixo dos campos), vazio tratado como botão
desabilitado via `canSubmit`. Sucesso não tem estado próprio: dispara `onAuthenticated?()`
e quem chamou fecha o cover.

**Classificação: REINTERPRETAR.** Conteúdo e função corretos e mínimos; já foi portado
para o Event Pro e funciona contra o Supabase real.

---

### 2. Início, cockpit (`LiquidHome` + `LiquidHomeViewModel`)
*Evidência: `01-home.png`*

**Propósito.** Dar o estado da operação numa tela só: qual é o próximo evento, quanto
estoque existe em cada status, o que precisa de ação e se o leitor está conectado.

**Dados.** `LiquidHomeViewModel.load()` chama, em sequência: `fetchProjects(status:
[.confirmado])` para a agenda, `fetchSerialSnapshot()` (paginado de 1000 em 1000) para os
contadores, e `fetchPackingList` + `fetchSerialsByIds` para calcular a prontidão do
próximo evento. Publica `proximoEvento`, `proximosEventos`, `counts` (`StatusCounts`:
disponivel, emCampo, manutencao, critico, semTag, total), `prontidaoEvento`, `isLoading`,
`errorMessage`, `carregou`.

**Componentes.** `HomeHeroCard` com `ReadinessGauge` de 76pt, card de KPI acoplado
(`panelSurface(tone: .inset)` com sobreposição negativa de 18pt), `HomeKPIStat` com
animação numérica, `agendaRow` com bloco de data mono, `HomeActionRow` para a pendência,
`readerRow` no rodapé, `TechnicalGridCanvas` de fundo.

**Estados.** Carregando (`isLoading && !carregou` faz o hero virar "Buscando eventos" e os
KPIs virarem travessão), erro (`errorNote` inline com ícone âmbar "Sem conexão com o
servidor"), vazio (hero vira "Nenhum evento na fila"; a seção Atenção só existe se
`counts.semTag > 0`), sucesso (`carregou == true`). Recarrega quando o path volta a zero.

**Classificação: REINTERPRETAR.** A composição está certa (próximo evento, números do
estoque, fila, pendência) e já foi reembalada no Event Pro em `964319b`. Só a roupa muda.

---

### 3. Eventos (`LiquidProjectsListView`)
*Evidência: `02-eventos.png` (filtro `.todos`), `05-projetos-despachar.png` (filtro `.aSair`)*

**Propósito.** Listar os eventos ativos e mandar cada um para a próxima ação da sua
trilha.

**Dados.** `apiClient.fetchProjects(status: filter.statuses)`. O enum `ProjectFilter` tem
três variantes: `.aSair` (`CONFIRMADO`), `.emCampo` (`EM_CAMPO`) e `.todos` (os dois).
Cada filtro carrega seu próprio rótulo de seção, título de vazio e dica de vazio.

**Componentes.** `LiquidSectionHeader` com contagem, `projectCard` (nome, cliente,
`LiquidStatusBadge`, linhas mono de data e local, hairline, CTA colorido), `LiquidSkeletonList`
no carregamento.

**Estados.** Carregando (`isLoading && projects.isEmpty` mostra 4 skeletons de 110pt),
vazio e erro **fundidos no mesmo `emptyState`** (o texto muda conforme `error == nil`),
sucesso (lista). Tem `refreshable`.

**Classificação: REINTERPRETAR.** Lista de eventos com estado é conteúdo permanente. Já
portada no Event Pro em `bcc4f43`. O CTA repetido em toda linha e o chevron saem na lei
nova.

---

### 4. Ajustes (`LiquidConfigView`)
*Evidência: `03-ajustes.png`*

**Propósito.** Guardar quatro coisas sem relação entre si: sessão do usuário, estado e
modo do leitor, versão do app e endereço do servidor.

**Dados.** `AuthSessionStore.shared.sessionEmail` e `signOut()`; `RFIDManager.connectionState`
e `runtimeMode`; `AppConfig.shared` para URL do Supabase, anon key, URL da API web e token
de debug; `Bundle.main` para versão e build.

**Componentes.** Quatro `LiquidSectionHeader` sobre quatro `panelSurface`, `Toggle` com
tint verde, botão de conectar/desconectar, seção Avançado colapsável com quatro campos e
botão Salvar, toast "Salvo" em cápsula verde.

**Estados.** Sem sessão (mostra "Entrar"), com sessão (mostra e-mail e "Sair"), quatro
estados de conexão do leitor, `hasChanges` habilitando o Salvar, toast de confirmação por
1,5s.

**Classificação: REPENSAR.** A função (conta, leitor, sobre) é necessária, mas o formato
empilha três públicos numa tela só. A seção Avançado é configuração de servidor num app de
campo: no produto novo isso é build config ou tela de suporte, não item de menu do
operador. A parte do leitor pertence à trilha de hardware, não a Ajustes.

---

### 5. Ações rápidas (`QuickActionsSheet`)
*Evidência: `04-quick-actions.png`*

**Propósito.** Lançar os quatro jobs de campo de qualquer aba.

**Dados.** Nenhum. Lista estática de quatro `HomeJob` com rota, ícone, título, subtítulo e
uma cor de acento cada: Identificar (ciano), Despachar (âmbar), Receber (verde), Etiquetar
(violeta).

**Componentes.** `LiquidSectionHeader`, `LazyVGrid` 2x2 de `HomeActionTile`, apresentado em
sheet de 400pt com drag indicator.

**Estados.** Nenhum. Superfície puramente estática.

**Classificação: REPENSAR.** A necessidade (chegar às ações de campo de qualquer lugar) é
real, o formato não sobrevive. As quatro cores de acento são exatamente o que a lei nova
proíbe, e Despachar e Receber apenas abrem outra lista de eventos: dois toques para chegar
onde a aba Eventos já leva em um. Na dock em cápsula escura essas ações precisam de outra
forma.

---

### 6. Packing (`LiquidPackingListView`)
*Evidência: `06-packing-list.png`*

**Propósito.** Mostrar o que o evento espera receber antes de começar a conferência
física.

**Dados.** `fetchPackingList(projectId:)` e, quando há seriais designados,
`fetchSerialsByIds(...)` para calcular o desgaste médio de cada linha. O `Project` chega
pronto pela rota.

**Componentes.** Card de identidade + card de progresso acoplado (mesmo padrão do hero da
home), `LiquidStatusBadge`, `LiquidCategoryBadge`, `LiquidWearBar`, barra de avanço fixa no
rodapé com CTA colorido por trilha, `LiquidSkeletonCard` + `LiquidSkeletonList` no
carregamento.

**Estados.** Carregando (skeleton), vazio e erro fundidos em `emptyItemsCard` ("Packing
list vazia" ou "Falha ao carregar"), sucesso (lista de linhas com quantidade).

**Problema específico.** O `progressAttachedCard` passa `progress: 0, state: .missing`
literalmente hardcoded, com a legenda "Conferidos no scan da validação". O instrumento
mais visível da tela sempre marca `0/35` e `0%`, em qualquer evento e qualquer momento.
É mobília, não medida.

**Classificação: REINTERPRETAR.** O conteúdo (identidade do evento + linhas esperadas com
quantidade) é a espinha do despacho e continua válido. O anel travado em zero sai.

---

### 7. Check-out (`LiquidCheckoutValidationView` + `CheckoutViewModel`)
*Evidência: `07-checkout-validation.png` (parado), `11-checkout-scan-ativo.png` (scan ativo)*

**Propósito.** Conferir o lote físico contra a packing list em tempo real e registrar a
saída.

**Dados.** `CheckoutViewModel` carrega `fetchPackingList`, escuta `rfidManager.scannedTags`,
resolve via `recordAndResolveRfidTags(contexto: .checkOutEvento)` e, no QR,
`resolveQRCode`. Finaliza com `checkoutProject(projectId:metodoScan:)` na API web, com
fallback legacy `registerCheckout` + `updateProjectStatus(.emCampo)`. Publica
`packingListItems`, `scannedSerials`, `matchedCounts`, `extraItems`, `unresolvedTags`,
`isLoading`, `isProcessingCheckout`, `checkoutComplete`, `error`.

**Componentes.** `progressHeader` com `ReadinessGauge` de 56pt, lista de `packingRow` com
dot de status e contador `matched/quantidade`, seção "Fora da lista" para extras,
`ScanEngine` embaixo, overlay de confirmação custom, `LiquidCompletionOverlay` no fim,
`LiquidQRScannerSheet` como fallback.

**Estados.** Carregando (`isLoading`), processando (`isProcessingCheckout` troca os botões
do overlay por spinner), erro (`error` repassado ao `ScanEngine`), sucesso
(`checkoutComplete` abre o overlay de fechamento e volta pra raiz). Estado por linha via
`validationState(for:)`: `.pending` âmbar, `.complete` verde, `.over` vermelho. O CTA
travado explica o motivo em ordem de acionabilidade (extras primeiro, depois faltantes).

**Problema específico.** `validationPanel` e `scanLayer` reivindicam ambos
`.frame(maxHeight: .infinity)` no mesmo `VStack`. Na prática o hero do scan vence e a lista
de conferência colapsa. Na captura `11-checkout-scan-ativo.png`, com o scan rodando, sobra
**uma linha cortada ao meio** da packing list. O operador confere 35 itens sem conseguir
ver o que falta.

**Classificação: REPENSAR.** A função é o coração do produto e não muda. O formato está
errado: a lista de trabalho precisa ser o conteúdo da tela e o scan precisa virar ambiente
(contador, faixa, som, haptic), não um hero de 300pt que come o viewport.

---

### 8. Confirmar volta (`LiquidReturnValidationView` + `ReturnViewModel`)
*Evidência: `16-retorno-validation.png`*

**Propósito.** Receber o lote que volta do campo, classificar cada peça e registrar
retorno, defeito ou falta.

**Dados.** `ReturnViewModel` monta a lista de esperados a partir de
`fetchProjectMovements(tipo: .saida)` + `fetchSerialsByIds`. Escaneia via
`recordAndResolveRfidTags(contexto: .retorno)` ou `resolveQRCode`. Finaliza com
`returnProject(projectId:metodoScan:items:)`, fallback `registerReturn` +
`updateProjectStatus(.finalizado)`. Publica `outboundItems: [ReturnItemState]`, `isLoading`,
`isProcessingReturn`, `returnComplete`, `error`, `pendingAssessmentId`. Computados:
`okCount`, `defectCount`, `missingCount`, `scannedCount`, `canFinalize`.

**Componentes.** `summaryHeader` com `ReadinessGauge` + três `countPill` (OK verde, defeito
vermelho, falta âmbar), `itemRow` por unidade com dot, status textual e botão de ação
(lápis para reavaliar, lupa para buscar o que não voltou), `ScanEngine`,
`LiquidConditionAssessment` como overlay, `LiquidCompletionOverlay` no fim.

**Estados.** Mesmos quatro do check-out, mais o estado por item (`ReturnResult`:
`.pending`, `.ok`, `.defeito(notas:desgaste:)`) e o estado "aguardando avaliação"
(`pendingAssessmentId != nil`). Vazio real observado na captura: evento marcado `EM_CAMPO`
sem movimentações de saída mostra "Nenhum item em campo neste evento" e a tela inteira vira
hero de scan.

**Classificação: REPENSAR.** Mesmo diagnóstico do check-out (lista esmagada pelo hero),
agravado pelo semáforo de três cores no cabeçalho, que na lei nova precisa de codificação
não cromática. A função (receber e classificar) é obrigatória.

---

### 9. Condição do item (`LiquidConditionAssessment`)

**Propósito.** Perguntar, para cada peça que voltou, se está OK ou com defeito, e capturar
o novo desgaste e as notas quando há defeito.

**Dados.** Recebe um `ResolvedItem`. Devolve por closure: `onOK()` ou `onDefect(notas,
desgaste)`. O desgaste inicial nasce um degrau abaixo do atual (`max(desgaste - 1, 1)`).

**Componentes.** Overlay escuro 70%, card `panelSurface`, dois botões de escolha (OK verde
preenchido, "Com defeito" vermelho vazado), `LiquidWearStepper` (5 cápsulas tocáveis de
12pt de altura), campo de notas multilinha com placeholder custom, botão de confirmação
que só habilita com notas preenchidas.

**Estados.** Escolha inicial, modo defeito expandido, botão de confirmação
habilitado/desabilitado.

**Classificação: REINTERPRETAR.** A decisão binária com captura obrigatória de justificativa
é o desenho certo. Só muda a roupa. Atenção ao alvo de toque: as cápsulas do stepper têm
12pt de altura, bem abaixo dos 44pt da lei nova.

---

### 10. Identificar (`IdentificarFlow`)
*Evidência: `13-identificar-scanengine.png`*

**Propósito.** Ler tags avulsas e descobrir que peças são, sem contexto de evento.

**Dados.** `rfid.scannedTags` e `apiClient.recordAndResolveRfidTags(tags:contexto:
.inventario)`. Empurra `.scanResult(ScanResultPayload(resolved:unresolved:))`.

**Componentes.** `ScanEngine` inteiro quando o leitor está conectado, `NeedsReaderPrompt`
quando não.

**Estados.** Sem leitor (prompt), pronto, escaneando, resolvendo (`isResolving` deixa o CTA
ocupado), erro (`errorMessage` repassado ao motor).

**Classificação: REINTERPRETAR.** Tela mínima e honesta: um motor, uma ação. Continua
válida.

---

### 11. Leitor desconectado (`NeedsReaderPrompt`)

**Propósito.** Barrar as trilhas que dependem de hardware e oferecer o caminho para
conectar.

**Dados.** Nenhum. Só empurra `.conectar`.

**Componentes.** Ícone em chip, título, dica, botão primário branco.

**Estados.** Único.

**Classificação: REINTERPRETAR.** Estado vazio bem resolvido (diz o que falta e dá o
caminho). Vira o padrão de empty state acionável do app novo.

---

### 12. Resultado do scan (`LiquidScanResultView`)
*Evidência: `14-scan-result.png`*

**Propósito.** Mostrar o que as tags lidas viraram: peças identificadas e tags sem
cadastro.

**Dados.** Recebe `resolved: [ResolvedItem]` e `unresolved: [String]` pela rota. Nenhuma
chamada própria. Cada card expandido mostra estado, desgaste, valor atual, localização,
marca e modelo, notas e tag RFID, tudo do `SerialNumber` + `Equipment`.

**Componentes.** Dois `heroCount` de 52pt com dot colorido, cards expansíveis com
`LiquidCategoryBadge` + `LiquidStatusBadge` + `LiquidWearBar`, `detailRow` de chave e valor,
link "Ver condição completa", seção de tags sem match com botão "Vincular" por linha.

**Estados.** Card colapsado/expandido (`expandedItemId`), seção de não resolvidos só existe
se houver. Sem carregando nem erro: a tela recebe dado pronto.

**Classificação: REINTERPRETAR.** A dupla resolvido/sem match é a leitura certa do scan, e
o atalho "Vincular" fecha o loop com o Etiquetar. Conteúdo permanente.

---

### 13. Etiquetar, passo 1: achar o item (`FindSerialStep`)
*Evidência: `12-etiquetar-passo1.png`*

**Propósito.** Achar o serial que vai receber a tag virgem.

**Dados.** `apiClient.fetchItems()` carrega o **catálogo inteiro** e filtra em memória por
nome, marca, modelo, prefixo e nome de categoria. Ao expandir um item,
`fetchSerialNumbers(forItemId:)` e mostra só os que ainda não têm `tagRfid`.

**Componentes.** `StepHeader` ("PASSO 1 DE 2"), campo de busca em `panelSurface`, cards
expansíveis por item com `LiquidCategoryBadge`, sublista de seriais com `LiquidStatusBadge`,
`InlineNotice` para erro.

**Estados.** Carregando catálogo, carregando seriais de um item (`loadingSerialsFor`),
erro de catálogo (`loadError`), erro de seriais (`serialError`), vazio ("Catálogo vazio" ou
"Nenhum item para a busca"), vazio de sublista ("Nenhum serial sem etiqueta neste item").

**Classificação: REPENSAR.** A função é necessária. O formato não escala: sem endpoint de
busca, sem paginação, o app baixa o catálogo todo e filtra no cliente. Na captura, a
primeira linha da lista aparece **sem nome nenhum**, só com a badge de categoria, porque o
item real do banco tem nome vazio. A lista também é o pior caso do arco-íris de categoria:
violeta, âmbar, rosa e ciano na mesma dobra.

---

### 14. Etiquetar, passo 2: ler e vincular (`ScanTagStep`)

**Propósito.** Capturar uma tag virgem e amarrá-la ao serial escolhido.

**Dados.** `rfid.scannedTags` (pega a última) ou `seedTag` quando a tag veio pronta do
resultado de scan. Grava com `apiClient.linkTag(serialId:tagRfid:)`.

**Componentes.** Card do serial alvo fixado no topo, conector visual em gradiente ciano
para violeta com o rótulo "vincular", `TagScanRing` (três anéis pulsando com stagger de
0,3s, respeitando Reduzir Movimento), card "Tag detectada" em ciano, par de botões "Ler
outra" e "Confirmar vínculo", `LiquidCompletionOverlay` no sucesso.

**Estados.** Sem leitor (`NeedsReaderPrompt` abaixo do card do alvo), aguardando tag (anel
pulsando), tag capturada (card ciano), vinculando (`isLinking`), erro (`linkError` em
vermelho), sucesso (`didLink`).

**Classificação: REINTERPRETAR.** O desenho de dois passos com o alvo fixado no topo é
claro e o atalho oportunista (`seedTag`) é uma boa ideia. Só a roupa muda.

**Bug encontrado.** `LiquidVincularTagView` cria a própria instância do cliente
(`@StateObject private var apiClient = APIClient()`) em vez de ler o `@EnvironmentObject`
como todas as outras telas. É um segundo cliente, com ciclo de autenticação e
`needsReauthentication` próprios, fora do gate da raiz.

---

### 15. Conectar leitor (`LiquidConnectReader`)
*Evidência: `08-conectar-leitor.png`, `09-conectar-buscando.png`, `10-conectar-conectado.png`*

**Propósito.** Parear o RFD40 por Bluetooth. É pré-requisito de quatro trilhas.

**Dados.** `RFIDManager`: `connectionState` (`.disconnected`, `.discovering`, `.connecting`,
`.connected(RFIDReaderInfo)`, `.error(String)`), `discoveredReaders`, e `RFIDReaderInfo`
com nome, serial e nível de bateria.

**Componentes.** Hero de status (ícone em círculo de 88pt, título, subtítulo), área de ação
que troca conforme o estado, card do leitor conectado com ícone de bateria escalonado, lista
de leitores encontrados.

**Estados.** Os cinco de conexão, cada um com ícone, cor, título e subtítulo próprios.
Cobertura completa e honesta.

**Classificação: REINTERPRETAR.** É a tela de estado mais bem resolvida do app antigo:
cinco estados, cada um dizendo o que aconteceu e o que fazer. Conteúdo permanente, só perde
as cores de status.

---

### 16. Unidade (`LiquidItemDetailView`)
*Evidência: `15-item-detail.png`*

**Propósito.** Mostrar a condição completa de uma unidade física e como o valor atual foi
calculado.

**Dados.** Recebe o `SerialNumber` (com `item: Equipment` embutido) pela rota, sem chamada
própria. Calcula `valorAtual` a partir de `valorMercadoUnitario × (desgaste/5) ×
fatorDepreciacao`, ou usa `serial.valorAtual` quando existe.

**Componentes.** Card de identidade com pares chave-valor mono, anel de desgaste de 104pt,
escala de estado em quatro chips (só leitura, o atual preenchido), barra de depreciação, e
o bloco de fórmula em mono mostrando a conta em três linhas.

**Estados.** Nenhum estado assíncrono. Campos opcionais aparecem só quando existem.

**Classificação: REINTERPRETAR.** O bloco de fórmula é a melhor peça de comunicação do app
inteiro: mostra a conta em vez de só o resultado, e isso resolve a pergunta que o cliente
faz ("por que essa peça vale isso?"). Mantém intacto, só troca a tipografia e tira o verde
da barra.

---

### 17. Item perdido (`LiquidItemLostView`)

**Propósito.** Ajudar a achar fisicamente uma unidade que não voltou do campo.

**Dados.** Recebe o `SerialNumber`. Mostra `serial.localizacao` (campo texto livre do banco,
hoje quase sempre "Galpao MMD"). **A força de sinal é simulação:** `SignalMeter` desenha 20
barras com `sin(índice + fase)`, sem nenhuma leitura de RSSI. O próprio código rotula isso
com uma badge "PRÉVIA" e um comentário explicando que não há RSSI no manager.

**Componentes.** Fundo com gradiente radial vermelho em `blendMode(.screen)`, cabeçalho de
alerta, card de última localização, `SignalMeter` animado, botão de conectar leitor quando
desconectado.

**Estados.** Leitor conectado (medidor rodando) e desconectado (texto + CTA).

**Classificação: REPENSAR.** A necessidade (achar peça sumida) é real e recorrente. O
formato promete algo que o hardware não entrega hoje: o `RFIDReaderProtocol` expõe só
inventário, sem modo locate. O SDK Zebra trata eventos de proximidade
(`srfidEventProximityNotify`, `SRFID_EVENT_MASK_PROXIMITY` em `ZebraRFIDManager.swift`), mas
isso nunca subiu para o protocolo. Ou o modo geiger vira real, ou a tela precisa ser outra
coisa (registro de perda, última movimentação, quem levou).

---

### 18. Scanner QR (`LiquidQRScannerSheet`)

**Propósito.** Fallback de leitura quando a tag RFID falha ou não existe.

**Dados.** Envolve `QRScanView` (câmera via AVFoundation), devolve a string por `onCode` e
fecha sozinha. Quem consome chama `processQRCode` no view model.

**Componentes.** Header com título e botão fechar circular, moldura de scan com borda ciano,
cápsula com a instrução "Aponte pro QR code".

**Estados.** Só o ciclo de vida da câmera (`isActive` ligado no `onAppear`, desligado no
`onDisappear`).

**Classificação: REINTERPRETAR.** Fallback necessário, implementação enxuta. Só muda a
moldura.

---

### 19. Fechamento de fluxo (`LiquidCompletionOverlay`)

**Propósito.** Confirmar que a operação foi gravada e devolver o operador ao ponto de
partida.

**Dados.** Recebe título e mensagem já montados por quem chamou. O retorno monta um resumo
humano ("12 OK, 2 com defeito, 1 não voltou").

**Componentes.** Overlay com check verde, título, mensagem e um botão único.

**Estados.** Único.

**Classificação: REINTERPRETAR.** Fechar o loop com uma confirmação explícita está certo.
O que falta não é a tela, é o registro persistente depois dela (ver item 3 de CRIAR NOVA).

---

### 20. Motor de scan (`ScanEngine`)
*Evidência: `11-checkout-scan-ativo.png`, `13-identificar-scanengine.png`*

**Propósito.** Superfície única de leitura RFID, reusada por quatro trilhas.

**Dados.** Lê `RFIDManager` do ambiente: `scannedTags`, `tagCount`, `isScanning`,
`isConnected`. Chama `startInventory()`, `stopInventory()`, `clearTags()` direto. A ação
primária é injetada pela trilha hospedeira via `ScanAction` (rótulo, ocupado, habilitado,
motivo do bloqueio, handler).

**Componentes.** `ParticleScanField` (quatro anéis concêntricos ciano + uma partícula por
tag, teto de 90), contador `liquidHero(76)`, lista de tags com badge "NEW" nos primeiros 2s,
barra inferior com Limpar, fallback QR, ação primária e botão escanear/parar.

**Estados.** Sem leitor (delegado a `onNeedsReader`), parado, escaneando, ação primária
travada com dica do motivo, erro em `errorMessage`.

**Classificação: REPENSAR.** É a peça mais forte do app antigo e a mais incompatível com a
lei nova. O hero de 300pt em ciano com partículas anima muito e informa pouco: diz quantas
tags foram lidas, nunca quantas **serviram**. Em papel claro e sem acento, ele precisa
virar uma faixa de estado que divide espaço com a lista, não um planetário que a engole.

---

### 21. Tour guiado (`TourOverlay` + `TourController` + `TourDefinitions`)

**Propósito.** Ensinar o app com coach marks sobre a interface real.

**Dados.** Três tours definidos: `.orientacao` (6 passos: hero, KPIs, botão +, aba Eventos,
status do leitor), `.checkout` (3 passos, um deles esperando a ação real do usuário),
`.retorno` (2 passos). Nove âncoras (`TourTarget`) espalhadas por cinco telas via
`.tourAnchor(...)`. Conclusão gravada em `UserDefaults` (`mmd_tour_done_<id>`).

**Componentes.** `SpotlightView` (dim com recorte arredondado, não captura toque),
`TourCard` (headline, corpo, barra de progresso, botão ou dica de ação).

**Estados.** Ativo/inativo, passo atual, três regras de avanço (`.tapNext`,
`.autoAfter(segundos)`, `.onAction(target)`).

**Classificação: DESCARTAR.** Tecnicamente bem feito e caro de manter: cada tela nova
carrega dívida de âncora, e o Event Pro já removeu a seção de tours do `AppConfig`. Um
operador de galpão com luva e pressa não lê seis cartões. Se o app precisa de tour, o
problema está na tela, não na falta de tutorial.

---

### 22. Conferência em grade (`LiquidCheckoutGridView`) — ÓRFÃ

**Propósito.** Ver a conferência do check-out como heatmap de unidades em vez de lista.

**Dados.** **Zero dado real.** `totalUnits = 214`, `readyUnits = 187`, `missingUnits = 27`,
o conjunto de faltantes e as 8 linhas de `CheckoutRow.mock` são todos literais. Recebe
`project: Project` no init e nunca o usa.

**Componentes.** `GlassCard(strong:)`, `ReadinessGauge`, `LiquidProgressBar`, `LazyVGrid` de
108 células tocáveis, chips de filtro em cápsula.

**Estados.** Só `filter` e `focused`, ambos visuais. Nenhum estado de dados.

**Classificação: DESCARTAR.** Mockup nunca ligado ao real, com incoerências internas: 108
células desenhadas para representar 214 unidades, e o chip "Faltando" em âmbar enquanto o
mesmo conceito na lista abaixo aparece em vermelho. Se a ideia de heatmap voltar, volta como
desenho novo em cima do estado real do scan, não como resgate deste arquivo.

---

### 23. Mapa do galpão (`LiquidPackingMapView`) — ÓRFÃ

**Propósito.** Guiar a coleta pelo galpão: prateleiras coloridas por progresso, rota
otimizada tracejada, marcador "você está aqui", card do próximo pick.

**Dados.** **Zero dado real.** Dez prateleiras fixas (A1 até C1, mais EXT), pontos de rota
fixos, próximo pick fixo ("Par LED 18x10W, 4 unidades"), stats fixos ("12:34", "~7 min",
"87/214", "41%"). Recebe `project` e nunca usa. O comentário do arquivo explica o porquê: o
campo `localizacao` no banco hoje guarda só "Galpao MMD", sem grid de prateleira.

**Componentes.** `GlassCard(strong:)`, mapa custom em `GeometryReader` com `routePath` e
`shelfBox`, barra de progresso de prateleiras, cards de stat, CTA com glow violeta.

**Estados.** Nenhum. Tudo `let`.

**Classificação: REPENSAR.** Chamaria de descarte se não fosse pela lei nova: "mapa full
bleed com rota" é justamente o motivo central do design novo. A função (levar o operador
pelo caminho certo com o mínimo de passos) sobrevive e ganha protagonismo. O que não
sobrevive é o formato: mapa fake dentro de um card de vidro. **Bloqueio real:** não existe
modelo de localização no Supabase, `localizacao` é texto livre. Antes de qualquer pixel,
essa decisão de dado precisa ser tomada.

---

## 3. CRIAR NOVA: o que falta olhando o fluxo inteiro

Olhando a operação ponta a ponta (evento fechado → packing → despacho → campo → retorno),
estas superfícies não existem no app antigo e o produto precisa delas. Ranqueadas por
impacto.

**1. Detalhe do evento (ficha).** Hoje tocar num evento pula direto pro packing. Não existe
lugar para ver cliente, endereço, datas, status do contrato, equipe ou o que já saiu.
O `Project` já carrega `nome`, `cliente`, `local`, `dataInicio`, `dataFim`, `status`, tudo
sendo usado só como subtítulo. É a tela que o mapa full bleed pede.

**2. Mapa e rota do evento.** O campo `local` existe e aparece como texto mono ("São Paulo
Expo", "Jardim Botânico · SP"). O operador que dirige até lá não tem nada. É o motivo
central da lei nova e não tem equivalente no app antigo.

**3. Recibo do despacho.** Depois do check-out o app mostra um overlay e volta pra raiz. Não
há como revisitar o que saiu, quando, por quem e com qual método. O dado existe
(`fetchProjectMovements`), a tela não.

**4. Histórico da unidade.** `LiquidItemDetailView` mostra condição e nunca mostra
trajetória. `fetchProjectMovements` já devolve movimentações; falta a visão por serial:
onde esteve, em que eventos, quantas voltas, quando o desgaste caiu.

**5. Busca global.** Não existe. Para achar um código MMD o operador entra em Etiquetar e
usa a busca client-side de lá, que serve a outro propósito. Achar uma peça pelo código é
necessidade diária.

**6. Estado offline e fila de sincronização.** Galpão tem sinal ruim. Hoje toda tela trata
falha de rede como erro terminal (`errorMessage`, `emptyState` de falha). Não há cache,
fila, nem indicação de "gravado localmente, sincroniza depois". Isso é decisão de
arquitetura antes de ser tela.

**7. Conferência manual.** Se a tag não lê e o QR está rasgado, o fluxo trava:
`canFinalize` nunca libera. Falta o caminho de marcar item na mão com justificativa. O
`checkoutProject` já aceita `overrideReason: String?` no APIClient e nenhuma tela oferece
isso.

---

## 4. O que o redesenho precisa resolver

Problemas concretos observados no código e confirmados no simulador.

**1. Semáforo de cor é a única codificação de estado, em quase toda tela.** `accentGreen`,
`accentAmber` e `accentRed` carregam significado sozinhos em: KPIs da home, dot do leitor,
badge de status de evento, badge de status de serial, linhas do check-out, pills do retorno,
linhas do retorno, botões da avaliação de condição, barra de depreciação, cor de bateria,
modo do leitor em Ajustes, toast de salvo, contadores do resultado de scan. Com zero acento
na lei nova, cada um desses precisa de outra codificação: posição, peso, rótulo, forma ou
densidade. Não é troca de paleta, é retrabalho de significado.

**2. Categoria vira arco-íris.** `LiquidCategoryBadge` mapeia cada categoria para uma cor
diferente. A captura `12-etiquetar-passo1.png` mostra violeta, âmbar, rosa e ciano na mesma
dobra. Oito categorias e oito cores não sobrevivem a "cor só com significado".

**3. Check-out e retorno esmagam a própria lista.** Painel de validação e camada de scan
disputam `maxHeight: .infinity` no mesmo `VStack`, e o hero vence. Com o scan ativo sobra
uma linha cortada da packing list. É o defeito funcional mais caro do app: o operador
confere um lote sem ver o que falta.

**4. Instrumento que sempre marca zero.** O card de progresso do packing passa
`progress: 0, state: .missing` hardcoded. Anel, percentual e contador `0/N` são decoração
com cara de medida.

**5. Duas telas de mock puro em produção.** `LiquidCheckoutGridView` e `LiquidPackingMapView`
somam 478 linhas de dado literal, ambas recebendo `project` sem nunca usar. A do grid ainda
se contradiz sozinha: 108 células para 214 unidades e o mesmo conceito ("faltando") em duas
cores diferentes na mesma tela.

**6. Cliente de API duplicado.** `LiquidVincularTagView` instancia
`@StateObject private var apiClient = APIClient()` em vez de usar o do ambiente, criando um
segundo ciclo de sessão fora do gate de auth da raiz.

**7. Quatro gramáticas de erro diferentes.** `LiquidHome` mostra card inline âmbar;
`LiquidProjectsListView` e `LiquidPackingListView` fundem erro e vazio no mesmo bloco
central (o operador não distingue "não tem evento" de "não consegui carregar");
`FindSerialStep` usa `InlineNotice`; `ScanEngine` recebe uma string solta. O app novo
precisa de uma só.

**8. Chevron como ritual.** `chevron.right` aparece na agenda da home, na linha do leitor,
na `HomeActionRow`, no CTA de todo card de evento, no card do próximo evento, na linha de
serial do Etiquetar, na lista de leitores. A lei nova pede linha simples sem chevron: são
sete lugares a limpar.

**9. Repetição de CTA por linha.** Cada `projectCard` termina com hairline + "Conferir
packing >" ou "Abrir >". Em uma lista de 15 eventos, a mesma frase aparece 15 vezes. A ação
pertence à linha inteira, não a um rótulo repetido.

**10. Densidade baixa por card de vidro.** `panelSurface` com padding `xl` em tudo faz três
eventos ocuparem a tela inteira. Um operador que precisa varrer 15 eventos rola muito para
ver pouco.

**11. Home decidiu não rolar.** O comentário em `LiquidHome.swift:39` declara "Home sem
scroll: tudo cabe na tela" e remove o pull-to-refresh junto com o `ScrollView`. Funciona
com três eventos na agenda; não funciona com dez, e tira o gesto de atualizar que o operador
espera.

**12. Dado sujo vaza cru pra interface.** Itens com nome vazio no banco renderizam cards sem
título: no Etiquetar sobra só uma badge de categoria flutuando, no resultado de scan sobra
só o código. O `displayName` não trata string vazia, só `nil`.

**13. Alvos de toque abaixo de 44pt.** As cápsulas do `LiquidWearStepper` têm 12pt de
altura. Os botões de ação da linha de retorno (lápis e lupa) são `Image` de 13pt sem frame
mínimo. Com luva, nenhum dos dois acerta.

**14. O design system tem peça morta e peça sobrecarregada.** `CausticBackground`, o fundo
iridescente que dá nome ao Liquid Glass, tem **zero uso em tela**: as quatro ocorrências no
código estão todas dentro de blocos `PreviewProvider`. Quem carrega o fundo de fato é
`TechnicalGridCanvas`, em 13 das 21 telas vivas. E o vidro de verdade (`GlassCard`,
`glassSurface`) só aparece nas duas telas órfãs. Na prática o app roda em painéis opacos,
e o DS mantém três camadas de fundo para usar uma.

**15. Onboarding acoplado às telas.** Nove `.tourAnchor(...)` espalhados por cinco arquivos
de tela mais `tour.notifyAction(...)` dentro do handler do botão de check-out. Toda tela
nova nasce devendo âncora para um sistema que o app novo já decidiu não levar.

---

## Apêndice: mapa de navegação atual

```
LiquidRoot (NavigationStack único)
├── gate: LiquidLoginView (fullScreenCover, quando Supabase configurado e sem sessão)
├── tabs (visíveis só com path vazio)
│   ├── .inicio   → LiquidHome
│   ├── .eventos  → LiquidProjectsListView(.todos)
│   └── .ajustes  → LiquidConfigView
├── sheet "+"     → QuickActionsSheet → 4 rotas
└── rotas (AppRoute)
    ├── .conectar          → LiquidConnectReader        (entradas: home, ajustes, scan engine, item perdido, identificar)
    ├── .config            → LiquidConfigView            (NUNCA empurrada; só existe como tab)
    ├── .projetos(filter)  → LiquidProjectsListView      (só do QuickActionsSheet)
    ├── .packing(project)  → LiquidPackingListView       → .checkout
    ├── .checkout(project) → LiquidCheckoutValidationView → ScanEngine + LiquidQRScannerSheet
    ├── .retorno(project)  → LiquidReturnValidationView   → ScanEngine + LiquidConditionAssessment + .itemLost
    ├── .identificarScan   → IdentificarFlow              → .scanResult
    ├── .scanResult        → LiquidScanResultView         → .itemDetail, .etiquetar(tag:)
    ├── .etiquetar(tag:)   → LiquidVincularTagView        (passo 1 → passo 2)
    ├── .itemDetail        → LiquidItemDetailView
    └── .itemLost          → LiquidItemLostView
```

Duas observações do mapa: a rota `.config` está declarada e nunca é empurrada por ninguém
(a tela só existe como aba), e `.projetos(filter)` só tem uma entrada, o sheet de ações
rápidas, o que torna Despachar e Receber um desvio para a mesma lista que a aba Eventos já
mostra.
