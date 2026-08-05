// ============================================================================
// EventPro: teste de contrato das migrations DELTA
// ----------------------------------------------------------------------------
// Irmão de `validation/rpc-contract.test.ts`, mas apontando para as deltas que
// convergem o banco LEGADO (o projeto real em produção) para o design alvo.
//
// O que este arquivo protege, e por quê:
//
//   1. BACKFILL. A tabela `packing_allocations` sem backfill é uma tabela
//      vazia num banco cheio: as RPCs novas leem dela e todo Evento em
//      andamento viraria "packing incompleto". O teste garante que o statement
//      de carga continua no arquivo, junto com o descarte de uuid órfão.
//   2. GUARDS DE LOOP no trigger de sincronização. O trigger array -> tabela e
//      o dual-write tabela -> array são duas escritas que se enxergam. Sem o
//      GUC de skip e sem o teto de `pg_trigger_depth()`, uma alteração futura
//      fecha o ciclo e derruba a operação em produção, não em teste.
//   3. SKIP LOCKED na auto-alocação. É a linha que mata a race documentada
//      como TODO no legado. Sumiu a linha, voltou a race, e nenhum teste de
//      uma sessão só percebe.
//   4. GRANTS. Risco §5.5 da auditoria: no legado, replay fora de ordem de
//      migrations reabria `checkout_projeto` para `authenticated`, permitindo
//      spoofing de `registrado_por` pela Data API.
//   5. ASSINATURA RETROCOMPATÍVEL. `p_registrado_por_id uuid DEFAULT NULL`
//      precisa ser o ÚLTIMO parâmetro das 4 RPCs portadas, senão a chamada
//      posicional do web legado passa a mandar o autor no lugar errado. E as
//      assinaturas antigas precisam ser removidas: sobrecarga viva torna a
//      chamada por nome do legado ambígua ("function is not unique").
//
// Rodar:
//   node --test --experimental-strip-types supabase/validation/delta-contract.test.ts
// ============================================================================

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const migrations = join(here, '..', 'migrations')

function ler(arquivo: string) {
  return readFileSync(join(migrations, arquivo), 'utf8')
}

// Versão sem comentários. Serve para as asserções negativas: as deltas citam
// construções do legado (`serial_numbers_designados`, `authenticated`) nos
// comentários justamente para explicar como lidam com elas, e comentário não
// é código.
function semComentarios(sql: string) {
  return sql
    .split('\n')
    .filter((linha) => !linha.trimStart().startsWith('--'))
    .join('\n')
}

const ALLOC_SQL = ler('20260806010000_packing_allocations.sql')
const ALLOC = semComentarios(ALLOC_SQL)
const CONFIG = semComentarios(ler('20260806011000_app_config_codigo_prefix.sql'))
const AUTORIA = semComentarios(ler('20260806012000_colunas_autoria.sql'))
const PACKING = semComentarios(ler('20260806013000_packing_list_integridade.sql'))
const RPCS_SQL = ler('20260806014000_rpcs_eventpro.sql')
const RPCS = semComentarios(RPCS_SQL)

// As 4 RPCs portadas do legado, com a assinatura EventPro e a posição exata do
// parâmetro de autoria.
const PORTADAS = [
  {
    nome: 'checkout_projeto',
    args: 'uuid, public.metodo_scan_enum, text, uuid',
    argsLegado: 'uuid, public.metodo_scan_enum, text',
    anterior: 'p_registrado_por text',
  },
  {
    nome: 'checkout_projeto_com_override',
    args: 'uuid, public.metodo_scan_enum, text, uuid, uuid',
    argsLegado: 'uuid, public.metodo_scan_enum, text, uuid',
    anterior: 'p_override_id uuid',
  },
  {
    nome: 'checkin_projeto',
    args: 'uuid, public.metodo_scan_enum, text, jsonb, uuid',
    argsLegado: 'uuid, public.metodo_scan_enum, text, jsonb',
    anterior: 'p_items jsonb',
  },
  {
    nome: 'resolver_retorno_pendencia',
    args: 'uuid, text, text, text, uuid',
    argsLegado: 'uuid, text, text, text',
    anterior: 'p_registrado_por text',
  },
] as const

