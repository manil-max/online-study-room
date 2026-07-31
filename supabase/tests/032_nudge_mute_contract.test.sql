-- 032_nudge_mute_contract.test.sql
-- WP-444: susturma sözleşmesi ve yan kanal kapalılığı.
--
-- Fixture notu: `base_seed` yalnız alpha (grup sahibi/admin) ve beta üretir;
-- üçüncü kişi burada işlem-yerel eklenir. Alpha grup sahibi olduğu için
-- `send_nudge`'daki blok muafiyeti onun lehine açıktır — bu test aynı zamanda
-- muafiyetin susturmayı BYPASS ETMEDİĞİNİ kanıtlar.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set gamma '10000000-0000-0000-0000-000000000003'
\set grp   '20000000-0000-0000-0000-000000000001'

insert into auth.users (id, email, raw_user_meta_data)
values (:'gamma', 'fixture-gamma@example.invalid',
        '{"display_name":"Fixture Gamma"}'::jsonb)
on conflict (id) do nothing;

insert into public.group_members (group_id, user_id, role, joined_at)
values (:'grp'::uuid, :'gamma'::uuid, 'member', now() - interval '1 day')
on conflict (group_id, user_id) do nothing;

select plan(14);

-- alpha, beta'nın yalnız dürtmesini susturur.
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select lives_ok(
  $$select public.mute_nudges_from('10000000-0000-0000-0000-000000000002')$$,
  'kullanıcı bir kişinin yalnız dürtmesini susturabilir'
);
select lives_ok(
  $$select public.mute_nudges_from('10000000-0000-0000-0000-000000000002')$$,
  'aynı kişi için tekrar çağrı idempotenttir'
);
select is(
  (select count(*)::int from public.nudge_mutes where user_id = :'alpha'),
  1,
  'idempotent çağrı ikinci satır üretmez'
);
select throws_ok(
  $$select public.mute_nudges_from('10000000-0000-0000-0000-000000000001')$$,
  'cannot_mute_self',
  'kendini susturma reddedilir'
);
select is(
  (select count(*)::int from public.nudge_mute_directory()),
  1,
  'dizin yalnız çağıranın kendi tercihini döndürür'
);

-- beta dürtmeye çalışır: çağrı BAŞARILI görünür ama satır/outbox oluşmaz.
select set_config('request.jwt.claim.sub', :'beta', true);

select lives_ok(
  $$select public.send_nudge('20000000-0000-0000-0000-000000000001',
                             '10000000-0000-0000-0000-000000000001', 'hadi')$$,
  'susturulmuş gönderen için çağrı normal görünür (yan kanal yok)'
);
-- 🔴 WP-473: bu üç iddia yan kanalın **gerçekten** kapalı olduğunu iddia ediyor,
-- o yüzden ayrıcalıklı rolde okunmalıdır. `authenticated` altında:
--   * `notification_outbox` `0066`'dan beri tamamen kapalı → sert hata,
--   * `nudge_suppressed_attempts` politikasız (deny all) → 0 döner, iddia 1
--     beklediği için yanlış nedenle kırmızı,
--   * `nudges` RLS ile süzülür → 0 "satır yok"u değil "göremiyorum"u ölçer,
--     yani susturma bozulsa bile test yeşil kalırdı.
-- Rol geri yüklenirken kimlik **beta**'dır; sıradaki `send_nudge` cooldown
-- iddiası gönderenin kimliğine bağlıdır.
reset role;
select is(
  (select count(*)::int from public.nudges
   where sender_id = :'beta' and recipient_id = :'alpha'),
  0,
  'susturulmuş dürtme için nudges satırı yazılmaz'
);
select is(
  (select count(*)::int from public.notification_outbox
   where notification_type = 'nudge' and recipient_id = :'alpha'),
  0,
  'satır olmadığı için nudges_enqueue_push tetiklenmez, outbox boş kalır'
);
select is(
  (select count(*)::int from public.nudge_suppressed_attempts
   where sender_id = :'beta' and recipient_id = :'alpha'),
  1,
  'bastırılmış deneme cooldown paritesi için kaydedilir'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);
select throws_ok(
  $$select public.send_nudge('20000000-0000-0000-0000-000000000001',
                             '10000000-0000-0000-0000-000000000001', 'tekrar')$$,
  'nudge_cooldown',
  'ikinci deneme susturulmamış durumla AYNI cooldown hatasını alır'
);
select is(
  (select count(*)::int from public.nudge_mutes),
  0,
  'gönderen başkasının susturma tablosunu RLS ile okuyamaz'
);

-- gamma susturulmamıştır: normal akış bozulmaz.
select set_config('request.jwt.claim.sub', :'gamma', true);
select lives_ok(
  $$select public.send_nudge('20000000-0000-0000-0000-000000000001',
                             '10000000-0000-0000-0000-000000000001', 'selam')$$,
  'susturulmamış kişinin dürtmesi normal düşer'
);
-- Bu iddia satırın **yazıldığını** ölçüyor, gönderenin onu görebildiğini değil;
-- o yüzden RLS'in arkasından okunur (bkz. yukarıdaki WP-473 notu).
reset role;
select is(
  (select count(*)::int from public.nudges
   where sender_id = :'gamma' and recipient_id = :'alpha'),
  1,
  'susturma yalnız hedef göndereni etkiler'
);
set local role authenticated;

-- geri alma
select set_config('request.jwt.claim.sub', :'alpha', true);
select lives_ok(
  $$select public.unmute_nudges_from('10000000-0000-0000-0000-000000000002')$$,
  'susturma geri alınabilir ve idempotenttir'
);

select * from finish();
rollback;
