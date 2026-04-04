# Design Brief: MMD Estoque Inteligente

## Referencia Visual

Arquivo: `~/Desktop/analytics-dashboard.html`
Sistema: Nothing Design System (Swiss typography, industrial craft, monochromatic)
Dispositivos alvo: iPhone (campo) + MacBook (gestao)

---

## Design System

### Fontes (Google Fonts)

```html
<link href="https://fonts.googleapis.com/css2?family=Doto:wght@400;700&family=Space+Grotesk:wght@300;400;500;700&family=Space+Mono:wght@400;700&display=swap" rel="stylesheet">
```

| Papel | Fonte | Uso |
|-------|-------|-----|
| Display/Hero | Doto | Numeros grandes (valor patrimonio, contagem scan, KPIs) |
| Body/UI | Space Grotesk | Texto corrido, titulos de secao, nomes de itens |
| Data/Labels | Space Mono | Micro-labels ALL CAPS, badges, codigos MMD-XXX-NNNN, valores monetarios |

### Tokens de Cor

```
Dark Mode (sidebar, iOS dark):
  --black: #000000          (fundo OLED)
  --surface: #111111        (superficies elevadas)
  --surface-raised: #1A1A1A (cards, campos)
  --border: #222222         (divisores sutis)
  --border-visible: #333333 (bordas intencionais)
  --text-disabled: #666666  (desabilitado, decorativo)
  --text-secondary: #999999 (labels, metadata)
  --text-primary: #E8E8E8   (texto principal)
  --text-display: #FFFFFF   (hero, destaque)

Light Mode (painel direito, paginas web):
  --black: #F5F5F5          (fundo off-white)
  --surface: #FFFFFF        (cards)
  --surface-raised: #F0F0F0 (elevacao secundaria)
  --border: #E8E8E8         (divisores)
  --border-visible: #CCCCCC (bordas intencionais)
  --text-disabled: #999999
  --text-secondary: #666666
  --text-primary: #1A1A1A
  --text-display: #000000

Accent/Status (identicos em ambos os modos):
  --accent: #D71921         (vermelho, alerta, urgente)
  --success: #4A9E5C        (OK, disponivel, retorno OK)
  --warning: #D4A843        (atencao, em campo, pendente)
  --interactive: #5B9BF6    (links, elementos tappable)
```

### Mapeamento de Status para Cor

