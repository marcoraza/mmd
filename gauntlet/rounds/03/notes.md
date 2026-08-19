# Rodada 3: notas do construtor

Dois espaços, sempre nesta ordem: `computado` é o que o CSS declara e o `getComputedStyle` devolve; `renderizado` é o que o `getBoundingClientRect` devolve dentro do telefone do preview, que aplica zoom 0.849, e é o que aparece no PNG. A Rodada 2 travou o computado em 52px e perdeu o renderizado. Esta rodada mira o renderizado e deixa o computado ser a consequência.

## O que mudou

**1. Passo de linha de 52px para 58px computados.** As dez linhas operacionais, três ações e sete zonas, voltam a 49.24px renderizados. Esse é o número de onde a `GRAMATICA.md` tirou "3 linhas de 49px" e "7 linhas de 49px", porque as duas medidas de origem, 151px da superfície de ação e 348px da lista, só fecham no espaço renderizado. O seletor ganhou `body .dk .tileMenu .hubRow` porque a folha anterior fixa 52px com três classes e venceria um seletor mais curto; o `.hubRow` sozinho estava passando por empate, não por vitória.

**2. O vazio antes da dock some por aritmética, não por enchimento.** Nada foi movido nem adicionado. Dez linhas ganhando 6px computados cada devolvem 60px ao fluxo, e a folga entre o fim da lista e o topo da dock cai de 70.73px para 10.73px computados. A dock continua com `bottom: 22px` e 62px computados, e os gaps continuam 16px.

**3. `24/36` virou uma unidade técnica em mono.** O metadado nasce como `local · data · <b id="hdOk">24</b>/36 conferidas`, então o total mora num nó de texto solto e CSS sozinho não alcança. A função `unifyTechnicalCount()` envolve o par num `<span class="cntTec">` sem tocar no `#hdOk`: o `b` continua com o mesmo id, no mesmo lugar da árvore, e o `r55.js:495` segue escrevendo `hdOk.textContent`. A função é idempotente e roda também dentro do `MutationObserver` que já existia, porque o detalhe só é montado depois da cena. A tipografia é 12px, peso 500, tracking .01em, que é o mesmo passo de contagem que a Home já usa em `.gq`; nenhum tamanho ou token novo entra fora desse.

## Medidas

Alturas, `min-height` computada e `getBoundingClientRect` renderizado, 390x844:

| Linha | Computado | Renderizado |
|---|---|---|
| Continuar leitura | 58px | 49.24px |
| Ler QR code | 58px | 49.24px |
| Adicionar manualmente | 58px | 49.24px |
| Iluminação | 58px | 49.24px |
| Áudio | 58px | 49.24px |
| Cabo | 58px | 49.24px |
| Energia | 58px | 49.24px |
| Vídeo | 58px | 49.24px |
| Estrutura | 58px | 49.24px |
| Efeito | 58px | 49.24px |

O passo entre linhas é igual à altura da linha: topos das zonas em 331.34, 380.58, 429.83, 479.07, 528.31, 577.55 e 626.79px renderizados, delta constante de 49.24px.

| Distância | Rodada 2 | Rodada 3 |
|---|---|---|
| gap cabeçalho para menu | 16px computados / 13.58px renderizados | 16px / 13.58px |
| gap menu para lista | 16px / 13.58px | 16px / 13.58px |
| folga lista para dock | 70.73px / 60.05px | **10.73px / 9.11px** |
| altura das dez linhas | 52px / 44.15px | **58px / 49.24px** |

Colunas esquerdas de `.dkHd`, `.tileMenu` e `.r60List` todas em 38.79px renderizados, desvio 0, uma coluna só. Fim da última zona `Efeito` em 676.03px renderizados e topo da dock em 686.84px: a dock não cobre nada. A dock continua com 62px computados e 52.64px renderizados.

## `24/36` no DOM

```html
São Paulo Expo · 11 ago · <span class="cntTec"><b id="hdOk">24</b>/36</span> conferidas
```

`#hdOk` presente, `#hdOk` dentro de `.cntTec`, texto do conjunto `24/36`. Teste de vida: escrevi `31` em `hdOk.textContent` e o conjunto virou `31/36` mantendo a família e o tamanho; devolvi para `24` e voltou a `24/36`.

## Tipografia da linha de contagem

