# Runbook do Evento `Treinamento · Marcelo`

Versão: `0.1.0-draft`  
Data: `17/07/2026`

O treinamento usa execuções numeradas com o mesmo nome visível. A restauração preserva o histórico: um ciclo finalizado nunca é reaberto, apagado ou devolvido à força para planejamento.

## Identidade

| Campo | Valor |
|---|---|
| Nome visível | `Treinamento · Marcelo` |
| Código da primeira execução | `TRN-MARCELO-01` |
| Marcador interno | `[MMD_TRAINING_EVENT:v1]` |
| Cliente | `MMD Eventos` |
| Local | `Ambiente controlado de treinamento MMD` |

O código e o marcador diferenciam treinamento de Evento de cliente em consultas, auditoria e suporte.

## Preparar sem escrever

Na pasta `apps/web`:

```bash
npm run training:prepare -- --run 1
```

O resultado precisa mostrar:

- `mode: probe-read-only`
- `ready: true`
- `writesPerformed: 0`
- cinco unidades sem conflito ativo
- packing inicial `4/5`
- pelo menos uma tag já vinculada

Salvar o resultado como relatório anterior ao take. EPC não entra no relatório, apenas o estado `vinculado` ou `vínculo físico pendente`.

## Aplicar a execução

Este comando escreve no Supabase e só pode rodar depois da confirmação explícita do Marco:

```bash
npm run training:prepare -- \
  --run 1 \
  --apply \
  --confirm TREINAMENTO-MARCELO
```

O script verifica o estado depois da escrita. Sucesso exige `mode: apply-verified`, `ready: true` e nenhuma mudança pendente numa segunda preparação.

## Estado inicial de cada take

Antes do take operacional:

1. Rodar o probe da execução ativa.
2. Confirmar Evento em `PLANEJAMENTO`.
3. Confirmar cinco unidades selecionadas e packing `4/5`.
4. Confirmar que nenhuma unidade tem conflito com Evento ativo.
5. Registrar o output no shot log sem EPC, credencial ou ID sensível.

Repetir o mesmo `--run N` é idempotente enquanto o Evento continua em planejamento. Divergência de packing aparece como mudança exata antes de qualquer escrita.

## Restaurar depois de check-out e retorno

O retorno finaliza o Evento e libera novamente as unidades aptas. `FINALIZADO` é terminal por regra do banco. A restauração segura cria a próxima execução:

```bash
npm run training:prepare -- --run 2
```

Depois da confirmação do plano:

```bash
npm run training:prepare -- \
  --run 2 \
  --apply \
  --confirm TREINAMENTO-MARCELO
```

Resultado esperado:

- `TRN-MARCELO-01` permanece finalizado e auditável
- `TRN-MARCELO-02` nasce em planejamento
- nome visível continua `Treinamento · Marcelo`
- packing volta a `4/5`
- nenhum registro do ciclo anterior é apagado

Se uma unidade terminar em manutenção, o próximo probe escolhe outra unidade disponível e sem conflito. Não mova a unidade danificada para disponível só para repetir o vídeo.

## Recusas intencionais

- `--reset` não existe
- `--apply` sem confirmação tipada falha antes da escrita
- Evento sem marcador exclusivo é recusado
- Evento em `CONFIRMADO`, `EM_CAMPO`, `FINALIZADO` ou `CANCELADO` não é refeito pelo script
- remoção de linha existente é recusada; use nova execução

## Relatório posterior

Depois de cada take, registrar no shot log:

- código da execução
- status final do Evento
- contagem de unidades por resultado
- movimentação de saída e retorno criada
- pendência ou manutenção criada
- decisão de usar ou descartar o take

Nunca incluir senha, token, service role, cookie, EPC completo ou dado pessoal de terceiro.
