# Lessons

## 2026-04-03

- Quando a planilha alvo estiver em edicao concorrente, nao escrever no `.xlsx`. Gerar uma saida intermediaria importavel (`.md` ou `.csv`) e registrar o timestamp da versao observada.
- Antes de aplicar qualquer preenchimento em arquivo vivo, revalidar a estrutura das abas. O layout pode mudar no meio da sessao.
- Se o conflito com outro agente for apenas cosmetico, aplicar por chave estavel (`Codigo`) e nao por posicao de linha.
- Nao tratar o valor atual da planilha como fonte confiavel so porque o campo ja estava preenchido. Se nao houver fonte melhor, marcar como estimativa explicita.
- Ao casar overrides e fontes locais, normalizar nomes curtos e aliases de subcategoria. A planilha mistura `TRIPE MIC`, `CAIXA SOM`, `RX MIC` e outros apelidos com versoes por extenso.
- Scripts que leem a planilha precisam tolerar cosmetica em campos numericos, como estrelas em `Desgaste` ou texto com `R$`.