// As 2 RPCs novas entram só nas asserções de grant e existência.
const NOVAS = [
  { nome: 'auto_allocate_packing', args: 'uuid, text, uuid' },
  { nome: 'conferencia_rfid_evento', args: 'uuid, text[], public.contexto_scan_enum, text, uuid' },
] as const

function escapar(valor: string) {
  return valor.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

// Recorta o bloco de uma função para as asserções não vazarem para a seguinte.
function corpo(sql: string, assinatura: string) {
  const inicio = sql.indexOf(assinatura)
  assert.ok(inicio >= 0, `bloco não encontrado: ${assinatura}`)
  const proxima = sql.indexOf('CREATE OR REPLACE FUNCTION', inicio + assinatura.length)
  return sql.slice(inicio, proxima === -1 ? undefined : proxima)
}

// ----------------------------------------------------------------------------
// 1. Backfill
// ----------------------------------------------------------------------------

test('a delta de packing_allocations faz backfill a partir do array legado', () => {
  assert.match(
    ALLOC,
    /INSERT INTO public\.packing_allocations \(packing_id, serial_id\)/,
    'backfill ausente: packing_allocations nasceria vazia num banco com Eventos em andamento',
  )
  assert.match(
    ALLOC,
    /unnest\(coalesce\(pl\.serial_numbers_designados, ARRAY\[\]::uuid\[\]\)\)/,
    'o backfill precisa ler serial_numbers_designados',
  )
})

test('o backfill descarta uuid órfão em vez de estourar a FK', () => {
  // O JOIN com serial_numbers é o que filtra o id que não existe mais.
  assert.match(
    ALLOC,
    /JOIN public\.serial_numbers sn ON sn\.id = alocado\.serial_id/,
    'sem o JOIN de existência, um uuid órfão do array aborta a migration inteira',
  )
  assert.match(
    ALLOC,
    /ON CONFLICT ON CONSTRAINT packing_allocations_serial_unique DO NOTHING/,
    'o backfill precisa tolerar o mesmo serial em duas linhas do array',
  )
})

test('o backfill relata órfãos e duplicatas em vez de silenciar', () => {
  assert.match(ALLOC, /RAISE NOTICE '[^']*órfão/, 'relatório de órfãos ausente')
  assert.match(ALLOC, /RAISE WARNING '[^']*mais de uma linha de packing/, 'relatório de duplicatas ausente')
})

test('a constraint de unicidade tem nome fixo (o ON CONFLICT depende dele)', () => {
  assert.match(ALLOC, /CONSTRAINT packing_allocations_serial_unique UNIQUE \(serial_id\)/)
})

// ----------------------------------------------------------------------------
// 2. Guards de loop no trigger de sincronização
// ----------------------------------------------------------------------------

test('o trigger de sync existe e é AFTER, na coluna do array', () => {
  assert.match(ALLOC, /CREATE OR REPLACE FUNCTION public\.sync_packing_allocations_from_array\(\)/)
  assert.match(
    ALLOC,
    /AFTER INSERT OR UPDATE OF serial_numbers_designados ON public\.packing_list/,
    'o trigger precisa disparar na escrita do array que o web legado faz',
  )
})

test('o trigger de sync tem guard de GUC contra o dual-write das RPCs', () => {
  const fn = corpo(ALLOC, 'CREATE OR REPLACE FUNCTION public.sync_packing_allocations_from_array()')
  assert.match(
    fn,
    /current_setting\('eventpro\.skip_allocation_sync', true\)/,
    'sem o guard de GUC, o trigger reconcilia por cima da decisão da RPC',
  )
  assert.match(fn, /RETURN NULL;/, 'o guard precisa sair sem reconciliar')
})

