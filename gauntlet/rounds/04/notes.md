# Rodada 4: notas do construtor

Rodada de fechamento. Um único gap, três declarações de CSS, nenhuma mudança de composição, densidade ou navegação. Todas as medidas da Rodada 3 foram remedidas, não herdadas.

## O que mudou

**A contagem ganha hierarquia interna sem ganhar tamanho.** A Rodada 3 unificou `24/36` em mono e, ao fazer isso, achatou o par: o `#hdOk` recebia `font-weight: 500` e `color: inherit`, então o realizado ficava com o mesmo peso e a mesma cor do total. A Rodada 4 desfaz só esse achatamento.

A regra copiada é a que a Home já usa e o crítico já aprovou:

```css
.gq   { font: 500 12px var(--mono); letter-spacing: .01em; color: var(--sub); }
.gq b { font-weight: 600; color: var(--ink); }
```

Em C isso vira:

```css
body .dk .dkSub .cntTec        { /* ...12px/500/.01em mono... */ color: #747880 !important; }
body .dk .dkSub .cntTec b,
body .dk .dkSub .cntTec b#hdOk { font-family: inherit; font-size: inherit;
                                 font-weight: 600; color: #202124; }
```

Três pontos de cuidado:

1. **Nenhum matiz novo.** `#747880` e `#202124` são os mesmos hex que a folha base do detalhe já aplica em `.dkSub` e `.dkSub b`, e são os mesmos neutros listados na Identidade. `var(--sub)` e `var(--ink)` não estão declarados no documento do r55, então o hex é o caminho literal, não um token novo.
2. **O total não precisou de elemento.** `/36` é um nó de texto solto dentro de `.cntTec` e herda cor e peso do span. Nada foi envolvido, nada foi inserido, `unifyTechnicalCount()` não mudou uma linha. Menos DOM que a Rodada 3, não mais.
3. **`font-size: inherit` entrou como trava.** A folha base tem regras para `.dkSub b`; fixar o tamanho no `b` garante que voltar o peso para 600 não reabre uma porta de tamanho.

## `24` e `/36` medidos separadamente

`/36` é um nó de texto, então foi medido com um `Range` sobre o nó, não com um seletor.

| Alvo | Família computada | Tamanho | Peso | Cor | Tracking |
|---|---|---|---|---|---|
| `.cntTec #hdOk` = `24` | `"JetBrains Mono", ui-monospace, "SF Mono", Menlo, monospace` | 12px | **600** | **`rgb(32, 33, 36)`** = `#202124` | 0.12px, `tabular-nums` |
| nó de texto `/36` | herda `.cntTec`: `"JetBrains Mono", ui-monospace, ...` | 12px | **500** | **`rgb(116, 120, 128)`** = `#747880` | 0.12px, `tabular-nums` |
| `.dkSub` em volta | `-apple-system, system-ui, "SF Pro Text"` | 13px | 400 | `rgb(116, 120, 128)` | -0.078px |

Duas separações provadas: peso 600 contra 500 e tinta contra cinza secundário. Tamanho, família e tracking continuam idênticos entre os dois, então a unidade não se parte em dois blocos.

**A grade mono aguentou o peso.** `24` mede 12.48px e `/36` mede 18.72px, ou 6.24px por caractere nos dois. Peso 600 e peso 500 têm o mesmo avanço, então nada reflui e o resto da frase não se move. A linha continua com uma caixa só: `.dkSub` devolve 1 `ClientRect`, 312.42 x 13.58px.

## Teste de vida do `#hdOk`

```
inicial   .dkSub.innerHTML = São Paulo Expo · 11 ago · <span class="cntTec"><b id="hdOk">24</b>/36</span> conferidas
escrevi   hdOk.textContent = "31"
depois    .cntTec = "31/36"; #hdOk peso 600, cor rgb(32,33,36), JetBrains Mono 12px; .dkSub em 1 linha
devolvi   hdOk.textContent = "24"
voltou    .cntTec = "24/36"; #hdOk peso 600, cor rgb(32,33,36); .dkSub em 1 linha
```

`#hdOk` presente por `getElementById`, dentro de `.cntTec`, no mesmo lugar da árvore. O `r55.js:495` continua escrevendo só o número e a tipografia acompanha sem reaplicar nada.

## As dez linhas, gaps e a dock

Nada aqui foi tocado. Remedido para provar que nada regrediu.

| Linha | `min-height` computada | `getBoundingClientRect` renderizado | Topo renderizado |
|---|---|---|---|
| Continuar leitura | 58px | 49.24px | 166.64 |
| Ler QR code | 58px | 49.24px | 215.88 |
| Adicionar manualmente | 58px | 49.24px | 265.12 |
| Iluminação | 58px | 49.24px | 331.34 |
| Áudio | 58px | 49.24px | 380.58 |
| Cabo | 58px | 49.24px | 429.83 |
| Energia | 58px | 49.24px | 479.07 |
| Vídeo | 58px | 49.24px | 528.31 |
| Estrutura | 58px | 49.24px | 577.55 |
| Efeito | 58px | 49.24px | 626.79 |

