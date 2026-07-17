# Faz 0A — Repo ve Doküman Gerçeği Denetimi (WP-37)

> **Tarih:** 2026-07-12 · **Sorumlu:** Codex (Claude/Opus taslağı devralındı)
> **Kapsam:** Yalnız tespit ve uzlaştırma önerisi; uygulama kodu, migration ve diğer dokümanlar değiştirilmedi. Canlı backend/deploy durumu WP-38'in konusudur.

## Kanıt ve yöntem

- `Kodda doğrulandı`: kaynak, migration veya git geçmişi doğrudan okundu.
- `Cihazda doğrulanmalı`: gerçek Android/OEM davranışı için ekran kaydı veya test cihazı gerekir.
- `Canlıda doğrulanmalı`: Supabase şeması, RLS veya Edge Function deploy'u canlı ortamda teyit edilmelidir.
- `Ürün kararı gerekiyor`: kullanıcı/ürün sahibi onayı olmadan kapatılamaz.

Bu denetimde `flutter analyze` **0 sorunla**, `flutter test --dart-define-from-file=env.json` **254 testle** geçti. Bu sonuç otomatik test aşamasını destekler; cihaz QA, canlı backend veya ürün kabulü kanıtı değildir.

İş durumları: `Planlandı → Geliştiriliyor → Kod tamamlandı (KT) → Otomatik test geçti (OT) → Gerçek cihaz QA geçti → Ürün kabulü geçti → Yayınlandı → Yayın sonrası doğrulandı`.

## 1. WP-1–36 yeniden sınıflandırması

> Aşağıdaki aşama, repoda doğrulanabilen **en yüksek güvenli aşamadır**. Gerçek cihaz QA ve ürün kabulü kanıtı bulunmadığı için hiçbir satır bu denetimde bunların üstüne çıkarılmadı. `OT*`, mevcut genel test paketinin geçtiğini; o WP için cihaz/canlı davranış kanıtı olmadığını belirtir.

