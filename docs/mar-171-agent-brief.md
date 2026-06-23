# MAR-171, briefing operacional para agentes

Data: 2026-06-23

Este documento é a fonte curta para colocar agentes de front-end, mobile e backend na mesma página durante o PRD MAR-171.

## Tese

O MMD Estoque já tem produto web e app iOS. O trabalho atual não é reconstruir front-end nem criar outro app. O trabalho é adaptar o produto existente para virar MVP operacional real: Evento, ficha, packing, alocação, aluguel avulso, check-out, retorno, dashboard, QR seguro, auth real e validação física RFID.

## Produto vivo

- Web real: `https://mmd-zeta.vercel.app`
- Código web: `apps/web`
- Mobile real: `apps/ios/MMDEstoque`, rodando hoje em simulador e pendente de device real para produção.
- Banco: Supabase, projeto `bphmxticdyuctovfumcj`.
- Importação oficial Event Pro: aplicada em 2026-06-23, lote `902ce07f-32dd-41b9-9ad3-6d1b5886853c`.
- PRD Linear: `MAR-171`
- Issues verticais: `MAR-172` a `MAR-188`
- Bloqueador técnico: `MAR-189`

## Separação de responsabilidades

### Backend, Supabase e coordenação

Fica com Codex supervisor:

- MAR-189: migration base, Supabase local, Supabase real, login real e ação auditada real.
- Migrations, RLS, grants, RPCs e contratos de API.
- Estado das issues no Linear.
- Evidência de build, lint, testes, reset local, Supabase remoto e gates de produção.
- Decisão de quando uma issue pode sair de `In Progress` para `Done`.

### Front-end web

Fica com agentes de front-end:

- Trabalhar em cima de `apps/web`, não em produto paralelo.
- Usar o design system existente: `apps/web/src/components/mmd/Primitives.tsx`, `apps/web/src/app/globals.css`, `apps/web/public/handoff/`.
- Melhorar telas existentes de Evento, packing, alocação, check-out, retorno, dashboard, QR e login quando necessário.
- Manter rotas e arquitetura atuais. Não criar nova casca de app.
- Não mudar schema, migration, RLS ou contrato de API sem alinhar com o supervisor.
- Não marcar issue como pronta só por screenshot. Screenshot prova visual, não prova produção real.

### Mobile iOS

Fica com agentes mobile, com o mesmo limite:

- Trabalhar no app existente em `apps/ios/MMDEstoque`.
- Mobile é campo: resumo do Evento, scan, check-out, retorno e config.
- Não colocar editor completo de ficha no mobile.
- Não criar regra própria para saída, retorno ou alocação. O app usa a mesma fronteira operacional do web.
- Simulador prova UI e contrato básico. Produção real exige iPhone físico, signing, RFD40 e tags reais.

## O que são os prints

Os prints em `tasks/evidence/` têm três tipos:

- Referência glass: visual antigo ou mock usado para orientar o design.
- Imagegen: variação raster gerada antes de codar uma tela ou estado.
- Screenshot final: prova de que a implementação renderizou em desktop, mobile ou simulador.

Eles não são um front-end novo. Eles são como fotos de obra: servem para provar e orientar, mas o produto vivo continua sendo `apps/web` e `apps/ios`.

## Estado atual por Linear

| Issue | Estado | Dono principal | Leitura |
| --- | --- | --- | --- |
| MAR-172 | In Progress | Backend/Supabase | Auth local e RLS avançados. Falta Supabase real, login real e auditoria real. |
| MAR-173 | In Progress | Web + Backend | QR público seguro e ficha interna existem localmente. Falta prova contra ambiente real. |
| MAR-174 | In Progress | Web + Backend | Ficha de Evento persistida existe localmente. Falta Supabase real aplicado. |
| MAR-175 | In Progress | Web + Backend | Comercial leve existe localmente. Falta persistência e upload real. |
| MAR-176 | In Progress | Web | Packing manual conectado. Falta escrita real validada. |
| MAR-177 | In Progress | Web | Importação de planilha existe. Falta fluxo real com catálogo real aplicado. |
| MAR-178 | In Progress | Web + Backend | Templates e sugestão existem. Falta migration e gravação real. |
| MAR-179 | In Progress | Web + Backend | Alocação e conflitos existem. Falta validação com dados reais e writes reais. |
| MAR-180 | In Progress | Web + Backend | Aluguel avulso existe. Falta checkout real com Supabase aplicado. |
| MAR-181 | In Progress | Web + Backend | Gate de saída e override existem. Falta fluxo real auditado. |
| MAR-182 | In Progress | Web + Backend | Check-out web usa regra única local. Falta execução real da RPC. |
| MAR-183 | In Progress | iOS + Backend | Mobile usa resumo e checkout pela API web. Falta validação real. |
| MAR-184 | In Progress | Web + Backend | Retorno com pendência existe. Falta retorno real no banco aplicado. |
| MAR-185 | In Progress | iOS + Backend | Retorno mobile usa regra compartilhada. Falta validação real. |
| MAR-186 | In Progress | Web + Backend | Dashboard consolidado existe local/demo. Falta dados reais no Supabase aplicado. |
| MAR-187 | Done | Web + Backend | Operação unit-only para cabos registrada. Delete físico segue HITL. |
| MAR-188 | In Progress | iOS + Hardware | Build/testes simulador verdes. Produção depende de iPhone, signing, RFD40 e tags reais. |
| MAR-189 | In Progress | Backend/Supabase | Bloqueador técnico do Supabase real e da migration base. |

