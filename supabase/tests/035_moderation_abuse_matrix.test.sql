-- 035_moderation_abuse_matrix.test.sql
-- WP-443: Moderasyon abuse, RLS ve uctan uca kabul kapisi.
--
-- 026-031 tek tek ozellikleri kilitliyor. Bu dosya kartin matrisini kapatir:
-- profil raporu, engel muafiyeti, silinmis icerik, coklu raporlayan riski,
-- yaptirim suresi, kotu niyetli raporlayan, iki admin yarisi ve normal
-- kullanicinin admin RPC yuzeyini supurmesi.
--
-- Kabul: RLS kacisi 0, kayip audit 0, ayni eylemde cift yaptirim 0.
--
-- Rol disiplini: admin RPC'leri `security definer` ve `is_super_admin()`
-- istiyor, yani `authenticated` rolunde cagrilir. `moderation_sanctions`
-- yazma yolu, `ugc_reports.canonical_snapshot` ve `admin_audit_logs` istemciye
-- kapali oldugu icin dogrulamalar `reset role` ile ayricalikli rolde okunur.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set gamma '10000000-0000-0000-0000-000000000003'
\set delta '10000000-0000-0000-0000-000000000004'
\set grp   '20000000-0000-0000-0000-000000000001'
\set msg   '40000000-0000-0000-0000-000000000030'

insert into auth.users (id, email, raw_user_meta_data)
values
  (:'gamma', 'matrix-gamma@example.invalid', '{"display_name":"Matrix Gamma"}'::jsonb),
  (:'delta', 'matrix-delta@example.invalid', '{"display_name":"Matrix Delta"}'::jsonb)
on conflict (id) do nothing;

insert into public.group_members (group_id, user_id, role, joined_at)
values
  (:'grp'::uuid, :'gamma'::uuid, 'member', now() - interval '1 day'),
  (:'grp'::uuid, :'delta'::uuid, 'member', now() - interval '1 day')
on conflict (group_id, user_id) do nothing;

insert into public.class_messages (id, group_id, user_id, body)
values (:'msg'::uuid, :'grp'::uuid, :'beta'::uuid, 'Silinecek kanit metni')
on conflict (id) do nothing;

-- alpha ve gamma yonetici; iki admin yarisi icin ikisi de gerekli.
-- delta BILEREK yonetici degildir: 8. bolumdeki RLS supurmesi onun kimligiyle
-- kosar.
insert into public.app_admins (user_id)
values (:'alpha'::uuid), (:'gamma'::uuid)
on conflict (user_id) do nothing;

select plan(29);

-- ===========================================================================
-- 1) Hedef turu: profil raporu (026-031'de hic kosulmadi)
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'delta', true);

select lives_ok(
  $$select public.report_ugc(
      'user', '10000000-0000-0000-0000-000000000002', 'abuse')$$,
  'profil raporu acilir ve `user` turu `profile` olarak normalize edilir'
);
reset role;
select is(
  (select count(*)::int from public.moderation_cases
   where target_type = 'profile'
     and target_id = '10000000-0000-0000-0000-000000000002'
     and status = 'open'),
  1,
  'profil raporu profile turunde tek acik vaka acar'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', :'delta', true);

select throws_ok(
  $$select public.report_ugc(
      'user', '10000000-0000-0000-0000-000000000004', 'abuse')$$,
  '42501', 'report_target_not_visible',
  'kisi kendini raporlayamaz'
);
select throws_ok(
  $$select public.report_ugc(
      'user', '10000000-0000-0000-0000-000000000002', 'abuse', null, null, null,
      '20000000-0000-0000-0000-000000000001')$$,
  'P0001', 'unexpected_context_group',
  'profil raporu baglam grubu kabul etmez'
);

-- ===========================================================================
-- 2) 🔴 Engel muafiyeti — WP-443 abuse matrisinin buldugu gercek acik
--
-- `can_see_user_sessions` `0095`ten beri `is_blocked_pair` icerir ve engel
-- SIMETRIKTIR. Rapor yolu ona bagliyken taciz eden kisi kurbanini engellediginde
-- kendi profilini/adini raporlanamaz yapiyordu; ustelik engellemenin en olasi
-- sebebi tam da bu tur bir ihlaldir. `0110` gorunurluk kapisini engelden ayirdi.
-- ===========================================================================
select set_config('request.jwt.claim.sub', :'beta', true);
select lives_ok(
  $$select public.block_user('10000000-0000-0000-0000-000000000003')$$,
  'taciz eden kisi kurbanini engelleyebilir (engelleme kaldirilmadi)'
);

