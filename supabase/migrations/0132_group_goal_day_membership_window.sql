-- 0132_group_goal_day_membership_window.sql
--
-- Bir uye gruptan ayrilinca grubun GECMIS hedef gunleri sessizce yaniyordu.
--
-- ===========================================================================
-- OLCULEN DURUM -- hipotezin tersi cikti
-- ===========================================================================
-- Lider'in supheci ifadesi "ayrilma grup serisini GERI ALMIYOR" idi. Kod bunun
-- TERSINI soyluyor: ayrilma grup serisini geri aliyor, ama **rastgele bir anda
-- ve sessizce**. Grup gunu toplamini hesaplayan uc yer de grubun BUGUNKU
-- uyelerine bakiyor:
--
--   `0120:88-92`  `_record_goal_completion`          -> `gm.left_at is null`
--   `0129:114-118` `_retract_goal_completion`         -> `gm.left_at is null`
--   `0129:299-303` `_repair_orphan_goal_completions`  -> `gm.left_at is null`
--
-- Sonuc zinciri:
--   1. Grup D gununde hedefi tutturur, olay yazilir (katkinin cogu A'dan).
--   2. A gruptan ayrilir. O anda hicbir sey olmaz -- gorunurde sorun yok.
--   3. Grupta KALAN biri, D gununde herhangi bir oturumunu siler ya da
--      duzenler. `_retract_goal_completion` D gununu BUGUNKU uyelerle yeniden
--      hesaplar, A'nin saniyeleri yok sayilir, toplam hedefin altina duser ve
--      olay SILINIR. Grubun gercekten hak ettigi gun, alakasiz bir silme
--      yuzunden kaybolur.
--   4. `_repair_orphan_goal_completions` ayni olcutu tasidigi icin `0129`un
--      apply DO blogu (`0129:345`) bu satirlari zaten dusurmus olabilir.
--
-- ===========================================================================
-- URUN SORUSU MU? HAYIR -- kural bu semada ZATEN yazili
-- ===========================================================================
-- "Ayrilinca gecmis grup gunu silinmeli mi?" sorusu bu depoda daha once
-- cevaplanmis. `0121:186-191` grup basarim projeksiyonunu tam olarak boyle
-- kuruyor:
--
--     and (gm.left_at is null or s.start_time < gm.left_at)
--
-- Yani: **uyeyken calisilan sure gruba sayilir; ayrildiktan sonra baslayan
-- oturum sayilmaz.** `0129:274-278` de ayni felsefeyi bir baska eksende
-- yaziyor -- "gecmisi BUGUNKU hedef degeriyle yargilama". Bugunku UYELIKLE
-- yargilamak ayni hatanin ikizidir. Bu migration `0121`in yuklemini hedef
-- gunu hesabina tasir; yeni bir urun karari uretmez.
--
-- 🔴 `joined_at` BILEREK YUKLEME GIRMEDI. Yeniden katilma `joined_at`i
-- `now()` yapiyor (`0012:121`, `0032:225`, `0093:193`), yani `joined_at`
-- gecmis uyeligin dogru olcusu DEGIL. `joined_at >= ...` gibi bir kosul
-- eklemek, ayni gun icinde ayrilip donen bir uyenin sabahki oturumunu
-- gruptan dusurur ve tam da onarmaya calistigimiz hatayi yeni bir yoldan
-- geri getirirdi.
--
-- Bu degisimin yonu TEK TARAFLI: yuklem yalnizca daha once HARIC tutulan
-- saniyeleri dahil eder. Grup gunu toplami hicbir kosulda kucul(e)mez, yani
-- bu migration YENI bir geri alma uretemez -- yalnizca yanlis geri almalari
-- durdurur.
--
-- Geri alma (Rollback): `0120` ve `0129`daki fonksiyon govdelerini
-- `create or replace` ile geri yaz ve
--   drop function if exists public._group_goal_day_seconds(uuid, date, text);
-- Bu migration'in kendisi hicbir satir silmez.

-- ---------------------------------------------------------------------
-- 1) TEK tanim: bir grubun bir gunku toplam saniyesi
-- ---------------------------------------------------------------------
-- `0129:68-70` "iki farkli tanim yazmak, iki gun sonra birbirinden sapan iki
-- hedef demekti" diyordu ve hakliydi -- ama tanim uc yere kopyalanmisti.
-- Buradan sonra tek yer var.
--
-- `_goal_day_seconds` (`0112:72`) uye BASINA calisir ve uyelik bilmez; grup
-- toplaminda uyelik penceresi gerektigi icin gun kesimi burada tekrarlanir.
-- Gun siniri ayni ifadedir: `(start_time at time zone tz)::date = day`.
create or replace function public._group_goal_day_seconds(
  p_group_id uuid,
  p_day date,
  p_time_zone text
)
returns bigint
language sql
stable
security definer
set search_path = public
as $wp658$
  select coalesce(sum(s.duration_seconds), 0)::bigint
  from public.group_members gm
  join public.study_sessions s
    on s.user_id = gm.user_id
   and s.duration_seconds > 0
   -- 🔴 `0121:191` ile BIREBIR ayni yuklem. `gm.left_at is null` filtresi
   -- YOK: ayrilmis uyenin uyeyken calistigi sure gruba aittir.
   and (gm.left_at is null or s.start_time < gm.left_at)
  where gm.group_id = p_group_id
    and (s.start_time at time zone p_time_zone)::date = p_day;
