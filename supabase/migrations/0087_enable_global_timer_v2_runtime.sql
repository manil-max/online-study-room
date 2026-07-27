-- 0087_enable_global_timer_v2_runtime.sql
-- WP-368 (V51-2): global timer V2 sunucu anahtarını aç.
--
-- `apply_global_timer_command` ilk işi olarak runtime bayrağına bakar
-- (`0082:217`) ve kapalıysa `global_timer_v2_disabled` fırlatır. Bayrak
-- 0082'de `false` tohumlandı ve hiçbir ortamda açılmadı. Yani istemci
-- tarafındaki `foregroundMirror` kademesi açık olsa ve komut sunucuya
-- ulaşsa bile **her komut reddediliyordu**; hata istemcide yutulduğu için
-- bu dışarıdan "senkron çalışmıyor" olarak görünüyordu.
--
-- İstemci düzeltmesi (WP-368, komutun başlatma anında yayınlanması) bu bayrak
-- kapalıyken hiçbir şey değiştirmez; ikisi birlikte anlamlıdır.
--
-- Bu migration tablo/kolon/politika değiştirmez, yalnız tek satırlık singleton
-- yapılandırmanın değerini günceller.
--
-- Geri alma (Rollback): `update public.global_timer_v2_runtime_config
-- set v2_enabled = false where singleton;` — anında etkilidir, sürüm
-- gerektirmez. V2'nin sunucu tarafı kill switch'i budur.

update public.global_timer_v2_runtime_config
set v2_enabled = true,
    updated_at = clock_timestamp()
where singleton;

-- Satır hiç yoksa (0082 seed'i atlanmış bir ortam) açık olarak kur.
insert into public.global_timer_v2_runtime_config (singleton, v2_enabled)
values (true, true)
on conflict (singleton) do update set
  v2_enabled = true,
  updated_at = clock_timestamp();
