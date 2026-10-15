# eventpro/lib

Camada pura portada do legado MMD (`apps/web/src/lib/`) para a fundação EventPro, conforme a Fase 3 de `docs/plano-migracao-eventpro.md` e o inventário da seção 2.1 de `docs/auditoria-migracao-eventpro.md`.

São módulos sem I/O: só regra de negócio, normalização e contratos de tipo. Toda leitura e escrita fica fora daqui (camada de dados, actions e BFF).

## Como rodar os testes

A partir de `eventpro/`:

```
node --test --experimental-strip-types lib/*.test.ts
```

Resultado atual: 87 testes, 87 passando, 0 falhando. É exatamente a mesma contagem do conjunto equivalente no legado, confirmando paridade de porte.

Typecheck dos módulos (sem os arquivos de teste, que o legado também exclui via `exclude: ["**/*.test.ts"]`):

```
tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions $(ls lib/*.ts | grep -v '\.test\.ts')
```

Passa limpo em `--strict`.

## Módulos portados

| Módulo | Origem no legado | Adaptação | Cobertura de teste |
|---|---|---|---|
| `types.ts` | `src/lib/types.ts` | Removidos `StatusLote`, `Lote`, `CreateLote` e `UpdateLote` (lotes não existem no EventPro). Adicionado `PackingStatus`, que no legado morava em `src/lib/data/projects.ts` e é dado de domínio, não de camada de dados. Comentário em `PackingList.serial_numbers_designados` apontando `packing_allocations` como fonte no EventPro | Sem teste próprio (igual ao legado); coberto indiretamente por todos os cores |
| `checkout-gate-core.ts` | `src/lib/checkout-gate-core.ts` | Cópia 1:1 | 6 testes |
| `checkout-execution-core.ts` | `src/lib/checkout-execution-core.ts` | Comentário de cabeçalho registrando que os seriais alocados chegam prontos em memória e que a fonte no EventPro é `packing_allocations`, não a coluna `uuid[]`. Nenhuma mudança de assinatura ou de comportamento | 6 testes |
| `return-resolution-core.ts` | `src/lib/return-resolution-core.ts` | Cópia 1:1 | 5 testes |
| `allocation-core.ts` | `src/lib/allocation-core.ts` | Mesmo comentário de cabeçalho sobre `packing_allocations`. Nenhuma mudança de assinatura ou de comportamento | 5 testes |
| `external-rental-core.ts` | `src/lib/external-rental-core.ts` | Import de `PackingStatus` migrado de `@/lib/data/projects` para `./types` (o tipo veio junto) | 5 testes |
| `packing-import-core.ts` | `src/lib/packing-import-core.ts` | Cópia 1:1 | 6 testes |
| `packing-suggestion-core.ts` | `src/lib/packing-suggestion-core.ts` | Cópia 1:1 | 6 testes |
| `evento-ficha-core.ts` | `src/lib/evento-ficha-core.ts` | Cópia 1:1 | 3 testes |
| `evento-comercial-core.ts` | `src/lib/evento-comercial-core.ts` | Cópia 1:1 | 6 testes |
| `rfid-scan-core.ts` | `src/lib/rfid-scan-core.ts` | Cópia 1:1 | 4 testes |
| `public-qr.ts` | `src/lib/public-qr.ts` | Removida `loteStatusToPublicStatus` e o import de `StatusLote` (lotes não existem no EventPro). Import de tipos passou de `@/lib/types` para `./types`. A função removida não tinha teste e não era invariante de não vazamento | 4 testes |
| `internal-qr-core.ts` | `src/lib/internal-qr-core.ts` | Cópia 1:1 | 3 testes |
| `dashboard-core.ts` | `src/lib/dashboard-core.ts` | Cópia 1:1 | 5 testes |
| `action-auth-core.ts` | `src/lib/action-auth-core.ts` | Cópia 1:1 | 5 testes |
| `auth-config.ts` | `src/lib/auth-config.ts` | Removido `/lotes` da lista de prefixos protegidos (rota morta no EventPro). O resto é 1:1 | 6 testes |
| `item-label.ts` | `src/lib/item-label.ts` | Cópia 1:1 | Sem teste (igual ao legado) |
| `nomenclature.ts` | `src/lib/nomenclature.ts` | `CATEGORIA_LABEL` trazido junto e passou a ser exportado daqui. No legado vinha de `src/components/catalog/helpers.ts`, que é camada de UI descartada na migração; o dicionário é dado de domínio. Import de `Categoria` passou de `@/lib/types` para `./types` | Sem teste (igual ao legado) |
| `event-pro-import-core.ts` | `src/lib/event-pro-import-core.ts` | Cópia 1:1 | 7 testes |
| `demo-mode-core.ts` | `src/lib/data/demo-mode-core.ts` | Cópia 1:1, movido de `data/` para a raiz de `lib/` | 5 testes |

## Fora de escopo neste porte

| Item | Motivo |
|---|---|
| `checkout-rpc-contract.test.ts` | Teste de contrato que lê o SQL das migrations. Pertence à Fase 2, apontando para as migrations novas do EventPro |
| `projeto-status-guard-contract.test.ts` | Mesmo caso: contrato de SQL, Fase 2 |
| `legacy-lotes-core.ts` e seu teste | Lotes são legado declarado (unit-only desde MAR-187). Não existem no EventPro |
| `packing-import-file.ts` | Depende de `exceljs`, é `server-only`. Entra junto com o BFF na Fase 4 |
| `src/lib/data/*` e `src/lib/actions/*` | Não são puros. São reescritos contra o schema novo, sem fallback progressivo de coluna e delegando alocação às RPCs |

## Pendências deixadas para as próximas fases

- Eliminar o fallback de admin sem login (risco 5.2 da auditoria) é ajuste em `requireActionUser`, que vive em `src/lib/action-auth.ts` e não é módulo puro. `action-auth-core.ts` só carrega o modelo de roles e veio intacto.
- A lista de prefixos protegidos em `auth-config.ts` reflete as rotas do web legado. Ela será redefinida quando a UI 2.0 existir (Fase 7).
- Definir default consciente de `MMD_READONLY` e equivalentes (risco 5.4) é decisão de configuração de ambiente, não de código puro.
