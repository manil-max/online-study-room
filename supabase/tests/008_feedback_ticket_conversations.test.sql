begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir _fixtures/base_seed.psql

insert into auth.users (id, email, raw_user_meta_data)
values (
  '10000000-0000-0000-0000-000000000099',
  'conversation-outsider@example.invalid',
  '{"display_name":"Conversation Outsider"}'::jsonb
)
on conflict (id) do nothing;

insert into public.app_admins (user_id)
values ('10000000-0000-0000-0000-000000000002')
on conflict (user_id) do nothing;

insert into public.feedback_tickets (
  id, user_id, kind, subject, message, status
) values (
  '40000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'feedback', 'Yazışma testi', 'İlk geri bildirim', 'open'
);

select plan(12);

select ok(
  exists(
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'feedback_ticket_messages'
      and column_name = 'read_at'
  ),
  'feedback conversations persist a recipient read timestamp'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (select sender_role from public.send_feedback_ticket_message(
    '40000000-0000-0000-0000-000000000001', '  Kullanıcı yanıtı  '
  )),
  'user',
  'ticket owner can send a message and the server derives the user role'
);

select is(
  (select status from public.feedback_tickets
    where id = '40000000-0000-0000-0000-000000000001'),
  'in_progress',
  'any conversation reply moves the ticket to in_progress'
);

select throws_ok(
  $$insert into public.feedback_ticket_messages (
      ticket_id, sender_id, sender_role, message
    ) values (
      '40000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001', 'admin', 'Sahte rol'
    )$$,
  '42501',
  'permission denied for table feedback_ticket_messages',
  'client cannot forge a message sender role because direct table insert is revoked'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000099', true);
select is(
  (select count(*) from public.feedback_ticket_messages),
  0::bigint,
  'unrelated user cannot read another users conversation'
);
select throws_ok(
  $$select public.send_feedback_ticket_message(
      '40000000-0000-0000-0000-000000000001', 'Yetkisiz yanıt'
    )$$,
  'P0001',
  'feedback_ticket_access_denied',
  'unrelated user cannot write another users conversation'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select is(
  (select sender_role from public.send_feedback_ticket_message(
    '40000000-0000-0000-0000-000000000001', 'Yönetim yanıtı'
  )),
  'admin',
  'super-admin reply receives the server-derived admin role'
);

select is(
  (select target_id from public.announcements
    where related_feedback_ticket_id = '40000000-0000-0000-0000-000000000001'
    order by created_at desc limit 1),
  '10000000-0000-0000-0000-000000000001',
  'admin reply creates a user-targeted announcement for the ticket owner'
);

select is(
  (select created_by::text from public.announcements
    where related_feedback_ticket_id = '40000000-0000-0000-0000-000000000001'
    order by created_at desc limit 1),
  '10000000-0000-0000-0000-000000000002',
  'announcement author is the authenticated admin, not a client-supplied id'
);

select public.mark_feedback_ticket_messages_read(
  '40000000-0000-0000-0000-000000000001'
);
select ok(
  (select read_at is not null from public.feedback_ticket_messages
    where ticket_id = '40000000-0000-0000-0000-000000000001'
      and sender_role = 'user'),
  'admin opening the conversation marks user messages read'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is(
  (select count(*) from public.feedback_ticket_messages),
  2::bigint,
  'ticket owner can read both sides of the conversation'
);
select public.mark_feedback_ticket_messages_read(
  '40000000-0000-0000-0000-000000000001'
);
select ok(
  (select read_at is not null from public.feedback_ticket_messages
    where ticket_id = '40000000-0000-0000-0000-000000000001'
      and sender_role = 'admin'),
  'ticket owner opening the conversation marks the admin reply read'
);

reset role;
select * from finish();
rollback;
