-- 0120_goal_completion_writer.sql
-- WP-492: hedef tamamlamasini SUNUCU yazar (V58-N03 / rapor T02).
--
-- `0112` okuma ucunu eksiksiz kurdu (goal_streak_projection -> repository ->
-- rozet), fakat `goal_progress_events` tablosuna satir yazan TEK yol olan
-- `record_goal_completion` uretimde hicbir yerden cagrilmiyordu: istemcide
-- yalniz yorumda, yedi edge function'da hic, tetikleyici de yok. Sonuc: seri
-- matematiksel olarak daima 0 ve rozet daima "Henuz seri yok".
--
-- Bu migration uc sey yapar:
--
--   1. Hedef matematigini auth'tan bagimsiz bir ic fonksiyona tasir
--      (`_record_goal_completion`). Genel `record_goal_completion` RPC'si ayni
--      imza ve ayni hata sozlesmesiyle durur, govdesi ic fonksiyona devreder.
--      Ikinci bir kopya yazmak, iki gun sonra birbirinden sapan iki hedef
--      tanimi demekti.
--
--   2. `study_sessions` uzerinde insert/update tetikleyicisi kurar. Gun toplami
--      hedefi gectiginde KISISEL kapsam ve kullanicinin aktif uyesi oldugu HER
--      grup icin olay yazilir (V57-N05: ayni seri modeli grup hedefinde de
--      gecerlidir). Yazma yolu sunucuda kalir; istemciye yeni bir API acilmaz.
--
--   3. Gecmis icin idempotent `backfill_goal_completions()` fonksiyonu ekler.
--      🔴 Migration bu fonksiyonu CAGIRMAZ. Backfill remote ortamda ayri sahip
--      GO'su ister (WP-492 karti); apply ile backfill ayni anda olmaz.
--
-- 🔴 Tetikleyici asla exception atmaz. Oturum kaydi kullanicinin calismasidir;
-- hedef yapilandirmasi eksik ya da hedef tutmamis olmasi bir oturumu
-- dusuremez. Bu, "exception when others ile kritik adimi yutmak" DEGILDIR:
-- hicbir hata yutulmaz, ic fonksiyon tetikleyicinin verebilecegi girdiler icin
-- tanimi geregi total yazilmistir (yapilandirilmamis hedef ve gelecek gun
-- `false` doner, exception uretmez).
--
-- KAPSAM DISI (bilerek yapilmadi):
--   * Oturum SILINMESI tamamlamayi geri almaz. Geri alma, hesap silme yolunda
--     (0113/0114) her satir icin grup toplami yeniden hesaplatir ve purge
--     maliyetini uye sayisiyla carpar. Ayri kart konusu; kartta bildirildi.
--   * Hedefin gun icinde degistirilmesi tek basina olay uretmez; olay yalniz
--     oturum yazildiginda degerlendirilir. Hedefi dusuren kullanicinin o gunku
--     bir sonraki oturumu tamamlamayi yazar.
--
-- Geri alma (Rollback):
--   drop trigger if exists study_sessions_project_goal_completion
--     on public.study_sessions;
--   drop function if exists public._study_session_project_goal_completion();
--   drop function if exists public.backfill_goal_completions();
--   drop function if exists public._record_goal_completion(text, uuid, date);
--   alter publication supabase_realtime drop table public.goal_progress_events;
--   -- ve `0112`deki record_goal_completion govdesini yeniden calistir.
--   -- Yazilmis `goal_progress_events` satirlari kalir; projeksiyon zararsizdir.

-- ---------------------------------------------------------------------------
-- 1. Auth'tan bagimsiz ic yazici
-- ---------------------------------------------------------------------------

