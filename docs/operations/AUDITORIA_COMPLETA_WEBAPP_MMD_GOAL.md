# Auditoria Completa do WebApp MMD: Trava antes do Goal

## Missão

Mapear tudo que o WebApp MMD já entrega, tudo que existe pela metade e tudo que falta para cumprir as fontes canônicas, com evidência de código, runtime, testes e backend.

## Premissa central

*Arquivo existente não prova feature pronta. Só comportamento alcançável, dado real e teste executado contam como construído.*

## Contexto

O WebApp acumulou rotas, componentes, migrations, fluxos operacionais e referências históricas. O cliente precisa de um inventário confiável para separar produto ativo, implementação parcial, código legado e promessa ainda ausente.

## Mapa do sistema

- Entrada: rotas, componentes, APIs, dados, migrations, testes, docs e runtime autenticado.
- Processamento: inventário, rastreamento de fluxo, execução, comparação com requisitos e classificação por evidência.
- Saída: mapa completo do produto com estado, prova, gap, risco e próxima decisão.
- Fronteira de confiança: código executado e dados observados. Nome de arquivo, mock e comentário não bastam.

## Regras duras

- Trabalhar em modo read-only. Não corrigir findings durante a auditoria.
- Inspecionar código e renderização. Não concluir por uma única fonte.
- Classificar cada capacidade como pronta, parcial, ausente, quebrada, legado ou inacessível.
- Separar UI, backend, persistência, segurança, teste e deploy para cada capacidade.
- Distinguir dados reais, fixtures, mocks e screenshots.
- Mapear todos os caminhos de escrita até o Supabase.
- Identificar rotas órfãs, componentes sem caller e ações sem consequência persistente.
- Registrar evidência reproduzível para cada conclusão importante.
- Não transformar opinião visual em blocker funcional.
- Não declarar ausência antes de buscar aliases, rotas internas e implementação legada.

## Fonte da verdade

- Código atual de `apps/web`, `supabase`, testes e configurações de deploy.
- `AGENTS.md`, `CONTEXT.md`, `docs/mar-171-agent-brief.md`, ADRs e issues ativas.
- Runtime local e Supabase local. Remoto entra apenas em leitura e smoke autorizado.

## Papéis obrigatórios

- Supervisor: mantém taxonomia, cobertura e evidência.
- Auditor Produto: inventaria rotas, telas, ações e jornadas.
- Auditor Técnico: rastreia APIs, dados, Auth, RLS, testes e deploy.
- Reviewer Adversarial: procura falso pronto, código órfão e gaps omitidos.

## Entregas

- Relatório Markdown canônico da auditoria.
- Matriz por capacidade com UI, backend, dados, testes, segurança e estado.
- Mapa de rotas, APIs e dependências.
- Jornadas críticas executadas no navegador.
- Lista priorizada do que falta, com bloqueios e ordem recomendada.
- Inventário de legado, código órfão e riscos de produção.
- Resumo executivo curto para Marco.

## Definition of Done

- [ ] Todas as rotas Web conhecidas foram abertas ou classificadas com motivo verificável.
- [ ] Cada ação visível foi ligada ao efeito server-side ou marcada como sem efeito.
- [ ] Cada API e server action possui callers, autorização e persistência mapeados.
- [ ] Auth, RLS e exposição pública aparecem na matriz.
- [ ] Testes, lint e build foram executados e os resultados entraram no relatório.
- [ ] Jornadas de catálogo, Evento, packing, checkout, retorno, QR público e treinamento foram verificadas.
- [ ] Mocks e dados reais aparecem separados.
- [ ] O relatório distingue construído, parcial, ausente, quebrado e legado.
- [ ] Cada gap P0 ou P1 possui evidência e consequência de produto.
- [ ] Reviewer adversarial não encontra superfície importante omitida.
- [ ] Nenhum arquivo de produto foi alterado.

## Frase final de aceite

**Marco pode apontar qualquer capacidade do WebApp e ver o que existe, a prova e o gap, mas a auditoria não pode chamar arquivo parado de produto pronto.**
