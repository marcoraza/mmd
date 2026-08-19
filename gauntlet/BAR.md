# BAR.md: detalhe do evento

Barra: **Home aprovada + Eventos A2.2, tema claro**

Refs usadas: `gauntlet/refs/home-aprovada-390-light.png` e `gauntlet/refs/eventos-a2-2-390-light.png`.

Artefato: `prototipo-eventpro-c-finalizacao.html?tab=eventos&scene=event-detail`, capturado em 390x844 e 1440x1000.

Dono do sistema acoplado: um único construtor por rodada, editando apenas a versão C.

## Identidade

- Tipografia: Inter Tight somente para nomes de evento e títulos de identidade; SF Pro Text/system para navegação, ações, listas e metadados; fonte mono somente em serial, hora, contagem técnica ou rótulo em caixa alta.
- Paleta: papel branco, tinta `#202124`, cinzas `#747880`/`#e3e5e9`, superfície escura `#1a1a1d` e acento `#4b6cff`. Sem gradiente roxo e sem novo matiz de destaque.
- Tom: instrumento operacional claro, silencioso e preciso. Nunca dashboard genérico, app bancário, painel gamer ou coleção de cards decorativos.
- Composição: hierarquia contínua, com cabeçalho, ações e zonas lidas como um único fluxo. A barra da Home é fixa e canônica.

## Veredito final

PICK CEGO: o crítico recebe melhor anterior e candidato como A/B embaralhados. O candidato só move a trava quando vence o pick e não transforma PASS anterior em FAIL.

## Critérios PASS/FAIL

| # | Critério | Como medir | PASS |
|---|---|---|---|
| K1 | Barra canônica | DOM em lista, detalhe e Catálogo | exatamente `Início, Eventos, Catálogo, Identificar`; `.dkRead` em `display:none`; zero rótulo `Mais` |
| K2 | Mesma língua da Home | famílias, radius, sombras e cores computadas | 100% dos valores vêm da Identidade ou da `GRAMATICA.md`; zero novo token solto |
| T1 | Título sob controle | `.dkNome` | Inter Tight, 30-32px, peso 600-650, título é o maior texto útil da tela |
| T2 | UI menos pesada | `.evtBack`, `.hubRow`, `.r60Row`, `.dkSub` | UI 14-16px em SF Pro Text/system, peso 400-600; metadado 12-13px; máximo 5 tamanhos na tela |
| S1 | Alinhamento único | bordas esquerdas de `.dkHd`, `.tileMenu`, `.r60List` | no máximo duas colunas; diferença máxima de 4px |
| S2 | Ritmo compacto | gaps entre cabeçalho, menu e lista; altura das linhas | gaps 12 ou 16px; linhas 48-52px; base de espaço 4px |
| L1 | Fluxo cabe no primeiro olhar | PNG 390x844 | título, três ações, sete zonas e barra inferior reconhecíveis; nenhum bloco cortado horizontalmente |
| L2 | Estados das zonas claros | PNG + DOM das sete `.r60Row` | completo usa check; pendente usa número; exatamente 7 zonas; nenhum estado depende apenas de cor |
| I1 | Ações operacionais | DOM e caixa de toque | 3 ações: continuar leitura, QR e manual; cada linha >= 44px; toda linha é alvo de clique |
| I2 | Volta e aba ativa | clique manual/Playwright | voltar retorna à agenda; Eventos continua ativa; sem flash de tela legada |
| R1 | Mobile íntegro | métricas do documento em 390x844 | `scrollWidth <= clientWidth`; nenhum texto truncado; dock não cobre a última zona |
| M1 | Motion com razão | CSS da versão C | zero transição >300ms e zero animação fora de `transform`/`opacity` |
| D1 | Não é clone externo | comparação de refs e código | composição própria; nenhuma família, cor ou padrão novo importado de produto externo |
| A1 | Sem slop | PNG e DOM | zero emoji, gradiente roxo, card triplicado decorativo ou ícone de template sem adaptação |

## Exclusões antes de medir

- Status bar e moldura preta do preview não entram na contagem tipográfica.
- Dados são fixos: LatBus, São Paulo Expo, 11 ago, 24/36 e sete zonas.
- Captura branca, cortada, com fonte fallback ou sem a dock canônica anula a rodada.
