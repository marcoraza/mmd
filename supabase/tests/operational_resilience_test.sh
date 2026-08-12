#!/usr/bin/env bash
set -euo pipefail

# Exercita operações reais em duas sessões locais. O reset no início e no fim
# deixa a instância local exatamente nas migrations, sem fixture persistida.

resilience_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
resilience_tmp="$(mktemp -d)"
cd "$resilience_root"

cleanup() {
  supabase db reset --local --no-seed --yes >/dev/null
  rm -rf "$resilience_tmp"
}
trap cleanup EXIT

db_psql() {
  docker exec -i supabase_db_mmd psql -U postgres -d postgres -Atq -v ON_ERROR_STOP=1 "$@"
}

editor_sql() {
  db_psql <<SQL
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"f1111111-1111-1111-1111-111111111111","role":"authenticated"}';
$1
COMMIT;
SQL
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s (esperado %s, recebeu %s)\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

supabase db reset --local --no-seed --yes >/dev/null

db_psql <<'SQL'
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'f1111111-1111-1111-1111-111111111111',
  'authenticated',
  'authenticated',
  'resilience@test.local',
  '',
  now(),
  '{"provider":"email","providers":["email"]}',
  '{}',
  now(),
  now()
);

UPDATE public.profiles
SET role = 'editor'
WHERE id = 'f1111111-1111-1111-1111-111111111111';

INSERT INTO public.items (id, nome, categoria, quantidade_total)
VALUES
  ('f2222222-2222-2222-2222-222222222222', 'Fixture resiliência', 'ILUMINACAO', 4),
  ('f2222222-2222-2222-2222-222222222223', 'Fixture fora do packing', 'AUDIO', 1);

INSERT INTO public.serial_numbers (id, item_id, codigo_interno, qr_code)
VALUES
  ('f3333333-3333-3333-3333-333333333331', 'f2222222-2222-2222-2222-222222222222', 'MMD-ILU-RES001', 'QR-RES-001'),
  ('f3333333-3333-3333-3333-333333333332', 'f2222222-2222-2222-2222-222222222222', 'MMD-ILU-RES002', 'QR-RES-002'),
  ('f3333333-3333-3333-3333-333333333333', 'f2222222-2222-2222-2222-222222222222', 'MMD-ILU-RES003', 'QR-RES-003'),
  ('f3333333-3333-3333-3333-333333333334', 'f2222222-2222-2222-2222-222222222222', 'MMD-ILU-RES004', 'QR-RES-004'),
  ('f3333333-3333-3333-3333-333333333335', 'f2222222-2222-2222-2222-222222222223', 'MMD-AUD-RES005', 'QR-RES-005');

INSERT INTO public.projetos (id, nome, status)
VALUES
  ('f4444444-4444-4444-4444-444444444441', 'Evento timeout', 'CONFIRMADO'),
  ('f4444444-4444-4444-4444-444444444442', 'Evento concorrente', 'CONFIRMADO'),
  ('f4444444-4444-4444-4444-444444444443', 'Evento Revisar concorrente', 'CONFIRMADO');

INSERT INTO public.packing_list (id, projeto_id, item_id, quantidade, serial_numbers_designados)
VALUES
  ('f5555555-5555-5555-5555-555555555551', 'f4444444-4444-4444-4444-444444444441', 'f2222222-2222-2222-2222-222222222222', 1, ARRAY['f3333333-3333-3333-3333-333333333331'::uuid]),
  ('f5555555-5555-5555-5555-555555555552', 'f4444444-4444-4444-4444-444444444442', 'f2222222-2222-2222-2222-222222222222', 1, ARRAY['f3333333-3333-3333-3333-333333333332'::uuid]),
  ('f5555555-5555-5555-5555-555555555553', 'f4444444-4444-4444-4444-444444444443', 'f2222222-2222-2222-2222-222222222222', 1, ARRAY['f3333333-3333-3333-3333-333333333334'::uuid]);
SQL

editor_sql "
SELECT public.salvar_decisao_conferencia(
  'f4444444-4444-4444-4444-444444444441', 'SAIDA',
  'f3333333-3333-3333-3333-333333333331', 'PRESENTE', 'QRCODE',
  'resilience:timeout:scan', '2026-08-12T23:00:00Z', NULL, NULL,
  'resilience:timeout:decision'
);
" >/dev/null

db_psql >"$resilience_tmp/lock.log" <<'SQL' &
BEGIN;
SELECT 1
FROM public.conferencias
WHERE projeto_id = 'f4444444-4444-4444-4444-444444444441'
  AND direcao = 'SAIDA'
