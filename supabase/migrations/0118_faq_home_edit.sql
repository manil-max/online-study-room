-- 0118_faq_home_edit.sql
-- WP-488: ana ekran düzenleme yolunu anlatan SSS satırı (TR + EN).
--
-- Sahip kararıyla ana ekranın görüntüleme modundaki üst şeridi ve düzenle
-- butonu kaldırıldı; yerine yeni buton konmayacak. Düzenlemeye giriş yolu
-- karta **uzun basmaktır**. Keşfedilebilirlik iki yerden sağlanır: tanıtım
-- turunun ana ekran adımı ve bu SSS satırı.
--
-- 🔴 TR ve EN birlikte eklenir. Yalnız TR eklemek İngilizce kullanıcıda eksik
-- bir SSS bırakır ve `faq_entries` yalnız `locale` sütununa göre süzülür.
--
-- Idempotenslik: `0091` tabloyu benzersiz kısıtsız kurdu, bu yüzden
-- `on conflict do nothing` bu satırları korumaz (çakışacak kısıt yok).
-- Tekrar apply'da kopya üretmemek için varlık kontrolü kullanılır.
--
-- Geri alma (Rollback):
--   delete from public.faq_entries
--    where question in (
--      'Ana ekrandaki kartları nasıl düzenlerim?',
--      'How do I edit the cards on the home screen?'
--    );

insert into public.faq_entries (locale, question, answer, sort_order, is_published)
select v.locale, v.question, v.answer, v.sort_order, true
from (
  values
    (
      'tr',
      'Ana ekrandaki kartları nasıl düzenlerim?',
      'Herhangi bir karta uzun bas; ana ekran düzenleme moduna geçer. '
      'Bu modda kart ekleyebilir, taşıyabilir, boyutlandırabilir ve '
      'düzeni sıfırlayabilirsin. Bitirmek için onay simgesine dokun.',
      15
    ),
    (
      'en',
      'How do I edit the cards on the home screen?',
      'Press and hold any card to enter edit mode. There you can add, move, '
      'resize and remove cards, or reset the layout. Tap the check icon to '
      'finish.',
      15
    )
) as v(locale, question, answer, sort_order)
where not exists (
  select 1
  from public.faq_entries existing
  where existing.locale = v.locale
    and existing.question = v.question
);
