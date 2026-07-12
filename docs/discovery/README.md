# Discovery histórico

Esta pasta guarda pesquisa, proposta e comparativos feitos antes do PRD MAR-171.

Use estes documentos para contexto comercial e memória do projeto. Não use como fonte atual de implementação.

Fonte atual para agentes:

1. `../mar-171-agent-brief.md`
2. `../handoff.md`
3. `../../AGENTS.md`
4. `../../CLAUDE.md`
5. ADRs em `../adr/`

Decisões atuais do grill:

- Produto fala Evento, não job.
- Cabos são unit-only. Lotes são legado.
- Auth, perfis, RLS e auditoria são gate de produção real.
- QR público é mínimo e não expõe dados sensíveis.
- Web cuida de ficha de evento, orçamento/contrato e gestão.
- Mobile cuida de campo: resumo do evento, scan, check-out e retorno.
