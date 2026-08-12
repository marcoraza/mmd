CREATE OR REPLACE FUNCTION app_private.reject_direct_rfid_tag_write()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  -- A configuração de sessão não é uma autorização: qualquer cliente que
  -- tenha conexão SQL pode forjá-la. As RPCs canônicas são SECURITY DEFINER
  -- e, por isso, executam DML como o dono confiável das migrations.
  IF NEW.tag_rfid IS DISTINCT FROM OLD.tag_rfid
     AND current_user <> 'postgres' THEN
    RAISE EXCEPTION 'RFID_TAG_WRITE_REQUIRES_OPERATION'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_serial_numbers_guard_rfid_tag_write
BEFORE UPDATE OF tag_rfid ON public.serial_numbers
FOR EACH ROW
EXECUTE FUNCTION app_private.reject_direct_rfid_tag_write();

REVOKE ALL ON FUNCTION app_private.reject_direct_rfid_tag_write()
FROM PUBLIC, anon, authenticated, service_role;
