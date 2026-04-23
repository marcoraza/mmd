# Plano de Execucao: Estoque Inteligente MMD

## Contexto

Consultoria de otimizacao operacional para Marcelo Santos, empresa de locacao de equipamentos AV/eventos (6-8 eventos/mes). O projeto principal e o sistema de estoque inteligente com RFID + QR Code, construido 100% in-house. Supabase e a fonte de verdade unica, sem integracao com Rentman ou qualquer ERP externo.

**Cliente:** Marcelo Santos (MMD)
**Consultor:** Marco Aquilino
**Contrato:** R$3.000/mes, 3 meses
**Foco:** 100% estoque inteligente
**Entrega:** 7 dias

---

## Diagnostico do Inventario

### Numeros

- **1.064 itens** na planilha principal
- **~R$ 372k** valor patrimonial registrado (so 103 itens tem valor, real e maior)
- **87% sem serial** de fabrica (921 itens "S/ SERIAL")
- **44% sao cabos** (465 itens)
- **47 categorias** brutas que normalizam pra ~8
- **21 seriais internos duplicados**
- **7 itens fora de operacao** (4 emprestados, 2 vendidos, 1 quebrado)

### Problemas criticos

1. **Sem identificador unico** em 87% dos itens. Solucao: gerar codigo interno padronizado (MMD-XXX-0001)
2. **Categorias inconsistentes** (47 variacoes pra ~8 reais). Solucao: taxonomia normalizada
3. **Cabos sem estrutura** (texto livre). Solucao: rastreamento por lote
4. **Dados duplicados** entre sheets. Solucao: consolidar, MAIO e a fonte da verdade
5. **Itens vendidos/emprestados misturados**. Solucao: status controlados

---

## Arquitetura do Sistema

### Diagrama Geral

```
                    ESTOQUE INTELIGENTE MMD
                    ======================

    ┌─────────────────────────────────────────────────────┐
    │                                                     │
    │   ┌───────────────────┐   ┌──────────────────────┐  │
    │   │   App iOS          │   │   Web App (Next.js)  │  │
    │   │   Swift/SwiftUI    │   │   Dashboard + CRUD   │  │
    │   │                   │   │                      │  │
    │   │  ┌─────────────┐  │   │  ┌────────────────┐  │  │
    │   │  │ RFID Scan    │  │   │  │ Dashboard      │  │  │
    │   │  │ (Zebra SDK)  │  │   │  │ Inventario     │  │  │
    │   │  │ Leitura lote │  │   │  │ Disponibilidade│  │  │
    │   │  └─────────────┘  │   │  └────────────────┘  │  │
    │   │  ┌─────────────┐  │   │  ┌────────────────┐  │  │
    │   │  │ QR Scan      │  │   │  │ Projetos       │  │  │
    │   │  │ (Camera)     │  │   │  │ Packing Lists  │  │  │
    │   │  │ Fallback     │  │   │  │ Eventos        │  │  │
    │   │  └─────────────┘  │   │  └────────────────┘  │  │
    │   │  ┌─────────────┐  │   │  ┌────────────────┐  │  │
    │   │  │ Packing List │  │   │  │ QR Code        │  │  │
    │   │  │ Check-in/out │  │   │  │ Geracao        │  │  │
    │   │  │ Validacao    │  │   │  │ Impressao      │  │  │
    │   │  └─────────────┘  │   │  └────────────────┘  │  │
    │   └────────┬──────────┘   └──────────┬───────────┘  │
    │            │                         │              │
    │            └──────────┬──────────────┘              │
    │                       │                             │
    │              ┌────────▼────────┐                    │
    │              │  API (Next.js)  │                    │
    │              │  API Routes     │                    │
    │              └────────┬────────┘                    │
    │                       │                             │
    │              ┌────────▼────────┐                    │
    │              │   Supabase      │                    │
    │              │  ┌───────────┐  │                    │
    │              │  │ Postgres  │  │                    │
    │              │  │ Auth      │  │                    │
    │              │  │ Realtime  │  │                    │
    │              │  │ Storage   │  │                    │
    │              │  └───────────┘  │                    │
    │              └─────────────────┘                    │
    │                                                     │
    └─────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────┐
    │                  HARDWARE                           │
    │                                                     │
    │   iPhone ◄──Bluetooth──► Zebra RFD40 (RFID UHF)   │
    │                                                     │
    │   Tags: RM3 (metal) / RM4 (sticker) / RM7 (metal) │
    └─────────────────────────────────────────────────────┘
```

### Fluxo de Status

```
                    CICLO DE VIDA DO EQUIPAMENTO
                    ============================

    ┌──────────┐     ┌────────┐     ┌──────────┐     ┌───────────┐
    │DISPONIVEL│────►│ PACKED │────►│EM_CAMPO  │────►│RETORNANDO │
    └──────────┘     └────────┘     └──────────┘     └───────────┘
         ▲                                                 │
         │                                                 │
         └─────────────────────────────────────────────────┘
                         (retorno OK)

         ┌──────────────────────────────────────┐
         │          FLUXOS ALTERNATIVOS         │
         │                                      │
         │  DISPONIVEL ──► MANUTENCAO ──► DISPONIVEL
         │  DISPONIVEL ──► EMPRESTADO ──► DISPONIVEL
         │  DISPONIVEL ──► VENDIDO (terminal)
         │  DISPONIVEL ──► BAIXA (terminal)
         │  EM_CAMPO ──► MANUTENCAO (retorno com defeito)
         └──────────────────────────────────────┘
```

