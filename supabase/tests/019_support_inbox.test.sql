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

select plan(18);

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

-- WP-473: hedef kimligi `0104` (WP-439) ile gercek ve gorunur bir varlik
-- olmak zorunda; uydurma 'target-1' dizgesi artik `invalid_target_id` ile
-- reddediliyor. Rapor hedefi ayni gruptaki beta profiline cevrildi; testin
-- niyeti (rapor kaynak satiri korunur, bilet ona baglanir) degismedi.
select lives_ok(
  $$select public.report_ugc('user', '10000000-0000-0000-0000-000000000002', 'spam', 'Ayrıntı', null)$$,
  'report RPC preserves the UGC report as the authoritative source row'
);

reset role;

select is(
  (select id::text from public.ugc_reports where target_id = '10000000-0000-0000-0000-000000000002'),
  (select ugc_report_id::text from public.feedback_tickets
   where ticket_type = 'report' order by created_at desc limit 1),
  'report ticket retains the authoritative UGC report reference'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (select ticket_type from public.feedback_tickets
   where ugc_report_id = (select id from public.ugc_reports where target_id = '10000000-0000-0000-0000-000000000002')),
  'report',
  'report has a linked support ticket without merging source tables'
);

select throws_ok(
  $$select public.admin_feedback_tickets(null, null, false)$$,
  'P0001',
  'not_super_admin',
  'non-admin cannot read the unified support inbox'
);

select throws_ok(
  $$select public.admin_update_feedback_status(
    '40000000-0000-0000-0000-000000000001', 'closed'
  )$$,
  'P0001',
  'not_super_admin',
  'non-admin cannot change a support ticket status'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);

select lives_ok(
  $$select public.admin_update_feedback_status(
    '40000000-0000-0000-0000-000000000001', 'in_progress'
  )$$,
  'super-admin can change a support ticket status'
);

select is(
  (select status from public.feedback_tickets
   where id = '40000000-0000-0000-0000-000000000001'),
  'in_progress',
  'admin status RPC updates the ticket'
);

select is(
  (select count(*) from public.admin_audit_logs
   where admin_id = '10000000-0000-0000-0000-000000000002'
     and target_user_id = '10000000-0000-0000-0000-000000000001'
     and action = 'support_ticket_status_changed'
     and reason like '%ticket=40000000-0000-0000-0000-000000000001%'
     and reason like '%type=feedback%'
     and reason like '%status=open%'
     and reason like '%in_progress%'),
  1::bigint,
  'status change leaves a server-authoritative admin audit record'
);

select lives_ok(
  $$select public.admin_update_feedback_status(
    '40000000-0000-0000-0000-000000000001', 'in_progress'
  )$$,
  'repeating the current status is safe'
);

select is(
  (select count(*) from public.admin_audit_logs
   where action = 'support_ticket_status_changed'),
  1::bigint,
  'unchanged status does not add a duplicate audit record'
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
