# ADR 0004: Importação oficial de planilhas Event Pro

Data: 2026-06-23

## Status

Aceito e aplicado no Supabase oficial.

## Contexto

A MMD tem planilhas reais de eventos vindas do Event Pro. Elas misturam dados do evento, orçamento, equipe, serviços, buffet, valores e listas de equipamento. O objetivo imediato não é trazer financeiro para o sistema. O objetivo é substituir mocks por histórico real, preservar os arquivos originais e abrir uma fila de revisão para transformar linhas operacionais em catálogo, packing e pendências.

## Decisão

- Importar como histórico oficial operacional, não como fixture.
- Manter UUID como chave técnica.
- Mostrar nome humano do evento como identificação principal.
- Gerar código curto secundário no padrão `EVT-AAMMDD-NN`, por exemplo `EVT-260624-01`.
- Adicionar `MONTAGEM` como status oficial entre `CONFIRMADO` e `EM_CAMPO`.
- Permitir check-out quando o evento estiver `CONFIRMADO` ou `MONTAGEM`.
- Não criar movimentações históricas para eventos passados.
- Não importar financeiro neste corte.
- Preservar cada XLSX original no bucket privado `mmd-event-pro-imports`.
- Usar hash do arquivo para impedir duplicidade.

## Cancelados

Eventos cancelados entram como histórico administrativo:

- status operacional `CANCELADO`;
- sem packing list;
- sem sugestão de packing;
- com pendência `EVENTO_CANCELADO`;
- arquivo original preservado.

## Revisão

A importação separa status operacional de selo de revisão:

- `IMPORTADO_OFICIAL`: importado sem pendência conhecida;
- `REVISAO_PENDENTE`: importado com montagem ausente, candidato de catálogo, packing ambíguo, serviço ignorado, data inconsistente ou evento cancelado;
- `REVISAO_CONCLUIDA`: reservado para fechamento posterior pela operação.

As pendências ficam em `event_import_issues`. Candidatos de catálogo ficam em `catalog_item_candidates`, sem virar item automaticamente.

## Resultado aplicado

Lote oficial: `902ce07f-32dd-41b9-9ad3-6d1b5886853c`.

- 11 arquivos XLSX importados.
- 11 hashes únicos.
- 11 originais preservados no Storage.
- 16 eventos criados em `projetos`.
- 1 evento cancelado.
- 7 linhas de packing casadas automaticamente com catálogo atual.
- 89 candidatos únicos de catálogo.
- 313 pendências de revisão.

## Comandos de manutenção

Simulação:

```bash
cd apps/web
node --experimental-strip-types scripts/import-event-pro-events.ts --input "/Users/marko/Downloads/Eventos Event Pro (1)"
```

Aplicação oficial:

```bash
cd apps/web
node --experimental-strip-types scripts/import-event-pro-events.ts --input "/Users/marko/Downloads/Eventos Event Pro (1)" --apply
```

## Consequências

O sistema já tem eventos reais para substituir mocks. A próxima entrega de produto deve expor a fila de revisão para Marcelo aprovar candidatos como item de catálogo, aluguel de parceiro, serviço ou ignorado.
