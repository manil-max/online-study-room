-- 0122_name_length_limits.sql
-- WP-517: görünen ad ve grup adı için karakter sınırı (istemci + sunucu + mevcut veri)
--
-- Sahip kararı (2026-08-08, önizlemeden seçildi): kişi adı 24, grup adı 30.
--
-- Neden gerekli: dört giriş noktasının hiçbirinde `maxLength` yoktu ve
-- `profiles.display_name` / `public.groups.name` için DB'de hiçbir uzunluk
-- kısıtı yoktu. Tek istisna `0032_public_group_discovery.sql` içindeki
-- `create_group_with_access` fonksiyonuydu (64) — yani 64 karakterden uzun
-- adla grup **oluşturulamıyordu** ama 64'e kadar olan ad kabul edilip
-- keşifte de sorunsuz görünüyordu; asıl tutarsızlık şuydu: RPC 64'e izin
-- verirken `update` yolunda (grup yeniden adlandırma, profil adı) HİÇBİR
-- sınır yoktu. Bu migration üç yolu da tek sayıya bağlar.
--
-- SIRA ÖNEMLİ: önce mevcut veri kırpılır, SONRA kısıt eklenir. Ters sırada
-- kısıt mevcut satırda patlar ve migration yarıda kalır. Bu hostta yerel
-- replay yok (Docker kalkmıyor), o yüzden sıra burada garanti edilir.
--
-- Kısıtlar bilinçli olarak yalnız ÜST sınırı zorlar. Alt sınır ("boş olamaz")
-- RPC'de duruyor; kısıta koymak, adı boş kalmış tarihsel bir satır varsa
-- migration'ı düşürürdü.
--
-- Geri alma (Rollback):
--   alter table public.profiles drop constraint if exists profiles_display_name_max_len;
--   alter table public.groups   drop constraint if exists groups_name_max_len;
--   -- create_group_with_access için 0076_group_time_zone.sql içindeki
--   -- sürümü yeniden çalıştır (tek fark: 30 yerine 64).
--   -- Kırpılan adlar geri gelmez; kırpma öncesi değerler saklanmaz.

begin;

-- 1) Mevcut veriyi sınıra çek (kırpma). Trim de uygulanır: sondaki boşluk
--    uzunluğa sayılıp gereksiz kırpmaya yol açmasın.
update public.profiles
   set display_name = left(btrim(display_name), 24)
 where display_name is not null
   and char_length(btrim(display_name)) > 24;

update public.groups
   set name = left(btrim(name), 30)
 where char_length(btrim(name)) > 30;

-- 2) Kısıtlar. `btrim` ile ölçülür ki "30 karakter + 5 boşluk" reddedilmesin.
alter table public.profiles
  drop constraint if exists profiles_display_name_max_len;
alter table public.profiles
  add constraint profiles_display_name_max_len
  check (display_name is null or char_length(btrim(display_name)) <= 24);

alter table public.groups
  drop constraint if exists groups_name_max_len;
alter table public.groups
  add constraint groups_name_max_len
  check (char_length(btrim(name)) <= 30);

-- 3) Grup oluşturma RPC'si 64'ten 30'a iner.
--    Uygulanmış migration değiştirilmez; ileri migration ile yeniden tanımlanır
--    (`.agents/AGENTS.md §2`). Gövde `0076_group_time_zone.sql` sürümüdür;
--    TEK fark uzunluk kontrolüdür.
create or replace function public.create_group_with_access(
  p_name text,
  p_visibility text,
  p_member_limit integer,
  p_time_zone text
)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
  uid uuid := auth.uid();
  normalized_name text := btrim(coalesce(p_name, ''));
  normalized_visibility text := lower(btrim(coalesce(p_visibility, 'private')));
  normalized_time_zone text := trim(coalesce(p_time_zone, ''));
  attempt integer;
begin
  if uid is null then
    raise exception 'Oturum bulunamadı';
  end if;
  -- WP-517: 64 -> 30.
  if normalized_name = '' or char_length(normalized_name) > 30 then
    raise exception 'Grup adı 1 ile 30 karakter arasında olmalı.';
  end if;
  if normalized_visibility not in ('private', 'public') then
    raise exception 'Geçersiz grup görünürlüğü.';
  end if;
  if p_member_limit not between 2 and 8 then
    raise exception 'Üye sınırı 2 ile 8 arasında olmalı.';
  end if;
  if not public.is_valid_group_time_zone(normalized_time_zone) then
    raise exception 'invalid_group_time_zone';
  end if;

  for attempt in 1..8 loop
    begin
      insert into public.groups (
        name, invite_code, created_by, visibility, member_limit, time_zone
      ) values (
        normalized_name,
        public.gen_invite_code(),
        uid,
        normalized_visibility,
        p_member_limit,
        normalized_time_zone
      ) returning * into g;

      insert into public.group_members (group_id, user_id, role)
        values (g.id, uid, 'admin');
      return g;
    exception when unique_violation then
      continue;
    end;
  end loop;

  raise exception 'Grup oluşturulamadı, tekrar deneyin.';
end;
$$;

grant execute on function public.create_group_with_access(text, text, integer, text)
  to authenticated;

commit;
