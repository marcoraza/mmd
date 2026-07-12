# Auditoria frontend histórica

Auditoria feita em 2026-05-25, antes do grill do PRD MAR-171.

Use esta pasta para entender débito técnico, tooling e histórico de decisões do web app. Não use como fonte atual de produto.

Entrada recomendada:

1. `RELATORIO-FINAL.md`
2. `FOLLOW-UP.md`

Arquivos em `analysis/`, `explore/` e `reviews/` são material bruto da auditoria. Eles podem conter termos antigos, hipóteses superadas e referências pré-grill.

Fonte atual para MAR-171:

- `../../docs/mar-171-agent-brief.md`
- `../../docs/handoff.md`
- `../../AGENTS.md`
- `../../CLAUDE.md`
- `../../apps/web/AGENTS.md`

Decisões atuais que vencem a auditoria antiga:

- Produto fala Evento, não job.
- Cabos são unit-only. Lotes são legado.
- Auth, perfis, RLS e auditoria são gate de produção real.
- QR público é mínimo e não expõe dados sensíveis.
- Web adapta telas existentes. Não criar front-end paralelo.
