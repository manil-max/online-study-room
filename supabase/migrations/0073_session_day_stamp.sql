-- 0073_session_day_stamp.sql
-- WP-325: Oturum gününü kayıt anında materialize eder. Tarihsel gün, ileride
-- grup/bölge zaman dilimi değişse bile yeniden hesaplanmaz; yeni kayıtlar için
-- mevcut ürün varsayılanı Europe/Istanbul'dur.
--
-- Geri alma (rollback):
--   1. drop trigger if exists study_sessions_stamp_day on public.study_sessions;
--   2. drop function if exists public._stamp_study_session_day();
--   3. drop index if exists public.study_sessions_user_day_idx;
--   4. 0041'deki get_user_day_totals(date,date) gövdesini start_time tabanlı
--      sürümle bilinçli olarak geri yükle.
--   5. alter table public.study_sessions drop column if exists day;
-- Not: geri alma yalnızca bakım penceresinde, yedek doğrulamasıyla uygulanır.

alter table public.study_sessions
  add column if not exists day date;

create or replace function public._stamp_study_session_day()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.day := (new.start_time at time zone 'Europe/Istanbul')::date;
  return new;
end;
$$;

drop trigger if exists study_sessions_stamp_day on public.study_sessions;
create trigger study_sessions_stamp_day
  before insert or update on public.study_sessions
  for each row execute function public._stamp_study_session_day();

-- Backfill sadece yeni day sütununu değiştirir. User trigger'ları bu kontrollü
-- tarihsel operasyon sırasında kapalıdır: böylece doğrulanmış oturum koruması
-- ile grup/başarım projeksiyonları gereksiz yere çalışmaz. Migration transaction
-- içinde hata olursa trigger durumu da atomik olarak geri alınır.
alter table public.study_sessions disable trigger user;

do $$
declare
  v_changed integer;
begin
  loop
    with batch as (
      select ctid
      from public.study_sessions
      where day is null
      order by ctid
      limit 1000
    )
    update public.study_sessions s
    set day = (s.start_time at time zone 'Europe/Istanbul')::date
    from batch
    where s.ctid = batch.ctid;

    get diagnostics v_changed = row_count;
    exit when v_changed = 0;
  end loop;
end;
$$;

alter table public.study_sessions enable trigger user;
alter table public.study_sessions alter column day set not null;

create index if not exists study_sessions_user_day_idx
  on public.study_sessions (user_id, day);

create or replace function public.get_user_day_totals(
  p_from date,
  p_to date
)
returns table (day date, seconds int)
language sql
security definer
set search_path = public
stable
as $$
  select
    s.day,
    sum(s.duration_seconds)::int as seconds
  from public.study_sessions s
  where s.user_id = auth.uid()
    and s.day between p_from and p_to
  group by s.day
  order by s.day;
$$;

grant execute on function public.get_user_day_totals(date, date) to authenticated;

comment on column public.study_sessions.day is
  'WP-325: server-stamped historical session day; never client-authored.';
comment on function public.get_user_day_totals(date, date) is
  'WP-325: self-only daily totals over stored study_sessions.day.';