test('o trigger de sync tem guard de reentrância por pg_trigger_depth', () => {
  const fn = corpo(ALLOC, 'CREATE OR REPLACE FUNCTION public.sync_packing_allocations_from_array()')
  assert.match(
    fn,
    /pg_trigger_depth\(\)\s*>\s*1/,
    'fail-safe estrutural: sem ele, um trigger futuro em packing_allocations fecha o ciclo',
  )
})

test('o guard de GUC do trigger casa com o flag que o dual-write liga', () => {
  assert.match(
    RPCS,
    /set_config\('eventpro\.skip_allocation_sync', 'on', true\)/,
    'o helper de dual-write precisa ligar exatamente o flag que o trigger lê',
  )
  assert.match(RPCS, /set_config\('eventpro\.skip_allocation_sync', 'off', true\)/)
})

test('o dual-write é função, não trigger em packing_allocations', () => {
  assert.match(
    RPCS,
    /CREATE OR REPLACE FUNCTION app_private\.sync_array_from_allocations\(p_packing_ids uuid\[\]\)/,
  )
  assert.doesNotMatch(
    ALLOC + RPCS,
    /CREATE TRIGGER \w+\s+(BEFORE|AFTER)[\s\S]{0,80}ON public\.packing_allocations/,
    'trigger em packing_allocations fecharia o ciclo com o trigger de packing_list',
  )
})

