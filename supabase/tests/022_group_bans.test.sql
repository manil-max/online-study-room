begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

-- Local seed aynı kimliği LOCAL001 koduyla oluşturur; bu test davet kodunu
-- transaction içinde sabitleyerek fixture'ı local/staging replay'de eşitler.
update public.groups
set invite_code = 'FIXTURE1'
where id = '20000000-0000-0000-0000-000000000001';

select plan(13);

insert into auth.users (id, email, raw_user_meta_data)
values ('10000000-0000-0000-0000-000000000003', 'group-ban@example.invalid', '{"display_name":"Group Ban"}'::jsonb)
on conflict (id) do nothing;

insert into public.group_members (group_id, user_id, role, joined_at)
values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 'member', now())
on conflict (group_id, user_id) do update set left_at = null;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.ban_group_member('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003')$$,
  'group owner can ban a member'
);
reset role;
select ok(
  exists (select 1 from public.group_bans where group_id = '20000000-0000-0000-0000-000000000001' and user_id = '10000000-0000-0000-0000-000000000003'),
  'ban record is persisted'
);
select ok(
  not exists (select 1 from public.group_members where group_id = '20000000-0000-0000-0000-000000000001' and user_id = '10000000-0000-0000-0000-000000000003' and left_at is null),
  'ban atomically removes active membership'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is((select count(*) from public.list_group_bans('20000000-0000-0000-0000-000000000001')), 1::bigint, 'group owner can view ban list');

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.join_group('FIXTURE1')$$, 'P0001', 'group_banned', 'banned member cannot join with a valid invite code'
);
select throws_ok(
  $$select public.list_group_bans('20000000-0000-0000-0000-000000000001')$$, 'P0001', 'not_group_admin', 'blocked member cannot view ban list'
);
select throws_ok(
  $$select public.ban_group_member('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002')$$, 'P0001', 'not_group_admin', 'non-manager cannot ban'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select public.ban_group_member('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001')$$, 'P0001', 'cannot_ban_self', 'manager cannot ban self'
);
select lives_ok(
  $$select public.unban_group_member('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003')$$,
  'manager can remove a ban'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
select lives_ok($$select public.join_group('FIXTURE1')$$, 'unbanned member can join again');

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select isnt(
  public.regenerate_group_invite_code('20000000-0000-0000-0000-000000000001'),
  'FIXTURE1',
  'invite reset invalidates the old code without touching existing members'
);
select ok(
  public.join_group('FIXTURE1') is null,
  'the old invite code is invalid immediately after reset'
);
select ok(
  exists (
    select 1 from public.group_members
    where group_id = '20000000-0000-0000-0000-000000000001'
      and user_id = '10000000-0000-0000-0000-000000000001'
      and left_at is null
  ),
  'invite reset leaves existing members untouched'
);
select * from finish();
rollback;
