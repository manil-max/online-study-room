# Karşı Rapor — Codex beta arıza analizinin bağımsız doğrulaması

> **Arşiv uyarısı:** Bu karşı rapor değerli yeniden üretim kanıtını korur;
> ancak bazı kesinlik ve çözüm hükümleri sonraki uzlaştırmada düzeltilmiştir.
> Uygulama için kanonik kaynak
> [`BETA-YAYIN-ARIZA-NIHAI-RAPORU-2026-07-23.md`](BETA-YAYIN-ARIZA-NIHAI-RAPORU-2026-07-23.md)
> dosyasıdır.

> Tarih: 2026-07-23
> İnceleme türü: Bağımsız doğrulama. Codex raporunun her iddiası repo/CI kanıtına karşı sınandı.
> Ek olarak **arıza yerel makinede fiilen yeniden üretildi** (aşağıda komut ve çıktı var).
> Kod, workflow, migration, tag, release veya uzak ortam değişikliği: **Yapılmadı.**
> Oluşturulan dosyalar: bu rapor + `app/env.cirepro.json` (gitignore kapsamında, yalnız yeniden üretim için).

---

## 0. Tek cümlelik hüküm

**Codex'in "ne kırık" teşhisi doğru, "neden kırık" açıklaması yanlış, "nasıl doğrularız" reçetesi gereksiz pahalı — ve raporun tamamen kaçırdığı, elindeki loglarda zaten yazan bir P0 var.**

Üç ayrı sonuç:

| | Hüküm |
|---|---|
| **Doğru** | Blokaj `notificationsEnabled()` içindeki korumasız plugin erişimidir. `514db21` yanlış seviyeyi test etmiştir. Yönetim/kanıt dağınıklığı gerçektir. |
| **Yanlış** | "Yerelde yeşil çünkü Windows, CI'da kırmızı çünkü Linux." Bu **teknik olarak yanlıştır** ve bir sonraki ajanı gereksiz yere CI'ya/Linux'a gönderir. Gerçek sebep dört adet `--dart-define` anahtarıdır. |
| **Kaçırılan** | Staging'de push retry worker'ı **21 dakika boyunca kuyrukta hiçbir şey yapmadı** — bu, betanın doğrulamak için var olduğu özelliğin ta kendisi. Kanıt Codex'in alıntıladığı iki log satırının içinde duruyor. |

---

## 1. Yerel yeniden üretim — arıza CI'a ihtiyaç duymuyor

Bu, raporun en operasyonel çıktısı. Codex "aynı dokuz test Linux/Ubuntu Android-target koşulunda çalıştırılmalı" diyor. Gerekmiyor.

`app/env.json` şu an yalnız iki anahtar taşıyor:

```json
{ "SUPABASE_URL": "...", "SUPABASE_ANON_KEY": "..." }
```

CI'daki Android job'ı ise `env.json`'a **dört Firebase anahtarı daha** yazıyor
([release.yml:106](.github/workflows/release.yml:106)). Farkın tamamı bu.

Bu dört anahtarı yerel bir dosyaya ekleyip aynı komutu çalıştırdım:

```bash
cd app && flutter test --dart-define-from-file=env.cirepro.json
```

Sonuç — **Windows makinesinde, 68 saniyede**:

```text
01:08 +677 -9: Some tests failed.
#3  AppNotificationCoordinator.notificationsEnabled (app_push_notification_service.dart:117:14)
#4  AppPushNotificationService.snapshot (app_push_notification_service.dart:379:29)
#5  PushHealthController._synchronizeImpl (push_notification_providers.dart:147:22)
```

CI'daki `beta-v4305` koşusunun çıktısı (run 30009302420):

```text
##[error]677 tests passed, 9 failed.
```

**Bire bir aynı.** Yani iki beta numarası, CI'a tag atmadan 1 dakikada görülebilecek bir hata için yakıldı.

---

## 2. Codex'in §3.3'ü neden yanlış — ve bu neden önemli

Rapor diyor ki: *"Bildirim koordinatörü `defaultTargetPlatform == TargetPlatform.android` değilse platform eklentisine girmeden `false/no-op` döner… Windows'taki 685/685 sonucu Linux release test ortamını temsil etmiyordu."*

