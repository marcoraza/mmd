# Lessons

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
