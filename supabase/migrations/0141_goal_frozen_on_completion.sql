-- 0141_goal_frozen_on_completion.sql
-- WP-828: hedef AYARI degisince gecmis gunler yeniden yargilanmaz.
--
-- KUSUR (olculdu, `supabase/tests/067_goal_frozen_on_completion_wp828.test.sql`):
-- "bu gun hedef tutuldu mu" karari, gecmisteki HER gun icin BUGUNKU
-- `profiles.daily_goal_minutes` ile yeniden veriliyordu. Iki yonu vardi:
--
--   * OKUMA (sisirme). Hedefini dusuren kullanici, calismasi hic degismeden
--     gecmisten rozet kazaniyordu:
--       - `weekend_goal_days`      (`0025` govdesi = `_achievement_metrics_legacy_v1`)
--       - `perfect_months`         (`0058` `_count_perfect_months_28`)
--       - gizli `last_second`, `no_limits` (`0025` govdesi)
--   * SILME. Hedefini YUKSELTEN kullanici gecmis bir gunun oturumunu
--     duzenleyince `_retract_goal_completion` (`0132`) o gunu bugunku hedefle
--     yargilayip tamamlama olayini SILIYORDU; ates serisi o gun kiriliyordu.
--     `055` "hedef sonradan yukselse de calisilmis gunun serisi YANMAZ"
--     kuralini onarim yolunda zaten koyuyordu -- yalniz onarim yolunda.
--
-- KOK NEDEN: semada "o gun hedef kacti" bilgisi hicbir yerde durmuyordu.
-- `goal_progress_events` gunun TAMAMLANDIGINI tutuyordu ama hangi hedefle
-- tamamlandigini tutmuyordu.
--
-- DUZELTME:
--   1. `goal_progress_events.goal_seconds` -- tamamlama olayi, yazildigi anda
--      gecerli hedefi kendi uzerinde dondurur. Olay `on conflict do nothing`
--      ile yazildigi icin sonradan degisen ayar donmus degeri EZEMEZ.
--   2. Okuma tarafi `0136` ates serisinin zaten izledigi yolu izler: hedef
--      gunlerini bugunku ayardan yeniden hesaplamaz, `goal_completed`
--      olaylarini sayar. Boylece hafta sonu, Kusursuz Ay, son saniye ve ates
--      serisi "hedef gunu" sorusuna TEK cevap verir.
--   3. Geri alma, bugunku hedefi degil olayin donmus hedefini kullanir.
--
-- `0141` ONCESI OLAYLAR (production'da `backfill_goal_completions`, WP-506,
-- 2026-08-08): `goal_seconds` null kalir, bilerek doldurulmaz -- o gunun
-- hedefi bilinmiyor ve tahmin etmek (ornegin bugunku degeri yazmak) SILME
-- kusurunu geri getirir. Onlar icin:
--   * sayma tarafi degismez (olay varsa gun sayilir),
--   * geri alma tabani 60 sn: yazici `daily_goal_minutes > 0` ister, yani hicbir
--     gun 1 dakikadan kucuk bir hedefle tamamlanmis olamaz. Taban kazanilmis
--     gunu ASLA silmez; yalniz arkasinda calisma kalmayan gunu temizler,
--   * `no_limits` hedefin DEGERINE ihtiyac duyar; null olaylar yeni "sinir yok"
--     acamaz. O gunler oturum yazildiginda zaten degerlendirilmisti
--     (`study_sessions_mark_achievement_dirty`), kazanilan odul yerinde durur.
--
-- VERI: bu migration HICBIR satir silmez, guncellemez ya da eklemez. Yalniz bir
-- nullable kolon ekler ve fonksiyon govdelerini degistirir. Kazanilmis oduller
-- benzersiz odul anahtariyla yazilidir ve `user_achievements` projeksiyonu
-- `greatest` ile ilerler (`0024`); sayim dusse bile kademe geri alinmaz
-- (`docs/URUN-POLITIKALARI.md §3`).
--
-- BILEREK KAPSAM DISI:
--   * Gecmis bir gune YENI elle oturum girmek o gunu bugunku hedefle
--     tamamlayabilir. Kapatilmadi: elle giris zaten kullanicinin kendi beyanidir
--     (hedef dusurmeden de gecmise 10 saat girilebilir), kapatmak koruma
--     katmaz ama geriye donuk girisi bozar.
--   * Cevrimdisi Dart aynasi (`achievement_ledger_engine.dart`) tek hedefle
--     hesaplamaya devam eder; yalniz anahtarsiz InMemory modda calisir ve ates
--     serisi de orada ayni sekilde birakilmistir. Gercek XP sunucudadir.
--
-- Geri alma (Rollback): `0132`deki `_record_goal_completion`,
-- `_retract_goal_completion`, `backfill_goal_completions`; `0058`deki
-- `_count_perfect_months_28` ve `0135`teki `_achievement_metrics` govdelerini
-- yeniden uygula. `drop function public._count_weekend_goal_days(uuid);`
-- `drop function public._goal_day_secrets(uuid);`. `goal_seconds` kolonu veri
-- tasimaz ve eski govdeler onu okumaz; birakilabilir ya da
-- `alter table public.goal_progress_events drop column goal_seconds;`.
-- Kazanilmis oduller geri alinmaz.

