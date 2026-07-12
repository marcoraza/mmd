# Handoff: montar a apresentação do motor MMD no Excalidraw

Para o agente que vai escrever direto no Excalidraw. Este documento traz tudo o que você precisa escrever (copy pronta) e como estruturar cada diagrama. Não invente número nem capacidade: tudo que é fato está aqui e em `inventario-motor.md`.

## 1. Missão

Montar um projeto Excalidraw que explica, para o Marcelo (dono da MMD Eventos, locadora de equipamento de AV, não técnico), como o sistema de estoque inteligente funciona por dentro. Material para uma reunião presencial conduzida pelo Marco. O sócio precisa ENTENDER, não se impressionar.

Entregável: um arquivo `.excalidraw` (formato nativo, editável em excalidraw.com) com vários diagramas num canvas só, empilhados verticalmente, cada um com título numerado e uma explicação curta ao lado ou abaixo.

## 2. Como produzir (duas vias, escolha uma)

- Via recomendada (DRY): estenda o gerador `gen-excalidraw.py` que já existe nesta pasta. Ele já produz os 3 primeiros diagramas e tem helpers `box`, `arrow`, `note`, `title` que cuidam do JSON completo e dos labels ligados ao container. Adicione os blocos novos com um `yOffset` crescente (cada diagrama 700 a 900px abaixo do anterior) e rode `python3 gen-excalidraw.py`. Saída: `motor-mmd.excalidraw`.
- Via alternativa: o MCP Excalidraw (`create_view`). Chame `read_me` uma vez antes de desenhar. Bom para iterar visual no chat, mas não gera o arquivo nativo sozinho. Se usar, ainda assim consolide tudo no `.excalidraw` no fim.

## 3. Regras de conteúdo (duras)

- Português do Brasil, acentuação completa e correta. Acentos renderizam bem na fonte do Excalidraw (Excalifont, fontFamily 1).
- Linguagem de dono de empresa, não de engenheiro. Traduza todo termo técnico. Pode citar o nome técnico entre parênteses como referência (ex: "Catálogo de tipos (items)"), nunca como título principal.
- Explicação item a item, sem frase de efeito, sem slogan. Cada conceito merece um "o que é" e um "como funciona".
- Números só os reais (seção 5). Zero número inventado.
- Honestidade no RFID: software pronto para a prova de campo, ainda não validado em campo. Não pinte como funcionando ao vivo.
- Proibido em-dash. Use vírgula, dois-pontos, parênteses. Sem reticências dramáticas, sem ponto-e-vírgula em prosa.

## 4. Convenções visuais (Excalidraw)

- Estilo: claro (fundo branco, cara de quadro branco), desenho à mão. Sem dark mode, salvo pedido.
- Paleta consistente, cada cor com um significado fixo no projeto inteiro:

| Cor | Preenchimento / Borda | Significa |
|---|---|---|
| Azul | `#a5d8ff` / `#4a9eed` | aplicativos, unidades, entradas |
| Roxo | `#d0bfff` / `#8b5cf6` | motor, processamento, eventos |
| Teal | `#c3fae8` / `#06b6d4` | banco de dados, catálogo, storage |
| Amarelo | `#fff3bf` / `#f59e0b` | decisão, notas, listas |
| Laranja | `#ffd8a8` / `#f59e0b` | histórico, pendente, externo |
| Verde | `#b2f2bb` / `#22c55e` | pronto, sucesso, tag conhecida |
| Vermelho | `#ffc9c9` / `#ef4444` | erro, falta, crítico |
| Cinza texto | `#757575` | notas e descrições (nunca mais claro que isto no branco) |

- Fontes: título do diagrama 28 a 30, label de caixa 16 a 18, nota 14 a 16. Nunca abaixo de 14.
- Caixas: mínimo 120x60. Deixe 20 a 30px de respiro entre elementos.
- Setas: sempre com verbo curto no label quando a relação não é óbvia ("usam", "tem várias", "entra em", "gera", "monta").
- Layout do canvas: um diagrama por bloco vertical. Comece cada bloco com um título numerado. Mantenha cada diagrama dentro de ~900px de largura para ler bem.
- Use a câmera (se via `create_view`) para guiar o olhar: zoom no título, depois abre para o diagrama inteiro.