| Status | Cor | Contexto |
|--------|-----|----------|
| DISPONIVEL | --success (#4A9E5C) | Pronto pra sair |
| PACKED | --text-display | Preparado, aguardando saida |
| EM_CAMPO | --warning (#D4A843) | Em evento |
| RETORNANDO | --interactive (#5B9BF6) | Em transito de volta |
| MANUTENCAO | --accent (#D71921) | Requer atencao |
| EMPRESTADO | --text-secondary (#999) | Fora do inventario ativo |
| VENDIDO | --text-disabled (#666) | Terminal |
| BAIXA | --text-disabled (#666) | Terminal |

### Mapeamento de Desgaste para Visual

Barra segmentada de 5 blocos:

| Desgaste | Blocos preenchidos | Cor dos blocos |
|----------|-------------------|----------------|
| 5 (Excelente) | 5/5 | --success |
| 4 (Bom) | 4/5 | --success |
| 3 (Regular) | 3/5 | --text-display (neutro) |
| 2 (Desgastado) | 2/5 | --warning |
| 1 (Critico) | 1/5 | --accent |

### Tipografia Scale

| Token | Tamanho | Uso MMD |
|-------|---------|---------|
| display-xl | 72-88px | Hero: valor patrimonio, contagem de scan |
| display-lg | 48px | KPI secundario: total itens, disponíveis |
| display-md | 36px | Titulos de pagina |
| heading | 24px | Titulos de secao |
| subheading | 18px | Subtitulos |
| body | 16px | Nomes de item, descricoes |
| body-sm | 14px | Texto secundario |
| caption | 12px | Timestamps, notas |
| label | 9-11px | ALL CAPS: "INVENTARIO", "STATUS", "DESGASTE" |

### Espacamento

Base 8px. Tight (4-8px) entre label e valor. Medium (16px) entre items de lista. Wide (32-48px) entre secoes. Vast (64-96px) ao redor do hero.

### Componentes-Chave

**Segmented Progress Bars:** Blocos retangulares de 5px altura, 2px gap. Sem border-radius. Preenchido = cor de status. Vazio = --border.

**Circular Gauge (SVG):** Arco fino em volta de numero central. Usado pra: taxa depreciacao, progresso de scan, disponibilidade.

**Status Badge:** Space Mono, ALL CAPS, 9px, pill (border-radius 999px), border 1px. Cor = status color no texto e borda.

**Nav com indicador lateral:** Borda esquerda de 2px no item ativo. Sem background highlight, apenas borda + texto --text-display.

**Dot-grid background:** radial-gradient(circle, #333 0.5px, transparent 0.5px), background-size: 16px 16px, opacity: 0.6. Apenas no painel dark.

**Card-less layout:** Secoes separadas por 1px border, sem cards com sombra. Bordas sao a estrutura.

---

## Hierarquia de Informacao

### Principio: Three-Layer Rule

Cada tela tem exatamente 3 camadas de importancia visual.

| Camada | Tratamento | Exemplo |
|--------|------------|---------|
| Primaria | Doto 48-88px, --text-display | R$335.2K (patrimonio) |
| Secundaria | Space Grotesk 14-18px, --text-primary | Lista de items, KPIs |
| Terciaria | Space Mono 9-11px ALL CAPS, --text-secondary | Labels, timestamps, metadata |

### Por Tela

**Dashboard (Web Overview)**
- Primaria: Valor Atual do Patrimonio (R$335.2K em Doto 88px)
- Secundaria: Status breakdown (por categoria e status), KPIs (valor original, depreciacao, itens sem valor)
- Terciaria: Activity feed, chips de sistema, timestamps

**Inventario (Web Lista)**
- Primaria: Barra de busca (a acao principal) + contagem total
- Secundaria: Items com nome, categoria badge, status badge, quantidade
- Terciaria: Marca, modelo, valor unitario, codigo interno

**Inventario (Web Detalhe)**
- Primaria: Nome do item + categoria (display-md)
- Secundaria: Serial numbers com status, desgaste (barra segmentada), valor
- Terciaria: Historico de movimentacoes, metadata

**Projetos (Web Lista)**
- Primaria: Projetos ativos com status badge (display-md)
- Secundaria: Cliente, datas, progresso da packing list
- Terciaria: Local, notas, timestamps

**Packing List Editor (Web)**
- Primaria: Progresso "12/15 ITENS ALOCADOS" (display-lg)
- Secundaria: Lista split: disponiveis (esquerda) / alocados (direita)
- Terciaria: Quantidade por item, valor estimado

**iOS Scan**
- Primaria: Contagem de tags live (Doto 72px, atualiza em tempo real)
- Secundaria: Lista de tags resolvidas com nome e status
- Terciaria: Status do leitor, bateria, metodo (RFID/QR)

**iOS Checkout**
- Primaria: Progresso "8/12" (Doto 72px) com barra segmentada
- Secundaria: Packing list com cores verde/amarelo/vermelho por item
- Terciaria: Nome do projeto, timestamps

**iOS Retorno**
- Primaria: Resumo "15 voltaram, 2 defeito, 1 faltando" (numeros em Doto)
- Secundaria: Lista de items com status de retorno
- Terciaria: Campo de notas pra defeito, timestamp

---

## Layout

### Web: Split Layout

```
+---[380px dark]---+--------[flex light]---------+
|                  |                              |
| Brand: MMD·EST.  | Titulo: Visao Geral          |
| Hero: R$335.2K   | KPI row (3 cols)             |
| Trend            | Charts area (2 cols)         |
| Mini-widgets 2x2 | Activity + Top Categories    |
| Nav vertical     | Status chips                 |
|                  |                              |
+------------------+------------------------------+
```

- Dark sidebar: fixo, nao scrolla. Dot-grid background.
- Light content: scrollavel, secoes separadas por 1px border.
- Mobile (iPhone): sidebar vira bottom nav dark. Conteudo ocupa 100%.

### iOS: Full Dark

App iOS e 100% dark mode. Fundo --black (#000), texto --text-display.
Tab bar: 5 items (Scan, Projetos, Inventario, Atividade, Config).
Nav bar: transparente, titulo em Space Grotesk.

Scan view: fundo preto total. Numero de tags em Doto 72px centralizado. Lista de tags embaixo com scroll.

---

## Regras pra Agentes

1. **Fontes obrigatorias.** Space Grotesk + Space Mono + Doto. Nenhuma outra.
2. **Sem sombras.** Nenhuma box-shadow em lugar nenhum. Flat surfaces, border separation.
3. **Sem gradients.** Exceto o dot-grid (radial-gradient decorativo).
4. **Sem border-radius > 16px** em cards. Botoes podem ser pill (999px) ou tecnico (4-8px).
5. **Labels sempre Space Mono ALL CAPS** com letter-spacing 0.08-0.12em.
6. **Numeros sempre Space Mono** (ou Doto pra hero). Nunca Space Grotesk pra numeros.
7. **Cores de status no valor, nao no background.** O numero fica verde/vermelho, nao a row.
8. **Uma unica surpresa visual por tela.** Um numero enorme, uma gauge circular, uma barra segmentada. Nao tudo junto.
9. **iOS dark-first.** Todo o app iOS usa dark mode. Sem light mode no iOS.
10. **Web split layout.** Sidebar dark 380px + conteudo light. Mobile: bottom nav dark.
