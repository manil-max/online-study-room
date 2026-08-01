-- 043_feedback_message_push.test.sql
-- WP-485: yönetici konuşmasında canlı yayın + push (migration 0117).
--
-- 🔴 Kart bu dosyayı `039_...` diye adlandırmıştı; 039–042 aradan geçen
-- WP'lerle dolduğu için sıradaki boş numara 043 alındı.
--
-- Ölçülen iki kök neden de yalnız gerçek veritabanında görünür:
--   1. `feedback_ticket_messages` `supabase_realtime` publication'ında mı;
--   2. mesaj insert'i KARŞI TARAF için outbox satırı doğuruyor mu, gönderen
--      için doğurmuyor mu.
--
-- Yön ayrımı testin özüdür: "bildirim düşüyor" demek yetmez, yanlış tarafa
-- düşen bildirim de bu iddiayı geçerdi.
--
-- 🔴 Mesajlar ÜRETİMDEKİ yoldan yazılıyor: bilet insert'i `0103` seed
-- tetikleyicisini, yanıtlar ise `send_feedback_ticket_message` RPC'sini
-- sürüyor. İlk yazımda mesaj satırı doğrudan insert ediliyordu ve CI bunu
-- `client_message_id` NOT NULL kısıtından yakaladı — o kolon `0074`te değil
-- `0103`te eklenmiş. Ham insert aynı zamanda `message_seq` sözleşmesini de
-- atlıyordu, yani test gerçek yazma yolunu hiç sınamıyordu.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set ticket '40000000-0000-0000-0000-000000000001'

select plan(9);

-- ===========================================================================
-- 1. Realtime yayını
-- ===========================================================================
select ok(
  exists(
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'feedback_ticket_messages'
  ),
  '0117 tabloyu supabase_realtime publication uyesi yapar'
);

-- Karşılaştırma: kardeş tablo zaten yayındaydı; asıl boşluk mesaj tablosuydu.
select ok(
  exists(
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'feedback_tickets'
  ),
  'feedback_tickets yayini korunuyor (0018)'
);

-- ===========================================================================
-- 2. Push tipi ve cihaz tercihi
-- ===========================================================================
select ok(
  (select pg_get_constraintdef(oid)
     from pg_constraint
    where conrelid = 'public.notification_outbox'::regclass
      and conname = 'notification_outbox_notification_type_check')
  like '%feedback_message%',
  'notification_outbox tip kisiti feedback_message kabul eder'
);

-- Eski gövde bilinmeyen tipte `invalid_push_notification_type` atardı ve
-- `claim_push_deliveries` her turda patlardı; yani tetikleyici tek başına
-- yetmezdi.
select ok(
  public._push_type_enabled(null::public.push_devices, 'feedback_message'),
  '_push_type_enabled yeni tipi taniyor ve istisna atmiyor'
);

-- ===========================================================================
-- 3. Tetikleyici: alici karsi taraftir
-- ===========================================================================
insert into public.app_admins (user_id) values (:'alpha')
on conflict (user_id) do nothing;

-- (a) Bilet acilisi: 0103 seed tetikleyicisi ilk kullanici mesajini yazar.
insert into public.feedback_tickets (id, user_id, kind, subject, message)
values (:'ticket', :'beta', 'bug', 'Fixture ticket', 'Bir sorun var');

select is(
  (select count(*)::integer from public.notification_outbox
    where notification_type = 'feedback_message' and recipient_id = :'alpha'),
  1,
  'kullanici mesaji yoneticiye outbox satiri dogurur'
);
select is(
  (select count(*)::integer from public.notification_outbox
    where notification_type = 'feedback_message' and recipient_id = :'beta'),
  0,
  'gonderen kendi mesajinin push`unu almaz'
);

-- (b) Yonetici yaniti: uretimdeki RPC yolu.
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select lives_ok(
  $$select public.send_feedback_ticket_message(
      '40000000-0000-0000-0000-000000000001',
      'Bakiyoruz, tesekkurler',
      '50000000-0000-0000-0000-000000000001'
    )$$,
  'yonetici RPC ile yanit yazabilir'
);
reset role;

select is(
  (select count(*)::integer from public.notification_outbox
    where notification_type = 'feedback_message' and recipient_id = :'beta'),
  1,
  'yonetici mesaji bilet sahibine outbox satiri dogurur'
);
select is(
  (select count(*)::integer from public.notification_outbox
    where notification_type = 'feedback_message' and recipient_id = :'alpha'),
  1,
  'yonetici kendi mesajindan ikinci bir bildirim almaz'
);

-- Yuk: dispatch-push genel dalindan okunacak alanlar dolu olmali, aksi halde
-- kullanici basliksiz/govdesiz bir bildirim gorur.
select ok(
  (select payload ? 'title'
      and payload ? 'body'
      and payload->>'route' = 'feedback_ticket'
     from public.notification_outbox
    where notification_type = 'feedback_message' and recipient_id = :'beta'
    limit 1),
  'yuk baslik, govde ve rota tasiyor'
);

select * from finish();
rollback;
