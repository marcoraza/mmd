# Handoff: Event Pro, sessão de 2026-07-27

Documento autocontido para retomar o trabalho numa sessão nova. Quem lê aqui não
viu a conversa anterior e não precisa ver.

## Onde estamos em uma frase

O app MMD Estoque foi congelado e limpo; nasceu o **Event Pro**, um app iOS novo em
`event-pro/`, com fundação de design derivada de um estudo medido do ClickUp mobile.
A tela de login funciona contra o Supabase real. As telas de operação ainda não
existem.

## Por que o Event Pro existe

O MMD Estoque atual leva nota 4,5 de 10 em design. O diagnóstico não é "feio", é
**plano**: tudo tem o mesmo peso visual e nada no app produz um momento. O design
system Liquid Glass está bem construído mas é pouco adotado pelas telas (o fundo
iridescente `CausticBackground` tem zero uso, o vidro real aparece em 2 de 19 telas,
o feedback de toque em 4 de 19, e o app inteiro não tem uma linha de haptic).

Decisão do Marco: em vez de refatorar o MMD, começar limpo em pasta separada,
trazendo só o necessário, e iterar lá. O MMD fica intacto como referência viva.

## Estado do repositório

Branch: `cc/sprint-auth-ios`

Dois commits desta sessão, ambos já feitos:

- `1a6a179` ios: remove Nothing Design System e telas legadas (3.761 linhas)
- `7b0f697` event-pro: fundacao do app novo com gramatica medida do ClickUp

IMPORTANTE: o working tree tem bastante coisa não commitada que **não é minha** e não
deve ser tocada sem o Marco pedir. Inclui trabalho em RFID (`RFIDManager`,
`ZebraRFIDManager`, `MockRFIDManager`), e uma frente inteira de treinamento no web
(`apps/web/src/app/treinamento/`, `training-*`). Não commitar isso junto.

## Como rodar agora

O simulador **iPhone 17 Pro** (`CCA2A995-1A46-489F-AA5A-4AB6BA03DE0B`) é o device
desta sessão. O Marco usa o **iPhone 17** em outra sessão paralela: não mexer nele.

```bash
xcrun simctl boot CCA2A995-1A46-489F-AA5A-4AB6BA03DE0B
xcrun simctl launch CCA2A995-1A46-489F-AA5A-4AB6BA03DE0B com.emdash.eventpro
```

Para build, usar o MCP do simulador com:
- project: `/Users/marko/Projects/mmd/event-pro/EventPro.xcodeproj`
- scheme: `EventPro`
- udid: `CCA2A995-1A46-489F-AA5A-4AB6BA03DE0B`

Depois de editar `project.yml` ou adicionar/remover arquivo, rodar `xcodegen generate`
dentro de `event-pro/` antes do build.

Acesso do app: usuário `supervisor`, senha `123456`. (Sim, é fraca. É Supabase de
produção com dados reais do cliente. Já avisei o Marco duas vezes; a decisão é dele.)

## Anatomia do Event Pro

```
event-pro/
├── project.yml                  XcodeGen, bundle com.emdash.eventpro
└── EventPro/
    ├── App/EventProApp.swift    @main, AuthState (wrapper do actor), RootView
    ├── Config/AppConfig.swift   copiado do MMD, sem a seção de tours
    ├── Design/
    │   ├── ColorOKLCH.swift     conversor oklch para Display P3 (namespace OKLCH)
    │   └── Tokens.swift         <<< o coração, ler antes de tudo
    ├── Models/                  6 models copiados do MMD sem alteração
    ├── Services/                APIClient, AuthSessionStore, KeychainStore
    ├── Resources/               Info.plist + Inter Tight e JetBrains Mono
    └── Views/                   LoginView, HomeView (casca com barra flutuante)
```

Backend foi duplicado no mínimo. RFID **não** veio, entra quando a tela de scan nascer.

## A lei do design, que é o ponto do projeto

`Design/Tokens.swift` codifica um estudo medido, não gosto pessoal. As três fontes
vivem em `~/code/raza-design-universes/`:

- `universo-clickup-mobile.md`, gramática da superfície mobile
- `mapa-clickup-mobile.md`, anatomia das cinco telas
- `clickup-sistema-espaco-estado-motion.md`, as escalas (é o mais importante)

Resumo operacional das leis:

1. **Espaço** sai de doze degraus de base 4 (4 até 48). Fora da lista não existe.
2. **Dois regimes de hierarquia**: escala grande só no título de tela e no número
   herói. Dentro de lista, hierarquia é por peso e cor, nunca por tamanho. Aumentar
   fonte dentro de lista é sotaque de landing e reprova.