## Importação oficial Event Pro

Aplicada em 2026-06-23 no Supabase oficial.

- Migration: `supabase/migrations/20260623193758_event_pro_import_official.sql`.
- Script: `apps/web/scripts/import-event-pro-events.ts`.
- ADR: `docs/adr/0004-event-pro-official-import.md`.
- 11 planilhas reais importadas como arquivos oficiais.
- 16 eventos reais criados com código curto `EVT-AAMMDD-NN`.
- 1 evento cancelado importado como histórico administrativo, sem packing.
- 7 linhas de packing casadas automaticamente com catálogo atual.
- 89 candidatos únicos de catálogo.
- 313 pendências de revisão.
- Financeiro preservado apenas no XLSX original, fora do escopo deste corte.

Para agentes:

- Não criar item de catálogo automaticamente a partir de candidato.
- Não usar evento cancelado para sugestão de packing.
- Não gerar movimentação histórica para evento importado.
- Qualquer UI de revisão deve consumir `event_import_issues` e `catalog_item_candidates`.
- Status `MONTAGEM` já é oficial e deve aparecer entre `CONFIRMADO` e `EM_CAMPO`.

## Estado da MAR-189 após autorização

Autorizado pelo Marco em 2026-06-23:

- `supabase/migrations/00001_initial_schema.sql` foi restaurada a partir de `HEAD`.
- O arquivo restaurado bate com o Git e não tem diff próprio.
- Supabase local no repo principal subiu e aplicou todas as migrations.
- `supabase db reset --local --no-seed` passou no repo principal.
- `supabase db lint --local` passou.
- `supabase db advisors --local` passou.
- `supabase migration list --local` listou as 14 migrations até `20260623094805`.
- Grants, RLS e funções sensíveis foram checados localmente.
- Perfis locais `viewer`, `editor` e `admin` resolveram corretamente.

Ainda falta para fechar MAR-189:

- Terminar simulação RLS por ação local: viewer bloqueado, editor cria, admin apaga.
- Rodar gates web completos depois do reset: testes, typecheck, lint e build.
- Validar Supabase remoto real.
- Listar migrations remotas.
- Aplicar ou confirmar migrations no Supabase real.
- Testar login real `editor` e `admin`.
- Provar uma ação auditada real gravando o operador correto.

## Regras para agentes de front-end

1. Não reconstruir produto paralelo.
2. Não trocar o design system.
3. Não usar print como código fonte.
4. Não mexer em migration, RLS ou RPC.
5. Não prometer produção real por screenshot.
6. Não usar lotes como fluxo operacional futuro.
7. Não expor valor, serial de fábrica, RFID, localização ou histórico no QR público.
8. Não criar regra mobile diferente da regra web.
9. Para UI nova ou tela alterada: usar referência glass, gerar imagegen, implementar no app real e anexar screenshot final.
10. Se uma tela já existe, adaptar essa tela. Não criar outra rota com a mesma função.

## Onde o agente de front-end deve começar

1. Ler este documento.
2. Ler `apps/web/AGENTS.md`.
3. Ler `tasks/auditoria-frontend/RELATORIO-FINAL.md`.
4. Conferir o produto vivo em `https://mmd-zeta.vercel.app`.
5. Conferir evidências visuais da issue que for trabalhar em `tasks/evidence/mar-XXX/`.
6. Só então tocar código em `apps/web`.

## Entrega esperada de front-end

Cada entrega visual precisa sair com:

- Issue Linear alvo.
- Tela ou componente tocado.
- Referência usada.
- Imagegen usado quando houver UI nova ou alteração visual relevante.
- Screenshot desktop.
- Screenshot mobile.
- Checks: typecheck, lint e build, ou justificativa clara quando não rodou.
- Nota clara se a entrega é visual/local ou se depende de Supabase real.

## Frase de alinhamento

O front-end já existe. Os agentes entram para adaptar e polir o app real, enquanto o supervisor destrava o backend real e garante que o que aparece bonito também funciona com dados, login, auditoria e hardware.