## 5. Fatos (fonte de verdade, do banco ao vivo em 23/06/2026)

Tabelas e contagem de hoje:
- Catálogo de tipos (items): 539
- Unidades físicas (serial_numbers): 1058
- Eventos (projetos): 11
- Listas de separação (packing_list): 65
- Histórico (movimentacoes): 2
- Lotes, legado (lotes): 152
- Leitores RFID (rfid_readers): 0
- Leituras RFID (rfid_scans): 0
- Saídas forçadas (checkout_overrides): 0
- Pendências (retorno_pendencias): 0
- Modelos de packing (packing_templates): 0
- Usuários (profiles): 1

Catálogo por categoria: AUDIO 205, ILUMINAÇÃO 195, ACESSÓRIO 32, ESTRUTURA 26, EFEITO 23, CABO 20, ENERGIA 20, VÍDEO 18.

Unidades por situação: DISPONÍVEL 1049, EMPRESTADO 4, VENDIDO 3, BAIXA 2.

Eventos por status: CONFIRMADO 4, PLANEJAMENTO 3, FINALIZADO 2, EM CAMPO 1, CANCELADO 1.

Etiquetagem: 539 de 539 tipos com código interno (100%). 530 de 1058 unidades com QR Code. 0 unidades com tag RFID.

Condição e valor: Estado tem fator (NOVO 1,00, SEMI-NOVO 0,85, USADO 0,65, RECONDICIONADO 0,50). Desgaste de 1 a 5. Valor atual = valor original x (desgaste / 5) x fator do estado. Exemplo: refletor de R$1.000, USADO, desgaste 4: 1000 x 0,8 x 0,65 = R$520.

As operações do motor (RPCs): checkout_projeto, checkout_projeto_com_override, checkin_projeto, resolver_retorno_pendencia, current_user_role, item_categoria_prefix.

Papéis: viewer (consulta), editor (opera o dia a dia), admin (força saída, resolve pendência, apaga).

RFID hoje: software integrado de ponta a ponta (RFD40, iPhone, sistema, histórico), com tratamento de tag conhecida e desconhecida. Falta a prova de campo. Plano de teste: bancada, depois galpão, depois fluxo real pequeno, com 10 a 20 equipamentos. Precisa de: RFD40, iPhone, acesso ao app, tags RFID reais, equipamentos separados.

## 6. Catálogo de estruturas (escolha a geometria pelo conteúdo)

- Camadas (caixas largas empilhadas, setas verticais com verbo): para mostrar partes de um sistema, uma sobre a outra.
- Fluxo linear (caixas em linha, setas horizontais): para um processo em ordem, etapa por etapa.
- Relacional, estilo ER (caixas ligadas por setas com cardinalidade): para dados que se conversam, use labels como "tem várias", "entra em".
- Fan-out (um nó, várias saídas): para "uma coisa gera várias opções ou peças". Não use para sequência.
- Fan-in (várias entradas, um resultado): para uma conta ou junção. Mantenha 2 níveis, não vire escada.
- Decisão / branch (losango ou dois ramos coloridos verde e amber): para "se passou, libera; se não, trava".
- Três colunas por etapa (você faz / o motor faz / no banco): para mostrar responsabilidade em cada passo de um fluxo.
- Comparação lado a lado (dois cards): para tipo vs unidade, ou pronto vs falta.
- Conta com exemplo (entradas, fórmula, resultado destacado): para cálculo, sempre com um número real de exemplo.
- Grade de cards (matriz): para listar muitos itens homogêneos, como as tabelas do banco.

Regra de proporção: diagrama bom é largo e baixo. Evite escada vertical gigante. Se precisar de entrada, comparação e saída ao mesmo tempo, quebre em dois diagramas.

## 7. Os diagramas (copy pronta e estrutura)

Os diagramas 1, 2 e 3 já estão no `gen-excalidraw.py` e no arquivo. Estão aqui para referência e ajuste fino. Os diagramas 4 a 7 são os que faltam montar. Os 8 a 10 são extras opcionais.

### Diagrama 1: As 3 partes do sistema  (FEITO)
- Estrutura: camadas.
- Objetivo: separar aplicativos, motor e banco.
- Caixas: "APLICATIVOS (web + iPhone)" azul, "MOTOR (as regras)" roxo, "BANCO DE DADOS (Supabase)" teal.
- Setas verticais: "usam", "guardam em".
- Notas ao lado: "as telas que a equipe usa", "decide o que pode e registra", "onde tudo fica guardado".