Delta constante de 49.24px entre topos de zona, igual à Rodada 3.

| Distância | Rodada 3 | Rodada 4 |
|---|---|---|
| gap cabeçalho para menu | 16px computados / 13.58px renderizados | 16px / 13.58px |
| gap menu para lista | 16px / 13.58px | 16px / 13.58px |
| folga última zona para dock | 10.73px / 9.11px | 10.81px renderizados |
| altura da dock | 62px / 52.64px | 62px / 52.64px |

Fim de `Efeito` em 676.03px renderizados, topo da dock em 686.84px. A dock não cobre a última zona. As três colunas esquerdas, `.dkHd`, `.tileMenu` e `.r60List`, todas em 38.79px renderizados, desvio 0.

## Varreduras

**Overflow, 390x844.** `scrollWidth` 390 igual a `clientWidth` 390. Zero elemento folha com `scrollWidth` maior que `clientWidth`, então zero texto truncado.

**Tipografia.** Tamanhos vivos na tela: 12, 13, 16 e 32px. Quatro de no máximo cinco. `.dkNome` continua Inter Tight 32px/650, tinta `#202124`. Volta, ação e zona continuam em `-apple-system` 16px/400. Mono continua só em `.cntTec`.

**Motion.** Propriedades com duração acima de zero em `.evtWrap` e `.dkDock`: `transform 120ms`, `transform 260ms`, `transform 160ms` e `opacity 160ms`. Zero animação nomeada, zero propriedade fora de `transform`/`opacity`, maior duração 260ms.

**Estados.** Sete zonas. `Áudio` e `Energia` com check; `Iluminação` 2, `Cabo` 2, `Vídeo` 4, `Estrutura` 3 e `Efeito` 1 com numeral. Dock com `Início, Eventos, Catálogo, Identificar`, `.dkRead` em `display: none`, `Eventos` ativa.

**Console.** Contexto de browser limpo por carga, e as duas versões rodaram em ordem alternada por causa de ruído de timing dos iframes legados. Depois de descontar o 404 de `favicon.ico`, a Rodada 4 devolveu os mesmos dois `pageerror` herdados nas duas passagens: `getComputedStyle` com parâmetro não-elemento e `getBoundingClientRect` de nulo. O melhor atual em `git HEAD` devolveu esses mesmos dois numa passagem e um terceiro herdado, `Cannot read properties of null (reading 'getComputedStyle')`, na outra. O erro extra apareceu no melhor atual, não no candidato. Nenhum erro novo entra com esta rodada.

## Navegação

Cada destino de uma carga limpa, porque o overlay de uma referência aberta captura o clique seguinte. Comportamento herdado, igual às Rodadas 2 e 3.

| Ação | Resultado |
|---|---|
| voltar | agenda de volta com 7 cartões de evento, `.evtWrap` fora, `Eventos` continua ativa, nenhuma referência aberta |
| Início | shell em `approved-home-open`, `homeReference` com `aria-hidden=false` |
| Eventos | detalhe preservado, `Eventos` ativa, nenhuma referência aberta |
| Catálogo | aba ativa vira `Catálogo` |
| Identificar | shell em `rfid-open`, `rfidReference` com `aria-hidden=false` |

## Captura

`detalhe-evento-390-light.png` e `detalhe-evento-1440-light.png`, tema claro, `deviceScaleFactor` 2, URL com `v=r04`. Gate `--max-blank 0.80` em PASS: 0.333 no 390 e 0.093 no 1440. Os dois números batem com a Rodada 3, o que era esperado: só a cor e o peso de dois glifos mudaram.

## Ficou

Um susto que vale registrar. A primeira versão do comentário deste bloco citava `.gq` entre crases. O CSS de C mora dentro de um template literal em JavaScript, então a crase fechou a string e a página inteira caiu com `Unexpected token '{'` e nenhum frame montado. Corrigido antes de qualquer medida, e o comentário agora avisa isso na própria folha. Nenhuma das medidas acima foi tirada da versão quebrada.

O scroller continua com 11px roláveis por causa do `padding-bottom: 106px` de guarda da dock, exatamente como na Rodada 3. Não é conteúdo escondido e não foi tocado: continua sendo uma linha da Rodada 2 que ninguém pediu para mexer.

A observação de leitura da Rodada 3 continua de pé. A faixa de 48-52px do critério S2 nasceu no espaço renderizado. Esta rodada mede 58px computados e 49.24px renderizados. Se a leitura for feita só no computado, S2 parece fora da faixa; no renderizado, que é o que aparece no PNG, ele está no meio dela.
