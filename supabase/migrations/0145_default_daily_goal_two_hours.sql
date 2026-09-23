-- 0145_default_daily_goal_two_hours.sql
-- WP-922: yeni hesabin kisisel gunluk hedefi 6 saat yerine 2 saat (120 dk).
--
-- KUSUR (olculdu): `0005_daily_goal.sql:11` kolonu `default 360` ile kurar ve
-- `handle_new_user` (son hali `0142`) profil satirina yalniz `id` ve
-- `display_name` yazar; yani her yeni hesap 6 saatlik hedefle baslar. Ilk gun
-- "0sn / 6sa" gorulur ve seri daha ilk gunden kirilir.
--
-- YAPILAN: yalniz kolon varsayilani 120 olur. Tetikleyici govdesi degismez
-- (hedef yazmadigi icin yeni varsayilani kendiliginden alir).
-- 🔴 Mevcut satirlara DOKUNULMAZ (DML yok): hedefini hic degistirmemis eski
-- kullanicinin 360'i onun gecmis serisinin olcutudur; toplu guncelleme gecmis
-- gunlerin tamamlanma anlamini degistirirdi. Istemcideki es deger
-- `kDefaultDailyGoalMinutes` (app/lib/data/models/profile.dart) de 120'dir.
-- Grup hedefi (`groups.daily_goal_minutes`) bu isin kapsami disindadir.
--
-- Geri alma (Rollback):
--   `alter table public.profiles alter column daily_goal_minutes set default 360;`
--   Ileri migration ile yapilir; bu dosya uygulandiktan sonra degistirilmez.
--   Bu arada acilmis hesaplarin 120 degeri kendi satirlarinda kalir.

alter table public.profiles
  alter column daily_goal_minutes set default 120;
