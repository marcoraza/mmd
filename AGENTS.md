# MMD Eventos: Estoque Inteligente

## Projeto

Sistema de estoque inteligente para empresa de locação de equipamentos AV/eventos (MMD, Marcelo Santos). RFID + QR Code, tudo in-house, sem integrações externas. Supabase é a fonte de verdade única para catálogo, eventos, packing lists, alocações, movimentações, condição e auditoria.

- **Cliente:** Marcelo Santos (MMD Eventos)
- **Contrato:** R$3.000/mes, 3 meses
- **Foco:** 100% estoque inteligente
- **ClickUp:** PROJETOS > [MMD] MMD EVENTOS (folder 901317960993)
- **Design System:** Liquid Glass 2030 em `apps/web/src/components/mmd/Primitives.tsx`, `apps/web/src/app/globals.css` e `apps/web/public/handoff/`
- **Briefing MAR-171:** `docs/mar-171-agent-brief.md`
- **Referências visuais e evidências:** `tasks/evidence/mar-XXX/`

## Design

Sistema visual Liquid Glass 2030: superfícies vítreas, caustics iridescentes, ring de prontidão como motivo central, dark-first. Tokens em oklch, componentes em `apps/web/src/components/mmd/Primitives.tsx`.

Fontes: Inter Tight (UI, headings, body), JetBrains Mono (seriais, timestamps, labels).
Dispositivos: iPhone (campo, galpão) + MacBook (gestão, escritório).

Prints em `tasks/evidence/` são referência, imagegen ou screenshot de QA. Eles não são um front-end novo nem fonte de verdade para reconstrução.

## Stack

| Componente | Tecnologia |
|---|---|
| App iOS (campo) | Swift/SwiftUI + Zebra iOS RFID SDK |
| Web app (gestão) | Next.js 16 (App Router) + React 19 + Tailwind v4 + Primitives.tsx (Liquid Glass 2030) |
| API | Next.js API Routes |
| Banco | Supabase (Postgres + Auth + Realtime + Storage) |
| RFID | Zebra RFD40 via Bluetooth no iPhone |
| QR Code | qrcode lib (geração) + AVFoundation/Web API (leitura) |
| Deploy web | Vercel |
| Deploy iOS | TestFlight / ad-hoc |

## Estrutura do Projeto

```
mmd/
├── AGENTS.md              # Este arquivo
├── docs/
│   ├── mar-171-agent-brief.md # Fonte curta para agentes do PRD atual
│   ├── handoff.md             # Estado operacional do projeto
│   ├── adr/                   # Decisões arquiteturais e de produto
│   └── discovery/             # Pesquisa, proposta, comparativos antigos
├── data/
│   ├── inventario-original.xlsx  # Excel original do Marcelo
│   └── inventario-limpo.xlsx     # Planilha profissional gerada
├── scripts/               # Scripts de automacao (Python)
├── tasks/                 # Sprint tracking, lessons
├── apps/
│   ├── ios/               # App iOS (Swift/SwiftUI + Zebra SDK)
│   └── web/               # Web app (Next.js)
└── supabase/
    └── migrations/        # SQL migrations (00001_initial_schema.sql)
```

## Decisões Técnicas

- **Tudo in-house.** Sem integração com Rentman ou qualquer ERP externo. Supabase é a fonte de verdade única.
- **RFID é prioridade.** QR Code é complemento/fallback.
- **RFID roda no iPhone (iOS).** RFD40 conecta via Bluetooth. SDK iOS nativo.
- **Cabos unit-only.** Cabos deixam de ser fluxo operacional por lote e viram unidades rastreáveis individuais.
- **Lotes são legado.** Lotes não devem voltar como regra operacional futura.
- **Modelo de dados:** Item (tipo) + Serial Number (unidade física), espelhando vocabulário de locação AV.
- **Evento é a linguagem de produto.** Rotas internas ainda podem usar `projetos`, mas UI e docs de produto falam Evento.
- **Auth é gate de produção real.** Dados reais exigem Supabase Auth, perfis e auditoria antes de exposição pública.
- **QR público é mínimo.** Não expõe valor, serial de fábrica, RFID, localização ou histórico.
- **Mobile não cria regra paralela.** iOS consome a mesma fronteira operacional do web.

## Convenções

- Arquivos: kebab-case
- Branches: cc/sprint-N-slug
- Código interno: MMD-{CAT}-{0001} (ex: MMD-ILU-0001)
- Prefixos: ILU, AUD, CAB, ENE, EST, EFE, VID, ACE
- Categorias: ILUMINACAO, AUDIO, CABO, ENERGIA, ESTRUTURA, EFEITO, VIDEO, ACESSORIO

## Sistema de Condição (Estado + Desgaste + Depreciação)

Três dimensões por equipamento:

**Estado** (ciclo de vida): NOVO, SEMI_NOVO, USADO, RECONDICIONADO
**Desgaste** (condição física, 1-5): 5=Excelente, 4=Bom, 3=Regular, 2=Desgastado, 1=Crítico
**Depreciação** (valor atual): Valor Original x (Desgaste/5) x Fator Estado
  - Fatores: NOVO=1.00, SEMI_NOVO=0.85, USADO=0.65, RECONDICIONADO=0.50

Defaults na importação: estado=USADO, desgaste=3.

## Planilha (13 abas)

1. MANUAL: instruções pra funcionários
2. DASHBOARD: KPIs, gráficos, saúde do inventário
3-10. Uma aba por categoria (ILUMINACAO, AUDIO, CABO, etc.)
11. LOTES: aba histórica da planilha, não regra operacional futura
12. FORA DE OPERACAO: vendidos, emprestados, baixa
13. REF CATEGORIAS: guia visual completo
