begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir _fixtures/base_seed.psql

select plan(8);

select ok(
  exists(
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'study_sessions'
      and column_name = 'day' and is_nullable = 'NO'
  ),
  'study_sessions.day is materialized and non-null'
);

select is(
  (select day from public.study_sessions
    where id = '30000000-0000-0000-0000-000000000001'),
  (select (start_time at time zone 'Europe/Istanbul')::date from public.study_sessions
    where id = '30000000-0000-0000-0000-000000000001'),
  'historical rows are backfilled with their Istanbul start day'
);

insert into public.study_sessions(
  id, user_id, start_time, end_time, duration_seconds, source, day
) values (
  '30000000-0000-0000-0000-000000000073',
  '10000000-0000-0000-0000-000000000001',
  '2026-05-10 20:45:00+00', '2026-05-10 22:15:00+00', 5400, 'manual',
  '1999-01-01'
);

select is(
  (select day from public.study_sessions
    where id = '30000000-0000-0000-0000-000000000073'),
  date '2026-05-10',
  'insert ignores a client-supplied day and uses the session start day'
);

select is(
  (select day from public.study_sessions
    where id = '30000000-0000-0000-0000-000000000073'),
  date '2026-05-10',
  'a midnight-crossing session stays in its start day'
);

update public.study_sessions
set start_time = '2026-05-11 20:45:00+00',
    end_time = '2026-05-11 22:15:00+00'
where id = '30000000-0000-0000-0000-000000000073';

select is(
  (select day from public.study_sessions
    where id = '30000000-0000-0000-0000-000000000073'),
  date '2026-05-11',
  'manual historical start-time edit recomputes the stored day'
);

update public.study_sessions
set day = '1999-01-01'
where id = '30000000-0000-0000-0000-000000000073';

select is(
  (select day from public.study_sessions
    where id = '30000000-0000-0000-0000-000000000073'),
  date '2026-05-11',
  'direct day mutation is overwritten by the server trigger'
);

select ok(
  exists(
    select 1 from pg_indexes
    where schemaname = 'public' and tablename = 'study_sessions'
      and indexname = 'study_sessions_user_day_idx'
  ),
  'user/day index exists for stored-day range queries'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (select seconds from public.get_user_day_totals(date '2026-05-11', date '2026-05-11')),
  (select sum(duration_seconds)::int from public.study_sessions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and (start_time at time zone 'Europe/Istanbul')::date = date '2026-05-11'),
  'get_user_day_totals matches the former start_time aggregate over stored day'
);

reset role;
select * from finish();
rollback;
