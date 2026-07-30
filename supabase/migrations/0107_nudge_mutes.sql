-- 0107_nudge_mutes.sql
-- WP-444: Kişi bazlı "yalnız dürtmeyi sessize al" tercihi.
--
-- Sözleşme (progress.md WP-444 · Faz 2 tasarım kararı, sabit):
--   * `nudge_mutes(user_id, muted_sender_id, created_at)`
--   * `mute_nudges_from` / `unmute_nudges_from` / `nudge_mute_directory`
--   * `send_nudge` susturulmuş alıcı için satır/realtime/outbox ÜRETMEZ,
--     fakat gönderene normal bir satır döndürür ve cooldown penceresini yine
--     işler (bastırılmış deneme kaydı). Aksi hâlde "ikinci dürtme hemen kabul
--     edildi" farkı tercihi ifşa ederdi.
--
-- Yan kanal analizi:
--   * Push outbox `0066`'daki `nudges_enqueue_push` AFTER INSERT trigger'ından
--     gelir; satır yazmadığımız için outbox ve realtime kendiliğinden susar.
--   * `nudge_suppressed_attempts` üzerinde HİÇBİR RLS policy'si yoktur →
--     PostgREST'ten kimse okuyamaz; yalnız SECURITY DEFINER fonksiyonu yazar.
--     Göndericiye select hakkı verilseydi tercih doğrudan ifşa olurdu.
--   * Susturma engelleme (`user_blocks`) DEĞİLDİR: mesaj/profil/grup erişimi
--     etkilenmez, yalnız dürtme düşmez.
--
-- Blok muafiyeti (grup sahibi / süper admin) susturmaya UYGULANMAZ: susturma
-- kullanıcının kendi tercihidir, yönetim yükümlülüğü argümanı yalnız blok
-- içindi. `0092`'nin send_nudge gövdesi korunur, üzerine muted dalı eklenir.

-- 1) Tercih tablosu -----------------------------------------------------------

create table if not exists public.nudge_mutes (
  user_id         uuid not null references auth.users (id) on delete cascade,
  muted_sender_id uuid not null references auth.users (id) on delete cascade,
  created_at      timestamptz not null default now(),
  primary key (user_id, muted_sender_id),
  check (user_id <> muted_sender_id)
);

create index if not exists idx_nudge_mutes_lookup
  on public.nudge_mutes (user_id, muted_sender_id);

alter table public.nudge_mutes enable row level security;

-- Yalnız kendi tercihini okuyabilir; kimse başkasının listesini göremez.
drop policy if exists nudge_mutes_select on public.nudge_mutes;
create policy nudge_mutes_select on public.nudge_mutes
  for select to authenticated
  using (user_id = auth.uid());

-- Doğrudan yazma yok: RPC'lerden geçer (idempotency ve self-mute kuralı
-- istemciye bırakılamaz).
drop policy if exists nudge_mutes_insert on public.nudge_mutes;
drop policy if exists nudge_mutes_update on public.nudge_mutes;
drop policy if exists nudge_mutes_delete on public.nudge_mutes;

-- 2) Bastırılmış deneme kaydı (cooldown pariteleri için) ----------------------
-- Okunamaz: policy tanımlanmaz, RLS açıktır → deny all.

create table if not exists public.nudge_suppressed_attempts (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups (id) on delete cascade,
  sender_id    uuid not null references auth.users (id) on delete cascade,
  recipient_id uuid not null references auth.users (id) on delete cascade,
  created_at   timestamptz not null default now()
);

create index if not exists idx_nudge_suppressed_cooldown
  on public.nudge_suppressed_attempts (group_id, sender_id, recipient_id, created_at desc);

alter table public.nudge_suppressed_attempts enable row level security;

-- 3) Tercih RPC'leri ----------------------------------------------------------