Flutter SDK'sının kendi kaynağı bunu çürütüyor —
`C:\src\flutter\packages\flutter\lib\src\foundation\_platform_io.dart:29`:

```dart
assert(() {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    result = platform.TargetPlatform.android;   // <-- her hostta
  }
  return true;
}());
```

`flutter test` **her işletim sisteminde** hedef platformu Android'e zorlar. Windows'ta da `_isAndroid == true`'dur. Platform teorisi geçersiz.

Gerçek ayrım noktası [firebase_push_config.dart:53](app/lib/core/config/firebase_push_config.dart:53):
dört dart-define boşsa `notConfigured` → `snapshot()` 348. satırda erken döner → plugin'e hiç dokunulmaz.

**Karşı kanıt, aynı CI koşusunun içinde:** `beta-v4304` koşusunda Ubuntu job'ı 9 test düşürürken **Windows job'ı aynı commit'te 685 testi geçti.** Sebep OS değil: [windows-release.yml:42-57](.github/workflows/windows-release.yml:42) `env.json` manifestine **hiç `FIREBASE_*` anahtarı yazmıyor.**

Bunun iki sonucu var:

1. Bir sonraki ajan Codex'in kabul kriteri #1'ini okuyup "Linux'ta doğrulamam lazım" derse, yine CI turuna girer. Gerek yok.
2. **Codex'in Faz 4 önerisi bu haliyle tehlikeli.** Rapor "ortak testler iki kez koşuyor, tek verify job'ında birleştirin" diyor. Ama bu iki job aynı suite'i iki kez koşmuyor — **iki farklı konfigürasyonda koşuyor.** Naif birleştirme, bu hata sınıfını yakalayan tek job'ı yok eder. Doğru düzeltme: iki *konfigürasyonu* korumak, iki *işletim sistemini* değil.

---

## 3. Raporun kaçırdığı P0 — staging kuyruğu donmuş durumda

Codex §7'de tek bir health çıktısı alıntılıyor ve "salt logdan ürün arızası kesinleştirilemez" diyor. İki koşuyu yan yana koyunca kesinleşiyor:

| Zaman (UTC) | queued | retry | processing | stuck | oldest_age | max_attempt |
|---|---:|---:|---:|---:|---:|---:|
| `12:38:08` (run 30007588454) | 2 | 0 | 0 | 0 | **55988** | 1 |
| `12:59:32` (run 30009050419) | 2 | 0 | 0 | 0 | **57272** | 1 |

`57272 − 55988 = 1284 s`. İki ölçüm arası duvar saati farkı: `12:59:32 − 12:38:08 = 21 dk 24 sn = 1284 s`.

**Tam olarak eşit.** Yani 21 dakikada kuyrukta *hiçbir şey* olmadı: bir satır claim edilmedi, bir attempt artmadı, bir tanesi bile retry'a veya failed'a düşmedi.

Bu 21 dakika boş bir pencere değil: `0069` staging'e ~`12:30Z`'de uygulanmıştı ve dakikalık cron worker'ı (`push-dispatch-retry-worker`, `* * * * *`) o andan itibaren canlıydı. **~21 tick, sıfır etki.**

Oysa [0066:576](supabase/migrations/0066_push_notification_delivery.sql:576) claim mantığı gereği, worker fonksiyona ulaşmış olsaydı en azından `attempts` artacaktı; cihaz kapalı olsaydı satırlar `skipped`'a düşecekti; lease düşseydi `stuck_lease_count` artacaktı. Hiçbiri olmadı.

Geriye üç olasılık kalıyor ve **üçü de betayı anlamsızlaştırır**:

- cron job `active = false` ya da hiç tetiklenmiyor,
- `net.http_post` çağrısı Edge'e ulaşmıyor (pg_net kuyruğu / URL / secret),
- bu iki satır kalıcı olarak claim edilemez durumda (`available_at` gelecekte vb.).

WP-270/`0069`'un tek amacı bu worker. Beta'nın cihaz kabul hedefi bu worker. **Kapı "success" dedi.** Codex haklı olarak kapının yorumsuz olduğunu söylüyor ama kapının zaten kırmızı olması gereken veriyi ürettiğini fark etmiyor.

