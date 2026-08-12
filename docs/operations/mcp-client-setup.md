# Operação do cliente MCP MMD

Estado: protocolo e catálogo estão implementados e testados, mas a rota remota responde `503 mcp_token_exchange_required`. Não publicar nem cadastrar cliente de produção antes de token exchange, deploy autorizado e migration aplicada.

## Endereço e autenticação

O servidor remoto pretendido fica em `https://SEU_DOMINIO/api/mcp`. Ele aceitará Streamable HTTP e também o handshake de compatibilidade `2025-11-25` usado por hosts atuais. Hoje a rota está bloqueada por segurança.

Depois do token exchange, cada chamada exigirá:

1. `Authorization: Bearer <token MCP com audiência da URL MCP>`.
2. `x-mmd-mcp-request-id: <id estável da tentativa>`, ou um ID JSON-RPC estável que o servidor consegue derivar.

O bearer MCP identifica a pessoa e o cliente OAuth registrado limita e revoga o agente. Nunca aceite um JWT de sessão web Supabase diretamente nesta rota, nem o repasse para a Data API. Não use `SUPABASE_SERVICE_ROLE_KEY`, token de QR ou URL assinada como credencial MCP.

Antes de liberar o endpoint, configure `MMD_MCP_RESOURCE_URL` como a URL HTTPS exata de `/api/mcp`, `MMD_MCP_AUTHORIZATION_SERVER` como o Authorization Server HTTPS que emite tokens próprios para esse resource e `MMD_MCP_ALLOWED_ORIGINS` somente quando houver cliente browser com Origin conhecido. Sem os dois primeiros, o metadata OAuth não é publicado. Sem Origin enviado, o desktop client continua aceito; Origin não listado falha fechado.

## Cadastro e revogação

`mcp_clients` é o registro de revogação do cliente. O token exchange precisa guardar credencial de cliente com KDF ou HMAC com pepper e rotação, nunca segredo simples em config local. Cadastre um ID único, escopos mínimos (`mcp:read` agora) e marque `active=false` com `revoked_at` ao revogar.

O servidor registra em `mcp_operation_log`: cliente, ator, ferramenta, ID da tentativa, hash, intenção, resultado, correlação e recibo opcional. Token, segredo e payload livre não entram no log. Reutilizar a mesma tentativa com outro payload falha como conflito. O limite distribuído implementado usa `mcp_rate_limit_buckets` por cliente e ator, com 60 chamadas por minuto por padrão. Antes de expor a rota, o edge/WAF também precisa limitar por IP antes de autenticar. Se a reserva de limite não responder, o endpoint falha fechado.

## Manifesto atual

Após o token exchange, o cliente poderá descobrir e ler:

- `mmd://eventos/{evento_id}`
- `mmd://unidades/{unidade_id}`
- `mmd_consultar_evento({ evento_id })`

Todas são somente leitura. Não há ferramenta de saída, retorno, RFID, packing ou pendência disponível. A confirmação do hospedeiro e o ACK persistido entram apenas quando o backend concluir o envelope transacional de mutação.

## Claude Code

Depois de o fluxo OAuth estar habilitado, use transporte HTTP. Não injete segredo proprietário de longa duração como cabeçalho por chamada:

```bash
claude mcp add --transport http mmd-eventos https://SEU_DOMINIO/api/mcp \
  --client-id SEU_CLIENT_ID
```

## ChatGPT Developer Mode

Cadastre a URL HTTPS remota e conclua OAuth somente depois de o emissor em `MMD_MCP_AUTHORIZATION_SERVER` estar configurado e validado. O metadata protegido será `/.well-known/oauth-protected-resource/mcp`. Sem esse emissor e deploy HTTPS, mantenha o conector indisponível: não há fallback demo, token técnico universal ou bypass de RLS.

## Provas locais atuais

- `npm run test:mcp`: descoberta e leitura pelos SDKs oficial moderno e legado, bearer ausente, Origin malicioso, DTO allowlist e metadata OAuth.
- `supabase/tests/mcp_registry_test.sql`: persiste os alvos de Evento e Unidade contra a CHECK real do registry e rejeita o template com chaves, tudo em transação com rollback.
- `npm run lint` e `npm run build`: endpoint `/api/mcp` e metadata compilam na app Next.
- A migration do registry é executada dentro de transação e rollback contra o Postgres local, sem gravar dados.

Ainda falta: Authorization Server ou token exchange que valide `iss`, `aud`, expiração e escopo MCP, e emita credencial downstream separada para RLS; limite pré-auth no WAF/edge; migration aplicada em ambiente alvo; URL HTTPS publicada e smoke nos dois clientes remotos. Deploy requer autorização nova.
