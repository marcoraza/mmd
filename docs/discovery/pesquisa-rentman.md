# Rentman vs Build In-House — Análise Completa

## 1. O que o Rentman faz (relevante pro Marcelo)

### Equipment Tracking com RFID
- **RFID nativo** — não é integração de terceiro, é módulo próprio
- Tags oficiais: RM3 (metal/não-metal), RM4 (sticker não-metal), RM7 (sticker metal)
- Hardware recomendado: **Zebra TC26/TC27** + sled **RFD40/RFD4030**
- Fluxo: cola tag → vincula no app → escaneia em lote na saída/retorno
- Leitura simultânea de múltiplos itens (não precisa escanear 1 por 1)
- Identifica itens faltando automaticamente
- Gerencia múltiplos projetos retornando ao mesmo tempo
- Packing lists digitais pra equipe

### Quoting & Invoicing
- Gera orçamento a partir dos dados do projeto
- Templates customizáveis com branding da empresa
- Puxa disponibilidade em tempo real (não oferta o que não tem)
- Descontos em múltiplos níveis
- **E-signature integrada** — cliente assina digitalmente
- Quando assina, status do projeto muda automaticamente (Pending → Confirmed)
- Faturamento e invoicing no mesmo fluxo

### Contrato
- **Sim, gera contrato a partir do orçamento** — mesmo template engine
- Assinatura digital no contrato
- PDF salvo automaticamente no projeto
- Termos e condições anexados automaticamente
- Documento legalmente válido com audit trail

### CRM
- Básico mas funcional: contatos, histórico, comunicação
- Integrado com projetos e financeiro
- Dashboard e calendários

### Outros
- App mobile (iOS/Android)
- API REST aberta
- Integração Make (ex-Integromat) nativa
- Gestão de crew (não é o caso do Marcelo agora, mas escala)
- Relatórios e analytics

---

## 2. Gaps do Rentman (o que NÃO faz)

| Funcionalidade | Rentman tem? | Observação |
|---|---|---|
| Estoque RFID | ✅ Sim | Nativo, robusto |
| Orçamento automatizado | ✅ Sim | Com templates e e-signature |
| Contrato automatizado | ✅ Sim | A partir do orçamento |
| Briefing digital (cliente preenche) | ❌ Não | Não tem formulário externo pro cliente |
| NPS/feedback pós-evento | ❌ Não | Sem módulo de pesquisa de satisfação |
| Checklist montagem customizável | ⚠️ Parcial | Packing lists sim, checklist operacional limitado |
| Automação avançada | ⚠️ Via API/Make | Não tem automação interna tipo "se X então Y" |
| WhatsApp integrado | ❌ Não | Comunicação por email apenas |

---

## 3. Custo Real (2 Power Users)

### Software Rentman

| Módulo | Custo/mês |
|---|---|
| Plataforma base | €39 |
| Equipment Scheduling Standard (2×€14) | €28 |
| Equipment Tracking (2×€9) | €18 |
| Quoting & Invoicing (2×€9) | €18 |
| **Total mensal** | **€103 (~R$640)** |

Usuários básicos (equipe de campo) = grátis.

### Hardware RFID

| Item | Custo estimado |
|---|---|
| Tags RFID (RM3/RM4/RM7) | €1-5 por unidade |
| Zebra TC26 + RFD40 sled | €2.000-3.500 o conjunto |

**Se o Marcelo já tem hardware Zebra compatível**, custo é só tags + software.

### Custo total estimado primeiro ano
- Software: ~R$7.700/ano
- Tags (200 equipamentos × R$20 média): ~R$4.000 (uma vez)
- Hardware: R$0 (já tem)
- **Total ano 1: ~R$11.700**
- **Total a partir do ano 2: ~R$7.700/ano (~R$640/mês)**

---

## 4. Reviews (resumo)

- **Rating:** 4.6/5 (Capterra, 241 reviews), 4.5/5 (G2)
- **CSAT suporte:** 93-96%
- **Top prós:** RFID tracking excelente, orçamento rápido, visão de disponibilidade em tempo real
- **Top contras:** curva de aprendizado inicial íngreme, app mobile limitado pra admin, relatórios poderiam ser melhores
- **Curva:** 2-4 semanas pra ficar confortável, 1-2 meses pra dominar

---

## 5. Análise Build vs Buy

### Cenário A — Rentman Puro

| Aspecto | Avaliação |
|---|---|
| Cobre estoque RFID | ✅ 100% |
| Cobre orçamento | ✅ 100% |
| Cobre contrato | ✅ 90% (template engine) |
| Cobre briefing digital | ❌ 0% |
| Cobre NPS | ❌ 0% |
| Tempo implementação | 2-4 semanas |
| Custo software | ~R$640/mês |
| Manutenção futura | Do Rentman (SaaS) |
| Risco | Baixo (produto maduro, 50K+ users) |

