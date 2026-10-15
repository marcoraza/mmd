-- Corrige a trava de transição de status para cobrir MONTAGEM.
--
-- Contexto: 20260623193758_event_pro_import_official adicionou MONTAGEM ao
-- status_projeto_enum (entre CONFIRMADO e EM_CAMPO) e as RPCs de checkout
-- passaram a aceitar CONFIRMADO ou MONTAGEM. Porém a trava criada em
-- 20260712191500_projeto_status_transition_guard usa CASE sem ELSE e sem o
-- ramo MONTAGEM. Em PL/pgSQL, CASE sem ramo correspondente levanta
-- CASE_NOT_FOUND: qualquer evento em MONTAGEM ficava preso, inclusive o
-- UPDATE interno de checkout_projeto (MONTAGEM -> EM_CAMPO), abortando o
-- check-out inteiro.
--
-- Matriz de transições aceitas (agora completa):
--   PLANEJAMENTO -> CONFIRMADO, CANCELADO
--   CONFIRMADO   -> MONTAGEM, EM_CAMPO (via checkout_projeto), PLANEJAMENTO, CANCELADO
--   MONTAGEM     -> EM_CAMPO (via checkout_projeto), CONFIRMADO, CANCELADO
--   EM_CAMPO     -> FINALIZADO (via checkin_projeto)
--   FINALIZADO   -> terminal
--   CANCELADO    -> terminal
--
-- O ELSE fica fail-closed com mensagem clara: se um novo valor entrar no
-- enum sem ganhar ramo aqui, o erro aponta a causa em vez de CASE_NOT_FOUND.
--
-- Idempotente: CREATE OR REPLACE. O trigger trg_projeto_status_transition
-- criado em 20260712191500 continua válido e passa a usar esta versão.

CREATE OR REPLACE FUNCTION public.enforce_projeto_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  CASE OLD.status
    WHEN 'PLANEJAMENTO' THEN
      IF NEW.status NOT IN ('CONFIRMADO', 'CANCELADO') THEN
        RAISE EXCEPTION 'Transição inválida: % -> %', OLD.status, NEW.status;
      END IF;
    WHEN 'CONFIRMADO' THEN
      IF NEW.status NOT IN ('MONTAGEM', 'EM_CAMPO', 'PLANEJAMENTO', 'CANCELADO') THEN
        RAISE EXCEPTION 'Transição inválida: % -> %', OLD.status, NEW.status;
      END IF;
    WHEN 'MONTAGEM' THEN
      IF NEW.status NOT IN ('EM_CAMPO', 'CONFIRMADO', 'CANCELADO') THEN
        RAISE EXCEPTION 'Transição inválida: % -> %', OLD.status, NEW.status;
      END IF;
    WHEN 'EM_CAMPO' THEN
      IF NEW.status <> 'FINALIZADO' THEN
        RAISE EXCEPTION 'EM_CAMPO só transita para FINALIZADO via check-in';
      END IF;
    WHEN 'FINALIZADO' THEN
      RAISE EXCEPTION 'FINALIZADO é terminal, não aceita transição';
    WHEN 'CANCELADO' THEN
      RAISE EXCEPTION 'CANCELADO é terminal, não aceita transição';
    ELSE
      RAISE EXCEPTION 'Status % sem ramo na matriz de transição: atualize enforce_projeto_status_transition', OLD.status;
  END CASE;

  RETURN NEW;
END;
$$;
