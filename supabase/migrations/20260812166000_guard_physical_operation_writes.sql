-- O estado físico só muda dentro das RPCs canônicas. Um GUC de sessão não é
-- autorização, porque o próprio cliente pode definir seu valor. As RPCs
-- canônicas executam como SECURITY DEFINER sob o dono confiável das migrations;
-- DML direto por authenticated e service_role preserva o seu próprio current_user
-- e é rejeitado.

CREATE OR REPLACE FUNCTION app_private.require_physical_operation_write()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'PHYSICAL_OPERATION_WRITE_REQUIRES_RPC'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_serial_numbers_guard_physical_status_write
BEFORE UPDATE OF status ON public.serial_numbers
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION app_private.require_physical_operation_write();

CREATE TRIGGER trg_movimentacoes_guard_physical_write
BEFORE INSERT OR UPDATE OR DELETE ON public.movimentacoes
FOR EACH ROW
EXECUTE FUNCTION app_private.require_physical_operation_write();

CREATE TRIGGER trg_retorno_pendencias_guard_physical_write
BEFORE INSERT OR UPDATE OR DELETE ON public.retorno_pendencias
FOR EACH ROW
EXECUTE FUNCTION app_private.require_physical_operation_write();

REVOKE ALL ON FUNCTION app_private.require_physical_operation_write()
FROM PUBLIC, anon, authenticated, service_role;
