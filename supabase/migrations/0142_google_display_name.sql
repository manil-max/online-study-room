-- 0142_google_display_name.sql
-- WP-832: Google ile gelen kullanicinin gorunen adi + kayit tetikleyicisinin cokmemesi.
--
-- KUSUR (olculdu, `supabase/tests/068_google_display_name_wp832.test.sql`):
-- `public.handle_new_user()` (`0001`) profil adini YALNIZ
-- `raw_user_meta_data ->> 'display_name'` alanindan okuyordu. Iki sonucu var:
--
--   * BOS AD. "Google ile devam et" (`signInWithIdToken`) metadata'ya
--     `display_name` YAZMAZ; Google `full_name` ve `name` getirir. Google ile
--     gelen her kullanici bos adla aciliyordu.
--   * TUM KAYDIN COKMESI. Tetikleyici `auth.users` insert'inin ICINDE kosar.
--     Profil insert'i hata firlatirsa kullanici satiri da geri alinir ve
--     istemci yalniz opak "Database error saving new user" gorur:
--       - `profiles_public_name_filter` (`0094`) yasakli terim iceren adda
--         `public_name_not_allowed` firlatir. Filtre alt-dizi aradigi icin
--         tamamen masum bir Google tam adi da takilabilir (orn. "amk" gecen
--         bir soyad); kullanicinin bu adi degistirme sansi YOKTUR, ad
--         Google hesabindan gelir.
--       - `profiles_display_name_max_len` (`0122`, btrim sonrasi <= 24)
--         uzun bir Google tam adinda `check_violation` firlatir.
--
-- DUZELTME (yalniz `handle_new_user` govdesi; sema/kisit/filtre DEGISMEZ):
--   1. Ad kaynagi sirasi: `display_name` -> `full_name` -> `name` -> ''.
--      Bos/yalniz bosluk olan kaynak atlanir, siradakine gecilir.
--   2. Normalizasyon: bosluklar tek bosluga indirilir, bastan/sondan kirpilir,
--      `0122` sinirina (24) kesilir ve kesimden sonra tekrar kirpilir (kesim
--      bir kelime arasina denk gelirse sonda bosluk kalmasin). Boylece uzunluk
--      kisiti bu yoldan ASLA patlamaz.
--   3. Aday ad once `assert_public_name_allowed` (`0094`) ile denenir. YALNIZ
--      o fonksiyonun kendi hatasi (`P0001` + mesaj `public_name_not_allowed`)
--      yakalanir ve ad '' olur. Diger her hata (tablo yok, izin, beklenmedik
--      durum) AYNEN yeniden firlatilir: kor bir `when others` gercek bir
--      sema bozuklugunu "bos adli kullanici" olarak gizlerdi. Kullanici bos
--      adla acilir; ad istemcideki profil ekranindan (filtre orada acik hata
--      verir) sonradan konur.
--   4. Degismeyenler (`0001` ile birebir): `security definer`,
--      `set search_path = public`, `on conflict (id) do nothing`, tetikleyici
--      tanimi (`on_auth_user_created`). `0017` bu fonksiyonu DEGISTIRMEZ; ayri
--      bir tetikleyici (`handle_new_user_gamification`) ekler, ona dokunulmaz.
--
-- E-POSTA/SIFRE YOLU: filtreden ve 24 sinirindan gecen ad icin sonuc ayni
-- kalir (tek fark: ic/uc bosluklar normalize edilir). Onceden kaydi DUSUREN
-- iki durum (yasakli terim, 24'ten uzun ad) artik kaydi dusurmez: yasakli adda
-- profil '' ile, uzun adda 24'e kesilmis adla acilir.
--
-- Geri alma (Rollback):
--   `0001_initial_schema.sql` icindeki `public.handle_new_user()` govdesini
--   yeniden calistir (yalniz `display_name`, normalizasyon ve filtre yakalama
--   yok). Veri degismez; bu migration hic satir yazmaz/silmez, yalniz yeni
--   kayitlarin nasil acildigini degistirir.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_name text;
begin
  -- 1) Kaynak sirasi + bosluk normalizasyonu. Her kaynak AYRI normalize edilir
  --    (tab/satir sonu dahil her bosluk dizisi tek bosluk, uclar kirpilir);
  --    sonuc bos kalan kaynak `nullif` ile atlanir. Normalizasyon siradan
  --    ONCE yapilmazsa yalniz "\t" iceren bir `display_name` dolu sayilip
  --    `full_name`i golgelerdi.
  v_name := coalesce(
    nullif(btrim(regexp_replace(coalesce(v_meta ->> 'display_name', ''), '\s+', ' ', 'g')), ''),
    nullif(btrim(regexp_replace(coalesce(v_meta ->> 'full_name', ''), '\s+', ' ', 'g')), ''),
    nullif(btrim(regexp_replace(coalesce(v_meta ->> 'name', ''), '\s+', ' ', 'g')), ''),
    ''
  );

  -- 2) `0122` siniri (24). Kesimden sonra tekrar kirpilir; kisit
  --    `char_length(btrim(display_name)) <= 24` oldugu icin bu noktadan sonra
  --    uzunluk kisiti patlayamaz.
  v_name := btrim(left(v_name, 24));

  -- 3) Ad filtresi (`0094`). Yalniz filtrenin KENDI hatasi yutulur; baska
  --    her hata yeniden firlatilir (yukaridaki baslik, madde 3).
  if v_name <> '' then
    begin
      perform public.assert_public_name_allowed(v_name);
    exception
      when raise_exception then
        if sqlerrm = 'public_name_not_allowed' then
          v_name := '';
        else
          raise;
        end if;
    end;
  end if;

  insert into public.profiles (id, display_name)
  values (new.id, v_name)
  on conflict (id) do nothing;
  return new;
end;
$$;

