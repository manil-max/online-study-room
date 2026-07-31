-- 036_group_departure_matrix.test.sql
-- WP-447: grup yaris kosulu ve guvenlik kabul matrisinin SUNUCU ucu.
--
-- Dart esi: `app/test/data/group_race_matrix_wp447_test.dart`.
-- Kartin dort kabul kriteri: duplicate mutation 0, gecikmis "sonradan cikmis"
-- gorunum 0, muted nudge bypass 0, kavramlar arasi istenmeyen yan etki 0.
--
-- Bu dosyanin merkezinde `0111` var: ayrilmanin degismezleri artik yazma
-- YOLUNDAN BAGIMSIZ. Onceki durumda `leave_group` RPC'si sahibi reddediyordu
-- ama `members_update_self` politikasi (`0008`) ayni satira dogrudan UPDATE
-- edilmesine izin veriyordu; yani her degismez tek kapida bekliyordu, oteki
-- kapi ardina kadar acikti.
--
-- pgTAP arity notu (WP-473 dersi): 4 argumanli `throws_ok` ikinci argumani
-- `char(5)` alir, yani SQLSTATE. Mesaj bekleyen iddialar 3 argumanli bicimi
-- kullanir; orada arg2 mesaj, arg3 aciklamadir.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set gamma '10000000-0000-0000-0000-000000000003'
\set grp   '20000000-0000-0000-0000-000000000001'
\set grp2  '20000000-0000-0000-0000-000000000002'
\set cmd1  '60000000-0000-0000-0000-000000000001'
\set cmd2  '60000000-0000-0000-0000-000000000002'

-- Ucuncu bir hesap ve ikinci bir grup: "susturma hesap kapsamli mi, grup
-- kapsamli mi" ve "yonetici baskasini cikarabiliyor mu" sorulari ancak ayri
-- bir ucuncu taraf varken bos dusmeden olculebilir.
insert into auth.users (id, email, raw_user_meta_data)
values (
  :'gamma', 'fixture-gamma@example.invalid',
  '{"display_name":"Fixture Gamma"}'::jsonb
) on conflict (id) do nothing;

insert into public.groups (id, name, invite_code, created_by, created_at)
values (:'grp2', 'Matris Ikinci Grup', 'FIXTUR2', :'beta'::uuid, now())
on conflict (id) do nothing;

insert into public.group_members (group_id, user_id, role, joined_at)
values
  (:'grp'::uuid,  :'gamma'::uuid, 'member', now() - interval '1 day'),
  (:'grp2'::uuid, :'beta'::uuid,  'admin',  now() - interval '1 day'),
  (:'grp2'::uuid, :'gamma'::uuid, 'member', now() - interval '1 day')
on conflict (group_id, user_id) do nothing;

select plan(26);

-- ===========================================================================
-- 1) 0111 kurulumu gercekten yerinde mi
-- ===========================================================================
select ok(
  exists (
    select 1 from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'group_members'
      and t.tgname = 'group_members_departure_guard'
      and not t.tgisinternal
  ),
  '0111 group_members uzerine cikis muhafizini kurar'
);

-- Kapi TEK imzali kalmali: PostgREST asiri yuklemede `42725` verir ve adli
-- parametreyle yapilan RPC cagrisi patlar (WP-472 dersi).
select is(
  (select count(*)::int from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'leave_group'),
  1,
  'leave_group tek imzali kalir'
);

-- ===========================================================================
-- 2) Sahiplik degismezi: HER yoldan
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select throws_ok(
  format($$select public.leave_group(%L::uuid, %L::uuid)$$, :'grp', :'cmd1'),
  'owner_must_transfer_or_delete',
  'RPC yolu: grup sahibi cikamaz'
);

-- Ayni sahip, ayni satir, DOGRUDAN UPDATE. `members_update_self` politikasi
-- `user_id = auth.uid()` dedigi icin RLS bu yazmayi gecirir; degismezi ayakta
-- tutan tek sey `0111` trigger'idir.
select throws_ok(
  format(
    $$update public.group_members set left_at = now()
      where group_id = %L and user_id = %L$$,
    :'grp', :'alpha'
  ),
  '23514',
  null,
  'dogrudan UPDATE yolu: grup sahibi cikamaz (0111)'
);

select throws_ok(
  format($$select public.ban_group_member(%L::uuid, %L::uuid)$$, :'grp', :'alpha'),
  'cannot_ban_self',
  'ban yolu: sahip kendini yasaklayamaz'
);

reset role;
select is(
  (select left_at from public.group_members
   where group_id = :'grp' and user_id = :'alpha'),
  null,
  'basarisiz cikis denemeleri sahibin uyeligine dokunmaz'
);
select ok(
  exists (select 1 from public.groups g
          join public.group_members m
            on m.group_id = g.id and m.user_id = g.created_by
          where g.id = :'grp' and m.left_at is null),
  'grup sahipsiz kalmaz: created_by hala aktif uye'
);

-- ===========================================================================
-- 3) Kendi cikisin tek kapisi: leave_group RPC
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'gamma', true);