3. **Elevação no dark** é clarear a superfície mais hairline de 1px, nunca sombra
   preta pesada. Teto de alpha em 10 por cento vem do ClickUp e continua valendo.
4. **Estados** (hover, press) são degraus da rampa com token próprio. Nunca
   `opacity` nem `brightness`, que lavam a cor e derrubam o contraste do texto.
5. **Cor só com significado**: estado operacional, identidade de categoria ou
   seleção. Cor decorativa é ruído e reprova.
6. **Toque nunca abaixo de 44pt** e texto nunca abaixo de 4,5:1. Ambos são mais
   rígidos que o ClickUp de propósito: galpão, luva e pressa.
7. **Motion**: duas curvas (`EP.snappy` para UI, `EP.ease` para fade), mais
   `EP.arrive` para entrada. Ação de alta frequência não ganha transição.
8. Todo alvo tocável usa `EPPressStyle`, que já traz escala e haptic.

## Armadilhas que já custaram tempo (todas registradas em tasks/lessons.md)

1. **A suíte de testes do MMD envenena a config do app no simulador.**
   `AuthSessionStoreTests` chama `AppConfig.shared.save()` com
   `https://example.supabase.co` e não restaura. Depois disso o login falha com
   "erro de rede" mesmo com tudo certo. Existe um chip de tarefa aberto para isolar
   isso. Se acontecer no Event Pro, é a mesma causa.

2. **Para escrever config no simulador, o device precisa estar DESLIGADO.**
   O `cfprefsd` do simulador serve cache próprio e sobrescreve edição externa.
   Sequência certa: `simctl shutdown`, editar o plist com `plutil`, depois `boot`.
   `simctl spawn <udid> defaults write` escreve fora do container e não funciona.

3. **O Supabase hiberna no free tier.** Sintoma: MCP dá timeout e o host nem resolve
   em DNS. Despausar com o token `sbp_` do keychain (entry "Supabase CLI", formato
   `go-keyring-base64:`) via `POST https://api.supabase.com/v1/projects/bphmxticdyuctovfumcj/restore`.
   Leva 3 a 4 minutos.

4. **Análise estática por grep não serve como prova de código morto.** Nesta sessão
   meu grep reportou "zero usos" para coisas em uso e quase deletei código vivo. O
   compilador é o verificador; buildar é obrigatório antes de afirmar.

## Verificações que já passaram

- MMD Estoque: build verde, 65 testes, 0 falhas, app roda idêntico depois da limpeza.
- Event Pro: build verde; login com senha errada retorna "usuário ou senha
  incorretos" vindo do servidor (prova que a rede e a URL estão certas), e com a
  senha certa troca de tela.

## Regra de direção (correção do Marco, 2026-07-27)

O Event Pro NÃO é produto novo. É o MMD Estoque reembalado na gramática ClickUp:
para cada tela, ler a equivalente do MMD (`Views/Liquid/` + `ViewModels/`), portar
conteúdo, dados e lógica intactos, e trocar só a lei visual (Tokens.swift). Não
inventar tela do zero. A sequência começa pela Home.

## Estado das telas

- FEITO `964319b`: **Home cockpit** (`Views/HomeView.swift` + `ViewModels/HomeViewModel.swift`,
  port do `LiquidHome` + `LiquidHomeViewModel`). Hero do próximo evento com prontidão
  como número herói, KPIs do estoque (formato 1.049), agenda de confirmados, atenção
  de itens sem tag. Sem interação fake: hero e agenda viram botão quando os destinos
  existirem. Ficou de fora o readerRow (RFID ainda não foi portado).
- FEITO `bcc4f43`: **lista de eventos** (`Views/EventsListView.swift`), aba Eventos.
  Quatro estados de dados, badge de estado cheio, data mono. Tap devolve `Project`
  via `onSelect`, hoje no-op.
- Barra flutuante troca aba de verdade; Ajustes tem sessão e Sair; `APIClient` nasce
  no app e é injetado por environmentObject.

Próximas reembalagens candidatas (sempre partindo do MMD): packing list
(`LiquidPackingListView`), detalhe de item, fluxo de conexão do leitor. Confirmar
ordem com o Marco antes de começar.

## Pendências declaradas

- Durações reais de motion do ClickUp não foram medidas: a extração de tokens veio
  com todas as durações em `0s` porque o ambiente tinha redução de movimento ativa.
  As curvas são reais. Para fechar, abrir o ClickUp web logado no navegador e ler
  `transition-duration` computado.
- Tema escuro do ClickUp mobile não foi estudado (não alterei config do iPhone
  pessoal do Marco). É a lacuna mais relevante, já que o Event Pro é dark-first.
- Estados de carregando e erro do ClickUp não foram observados ao vivo.
- Senha `123456` em produção.
