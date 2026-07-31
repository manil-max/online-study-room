-- 040_pseudonymous_actor_retention.test.sql
-- WP-464 Faz 2: sahip karari "takma kimlikle korunsun, set null + hash".
--
-- `0114` oncesi `public` -> `auth.users` arasindaki YEDI `not null` +
-- `on delete restrict` FK `auth.admin.deleteUser`'i FK ihlaliyle dusuruyordu;
-- yani `0113` zamanlayiciyi baglasa bile bu hesaplar HIC silinemiyordu.
-- Bu dosya iki seyi birlikte kanitlar: (a) blokaj kalkti, (b) kanit kaybolmadi.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'

-- Silinecek aktor: BASKASININ biletine yanit vermis bir kullanici.
-- 🔴 Senaryo bilerek boyle: bilet SAHIBI silinince `feedback_tickets.user_id`
-- zaten `on delete cascade` oldugu icin bilet ve mesajlari komple gider (bu
-- dogrudur, kendi icerigidir). Takma kimligin korunmasinin gorulebildigi tek
-- yer, aktor ile bilet sahibinin FARKLI olmasidir.
insert into auth.users (id, email, raw_user_meta_data)
values ('10000000-0000-0000-0000-0000000000e1', 'fixture-e1@example.invalid', '{}'::jsonb)
on conflict (id) do nothing;

\set epsilon '10000000-0000-0000-0000-0000000000e1'

select plan(12);

-- ===========================================================================
-- 1. Takma kimlik uretici
-- ===========================================================================
select is(
  char_length(public.pseudonymous_user_hash(:'alpha')),
  64,
  'takma kimlik 64 haneli sha256 hex'
);
select is(
  public.pseudonymous_user_hash(:'alpha'),
  public.pseudonymous_user_hash(:'alpha'),
  'ayni uid ayni takma kimligi uretir (deterministik)'
);
select isnt(
  public.pseudonymous_user_hash(:'alpha'),
  public.pseudonymous_user_hash(:'epsilon'),
  'farkli uid farkli takma kimlik uretir'
);

-- `0113`teki denetim izi ayni insayi satir ici kullaniyor. Ikisi ayrisirsa
-- "bu hesap silindi mi" ile "bu yaptirimi kim verdi" eslesemez hale gelir.
select lives_ok(
  format(
    $$select public.record_account_purge_outcome(null, %L, 'completed')$$,
    :'epsilon'
  ),
  'denetim izi yazilabilir'
);
select is(
  (select user_hash from public.account_purge_audit limit 1),
  public.pseudonymous_user_hash(:'epsilon'),
  '0113 denetim izi ile 0114 takma kimligi AYNI insayi kullanir'
);

-- ===========================================================================
-- 2. Blokaj kalkti
-- ===========================================================================
select is(
  (select count(*)::int
   from pg_constraint c
   join pg_class t on t.oid = c.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   where c.contype = 'f' and c.confdeltype = 'r'
     and c.confrelid = 'auth.users'::regclass and n.nspname = 'public'),
  0,
  'auth.users silmeyi blokleyen restrict FK KALMADI'
);
select is(
  (select count(*)::int
   from pg_constraint c
   join pg_class t on t.oid = c.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   where c.contype = 'f' and c.confdeltype = 'n'
     and c.confrelid = 'auth.users'::regclass and n.nspname = 'public'
     and t.relname in (
       'admin_audit_logs', 'announcements', 'feedback_ticket_notes',
       'feedback_ticket_messages', 'group_bans', 'moderation_name_resets',
       'moderation_sanctions')),
  7,
  'yedi tablonun tamami artik on delete set null'
);

-- ===========================================================================
-- 3. Kanit atfedilebilir kalir
-- ===========================================================================
-- Hash sutunlari zorunlu: kimlik gitse bile satir "kim yapti" sorusunu
-- takma kimlikle cevaplayabilmeli.
select is(
  (select count(*)::int
   from information_schema.columns
   where table_schema = 'public' and is_nullable = 'NO'
     and (table_name, column_name) in (
       ('admin_audit_logs', 'admin_hash'),
       ('announcements', 'created_by_hash'),
       ('feedback_ticket_notes', 'admin_hash'),
       ('feedback_ticket_messages', 'sender_hash'),
       ('group_bans', 'banned_by_hash'),
       ('moderation_name_resets', 'reset_by_hash'),
       ('moderation_sanctions', 'actor_hash'))),
  7,
  'yedi takma kimlik sutununun tamami not null'
);

-- ===========================================================================
-- 4. Uctan uca: aktor silinir, kanit kalir
-- ===========================================================================
insert into public.feedback_tickets (id, user_id, kind, subject, message)
values ('50000000-0000-0000-0000-000000000001', :'alpha', 'feedback',
        'fixture konu', 'fixture govde');

-- Mesaji BILET SAHIBI DEGIL epsilon yaziyor (admin yaniti).
insert into public.feedback_ticket_messages
  (id, ticket_id, sender_id, sender_role, message, client_message_id, message_seq)
values ('51000000-0000-0000-0000-000000000001',
        '50000000-0000-0000-0000-000000000001', :'epsilon', 'admin',
        'fixture yanit', '52000000-0000-0000-0000-000000000001', 1);

select is(
  (select sender_hash from public.feedback_ticket_messages
   where id = '51000000-0000-0000-0000-000000000001'),
  public.pseudonymous_user_hash(:'epsilon'),
  'tetikleyici takma kimligi insert aninda doldurur'
);

-- 🔴 Asil sinav: 0114 oncesi bu ifade FK ihlaliyle PATLARDI.
delete from auth.users where id = :'epsilon';

select is(
  (select count(*)::int from public.feedback_ticket_messages
   where id = '51000000-0000-0000-0000-000000000001'),
  1,
  'aktor silinince kanit satiri KALIR (cascade ile gitmez)'
);
select ok(
  (select sender_id is null from public.feedback_ticket_messages
   where id = '51000000-0000-0000-0000-000000000001'),
  'ham kimlik NULL olur'
);
-- `on delete set null` satiri UPDATE eder ve tetikleyiciyi atesler; tetikleyici
-- hash'i EZMEMELI. Bu iddia tam olarak o riski olcer.
select is(
  (select sender_hash from public.feedback_ticket_messages
   where id = '51000000-0000-0000-0000-000000000001'),
  public.pseudonymous_user_hash(:'epsilon'),
  'takma kimlik silme sonrasi DEGISMEDEN durur (tetikleyici ezmez)'
);

select * from finish();
rollback;