select throws_ok(
  format(
    $$update public.group_members set left_at = now()
      where group_id = %L and user_id = %L$$,
    :'grp', :'gamma'
  ),
  '23514',
  null,
  'uye kendi left_at satirini dogrudan yazamaz: RPC atlanmaz (0111)'
);

reset role;
select is(
  (select left_at from public.group_members
   where group_id = :'grp' and user_id = :'gamma'),
  null,
  'reddedilen dogrudan UPDATE uyeligi degistirmez'
);

-- RPC yolu ise calisir: kapi kapali degil, TEK.
set local role authenticated;
select set_config('request.jwt.claim.sub', :'gamma', true);
select is(
  public.leave_group(:'grp'::uuid, :'cmd1'::uuid),
  'left',
  'RPC yolu acik kalir: mesru cikis engellenmez'
);

-- ===========================================================================
-- 4) Duplicate mutation 0 / gecikmis gorunum 0
-- ===========================================================================
select is(
  public.leave_group(:'grp'::uuid, :'cmd1'::uuid),
  'left',
  'ayni anahtarla tekrar: ilk sonuc doner (20x tap tek mutasyon)'
);
select is(
  public.leave_group(:'grp'::uuid, :'cmd2'::uuid),
  'already_left',
  'ikinci cihazin gec gelen cikisi sahte hata degil, already_left'
);
reset role;
select is(
  (select count(*)::int from public.group_members
   where group_id = :'grp' and user_id = :'gamma' and left_at is not null),
  1,
  'tekrar eden cagrilar tek uyelik satirini tek kez kapatir'
);

-- ===========================================================================
-- 5) Yonetici BASKASINI cikarabilir: muhafiz mesru kick'i bozmaz
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select lives_ok(
  format(
    $$update public.group_members set left_at = now()
      where group_id = %L and user_id = %L$$,
    :'grp', :'beta'
  ),
  'yonetici baskasini cikarabilir: 0111 kick yolunu kapatmaz'
);
reset role;
select isnt(
  (select left_at from public.group_members
   where group_id = :'grp' and user_id = :'beta'),
  null,
  'kick soft-delete olarak yazilir'
);

-- Yeniden katilim (`left_at` -> null) muhafizin konusu degil.
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select lives_ok(
  format(
    $$update public.group_members set left_at = null
      where group_id = %L and user_id = %L$$,
    :'grp', :'beta'
  ),
  'yeniden katilim serbest: muhafiz yalniz cikis gecisini denetler'
);

-- ===========================================================================
-- 6) Kavramlar arasi yan etki 0
-- ===========================================================================
select lives_ok(
  format($$select public.ban_group_member(%L::uuid, %L::uuid)$$, :'grp', :'beta'),
  'yonetici uyeyi gruptan yasaklayabilir'
);

reset role;
select is(
  (select count(*)::int from public.group_bans
   where group_id = :'grp' and user_id = :'beta'),
  1,
  'grup yasagi grup kapsamli satir yazar'
);
-- Grup yasagi HESAP kapsamli engelleme degildir: `user_blocks` bos kalmali.
select is(
  (select count(*)::int from public.user_blocks
   where blocker_id = :'alpha' and blocked_id = :'beta'),
  0,
  'grup yasagi kisisel engelleme YARATMAZ'
);
select is(
  (select count(*)::int from public.nudge_mutes
   where user_id = :'alpha' and muted_sender_id = :'beta'),
  0,
  'grup yasagi durtme susturmasi YARATMAZ'
);
-- Yasak yalniz o gruba ait: beta kendi ikinci grubunda aktif kalir.
select is(
  (select count(*)::int from public.group_members
   where group_id = :'grp2' and user_id = :'beta' and left_at is null),
  1,
  'bir gruptaki yasak digerindeki uyeligi dusurmez'
);

-- ===========================================================================
-- 7) Muted nudge bypass 0
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select lives_ok(
  format($$select public.mute_nudges_from(%L::uuid)$$, :'gamma'),
  'kullanici bir kisinin durtmelerini susturabilir'
);

reset role;
-- Susturma HESAP kapsamli: satir gruba bagli degil, yani ikinci grup
-- uzerinden sizacak bir yol yok.
select is(
  (select count(*)::int from information_schema.columns
   where table_schema = 'public' and table_name = 'nudge_mutes'
     and column_name = 'group_id'),
  0,
  'nudge_mutes grup kapsamli degil: ikinci gruptan bypass edilemez'
);
select is(
  (select count(*)::int from public.nudge_mutes
   where user_id = :'alpha' and muted_sender_id = :'gamma'),
  1,
  'susturma tercihi gercekten yazildi (yukaridaki iddia bos dusmesin)'
);
select is(
  (select count(*)::int from public.group_members
   where group_id = :'grp2' and user_id = :'gamma' and left_at is null),
  1,
  'susturma uyeligi dusurmez: susturma engelleme degildir'
);
select is(
  (select count(*)::int from public.user_blocks
   where blocker_id = :'alpha' and blocked_id = :'gamma'),
  0,
  'durtme susturmasi kisisel engelleme YARATMAZ'
);

select * from finish();
rollback;
