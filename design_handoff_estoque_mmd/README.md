# Handoff · Estoque Inteligente MMD

> **Sistema de gestão de estoque para locadoras de equipamento de show, com RFID como núcleo operacional.**
> Cliente: MMD Audio. Integra com Rentman (ERP de locação) via API como fonte-de-verdade de projetos e bookings; o app assume a camada física (o que foi escaneado, embalado, devolvido, em qual condição).

---

## 1. Sobre estes arquivos

Os arquivos deste pacote são **referências de design criadas em HTML** — protótipos que mostram a aparência e o comportamento pretendidos, **não código de produção pra copiar direto**.

A tarefa do dev é **recriar estes designs no codebase do projeto**, usando os padrões e bibliotecas do ambiente alvo:

- **Web** (dashboard, catálogo, calendário, fichas de item): React + Tailwind, ou framework equivalente. O vocabulário visual é "liquid glass 2030" — CSS moderno (oklch, backdrop-filter, color-mix) é parte do design, não detalhe.
- **Mobile** (scan RFID, check-out, packing, vinculação): **SwiftUI no iOS**. A hero interaction (partículas que aparecem quando uma tag é lida) só vai brilhar com animação nativa — não tente portar isso do HTML.

Se ainda não há codebase, a recomendação é:
- **Frontend web**: Next.js (App Router) + Tailwind + shadcn/ui + Framer Motion
- **Mobile**: SwiftUI (iOS-only no MVP — Android fica pra fase 2)
- **Backend**: o que já existe no Rentman + uma camada fininha (Supabase/PostgREST ou Node/Hono) pra guardar o que é específico do app (leituras RFID, fotos de condição, packing history)

## 2. Fidelidade

**Alta fidelidade (hifi).** Cores, tipografia, espaçamentos, border-radius, sombras e transições estão todos definidos nos tokens e devem ser respeitados pixel-a-pixel. Onde há componente do shadcn/ui equivalente, usar o do shadcn — mas estilizado com os tokens daqui (NÃO com o default indigo/slate do shadcn).

Os conteúdos textuais (copy, dados fictícios de projetos, seriais, modelos de equipamento) são **ilustrativos** — serão substituídos por dados reais do Rentman e pelo catálogo da MMD. Mas a **estrutura informacional** de cada tela é proposital e deve ser seguida.

---

## 3. Contexto do produto (ler antes de codar)

### O problema
A MMD loca equipamento de áudio, luz e vídeo para shows e eventos. Hoje a gestão do estoque é **planilha + Rentman + memória do galpão**. Quando um projeto volta, itens somem, vão pra manutenção sem registro, ou são alocados pra dois eventos no mesmo fim de semana. Rentman sabe o que foi vendido; não sabe o que voltou.

### A solução
Cada item físico ganha uma **tag RFID UHF** colada. Quatro pontos de verdade:

1. **Saída (check-out)** — leitor de portal confere que o que sai bate com a packing list do Rentman
2. **Retorno (check-in)** — mesmo leitor, operador marca condição (OK, sujo, precisa reparo, faltando)
3. **Inventário contínuo** — operador com leitor handheld varre o galpão e localiza
4. **Alocação** — dashboard mostra disponibilidade real (livre vs. em evento vs. em reparo) alinhada com o calendário do Rentman

### Princípios de design
- **Dark-first.** Operadores ficam no galpão ou backstage — telas claras queimam retina. Light mode existe como acessibilidade.
- **Liquid glass.** Superfícies vítreas com *caustics* iridescentes (orbs ciano/violeta desfocados sob as superfícies). Marca o produto como "moderno mas respeitando o ofício" — nada de skeuomorfismo de estúdio.
- **Ring de prontidão** é o motivo central: um arco que enche conforme o item/projeto/envio está pronto. Aparece em tamanhos de 48px a 200px em toda a interface.
- **RFID é o herói.** A tela de scan usa partículas que viajam das tags até a lista — gamifica o que senão seria trabalho chato.

---

## 4. Telas (15 no total · 5 core × 3 variações cada + suportes)

> Cada core screen tem 3 variações na **galeria explorativa** (`galeria-explorativa.html`). O dev deve consolidar com a variação marcada ★ abaixo — é a preferida pra MVP, as outras são alternativas registradas.

### Telas core

| # | Tela | Plataforma | Variação ★ | Arquivo do protótipo |
|---|------|------------|------------|----------------------|
| 1 | **Dashboard** | Web | Painel clássico (A) | `components/screen-dashboard.jsx` |
| 2 | **Projetos & Packing** | Web | Split view (A) | `components/screen-projects.jsx` |
| 3 | **Item & Condição** | Web | Detalhe + timeline (A) | `components/screen-item-detail.jsx` |
| 4 | **RFID scan** (hero) | iOS | Partículas ao vivo (A) | `components/screen-rfid-scan.jsx` |
| 5 | **Check-out validação** | iOS | Lista (A) | `components/screen-checkout.jsx` |

