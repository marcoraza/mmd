// ============================================================================
// EventPro: teste de contrato das RPCs (fase 2)
// ----------------------------------------------------------------------------
// Mesmo padrão de `apps/web/src/lib/checkout-rpc-contract.test.ts` no legado: o
// teste lê o SQL da migration e trava as propriedades que não aparecem em teste
// funcional, ou que só aparecem quando já é tarde.
//
// O que este arquivo protege, e por quê:
//
//   1. Ordem dentro do check-out (lock, checagem de status, auditoria,
//      mutação). Um smoke feliz passa igual se alguém inverter auditoria e
//      mutação; o buraco só aparece no dia em que a transação falha no meio.
//   2. `SKIP LOCKED` na auto-alocação. É a linha que mata a race do legado.
//      Sumiu a linha, voltou a race, e nenhum teste de uma sessão só percebe.
//   3. Grants. Este é o risco §5.5 da auditoria: no legado, replay fora de
//      ordem de migrations reabria `checkout_projeto` para `authenticated`,
//      permitindo spoofing de `registrado_por` pela Data API.
//   4. Cobertura total no check-in e a matriz CONFIRMADO/MONTAGEM: são as duas
//      regras que já quebraram uma vez em produção no legado.
//
// Rodar:
//   node --test --experimental-strip-types eventpro/supabase/validation/rpc-contract.test.ts
// ============================================================================

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const sql = readFileSync(join(here, '..', 'migrations', '0002_rpcs.sql'), 'utf8')

// Versão sem as linhas de comentário. Serve para as asserções negativas: o
// arquivo cita construções do legado (`serial_numbers_designados`, por exemplo)
// justamente para explicar por que não as usa, e comentário não é código.
const codigo = sql
  .split('\n')
  .filter((linha) => !linha.trimStart().startsWith('--'))
  .join('\n')

const RPCS = [
  { nome: 'checkout_projeto', args: 'uuid, public.metodo_scan_enum, text, uuid' },
  {
    nome: 'checkout_projeto_com_override',
    args: 'uuid, public.metodo_scan_enum, text, uuid, uuid',
  },
  { nome: 'checkin_projeto', args: 'uuid, public.metodo_scan_enum, text, jsonb, uuid' },
  { nome: 'resolver_retorno_pendencia', args: 'uuid, text, text, text, uuid' },
  { nome: 'auto_allocate_packing', args: 'uuid, text, uuid' },
  {
    nome: 'conferencia_rfid_evento',
    args: 'uuid, text[], public.contexto_scan_enum, text, uuid',
  },
] as const

// Recorta o corpo de uma função para as asserções de ordem não vazarem para a
// função seguinte do arquivo.
function corpo(nome: string) {
  const abertura = `CREATE OR REPLACE FUNCTION public.${nome}(`
  const inicio = codigo.indexOf(abertura)
  assert.ok(inicio >= 0, `função public.${nome} não encontrada em 0002_rpcs.sql`)
  const proxima = codigo.indexOf('CREATE OR REPLACE FUNCTION', inicio + abertura.length)
  return codigo.slice(inicio, proxima === -1 ? undefined : proxima)
}