$wp658$;

comment on function public._group_goal_day_seconds(uuid, date, text) is
  'WP-658: grup hedef gununun TEK toplam tanimi. Uyeyken calisilan sure '
  'sayilir (0121:191 yuklemi); ayrilma gecmis gunu yakmaz.';

revoke all on function public._group_goal_day_seconds(uuid, date, text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 2) Yazici (`0120:56`) -- govde aynidir, grup toplami tek tanima devreder
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
as $wp658$
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
    event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
  ) values (
    p_scope_type || ':' || p_scope_id::text || ':goal_completed:' || p_day::text,
    p_scope_type, p_scope_id, v_time_zone, 'goal_completed', p_day, now()
  )
  on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;

  return true;
end;
$wp658$;

revoke all on function public._record_goal_completion(text, uuid, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3) Geri alici (`0129:71`) -- ayni tanim, ayni matematik
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
as $wp658$
declare
  v_time_zone text;
  v_goal_minutes integer;
  v_seconds bigint;
begin
  if p_scope_type is null or p_scope_id is null or p_day is null then
    return false;
  end if;

  if not exists (
    select 1 from public.goal_progress_events e
    where e.scope_type = p_scope_type
      and e.scope_id = p_scope_id
      and e.event_kind = 'goal_completed'
      and e.goal_day = p_day
  ) then
    return false;
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
      return false;
    end if;
    v_seconds := public._group_goal_day_seconds(p_scope_id, p_day, v_time_zone);

  else
    return false;
  end if;

  if v_goal_minutes is null or v_goal_minutes <= 0 then
    return false;
  end if;

  if v_seconds >= (v_goal_minutes::bigint * 60) then
    return false;
  end if;

  delete from public.goal_progress_events e
   where e.scope_type = p_scope_type
     and e.scope_id = p_scope_id
     and e.event_kind = 'goal_completed'
     and e.goal_day = p_day;

  return true;
end;
$wp658$;

comment on function public._retract_goal_completion(text, uuid, date) is
  'WP-641/WP-658: bir kapsamin bir gunu artik hedefi tutmuyorsa tamamlama '
  'olayini dusurur. Grup toplami `_group_goal_day_seconds` ile tek tanimdir.';

