begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql
select plan(6);

-- WP-367 (V51-1): İstemci canlılığı projeksiyon satırının `lease_expires_at`
-- alanından türetir. 0081'de heartbeat yalnız kanonik satırı yeniliyordu, bu
-- yüzden kullanıcı sayaç çalışırken ~70-90 sn sonra çevrimdışına düşüyordu.

insert into public.groups (id, name, invite_code, created_by, created_at)
values ('20000000-0000-0000-0000-000000000086', 'Heartbeat Lease', 'LEASE086',
  '10000000-0000-0000-0000-000000000001', clock_timestamp());
insert into public.group_members (group_id, user_id, role, joined_at)
values ('20000000-0000-0000-0000-000000000086',
  '10000000-0000-0000-0000-000000000001', 'admin', clock_timestamp());

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select public.apply_multi_group_presence_state('studying', clock_timestamp(), 60, null);
reset role;

select is(
  (select count(*)::integer from public.group_live_presence
    where user_id = '10000000-0000-0000-0000-000000000001'),
  2,
  'active state fans out to both memberships before the heartbeat'
);

-- Lease'i geçmişe çek: bu, sahibin cihazda gördüğü ~80. saniyedeki durumdur.
update public.user_live_presence_state
set lease_expires_at = clock_timestamp() - interval '5 seconds'
where user_id = '10000000-0000-0000-0000-000000000001';
update public.group_live_presence
set lease_expires_at = clock_timestamp() - interval '5 seconds'
where user_id = '10000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select public.heartbeat_multi_group_presence();
reset role;

select ok(
  (select lease_expires_at from public.user_live_presence_state
    where user_id = '10000000-0000-0000-0000-000000000001') > clock_timestamp(),
  'heartbeat renews the canonical lease'
);

-- Asıl regresyon: 0086 öncesinde bu satır geçmişte kalıyordu ve okuyucular
-- kullanıcıyı çevrimdışı gösteriyordu.
select is(
  (select count(*)::integer from public.group_live_presence
    where user_id = '10000000-0000-0000-0000-000000000001'
      and lease_expires_at > clock_timestamp()),
  2,
  'heartbeat renews every fan-out projection lease, not just the canonical row'
);

select is(
  (select count(*)::integer from public.group_live_presence
    where user_id = '10000000-0000-0000-0000-000000000001'),
  2,
  'heartbeat renewal never adds or drops a projection row'
);

select is(
  (select count(distinct lease_expires_at)::integer from public.group_live_presence
    where user_id = '10000000-0000-0000-0000-000000000001'),
  1,
  'every projection row carries the same renewed lease as the canonical state'
);

-- Davranış koruması: çevrimdışı kullanıcıda heartbeat hâlâ reddedilir; aksi
-- halde durdurulmuş bir sayaç kendini süresiz canlı tutabilirdi.
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select public.apply_multi_group_presence_state('offline', null, 0, null);
select throws_ok(
  $$select public.heartbeat_multi_group_presence()$$,
  'presence_state_not_active',
  'heartbeat still refuses to renew an offline state'
);
reset role;

select * from finish();
rollback;
