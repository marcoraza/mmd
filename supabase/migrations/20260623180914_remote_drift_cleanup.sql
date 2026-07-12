-- Remove drift antigo do Supabase MMD que nao existe no schema local validado.
-- Policies anon_all_* abriam escrita anonima em tabelas internas.
DROP POLICY IF EXISTS anon_all_items ON public.items;
DROP POLICY IF EXISTS anon_all_serial_numbers ON public.serial_numbers;
DROP POLICY IF EXISTS anon_all_projetos ON public.projetos;
DROP POLICY IF EXISTS anon_all_packing_list ON public.packing_list;
DROP POLICY IF EXISTS anon_all_movimentacoes ON public.movimentacoes;
DROP POLICY IF EXISTS anon_all_lotes ON public.lotes;

-- Remove fixtures RFID demo aplicadas antes de o historico remoto estar alinhado.
DELETE FROM public.rfid_scans
WHERE reader_id IN (
  '11111111-1111-1111-1111-111111110001',
  '11111111-1111-1111-1111-111111110002',
  '11111111-1111-1111-1111-111111110003'
)
OR tag_rfid IN (
  'E2000017220B01041990E8E4',
  'E2000017220B01041990F123',
  'E2000017220B01041990ABCD'
);

DELETE FROM public.rfid_readers
WHERE id IN (
  '11111111-1111-1111-1111-111111110001',
  '11111111-1111-1111-1111-111111110002',
  '11111111-1111-1111-1111-111111110003'
)
OR serial_fabrica IN (
  'RFD40-A1B2C3',
  'RFD40-D4E5F6',
  'RFD40-G7H8I9'
);
