# MMD Eventos: Estoque Inteligente

## Projeto

Sistema de estoque inteligente para empresa de locação de equipamentos AV/eventos (MMD, Marcelo Santos). RFID + QR Code, tudo in-house, sem integrações externas. Supabase é a fonte de verdade única para catálogo, eventos, packing lists, alocações, movimentações, condição e auditoria.

- **Cliente:** Marcelo Santos (MMD Eventos)
- **Contrato:** R$3.000/mês, 3 meses
- **Foco:** 100% estoque inteligente
- **Design System:** Liquid Glass 2030 em `apps/web/src/components/mmd/Primitives.tsx`, `apps/web/src/app/globals.css` e `apps/web/public/handoff/`
- **Briefing MAR-171:** `docs/mar-171-agent-brief.md`
- **Referências visuais e evidências:** `tasks/evidence/mar-XXX/`

## Fonte de Verdade Atual

Para o PRD MAR-171, leia nesta ordem:

1. `docs/mar-171-agent-brief.md`
2. `docs/handoff.md`
3. `apps/web/AGENTS.md`
4. `tasks/mar-171-supervisor.md`
5. ADRs em `docs/adr/`

Documentos em `docs/discovery/` e `tasks/auditoria-frontend/` são históricos. Podem ajudar com contexto, mas não substituem o briefing MAR-171 nem as decisões do grill.

## Design

Sistema visual Liquid Glass 2030: superfícies vítreas, caustics iridescentes, ring de prontidão como motivo central, dark-first. Tokens em oklch, componentes em `apps/web/src/components/mmd/Primitives.tsx`.

Fontes: Inter Tight (UI, headings, body), JetBrains Mono (seriais, timestamps, labels).
Dispositivos: iPhone (campo, galpão) + MacBook (gestão, escritório).

Prints em `tasks/evidence/` têm três tipos: referência glass, imagegen e screenshot final de QA. Eles não são um front-end novo nem fonte de verdade para reconstrução.

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
├── AGENTS.md              # Contrato operacional para agentes Codex
├── CLAUDE.md              # Espelho de contexto para Claude Code
├── CONTEXT.md             # Linguagem ubíqua do produto
├── docs/
│   ├── mar-171-agent-brief.md # Fonte curta para agentes do PRD atual
│   ├── handoff.md             # Estado operacional do projeto
│   ├── adr/                   # Decisões arquiteturais e de produto
│   └── discovery/             # Pesquisa, proposta, comparativos antigos
├── data/                  # Inventários e arquivos importáveis, quando presentes
├── scripts/               # Scripts de automação
├── tasks/                 # Sprint tracking, auditorias, lessons e evidências
├── apps/
│   ├── ios/               # App iOS (Swift/SwiftUI + Zebra SDK)
│   └── web/               # Web app (Next.js)
└── supabase/
    └── migrations/        # SQL migrations
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
- **Ficha de evento nasce no web.** Preenchida quando o contrato fecha, por Marcelo, admin ou equipe. Mobile pode consultar e executar campo.
- **Orçamento e contrato ficam no web.** O sistema guarda status, link ou anexo comercial leve, não vira financeiro completo.

## Fronteira Web, Mobile e Backend

- Web: gestão, ficha de evento, orçamento/contrato, packing, importação de planilha, alocação, checklist, dashboard e administração.
- Mobile: campo, scan, check-out, retorno, resumo do evento e conexão com RFD40.
- Backend/Supabase: migrations, RLS, grants, RPCs, auditoria, contratos de API e dados reais.

Front-end não deve criar produto paralelo. Qualquer tela nova ou alteração visual relevante deve partir dos mocks glass existentes, gerar imagegen quando fizer sentido, implementar no app real e anexar screenshot final.

## Convenções

- Arquivos: kebab-case
- Branches: `cc/sprint-N-slug`
- Código interno: `MMD-{CAT}-{0001}` (ex: `MMD-ILU-0001`)
- Prefixos: ILU, AUD, CAB, ENE, EST, EFE, VID, ACE
- Categorias: ILUMINACAO, AUDIO, CABO, ENERGIA, ESTRUTURA, EFEITO, VIDEO, ACESSORIO
- Produto fala Evento. Evite chamar de job.

## Sistema de Condição

Três dimensões por equipamento:

**Estado** (ciclo de vida): NOVO, SEMI_NOVO, USADO, RECONDICIONADO
**Desgaste** (condição física, 1-5): 5=Excelente, 4=Bom, 3=Regular, 2=Desgastado, 1=Crítico
**Depreciação** (valor atual): Valor Original x (Desgaste/5) x Fator Estado

Fatores:

- NOVO: 1.00
- SEMI_NOVO: 0.85
- USADO: 0.65
- RECONDICIONADO: 0.50

Defaults na importação: estado=USADO, desgaste=3.

## Planilha

A planilha original segue como fonte de entrada e referência histórica. O fluxo futuro é Supabase-first.

Abas relevantes:

1. MANUAL: instruções pra funcionários
2. DASHBOARD: KPIs, gráficos, saúde do inventário
3-10. Uma aba por categoria
11. LOTES: aba histórica, não regra operacional futura
12. FORA DE OPERACAO: vendidos, emprestados, baixa
13. REF CATEGORIAS: guia visual completo
