-- Movimentação física passa exclusivamente pela Conferência autenticada. Estas
-- RPCs históricas continuam no schema para não reescrever migrations antigas,
-- mas não são mais executáveis por nenhum papel do Data API.

REVOKE ALL ON FUNCTION public.checkout_projeto(
  uuid,
  public.metodo_scan_enum,
  text
) FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.checkout_projeto_com_override(
  uuid,
  public.metodo_scan_enum,
  text,
  uuid
) FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.checkin_projeto(
  uuid,
  public.metodo_scan_enum,
  text,
  jsonb
) FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.resolver_retorno_pendencia(
  uuid,
  text,
  text,
  text
) FROM PUBLIC, anon, authenticated, service_role;
