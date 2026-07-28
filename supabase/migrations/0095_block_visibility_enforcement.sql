-- 0095_block_visibility_enforcement.sql
-- WP-413: Engelleme yaptırımının eksik yüzeyleri — süzgeç sunucuda.
--
-- 0092 engellemeyi yalnız `send_nudge` mutasyonunda zorluyordu. Sahibin v55 saha
-- turunda engellenen kişi hâlâ istatistik/liderlik tablolarında adıyla görünüyor
-- ve profili açılabiliyordu. Süzgeç istemcide olduğu için (a) atlanabiliyor,
-- (b) yeni yüzey eklendiğinde sessizce kaçıyordu. Bu migration süzgeci sunucuya
-- taşır ve iki yönlü uygular (A→B ve B→A aynı sonucu verir).
--
-- İşleyiş — üç katman:
--   1) `is_blocked_pair(a, b)`: iki yönlü engel kontrolü, tek doğruluk kaynağı.
--   2) `can_see_user_sessions(target)`: repodaki merkezi sosyal görünürlük
--      helper'ı engelli çifti reddeder. Bu tek değişiklik şu politikaları
--      birden daraltır: `study_sessions` (0010), `user_achievements` /
--      `gamification_profiles` / `achievement_metric_progress` (0024) ve
--      `profiles` (0036). Yani engellenen kişinin profili **doğrudan id ile
--      bile** açılamaz; sosyal profil ekranının beslendiği her tablo kapanır.
--      `group_daily_totals` SECURITY INVOKER olduğu için otomatik daralır.
--   3) SECURITY DEFINER grup RPC'leri RLS'i atladığından süzgeç **RPC'nin
--      içine** ayrı ayrı konur: `group_contribution_breakdown`,
--      `group_leaderboard_series`, `group_alpha_scores`.
--
-- 🔴 Kamp ateşi bilerek KAPSAM DIŞI ve bu migration onu korumak için iki yeni
-- dizin RPC'si ekler:
--   • `group_member_directory(gid)` — engellenen üyeyi listeden **silmez**;
--     satırı döndürür ama kimliğini (ad/avatar/hayvan) boşaltır ve
--     `is_blocked = true` işaretler. Böylece kamp ateşinde kişi sahneden
--     kaybolmaz, anonimleşir ve **katılımcı sayısı bozulmaz** (sahip cihazda
--     doğruladı: doğru davranış budur). Üye listesi de aynı kaynaktan beslenir.
--   • `blocked_user_directory()` — "Engellenen kullanıcılar" yönetim ekranı.
--     `profiles` artık engelli çifti reddettiği için kullanıcı kimi
--     engellediğini göremez hâle gelirdi; bu RPC yalnız **çağıranın kendi**
--     engellediklerini gerçek adıyla döndürür. Sosyal yüzey açmaz.
--
-- Muafiyet: `is_super_admin()` yalnız `profiles` politikasında zaten OR'lu
-- olduğu için moderasyon erişimi korunur; yeni muafiyet eklenmez.
--
-- Geri alma (Rollback):
--   -- can_see_user_sessions gövdesini 0009 haline döndür:
--   create or replace function public.can_see_user_sessions(target uuid)
--   returns boolean language sql security definer set search_path = public stable
--   as $$ select target = auth.uid() or exists (
--          select 1 from public.group_members me
--          join public.group_members other on other.group_id = me.group_id
--          where me.user_id = auth.uid() and me.left_at is null
--            and other.user_id = target) $$;
--   -- grup RPC'lerini 0041 (breakdown, series) ve 0061 (alpha) haline döndür.
--   drop function if exists public.group_member_directory(uuid);
--   drop function if exists public.blocked_user_directory();
--   drop function if exists public.is_blocked_pair(uuid, uuid);

