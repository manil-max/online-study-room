-- 0140_revoke_dead_rpc_grants.sql
-- WP-807: hiçbir istemcinin çağırmadığı dört RPC'nin `authenticated` grant'ı
-- kaldırılır. **Gövdeler durur**, yalnız kullanıcıya açık yüzey daralır.
--
-- Ölü özellik denetiminin (2026-09-07) C maddesi. Dördü de bağımsız olarak
-- doğrulandı: `app/lib` ve `supabase/functions` içinde tek çağrı yok.
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

-- 3) Hedef tamamlama yazımı `0120`de sunucu tetikleyicisine taşındı
--    (`_record_goal_completion`). Genel RPC'yi kimse çağırmıyor; AGENTS §2
--    "server-authoritative" gereği gereksiz yazma yüzeyi.
-- 🔴 BURADA `authenticated`tan almak YETMEZ ve bunu staging kuru kosusu
-- yakaladi (run 34137055615, "Failed test 3"). PostgreSQL bir fonksiyon
-- yaratildiginda `EXECUTE`i VARSAYILAN OLARAK `PUBLIC`e verir. `0112` ve
-- `0120` bu fonksiyonda `revoke ... from public` yapmamis; dolayisiyla
-- `authenticated` yetkiyi kendi grant'indan degil PUBLIC'ten MIRAS aliyordu
-- ve yalniz ondan revoke etmek hicbir sey degistirmiyordu.
--
-- Ust iki fonksiyon bu tuzaga dusmedi cunku kendi migration'larinda
-- (`0047:415`, `0050:497`) PUBLIC revoke'u zaten vardi.
--
-- Ders: "revoke yazdim" ile "yetki kalkti" ayni sey degildir; olculmeden
-- bilinmez. Testin `has_function_privilege` ile OKUYARAK olcmesi bu yuzden.
revoke execute on function public.record_goal_completion(text, uuid, date)
  from public, anon, authenticated;
comment on function public.record_goal_completion(text, uuid, date) is
  'WP-807: gövde durur (0120 rollback yolu ona dayanır), `authenticated` '
  'grant''ı kaldırıldı — üretim yazıcısı artık tetikleyicidir.';

notify pgrst, 'reload schema';
