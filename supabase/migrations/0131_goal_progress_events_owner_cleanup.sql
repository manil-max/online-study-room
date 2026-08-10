-- 0131_goal_progress_events_owner_cleanup.sql
--
-- Hesap (ve grup) silinince `goal_progress_events` satirlari VERITABANINDA
-- KALIYORDU.
--
-- ===========================================================================
-- OLCULEN DURUM -- koddan, karttan degil
-- ===========================================================================
-- `0112:27-41` tabloyu su sutunlarla kurar:
--
--     scope_type  text not null check (scope_type in ('personal','group')),
--     scope_id    uuid not null,
--
-- `scope_id` uzerinde HICBIR yabanci anahtar yok. Silme yollarinda da tablo
-- adi hic gecmiyor: `0113`, `0114`, `0124` ve
-- `supabase/functions/purge-accounts/index.ts` (562 satirin tamami) taranmis
-- durumda -- `goal_progress_events` sifir kez geciyor. Yani
-- `auth.admin.deleteUser` cascade'i bu tabloya HIC ulasmiyor ve silinen
-- hesabin tamamlama olaylari kaliciydi.
--
-- ===========================================================================
-- 🔴 NEDEN "scope_id'ye FK EKLE" YANLIS BIR DUZELTMEDIR
-- ===========================================================================
-- `scope_id` COK BICIMLI: `scope_type = 'personal'` iken `auth.uid()`,
-- `scope_type = 'group'` iken `groups.id` tasir (`0120:117`). `auth.users`'a
-- tek bir FK eklemek grup satirlarinin HEPSINI ihlal ederdi ve migration
-- apply aninda 23503 ile duserdi. PostgreSQL'de kismi (`where`li) yabanci
-- anahtar YOKTUR. Bu yuzden cozum FK degil, sahibi giden satiri dusuren
-- tetikleyicidir.
--
-- ===========================================================================
-- 🔴 HESAP SILME TUZAGI (`0124` / WP-549 sinifi)
-- ===========================================================================
-- Bu depoda hesap silme tam bu sinifta bir kez tamamen bloke oldu: yedi
-- `restrict` FK ve `study_sessions` uzerindeki yaz-geri tetikleyicileri
-- `delete from auth.users`'i 23503 ile dusurmustu. Buradaki tetikleyiciler o
-- tuzaga giremez, cunku:
--
--   * hicbir sey YAZMIYOR -- yalnizca `delete` calistiriyorlar; 23503 bir
--     INSERT/UPDATE kontroludur (`0124:365`),
--   * `goal_progress_events`'e isaret eden HICBIR FK yok, yani bu silme
--     baska bir zincire dokunmuyor.
--
-- Yine de "varsayma, olc" kurali geregi `supabase/tests/057` `delete from
-- auth.users`in HALA calistigini `lives_ok` ile ayrica iddia eder.
--
-- ===========================================================================
-- NEDEN `auth.users` DEGIL `public.profiles`
-- ===========================================================================
-- `profiles.id` tam olarak kisisel kapsamin `scope_id`'sidir ve
-- `references auth.users (id) on delete cascade` (`0001:16`) ile bagladir --
-- yani hesap silindiginde bu satir GARANTILI gider. Tetikleyiciyi `public`
-- semasinda tutmak `auth` semasi sahipligine hic dokunmadan ayni kapsami
-- verir. (`0001:98` `auth.users` uzerinde tetikleyici kurabiliyor; burada o
-- riske girmeye gerek yok.)
--
-- Kapi: profil satiri kullanicidan BAGIMSIZ silinirse (bugun boyle bir yol
-- yok) yasayan bir hesabin serisi yanmamali. Bu yuzden tetikleyici once
-- hesabin gercekten gittigini dogrular. `delete from auth.users` cascade'i
-- sirasinda `auth.users` satiri ZATEN gitmis olur -- `_account_still_exists`
-- (`0124:400`) tam bu gorunurluge dayanir ve `tests/052` onu olcer.
--
-- Geri alma (Rollback):
--   drop trigger if exists profiles_purge_goal_progress_events
--     on public.profiles;
--   drop trigger if exists groups_purge_goal_progress_events
--     on public.groups;
--   drop function if exists public._purge_goal_progress_events_for_profile();
--   drop function if exists public._purge_goal_progress_events_for_group();
--   drop function if exists public.purge_orphan_goal_progress_events();
--   drop function if exists public._purge_orphan_goal_progress_events();
--   -- Dusurulmus satirlar geri gelmez; zaten sahipsizdiler.