### Telas de suporte

| # | Tela | Plataforma | Quando aparece |
|---|------|------------|----------------|
| 6 | **Catálogo mestre** | Web | Gestão de produtos, quantidades, foto, serial range |
| 7 | **Calendário de disponibilidade** | Web | Timeline de 21 dias · conflitos destacados |
| 8 | **Resolver conflito** | Web | Modal/tela quando projeto pede item que não tem — 4 alternativas (modelo alt, deslocar data, split, sub-locação) |
| 9 | **QR print sheet** | Web | Imprime folhas A4 com QR codes pra colar em equipamento (fallback quando RFID não funciona) |
| 10 | **Vinculação tag ↔ serial** | iOS | Primeira vez que um item ganha tag — operador escaneia tag e serial |
| 11 | **Item perdido / busca** | iOS | Modo "quente-frio" pra encontrar item sumido com handheld |
| 12 | **Onboarding primeiro scan** | iOS | Tutorial 3-telas na primeira vez que usa o app |
| 13 | **Modo empacotamento** | iOS | Packing list ao vivo, com check conforme embala |

Todos navegáveis em `prototipo-clicavel.html`.

---

## 5. Design tokens

Fonte-de-verdade: **`tokens/mmd-tokens.json`** (DTCG format) e **`tokens/mmd-tokens.css`** (variáveis CSS já prontas pra importar).

### Paleta (oklch — NÃO converter pra hex sem testar)

```
--bg-0:     oklch(0.12 0.015 250)   /* app background */
--bg-1:     oklch(0.16 0.018 250)   /* raised panels */
--bg-2:     oklch(0.20 0.02 250)    /* popovers */

--fg-0:     oklch(0.98 0.005 250)   /* high contrast */
--fg-1:     oklch(0.85 0.008 250)   /* body */
--fg-2:     oklch(0.65 0.01 250)    /* labels */
--fg-3:     oklch(0.48 0.012 250)   /* disabled */

--accent-cyan:   oklch(0.75 0.14 210)   /* ações primárias */
--accent-violet: oklch(0.70 0.17 295)   /* hero, RFID */
--accent-amber:  oklch(0.80 0.15 75)    /* warning, parcial */
--accent-green:  oklch(0.80 0.17 150)   /* sucesso, pronto */
--accent-red:    oklch(0.70 0.18 25)    /* erro, faltando */
```

### Superfícies vítreas

```css
.glass {
  background: rgba(255,255,255,0.05);
  border: 1px solid rgba(255,255,255,0.10);
  backdrop-filter: blur(24px) saturate(180%);
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.18),   /* highlight top */
    0 2px 6px rgba(0,0,0,0.25),
    0 20px 60px rgba(0,0,0,0.35);
}
```
O highlight inset e os dois box-shadows empilhados são o que vende a "vidraria". Não cortar nada.

### Caustics
Dois orbs desfocados (cyan top-left, violeta bottom-right), blur 60px, opacity 0.55. São **decorativos, não interativos**. Vão atrás de todo glass.

Ver `styles/glass.css` pra implementação completa.

### Tipografia

- **Inter Tight** (UI, headings, body) — via Google Fonts, pesos 400/500/600
- **JetBrains Mono** (seriais, timestamps, IDs, mono-labels uppercase) — via Google Fonts, peso 400/500

Escala:

| Role | Size | Line | Weight | Tracking |
|------|------|------|--------|----------|
| display | 42 | 1.1 | 500 | -1.0 |
| title | 28 | 1.15 | 500 | -0.6 |
| h2 | 22 | 1.2 | 500 | -0.3 |
| h3 | 17 | 1.3 | 500 | -0.1 |
| body | 14 | 1.5 | 400 | 0 |
| small | 12 | 1.4 | 400 | 0 |
| mono-label | 10 | 1.3 | 500 | 1.2 | uppercase |

### Radii · Spacing · Motion
Ver `tokens/mmd-tokens.json` — todos os valores estão lá com descrição.

### Ring de prontidão
Componente reutilizável. Props: `value` (0–100), `size` (sm 48 / md 72 / lg 120 / xl 200), `state` (missing / partial / ready). Gradiente de stroke varia conforme state. Texto central mostra "%" em mono.

Exemplo no protótipo: `components/primitives.jsx` → componente `Ring`.

---

## 6. Interações & animações

- **Transições default**: 240ms cubic-bezier(0.4, 0, 0.2, 1)
- **Hero (RFID scan)**: partículas individuais por tag, cada uma com delay stagger de ~30ms, curva ease-out de 420ms
- **Hover em cards**: elevação de sombra + 1px lift (`transform: translateY(-1px)`)
- **Focus ring**: 2px outline cyan com offset 2px
- **Listas grandes** (catálogo, check-out): virtualizar a partir de ~50 itens

### Micro-comportamentos críticos

