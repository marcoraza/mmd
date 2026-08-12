# Lessons

## 2026-08-12

- Em toda escrita idempotente de estoque, o retry precisa comparar `actor_id` e `payload_hash` antes de devolver ACK. Chave igual de outro operador é conflito, nunca recibo alheio. Em EPC, RLS de linha não protege coluna sensível: bloquear alteração direta de `tag_rfid` no banco e liberar só a RPC transacional auditada.

## 2026-07-27

- `AuthSessionStoreTests` chama `AppConfig.shared.save(supabaseUrl: "https://example.supabase.co", anonKey: "test-anon-key", ...)`, que grava em `UserDefaults.standard` do app host e nao restaura no tearDown. Rodar a suite no simulador deixa o app instalado apontando para um host inexistente, e o sintoma aparece depois como "Erro de rede: nao foi possivel encontrar um servidor" na tela de login. Teste que toca config global precisa de suite isolada ou restore no tearDown.
- Ao diagnosticar config de app no simulador, o arquivo em `Containers/Data/.../Library/Preferences/<bundle>.plist` nao e fonte de verdade com o device ligado: o `cfprefsd` do simulador serve cache proprio e faz flush por cima de edicoes externas. Para escrever config confiavel: `simctl shutdown`, editar com `plutil` com o device parado, depois `boot`. `simctl spawn <udid> defaults write` escreve fora do container do app e nao tem efeito.
- Projeto Supabase do MMD hiberna no free tier. Sintoma: `execute_sql` do MCP da timeout e o host nem resolve em DNS. Despausar via `POST https://api.supabase.com/v1/projects/<ref>/restore` com o token `sbp_` do CLI (keychain, entry "Supabase CLI", formato `go-keyring-base64:`). Restore leva 3 a 4 minutos.

## 2026-07-17

- Quando Marco pedir uma entrega usando uma skill, usar o protocolo existente sem editar a skill compartilhada. Neste projeto, o hub reúne as trilhas e os tutoriais Web/iOS aplicam o formato `raza-showcase` com capturas e anéis numerados.
- Em tutorial visual, screenshots soltos não são fonte de verdade da interface. Para Web, renderizar a codebase atual e ancorar marcações no DOM. Para iOS, seguir `MMDEstoqueApp -> LiquidRoot` e os `TourAnchor` do SwiftUI. Nunca usar `ContentView` ou frames legados só porque ainda existem no target.

## 2026-04-03

- Em tarefas de saneamento de planilha, nao assumir que o prompt descreve a versao atual do arquivo. Ler a estrutura real primeiro e tratar o prompt como contexto historico.
- Quando a planilha alvo estiver em edicao concorrente, nao escrever no `.xlsx`. Gerar uma saida intermediaria importavel (`.md` ou `.csv`) e registrar o timestamp da versao observada.
- Antes de aplicar qualquer preenchimento em arquivo vivo, revalidar a estrutura das abas. O layout pode mudar no meio da sessao.
- Se o conflito com outro agente for apenas cosmetico, aplicar por chave estavel (`Codigo`) e nao por posicao de linha.
- Nao tratar o valor atual da planilha como fonte confiavel so porque o campo ja estava preenchido. Se nao houver fonte melhor, marcar como estimativa explicita.
- Ao casar overrides e fontes locais, normalizar nomes curtos e aliases de subcategoria. A planilha mistura `TRIPE MIC`, `CAIXA SOM`, `RX MIC` e outros apelidos com versoes por extenso.
- Scripts que leem a planilha precisam tolerar cosmetica em campos numericos, como estrelas em `Desgaste` ou texto com `R$`.
- Quando um pipeline exporta `Valor Atual`, o campo `Deprec.%` precisa manter o mesmo contrato semantico da planilha: percentual perdido, nao percentual remanescente.
- Scripts que reaplicam valores no `.xlsx` nao podem congelar colunas derivadas. Se a regra vive na planilha, reescrever a formula e forcar recalc ao salvar.
- Nomes ambigguos de item nao podem ser inferidos so pelo texto. Antes de reprecificar um registro como acessorio ou capsula, validar com o Marco quando o nome puder apontar para o equipamento principal, como em `PARA MICROFONE SM58`.
- Antes de citar um teste como parte de um PR, conferir se ele esta versionado e se roda contra o codigo realmente commitado. Teste local em arquivo untracked nao conta como cobertura entregue.
- Em saida voltada para leitura humana na planilha ou no markdown, moeda em BRL deve sair no formato visual brasileiro, como `R$ 6.922,00`, mesmo que a estrutura interna continue numerica para processamento.
- Em grafico do dashboard, o texto exibido na fatia precisa usar a mesma metrica da serie do grafico. Se o pie chart usa `Valor Original`, o rotulo tambem precisa usar `Valor Original`, nao `Valor Atual`.