Bunu kapatan tek, salt-okunur sorgu (mutasyon yok):

```sql
select jobname, schedule, active from cron.job where jobname = 'push-dispatch-retry-worker';
select status, start_time, return_message from cron.job_run_details
  where jobid = (select jobid from cron.job where jobname='push-dispatch-retry-worker')
  order by start_time desc limit 20;
select id, status, attempts, available_at, created_at, last_error_code
  from public.notification_deliveries where status in ('pending','retry','processing');
```

---

## 4. Codex'in abartılı sıraladığı bulgu — Edge deploy P0 değil

Rapor P0 olarak koyuyor: *"Staging DB `0069`, kayıtlı Edge deploy `3bdf8bb` → backend parçaları aynı SHA'da değil."*

**Gerçek kısmı doğru:** `dispatch-push/index.ts` `87f7965`'te değişti; Edge'i deploy eden tek mekanizma `Staging Push Activation` ve son koşusu 22 Temmuz'da `3bdf8bb` SHA'sıyla. İz kaydı gerçekten kopuk.

**Ama etkisi P0 değil.** `87f7965`'in Edge tarafındaki tek işlevsel eklentisi `action: "health"` dalı. Bu dalın repoda **hiçbir çağıranı yok** — `app/lib`, `tooling/`, `.github/` taramasında sıfır sonuç. Uygulama `dispatch-push`'u hiç çağırmıyor (`functions.invoke` yalnız `admin-*` fonksiyonlarına).

Dahası cron worker'ı gövdeye `{"source":"scheduled_retry"}` yolluyor, `action` yollamıyor
([0069:33](supabase/migrations/0069_push_dispatch_retry_health.sql:33)); fonksiyon bu durumda 378. satırdaki `claim_push_deliveries` fallback'ine düşüyor — bu davranış eski deploy'da da aynı. **Yani bayat Edge deploy'u retry worker'ını bozmuyor.**

Bu bir **P2 izlenebilirlik borcu**dur. P0 yapmak, Codex'in kendi eleştirdiği hataya düşmektir: gereksiz bir staging deploy turu daha.

---

## 5. Doğrulanan bulgular (Codex haklı)

Hepsini bağımsız olarak teyit ettim:

| Codex iddiası | Durum | Kanıt |
|---|---|---|
| Hata zinciri `snapshot → notificationsEnabled → resolvePlatformSpecificImplementation` | ✅ | Yerel repro stack'i birebir |
| `514db21` yalnız `initialize()`'ı koruyor, 117. satır korumasız | ✅ | [app_push_notification_service.dart:113-122](app/lib/core/notifications/app_push_notification_service.dart:113) |
| Yeni test `notificationsEnabled`/`snapshot` çağırmıyor | ✅ | Test dosyası yalnız `initialize()` çağırıyor |
| `error.toString().startsWith(...)` kırılgan; `_initialized` false kalıyor | ✅ | Kod okundu |
| 4304: 676+9 / 4305: 677+9, aynı 9 test | ✅ | CI logları |
| Eski release workflow'u tam suite koşmuyordu | ✅ | `3bdf8bb:release.yml` yalnız manifest gate testi |
| 23 Temmuz 12:25–12:59 arası 7 Database Gates koşusu | ✅ | `gh run list` |
| Her manuel apply, `needs: validate` yüzünden full local replay'i tekrarlıyor | ✅ | [database-gates.yml:93](.github/workflows/database-gates.yml:93) |
| Remote pgTAP tamamen kaldırıldı, yerine tek sorgu geldi | ✅ | `9f6c571` diff: `supabase test db --linked` → `db query` |
| `configuration_status` yalnız satır varlığına bakıyor, alan doluluğuna değil | ✅ | [0069:105](supabase/migrations/0069_push_dispatch_retry_health.sql:105) |
| `production` Environment koruma kuralı yok; `main` korumasız | ✅ | `gh api .../environments` → `"protection":[]`, branch protection 404 |
| `progress.md` hâlâ `4303`/`0068`; `pubspec` `+4303`; KALITE-PROGRAMI `0068` | ✅ | Dosyalar okundu |
| 16 commit / 46 dosya / +2322 −1915 | ✅ | `git diff --shortstat 3bdf8bb..HEAD` |
| Kurallar silinmedi | ✅ | `AGENTS.md`/`.agents/` diff temiz |
| Production'a dokunulmadı, v43 korunuyor | ✅ | Yeni stable run/tag/apply yok |

