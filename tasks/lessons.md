# Lessons

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
