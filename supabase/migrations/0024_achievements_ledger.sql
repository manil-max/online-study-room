-- =====================================================================
-- 0024_achievements_ledger.sql — Başarım 3.0 R1 (WP-56)
-- Server-authoritative XP ledger + achievements_dict + process RPC.
--
-- Kurallar (docs/BASARIM-MIMARISI.md · KALITE-PROGRAMI §8.6):
--   • İstemci XP yazamaz; yalnız olay fırlatır (RPC).
--   • xp_ledger append-only; event_key UNIQUE (idempotency).
--   • gamification_profiles.xp / crown_rank yalnız ledger tetikleyicisi yazar.
--   • Sosyal okuma: can_see_user_sessions (B7 sıkılaştırma).
--
-- Geri alma (özet):
--   drop function public.process_achievement_event;
--   drop function public._award_achievement_tier;
--   drop function public._recalc_crown_rank;
--   drop function public._guard_gamification_xp_write;
--   drop trigger trg_xp_ledger_apply / trg_guard_gamification_xp on ...;
--   drop table public.xp_ledger, public.achievements_dict;
--   (RLS politikaları önceki 0017/0022 hâline dönmek ayrı adım)
--
-- Çalıştırma: Supabase SQL Editor → sırayla (0023 sonrası) → Run.
-- Tekrar-çalıştırılabilir (idempotent) olacak şekilde yazıldı.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Sözlük: achievements_dict
-- ---------------------------------------------------------------------
create table if not exists public.achievements_dict (
  id text primary key,
  category text not null check (category in (
    'study', 'streak', 'group', 'social', 'secret'
  )),
  name text not null,
  description text not null,
  max_tier integer not null check (max_tier between 1 and 6),
  icon_key text not null default 'emoji_events',
  is_secret boolean not null default false,
  -- tiers: [{ "tier":1, "threshold":50, "unit":"hours", "xp":100 }, ...]
  tiers jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.achievements_dict enable row level security;

drop policy if exists achievements_dict_select on public.achievements_dict;
create policy achievements_dict_select on public.achievements_dict
  for select to authenticated
  using (true);

-- İstemci yazamaz (yalnız migration / service_role)
revoke insert, update, delete on public.achievements_dict from authenticated, anon;

-- ---------------------------------------------------------------------
-- 2) Append-only XP ledger
-- ---------------------------------------------------------------------
create table if not exists public.xp_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  achievement_id text not null references public.achievements_dict (id),
  tier integer not null check (tier between 1 and 6),
  xp_amount integer not null check (xp_amount >= 0),
  reason text,
  event_key text not null,
  created_at timestamptz not null default now(),
  unique (event_key)
);

create index if not exists xp_ledger_user_id_idx on public.xp_ledger (user_id);
create index if not exists xp_ledger_user_achievement_idx
  on public.xp_ledger (user_id, achievement_id);

alter table public.xp_ledger enable row level security;

-- Okuma: kendi veya ortak aktif grup (sosyal vitrin)
drop policy if exists xp_ledger_select on public.xp_ledger;
create policy xp_ledger_select on public.xp_ledger
  for select to authenticated
  using (public.can_see_user_sessions(user_id));

-- Doğrudan yazım yok; yalnız SECURITY DEFINER RPC / trigger zinciri
revoke insert, update, delete on public.xp_ledger from authenticated, anon;

do $$
begin
  alter publication supabase_realtime add table public.xp_ledger;
exception
  when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------
-- 3) B7: sosyal profil RLS sıkılaştırma (gamification + user_achievements)
-- ---------------------------------------------------------------------
drop policy if exists gamification_profiles_select on public.gamification_profiles;
create policy gamification_profiles_select on public.gamification_profiles
  for select to authenticated
  using (public.can_see_user_sessions(user_id));

drop policy if exists "Anyone can view user achievements" on public.user_achievements;
drop policy if exists user_achievements_select on public.user_achievements;
create policy user_achievements_select on public.user_achievements
  for select to authenticated
  using (public.can_see_user_sessions(user_id));

-- İstemci başarı/XP yazamaz (server-authoritative)
drop policy if exists "Users can insert their own achievements" on public.user_achievements;
drop policy if exists "Users can update their own achievements" on public.user_achievements;
drop policy if exists user_achievements_insert on public.user_achievements;
drop policy if exists user_achievements_update on public.user_achievements;

