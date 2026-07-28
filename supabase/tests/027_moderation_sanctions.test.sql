begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'

select plan(6);

select has_table('public', 'moderation_name_resets',
  'isim sıfırlamalarının geri alma kaydı vardır');
-- pgTAP'ta `hasnt_table_privilege` yok; yerleşik `has_table_privilege` (3 arg)
-- pgTAP'ın ok()'ine sarılır.
select ok(not has_table_privilege('authenticated', 'public.moderation_name_resets', 'select'),
  'authenticated geri alma kayıtlarını okuyamaz');
select ok(not has_table_privilege('authenticated', 'public.admin_audit_logs', 'update'),
  'authenticated denetim kaydını değiştiremez');
select ok(not has_table_privilege('authenticated', 'public.admin_audit_logs', 'delete'),
  'authenticated denetim kaydını silemez');

insert into public.moderation_name_resets (
  target_type, target_id, previous_name, reset_by
) values ('user', :'beta'::uuid, 'İlk ad', :'alpha'::uuid);
insert into public.moderation_name_resets (
  target_type, target_id, previous_name, reset_by
) values ('user', :'beta'::uuid, 'Yanlış yeni ad', :'alpha'::uuid)
on conflict (target_type, target_id) do nothing;

select is(
  (select previous_name from public.moderation_name_resets
   where target_type = 'user' and target_id = :'beta'::uuid),
  'İlk ad',
  'tekrar sıfırlama geri alma için özgün adı korur'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);
-- pgTAP `throws_like(sql, pattern, description)` alır; SQLSTATE argümanı
-- `throws_ok`'a aittir, dördüncü argümanlı sürüm yoktur.
select throws_like(
  $$select * from public.moderation_name_resets$$,
  '%permission denied%',
  'sıradan kullanıcı isim geri alma geçmişini okuyamaz'
);
reset role;

select * from finish();
rollback;
