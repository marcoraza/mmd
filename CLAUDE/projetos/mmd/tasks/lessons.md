# Lessons

## 2026-04-03

- Quando a planilha alvo estiver em edicao concorrente, nao escrever no `.xlsx`. Gerar uma saida intermediaria importavel (`.md` ou `.csv`) e registrar o timestamp da versao observada.
- Antes de aplicar qualquer preenchimento em arquivo vivo, revalidar a estrutura das abas. O layout pode mudar no meio da sessao.
- Se o conflito com outro agente for apenas cosmetico, aplicar por chave estavel (`Codigo`) e nao por posicao de linha.
