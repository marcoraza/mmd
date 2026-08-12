# Plano de execução: agente operacional do cliente MMD

Trava: `docs/operations/AGENTE_OPERACIONAL_CLIENTE_MMD_GOAL.md`

1. Inventariar fontes canônicas e marcar conflitos ou material histórico.
2. Definir a pasta final, manifesto e ordem de leitura antes de escrever conteúdo.
3. Construir modelo de domínio, glossário, papéis e matriz de permissões.
4. Documentar capacidades do produto com estado construído, parcial ou futuro.
5. Escrever workflows completos de consulta e ação.
6. Integrar o catálogo MCP quando a task correspondente estabilizar ferramentas e recursos.
7. Escrever safety, confirmações, limites e comportamento diante de incerteza.
8. Criar cenários e evals que cubram caminho feliz, falhas e ataques.
9. Rodar dois agentes independentes contra a pasta sem contexto da sessão.
10. Corrigir gaps até os evals e o Red Team fecharem limpos.

Dependências vivas:
- `MMD · Event Pro backend completo`, thread `019ff6c0-bc3c-7ce3-89de-b67aa732ed0e`.
- Task do MCP do cliente criada junto desta execução.
- Task da auditoria completa do WebApp criada junto desta execução.

Skills ativáveis:
- `mattpocock-writing-for-agents`: estrutura e instruções executáveis.
- `mattpocock-domain-modeling`: vocabulário e invariantes.
- `mattpocock-teach`: progressão do treinamento.
- `hardikpandya-stop-slop`: clareza e densidade.
- `raza-100`: convergência adversarial dos evals.
- `supabase:supabase`: validar o que é dado vivo e permissão real.

Condição de parada: a pasta passa pelos evals com agentes sem contexto externo e contém apenas capacidades comprovadas ou marcadas como futuras.
