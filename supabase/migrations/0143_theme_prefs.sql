-- 0143_theme_prefs.sql
-- WP-838: tema tercihi ve ozel temalar hesapta saklanir.
--
-- KUSUR (olculdu, `app/lib/core/theme/theme_settings.dart`): tema tercihlerinin
-- TAMAMI yalniz `SharedPreferences`e yaziliyor (aile, palet, mod, renk kaynagi,
-- ozel paletler, ozel temalar, aktif ozel tema). Sunucuya hicbir sey gitmiyor,
-- bu yuzden yeni cihaz ilk kurulum varsayilaniyla (`kFirstRunFamilyId`,
-- WP-841'den beri `campfire_day`) aciliyor: sahibin "yeni cihazda acinca tema
-- ayarim gitmis" geri bildirimi tam olarak budur.
--
-- ---------------------------------------------------------------------------
-- NEDEN `public.profiles` UZERINDE BIR KOLON DEGIL (gorev metninden sapma)
-- ---------------------------------------------------------------------------
-- Gorev "profiles uzerinde tek nullable jsonb kolon" diyordu; kolon yolu
-- "yalniz sahibi okuyabilir" kosulunu SAGLAYAMIYOR:
--
--   * `profiles_select` (son hali `0036_security_hardening.sql:81`) satir
--     seviyesinde `id = auth.uid() or public.can_see_user_sessions(id) or
--     public.is_super_admin()` diyor. `can_see_user_sessions` (`0095`, oncesi
--     `0009`) ORTAK GRUP UYESI icin true doner. Yani profil satirini ayni
--     gruptaki herkes okur; o satira konan her kolon da okunur. Tema JSON'u
--     kullanicinin kendi yazdigi ozel tema ADLARINI tasiyor.
--   * RLS satir seviyesindedir; tek bir kolonu maskeleyemez. Kolonu gizlemenin
--     tek yolu kolon-seviyesi grant'tir (`revoke select on profiles` + kalan
--     kolonlari tek tek `grant`). Bu da `select *` yapan cagriyi dusurur:
--     `app/lib/data/repositories/supabase/supabase_auth_repository.dart:335`
--     (`_profileFor`) tam olarak `.select()` yapiyor ve hatayi YUTUYOR — yani
--     acilista profil sessizce eksik yuklenirdi (WP-609'un aynisi).
--
-- Bu yuzden tercihler kendi sahibine kilitli AYRI bir tabloda durur. Tablo
-- `auth.users`'a `on delete cascade` ile bagli oldugu icin hesap silme zinciri
-- (`0114`/`0124`) kendiliginden kapsar ve yeni bir `restrict` FK eklenmez
-- (`supabase/tests/050_*.test.sql` restrict envanteri degismez).
--
-- SOZLESME: `prefs` istemcinin yazdigi TAM tercih kumesidir ve icinde
-- ISO-8601/UTC bir `updatedAt` tasir. Catisma kurali son-yazan-kazanir:
-- istemci giriste sunucu kopyasini kendi yerel damgasiyla karsilastirir,
-- alan alan birlestirme YAPILMAZ. Sunucu tarafinda dogrulama/hesaplama yoktur;
-- bu tamamen kullaniciya ait kozmetik bir tercihtir (XP/odul gibi
-- server-authoritative bir veri DEGILDIR).
--
-- Mevcut satirlara dokunulmaz: yeni tablo bos baslar, `public.profiles`
-- semasi hic degismez.
--
-- Geri alma (Rollback):
--   drop table if exists public.user_theme_prefs;
--   (Politikalar ve grant'lar tabloyla birlikte duser. Veri kaybi yalniz
--    sunucudaki tema kopyasidir; cihazlardaki `SharedPreferences` kaydi
--    dokunulmadan kalir, yani kullanici hicbir sey kaybetmez.)

create table if not exists public.user_theme_prefs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  prefs jsonb not null
    constraint user_theme_prefs_prefs_is_object
    check (jsonb_typeof(prefs) = 'object')
);

comment on table public.user_theme_prefs is
  'WP-838: kullanicinin tema tercihleri (aile, palet, mod, renk kaynagi, ozel '
  'paletler/temalar, aktif ozel tema) + istemcinin yazdigi ISO-8601 updatedAt. '
  'Yalniz sahibi okur/yazar; catisma son-yazan-kazanir ile cozulur.';

alter table public.user_theme_prefs enable row level security;

-- Yalniz sahibi. `profiles`tan farkli olarak ortak grup uyesine veya
-- super admine acilmaz: burada sosyal bir gorunurluk ihtiyaci yok.
drop policy if exists user_theme_prefs_select on public.user_theme_prefs;
create policy user_theme_prefs_select on public.user_theme_prefs
  for select to authenticated using (user_id = auth.uid());

drop policy if exists user_theme_prefs_insert on public.user_theme_prefs;
create policy user_theme_prefs_insert on public.user_theme_prefs
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists user_theme_prefs_update on public.user_theme_prefs;
create policy user_theme_prefs_update on public.user_theme_prefs
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Istemci yalniz kendi satirini okur/yazar; silme yolu YOK (hesap silme
-- cascade ile temizler), bu yuzden `delete` grant'i de verilmez.
-- 🔴 Supabase'in varsayilan ayricaliklari yeni public tablolarini `anon` ve
-- `authenticated` rollerine ACIK dogar; olculdu: dry-run 35299032541,
-- `069` testi 4. iddiada dustu cunku `anon` SELECT yetkisiyle geliyordu.
-- RLS satirlari yine korurdu, ama yetki tablosu niyeti yansitmali: oturumsuz
-- rolun bu tabloda isi yok. `0094` ayni kalibi kullaniyor.
revoke all on table public.user_theme_prefs from anon, authenticated;
grant select, insert, update on public.user_theme_prefs to authenticated;