select set_config('request.jwt.claim.sub', :'gamma', true);
select lives_ok(
  $$select public.report_ugc(
      'user', '10000000-0000-0000-0000-000000000002', 'hate')$$,
  'engellenen kullanici engelleyenin profilini YINE DE raporlayabilir'
);
-- Duzeltmenin kapsami dar tutuldu: rapor hakki acildi diye sosyal gorunurluk
-- kapisi gevsetilmedi.
select ok(
  not public.can_see_user_sessions('10000000-0000-0000-0000-000000000002'),
  'engel sosyal gorunurlugu kesmeye devam eder (can_see_user_sessions bozulmadi)'
);

-- ===========================================================================
-- 3) Coklu raporlayan → yuksek risk (030 yalnizca icerik turu dalini surdu)
-- ===========================================================================
select set_config('request.jwt.claim.sub', :'alpha', true);
select public.report_ugc(
  'message', '40000000-0000-0000-0000-000000000030', 'spam', null, null, null,
  '20000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub', :'gamma', true);
select public.report_ugc(
  'message', '40000000-0000-0000-0000-000000000030', 'spam', null, null, null,
  '20000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub', :'delta', true);
select public.report_ugc(
  'message', '40000000-0000-0000-0000-000000000030', 'spam', null, null, null,
  '20000000-0000-0000-0000-000000000001');

reset role;
select is(
  (select severity from public.moderation_cases
   where target_type = 'message'
     and target_id = '40000000-0000-0000-0000-000000000030'
     and status in ('open', 'in_review')),
  'high',
  'uc ayri raporlayan vakayi yuksek riske tasir (icerik turunden bagimsiz dal)'
);
select ok(
  (select sla_due_at <= opened_at + interval '4 hours' from public.moderation_cases
   where target_type = 'message'
     and target_id = '40000000-0000-0000-0000-000000000030'
     and status in ('open', 'in_review')),
  'yuksek risk SLA penceresini 4 saate ceker'
);

-- ===========================================================================
-- 4) Silinmis icerik — kanit raporla birlikte yok olmaz
-- ===========================================================================
delete from public.class_messages where id = :'msg'::uuid;

select is(
  (select count(*)::int from public.ugc_reports
   where target_type = 'message' and target_id = '40000000-0000-0000-0000-000000000030'),
  3,
  'hedef mesaj silinince raporlar dusmez'
);
select is(
  (select distinct canonical_snapshot->>'body' from public.ugc_reports
   where target_type = 'message' and target_id = '40000000-0000-0000-0000-000000000030'),
  'Silinecek kanit metni',
  'sunucunun kanit govdesi icerik silinse de okunabilir kalir'
);

-- ===========================================================================
-- 5) Yaptirim suresi — dolmus kisit yeni yaptirimin onunde durmaz
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select (public.admin_begin_moderation_sanction(
  '10000000-0000-0000-0000-000000000002', 'mute_24h', 'ilk susturma',
  'wp443-mute-key-0001')).id as mute_id \gset
select public.admin_finish_moderation_sanction(:'mute_id'::uuid, true);

select ok(
  public.moderation_is_muted('10000000-0000-0000-0000-000000000002'),
  'uygulanan susturma etkindir'
);

-- Sureyi gecmise cek: `moderation_sanctions`a istemci yazamaz (grant/policy
-- yok), guncelleme ayricalikli rolde yapilir.
reset role;
update public.moderation_sanctions
set expires_at = now() - interval '1 hour'
where idempotency_key = 'wp443-mute-key-0001';

select ok(
  not public.moderation_is_muted('10000000-0000-0000-0000-000000000002'),
  'suresi dolan susturma kendiliginden etkisini yitirir'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
-- 🔴 `moderation_sanctions_one_active_idx` `expires_at`e BAKMAZ; kisitli kume
-- yalnizca `state in (pending, applied)` der. `admin_begin_...` dolmus satiri
-- once `revoked`a cekmezse bu cagri ham `23505` alirdi.
select lives_ok(
  $$select public.admin_begin_moderation_sanction(
      '10000000-0000-0000-0000-000000000002', 'suspend_7d', 'tekrar ihlal',
      'wp443-suspend-key-0001')$$,
  'suresi dolmus kisit yeni yaptirimin onunu tikamaz'
);
reset role;
select is(
  (select state from public.moderation_sanctions
   where idempotency_key = 'wp443-mute-key-0001'),
  'revoked',
  'dolmus kisit sessizce silinmez, revoked olarak kayitta kalir'
);

-- ===========================================================================
-- 6) Iki admin yarisi — ayni yaptirim iki kez kapanmaz
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select id as raced_id from public.moderation_sanctions
where idempotency_key = 'wp443-suspend-key-0001' \gset
select public.admin_finish_moderation_sanction(:'raced_id'::uuid, true);