test('as RPCs que mutam alocação chamam o dual-write', () => {
  for (const nome of ['checkin_projeto', 'resolver_retorno_pendencia', 'auto_allocate_packing']) {
    const fn = corpo(RPCS, `CREATE OR REPLACE FUNCTION public.${nome}(`)
    assert.match(
      fn,
      /PERFORM app_private\.sync_array_from_allocations\(/,
      `${nome} muta packing_allocations e precisa reprojetar o array para o web legado`,
    )
  }
})

test('checkout não faz dual-write (não muta alocação)', () => {
  const fn = corpo(RPCS, 'CREATE OR REPLACE FUNCTION public.checkout_projeto(')
  assert.doesNotMatch(fn, /sync_array_from_allocations/)
})

// ----------------------------------------------------------------------------
// 3. SKIP LOCKED
// ----------------------------------------------------------------------------

test('auto_allocate_packing usa FOR UPDATE SKIP LOCKED', () => {
  const fn = corpo(RPCS, 'CREATE OR REPLACE FUNCTION public.auto_allocate_packing(')
  assert.match(
    fn,
    /FOR UPDATE OF sn SKIP LOCKED/,
    'sem SKIP LOCKED a race do autoAllocate legado volta',
  )
  assert.match(fn, /FOR UPDATE;/, 'a linha de packing precisa ser travada antes de contar o que falta')
  assert.match(
    fn,
    /ON CONFLICT ON CONSTRAINT packing_allocations_serial_unique DO NOTHING/,
    'terceira barreira: o banco recusa a alocação dupla mesmo se os locks falharem',
  )
})

// ----------------------------------------------------------------------------
// 4. REVOKE / GRANT
// ----------------------------------------------------------------------------

test('as 6 RPCs revogam PUBLIC, anon e authenticated e concedem só service_role', () => {
  for (const rpc of [...PORTADAS, ...NOVAS]) {
    const assinatura = escapar(`public.${rpc.nome}(${rpc.args})`)
    for (const alvo of ['PUBLIC', 'anon', 'authenticated']) {
      assert.match(
        RPCS,
        new RegExp(`REVOKE ALL ON FUNCTION ${assinatura} FROM ${alvo};`),
        `REVOKE ausente para ${rpc.nome} / ${alvo}`,
      )
    }
    assert.match(
      RPCS,
      new RegExp(`GRANT EXECUTE ON FUNCTION ${assinatura} TO service_role;`),
      `GRANT de service_role ausente para ${rpc.nome}`,
    )
  }
})

test('nenhuma RPC concede EXECUTE para authenticated ou anon', () => {
  const grants = RPCS.split('\n').filter((l) => l.includes('GRANT EXECUTE ON FUNCTION'))
  assert.ok(grants.length > 0, 'nenhum GRANT EXECUTE encontrado')
  for (const linha of grants) {
    assert.doesNotMatch(
      linha,
      /\bauthenticated\b|\banon\b/,
      `grant permissivo reabre spoofing de registrado_por pela Data API: ${linha.trim()}`,
    )
  }
})

test('o REVOKE vem antes do GRANT de cada RPC', () => {
  for (const rpc of [...PORTADAS, ...NOVAS]) {
    const assinatura = `public.${rpc.nome}(${rpc.args})`
    const revoke = RPCS.indexOf(`REVOKE ALL ON FUNCTION ${assinatura} FROM PUBLIC;`)
    const grant = RPCS.indexOf(`GRANT EXECUTE ON FUNCTION ${assinatura} TO service_role;`)
    assert.ok(revoke >= 0 && grant >= 0, `grants de ${rpc.nome} ausentes`)
    assert.ok(revoke < grant, `${rpc.nome}: o REVOKE precisa vir antes do GRANT`)
  }
})

test('os helpers de app_private não ficam expostos na Data API', () => {
  for (const helper of ['resolve_autoria(text, uuid)', 'sync_array_from_allocations(uuid[])']) {
    for (const alvo of ['PUBLIC', 'anon', 'authenticated']) {
      assert.match(
        RPCS,
        new RegExp(`REVOKE ALL ON FUNCTION ${escapar(`app_private.${helper}`)} FROM ${alvo};`),
        `REVOKE ausente para app_private.${helper} / ${alvo}`,
      )
    }
  }
})

// ----------------------------------------------------------------------------
// 5. Assinatura retrocompatível
// ----------------------------------------------------------------------------

test('p_registrado_por_id é o ÚLTIMO parâmetro e tem DEFAULT NULL nas 4 RPCs portadas', () => {
  for (const rpc of PORTADAS) {
    const abertura = `CREATE OR REPLACE FUNCTION public.${rpc.nome}(`
    const inicio = RPCS.indexOf(abertura)
    assert.ok(inicio >= 0, `RPC ausente: ${rpc.nome}`)
    const fim = RPCS.indexOf(')\nRETURNS', inicio)
    assert.ok(fim > inicio, `não consegui delimitar a assinatura de ${rpc.nome}`)

    const params = RPCS.slice(inicio + abertura.length, fim)
      .split(',')
      .map((p) => p.trim())
      .filter(Boolean)

    assert.equal(
      params.at(-1),
      'p_registrado_por_id uuid DEFAULT NULL',
      `${rpc.nome}: o parâmetro de autoria precisa ser o último e ter DEFAULT NULL, senão a chamada posicional do web legado quebra`,
    )
    assert.equal(
      params.at(-2),
      rpc.anterior,
      `${rpc.nome}: a ordem dos parâmetros originais mudou, o que quebra chamada posicional`,
    )
  }
})

test('as 2 RPCs novas também aceitam o parâmetro opcional no fim', () => {
  for (const [nome, ultimo] of [
    ['auto_allocate_packing', 'p_registrado_por_id uuid DEFAULT NULL'],
    ['conferencia_rfid_evento', 'p_reader_id uuid DEFAULT NULL'],
  ] as const) {
    const abertura = `CREATE OR REPLACE FUNCTION public.${nome}(`
    const inicio = RPCS.indexOf(abertura)
    assert.ok(inicio >= 0, `RPC ausente: ${nome}`)
    const fim = RPCS.indexOf(')\nRETURNS', inicio)
    const params = RPCS.slice(inicio + abertura.length, fim)
      .split(',')
      .map((p) => p.trim())
      .filter(Boolean)
    assert.equal(params.at(-1), ultimo, `${nome}: último parâmetro inesperado`)
  }
})

test('as assinaturas legadas são removidas (sobrecarga viva quebraria a chamada por nome)', () => {
  for (const rpc of PORTADAS) {
    assert.match(
      RPCS,
      new RegExp(`DROP FUNCTION IF EXISTS ${escapar(`public.${rpc.nome}(${rpc.argsLegado})`)};`),
      `${rpc.nome}: sem o DROP da assinatura antiga, a chamada por nome do web legado vira "function is not unique"`,
    )
  }
})

test('o DROP das assinaturas antigas vem antes dos CREATE novos', () => {
  const ultimoDrop = Math.max(
    ...PORTADAS.map((rpc) => RPCS.indexOf(`DROP FUNCTION IF EXISTS public.${rpc.nome}(`)),
  )
  const primeiroCreate = Math.min(
    ...PORTADAS.map((rpc) => RPCS.indexOf(`CREATE OR REPLACE FUNCTION public.${rpc.nome}(`)),
  )
  assert.ok(ultimoDrop >= 0 && primeiroCreate >= 0)
  assert.ok(
    ultimoDrop < primeiroCreate,
    'DROP depois do CREATE apagaria a função nova quando as aridades coincidissem',
  )
})

// ----------------------------------------------------------------------------
// 6. Leitura relacional e autoria dentro das RPCs
// ----------------------------------------------------------------------------

test('as RPCs leem alocação de packing_allocations, não do array legado', () => {
  for (const rpc of PORTADAS) {
    const fn = corpo(RPCS, `CREATE OR REPLACE FUNCTION public.${rpc.nome}(`)
    assert.doesNotMatch(
      fn,
      /serial_numbers_designados/,
      `${rpc.nome} ainda lê o array legado; a fonte de verdade é packing_allocations`,
    )
  }
  const checkout = corpo(RPCS, 'CREATE OR REPLACE FUNCTION public.checkout_projeto(')
  assert.match(checkout, /FROM public\.packing_allocations pa/)
})

test('toda RPC portada resolve autoria antes de qualquer escrita', () => {
  for (const rpc of PORTADAS) {
    const fn = corpo(RPCS, `CREATE OR REPLACE FUNCTION public.${rpc.nome}(`)
    const resolve = fn.indexOf('app_private.resolve_autoria(')
    const insert = fn.indexOf('INSERT INTO public.')
    assert.ok(resolve >= 0, `${rpc.nome}: não resolve autoria`)
    if (insert >= 0) {
      assert.ok(resolve < insert, `${rpc.nome}: autoria precisa ser resolvida antes de gravar`)
    }
    assert.match(
      fn,
      /registrado_por_id/,
      `${rpc.nome}: precisa gravar o autor com FK, não só o label`,
    )
  }
})

test('o check-out audita antes de mutar e trava na ordem certa', () => {
  for (const nome of ['checkout_projeto', 'checkout_projeto_com_override']) {
    const fn = corpo(RPCS, `CREATE OR REPLACE FUNCTION public.${nome}(`)
    const lockProjeto = fn.indexOf('FROM public.projetos')
    const lockSeriais = fn.indexOf('PERFORM 1 FROM public.serial_numbers')
    const auditoria = fn.indexOf('INSERT INTO public.movimentacoes')
    const mutacao = fn.indexOf('UPDATE public.serial_numbers')
    assert.ok(lockProjeto >= 0 && lockSeriais >= 0 && auditoria >= 0 && mutacao >= 0)
    assert.ok(lockProjeto < lockSeriais, `${nome}: trava o Evento antes das unidades`)
    assert.ok(lockSeriais < auditoria, `${nome}: trava antes de auditar`)
    assert.ok(auditoria < mutacao, `${nome}: audita antes de mutar`)
  }
})

test('conferencia_rfid_evento trata tag de lote legado como DESCONHECIDA', () => {
  const fn = corpo(RPCS, 'CREATE OR REPLACE FUNCTION public.conferencia_rfid_evento(')
  assert.match(fn, /LEFT JOIN public\.lotes lo ON lo\.tag_rfid = l\.tag/)
  assert.match(fn, /'Tag RFID não reconhecida \/ Lote legado: ' \|\| r\.lote_codigo/)
  assert.match(
    fn,
    /WHEN r\.serial_id IS NULL THEN 'DESCONHECIDA'/,
    'lote nunca pode virar CONFIRMADO: a política é unit-only',
  )
  assert.doesNotMatch(
    fn,
    /lote_id/,
    'rfid_scans.lote_id não pode ser preenchido pela conferência (unit-only)',
  )
})

// ----------------------------------------------------------------------------
// 7. Deltas B, C e D
// ----------------------------------------------------------------------------

test('app_config nasce com o prefixo MMD e a função passa a lê-lo', () => {
  assert.match(CONFIG, /INSERT INTO public\.app_config \(key, value, descricao\) VALUES\s*\n\s*\('codigo_prefix', 'MMD'/)
  const fn = corpo(CONFIG, 'CREATE OR REPLACE FUNCTION public.generate_item_codigo_interno()')
  assert.match(fn, /FROM public\.app_config\s*\n\s*WHERE key = 'codigo_prefix'/)
  assert.doesNotMatch(fn, /'MMD-'/, 'o prefixo não pode continuar hardcoded na função')
  assert.match(fn, /pg_advisory_xact_lock/, 'o advisory lock por categoria não pode se perder')
})

test('as colunas de autoria têm FK para profiles com ON DELETE SET NULL', () => {
  const esperado = [
    ['movimentacoes', 'registrado_por_id'],
    ['checkout_overrides', 'registrado_por_id'],
    ['retorno_pendencias', 'registrado_por_id'],
    ['retorno_pendencias', 'resolvido_por_id'],
  ] as const
  for (const [tabela, coluna] of esperado) {
    assert.match(
      AUTORIA,
      new RegExp(`ADD COLUMN IF NOT EXISTS ${coluna} uuid`),
      `coluna ${tabela}.${coluna} ausente`,
    )
    assert.match(
      AUTORIA,
      new RegExp(
        `FOREIGN KEY \\(${coluna}\\) REFERENCES public\\.profiles\\(id\\) ON DELETE SET NULL`,
      ),
      `FK de ${tabela}.${coluna} precisa ser ON DELETE SET NULL para não apagar trilha`,
    )
  }
  assert.doesNotMatch(
    AUTORIA,
    /SET NOT NULL/,
    'as colunas de autoria são nullable: dado histórico não tem autor recuperável',
  )
  assert.match(AUTORIA, /CREATE TRIGGER trg_rfid_readers_updated_at/)
})

test('packing_list ganha índice e constraints sem nunca mesclar dado', () => {
  assert.match(PACKING, /CREATE INDEX IF NOT EXISTS idx_packing_list_projeto\s*\n?\s*ON public\.packing_list\(projeto_id\)/)
  assert.match(
    PACKING,
    /RAISE WARNING '[^']*duplicado/,
    'duplicata precisa virar aviso, não merge automático',
  )
  assert.match(PACKING, /CHECK \(quantidade > 0\) NOT VALID/)
  assert.match(PACKING, /VALIDATE CONSTRAINT packing_list_quantidade_positiva/)
  assert.match(
    PACKING,
    /EXCEPTION\s*\n\s*WHEN check_violation THEN/,
    'a validação precisa degradar para NOT VALID em vez de derrubar a migration',
  )
  for (const proibido of [/\bDELETE FROM public\.packing_list\b/, /\bUPDATE public\.packing_list\b/]) {
    assert.doesNotMatch(PACKING, proibido, 'a delta defensiva não pode escrever dado')
  }
})

test('a coluna legada é documentada como transitória', () => {
  assert.match(
    ALLOC_SQL,
    /COMMENT ON COLUMN public\.packing_list\.serial_numbers_designados IS/,
    'a coluna precisa carregar no banco o aviso de que é transitória',
  )
  assert.match(ALLOC_SQL, /LEGADO E TRANSITÓRIO/)
})