-- ---------------------------------------------------------------------
-- 1) Kolon: tamamlama olayi hedefini dondurur
-- ---------------------------------------------------------------------
alter table public.goal_progress_events
  add column if not exists goal_seconds bigint;

alter table public.goal_progress_events
  drop constraint if exists goal_progress_events_goal_seconds_positive;
alter table public.goal_progress_events
  add constraint goal_progress_events_goal_seconds_positive
  check (goal_seconds is null or goal_seconds > 0);

comment on column public.goal_progress_events.goal_seconds is
  'WP-828: goal_completed olayinin yazildigi anda gecerli hedef (sn). '
  'Null = 0141 oncesi yazilmis olay; o gunun hedefi bilinmiyor.';

-- ---------------------------------------------------------------------
-- 2) Yazici (`0132:103`) -- tek fark: hedefi olayin uzerine yazar
-- ---------------------------------------------------------------------
create or replace function public._record_goal_completion(
  p_scope_type text,
  p_scope_id uuid,
  p_day date
)
returns boolean
language plpgsql
security definer
set search_path = public
as $wp828$
declare
  v_time_zone text;
  v_goal_minutes integer;
  v_seconds bigint;
begin
  if p_scope_type is null or p_scope_id is null or p_day is null then
    raise exception 'invalid_goal_scope';
  end if;

  if p_scope_type = 'personal' then
    v_time_zone := 'Europe/Istanbul';
    select daily_goal_minutes into v_goal_minutes
    from public.profiles where id = p_scope_id;
    v_seconds := public._goal_day_seconds(p_scope_id, p_day, v_time_zone);

  elsif p_scope_type = 'group' then
    select time_zone, daily_goal_minutes into v_time_zone, v_goal_minutes
    from public.groups where id = p_scope_id;
    if v_time_zone is null then
      raise exception 'group_not_found';
    end if;
    v_seconds := public._group_goal_day_seconds(p_scope_id, p_day, v_time_zone);

  else
    raise exception 'invalid_goal_scope';
  end if;

  if v_goal_minutes is null or v_goal_minutes <= 0 then
    return false;
  end if;
  if p_day > (now() at time zone v_time_zone)::date then
    return false;
  end if;

  if v_seconds < (v_goal_minutes::bigint * 60) then
    return false;
  end if;

  insert into public.goal_progress_events (
    event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at,
    goal_seconds
  ) values (
    p_scope_type || ':' || p_scope_id::text || ':goal_completed:' || p_day::text,
    p_scope_type, p_scope_id, v_time_zone, 'goal_completed', p_day, now(),
    v_goal_minutes::bigint * 60
  )
  on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;

  return true;
end;
$wp828$;

revoke all on function public._record_goal_completion(text, uuid, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3) Geri alici (`0132:169`) -- bugunku hedef DEGIL, olayin donmus hedefi
-- ---------------------------------------------------------------------
create or replace function public._retract_goal_completion(
  p_scope_type text,
  p_scope_id uuid,
  p_day date
)
returns boolean
language plpgsql
security definer
set search_path = public
as $wp828$
declare
  v_time_zone text;
  v_goal_seconds bigint;
  v_seconds bigint;