| Alvo | Família computada | Tamanho | Peso | Tracking |
|---|---|---|---|---|
| `.dkSub` | `-apple-system, system-ui, SF Pro Text` | 13px | 400 | -0.078px |
| `.cntTec` | `JetBrains Mono, ui-monospace, SF Mono, Menlo` | 12px | 500 | 0.12px, `tabular-nums` |
| `.cntTec #hdOk` | `JetBrains Mono` herdada | 12px | 500 | 0.12px, `tabular-nums` |

A família declarada não prova qual fonte desenhou, então medi o avanço real: `24/36` ocupa 36.75px sem o zoom, ou 0.61em por caractere, que é o avanço de 0.6em da JetBrains Mono mais o tracking. A mesma string em `-apple-system` 12px mede 27.94px. É mono de verdade, não fallback proporcional.

Resto da linha tipográfica intacto: `.dkNome` Inter Tight 32px/650, `.evtBack`, `.hubRow .n` e `.r60Row strong` em `-apple-system` 16px/400, `.r67v` 13px/500. Tamanhos vivos na tela: 12, 13, 16 e 32px, quatro de no máximo cinco.

## Varreduras

**Motion.** Percorri `transitionProperty`, `transitionDuration` e `animationName` de todo elemento de `.evtWrap` e `.dkDock`. Zero propriedade fora de `transform`/`opacity` com duração maior que zero, zero duração acima de 300ms, zero animação. O maior valor segue sendo a lente da dock em 260ms.

**Overflow.** `scrollWidth` 390 igual a `clientWidth` 390. Zero elemento folha com `scrollWidth` maior que `clientWidth`, então zero texto truncado.

**Estados.** Sete zonas. `Áudio` e `Energia` completas com o `svg.tk` de check; `Iluminação` 2, `Cabo` 2, `Vídeo` 4, `Estrutura` 3 e `Efeito` 1 pendentes com numeral. Nenhum estado depende só de cor. Dock com `Início, Eventos, Catálogo, Identificar`, `.dkRead` em `display: none` e `Eventos` ativa.

**Console.** Dois `pageerror` herdados dos iframes legados, `getComputedStyle` com parâmetro nulo e `getBoundingClientRect` de nulo, mais o 404 de `favicon.ico`. Rodei o mesmo script contra a cópia do arquivo em `git HEAD` e a saída é caractere por caractere a mesma. Nenhum erro novo.

## Navegação

Cada destino testado a partir de uma carga limpa, porque o overlay de uma referência aberta captura o clique seguinte, e isso é comportamento herdado idêntico ao da Rodada 2.

| Ação | Resultado |
|---|---|
| voltar | agenda de volta, `Eventos` continua ativa, sem tela legada |
| Início | `body.approved-home-open`, `homeReference` com `aria-hidden=false` |
| Eventos | detalhe preservado, `Eventos` ativa, nenhuma referência aberta |
| Catálogo | aba ativa vira `Catálogo` |
| Identificar | `body.rfid-open`, `rfidReference` com `aria-hidden=false` |

## Captura

`detalhe-evento-390-light.png` e `detalhe-evento-1440-light.png`, tema claro, `deviceScaleFactor` 2. Gate `--max-blank 0.80` em PASS: 0.093 no 1440 e 0.333 no 390.

## Ficou

O scroller passou de 818/818 para 829px de conteúdo em 818px de caixa, ou seja, 11px roláveis. Isso é o `padding-bottom: 106px` de guarda da dock passando um pouco do fim, não conteúdo escondido: a última zona termina 10.81px acima da dock com `scrollTop` em zero. Dá para zerar baixando a guarda para 95px, mas isso encosta o padding na dock por um valor que não medi em todas as cenas, então preferi não mexer numa linha da Rodada 2 que ninguém pediu.

Uma decisão de leitura que o crítico precisa saber: a faixa de 48-52px do critério S2 nasceu no espaço renderizado, e na Rodada 2 ela foi lida no espaço computado. Nos dois casos a Rodada 2 batia, por coincidência de 52 estar nas duas faixas. Aqui os números divergem de propósito, 58 computados e 49.24 renderizados, e é o renderizado que reproduz a referência. Se a medição for feita só no computado, esta rodada lê como 58 e parece fora da faixa. Deixo os dois na mesa em vez de escolher por conta própria.