| WP | Kapsam | En yüksek kanıtlanabilir aşama | Kısa gerekçe | Etiket |
|---|---|---|---|---|
| 1 | Android Widget Foundation | KT | Üç provider tanımlı; stats/leaderboard gerçek veri almıyor. | `Kodda doğrulandı` |
| 2 | Kalıcı bildirim ve arka plan timer | KT | Foreground service yok; dış komut lifecycle'a bağlı. | `Kodda doğrulandı` |
| 3 | Auth recovery | OT* | Recovery akışı kaynakta var; gerçek e-posta/deep-link kanıtı yok. | `Cihazda doğrulanmalı` |
| 4 | Home responsive QA | OT* | Dashboard render/taşma testleri mevcut; cihaz matrisi yok. | `Kodda doğrulandı` |
| 5 | Presence lifecycle | OT* | Heartbeat/lifecycle kaynakta var; canlı presence davranışı kanıtsız. | `Cihazda/canlıda doğrulanmalı` |
| 6 | Android surface extensions | KT | Kilit ekranı görünümü OEM'e bağlı. | `Cihazda doğrulanmalı` |
| 7 | Class chat | OT* | Migration ve çift repository var; canlı RLS/realtime kanıtsız. | `Canlıda doğrulanmalı` |
| 8 | Nudge + notifications | OT* | Kod var; bildirim teslimatı/OEM davranışı kanıtsız. | `Cihazda doğrulanmalı` |
| 9 | Gamification | KT | Eski dört-kural motoru, yeni motorla paralel kalıyor. | `Kodda doğrulandı` |
| 10 | Class metrics pack | OT* | Grup metrik kaynakları var; yüzeyler arası parity henüz denetlenmedi. | `Kodda doğrulandı` |
| 11 | Windows desktop track | KT | EXE izi var; installer ve desktop polish eksik. | `Kodda doğrulandı` |
| 12 | Sync & offline track | OT* | Offline-first katmanı var; idempotency/reconciliation denetimi yok. | `Kodda doğrulandı` |
| 13 | Release channels | OT* | Stable/beta ve updater kaynakta; yayın sonrası doğrulama kanıtı yok. | `Kodda doğrulandı` |
| 14 | Güvenli admin + feedback temeli | KT | Migration/Edge Function var; canlı deploy ve RLS teyidi yok. | `Canlıda doğrulanmalı` |
| 15 | Device integrations spike | KT | Native kısayol köprüsü var; cihaz matrisi yok. | `Cihazda doğrulanmalı` |
| 16 | Dashboard advanced polish | OT* | Dashboard testleri geçiyor; ürün kabulü kanıtı yok. | `Kodda doğrulandı` |
| 17 | Android canlı sayaç yüzeyleri | KT | Timer güvenilirliği foreground service olmadan kanıtlanamaz. | `Cihazda doğrulanmalı` |
| 18 | Grup ekranı hiyerarşisi | OT* | UI kaynakta; ürün kabulü/cihaz kanıtı yok. | `Cihazda doğrulanmalı` |
| 19 | Device integration settings hook | KT | Ayar kancası var; native etki kanıtsız. | `Cihazda doğrulanmalı` |
| 20 | Özelleştirilebilir saat stilleri | OT* | Kod ve test paketi var; backlog hâlâ planlı diyor. | `Kodda doğrulandı` |
| 21 | Gelişmiş grid boyutlandırma | OT* | Reflow testleri var; backlog hâlâ planlı diyor. | `Kodda doğrulandı` |
| 22 | Canlı grup hedefi animasyonu | KT | Kod var; süre/reduce-motion kabulü yok. | `Cihazda doğrulanmalı` |
| 23 | Clock Center + StandBy | KT | Saat, bağımsız saat deneyimi değil; alarm/timer IA'ya bağlı değil. | `Kodda doğrulandı` |
| 24 | Alarm + çoklu timer temeli | KT | Ekranlar var; exact-alarm ve reboot recovery kanıtı yok. | `Cihazda doğrulanmalı` |
| 25 | 3 tuşlu navigasyon safe area | KT | Kaynak değişikliği var; hedef Samsung cihaz kanıtı yok. | `Cihazda doğrulanmalı` |
| 26 | Tema paleti + özel slotlar | KT | 11 palet ortak zemin/kart yüzeylerini kullanıyor. | `Kodda doğrulandı` |
| 27 | Windows desktop shell | Planlandı | Kod/teslim kanıtı yok. | `Kodda doğrulandı` |
| 28 | Windows dağıtım ve polish | Planlandı | WP-27'ye bağımlı; installer henüz yok. | `Kodda doğrulandı` |
| 29 | Stable/beta ikon ve branding | OT* | Branding kaynakta ve v7 etiketi var; ürün kabulü kanıtı yok. | `Kodda doğrulandı` |
| 30 | Release notes + updater dialog | OT* | Updater özelliği kaynakta; gerçek güncelleme yolu kanıtsız. | `Cihazda doğrulanmalı` |
| 31 | Hesabımı yönet merkezi | KT | Recovery/e-posta akışı var; canlı auth doğrulaması yok. | `Cihazda/canlıda doğrulanmalı` |
| 32 | Geri bildirim ekran görüntüsü eki | KT | `0019` yerelde var; Storage/RLS canlı durumu bilinmiyor. | `Canlıda doğrulanmalı` |
| 33 | Güvenli süper-admin işlemleri | KT | `0020` ve Edge Function yerelde var; deploy kanıtı yok. | `Canlıda doğrulanmalı` |
| 34 | Admin paneli, moderasyon, duyurular | KT | `0021` ve Edge Function yerelde var; deploy kanıtı yok. | `Canlıda doğrulanmalı` |
| 35 | Sosyal profil 2.0 + başarı yolculuğu | KT | XP istemci yazımı ve geniş RLS, ürünün güvenlik hedefini bozuyor. | `Kodda doğrulandı` |
| 36 | Beş sekmeli IA + bildirim merkezi | OT* | Beş sekme/bildirim merkezi kaynakta; canlı `0023` kanıtı yok. | `Canlıda doğrulanmalı` |

**Sonuç:** `progress.md` içindeki “Tamamlanan İş Paketleri” başlığı tarihsel kod teslimlerini gösterir; yeni kalite tanımındaki “Ürün kabulü geçti” anlamına gelecek cihaz ve ürün kanıtlarını göstermiyor.

## 2. Özellik envanteri

