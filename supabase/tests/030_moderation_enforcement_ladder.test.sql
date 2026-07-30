begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'
\set msg   '40000000-0000-0000-0000-000000000010'

select plan(19);

insert into public.class_messages (id, group_id, user_id, body)
values (:'msg'::uuid, :'grp'::uuid, :'beta'::uuid, 'Karantinaya girecek metin')
on conflict (id) do nothing;

insert into public.app_admins (user_id) values (:'alpha'::uuid) on conflict do nothing;

-- Alpha hem raporlayan hem super-admin: bu testte yaptırım/karantina yolunu
-- sürer. Yaptırımın hedefi beta'dır.
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select lives_ok(
  $$select public.report_ugc(
    'message', '40000000-0000-0000-0000-000000000010', 'hate', null,
    null, null, '20000000-0000-0000-0000-000000000001'
  )$$,
  'nefret söylemi raporu açılır'
);
select is(
  (select c.severity from public.moderation_cases c
   where c.target_type = 'message' and c.target_id = :'msg'),
  'high',
  'içerik türü yüksek önem verir'
);
select ok(
  (select c.sla_due_at <= c.opened_at + interval '4 hours' from public.moderation_cases c
   where c.target_type = 'message' and c.target_id = :'msg'),
  'yüksek önem SLA süresi 4 saate çekilir'
);

-- --- Basamaklı yaptırım: aç → kapat, idempotent ---------------------------

select is(
  (select state from public.admin_begin_moderation_sanction(
    :'beta'::uuid, 'mute_24h', 'tekrarlayan hakaret', 'wp441-mute-key-0001'
  )),
  'pending',
  'yaptırım önce pending olarak açılır'
);
select is(
  (select count(*) from public.moderation_sanctions where target_user_id = :'beta'),
  1::bigint,
  'aynı idempotency anahtarı ikinci satır açmaz'
);
select is(
  (select id from public.admin_begin_moderation_sanction(
    :'beta'::uuid, 'mute_24h', 'tekrarlayan hakaret', 'wp441-mute-key-0001'
  )),
  (select id from public.moderation_sanctions where target_user_id = :'beta'),
  'tekrar gönderim aynı kaydı geri verir'
);
select throws_ok(
  $$select public.admin_begin_moderation_sanction(
    '10000000-0000-0000-0000-000000000002'::uuid, 'suspend_7d', 'ikinci ceza',
    'wp441-suspend-key-0001'
  )$$,
  'P0001', 'sanction_already_active',
  'aktif kısıt varken ikinci kısıtlayıcı yaptırım açılmaz'
);

select is(
  (select state from public.admin_finish_moderation_sanction(
    (select id from public.moderation_sanctions where target_user_id = :'beta'), true
  )),
  'applied',
  'auth işi bittikten sonra yaptırım uygulanmış olur'
);
select is(
  (select count(*) from public.admin_audit_logs
   where target_user_id = :'beta' and action = 'moderation:mute_24h'),
  1::bigint,
  'denetim satırı yaptırımla aynı transaction''da yazılır'
);
select is(
  (select count(*) from public.notification_outbox
   where recipient_id = :'beta' and notification_type = 'announcement'
     and payload->>'route' = 'safety_notice'),
  1::bigint,
  'kısıt kullanıcıya gerçekten iletilir'
);
select ok(
  public.moderation_is_muted(:'beta'::uuid),
  'susturma sunucu tarafında etkindir'
);

reset role;

-- --- Mute yazmayı keser, okumayı kesmez ------------------------------------

set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);
select throws_ok(
  $$insert into public.class_messages (group_id, user_id, body)
    values ('20000000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000002', 'susturulmus yazi')$$,
  '42501',
  null,
  'susturulmuş kullanıcı yazamaz'
);
select is(
  (select count(*) from public.class_messages where id = :'msg'),
  1::bigint,
  'susturulmuş kullanıcı okumaya devam eder'
);
reset role;

-- --- Karantina geri alınabilir ---------------------------------------------

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select lives_ok(
  $$select public.admin_set_case_quarantine(
    (select id from public.moderation_cases
     where target_type = 'message'
       and target_id = '40000000-0000-0000-0000-000000000010'),
    true, 'inceleme bitene kadar')$$,
  'yüksek riskli içerik karantinaya alınır'
);
reset role;

-- Beta mesajın yazarıdır ve kendi satırını görmeye devam eder; karantina
-- üçüncü kişiye kapatır. Alpha super-admin olduğu için de görür.
set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);
select is(
  (select count(*) from public.class_messages where id = :'msg'),
  1::bigint,
  'karantina yazarın kendi satırını gizlemez'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select lives_ok(
  $$select public.admin_set_case_quarantine(
    (select id from public.moderation_cases
     where target_type = 'message'
       and target_id = '40000000-0000-0000-0000-000000000010'),
    false, 'inceleme bitti')$$,
  'karantina geri alınır'
);

-- --- Geri alma ve yetki ---------------------------------------------------

select is(
  (select state from public.admin_revoke_moderation_sanction(
    (select id from public.moderation_sanctions where target_user_id = :'beta'),
    'yanlış uygulandı'
  )),
  'revoked',
  'yaptırım geri alınır'
);
select ok(
  not public.moderation_is_muted(:'beta'::uuid),
  'geri alınan susturma etkisini yitirir'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);
select throws_ok(
  $$select public.admin_begin_moderation_sanction(
    '10000000-0000-0000-0000-000000000001'::uuid, 'ban_permanent', 'keyfi',
    'wp441-abuse-key-0001'
  )$$,
  '42501', 'not_super_admin',
  'admin olmayan yaptırım yazamaz'
);
reset role;

select * from finish();
rollback;
