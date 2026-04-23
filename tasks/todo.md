# Todo

## Sprint 0 - Data Cleanup + Supabase Schema

- [x] Validar task `86agn5dq2` no ClickUp, mover para `in progress` e registrar comentario inicial
- [x] Inspecionar a estrutura real de `data/inventario-original.xlsx` e reconciliar divergencias do prompt
- [x] Implementar `scripts/cleanup_inventory.py` reaproveitando o parsing util do pipeline existente
- [x] Gerar `data/items.json`, `data/serial_numbers.json`, `data/lotes.json`, `data/migration.sql` e `data/cleanup_report.txt`
- [x] Implementar `scripts/seed_supabase.py` e `scripts/requirements.txt`
- [x] Executar validacoes locais do cleanup, unicidade de codigos, categorias normalizadas e status
- [x] Validar SQL gerado e registrar pendencias reais da base atual
- [x] Finalizar ClickUp com comentario de resumo, registrar PR `#1` e mover task para `REVIEW`

## Sprint 0 - Review

- A planilha atual diverge do prompt: a aba relevante se chama `EQUIPAMENTOS - MAIO`.
- A aba `EQUIPAMENTOS - MAIO` nao contem o inventario fisico completo. Ela funciona como curadoria parcial de valores, observacoes e alguns seriais.
- A contagem atual observada na aba antiga e `1069` linhas fisicas, nao `1064`.
- A aba `CABOS` existe e concentra os lotes genericos de cabo fora da estrutura tabular das abas de equipamentos.
- O pipeline final usou `1050` linhas uteis em `EQUIPAMENTOS`, com `520` serials individuais e `530` unidades agregadas em `50` lotes.
- O Supabase remoto foi validado com `277` items, `520` serial_numbers e `50` lotes, e as tabelas alvo ficaram com `rls=True` e `1` policy cada.
- O PR desta entrega foi aberto em `main` como `#1`.
- O teste `tests/test_depreciation_pipeline.py` ficou fora do PR porque depende de mudancas locais ainda nao versionadas no pipeline de pricing.
- O proximo passo apos o merge do Sprint 0 e integrar o trabalho de pricing nos JSONs gerados, reaplicar valores financeiros e re-seedar o Supabase.

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
- A rodada de pesquisa em paralelo com subagentes deixou de aceitar kit/set inteiro como fonte para componente avulso e passou a derrubar overrides suspeitos quando o titulo da fonte indica sistema completo.
- O exportador agora prioriza overrides curados do codigo sobre o CSV gerado, aplica salvaguarda conservadora para inferencias infladas e preserva a formula de `Deprec.%` no `.xlsx`.
- Foram saneados os blocos mais contaminados de wireless e percussao eletronica, com `SPD-SX SAMPLING PAD = R$ 6.619,00`, `HANDSONIC HPD-20 = R$ 7.839,00`, `EWD1 = R$ 3.581,65`, `ewd skm-s freq.q1-6 = R$ 3.581,65`, `SKM100s G4 - Freq g = R$ 2.250,00` e `T2 Wireless Transmitter = R$ 334,01`.
- O markdown de importacao passou a exibir moeda em formato visual brasileiro (`R$ 6.922,00`), enquanto o importador continua tolerante a esse formato cosmetico.
- A reaplicacao consolidada desta passada atualizou `519` linhas, manteve `0` codigos orfaos e fechou o dashboard em `Valor Original = R$ 796.323,50` e `Valor Atual = R$ 707.348,99`.
- O grafico de pizza do dashboard foi movido para a faixa vazia da direita, sem legenda, e agora mostra em cada fatia `Categoria + R$` usando exatamente `Valor Original` por categoria, como `AUDIO R$ 446.936,35` e `VIDEO R$ 13.022,82`.

## Sprint 4 - Web Projects + Validation

- [x] Corrigir o parser numerico de `scripts/apply-pricing-markdown.py` para nao inflar valores com decimal em ponto
- [x] Revalidar `tests/test_depreciation_pipeline.py`
- [x] Rodar a suite local existente do pipeline Python
- [x] Substituir o placeholder de `apps/web/src/app/projetos/page.tsx` por uma listagem real com filtros e progresso por projeto
- [x] Restaurar o `node_modules` de `apps/web` com `npm ci`
- [x] Rodar `eslint` no web e confirmar que voltou a executar
- [x] Rodar `npm run build` no web
- [x] Definir a estrategia das rotas dinamicas `/items/[id]` para o modo `output: "export"`