-- ---------------------------------------------------------------------
-- 1. Tek doğruluk kaynağı: iki yönlü engel kontrolü
-- ---------------------------------------------------------------------
create or replace function public.is_blocked_pair(p_a uuid, p_b uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select p_a is not null
     and p_b is not null
     and p_a <> p_b
     and exists (
       select 1 from public.user_blocks
       where (blocker_id = p_a and blocked_id = p_b)
          or (blocker_id = p_b and blocked_id = p_a)
     );
$$;

revoke all on function public.is_blocked_pair(uuid, uuid) from public, anon;
grant execute on function public.is_blocked_pair(uuid, uuid) to authenticated;

comment on function public.is_blocked_pair(uuid, uuid) is
  'WP-413: symmetric block check; null-safe (service_role/edge calls see no block).';

-- ---------------------------------------------------------------------
-- 2. Merkezi sosyal görünürlük helper'ı engelli çifti reddeder
--    (study_sessions, gamification_profiles, user_achievements,
--     achievement_metric_progress ve profiles politikalarını birden daraltır)
-- ---------------------------------------------------------------------
create or replace function public.can_see_user_sessions(target uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select target = auth.uid() or (
    not public.is_blocked_pair(auth.uid(), target)
    and exists (
      select 1 from public.group_members me
      join public.group_members other on other.group_id = me.group_id
      where me.user_id = auth.uid() and me.left_at is null
        and other.user_id = target
        -- other.left_at filtrelenmez → ayrılan üyenin geçmiş oturumları
        -- kalan üyelere görünür kalır (0009 davranışı korunur)
    )
  );
$$;

comment on function public.can_see_user_sessions(uuid) is
  'WP-413: shared-active-group visibility, now denied for blocked pairs (both directions).';

-- ---------------------------------------------------------------------
-- 3. SECURITY DEFINER grup RPC'leri: süzgeç RPC'nin İÇİNDE
-- ---------------------------------------------------------------------
create or replace function public.group_contribution_breakdown(
  p_group_id uuid,
  p_from date,
  p_to date
)
returns table (user_id uuid, seconds int)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null or not public.is_group_member(p_group_id) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  select
    s.user_id,
    sum(s.duration_seconds)::int as seconds
  from public.study_sessions s
  inner join public.group_members gm
    on gm.user_id = s.user_id
   and gm.group_id = p_group_id
   and gm.left_at is null
  where ((s.start_time at time zone 'Europe/Istanbul')::date) between p_from and p_to
    -- WP-413: engellenen kişi tabloda görünmez (iki yönlü).
    and not public.is_blocked_pair(auth.uid(), s.user_id)
  group by s.user_id
  order by seconds desc;
end;
$$;

grant execute on function public.group_contribution_breakdown(uuid, date, date)
  to authenticated;

create or replace function public.group_leaderboard_series(
  p_group_id uuid,
  p_from date,
  p_to date
)
returns table (day date, user_id uuid, seconds int)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null or not public.is_group_member(p_group_id) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  select
    ((s.start_time at time zone 'Europe/Istanbul')::date) as day,
    s.user_id,
    sum(s.duration_seconds)::int as seconds
  from public.study_sessions s
  inner join public.group_members gm
    on gm.user_id = s.user_id
   and gm.group_id = p_group_id
   and gm.left_at is null
  where ((s.start_time at time zone 'Europe/Istanbul')::date) between p_from and p_to
    -- WP-413: engellenen kişi seride görünmez (iki yönlü).
    and not public.is_blocked_pair(auth.uid(), s.user_id)
  group by 1, 2
  order by 1, 3 desc;
end;
$$;

grant execute on function public.group_leaderboard_series(uuid, date, date)
  to authenticated;

create or replace function public.group_alpha_scores(p_group_id uuid)
returns table (user_id uuid, alpha_wins bigint)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null or not public.is_group_member(p_group_id) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  select
    gm.user_id,
    coalesce(sum(day.alpha_wins) filter (where day.finalized_at is not null), 0)::bigint
      as alpha_wins
  from public.group_members gm
  left join public.group_achievement_daily day
    on day.group_id = gm.group_id
   and day.user_id = gm.user_id
  where gm.group_id = p_group_id
    and gm.left_at is null
    -- WP-413: engellenen kişi alpha sıralamasında görünmez (iki yönlü).
    and not public.is_blocked_pair(auth.uid(), gm.user_id)
  group by gm.user_id
  order by alpha_wins desc, gm.user_id;
end;
$$;

revoke all on function public.group_alpha_scores(uuid) from public, anon;
grant execute on function public.group_alpha_scores(uuid) to authenticated;

comment on function public.group_contribution_breakdown(uuid, date, date) is
  'WP-413: member contribution seconds; member-only; blocked pairs filtered server-side.';
comment on function public.group_leaderboard_series(uuid, date, date) is
  'WP-413: per-day member seconds; member-only; blocked pairs filtered server-side.';
comment on function public.group_alpha_scores(uuid) is
  'WP-413: finalized alpha totals; member-only; blocked pairs filtered server-side.';

-- ---------------------------------------------------------------------
-- 4. Üye dizini: kamp ateşi ve üye listesi için ANONİMLEŞTİRME (silme değil)
-- ---------------------------------------------------------------------
create or replace function public.group_member_directory(p_group_id uuid)
returns table (
  id uuid,
  display_name text,
  avatar_url text,
  created_at timestamptz,
  daily_goal_minutes int,
  is_active boolean,
  animal text,
  monthly_report_opt_in boolean,
  is_blocked boolean
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null or not public.is_group_member(p_group_id) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  select
    p.id,
    -- 🔴 Engellenen üye listeden SİLİNMEZ: satır kalır, kimlik boşalır.
    -- Kamp ateşi bu sayede kişiyi sahnede tutar, anonim gösterir ve
    -- katılımcı sayısını bozmaz.
    case when v.blocked then '' else p.display_name end as display_name,
    case when v.blocked then null else p.avatar_url end as avatar_url,
    p.created_at,
    p.daily_goal_minutes,
    (gm.left_at is null) as is_active,
    case when v.blocked then null else p.animal end as animal,
    p.monthly_report_opt_in,
    v.blocked as is_blocked
  from public.group_members gm
  join public.profiles p on p.id = gm.user_id
  cross join lateral (
    select public.is_blocked_pair(auth.uid(), gm.user_id) as blocked
  ) v
  where gm.group_id = p_group_id;
end;
$$;

revoke all on function public.group_member_directory(uuid) from public, anon;
grant execute on function public.group_member_directory(uuid) to authenticated;

comment on function public.group_member_directory(uuid) is
  'WP-413: group roster for campfire/member list; blocked members stay in the row set but are anonymised (name/avatar/animal cleared, is_blocked=true) so the participant count is preserved.';

-- ---------------------------------------------------------------------
-- 5. "Engellenen kullanıcılar" yönetim ekranı
--    profiles artık engelli çifti reddediyor; kullanıcı kimi engellediğini
--    görebilmeli. Yalnız çağıranın KENDİ engellediklerini döndürür.
-- ---------------------------------------------------------------------
create or replace function public.blocked_user_directory()
returns table (
  id uuid,
  display_name text,
  avatar_url text,
  created_at timestamptz,
  blocked_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  return query
  select
    b.blocked_id as id,
    coalesce(p.display_name, '') as display_name,
    p.avatar_url,
    coalesce(p.created_at, to_timestamp(0)) as created_at,
    b.created_at as blocked_at
  from public.user_blocks b
  left join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by lower(coalesce(p.display_name, '')), b.blocked_id;
end;
$$;

revoke all on function public.blocked_user_directory() from public, anon;
grant execute on function public.blocked_user_directory() to authenticated;

comment on function public.blocked_user_directory() is
  'WP-413: caller-owned block list with real names for the management screen; opens no social surface.';
