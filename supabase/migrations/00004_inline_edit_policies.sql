-- Inline edit (fase 1.5): permite que anon altere quantidade de itens
-- e desgaste de serial_numbers. Temporário até implementar Supabase Auth no fim
-- do projeto. Aceitável porque o site é privado e a URL não é divulgada.

-- Items: update quantidade_total
drop policy if exists "catalog_update_qtd" on items;
create policy "catalog_update_qtd"
  on items
  for update
  to anon
  using (true)
  with check (true);

-- Serial numbers: update desgaste (condição)
drop policy if exists "serials_update_desgaste" on serial_numbers;
create policy "serials_update_desgaste"
  on serial_numbers
  for update
  to anon
  using (true)
  with check (true);
