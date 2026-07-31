begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'
\set msg   '40000000-0000-0000-0000-000000000010'

-- 16: WP-473'te kanıt gövdesinin kullanıcıya kapalı olduğunu doğrulayan iddia eklendi.
select plan(16);

insert into public.class_messages (id, group_id, user_id, body)
values (:'msg'::uuid, :'grp'::uuid, :'beta'::uuid, 'Sunucunun kanonik metni')
on conflict (id) do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select lives_ok(
  $$select public.report_ugc(
    'message', '40000000-0000-0000-0000-000000000010', 'spam', null,
    'istemci bunu değiştirebilir', null, '20000000-0000-0000-0000-000000000001'
  )$$,
  'aktif üye gerçek grup bağlamındaki mesajı raporlayabilir'
);
-- 🔴 WP-473: `canonical_snapshot` `0106` (WP-442) ile **bilerek** normal
-- kullanıcıdan alındı — raporlayan kendi satırını okusa bile sunucunun ürettiği
-- kanıt gövdesini göremez (tablo grantı kaldırılıp izin verilen sütunlar tek tek
-- verildi). Bu dosya `0104` zamanında yazıldı, hiç koşmadı ve sonraki kararı
-- göremedi. İddianın niyeti — "istemci ipucu değil server metni saklanır" —
-- korunuyor, yalnız ayrıcalıklı rolde doğrulanıyor; hemen ardından sütunun
-- kullanıcıya gerçekten kapalı olduğu da ayrıca iddia ediliyor.
reset role;
reset role;
select is(
  (select canonical_snapshot->>'body' from public.ugc_reports
   where target_type = 'message' and target_id = :'msg'),
  'Sunucunun kanonik metni',
  'istemci ipucu yerine server kanonik metni saklanır'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select throws_ok(
  $$select canonical_snapshot from public.ugc_reports$$,
  '42501',
  'permission denied for table ugc_reports',
  'kanıt gövdesi raporlayana bile kapalıdır (0106 sütun grantı)'
);
select is(
  (select client_hint from public.ugc_reports
   where target_type = 'message' and target_id = :'msg'),
  'istemci bunu değiştirebilir',
  'istemci ipucu kanıttan ayrı korunur'
);
select throws_ok(
  $$select public.report_ugc(
    'message', '40000000-0000-0000-0000-000000000010', 'hate', null,
    null, null, '20000000-0000-0000-0000-000000000002'
  )$$,
  '42501', 'report_target_not_visible',
  'uydurulmuş mesaj bağlamı RLS kapısında reddedilir'
);
select throws_ok(
  $$select public.report_ugc(
    'message', '40000000-0000-0000-0000-000000000010', 'hate'
  )$$,
  'P0001', 'context_group_required',
  'mesaj raporu bağlam grubu olmadan açılmaz'
);
select lives_ok(
  $$select public.report_ugc(
    'group', '20000000-0000-0000-0000-000000000001', 'spam'
  )$$,
  'grup hedefi açılır'
);
select lives_ok(
  $$select public.report_ugc(
    'group_name', '20000000-0000-0000-0000-000000000001', 'spam'
  )$$,
  'grup adı aynı kimlikte ayrı vaka açar'
);
reset role;
select is(
  (select count(*) from public.moderation_cases
   where target_id = :'grp' and status in ('open', 'in_review')),
  2::bigint,
  'grup ve grup adı ayrı açık vakadır'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
reset role;
select is(
  (select count(*) from public.moderation_cases
   where target_type = 'message' and target_id = :'msg' and status = 'open'),
  1::bigint,
  'aynı hedef tek açık vakada toplanır'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select throws_like(
  $$update public.ugc_reports
    set canonical_snapshot = '{}'::jsonb
    where target_type = 'message' and target_id = '40000000-0000-0000-0000-000000000010'$$,
  '%ugc_report_evidence_immutable%',
  'kanıt ve hedef alanları update ile değiştirilemez'
);

reset role;
insert into public.app_admins (user_id) values (:'alpha'::uuid) on conflict do nothing;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select is(
  public.admin_set_ugc_report_group_status('message', :'msg', 'resolved'),
  1::bigint,
  'admin vaka durumunu kapatır'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select lives_ok(
  $$select public.report_ugc(
    'message', '40000000-0000-0000-0000-000000000010', 'abuse', null,
    null, null, '20000000-0000-0000-0000-000000000001'
  )$$,
  'kapanan vakadan sonraki rapor yeni vaka açar'
);
select is(
  (select count(*) from public.moderation_cases
   where target_type = 'message' and target_id = :'msg'),
  2::bigint,
  'kapanan vakadan sonra ayrı vaka oluşur'
);
select lives_ok(
  $$select public.report_ugc(
    'message', '40000000-0000-0000-0000-000000000010', 'spam', null,
    null, null, '20000000-0000-0000-0000-000000000001'
  )$$,
  'kapanan vakadaki aynı sebep tekrar raporlanabilir'
);
select is(
  (select r.status from public.ugc_reports r
   join public.moderation_cases c on c.id = r.case_id
   where r.target_type = 'message' and r.target_id = :'msg' and r.reason = 'spam'),
  'open',
  'tekrar rapor açık vakaya taşınır ve kuyruğa geri döner'
);
reset role;

select * from finish();
rollback;