| Alan | Gerçek davranış | Açık/eksik | Kanıt |
|---|---|---|---|
| Sayaç | Stopwatch/countdown/pomodoro state'i ve dış komut kuyruğu var. | Native timer state store, foreground service, boot restore ve 8 saat doğruluğu yok. | `Kodda doğrulandı` — `study_providers.dart:371-374` |
| Bildirim | Kalıcı bildirim ve `TimerActionReceiver` var. | Native `Chronometer` ve uygulama açılmadan güvenilir kontrol yok. | `Kodda doğrulandı` / `Cihazda doğrulanmalı` |
| Widget | Timer, stats ve leaderboard provider'ları manifestte var. | Besleme yalnız timer snapshot'ı; stats/leaderboard placeholder. | `Kodda doğrulandı` — manifest:54-81, provider:656-678 |
| Senkron | Offline-first repository ve RPC agregasyonları var. | Canonical projection, standart invalidation/idempotency ve çoklu cihaz mutabakatı yok. | `Kodda doğrulandı` |
| Saat | Büyük dijital saat, StandBy ve ayrı alarm/timer ekranları var. | Dünya saati ve bağımsız Saat IA'sı; exact alarm/reboot recovery yok. | `Kodda doğrulandı` |
| Tema | 11 hazır palet ve özel slotlar var. | Ortak `_bg`/`_card` yüzeyleri nedeniyle tema aileleri farklı atmosfer oluşturmuyor; semantic token motoru yok. | `Kodda doğrulandı` |
| Başarım | Dört-kural eski motor ile 10×6 yeni motor birlikte duruyor. | Tek motor, server-authoritative XP ledger ve idempotent ödül yok. | `Kodda doğrulandı` |
| Sosyal profil | Vitrin, rozet, XP ve taç alanları var. | `0022` erişimi ortak grup üyeliğiyle sınırlamıyor. | `Kodda doğrulandı` / `Canlıda doğrulanmalı` |
| Gruplar | Üyelik, hedef, presence, kamp ateşi, sıralama ve trend var. | Kamp ateşinin sırası, animasyon süresi/reduce-motion WP-45'te. | `Kodda doğrulandı` |
| İstatistik | Saf istatistik fonksiyonları ve çoklu kartlar var. | Sıralama sırası ve canonical projection eksik. | `Kodda doğrulandı` |
| Admin | Çok sekmeli panel, migrations ve iki Edge Function mevcut. | Canlı deploy/RLS doğrulanmadı. | `Canlıda doğrulanmalı` |

## 3. Bilinen bug listesi

### P0 — v8 blocker

| ID | Bulgu | Kanıt | Gerekli aksiyon |
|---|---|---|---|
| P0-1 | `0022`, hem `user_achievements` hem `gamification_profiles` için `using (true)` ile tüm authenticated kullanıcılara okuma açıyor. | `Kodda doğrulandı` — `0022_social_profile_progression.sql:42-46,83-87` | Ortak aktif grup üyeliğine dayalı RLS migration'ı, canlı uygulama ve RLS testi. |
| P0-2 | Başarım/XP istemcide hesaplanıp repository üzerinden yazılıyor; append-only ledger ve olay idempotency'si yok. | `Kodda doğrulandı` — `gamification_providers.dart:52-67` | Server-side evaluator + benzersiz event key + XP ledger. |
| P0-3 | Foreground service/boot receiver yok; aktif sayaç ve dış komutlar güvenilir lifecycle garantisine sahip değil. | `Kodda doğrulandı` — `study_providers.dart:371-374`; manifest | WP-40 ve Samsung/Pixel cihaz QA. |

### P1 — temel beklenti/güvenilirlik açığı

| ID | Bulgu | Kanıt |
|---|---|---|
| P1-1 | Stats ve leaderboard widget'ları placeholder kalıyor. | `Kodda doğrulandı` |
| P1-2 | Yeni başarı motorunda seri, kusursuz hafta ve grup günleri hesapları eksik/hardcoded. | `Kodda doğrulandı` |
| P1-3 | İki paralel başarı motoru farklı XP/taç kaynağı üretiyor. | `Kodda doğrulandı` |
| P1-4 | Bildirimde canlı `HH:MM:SS` ve uygulama açmadan güvenilir Başlat/Durdur yok. | `Cihazda doğrulanmalı` |
| P1-5 | Saat sekmesi bağımsız saat ürünü değil; Dünya Saati ve bütünleşik alarm/timer IA'sı yok. | `Kodda doğrulandı` |
| P1-6 | Paletler çoğunlukla aynı görünümde. | `Kodda doğrulandı` |
| P1-7 | Tüketiciler için tek istatistik projection'ı ve idempotency standardı yok. | `Kodda doğrulandı` |
| P1-8 | Reboot sonrasında aktif sayaç geri yüklenmiyor. | `Kodda doğrulandı` / `Cihazda doğrulanmalı` |