## 2026-04-21

- Cada JSX do `design_handoff_estoque_mmd/components/` pode ter multiplas variacoes (V1/V2/V3). O Marco ja fez uma escolha por tela. Antes de portar qualquer proxima tela (catalog-calendar, screen-projects, screen-item-detail, etc.), listar as variacoes existentes no arquivo e perguntar qual e a correta. Nunca assumir V1 por default. A escolha do dashboard foi V2 Cinematic.
- As escolhas consolidadas do Marco estao na `design_handoff_estoque_mmd/galeria-explorativa.html` (card "Escolhas consolidadas"), nao no README. Conferir a galeria antes de perguntar de novo. Escolhas: Dashboard=Cinematic, Projetos=Kanban com switch Timeline/Split, Item=Card 3D flutuante, RFID=Particulas ao vivo (hero), Checkout=Hibrido (grade + lista com filtros sincronizados).
- Regra global web: tema inicia sempre em LIGHT, com switch para dark (desktop e iOS). Nao respeitar prefers-color-scheme; default hardcoded light. Persistir em localStorage `mmd-theme`. iOS usa AppStorage equivalente e `.preferredColorScheme`.
- Checklist de consistencia por tela (rodar antes de passar pra proxima):
  - Tokens: `--bg-*`, `--fg-*`, `--glass-*`, acentos, sem cor hardcoded
  - Tipografia: Inter Tight body, JetBrains Mono mono uppercase labels/data, hierarquia coerente (56/28/14/11/10)
  - Espacamento: mesmos multiplos (4/8/12/14/18/24/28/36/40/48)
  - Primitives reusados: GlassCard, Ring, Caustic, TopBar, SideRail
  - Grid e ritmo equivalentes ao Dashboard
  - Light e Dark ambos validados via screenshot
  - Data layer: loader tipado em `lib/data/`, mock separado do componente
  - Motion tokens (`--motion-fast/default`), focus ring visivel
  - Acessibilidade: aria-label, contraste, hit area >=40px
  - Copy pt-BR, REGRA ZERO (zero em-dash)
- Ao final de cada tela, dar nota 0-10 e listar o que falta pra 10 antes de seguir.

## 2026-06-23

