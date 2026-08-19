# GRAMATICA.md: números destilados da Home e Eventos

Medição feita por Playwright em 390x844, com `getComputedStyle` e `getBoundingClientRect`, em 2026-08-19.

| Qualidade | Ref de origem | Medida | Valor medido | Regra traduzida para C |
|---|---|---|---|---|
| título de identidade | Home aprovada | `font-size`, peso, tracking | 40px, 600, -2.2px, Inter Tight | nome do evento usa Inter Tight, 30-32px, peso 600-650; nenhum outro texto compete |
| corpo e metadado | Home + Eventos | tamanhos distintos | 9, 13, 14, 16 e 32/40px | no detalhe, máximo 5 tamanhos; UI 15-16px e metadado 12-13px |
| margem lateral | Eventos A2.2 | borda dos blocos no viewport | 39-42px no frame renderizado; desvio entre blocos 3.4px | bordas de título, menu e lista em no máximo duas colunas, com desvio <= 4px |
| superfície de ação | detalhe atual | altura, radius, linhas | 151px, radius 24px, 3 linhas de 49px | três ações em uma superfície única; linha 48-52px; radius 22-24px |
| lista operacional | detalhe atual | altura, radius, linhas | 348px, radius 24px, 7 linhas de 49px | sete zonas visíveis; linha 48-52px; lista não corta antes da dock |
| ritmo vertical | detalhe atual | distância entre blocos | 12-16px entre cabeçalho, ações e lista | gaps principais de 12 ou 16px; microgap de 4 ou 8px |
| barra inferior | Home aprovada | caixa, inset, aba ativa | 62px, radius 22px, inset 20px, aba 51px/radius 17px | usar exatamente a barra canônica; quatro abas; nenhum botão RFID separado |
| acento | Home + Eventos | cor ativa | `#4b6cff` | azul apenas para ação/estado ativo; sem novo matiz de destaque |
| neutros | Home + Eventos | texto e superfícies | `#202124`, `#747880`, `#e3e5e9`, `#fff`, `#1a1a1d` | limitar a tela a estes neutros e ao azul; estados adicionais usam tokens já existentes |
| motion | Home + Eventos | duração e propriedades | 120-160ms na barra | feedback abaixo de 300ms; somente `transform` e `opacity` |

O construtor usa estes números e a Identidade do `BAR.md`. Ele não recebe os PNGs das referências.
