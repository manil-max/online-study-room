begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir _fixtures/base_seed.psql

insert into public.app_admins (user_id)
values ('10000000-0000-0000-0000-000000000002')
on conflict (user_id) do nothing;

insert into auth.users (id, email, raw_user_meta_data)
values (
  '10000000-0000-0000-0000-000000000099',
  'support-rate@example.invalid',
  '{"display_name":"Support Rate"}'::jsonb
)
on conflict (id) do nothing;

insert into public.feedback_tickets (
  id, user_id, kind, subject, message, status
) values (
  '40000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'feedback', 'Eski bilet', 'Önceki sürümden gelen bilet.', 'open'
);

select plan(12);

select is(
  (select ticket_type from public.feedback_tickets
   where id = '40000000-0000-0000-0000-000000000001'),
  'feedback',
  'existing feedback ticket is backfilled as feedback'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$insert into public.feedback_tickets (user_id, kind, ticket_type, subject, message)
    values (auth.uid(), 'feedback', 'question', 'SSS sorusu', 'Bu soru destek kutusuna düşer.')$$,
  'ticket owner can create a question ticket'
);

reset role;

select is(
  (select count(*) from public.notification_outbox
   where event_key like 'support-ticket:%'
     and payload ->> 'ticket_type' = 'question'
     and recipient_id = '10000000-0000-0000-0000-000000000002'),
  1::bigint,
  'new ticket creates one idempotent admin push outbox event'
);

select is(
  (select notification_type from public.notification_outbox
   where event_key like 'support-ticket:%' limit 1),
  'announcement',
  'support notification uses the existing push delivery path'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$select public.report_ugc('user', 'target-1', 'spam', 'Ayrıntı', null)$$,
  'report RPC preserves the UGC report as the authoritative source row'
);

reset role;

select is(
  (select id::text from public.ugc_reports where target_id = 'target-1'),
  (select ugc_report_id::text from public.feedback_tickets
   where ticket_type = 'report' order by created_at desc limit 1),
  'report ticket retains the authoritative UGC report reference'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (select ticket_type from public.feedback_tickets
   where ugc_report_id = (select id from public.ugc_reports where target_id = 'target-1')),
  'report',
  'report has a linked support ticket without merging source tables'
);

select throws_ok(
  $$select public.admin_feedback_tickets(null, null, false)$$,
  'P0001',
  'not_super_admin',
  'non-admin cannot read the unified support inbox'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000099', true);

select lives_ok(
  $$insert into public.feedback_tickets (user_id, kind, ticket_type, subject, message)
    values (auth.uid(), 'feedback', 'feedback', 'İkinci', 'İkinci destek mesajı.')$$,
  'second non-report ticket remains below the rate limit'
);

select lives_ok(
  $$insert into public.feedback_tickets (user_id, kind, ticket_type, subject, message)
    values (auth.uid(), 'feedback', 'feedback', 'Üçüncü', 'Üçüncü destek mesajı.')$$,
  'third non-report ticket remains below the rate limit'
);

select lives_ok(
  $$insert into public.feedback_tickets (user_id, kind, ticket_type, subject, message)
    values (auth.uid(), 'feedback', 'feedback', 'Dördüncü', 'Dördüncü destek mesajı.')$$,
  'third prior ticket remains below the rate limit'
);

select throws_ok(
  $$insert into public.feedback_tickets (user_id, kind, ticket_type, subject, message)
    values (auth.uid(), 'feedback', 'feedback', 'Beşinci', 'Beşinci destek mesajı.')$$,
  'P0001',
  'support_ticket_rate_limited',
  'server rejects a fourth support ticket in fifteen minutes'
);

reset role;
select * from finish();
rollback;
