# Denetim — Masaüstü (Windows) + sürüm/dağıtım hattı

> **Yöntem:** yalnız kod ve iş akışı dosyaları kanıt sayıldı. `progress.md`,
> `docs/**` ve kod yorumları iddia kabul edildi ve gerçekle karşılaştırıldı.
> Derleme başlatılmadı; hiçbir üretim dosyası değiştirilmedi.
> **Tarih:** 2026-08-09 · **Kapsam:** `app/lib/features/desktop/**`,
> `app/lib/core/desktop/**`, `app/lib/features/updater/**`, `app/windows/**`,
> `.github/workflows/**`, `tooling/**`, `scripts/**`.
>
> Bugün (2026-08-09) bu alana dokunan WP'ler (WP-590 imza kapısı, WP-597 Store
> yolu, WP-600/602 QA matrisi + smoke kanıtı, WP-594 masaüstü rozet/odak halkası,
> WP-606 paket dili) `git log` ile kontrol edildi; **düzeltilmiş olanlar bu
> raporda yok.** Aşağıdakiler ya hâlâ açık ya da bugünkü değişikliklerle
> **yeni doğmuş** durumlardır.

**Özet:** 3 KANAMA · 5 RİSK · 5 TEMİZLİK.

---

## KANAMA

### K1 — Microsoft Store paketi, mağaza dışı güncelleyiciyi AÇIK taşıyor

**Belirti.** WP-597 ile eklenen Store yolu, uygulamanın `DISTRIBUTION_CHANNEL`
değerini değiştirmiyor. Store'a gönderilecek MSIX, sideload ZIP ile **birebir
aynı** Dart derlemesinden paketleniyor; o derlemede uygulama içi GitHub
güncelleyicisi açık.

**Kanıt.**
- `.github/workflows/windows-release.yml:63` — manifest her koşumda
  `DISTRIBUTION_CHANNEL = 'windows'` yazıyor; Store dalı için ayrı bir değer yok.
- `.github/workflows/windows-release.yml:73` — tek `flutter build windows`
  çağrısı. Store paketi (`:167`) aynı `build/windows/x64/runner/Release`
  çıktısından `--build-windows false` ile üretiliyor, yani **yeniden
  derlenmiyor**.
- `app/lib/core/config/distribution_channel.dart:139-141` — Windows'ta define
  yoksa/`windows` ise kanal `DistributionChannel.windows`.
- `app/lib/core/config/distribution_channel.dart:154` —
  `DistributionChannel.windows => true` (`allowsSideloadUpdates`).
- `app/lib/features/updater/updater_dialog.dart:20` ve
  `updater_service.dart:59` — kanal izin veriyorsa açılışta GitHub'a çıkılıyor,
  ZIP indiriliyor.
- Kodun kendi uyarısı: `distribution_channel.dart:34-38` —
  *"define unutulursa Windows varsayımı `windows` olur ve updater açık kalır.
  Bu yüzden Faz H'de build öncesi bir kapı testi şarttır."* O kapı yazılmadı:
  `microsoftStore` değeri **hiçbir workflow'da** geçmiyor (repo genelinde yalnız
  `distribution_channel.dart` ve `test/core/distribution_channel_test.dart`
  içinde var).

**Etki.** Store sertifikasyonunda mağaza dışı güncelleme politika ihlalidir;
paket reddedilebilir. Reddedilmese bile Store'dan kuran kullanıcı, açılışta
"yeni sürüm var, ZIP indir, elle çıkar" diyalogu görür — Store kurulumunu
bozan bir yol. WP-597 belgesi (`docs/WINDOWS-STORE-YOLU.md`) bu riski hiç
saymıyor; "Ölçülmemiş olan" bölümünde bile geçmiyor.

**Öncelik:** KANAMA (Store gönderiminden önce kapatılmalı).

---

### K2 — Windows'ta alarm kaydetmek/açıp-kapatmak istisna fırlatıyor

**Belirti.** Masaüstünde "Saat" sekmesinde bir alarm kaydedilince, açılıp
kapatılınca veya silinince bildirim eklentisi **başlatılmadığı için**
`StateError` fırlıyor. Alarm diske yazılıyor ama liste tazelenmiyor ve alarm
hiçbir zaman çalmıyor.

**Kanıt (zincir, uçtan uca).**
1. `app/lib/core/notifications/alarm_notification_service.dart:56-63` —
   `initialize()` Windows/Linux/macOS'ta `_initialized = true; return;` diyor,
   yani `_plugin.initialize(...)` **hiç çağrılmıyor**.
