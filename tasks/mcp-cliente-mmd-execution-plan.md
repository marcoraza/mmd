# Plano de execução: MCP do Cliente MMD

Trava: `docs/operations/MCP_CLIENTE_MMD_GOAL.md`

1. Ler o backend atual, o goal de fechamento sem iOS e os contratos que já chegaram ao remoto.
2. Pesquisar a especificação MCP atual e os requisitos de clientes de pelo menos duas famílias.
3. Escolher a menor arquitetura remota compatível com o deploy existente.
4. Fixar o modelo de identidade, scopes, confirmação e auditoria antes das ferramentas.
5. Construir primeiro um vertical read-only de Evento e Unidade.
6. Provar conexão local e remota com clientes reais.
7. Adicionar recursos e ferramentas por domínio, reutilizando contratos canônicos.
8. Adicionar mutações apenas quando o backend correspondente tiver idempotência e autorização fechadas.
9. Cobrir argumentos inválidos, perfil insuficiente, retry, timeout, injection e vazamento de secrets.
10. Produzir catálogo, exemplos de configuração e runbook operacional.
11. Rodar review de protocolo, domínio e segurança.
12. Fazer deploy com autorização específica. Sem deploy, entregar artefato pronto e prova local completa.

Dependência viva: task `MMD · Event Pro backend completo`, thread `019ff6c0-bc3c-7ce3-89de-b67aa732ed0e`.

Skills ativáveis:
- `mattpocock-research`: especificação e compatibilidade MCP.
- `mattpocock-domain-modeling`: recursos, ferramentas e vocabulário.
- `mattpocock-tdd`: contratos e segurança.
- `supabase:supabase`: dados, Auth e RLS.
- `mattpocock-code-review`: fechamento técnico.
- `raza-thermo`: review final por envolver Auth, permissões e dados do cliente.
- `gstack-careful`: antes de qualquer operação remota.

Condição de parada: servidor e documentação passam a Definition of Done ou existe um blocker externo comprovado que exige escolha do Marco sobre hospedagem, identidade ou ação destrutiva.