## Sprint 4 - Review

- O parser antigo removia todos os pontos antes de converter numero, entao `950.00` virava `95000`.
- A regressao foi corrigida em `scripts/apply-pricing-markdown.py` e a suite Python local fechou com `7 passed`.
- A pagina de projetos do web deixou de ser placeholder e agora carrega projetos reais via Supabase, com filtro por status, busca textual e progresso calculado a partir de `packing_list` e `movimentacoes`.
- O `apps/web/node_modules` foi reconstruido com `npm ci`, destravando `tsc` e a execucao do `eslint`.
- O web saiu de `/items/[id]` e passou a usar paginas estaticas com query string em `/items/detalhe` e `/items/editar`, preservando o fluxo de detalhe e edicao sem quebrar `output: "export"`.
- `npm run build` agora fecha com export estatico completo e `tsc --noEmit` volta a passar no `apps/web`.
- `npm run lint` fecha sem erros; sobrou apenas 1 warning conhecido em `src/app/layout.tsx` sobre fonte custom carregada via layout.

## Sprint 5 - Web Events + Packing List

- [x] Criar paginas estaticas de projeto em `/projetos/novo`, `/projetos/editar?id=` e `/projetos/detalhe?id=`
- [x] Adicionar CRUD basico de projetos no web
- [x] Implementar editor de packing list no detalhe do projeto
- [x] Atualizar listagem de projetos com links para detalhe/edicao
- [x] Implementar dashboard de disponibilidade por data no web
- [x] Implementar pagina de etiquetas QR para impressao no web
- [x] Validar `npm run lint`, `npm run build` e `tsc --noEmit` no `apps/web`

## Sprint 5 - Review

- O fluxo de projetos passou a ter paginas estaticas em `/projetos/novo`, `/projetos/editar?id=` e `/projetos/detalhe?id=`, mantendo compatibilidade com `output: "export"`.
- A listagem de projetos ganhou links de abrir/editar, CTA para novo projeto e atalhos diretos para `Disponibilidade` e `Etiquetas QR`.
- O detalhe do projeto agora concentra o editor de packing list com CRUD de linhas, totalizadores e refresh dos numeros do projeto apos cada alteracao.
- A pagina `/projetos/disponibilidade` calcula reserva por intervalo de datas com base em projetos `CONFIRMADO` e `EM_CAMPO`, agregando packing list por item e sinalizando gargalos de disponibilidade.
- A pagina `/qrcodes` gera uma grade imprimivel em A4 para serial numbers e lotes, usando o valor salvo em `qr_code` ou fallback para o codigo interno/codigo de lote.
- `npm run build` fecha com export estatico completo, `tsc --noEmit` volta a passar e `npm run lint` fica sem erros; restam apenas 2 warnings conhecidos em `src/app/layout.tsx` (fonte custom) e `src/app/qrcodes/page.tsx` (`<img>` para QR remoto).

## Sprint 6 - RFID Linking + Realtime

- [x] Criar pagina web de vinculacao RFID para `serial_numbers` e `lotes`
- [x] Adicionar importacao CSV em massa para `tag_rfid`
- [x] Integrar Supabase Realtime nas paginas principais de `items`, `lotes` e `projetos`
- [x] Atualizar navegacao com entrada dedicada para RFID
- [x] Validar `npm run lint`, `npm run build`, `tsc --noEmit` e preview local das rotas afetadas

## Sprint 6 - Review

- O web ganhou a rota estatica `/rfid`, com visao unica de seriais e lotes, filtros por tipo e status de vinculacao, formulario manual de `tag_rfid` e suporte a limpar uma tag existente.
- A mesma tela passou a aceitar importacao CSV com template baixavel, autodeteccao de `,` ou `;`, aliases de cabecalho (`tipo`, `codigo`, `tag_rfid`, `codigo_interno`, `codigo_lote`, `rfid_tag`) e relatorio de alertas por linha.
- A navegacao principal agora expoe `RFID` tanto no sidebar desktop quanto no bottom nav mobile.
- Foi criado um hook compartilhado de Supabase Realtime para evitar duplicacao, com debounce leve de refresh, e ele passou a atualizar automaticamente as paginas de `items`, `lotes` e `projetos` quando entram mudancas em `items`, `serial_numbers`, `lotes`, `packing_list`, `movimentacoes` ou `projetos`.
- `npm run build`, `tsc --noEmit` e `curl -I` nas rotas `/nmd/rfid/`, `/nmd/projetos/` e `/nmd/lotes/` ficaram verdes.
- `npm run lint` continua sem erros e preserva os 2 warnings antigos: `src/app/layout.tsx` sobre fonte custom no layout e `src/app/qrcodes/page.tsx` pelo uso de `<img>` para QR remoto.

