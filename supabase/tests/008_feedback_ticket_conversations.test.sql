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

-- 11: WP-473'te iki bayat duyuru iddiası tek "duyuru üretilmez" iddiasına indi.
select plan(11);

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

-- 🔴 WP-473: bu iki iddia `0074` (WP-317) dünyasına aitti; admin yanıtı o
-- zaman kullanıcıya ayrı bir duyuru satırı yazıyordu. `0103` (WP-435) tek
-- gerçek olarak konuşma dizisini seçti ve duyuru satırını **bilerek** kaldırdı:
-- aynı mesajın ikinci bir gerçeği olmayacak, okunmamış sinyali okundu imleci ve
-- WP-436 rozet zinciri taşıyacak. Kanonik kaynak
-- `021_feedback_thread_single_truth`'tur ("admin replies no longer create a
-- second announcement truth"). Bu dosya hiç koşmadığı için iki sözleşme üç tur
-- boyunca yan yana durabildi; eski iddia yenisiyle değiştiriliyor.
select is(
  (select count(*) from public.announcements
    where related_feedback_ticket_id = '40000000-0000-0000-0000-000000000001'),
  0::bigint,
  'admin reply does not fork a second announcement truth for the same message'
);

select public.mark_feedback_ticket_messages_read(
  '40000000-0000-0000-0000-000000000001'
);
-- WP-473: `0103` bilet gövdesini konuşmanın kanonik ilk mesajı yaptı, yani
-- `sender_role = 'user'` artık **iki** satır döndürüyor ve skaler alt sorgu
-- "more than one row" ile patlıyordu. `bool_and` hem hatayı kaldırır hem de
-- iddiayı güçlendirir: kullanıcı mesajlarının **hepsi** okundu işaretlenmeli.
select ok(
  (select bool_and(read_at is not null) from public.feedback_ticket_messages
    where ticket_id = '40000000-0000-0000-0000-000000000001'
      and sender_role = 'user'),
  'admin opening the conversation marks every user message read'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is(
  (select count(*) from public.feedback_ticket_messages),
  3::bigint,
  'ticket owner can read the canonical initial message and both conversation sides'
);
select public.mark_feedback_ticket_messages_read(
  '40000000-0000-0000-0000-000000000001'
);
select ok(
  (select bool_and(read_at is not null) from public.feedback_ticket_messages
    where ticket_id = '40000000-0000-0000-0000-000000000001'
      and sender_role = 'admin'),
  'ticket owner opening the conversation marks the admin reply read'
);

reset role;
select * from finish();
rollback;
