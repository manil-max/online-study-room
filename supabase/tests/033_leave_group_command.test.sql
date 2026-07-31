-- 033_leave_group_command.test.sql
-- WP-445: gruptan çıkış idempotent, sahiplik değişmezi korunur, presence temizlenir.
--
-- Fixture: alpha grubun sahibi/admin'i, beta üyesi.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'
\set cmd1  '50000000-0000-0000-0000-000000000001'
\set cmd2  '50000000-0000-0000-0000-000000000002'
\set cmd3  '50000000-0000-0000-0000-000000000003'

-- Ayrılan üyenin kamp ateşinde asılı kalmadığını gösterebilmek için canlı
-- presence satırı bırakılır.
insert into public.group_live_presence (
  group_id, user_id, status, started_at, today_seconds,
  lease_expires_at, state_version
) values (
  :'grp'::uuid, :'beta'::uuid, 'studying', now(), 600,
  now() + interval '5 minutes', 1
) on conflict (group_id, user_id) do nothing;

select plan(11);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);

select is(
  public.leave_group(:'grp'::uuid, :'cmd1'::uuid),
  'left',
  'aktif üye gruptan çıkabilir'
);
-- 🔴 WP-473: bu iddia satırın **durduğunu** ölçüyor, çıkanın onu görebildiğini
-- değil. `members_select` politikası `is_group_member(group_id)` ister, o da
-- `left_at is null` şartına bağlıdır (`0008`) — yani çıkıştan sonra beta artık
-- hiçbir üyelik satırını göremez ve sorgu NULL döner. Eski hâl bu yüzden
-- kırmızıydı; üstelik satır gerçekten SİLİNMİŞ olsa da aynı NULL'ı görürdü,
-- yani soft-delete değişmezini hiç sınamıyordu.
reset role;
select isnt(
  (select left_at from public.group_members
   where group_id = :'grp' and user_id = :'beta'),
  null,
  'çıkış soft-delete: satır silinmez, left_at yazılır'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);
select is(
  (select count(*)::int from public.group_live_presence
   where group_id = :'grp' and user_id = :'beta'),
  0,
  'presence satırı aynı işlemde silinir: kamp ateşinde asılı kalmaz'
);
select is(
  (select public.is_group_member(:'grp'::uuid)),
  false,
  'ayrılan üye grup erişimini yitirir'
);

-- Aynı komut anahtarıyla tekrar: iş yeniden yapılmaz.
select is(
  public.leave_group(:'grp'::uuid, :'cmd1'::uuid),
  'left',
  'aynı komut anahtarı ilk sonucu aynen döndürür (idempotent)'
);
select is(
  (select count(*)::int from public.group_leave_commands
   where user_id = :'beta' and group_id = :'grp'),
  1,
  'tekrar eden çağrı ikinci komut satırı üretmez'
);

-- Yeni anahtarla gelen çevrimdışı retry: hata değil, alreadyLeft.
select is(
  public.leave_group(:'grp'::uuid, :'cmd2'::uuid),
  'already_left',
  'zaten çıkmış kullanıcı için sonuç already_left, hata değil'
);

-- Birincil grup uzlaşması aynı işlemde (0079 trigger'ı left_at UPDATE'inde).
select is(
  (select primary_group_id from public.user_group_preferences
   where user_id = :'beta'),
  null,
  'ayrılınca birincil grup tercihi sunucuda uzlaşır'
);

-- Sahiplik değişmezi.
select set_config('request.jwt.claim.sub', :'alpha', true);
select throws_ok(
  format($$select public.leave_group(%L::uuid, %L::uuid)$$, :'grp', :'cmd3'),
  'owner_must_transfer_or_delete',
  'grup sahibi çıkamaz: sahipsiz grup bırakılmaz'
);
select is(
  (select left_at from public.group_members
   where group_id = :'grp' and user_id = :'alpha'),
  null,
  'başarısız çıkış sahibin üyeliğine dokunmaz'
);

-- Başkasının komut anahtarı devralınamaz.
select throws_ok(
  format($$select public.leave_group(%L::uuid, %L::uuid)$$, :'grp', :'cmd1'),
  'leave_command_mismatch',
  'başka kullanıcının komut anahtarı kabul edilmez'
);

select * from finish();
rollback;