- Para o PRD MAR-171, `docs/mar-171-agent-brief.md` é a fonte curta atual. Referências antigas a `design_handoff_estoque_mmd/` são históricas. O design atual vive em `apps/web/public/handoff/`, `apps/web/src/components/mmd/Primitives.tsx`, `apps/web/src/app/globals.css` e nas evidências por issue.
- Não ressuscitar cabos por lote como operação futura. Cabos são unit-only e lotes são legado.
- Não tratar auth como etapa posterior ao MVP. Dados reais exigem Supabase Auth, perfis, RLS e auditoria antes de produção real.
- Frente de UI deve adaptar `apps/web` e `apps/ios` existentes. Prints, imagegen e screenshots são evidência e referência, não produto paralelo.
- Planilha real de evento não é packing puro. Importação precisa separar evento, financeiro, serviço, equipamento, candidato de catálogo e pendência de revisão antes de escrever no Supabase.
- Evento cancelado deve entrar como histórico administrativo, sem packing e sem alimentar sugestão de equipamento.
- Quando uma planilha usa dia/mês sem ano, o importador deve buscar o ano da aba ou do arquivo antes de cair no ano atual.
- Evento real criado a partir de planilha não pode expor rastro técnico no produto. Backup fica em `tasks/evidence`, tela mostra nome humano, status, data, percentual e resumo curto da ficha.
- Card de evento não deve renderizar a ficha inteira em `notas`. Cabeçalho mostra no máximo endereço, montagem e desmontagem; detalhe completo fica no fluxo da ficha.
- Criar evento pela ficha não popula packing list. Quando a origem real for planilha, fazer backfill explícito da packing list e filtrar serviço, equipe, buffet, mobiliário solto e financeiro antes de criar item pendente no catálogo.

- Event Pro nao e produto novo: e o MMD Estoque reembalado na gramatica medida do ClickUp. Antes de desenhar qualquer tela nova, ler a tela equivalente do MMD (Views/Liquid/ + ViewModels/) e portar conteudo, dados e logica; muda so a lei visual (Tokens.swift). A ordem combinada comecava pela Home (LiquidHome -> InicioView), nao por tela inventada. Handoff dizia "lista de eventos" e eu li como licenca pra criar do zero; o certo era perguntar qual tela do MMD estava sendo reembalada.

## 2026-07-28

- No protótipo da Home 2.0 (`tasks/evidence/home-2.0/prototipo-home.html`), a variável `aba` inicia em `"eventos"`: a tela do grill (topo tipográfico, mapa, agenda) é a aba EVENTOS, não o Início. Eu a implementei como Home e o Marco corrigiu. Ao portar protótipo com barra de abas, conferir qual aba o protótipo marca como ativa antes de mapear a tela pro destino; o apelido do documento ("Home 2.0") não define o slot na navegação.
- A agenda da tela de Eventos carrega TODOS os eventos cadastrados do horizonte operacional (planejamento, confirmado, em campo), não um recorte dos próximos 7. Recorte de "próximos" foi invenção minha por causa do layout do protótipo com 7 fixtures.

## 2026-08-01