1. **Scan RFID continuous mode**: leitor envia tags a ~200ms. UI agrupa por intervalo de 100ms pra não piscar. Cada tag nova anima in; tags já vistas só atualizam RSSI (indicador de proximidade).
2. **Packing list**: quando 100% dos itens da PL saem OK, card dispara animação de sucesso (verde + ring completa) + vibração háptica no mobile.
3. **Condição no check-in**: foto obrigatória quando operador marca "dano". Upload é assíncrono — UI não bloqueia.
4. **Conflitos**: quando editor de projeto detecta falta, banner sobe (não modal bloqueante) com CTA "ver alternativas" que leva pra tela de resolução.

---

## 7. Estado & dados

### Entidades principais

```
Produto          (catálogo — "Par LED 18x10W", tem N unidades)
  └─ Item        (unidade física — serial, tag RFID, condição, histórico)
       └─ Leitura (log de scan: timestamp, local, operador)

Projeto          (vem do Rentman — cliente, datas, local)
  └─ PackingList (lista de Produtos+qty pedidos)
       └─ Alocação (Items específicos designados pra esse projeto)

Conflito         (derivado — quando PackingList.pedido > Alocação.disponível)
```

### Sincronização Rentman
- Projetos + packing lists são **read-only vindos do Rentman** (pull a cada 5min + webhook no create/update)
- Alocações (qual item físico foi pra qual projeto) são **do app** — Rentman só sabe "foram 20 par LEDs", o app sabe quais 20
- Condição, histórico de reparos, fotos: **do app**

### Auth
- Operadores: login simples (email/senha) + biometria no mobile
- Admin: mesma auth, role diferente
- Não há multi-tenant no MVP — só MMD

---

## 8. Arquivos deste pacote

```
design_handoff_estoque_mmd/
├── README.md                          ← você está aqui
├── screenshots/                       ← PNGs de cada tela (veja rápido, sem rodar)
│   ├── 00-design-tokens.png
│   ├── 01-onboarding.png  …  13-resolver-conflito.png
├── prototipo-clicavel.html            ← navegue por aqui primeiro (15 telas linkadas)
├── galeria-explorativa.html           ← mostra 3 variações por tela core (decisões de design)
├── design-tokens-visual.html          ← tokens renderizados visualmente
├── tokens/
│   ├── mmd-tokens.json                ← ⭐ fonte-de-verdade (DTCG)
│   └── mmd-tokens.css                 ← variáveis CSS prontas
├── styles/
│   └── glass.css                      ← superfície vítrea, caustics, rings
├── frames/
│   ├── ios-frame.jsx                  ← bezel iPhone (referência — substituir por device real)
│   └── browser-window.jsx             ← chrome web (não portar)
└── components/
    ├── primitives.jsx                 ← Ring, Glass, Pill, Badge, Btn — PORTAR TODOS
    ├── screen-dashboard.jsx
    ├── screen-projects.jsx
    ├── screen-item-detail.jsx
    ├── screen-rfid-scan.jsx           ← hero — atenção especial
    ├── screen-checkout.jsx
    ├── screen-checkout-combined.jsx   ← variação alternativa
    ├── support-screens.jsx            ← QR print, vinculação, busca, onboarding, packing
    ├── catalog-calendar.jsx           ← catálogo mestre + calendário
    └── conflict-resolver.jsx          ← tela de resolução de conflito
```

---

## 9. Ordem sugerida de implementação

1. **Tokens + primitives** (Ring, Glass, Pill, Badge, Btn) — sem isso nada bate
2. **Dashboard web** — valida que stack + tokens ficaram certos
3. **Catálogo + item detail web** — CRUD básico, testa Rentman sync
4. **iOS shell + auth + RFID scan** — destrava o fluxo operacional
5. **Check-out + check-in iOS** — fluxo crítico do galpão
6. **Projetos + packing list web** — fecha o loop com Rentman
7. **Calendário + conflitos** — polish de gestão
8. **QR print, onboarding, busca, vinculação** — suportes

---

## 10. Abertas / decisões pendentes

- [ ] **Leitor RFID**: modelo final ainda não fechado. Protótipo assume SDK que retorna `{tagId, rssi, timestamp}` por callback. Se o SDK escolhido for diferente, a tela de scan precisa adaptador.
- [ ] **Offline mode no mobile**: MVP assume online. Se galpão tem Wi-Fi ruim, vai precisar fila local + sync — fase 2.
- [ ] **Android**: fora do escopo MVP. Se entrar, SwiftUI vira React Native? Decidir antes de começar.
- [ ] **Multi-galpão**: MMD só tem um hoje. Arquitetura não bloqueia N galpões, mas UI não mostra seletor.

---

## 11. Contato

Dúvidas de design durante a implementação: voltar pro projeto original no Claude e perguntar. Mantenha este README como index — ele é suficiente pra implementação, os HTML são referências visuais.
