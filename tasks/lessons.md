# Lessons

## 2026-04-03

- Em tarefas de saneamento de planilha, nao assumir que o prompt descreve a versao atual do arquivo. Ler a estrutura real primeiro e tratar o prompt como contexto historico.
- Quando a planilha alvo estiver em edicao concorrente, nao escrever no `.xlsx`. Gerar uma saida intermediaria importavel (`.md` ou `.csv`) e registrar o timestamp da versao observada.
- Antes de aplicar qualquer preenchimento em arquivo vivo, revalidar a estrutura das abas. O layout pode mudar no meio da sessao.
- Se o conflito com outro agente for apenas cosmetico, aplicar por chave estavel (`Codigo`) e nao por posicao de linha.
- Nao tratar o valor atual da planilha como fonte confiavel so porque o campo ja estava preenchido. Se nao houver fonte melhor, marcar como estimativa explicita.
- Ao casar overrides e fontes locais, normalizar nomes curtos e aliases de subcategoria. A planilha mistura `TRIPE MIC`, `CAIXA SOM`, `RX MIC` e outros apelidos com versoes por extenso.
- Scripts que leem a planilha precisam tolerar cosmetica em campos numericos, como estrelas em `Desgaste` ou texto com `R$`.
- Quando um pipeline exporta `Valor Atual`, o campo `Deprec.%` precisa manter o mesmo contrato semantico da planilha: percentual perdido, nao percentual remanescente.
- Scripts que reaplicam valores no `.xlsx` nao podem congelar colunas derivadas. Se a regra vive na planilha, reescrever a formula e forcar recalc ao salvar.
- Nomes ambigguos de item nao podem ser inferidos so pelo texto. Antes de reprecificar um registro como acessorio ou capsula, validar com o Marco quando o nome puder apontar para o equipamento principal, como em `PARA MICROFONE SM58`.
- Antes de citar um teste como parte de um PR, conferir se ele esta versionado e se roda contra o codigo realmente commitado. Teste local em arquivo untracked nao conta como cobertura entregue.