function escapar(valor: string) {
  return valor.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

test('as 6 RPCs existem com a assinatura esperada', () => {
  for (const rpc of RPCS) {
    assert.match(
      sql,
      new RegExp(`CREATE OR REPLACE FUNCTION public\\.${rpc.nome}\\(`),
      `RPC ausente: ${rpc.nome}`,
    )
  }
})

test('check-out trava, valida status e audita antes de mutar', () => {
  const fn = corpo('checkout_projeto')

  const lockEvento = fn.indexOf('WHERE id = p_projeto_id\n  FOR UPDATE;')
  const lockSeriais = fn.indexOf('WHERE id = ANY(v_serial_ids)\n    FOR UPDATE;')
  const checkStatus = fn.indexOf('IF v_bad_status_count > 0 THEN')
  const auditoria = fn.indexOf('INSERT INTO public.movimentacoes')
  const mutaSeriais = fn.indexOf('UPDATE public.serial_numbers')
  const mutaEvento = fn.indexOf('UPDATE public.projetos')

  assert.ok(lockEvento > 0, 'Evento não é travado com FOR UPDATE')
  assert.ok(lockSeriais > lockEvento, 'unidades não são travadas com FOR UPDATE')
  assert.ok(checkStatus > lockSeriais, 'status da unidade é checado antes do lock')
  assert.ok(auditoria > checkStatus, 'auditoria gravada antes de validar status')
  assert.ok(mutaSeriais > auditoria, 'unidade mutada antes da auditoria')
  assert.ok(mutaEvento > mutaSeriais, 'Evento mutado antes das unidades')

  assert.match(fn, /status <> 'DISPONIVEL'/)
  assert.match(fn, /registrado_por, registrado_por_id, metodo_scan/)
})

test('check-out aceita CONFIRMADO e MONTAGEM, e só eles', () => {
  for (const nome of ['checkout_projeto', 'checkout_projeto_com_override']) {
    const fn = corpo(nome)
    assert.match(
      fn,
      /IF v_projeto_status::text NOT IN \('CONFIRMADO', 'MONTAGEM'\) THEN/,
      `${nome} sem a matriz CONFIRMADO/MONTAGEM`,
    )
    assert.match(fn, /Check-out requer Evento CONFIRMADO ou MONTAGEM/)
  }
})

test('override pula readiness mas nunca pula unidade indisponível', () => {
  const fn = corpo('checkout_projeto_com_override')

  assert.doesNotMatch(fn, /v_packing_missing/, 'override não deveria checar readiness')
  assert.match(fn, /FROM public\.checkout_overrides co/)
  assert.match(fn, /status <> 'DISPONIVEL'/)

  const checaOverride = fn.indexOf('FROM public.checkout_overrides co')
  const checkStatus = fn.indexOf('IF v_bad_status_count > 0 THEN')
  const auditoria = fn.indexOf('INSERT INTO public.movimentacoes')
  const carimbo = fn.indexOf('SET executado_em = now()')

  assert.ok(checaOverride > 0)
  assert.ok(checkStatus > checaOverride)
  assert.ok(auditoria > checkStatus)
  assert.ok(carimbo > auditoria)
  assert.match(fn, /Saída forçada por override auditado/)
})

test('check-in exige cobertura total das unidades que saíram', () => {
  const fn = corpo('checkin_projeto')

  assert.match(fn, /v_duplicate_count > 0/)
  assert.match(fn, /RAISE EXCEPTION 'Lista de retorno contém unidade duplicada'/)
  assert.match(fn, /IF v_unexpected_count > 0 OR v_missing_count > 0 THEN/)
  assert.match(
    fn,
    /RAISE EXCEPTION 'Lista de retorno não bate com as unidades que saíram neste Evento'/,
  )

  const duplicata = fn.indexOf('v_duplicate_count > 0')
  const cobertura = fn.indexOf('IF v_unexpected_count > 0 OR v_missing_count > 0 THEN')
  const auditoria = fn.indexOf('INSERT INTO public.movimentacoes')

  assert.ok(duplicata > 0)
  assert.ok(cobertura > duplicata)
  assert.ok(auditoria > cobertura, 'auditoria gravada antes de validar cobertura')
})

test('check-in abre pendência sem baixa automática e finaliza só sem pendência', () => {
  const fn = corpo('checkin_projeto')

  assert.match(fn, /WHEN parsed\.resultado = 'NAO_VOLTOU' THEN 'RETORNANDO'/)
  assert.doesNotMatch(fn, /WHEN parsed\.resultado = 'NAO_VOLTOU' THEN 'BAIXA'/)
  assert.match(fn, /ON CONFLICT \(projeto_id, serial_number_id\)/)

  const pendencia = fn.indexOf('INSERT INTO public.retorno_pendencias')
  const liberaAlocacao = fn.indexOf('DELETE FROM public.packing_allocations')
  const checaAberta = fn.indexOf("rp.status = 'ABERTA'")
  const finaliza = fn.indexOf("SET status = 'FINALIZADO'")

  assert.ok(pendencia > 0)
  assert.ok(liberaAlocacao > pendencia)
  assert.ok(checaAberta > liberaAlocacao)
  assert.ok(finaliza > checaAberta)

  // A unidade que não voltou mantém a alocação até a resolução.
  assert.match(fn, /AND parsed\.resultado <> 'NAO_VOLTOU';/)
})

test('resolução de pendência cobre as 4 ações e libera a alocação', () => {
  const fn = corpo('resolver_retorno_pendencia')

  assert.match(fn, /v_acao NOT IN \('ENCONTRADA', 'MANUTENCAO', 'BAIXA', 'COBRANCA'\)/)
  assert.match(fn, /v_status_novo := 'DISPONIVEL';/)
  assert.match(fn, /v_status_novo := 'MANUTENCAO';/)
  assert.match(fn, /v_status_novo := 'BAIXA';/)
  assert.match(fn, /v_status_novo := v_status_anterior;/)
  assert.match(fn, /Pendência resolvida com nota de cobrança/)
  assert.match(fn, /DELETE FROM public\.packing_allocations/)
  assert.match(fn, /resolvido_por_id = v_autor_id/)
})

test('auto-alocação usa FOR UPDATE SKIP LOCKED e é idempotente', () => {
  const fn = corpo('auto_allocate_packing')

  assert.match(fn, /FOR UPDATE OF sn SKIP LOCKED/, 'sem SKIP LOCKED a race do legado volta')
  assert.match(fn, /FROM public\.packing_list pl\s+WHERE pl\.id = p_packing_id\s+FOR UPDATE;/)
  assert.match(fn, /ON CONFLICT ON CONSTRAINT packing_allocations_serial_unique DO NOTHING/)

  // Idempotência: linha completa sai sem erro e sem alocar.
  assert.match(fn, /IF v_missing <= 0 THEN\s+RETURN;\s+END IF;/)

  // Nunca remove alocação existente.
  assert.doesNotMatch(fn, /DELETE FROM/)

  // Ordem FIFO de allocation-core.ts: nunca movimentada primeiro.
  assert.match(fn, /ASC NULLS FIRST/)
})

test('conferência RFID classifica, grava toda leitura e não muta status', () => {
  const fn = corpo('conferencia_rfid_evento')

  assert.match(fn, /'CONFIRMADO'/)
  assert.match(fn, /'EXTRA'/)
  assert.match(fn, /'DESCONHECIDA'/)
  assert.match(fn, /'FALTANTE'/)

  // Normalização espelhando normalizeRfidTag (upper, remove espaço, : e -).
  assert.match(fn, /upper\(regexp_replace\(btrim\(t\.raw\), '\[\[:space:\]:-\]\+', '', 'g'\)\)/)

  // Toda leitura vira scan, inclusive a desconhecida, com nota.
  assert.match(fn, /INSERT INTO public\.rfid_scans/)
  assert.match(fn, /'Tag RFID não reconhecida'/)

  // Conferência é leitura mais telemetria: nada de lock nem de mutação.
  assert.doesNotMatch(fn, /FOR UPDATE/)
  assert.doesNotMatch(fn, /UPDATE public\.serial_numbers/)
  assert.doesNotMatch(fn, /UPDATE public\.projetos/)
})

test('as 6 RPCs são revogadas de PUBLIC, anon e authenticated', () => {
  for (const rpc of RPCS) {
    const assinatura = escapar(`public.${rpc.nome}(${rpc.args})`)
    for (const alvo of ['PUBLIC', 'anon', 'authenticated']) {
      assert.match(
        sql,
        new RegExp(`REVOKE ALL ON FUNCTION ${assinatura} FROM ${alvo};`),
        `${rpc.nome} sem REVOKE de ${alvo}`,
      )
    }
  }
})

test('as 6 RPCs só concedem EXECUTE a service_role', () => {
  for (const rpc of RPCS) {
    const assinatura = escapar(`public.${rpc.nome}(${rpc.args})`)
    assert.match(
      sql,
      new RegExp(`GRANT EXECUTE ON FUNCTION ${assinatura} TO service_role;`),
      `${rpc.nome} sem GRANT para service_role`,
    )
  }

  // Nenhum GRANT de EXECUTE para authenticated ou anon em lugar nenhum do
  // arquivo. Regressão direta do risco §5.5 da auditoria.
  const grantsDeExecute = sql.match(/GRANT EXECUTE ON FUNCTION[^;]+;/gs) ?? []
  assert.ok(grantsDeExecute.length > 0)
  for (const grant of grantsDeExecute) {
    assert.doesNotMatch(grant, /\bauthenticated\b/, `GRANT indevido para authenticated: ${grant}`)
    assert.doesNotMatch(grant, /\banon\b/, `GRANT indevido para anon: ${grant}`)
  }
})

test('as RPCs são SECURITY DEFINER com search_path travado', () => {
  for (const rpc of RPCS) {
    const fn = corpo(rpc.nome)
    assert.match(fn, /SECURITY DEFINER/, `${rpc.nome} não é SECURITY DEFINER`)
    assert.match(fn, /SET search_path = public/, `${rpc.nome} sem search_path travado`)
  }
})

test('autoria deriva de auth.uid() e cai para o parâmetro só sem sessão', () => {
  assert.match(sql, /CREATE OR REPLACE FUNCTION app_private\.resolve_autoria\(/)
  assert.match(sql, /v_uid := auth\.uid\(\);/)
  assert.match(sql, /RAISE EXCEPTION 'registrado_por é obrigatório/)
  assert.match(sql, /RAISE EXCEPTION 'registrado_por_id % não corresponde a nenhum profile'/)

  // O helper de autoria também fica fora do alcance de authenticated.
  assert.match(sql, /REVOKE ALL ON FUNCTION app_private\.resolve_autoria\(text, uuid\) FROM authenticated;/)

  // Toda RPC de mutação resolve autoria antes de qualquer outra coisa.
  for (const nome of [
    'checkout_projeto',
    'checkout_projeto_com_override',
    'checkin_projeto',
    'resolver_retorno_pendencia',
    'auto_allocate_packing',
  ]) {
    const fn = corpo(nome)
    assert.match(
      fn,
      /FROM app_private\.resolve_autoria\(p_registrado_por, p_registrado_por_id\) a;/,
      `${nome} não resolve autoria`,
    )
    assert.match(fn, /registrado_por_id/, `${nome} não grava registrado_por_id`)
  }
})

test('o defeito estrutural do legado não foi portado', () => {
  // A alocação é relacional. Se `serial_numbers_designados` reaparecer, o porte
  // trouxe junto o array sem integridade referencial (auditoria §2.3, §4.5).
  assert.doesNotMatch(codigo, /serial_numbers_designados/)
  assert.match(codigo, /FROM public\.packing_allocations pa\s+JOIN public\.packing_list pl/)
})
