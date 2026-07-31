-- 0112_goal_streak_projection.sql
-- WP-453 Faz 2: hedef tamamlamasina dayali seri motorunun SUNUCU ayagi.
--
-- Faz 1 saf Dart durum makinesini ve `app/test/fixtures/goal_streak_parity_v1.json`
-- parity fixture'ini indirdi. Bu migration AYNI fixture'i SQL projection'a
-- uyguluyor; iki uc arasinda sozlesme testi olmadan yasayan ozellikler oldu
-- (WP-373), bu yuzden algoritma iki yerde de ayni ve `037` her iki ucu birden
-- okuyor.
--
-- Kart numarayi `0110` diye yaziyordu; o numara WP-443'un moderasyon
-- migration'ina gitti. Yeni numara `0112`.
--
-- SOZLESME
--   * Seri YALNIZ `goal_completed` olayindan ilerler. `app_opened`,
--     `timer_started` ve `partial_progress` kayit altina alinir ama projeksiyona
--     GIRMEZ — kartin birincil sikayeti "uygulamayi acmakla seri ilerliyor"du.
--   * Tek kacirma korunur (grace), iki ardisik kacirma sifirlar:
--     `tamamla-bos-tamamla-bos-tamamla = 3`. Bu tek seferlik joker degildir,
--     her tek kacirmada tekrar uygulanir ve tuketilen `streak_freezes`
--     bakiyesiyle KARISTIRILMAZ (o ayri bir kavram).
--   * Kisisel ve grup serisi ayri ledger anahtari kullanir; ayni gun ayni
--     kimlik iki kapsamda birbirini beslemez.
--   * Olay yazma istemciye acik degil: `record_goal_completion` sunucuda
--     `study_sessions`'tan gercekten hedefe ulasildigini DOGRULAR. Istemcinin
--     "tamamladim" demesi yeterli degildir.

create table if not exists public.goal_progress_events (
  event_key   text primary key,
  scope_type  text not null check (scope_type in ('personal', 'group')),
  scope_id    uuid not null,
  time_zone   text not null,
  event_kind  text not null check (
    event_kind in ('app_opened', 'timer_started', 'partial_progress', 'goal_completed')
  ),
  goal_day    date not null,
  occurred_at timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  -- Ayni kapsam + ayni gun + ayni tur ikinci kez yazilamaz. "duplicate goal
  -- event cift artis uretmez" kabulu uygulama katmaninda degil, SEMADA duruyor.
  unique (scope_type, scope_id, event_kind, goal_day)
);

create index if not exists goal_progress_events_scope_day_idx
  on public.goal_progress_events (scope_type, scope_id, goal_day desc);

alter table public.goal_progress_events enable row level security;

-- Okuma: kisi kendi kisisel olaylarini, grup olaylarini ise yalniz aktif uyesi
-- oldugu grup icin gorur. Yazma yolu yok — tek kapi RPC.
drop policy if exists goal_progress_events_select on public.goal_progress_events;
create policy goal_progress_events_select on public.goal_progress_events
  for select to authenticated
  using (
    case scope_type
      when 'personal' then scope_id = auth.uid()
      when 'group' then public.is_group_member(scope_id)
      else false
    end
  );

revoke insert, update, delete on public.goal_progress_events from authenticated;

-- ---------------------------------------------------------------------------
-- Gun toplamlari
-- ---------------------------------------------------------------------------

-- Bir kullanicinin verilen takvim gunundeki toplam calisma saniyesi.
--
-- Gun siniri kapsamin saat dilimine gore kesilir: grup kendi bolgesinde,
-- kisisel hesap Europe/Istanbul'da. Seans BASLANGICI gunu belirler; bu, mevcut
-- `group_daily_totals` (0011) davranisiyla ayni olsun diye bilerek boyle.
create or replace function public._goal_day_seconds(
  p_user_id uuid,
  p_day date,
  p_time_zone text
)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(s.duration_seconds), 0)::bigint
  from public.study_sessions s
  where s.user_id = p_user_id
    and s.duration_seconds > 0
    and (s.start_time at time zone p_time_zone)::date = p_day;
$$;

revoke all on function public._goal_day_seconds(uuid, date, text) from public;