create or replace function public.mute_nudges_from(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
begin
  if v_caller is null then
    raise exception 'not_authenticated';
  end if;
  if p_user_id is null then
    raise exception 'invalid_target';
  end if;
  if v_caller = p_user_id then
    raise exception 'cannot_mute_self';
  end if;

  insert into public.nudge_mutes (user_id, muted_sender_id)
  values (v_caller, p_user_id)
  on conflict (user_id, muted_sender_id) do nothing;   -- idempotent
end;
$$;

create or replace function public.unmute_nudges_from(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
begin
  if v_caller is null then
    raise exception 'not_authenticated';
  end if;

  delete from public.nudge_mutes
  where user_id = v_caller and muted_sender_id = p_user_id;  -- idempotent
end;
$$;

-- Yönetim ekranı listesi. Yalnız çağıranın kendi tercihi; ad/avatar
-- okunamazsa null döner ve ekran maskeli ad üretir.
create or replace function public.nudge_mute_directory()
returns table (
  muted_sender_id uuid,
  muted_at        timestamptz,
  display_name    text,
  avatar_url      text
)
language sql
security definer
set search_path = public
as $$
  select m.muted_sender_id,
         m.created_at as muted_at,
         nullif(p.display_name, '') as display_name,
         p.avatar_url
  from public.nudge_mutes m
  left join public.profiles p on p.id = m.muted_sender_id
  where m.user_id = auth.uid()
  order by m.created_at desc;
$$;

grant execute on function public.mute_nudges_from(uuid) to authenticated;
grant execute on function public.unmute_nudges_from(uuid) to authenticated;
grant execute on function public.nudge_mute_directory() to authenticated;

-- 4) send_nudge — susturmayı yan kanal açmadan uygula -------------------------
-- `0092`'nin gövdesi korunur; yalnız cooldown kaynağı genişler ve muted dalı
-- eklenir. Hata mesajları, sıraları ve cooldown davranışı DEĞİŞMEZ.

create or replace function public.send_nudge(
  p_group_id uuid,
  p_recipient_id uuid,
  p_message text default null
)
returns public.nudges
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender uuid := auth.uid();
  v_message text := nullif(trim(coalesce(p_message, '')), '');
  v_row public.nudges;
  v_block_exempt boolean;
  v_muted boolean;
begin
  if v_sender is null then
    raise exception 'not_authenticated';
  end if;
  if v_sender = p_recipient_id then
    raise exception 'cannot_nudge_self';
  end if;
  if char_length(coalesce(v_message, '')) > 120 then
    raise exception 'message_too_long';
  end if;
  if not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = v_sender and left_at is null
  ) or not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = p_recipient_id and left_at is null
  ) then
    raise exception 'not_group_member';
  end if;

  -- F2: grup sahibi veya platform yöneticisi, yönetim yükümlülükleri için muaf.
  select public.is_group_admin(p_group_id)
    or public.is_super_admin()
    or exists (select 1 from public.groups where id = p_group_id and created_by = p_recipient_id)
    or exists (select 1 from public.app_admins where user_id = p_recipient_id)
  into v_block_exempt;

  if not v_block_exempt and exists (
    select 1 from public.user_blocks
    where (blocker_id = v_sender and blocked_id = p_recipient_id)
       or (blocker_id = p_recipient_id and blocked_id = v_sender)
  ) then
    raise exception 'nudge_blocked';
  end if;

  -- WP-444: cooldown penceresi gerçek ve bastırılmış denemeleri birlikte sayar.
  -- Yalnız `nudges` sayılsaydı susturulmuş alıcıya art arda dürtme kabul edilir,
  -- gönderen tercihi bu farktan okurdu.
  if exists (
    select 1 from public.nudges
    where group_id = p_group_id and sender_id = v_sender and recipient_id = p_recipient_id
      and created_at > now() - interval '10 minutes'
  ) or exists (
    select 1 from public.nudge_suppressed_attempts
    where group_id = p_group_id and sender_id = v_sender and recipient_id = p_recipient_id
      and created_at > now() - interval '10 minutes'
  ) then
    raise exception 'nudge_cooldown';
  end if;

  select exists (
    select 1 from public.nudge_mutes
    where user_id = p_recipient_id and muted_sender_id = v_sender
  ) into v_muted;

  if v_muted then
    -- Satır yok → realtime yok → `nudges_enqueue_push` tetiklenmez → outbox yok.
    insert into public.nudge_suppressed_attempts (group_id, sender_id, recipient_id)
    values (p_group_id, v_sender, p_recipient_id);

    v_row.id := gen_random_uuid();
    v_row.group_id := p_group_id;
    v_row.sender_id := v_sender;
    v_row.recipient_id := p_recipient_id;
    v_row.message := v_message;
    v_row.created_at := now();
    v_row.read_at := null;
    return v_row;
  end if;

  insert into public.nudges (group_id, sender_id, recipient_id, message)
  values (p_group_id, v_sender, p_recipient_id, v_message)
  returning * into v_row;
  return v_row;
end;
$$;

grant execute on function public.send_nudge(uuid, uuid, text) to authenticated;