2. Aynı dosya `:45` — `_useNative` yalnız Android'de true. `:122-130` — Windows
   `_useNative == false` kolundan geçip `_plugin.zonedSchedule(...)` çağırıyor.
   `cancelAlarm` (`:161-166`) ve `scheduleTimer` (`:200-215`) aynı desende.
3. `flutter_local_notifications-22.0.1/lib/src/flutter_local_notifications_plugin.dart:473-484`
   — Windows'ta çağrı `FlutterLocalNotificationsWindows`'a yönleniyor.
4. `flutter_local_notifications_windows-3.1.1/lib/src/plugin/ffi.dart:319-323`
   — `if (!_isReady) throw StateError('Flutter Local Notifications must be
   initialized before use');`. `cancel` (`:135-142`) ve `cancelAll` (`:145-152`)
   de aynı şekilde fırlatıyor. `_isReady` yalnız `initialize` içinde set ediliyor
   (`:105`).
5. Eklenti Windows derlemesinde **gerçekten kayıtlı**:
   `app/windows/flutter/generated_plugins.cmake` → `FLUTTER_FFI_PLUGIN_LIST`
   içinde `flutter_local_notifications_windows`; `.dart_tool/flutter_build/
   dart_plugin_registrant.dart:339` → `FlutterLocalNotificationsWindows.registerWith()`.
6. Çağıran tarafta yakalama yok:
   `app/lib/data/providers/alarm_providers.dart:63-73` — `saveAlarm`
   `repo.saveAlarm` (yazar) → `_syncNative()` (**fırlatır**) →
   `ref.invalidateSelf()` (asla çalışmaz). `:110-119` `_syncNative` →
   `svc.rescheduleAll` → her alarm için `scheduleAlarm`/`cancelAlarm`.
   Ekran tarafı da yakalamıyor: `app/lib/features/clock/alarms_screen.dart:47`
   ve `:350` çevresinde `.then(...)` var, `catchError` yok.

**Etki.** Windows'ta alarm özelliği ekranda **var gibi duruyor** ("Sonraki: yarın
07:00" yazıyor) ama çalışmıyor; üstelik kaydetme akışı sessiz bir hata ile
kesiliyor, liste güncellenmiyor. `alarmsProvider.build()` (`:41-62`) sync
çağırmadığı için liste yüklenmesi bozulmuyor — bu yüzden hata yalnız etkileşimde
görünüyor ve kolayca gözden kaçıyor.

Mağaza metni sesin çalmadığını **söylüyor**
(`docs/store/MICROSOFT-STORE-LISTING.md:114`, `:146`) ama "kaydetmek de
patlıyor"u söylemiyor; kullanıcıya vaat edilen "Windows'ta … görev listesi"
ifadesi aynı sekmenin içinde.

**Kapı neden görmedi.** `app/test/` altında `TargetPlatform.windows` ile alarm/
bildirim yolunu koşturan **tek bir test yok** (`grep -rn "TargetPlatform.windows"
test/` → yalnız distribution_channel, campfire, desktop shell, badge, pull-to-
refresh dosyaları). Windows entegrasyon kapısı da bu ekrana hiç girmiyor (bkz. R1).

**Öncelik:** KANAMA.

---

### K3 — Sürüm hattı şu an KİLİTLİ: stable Windows/Android artefaktı üretilemez

**Belirti.** Yerel migration head 0124, production kontrat pini 0123. Release
preflight iki ucu birden şart koştuğu için stable tag hangi head ile atılırsa
atılsın düşüyor; `windows` işi `needs: preflight` olduğu için Windows ZIP de
hiç üretilmiyor.

**Kanıt.**
- `supabase/migrations/` son dosya `0124_account_purge_indirect_restrict_chains.sql`
  (124 dosya, kesintisiz).
- `tooling/release/deploy-contract.json:3` `local_migration_head: "0124"`,
  `:5` staging `0124`, `:11` production **`0123`**.
- `tooling/release/release-preflight.ps1:60-63` — `Get-LocalMigrationHead`
  (=0124) `!= ExpectedMigrationHead` ise `throw`.
- Aynı dosya `:72-74` — `contract.production.migration_head` (=0123)
  `!= ExpectedMigrationHead` ise `throw`.
  → `0123` verilirse (1) düşer, `0124` verilirse (2) düşer. Ara değer yok.
- `.github/workflows/release.yml:213-222` — `windows` işi `needs: preflight`.
- Beta kolu da kapalı: `tooling/release/release-gate.ps1` (`release_enabled`
  kontrolü) — staging `release_enabled: false` ve production için tek yol
  `PRODUCTION RELEASE GO:<sha>:<head>:<ref>` dizesi, o da aynı head'e bağlı.

