-- Trava de transição de status de evento no nível do banco.
--
-- Absorvido da branch fix/checkin-security (migration 00008 nunca aplicada).
-- Os outros dois itens daquela migration (pertencimento de serial e cobertura
-- total no check-in) já foram cobertos por 20260623094805_return_pending_resolution.
-- Este é o pedaço que faltava: nada impedia UPDATE direto em projetos.status
-- de pular estados (kanban arrastando EM_CAMPO pra FINALIZADO sem check-in,
-- updateProjetoStatus sem regra, ou UPDATE manual no banco).
--
-- Matriz de transições aceitas:
--   PLANEJAMENTO -> CONFIRMADO, CANCELADO
--   CONFIRMADO   -> EM_CAMPO (via checkout_projeto), PLANEJAMENTO, CANCELADO
--   EM_CAMPO     -> FINALIZADO (via checkin_projeto)
--   FINALIZADO   -> terminal
--   CANCELADO    -> terminal
--
-- Compatibilidade validada contra os fluxos atuais:
--   checkout_projeto exige CONFIRMADO e seta EM_CAMPO (ok);
--   checkin_projeto exige EM_CAMPO e seta FINALIZADO (ok);
--   importador Event Pro só faz INSERT, trigger é BEFORE UPDATE (ok);
--   kanban do web passa a receber erro em transição inválida (intencional).
--
-- Consequência assumida: FINALIZADO e CANCELADO são terminais. Reabrir evento
-- finalizado por engano exige intervenção administrativa no banco.
--
-- Idempotente: CREATE OR REPLACE na função, DROP TRIGGER IF EXISTS antes do
-- CREATE TRIGGER.

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
      IF NEW.status NOT IN ('EM_CAMPO', 'PLANEJAMENTO', 'CANCELADO') THEN
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
  END CASE;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_projeto_status_transition ON public.projetos;
CREATE TRIGGER trg_projeto_status_transition
  BEFORE UPDATE OF status ON public.projetos
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_projeto_status_transition();
