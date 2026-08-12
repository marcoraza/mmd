# MCP do Cliente MMD: Trava antes do Goal

## Missão

Entregar um servidor MCP padrão que permita a qualquer agente compatível consultar e operar o sistema MMD com autenticação, permissões, auditoria e dados canônicos compartilhados pelo Web e pelo iOS.

## Premissa central

*O MCP acessa a mesma verdade operacional do produto. Ele não raspa telas, não duplica regra de negócio e não usa credencial privilegiada como identidade do cliente.*

## Contexto

O Web e o iOS são interfaces sobre Supabase e contratos operacionais comuns. O cliente precisa conectar agentes diferentes sem receber um conector específico por fornecedor. O MCP deve expor informação e ação com fronteiras claras, mantendo os mesmos gates de Auth, RLS, idempotência e auditoria do produto.

## Mapa do sistema

- Entrada: agente MCP, sessão do cliente, intenção de consulta ou ação e parâmetros validados.
- Processamento: autenticação, autorização, chamada ao contrato canônico, auditoria e tratamento de erro.
- Saída: recurso, resposta de ferramenta ou confirmação persistida com origem rastreável.
- Fronteira de confiança: o servidor MCP e o backend autenticado. O agente conectado continua não confiável.

## Regras duras

- Usar protocolo MCP padrão e transporte remoto aceito pelos clientes atuais.
- Separar consulta de mutação em ferramentas diferentes.
- Exigir identidade humana ou técnica rastreável para toda ação.
- Respeitar RLS, perfis e permissões já definidos pelo produto.
- Nunca enviar `service_role`, secrets, dados pessoais desnecessários ou campos vetados pelo QR público.
- Reutilizar RPCs e APIs canônicas. Não reimplementar regra de estoque no servidor MCP.
- Toda mutação deve aceitar idempotência, retornar ACK persistido e registrar auditoria.
- Ferramenta perigosa deve explicar impacto e exigir confirmação do agente hospedeiro quando o protocolo permitir.
- Erro parcial não pode aparecer como sucesso.
- O catálogo de ferramentas deve informar parâmetros, efeitos, permissões e exemplos reais.
- O servidor deve funcionar com mais de um cliente MCP sem extensão proprietária obrigatória.
- Não declarar compatibilidade universal sem testar clientes de famílias diferentes.

## Fonte da verdade

- Dados e regras: Supabase, migrations e contratos server-side do MMD.
- Produto: `CONTEXT.md`, ADRs e issue `#27`.
- Segurança: `AGENTS.md`, RLS, perfis e auditoria do projeto.
- Protocolo: especificação oficial do Model Context Protocol e documentação primária dos clientes testados.

## Papéis obrigatórios

- Supervisor: protege protocolo, segurança, escopo e Definition of Done.
- Executor Protocolo: pesquisa compatibilidade e implementa servidor, transporte e descoberta.
- Executor Domínio: mapeia recursos e ferramentas para os contratos canônicos.
- Reviewer Segurança: ataca Auth, RLS, secrets, mutações e abuso por agente.

## Entregas

- Servidor MCP versionado no repositório com execução local e remota.
- Autenticação e autorização por usuário ou credencial técnica limitada.
- Recursos de leitura para Eventos, catálogo, Unidades, packing, Conferências, movimentos e pendências.
- Ferramentas de ação autorizadas pelo domínio disponível no backend.
- Catálogo Markdown de ferramentas, recursos, permissões e exemplos.
- Configurações de conexão para clientes MCP testados.
- Testes de contrato, segurança, idempotência e compatibilidade.
- Runbook de deploy, rotação de credenciais, logs e incidente.

## Definition of Done

- [ ] Um cliente MCP descobre recursos e ferramentas sem configuração proprietária do servidor.
- [ ] Dois clientes MCP de famílias diferentes conectam e executam consultas reais.
- [ ] Usuário sem permissão recebe negação e nenhum dado interno.
- [ ] Consultas do MCP retornam os mesmos dados canônicos usados pelo produto.
- [ ] Mutações usam contratos existentes, idempotência e auditoria.
- [ ] Retry não duplica efeito e erro não fabrica ACK.
- [ ] Logs identificam cliente, ator, ferramenta, intenção e resultado sem registrar secrets.
- [ ] Testes cobrem prompt injection em dados retornados e argumentos inválidos.
- [ ] Nenhum secret aparece no bundle, resposta MCP, log ou documentação.
- [ ] Servidor remoto passa smoke test fora da máquina de desenvolvimento.
- [ ] Documentação permite conectar um novo agente sem ajuda do autor.
- [ ] Review de segurança fecha sem finding bloqueante.

## Frase final de aceite

**O cliente pode conectar qualquer agente MCP compatível aos dados e ações autorizadas do MMD, mas o agente não pode ultrapassar as permissões nem criar uma segunda verdade do estoque.**