### Diagrama 2: O banco, tabelas que se conversam  (FEITO)
- Estrutura: relacional simplificado.
- Caixas: "Catálogo de tipos (539)" teal, "Unidades físicas (1058)" azul, "Eventos (11)" roxo, "Listas (65)" amarelo, "Histórico (2)" laranja.
- Setas: items "tem várias" unidades, unidades "entra em" listas, eventos "monta" listas, unidades "gera" histórico.
- Nota: "cada linha liga a unidade e o evento". Legenda: "número = quantos registros existem hoje".

### Diagrama 3: O loop, o caminho de um equipamento  (FEITO)
- Estrutura: fluxo linear de 5 etapas.
- Caixas em linha: Alocar, Check-out, Campo (laranja), Check-in, Resolver (roxo).
- Notas sob cada uma: "reserva as peças", "saída, tudo ou nada", "em uso no evento", "volta e confere", "o que não voltou".
- Subtítulo: "antes da saída, o motor confere a prontidão".

### Diagrama 4: O Supabase, tabela a tabela  (MONTAR)
- Estrutura: grade de cards (sugestão 3 colunas x 4 linhas, 12 cards).
- Objetivo: mostrar tudo que o banco guarda, o que cada tabela faz e quantos registros tem.
- Título: "O que o banco guarda, tabela por tabela".
- Cada card: nome amigável no topo (label, 16), abaixo uma nota curta (14) e o número de registros em destaque. Use teal para o núcleo, cinza claro ou laranja suave para as de apoio e as zeradas. Marque "Lotes" como legado.
- Copy de cada card (nome | o que guarda | número):
  - Catálogo de tipos (items) | cada modelo de equipamento: nome, marca, categoria, valor | 539
  - Unidades físicas (serial_numbers) | cada peça real: código, etiqueta, estado, desgaste | 1058
  - Eventos (projetos) | cada evento ou locação: cliente, datas, status | 11
  - Listas de separação (packing_list) | o que cada evento leva: item, quantidade, unidades | 65
  - Histórico (movimentacoes) | cada saída e retorno: autor, hora, método | 2
  - Lotes, legado (lotes) | cabos em bloco do modelo antigo, em descontinuação | 152
  - Leitores RFID (rfid_readers) | os leitores RFD40 registrados | 0
  - Leituras RFID (rfid_scans) | cada etiqueta lida em campo | 0
  - Saídas forçadas (checkout_overrides) | auditoria das saídas por exceção do admin | 0
  - Pendências (retorno_pendencias) | o que não voltou, esperando resolução | 0
  - Modelos de packing (packing_templates) | listas salvas para reusar | 0
  - Usuários (profiles) | quem acessa e com qual papel | 1
- Dica: agrupe visualmente o núcleo (catálogo, unidades, eventos, listas, histórico) separado das de apoio. Pode colocar uma linha divisória ou um rótulo "núcleo" e "apoio".

### Diagrama 5: O motor protege a operação  (MONTAR)
- Estrutura: decisão / branch, mais um bloco de "tudo ou nada".
- Objetivo: mostrar que o motor não deixa a operação dar errado.
- Título: "O motor protege a operação".
- Parte A, o porteiro de prontidão:
  - Caixa azul: "Pedido de saída".
  - Losango ou caixa amarela de decisão: "Prontidão OK? (evento confirmado, lista cheia, cobertura)".
  - Ramo sim, caixa verde: "Libera: peças viram 'em campo' e grava no histórico".
  - Ramo não, caixa amber: "Trava. O admin pode forçar com motivo, e isso vai pra auditoria".
- Parte B, tudo ou nada:
  - Caixa azul: "Saída de 30 peças".
  - Duas saídas: verde "ou todas saem" e vermelho "ou nada muda". Nota: "nunca pela metade".
- Dica: deixe o porteiro em cima e o tudo-ou-nada embaixo, cada um largo e baixo.

