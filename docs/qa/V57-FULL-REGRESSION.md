# V57 — Tam regresyon ve kapı denetimi (WP-465)

Kapsam: v57 turunun **bütün kapılarını gerçek çıktıyla** koşmak, test
sayılarını pinlemek ve sessizce atlanan test olmadığını kanıtlamak.

Sürüm kapsamı: `v56` sonrası **80 commit**, HEAD `f39f6c8`, migration head
`0114`.

> Bu kart iddiaya değil çıktıya bakar. Aşağıdaki her satır bu turda gerçekten
> çalıştırıldı; çalıştırılamayanlar **açıkça** öyle işaretlendi.

---

## 1. Kapı sonuçları

| Kapı | Komut | Sonuç |
| --- | --- | --- |
| Analyze | `flutter analyze` | ✅ `No issues found!` (129.1s) |
| Test — tümü | `flutter test` | ✅ **1433 / 1433** |
| Test — CI ubuntu | `flutter test --exclude-tags=golden --dart-define-from-file=env.json` | ✅ **1399 / 1399** |
| Test — CI windows | `flutter test --tags=golden --dart-define-from-file=env.json --concurrency=1` | ✅ **34 / 34** |
| pgTAP + replay | Database Gates (`local.ps1 baseline`) | ✅ `Files=44, Tests=647, PASS` |
| Deploy guard | `tooling/supabase/guard.tests.ps1` | ✅ 75 / 75 |
| Release preflight | `tooling/release/release-preflight.tests.ps1` | ✅ 8 / 8 |
| l10n (Flutter) | `scripts/l10n_audit.py` | ✅ 1480 anahtar, EN/TR eşleşiyor |
| l10n (native) | `scripts/l10n_android_audit.py` | ✅ 66 anahtar, EN=TR |
| Gizli dosya | `git ls-files` + içerik taraması | ✅ temiz (§4) |
| Android build | `flutter build apk --debug --flavor local` | ✅ 144.8s, APK üretildi |
| Windows build | `flutter build windows --release` | ✅ 74.3s |
| Windows smoke | `scripts/windows_fast_smoke.ps1` | ✅ PASS — **görüntü doğrulandı** (§5.3) |
| Entegrasyon (kapısız) | `flutter test -d windows integration_test/...` | ✅ 1/1 (§5.4) |

CI kanıtı (yalnız "yeşil sanılan" değil, gerçek run):

| Workflow | Commit | Sonuç |
| --- | --- | --- |
| CI | `f39f6c8` | success |
| CI | `51ed049` | success |
| Database Gates | `51ed049` | success |
| l10n Gate | `fefb015` | success |

---

## 2. 🔴 Asıl ölçü — test sayısı korunuyor mu

Kart açıkça uyarıyor: *"Testlerin toplam sayısını önceden pinleyip sessiz
atlanan test kabul etme."* Buradaki risk gerçek: CI paketi **iki komuta**
bölünmüş ve `--dart-define-from-file` kullanıyor. Bir test tag yüzünden iki
komutun da dışında kalırsa ya da env eksikliğinde sessizce atlanırsa kimse
görmez.

```
düz koşum         : 1433
CI ubuntu (golden hariç) : 1399
CI windows (yalnız golden):   34
                    ------
1399 + 34         = 1433  ✅ korunuyor
```

Yani: golden tag ayrımı **hiçbir testi dışarıda bırakmıyor** ve
`--dart-define-from-file=env.json` **hiçbir testi sessizce atlatmıyor**.

Atlama mekanizmaları ayrıca tarandı:

| Mekanizma | Bulgu |
| --- | --- |
| `skip:` | 1 eşleşme — `app_tours_test.dart:135`, bir **UI etiketi** (`'Atla / Skip'`), test atlaması değil |
| `@Skip(...)` | yok |
| `solo:` | yok |

pgTAP tarafında aynı ölçü:

```
yereldeki plan() toplamı : 647  (44 dosya)
CI'ın koştuğu            : 647  (Files=44)
```

Eşit olması, hiçbir pgTAP dosyasının erken kesilmediğini (plan/çalışan
uyuşmazlığı olmadığını) gösterir.

---

## 3. Migration ve eski veri

- Replay **`0001 → 0114` sıfırdan** koşuyor (`supabase db reset`), yani
  zincirin tamamı her turda yeniden uygulanıyor. Bu turda `0113` ve `0114`
  eklendi ve ikisi de temiz zincirde uygulandı.