select set_config('request.jwt.claim.sub', :'gamma', true);
select is(
  (public.admin_finish_moderation_sanction(:'raced_id'::uuid, true)).state,
  'applied',
  'ikinci yonetici ayni yaptirimi kapatinca cagri idempotent doner'
);
reset role;
-- "Ayni eylemde cift yaptirim 0" ve "kayip audit 0" ayni yerde olculur: ikinci
-- kapanis ne yeni yaptirim ne de ikinci denetim satiri uretir.
select is(
  (select count(*)::int from public.admin_audit_logs
   where action = 'moderation:suspend_7d'
     and target_user_id = '10000000-0000-0000-0000-000000000002'),
  1,
  'iki admin yarisi tek denetim satiri birakir (cift yaptirim yok)'
);
select is(
  (select count(*)::int from public.moderation_sanctions
   where target_user_id = '10000000-0000-0000-0000-000000000002'
     and state = 'applied'
     and public.moderation_is_restrictive(action)),
  1,
  'hedef basina tek aktif kisit invarianti yaris sonrasinda da gecerlidir'
);

-- ===========================================================================
-- 7) Kotu niyetli raporlayan sayaci
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select public.admin_set_ugc_report_group_status(
  'profile', '10000000-0000-0000-0000-000000000002', 'rejected');
select public.admin_set_ugc_report_group_status(
  'message', '40000000-0000-0000-0000-000000000030', 'rejected');

select is(
  (public.admin_reporter_abuse_score(
    '10000000-0000-0000-0000-000000000003')->>'rejected_reports')::int,
  2,
  'reddedilen vakalar raporlayana geri sayilir'
);
select is(
  (public.admin_reporter_abuse_score(
    '10000000-0000-0000-0000-000000000003')->>'flagged')::boolean,
  false,
  'esik altindaki raporlayan otomatik isaretlenmez (rapor gelmesi suc degil)'
);

-- ===========================================================================
-- 8) 🔴 RLS kacisi 0
-- ===========================================================================
-- Once yuzeyin TAMAMI supurulur. Tek tek throws_ok yazmak yeni eklenen bir
-- admin RPC'yi kacirir; bu iddia `is_super_admin` kapisi unutulan ilk
-- fonksiyonda duser.
select is(
  (select count(*)::int from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname like 'admin\_%'
     and p.prosrc not like '%is_super_admin%'),
  0,
  'her public.admin_* fonksiyonu is_super_admin kapisi tasir'
);
select ok(
  (select count(*) from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'admin\_%') >= 15,
  'supurme bos kumeye bakmiyor (en az 15 admin RPC var)'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'delta', true);

select throws_ok(
  $$select public.admin_ugc_report_groups()$$,
  '42501', 'not_super_admin',
  'normal kullanici moderasyon kuyrugunu okuyamaz'
);
select throws_ok(
  $$select public.admin_begin_moderation_sanction(
      '10000000-0000-0000-0000-000000000002', 'ban_permanent', 'kendi kararim',
      'wp443-escalation-key')$$,
  '42501', 'not_super_admin',
  'normal kullanici yaptirim acamaz'
);
select throws_ok(
  $$select public.admin_set_case_quarantine(
      '00000000-0000-0000-0000-000000000000', true, 'kendi kararim')$$,
  '42501', 'not_super_admin',
  'normal kullanici karantina uygulayamaz'
);
select throws_ok(
  $$select public.admin_reporter_abuse_score(
      '10000000-0000-0000-0000-000000000002')$$,
  '42501', 'not_super_admin',
  'normal kullanici baskasinin rapor gecmisini goremez'
);
select throws_ok(
  $$select public.admin_decide_moderation_appeal(
      '00000000-0000-0000-0000-000000000000', 'accepted', 'kendi kararim')$$,
  '42501', 'not_super_admin',
  'normal kullanici itiraz karara baglayamaz'
);
-- Yaptirim tablosu okunabilir ama yalniz kendi satiri; baskasinin cezasi
-- sizmaz (`moderation_sanctions_select_own`).
select is(
  (select count(*)::int from public.moderation_sanctions),
  0,
  'normal kullanici baskasinin yaptirim kaydini goremez'
);
-- Kanit gövdesi `0106`dan beri sutun grantiyla kapali; raporlayan bile goremez.
select throws_ok(
  $$select canonical_snapshot from public.ugc_reports$$,
  '42501',
  'permission denied for table ugc_reports',
  'kanit govdesi normal kullaniciya kapali kalir'
);

reset role;
select * from finish();
rollback;