FOR UPDATE;
\echo locked
SELECT pg_sleep(1);
COMMIT;
SQL
lock_pid=$!

for _ in {1..40}; do
  if rg -q '^locked$' "$resilience_tmp/lock.log"; then
    break
  fi
  sleep 0.05
done
rg -q '^locked$' "$resilience_tmp/lock.log"

if editor_sql "
  SET LOCAL statement_timeout = '100ms';
  SELECT public.confirmar_conferencia_saida(
    (SELECT id FROM public.conferencias WHERE projeto_id = 'f4444444-4444-4444-4444-444444444441' AND direcao = 'SAIDA'),
    ARRAY[(SELECT id FROM public.conferencia_decisoes WHERE serial_number_id = 'f3333333-3333-3333-3333-333333333331')],
    1,
    'resilience:timeout:confirmation',
    NULL
  );
" >"$resilience_tmp/timeout.log" 2>&1; then
  printf 'FAIL: confirmação deveria expirar antes do commit\n' >&2
  exit 1
fi

rg -q 'statement timeout' "$resilience_tmp/timeout.log"
wait "$lock_pid"

assert_eq "$(db_psql -c "SELECT count(*) FROM public.conferencia_confirmacoes WHERE idempotency_key = 'resilience:timeout:confirmation';")" "0" "timeout pré-commit não cria Recibo"
assert_eq "$(db_psql -c "SELECT status::text FROM public.serial_numbers WHERE id = 'f3333333-3333-3333-3333-333333333331';")" "DISPONIVEL" "timeout pré-commit não altera Unidade"

# O resultado da confirmação é suprimido, a transação confirma e a sessão fica
# dormindo. Ao cortar o cliente neste ponto, simulamos a resposta perdida após
# commit, sem depender de um mock dentro da RPC.
db_psql >"$resilience_tmp/post-commit.log" 2>&1 <<'SQL' &
\o /dev/null
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"f1111111-1111-1111-1111-111111111111","role":"authenticated"}';
SELECT public.confirmar_conferencia_saida(
  (SELECT id FROM public.conferencias WHERE projeto_id = 'f4444444-4444-4444-4444-444444444441' AND direcao = 'SAIDA'),
  ARRAY[(SELECT id FROM public.conferencia_decisoes WHERE serial_number_id = 'f3333333-3333-3333-3333-333333333331')],
  1,
  'resilience:timeout:confirmation',
  NULL
);
COMMIT;
SELECT pg_sleep(5);
SQL
post_commit_pid=$!

for _ in {1..40}; do
  if [[ "$(db_psql -c "SELECT count(*) FROM public.conferencia_confirmacoes WHERE idempotency_key = 'resilience:timeout:confirmation';")" == "1" ]]; then
    break
  fi
  sleep 0.05
done
assert_eq "$(db_psql -c "SELECT count(*) FROM public.conferencia_confirmacoes WHERE idempotency_key = 'resilience:timeout:confirmation';")" "1" "commit ocorreu antes da resposta ser perdida"
kill -TERM "$post_commit_pid" || true
wait "$post_commit_pid" 2>/dev/null || true

timeout_ack="$(db_psql -c "SELECT id FROM public.conferencia_confirmacoes WHERE idempotency_key = 'resilience:timeout:confirmation';")"
timeout_retry_ack="$(editor_sql "
SELECT public.confirmar_conferencia_saida(
  (SELECT id FROM public.conferencias WHERE projeto_id = 'f4444444-4444-4444-4444-444444444441' AND direcao = 'SAIDA'),
  ARRAY[(SELECT id FROM public.conferencia_decisoes WHERE serial_number_id = 'f3333333-3333-3333-3333-333333333331')],
  1,
  'resilience:timeout:confirmation',
  NULL
) ->> 'confirmation_id';
")"
assert_eq "$timeout_retry_ack" "$timeout_ack" "retry após timeout do cliente devolve o Recibo persistido"

editor_sql "
SELECT public.salvar_decisao_conferencia(
  'f4444444-4444-4444-4444-444444444442', 'SAIDA',
  'f3333333-3333-3333-3333-333333333332', 'PRESENTE', 'QRCODE',
  'resilience:concurrent:scan', '2026-08-12T23:01:00Z', NULL, NULL,
  'resilience:concurrent:decision'
);
" >/dev/null

for worker in 1 2; do
  editor_sql "
  SELECT public.confirmar_conferencia_saida(
    (SELECT id FROM public.conferencias WHERE projeto_id = 'f4444444-4444-4444-4444-444444444442' AND direcao = 'SAIDA'),
    ARRAY[(SELECT id FROM public.conferencia_decisoes WHERE serial_number_id = 'f3333333-3333-3333-3333-333333333332')],
    1,
    'resilience:concurrent:confirmation',
    NULL
  ) ->> 'confirmation_id';