- Head pinleri **dört yerde** tutarlı: `deploy-contract.json` (`0114`),
  `001_schema_contract.test.sql` migration **sayısı** (114) ve head
  **string**'i (`0114`), guard betiği (diskten türetir).
- Yerel kalıcı veri (upgrade) yolu testli: `theme_settings_test.dart` eski
  paletin bir kez göç edip aktif kaldığını, `schemaVersion = 99` gibi
  **ileri** bir sürümün de güvenli karşılandığını doğruluyor;
  `timer_v2_command_outbox` şema sürümü tutmayan kaydı düşürüyor.

> ⚠️ **Test edilmeyen tek yol:** `0114`'ün **backfill**'i. Local replay boş
> tablolar üzerinde çalıştığı için backfill gerçek satırla hiç sınanmıyor.
> Gerekçeli güvence: yedi sütunun tamamı `0114` öncesi `not null` idi, yani
> `pseudonymous_user_hash(id)` hiçbir zaman NULL almaz ve her satır hash alır;
> ardından gelen `set not null` bu yüzden başarısız olamaz. Gerçek veriyle ilk
> sınav **staging apply** olacak (WP-466).

---

## 4. Gizli dosya taraması

| Kontrol | Sonuç |
| --- | --- |
| İzlenen `.env` / `secrets.dart` / `firebase_options.dart` / `env*.json` / keystore | **yok** — yalnız 6 adet `*.example.json` şablonu izleniyor |
| İzlenen dosyalarda JWT deseni (`eyJ...`) | **yok** |
| Gerçek Supabase project ref | 1 eşleşme: `docs/recovery/PRODUCTION-BASELINE.md` |

Son satır **bulgu değildir**: project host'u istemci binary'sine zaten gömülü
(gizli değil) ve belge açıkça *"Dosyanın anahtar değeri kaydedilmedi"* diyor —
yalnız host ve `env.json`'ın SHA-256'sı kayıtlı.

---

## 5. Derleme kapıları

### 5.1 Android

✅ `flutter build apk --debug --flavor local` — `assembleLocalDebug` 144.8s,
`app-local-debug.apk` üretildi (182 MB, debug).

🔴 **İlk deneme düştü ve sebebi kayda değer:** flavor belirtmeden çağrılan
`flutter build apk --debug` `:app:validateBetaEnvironment` görevinde
*"beta artefaktı için CHANNEL zorunlu"* ile kırıldı. Bu bir ürün kırığı
**değil** — `app/android/app/build.gradle.kts` içindeki
`validateEnvironmentIdentity` muhafızı doğru çalışıyor: her flavor için
`CHANNEL`, `APP_ENVIRONMENT`, `GIT_COMMIT_SHA` (`^[0-9a-f]{7,40}$`) ve
`MIGRATION_HEAD` (`^\d{4}$`) zorunlu, ayrıca kanal↔backend eşleşmesi ve
"istemci build'inde service-role key olamaz" kuralı denetleniyor.

Tuzak şu: **flavor verilmezse beta'ya düşüyor** ve hata mesajı geliştiriciyi
yanlış flavor'a bakmaya yönlendiriyor. Ayrıca depodaki `app/env.json` eski
tek-dosya biçiminde (yalnız `SUPABASE_URL` + `SUPABASE_ANON_KEY`) olduğu için
testlere yetiyor ama **derlemeye yetmiyor**. Doğru çağrı `--flavor local` ve
`env.local.example.json` alanlarını taşıyan bir env dosyasıdır. (§6, bulgu 2)

### 5.2 Windows

✅ `flutter build windows --release` — 74.3s, `online_study_room.exe`
yeniden üretildi.

Bu build **gerekliydi**: depodaki binary 26 Temmuz tarihliydi, yani v57
turunun tamamından (WP-453/454/455/464) eskiydi. Smoke'u o binary üzerinde
koşmak "yeşil" ama anlamsız bir sonuç üretirdi.

✅ `scripts/windows_fast_smoke.ps1 -CloseAfter -DismissInitialDialog` —
`WINDOWS_FAST_SMOKE PASS`, pencere 1262 ms'de görünür oldu, ekran
görüntüsünde uygulama **gerçekten açıldı** (başlık "Focus Camp", sürüm notları
diyaloğu dolu içerikle çizildi).

### 5.3 🔴 Smoke kapısı yalanı söyleyebiliyor (bulgu 6)

İlk smoke koşumu da `WINDOWS_FAST_SMOKE PASS` dedi — ama ekran görüntüsünde
uygulama **ölümcül yapılandırma hatası** ekranındaydı:

> *"Secure configuration could not be verified — The connection was closed to
> avoid writing data to the wrong environment."*
> `Diagnostic code: invalid_version_build`

Sebep bendeydi (env dosyasına `APP_VERSION_NAME=0.0.0-wp465` yazmıştım;
`app_build_manifest.dart:291` local kanal için **tam olarak** `0.0.0-local` +
build `0` şart koşuyor) — yani **ürün kırık değil**. Düzeltip yeniden
derleyince uygulama normal açıldı.

Asıl bulgu şu: kapı ikisini **ayırt edemedi**. `windows_fast_smoke.ps1` yalnız
"görünür bir pencere oluştu mu" ölçüyor; çalışan uygulama ile hard-fail etmiş
uygulama onun için aynı. Ekran görüntüsü üretiyor ama **kimse bakmazsa** kapı
yeşil raporlar. Bu turda gerçek fark yalnız görüntüye bakıldığı için görüldü.

### 5.4 Kapısız entegrasyon testi

✅ `flutter test -d windows integration_test\v8_critical_flows_test.dart` —
Debug Windows build 226.8s, ardından `+1: All tests passed!`
("girişli kullanıcı V8 ana yüzeylerine cihazda geçebilir").

Yani test **sağlam**; sorun testte değil, onu hiçbir CI kapısının
koşmamasında (bulgu 3).

---

## 6. Bulgular

Kritik/ağır: **0**.

| # | Sınıf | Bulgu |
| --- | --- | --- |
| 1 | P3 (DX) | Dört `app/env.*.example.json` şablonunda `MIGRATION_HEAD` bayat: `0070` / `0063` / `0062` / `0062`, gerçek head `0114`. **Yayın hatası değil** — `release.yml` bu değeri sözleşmeden (`preflight.outputs.migration_head`) üretir, şablondan değil. Etki yalnız şablonu kopyalayan geliştiricinin build manifest'i. Manifest kapısı yalnız `^\d{4}$` biçimini doğruladığı için sessiz kalır. |
| 2 | P3 (DX) | `flutter build apk` **flavor'sız** çağrıldığında `beta` flavor'ına düşüyor ve `validateBetaEnvironment` "CHANNEL zorunlu" ile kırılıyor. Muhafız **doğru** çalışıyor (kanal/backend karışmasını engelliyor) ama hata mesajı yanlış flavor'a işaret ettiği için tuzak. Doğrusu `--flavor local` + `CHANNEL/APP_ENVIRONMENT/GIT_COMMIT_SHA/MIGRATION_HEAD` içeren env dosyası. |
| 3 | **P2 — ✅ DÜZELTİLDİ** | `app/integration_test/v8_critical_flows_test.dart` **hiçbir CI kapısında koşmuyordu.** Git'te izleniyor, adı "kritik akışlar", ama yalnız elle çalıştırılan `scripts/windows_local_dev.ps1 -IntegrationTest` çağırıyor. `flutter test` varsayılan olarak sadece `test/` dizinini koşar; `ci.yml` de öyle. Hafifletici: `flutter analyze` bu dosyayı **kapsıyor** (analyzer exclude'u yok), yani derleme çürümesi sessiz kalmaz — gözden kaçan yalnız davranışsal regresyondur. Sonuç için §5.3. |
| 4 | P3 (temizlik) | `app/analyze_out.txt` **git'te izleniyordu**: UTF-16 kodlu, eski bir `flutter analyze` hata dökümü, `e351741` (WP-25) ile kazara eklenmiş, hiçbir yerden referans yok. İçeriği "error - Target of URI doesn't exist..." satırları olduğu için depoyu okuyanı analyze kırıkmış gibi yanıltıyordu (analyze **temiz**). Hiçbir kartın sahipliğinde olmayan build artığı olduğu için bu turda **kaldırıldı**. |
| 5 | P3 (kapsam) | Kartın regresyon listesindeki **a11y** için ayrılmış test yok: `a11y`/`accessib` geçen test dosyası 0, yalnız 4 dosyada dolaylı `Semantics` kullanımı var. Karşılaştırma: `offline` 11, `dark` 13, `logout` 2 dosya. Bu bir kusur değil, **kapsam boşluğu** — cihaz a11y satırları WP-466'ya, otomatik a11y testi bir sonraki tura. |

