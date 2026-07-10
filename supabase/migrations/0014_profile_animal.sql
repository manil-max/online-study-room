-- 0014_profile_animal.sql
-- Kamp ateşi canlı ekranı (2G yenileme): her kullanıcı kendini temsil eden bir
-- "kamp hayvanı" seçer. Kozmetik bir alan; grup üyeleri birbirinin hayvanını
-- canlı sahnede görür. Seçilmezse uygulama tarafında kullanıcıya göre
-- deterministik bir varsayılan atanır (kolon null kalabilir).
--
-- RLS değişikliği GEREKMEZ: `profiles` zaten grup üyelerince okunabiliyor ve
-- kullanıcı yalnız kendi satırını güncelleyebiliyor (0001).

alter table public.profiles
  add column if not exists animal text;
