-- Supabase OAuth usa `sub` como identificador canônico do usuário. O MCP
-- mantém `user_id` como claim redundante e exige igualdade entre ambos para
-- rejeitar tokens montados com identidades divergentes.

CREATE OR REPLACE FUNCTION public.mmd_custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_claims jsonb := coalesce(event->'claims', '{}'::jsonb);
  v_client_id text := coalesce(event->>'client_id', event->'claims'->>'client_id');
  v_actor_id text := event->'claims'->>'sub';
  v_resource_audience text;
  v_scopes text[];
BEGIN
  SELECT client.resource_audience, client.scopes
    INTO v_resource_audience, v_scopes
  FROM public.mcp_clients AS client
  WHERE client.client_id = v_client_id
    AND client.active
    AND client.revoked_at IS NULL;

  IF NOT FOUND OR v_actor_id IS NULL OR v_actor_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    RETURN jsonb_build_object('claims', v_claims);
  END IF;

  v_claims := jsonb_set(v_claims, '{aud}', to_jsonb(v_resource_audience), true);
  v_claims := jsonb_set(v_claims, '{user_id}', to_jsonb(v_actor_id), true);
  v_claims := jsonb_set(v_claims, '{mcp_scopes}', to_jsonb(v_scopes), true);
  RETURN jsonb_build_object('claims', v_claims);
END;
$$;

REVOKE ALL ON FUNCTION public.mmd_custom_access_token_hook(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mmd_custom_access_token_hook(jsonb) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.mmd_custom_access_token_hook(jsonb) TO supabase_auth_admin;
