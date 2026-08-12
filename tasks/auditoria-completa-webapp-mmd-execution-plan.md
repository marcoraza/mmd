# Plano de execução: auditoria completa do WebApp MMD

Trava: `docs/operations/AUDITORIA_COMPLETA_WEBAPP_MMD_GOAL.md`

1. Fixar commit, ambiente, fontes canônicas e taxonomia de estados.
2. Inventariar rotas, layouts, componentes, server actions, APIs e testes com busca estática.
3. Mapear Supabase, Auth, RLS, Storage, Realtime e migrations consumidas pelo Web.
4. Executar install, testes, lint, typecheck e build sem alterar código.
5. Subir Web e Supabase local com fixtures identificadas.
6. Percorrer todas as rotas e jornadas no navegador em desktop e mobile Web.
7. Rastrear cada ação visível até persistência, erro e auditoria.
8. Comparar capacidades observadas com brief, CONTEXT, ADRs e issues.
9. Produzir matriz e relatório com evidência, risco e ordem de fechamento.
10. Rodar auditor adversarial independente e corrigir apenas o relatório.

Skills ativáveis:
- `shadcn-improve`: survey read-only e planos autocontidos.
- `raza-codemap`: mapa visual da arquitetura.
- `browser:control-in-app-browser`: prova das rotas e jornadas.
- `supabase:supabase`: leitura de schema, Auth e RLS.
- `mattpocock-code-review`: método de evidência contra standards e spec.
- `tushar-remove-ai-slop`: identificar padrões genéricos no visual sem misturar com bugs.

Condição de parada: relatório cobre a superfície Web inteira, passa pelo reviewer e deixa cada capacidade com estado e prova reproduzível.