" >"$resilience_tmp/concurrent-$worker.log" &
  worker_pids[$worker]=$!
done
wait "${worker_pids[1]}"
wait "${worker_pids[2]}"

assert_eq "$(db_psql -c "SELECT count(*) FROM public.conferencia_confirmacoes WHERE idempotency_key = 'resilience:concurrent:confirmation';")" "1" "retry concorrente cria um só Recibo"
assert_eq "$(db_psql -c "SELECT count(*) FROM public.movimentacoes WHERE projeto_id = 'f4444444-4444-4444-4444-444444444442' AND tipo = 'SAIDA';")" "1" "retry concorrente cria uma só movimentação"

for worker in 1 2; do
  editor_sql "
  SELECT public.aplicar_vinculo_rfid(
    'f3333333-3333-3333-3333-333333333333',
    'E28011702000020A5C41F00A',
    'resilience:concurrent:rfid'
  ) ->> 'operation_id';
" >"$resilience_tmp/rfid-$worker.log" &
  rfid_pids[$worker]=$!
done
wait "${rfid_pids[1]}"
wait "${rfid_pids[2]}"

assert_eq "$(db_psql -c "SELECT count(*) FROM public.rfid_tag_operations WHERE idempotency_key = 'resilience:concurrent:rfid';")" "1" "retry concorrente cria uma só associação RFID"
assert_eq "$(db_psql -c "SELECT tag_rfid FROM public.serial_numbers WHERE id = 'f3333333-3333-3333-3333-333333333333';")" "E28011702000020A5C41F00A" "retry concorrente preserva uma única tag RFID"

editor_sql "
SELECT public.salvar_decisao_conferencia(
  'f4444444-4444-4444-4444-444444444443', 'SAIDA',
  'f3333333-3333-3333-3333-333333333335', 'PRESENTE', 'RFID',
  'resilience:exception:scan', '2026-08-12T23:02:00Z', NULL, NULL,
  'resilience:exception:decision'
);
" >/dev/null

for worker in 1 2; do
  editor_sql "
  SELECT public.resolver_excecao_conferencia_saida(
    (SELECT cd.id FROM public.conferencia_decisoes cd JOIN public.conferencias c ON c.id = cd.conferencia_id WHERE c.projeto_id = 'f4444444-4444-4444-4444-444444444443'),
    'ADICIONAR',
    1,
    'resilience:concurrent:exception'
  ) ->> 'resolution_id';
" >"$resilience_tmp/exception-$worker.log" &
  exception_pids[$worker]=$!
done
wait "${exception_pids[1]}"
wait "${exception_pids[2]}"

assert_eq "$(db_psql -c "SELECT count(*) FROM public.conferencia_excecao_resolucoes WHERE idempotency_key = 'resilience:concurrent:exception';")" "1" "retry concorrente cria uma só resolução de Revisar"
assert_eq "$(db_psql -c "SELECT version FROM public.conferencias WHERE projeto_id = 'f4444444-4444-4444-4444-444444444443' AND direcao = 'SAIDA';")" "2" "retry concorrente avança uma única versão de Revisar"

for worker in 1 2; do
  editor_sql "
  SELECT public.finalizar_conferencia_retorno(
    'f4444444-4444-4444-4444-444444444442',
    0,
    'resilience:concurrent:finalization'
  ) ->> 'finalization_id';
" >"$resilience_tmp/finalization-$worker.log" &
  finalization_pids[$worker]=$!
done
wait "${finalization_pids[1]}"
wait "${finalization_pids[2]}"

assert_eq "$(db_psql -c "SELECT count(*) FROM public.retorno_conferencia_finalizacoes WHERE projeto_id = 'f4444444-4444-4444-4444-444444444442';")" "1" "retry concorrente cria uma só finalização"
assert_eq "$(db_psql -c "SELECT count(*) FROM public.retorno_pendencias WHERE projeto_id = 'f4444444-4444-4444-4444-444444444442';")" "1" "retry concorrente cria uma só pendência"
assert_eq "$(db_psql -c "SELECT count(*) FROM public.movimentacoes WHERE projeto_id = 'f4444444-4444-4444-4444-444444444442' AND tipo = 'RETORNO';")" "1" "retry concorrente cria uma só movimentação de retorno"

printf 'PASS: timeout pré/pós-commit e retry concorrente preservam um único efeito operacional.\n'
