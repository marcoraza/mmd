# Todo

- [x] Inspecionar a estrutura da planilha `data/inventario-limpo.xlsx`
- [x] Medir lacunas de `Valor Unit. (R$)` em `ITENS` e `Valor (R$)` em `SERIAL NUMBERS`
- [x] Implementar script de enriquecimento com fontes locais + pesquisa web
- [x] Adaptar a saida para `.md` importavel quando a planilha entrou em edicao concorrente
- [x] Gerar `data/valores-para-importacao.md` com valores por serial para a versao atual da planilha
- [x] Validar resumo, CSV e secao de revisao prioritaria do markdown gerado
- [x] Aplicar os valores no `.xlsx` real por `Codigo`, com backup antes de salvar
- [x] Atualizar dashboard e resumos estaticos para refletir os novos totais
- [ ] Priorizar itens estimados de maior impacto para uma segunda passada
- [ ] Adicionar overrides manuais com fonte para modelos em que a busca automatica falhou
- [ ] Regenerar o markdown de importacao, reaplicar no `.xlsx` e revalidar totais

## Review

- A planilha alvo mudou de estrutura durante a execucao e passou a ser editada por outro agente.
- Para evitar conflito, a entrega final foi convertida para markdown importavel em vez de editar o `.xlsx`.
- O arquivo gerado reflete a versao atual observada em `2026-04-03 13:49`, com 507 seriais e 255 itens unicos.
- Depois da liberacao do Marco, os valores foram aplicados no arquivo real e os campos de valor ficaram completos nas abas com colunas de precificacao.
- A segunda passada foi aberta para reduzir o peso das estimativas genericas mais caras, sem mudar a logica de aplicacao por `Codigo`.
