create table if not exists public.training_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  track text not null check (track in ('web', 'ios')),
  chapter_id text not null,
  completed_at timestamptz not null default now(),
  primary key (user_id, track, chapter_id)
);

alter table public.training_progress enable row level security;

create policy "training_progress_select_own"
  on public.training_progress
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "training_progress_insert_own"
  on public.training_progress
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "training_progress_update_own"
  on public.training_progress
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "training_progress_delete_own"
  on public.training_progress
  for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.training_progress to authenticated;
