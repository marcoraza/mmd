# Todo

- [x] Inspecionar a estrutura da planilha `data/inventario-limpo.xlsx`
- [x] Medir lacunas de `Valor Unit. (R$)` em `ITENS` e `Valor (R$)` em `SERIAL NUMBERS`
- [x] Implementar script de enriquecimento com fontes locais + pesquisa web
- [x] Adaptar a saida para `.md` importavel quando a planilha entrou em edicao concorrente
- [x] Gerar `data/valores-para-importacao.md` com valores por serial para a versao atual da planilha
- [x] Validar resumo, CSV e secao de revisao prioritaria do markdown gerado
- [x] Aplicar os valores no `.xlsx` real por `Codigo`, com backup antes de salvar
- [x] Atualizar dashboard e resumos estaticos para refletir os novos totais
- [x] Priorizar itens estimados de maior impacto para uma segunda passada
- [x] Adicionar overrides manuais com fonte para modelos em que a busca automatica falhou
- [x] Regenerar o markdown de importacao, reaplicar no `.xlsx` e revalidar totais
- [x] Remover a precedencia de valores herdados da planilha atual
- [x] Reprecificar os itens herdados com fonte local, curadoria web e estimativa explicita
- [x] Reaplicar a nova rodada no `.xlsx` com parser tolerante a campos cosmeticos

## Review

- A planilha alvo mudou de estrutura durante a execucao e passou a ser editada por outro agente.
- Para evitar conflito, a entrega final foi convertida para markdown importavel em vez de editar o `.xlsx`.
- O arquivo gerado reflete a versao atual observada em `2026-04-03 13:49`, com 507 seriais e 255 itens unicos.
- Depois da liberacao do Marco, os valores foram aplicados no arquivo real e os campos de valor ficaram completos nas abas com colunas de precificacao.
- A segunda passada foi aberta para reduzir o peso das estimativas genericas mais caras, sem mudar a logica de aplicacao por `Codigo`.
- A segunda passada substituiu 98 linhas por fontes curadas e reduziu o valor original agregado do dashboard para `R$ 973.885,50`.
- Permaneceram 7 itens em revisao prioritaria, todos com `manual_web_curado` mas confianca abaixo de `0.70`.
- A terceira passada elevou a maior parte das confiancas manuais e adicionou override curado para `Showtech ST-OP1806CS`, reduzindo a revisao prioritaria para 1 item.
- Permanecem sem fonte publica suficiente para override confiavel os modelos `Showtech ST-32T` e `Showtech ST-1260XWS`, entao eles ficaram com o valor existente da planilha.
- O item ambigguo `PARA MICROFONE SM58` foi assumido como valor aproximado em `R$ 1.600,00`, encerrando a revisao prioritaria do markdown.
- Os campos numericos de valor no `.xlsx` foram padronizados para exibir `R$`.
- Nao ha vazios nas colunas de valor, mas ainda existem `242` itens unicos cuja fonte atual no markdown e apenas `valor ja presente na planilha`, sem revalidacao externa nesta rodada.
- A rodada de revisao dos herdados removeu totalmente o fallback `historico_planilha_atual`; agora `0` itens usam o valor antigo da planilha como fonte final.
- O pipeline passou a normalizar aliases de subcategoria (`TRIPE MIC`, `CAIXA SOM`, `RX MIC`, `MESA SOM`, `MESA LUZ`, etc.) para aproveitar melhor fontes curadas e locais.
- Foram adicionadas ancoras manuais para itens de maior impacto em `ILUMINACAO`, `ACESSORIO` e `VIDEO`, e o markdown final ficou com `0` itens em `estimativa_global`.
- A planilha final reaplicada ficou com `516` linhas atualizadas por `Codigo`, `0` vazios nas colunas de valor e dashboard em `Valor Original = R$ 974.094,53` e `Valor Atual = R$ 394.569,04`.
- Permanecem `166` itens unicos em revisao prioritaria, mas todos agora marcados explicitamente como estimativa por subcategoria, brand+subcategoria ou categoria, sem reaproveitamento silencioso de valor herdado.