**Pro Marco como consultor:** valor tá em configurar, migrar dados, treinar. Mas o Marcelo pode pensar "eu poderia ter feito isso sozinho".

### Cenário B — Build In-House (Sheets + Scripts + Make)

| Aspecto | Avaliação |
|---|---|
| Cobre estoque RFID | ⚠️ Complexo — integrar Zebra com Sheets não é trivial |
| Cobre orçamento | ✅ Viável (Forms + Sheets + PDF) |
| Cobre contrato | ✅ Viável (template + merge + PDF) |
| Cobre briefing digital | ✅ Fácil (Google Forms) |
| Cobre NPS | ✅ Fácil (Google Forms) |
| Tempo implementação | 4-8 semanas |
| Custo software | R$0 |
| Manutenção futura | Do Marco (ou o Marcelo fica dependente) |
| Risco | Médio-alto (RFID é o ponto fraco) |

**Problema central:** RFID in-house é overengineering. O Zebra SDK precisa de app mobile custom ou middleware. Isso não é "Sheets + script" — é projeto de dev. Sem RFID, perde o diferencial que o Marcelo mais quer.

### Cenário C — Híbrido (Rentman + Custom) ⭐

| Aspecto | Avaliação |
|---|---|
| Cobre estoque RFID | ✅ Rentman |
| Cobre orçamento | ✅ Rentman |
| Cobre contrato | ✅ Rentman |
| Cobre briefing digital | ✅ Custom (Google Forms/Typeform) |
| Cobre NPS | ✅ Custom (Google Forms) |
| Checklist operacional | ✅ Custom (Notion/Sheets) |
| Tempo implementação | 2-3 semanas (core) + 1-2 semanas (custom) |
| Custo software | ~R$640/mês (Rentman) |
| Manutenção futura | Rentman cuida do core, custom é simples |
| Risco | Baixo |

---

## 6. Tabela Comparativa Final

| Critério | Rentman Puro | In-House | Híbrido |
|---|---|---|---|
| Custo mensal software | R$640 | R$0 | R$640 |
| RFID funcional | ✅ Nativo | ❌ Inviável em 30d | ✅ Nativo |
| Orçamento auto | ✅ | ✅ | ✅ |
| Contrato auto | ✅ | ✅ | ✅ |
| Briefing digital | ❌ | ✅ | ✅ |
| NPS pós-evento | ❌ | ✅ | ✅ |
| Tempo deploy | 2-4 sem | 4-8 sem | 3-4 sem |
| Manutenção | SaaS | Manual | Mix |
| Percepção de valor | Média | Alta | Alta |
| Risco técnico | Baixo | Alto (RFID) | Baixo |
| Valor do consultor | Médio | Alto | **Máximo** |

---

## 7. Recomendação

### Cenário C — Híbrido é o caminho.

**Por quê:**

1. **RFID não se builda em 30 dias com Sheets.** O Marcelo já tem o hardware Zebra, o Rentman é o único que integra nativamente com Zebra sem dev custom. Tentar buildar isso é overengineering e risco de não entregar.

2. **O Rentman cobre 70% do escopo sozinho** (estoque + orçamento + contrato). Os R$640/mês são do Marcelo, não do Marco — e é custo baixo pro que entrega.

3. **O valor do Marco tá nos 30% que o Rentman não faz** — briefing digital, NPS, automações customizadas, mapeamento de processos, classificação de tarefas, treinamento. Isso é consultoria pura, não software.

4. **Posicionamento perfeito:** "Eu vou implementar a melhor ferramenta do mercado pro teu core (Rentman), e vou construir em cima dela tudo que ela não faz. Tu fica com o melhor dos dois mundos."

### Como posicionar na proposta:

- **Fase 1 (semanas 1-4):** Implementar Rentman (config, migração, RFID, treinamento) + briefing digital custom
- **Fase 2 (semanas 5-8):** Automações custom (NPS, checklists, integrações via API/Make) + mapeamento processos
- **Fase 3 (semanas 9-12):** Otimização, documentação, handoff

- **Investimento consultoria:** R$3.000/mês (mantém)
- **Investimento software:** ~R$640/mês Rentman (custo do Marcelo, não incluso na consultoria)
- **Investimento total do Marcelo:** ~R$3.640/mês por 3 meses

O Marco entrega mais, mais rápido, com menos risco. O Marcelo fica com sistema enterprise rodando. Win-win.
