# progress.md — İlerleme Takibi

> Son güncelleme: 2026-07-23 (post-v43 adli uyumlama ve kurtarma planı)
> Kanonik program: `docs/KALITE-PROGRAMI.md` · Kurallar: `.agents/AGENTS.md`
> **“Tamamlandı” = gerçek cihaz QA + ürün kabulü.** Kod/test/yayın kanıtı tek başına tamamlanma değildir.

---

## Proje Gerçekleri

- **Stable gerçek:** `v43` · `1.0.43+43` · commit `fa771ce` · production backend · migration head `0065`.
- **Beta deney gerçeği:** `beta-v4303` · `1.0.43-beta.3+4303` · commit `3bdf8bb` · staging backend · migration head `0068`.
- **Beta artefakt durumu:** Android APK yayımlandı; beta-v4303 Windows MSIX/ZIP workflow'u iki zamanlama testinde düştüğü için release **kısmi** kaldı.
- **Migration gerçeği:** local/staging `0068`; production `0065`. `0066–0068` production'a uygulanmadı.
- **Production kararı:** Yeni stable tag, production migration/Edge deploy ve production mutasyonu **HOLD**. Somut işlem için staging kabulü + soak + backup/dry-run + açık kullanıcı GO gerekir.
- **Açık yönetim çelişkisi:** `tooling/release/deploy-contract.json` production `deploy_enabled/release_enabled` değerleri bugün açık; bu güvenli varsayılan değildir ve WP-269'da kapatılacaktır.
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md`, planner ve worker kuralları v43 sonrasında silinmedi/değiştirilmedi.
- **Git:** Tek çalışma dalı `main`; branch/merge/push kullanıcı açıkça istemedikçe yok.
- **Son WP numarası:** **274**. Sıradaki boş numara **WP-275**.
- **Kanonik olay raporu:** [`docs/KURTARMA-ON-INCELEME-RAPORU-2026-07-23.md`](docs/KURTARMA-ON-INCELEME-RAPORU-2026-07-23.md)
- **Tarihsel kayıt:** Eski WP ayrıntıları [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md) ve git geçmişindedir; canlı dosyaya geri kopyalanmaz.

---

## ⚡ Aktif Çalışma Kaydı

> Yalnız o anda gerçekten dosya yazan ajan “Aktif” görünür. Park/test bekleyen işler lane tutmaz.

### Gemini Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** `main`
- **Başlangıç / Son güncelleme:** —
- **Not:** —

### Claude Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** `main`
- **Başlangıç / Son güncelleme:** —
- **Not:** —

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** `main`
- **Başlangıç / Son güncelleme:** — / 2026-07-23 (Europe/Istanbul)
- **Not:** Post-v43 kayıt hijyeni ve WP-269–274 planı tamamlandı.

### Codex-2 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** `main`
- **Başlangıç / Son güncelleme:** —
- **Not:** —

### Grok Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** `main`
- **Başlangıç / Son güncelleme:** —
- **Not:** —

---

## Öncelik ve Yürütme Sırası

| Sıra | İş | Durum | Başlatma kuralı |
|---|---|---|---|
| 0 | Stable/production freeze | 🔴 HOLD | WP-271 kabulü ve soak olmadan kaldırılmaz |
| 1A | WP-269 Release kapılarını sadeleştir | [ ] Bekliyor | Hemen claim edilebilir |
| 1B | WP-270 Push retry/health motoru | [ ] Bekliyor | WP-269 ile paralel olabilir |
| 1C | WP-272 v43 sayaç paneli sözleşmesi | [ ] Bekliyor | WP-269/270 ile paralel olabilir; en fazla iki lane kuralına uy |
| 2A | WP-271 Staging gerçek push kabulü | [ ] Bekliyor | WP-269 + WP-270 kabulünden sonra |
| 2B | WP-273 Windows deterministik release | [ ] Bekliyor | WP-269'dan sonra |
| Karar | WP-274 Tools erişim kararı | [?] Ürün kararı gerekiyor | Kullanıcı yön seçmeden worker başlamaz |

> **Çakışma matrisi:** WP-269 workflow/tooling, WP-270 Supabase+push, WP-272 Android native sayaç yüzeyindedir; SAHİP dosyaları kesişmez. WP-271, WP-269/270 çıktısını staging'e taşıdığı için seridir. WP-273, `.github/workflows/windows-release.yml` nedeniyle WP-269 sonrasıdır. Aynı anda en fazla iki lane açılır.

---

## Kurtarma Plan Kuyruğu

### WP-269: Release ve Database Gates Sadeleştirmesi 🧭
- **Program/Faz:** Kurtarma · Faz 1 — release yönetişimi
- **Ajan:** —
- **Durum:** [ ] Bekliyor
- **Problem:** Database apply, tam Flutter test/build ve beta aday APK aynı zincire bağlanmış; production bayrakları açık kalmış; Android/Windows release kısmi tamamlanabiliyor.
- **Kapsam dışı:** Feature kodu, yeni migration, staging/production apply, tag/push/release, GitHub production secret'larını okuma.
- **SAHİP dosyalar (yaz):** `.github/workflows/database-gates.yml`, `.github/workflows/release.yml`, `.github/workflows/windows-release.yml`, `tooling/release/**`, `tooling/supabase/guard.tests.ps1`, `docs/recovery/RELEASE-GATE.md`.
- **DOKUNMA (oku, değiştirme):** `app/lib/**`, `app/android/**`, `supabase/migrations/**`, `supabase/functions/**`, Firebase dosyaları.
- **Adımlar:**
  - [ ] Database Gates'i list→dry-run→apply→pgTAP/post-check ile sınırla; Flutter/APK aday build'ini ayır.
  - [ ] Production deploy/release varsayılanını kapat; kalıcı açık flag yerine tek kullanımlık exact SHA/head/GO doğrulaması tasarla.
  - [ ] “beta preflight” ve “stable preflight” için tek giriş noktası ve kısa kanıt özeti üret.
  - [ ] Android/Windows artefakt durumunu `partial|complete|failed` olarak tek manifestte göster; release'i ancak zorunlu artefaktlar tamamlanınca finalize et.
  - [ ] Repo dışı sahip aksiyonu olarak GitHub `production` Environment required reviewer kurulumunu açık checklist'e yaz.
- **Veri/Migration etkisi:** Yok. Rollback, yalnız workflow/tooling commit'ini geri almaktır.
- **Ortam/Deploy:** Local + CI dry-run; remote apply, tag ve yayın yok. Production HOLD korunur.
- **RLS/Güvenlik:** Secret çıktısı 0; environment/channel/SHA/head fail-closed; required-reviewer eksikliği görünür blokerdir.
- **Edge-case'ler:** Windows artefaktı geç kalır, rerun aynı release'i iki kez finalize eder, staging head production head'den ileridedir, eski tag tekrar çalıştırılır.
- **Kabul (ölçülebilir):** Staging DB apply job'ında Flutter setup/build adımı 0; guard testleri production varsayılanını kapalı kanıtlar; preflight yanlış SHA/head/channel'da exit≠0; kısmi release “complete” görünmez; tüm tooling testleri yeşil.
- **Tuzaklar:** Kalite kapısını silmek yerine doğru olaya taşımak; GitHub reviewer ayarını repo koduyla yapılmış saymak; eski production açık flag'ini korumak.
- **Model önerisi:** 🔴 Opus / frontier-high

### WP-270: Push Retry Worker, Salt-Okunur Health ve Kuyruk Gözlemi 📬
- **Program/Faz:** Kurtarma · Faz 2 — bildirim güvenilirliği
- **Ajan:** —
- **Durum:** [ ] Bekliyor
- **Problem:** Outbox/retry/lease state'i var fakat zamanlanmış worker yok; geçici hata sonrası kayıt süresiz bekleyebilir. Mevcut “health” çağrısı iş claim edip gönderim yapabiliyor.
- **Kapsam dışı:** Production deploy, beta tag/release, Android sayaç görünümü, pazarlama segmentasyonu.
- **SAHİP dosyalar (yaz):** yeni `supabase/migrations/0069_*`, `supabase/functions/dispatch-push/**`, `supabase/tests/**`, `app/lib/core/notifications/**`, ilgili notification health UI/repository/provider testleri.
- **DOKUNMA (oku, değiştirme):** release workflow'ları ve `tooling/release/deploy-contract.json` (WP-269/271), Android timer FGS/layout (WP-272), production.
- **Adımlar:**
  - [ ] Kimlik bilgisi güvenli, periyodik dispatcher tetikleyicisi kur; retry zamanı gelen işi yeniden claim et.
  - [ ] Salt-okunur health/status yolunu work/dispatch yolundan ayır.
  - [ ] Stuck lease recovery, queue depth/oldest age/attempt/error code ölçümlerini ekle.
  - [ ] Self-test UI'da transport/config/timeout/server/FCM hata sınıfını görünür yap.
  - [ ] Gerçek PostgreSQL fixture'ıyla transient hata→backoff→başarı ve invalid-token kapanışını test et.
- **Veri/Migration etkisi:** Yeni ileri `0069`; remote'a uygulanmış `0066–0068` değişmez. Rollback cron/tetikleyiciyi durdurur, yeni enqueue'yu kapatır; outbox/delivery kanıt satırlarını silmez.
- **Ortam/Deploy:** Önce local full replay + pgTAP + Edge type-check. Staging terfisi WP-271; production yok.
- **RLS/Güvenlik:** Service-role/client'a çıkmaz; health hassas token/payload göstermez; client direct-DML reddi korunur; tetikleyici secret'ı DB log'una yazılmaz.
- **Edge-case'ler:** Çakışan iki worker, lease sırasında crash, 429/5xx, bozuk service account, token refresh/logout, aynı hesap iki cihaz, büyük fan-out.
- **Kabul (ölçülebilir):** Geçici hata fixture'ı `next_attempt_at` sonrası ek kullanıcı çağrısı olmadan yeniden işlenir; iki worker duplicate teslim üretmez; health çağrısı öncesi/sonrası outbox/delivery satır ve state farkı 0; stuck lease belirlenen eşiğin ardından geri alınır; local `0001→0069` replay + pgTAP + Edge type-check yeşil.
- **Tuzaklar:** HTTP health kontrolünü work endpoint'ine yöneltmek; her outbox satırından ayrı fan-out fırtınası; secret'ı migration literaline koymak.
- **Model önerisi:** 🔴 Opus / frontier-high

### WP-271: Staging Gerçek Push ve Tek-Cihaz Beta Kabulü 📱
- **Program/Faz:** Kurtarma · Faz 3 — staging kabulü
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-269 + WP-270 otomatik kabulü
- **Problem:** beta-v4303 Android APK ve staging altyapısı yayımlanmış olsa da gerçek FCM teslim, retry, Samsung görünümü ve ölçümlü cihaz kabulü yoktur.
- **Kapsam dışı:** Production migration/secret/function/stable release; yeni feature/fix. Testte bug bulunursa bu WP içinde acele fix yapılmaz, ayrı debug WP açılır.
- **SAHİP dosyalar (yaz):** `tooling/release/deploy-contract.json` (yalnız staging head/HOLD), `docs/qa/DEVICE-QA-MATRIX.md`, `docs/recovery/PUSH-STAGING-ACCEPTANCE.md`, beta kabul kanıt manifestleri ve gerekiyorsa release metadata dosyaları.
- **DOKUNMA (oku, değiştirme):** Feature/native kodu, uygulanmış migration dosyaları, production contract/head.
- **Adımlar:**
  - [ ] Exact staging project-ref için list+dry-run+apply+post-check; dispatcher secret/function ve periyodik tetikleyiciyi doğrula.
  - [ ] Tek staging hesabı/tek Android cihazla foreground, background ve process-terminated remote self-test koş.
  - [ ] Dürtme/duyuru/güncelleme ayrımı, duplicate, token refresh/logout ve zorlanmış transient retry senaryolarını kaydet.
  - [ ] App-kapalı timer paneli/action ve bildirim merkezi hata kodunu aynı adayda doğrula.
  - [ ] Aday gerekiyorsa kullanıcı açıkça istediğinde benzersiz beta tag/release çıkar; önceki tag'i yeniden kullanma.
- **Veri/Migration etkisi:** Kabul edilmiş `0069` yalnız staging'e ileri terfi eder; rollback tetikleyiciyi/dispatcher'ı kapatır, kanıt satırlarını korur.
- **Ortam/Deploy:** Yalnız staging/beta. Production kesinlikle yok.
- **RLS/Güvenlik:** Test hesabı ve redacted kanıt; payload/token/secret ekran görüntüsü/logda 0; cross-user teslim reddi kanıtlanır.
- **Edge-case'ler:** Android “force stop” ile normal process termination ayrılır; Doze/batarya optimizasyonu; ağ kesintisi; eski beta client; iki cihaz ancak temel tek-cihaz kapısı geçtikten sonra.
- **Kabul (ölçülebilir):** En az 20 ölçümlü gerçek remote self-testte duplicate=0, yanlış kullanıcı/cihaz teslimi=0 ve p95≤10 sn; zorlanmış transient hata otomatik retry ile teslim olur; terminated app bildirimi görünür; timer action app açmadan çalışır; P0/P1=0. **Cihazda doğrulanmalı.**
- **Tuzaklar:** Local notification'ı FCM kanıtı saymak; Settings “Force stop” sonrası Android'in teslim engelini ürün bug'ı diye yanlış sınıflandırmak; test sırasında production hedeflemek.
- **Model önerisi:** 🔴 Opus / frontier-high

### WP-272: v43 Sayaç Paneli Sözleşmesi ve Now Bar İzolasyonu ⏱️
- **Program/Faz:** Kurtarma · Faz 2 — Android timer ürün kontratı
- **Ajan:** —
- **Durum:** [ ] Bekliyor
- **Problem:** beta-v4302 kabul edilmiş v43 custom paneli standard notification ile değiştirdi; beta-v4303 paneli büyük ölçüde geri getirdi fakat v43 fallback davranışı ve cihaz kabulü net değildir.
- **Kapsam dışı:** Timer state/session/XP motorunu yeniden yazmak, push/outbox, Samsung private API, stable release.
- **SAHİP dosyalar (yaz):** `app/android/app/src/main/kotlin/**/timer/StudyTimerService.kt`, `app/android/app/src/main/res/layout/timer_notification.xml`, timer notification ikon/manifest yüzeyi, `app/lib/core/background/timer_foreground_service.dart`, ilgili native/source/widget testleri ve cihaz kabul kanıtları.
- **DOKUNMA (oku, değiştirme):** `supabase/**`, push dispatcher, release workflow'ları, timer session persistence/achievement zinciri.
- **Adımlar:**
  - [ ] v43 custom panelini stable ürün kontratı olarak fixture/screenshot sözleşmesine bağla.
  - [ ] v43 fallback flag/davranışını diff ile çıkar; desteklenmeyen cihazda işlevsel standard fallback'i geri kur.
  - [ ] Promoted/Now Bar yolunu stable paneli değiştirmeyen açık deney/diagnostic olarak ayır.
  - [ ] Başlat/Duraklat/Durdur native action, kill/reboot ve uzun sayaç matrisini Samsung'da koş.
- **Veri/Migration etkisi:** Yok. Rollback v43 timer presentation commit/fixture'ına dönüştür.
- **Ortam/Deploy:** Local Android build + beta cihaz QA; tag/stable/production yok.
- **RLS/Güvenlik:** Etki yok; PendingIntent mutability/exported component kontrolleri korunur.
- **Edge-case'ler:** API 29–33/34+, OEM custom-layout kısıtı, font ölçeği, dark/light, reboot, Doze, uygulama güncellemesi sırasında aktif timer.
- **Kabul (ölçülebilir):** Samsung'da v43 referansıyla aynı bilgi hiyerarşisi ve üç action erişilebilir; desteklenmeyen yolda fallback notification kaybolmaz; 8 saatte sapma ≤±1 sn; app-kapalı action başarı oranı 20/20; FGS crash=0. **Cihazda doğrulanmalı.**
- **Tuzaklar:** Now Bar görünümünü garanti etmek; görünüm düzeltirken timer state motoruna dokunmak; kaynak-string testini cihaz kabulü saymak.
- **Model önerisi:** 🔴 Opus / frontier-high

### WP-273: Windows Deterministik Test ve Tam Artefakt Release'i 🪟
- **Program/Faz:** Kurtarma · Faz 4 — Windows release güveni
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-269
- **Problem:** beta-v4303 Windows workflow'u iki timer zamanlama testinde flaky düştü; Android release önce görünür olduğu için release kısmi kaldı.
- **Kapsam dışı:** Store public submission, yeni Windows feature/marka, Android build, production backend/migration.
- **SAHİP dosyalar (yaz):** `app/test/data/timer_background_reconcile_test.dart` ve yalnız ilgili fake-clock/test harness dosyaları, Windows paketleme testleri, `docs/QA-WINDOWS.md`, WP-269 sonrası gerekli dar `.github/workflows/windows-release.yml` düzeltmesi.
- **DOKUNMA (oku, değiştirme):** Timer üretim davranışı (test gerçek bug kanıtlamadıkça), Supabase, Android native, Store identity/asset dosyaları.
- **Adımlar:**
  - [ ] Gerçek zaman/scheduler yarışını fake clock/fake async ile deterministik yap; timeout uzatarak gizleme.
  - [ ] İki hedef testi ardışık en az 20 kez ve tam Windows suite'i çalıştır.
  - [ ] Tag atmadan aynı SHA'dan MSIX+ZIP dry-run üret; SHA/provenance/manifest kontrol et.
  - [ ] Android+Windows zorunlu artefaktlarının release finalize öncesi birlikte hazır olmasını doğrula.
- **Veri/Migration etkisi:** Yok. Rollback test harness/workflow commit'idir.
- **Ortam/Deploy:** Local Windows + CI dry-run; Store/tag/release yok.
- **RLS/Güvenlik:** Paket production secret'ı/log'u sızdırmaz; kanal/backend manifesti fail-closed.
- **Edge-case'ler:** Yavaş GitHub runner, locale/TZ, yeniden koşum, aynı asset'i iki kez yükleme, yalnız Windows veya yalnız Android başarı.
- **Kabul (ölçülebilir):** İki flaky test 20/20 ardışık yeşil; tam Windows suite + build + MSIX/ZIP dry-run yeşil; manifest SHA/commit/channel/head doğru; zorunlu bir artefakt yokken release `complete` olamaz.
- **Tuzaklar:** Sadece timeout büyütmek; üretim kodunu test flake'i için değiştirmek; Android yayımlandıktan sonra Windows'u belirsiz saatlerde eklemek.
- **Model önerisi:** 🟣 Pro / frontier-high

### WP-274: Tools Saat/Kronometre/Dünya Erişim Kararı 🧰
- **Program/Faz:** Kurtarma · Faz 4 — bildirim dışı drift
- **Ajan:** —
- **Durum:** [?] Ürün kararı gerekiyor
- **Problem:** WP-264 Tools girişlerini kaldırdı fakat Stopwatch/World Clock kaynakları duruyor; v43 sonrası kullanıcı görünür kapsam azaldı ve canlı dosyada bu yalnız “sadeleştirme” diye görünüyordu.
- **Önerilen karar:** v43 davranışını koruyup Saat ana yüzeyi/Kronometre/Dünya Saatleri girişlerini geri aç; kalıcı kaldırma isteniyorsa dead dosya/testleri ayrı temizlik olarak sil.
- **Kapsam dışı:** Android study timer/FGS, alarm motoru, push sistemi, navigation mimarisini yeniden tasarlamak.
- **SAHİP dosyalar (yaz):** `app/lib/features/clock/clock_screen.dart`, gerekirse `app/lib/core/navigation/home_shell.dart`, ilgili clock/navigation testleri; kaldırma seçilirse yalnız açıkça listelenen dead Stopwatch/World Clock dosyaları.
- **DOKUNMA (oku, değiştirme):** `app/lib/data/providers/study_providers.dart`, `app/lib/core/notifications/**`, `app/android/**`, release/migration dosyaları.
- **Adımlar:**
  - [ ] Kullanıcı “geri getir” veya “kalıcı kaldır” kararını kayda geçir.
  - [ ] Geri getir seçeneğinde v43 giriş/route davranışını restore edip mobil yatay StandBy'ı koru.
  - [ ] Kaldır seçeneğinde unreachable dosya/test/yorumları kontrollü sil; alarm/timer motoruna dokunma.
  - [ ] Dikey/yatay ve tap-to-top/navigation regresyonlarını test et.
- **Veri/Migration etkisi:** Yok. Rollback tek UI/navigation commit'idir.
- **Ortam/Deploy:** Local only; remote/tag/release yok.
- **RLS/Güvenlik:** Etki yok.
- **Edge-case'ler:** Stopwatch ile çalışma sayacını karıştırma, yatay StandBy, geri tuşu, seçili sekme state'i, desktop navigation.
- **Kabul (ölçülebilir):** Seçilen ürün kararıyla görünür girişler ve fiziksel kaynaklar çelişmez; unreachable ürün ekranı 0; ilgili widget/navigation testleri ve `flutter analyze` yeşil; cihazda dikey+yatay kabul.
- **Tuzaklar:** Ürün kararı almadan dosya silmek; study timer native servislerini Stopwatch sanmak.
- **Model önerisi:** 🟣 Pro

---

## Test / Ürün Kabulü İçin Bekleyenler (Park)

> Bunlar aktif lane değildir. Eski kartı yeniden claim etmek yerine açık eksik için yukarıdaki kurtarma WP'si kullanılır.

| WP | Kanıtlı durum | Açık kabul / karar |
|---|---|---|
| WP-231 | Otomatik test geçti | İki cihazda kişisel ≤1 sn, grup ≤5 sn reconnect/refresh QA |
| WP-254 | Kodlandı ve v43 içinde yayımlandı | İstanbul saat gösterimi gerçek cihaz kabul kaydı eksik |
| WP-259 | Yerel Windows smoke/build/navigation geçti | Temiz VM'de N→N+1 MSIX, uninstall ve DPI matrisi |
| WP-263 | Analyze + hedef/tam test geçti | Gizli rozet rengi cihaz/tema/a11y kabulü |
| WP-264 | Analyze + 670/670 test geçti | Kullanıcı görünür özellik kaybı; WP-274 ürün kararı bekliyor |
| WP-266 | Push omurgası, local `0001→0066`, 116 pgTAP ve beta entegrasyonu yapıldı | Retry worker ve gerçek FCM kabulü eksik → WP-270/271 |
| WP-267 | Standard/promoted deney kodlandı; beta-v4302'de kullanıcı görünür regresyon üretti | Bu yön kabul edilmedi; v43 panel kontratı → WP-272 |
| WP-268 | Staging `0066–0068`, dispatcher activation ve beta-v4302/4303 Android yayınları yapıldı | Eski “aktivasyon/release bekliyor” kaydı kapandı; cihaz kabulü → WP-271/272 |

### Bekleyen Ürün Kararları

- **WP-252:** Pomodoro'nun uygulama kapalıyken native faz geçişi. Ürün onayı olmadan başlanmaz.
- **WP-274:** Tools Saat/Kronometre/Dünya erişimleri. Öneri: v43 girişlerini geri getir.

### Düşük Öncelikli Planlar

- **WP-236:** Dönem-bazlı leaderboard history; kurtarma ve stable güveni bitmeden başlanmaz.
- **WP-238:** Eğilim kartı 7/14/30/90/180/360 döngü seçici; 180/360 veri kaynağı kararı gerekir.
- **WP-260–262:** Windows Store kimliği/listing/private pilot; önce WP-259 ve WP-273 kabulü gerekir. Public Store için ayrıca açık kullanıcı GO zorunludur.
- **WP-110–124:** Google Play production programı NO-GO; kanonik ayrıntı `docs/KALITE-PROGRAMI.md §8.8`.

---

## Kapanan / Tekilleştirilen Stale Kayıtlar

| Kayıt | Yeni sınıf |
|---|---|
| WP-235 | Test-only iş tamamlandı; kırık achievement lifecycle testleri düzeltildi, aktif plan değil |
| WP-237 | Cihaz QA geçti; aktif plan değil |
| WP-239 | Cihaz QA geçti; aktif plan değil |
| WP-227–230, WP-233–251, WP-253, WP-255–258 | Eski kabul/yayın kayıtları; canlı kuyruktan çıkarıldı, tarihsel arşiv+git kanıtıdır |
| WP-232 | Eski “production recovery release” kartı v43 fiilî yayını ve yeni post-v43 riskleri nedeniyle yeniden kullanılmaz; production HOLD ve yeni release kapısı WP-269/271 ile yönetilir |
| WP-266/267/268 eski ayrıntılı kartları | Yapılan iş kaybolmadı; park tablosunda gerçek durum, kalan iş yeni WP-270/271/272'de |
| beta-v4302 “dispatcher/release bekliyor” lane notu | Stale; activation ve beta-v4302/4303 yayınları tamamlandığı için kapatıldı |

---

## Tamamlanan İş Paketleri

> Canlı dosya yalnız yeni kabul kayıtlarını kısa satırla tutar. Eski ayrıntılar arşiv+git'tedir.

- **WP-225 — Production Freeze ve Adli Baseline** · Tamamlandı 2026-07-20 · production write olmadan baseline çıkarıldı.
- **WP-226 — Supabase CLI ve Migration Baseline** · Tamamlandı 2026-07-20 · pinli CLI/Docker local replay ve pgTAP tabanı kuruldu.
- **WP-258 — v43 stable** · Yayınlandı 2026-07-21 · Android APK + Windows MSIX/ZIP · production `0065`.

---

## Worker'a Verilecek Kısa Komutlar

- `worker'ı oku ve WP-269'u yap`
- `worker'ı oku ve WP-270'i yap`
- WP-269 ve WP-270 kabulünden sonra: `worker'ı oku ve WP-271'i yap`
- Ayrı native lane uygunsa: `worker'ı oku ve WP-272'yi yap`
- WP-269 sonrası: `worker'ı oku ve WP-273'ü yap`
- WP-274 için önce kullanıcı ürün kararını verir; sonra worker'a atanır.

> Worker her seferinde önce Aktif Çalışma Kaydı'nı okuyup kendi lane'ini claim eder. Aynı anda en fazla iki lane; production/stable hiçbir WP'nin örtük parçası değildir.