- O botão preto com glifo de scan no dock do Event Pro é uma ação RFID, não um menu de atalhos. Ao tocar, deve abrir diretamente uma superfície de leitura `Identificar`, com estado do RFD40, contagem ao vivo e acionamento pelo gatilho físico ou controle na tela. A tela nova troca a embalagem, não o produto já construído: preservar o `ScanEngine`, o feed de EPCs, Limpar, Resolver, resultado e `Vincular` para tag desconhecida. `Etiquetar` nasce no Catálogo ou de uma tag desconhecida; `Conferir` nasce no contexto do Evento. Antes de inventar opções para hardware especializado, conferir a semântica do controle, o fluxo legado e o padrão do fabricante.
- Nas iterações visuais do Event Pro, apresentar sempre cinco opções dentro do mesmo protótipo, com seletor fixo e compacto que não encosta no iPhone. As opções precisam variar a relação da interface com o contexto, não apenas trocar forma, cor ou animação do mesmo componente.
- O círculo do leitor é uma assinatura não negociável e precisa continuar como componente principal. A rejeição era às cinco skins aleatórias do mesmo radar, não ao círculo. A diferenciação deve acontecer na semântica de scanner dentro e ao redor dele: varredura, tags únicas, taxa de aquisição, última leitura ou correspondência. Cada marca visual precisa representar dado real, nunca partícula decorativa. Antes da próxima iteração de scanner, pesquisar o fluxo equivalente em Zebra 123RFID, TSL RFID Explorer, Unitech TagAccess e Rentman.
- Com dezenas de tags, os nomes precisam continuar reconhecíveis sem transformar pontos pequenos em alvos. O círculo resume o estado ao vivo e o ledger cronológico preserva os nomes. Se houver uma lista completa sobreposta, novos equipamentos entram sem deslocar a linha sob o dedo.
- Nas evoluções de `Sweep` + `Última leitura`, não repetir a sessão no título, no contador superior e na faixa de status. O topo informa conexão do RFD40, o círculo informa o último equipamento e o botão do ledger informa a contagem. Cada dado aparece uma vez. Quando Marco pedir para manter uma opção e criar cinco modelos novos, preservar a baseline como sexta comparação, sem fingir que ela é um dos candidatos novos.
- Depois que Marco trava uma opção, o protótipo precisa abrir nela e as alternativas viram histórico. No Halo, o item atual pertence ao círculo e não se repete na lista curta; abaixo entram as cinco leituras anteriores. O ledger completo começa pelo item mais recente, destaca o atual e mantém o controle de recolher sempre visível.
- Apple-style não é adicionar cards arredondados e números grandes. Na lista RFID, simplicidade significa título curto, contagem inline, fonte do sistema, peso regular ou medium, uma superfície contínua e espaço como hierarquia. KPIs por categoria, pills e negrito repetido saem. Quando o scanner já está travado, novas opções variam apenas a abertura e o layout do ledger, sem redesenhar o Halo.
- Simplificar a lista RFID não autoriza remover informação operacional. Cada leitura precisa expor nome do item, área, código MMD e número da tag. O refinamento acontece na hierarquia: nome em medium, área e código em mono discreto, tag alinhada na margem e espaço no lugar de cards pesados. Na opção `Compact`, o half-sheet fecha somente pelo arrasto da pega; seta de recolher é ruído.
- Depois que a `Index Line` foi travada, as próximas alternativas do gatilho variam conteúdo, não voltam a trocar material ou forma. Motion de sheet precisa ser manipulação direta: abrir pelo arrasto para cima, fechar pela pega para baixo e atualizar a posição 1:1 enquanto o dedo se move nos dois sentidos. Se o usuário inverter o gesto antes de soltar, o sheet inverte junto, sem esperar a decisão final nem saltar para uma animação independente.
- A hierarquia travada do gatilho é `Live State`: estado e apoio à esquerda, glifo do ledger antes do contador e número sozinho na margem direita. Se `Leitura ativa` e `RFID em andamento` já dão contexto, acrescentar `itens` ao `36` é redundância. O número usa peso leve, não bold. No motion, o sheet mantém opacidade durante o deslocamento; profundidade entra pelo backdrop proporcional ao progresso, sem dissolver o objeto que está preso ao dedo.
- Quando a linha precisa comunicar `toque para abrir`, explorar affordance sem desmontar a hierarquia travada. A variação útil está em quatro alavancas: posição do contador, posição do glifo, nome explícito da ação e existência de uma zona tátil local. `Ledger Key` é a candidata mais sólida desta rodada porque o endcap reúne glifo e `36` como uma tecla, mas preserva a superfície plana da Index Line.
- Quando o chevron já comunica que a lista sobe, `Leitura ativa`, `RFID em andamento` e a nota do gatilho físico viram ruído. O controle pode ficar reduzido a direção, glifo de lista e contagem. A sombra precisa explicar a camada e a possibilidade de toque: projeção em dois níveis, highlight superior e compressão no press, sem virar card decorativo.
- Depois de travar o `Floating Index`, retirar o contador exige recompor a tecla, não apenas esconder o `36`. Chevron e glifo ocupam duas zonas de 32 pt dentro de uma peça de 88 × 58 pt. A quantidade realocada deve pertencer a uma estrutura existente, como Halo ou ledger, e aparecer uma vez só.
- A posição final do contador é o cabeçalho do ledger curto: `Leituras anteriores` à esquerda e `36 lidos` à direita. O Halo continua dedicado ao equipamento atual e a tecla `Floating Index` continua dedicada a abrir a lista.
- Abertura de sheet no canto inferior reduz descoberta e alcance. Depois de travar o contador no `Ledger Header`, o gatilho deve ocupar o centro da base e funcionar como indicação de manipulação direta: desenho mínimo, hit area de pelo menos 44 pt e nenhum texto, contador ou ícone de lista competindo com o gesto.
- Em template HTML longo, uma tag de fechamento extra pode tirar o dock do ancestral que carrega a variante visual sem quebrar o parse. O sintoma foi `.v9a .actionReader` não casar, `scanSlot` continuar em `display: contents` e o botão RFID virar uma pílula vertical. Validar hierarquia real com `closest()` e bounding boxes, não só classes no source.
- Fechar o scanner com o ledger aberto precisa limpar estado e classe visual juntos. `readerListOpen = false` sem remover `list-open`, `drawer-interacting` e estilos inline deixa o sheet vivo durante a animação de saída. A pega do sheet também aceita duplo clique como atalho de colapso, além do arrasto 1:1.
- Duplo clique em uma pega que também inicia drag dispara dois ciclos `pointerdown`/`pointerup` antes de `dblclick`. Cada `pointerup` não pode deixar um timer de settle independente. Um único `settleTimer` cancelável evita que um callback antigo limpe `transform` durante a animação nova. Validar com amostras de deslocamento: a sequência precisa ser monotônica até sair da tela.

