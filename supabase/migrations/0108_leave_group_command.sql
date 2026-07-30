-- 0108_leave_group_command.sql
-- WP-445: Gruptan çıkış idempotent, sunucu-otoriter ve atomik olur.
--
-- Önceki durum: istemci `group_members` satırını doğrudan UPDATE ediyordu
-- (`removeMember`). Kullanıcı kimliği istemciden geliyordu, komut tekrarı
-- ayırt edilemiyordu ve sahiplik kuralı hiç yoktu — hızlı çift tap iki ayrı
-- mutasyon, zaman aşımında yapılan retry ise "çıkmış mı çıkmamış mı" belirsizliği
-- üretiyordu.
--
-- Sözleşme:
--   * `leave_group(p_group_id, p_command_id)` yalnız `auth.uid()` ile çalışır;
--     istemcinin gönderdiği kullanıcı kimliğine güvenilmez.
--   * `p_command_id` idempotency anahtarıdır. Aynı anahtarla tekrar çağırmak
--     işi TEKRAR YAPMAZ, ilk çağrının sonucunu döndürür. İstemci tek kullanıcı
--     hareketi için tek anahtar üretir ve retry'da aynısını gönderir.
--   * Çıkış soft-delete'tir (`0008`): satır silinmez, `left_at` yazılır.
--     `0079`'daki `group_members_primary_group_reconcile` trigger'ı `left_at`
--     UPDATE'inde ateşlendiği için birincil grup uzlaşması aynı işlemde olur.
--   * `group_live_presence` satırı aynı işlemde silinir: ayrılan kişi kamp
--     ateşinde asılı kalmaz.
--
-- Sahiplik değişmezi: grup sahibi (`groups.created_by`) gruptan çıkamaz —
-- aksi hâlde sahipsiz grup kalırdı. Devretme veya silme yolu açıktır ve UI
-- sahibe düz "çık" yerine bu iki yolu gösterir.

create table if not exists public.group_leave_commands (
  command_id uuid primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  group_id   uuid not null references public.groups (id) on delete cascade,
  outcome    text not null check (outcome in ('left', 'already_left')),
  created_at timestamptz not null default now()
);

create index if not exists group_leave_commands_user_idx
  on public.group_leave_commands (user_id, created_at desc);

alter table public.group_leave_commands enable row level security;

-- Yalnız kendi komut geçmişini okur; yazma tek yoldan, RPC'den geçer.
drop policy if exists group_leave_commands_select_own on public.group_leave_commands;
create policy group_leave_commands_select_own on public.group_leave_commands
  for select to authenticated
  using (user_id = auth.uid());

create or replace function public.leave_group(
  p_group_id uuid,
  p_command_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_outcome text;
  v_owner uuid;
  v_is_active boolean;
  v_is_admin boolean;
  v_other_members integer;
  v_other_admins integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_group_id is null or p_command_id is null then
    raise exception 'invalid_leave_command';
  end if;

  -- Aynı kullanıcı+grup için tüm çıkış komutlarını sıraya sokar: 20 hızlı tap
  -- da, zaman aşımı sonrası retry de bu kapıdan tek tek geçer.
  perform pg_advisory_xact_lock(
    hashtext(v_uid::text || ':' || p_group_id::text)
  );

  -- 1) Tekrar (replay): iş yeniden yapılmaz, ilk sonuç aynen döner.
  select outcome into v_outcome
  from public.group_leave_commands
  where command_id = p_command_id;

  if found then
    if not exists (
      select 1 from public.group_leave_commands
      where command_id = p_command_id and user_id = v_uid and group_id = p_group_id
    ) then
      -- Anahtar başkasının ya da başka grubun komutu: sessizce kabul edilmez.
      raise exception 'leave_command_mismatch';
    end if;
    return v_outcome;
  end if;

  select created_by into v_owner from public.groups where id = p_group_id;
  if v_owner is null then
    raise exception 'group_not_found';
  end if;

  select (left_at is null), (role = 'admin')
  into v_is_active, v_is_admin
  from public.group_members
  where group_id = p_group_id and user_id = v_uid;

  -- 2) Zaten üye değil (ya da hiç olmadı): idempotent "already_left".
  --    Hata DEĞİLDİR; aksi hâlde çevrimdışı retry sahte hata gösterirdi.
  if v_is_active is null or v_is_active = false then
    insert into public.group_leave_commands (command_id, user_id, group_id, outcome)
    values (p_command_id, v_uid, p_group_id, 'already_left');
    return 'already_left';
  end if;

  select count(*) into v_other_members
  from public.group_members
  where group_id = p_group_id and user_id <> v_uid and left_at is null;

  -- 3) Sahiplik değişmezi: sahip çıkarsa grup sahipsiz kalır.
  if v_uid = v_owner then
    raise exception 'owner_must_transfer_or_delete';
  end if;

  -- 4) Son yönetici koruması. Sahip çıkamadığı için normalde ulaşılamaz;
  --    sahibi silinmiş eski gruplar için güvenlik ağı olarak durur.
  if v_is_admin and v_other_members > 0 then
    select count(*) into v_other_admins
    from public.group_members
    where group_id = p_group_id and user_id <> v_uid
      and left_at is null and role = 'admin';
    if v_other_admins = 0 then
      raise exception 'last_admin_must_transfer';
    end if;
  end if;

  -- 5) Çıkış: soft-delete + presence temizliği aynı işlemde.
  update public.group_members
  set left_at = now()
  where group_id = p_group_id and user_id = v_uid and left_at is null;

  delete from public.group_live_presence
  where group_id = p_group_id and user_id = v_uid;

  insert into public.group_leave_commands (command_id, user_id, group_id, outcome)
  values (p_command_id, v_uid, p_group_id, 'left');

  return 'left';
end;
$$;

grant execute on function public.leave_group(uuid, uuid) to authenticated;