### P2 — cila ve doküman tutarlılığı

- Başarımlar ayarların altında gömülü; profil ana eylemi değil. `Kodda doğrulandı`
- İstatistikte sıralama ve Gruplar'da kamp ateşi istenen sırada değil. `Ürün kararı gerekiyor`
- Kamp ateşi animasyonu için ölçülebilir süre/reduce-motion kanıtı yok. `Cihazda doğrulanmalı`
- Windows installer ve masaüstü polish WP-27/28'de bekliyor. `Kodda doğrulandı`

## 4. Risk kaydı ve v8 blocker'ları

| Risk | Etki | Azaltım |
|---|---|---|
| Yerel `0020–0023` canlıda yoksa admin/başarım/bildirim sessizce kırılır. | Yüksek | WP-38 matrisi ve sırayla canlı doğrulama. |
| İstemci XP yazımı liderlik ve rütbeyi manipüle edilebilir bırakır. | Yüksek | P0-2 server-authoritative dönüşüm. |
| Sosyal profil RLS'i mahremiyet ihlali yaratır. | Yüksek | P0-1 migration, canlı RLS testi. |
| Foreground service OEM pil kısıtında bekleneni vermez. | Orta | Faz 0B Samsung/Pixel test matrisi. |
| Otomatik testler native, OEM ve canlı Supabase akışlarını kapsamıyor. | Yüksek | Integration, native ve cihaz QA kanıtı. |

**v8 stable blocker listesi:** P0-1, P0-2, P0-3; placeholder widget'ların kaldırılması (WP-42); native chronometer kontrolü (WP-41); canonical projection/idempotency (WP-43); WP-38 canlı durumunun kesinleşmesi; Faz 0B cihaz/integration testleri; Samsung cihaz QA, en az üç günlük beta soak ve rollback planı.

## 5. Doküman tutarsızlıkları ve öneriler

> Bunlar öneridir; WP-37 kapsamında diğer dokümanlar değiştirilmedi.

| ID | Bulgu | Öneri |
|---|---|---|
| D1 | `project.md`, 0007/0012'nin atlandığını söylüyor; bu migration dosyaları repoda var. | Migration tablosunu 0001–0023 yerel gerçeklikle tamamla. |
| D2 | `project.md`, 0014–0017'yi atlıyor ve 0019–0023'ü “planlandı” diyor; dosyalar yerelde mevcut. | “Yerelde var; canlı durum WP-38'de” ifadesini kullan. |
| D3 | `backlog.md`, WP-20/21/22/26 ve Saat 23/24'ü hâlâ planlı/genişletiliyor gösteriyor. | Tarihsel kod teslimini `[x]`, kalite seviyesini bu denetim tablosuna bağla. |
| D4 | Backlog widget ve arka plan süre tutmayı tamamlanmış gösteriyor. | V8-A eksiklerini açıkça belirt; yanıltıcı tamamlandı işaretini kaldır. |
| D5 | `project.md` veri modelinde bazı başarı/hatırlatıcı tablo isimleri migration'lardan farklı. | Gerçek adları `gamification_profiles`, `user_achievements`, `study_reminders`, `announcement_reads` olarak düzelt. |
| D6 | `progress.md` “19 kart türü” iddiasının kaynak sayımı bu denetimde doğrulanmadı. | `card_picker.dart` üzerinden say veya yaklaşık olduğunu yaz. |
| D7 | Kalite programında “10 palet” deniyor, kaynakta 11 palet var. | Sayıyı 11 yap. |
| D8 | Bazı eski test/yorumlar dört sekme terminolojisini taşıyor. | Beş sekmeli IA'ya göre test ve yorumları ilgili WP'de güncelle. |

## Kapanış

Kabul kriterleri karşılandı: bu belge WP-1–36 yeniden sınıflandırmasını, özellik envanterini, P0/P1/P2 listesini, risk ve v8 blocker kaydını, ayrıca belge uzlaştırma önerilerini kanıt etiketleriyle içerir. `app/` altında çalışma değişikliği yoktur. Canlı durumlar için sonraki bağımlılık WP-38, doküman düzeltmelerinin uygulanması ise `Ürün kararı gerekiyor`.