-- ---------------------------------------------------------------------
-- 1) Kisisel kapsam: profil gidince olaylar da gider
-- ---------------------------------------------------------------------
create or replace function public._purge_goal_progress_events_for_profile()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $wp657$
begin
  -- 🔴 Yalniz hesap GERCEKTEN gittiginde. Profil satirinin tek basina
  -- silindigi bir yol bugun yok; olsaydi yasayan kullanicinin serisini
  -- yakmak, sahipsiz satir birakmaktan agir olurdu.
  if exists (select 1 from auth.users u where u.id = old.id) then
    return old;
  end if;

  delete from public.goal_progress_events e
   where e.scope_type = 'personal'
     and e.scope_id = old.id;

  return old;
end;
$wp657$;

revoke all on function public._purge_goal_progress_events_for_profile()
  from public, anon, authenticated;

drop trigger if exists profiles_purge_goal_progress_events on public.profiles;
create trigger profiles_purge_goal_progress_events
  after delete on public.profiles
  for each row
  execute function public._purge_goal_progress_events_for_profile();

-- ---------------------------------------------------------------------
-- 2) Grup kapsami: grup gidince grup olaylari da gider
-- ---------------------------------------------------------------------
-- Bu dal teorik degil: purge, aktif uyesi kalmayan grubu GERCEKTEN siler
-- (`purge-accounts/index.ts:384`) ve `groups.created_by -> auth.users`
-- cascade'i (`0001:27`) ayni sonucu bir baska yoldan uretir. Iki yolda da
-- `goal_progress_events`'in grup satirlari bugune kadar yerinde kaliyordu.
create or replace function public._purge_goal_progress_events_for_group()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $wp657$
begin
  delete from public.goal_progress_events e
   where e.scope_type = 'group'
     and e.scope_id = old.id;
  return old;
end;
$wp657$;

revoke all on function public._purge_goal_progress_events_for_group()
  from public, anon, authenticated;

drop trigger if exists groups_purge_goal_progress_events on public.groups;
create trigger groups_purge_goal_progress_events
  after delete on public.groups
  for each row
  execute function public._purge_goal_progress_events_for_group();

-- ---------------------------------------------------------------------
-- 3) GECMIS: zaten sahipsiz kalmis satirlar
-- ---------------------------------------------------------------------
-- Tetikleyiciler bugunden sonrasini kapatir. Tablo `0112`den (v58) beri
-- yaziyor ve o gunden bu yana silinen her hesabin/grubun satirlari duruyor.
--
-- 🔴 Olcut YORUM ICERMEZ: satirin sahibi ya vardir ya yoktur. `0129`daki
-- "dar olcut" tartismasi burada yasanmaz -- burada hedef degeri, saat dilimi
-- veya uyelik yorumlanmiyor.
create or replace function public._purge_orphan_goal_progress_events()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $wp657$
declare
  v_removed integer := 0;
begin
  with orphan as (
    delete from public.goal_progress_events e
     where case e.scope_type
       when 'personal' then
         not exists (select 1 from auth.users u where u.id = e.scope_id)
       when 'group' then
         not exists (select 1 from public.groups g where g.id = e.scope_id)
       else false
     end
    returning 1
  )
  select count(*)::integer into v_removed from orphan;

  return v_removed;
end;
$wp657$;

revoke all on function public._purge_orphan_goal_progress_events()
  from public, anon, authenticated;

-- Genel kapi: `0129`daki `repair_orphan_goal_completions` ile ayni sozlesme.
create or replace function public.purge_orphan_goal_progress_events()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $wp657$
begin
  if auth.role() is distinct from 'service_role'
     and current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  return public._purge_orphan_goal_progress_events();
end;
$wp657$;

comment on function public.purge_orphan_goal_progress_events() is
  'WP-657: sahibi (hesap ya da grup) artik var olmayan hedef tamamlama '
  'olaylarini dusurur. Olcut yorum icermez: sahip ya vardir ya yoktur.';

revoke all on function public.purge_orphan_goal_progress_events()
  from public, anon, authenticated;
grant execute on function public.purge_orphan_goal_progress_events()
  to service_role;

-- 🔴 Burada CAGRILIR. `0120:23` backfill'i bilerek cagirmiyordu cunku o EKLEME
-- yapar ve hatali ekleme seri sisirir. Bu fonksiyon yalnizca sahipsiz satiri
-- dusurur; ertelenmesi silinmis hesaplarin verisini saklamaya devam etmek
-- demekti (saklama karari: `docs/HESAP-SILME-RETENTION-KARARI.md`).
do $wp657$
declare
  v_removed integer;
begin
  v_removed := public._purge_orphan_goal_progress_events();
  raise notice 'WP-657 temizlik: % sahipsiz hedef olayi dusuruldu', v_removed;
end $wp657$;

notify pgrst, 'reload schema';
