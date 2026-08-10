-- Corrige a trava de transição de status para cobrir MONTAGEM.
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