| 6 | **P2 — ✅ DÜZELTİLDİ** | `scripts/windows_fast_smoke.ps1` **çalışan uygulama ile hard-fail etmiş uygulamayı ayırt edemiyordu.** Bu turda ampirik olarak gösterildi: aynı betik, ölümcül "Secure configuration could not be verified / `invalid_version_build`" ekranındaki uygulama için de `WINDOWS_FAST_SMOKE PASS` bastı (§5.3). Ölçtüğü tek şey "görünür pencere oluştu mu". Ekran görüntüsü üretiyor ama karar ona bakmıyor. Öneri: betiğe basit bir içerik kontrolü (ör. beklenen bir metnin/pikselin varlığı) ya da uygulamadan okunabilen bir sağlık sinyali eklenmeli; aksi halde "Windows smoke yeşil" cümlesi kanıt değildir. |

### 6.1 İki P2 kapı kusuru kapatıldı (2026-07-31)

**Bulgu 3 — entegrasyon testi artık CI'da.** `ci.yml`'e ayrı bir
`integration-tests` işi eklendi (windows-latest, `-d windows`). Ayrı iş
olmasının sebebi: `-d windows` gerçek bir Debug Windows derlemesi yapar;
golden işine eklenseydi hem o işin süresini riske atardı hem de kırmızı
düştüğünde hangisinin bozulduğu belirsiz kalırdı.

**Bulgu 6 — smoke artık hard-fail'i yakalıyor.** Ayırt edici sinyal ürün
tarafına hiç dokunmadan bulundu: **pencere başlığı**.

| Durum | Başlık |
| --- | --- |
| Native bootstrap (`windows/runner/main.cpp:32`) | `Odak Kampi` (ASCII `i`) |
| Başarılı açılış, TR (`desktop_window_io.dart:123`) | `Odak Kampı` (noktalı `ı`) |
| Başarılı açılış, EN | `Focus Camp` |

Dart başlığı ancak yapılandırma doğrulaması **geçtikten sonra** yerelleştirilmiş
ada çevirir. Başlık hâlâ bootstrap değeriyse Dart oraya hiç ulaşmamıştır —
dile bağlı olmayan, ürün değişikliği gerektirmeyen bir sinyal.

🔴 **Mutasyonla sınandı** (hafızadaki ders: bir kapıya güvenmeden önce kasten
kırık girdiyle koştur):

| Girdi | Eski davranış | Yeni davranış |
| --- | --- | --- |
| Sağlam build (`0.0.0-local`) | PASS | ✅ PASS, `title=Focus Camp` |
| Bozuk build (`0.0.0-MUTASYON` → `invalid_version_build`) | 🔴 **PASS** | ✅ **FAIL**, sebebi adıyla söylüyor |

Yani kapı artık ölçmesi gereken şeyi ölçüyor. Ekran görüntüsü başarısızlıkta
da kanıt olarak saklanıyor ve hata mesajı yolunu veriyor.

---

Bulgu 3 ve 6 **P2 idi**; ikisi de **ürün kusuru değil kapı kusuruydu** —
`ci.yml` ve `windows_fast_smoke.ps1`'i ilgilendirir, hiçbir ürün kartını
değil. WP-465 "ilgili ürün dosyasını ilgili ajan düzeltir" dediği ve bunlar
CI/altyapı kalemi olduğu için **kayda geçirildi, düzeltilmedi**; WP-467'nin
backlog derlemesine ve kapı kilidi kararına gider. Kalan üçü P3, biri
(`analyze_out.txt`) bu turda temizlendi.

İkisinin ortak dersi tek cümle: **bir kapının "PASS" demesi, ölçmesi gereken
şeyi ölçtüğü anlamına gelmiyor.** Biri hiç koşmuyordu, diğeri koşup yanlış
şeye bakıyordu; ikisi de yıllardır yeşil görünüyordu.

Kritik/ağır bulgu olmadığı için hiçbir sahip kartı yeniden açılmadı.

---

## 7. Bu kartın KAPSAMADIĞI şey

WP-465 otomatik kapıları kapatır; **cihaz satırları bu karta ait değildir.**
WP-438 kartı bunu zaten böyle yazıyor: *"cihaz satırları C/WP-465-466'da"*.
Gerçek cihaz matrisi (Samsung/Pixel, iki hesap-iki cihaz, force-stop, reboot,
internet kaybı, 23:59–00:01) **WP-466**'nın kabulüdür ve gerçek donanım
gerektirir.

Aynı şekilde staging apply/koşu kanıtı da WP-466'dadır; sözleşme bu turda
bilerek `deploy_enabled=false` bırakıldı ve preflight bunu fail-closed olarak
doğruladı (`Local head 0114 is ahead of staging 0100`).
