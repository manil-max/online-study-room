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
- **Yönetim varsayılanı (WP-269):** `tooling/release/deploy-contract.json` production `deploy_enabled/release_enabled` artık **kapalı** (güvenli varsayılan). Stable yalnız protected `production` Environment içinde tek kullanımlık exact SHA/head/project-ref GO ile ilerler; guard testleri kapalıyı kanıtlar.
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md`, planner ve worker kuralları v43 sonrasında silinmedi/değiştirilmedi.
- **Git:** Tek çalışma dalı `main`; branch/merge/push kullanıcı açıkça istemedikçe yok.
- **Son WP numarası:** **279**. Sıradaki boş numara **WP-280**.
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
- **Durum:** [~] Aktif
- **Faz/WP:** Kurtarma · Faz 3 — WP-271 beta aday yayını
- **Aşama:** Staging gate ve beta-v4304 hazırlanıyor
- **SAHİP yollar:** `tooling/release/deploy-contract.json`, ilgili `tooling/release/*.tests.ps1`, `CHANGELOG.md`, `app/assets/release_notes.json`, `progress.md` (yalnız bu lane)
- **Ortak/riskli yüzey:** Staging migration head/release metadata; yalnız staging beta. Production, stable, Store ve feature kodu kapsam dışıdır.
- **Dal:** `main`
- **Başlangıç / Son güncelleme:** 2026-07-23 17:06 / 2026-07-23 17:06 (Europe/Istanbul)
- **Not:** Kullanıcı cihaz kabulü için GitHub beta yayını istedi. `0069` staging gate sonrası benzersiz `beta-v4304` prerelease hedefleniyor; production HOLD korunur.

### Codex-2 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** `main`
- **Başlangıç / Son güncelleme:** — / 2026-07-23 (Europe/Istanbul)
- **Not:** Backlog uyumlama ve WP-275–279 planı tamamlandı; WP-269 lane'ine dokunulmadı.

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
| 1A | WP-269 Release kapılarını sadeleştir | ✅ Kod+test tamam → Park | CI orchestrator koşusu + owner required-reviewer kabulü bekliyor |
| 1B | WP-270 Push retry/health motoru | [x] Otomatik test geçti → Park | WP-271 staging/cihaz kabulünü bekliyor |
| 1C | WP-272 v43 sayaç paneli sözleşmesi | [x] Otomatik test geçti → Park | Samsung cihaz kabulü bekliyor |
| 2A | WP-271 Staging gerçek push kabulü | [ ] Bekliyor | WP-269 + WP-270 kabulünden sonra |
| 2B | WP-273 Windows deterministik release | [x] Otomatik test geçti → Park | Temiz Windows VM kabulü bekliyor |
| Karar | WP-274 Tools erişim kararı | [x] Otomatik test geçti → Park | Kalıcı kaldırma seçildi; cihaz kabulü bekliyor |
| Sonra | WP-275 Taç XP barı | [x] Otomatik test geçti → Park | Android/Windows cihaz kabulü bekliyor |
| Sonra | WP-276/277 kabul ve ops kanıtı | [ ] Bekliyor | Kurtarma cihaz/release kapılarından sonra |
| Karar | WP-278/279 dil ve aylık rapor | [?] Ürün kararı gerekiyor | Açık ürün/ops kararı olmadan worker başlamaz |

> **Çakışma matrisi:** WP-269 workflow/tooling, WP-270 Supabase+push, WP-272 Android native sayaç yüzeyindedir; SAHİP dosyaları kesişmez. WP-271, WP-269/270 çıktısını staging'e taşıdığı için seridir. WP-273, `.github/workflows/windows-release.yml` nedeniyle WP-269 sonrasıdır. Aynı anda en fazla iki lane açılır.

---

## Kurtarma Plan Kuyruğu

### WP-269: Release ve Database Gates Sadeleştirmesi 🧭
- **Program/Faz:** Kurtarma · Faz 1 — release yönetişimi
- **Ajan:** Codex (uygulama) → Claude (devir + doğrulama)
- **Durum:** [x] Kod+tooling testi tamamlandı → **Park** (CI koşusu + owner reviewer kabulü bekliyor)
- **Problem:** Database apply, tam Flutter test/build ve beta aday APK aynı zincire bağlanmış; production bayrakları açık kalmış; Android/Windows release kısmi tamamlanabiliyor.
- **Kapsam dışı:** Feature kodu, yeni migration, staging/production apply, tag/push/release, GitHub production secret'larını okuma.
- **SAHİP dosyalar (yaz):** `.github/workflows/database-gates.yml`, `.github/workflows/release.yml`, `.github/workflows/windows-release.yml`, `tooling/release/**`, `tooling/supabase/guard.tests.ps1`, `docs/recovery/RELEASE-GATE.md`.
- **DOKUNMA (oku, değiştirme):** `app/lib/**`, `app/android/**`, `supabase/migrations/**`, `supabase/functions/**`, Firebase dosyaları.
- **Adımlar:**
  - [x] Database Gates'i list→dry-run→apply→pgTAP/post-check ile sınırla; Flutter/APK aday build'ini ayır. (Flutter/keystore adımları workflow'dan çıktı; guard testi `flutter|beta-build.ps1|KEYSTORE_BASE64` yokluğunu zorluyor.)
  - [x] Production deploy/release varsayılanını kapat; kalıcı açık flag yerine tek kullanımlık exact SHA/head/GO doğrulaması tasarla. (`deploy_enabled/release_enabled=false`; `release-gate.ps1` yalnız CI+protected `production` env + exact `PRODUCTION RELEASE GO:<sha>:<head>:<ref>` + kanıt ile geçer.)
  - [x] “beta preflight” ve “stable preflight” için tek giriş noktası ve kısa kanıt özeti üret. (`tooling/release/release-preflight.ps1` + testleri.)
  - [x] Android/Windows artefakt durumunu `partial|complete|failed` olarak tek manifestte göster; release'i ancak zorunlu artefaktlar tamamlanınca finalize et. (`release_status` job `release-status-manifest.json`; `finalize` yalnız android+windows `success` ise koşar.)
  - [x] Repo dışı sahip aksiyonu olarak GitHub `production` Environment required reviewer kurulumunu açık checklist'e yaz. (`docs/recovery/RELEASE-GATE.md` owner checklist.)
- **Kanıt (Kodda doğrulandı):** `guard.tests.ps1` 39/39, `release-preflight.tests.ps1` 4/4, `beta-build.tests.ps1` 4/4 yeşil; üç workflow YAML geçerli.
- **Açık kabul (Cihazda/CI'da doğrulanmalı):** Gerçek beta orchestrator koşusunda iki zorunlu artefakt `complete`; owner `production` Environment required-reviewer kurulumu.
- **Veri/Migration etkisi:** Yok. Rollback, yalnız workflow/tooling commit'ini geri almaktır.
- **Ortam/Deploy:** Local + CI dry-run; remote apply, tag ve yayın yok. Production HOLD korunur.
- **RLS/Güvenlik:** Secret çıktısı 0; environment/channel/SHA/head fail-closed; required-reviewer eksikliği görünür blokerdir.
- **Edge-case'ler:** Windows artefaktı geç kalır, rerun aynı release'i iki kez finalize eder, staging head production head'den ileridedir, eski tag tekrar çalıştırılır.
- **Kabul (ölçülebilir):** Staging DB apply job'ında Flutter setup/build adımı 0; guard testleri production varsayılanını kapalı kanıtlar; preflight yanlış SHA/head/channel'da exit≠0; kısmi release “complete” görünmez; tüm tooling testleri yeşil.
- **Tuzaklar:** Kalite kapısını silmek yerine doğru olaya taşımak; GitHub reviewer ayarını repo koduyla yapılmış saymak; eski production açık flag'ini korumak.
- **Model önerisi:** 🔴 Opus / frontier-high

### WP-270: Push Retry Worker, Salt-Okunur Health ve Kuyruk Gözlemi 📬
- **Program/Faz:** Kurtarma · Faz 2 — bildirim güvenilirliği
- **Ajan:** Codex
- **Durum:** [x] Otomatik test geçti → **Park** (staging/cihaz kabulü bekliyor)
- **Problem:** Outbox/retry/lease state'i var fakat zamanlanmış worker yok; geçici hata sonrası kayıt süresiz bekleyebilir. Mevcut “health” çağrısı iş claim edip gönderim yapabiliyor.
- **Kapsam dışı:** Production deploy, beta tag/release, Android sayaç görünümü, pazarlama segmentasyonu.
- **SAHİP dosyalar (yaz):** yeni `supabase/migrations/0069_*`, `supabase/functions/dispatch-push/**`, `supabase/tests/**`, `app/lib/core/notifications/**`, ilgili notification health UI/repository/provider testleri.
- **DOKUNMA (oku, değiştirme):** release workflow'ları ve `tooling/release/deploy-contract.json` (WP-269/271), Android timer FGS/layout (WP-272), production.
- **Adımlar:**
  - [x] Kimlik bilgisi güvenli, periyodik dispatcher tetikleyicisi kur; retry zamanı gelen işi yeniden claim et.
  - [x] Salt-okunur health/status yolunu work/dispatch yolundan ayır.
  - [x] Stuck lease recovery, queue depth/oldest age/attempt/error code ölçümlerini ekle.
  - [x] Self-test UI'da transport/config/timeout/server/FCM hata sınıfını görünür yap.
  - [x] Gerçek PostgreSQL fixture'ıyla transient hata→backoff→başarı ve invalid-token kapanışını test et.
- **Kanıt (Kodda doğrulandı):** Local `0001→0069` replay; pgTAP 137/137; local Edge runtime `dispatch-push` smoke (beklenen `405 Method Not Allowed`); hedef Flutter testleri 10/10; `flutter analyze` 0 sorun. Yerel kanıt manifesti: `.artifacts/deploy-evidence/20260723T112626126Z-local-test/`.
- **Açık kabul (Cihazda/staging'de doğrulanmalı):** WP-271 kapsamında staging cron/Edge ve gerçek FCM ile 20 ölçüm, terminated-app teslimi ve retry kanıtı.
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
- **Durum:** [?] Ops/cihaz girdisi bekliyor · **Bağımlılık:** WP-269 + WP-270 otomatik kabulü
- **Problem:** beta-v4303 Android APK ve staging altyapısı yayımlanmış olsa da gerçek FCM teslim, retry, Samsung görünümü ve ölçümlü cihaz kabulü yoktur.
- **Kapsam dışı:** Production migration/secret/function/stable release; yeni feature/fix. Testte bug bulunursa bu WP içinde acele fix yapılmaz, ayrı debug WP açılır.
- **SAHİP dosyalar (yaz):** `tooling/release/deploy-contract.json` (yalnız staging head/HOLD), `docs/qa/DEVICE-QA-MATRIX.md`, `docs/recovery/PUSH-STAGING-ACCEPTANCE.md`, beta kabul kanıt manifestleri ve gerekiyorsa release metadata dosyaları.
- **DOKUNMA (oku, değiştirme):** Feature/native kodu, uygulanmış migration dosyaları, production contract/head.
- **Adımlar:**
  - [ ] Exact staging project-ref için list+dry-run+apply+post-check; dispatcher secret/function ve periyodik tetikleyiciyi doğrula.
  - [ ] Tek staging hesabı/tek Android cihazla foreground, background ve process-terminated remote self-test koş.
  - [ ] Dürtme/duyuru/güncelleme ayrımı, duplicate, token refresh/logout ve zorlanmış transient retry senaryolarını kaydet.
  - [ ] App-kapalı timer paneli/action ve bildirim merkezi hata kodunu aynı adayda doğrula.
  - [ ] Cihaz kabulünde GitHub prerelease beta adayını kullan; mevcut aday aynı SHA/head değilse normal preflight sonrası benzersiz beta tag/release çıkar. Bu kalıcı ürün politikası için tekrar onay sorma; önceki tag'i yeniden kullanma.
- **Veri/Migration etkisi:** Kabul edilmiş `0069` yalnız staging'e ileri terfi eder; rollback tetikleyiciyi/dispatcher'ı kapatır, kanıt satırlarını korur.
- **Ortam/Deploy:** Yalnız staging/beta. Production kesinlikle yok.
- **RLS/Güvenlik:** Test hesabı ve redacted kanıt; payload/token/secret ekran görüntüsü/logda 0; cross-user teslim reddi kanıtlanır.
- **Edge-case'ler:** Android “force stop” ile normal process termination ayrılır; Doze/batarya optimizasyonu; ağ kesintisi; eski beta client; iki cihaz ancak temel tek-cihaz kapısı geçtikten sonra.
- **Kabul (ölçülebilir):** En az 20 ölçümlü gerçek remote self-testte duplicate=0, yanlış kullanıcı/cihaz teslimi=0 ve p95≤10 sn; zorlanmış transient hata otomatik retry ile teslim olur; terminated app bildirimi görünür; timer action app açmadan çalışır; P0/P1=0. **Cihazda doğrulanmalı.**
- **Hazırlık kanıtı (2026-07-23):** GitHub `beta-v4303` prerelease aday APK'sı indirildi; `app-beta-release.apk.sha256` ile hash eşleşti. Release manifesti `beta` / commit `3bdf8bb8e25b0d303990f1e28d8ba184b4457ece` / staging head `0068` bildiriyor. Yerel Android platform-tools (`adb 37.0.0`) hazır; bu makinede bağlı cihaz yok, staging hesabı/remote test henüz koşturulmadı.
- **Tuzaklar:** Local notification'ı FCM kanıtı saymak; Settings “Force stop” sonrası Android'in teslim engelini ürün bug'ı diye yanlış sınıflandırmak; test sırasında production hedeflemek.
- **Model önerisi:** 🔴 Opus / frontier-high

> **Park notu (2026-07-23):** Staging erişim tokenı/DB parolası, sentetik staging hesabı ve gerçek Android cihaz mevcut ortamda yok. Bu girdiler olmadan `migration list`/dry-run/push veya 20 ölçümlü FCM kabul kanıtı üretilmez; production HOLD korunur.

### WP-272: v43 Sayaç Paneli Sözleşmesi ve Now Bar İzolasyonu ⏱️
- **Program/Faz:** Kurtarma · Faz 2 — Android timer ürün kontratı
- **Ajan:** —
- **Durum:** [x] Otomatik test geçti → **Park** (Samsung cihaz kabulü bekliyor)
- **Problem:** beta-v4302 kabul edilmiş v43 custom paneli standard notification ile değiştirdi; beta-v4303 paneli büyük ölçüde geri getirdi fakat v43 fallback davranışı ve cihaz kabulü net değildir.
- **Kapsam dışı:** Timer state/session/XP motorunu yeniden yazmak, push/outbox, Samsung private API, stable release.
- **SAHİP dosyalar (yaz):** `app/android/app/src/main/kotlin/**/timer/StudyTimerService.kt`, `app/android/app/src/main/res/layout/timer_notification.xml`, timer notification ikon/manifest yüzeyi, `app/lib/core/background/timer_foreground_service.dart`, ilgili native/source/widget testleri ve cihaz kabul kanıtları.
- **DOKUNMA (oku, değiştirme):** `supabase/**`, push dispatcher, release workflow'ları, timer session persistence/achievement zinciri.
- **Adımlar:**
  - [x] v43 custom panelini `timer_notification_v43_contract.json` fixture'ı ve kaynak sözleşme testiyle bağla.
  - [x] v43 `flutter.timer_panel_expanded` fallback flag/davranışını geri kur; false yolunda standard chronometer + native action kalır.
  - [x] Promoted/Now Bar'ı `not_requested` tanı extrası olarak ayır; stable custom panelde promoted API isteği yoktur.
  - [ ] Başlat/Duraklat/Durdur native action, kill/reboot ve uzun sayaç matrisini Samsung'da koş. **Cihazda doğrulanmalı.**
- **Veri/Migration etkisi:** Yok. Rollback v43 timer presentation commit/fixture'ına dönüştür.
- **Ortam/Deploy:** Local Android build + beta cihaz QA; tag/stable/production yok.
- **RLS/Güvenlik:** Etki yok; PendingIntent mutability/exported component kontrolleri korunur.
- **Edge-case'ler:** API 29–33/34+, OEM custom-layout kısıtı, font ölçeği, dark/light, reboot, Doze, uygulama güncellemesi sırasında aktif timer.
- **Kod kanıtı (2026-07-23):** `flutter test --dart-define-from-file=env.json test/core/verified_timer_bridge_contract_test.dart` 7/7 ve `flutter analyze --no-pub` geçti. Android SDK bu çalışma ortamında yok (`No Android SDK found`); APK/Kotlin derleme ve Samsung ekran görüntüsü/aksiyon matrisi cihaz QA'da tamamlanacak.
- **Kabul (ölçülebilir):** Samsung'da v43 referansıyla aynı bilgi hiyerarşisi ve üç action erişilebilir; desteklenmeyen yolda fallback notification kaybolmaz; 8 saatte sapma ≤±1 sn; app-kapalı action başarı oranı 20/20; FGS crash=0. **Cihazda doğrulanmalı.**
- **Tuzaklar:** Now Bar görünümünü garanti etmek; görünüm düzeltirken timer state motoruna dokunmak; kaynak-string testini cihaz kabulü saymak.
- **Model önerisi:** 🔴 Opus / frontier-high

### WP-273: Windows Deterministik Test ve Tam Artefakt Release'i 🪟
- **Program/Faz:** Kurtarma · Faz 4 — Windows release güveni
- **Ajan:** —
- **Durum:** [x] Otomatik test geçti → **Park** (temiz Windows VM kabulü bekliyor) · **Bağımlılık:** WP-269 kod/tooling çıktısı sağlandı
- **Problem:** beta-v4303 Windows workflow'u iki timer zamanlama testinde flaky düştü; Android release önce görünür olduğu için release kısmi kaldı.
- **Kapsam dışı:** Store public submission, yeni Windows feature/marka, Android build, production backend/migration.
- **SAHİP dosyalar (yaz):** `app/test/features/timer_background_reconcile_test.dart` ve yalnız ilgili fake-clock/test harness dosyaları, Windows paketleme testleri, `docs/QA-WINDOWS.md`, WP-269 sonrası gerekli dar `.github/workflows/windows-release.yml` düzeltmesi.
- **DOKUNMA (oku, değiştirme):** Timer üretim davranışı (test gerçek bug kanıtlamadıkça), Supabase, Android native, Store identity/asset dosyaları.
- **Adımlar:**
  - [x] Gerçek zaman/scheduler yarışını timeout uzatmadan, yerel-emission ve ağ-tamamlanma kapılarıyla deterministik yap.
  - [x] Hedef timer reconcile grubu ardışık 20 kez ve tam Flutter suite'i çalıştır.
  - [x] Tag atmadan yerel Windows release EXE ile MSIX+ZIP dry-run üret; SHA-256/provenance/manifest kontrol et.
  - [x] Android+Windows zorunlu artefaktlarının release finalize öncesi birlikte hazır olmasını WP-269 workflow sözleşmesinde doğrula.
- **Veri/Migration etkisi:** Yok. Rollback test harness/workflow commit'idir.
- **Ortam/Deploy:** Local Windows + CI dry-run; Store/tag/release yok.
- **RLS/Güvenlik:** Paket production secret'ı/log'u sızdırmaz; kanal/backend manifesti fail-closed.
- **Edge-case'ler:** Yavaş GitHub runner, locale/TZ, yeniden koşum, aynı asset'i iki kez yükleme, yalnız Windows veya yalnız Android başarı.
- **Kabul (ölçülebilir):** İki flaky test 20/20 ardışık yeşil; tam Windows suite + build + MSIX/ZIP dry-run yeşil; manifest SHA/commit/channel/head doğru; zorunlu bir artefakt yokken release `complete` olamaz.
- **Kod kanıtı (2026-07-23):** hedef `timer_background_reconcile_test.dart` 20/20; `flutter test`, `flutter analyze`, `flutter build windows --release`, `dart run msix:create --build-windows false` geçti. Yerel manifest `app/build/wp273-windows-dry-run/platform-manifest.json` `local` kanalını, migration head `0069`u ve MSIX/ZIP SHA-256 değerlerini kaydetti; tag/push/release yok.
- **Mevcut makine smoke (2026-07-23):** Kurulu `OdakKampi.App` `1.0.0.0→1.0.0.8` MSIX güncellemesi, paketli uygulama açılışı ve portable ZIP açılışı geçti. Bu makine temiz VM değildir; kullanıcı verisini silmemek için uninstall koşturulmadı.
- **Açık kabul (Cihazda doğrulanmalı):** Temiz Windows VM'de MSIX kurulum, N→N+1 güncelleme ve kaldırma; yayın/Store işlemi yapılmadı.
- **Tuzaklar:** Sadece timeout büyütmek; üretim kodunu test flake'i için değiştirmek; Android yayımlandıktan sonra Windows'u belirsiz saatlerde eklemek.
- **Model önerisi:** 🟣 Pro / frontier-high

### WP-274: Tools Saat/Kronometre/Dünya Erişim Kararı 🧰
- **Program/Faz:** Kurtarma · Faz 4 — bildirim dışı drift
- **Ajan:** —
- **Durum:** [x] Otomatik test geçti → **Park** (dikey/yatay cihaz kabulü bekliyor)
- **Problem:** WP-264 Tools girişlerini kaldırdı fakat Stopwatch/World Clock kaynakları duruyor; v43 sonrası kullanıcı görünür kapsam azaldı ve canlı dosyada bu yalnız “sadeleştirme” diye görünüyordu.
- **Ürün kararı (2026-07-23):** Kullanıcı **kalıcı kaldırmayı** seçti; mobil yatay StandBy davranışı da kalkacak.
- **Kapsam dışı:** Android study timer/FGS, alarm motoru, push sistemi, navigation mimarisini yeniden tasarlamak.
- **SAHİP dosyalar (yaz):** `app/lib/features/clock/clock_screen.dart`, gerekirse `app/lib/core/navigation/home_shell.dart`, ilgili clock/navigation testleri; kaldırma seçilirse yalnız açıkça listelenen dead Stopwatch/World Clock dosyaları.
- **DOKUNMA (oku, değiştirme):** `app/lib/data/providers/study_providers.dart`, `app/lib/core/notifications/**`, `app/android/**`, release/migration dosyaları.
- **Adımlar:**
  - [x] Kullanıcı “kalıcı kaldır” kararını kayda geçir.
  - [x] Kronometre, Dünya Saati ve yatay StandBy ekran dosyalarını kaldır; alarm/timer motoruna dokunma.
  - [x] Yatay yönü ayrı bir ekran yerine normal Araçlar akışında tut.
  - [x] Dikey/yatay ve Araçlar sekmesi regresyonlarını otomatik testte doğrula. **Cihazda doğrulanmalı.**
- **Veri/Migration etkisi:** Yok. Rollback tek UI/navigation commit'idir.
- **Ortam/Deploy:** Local only; remote/tag/release yok.
- **RLS/Güvenlik:** Etki yok.
- **Edge-case'ler:** Stopwatch ile çalışma sayacını karıştırma, yatay StandBy, geri tuşu, seçili sekme state'i, desktop navigation.
- **Kod kanıtı (2026-07-23):** `clock_screen_test.dart` dikey/yatay Araçlar akışını doğruluyor; erişim referansı taramasında silinen ekranlara çağrı 0. `flutter test --dart-define-from-file=env.json` ve `flutter analyze --no-pub` geçti.
- **Kabul (ölçülebilir):** Seçilen ürün kararıyla görünür girişler ve fiziksel kaynaklar çelişmez; unreachable ürün ekranı 0; ilgili widget/navigation testleri ve `flutter analyze` yeşil; cihazda dikey+yatay kabul.
- **Tuzaklar:** Ürün kararı almadan dosya silmek; study timer native servislerini Stopwatch sanmak.
- **Model önerisi:** 🟣 Pro

### WP-275: Taç XP Barını Mutlak Hedefe Hizala 👑
- **Program/Faz:** Ürün doğruluğu · profil/başarım görseli
- **Ajan:** —
- **Durum:** [x] Otomatik test geçti → **Park** (Android/Windows cihaz kabulü bekliyor)
- **Problem:** `xpBarMetrics` ve iki profil yüzeyi bugün kademe-içi değeri gösterir: örneğin 25k XP ve sonraki taç 75k iken `5k / 55k`. Ürün beklentisi mutlak toplamdır: `25k / 75k` ve doluluk `25/75`.
- **Kapsam dışı:** XP ekonomisi, taç eşikleri, server/RPC/migration, ledger, ödül hesaplama ve yeni rozet tasarımı.
- **SAHİP dosyalar (yaz):** `app/lib/core/stats/progression_visuals.dart`, `app/lib/features/profile/widgets/gamification_card.dart`, `app/lib/features/profile/widgets/achievement_showcase.dart`, ilgili profil/widget/unit testleri ve l10n yalnız yeni metin gerekirse.
- **DOKUNMA (oku, değiştirme):** `supabase/**`, achievement dictionary/economy fixture'ları, `app/lib/data/providers/**`, release/workflow dosyaları.
- **Adımlar:**
  - [x] Metrik sözleşmesini mutlak `currentXp / nextThreshold` ve aynı pay/payda doluluğu olarak yeniden tanımla.
  - [x] Profil özeti, tam başarımlar yüzeyi ve Semantics etiketini aynı saf metrikten besle.
  - [x] 0, 20k, 25k, 75k ve maksimum taç sınırlarında birim/widget regresyon testleri yaz.
  - [x] Maksimum/sonsuz kademe metnini açıkça tamamlandı olarak koru; `0 / 0` gösterme.
- **Veri/Migration etkisi:** Yok. Rollback yalnız istemci görsel metrik commit'idir.
- **Ortam/Deploy:** Local test + Android/Windows cihaz kabulü; remote, tag ve production yok.
- **RLS/Güvenlik:** XP istemciden yazılmaz; yüzey yalnız sunucudan gelen profil XP'sini gösterir.
- **Edge-case'ler:** Negatif/bozuk XP, eşiğe tam eşitlik, maksimum kademe, büyük sayı formatı, screen-reader yüzdesi, dar ekran.
- **Kod kanıtı (2026-07-23):** `flutter test --dart-define-from-file=env.json test/features/achievement_showcase_test.dart test/features/profile/crowned_avatar_test.dart test/features/profile/gamification_card_layout_test.dart` 18/18 ve `flutter analyze --no-pub` geçti.
- **Kabul (ölçülebilir):** 25k XP / sonraki 75k eşikte iki UI ve Semantics tam `25k / 75k` gösterir, progress `25/75`; eşikte %100 sonraki hedefe geçer; maksimumda `0 / 0` yok; analyze + hedef testler yeşil. **Cihazda doğrulanmalı.**
- **Tuzaklar:** Yalnız etiketi değiştirip barı kademe-içi bırakmak; %100'de eski taç hedefini göstermek; ekonomi kuralını UI fix'i için değiştirmek.
- **Model önerisi:** 🟣 Pro

### WP-276: Hesap Silme Pipeline'ı Staging Ops ve Kabul Kanıtı 🗑️
- **Program/Faz:** Play/hesap yaşam döngüsü · staging operasyon kabulü
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-269 release kapısı; production için ayrıca somut kullanıcı GO gerekir
- **Problem:** `0037`, `purge-accounts` Edge, retry mantığı ve uygulama UI'ı kodda vardır; ancak staging Edge/cron zinciri ve gerçek talep→iptal→purge davranışı kanıtlanmış değildir.
- **Kapsam dışı:** Production purge, gerçek kullanıcı hesabı silme, retention politikasını değiştirme, yeni migration/feature kodu. Bulunan hata için ayrı debug WP açılır.
- **SAHİP dosyalar (yaz):** `docs/qa/ACCOUNT-DELETION-STAGING.md`, `docs/play-store/PLAY-RELEASE-GATE.md`, redacted staging kanıt manifestleri; yalnız zorunlu düzeltme kanıtı için ilgili test dosyaları.
- **DOKUNMA (oku, değiştirme):** `supabase/migrations/0037_*`, production contract/head, kullanıcı verisi, `purge-accounts` kodu (defect yoksa).
- **Adımlar:**
  - [ ] Staging project-ref ile migration/function/secret/cron önkoşullarını list+dry-run ile doğrula.
  - [ ] Sentetik staging hesapta istek, 14 gün grace simülasyonu, iptal, idempotent tekrar ve yetkisiz çağrı senaryolarını koş.
  - [ ] Avatar/storage, grup sahipliği, sohbet scrub ve Auth silme sırasını redacted post-check ile kanıtla.
  - [ ] Retry `<5` ve terminal `failed` yolunu zorlanmış hata ile ölç; geri alma/cron durdurma runbook'unu yaz.
- **Veri/Migration etkisi:** Yeni migration yok. Staging test verisi kontrollü purge edilir; production'a hiçbir yazma yok. Rollback cron/fonksiyon tetiklenmesini kapatır, kanıtı silmez.
- **Ortam/Deploy:** Local→staging; production yalnız backup+dry-run+cihaz/ops kanıtı ve somut kullanıcı GO ile ayrı WP'de.
- **RLS/Güvenlik:** Service role istemciye/loga girmez; kullanıcı yalnız kendi talebini görür/iptal eder; test hesabı dışında veri 0; PII redacted.
- **Edge-case'ler:** Response kaybı, iki cihazdan istek/iptal yarışı, storage erişim kaybı, cron gecikmesi, beşinci retry, grup sahibi silinmesi.
- **Kabul (ölçülebilir):** Sentetik hesapta request/cancel/purge akışları idempotent; yetkisiz çağrı 401/403; avatar+Auth+bağlı veri sonucu runbook'la tutarlı; retry terminali beş denemede doğru; staging kanıtı ve rollback rehearsal tamam. **Cihazda/staging'de doğrulanmalı.**
- **Tuzaklar:** Test için gerçek hesabı silmek; Auth'u storage temizliğinden önce silmek; cron secret'ını kanıta yazmak; staging sonucunu production kabulü saymak.
- **Model önerisi:** 🔴 Opus / frontier-high

### WP-277: Başarım, Görev ve Grup İlerlemesi Kabul Matrisi 🎯
- **Program/Faz:** Başarım/Sosyal Profil 3.2 · kabul ve drift denetimi
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-271 cihaz/release güveni ve WP-276 ile aynı anda backend ops çalıştırılmaz
- **Problem:** WP-208–220'nin önemli kod/migration parçaları tarihsel olarak uygulanmış, fakat süre kaynakları, pending reward/claim, görev ve grup görünürlüğü için tek güncel cihaz/staging kabul paketi yoktur.
- **Kapsam dışı:** Yeni başarı kuralı/XP fiyatı, tarihsel veri rewrite/backfill, production migration/claim, kabul sırasında plansız feature geliştirme.
- **SAHİP dosyalar (yaz):** `docs/qa/ACHIEVEMENT-TASK-GROUP-ACCEPTANCE.md`, ilgili mevcut test fixture/QA manifestleri ve yalnız kabul açığını kanıtlayan testler.
- **DOKUNMA (oku, değiştirme):** `supabase/migrations/**`, economy dictionary/threshold, timer/push/release kodu; bulunan hata ayrı debug WP'sine ayrılır.
- **Adımlar:**
  - [ ] Manuel, uygulama sayaç, geri sayım/Pomodoro ve native timer için aynı süre→istatistik/XP/başarım/grup sonuç matrisini çıkar.
  - [ ] Pending reward→claim, ikinci claim no-op, iki cihaz görünürlüğü ve 23:59→00:01 İstanbul sınırını staging fixture ile doğrula.
  - [ ] Günlük görev toggle/undo, private grup avatar/erişim ve block/UGC görünürlüğü için mevcut sözleşme testlerini koş.
  - [ ] Başarısız kanıtı P0/P1/ürün kararı olarak sınıflandır; bu WP içinde kod fix'i yapma.
- **Veri/Migration etkisi:** Yok; sentetik/staging fixture kullanılır. Production veri/ledger değişmez.
- **Ortam/Deploy:** Local + staging cihaz QA; production/tag/release yok.
- **RLS/Güvenlik:** Cross-user progress/claim/direct-DML abuse reddi; group/private avatar ve block testlerinde gerçek kullanıcı verisi kullanılmaz.
- **Edge-case'ler:** Offline/retry, duplicate claim, iki cihaz, üyelik değişimi, gece yarısı, eski beta client, stale cache.
- **Kabul (ölçülebilir):** Matrisin her satırı kanıtlı veya açık bug/karar olarak sınıflı; duplicate XP=0, unauthorized progress/claim=0, beş süre kaynağında sonuç farkı=0; cihaz/staging kanıt manifesti tamam. **Cihazda/staging'de doğrulanmalı.**
- **Tuzaklar:** Tarihsel kodu tekrar yazmak; fixture sonucunu gerçek kullanıcı kabulü saymak; kabul WP'sinde migration/backfill yapmak.
- **Model önerisi:** 🔴 Opus / frontier-high

### WP-278: AR/DE Dil Desteği ve RTL Ürün Kararı 🌐
- **Program/Faz:** Uluslararasılaştırma · ürün kapsam kararı
- **Ajan:** —
- **Durum:** [?] Ürün kararı gerekiyor
- **Problem:** EN/TR l10n cihaz/ürün kabulü almış; AR/DE kod/ARB tabanı vardır fakat insan çevirisi ve RTL cihaz kabulü ürün kapsamına alınmamıştır.
- **Kapsam dışı:** EN/TR metinlerini yeniden çevirmek, generated l10n'i elle düzenlemek, yeni dil eklemek.
- **SAHİP dosyalar (yaz):** `docs/L10N-SOZLUK.md`, AR/DE ARB kaynakları ve yalnız karar sonrası ilgili RTL/widget testleri.
- **DOKUNMA (oku, değiştirme):** EN/TR katalogları, Android native EN/TR kaynakları, feature/migration/release dosyaları.
- **Adımlar:**
  - [ ] Kullanıcı AR/DE'nin gerçekten ürün dili olup olmayacağını ve çeviri sahibini karara bağlar.
  - [ ] Evet ise insan çevirisi, RTL layout matrisi ve gerçek Android/Windows kabulünü ayrı uygulanabilir alt-WP'lere böl.
  - [ ] Hayır ise dil seçeneğini EN/TR ile sınırla ve AR/DE'nin deneysel/tarihsel durumunu dürüstçe belgeleyip UI'da yanıltıcı seçenek bırakma.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Local + cihaz QA; remote/production yok.
- **RLS/Güvenlik:** Etki yok.
- **Edge-case'ler:** RTL icon yönü, sayı/tarih formatı, uzun Almanca metin, fallback EN, cihaz dil değişimi.
- **Kabul (ölçülebilir):** Seçilen kapsam ve UI seçenekleri birebir; AR seçilirse kritik akışlarda RTL overflow=0 ve insan çevirisi onaylı; kapsam dışıysa kullanıcıya sunulmaz.
- **Tuzaklar:** EN metnini “çeviri” saymak; generated dosyayı elle değiştirmek; cihaz QA olmadan RTL kapatmak/açmak.
- **Model önerisi:** 🟣 Pro + insan çeviri sahibi

### WP-279: Aylık Rapor Canlı Ops Kararı ve Staging Provası 📧
- **Program/Faz:** Operasyonel özellik · e-posta raporları
- **Ajan:** —
- **Durum:** [?] Ürün kararı gerekiyor
- **Problem:** WP-69/108 kodu cron/retry ve ayar anahtarını içerir, ancak DNS/Resend sağlayıcısı, gönderici kimliği ve canlı e-posta maliyet/retention kararı yoktur; bu nedenle özellik kullanıcıya güvenilir vaat edilemez.
- **Kapsam dışı:** Gizli anahtar eklemek, production Edge/cron deploy etmek, kullanıcıya e-posta göndermek.
- **SAHİP dosyalar (yaz):** `docs/ops/MONTHLY-REPORT-DECISION.md` (yeni), `docs/play-store/DATA-SAFETY.md` ilgili satırları ve karar sonrası staging QA manifesti.
- **DOKUNMA (oku, değiştirme):** `supabase/functions/send-report/**`, cron migration'ları, production secrets, profil tercih kodu.
- **Adımlar:**
  - [ ] Kullanıcı DNS domaini, gönderici adı/adresi, Resend/alternatif sağlayıcı, aylık maliyet limiti ve opt-in metnini karara bağlar.
  - [ ] Evet ise ayrı uygulama WP'si için staging secret/cron dry-run, unsubscribe/deletion/purge ve retry kabulünü planla.
  - [ ] Hayır ise UI tercihinin deneysel/kapalı durumu ve Data Safety anlatımıyla tutarlılığı belgeleyip canlı vaat bırakma.
- **Veri/Migration etkisi:** Yok; karar sonrası olası remote ops ayrı WP'dir.
- **Ortam/Deploy:** Karar dokümanı local; staging/production e-posta yok.
- **RLS/Güvenlik:** E-posta/secret loglanmaz; opt-in ve hesap silme/purge uyumu zorunlu.
- **Edge-case'ler:** Bounce, unsubscribe, silme grace, duplicate cron, sağlayıcı kesintisi, yanlış sender domaini.
- **Kabul (ölçülebilir):** Yazılı GO/NO-GO ve sahip bilgisi; GO ise ayrı staging uygulama WP'sinin önkoşulları eksiksiz, NO-GO ise UI/Docs canlı gönderim iddiası taşımıyor.
- **Tuzaklar:** DNS/API key olmadan cron açmak; opt-in'i açık rıza sanmak; silinen kullanıcıya rapor göndermek.
- **Model önerisi:** 🟣 Pro / ops sahibi

---

## Test / Ürün Kabulü İçin Bekleyenler (Park)

> Bunlar aktif lane değildir. Eski kartı yeniden claim etmek yerine açık eksik için yukarıdaki kurtarma WP'si kullanılır.

| WP | Kanıtlı durum | Açık kabul / karar |
|---|---|---|
| WP-269 | Kod+tooling testi geçti (guard 39, preflight 4, beta-build 4; 3 workflow YAML geçerli) | Gerçek beta orchestrator koşusunda iki zorunlu artefakt `complete`; owner `production` Environment required-reviewer kurulumu |
| WP-273 | Hedef timer reconcile 20/20; tam Flutter test 685/685, analiz, Windows release EXE ve yerel MSIX/ZIP dry-run geçti | Temiz Windows VM'de MSIX kurulum, N→N+1 güncelleme ve kaldırma |
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
- **WP-259–262:** Windows Store kartları `docs/WINDOWS-STORE-PLAN.md` içinde kanoniktir; önce WP-259 temiz VM QA ve WP-273 gerekir. Public Store için ayrıca açık kullanıcı GO zorunludur.
- **WP-110–124:** Google Play production programı NO-GO; ayrıntılı kartlar `docs/archive/progress-tarihsel-2026-07.md` ve kanonik sıra `docs/KALITE-PROGRAMI.md §8.8`dedir. Play programı açıkça başlatılmadan bu kartlar claim edilmez.

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
