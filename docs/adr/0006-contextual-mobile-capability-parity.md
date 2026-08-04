---
status: proposed
---

# ADR 0006: Paridade mobile por capacidades contextuais

O Event Pro preserva as capacidades úteis do app legado sem copiar sua árvore de telas. A navegação persistente fica em Início, Eventos e Catálogo, com Identificar como scanner global. Etiquetar e Localizar pertencem à unidade; Conferência de saída e Conferência de retorno pertencem ao Evento; conexão do RFD40 aparece dentro da operação que precisa dela. Toda a rotina RFID da MMD deve existir no app, enquanto firmware, Wi-Fi e ajuste manual de antena permanecem fora da UX operacional. Essa divisão reduz caminhos e componentes repetidos sem remover consequências operacionais.
