# Plano: Reescrita Mobile Liquid Glass (MMD Estoque iOS)

Plano mestre da migração do app iOS do Nothing Design System para Liquid Glass 2030.
Derivado de uma sessão de grill (9 decisões). Valida com Marco antes de executar.

## Contexto

- Decisão de produto: Nothing morre 100%, Liquid assume todo o mobile.
- O mobile NÃO é espelho do web. Web = gestão (Marcelo, escritório). Mobile = execução de campo (equipe, iPhone + RFD40).
- A reescrita é ~95% trabalho visual (frontend SwiftUI). O backend (Supabase + APIClient) já está pronto: 7 migrations, infra RFID, loop operacional, check-out e retorno funcionando.
- O app não está em uso (sem auth, mock RFID, último commit abril). Estado misto durante a transição não machuca ninguém.

## Decisões do grill

| # | Tema | Decisão |
|---|---|---|
| 1 | Fidelidade | Liquid com legibilidade primeiro. Hero do scan cinematográfica, telas de trabalho sóbrias e de alto contraste. |
| 2 | Escopo | Reskin das 10 superfícies + produzir vincular-tag (etiquetar em campo). |
| 3 | Organização raiz | Por job. Home com 4 ações (Identificar, Despachar, Receber, Etiquetar) + Config. |
| 4 | Motor de scan | Único, reaproveitado nas 4 trilhas. A validação é camada por cima. |
| 5 | Etiquetar | Entrada própria na home + atalho oportunista quando o scan acha tag virgem. |
| 6 | Estratégia | Big bang numa branch, construído em waves com agentes paralelos. |
| 7 | Granularidade | 4 agentes por domínio na Wave 1. |
| 8 | Ferramentas | Visual tudo com Claude. |
| 9 | Codex | QA + backend (vincular-tag) + testes, em paralelo, sem tocar nas Views. |

## Régua visual (decisão 1)

- Hero do scan: onde caustics, vidro translúcido e glow vivem. Momento "uau".
- Telas de trabalho (check-out, retorno, listas): contraste alto, leitura rápida, caustics contidos no fundo, vidro só onde não cobre o dado. Campo: sol, pressa, luva.
- O `docs/design-brief.md` é a bíblia do Nothing. A hierarquia de conteúdo (o que é primário/secundário/terciário em cada tela) sobrevive e serve de espinha. As regras visuais (Space Grotesk/Mono/Doto, sem sombra, sem gradient, OLED puro) morrem.

## Inventário de telas (10 superfícies)

| Superfície | Origem |
|---|---|
| Home (lançador das 4 ações) | nova |
| Conectar leitor / status | existe, vira gate e banner persistente no topo |
| Scan (motor único, hero) | unifica ScanView + scan do checkout + scan do retorno |
| Resultado do item (identificar) | reskin de ScanResultView |
| Lista de projetos (filtrada por contexto) | reskin de ProjectsListView |
| Packing / detalhe do projeto | reskin de PackingListView |
| Camada de validação check-out | hoje embutida em CheckoutFlowView, vira camada sobre o motor |
| Camada de validação retorno + defeito | hoje embutida em ReturnFlowView, vira camada sobre o motor |
| Vincular tag | nova |
| Config | reskin de ConfigView |

Assumção registrada: a lista de projetos é uma tela só, parametrizada. Despachar abre os projetos a sair, Receber abre os que estão em campo.

## Fluxo (por job)

Pré-requisito de tudo: conectar o leitor RFD40 (Bluetooth) habilita o scan. Status sempre visível no topo.

- Identificar: scan tag -> resultado do item.
- Despachar: projeto -> packing -> scan lote -> confirma saída (EM_CAMPO).
- Receber: projeto em campo -> scan lote -> marca defeito -> confirma volta.
- Etiquetar: tag virgem -> busca item -> vincula. Também nasce de dentro do scan quando a tag é desconhecida.

## Fundação Liquid (Wave 0, Claude)

Toda tela depende disto. Passo zero, serial.

- Tokens em Swift: cores oklch viram `Color` (bg 0/1/2, fg 0/1/2/3, accents cyan/violet/amber/green/red), radii (10/16/24/32), blur (12/24/40), shadows com glow, motion, gradientes do ring. Fonte: `design_handoff_estoque_mmd/tokens/mmd-tokens.json`.
- Fontes: bundle de Inter Tight + JetBrains Mono. Aposentar Space Grotesk, Space Mono, Doto.
- Componentes compartilhados:
  - `CausticBackground` (orbs ciano/violeta desfocados sob vidro).
  - `GlassSurface` / `GlassCard` (vidro translúcido, borda highlight, sombra).
  - `ReadinessRing` (ring de prontidão, motivo central, gradientes por estado).
  - `ScanEngine` (motor de scan visual: contador hero, lista de tags, botão escanear, pulse, fallback QR).
  - Reskin de `StatusBadge`, `WearBar`, `ProgressSegmentBar`, `DotGrid` (ou aposentar o que não couber).