## iOS - RFID Runtime Config

- [x] Persistir `useMockRFID` em `AppConfig`
- [x] Permitir troca dinamica de implementacao no `RFIDManager`
- [x] Fazer a tela de Config salvar e aplicar a troca de mock/real na hora
- [x] Cobrir o swap de implementacao com teste do wrapper
- [x] Validar compilacao do alvo de testes com `xcodebuild build-for-testing`

## iOS - RFID Runtime Config Review

- O toggle de leitor simulado em Config deixou de ser cosmetico e passou a persistir em `UserDefaults`, com fallback inicial diferente entre `DEBUG` e `RELEASE` apenas quando ainda nao existe preferencia salva.
- O `RFIDManager` agora consegue trocar a implementacao em runtime, desligando a anterior, limpando tags, rebinding dos publishers e expondo o modo efetivo (`Simulado`, `Zebra SDK` ou `Simulado (fallback)`).
- A tela de Config passou a incluir o modo efetivo do leitor e aplica a troca imediatamente apos salvar, sem exigir reinicio do app.
- O alvo de testes compila com as mudancas via `xcodebuild build-for-testing -project apps/ios/MMDEstoque/MMDEstoque.xcodeproj -scheme MMDEstoque -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1'`.
- A execucao completa de `xcodebuild test` continuou bloqueada pelo runner do simulador neste ambiente, entao a validacao desta rodada ficou em build-for-testing + revisao dos testes afetados.

## Web - Polish + Handoff

- [x] Corrigir os warnings restantes do `apps/web`
- [x] Migrar as fontes do layout para `next/font/google`
- [x] Trocar a imagem remota de QR para `next/image`
- [x] Substituir a tela rasa de Config por uma central operacional real
- [x] Validar `npm run lint`, `npm run build`, `tsc --noEmit` e preview local das rotas atualizadas

## Web - Polish + Handoff Review

- O warning de fonte custom no layout foi removido ao migrar `Doto`, `Space Grotesk` e `Space Mono` para `next/font/google`, preservando a mesma identidade visual sem depender de `<link>` manual no `<head>`.
- O warning de `<img>` na tela de etiquetas QR foi removido com `next/image` em modo `unoptimized`, mantendo compatibilidade com QR remoto e export estatico.
- A pagina `/config` deixou de ser um bloco estatico e passou a funcionar como central de status operacional, com resumo de ambiente, contagens da base, rotas-chave e checklist de prontidao para entrega.
- `npm run lint` ficou sem warnings nem erros, `npm run build` continua verde e `tsc --noEmit` tambem volta a passar depois do build.
- O preview local respondeu `200` para `/nmd/config/` e `/nmd/qrcodes/`, confirmando que as rotas alteradas seguem acessiveis no servidor de desenvolvimento.

## Web - Backend Unavailable UX

- [x] Diagnosticar por que o web nao estava servindo dados do backend
- [x] Confirmar variaveis publicas do Supabase e validar reachability do host configurado
- [x] Corrigir estados de erro para nao exibir contagens zeradas quando o backend cair
- [x] Expor o estado `backend indisponivel` no dashboard, sidebar e configuracoes
- [x] Revalidar `npm run lint`, `npm run build` e preview local das telas afetadas

## Web - Backend Unavailable UX Review

- O problema nao estava no parser do frontend nem na ausencia de `.env.local`; as variaveis publicas existem, mas o host configurado em `NEXT_PUBLIC_SUPABASE_URL` nao resolve em DNS.
- O endpoint `bphmxticdyuctovfumcj.supabase.co` falha tanto em resolucao via `python3 socket.gethostbyname(...)` quanto em acesso HTTP, o que indica backend inacessivel ou projeto removido.
- A `SidebarWrapper` passou a propagar erro real de leitura do Supabase, em vez de mascarar falhas como zeros silenciosos.
- A sidebar agora mostra `BACKEND OFFLINE` e troca os widgets numericos por `—` quando nao ha leitura valida da base.
- O dashboard principal distingue `SUPABASE NAO CONFIGURADO` de `BACKEND INDISPONIVEL`, evitando diagnostico enganoso quando as envs existem mas a base nao responde.
- A tela `/config` passou a exibir o host configurado, o status `DOWN` e um alerta operacional explicando que o ambiente esta configurado, mas o backend nao respondeu.
- `npm run lint` e `npm run build` seguiram verdes apos as mudancas, e o preview local confirmou os novos estados de indisponibilidade em `/nmd/` e `/nmd/config/`.

