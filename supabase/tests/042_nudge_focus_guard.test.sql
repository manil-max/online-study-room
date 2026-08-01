-- 042_nudge_focus_guard.test.sql
-- WP-476: çalışan kişiyi dürtmeme, 20 dakika cooldown ve İlham Kaynağı
-- metriğinin ham gönderim yerine gerçek çalışma dönüşümünü sayması.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

select plan(8);

-- Aktif lease: çalışan kişinin odağı sunucuda korunur.
insert into public.user_live_presence_state (
  user_id, status, started_at, today_seconds, lease_expires_at, state_version
) values (
  :'beta', 'studying', now() - interval '1 minute', 60,
  now() + interval '60 seconds', 1
) on conflict (user_id) do update set
  status = excluded.status,
  started_at = excluded.started_at,
  today_seconds = excluded.today_seconds,
  lease_expires_at = excluded.lease_expires_at,
  state_version = public.user_live_presence_state.state_version + 1;

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select throws_ok(
  $$select public.send_nudge(
      '20000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000002', null
    )$$,
  'recipient_is_studying',
  'aktif lease ile çalışan kişi dürtülemez'
);

-- Bayat lease sonsuz kilit üretmez.
reset role;
update public.user_live_presence_state
set lease_expires_at = now() - interval '1 second'
where user_id = :'beta';
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select lives_ok(
  $$select public.send_nudge(
      '20000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000002', null
    )$$,
  'lease dolunca eski studying satırı dürtmeyi kilitlemez'
);

-- Cooldown sınırı: 15 dakika reddedilir, 21 dakika kabul edilir.
reset role;
delete from public.nudges where sender_id = :'alpha' and recipient_id = :'beta';
insert into public.nudges (group_id, sender_id, recipient_id, created_at)
values (:'grp', :'alpha', :'beta', now() - interval '15 minutes');
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select throws_ok(
  $$select public.send_nudge(
      '20000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000002', null
    )$$,
  'nudge_cooldown',
  '15 dakika önceki dürtme 20 dakikalık pencerede reddedilir'
);

reset role;
update public.nudges
set created_at = now() - interval '21 minutes'
where sender_id = :'alpha' and recipient_id = :'beta';
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select lives_ok(
  $$select public.send_nudge(
      '20000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000002', null
    )$$,
  '20 dakika dolunca aynı kişiye yeniden dürtme kabul edilir'
);

-- İlham metriği: yalnız dürtmeden sonraki 20 dakikada başlayan çalışma sayılır.
reset role;
delete from public.nudges where sender_id = :'alpha' and recipient_id = :'beta';
delete from public.study_sessions
where id in (
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000002'
);
insert into public.nudges (
  id, group_id, sender_id, recipient_id, created_at
) values (
  '41000000-0000-0000-0000-000000000001', :'grp', :'alpha', :'beta',
  now() - interval '10 minutes'
);
insert into public.live_study_runs (
  id, run_token, user_id, client_request_id, status, started_at,
  finalized_at, session_id
) values (
  '42000000-0000-0000-0000-000000000002',
  '42000000-0000-0000-0000-000000000012',
  :'beta',
  '42000000-0000-0000-0000-000000000022',
  'finalized',
  now() - interval '5 minutes',
  now() - interval '4 minutes',
  '42000000-0000-0000-0000-000000000002'
);
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source, live_run_id
) values
  (
    '42000000-0000-0000-0000-000000000001', :'beta',
    now() - interval '11 minutes', now() - interval '10 minutes 30 seconds',
    30, 'manual', null
  ),
  (
    '42000000-0000-0000-0000-000000000002', :'beta',
    now() - interval '5 minutes', now() - interval '4 minutes',
    60, 'live', '42000000-0000-0000-0000-000000000002'
  );

select is(
  public._count_converted_nudges(:'alpha'::uuid),
  1,
  'dürtmeden önceki çalışma sayılmaz, 20 dakika içindeki çalışma sayılır'
);
select is(
  (public._achievement_metrics(:'alpha'::uuid)->>'nudge_starts')::int,
  1,
  'İlham Kaynağı değerlendirmesi dönüştürülmüş dürtme sayısını kullanır'
);
select is(
  (
    select source_version
    from public.achievement_metric_definitions
    where achievement_id = 'inspiration'
  ),
  'nudge_conversion_verified_v1',
  'metrik sözleşme sürümü dönüşüm davranışını ilan eder'
);
select is(
  (
    select description
    from public.achievements_dict
    where id = 'inspiration'
  ),
  'Dürttüğün kişi 20 dakika içinde çalışmaya başlarsa sayılır',
  'sunucu sözlüğü kullanıcıya gerçek kuralı söyler'
);

select * from finish();
rollback;