-- gamification_profiles: istemci yalnız streak_freezes + selected_badges günceller;
-- xp/crown_rank değişimi tetikleyici ile engellenir (aşağıda).
-- INSERT kendi satırı için kalır (ilk satır); xp default 0.

-- ---------------------------------------------------------------------
-- 4) Crown rank yardımcısı + XP koruma tetikleyicisi
-- ---------------------------------------------------------------------
create or replace function public._recalc_crown_rank(p_xp integer)
returns text
language sql
immutable
as $$
  select case
    when p_xp >= 100000 then 'diamond_owl'
    when p_xp >= 50000 then 'ruby_master'
    when p_xp >= 25000 then 'platinum_scholar'
    when p_xp >= 10000 then 'gold_achiever'
    when p_xp >= 5000 then 'silver_learner'
    when p_xp >= 1000 then 'bronze_beginner'
    else 'wood_novice'
  end;
$$;

create or replace function public._guard_gamification_xp_write()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- app.allow_xp_write = 'on' yalnız SECURITY DEFINER fonksiyonlar tarafından set edilir
  if current_setting('app.allow_xp_write', true) is distinct from 'on' then
    if tg_op = 'UPDATE' then
      new.xp := old.xp;
      new.crown_rank := old.crown_rank;
    elsif tg_op = 'INSERT' then
      new.xp := coalesce(new.xp, 0);
      if new.xp <> 0 then
        new.xp := 0;
      end if;
      new.crown_rank := coalesce(new.crown_rank, 'wood_novice');
      if new.crown_rank is distinct from 'wood_novice' and new.xp = 0 then
        new.crown_rank := 'wood_novice';
      end if;
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_guard_gamification_xp on public.gamification_profiles;
create trigger trg_guard_gamification_xp
  before insert or update on public.gamification_profiles
  for each row execute function public._guard_gamification_xp_write();

-- Ledger satırı → profil XP + user_achievements projeksiyonu
create or replace function public._apply_xp_ledger_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total integer;
  v_max_tier integer;
begin
  perform set_config('app.allow_xp_write', 'on', true);

  insert into public.gamification_profiles (user_id, xp, crown_rank)
  values (new.user_id, new.xp_amount, public._recalc_crown_rank(new.xp_amount))
  on conflict (user_id) do update
    set xp = public.gamification_profiles.xp + excluded.xp,
        crown_rank = public._recalc_crown_rank(
          public.gamification_profiles.xp + excluded.xp
        ),
        updated_at = now();

  select coalesce(max(tier), new.tier)
    into v_max_tier
  from public.xp_ledger
  where user_id = new.user_id and achievement_id = new.achievement_id;

  insert into public.user_achievements (
    user_id, achievement_id, tier, progress, unlocked_at, updated_at
  ) values (
    new.user_id, new.achievement_id, v_max_tier, v_max_tier, now(), now()
  )
  on conflict (user_id, achievement_id) do update
    set tier = greatest(public.user_achievements.tier, excluded.tier),
        progress = greatest(public.user_achievements.progress, excluded.progress),
        unlocked_at = coalesce(public.user_achievements.unlocked_at, now()),
        updated_at = now();

  select xp into v_total
  from public.gamification_profiles
  where user_id = new.user_id;

  return new;
end;
$$;

drop trigger if exists trg_xp_ledger_apply on public.xp_ledger;
create trigger trg_xp_ledger_apply
  after insert on public.xp_ledger
  for each row execute function public._apply_xp_ledger_row();

-- ---------------------------------------------------------------------
-- 5) Seed: Başarım 3.0 sözlüğü (BASARIM-MIMARISI.md)
-- ---------------------------------------------------------------------
insert into public.achievements_dict
  (id, category, name, description, max_tier, icon_key, is_secret, tiers)