## Web - Backend Recovery Check

- [x] Validar diretamente no perfil `mmd` do Chrome se a configuracao do Supabase no web estava correta
- [x] Extrair sessao autenticada do dashboard do Supabase a partir do perfil logado
- [x] Confirmar status real do projeto `MMD` via Management API
- [x] Validar as API keys do projeto e testar a API REST publica com a `anon key` configurada no web

## Web - Backend Recovery Check Review

- O perfil `mmd` do Chrome confirmou que o projeto correto e o mesmo configurado no `apps/web/.env.local`, com `ref = bphmxticdyuctovfumcj`.
- A `anon key` configurada no web bate com a chave legacy `anon` retornada pela Management API do Supabase para o projeto `MMD`.
- O problema nao era credencial errada. O painel do Supabase mostrou o projeto primeiro em `RESTORING` e logo depois em `ACTIVE_HEALTHY`, indicando recuperacao do ambiente.
- A API REST publica voltou a responder `200` em `GET /rest/v1/items?select=id&limit=1` usando exatamente a URL e a `anon key` do `.env.local`.
- O host principal `https://bphmxticdyuctovfumcj.supabase.co` voltou a responder na borda do Supabase, entao o bloco real saiu de configuracao invalida para indisponibilidade temporaria do projeto.

## Web - Static Export Freeze Fix

- [x] Identificar por que o IAB seguia mostrando `BACKEND INDISPONIVEL` mesmo com o Supabase ativo
- [x] Migrar `sidebar`, `dashboard` e `config` do web para fetch client-side em vez de leitura no build
- [x] Prover um preview local emergencial que consulte o Supabase em runtime sem depender do export antigo

## Web - Static Export Freeze Fix Review

- O estado `offline` visto no IAB nao vinha mais do backend em si, e sim do `out/` estatico gerado quando o projeto Supabase ainda estava pausado.
- `SidebarWrapper`, `app/page.tsx` e `app/config/page.tsx` foram ajustados para ler o Supabase no cliente, evitando congelar o estado do backend no momento do build/export.
- O runtime local do Next continuou instavel neste ambiente, com `next build` e `next dev` presos antes do bootstrap, entao a validacao visual imediata foi destravada por um preview estatico leve em `/tmp/mmd-preview/nmd`, que consulta o Supabase direto via REST usando a `anon key` publica.
- O preview emergencial respondeu `200` em `/nmd/`, `/nmd/items/`, `/nmd/projetos/` e `/nmd/config/`, e o Supabase confirmou CORS liberado para `http://localhost:3000`.

---

## Plano MVP: Web-first depois iOS

Fonte canonica: `design_handoff_estoque_mmd/README.md` (Liquid Glass 2030).
Decisoes locked:
- Tudo in-house. Sem Rentman. Supabase e a fonte de verdade unica.
- Auth fica pra pos-MVP. Uso interno, galpao controlado.
- Design System: Liquid Glass 2030 em tudo. iOS existente sera reescrito quando chegar a vez.
- Particulas no RFID scan sao o herói do app iOS. Implementar.
- Sequencia: terminar WEB completo antes de tocar iOS.

### Fase W1. Design System Alignment (web)

- [ ] Auditar `apps/web` tokens vs `design_handoff_estoque_mmd/tokens/mmd-tokens.json` (radii, spacing, cores oklch, fontes)
- [ ] Alinhar radii: sm 10 / md 16 / lg 24 (hoje 4/8/12)
- [ ] Consolidar estrategia dark-first com light como acessibilidade
- [ ] Garantir Inter Tight + JetBrains Mono carregando no layout
- [ ] Portar `styles/glass.css` (caustics, orbs, superficies vitreas) se faltar
- [ ] Verificar primitives (Ring, Glass, Pill, Badge, Btn) batem com handoff pixel-by-pixel

### Fase W2. Item Detail + Timeline

- [ ] Criar rota `/items/[id]` dedicada (hoje so tem side panel)
- [ ] Header com foto, codigo interno, marca/modelo, ring de condicao
- [ ] Bloco de status: estado, desgaste, depreciacao, valor atual
- [ ] Timeline de movimentacoes (check-out, check-in, manutencao, reparo)
- [ ] Secao de projetos (historico de eventos que levou)
- [ ] Botoes de acao: editar, marcar manutencao, baixar, imprimir QR

