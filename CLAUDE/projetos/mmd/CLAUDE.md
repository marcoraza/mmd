# MMD Eventos — Estoque Inteligente

## Projeto

Sistema de estoque inteligente para empresa de locacao de equipamentos AV/eventos (MMD, Marcelo Santos). RFID + QR Code in-house, espelhando Rentman.

- **Cliente:** Marcelo Santos (MMD Eventos)
- **Contrato:** R$3.000/mes, 3 meses
- **Foco:** 100% estoque inteligente
- **ClickUp:** PROJETOS > [MMD] MMD EVENTOS (folder 901317960993)

## Stack

| Componente | Tecnologia |
|---|---|
| App iOS (campo) | Swift/SwiftUI + Zebra iOS RFID SDK |
| Web app (gestao) | Next.js 14 + Tailwind + shadcn/ui |
| API | Next.js API Routes |
| Banco | Supabase (Postgres + Auth + Realtime + Storage) |
| RFID | Zebra RFD40 via Bluetooth no iPhone |
| QR Code | qrcode lib (geracao) + AVFoundation/Web API (leitura) |
| Deploy web | Vercel |
| Deploy iOS | TestFlight / ad-hoc |

## Estrutura do Projeto

```
mmd/
├── CLAUDE.md              # Este arquivo
├── docs/
│   ├── discovery/         # Pesquisa, proposta, comparativos (pre-projeto)
│   ├── plano-*.md         # Plano de execucao
│   ├── agent-prompts.md   # Prompts dos sprints (/cc)
│   └── command-center.html # Command Center HTML
├── data/
│   ├── inventario-original.xlsx  # Excel original do Marcelo
│   └── inventario-limpo.xlsx     # Planilha profissional gerada
├── scripts/               # Scripts de automacao (Python)
├── tasks/                 # Sprint tracking, lessons
├── apps/
│   ├── ios/               # App iOS (Swift/SwiftUI + Zebra SDK)
│   └── web/               # Web app (Next.js)
└── supabase/              # Schema, migrations, seed data
```

## Decisoes Tecnicas

- **RFID e prioridade.** QR Code e complemento/fallback.
- **RFID roda no iPhone (iOS).** RFD40 conecta via Bluetooth. SDK iOS nativo.
- **Cabos por lote.** Cabos genericos agrupados em kits com QR Code unico.
- **Modelo de dados espelha Rentman.** Item (tipo) + Serial Number (unidade fisica).
- **Sheet MAIO e a fonte da verdade** do inventario original.

## Convencoes

- Arquivos: kebab-case
- Branches: cc/sprint-N-slug
- Codigo interno: MMD-{CAT}-{0001} (ex: MMD-ILU-0001)
- Prefixos: ILU, AUD, CAB, ENE, EST, EFE, VID, ACE
- Categorias: ILUMINACAO, AUDIO, CABO, ENERGIA, ESTRUTURA, EFEITO, VIDEO, ACESSORIO

## Sistema de Condicao (Estado + Desgaste + Depreciacao)

Tres dimensoes por equipamento:

**Estado** (ciclo de vida): NOVO, SEMI_NOVO, USADO, RECONDICIONADO
**Desgaste** (condicao fisica, 1-5): 5=Excelente, 4=Bom, 3=Regular, 2=Desgastado, 1=Critico
**Depreciacao** (valor atual): Valor Original x (Desgaste/5) x Fator Estado
  - Fatores: NOVO=1.00, SEMI_NOVO=0.85, USADO=0.65, RECONDICIONADO=0.50

Defaults na importacao: estado=USADO, desgaste=3.

## Planilha (13 abas)

1. MANUAL — instrucoes pra funcionarios
2. DASHBOARD — KPIs, graficos, saude do inventario
3-10. Uma aba por categoria (ILUMINACAO, AUDIO, CABO, etc.)
11. LOTES — cabos agrupados
12. FORA DE OPERACAO — vendidos, emprestados, baixa
13. REF CATEGORIAS — guia visual completo
