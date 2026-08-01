# Fonte de verdade para o Fable: MMD Estoque atual

Data: 17/07/2026  
Objetivo: reconstruir o tutorial visual de 5 a 6 minutos a partir da implementação atual, sem reaproveitar screenshots ou coordenadas antigas.

## Regra principal

Descarte todos os PNGs, contact sheets, crops e marcações usados na versão anterior do Claude Design.

O arquivo `mmd-current-codebase-2026-07-17.zip` é a única fonte visual e estrutural válida. Gere os próprios frames a partir desse código. Não use `web-dashboard.png`, `web-alocacao.png`, `ios-contact-sheet.png` ou qualquer screenshot já anexado ao projeto.

## iOS atual, verificado no Xcode

Build verificado com sucesso no simulador iOS 26.2 usando o scheme `MMDEstoque`.

Entrada real:

```text
MMDEstoqueApp.swift
  -> LiquidRoot.swift
     -> LiquidHome.swift
     -> LiquidProjectsListView.swift
     -> LiquidPackingListView.swift
     -> LiquidCheckoutValidationView.swift
     -> LiquidReturnValidationView.swift
     -> LiquidConnectReader.swift
     -> IdentificarFlow.swift
     -> ScanEngine.swift
```

Arquitetura visível atual:

- abas persistentes: `Início`, `Eventos`, `Ajustes`
- botão circular `+`: abre `Identificar`, `Despachar`, `Receber`, `Etiquetar`
- Home: próximo Evento, prontidão, KPIs, agenda, atenção e status do leitor no rodapé
- Despachar: Evento confirmado -> Packing -> Check-out -> leitura RFID -> confirmar saída
- Receber: Evento em campo -> Confirmar volta -> leitura RFID -> condição -> registrar volta
- Identificar: leitura RFID ou QR -> resultado -> detalhe da unidade
- RFD40: acesso pelo status do leitor na Home ou pelo CTA contextual do `ScanEngine`

### Arquivos iOS proibidos

Não use nem represente estas telas legadas, mesmo que ainda existam no repositório ou no target:

```text
Views/ContentView.swift
Views/CheckoutFlowView.swift
Views/ConnectReaderView.swift
Views/PackingListView.swift
Views/ProjectsListView.swift
Views/ReturnFlowView.swift
Views/ScanView.swift
```

Essas telas não são a raiz do app atual. A raiz real é `LiquidRoot`.

## Marcação precisa no iOS

O app atual já possui o sistema correto de spotlight e alinhamento:

- `Onboarding/TourAnchor.swift`
- `Onboarding/TourOverlay.swift`
- `Onboarding/SpotlightView.swift`
- `Onboarding/TourDefinitions.swift`
- `Onboarding/TourModels.swift`

Use os bounds gerados por `TourAnchorKey` como fonte geométrica. Não posicione círculos com valores fixos de `x` e `y`.

Targets existentes:

```text
heroCard
kpiCard
plusButton
eventosTab
readerStatus
packingHero
openCheckout
checkoutScan
retornoHeader
```

Para um elemento sem `TourAnchor`, use a `accessibilityLabel` do SwiftUI ou crie um anchor equivalente no fac-símile renderizado. O círculo precisa derivar do retângulo real do componente na tela final.

## Web atual

Renderize as telas a partir de `apps/web/src`. Preserve os componentes reais, tokens de `globals.css`, `Primitives.tsx`, navegação e dados de fixture.

Fluxo operacional principal:

```text
Dashboard -> Eventos -> detalhe do Evento -> Packing -> Alocação -> Check-out -> Auditoria
```

O treinamento usa o Evento isolado `Treinamento · Marcelo`.

Para cada frame Web:

1. monte a tela real em um capture harness com fixtures determinísticas
2. aguarde fontes e layout estabilizarem
3. localize o elemento por papel, texto ou seletor estável
4. leia `getBoundingClientRect()` depois do layout final
5. ancore cursor, pulso, círculo, sublinhado e callout nesse retângulo
6. faça o screenshot do frame já composto

É proibido marcar uma coordenada visual estimada.

## Frames que o próprio Fable deve gerar

Web, 1440x900:

1. Dashboard com Evento `Treinamento · Marcelo`
2. lista de Eventos e clique no Evento de treinamento
3. detalhe do Evento e gate operacional
4. Packing com cobertura e item faltante
5. Alocação com clique em um Serial Number real
6. Check-out e confirmação
7. Auditoria e persistência da movimentação
8. QR público mínimo

iOS, 390x844, baseado somente no Liquid atual:

1. Home atual
2. botão `+` e Ações rápidas
3. lista de Eventos para Despachar
4. Packing atual
5. Check-out com `ScanEngine`
6. Conectar leitor RFD40
7. leitura RFID com contador e status
8. confirmar saída
9. Receber e Confirmar volta
10. condição do item e fechamento do retorno

## Segurança e verdade

- nunca mostrar senha, token, endpoint do Supabase, chave, EPC bruto ou credencial
- usar códigos amigáveis `MMD-...` nos frames educacionais
- RFID é o caminho principal; QR é fallback
- o badge `STORYBOARD` continua obrigatório quando o frame não for uma captura do iPhone e RFD40 reais
- não chamar simulação de hardware real

## Novo artefato

Crie um arquivo novo, `MMD Estoque Tutorial v2.dc.html`. Não edite a animação anterior.

Primeiro gere e mostre uma contact sheet com todos os frames Web e iOS produzidos a partir do código. Só depois monte a timeline e o motion.

Gate de aprovação interno antes da timeline:

- nenhum asset antigo presente
- iOS corresponde a `LiquidRoot`
- todos os círculos tocam o elemento correto
- todos os sublinhados estão dentro do texto alvo
- nenhuma informação sensível aparece
- o frame seguinte mostra a consequência da ação anterior