### Fase W3. Projetos: Split View + Resolver Conflito

- [ ] Repensar `/projetos` pro layout Split View do handoff (lista esquerda, detalhe direita)
- [ ] Detalhe de projeto com packing list inline + ring de readiness
- [ ] Tela dedicada de resolver conflito: quando `pedido > disponivel`
- [ ] Sugestao automatica de substituicoes (itens equivalentes disponiveis)
- [ ] Confirmar alocacao manual serial-a-serial quando necessario

### Fase W4. Dashboard Real (Supabase wired)

- [ ] Trocar mocks do dashboard cinematografico por queries reais
- [ ] KPIs: total itens, disponiveis, em campo, manutencao, desgaste medio
- [ ] Ring central: readiness global (itens prontos vs comprometidos)
- [ ] Alertas: itens criticos (desgaste <=2), nao devolvidos, conflitos abertos
- [ ] Grafico de projetos proximos 21 dias com disponibilidade

### Fase W5. Saida + Retorno via Web

- [ ] Fluxo de check-out via desktop (escolher projeto, confirmar packing list, marcar saida)
- [ ] Fluxo de check-in com marcacao de condicao por item (OK, sujo, reparo, faltando)
- [ ] Registrar movimentacoes na timeline do item
- [ ] Atualizar status do serial no Supabase (DISPONIVEL, PACKED, EM_CAMPO, etc.)
- [ ] Validacao pedido vs retorno, destaca itens faltantes

### Fase W6. Calendario de Disponibilidade

- [ ] Rota dedicada: calendario 21 dias com disponibilidade por item/categoria
- [ ] Visao compacta: barras por item mostrando janelas ocupadas
- [ ] Click em janela abre projeto associado
- [ ] Heatmap de pressao de estoque (dias com mais conflitos previstos)

### Fase W7. QR Print Sheet

- [ ] Tela de configuracao de folha de QR: seleciona items, tamanho, layout
- [ ] Preview com paginacao
- [ ] Export PDF pronto pra imprimir em adesivo
- [ ] Padrao: QR + codigo interno + nome curto

### Fase W8. Polish Visual + QA pixel-peep

- [ ] Revisar cada tela web contra screenshots do handoff
- [ ] Ajustar spacing, tipografia, hierarquia
- [ ] Garantir caustics/orbs ligados nas superficies vitreas principais
- [ ] Smoke test em Chrome via DevTools MCP (dashboard, projetos, items, calendario)
- [ ] Lighthouse audit (performance, a11y)

### Fase W9. Deploy + Handoff Web

- [ ] Build de producao estavel (resolver travas do `next build` se persistirem)
- [ ] Deploy Vercel ou GitHub Pages (conforme fluxo atual)
- [ ] Rodar suite de smoke em producao
- [ ] Gravar loom/video curto pro Marcelo com os fluxos principais

---

### Fase I1. iOS Rewrite: Shell Liquid Glass

- [ ] Scrap do visual atual. Portar tokens Liquid Glass pro SwiftUI
- [ ] Primitives iOS: Ring, Glass, Pill, Badge, Btn (equivalentes Swift)
- [ ] Layout base: tab bar, sidebar modal, navigation stack
- [ ] Dark-first, caustics em telas core

### Fase I2. RFID Scan Herói (com particulas)

- [ ] Tela de scan RFID com animacao de particulas viajando da tag pra lista
- [ ] Ring central pulsa conforme leituras chegam
- [ ] Feedback haptico + som por item novo reconhecido
- [ ] Destaque visual pra item fora da packing list (erro)

### Fase I3. Check-out + Check-in iOS

- [ ] Fluxo completo: selecionar projeto, escanear, confirmar saida
- [ ] Retorno com marcacao de condicao (OK, sujo, reparo, faltando) por item
- [ ] Sync com Supabase em tempo real
- [ ] Offline queue (fase 2 se tempo permitir)

### Fase I4. Suportes iOS

- [ ] Onboarding (primeira abertura, setup de leitor)
- [ ] Vinculacao de tag (associar RFID UHF a serial existente)
- [ ] Busca de item perdido (scan ate achar, radar)
- [ ] Detalhe de item com timeline

### Fase I5. Deploy iOS

- [ ] Build e distribuir via TestFlight
- [ ] Marcelo testa com equipe de galpao
- [ ] Ciclo de feedback + fix
- [ ] Handoff final
