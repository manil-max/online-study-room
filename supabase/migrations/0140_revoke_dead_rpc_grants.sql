-- 0140_revoke_dead_rpc_grants.sql
-- WP-807: hiçbir istemcinin çağırmadığı **iki** RPC'nin `authenticated`
-- grant'ı kaldırılır. **Gövdeler durur**, yalnız kullanıcıya açık yüzey daralır.
--
-- Ölü özellik denetiminin (2026-09-07) C maddesi. Denetim dört aday saydı;
-- ikisi kaldırıldı, ikisi kaldırılmadı ve nedenleri aşağıda yazılı. Sayının
-- düşmesi ölçümün sonucudur: 'çağrılmıyor' ile 'kaldırılabilir' aynı şey
-- değil.
--
-- 🔴 Neden gövde silinmiyor: bunlar bozuk değil, **kullanılmıyor**. Silmek
-- rollback notlarını ve migration metnini okuyan testleri kırardı
-- (`0120`'nin geri alma yolu `record_goal_completion`a dayanır,
-- `goal_streak_parity_wp453_test.dart:99` migration METNİNİ okur). Yüzeyi
-- daraltmak yeterli: `grant` bir satır, geri gelmesi de bir satır.
--
-- Geri alma (Rollback): ilgili `grant execute ... to authenticated` satırını
-- yeniden çalıştır. Hiçbir veri değişmez.
--
-- ---------------------------------------------------------------------------
-- DOKUNULMAYAN — bilerek
--
-- `admin_reporter_abuse_score(uuid)` (`0105:443`) ÖLÜ GRANT DEĞİLDİR:
-- `supabase/tests/035` ve `064` onu çağırıyor, `0137:21-23` `admin_user_insight`
-- ten AYRI bir sözleşme olduğunu açıklıyor ve `ADMIN-PANEL-PLAN.md:278` onu
-- bilinen bir ÜRÜN boşluğu olarak listeliyor. Sorun grant değil, panelde
-- ekranının olmaması. Grant duruyor.
--
-- `create_group(text)` (`0012:50`) da DOKUNULMUYOR ve bu bir karardır:
-- `0032` ve `0071` gövdeyi "eski istemciler için" bilerek bırakmış. Sahada
-- `create_group_with_access` öncesi bir APK kalmışsa grant'ı kaldırmak grup
-- kurulumunu kırardı. Head 0140'a göre öyle bir istemci çok eski olurdu ama
-- bu bir ÜRÜN kararıdır, temizlik kararı değil — sahibin bilgisi olmadan
-- alınmaz.

-- 1) Başarım XP uzlaştırma — self-servis ekranı hiç yazılmadı.
revoke execute on function public.my_achievement_xp_reconciliation()
  from authenticated;
comment on function public.my_achievement_xp_reconciliation() is
  'WP-807: gövde durur, `authenticated` grant''ı kaldırıldı — çağıran ekran '
  'hiç yazılmadı. Destek gerekirse tek satır grant geri gelir.';

-- 2) Eski başarım denetimi — gerçek kullanıcısı destek/operasyon, yani
--    `service_role`. Yetki kapısı zaten sağlamdı (`0050:427-429`), bu bir
--    güvenlik düzeltmesi değil, yüzey daraltma.
revoke execute on function public.achievement_legacy_audit(uuid)
  from authenticated;
comment on function public.achievement_legacy_audit(uuid) is
  'WP-807: gövde durur, `authenticated` grant''ı kaldırıldı — operasyon '
  'aracıdır, kullanıcı yüzeyi değil.';

-- ---------------------------------------------------------------------------
-- 🔴 3) `record_goal_completion(text, uuid, date)` — REVOKE EDİLMEDİ.
--
-- İlk taslakta bu da kaldırılıyordu ("üretim yazıcısı artık tetikleyici").
-- Staging kuru koşusu iki turda iki ayrı şey öğretti ve ikincisi kararı
-- DEĞİŞTİRDİ:
--
--   Tur 1 (run 34137055615): `revoke ... from authenticated` HİÇBİR ŞEY
--   yapmadı. PostgreSQL fonksiyona `EXECUTE`i varsayılan olarak `PUBLIC`e
--   verir; `0112`/`0120` burada `revoke ... from public` yapmamış, yani
--   `authenticated` yetkiyi PUBLIC'ten miras alıyordu. Üstteki iki fonksiyon
--   bu tuzağa düşmedi çünkü kendi migration'larında (`0047:415`, `0050:497`)
--   PUBLIC revoke'u zaten vardı. Sözdizimi geçerliydi, hata vermedi, etkisi
--   sıfırdı — "revoke yazdım" ile "yetki kalktı" aynı şey değildir.
--
--   Tur 2 (run 34137437787): `from public, anon, authenticated` yazınca revoke
--   GERÇEKTEN çalıştı ve ÜÇ mevcut pgTAP dosyası kırmızıya döndü —
--   `037_goal_streak_projection:200`, `038_progression_matrix:135`,
--   `045_goal_completion_writer:293`. Hepsi `set role authenticated` ile bu
--   RPC'yi çağırıp koruma kapılarını KANITLIYOR: *"başkasının kişisel serisi
--   yazılamaz"*, *"geleceğe seri yazılamaz: cihaz saatini ileri almak işe
--   yaramaz"*, *"hedefe ulaşılmadan tamamlama kaydı yazılmaz"*.
--
-- Yani bu bir ÖLÜ grant değil, **korumaları etkin biçimde kanıtlanmış bir
-- yüzey**. Kaldırmak yüzeyi değil, `0112` sözleşmesinin kanıtını silerdi:
-- kimse çağıramayınca "çağıran da yazamaz" iddiası boşa düşer.
--
-- Aynı ölçüt `create_group(text)` ve `admin_reporter_abuse_score(uuid)` için
-- de kullanıldı: çağrılmıyor olmak tek başına kaldırma gerekçesi değildir.
-- ---------------------------------------------------------------------------

notify pgrst, 'reload schema';
