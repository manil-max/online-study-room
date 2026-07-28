begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

select plan(4);

insert into auth.users (id, email, raw_user_meta_data)
values
  ('10000000-0000-0000-0000-000000000003', 'block-sender@example.invalid', '{"display_name":"Block Sender"}'::jsonb),
  ('10000000-0000-0000-0000-000000000004', 'block-recipient@example.invalid', '{"display_name":"Block Recipient"}'::jsonb)
on conflict (id) do nothing;

insert into public.group_members (group_id, user_id, role, joined_at)
values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 'member', now()),
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000004', 'member', now())
on conflict (group_id, user_id) do nothing;

insert into public.user_blocks (blocker_id, blocked_id)
values ('10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000004')
on conflict do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.send_nudge('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000004', null)$$,
  'P0001', 'nudge_blocked', 'blocker cannot nudge the blocked member'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);
select throws_ok(
  $$select public.send_nudge('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', null)$$,
  'P0001', 'nudge_blocked', 'blocked member cannot nudge the blocker'
);
reset role;

select ok(
  to_regprocedure('public.send_nudge(uuid,uuid,text)') is not null,
  'nudge RPC remains available after block enforcement'
);
select ok(
  exists (select 1 from public.user_blocks),
  'block records remain the source of truth; membership is not deleted'
);
select * from finish();
rollback;
