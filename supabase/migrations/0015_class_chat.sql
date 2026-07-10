-- 0015_class_chat.sql
-- Sınıf sohbeti: mesajlar yalnızca aktif grup üyeleri tarafından okunur ve
-- yazılır. İstemci tarafı kontroller kozmetiktir; gerçek yetki RLS'tedir.

create table if not exists public.class_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (
    char_length(trim(body)) between 1 and 500
  ),
  created_at timestamptz not null default now()
);

create index if not exists idx_class_messages_group_created
  on public.class_messages (group_id, created_at desc);

create index if not exists idx_class_messages_user_created
  on public.class_messages (user_id, created_at desc);

alter table public.class_messages enable row level security;

drop policy if exists class_messages_select on public.class_messages;
create policy class_messages_select on public.class_messages
  for select to authenticated
  using (public.is_group_member(group_id));

drop policy if exists class_messages_insert on public.class_messages;
create policy class_messages_insert on public.class_messages
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and public.is_group_member(group_id)
  );

do $$
begin
  alter publication supabase_realtime add table public.class_messages;
exception
  when duplicate_object then null;
end $$;