### Fluxo Operacional

```
    FLUXO DE SAIDA (Packing)
    ========================

    Marcelo cria projeto ──► Monta packing list ──► Equipe abre no app iOS
         (web app)              (web app)              (iPhone)
                                                          │
                                                          ▼
                                                   Escaneia RFID
                                                   em lote
                                                          │
                                                          ▼
                                               ┌──────────────────┐
                                               │  VALIDACAO        │
                                               │                  │
                                               │  ✅ Na lista      │
                                               │  ❌ Nao na lista  │
                                               │  ⚠️  Faltando     │
                                               └──────────────────┘
                                                          │
                                                          ▼
                                                   Confirma saida
                                                   Status → EM_CAMPO


    FLUXO DE RETORNO
    =================

    Equipe escaneia ──► Sistema compara ──► Resultado
    RFID em lote         com packing list
                                               │
                              ┌─────────────────┼──────────────┐
                              ▼                 ▼              ▼
                         Voltou OK         Com defeito    Nao voltou
                         → DISPONIVEL      → MANUTENCAO  → Alerta
```

### Modelo de Dados

```
    ┌──────────────┐       ┌──────────────────┐
    │    items     │       │  serial_numbers   │
    │──────────────│       │──────────────────│
    │ id (PK)      │◄──┐  │ id (PK)          │
    │ nome         │   │  │ item_id (FK)  ────┘
    │ categoria    │   │  │ codigo_interno    │
    │ subcategoria │   │  │ serial_fabrica    │
    │ marca        │   │  │ tag_rfid          │
    │ modelo       │   │  │ qr_code           │
    │ qtd_total    │   │  │ status            │
    │ valor_unit   │   │  │ estado            │
    └──────────────┘   │  │ desgaste          │
                       │  │ depreciacao_pct   │
                       │  │ valor_atual       │
                       │  │ localizacao       │
                       │  └──────────────────┘
    ┌──────────────┐   │
    │   projetos   │   │  ┌──────────────────┐
    │──────────────│   │  │  packing_list     │
    │ id (PK)      │◄──┼──│──────────────────│
    │ nome         │   │  │ id (PK)          │
    │ cliente      │   │  │ projeto_id (FK)──┘
    │ data_inicio  │   └──│ item_id (FK)     │
    │ data_fim     │      │ quantidade       │
    │ local        │      │ serials_design.  │
    │ status       │      └──────────────────┘
    └──────────────┘
                          ┌──────────────────┐
    ┌──────────────┐      │  movimentacoes   │
    │    lotes     │      │──────────────────│
    │──────────────│      │ id (PK)          │
    │ id (PK)      │      │ serial_id (FK)   │
    │ item_id (FK) │      │ projeto_id (FK)  │
    │ codigo_lote  │      │ tipo             │
    │ descricao    │      │ status_anterior  │
    │ quantidade   │      │ status_novo      │
    │ tag_rfid     │      │ registrado_por   │
    │ qr_code      │      │ metodo_scan      │
    │ status       │      │ timestamp        │
    └──────────────┘      └──────────────────┘
```

### Sistema de Condicao (Estado + Desgaste + Depreciacao)

Cada unidade fisica (serial_number) tem 3 campos que substituem o antigo enum `condicao` (OK/DEFEITO/REVISAR):

| Campo | Tipo | Descricao |
|-------|------|-----------|
| estado | enum: NOVO, SEMI_NOVO, USADO, RECONDICIONADO | Estagio do ciclo de vida |
| desgaste | int 1-5 | Avaliacao de desgaste fisico. 5=excelente, 1=critico |
| depreciacao_pct | numeric | % do valor original restante |
| valor_atual | numeric | Calculado: valor_mercado x (desgaste/5) x fator_estado |

Fatores por estado:
- NOVO = 1.00
- SEMI_NOVO = 0.85
- USADO = 0.65
- RECONDICIONADO = 0.50

Defaults para importacao inicial: estado=USADO, desgaste=3, depreciacao e valor_atual calculados automaticamente.

O dashboard exibe metricas de saude patrimonial: desgaste medio por categoria, itens com desgaste critico (1-2), e depreciacao total.

### Taxonomia de Categorias (normalizada)

