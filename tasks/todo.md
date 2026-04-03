# Todo

## Sprint 0 - Data Cleanup + Supabase Schema

- [x] Validar task `86agn5dq2` no ClickUp, mover para `in progress` e registrar comentario inicial
- [x] Inspecionar a estrutura real de `data/inventario-original.xlsx` e reconciliar divergencias do prompt
- [x] Implementar `scripts/cleanup_inventory.py` reaproveitando o parsing util do pipeline existente
- [x] Gerar `data/items.json`, `data/serial_numbers.json`, `data/lotes.json`, `data/migration.sql` e `data/cleanup_report.txt`
- [x] Implementar `scripts/seed_supabase.py` e `scripts/requirements.txt`
- [x] Executar validacoes locais do cleanup, unicidade de codigos, categorias normalizadas e status
- [x] Validar SQL gerado e registrar pendencias reais da base atual
- [ ] Finalizar ClickUp com comentario de resumo e mover task para `REVIEW`

## Sprint 0 - Review

- A planilha atual diverge do prompt: a aba relevante se chama `EQUIPAMENTOS - MAIO`.
- A aba `EQUIPAMENTOS - MAIO` nao contem o inventario fisico completo. Ela funciona como curadoria parcial de valores, observacoes e alguns seriais.
- A contagem atual observada na aba antiga e `1069` linhas fisicas, nao `1064`.
- A aba `CABOS` existe e concentra os lotes genericos de cabo fora da estrutura tabular das abas de equipamentos.
- O pipeline final usou `1050` linhas uteis em `EQUIPAMENTOS`, com `520` serials individuais e `530` unidades agregadas em `50` lotes.
- O Supabase remoto foi validado com `277` items, `520` serial_numbers e `50` lotes, e as tabelas alvo ficaram com `rls=True` e `1` policy cada.

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
- [x] Trocar a logica de `Valor Atual` para refletir mercado atual/proxy de mercado, nao depreciacao fixa
- [x] Regenerar `data/valores-para-importacao.md` e medir o impacto da nova regra
- [x] Reaplicar os novos `Valor Atual` no `.xlsx` e validar dashboard e maiores itens

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
- A rodada de saneamento de realidade elevou `manual_web_curado` para `171` linhas seriais e derrubou estimativas distorcidas em wireless, microfones, caixas de 12", mesas Behringer e subwoofer Mackie.
- O exportador passou a incluir seriais `MMD-*` sem `Nome`, reaproveitando `Subcategoria` como fallback, o que fechou os 4 codigos `SUP TV` que estavam fora do pipeline.
- O `apply-pricing-markdown.py` foi corrigido para recalcular o dashboard com todas as 8 abas precificadas, preencher `Valor Atual` por categoria, atualizar a tabela de status e regenerar o top 10.
- A reaplicacao final ficou com `520` linhas por `Codigo`, `0` codigos orfaos e `0` vazios reais em `Valor Original`, `Valor Atual` e `Deprec.%` para todos os seriais `MMD-*`.
- O dashboard final passou a refletir `520` itens, `Valor Original = R$ 824.794,29` e `Valor Atual = R$ 335.250,39`.
- Os principais grupos ainda em estimativa explicita ficaram concentrados em iluminacao sem preco publico rastreavel, sobretudo `ST-32T`, `ST-LS6`, `ST-960PS`, `NE-117G-I` e `LP-354`.
- A rodada final de iluminacao substituiu esses 5 grupos por `manual_web_curado`, com ancora direta ou equivalente de mercado para `ST-LS6`, `ST-960PS`, `LP-354`, `ST-32T` e `NE-117G-I`.
- A base reaplicada e validada nesta rodada fechou em `519` seriais `MMD-*`, `0` vazios e dashboard em `Valor Original = R$ 796.323,50` e `Valor Atual = R$ 327.362,74`.
- Ainda restam `159` linhas em estimativa explicita no markdown, mas nenhuma delas pertence mais aos 5 blocos de maior impacto que estavam distorcendo a planilha.
- O fluxo de reaplicacao agora deixa `Deprec.%` como formula da planilha, em vez de gravar um numero estatico vindo do markdown.
- O dashboard da reaplicacao passou a mostrar depreciacao como perda patrimonial (`Valor Original - Valor Atual`), nao como percentual remanescente.
- A validacao de regressao cobre o caso real em que o markdown traz `26%`, mas a planilha precisa expor `74%` de depreciacao para `R$ 950,00 -> R$ 247,00`.
- A regra desta rodada passou a preservar `Valor Original` exatamente como esta na planilha e tratar `Valor Atual` como preco geral de mercado em `2026-04-03`, com depreciacao calculada apenas como `Valor Original - Valor Atual`.
- Foram incorporados overrides curados de mercado atual para itens de maior divergencia, incluindo `ST-XQDFS24 - BLINDADA`, `ST-X251LAY`, `DXS12`, `Art 712-A`, `XDJ-RR PIONEER`, `DDJ-400 PIONEER`, `8003-AS II 2200W` e `PARA MICROFONE SM58`.
- A reaplicacao desta rodada atualizou `519` linhas, manteve `0` codigos orfaos e elevou o dashboard para `Valor Original = R$ 796.323,50` e `Valor Atual = R$ 708.392,39`.
- O maior descolamento identificado vinha do uso antigo de depreciacao/fallback local em vez de mercado atual, com destaque para `8003-AS II 2200W`, `K8/K10`, `Evox J8`, `X32 RACK`, `XDJ-RX PIONEER` e `DXS12`.
- Ainda restam muitas linhas em fallback explicito ou estimativa no markdown, mas a base agora diferencia claramente o que veio de pesquisa web atual (`web_atual_curado`) do que ainda depende de proxy ou historico local.
- O registro `PARA MICROFONE SM58` tinha sido interpretado errado como acessorio; apos correcao do Marco, ele foi reaplicado como o proprio microfone `Shure SM58`, subindo de `R$ 30,00` para `R$ 1.119,00` e levando o dashboard a `Valor Atual = R$ 709.481,39`.