## 2026-08-02

- Evoluir uma referência visual não é recombinar componentes existentes do sistema. No perfil do equipamento, misturar retrato, dial de condição, timeline longa, tabela técnica, notas e CTA produziu um Frankenstein apesar de cada peça isolada estar correta. Quando uma direção é travada, como `Ink Specimen`, as cinco opções seguintes precisam compartilhar uma única gramática e variar composição, ritmo e hierarquia. Para perfil mobile minimalista, a viewport é orçamento fixo: uma superfície dominante, identidade, estado e percurso curto, com `scrollHeight === clientHeight` validado em todas as opções.
- Quando Marco pede variações usando um componente aprovado como base, esclarecer pelo escopo visual já indicado: o componente travado fica pixel a pixel idêntico e a variação acontece apenas no entorno pedido. No `Ink Monolith`, variar tipografia, objeto ou anéis dentro da prancha violou a trava. A validação correta compara coordenadas internas relativas ao card nas cinco opções, não apenas aparência geral.
- `Últimas movimentações` em um perfil compacto não deve cair automaticamente em timeline com trilho e bolinhas. Para três registros, hierarquia tipográfica e composição espacial comunicam melhor: último movimento dominante, ledger de linhas, colunas de data, cadeia de estados ou último mais anteriores. O componente precisa preservar data, estado e local sem truncar, caber no campo fixo e continuar legível em um segundo.
- Em uma pega que combina drag e duplo toque, `pointerup` e o fallback `mouseup` podem chamar o mesmo `release` para um único toque. O segundo ciclo zerava a janela de detecção e tornava o fechamento intermitente. `release` precisa sair cedo quando o drag já terminou, e o segundo toque deve ser reconhecido pelo próprio estado do gesto, sem depender apenas de `dblclick`.
- Quando a opção visual muda de família de classe, como `handle1` para `mono1`, regras de motion também precisam migrar. Se só o componente visível acompanha a renomeação, o scanner cai silenciosamente no fallback de `clip-path`: ao fechar, a folha vira um segundo círculo ao lado do botão RFID. Validar o seletor ativo e capturar quadros intermediários da transição, não apenas o estado final.
- Em lista com TAG alinhada à direita, `scrollbar-gutter: stable` sozinho não garante separação visual. O thumb nativo ainda ocupa a mesma faixa perceptiva dos números. Validar durante o scroll ativo e tratar trilho e TAG como colunas independentes: borda externa, gutter reservado, margem oposta ou indicador próprio.
