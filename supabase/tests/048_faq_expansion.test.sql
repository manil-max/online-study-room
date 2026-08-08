-- 048_faq_expansion.test.sql
-- WP-522: SSS genişletmesi (migration 0123).
--
-- Sahip v60 cihaz denemesinde "SSS eksik" dedi. 0123 her dile 20 satır ekledi.
-- Bu test içeriğin **kelimesini** değil, içeriği bozan üç somut hatayı ölçer:
--   1) tek dile ekleme (0118'in dersi — `faq_entries` yalnız `locale` ile
--      süzülür, eksik dil sessiz kalır),
--   2) yayımlanmamış satır (istemci `is_published` süzer, satır görünmez),
--   3) tekrar apply'da kopya (tabloda benzersiz kısıt YOK).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(7);

-- 1) İki dilin satır sayısı eşit olmalı. Bu bir ratchet: bundan sonra tek
--    dile SSS ekleyen her migration bu kapıda kırmızı düşer.
select is(
  (select count(*)::integer from public.faq_entries where locale = 'tr'),
  (select count(*)::integer from public.faq_entries where locale = 'en'),
  'TR ve EN SSS satir sayisi esit'
);

-- 2) 0091 (12) + 0118 (1) + 0123 (20) = en az 33 satır/dil.
select cmp_ok(
  (select count(*)::integer from public.faq_entries
    where locale = 'tr' and is_published),
  '>=',
  33,
  'TR tarafinda en az 33 yayimlanmis SSS var'
);

select cmp_ok(
  (select count(*)::integer from public.faq_entries
    where locale = 'en' and is_published),
  '>=',
  33,
  'EN tarafinda en az 33 yayimlanmis SSS var'
);

-- 3) 0123'ün yirmi yuvası iki dilde de dolu ve yayımlanmış olmalı.
--    sort_order kullanılıyor çünkü soru metni ileride düzeltilebilir; yuva
--    numarası migration'ın sözleşmesidir.
select is(
  (select count(distinct sort_order)::integer from public.faq_entries
    where locale = 'tr' and is_published
      and sort_order in (2,4,6,8,12,22,25,35,45,55,65,75,85,95,105,115,125,130,135,140)),
  20,
  '0123 TR yuvalarinin yirmisi de yayimlanmis'
);

select is(
  (select count(distinct sort_order)::integer from public.faq_entries
    where locale = 'en' and is_published
      and sort_order in (2,4,6,8,12,22,25,35,45,55,65,75,85,95,105,115,125,130,135,140)),
  20,
  '0123 EN yuvalarinin yirmisi de yayimlanmis'
);

-- 4) Cevap gövdesi anlamlı uzunlukta olmalı. Tek satırlık "Evet." tipi bir
--    cevap SSS'yi kalabalıklaştırır ama soruyu kapatmaz; 0123'ün cevapları
--    en kısa halinde bile 120 karakterin üstünde.
select is(
  (select count(*)::integer from public.faq_entries
    where sort_order in (2,4,6,8,12,22,25,35,45,55,65,75,85,95,105,115,125,130,135,140)
      and char_length(btrim(answer)) < 120),
  0,
  '0123 cevaplarinin hepsi 120 karakterden uzun'
);

-- 5) Idempotenslik: `0091` tabloyu benzersiz kısıt olmadan kurdu, bu yüzden
--    `on conflict` bu satırları korumaz. 0123'ün varlık kontrolü tekrar
--    apply'da kopya üretmemeli.
insert into public.faq_entries (locale, question, answer, sort_order, is_published)
select 'tr', 'Uygulamaya nasıl başlarım?', 'kopya', 2, true
where not exists (
  select 1 from public.faq_entries
  where locale = 'tr' and question = 'Uygulamaya nasıl başlarım?'
);

select is(
  (select count(*)::integer from public.faq_entries
    where locale = 'tr' and question = 'Uygulamaya nasıl başlarım?'),
  1,
  'tekrar apply kopya uretmez'
);

select * from finish();
rollback;