begin
  if p_scope_type is null or p_scope_id is null or p_day is null then
    return false;
  end if;

  select e.goal_seconds
    into v_goal_seconds
  from public.goal_progress_events e
  where e.scope_type = p_scope_type
    and e.scope_id = p_scope_id
    and e.event_kind = 'goal_completed'
    and e.goal_day = p_day;
  if not found then
    return false;
  end if;

  if p_scope_type = 'personal' then
    v_time_zone := 'Europe/Istanbul';
    v_seconds := public._goal_day_seconds(p_scope_id, p_day, v_time_zone);

  elsif p_scope_type = 'group' then
    select time_zone into v_time_zone
    from public.groups where id = p_scope_id;
    if v_time_zone is null then
      return false;
    end if;
    v_seconds := public._group_goal_day_seconds(p_scope_id, p_day, v_time_zone);

  else
    return false;
  end if;

  -- Null = `0141` oncesi olay: 60 sn tabani (dosya basligi).
  if v_seconds >= coalesce(v_goal_seconds, 60) then
    return false;
  end if;

  delete from public.goal_progress_events e
   where e.scope_type = p_scope_type
     and e.scope_id = p_scope_id
     and e.event_kind = 'goal_completed'
     and e.goal_day = p_day;

  return true;
end;
$wp828$;

comment on function public._retract_goal_completion(text, uuid, date) is
  'WP-641/WP-658/WP-828: bir kapsamin bir gunu, TAMAMLANDIGI hedefin altina '
  'dustuyse olayi dusurur. Bugunku hedef ayari gecmisi yargilamaz.';

revoke all on function public._retract_goal_completion(text, uuid, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4) Backfill (`0132:338`) -- yazdigi olaylar da hedefi dondurur
-- ---------------------------------------------------------------------
create or replace function public.backfill_goal_completions()
returns integer
language plpgsql
security definer
set search_path = public
as $wp828$
declare
  v_personal integer := 0;
  v_group integer := 0;
begin
  if auth.role() is distinct from 'service_role'
     and current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;

  with day_totals as (
    select
      s.user_id,
      (s.start_time at time zone 'Europe/Istanbul')::date as goal_day,
      sum(s.duration_seconds)::bigint as seconds,
      max(s.end_time) as last_end
    from public.study_sessions s
    where s.duration_seconds > 0
    group by s.user_id, (s.start_time at time zone 'Europe/Istanbul')::date
  )
  insert into public.goal_progress_events (
    event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at,
    goal_seconds
  )
  select
    'personal:' || d.user_id::text || ':goal_completed:' || d.goal_day::text,
    'personal', d.user_id, 'Europe/Istanbul', 'goal_completed', d.goal_day,
    coalesce(d.last_end, now()),
    p.daily_goal_minutes::bigint * 60
  from day_totals d
  join public.profiles p on p.id = d.user_id
  where p.daily_goal_minutes > 0
    and d.seconds >= p.daily_goal_minutes::bigint * 60
    and d.goal_day <= (now() at time zone 'Europe/Istanbul')::date
  on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;
  get diagnostics v_personal = row_count;

  with group_day_candidates as (
    select
      g.id as group_id,
      g.time_zone,
      g.daily_goal_minutes,
      (s.start_time at time zone g.time_zone)::date as goal_day,
      max(s.end_time) as last_end
    from public.groups g
    join public.group_members gm
      on gm.group_id = g.id
    join public.study_sessions s
      on s.user_id = gm.user_id
     and s.duration_seconds > 0
     and (gm.left_at is null or s.start_time < gm.left_at)
    where g.daily_goal_minutes > 0
    group by g.id, g.time_zone, g.daily_goal_minutes,
             (s.start_time at time zone g.time_zone)::date
  )
  insert into public.goal_progress_events (
    event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at,
    goal_seconds
  )
  select
    'group:' || d.group_id::text || ':goal_completed:' || d.goal_day::text,
    'group', d.group_id, d.time_zone, 'goal_completed', d.goal_day,
    coalesce(d.last_end, now()),
    d.daily_goal_minutes::bigint * 60
  from group_day_candidates d
  where d.goal_day <= (now() at time zone d.time_zone)::date
    and public._group_goal_day_seconds(d.group_id, d.goal_day, d.time_zone)
        >= d.daily_goal_minutes::bigint * 60
  on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;
  get diagnostics v_group = row_count;

  return v_personal + v_group;
end;
$wp828$;

revoke all on function public.backfill_goal_completions()
  from public, anon, authenticated;
grant execute on function public.backfill_goal_completions() to service_role;