**WP-269 savunulmalı.** Ek kanıt: `beta-v4303`'te "Windows Release Artifact" koşusu **düştü** (run 29956967665) ama release yine de yayımlandı — GitHub'daki `beta-v4303` prerelease'inde yalnız `app-beta-release.apk` var, Windows artefaktı **yok**. WP-269'un atomik iki-platform kapısı tam olarak bunu engelliyor. Bugünkü acı, o doğru kapının faturasıdır; kapıyı geri almak çözüm değil.

---

## 6. Asıl sistemik sorun — "şimdi buldum" döngüsünün mekaniği

Codex "her düzeltme dar bir alt adımda doğrulanıyor" diyor. Doğru ama yeterince derin değil. Bu projede döngüyü üreten üç somut yapı var:

**a) Yerel doğrulama ile CI doğrulaması aynı konfigürasyonu çalıştırmıyor.**
`app/env.json` (2 anahtar) ≠ CI Android `env.json` (17 anahtar) ≠ CI Windows `env.json` (14 anahtar, Firebase yok). Üç farklı uygulama var ve hiçbir yerde "yerelde CI'ın koştuğunu koş" komutu tanımlı değil. Ajan yerelde yeşil görüyor, dürüstçe "yeşil" diyor, CI kırmızı. Bu bir dikkat sorunu değil, **eksik bir tooling**.

**b) Doğrulama tag'den sonra.** Deterministik bir hata bile benzersiz bir beta numarasını yakıyor, tur 10-15 dakika sürüyor, ajan panikle ikinci bir "fix" atıyor. Codex bunu yakalamış; (a) ile birleşince neden bu kadar çok tur döndüğü açıklanıyor.

**c) Kapılar "komut çalıştı mı" diye soruyor, "sistem çalışıyor mu" diye değil.** §3'teki donmuş kuyruk bunun kanıtı: sorgu çalıştı → yeşil. Aynı desen `configuration_status`'ta da var (satır var → `configured`).

Bu üçü düzeltilmeden hangi ajanın çalıştığı fark etmez.

---

## 7. Düzeltilmiş öncelik tablosu

Codex'in tablosuna göre değişenler **kalın**.

| Öncelik | Bulgu | Değişiklik |
|---|---|---|
| **P0** | Staging retry worker 21 dk boyunca kuyruğu hiç ilerletmedi | **Codex'te yok** |
| P0 | `notificationsEnabled()` korumasız plugin erişimi | Aynı |
| P0 | `514db21` gerçek çağrı zincirini test etmiyor | Aynı |
| **P0** | Yerel test konfigürasyonu CI'ı temsil etmiyor (4 dart-define) | **Codex'te "Linux/Windows farkı" olarak yanlış teşhis** |
| P1 | Health kapısı değerleri yorumlamıyor | Aynı |
| P1 | Remote pgTAP tamamen kaldırıldı | Aynı |
| P1 | Tam doğrulama tag'den sonra | Aynı |
| P1 | DB değişmeyen adayda staging apply tekrarı | Aynı |
| P1 | Production Environment gerçekte korumasız | Aynı |
| P1 | Stable workflow ↔ kural anlatımı çelişkisi | Aynı |
| **P2** | Staging Edge deploy SHA'sı bayat | **Codex'te P0 — çağıranı olmayan tek dal, indirildi** |
| P2 | `progress.md` / KALITE-PROGRAMI / AJAN-KULLANIM stale | Aynı |
| P2 | Incident kapsamına ilgisiz ürün değişiklikleri girdi | Aynı |
| **—** | "Ortak suite iki job'da tekrar ediyor" | **Geri çekilmeli — iki farklı konfigürasyon, tekrar değil** |

---

