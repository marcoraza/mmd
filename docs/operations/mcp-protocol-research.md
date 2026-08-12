# Pesquisa de protocolo: MCP Cliente MMD

Data da verificação: 2026-08-12.

## Decisão

O servidor MMD usa **Streamable HTTP** no endpoint remoto único `/api/mcp`, apoiado no SDK oficial TypeScript v2:

- runtime: `@modelcontextprotocol/server@2.0.0`;
- smoke test: `@modelcontextprotocol/client@2.0.0`;
- protocolo primário: MCP `2026-07-28`, sem estado entre requests;
- compatibilidade: o handler do SDK aceita o handshake legado `2025-11-25` em modo stateless. Nenhuma sessão, credencial ou regra de domínio fica em memória do processo.

Essa é a menor arquitetura que funciona em Next.js Route Handler e atende clientes remotos atuais. Não foi adotado HTTP+SSE legado como transporte principal. SSE permanece uma possibilidade de resposta do Streamable HTTP, não uma rota paralela.

## O que a especificação exige

1. Streamable HTTP usa um endpoint que recebe `POST` e pode receber `GET`; o cliente envia mensagens JSON-RPC em `POST`. Uma resposta pode ser JSON ou SSE. A especificação substituiu o antigo HTTP+SSE. [Transportes MCP](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports)
2. Para `2026-07-28`, a negociação é por `server/discover` e cada request moderno carrega o envelope `_meta`. A linha 2 do SDK oficial suporta também a família `2025-11-25`, cuja negociação começa por `initialize`. [SDK TypeScript v2](https://github.com/modelcontextprotocol/typescript-sdk/tree/main/packages/server) e [ciclo de vida MCP](https://modelcontextprotocol.io/specification/2026-07-28/basic/lifecycle)
3. O servidor precisa validar `Origin` quando o header vier presente, para impedir DNS rebinding. Cliente local deve ficar em loopback. [Segurança do transporte](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports#security-warning)
4. Servidores HTTP protegidos expõem OAuth Protected Resource Metadata (RFC 9728), retornam `WWW-Authenticate` em falha de autenticação e anunciam o authorization server. Clientes descobrem o authorization server por OAuth Authorization Server Metadata ou OpenID Connect Discovery. [Autorização MCP](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization)
5. O protocolo não transforma dados retornados em instruções confiáveis. Texto de notas, itens, eventos e clientes deve seguir como dado para o agente hospedeiro, nunca alterar URI, escopo, ferramenta ou autorização no servidor.

## Modelo de segurança acordado

O endpoint MCP falha fechado em toda request. Ele não usa `requireRequestUser`, pois esse helper pode entregar admin local quando a autenticação da interface web está desligada.

O endpoint permanece fechado até haver um Authorization Server que emita um bearer MCP próprio, limitado ao resource URL, com emissor, audiência, expiração e escopo validados. Esse bearer não pode ser repassado à Data API. O token exchange futuro precisa produzir uma credencial downstream separada que preserve a identidade usada por RLS. `SUPABASE_SERVICE_ROLE_KEY` e `supabaseAdmin` são proibidos no caminho de dados MCP.

O log/auditoria de uma operação MCP deve guardar somente metadados permitidos: `mcp_operation_id`, `client_id`, `actor_id`, ferramenta ou recurso, intenção, `payload_hash`, chave de idempotência, consentimento, resultado ou erro e correlação. Token e payload sensível não entram em log. Mutações só entram depois de existir esse recibo persistido, idempotência no contrato canônico e confirmação humana quando aplicável.

## Clientes considerados

| Família | Configuração compatível | Limite da prova |
| --- | --- | --- |
| Claude Code | servidor remoto `http` ou `streamable-http` apontando para a URL HTTPS do `/api/mcp` | Claude Code recomenda HTTP para servidor remoto, suporta OAuth e mantém SSE como transporte antigo. [Documentação oficial](https://code.claude.com/docs/en/mcp) |
| ChatGPT Developer Mode | app MCP remoto com endpoint HTTPS e metadados OAuth | ChatGPT conecta apenas a servidores remotos, faz scan de ferramentas e pede confirmação para ações relevantes. A funcionalidade completa de escrita varia por plano e está em beta. [Documentação oficial](https://help.openai.com/en/articles/12584461-developer-mode-apps-and-full-mcp-connectors-in-chatgpt-beta) |
| Cliente oficial de smoke test | `@modelcontextprotocol/client@2.0.0` com `StreamableHTTPClientTransport` | Prova o protocolo v2 sem assumir comportamento proprietário de host. [SDK TypeScript v2](https://github.com/modelcontextprotocol/typescript-sdk/tree/main/packages/client) |

## Limites reais desta etapa

- A prova de descoberta e leitura em cliente real local pode usar o client oficial, mas a prova em Claude Code e ChatGPT depende de URL HTTPS pública ou túnel seguro, usuário Supabase real e consentimento de administrador do workspace.
- O ChatGPT não conecta diretamente a um servidor local. A documentação oficial indica Secure MCP Tunnel para servidor privado. Isso não autoriza deploy nem exposição pública.
- Sem deploy autorizado, não se declara smoke test remoto, conexão real com ChatGPT ou compatibilidade universal.
- Mutações não entram na primeira superfície até a dependência de backend consolidar contrato canônico, recibo, auditoria, idempotência e escopo.

## Modo degradado da pesquisa

A skill `mattpocock-research` pede um agente de pesquisa em background. O squad obrigatório ocupava todos os quatro slots disponíveis. Com autorização do supervisor, a pesquisa foi feita diretamente, apenas em fontes primárias: especificação MCP, repositório do SDK oficial e documentação oficial de Claude Code e ChatGPT. O arquivo preserva as fontes verificáveis e não usa fontes secundárias.
