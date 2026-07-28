begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

-- WP-413: engelleme yaptırımı sunucuda ve iki yönlü.
-- Fixture: alpha (…0001, grup yöneticisi) ve beta (…0002, üye) aynı grupta,
-- ikisinin de bugün 1 saatlik oturumu var.
\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

-- Yerel seed profil adlarını kendi değerleriyle kuruyor; test kendi
-- beklentisini deterministik kılmak için adları sabitler.
update public.profiles set display_name = 'Wp Alpha' where id = :'alpha'::uuid;
update public.profiles set display_name = 'Wp Beta'  where id = :'beta'::uuid;

select plan(17);

-- ---------------------------------------------------------------------
-- Engel YOKKEN taban davranış (boş kümeyi yanlışlıkla "yaptırım" sanmayalım)
-- ---------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select ok(
  public.can_see_user_sessions(:'beta'::uuid),
  'engel yokken ortak grup üyesi görünür'
);
reset role;

insert into public.user_blocks (blocker_id, blocked_id)
values (:'alpha'::uuid, :'beta'::uuid)
on conflict do nothing;

-- ---------------------------------------------------------------------
-- A→B yönü: engelleyen taraf
-- ---------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select ok(
  not public.can_see_user_sessions(:'beta'::uuid),
  'engelleyen, engellediğinin sosyal görünürlüğünü kaybeder'
);

select is(
  (select count(*) from public.profiles where id = :'beta'::uuid),
  0::bigint,
  'engellenen kişinin profili doğrudan id ile bile okunamaz (A→B)'
);

select is(
  (
    select count(*)
    from public.group_contribution_breakdown(
      :'grp'::uuid,
      (timezone('Europe/Istanbul', now()))::date,
      (timezone('Europe/Istanbul', now()))::date
    ) r
    where r.user_id = :'beta'::uuid
  ),
  0::bigint,
  'katkı tablosunda engellenen kişi yok (A→B)'
);

select is(
  (
    select count(*)
    from public.group_leaderboard_series(
      :'grp'::uuid,
      (timezone('Europe/Istanbul', now()))::date,
      (timezone('Europe/Istanbul', now()))::date
    ) r
    where r.user_id = :'beta'::uuid
  ),
  0::bigint,
  'liderlik serisinde engellenen kişi yok (A→B)'
);

select is(
  (
    select count(*) from public.group_alpha_scores(:'grp'::uuid) r
    where r.user_id = :'beta'::uuid
  ),
  0::bigint,
  'alpha sıralamasında engellenen kişi yok (A→B)'
);

select is(
  (
    select count(*) from public.group_daily_totals(:'grp'::uuid) r
    where r.user_id = :'beta'::uuid
  ),
  0::bigint,
  'günlük grup toplamlarında engellenen kişinin oturumu yok (A→B)'
);

-- Engelleyen kendi verisini kaybetmez.
select ok(
  (
    select count(*) from public.group_daily_totals(:'grp'::uuid) r
    where r.user_id = :'alpha'::uuid
  ) > 0,
  'engelleyen kendi oturumunu görmeye devam eder'
);

-- 🔴 Kamp ateşi regresyon kilidi: satır SİLİNMEZ, kimlik boşalır.
-- Bu üç iddia ileride birinin "engelleneni tamamen gizle"ye çevirmesini durdurur.
select is(
  (select count(*) from public.group_member_directory(:'grp'::uuid)),
  2::bigint,
  'üye dizini engellenen üyeyi listeden silmez — katılımcı sayısı korunur'
);

select is(
  (
    select r.display_name || '|' || coalesce(r.avatar_url, 'NULL')
      || '|' || coalesce(r.animal, 'NULL') || '|' || r.is_blocked::text
    from public.group_member_directory(:'grp'::uuid) r
    where r.id = :'beta'::uuid
  ),
  '|NULL|NULL|true',
  'engellenen üyenin kimliği boşaltılır ve is_blocked işaretlenir (anonimleşir, gizlenmez)'
);

select is(
  (
    select r.display_name from public.group_member_directory(:'grp'::uuid) r
    where r.id = :'alpha'::uuid
  ),
  'Wp Alpha',
  'dizin fazladan maskeleme yapmaz — engellenmeyen üyenin adı korunur'
);

-- Yönetim ekranı: kullanıcı kimi engellediğini görebilmeli.
select is(
  (select count(*) from public.blocked_user_directory()),
  1::bigint,
  'engellenenler dizini yalnız çağıranın kendi engellerini döndürür'
);

select is(
  (select display_name from public.blocked_user_directory()),
  'Wp Beta',
  'engellenenler dizini gerçek adı gösterir (yönetim ekranı çalışır kalır)'
);

-- ---------------------------------------------------------------------
-- B→A yönü: engellenen taraf (yaptırım simetrik)
-- ---------------------------------------------------------------------
select set_config('request.jwt.claim.sub', :'beta', true);

select ok(
  not public.can_see_user_sessions(:'alpha'::uuid),
  'engellenen de engelleyeni göremez (simetrik)'
);

select is(
  (select count(*) from public.profiles where id = :'alpha'::uuid),
  0::bigint,
  'engellenen kişi engelleyenin profilini açamaz (B→A)'
);

select is(
  (
    select count(*)
    from public.group_contribution_breakdown(
      :'grp'::uuid,
      (timezone('Europe/Istanbul', now()))::date,
      (timezone('Europe/Istanbul', now()))::date
    ) r
    where r.user_id = :'alpha'::uuid
  ),
  0::bigint,
  'katkı tablosu B→A yönünde de süzülür'
);

select is(
  (select count(*) from public.blocked_user_directory()),
  0::bigint,
  'engellenen taraf kendisini engelleyeni bu dizinde görmez'
);

reset role;
select * from finish();
rollback;