## 8. Somut sıra (uygulanmadı, öneri)

**Adım 0 — 5 dakika, kod değişikliği yok.**
`app/env.ci.example.json` (CI Android job'ıyla aynı anahtar seti, sahte Firebase değerleriyle) + tek satırlık bir betik: `tooling/verify-candidate.ps1`. Amaç: "yerelde yeşil" ile "CI'da yeşil" arasındaki farkı kalıcı olarak sıfırlamak. Bugün eksik olan tek şey bu.

**Adım 1 — beta blokajı.**
`AppNotificationCoordinator`'a plugin/capability enjeksiyonu; mesaj metnine bakan `LateInitializationError` yutmayı kaldır. Regresyon testi `snapshot()` → `PushHealthController` → app root zincirini, `FIREBASE_*` define'ları **dolu** olarak koşsun. Kabul: Adım 0'daki komut yerel Windows'ta yeşil.

**Adım 2 — donmuş kuyruğu çöz (Adım 1'e paralel).**
§3'teki üç salt-okunur sorgu. Sonuca göre: cron aktif değilse aktive et; `net.http_post` ulaşmıyorsa Edge/route/secret; satırlar claim edilemezse nedenini kayda geçir. **Bu çözülmeden atılacak beta, cihazda zaten başarısız olacaktır.**

**Adım 3 — health kapısını anlamlı yap.**
`configuration_status` alan doluluğuna baksın; `cron.job.active` ve son `job_run_details` sonucu kontrol edilsin; `stuck_lease_count = 0` ve queue yaşı için eşik konsun; bilinen fixture istisnası açıkça listelensin.

**Adım 4 — tag öncesi aday doğrulaması.**
`workflow_dispatch` ile SHA alan bir "candidate verify" job'ı; Android-konfigli suite + Windows-konfigli suite + iki build smoke. **İki konfigürasyon da korunur.** Yeşilse tag.

**Adım 5 — kapıları değişiklik türüne bağla** (Codex'in Faz 5 tablosu doğru, aynen alınabilir).

**Adım 6 — yönetim gerçeğini temizle** (Codex'in Faz 6'sı doğru).

**Edge deploy izlenebilirliği (P2):** aynı turda, `Staging Push Activation`'ın deploy ettiği SHA'yı bir manifest satırına yazmak yeterli. Ayrı bir kurtarma fazı gerekmiyor.

---

## 9. Codex'in kabul kriterlerine düzeltme

Listesi büyük ölçüde doğru; iki maddesi değişmeli, bir madde eklenmeli:

- ❌ #1 "Aynı dokuz test **Linux/Ubuntu** Android-target davranışında geçiyor" → ✅ **"Aynı dokuz test, `FIREBASE_*` define'ları dolu konfigürasyonda geçiyor (hangi OS olduğu önemsiz)."**
- ❌ #6 "Edge deploy SHA'sı tek kanıtta" — beta'yı bloke etmemeli, P2 olarak ayrı izlenmeli.
- ➕ **Yeni:** "Staging kuyruğundaki iki bekleyen delivery'nin durumu açıklanmış; retry worker'ın kuyruğu fiilen ilerlettiği ardışık iki health okumasıyla gösterilmiş."

---

## 10. Nihai değerlendirme

Codex'in raporu iyi bir rapor: kanıtlı, dürüst, geri alınmaması gereken kazanımları (WP-269, production HOLD) doğru savunuyor ve gerçek yönetim borçlarını doğru sayıyor. Ana yönü kabul edilebilir.

İki kusuru var, ikisi de aynı kökten: **rapor kanıtı toplarken CI'ı otorite kabul etti, kendisi çalıştırmadı.** Bu yüzden (a) yerelde 68 saniyede üretilebilen bir arıza için "Linux'ta doğrula" reçetesi yazdı, (b) elindeki iki health tablosunu yan yana koymadığı için donmuş kuyruğu göremedi.

Proje yeniden yazılacak durumda değil, kurallar silinmemiş, v43 stable güvende. Ama şu an atılacak `beta-v4306`, **Adım 0 ve Adım 2 yapılmadan yine boşa gider** — bu sefer test değil, cihazda push gelmediği için.
