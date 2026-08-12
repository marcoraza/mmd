-- Registro privado de clientes MCP e trilha de protocolo.
-- Nenhuma tabela de estoque é acessada por service_role neste contrato.
-- O uso privilegiado fica restrito a validar a credencial de um cliente MCP
-- e persistir sua auditoria, depois de o JWT humano/técnico ser verificado.

CREATE TABLE public.mcp_clients (
  client_id text PRIMARY KEY CHECK (client_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{2,127}$'),
  secret_hash text NOT NULL CHECK (secret_hash ~ '^[0-9a-f]{64}$'),
  scopes text[] NOT NULL DEFAULT ARRAY['mcp:read']::text[] CHECK (
    scopes <@ ARRAY['mcp:read', 'mcp:operate']::text[]
  ),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  CONSTRAINT mcp_clients_revocation_consistency CHECK (
    (active AND revoked_at IS NULL) OR (NOT active AND revoked_at IS NOT NULL)
  )
);

CREATE TABLE public.mcp_operation_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id text NOT NULL REFERENCES public.mcp_clients(client_id) ON DELETE RESTRICT,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  tool text NOT NULL CHECK (tool ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{2,127}$'),
  client_request_id text NOT NULL CHECK (client_request_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$'),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  intent text NOT NULL CHECK (intent IN ('READ', 'MUTATION')),
  outcome text NOT NULL CHECK (outcome IN ('SUCCEEDED', 'DENIED', 'FAILED')),
  receipt_id uuid REFERENCES public.conferencia_confirmacoes(id) ON DELETE RESTRICT,
  correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT mcp_operation_log_request_unique UNIQUE (
    client_id,
    actor_id,
    tool,
    client_request_id
  ),
  CONSTRAINT mcp_operation_log_completion_order CHECK (completed_at >= created_at)
);

CREATE INDEX mcp_operation_log_actor_created_idx
  ON public.mcp_operation_log(actor_id, created_at DESC);

CREATE TABLE public.mcp_rate_limit_buckets (
  client_id text NOT NULL REFERENCES public.mcp_clients(client_id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  window_started_at timestamptz NOT NULL,
  request_count integer NOT NULL DEFAULT 0 CHECK (request_count >= 0),
  PRIMARY KEY (client_id, actor_id, window_started_at)
);

CREATE OR REPLACE FUNCTION public.claim_mcp_rate_limit(
  p_client_id text,
  p_actor_id uuid,
  p_limit integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_window_started_at timestamptz := date_trunc('minute', now());
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Apenas o adaptador MCP pode reservar limite';
  END IF;
  IF p_limit < 1 OR p_limit > 1000 THEN
    RAISE EXCEPTION 'Limite MCP inválido';
  END IF;

  INSERT INTO public.mcp_rate_limit_buckets (
    client_id, actor_id, window_started_at, request_count
  ) VALUES (
    p_client_id, p_actor_id, v_window_started_at, 1
  )
  ON CONFLICT (client_id, actor_id, window_started_at)
  DO UPDATE SET request_count = mcp_rate_limit_buckets.request_count + 1
  WHERE mcp_rate_limit_buckets.request_count < p_limit;

  RETURN FOUND;
END;
$$;

ALTER TABLE public.mcp_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mcp_operation_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mcp_rate_limit_buckets ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.mcp_clients FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.mcp_operation_log FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.mcp_rate_limit_buckets FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.mcp_operation_log FROM authenticated;

GRANT SELECT ON TABLE public.mcp_operation_log TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.mcp_clients TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.mcp_operation_log TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.mcp_rate_limit_buckets TO service_role;

REVOKE ALL ON FUNCTION public.claim_mcp_rate_limit(text, uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.claim_mcp_rate_limit(text, uuid, integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_mcp_rate_limit(text, uuid, integer) TO service_role;

CREATE POLICY mcp_operation_log_actor_read ON public.mcp_operation_log
  FOR SELECT
  TO authenticated
  USING (actor_id = (SELECT auth.uid()) OR app_private.current_user_role() = 'admin');

COMMENT ON TABLE public.mcp_clients IS
  'Registro privado de clientes MCP. Apenas o adaptador servidor valida secret_hash; service_role não opera estoque por esta tabela.';

COMMENT ON TABLE public.mcp_operation_log IS
  'Auditoria sem bearer, segredo ou payload livre. Escrita vem do adaptador MCP após autenticar ator e cliente.';
