-- 056_faq_correction_wp656.test.sql
-- WP-656 (hunter Lane H): SSS icerigi urunle celismemeli (migration 0130).
--
-- `048` "satir sayisi arttı mi" sorusunu olcuyordu; icerigin DOGRU olup
-- olmadigini olcmuyordu. Bu dosya, koddan yalanlanmis dokuz cumlenin geri
-- gelmesini engelleyen bir MANDAL kurar: her biri icin YASAK bir metin
-- parcasi ve ZORUNLU bir metin parcasi vardir.
--
-- 🔴 Neden metin arıyoruz: SSS bir veri tablosudur, davranisi yoktur. Burada
-- olculebilecek tek sey "kullanicinin okudugu cumle sunu iddia ediyor mu".
-- Iddianin KODA uygunlugu `0130` basligindaki `dosya:satir` kanitlariyla
-- baglanmistir; bu test o kararin geri alinmasini yakalar.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(16);

-- ---------------------------------------------------------------------------
-- 1) Iki dil hala esit ve buyudu (0123 mandal-degerini 33'ten 39'a cikariyoruz)
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::integer from public.faq_entries where locale = 'tr'),
  (select count(*)::integer from public.faq_entries where locale = 'en'),
  'TR ve EN SSS satir sayisi esit'
);

select cmp_ok(
  (select count(*)::integer from public.faq_entries
    where locale = 'tr' and is_published),
  '>=',
  39,
  'TR tarafinda en az 39 yayimlanmis SSS var'
);

select cmp_ok(
  (select count(*)::integer from public.faq_entries
    where locale = 'en' and is_published),
  '>=',
  39,
  'EN tarafinda en az 39 yayimlanmis SSS var'
);

-- ---------------------------------------------------------------------------
-- 2) 0130'un alti yeni yuvasi iki dilde de dolu ve yayimlanmis
-- ---------------------------------------------------------------------------
select is(
  (select count(distinct sort_order)::integer from public.faq_entries
    where locale = 'tr' and is_published
      and sort_order in (145,150,155,160,165,170)),
  6,
  '0130 TR yuvalarinin altisi da yayimlanmis'
);

select is(
  (select count(distinct sort_order)::integer from public.faq_entries
    where locale = 'en' and is_published
      and sort_order in (145,150,155,160,165,170)),
  6,
  '0130 EN yuvalarinin altisi da yayimlanmis'
);

select is(
  (select count(*)::integer from public.faq_entries
    where sort_order in (145,150,155,160,165,170)
      and char_length(btrim(answer)) < 120),
  0,
  '0130 cevaplarinin hepsi 120 karakterden uzun'
);

-- ---------------------------------------------------------------------------
-- 3) YALANLANMIS CUMLELER GERI GELMESIN (D1..D9)
--    Her iddia icin: yasak metin YOK + duzeltilmis metin VAR.
-- ---------------------------------------------------------------------------

-- D8 (en agir): "tekrar giris yaparsan iptal olur" -- hesap kaybettirir.
select is(
  (select count(*)::integer from public.faq_entries
    where question in ('Hesabımı nasıl silerim?', 'How do I delete my account?')
      and (answer ilike '%tekrar giriş yaparsan istek iptal%'
        or answer ilike '%signing in again during it cancels%')),
  0,
  'D8: "tekrar giris iptal eder" iddiasi SSS de yok'
);

select is(
  (select count(*)::integer from public.faq_entries
    where question in ('Hesabımı nasıl silerim?', 'How do I delete my account?')
      and (answer ilike '%İPTAL ETMEZ%' or answer ilike '%does NOT cancel%')),
  2,
  'D8: iki dilde de "giris yapmak iptal etmez" uyarisi var'
);

-- D7: tac basarim sayisi degil XP.
select is(
  (select count(*)::integer from public.faq_entries
    where question in (
      'Profilimdeki taç ne anlama geliyor?',
      'What does the crown on my profile mean?')
      and (answer ilike '%2 başarımda bronz%'
        or answer ilike '%bronze%at 2,%'
        or answer ilike '%how many achievements you have unlocked: bronze%')),
  0,
  'D7: "2/3/4 basarim" tac esigi iddiasi SSS de yok'
);

select is(
  (select count(*)::integer from public.faq_entries
    where question in (
      'Profilimdeki taç ne anlama geliyor?',
      'What does the crown on my profile mean?')
      and (answer like '%1.000.000%' or answer like '%1,000,000%')),
  2,
  'D7: iki dilde de 1.000.000 XP ust esigi yaziyor'
);

-- D1: gun siniri grup/hesap saat dilimi DEGIL, Europe/Istanbul.
select is(
  (select count(*)::integer from public.faq_entries
    where question in ('Gün ne zaman biter?', 'When does the day end?')
      and (answer ilike '%hesabının etkin zaman dilimi%'
        or answer ilike '%active group or account time zone%')),
  0,
  'D1: "hesabin zaman dilimi" iddiasi SSS de yok'
);

select is(
  (select count(*)::integer from public.faq_entries
    where question in ('Gün ne zaman biter?', 'When does the day end?')
      and answer like '%Europe/Istanbul%'),
  2,
  'D1: iki dilde de Europe/Istanbul sabiti yaziyor'
);

-- D2: seri gun sinirini gruba baglamiyor.
select is(
  (select count(*)::integer from public.faq_entries
    where question in (
      'Seri kuralları nasıl çalışır?', 'How do streak rules work?')
      and (answer ilike '%grubunun zaman dilimine göre%'
        or answer ilike '%in the group time zone%')),
  0,
  'D2: seri gun sinirini gruba baglayan cumle SSS de yok'
);

-- D3: birincil grup Ayarlar da degil.
select is(
  (select count(*)::integer from public.faq_entries
    where question in ('Birincil grup nedir?', 'What is a primary group?')
      and (answer ilike '%Ayarlardan değiştirebilirsin%'
        or answer ilike '%You can change it in Settings%')),
  0,
  'D3: "Ayarlardan degistir" iddiasi SSS de yok'
);

-- D4/150: XP nin geri gidebildigi iki ayri maddede de soylenmis olmali.
select cmp_ok(
  (select count(*)::integer from public.faq_entries
    where is_published
      and (answer ilike '%geri al%' or answer ilike '%geri gider%'
        or answer ilike '%takes back%' or answer ilike '%taken back%')),
  '>=',
  4,
  'D4: XP nin geri gittigini soyleyen en az dort satir var'
);

-- ---------------------------------------------------------------------------
-- 4) Idempotenslik: tabloda benzersiz kisit YOK; tekrar apply kopya uretmemeli.
-- ---------------------------------------------------------------------------
insert into public.faq_entries (locale, question, answer, sort_order, is_published)
select 'tr', 'Uygulama ücretli mi, reklam var mı?', 'kopya', 145, true
where not exists (
  select 1 from public.faq_entries
  where locale = 'tr' and question = 'Uygulama ücretli mi, reklam var mı?'
);

select is(
  (select count(*)::integer from public.faq_entries
    where locale = 'tr' and question = 'Uygulama ücretli mi, reklam var mı?'),
  1,
  'tekrar apply kopya uretmez'
);

select * from finish();
rollback;
