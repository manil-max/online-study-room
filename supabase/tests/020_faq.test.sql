begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir _fixtures/base_seed.psql

select plan(6);

insert into public.faq_entries (id, locale, question, answer, sort_order, is_published)
values
  ('51000000-0000-0000-0000-000000000001', 'tr', 'Yayınlanan soru', 'Anon kullanıcı bunu görebilir.', 900, true),
  ('51000000-0000-0000-0000-000000000002', 'tr', 'Taslak soru', 'Anon kullanıcı bunu göremez.', 901, false)
on conflict (id) do update set is_published = excluded.is_published;

set local role anon;
select is(
  (select count(*) from public.faq_entries where id in ('51000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000002')),
  1::bigint,
  'anon reads only published FAQ entries'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.submit_faq_question('Widget eklerken takıldım; yardım eder misiniz?')$$,
  'signed-in user can submit a FAQ question'
);
reset role;

select is(
  (select ticket_type from public.feedback_tickets where subject like 'Widget eklerken%' limit 1),
  'question',
  'FAQ question enters the unified support inbox as a question'
);

set local role anon;
select throws_ok(
  $$select public.submit_faq_question('Anon gönderim denemesi')$$,
  '42501',
  'permission denied for function submit_faq_question',
  'anon cannot submit a FAQ question'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select public.submit_faq_question('x')$$,
  'P0001',
  'invalid_question',
  'short question is rejected server-side'
);
reset role;

select ok(
  (select count(*) >= 12 from public.faq_entries where locale = 'tr' and is_published)
  and (select count(*) >= 12 from public.faq_entries where locale = 'en' and is_published),
  'initial Turkish and English FAQ content is populated'
);

select * from finish();
rollback;
