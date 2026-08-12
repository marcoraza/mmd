-- Reconcilia o drift remoto: estas seis tabelas já possuem policies versionadas,
-- mas chegaram ao advisor com RLS desligada. Falha antes de ativar RLS se uma
-- policy esperada sumiu, para não interromper consumidores autenticados.
DO $$
DECLARE
  missing_policies text;
BEGIN
  SELECT string_agg(expected.table_name || '.' || expected.policy_name, ', ')
  INTO missing_policies
  FROM (
    VALUES
      ('items', 'items_read'),
      ('items', 'items_insert'),
      ('items', 'items_update'),
      ('items', 'items_delete'),
      ('serial_numbers', 'serial_numbers_read'),
      ('serial_numbers', 'serial_numbers_insert'),
      ('serial_numbers', 'serial_numbers_update'),
      ('serial_numbers', 'serial_numbers_delete'),
      ('projetos', 'projetos_read'),
      ('projetos', 'projetos_insert'),
      ('projetos', 'projetos_update'),
      ('projetos', 'projetos_delete'),
      ('packing_list', 'packing_list_read'),
      ('packing_list', 'packing_list_insert'),
      ('packing_list', 'packing_list_update'),
      ('packing_list', 'packing_list_delete'),
      ('movimentacoes', 'movimentacoes_read'),
      ('movimentacoes', 'movimentacoes_insert'),
      ('movimentacoes', 'movimentacoes_update'),
      ('movimentacoes', 'movimentacoes_delete'),
      ('lotes', 'lotes_read'),
      ('lotes', 'lotes_insert'),
      ('lotes', 'lotes_update'),
      ('lotes', 'lotes_delete')
  ) AS expected(table_name, policy_name)
  LEFT JOIN pg_policies policy
    ON policy.schemaname = 'public'
   AND policy.tablename = expected.table_name
   AND policy.policyname = expected.policy_name
  WHERE policy.policyname IS NULL;

  IF missing_policies IS NOT NULL THEN
    RAISE EXCEPTION 'LEGACY_RLS_POLICY_MISSING: %', missing_policies
      USING ERRCODE = '55000';
  END IF;
END;
$$;

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.serial_numbers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projetos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packing_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimentacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lotes ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE
  public.items,
  public.serial_numbers,
  public.projetos,
  public.packing_list,
  public.movimentacoes,
  public.lotes
FROM PUBLIC, anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.items,
  public.serial_numbers,
  public.projetos,
  public.packing_list,
  public.movimentacoes,
  public.lotes
TO authenticated;