## Waves e agentes

| Wave | Quem | Trabalho | Modo |
|---|---|---|---|
| 0 | Claude | Fundação Liquid (tokens, fontes, componentes, motor de scan) | serial, bloqueia tudo |
| 0' | Codex | Backend vincular-tag (PATCH) + scaffold de testes da camada de dados | paralelo à Wave 0 |
| 1 | Claude (4 subagentes) | As 10 telas, divididas por domínio | paralelo, worktree por agente |
| 1' | Codex | Testes das telas conforme entregam + limpeza do Nothing | paralelo à Wave 1 |
| 2 | Claude (eu) | Costura da navegação, build no simulador, screenshots, revisão adversarial do Codex | integração final |

### Divisão da Wave 1 (Claude, 4 subagentes)

1. Moldura: home + navegação raiz + conectar leitor/status + config.
2. Scan + validação: resultado do item + camada check-out + camada retorno/defeito (sobre o motor).
3. Projetos: lista filtrada + packing/detalhe.
4. Etiquetar: vincular tag + atalho oportunista.

### Contratos entre agentes

- A fundação publica os componentes prontos. A Wave 1 só consome, nunca edita a fundação.
- A navegação raiz é da Moldura. Ela entrega o esqueleto e as rotas cedo, os outros três penduram as telas nas rotas.
- Cada subagente Claude roda no próprio worktree, em arquivos disjuntos. Merge na Wave 2.
- Fronteira de stack: Claude toca `Views/` e `Design/`. Codex toca `Services/`, `Models/`, testes e `supabase/`. Disjunto, sem colisão.

## Backend (Codex)

Quase tudo pronto. O que falta:

- Vincular tag: método no APIClient que faz PATCH em `serial_numbers` setando `tag_rfid` (espelha `updateProjectStatus`). A coluna e os índices já existem (`00006_rfid_infrastructure.sql`).
- ViewModel leve de vínculo (lógica de busca do serial + associação), sem View.
- Testes: ViewModels (checkout, retorno, vínculo) + camada de dados.

## Validação (Wave 2)

- Build verde no simulador iOS.
- Screenshot de cada uma das 10 telas, prova visual do Liquid.
- Revisão adversarial do código (Codex como segundo cérebro independente).
- Scan de consistência: nenhum resíduo de Nothing (cor, fonte, token), nenhum em-dash em string visível.

## Pré-checks antes de executar

- [ ] Confirmar que o Codex está configurado neste ambiente.
- [ ] Criar branch da reescrita (`cc/reescrita-liquid-mobile`).
- [ ] Confirmar Xcode + simulador iOS disponíveis pra validação visual.

## Checklist de execução

### Wave 0 (Claude, fundação)
- [ ] Tokens Liquid em Swift (cores, radii, blur, shadow, motion, ring).
- [ ] Fontes Inter Tight + JetBrains Mono no bundle.
- [ ] CausticBackground.
- [ ] GlassSurface / GlassCard.
- [ ] ReadinessRing.
- [ ] ScanEngine (motor de scan visual).
- [ ] Reskin dos componentes que sobrevivem.

### Wave 0' (Codex, backend)
- [ ] Método vincular-tag no APIClient.
- [ ] ViewModel de vínculo.
- [ ] Scaffold de testes da camada de dados.

### Wave 1 (Claude, 4 subagentes)
- [ ] Moldura: home + nav + conectar + config.
- [ ] Scan + validação: resultado + check-out + retorno.
- [ ] Projetos: lista filtrada + packing/detalhe.
- [ ] Etiquetar: vincular tag + atalho oportunista.

### Wave 1' (Codex, qualidade)
- [ ] Testes das telas conforme entregam.
- [ ] Remoção do Nothing (Theme antigo, fontes antigas, dead code).

### Wave 2 (Claude, integração)
- [ ] Costura da navegação.
- [ ] Build no simulador.
- [ ] Screenshots das 10 telas.
- [ ] Revisão adversarial Codex aplicada.
- [ ] Scan de consistência (zero resíduo Nothing, zero em-dash).