-- ---------------------------------------------------------------------
-- 5) Okuma: hedef gunleri olaydan sayilir (`0136` ates serisiyle ayni kaynak)
-- ---------------------------------------------------------------------
create or replace function public._count_weekend_goal_days(p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $wp828$
  select count(*)::integer
  from public.goal_progress_events e
  where e.scope_type = 'personal'
    and e.scope_id = p_user_id
    and e.event_kind = 'goal_completed'
    and extract(isodow from e.goal_day) in (6, 7);
$wp828$;

revoke all on function public._count_weekend_goal_days(uuid)
  from public, anon, authenticated;

-- `0058` ile ayni imza ve esik (ay icinde >= 28 hedef gunu); kaynak degisti.
create or replace function public._count_perfect_months_28(p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $wp828$
  select count(*)::integer
  from (
    select date_trunc('month', e.goal_day)
    from public.goal_progress_events e
    where e.scope_type = 'personal'
      and e.scope_id = p_user_id
      and e.event_kind = 'goal_completed'
    group by 1
    having count(*) >= 28
  ) perfect;
$wp828$;

revoke all on function public._count_perfect_months_28(uuid)
  from public, anon, authenticated;

-- `0025` govdesindeki iki gizli rozetin hedefe bagli yarisi.
--   last_second: 23:55-23:59 arasinda biten bir oturumun BITIS gunu hedef gunu.
--   no_limits:   bir gunun toplami, O GUNUN hedefinin en az 3 kati.
create or replace function public._goal_day_secrets(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $wp828$
  select jsonb_build_object(
    'last_second', exists (
      select 1
      from public.study_sessions s
      join public.goal_progress_events e
        on e.scope_type = 'personal'
       and e.scope_id = s.user_id
       and e.event_kind = 'goal_completed'
       and e.goal_day = (s.end_time at time zone 'Europe/Istanbul')::date
      where s.user_id = p_user_id
        and extract(hour from (s.end_time at time zone 'Europe/Istanbul')) = 23
        and extract(minute from (s.end_time at time zone 'Europe/Istanbul'))
            between 55 and 59
    ),
    'no_limits', exists (
      select 1
      from public.goal_progress_events e
      where e.scope_type = 'personal'
        and e.scope_id = p_user_id
        and e.event_kind = 'goal_completed'
        and e.goal_seconds is not null
        and public._goal_day_seconds(p_user_id, e.goal_day, 'Europe/Istanbul')
            >= 3 * e.goal_seconds
    )
  );
$wp828$;

revoke all on function public._goal_day_secrets(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 6) Metrik sarmalayici (`0135:162`) -- uc ek ezme, projeksiyondan ONCE
-- ---------------------------------------------------------------------
create or replace function public._achievement_metrics(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
volatile
as $wp828$
declare
  v_metrics jsonb;
  v_perfect_months integer;
  v_converted_nudges integer;
  v_fire_streak integer;
  v_wp721 jsonb;
  v_goal_secrets jsonb;
begin
  v_metrics := public._achievement_metrics_legacy_v1(p_user_id);

  v_perfect_months := public._count_perfect_months_28(p_user_id);
  v_metrics := jsonb_set(
    v_metrics, '{perfect_months}', to_jsonb(coalesce(v_perfect_months, 0)), true
  );

  -- WP-828: legacy govde bu uc degeri BUGUNKU hedefle hesapliyordu.
  v_metrics := jsonb_set(
    v_metrics, '{weekend_goal_days}',
    to_jsonb(coalesce(public._count_weekend_goal_days(p_user_id), 0)), true
  );
  v_goal_secrets := public._goal_day_secrets(p_user_id);
  v_metrics := jsonb_set(
    v_metrics, '{secrets,last_second}', v_goal_secrets->'last_second', true
  );
  v_metrics := jsonb_set(
    v_metrics, '{secrets,no_limits}', v_goal_secrets->'no_limits', true
  );

  v_converted_nudges := public._count_converted_nudges(p_user_id);
  v_metrics := jsonb_set(
    v_metrics, '{nudge_starts}', to_jsonb(coalesce(v_converted_nudges, 0)), true
  );

  v_fire_streak := public._current_fire_streak_days(p_user_id);
  v_metrics := jsonb_set(
    v_metrics, '{streak_days}', to_jsonb(coalesce(v_fire_streak, 0)), true
  );

  perform public._project_achievement_metrics(p_user_id, v_metrics);

  v_wp721 := public.project_wp721_metrics(p_user_id);
  v_metrics := jsonb_set(
    v_metrics, '{ancient_member_days}', v_wp721->'ancient_member_days', true
  );
  v_metrics := jsonb_set(
    v_metrics, '{metronome_weeks}', v_wp721->'metronome_weeks', true
  );
  return v_metrics;
end;
$wp828$;

revoke all on function public._achievement_metrics(uuid)
  from public, anon, authenticated;
