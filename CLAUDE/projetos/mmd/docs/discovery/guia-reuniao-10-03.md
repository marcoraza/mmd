# Guia de Reunião — Marcelo Santos
## 10/03 — Follow-up + Proposta

---

## PARTE 1 — Abertura

**Recapitula as dores dele** — estoque por planilha e WhatsApp, orçamento manual de 1-2h, tudo dependendo dele.

**Mostra que já mapeou** — não é genérico, tu entendeu a operação dele.

**Apresenta os 3 quick wins como sistema integrado:**

**1.** Estoque inteligente — cada equipamento rastreado em tempo real, acessa do celular.

**2.** Orçamento automatizado — dados entram uma vez, proposta sai pronta, já cruza com disponibilidade.

**3.** Contrato automático — cliente aprova orçamento, contrato se preenche sozinho.

**Faz ele visualizar:** "Chega pedido, tu vê o que tem, monta orçamento em minutos, cliente aprova, contrato sai pronto — sem digitar nada duas vezes."

---

## PARTE 2 — Detalhamento dos Quick Wins

### Quick Win 1 — Orçamento Automatizado

**Implementação: Google Sheets + Apps Script ou Make/Zapier. Zero código pesado.**

**O sistema:**
1. Formulário de entrada — Marcelo preenche dados do evento (tipo, data, local, equipamentos)
2. Planilha automática puxa preços da tabela-base de equipamentos
3. Template gera PDF com itens, valores, condições — layout da empresa
4. Envio direto pro cliente (email ou WhatsApp)

**Resultado:** Marcelo alimenta a tabela de preços uma vez. Depois é só preencher o formulário. De 1-2h pra 10-15 min.

---

### Quick Win 2 — Controle de Estoque Remoto

**Esse é o que precisa de mais cuidado.**

**O que TU faz remoto:**
- Monta o sistema inteiro (estrutura, lógica, interface)
- Define categorias, códigos, RFIDs
- Cria a planilha/app de controle
- Monta os fluxos de entrada/saída
- Gera os RFIDs e manda pra impressão

**O que o MARCELO faz presencial:**
- Inventário inicial — contar e catalogar tudo
- Imprimir e colar RFIDs nos equipamentos
- Usar o sistema no dia a dia (check-in/check-out)

**Sistema RFID (Marcelo já tem o hardware):**
1. Sistema master com todos os equipamentos (nome, categoria, tag RFID, status, localização)
2. Cada equipamento vinculado à sua tag RFID
3. Sai pro evento: leitor RFID registra saída em lote — passa vários de uma vez
4. Volta: leitor registra retorno automaticamente
5. Dashboard de disponibilidade em tempo real

---

### Cronograma de Implementação Remota

**Semana 1 (tu faz):**
- Monta planilha master + formulários de check-in/check-out
- Gera template de inventário pra Marcelo preencher
- Configura integração com leitor RFID dele

**Semana 1 (Marcelo faz):**
- Preenche inventário completo (tu manda template, ele preenche)
- Tira foto dos equipamentos principais

**Semana 2 (tu faz):**
- Gera RFIDs de todos os itens
- Configura leitura automática em lote
- Monta dashboard de disponibilidade
- Grava vídeo de 5 min explicando como usar

**Semana 2 (Marcelo faz):**
- Imprime e cola RFIDs
- Testa o fluxo num evento real

---

### Quick Win 3 — Contrato Automatizado

**Semanas 3-4:**
- Orçamento aprovado → sistema puxa dados e preenche contrato automaticamente
- PDF pronto pra assinatura digital
- Envio direto pro cliente

---

## PARTE 3 — Fechamento

**Proposta:** R$3.000/mês, contrato de 3 meses.

**Reuniões:** 2x/semana no primeiro mês, depois 1x.

**Primeiros 30 dias:** os 3 quick wins entregues e rodando.

**Meses 2-3:** otimizar o resto da operação — mapear todos os processos, classificar o que automatiza, o que precisa de IA, o que precisa de gente.

**Fecha perguntando:** se faz sentido, se quer ajustar algo, e combina o kick-off.

---

## Resumo

Tu não precisa estar lá. Tu monta o sistema, ele opera. A única parte presencial é vincular tag e usar o leitor — e isso é dele.

**O segredo: tu entrega o sistema pronto pra usar, não um projeto pra ele montar.**
