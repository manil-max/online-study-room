begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set gamma '10000000-0000-0000-0000-000000000003'
\set grp   '20000000-0000-0000-0000-000000000001'
\set msg   '40000000-0000-0000-0000-000000000010'

select plan(18);

insert into auth.users (id, email, raw_user_meta_data)
values (:'gamma'::uuid, 'fixture-gamma@example.invalid', '{}'::jsonb)
on conflict (id) do nothing;

insert into public.class_messages (id, group_id, user_id, body)
values (:'msg'::uuid, :'grp'::uuid, :'beta'::uuid, 'İtiraz edilecek metin')
on conflict (id) do nothing;

-- Alpha yaptırımı uygulayan, gamma ikinci yönetici.
insert into public.app_admins (user_id)
values (:'alpha'::uuid), (:'gamma'::uuid)
on conflict do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select lives_ok(
  $$select public.report_ugc(
    'message', '40000000-0000-0000-0000-000000000010', 'harassment', null,
    null, null, '20000000-0000-0000-0000-000000000001'
  )$$,
  'rapor açılır ve vakayı kurar'
);

select is(
  (select state from public.admin_finish_moderation_sanction(
    (select id from public.admin_begin_moderation_sanction(
      '10000000-0000-0000-0000-000000000002'::uuid, 'mute_24h',
      'tekrarlayan hakaret', 'wp442-mute-key-0001',
      (select id from public.moderation_cases
       where target_type = 'message' and target_id = '40000000-0000-0000-0000-000000000010')
    )),
    true
  )),
  'applied',
  'yaptırım uygulanır'
);
reset role;

-- --- İtiraz ---------------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claim.sub', :'gamma', true);
select throws_ok(
  $$select public.submit_moderation_appeal(
    (select id from public.moderation_sanctions
     where target_user_id = '10000000-0000-0000-0000-000000000002'),
    'benim yaptırımım değil ama itiraz ediyorum'
  )$$,
  '42501', 'sanction_not_found',
  'başkasının yaptırımına itiraz edilemez ve varlığı sızmaz'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);
select is(
  (select status from public.submit_moderation_appeal(
    (select id from public.moderation_sanctions
     where target_user_id = '10000000-0000-0000-0000-000000000002'),
    'mesajı ben yazmadım, hesabım paylaşımlıydı'
  )),
  'open',
  'yaptırım gören kişi itiraz edebilir'
);
select is(
  (select count(*) from public.moderation_appeals),
  1::bigint,
  'tekrar gönderim ikinci itiraz açmaz'
);
-- 🔴 WP-473: bu iddia sunucu durumunu ölçüyor, itiraz edenin görüş alanını
-- değil. Aktif kimlik beta (yaptırım gören); `ugc_reports` RLS'i raporu yalnız
-- raporlayana açtığı için sorgu beta altında **sıfır satır** görüyordu ve
-- `bool_and` boş kümede NULL dönüyordu — yani saklama süresi hiç uzatılmasa
-- bile test aynı şekilde düşerdi. Ayrıcalıklı rolde okununca iddia gerçekten
-- saklama süresini ölçer.
reset role;
select ok(
  (select bool_and(r.evidence_retention_until > now() + interval '100 days')
   from public.ugc_reports r
   where r.target_type = 'message' and r.target_id = :'msg'),
  'açık itiraz kanıt saklama süresini ileri atar'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);

-- Kanıt gövdesi normal kullanıcıya kapalıdır.
select throws_ok(
  $$select canonical_snapshot from public.ugc_reports
    where target_id = '40000000-0000-0000-0000-000000000010'$$,
  '42501',
  null,
  'yetkisiz kullanıcı kanıt gövdesini okuyamaz'
);
reset role;

-- --- Karar ----------------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select throws_ok(
  $$select public.admin_decide_moderation_appeal(
    (select id from public.moderation_appeals), 'upheld', 'kendi kararım'
  )$$,
  '42501', 'appeal_conflict_of_interest',
  'yaptırımı uygulayan admin kendi kararını denetleyemez'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', :'gamma', true);
select is(
  (select status from public.admin_decide_moderation_appeal(
    (select id from public.moderation_appeals), 'overturned', 'kanıt yetersiz'
  )),
  'overturned',
  'ikinci yönetici itirazı karara bağlar'
);
select ok(
  not public.moderation_is_muted(:'beta'::uuid),
  'kabul edilen itiraz yaptırımı kaldırır'
);
select is(
  (select status from public.admin_decide_moderation_appeal(
    (select id from public.moderation_appeals), 'upheld', 'ikinci kez'
  )),
  'overturned',
  'karar verilmiş itiraz yeniden karara bağlanmaz'
);
select is(
  (select count(*) from public.moderation_sanctions
   where target_user_id = :'beta' and state = 'revoked'),
  1::bigint,
  'yaptırım kaldırma idempotenttir'
);

-- --- Denetim zinciri -------------------------------------------------------

select ok(
  (select count(*) from public.moderation_audit_events
   where entity_type = 'sanction' and action = 'state_changed') >= 1,
  'yaptırım durum değişimi denetim zincirine düşer'
);
-- 🔴 WP-473: append-only iddiası **ayrıcalıklı rolde** kurulmalıdır.
-- `authenticated` altında `update`/`delete` zaten grant kapısında düşüyor
-- ("permission denied for table"), yani tetikleyici hiç çalışmıyordu ve test
-- kanıtlamak istediği şeyi kanıtlamıyordu. `0106`'nın kendi notu da bunu
-- söylüyor: tetikleyici tablo sahibinde de çalışsın diye var, "yalnız `revoke`
-- yeterli olmazdı". Aşağısı tam o iddiayı sınar.
reset role;
select throws_ok(
  $$update public.moderation_audit_events set reason = 'degistirildi'$$,
  '42501', 'moderation_audit_append_only',
  'geçmiş denetim satırı sahibi tarafından bile değiştirilemez'
);
select throws_ok(
  $$delete from public.moderation_audit_events$$,
  '42501', 'moderation_audit_append_only',
  'geçmiş denetim satırı sahibi tarafından bile silinemez'
);
reset role;

-- --- Kanıt imhası ----------------------------------------------------------

-- Saklama süresi dolmuş, itirazı olmayan tarihsel kayıt.
insert into public.ugc_reports (
  reporter_id, target_type, target_id, reason, content_snapshot,
  canonical_snapshot, evidence_retention_until
) values (
  :'alpha'::uuid, 'profile', :'gamma', 'spam', 'eski metin',
  jsonb_build_object('target_type', 'profile', 'profile_id', :'gamma'),
  now() - interval '1 day'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select is(
  public.moderation_purge_expired_evidence(),
  1,
  'süresi dolan ve itirazsız kanıt imha edilir'
);
reset role;

-- Kanıt sütunları `authenticated`e kapalı olduğu için doğrulama sahip rolüyle.
select is(
  (select count(*) from public.ugc_reports
   where target_type = 'profile' and target_id = :'gamma'
     and canonical_snapshot is null and evidence_hash is not null),
  1::bigint,
  'içerik silinir ama değişmezlik imzası kalır'
);
select is(
  (select count(*) from public.ugc_reports
   where target_type = 'message' and target_id = :'msg'
     and evidence_redacted_at is null),
  1::bigint,
  'itiraz görmüş kanıt aynı turda imha edilmez'
);

select * from finish();
rollback;