create or replace function public._record_goal_completion(
  p_scope_type text,
  p_scope_id uuid,
  p_day date
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
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
    -- Grup hedefi grubun TOPLAM gunudur; tek kisinin gunu degil (`0112`).
    select coalesce(sum(public._goal_day_seconds(gm.user_id, p_day, v_time_zone)), 0)
    into v_seconds
    from public.group_members gm
    where gm.group_id = p_scope_id
      and gm.left_at is null;

  else
    raise exception 'invalid_goal_scope';
  end if;

  -- Hedef yapilandirilmamis: olay yazilmaz. RPC bunu `goal_not_configured`
  -- ile reddeder; tetikleyici yolunda sessiz `false` dogru davranistir.
  if v_goal_minutes is null or v_goal_minutes <= 0 then
    return false;
  end if;
  -- Gelecege seri yazilamaz. RPC bunu exception ile reddeder (istemci iddiasi),
  -- ic yol yalniz atlar (kayitli oturumdan gelen gun zaten gecmistir).
  if p_day > (now() at time zone v_time_zone)::date then
    return false;
  end if;

  -- 🔴 Otorite burada: istemcinin iddiasi degil, kayitli seanslar karar verir.
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
$$;

revoke all on function public._record_goal_completion(text, uuid, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Genel RPC: yetki kapisi burada, hesap ic fonksiyonda
-- ---------------------------------------------------------------------------

-- `0112`deki imza, hata kodlari ve donus degeri DEGISMEDI. Govde yalniz
-- yetkilendirme + yapilandirma kapisini tutar, tamamlama karari tek yerdedir.
create or replace function public.record_goal_completion(
  p_scope_type text,
  p_scope_id uuid,
  p_day date
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_goal_minutes integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_scope_type is null or p_scope_id is null or p_day is null then
    raise exception 'invalid_goal_scope';
  end if;
  if p_day > (now() at time zone 'Europe/Istanbul')::date then
    -- Gelecege seri yazilamaz; aksi halde cihaz saatini ileri alan biri
    -- seriyi istedigi gibi uzatirdi.
    raise exception 'goal_day_in_future';
  end if;

  if p_scope_type = 'personal' then
    if p_scope_id <> v_uid then
      raise exception 'goal_scope_forbidden';
    end if;
    select daily_goal_minutes into v_goal_minutes
    from public.profiles where id = v_uid;
  elsif p_scope_type = 'group' then
    if not public.is_group_member(p_scope_id) then
      raise exception 'goal_scope_forbidden';
    end if;
    select daily_goal_minutes into v_goal_minutes
    from public.groups where id = p_scope_id;
    if not found then
      raise exception 'group_not_found';
    end if;
  else
    raise exception 'invalid_goal_scope';
  end if;

  if v_goal_minutes is null or v_goal_minutes <= 0 then
    raise exception 'goal_not_configured';
  end if;

  return public._record_goal_completion(p_scope_type, p_scope_id, p_day);
end;
$$;

grant execute on function public.record_goal_completion(text, uuid, date) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Yazma yolu: study_sessions tetikleyicisi
-- ---------------------------------------------------------------------------

create or replace function public._study_session_project_goal_completion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_day date;
  v_group record;
begin
  if new.duration_seconds is null or new.duration_seconds <= 0 then
    return new;
  end if;

  -- Kisisel kapsam: gun siniri Europe/Istanbul (`_goal_day_seconds` ile ayni).
  -- Olay zaten varsa toplam hic hesaplanmaz; gunun ikinci, ucuncu oturumu
  -- tetikleyiciyi iki indeks okumasina indirir.
  v_day := (new.start_time at time zone 'Europe/Istanbul')::date;
  if not exists (
    select 1 from public.goal_progress_events e
    where e.scope_type = 'personal'
      and e.scope_id = new.user_id
      and e.event_kind = 'goal_completed'
      and e.goal_day = v_day
  ) then
    perform public._record_goal_completion('personal', new.user_id, v_day);
  end if;

  -- Grup kapsami: kullanicinin aktif uyesi oldugu her grup, KENDI saat
  -- diliminde degerlendirilir (`0076` grup zaman dilimi).
  for v_group in
    select g.id, g.time_zone
    from public.group_members gm
    join public.groups g on g.id = gm.group_id
    where gm.user_id = new.user_id
      and gm.left_at is null
  loop
    v_day := (new.start_time at time zone v_group.time_zone)::date;
    if not exists (
      select 1 from public.goal_progress_events e
      where e.scope_type = 'group'
        and e.scope_id = v_group.id
        and e.event_kind = 'goal_completed'
        and e.goal_day = v_day
    ) then
      perform public._record_goal_completion('group', v_group.id, v_day);
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists study_sessions_project_goal_completion on public.study_sessions;
create trigger study_sessions_project_goal_completion
  after insert or update on public.study_sessions
  for each row execute function public._study_session_project_goal_completion();

-- ---------------------------------------------------------------------------
-- 4. Realtime yayini: yazilan olay EKRANA ulassin
-- ---------------------------------------------------------------------------
-- `SupabaseGoalStreakRepository.watchProjection` `goal_progress_events` uzerinde
-- realtime stream dinleyip her degisimde projeksiyonu yeniden okur. Tablo
-- publication'da olmadigi icin o dinleyici bugune kadar hic tetiklenemezdi:
-- olay yazilsa bile rozet ancak ekran yeniden abone olunca degisirdi. Kabul
-- kriteri "hedef tutturuldugu gun canli alev" oldugu icin yayin bu kartin
-- parcasidir. Kosullu kalip 0016/0018/0117 ile ayni.
--
-- Guvenlik: realtime RLS'e tabidir; `goal_progress_events_select` (0112) zaten
-- kisisel olayi yalniz sahibine, grup olayini yalniz aktif uyeye acar.
do $$
begin
  alter publication supabase_realtime add table public.goal_progress_events;
exception
  when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Gecmis: idempotent backfill (migration CAGIRMAZ)
-- ---------------------------------------------------------------------------

-- Tarihsel hedefler saklanmadigi icin backfill GUNCEL hedef degerini kullanir.
-- Bu bilincli bir yaklasimdir: alternatif, gecmisi hic yazmamak ve sahibin
-- serisini kalici olarak 0 birakmakti.
create or replace function public.backfill_goal_completions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
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

  with group_day_totals as (
    select
      g.id as group_id,
      g.time_zone,
      g.daily_goal_minutes,
      (s.start_time at time zone g.time_zone)::date as goal_day,
      sum(s.duration_seconds)::bigint as seconds,
      max(s.end_time) as last_end
    from public.groups g
    join public.group_members gm
      on gm.group_id = g.id and gm.left_at is null
    join public.study_sessions s
      on s.user_id = gm.user_id and s.duration_seconds > 0
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
  from group_day_totals d
  where d.daily_goal_minutes > 0
    and d.seconds >= d.daily_goal_minutes::bigint * 60
    and d.goal_day <= (now() at time zone d.time_zone)::date
  on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;
  get diagnostics v_group = row_count;

  return v_personal + v_group;
end;
$$;

revoke all on function public.backfill_goal_completions()
  from public, anon, authenticated;
grant execute on function public.backfill_goal_completions() to service_role;

notify pgrst, 'reload schema';
