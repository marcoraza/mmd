# EventPro web (BFF)

Backend for frontend do EventPro. Fases 3 e 4 de `docs/plano-migracao-eventpro.md`:
libs puras portadas, camada de dados e de ações reescrita contra o schema novo, e a
superfície HTTP dos contratos congelados de `docs/contratos-api.md`.

**Não há UI de produto aqui.** O design 2.0 é a fase 7. As únicas páginas são `/login`
(formulário simples com Server Action) e `/` (status de saúde e lista de endpoints).

## Endpoints

| Método | Rota | Contrato |
|---|---|---|
| POST | `/api/eventos/[id]/checkout` | §2, congelado |
| POST | `/api/eventos/[id]/retorno` | §3, congelado |
| GET | `/api/eventos/[id]/resumo` | §4, congelado |
| POST | `/api/rfid/scans` | §5, congelado |
| POST | `/api/qr-sheet` | §6, congelado com a refatoração de §6.6 |
| POST | `/api/eventos/[id]/conferencia-rfid` | §7, novo |
| GET | `/api/seriais/busca` | §8, novo |

## Camadas

```
src/lib/*-core.ts     regra pura, sem I/O, com suíte node --test
src/lib/data/*        leitura (Supabase service role), sem fallback de coluna
src/lib/actions/*     escrita por domínio, delegando às RPCs
src/app/api/*         rotas HTTP, uma por endpoint do contrato
```

`src/lib/actions/*` é `server-only`, não `'use server'`: nenhuma dessas funções é
endpoint de Server Action chamável pelo cliente. Ver o comentário de arquitetura em
`src/lib/actions/eventos.ts`.

## Variáveis de ambiente

| Variável | Default | Papel |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | — | obrigatória |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | — | obrigatória (auth por cookie) |
| `SUPABASE_SERVICE_ROLE_KEY` | — | obrigatória (leitura e RPCs) |
| `EVENTPRO_READONLY` | `false` | `true` bloqueia toda escrita |
| `EVENTPRO_DEV_BYPASS_AUTH` | `false` | só tem efeito com `NODE_ENV=development` |
| `EVENTPRO_LOCAL_OPERATOR` | `Dev EventPro` | label de autor no bypass de dev |
| `NEXT_PUBLIC_EVENTPRO_PUBLIC_BASE_URL` | origem da requisição | base do QR público |
| `NEXT_PUBLIC_EVENTPRO_WHATSAPP_URL` | — | contato na ficha pública |
| `NEXT_PUBLIC_EVENTPRO_PHONE` | — | contato na ficha pública |

Auth é **sempre** exigida (risco 5.2 da auditoria). O fallback de admin local só existe
com `EVENTPRO_DEV_BYPASS_AUTH=true` **e** `NODE_ENV=development`, e emite warning.

`EVENTPRO_READONLY` tem default `false` (risco 5.4): somente leitura é um modo que
alguém liga de propósito, não um estado acidental de deploy.

## Comandos

```
npm install
npm run dev
npm run typecheck   # tsc --noEmit
npm run lint        # eslint . --max-warnings=0
npm test            # node --test --experimental-strip-types
npm run build
```

Os quatro rodam em CI por push e PR (`.github/workflows/web.yml`).
