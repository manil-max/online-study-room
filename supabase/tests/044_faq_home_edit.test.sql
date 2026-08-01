-- 044_faq_home_edit.test.sql
-- WP-488: ana ekran düzenleme SSS satırı (migration 0118).
--
-- Ana ekranın görüntüleme modundaki düzenle butonu kaldırıldı ve yerine yeni
-- buton konmadı (sahip kararı). Keşfedilebilirlik iki yerden geliyor: tanıtım
-- turu (istemci testinde) ve bu SSS satırı.
--
-- 🔴 İki dil birlikte iddia ediliyor. `faq_entries` yalnız `locale` sütununa
-- göre süzülüyor; yalnız TR eklenseydi İngilizce kullanıcıda eksik bir SSS
-- kalırdı ve hiçbir test bunu görmezdi.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(4);

select is(
  (select count(*)::integer from public.faq_entries
    where locale = 'tr'
      and question = 'Ana ekrandaki kartları nasıl düzenlerim?'
      and is_published),
  1,
  '0118 TR sorusunu yayimlanmis olarak ekler'
);

select is(
  (select count(*)::integer from public.faq_entries
    where locale = 'en'
      and question = 'How do I edit the cards on the home screen?'
      and is_published),
  1,
  '0118 EN sorusunu yayimlanmis olarak ekler'
);

-- Cevap gercek giris yolunu tarif etmeli; "duzenle butonuna bas" demek artik
-- yanlis bilgi olurdu.
select ok(
  (select answer from public.faq_entries
    where locale = 'tr'
      and question = 'Ana ekrandaki kartları nasıl düzenlerim?')
  like '%uzun bas%',
  'TR cevabi uzun basmayi tarif ediyor'
);

-- Idempotenslik: 0091 tabloyu benzersiz kisit olmadan kurdu, bu yuzden
-- `on conflict` bu satirlari korumaz. Ayni insert tekrar kosarsa kopya
-- uretmemeli.
insert into public.faq_entries (locale, question, answer, sort_order, is_published)
select 'tr', 'Ana ekrandaki kartları nasıl düzenlerim?', 'kopya', 15, true
where not exists (
  select 1 from public.faq_entries
  where locale = 'tr' and question = 'Ana ekrandaki kartları nasıl düzenlerim?'
);

select is(
  (select count(*)::integer from public.faq_entries
    where locale = 'tr'
      and question = 'Ana ekrandaki kartları nasıl düzenlerim?'),
  1,
  'tekrar apply kopya uretmez'
);

select * from finish();
rollback;