**Etki.** "Sabaha Windows yayına hazır olsun" hedefi bu hâliyle **çalışmaz**:
tag atılsa bile preflight'ta durur. Çözüm ya 0124'ün production'a uygulanıp
pinin ilerlemesi ya da sahibin açık kararı. Bu bir hata değil, **açık bir
blokaj** — ama hiçbir yerde "yayın şu an mümkün değil" diye yazmıyor.

**Öncelik:** KANAMA (yayın yolunu kapatıyor).

---

## RİSK

### R1 — "Windows integration (critical flows)" kapısı masaüstü kabuğunu kaybetse bile yeşil kalır

**Belirti.** Adı "kritik akışlar" olan tek Windows çalışma-zamanı kapısı,
masaüstü kabuğu hiç yoksa da geçer; ayrıca hiçbir şeye **tıklamaz**.

**Kanıt.**
- `.github/workflows/ci.yml:225` — `flutter test -d windows
  integration_test/v8_critical_flows_test.dart`.
- `app/integration_test/v8_critical_flows_test.dart:36-46` —
  `_selectedNavigationIndex` / `_selectNavigationDestination` önce
  `DesktopNavigationPane` arıyor, **bulamazsa `NavigationBar`'a düşüyor**. Yani
  Windows'ta masaüstü paneli kaybolsa (mobil kabuğa düşse) test yine geçer.
- Aynı dosya `:39-40`, `:47-52` — gezinme `tester.tap` ile değil, widget'ın
  `onSelected` **callback'i doğrudan çağrılarak** yapılıyor. Panelin görünür,
  hit-test edilebilir veya klavyeyle erişilebilir olması ölçülmüyor.
- `main()` koşmuyor: test `buildV8TestApp` ile doğrudan `OnlineStudyRoomApp`
  monte ediyor (`app/test/support/v8_test_setup.dart:59-73`); `initDesktopWindow`,
  `AppBuildManifest` doğrulaması, `showDesktopWindowWhenReady` hiç çalışmıyor.

**Bozuk girdi denemesi (kâğıt üzerinde):** `home_shell.dart:122`'deki
`if (isDesktopWindow)` dalını kaldırsanız kapı **kırmızıya düşmez**.

**Etki.** Windows tarafında "gerçek cihazda koşan" tek kapı, masaüstü kabuğunun
varlığını bile garanti etmiyor.

**Öncelik:** RİSK.

---

### R2 — Yayınlanan Windows ZIP'i hiçbir kapı bir kez bile ÇALIŞTIRMIYOR

**Belirti.** `flutter build windows --release` çıktısı doğrudan ZIP'lenip
kullanıcıya gidiyor; o EXE'nin açılıp açılmadığı hiçbir otomatik adımda
sınanmıyor.

**Kanıt.**
- `.github/workflows/windows-release.yml:73` (release build) → `:258`
  (`Compress-Archive`) → `:275-279` (`upload-artifact`). Arada çalıştırma yok.
  Tek kontrol `:253` `if (-not $zipItems) { throw ... }` — yani "klasör boş mu".
- `scripts/windows_fast_smoke.ps1` (uygulamayı açıp pencere başlığını doğrulayan
  gerçek smoke) **hiçbir workflow'dan ve `scripts/test_all.py`'den
  çağrılmıyor**: repo genelinde çağıran tek yer `scripts/windows_smoke_screenshot.ps1:8`
  ve belgeler (`docs/QA-WINDOWS.md:9`).
- `scripts/test_all.py:274-278` — tek Windows kapısı `integration` ve o da
  `flutter test -d windows` (debug), tier 3, yalnız `--full`.

**Etki.** WP-465'te ölçülen sınıf hâlâ açık: ölümcül yapılandırma ekranıyla
açılan bir sürüm CI'da fark edilmez. Smoke betiği `:219-230`'da bunu yakalayacak
tek gerçek sinyali (pencere başlığı) taşıyor ama kimse çağırmıyor.

**Öncelik:** RİSK.

---

### R3 — Windows sürümünde canlı yasal adresler yok (Android'de var)

**Belirti.** `LEGAL_BASE_URL` Android release manifestine yazılıyor, Windows
manifestine yazılmıyor. Windows'ta gizlilik/kullanım/veri silme bağlantıları
"yapılandırılmadı" metnine düşüyor.

**Kanıt.**
- `.github/workflows/release.yml:122` — Android env.json'da
  `'LEGAL_BASE_URL':'https://manil-max.github.io/online-study-room'`.