values
  -- Çalışma
  ('marathon_total', 'study', 'Maratoncu',
   'Uygulama ömrü boyunca toplam çalışma saati',
   5, 'timer', false,
   '[{"tier":1,"threshold":50,"unit":"hours","xp":100},{"tier":2,"threshold":200,"unit":"hours","xp":500},{"tier":3,"threshold":500,"unit":"hours","xp":1500},{"tier":4,"threshold":1000,"unit":"hours","xp":5000},{"tier":5,"threshold":2500,"unit":"hours","xp":15000}]'::jsonb),
  ('steel_will', 'study', 'Çelik İrade',
   'Mola vermeden tek seferde masada kalma süresi (dakika)',
   5, 'self_improvement', false,
   '[{"tier":1,"threshold":60,"unit":"minutes","xp":50},{"tier":2,"threshold":90,"unit":"minutes","xp":100},{"tier":3,"threshold":120,"unit":"minutes","xp":250},{"tier":4,"threshold":180,"unit":"minutes","xp":1000},{"tier":5,"threshold":300,"unit":"minutes","xp":5000}]'::jsonb),
  ('day_hero', 'study', 'Günün Kahramanı',
   'Tek takvim gününde çalışılan toplam süre (saat)',
   5, 'directions_run', false,
   '[{"tier":1,"threshold":2,"unit":"day_hours","xp":50},{"tier":2,"threshold":4,"unit":"day_hours","xp":150},{"tier":3,"threshold":6,"unit":"day_hours","xp":500},{"tier":4,"threshold":8,"unit":"day_hours","xp":1500},{"tier":5,"threshold":10,"unit":"day_hours","xp":5000}]'::jsonb),
  -- Seri
  ('fire_streak', 'streak', 'Ateş Harlı',
   'Arka arkaya her gün hedefe ulaşma serisi (gün)',
   5, 'local_fire_department', false,
   '[{"tier":1,"threshold":7,"unit":"streak_days","xp":100},{"tier":2,"threshold":30,"unit":"streak_days","xp":500},{"tier":3,"threshold":150,"unit":"streak_days","xp":2500},{"tier":4,"threshold":365,"unit":"streak_days","xp":10000},{"tier":5,"threshold":730,"unit":"streak_days","xp":30000}]'::jsonb),
  ('weekend_goal_days', 'streak', 'Hafta Sonu Savaşçısı',
   'Cumartesi-Pazar hedefe ulaşılan gün sayısı',
   5, 'weekend', false,
   '[{"tier":1,"threshold":4,"unit":"weekend_goal_days","xp":50},{"tier":2,"threshold":8,"unit":"weekend_goal_days","xp":150},{"tier":3,"threshold":20,"unit":"weekend_goal_days","xp":500},{"tier":4,"threshold":50,"unit":"weekend_goal_days","xp":1500},{"tier":5,"threshold":100,"unit":"weekend_goal_days","xp":5000}]'::jsonb),
  ('perfect_month', 'streak', 'Kusursuz Ay',
   '30 gün boyunca hedefin altına düşmeme (ay sayısı)',
   5, 'star', false,
   '[{"tier":1,"threshold":1,"unit":"perfect_months","xp":300},{"tier":2,"threshold":3,"unit":"perfect_months","xp":1000},{"tier":3,"threshold":6,"unit":"perfect_months","xp":2500},{"tier":4,"threshold":12,"unit":"perfect_months","xp":7500},{"tier":5,"threshold":24,"unit":"perfect_months","xp":20000}]'::jsonb),
  -- Grup (ilerleme R1'de oturum/grup verisinden kısmi; sözlük tam)
  ('alpha_wolf', 'group', 'Alfa Kurt',
   'Grupta gün birincisi olma sayısı',
   5, 'emoji_events', false,
   '[{"tier":1,"threshold":5,"unit":"group_day_first","xp":100},{"tier":2,"threshold":10,"unit":"group_day_first","xp":300},{"tier":3,"threshold":20,"unit":"group_day_first","xp":1000},{"tier":4,"threshold":50,"unit":"group_day_first","xp":3000},{"tier":5,"threshold":100,"unit":"group_day_first","xp":10000}]'::jsonb),
  ('team_player', 'group', 'Takım Oyuncusu',
   'Grubun günlük hedefine katkı günü sayısı',
   5, 'groups', false,
   '[{"tier":1,"threshold":10,"unit":"group_goal_contrib","xp":50},{"tier":2,"threshold":30,"unit":"group_goal_contrib","xp":200},{"tier":3,"threshold":100,"unit":"group_goal_contrib","xp":800},{"tier":4,"threshold":300,"unit":"group_goal_contrib","xp":2500},{"tier":5,"threshold":1000,"unit":"group_goal_contrib","xp":8000}]'::jsonb),
  ('campfire_hours', 'group', 'Kamp Ateşi Etrafında',
   'En az 3 kişi aktifken masada kalınan süre (saat)',
   5, 'whatshot', false,
   '[{"tier":1,"threshold":10,"unit":"campfire_hours","xp":100},{"tier":2,"threshold":50,"unit":"campfire_hours","xp":400},{"tier":3,"threshold":150,"unit":"campfire_hours","xp":1500},{"tier":4,"threshold":500,"unit":"campfire_hours","xp":5000},{"tier":5,"threshold":1000,"unit":"campfire_hours","xp":12000}]'::jsonb),
  -- Sosyal
  ('inspiration', 'social', 'İlham Kaynağı',
   'Dürtme sonrası arkadaşın çalışmaya başlaması (anti-spam: günde en fazla 2)',
   5, 'campaign', false,
   '[{"tier":1,"threshold":5,"unit":"nudge_starts","xp":100},{"tier":2,"threshold":20,"unit":"nudge_starts","xp":400},{"tier":3,"threshold":50,"unit":"nudge_starts","xp":1200},{"tier":4,"threshold":150,"unit":"nudge_starts","xp":4000},{"tier":5,"threshold":500,"unit":"nudge_starts","xp":15000}]'::jsonb),
  ('locomotive', 'social', 'Lokomotif',
   'Boş grupta ilk oturup 15 dk içinde 2 üye daha gelme sayısı',
   5, 'train', false,
   '[{"tier":1,"threshold":5,"unit":"locomotive_events","xp":150},{"tier":2,"threshold":15,"unit":"locomotive_events","xp":500},{"tier":3,"threshold":30,"unit":"locomotive_events","xp":1500},{"tier":4,"threshold":100,"unit":"locomotive_events","xp":4500},{"tier":5,"threshold":300,"unit":"locomotive_events","xp":15000}]'::jsonb),
  -- Gizli (tek kademe)
  ('secret_night_owl', 'secret', 'Gece Kuşu',
   'Gizli bir başarım, açmak için şanslı veya çok dikkatli olmalısın',
   1, 'dark_mode', true,
   '[{"tier":1,"threshold":1,"unit":"secret_night_owl","xp":500}]'::jsonb),
  ('secret_dawn', 'secret', 'Gün Doğumu',
   'Gizli bir başarım, açmak için şanslı veya çok dikkatli olmalısın',
   1, 'wb_sunny', true,
   '[{"tier":1,"threshold":1,"unit":"secret_dawn","xp":500}]'::jsonb),
  ('secret_404', 'secret', '404 Dakika',
   'Gizli bir başarım, açmak için şanslı veya çok dikkatli olmalısın',
   1, 'error_outline', true,
   '[{"tier":1,"threshold":1,"unit":"secret_404","xp":4044}]'::jsonb),
  ('secret_pi', 'secret', 'Pi Sırrı',
   'Gizli bir başarım, açmak için şanslı veya çok dikkatli olmalısın',
   1, 'functions', true,
   '[{"tier":1,"threshold":1,"unit":"secret_pi","xp":314}]'::jsonb),
  ('secret_break_enemy', 'secret', 'Mola Düşmanı',
   'Gizli bir başarım, açmak için şanslı veya çok dikkatli olmalısın',
   1, 'block', true,
   '[{"tier":1,"threshold":1,"unit":"secret_break_enemy","xp":1000}]'::jsonb),
  ('secret_last_second', 'secret', 'Son Saniye Kurtarıcısı',
   'Gizli bir başarım, açmak için şanslı veya çok dikkatli olmalısın',
   1, 'hourglass_bottom', true,
   '[{"tier":1,"threshold":1,"unit":"secret_last_second","xp":1500}]'::jsonb),
  ('secret_1337', 'secret', '1337 Elite',
   'Gizli bir başarım, açmak için şanslı veya çok dikkatli olmalısın',
   1, 'sports_esports', true,
   '[{"tier":1,"threshold":1,"unit":"secret_1337","xp":1337}]'::jsonb),
  ('secret_no_limits', 'secret', 'Sınır Tanımaz',
   'Gizli bir başarım, açmak için şanslı veya çok dikkatli olmalısın',
   1, 'trending_up', true,
   '[{"tier":1,"threshold":1,"unit":"secret_no_limits","xp":3000}]'::jsonb),
  ('secret_matrix', 'secret', 'Matrix Hatası',
   'Gizli bir başarım, açmak için şanslı veya çok dikkatli olmalısın',
   1, 'memory', true,
   '[{"tier":1,"threshold":1,"unit":"secret_matrix","xp":1111}]'::jsonb),
  ('secret_nye', 'secret', 'Yılbaşı Nöbeti',
   'Gizli bir başarım, açmak için şanslı veya çok dikkatli olmalısın',
   1, 'celebration', true,
   '[{"tier":1,"threshold":1,"unit":"secret_nye","xp":5000}]'::jsonb)
on conflict (id) do update set
  category = excluded.category,
  name = excluded.name,
  description = excluded.description,
  max_tier = excluded.max_tier,
  icon_key = excluded.icon_key,
  is_secret = excluded.is_secret,
  tiers = excluded.tiers;

-- ---------------------------------------------------------------------
-- 6) Ödül yazımı (idempotent) — yalnız SECURITY DEFINER zincirinden
-- ---------------------------------------------------------------------
create or replace function public._award_achievement_tier(
  p_user_id uuid,
  p_achievement_id text,
  p_tier integer,
  p_xp integer,
  p_reason text default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
  v_id uuid;
begin
  v_key := p_user_id::text || '|' || p_achievement_id || '|tier_' || p_tier::text;

  insert into public.xp_ledger (
    user_id, achievement_id, tier, xp_amount, reason, event_key
  ) values (
    p_user_id, p_achievement_id, p_tier, p_xp, p_reason, v_key
  )
  on conflict (event_key) do nothing
  returning id into v_id;

  return v_id is not null;
end;
$$;

-- ---------------------------------------------------------------------
-- 7) Metrik hesaplama (Europe/Istanbul gün sınırı)
-- ---------------------------------------------------------------------
create or replace function public._achievement_metrics(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_goal_minutes integer;
  v_total_seconds bigint;
  v_max_session_minutes integer;
  v_max_day_hours integer;
  v_streak integer := 0;
  v_weekend_goal_days integer := 0;
  v_perfect_months integer := 0;
  v_secret_night boolean := false;
  v_secret_dawn boolean := false;
  v_secret_404 boolean := false;
  v_secret_pi boolean := false;
  v_secret_matrix boolean := false;
  v_secret_1337 boolean := false;
  v_secret_nye boolean := false;
  v_secret_last_second boolean := false;
  v_secret_no_limits boolean := false;
  r record;
  day_secs integer;
  goal_secs integer;
  cursor_day date;
  run integer;
  months_ok integer := 0;
  v_day_map jsonb := '{}'::jsonb;
  v_day_key text;
  v_day_val integer;
begin
  select coalesce(daily_goal_minutes, 360)
    into v_goal_minutes
  from public.profiles
  where id = p_user_id;
  v_goal_minutes := coalesce(v_goal_minutes, 360);
  goal_secs := v_goal_minutes * 60;

  select
    coalesce(sum(duration_seconds), 0),
    coalesce(max(duration_seconds / 60), 0)
  into v_total_seconds, v_max_session_minutes
  from public.study_sessions
  where user_id = p_user_id;

  -- Günlük toplamlar (Europe/Istanbul) → jsonb harita
  for r in
    select
      ((start_time at time zone 'Europe/Istanbul')::date) as day,
      sum(duration_seconds)::integer as total_seconds
    from public.study_sessions
    where user_id = p_user_id
    group by 1
  loop
    v_day_map := v_day_map || jsonb_build_object(r.day::text, r.total_seconds);
    if (r.total_seconds / 3600) > coalesce(v_max_day_hours, 0) then
      v_max_day_hours := r.total_seconds / 3600;
    end if;
    if r.total_seconds >= goal_secs
       and extract(isodow from r.day) in (6, 7) then
      v_weekend_goal_days := v_weekend_goal_days + 1;
    end if;
    if r.total_seconds >= goal_secs * 3 then
      v_secret_no_limits := true;
    end if;
  end loop;
  v_max_day_hours := coalesce(v_max_day_hours, 0);

  -- Gizli: tek oturum koşulları
  for r in
    select
      duration_seconds,
      (start_time at time zone 'Europe/Istanbul') as start_local,
      (end_time at time zone 'Europe/Istanbul') as end_local
    from public.study_sessions
    where user_id = p_user_id
  loop
    if (r.duration_seconds / 60) = 404 then v_secret_404 := true; end if;
    if (r.duration_seconds / 60) = 194 then v_secret_pi := true; end if;
    if (r.duration_seconds / 60) in (111, 222, 333, 555) then
      v_secret_matrix := true;
    end if;

    if r.duration_seconds >= 7200
       and extract(hour from r.start_local) >= 0
       and extract(hour from r.start_local) < 4 then
      v_secret_night := true;
    end if;

    if r.duration_seconds >= 3600
       and extract(hour from r.start_local) >= 5
       and extract(hour from r.start_local) < 7 then
      v_secret_dawn := true;
    end if;

    if extract(hour from r.start_local) = 13
       and extract(minute from r.start_local) = 37
       and r.duration_seconds >= 3600 then
      v_secret_1337 := true;
    end if;

    if (extract(month from r.start_local) = 12
        and extract(day from r.start_local) = 31
        and (extract(hour from r.start_local) * 60
             + extract(minute from r.start_local)) >= (23 * 60 + 50)
        and r.end_local::date > r.start_local::date)
       or (extract(month from r.end_local) = 1
           and extract(day from r.end_local) = 1
           and (extract(hour from r.end_local) * 60
                + extract(minute from r.end_local)) <= 10
           and r.start_local::date < r.end_local::date) then
      v_secret_nye := true;
    end if;

    if extract(hour from r.end_local) = 23
       and extract(minute from r.end_local) between 55 and 59 then
      v_day_key := (r.end_local::date)::text;
      v_day_val := coalesce((v_day_map->>v_day_key)::integer, 0);
      if v_day_val >= goal_secs then
        v_secret_last_second := true;
      end if;
    end if;
  end loop;

  -- Streak (Istanbul bugünden geriye)
  cursor_day := (now() at time zone 'Europe/Istanbul')::date;
  day_secs := coalesce((v_day_map->>cursor_day::text)::integer, 0);
  if day_secs < goal_secs then
    cursor_day := cursor_day - 1;
  end if;

  run := 0;
  loop
    day_secs := coalesce((v_day_map->>cursor_day::text)::integer, 0);
    exit when day_secs < goal_secs;
    run := run + 1;
    cursor_day := cursor_day - 1;
  end loop;
  v_streak := run;

  -- Kusursuz ay R1: ayda ≥ 28 hedef günü
  if v_day_map <> '{}'::jsonb then
    for r in
      select mk, count(*) as goal_days
      from (
        select to_char(k::date, 'YYYY-MM') as mk
        from jsonb_object_keys(v_day_map) as k
        where coalesce((v_day_map->>k)::integer, 0) >= goal_secs
      ) s
      group by mk
    loop
      if r.goal_days >= 28 then
        months_ok := months_ok + 1;
      end if;
    end loop;
  end if;
  v_perfect_months := months_ok;

  return jsonb_build_object(
    'total_hours', (v_total_seconds / 3600)::integer,
    'max_session_minutes', v_max_session_minutes,
    'max_day_hours', v_max_day_hours,
    'streak_days', v_streak,
    'weekend_goal_days', v_weekend_goal_days,
    'perfect_months', v_perfect_months,
    'goal_minutes', v_goal_minutes,
    'secrets', jsonb_build_object(
      'night_owl', v_secret_night,
      'dawn', v_secret_dawn,
      'm404', v_secret_404,
      'pi', v_secret_pi,
      'matrix', v_secret_matrix,
      'leet', v_secret_1337,
      'nye', v_secret_nye,
      'last_second', v_secret_last_second,
      'no_limits', v_secret_no_limits
    )
  );
end;
$$;

-- ---------------------------------------------------------------------
-- 8) Ana RPC: process_achievement_event
-- ---------------------------------------------------------------------
create or replace function public.process_achievement_event(
  p_event_type text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_metrics jsonb;
  v_awarded jsonb := '[]'::jsonb;
  v_def record;
  v_tier jsonb;
  v_progress integer;
  v_threshold integer;
  v_xp integer;
  v_tier_n integer;
  v_unit text;
  v_ok boolean;
  v_total_xp integer := 0;
  v_rank text := 'wood_novice';
  v_secrets jsonb;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- Bilinen olay tipleri (R1): session_completed, manual_refresh, nudge_sent (sosyal sonra)
  if p_event_type not in (
    'session_completed', 'manual_refresh', 'profile_opened'
  ) then
    raise exception 'unknown event_type: %', p_event_type;
  end if;

  v_metrics := public._achievement_metrics(v_uid);
  v_secrets := v_metrics->'secrets';

  for v_def in
    select * from public.achievements_dict
    order by id
  loop
    -- Grup/sosyal karmaşık metrikler R1'de 0 (sözlük hazır; ileride doldurulur)
    v_progress := case v_def.id
      when 'marathon_total' then (v_metrics->>'total_hours')::integer
      when 'steel_will' then (v_metrics->>'max_session_minutes')::integer
      when 'day_hero' then (v_metrics->>'max_day_hours')::integer
      when 'fire_streak' then (v_metrics->>'streak_days')::integer
      when 'weekend_goal_days' then (v_metrics->>'weekend_goal_days')::integer
      when 'perfect_month' then (v_metrics->>'perfect_months')::integer
      when 'alpha_wolf' then 0
      when 'team_player' then 0
      when 'campfire_hours' then 0
      when 'inspiration' then 0
      when 'locomotive' then 0
      when 'secret_night_owl' then case when (v_secrets->>'night_owl')::boolean then 1 else 0 end
      when 'secret_dawn' then case when (v_secrets->>'dawn')::boolean then 1 else 0 end
      when 'secret_404' then case when (v_secrets->>'m404')::boolean then 1 else 0 end
      when 'secret_pi' then case when (v_secrets->>'pi')::boolean then 1 else 0 end
      when 'secret_matrix' then case when (v_secrets->>'matrix')::boolean then 1 else 0 end
      when 'secret_1337' then case when (v_secrets->>'leet')::boolean then 1 else 0 end
      when 'secret_nye' then case when (v_secrets->>'nye')::boolean then 1 else 0 end
      when 'secret_last_second' then case when (v_secrets->>'last_second')::boolean then 1 else 0 end
      when 'secret_no_limits' then case when (v_secrets->>'no_limits')::boolean then 1 else 0 end
      when 'secret_break_enemy' then 0 -- pomodoro skip verisi R1'de yok
      else 0
    end;

    for v_tier in
      select * from jsonb_array_elements(v_def.tiers)
    loop
      v_tier_n := (v_tier->>'tier')::integer;
      v_threshold := (v_tier->>'threshold')::integer;
      v_xp := (v_tier->>'xp')::integer;
      v_unit := v_tier->>'unit';

      if v_progress >= v_threshold then
        v_ok := public._award_achievement_tier(
          v_uid,
          v_def.id,
          v_tier_n,
          v_xp,
          format('%s progress=%s %s', v_def.id, v_progress, coalesce(v_unit, ''))
        );
        if v_ok then
          v_awarded := v_awarded || jsonb_build_array(
            jsonb_build_object(
              'achievement_id', v_def.id,
              'tier', v_tier_n,
              'xp', v_xp,
              'name', v_def.name,
              'is_secret', v_def.is_secret
            )
          );
        end if;
      end if;
    end loop;
  end loop;

  select coalesce(xp, 0), coalesce(crown_rank, 'wood_novice')
    into v_total_xp, v_rank
  from public.gamification_profiles
  where user_id = v_uid;

  return jsonb_build_object(
    'event_type', p_event_type,
    'awarded', v_awarded,
    'total_xp', coalesce(v_total_xp, 0),
    'crown_rank', coalesce(v_rank, 'wood_novice'),
    'metrics', v_metrics
  );
end;
$$;

revoke all on function public.process_achievement_event(text, jsonb) from public;
grant execute on function public.process_achievement_event(text, jsonb) to authenticated;

revoke all on function public._award_achievement_tier(uuid, text, integer, integer, text) from public;
revoke all on function public._achievement_metrics(uuid) from public;
revoke all on function public._apply_xp_ledger_row() from public;
revoke all on function public._guard_gamification_xp_write() from public;
revoke all on function public._recalc_crown_rank(integer) from public;

-- Yardımcı: istemci sözlüğü okusun
grant select on public.achievements_dict to authenticated;
grant select on public.xp_ledger to authenticated;