-- ---------------------------------------------------------------------------
-- Olay yazici: sunucu-otoriter
-- ---------------------------------------------------------------------------

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
  v_time_zone text;
  v_goal_minutes integer;
  v_seconds bigint;
  v_key text;
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
    v_time_zone := 'Europe/Istanbul';
    select daily_goal_minutes into v_goal_minutes
    from public.profiles where id = v_uid;
    v_seconds := public._goal_day_seconds(v_uid, p_day, v_time_zone);

  elsif p_scope_type = 'group' then
    if not public.is_group_member(p_scope_id) then
      raise exception 'goal_scope_forbidden';
    end if;
    select time_zone, daily_goal_minutes into v_time_zone, v_goal_minutes
    from public.groups where id = p_scope_id;
    if v_time_zone is null then
      raise exception 'group_not_found';
    end if;
    -- Grup hedefi grubun TOPLAM gunudur; tek kisinin gunu degil.
    select coalesce(sum(public._goal_day_seconds(gm.user_id, p_day, v_time_zone)), 0)
    into v_seconds
    from public.group_members gm
    where gm.group_id = p_scope_id
      and gm.left_at is null;

  else
    raise exception 'invalid_goal_scope';
  end if;

  if v_goal_minutes is null or v_goal_minutes <= 0 then
    raise exception 'goal_not_configured';
  end if;

  -- 🔴 Otorite burada: istemcinin iddiasi degil, kayitli seanslar karar verir.
  if v_seconds < (v_goal_minutes::bigint * 60) then
    return false;
  end if;

  v_key := p_scope_type || ':' || p_scope_id::text || ':goal_completed:' || p_day::text;

  insert into public.goal_progress_events (
    event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
  ) values (
    v_key, p_scope_type, p_scope_id, v_time_zone, 'goal_completed', p_day, now()
  )
  -- Tekrar cagri is yapmaz; unique kisit zaten cift artisi imkansiz kilar.
  on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;

  return true;
end;
$$;

grant execute on function public.record_goal_completion(text, uuid, date) to authenticated;

-- ---------------------------------------------------------------------------
-- Projeksiyon: Faz 1 Dart durum makinesinin birebir esi
-- ---------------------------------------------------------------------------

create or replace function public.goal_streak_projection(
  p_scope_type text,
  p_scope_id uuid,
  p_as_of_day date
)
returns table (
  scope_type text,
  scope_id uuid,
  time_zone text,
  as_of_day date,
  current_streak integer,
  completion_count integer,
  last_completed_day date,
  state text,
  source_version text
)
language sql
stable
security invoker
set search_path = public
as $$
  with completed as (
    -- Yalniz `goal_completed`. Diger olay turleri kayitta durur ama seriye
    -- girmez: kartin "app open / timer start / kismi ilerleme artis uretmez"
    -- kabulu tam olarak bu `where`dir.
    select distinct e.goal_day, e.time_zone
    from public.goal_progress_events e
    where e.scope_type = p_scope_type
      and e.scope_id = p_scope_id
      and e.event_kind = 'goal_completed'
      and e.goal_day <= p_as_of_day
  ), runs as (
    select
      goal_day,
      -- Iki ardisik bos gun (fark > 2) yeni bir seri baslatir; tek bos gun
      -- (fark = 2) seriyi surdurur.
      sum(
        case
          when prev_day is null or (goal_day - prev_day) > 2 then 1
          else 0
        end
      ) over (order by goal_day) as run_id
    from (
      select goal_day, lag(goal_day) over (order by goal_day) as prev_day
      from completed
    ) ordered
  ), summary as (
    select
      (select count(*)::integer from completed) as completion_count,
      (select max(goal_day) from completed) as last_completed_day,
      (
        select count(*)::integer from runs
        where run_id = (select max(run_id) from runs)
      ) as last_run_length
  )
  select
    p_scope_type,
    p_scope_id,
    (select time_zone from completed order by goal_day desc limit 1),
    p_as_of_day,
    case
      when s.last_completed_day is null then 0
      when (p_as_of_day - s.last_completed_day) <= 2 then s.last_run_length
      else 0
    end,
    s.completion_count,
    s.last_completed_day,
    case
      when s.last_completed_day is null then 'empty'
      when (p_as_of_day - s.last_completed_day) = 0 then 'completed_today'
      when (p_as_of_day - s.last_completed_day) = 1 then 'pending_today'
      when (p_as_of_day - s.last_completed_day) = 2 then 'at_risk'
      else 'expired'
    end,
    'goal_completion_v1'
  from summary s;
$$;

grant execute on function public.goal_streak_projection(text, uuid, date) to authenticated;