- `.github/workflows/windows-release.yml:50-64` — Windows manifestinde
  13 anahtar var, `LEGAL_BASE_URL` **yok**.
- `app/lib/features/profile/legal_documents.dart:10-15` —
  `defaultValue: ''` → `hasPublicLegalSite == false`.
- `app/lib/l10n/app_tr.arb:1098` — o durumda gösterilen metin:
  "Canlı HTTPS URL henüz yapılandırılmadı (LEGAL_BASE_URL)…".
- Kapı tek yönlü: `tooling/release/release-preflight.ps1:108` yalnız
  `release.yml` metninde `assert base['LEGAL_BASE_URL']` arıyor; Windows
  manifestini hiç ölçmüyor.

**Etki.** Store sertifikasyonunda gizlilik politikası bağlantısı ayrıca
listing'den veriliyor, o yüzden sert blok değil; ama uygulama içi hukuki yüzey
Windows'ta Android'den zayıf ve bunu ölçen kapı yok. Metin uygulama içinde
okunabildiği için çıkmaz sokak değil.

**Öncelik:** RİSK.

---

### R4 — Mini odak penceresi WP-250 "durdurma anında dondur" sözleşmesini uygulamıyor

**Belirti.** Mini pencere (Ctrl+Shift+M), durdurma sürerken saymaya devam ediyor
ve "Durdur ve kaydet" düğmesi aktif kalıyor. Ana ekran ikisini de yapmıyor.

**Kanıt.**
- `app/lib/features/desktop/compact_focus_view.dart:49-57` — `_displaySeconds`
  yalnız `state.isRunning`'e bakıyor; `isStopping` hiç okunmuyor.
- Aynı dosya `:38-41` — tik yine `isRunning` ile sürüyor, yani `isStopping`
  penceresinde sayı büyümeye devam ediyor.
- Aynı dosya `:246-257` — düğme `running ? stop() : start`; `isStopping`
  ne düğmeyi kilitliyor ne de ilerleme gösteriyor.
- Karşılaştırma: `app/lib/features/classroom/widgets/study_timer_card.dart:225`
  (`timer.isRunning && !timer.isStopping`) ve `:441-465` (isStopping'te
  `onPressed: null` + spinner + "Durduruluyor"). Aynı desen
  `focus_timer_screen.dart:167`'de de var.
- Veri güvenliği tarafı korunuyor: `study_providers.dart:2330`
  `if (_stopInFlight) return;` ikinci çağrıyı yutuyor — yani bu bir veri
  bozulması değil, yüzey tutarsızlığı.
