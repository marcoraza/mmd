# Operação do cliente MCP MMD

Estado: protocolo, validação OAuth, leituras e sete mutações canônicas por capability estão implementados e testados localmente. A tela e a ação de consentimento aguardam prova end-to-end com o Authorization Server habilitado. Sem a configuração completa, a rota responde `503 mcp_remote_not_configured`. Não publicar nem cadastrar cliente de produção antes de migrations aplicadas, OAuth habilitado, credencial técnica dedicada criada, WAF configurado e deploy autorizado.

## Endereço e autenticação

O servidor remoto pretendido fica em `https://SEU_DOMINIO/api/mcp`. Ele aceitará Streamable HTTP e também o handshake de compatibilidade `2025-11-25` usado por hosts atuais. Hoje a rota está bloqueada por segurança.

Cada chamada exige:

1. `Authorization: Bearer <token MCP com audiência da URL MCP>`.
2. `x-mmd-mcp-request-id: <id estável da tentativa>`, ou um ID JSON-RPC estável que o servidor consegue derivar.

O bearer MCP identifica a pessoa e o cliente OAuth registrado limita e revoga o agente. O hook emite `aud` igual a `MMD_MCP_RESOURCE_URL` e `mcp_scopes` iguais aos do registry. Nunca aceite um JWT de sessão web Supabase nesta rota, nem repasse o bearer MCP para a Data API. A aplicação emite uma capability aleatória de 256 bits para cada leitura e o banco guarda somente o hash, ator, cliente, alvo, `resource_id`, hash dos argumentos, expiração e consumo. `mmd_mcp_executor` não aceita claims do chamador e não lê tabela diretamente. Nas mutações, o wrapper `SECURITY DEFINER` fixa `request.jwt.claims` somente com ator e cliente revalidados a partir da capability consumida. As policies Web e as RPCs MCP usam o mesmo predicado de perfil ativo. Não use `SUPABASE_SERVICE_ROLE_KEY`, token de QR ou URL assinada como identidade MCP.

O metadata protegido não anuncia `mcp:read` ou `mcp:operate` como scopes OAuth. O Supabase OAuth ainda não aceita scopes granulares customizados. A autorização operacional vem exclusivamente do claim `mcp_scopes` emitido pelo hook a partir do registry, não do texto de scope pedido pelo cliente.

Antes de liberar o endpoint, configure `MMD_MCP_RESOURCE_URL` como a URL HTTPS exata de `/api/mcp`, `MMD_MCP_AUTHORIZATION_SERVER` como o Authorization Server HTTPS que emite tokens próprios para esse resource e `MMD_MCP_ALLOWED_ORIGINS` somente quando houver cliente browser com Origin conhecido. Sem os dois primeiros, o metadata OAuth não é publicado. Sem Origin enviado, o desktop client continua aceito; Origin não listado falha fechado.

## Cadastro e revogação

`mcp_clients` é o registro de revogação do cliente. Segredos de cliente pertencem ao Supabase OAuth Server e nunca são copiados para a aplicação. Cadastre o mesmo `client_id`, a URL HTTPS exata do resource e `mcp:read`. Clientes autorizados a operar recebem também `mcp:operate`; a constraint exige que `mcp:operate` nunca exista sem `mcp:read`. Marque `active=false` com `revoked_at` ao revogar.

As migrations criam `mmd_mcp_executor` como `NOLOGIN`, sem membership em `authenticated`. Isso impede uso acidental antes da ativação. No preflight autorizado, gere uma senha aleatória de 256 bits fora do Git, execute `ALTER ROLE mmd_mcp_executor LOGIN PASSWORD '<senha>';` no banco alvo e grave somente a connection string no secret `MMD_MCP_DATABASE_URL`. O usuário da URL precisa ser exatamente `mmd_mcp_executor` ou, no pooler, `mmd_mcp_executor.<project-ref>`.

Antes do deploy, execute `npm --prefix apps/web run smoke:mcp-db` com esse secret. O smoke abre uma conexão real pelo mesmo driver da rota, confirma `current_user` e `session_user`, prova que `SELECT public.items` recebe `42501` e que as oito RPCs de leitura são alcançáveis e falham fechadas com token inválido. Rotacione a senha com outro `ALTER ROLE`, atualize o secret e repita o smoke. Em incidente, remova o secret, rode `ALTER ROLE mmd_mcp_executor NOLOGIN PASSWORD NULL;` e revogue o cliente no registry.

O servidor registra em `mcp_operation_log`: cliente, ator, ferramenta, ID da tentativa, hash, intenção, resultado, correlação e recibo opcional. Token, segredo e payload livre não entram no log. Reutilizar a mesma tentativa com outro payload falha como conflito. O limite distribuído implementado usa `mcp_rate_limit_buckets` por cliente e ator, com 60 chamadas por minuto por padrão. Antes de expor a rota, o edge/WAF também precisa limitar por IP antes de autenticar. Se a reserva de limite não responder, o endpoint falha fechado.

## Manifesto atual

Após configurar e publicar o ambiente, o cliente poderá descobrir e ler:

- `mmd://eventos/{evento_id}`
- `mmd://unidades/{unidade_id}`
- `mmd_consultar_evento({ evento_id })`

Com `mcp:operate` e perfil autorizado, ele também descobre as sete ferramentas descritas em `docs/operations/mcp-tool-catalog.md`: decisão, exceção, confirmação de saída e retorno, finalização de retorno, pendência e vínculo RFID. Toda mutação carrega `client_request_id`, usa operation log e capability presos a cliente, ator, ferramenta e hash, e devolve ACK mínimo persistido. Ferramentas físicas anunciam impacto destrutivo e exigem confirmação do hospedeiro.

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
- `supabase/tests/mcp_mutation_capability_test.sql`: prova claim persistido, retry, conflito de payload, capability inválida e falha sem ACK fabricado.
- `npm run smoke:mcp-db`: prova conexão real sob o login dedicado e as restrições usadas pela rota.
- `npm run lint` e `npm run build`: endpoint `/api/mcp` e metadata compilam na app Next.
- As migrations de registry e capability são executadas dentro de transação e rollback contra o Postgres local, sem gravar dados.

Ainda falta: habilitar o Supabase OAuth 2.1 e apontar a Authorization Path para `/oauth/consent`; selecionar `public.mmd_custom_access_token_hook`; aplicar as migrations no ambiente alvo; ativar o login dedicado; configurar secrets e limite pré-auth no WAF/edge; publicar URL HTTPS e fazer smoke no Claude Code e ChatGPT Developer Mode. Deploy requer autorização nova.