### Diagrama 6: Quanto cada peça vale hoje  (MONTAR)
- Estrutura: conta com exemplo (fan-in de 3 entradas para 1 fórmula, e um resultado).
- Objetivo: mostrar que o valor é automático, sem reavaliação manual.
- Título: "Quanto cada peça vale hoje".
- Três entradas (azul), lado a lado à esquerda:
  - "Valor original" | nota: "quanto custou"
  - "Desgaste (1 a 5)" | nota: "condição física, atualiza no retorno"
  - "Estado" | nota: "NOVO 1,00 / SEMI 0,85 / USADO 0,65 / RECOND 0,50"
- Caixa central roxa, a fórmula: "valor atual = valor original x (desgaste / 5) x fator do estado".
- Caixa de resultado, verde, à direita: "Exemplo: R$1.000, USADO, desgaste 4 -> 1000 x 0,8 x 0,65 = R$520".
- Dica: setas das 3 entradas convergindo para a fórmula, e da fórmula para o resultado. Mantenha 2 níveis.

### Diagrama 7: RFID, software pronto para a prova de campo  (MONTAR)
- Estrutura: fluxo linear de 4 nós, mais branch de 2, mais bloco de status e plano.
- Objetivo: mostrar o caminho da leitura e o estado honesto.
- Título: "RFID, software pronto para a prova de campo".
- Fluxo (azul, setas): "RFD40 lê a tag" -> "iPhone recebe" -> "Envia ao sistema" -> "Vira histórico".
- Branch abaixo:
  - Verde: "Tag já cadastrada: associa ao equipamento certo".
  - Amber: "Tag desconhecida: registra pra tratar depois, não descarta".
- Status, dois cards:
  - Verde: "Hoje: software pronto para a prova física".
  - Vermelho: "Ainda não: RFID validado em campo".
- Plano (fluxo linear de 3 passos): "Bancada" -> "Galpão" -> "Fluxo real pequeno".
- Nota: "Teste com 10 a 20 equipamentos. Precisa de: RFD40, iPhone, app, tags reais, equipamentos separados".

### Diagrama 8 (opcional): Tipo vs peça real
- Estrutura: comparação lado a lado.
- Dois cards: "Tipo, o modelo no catálogo (539)" azul e "Unidade física, a peça real (1058)" azul claro, com seta "1 tipo, várias unidades". Nota: a unidade tem código tipo MMD-ILU-0001.

### Diagrama 9 (opcional): Web e campo, o mesmo motor
- Estrutura: fan-in.
- Dois cards no topo: "Web, no escritório" e "iPhone, no galpão". Setas convergindo para uma caixa: "Mesmo motor, mesmo banco". Nota: "se um muda, a tela do outro atualiza sozinha".
- Sob cada card, uma lista curta do que faz (web: cadastra evento, monta lista, importa planilha, painel; iPhone: lê RFID e QR, check-out, conferência de retorno, resumo em campo).

### Diagrama 10 (opcional): O que está pronto e o que falta
- Estrutura: comparação lado a lado, duas colunas.
- Coluna verde "Pronto": banco completo e 100% catalogado; motor de ponta a ponta no banco e no web; porteiro, alocação justa, conferência, pendências; app de campo com RFID integrado; metade do parque com QR.
- Coluna amber "Por ativar": prova de campo do RFID e etiquetagem física; rodar o loop em volume; cadastro de usuários em uso real.

## 8. Ordem e narrativa

Do chão ao topo, na ordem dos blocos no canvas: 1 (as 3 partes) abre o mapa. 2 e 4 explicam o banco. 5 e 3 explicam o motor e o loop. 6 mostra o valor. 7 mostra o RFID. 8, 9, 10 reforçam e fecham. Cada bloco com título numerado e uma explicação curta em texto ao lado ou abaixo, no estilo "diagrama e explicação".

## 9. Definition of Done

- [ ] Todos os diagramas num único `.excalidraw`, empilhados, com título numerado.
- [ ] Toda copy bate com a seção 5. Zero número inventado.
- [ ] Linguagem de dono de empresa, item a item, sem slogan.
- [ ] RFID com o estado honesto (pronto para prova, não validado em campo).
- [ ] Paleta consistente com a tabela da seção 4, fontes nunca abaixo de 14.
- [ ] Acentuação correta, zero em-dash.
- [ ] Cada diagrama largo e baixo, legível a ~700 a 900px, sem escada vertical gigante.
- [ ] Abre limpo em excalidraw.com (peça ao Marco para confirmar, ou valide a estrutura do JSON).