- Ek olarak mini pencere `listenTimerNotices(context, ref)` çağırmıyor
  (`study_timer_card.dart:209` çağırıyor): WP-598 uyarıları ("uygulamayı
  kapatmak sayacı durdurmaz", kazara yeniden başlatma) mini pencerede hiç
  görünmüyor. Aynı şekilde `_stopTimer`'daki ayna-koşu onay diyalogu
  (`study_timer_card.dart:113-143`) mini pencerede yok; `stop()` içindeki
  `study_providers.dart:2345` yönlendirmesi sayesinde davranış doğru kalıyor
  ama kullanıcı onayı sorulmuyor.

**Etki.** Masaüstünde aynı sayaç iki yüzeyde farklı sayı gösteriyor; hafızadaki
"UI kendi gösterdiği sayıyı dondurmalı" dersinin masaüstü kolu eksik.

**Öncelik:** RİSK.

---

### R5 — İmza kapısı KARA LİSTE: tek bir bilinen kötü yayıncı dizesine bakıyor

**Belirti.** MSIX'in yayınlanabilir sayılması, yayıncının **tam olarak** msix
paketinin test sertifikası öznesi olup olmamasına bağlı. Başka herhangi bir
güvenilmez/kendinden imzalı özne "güvenilir" sayılır.

**Kanıt.**
- `.github/workflows/windows-release.yml:206-207` —
  `$testPublisher = 'CN=Msix Testing, …'` · `$trusted = $packageIdentity.Publisher -ne $testPublisher`.
- `app/pubspec.yaml:169` — `publisher: CN=OdakKampiTest`. Kapı, msix paketinin
  bu değeri kendi test öznesiyle **ezdiği** varsayımına dayanıyor
  (`windows-release.yml:196-199` yorumu). Varsayım doğruysa kapı çalışır;
  msix sürümü davranışını değiştirirse (`app/pubspec.yaml:87` `msix: ^3.18.0`
  — caret, üst sınır yok) kapı **sessizce yeşile döner** ve kurulamayan bir
  MSIX yayınlanır.
- Aynı repo bu dersi Play izinlerinde zaten aldı: `scripts/test_all.py:532-538`
  — "kara liste TEK BAŞINA yetmez … beyaz liste ölçer". Windows imza kapısı bu
  dönüşümü yapmadı.
- Doğru ölçüm elde mevcut ama kullanılmıyor: paket zaten açılıyor
  (`windows-release.yml:180-187`), `AppxSignature.p7x` varlığı/özne beyaz
  listesi aynı yerde ölçülebilirdi.

**Etki.** Fail-open kapı. Bugün gerçekleşmiyor, ama kapının doğruluğu bir
üçüncü taraf paketin davranışına bağlı ve o paket sürüm sınırı olmadan yükselir.

**Öncelik:** RİSK.

---

## TEMİZLİK

### T1 — `stable-candidate.yml` ölü: hiçbir girdiyle koşamaz
- **Kanıt.** `.github/workflows/stable-candidate.yml:54` `[[ "${{ inputs.expected_migration_head }}" = "0085" ]]` (gerçek production head `0123`), `:55-56` kontratta `deploy_enabled`/`release_enabled` **`false`** şartı, `:97` ve `:109` sabit `1.0.49`/`49` (uygulama `1.0.62+62`).
- **Etki.** Çağrılırsa ilk adımda düşer. Yine de `flutter-pin` kapısında sayılıyor, yani bakım maliyeti üretiyor. Ya güncellenmeli ya silinmeli.

### T2 — `tooling/release/verify-candidate.ps1` çağıransız
- **Kanıt.** Repo genelinde tek referans kendi testi: `tooling/release/verify-candidate.tests.ps1:5`. Hiçbir workflow, `test_all.py` kapısı veya başka betik çağırmıyor.
- **Etki.** "Yazılmış ama çağıran yok" sınıfı. (Aynı sınıfın bir örneği bugün `windows_performance_baseline.ps1` için belgelendi; bu ikinci örnek belgelenmedi.)

### T3 — `docs/WINDOWS-RELEASE-GATE.md` bugünkü gerçeği anlatmıyor
- **Kanıt.** `:93-105` hâlâ *"🔴 Bilinen blok — stable Windows işi şu an düşer … iş `throw` eder … ZIP de yayınlanmaz"* diyor. WP-590 (commit `e354394`, bugün) tam bunu kaldırdı: `windows-release.yml:201-229` artık `throw` etmiyor, yalnız MSIX'i alıkoyuyor; ZIP koşulsuz üretiliyor (`:258`). Ayrıca `:20` tablosu MSIX'i hâlâ "yayınlanan ikincil artefakt" gibi gösteriyor, oysa `docs/QA-WINDOWS.md:125` doğru olanı yazıyor ("yayınlanmaz").
- **Etki.** İki belge aynı konuda çelişiyor; bu belgeye bakan "Windows yayını bloklu" sonucuna varır.

### T4 — Mağaza metni §17 artık yanlış
- **Kanıt.** `docs/store/MICROSOFT-STORE-LISTING.md:484-489` — *"MSIX paketi şu an yalnız Türkçeyi beyan ediyor … Düzeltmesi tek satır (`tr-tr, en-us`)"*. Oysa `app/pubspec.yaml:178` zaten `languages: tr-tr, en-us` (commit `50dfd41`, listing commit'i `a60e493`'ten **önce**). `docs/WINDOWS-STORE-YOLU.md:45` doğrusunu yazıyor.
- **Etki.** Sahip listing belgesini okuyup olmayan bir işi yapmaya kalkar.

### T5 — Küçük tutarsızlıklar (kanıtlı, düşük etki)
- **`DISTRIBUTION_CHANNEL='github'` geçersiz bir değer.** `.github/workflows/release.yml:122` `'github'` yazıyor; `app/lib/core/config/distribution_channel.dart:123-130` bunu tanımıyor → `null` → platform/legacy çıkarımına düşülüyor ve **kazara doğru** sonuç üretiliyor. Define fiilen ölü.
- **Store modunda platform manifesti yanlış kimlik yazıyor.** `windows-release.yml:273` `identityName = '${{ steps.msix.outputs.identity }}'` — Store modunda gerçek paket kimliği `store_identity` (`:165`), manifest sideload kimliğini kaydediyor.
- **Masaüstü sekme etiketi ile içerik uyuşmuyor.** `desktop_home_shell.dart:49` sekme adı `desktopSaat` ("Saat"), mobilde aynı ekran `navTools` ("Araçlar" = Alarm + Timer + Görevler, `home_shell.dart` NavigationBar). Mağaza metni Windows için "görev listesi" vaat ediyor (`MICROSOFT-STORE-LISTING.md:114`) ama sekme adı yalnız saat diyor.
- **Grup sekmesinde uzun-bas sınıf değiştirici masaüstünde yok.** `home_shell.dart:159-168` mobilde `GestureDetector`+`showClassSwitcher`; `desktop_navigation_pane.dart` içinde `onLongPress`/`showClassSwitcher` **hiç geçmiyor**.
- **Windows stable, kısmen tamamlanmış yayında güncelleme göremez.** `release.yml:224-262` (`finalize_android`) Android-only bir release yayınlıyor; Windows işi bitmeden `releases/latest` bu olur. `updater_service.dart:91-107` stable kolunda yalnız `releases/latest`'e bakıyor, asset yoksa `failed()` dönüyor — beta kolundaki "asset'i olan en yüksek build" taraması (`:156-177`) stable'da yok.

---

## Kapı envanteri

> Her satır: **ne iddia ediyor / gerçekte ne ölçüyor / kasten bozuk girdiyle
> kırmızıya düşer mi.**

### `scripts/test_all.py`

| Kapı | İddia | Gerçekte ölçtüğü | Bozuk girdide kırmızı? |
|---|---|---|---|
| `contract` | Dart/Edge ↔ SQL sözleşmesi | Çağrı/imza karşılaştırması | **Evet** — `contract-self` bunu ayrıca kanıtlıyor |
| `contract-self` | Kapı kendini sınar | Sahte RPC/sütun enjekte edip kırmızı bekliyor | Evet (kapının kapısı) |
| `l10n` / `l10n-self` | Katalog eşliği + gömülü metin | Aynı; self-test üç kör noktayı deniyor | Evet |
| `l10n-android` | Android kaynak metin | `res/**` taraması | Evet |
| `migration-head` | Head dört yerde pinli | Zincir bütünlüğü + kontrat + `guard.tests.ps1` literali | Evet |
| `legal-site` | Yasal site sözleşmesi | Koddaki yolların üretildiği | Evet |
| `play-firebase` | Play flavor kaynakları | Dosya varlığı + applicationId eşliği; **yorum satırları atılıyor** (`test_all.py:869`) | Evet |
| `play-manifest` | Play izin sözleşmesi | Kaynak katmanı her zaman; **çıktı/beyaz liste yalnız taze merged manifest diskteyse** (`:650-667`) | Kısmen — `--require-merged` yoksa çıktı katmanı **ATLANIR** ama bunu açıkça yazıyor |
| `android-signing` | İmza kapısı doğru katmanda | `build.gradle.kts` metin taraması. ⚠️ `test_all.py:803` `if "Release[A-Za-z]*$" not in body` — bu bir **regex değil düz metin araması**; gradle dosyasında o literal dize duruyorsa geçer | Zayıf: kapının bu üçüncü maddesi gerçek görev eşleşmesini ölçmüyor |
| `flutter-pin` | Sürüm her workflow'da aynı | `.flutter-version` ↔ her `flutter-action` adımı; adım sayısı ile pin sayısı da karşılaştırılıyor | **Evet** (güçlü) |
| `analyze` / `test` / `golden` | Flutter kapıları | Standart | Evet |
| `coverage` | Kapsam ratchet | lcov ↔ baseline. ⚠️ **Baseline dosyası yoksa yeniden yazıp `return 0`** (`coverage_audit.py`, `load_baseline() is None` kolu) | **Hayır** — baseline silinirse kapı sessizce yeşil ve yeni taban yazılır. Ayrıca `CRITICAL_PATHS` içinde `lib/features/desktop/` ve `lib/features/updater/` **yok** |
| `guard` / `preflight` | Deploy/release kapı testleri | PowerShell birim testleri | Evet |
| `deno-check` / `deno-test` | Edge Function | Tip + davranış | Evet |
| `android-unit` | Native JVM testleri | Kotlin unit | Evet |
| `android-smoke` | Emülatörde sayaç | Gerçek süreç + logcat crash tamponu | Evet (cihaz varsa; yoksa ATLANDI, çıkış 3) |
| `integration` | **"Windows entegrasyon (kritik akışlar)"** | Gerçek Windows süreci açılıyor ama yalnız `selectedIndex` int'i doğrulanıyor; masaüstü paneli yoksa mobil kola düşüp geçiyor | **Hayır** — bkz. R1 |
| `pgtap` | Yerel replay | Docker gerekli, bu makinede ATLANDI | — |
| **(yok)** | Windows paket/kabuk smoke | — | `windows_fast_smoke.ps1` hiçbir kapıdan çağrılmıyor (R2) |

### `.github/workflows/**`

| Kapı | İddia | Gerçekte ölçtüğü | Bozuk girdide kırmızı? |
|---|---|---|---|
| `ci.yml` · backend-contract | Sözleşme + head + pin + Play | `test_all.py` alt kapıları | Evet |
| `ci.yml` · CI script bağlantısı | Satır-satır tuzağı geri gelmesin | `verify_ci_script_wiring.py`: tek satır + var olan `.sh`; hiç adım bulunamazsa da kırmızı | **Evet** (kendi körlüğünü de ölçüyor) |
| `ci.yml` · analyze+test+coverage | Tam paket | Standart + ratchet | Evet (ratchet istisnası yukarıda) |
| `ci.yml` · integration-tests | "Windows critical flows" | Bkz. R1 | **Hayır** |
| `ci.yml` · golden-tests | Windows golden | Raster karşılaştırma | Evet |
| `ci.yml` · android-emulator | Sayaç smoke | Gerçek emülatör + crash tamponu; `if: github.event_name != 'pull_request'` | Evet (PR'da koşmaz) |
| `l10n-gate.yml` | Katalog + gömülü metin | `--self-test` ile kapının reddettiği kanıtlanıyor | **Evet** |
| `legal-site.yml` | Yasal site canlı | Deploy sonrası dört sayfaya **gerçek HTTP 200** araması (10 deneme) | **Evet** (deploy "success" demesi yetmiyor) |
| `release.yml` · preflight | Tag/sha/head/kontrat + notlar + Play AAB yolu | Metin + kontrat kontrolü; AAB adımının workflow'da durduğu ölçülüyor | Evet — **şu an her stable girdisinde kırmızı** (K3) |
| `release.yml` · play-manifest (`--require-merged`) | Gönderilen AAB'nin izinleri | Taze birleşik manifest zorunlu, beyaz liste | **Evet** (güçlü) |
| `release.yml` · finalize_complete | Windows+Android manifest birleşimi | `assert {'android','windows'}` | Evet |
| `windows-release.yml` · kanal/backend guard | Yanlış env ile artefakt üretme | `current_build_manifest_gate_test.dart` → yalnız `AppBuildManifest.current` fırlatmıyor mu (kanal/env/sha/head/ref). **LEGAL_BASE_URL, DISTRIBUTION_CHANNEL doğruluğu ölçülmüyor** | Kısmen (R3, K1 kaçıyor) |
| `windows-release.yml` · MSIX sürüm sözleşmesi | version_name ↔ build_number | `throw`'lu regex eşlemesi, iki kanal ayrı | **Evet** |
| `windows-release.yml` · paket doğrulama | Bayrak gerçekten işlendi mi | MSIX açılıp `AppxManifest.xml` okunuyor; Name/Version/(Store'da) Publisher karşılaştırılıyor | **Evet** (paketin kendisinden okuyor) |
| `windows-release.yml` · imza kapısı | Kurulamayan MSIX yayınlanmasın | Tek bilinen kötü yayıncı dizesi (kara liste) | Zayıf — R5 |
| `windows-release.yml` · Store yarım yapılandırma | Fail-closed | `storeSet` 1 veya 2 ise `throw` | **Evet** |
| `windows-release.yml` · artefakt yükleme | Boş yükleme hata | `if-no-files-found: error` (store kolu koşullu) | Evet |
| `stable-candidate.yml` | İmzalı stable APK adayı | Sabit `0085`/`1.0.49` pinleri | Her girdide kırmızı → **ölü kapı** (T1) |
| `database-gates.yml`, `*-activation.yml`, `supabase-auth-config.yml` | — | Bu denetimin kapsamı dışı (veritabanı denetçisinde) | — |

---

## Kontrol ettim, SAĞLAM çıktı

- **Windows sürüm numarası zinciri tek kaynaktan türüyor.**
  `app/windows/runner/CMakeLists.txt:24-28` + `Runner.rc:63-77` Flutter'ın
  `FLUTTER_VERSION` define'ını kullanıyor; `windows/flutter/ephemeral/generated_config.cmake`
  `1.0.62+62` üretiyor. `package_info_plus-10.1.0/lib/src/package_info_plus_windows.dart`
  `productVersion`'ı `+` ile bölüp `buildNumber` üretiyor → `updater_service.dart:73`
  `int.tryParse(info.buildNumber)` doğru sayıyı alıyor. Beta biçimi
  (`1.0.4-beta.2+402`) de bozulmuyor. **Bu zincirde kopukluk yok.**
- **Artefakt adı zinciri tutarlı.** `updater_service.dart:151-153`
  (`odak-kampi-windows-{beta,stable}.zip`) ↔ `windows-release.yml:139`
  (`prefix=odak-kampi-windows-$channel`) ↔ `release.yml:328`
  (`release-assets/windows/*.zip`). `windows_packaging_wp568_test.dart` bunu
  metin düzeyinde kilitliyor.
- **Updater bütünlük kapısı Windows'ta fail-closed.**
  `updater_dialog.dart:178-187` — `sha256Url == null` ise dosya siliniyor ve
  "doğrulanamadı" deniyor; `:189-208` hash uyuşmazlığında da aynısı. CI her
  yayınlanan dosyanın yanına `.sha256` yazıyor (`windows-release.yml:268-272`).
- **Updater Windows'ta "kuruyormuş gibi" yapmıyor.** `updater_dialog.dart:212-219`
  + `WindowsUpdateReadyView` — dosya indirilenler klasörüne konuyor, üç adım ve
  tam yol gösteriliyor, "Klasörü aç" başarısız olursa yol hata satırında
  (`:250-258`). Çıkmaz sokak yok.
- **Mini pencere klavye tuzağı değil.** `compact_focus_view.dart:63-81` —
  kabuk değiştiği için Ctrl+Shift+M/P yeniden bağlanıyor; girişsiz durumda bile
  "Tam pencereye dön" düğmesi var (`:116-122`).
- **Masaüstü panellerinde Esc çıkışı var.** `desktop_surface.dart:97-107` —
  Esc önce panel içi geçmişi, sonra paneli kapatıyor.
- **Pencere geometrisi bağlı olmayan ekrana taşmıyor.** `desktop_window_io.dart:100-105`
  ve `:209-218` — kayıtlı bounds bağlı ekranların çalışma alanına clamp ediliyor.
  Compact her açılışta kapalı başlıyor (`:113-114`, gri ilk kare önlemi).
- **Beyaz HWND önlemi yerinde.** `main.dart:152-156` + `desktop_window_io.dart:135-152`
  — pencere ilk frame'den sonra gösteriliyor; `main.dart:76-92` Windows'ta
  framework hatası için okunur (ve WP-594'ten sonra yerelleştirilmiş) yüzey var.
- **Klavye kısayolları mağaza metniyle birebir uyuşuyor.**
  `desktop_home_shell.dart:96-107` — Ctrl+1…5 (beş hedef, `:37-67`), Ctrl+Shift+M,
  Ctrl+Shift+P, F5, Ctrl+, → `MICROSOFT-STORE-LISTING.md:105` ve `:137` ile aynı.
- **Masaüstü rail'i mobil ile aynı yenileme kaynağını çağırıyor.**
  `home_shell.dart` → `onRefresh: () => refreshAppData(ref)` (WP-550'nin ikinci
  provider listesi geri gelmemiş).
- **Windows sekmeleri tembel yükleniyor.** `desktop_home_shell.dart:181-209` —
  ziyaret edilmemiş sekme hiç monte edilmiyor, `TickerMode` ile arka plan
  animasyonları duruyor.
- **`msix:create` pubspec'i kirletmiyor ve bu ölçülüyor.**
  `windows-release.yml:160`/`:172` — SHA-256 öncesi/sonrası karşılaştırması.
- **Taşınabilir ZIP kendi MSIX'ini taşımıyor.** `windows-release.yml:252`
  (`$_.Extension -ne '.msix'`).
- **Store paketi GitHub Release'e girmiyor.** `windows-release.yml:264-267`
  (ayrı `build/windows-store`) + `:285-290` (ayrı artefakt, koşullu).
- **Beta ve stable Windows kimliği ayrı.** `windows-release.yml:102` / `:109`
  (`OdakKampi.App.Beta` vs `OdakKampi.App`) — beta kurulumu stable'ı ezmiyor.
- **MSIX paketi artık TR+EN ilan ediyor** ve bu `supportedLocales` ile
  bağlanmış: `app/pubspec.yaml:178` ↔ `windows_store_mode_wp597_test.dart:194-233`.
- **`windows_fast_smoke.ps1` kendi kanıtı hakkında dürüst.** `:163-201` — boş
  yakalamayı baskın renk oranıyla ölçüp `screenshotUsable: false` yazıyor;
  gerçek sinyal pencere başlığı (`:219-230`) ve o sağlam. (Sorun betiğin
  kendisi değil, çağrılmaması — R2.)
- **`verify_ci_script_wiring.py` kendi körlüğünü de kırmızıya çeviriyor**
  (`:121-127`): hiç satır-satır action bulunamazsa kapı düşüyor.
