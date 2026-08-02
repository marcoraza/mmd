-- Prova local dos constraints de destino do Evento.
-- Uso: docker exec -i supabase_db_mmd psql -U postgres -v ON_ERROR_STOP=1 < scripts/verify-destino-constraints.sql

BEGIN;

DELETE FROM public.projetos WHERE id = '99999999-9999-9999-9999-999999999999';

INSERT INTO public.projetos (id, nome, status)
VALUES ('99999999-9999-9999-9999-999999999999', 'Constraint Fixture', 'PLANEJAMENTO');

-- Legado: trio nulo
UPDATE public.projetos
SET destino_latitude = NULL, destino_longitude = NULL, destino_confirmado_em = NULL
WHERE id = '99999999-9999-9999-9999-999999999999';

-- Pin válido
UPDATE public.projetos
SET destino_latitude = -23.56,
    destino_longitude = -46.65,
    destino_confirmado_em = now()
WHERE id = '99999999-9999-9999-9999-999999999999';

DO $$
BEGIN
  BEGIN
    UPDATE public.projetos
    SET destino_latitude = -23.56, destino_longitude = NULL, destino_confirmado_em = now()
    WHERE id = '99999999-9999-9999-9999-999999999999';
    RAISE EXCEPTION 'expected incomplete pair to fail';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'incomplete pair rejected OK';
  END;

  BEGIN
    UPDATE public.projetos
    SET destino_latitude = 91, destino_longitude = 0, destino_confirmado_em = now()
    WHERE id = '99999999-9999-9999-9999-999999999999';
    RAISE EXCEPTION 'expected lat range to fail';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'lat range rejected OK';
  END;

  BEGIN
    UPDATE public.projetos
    SET destino_latitude = 0, destino_longitude = 181, destino_confirmado_em = now()
    WHERE id = '99999999-9999-9999-9999-999999999999';
    RAISE EXCEPTION 'expected lng range to fail';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'lng range rejected OK';
  END;

  BEGIN
    UPDATE public.projetos
    SET destino_latitude = -23.56,
        destino_longitude = -46.65,
        destino_confirmado_em = NULL
    WHERE id = '99999999-9999-9999-9999-999999999999';
    RAISE EXCEPTION 'expected missing timestamp with pin to fail';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'pin without timestamp rejected OK';
  END;
END $$;

DELETE FROM public.projetos WHERE id = '99999999-9999-9999-9999-999999999999';
COMMIT;