revoke all on function public._retract_goal_completion(text, uuid, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4) Etkilenen (kapsam, gun) daraltmasi (`0129:157`)
-- ---------------------------------------------------------------------
-- 🔴 Buradaki `gm.left_at is null` de kaldirildi ve ayni yuklemle degistirildi.
-- Sebep simetri: ayrilmis uye ESKI bir oturumunu silerse o saniyeler gercekten
-- yok olur ve grubun o gunu yeniden degerlendirilmelidir. Eski hal o silmeyi
-- HIC gormuyordu -- yani hak edilmeyen bir grup gunu, ayrilan uye uzerinden
-- sonsuza kadar ayakta kalabiliyordu.
create or replace function public._retract_goal_days_for_session(
  p_user_id uuid,
  p_start_time timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $wp658$
declare
  v_group record;
begin
  if p_user_id is null or p_start_time is null then
    return;
  end if;
  -- Silinmekte olan hesap: purge maliyetini uye sayisiyla carpmamak icin
  -- atlanir (`0129` basligi, `0120:35` ayni gerekce).
  if not public._account_still_exists(p_user_id) then
    return;
  end if;

  perform public._retract_goal_completion(
    'personal',
    p_user_id,
    (p_start_time at time zone 'Europe/Istanbul')::date
  );

  for v_group in
    select g.id, g.time_zone
    from public.group_members gm
    join public.groups g on g.id = gm.group_id
    where gm.user_id = p_user_id
      and (gm.left_at is null or p_start_time < gm.left_at)
  loop
    perform public._retract_goal_completion(
      'group',
      v_group.id,
      (p_start_time at time zone v_group.time_zone)::date
    );
  end loop;
end;
$wp658$;

revoke all on function public._retract_goal_days_for_session(uuid, timestamptz)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 5) Gecmis onarimi (`0129:283`) -- ayni tanim
-- ---------------------------------------------------------------------
-- Bu fonksiyon `0129`un apply DO blogunda CAGRILDI (bu sabah staging +
-- production). Eski olcutu tasidigi surece, katkisi yalniz ayrilmis uyelerden
-- gelen her grup gununu "arkasinda tek saniye yok" sayip dusuruyordu.
create or replace function public._repair_orphan_goal_completions()
returns integer
language plpgsql
security definer
set search_path = public
as $wp658$
declare
  v_removed integer := 0;
begin
  with orphan as (
    delete from public.goal_progress_events e
     where e.event_kind = 'goal_completed'
       and case e.scope_type
         when 'personal' then
           public._goal_day_seconds(e.scope_id, e.goal_day, e.time_zone) = 0
         when 'group' then
           public._group_goal_day_seconds(e.scope_id, e.goal_day, e.time_zone) = 0
         else false
       end
    returning 1
  )
  select count(*)::integer into v_removed from orphan;

  return v_removed;
end;
$wp658$;

revoke all on function public._repair_orphan_goal_completions()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 6) Backfill (`0120:278`) -- ucuncu kopya da tek tanima baglanir
-- ---------------------------------------------------------------------
-- Bu fonksiyon hicbir migration'dan cagrilmaz (ops kapisi), ama grup CTE'si
-- ayni `left_at is null` filtresini tasiyordu. Birakilsaydi, sema "grup gunu
-- nedir" sorusuna iki farkli cevap veren iki fonksiyon tasimaya devam
-- ederdi -- `0129:68`in acikca yasakladigi durum.
create or replace function public.backfill_goal_completions()
returns integer
language plpgsql
security definer
set search_path = public
as $wp658$
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
    event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
  )
  select
    'personal:' || d.user_id::text || ':goal_completed:' || d.goal_day::text,
    'personal', d.user_id, 'Europe/Istanbul', 'goal_completed', d.goal_day,
    coalesce(d.last_end, now())
  from day_totals d
  join public.profiles p on p.id = d.user_id
  where p.daily_goal_minutes > 0
    and d.seconds >= p.daily_goal_minutes::bigint * 60
    and d.goal_day <= (now() at time zone 'Europe/Istanbul')::date
  on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;
  get diagnostics v_personal = row_count;

  -- Aday (grup, gun) ciftleri: uyeyken calisilmis her oturum bir aday uretir.
  -- Hedef karari adaylikta DEGIL, tek tanimli toplamda verilir.
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
    event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
  )
  select
    'group:' || d.group_id::text || ':goal_completed:' || d.goal_day::text,
    'group', d.group_id, d.time_zone, 'goal_completed', d.goal_day,
    coalesce(d.last_end, now())
  from group_day_candidates d
  where d.goal_day <= (now() at time zone d.time_zone)::date
    and public._group_goal_day_seconds(d.group_id, d.goal_day, d.time_zone)
        >= d.daily_goal_minutes::bigint * 60
  on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;
  get diagnostics v_group = row_count;

  return v_personal + v_group;
end;
$wp658$;

revoke all on function public.backfill_goal_completions()
  from public, anon, authenticated;
grant execute on function public.backfill_goal_completions() to service_role;

notify pgrst, 'reload schema';
