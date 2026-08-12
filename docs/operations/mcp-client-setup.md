# Operação do cliente MCP MMD

Estado: protocolo, validação OAuth e leitura por capability estão implementados e testados localmente. A tela e a ação de consentimento estão implementadas, mas aguardam prova end-to-end com o Authorization Server habilitado. Sem a configuração completa, a rota responde `503 mcp_remote_not_configured`. Não publicar nem cadastrar cliente de produção antes de migrations aplicadas, OAuth habilitado, credencial técnica dedicada criada, WAF configurado e deploy autorizado.

## Endereço e autenticação

O servidor remoto pretendido fica em `https://SEU_DOMINIO/api/mcp`. Ele aceitará Streamable HTTP e também o handshake de compatibilidade `2025-11-25` usado por hosts atuais. Hoje a rota está bloqueada por segurança.

Cada chamada exige:

1. `Authorization: Bearer <token MCP com audiência da URL MCP>`.
2. `x-mmd-mcp-request-id: <id estável da tentativa>`, ou um ID JSON-RPC estável que o servidor consegue derivar.

O bearer MCP identifica a pessoa e o cliente OAuth registrado limita e revoga o agente. O hook emite `aud` igual a `MMD_MCP_RESOURCE_URL` e `mcp_scopes` iguais aos do registry. Nunca aceite um JWT de sessão web Supabase nesta rota, nem repasse o bearer MCP para a Data API. A aplicação emite uma capability aleatória de 256 bits para cada leitura e o banco guarda somente o hash, ator, cliente, alvo, `resource_id`, hash dos argumentos, expiração e consumo. `mmd_mcp_executor` não assume `authenticated`, não injeta claims e não lê tabela diretamente. As policies Web e as RPCs MCP usam o mesmo predicado de perfil ativo. Não use `SUPABASE_SERVICE_ROLE_KEY`, token de QR ou URL assinada como identidade MCP.

O metadata protegido não anuncia `mcp:read` ou `mcp:operate` como scopes OAuth. O Supabase OAuth ainda não aceita scopes granulares customizados. A autorização operacional vem exclusivamente do claim `mcp_scopes` emitido pelo hook a partir do registry, não do texto de scope pedido pelo cliente.

Antes de liberar o endpoint, configure `MMD_MCP_RESOURCE_URL` como a URL HTTPS exata de `/api/mcp`, `MMD_MCP_AUTHORIZATION_SERVER` como o Authorization Server HTTPS que emite tokens próprios para esse resource e `MMD_MCP_ALLOWED_ORIGINS` somente quando houver cliente browser com Origin conhecido. Sem os dois primeiros, o metadata OAuth não é publicado. Sem Origin enviado, o desktop client continua aceito; Origin não listado falha fechado.

## Cadastro e revogação

`mcp_clients` é o registro de revogação do cliente. Segredos de cliente pertencem ao Supabase OAuth Server e nunca são copiados para a aplicação. Cadastre o mesmo `client_id`, a URL HTTPS exata do resource, escopos mínimos (`mcp:read` agora) e marque `active=false` com `revoked_at` ao revogar. A segunda migration cria `mmd_mcp_executor` sem login e remove qualquer membership em `authenticated`. A ativação remota deve gerar senha forte fora do Git, habilitar `LOGIN` nesse papel e guardar somente a connection string no secret `MMD_MCP_DATABASE_URL`.

O servidor registra em `mcp_operation_log`: cliente, ator, ferramenta, ID da tentativa, hash, intenção, resultado, correlação e recibo opcional. Token, segredo e payload livre não entram no log. Reutilizar a mesma tentativa com outro payload falha como conflito. O limite distribuído implementado usa `mcp_rate_limit_buckets` por cliente e ator, com 60 chamadas por minuto por padrão. Antes de expor a rota, o edge/WAF também precisa limitar por IP antes de autenticar. Se a reserva de limite não responder, o endpoint falha fechado.

## Manifesto atual

Após configurar e publicar o ambiente, o cliente poderá descobrir e ler:

- `mmd://eventos/{evento_id}`
- `mmd://unidades/{unidade_id}`
- `mmd_consultar_evento({ evento_id })`

Todas são somente leitura. Não há ferramenta de saída, retorno, RFID, packing ou pendência disponível. A confirmação do hospedeiro e o ACK persistido entram apenas quando o backend concluir o envelope transacional de mutação.

## Claude Code

Depois de o fluxo OAuth estar habilitado, use transporte HTTP. Não injete segredo proprietário de longa duração como cabeçalho por chamada:

```bash
claude mcp add --transport http \
  --client-id SEU_CLIENT_ID --callback-port 8765 \
  mmd-eventos https://SEU_DOMINIO/api/mcp
```

Registre antes no Supabase OAuth App a callback exata `http://localhost:8765/callback` como cliente público. Depois rode `/mcp` no Claude Code e conclua o login no navegador.

## ChatGPT Developer Mode

Cadastre a URL HTTPS remota e conclua OAuth somente depois de o emissor em `MMD_MCP_AUTHORIZATION_SERVER` estar configurado e validado. O metadata protegido será `/.well-known/oauth-protected-resource/mcp`. Sem esse emissor e deploy HTTPS, mantenha o conector indisponível: não há fallback demo, token técnico universal ou bypass da autorização por capability.

## Provas locais atuais

- `npm run test:mcp`: descoberta e leitura pelos SDKs oficial moderno e legado, bearer ausente, Origin malicioso, DTO allowlist e metadata OAuth.
- `supabase/tests/mcp_registry_test.sql`: persiste os alvos de Evento e Unidade contra a CHECK real do log, rejeita o template com chaves, nega `SELECT` direto ao executor e prova consumo único das RPCs de Evento e Unidade, tudo em transação com rollback.
- `npm run lint` e `npm run build`: endpoint `/api/mcp` e metadata compilam na app Next.
- As migrations de registry e capability são executadas dentro de transação e rollback contra o Postgres local, sem gravar dados.

Ainda falta: habilitar o Supabase OAuth 2.1 e apontar a Authorization Path para `/oauth/consent`; selecionar `public.mmd_custom_access_token_hook`; aplicar as migrations no ambiente alvo; criar a senha do papel `mmd_mcp_executor`; configurar secrets e limite pré-auth no WAF/edge; publicar URL HTTPS e fazer smoke no Claude Code e ChatGPT Developer Mode. Deploy requer autorização nova.
