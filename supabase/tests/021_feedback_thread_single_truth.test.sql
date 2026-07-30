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
  'feedback-thread-outsider@example.invalid',
  '{"display_name":"Thread outsider"}'::jsonb
)
on conflict (id) do nothing;

insert into public.feedback_tickets (
  id, user_id, kind, subject, message, status
) values (
  '43500000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'feedback', 'Tek gerçek', 'İlk kanonik mesaj', 'open'
);

select plan(12);

select is(
  (select message from public.feedback_ticket_messages
    where ticket_id = '43500000-0000-0000-0000-000000000001'
    order by message_seq),
  'İlk kanonik mesaj',
  'new ticket initial text is seeded into the canonical message sequence'
);

select is(
  (select message_seq from public.feedback_ticket_messages
    where ticket_id = '43500000-0000-0000-0000-000000000001'),
  1::bigint,
  'initial message starts at the server ordering cursor one'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (select message_seq from public.send_feedback_ticket_message(
    '43500000-0000-0000-0000-000000000001',
    'Devam mesajı',
    '43500000-0000-0000-0000-000000000101'
  )),
  2::bigint,
  'next message receives the server-owned sequence cursor'
);

select is(
  (select id from public.send_feedback_ticket_message(
    '43500000-0000-0000-0000-000000000001',
    'Devam mesajı',
    '43500000-0000-0000-0000-000000000101'
  )),
  (select id from public.feedback_ticket_messages
    where ticket_id = '43500000-0000-0000-0000-000000000001'
      and client_message_id = '43500000-0000-0000-0000-000000000101'),
  'retrying a command id returns the original message row'
);

select is(
  (select count(*) from public.feedback_ticket_messages
    where ticket_id = '43500000-0000-0000-0000-000000000001'),
  2::bigint,
  'an idempotent retry does not append a duplicate message'
);

select public.mark_feedback_ticket_messages_read(
  '43500000-0000-0000-0000-000000000001'
);
select is(
  (select last_read_message_seq from public.feedback_ticket_read_watermarks
    where ticket_id = '43500000-0000-0000-0000-000000000001'
      and user_id = '10000000-0000-0000-0000-000000000001'),
  2::bigint,
  'the reader watermark records the latest server sequence'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000099', true);
select is(
  (select count(*) from public.feedback_ticket_messages
    where ticket_id = '43500000-0000-0000-0000-000000000001'),
  0::bigint,
  'an unrelated user cannot select another users thread'
);
select throws_ok(
  $$select public.send_feedback_ticket_message(
      '43500000-0000-0000-0000-000000000001',
      'Enjekte mesaj',
      '43500000-0000-0000-0000-000000000199'
    )$$,
  'P0001',
  'feedback_ticket_access_denied',
  'an unrelated user cannot append to another users thread'
);
select throws_ok(
  $$insert into public.feedback_ticket_messages (
      ticket_id, sender_id, sender_role, message, client_message_id, message_seq
    ) values (
      '43500000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000099', 'admin', 'Sahte rol',
      '43500000-0000-0000-0000-000000000200', 3
    )$$,
  '42501',
  'permission denied for table feedback_ticket_messages',
  'direct insert cannot forge sender role or sequence'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select is(
  (select sender_role from public.send_feedback_ticket_message(
    '43500000-0000-0000-0000-000000000001',
    'Yönetim yanıtı',
    '43500000-0000-0000-0000-000000000201'
  )),
  'admin',
  'the server derives the super-admin sender role'
);
select is(
  (select latest_message_seq from public.feedback_tickets
    where id = '43500000-0000-0000-0000-000000000001'),
  3::bigint,
  'ticket projection tracks the latest canonical message sequence'
);
select is(
  (select count(*) from public.announcements
    where related_feedback_ticket_id = '43500000-0000-0000-0000-000000000001'),
  0::bigint,
  'admin replies no longer create a second announcement truth'
);

reset role;
select * from finish();
rollback;