```
    CATEGORIA (enum 8)          SUBCATEGORIAS (exemplos)
    ──────────────────          ────────────────────────
    ILUMINACAO                  Par LED, Ribalta, Moving, Mini Moving,
                                Mini Brute, Strobo, Laser, Luz Negra, COB
    AUDIO                       Caixa de som, Subwoofer, Mesa de som,
                                Amplificador, Microfone, Direct Box,
                                CDJ/XDJ, In-ear, Processador
    CABO                        XLR, DMX, P10, AC, Powercon, HDMI,
                                Speakon, USB, RCA, VGA
    ENERGIA                     Regua, Centopeia, Extensao, Transformador
    ESTRUTURA                   Tripe, Box Truss, Praticavel, Suporte TV
    EFEITO                      Fumaca, Haze, CO2, Fluido
    VIDEO                       Projetor, Notebook, Tablet
    ACESSORIO                   Case, Ferramenta, Roteador, MIDI
```

---

## Stack Tecnica

| Componente | Tecnologia |
|---|---|
| App iOS (campo) | Swift/SwiftUI + Zebra iOS RFID SDK (XCFramework) |
| Web app (gestao) | Next.js + Tailwind + PWA |
| API | Next.js API Routes |
| Banco de dados | Supabase (Postgres + Auth + Realtime + Storage) |
| RFID | Zebra RFD40 via Bluetooth → iPhone → Zebra iOS SDK |
| QR Code | Geracao: qrcode lib. Leitura: AVFoundation (iOS) + Web API |
| Deploy web | Vercel (free tier) |
| Deploy iOS | TestFlight / ad-hoc distribution |

---

## Cronograma — 7 Dias

### Dia 1: Limpeza de dados + Supabase
- Script Python: consolidar inventario, normalizar categorias, gerar codigos internos
- Calcular sistema de condicao: estado, desgaste, depreciacao_pct e valor_atual para cada serial
- Agrupar cabos em lotes
- Setup Supabase: schema completo, enums (incluindo estado_enum), RLS, auth
- Seed data: importar base limpa com campos de condicao preenchidos

### Dia 2: App iOS — RFID scan (PRIORIDADE)
- Xcode project com Zebra iOS RFID SDK
- Conexao Bluetooth com RFD40
- Leitura em lote: scan → lista de tags → resolve contra API
- Tela de resultado com itens escaneados

### Dia 3: App iOS — packing list + check-in/check-out
- Tela de projetos e packing list
- Fluxo de saida: scan RFID → valida contra packing list → confirma
- Fluxo de retorno: scan → compara → alerta faltantes
- QR Code scan como fallback
- Marcacao de defeito no retorno

### Dia 4: Web app — dashboard + CRUD
- Next.js app com Supabase
- Dashboard: totais por categoria, status, valor patrimonial
- Lista de items com busca/filtro
- CRUD completo de items, serial numbers e lotes

### Dia 5: Web app — eventos + packing list + QR
- CRUD de projetos/eventos
- Editor de packing list
- Dashboard de disponibilidade por data
- Geracao e impressao de QR Codes (etiquetas A4)

### Dia 6: Vinculacao RFID + real-time
- Tela de vinculacao tag RFID → serial number (iOS + web)
- Importacao em massa via CSV
- Supabase Realtime: status atualiza em tempo real
- Testes end-to-end com dados simulados

### Dia 7: Deploy + polish + entrega
- Deploy web (Vercel) + iOS (TestFlight)
- Testes end-to-end completos
- Ajustes de UX
- Guia rapido pro Marcelo
- Handoff: credenciais, acessos

---

## Modelo de dados (in-house)

Nao ha integracao com Rentman ou qualquer ERP externo. Supabase e a fonte de verdade unica.

**Conceitos centrais:**
- Item (tipo/catalogo) vs Serial Number (unidade fisica)
- Projeto com packing list criado direto no app
- Status por serial: Disponivel → Packed → Em campo → Retorno
- RFID scan em lote + QR Code individual
- Validacao packing list vs scan
- Dashboard de disponibilidade em tempo real

**Fora do MVP (fase 2):**
- Flight cases como containers
- Workflow de reparo/dano automatizado
- Multi-warehouse
- Sub-rentals
- Statuses customizaveis
- Auth com roles (operador vs admin) e biometria

---

## Hardware RFID

- **Leitor:** Zebra RFD40 (ou RFD4030 Standard)
- **Conexao:** Bluetooth com iPhone
- **SDK:** Zebra RFID SDK for iOS (XCFramework, Swift/Obj-C)
- **Tags:** RM3 (metal), RM4 (sticker nao-metal), RM7 (sticker metal)
- **App referencia:** 123RFID Mobile (app oficial Zebra pra testes)

---

## Verificacao Final

- [ ] Dados consolidados e importados sem perda
- [ ] Campos de condicao (estado, desgaste, depreciacao_pct, valor_atual) preenchidos em todos os serials
- [ ] QR Code gerado e escaneavel pra cada item/lote
- [ ] Check-in/check-out funcional via camera
- [ ] Dashboard mostra disponibilidade correta em tempo real
- [ ] Dashboard exibe metricas de saude patrimonial (desgaste medio, itens criticos, depreciacao)
- [ ] RFID le multiplos itens em lote (testado com simulacao)
- [ ] Itens vinculados a eventos com rastreamento saida/retorno
- [ ] Alertas de itens nao devolvidos funcionando
- [ ] App iOS distribuido via TestFlight
- [ ] Web app em producao na Vercel
