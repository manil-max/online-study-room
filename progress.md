# progress.md — Canlı Durum

> Son güncelleme: **2026-08-01** · Saat dilimi: **Europe/Istanbul**
>
> 🧭 **BU DOSYA TEK GÜNCEL KAYNAKTIR** (sahip kararı, 2026-07-26). Yol haritası,
> açık kararlar, QA kuyruğu ve aktif iş — hepsi burada. `docs/PLAN.md` artık
> yalnız buraya işaret eden bir sapıdır; iki dosyada iki farklı gerçek olmaz.
>
> 🔴 **Sürüm politikası (2026-07-26):** tag oluşturma ve release tetikleme **sahip
> onayına bağlıdır**. Commit/push serbest; düzeltmeler biriktirilip tek sürümde çıkar.
>
> 🧱 **Yapı:** iş **fazlara** bölünür, her fazın altında **WP kartları** durur
> (`.agents/skills/planner/SKILL.md` sözleşmesi). Faz = "neredeyiz", WP = "kim
> neyi yazacak, nereye dokunmayacak, kabul ne".
>
> **Okuma sırası:** `⚡ Aktif Çalışma Kaydı` → `🗺️ Yol Haritası` →
> `Test için bekleyenler` → `Bekleyen Uygulanabilir WP'ler`.

## Proje Gerçekleri

- ✅ **Migration gerçeği (2026-08-01):** repo/local/staging/production üçü de
  **`0116`**. Staging `0115–0116` apply run `30700266897`, production
  `0101–0116` apply run `30700518285`; iki post-check de
  `local|remote|file = 0116` verdi. v57 stable release run `30700647563`
  tamamen yeşil ve tag SHA'sı `3d1960f552165a8b8f0101f2ed357c583fd5ebe6`.
  - ✅ **Kontrat notu:** `tooling/release/deploy-contract.json` içinde staging
    ve production `deploy_enabled` / `release_enabled` değerlerinin dördü de
    `false`; guard bu fail-closed durumu doğrular.
  - **Tarihsel (2026-07-31, düzeltildi):** bu madde bir süre repo/local `0108`,
    staging `0100` ve "hiçbiri replay edilmedi, Database Gates kırmızı" diyordu.
    Üçü de bayatlamıştı; `AGENTS.md §4` release gerçeğini buradan okuttuğu
    için yanlış karar riski taşıyordu.
- **Önceki migration gerçeği (2026-07-28, v56):** repo/local **`0100`** · staging
  **`0100`** · production **`0100`**. Yerel replay `0001→0100` ve 377 pgTAP
  geçti; staging post-check `0100` (run `30380751277`), production post-check
  `0100` (run `30383034112`). Stable v56'nın başarılı son release koşumu
  `30384688718`dir.
- ✅ **Release kapısı yeniden kilitlendi (2026-07-30 · WP-429):**
  `tooling/release/deploy-contract.json` içindeki staging ve production
  `deploy_enabled` / `release_enabled` değerlerinin dördü de `false`.
  `guard.tests.ps1` **75/75**, `release-preflight.tests.ps1` **8/8** geçti;
  commit `b6b47a9`. Bu işlem veritabanına, tag'e veya mevcut v56 yayınına
  dokunmadı; yalnız gelecekteki yanlış apply/release tetiklemesini fail-closed
  yaptı. Yeni staging/production terfisi ve stable release, kendi güncel kanıtı
  ve yeni somut sahip GO'su olmadan açılamaz.
- **Önceki migration gerçeği (2026-07-28, v55 sonrası):** repo/local **`0094`** ·
  staging **`0094`** · production **`0094`** — üç ortam hizalı. PLAN 3 Faz L
  beş adım getirdi: `0090` destek kutusu bilet türü, `0091` sunucudan beslenen
  SSS, `0092` `send_nudge` içinde iki yönlü engelleme, `0093` grup yasağı +
  sunucu tarafı davet kodu yenileme, `0094` herkese açık ad süzgeci. Beşi de
  eklemeli ya da mevcut fonksiyonu **aynı imzayla** değiştiriyor
  (`join_group`, `join_public_group`, `send_nudge`), bu yüzden sahadaki v54
  istemcileri apply sırasında kırılmadı. Tarihsel not (`0089`): `0089` yalnız `0082`'de tanımlanıp
  hiçbir cron'a bağlanmamış olan `expire_global_timer_v2_leases(200)` süpürücüsünü
  dakikalık pg_cron job'ına bağlar; tablo/kolon/indeks/politika/grant değişmez,
  satır eklenmez, geri alma tek `cron.unschedule`'dır. Sırayla staging'e
  (run `30303743005`) ve production'a (run `30307084863`) uygulandı; ikisinde de
  post-check head `0089` bildirdi. Production kapısı apply biter bitmez yeniden
  **HOLD**'a alındı. 🔴 **Asıl düzeltme istemcidedir** — çoklu cihaz senkronu için
  iki cihazda da yeni sürüm şart; `0089` yalnız çöken cihazın koşusunu kapatan
  güvenlik ağıdır.
- **Önceki migration gerçeği (2026-07-27, WP-370):** üç ortam da **`0088`**. `0088` (V2 start/stop artık
  origin cihazı dışlayan timer-sync outbox olayı üretir; timer-sync rollout
  bayrağı açık) sırayla staging'e (run `30296764464`) ve production'a
  (run `30297435093`) uygulandı; ikisinde de post-check head `0088` bildirdi.
  Öncesi `0086`+`0087` Faz F5'te uygulanmıştı (run `30288908244`).
  Önceki hizalama (`0085`) WP-351'de yapılmıştı. Production'ın Supabase CLI
  geçmişi WP-351'de `repair-baseline-0070` ile dolduruldu (yalnız `applied`
  işaretleme, sıfır DDL); ayrıntı
  [`docs/recovery/PRODUCTION-BASELINE.md`](docs/recovery/PRODUCTION-BASELINE.md).
  Deploy contract aynı üç head'i taşır ve production `deploy_enabled` terfi
  bitince **yeniden `false` kilitlendi**.
- **Önceki stable/production:** **v53** yayında (WP-370/371: timer-sync teslim zinciri
  + turun yaşam döngüsüne bağlanması); etkin şema **`0088`**. Öncesi v52
  (Faz F5: presence lease tazeleme + sayaç komut yayını), etkin şema `0087`.
  🟢 `0086` sunucu taraflı olduğu için **v51'de kalan cihazlarda da** aktiflikten
  düşme düzeldi.
  🔴 **Sayaç eşitlemesi v52'de çalışmıyordu ve release notu bunu yanlış vaat
  etti.** v52 yalnız komutun A→sunucu ayağını kapatmıştı; sunucu→B sinyalini
  üreten parça hiç devrede değildi (`enqueue_timer_sync_push` hiçbir gerçek
  yoldan çağrılmıyordu, runtime bayrağı da kapalıydı). Eksik halka `0088` ile
  kuruldu; eşitleme için **iki cihazda da v53** ve push kaydı şart.
  Yedek/PITR **yok** — sahip kararıyla `backup_requirement: "waived"`; bu bir
  muafiyet kaydıdır, duran bir apply izni değildir. Yeni production migration,
  Edge deploy veya stable tag/release yalnız ayrı ve somut sahip GO'su ile yapılır.
- **Beta/staging:** **`beta-v4402`** son beta artefaktıdır; Android APK + Windows
  MSIX/ZIP mevcut, release run `30212796092` bütünüyle PASS. Staging veritabanı
  v56 terfisiyle `0100`dedir. Fiziksel cihaz bağlı olmadığı için bu eski beta
  adayıyla yeni v56 davranışı kabul edilmiş sayılmaz.
- **Release ilkesi:** Android beta/stable artefaktı Android işi başarılı olunca yayımlanır. Windows bağımsız sürer ve başarılı olursa aynı release'e eklenir; Windows hatası Android güncellemesini geri çekmez.
- **Sürüm sırası:** kod/testi biten işler tek QA kuyruğunda birikir; yeni beta/stable yalnız sahip onayıyla çıkar. Eski beta dalga kararları git geçmişindedir.
- **Yönetim kuralı:** Production `deploy_enabled/release_enabled` kapalı olmalı ve
  her terfiden sonra yeniden kapatılmalıdır. Stable yalnız protected `production`
  Environment, exact SHA/head/project-ref GO ve reviewer kanıtıyla ilerler.
  **Mevcut sözleşme bu kurala uygundur; kapılar WP-429 ile fail-closed'dur.**
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md` ve `docs/KALITE-PROGRAMI.md` geçerlidir. Tek çalışma dalı `main`; her WP ayrı commit; production varsayılmaz.
- **Aktif tur:** **PLAN 5 / v57 teknik uygulama planı açıldı.** v56 saha
  geri bildirimi ve rakip uygulama analizi ayrıntılı, bağımlı WP zincirlerine
  dönüştürüldü. Ham/profesyonelleştirilmiş gözlem kaydı:
  `docs/V56-SAHIP-GERI-BILDIRIM-RAPORU.md`. Rakip analizi ve açık ürün borçlarıyla
  birleştirilmiş kapsam: `docs/V57-YAPILACAKLAR.md`. Yürütme gerçeği aşağıdaki
  Ajan A–D kayıtları ve PLAN 5 WP kartlarıdır.
- **Son WP numarası:** **WP-476** (2026-08-01). WP-429 release kilidi tamamlandı;
  WP-430…WP-467 PLAN 5 uygulama, kabul ve teslim zinciridir. WP-468…WP-473
  (bölüm `5.K`) 2026-07-31 tur kapanış denetiminden doğdu: kapı onarımı ve
  turun bıraktığı sessiz borcun kapatılması. Ürün zinciri onlardan sonra sürer.
- **Önceki not (WP-372, 2026-07-27).** V52'de komutun A→server yolu kapanmıştı; server→B timer-sync teslim zinciri WP-370 (`0088`) ile kuruldu, WP-371 turu yaşam döngüsüne bağladı, WP-372 v53 stable'ı çıkardı.
- ✅ **Tarihsel ortam uzlaşması (WP-351, 2026-07-27):** üç ortam `0085`te
  hizalanmış ve production CLI geçmişi onarılmıştı. Güncel head yukarıdaki
  v56 kaydında `0100`dür.

## ⚡ Aktif Çalışma Kaydı

> 🔴 **PARALEL AJAN MODELİ KAPANDI (2026-07-31, sahip kararı).** Sekizli, ardından
> dörtlü Codex hattı bırakıldı; iş **tek ajanla** yürüyor. Eski `### Ajan A/B/C/D`
> kayıtları, ortak koordinasyon panosu, migration/sıcak dosya kilitleri ve lane
> claim protokolü **artık geçerli değildir** — tek ajanda çakışacak lane yok.
> Turun git geçmişi duruyor; kapanış denetimi aşağıdadır.

### 🔍 Tur kapanış denetimi (2026-07-31)

v57 turu 4–8 ajanla yürüdü. Turun sonunda yapılan tam denetimin bulduğu zemin:

| Bulgu | Ölçüm |
|---|---|
| **52 commit `origin/main`'e hiç gitmedi** | Son CI koşumu 2026-07-28; WP-430…WP-463 hiçbir kapıdan geçmedi |
| **Ortak git index'i eski tree'de kalmıştı** | ~30 dosya staged geri-alma; düz `git commit` WP-437/438/442/444/445/459/460 + `0107`/`0108`'i geri alacaktı. `git reset` ile kayıpsız çözüldü |
| **l10n Gate kırmızı** | `study_providers.dart:1750` gömülü TR metin (WP-448) |
| **Database Gates ilk adımda kırmızı** | `guard.tests.ps1`: yerel head `0108`, kontrat `0101` |
| **Tam test 1326/6 kırmızı** | `admin_repository_test` (1) + `campfire_sky_golden_test` (5) |
| **`flutter analyze`** | ✅ temiz |

**Kart iddiaları ile gerçek uyuşmadı.** Ajanların "57/57 yeşil", "44/44 yeşil"
kayıtları kendi seçtikleri hedefli alt kümelerden geliyordu; tam koşum kırmızıydı.
WP-459/460 commit'liydi ama kartları `[ ]` duruyordu. WP-462 üç kez commit'lendi,
ikisi birbirini iptal etti (`50be50a` goldenları değiştirdi, `5fc8249` aynen geri
aldı). `progress.md` eşzamanlı yazıcılar yüzünden üç kez boşaltılıp geri getirildi
ve Ajan A'nın WP-449/450 lane notu kalıcı olarak kayboldu.

**Sessiz ürün hatası (en ağır bulgu).** Commit edilmemiş WP-449 kodu
`upsert_user_task(p_interval_days, p_anchor_date)` ve
`set_user_task_completion(p_occurrence_day)` çağırıyor; bu parametreler hiçbir
migration'da tanımlı değil (`0048` tek tanım). Testler yalnız InMemory
repository'yi sürdüğü için boşluk otomatik kanıtla görünmedi.
✅ **Kapandı — WP-472 (2026-07-31):** `0109` iki RPC'yi de varsayılanlı yeni
parametrelerle yeniden tanımladı, eski imzaları düşürdü (aksi hâlde PostgREST
`42725` alırdı) ve faz doğrulamasını sunucuya taşıdı. Boşluğun bir daha
görünmez olmaması için iki uçlu sözleşme testi eklendi.

### Tek ajan çalışma protokolü

1. Oturum başında kök `AGENTS.md`, `.agents/AGENTS.md`, worker rehberi, bu bölüm,
   ilgili WP kartı, `git status --short` ve son commitler okunur.
2. **Her WP ayrı commit'tir** ve commit sonrası **push edilir.** Lane/kilit yok;
   tek ajan olduğu için `git add -A` ve `commit -a` artık yasak değil, fakat
   commit'in yalnız o WP'nin dosyalarını taşıması şartı sürüyor.
3. 🔴 **Kabul kanıtı ajanın "yeşil" demesi değil, push edilmiş commit üzerinde
   koşan CI'dır.** Hedefli test koşumu geliştirme aracıdır, kapı değildir.
   Kapılar kırmızıyken yeni ürün WP'si başlamaz.
4. Flutter testleri `app/` içinde `--dart-define-from-file=env.json` ile;
   `flutter analyze` bayraksız çalışır (`--dart-define-from-file` kabul etmez).
5. Migration yazılırken head **üç yerde birden** ilerletilir:
   `tooling/release/deploy-contract.json` · `supabase/tests/001_schema_contract.test.sql`
   · `tooling/supabase/guard.tests.ps1`. Local replay bu hostta Docker kalkmadığı
   için koşamıyor; kanıt Database Gates workflow'unun local replay job'ından alınır.
6. Cihaz, staging, release ve production işi otomatik yetki değildir.
   **Production / stable kapıları KAPALI** ve yeni somut sahip GO'su olmadan açılmaz.

### Şu anki durum

- **Faz 0 — zemin temizliği: ✅ TAMAM (2026-07-31).** Index HEAD'e hizalandı;
  devralınan commit edilmemiş iş üç ayrık commit olarak indi:
  WP-449 `3f97e8b` · WP-450 `42e0ac7` · WP-461 `9989d88`. Hedefli koşum 44/44 yeşil.
  WP-461 manifest değişikliği HEAD baytları üzerine yeniden kuruldu: disk sürümünde
  14 satır LF'ten CRLF'e çevrilmişti ve düz commit gerçek 9 satırlık değişikliği
  37 satırlık satır-sonu gürültüsünün içinde gizliyordu.
- **Faz 1 — kapılar: ✅ TAMAM (2026-07-31).** WP-468 `5ee1ab2` · WP-469 `16c7cc3` ·
  WP-470 `1da65f0` · WP-471 `00fd27a`.

  | Kapı | Önce | Sonra |
  |---|---|---|
  | `flutter test` | 1326 / **6 kırmızı** | **1332 / 0** |
  | `flutter analyze` | temiz | temiz |
  | `scripts/l10n_audit.py` | **FAIL 1** | OK (1466 anahtar) |
  | `guard.tests.ps1` | **ilk assert'te düştü** | 75/75 |
  | `release-preflight.tests.ps1` | **düştü** | 8/8 |

  İki bulgu kayda değer: (1) golden'lar baştan doğruydu, kararsız olan widget'tı —
  `_MemberLabel` enjekte edilen saati yok sayıp duvar saatini okuyordu, bu yüzden
  goldenlar her gün kayıyordu; hiçbir golden dosyası değiştirilmedi ve tolerans
  yükseltilmedi. (2) `release-preflight` beta senaryosu, yerel head staging'in
  önünde olduğu için artık **fail-closed düşüyor** ve test bunu doğruluyor —
  uygulanmamış şemayla beta çıkarılamaz.
- **Sırada:** push → CI'ın üç günde ilk kez koşması. Yeni ürün WP'si yok.
- ✅ **Faz 2 — sessiz borç bitti:** WP-473 (Database Gates ilk kez yeşil: 37
  dosya / 486 pgTAP testi) ve WP-472 (`0109` + iki uçlu sözleşme testi).
- **Sonra Faz 3 — kalan ürün zinciri, tek sıra:**
  `443 → 446 → 447 → 451 → 454 → 455 → 464 → 465 → 466 → 467`.
- **Devralınan açık dirty iş:** iki campfire preview golden (`campfire_wp377_preview.png`,
  `campfire_wp382_preview.png`) hâlâ commit edilmedi; WP-471 kapsamında görüntüye
  bakılarak çözülecek, körlemesine commit edilmeyecek.


## 🗺️ Yol Haritası — sırada ne var

> **Aktif yürütme PLAN 5 / v57'dir.** PLAN 1–4 aşağıda tarihsel ürün ve teslim
> kayıtları olarak korunur; yeni ajanlar iş seçmek için onları değil, en üstteki
> Ajan A–D zincirlerini ve PLAN 5 WP-429…467 kartlarını kullanır.

### Şu anki gerçek durum

| Konu | Durum |
| --- | --- |
| Sürüm | **`v57` stable yayında** · release run `30700647563` · production şeması `0116` |
| Aktif plan | **PLAN 5 / v57 tamamlandı** · deploy/release kapıları yeniden kilitli |
| Cihaz kabulü | ⚪ **v57 için sahip muafiyeti:** beta-v5701, fiziksel cihaz QA ve 3 günlük soak 2026-08-01 kararıyla bu sürümden kaldırıldı |
| Sürüm politikası | 🔴 Sahip onayı olmadan yeni sürüm çıkmaz |
| Otomatik doğrulama | v57: analyze + 1514 Flutter + 34 golden + Windows kritik akış + Deno + coverage ratchet; temiz replay 663/663 pgTAP yeşil |
| l10n | İlk mağaza runtime hedefi yalnız TR+EN; generated paket daraltması WP-457 |
| Migration | Repo/local/staging/production **`0116`** |
| Yedek | 🔴 **Yok.** Free plan; PITR ve günlük yedek kapalı. Sahip kararıyla muaf; geri dönüş yolu yok |
| Beta | **`beta-v4402`** son beta; Android APK + Windows MSIX/ZIP hazır, V3 flag'leri kapalı |
| Remote kapıları | staging + production deploy/release dört bayrak v57 sonrası **kapalı** |
| Play Console | 🟢 **Doğrulama alındı** (2026-07-28). Form doldurulmadı; hazırlık PLAN 3 · Faz M |
| Microsoft Partner Center | 🟢 **Doğrulama alındı** (2026-07-28). Ana odak Play; Microsoft PLAN 2 · Faz H'de kalır |

---

## PLAN 1 — ÜRÜN & KOD

### Faz A — Doğrulama borcu ✅ *KAPANDI (sahip, 2026-07-26)*

Sahip v46–v48 turlarında cihazda test etti ve tek tek doğruladı: **özel tema
okunabilirliği · spektrum renk seçici · font düğmelerinin sabitliği · grafikteki
gün etiketleri · boş ikinci bildirim · taç ve aura** — hepsinde sorun yok.

- **Şifre değiştirme/sıfırlama** Faz C'de kodlandı; iki cihazlı kabulü tek QA
  kuyruğunda WP-319 olarak duruyor.

**Faz A'dan çıkan kod bulguları → Faz C5.**

---

### Faz B — Admin & geri bildirim döngüsü · kodlandı, QA bekliyor

Ek görüntüleme, çift yönlü yazışma ve arşivleme kodlandı. Faz B'de yeni kod işi
yok; üç akış aynı staging/beta kabul turunda doğrulanacak.

#### Kod/testi tamamlanan WP'ler

| WP | Kod durumu | Kalan kapı |
| --- | --- | --- |
| **WP-316** Geri bildirim eki | Kod/test + staging tamam | Staging cihaz kabulü |
| **WP-317** Admin ↔ kullanıcı yazışması | Kod/test tamam | Beta akış + RLS/push kabulü |
| **WP-318** Bilet arşivi | Kod/test tamam | Beta arşiv/geri alma kabulü |

> Bu üç WP yeniden claim edilmez; yalnız aşağıdaki **Test için bekleyenler**
> kuyruğundan doğrulanır. Testte hata çıkarsa yeni WP açılır.
---

### Faz C — Hesap, güvenlik, ayarlar hijyeni

Faz C'nin kod işleri tamamlandı. Yalnız cihaz kabulü ve Faz H'deki gerçek Store
paketi kontrolü kaldı.

#### Kod/testi tamamlanan WP'ler

| WP | Kod durumu | Kalan kapı |
| --- | --- | --- |
| **WP-319 / 319-G** Şifre değiştirme, sıfırlama, diğer oturumları kapatma | Kod/test tamam | İki cihaz + Android recovery kabulü |
| **WP-320** Ayarlar bilgi mimarisi | Kod/test tamam | Android/Windows yerleşim kabulü |
| **WP-321** Yalnız TR + EN | Kod/test tamam | Dil listesi + DE cihaz fallback kabulü |
| **WP-322** Teknik borç temizliği | Kod/test tamam | Kapandı; Store kanalının gerçek paket kontrolü Faz H'ye ait |

> Test bekleyen ilk üç kayıt aşağıdaki tek QA kuyruğundadır. WP-322 yeniden
> claim edilmez; Microsoft Store paketi oluşmadan ayrıca cihaz testi yoktur.
---

### Faz D — Yeni kullanıcı deneyimi (tanıtım turu)

Şu an sadece açılışta tek bir `onboarding_screen` var; uygulama içinde hiçbir
yerde rehberlik yok.

> **WP-323 → WP-324 zinciri tamamlandı.** Proje sahibi WP-324 için WP-323 cihaz
> kabulü ön koşulunu ve ayrıca cihaz kabulünü açıkça atladı (2026-07-26).

#### WP-323: Tanıtım turu motoru 🎈

- **Durum:** [~] Kod/test tamam — Android + Windows cihaz kabulü bekliyor.
- **Kanıt:** `flutter analyze` temiz · tam paket **849 test yeşil**; kullanıcı,
  sürüm ve ekran anahtarları, kuyruk engeli, kalıcılık ve 360 px sınırı kapsandı.
- **Kalan:** Ayrıntılı kabul adımları aşağıdaki **Test için bekleyenler** kuyruğunda.

#### WP-324: Tanıtım turu içerikleri ✍️
- **Program/Faz:** Faz D · Yeni kullanıcı deneyimi
- **Ajan:** Codex · **Durum:** [x] Tamamlandı · **Bağımlılık:** WP-323 motoru
- **Problem:** Motor tek başına bir şey anlatmaz; her ekranın kendi kısa tanıtımı gerekir.
- **Kapsam dışı:** Motor davranışı, yeni ekran tasarımı.
- **SAHİP dosyalar (yaz):** Ana Sayfa · Sayaç · Kamp Ateşi · Gruplar · İstatistik · Profil ekranlarının tur tanımları · `app/lib/l10n/*.arb`
- **DOKUNMA:** `app/lib/core/tour/**` (WP-323'ün motoru — **okunur**)
- **Adımlar:**
  - [x] Ana Sayfa, Sayaç, Gruplar, Kamp Ateşi, İstatistik ve Profil için en fazla 2 balon
  - [x] Metinler TR + EN; DE/AR geri dönüş dosyaları da üretim paritesi için güncellendi
  - [x] Hızlı geçiş WP-323 motoruyla korunuyor; boş veri durumları ayrı ve var olmayan hedefe bağlanmıyor
- **Veri/Migration etkisi:** Yok. · **Ortam/Deploy:** local. · **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** kullanıcının henüz grubu yok (grup turu ne diyecek) · istatistik boşken · kamp ateşi kilitliyken
- **Kabul (ölçülebilir):** Her ekranda balon sayısı **≤ 4** · her balon **≤ 2 satır** · veri boşken tur anlamlı metin gösteriyor (boş ekranı işaret etmiyor) · TR ve EN'de taşma yok.
- **Tuzaklar:** Boş durumda "şurada süren görünür" demek, hiçbir şey görünmeyen bir alanı işaret eder — boş hâl metinleri ayrı yazılmalı.
- **Kanıt:** `flutter analyze` temiz · tam paket **885 test yeşil** · WP-324 içerik/360 px testleri **4/4** · l10n audit yeni bulgu eklemedi (**31 bilinen taban**).
- **Kabul notu:** Proje sahibinin açık yetkisiyle cihaz kabulü atlandı; QA kuyruğuna eklenmedi.
- **Model önerisi:** 🔵 Sonnet

---

### Faz E — Veri doğruluğu ve grup semantiği

**E1. Gün sınırı — yurtdışı kullanıcı.**

⚠️ **Eski plandaki iddia yanlıştı.** "Gün toplamı UTC'ye göre" **değil**: sunucu
tarafı baştan sona `Europe/Istanbul` (`0007`, `0011`, `0024`, `0039`, `0051`,
`0053`, `0062`, `0063` … 60'tan fazla yerde), istemci de `istanbulDay`. "İstanbul'a
çevirme" işi **çoktan yapılmış**.

⚠️ **Backfill diye bir iş de yok.** Gün toplamları hiçbir tabloda saklanmıyor;
`get_user_day_totals` her çağrıda ham `study_sessions` satırlarından hesaplıyor.

**Gerçek açık:** herkesin günü İstanbul yarısında sıfırlanıyor.

| Kullanıcı | Gün ne zaman sıfırlanıyor | Sonuç |
| --- | --- | --- |
| Türkiye (UTC+3) | 00:00 | doğru |
| Sydney (UTC+11) | 08:00 | sabah çalışması düne yazılır |
| New York (UTC−5) | 16:00 | 🔴 akşam çalışması yarına yazılır |

**Çözüm (K8):** gün sınırı **birincil grubun bölgesinden** gelir →
grubu yoksa **cihazın** saat dilimi → o da yoksa `Europe/Istanbul`.
Böylece kişisel ve grup istatistiği **asla çelişmez**.

> **Tamamlanan zincir:** WP-325 → WP-326 → WP-327. Kalan WP-328 ve WP-329
> `supabase/migrations/**` sıcak yüzeyi nedeniyle seri yürür.

#### Kod/testi tamamlanan WP'ler

| WP | Kod durumu | Kalan kapı |
| --- | --- | --- |
| **WP-315** Grup üye sınırı 8 | Kod/test tamam; `0071` staging'e uygulandı | Beta cihazda 8 sınırı |
| **WP-325** Oturum gününü kayıt anında damgalama | Kod/test + staging tamam | Cihaz/veri eşliği kabulü |
| **WP-326** Grup bölgesi ve gün sınırı zinciri | Kod/test + staging tamam | Beta saat dilimi kabulü |
| **WP-327** Grup bölgesi ve anlık saat farkı | Kod/test + staging tamam | Beta kart/diyalog kabulü |
| **WP-328** Keşif sıralaması + arama/filtre | Kod/test + staging tamam | Android/Windows filtre kabulü |
| **WP-329** Birincil grup | Kod/test + staging tamam | WP-348 revizyonu + iki cihaz primary kabulü |

> `0073→0084` zinciri staging'e terfi etti. Bu kartlar yeniden claim edilmez;
> birincil grubun yeni IA/cooldown talebi ileri migration kullanan **WP-348**'dir.

#### WP-329: Birincil grup 🏠
- **Program/Faz:** Faz E · Grup semantiği · **Durum:** [~] Kod/test + staging tamam; WP-348 revizyonu/cihaz kabulü bekliyor · **Bağımlılık:** WP-326 + WP-328
- **Problem:** Kullanıcı birden çok gruba üye olabiliyor; UI'da seçili grup ile görev/hedef/grup progression muhasebesini alan birincil grup aynı kavram sanılıyor. Tercih cihazlar arasında ortak ve server-authoritative değil.
- **Kapsam dışı:** Çoklu grup üyeliğini kaldırmak · presence'ı yalnız primary gruba indirmek · direct grup bildirimlerini primary ile filtrelemek · geçmiş session'ları yeniden atfetmek · gün-sınırı algoritmasını değiştirmek.
- **SAHİP dosyalar (yaz):** `supabase/migrations/00NN_primary_group_preference.sql` · `app/lib/data/providers/group_providers.dart` · ilgili group repository interface + Supabase/InMemory çiftleri · birincil grup seçim UI'ı ve testleri
- **DOKUNMA:** `groups.time_zone` (WP-326) · keşif (WP-328) · `study_sessions`/`project_group_day`/başarım projeksiyonları (WP-336) · presence/timer kodu (WP-338+) · push dispatcher
- **Adımlar:**
  - [ ] Private `user_group_preferences` + append-only preference history kur; mutation yalnız security-definer RPC.
  - [ ] Kullanıcı yalnız aktif üyesi olduğu grubu primary seçebilsin; iki cihaz seçimi kullanıcı lock'u + selection revision ile sıralansın.
  - [ ] Tek aktif grubu olan kullanıcı otomatik primary olsun; hiç grubu yoksa null; çok grubu olup seçimi yoksa rastgele atama yapılmasın.
  - [ ] Aktif timer varken primary değişimi timer/bildirim/widget'ı restart etmesin; yeni seçim sonraki çalışma/session için geçerli olsun.
  - [ ] UI'daki seçili/gezilen grup cihaz-yerel kalırken primary hesap-geneli gösterilsin.
  - [ ] Direct grup duyurusu/dürtmesi bütün ilgili üyeliklerde sürsün; yalnız duplicate event idempotency uygulansın.
- **Veri/Migration etkisi:** Yeni preference + history tabloları/RPC. Tek grubu olanlara deterministic backfill; çok gruplular seçim bekler. Remote'a uygulanınca down migration yerine flag kapatma + ileri düzeltme. `study_sessions.day` değişmez.
- **Ortam/Deploy:** local → staging → production ayrı GO.
- **RLS/Güvenlik:** Preference/history public profile'a sızmaz; client primary revision veya history zamanı seçemez; membership leave/delete ile preference aynı kullanıcı lock sınırında uzlaştırılır.
- **Edge-case'ler:** hiç grup yok · tek grup · çok grup/seçim yok · iki cihaz eşzamanlı seçim · primary üyeliği bitmiş · grup silinmiş · aktif timer sırasında seçim · offline cihazda stale preference.
- **Kabul (ölçülebilir):** Telefon ve tablette aynı primary görünür · stale selection revision güncel tercihi geri alamaz · üye olunmayan grup RPC'de reddedilir · tek grup otomatik seçilir · primary silinince güvenli null/yeniden seçim oluşur · timer/bildirim/widget primary değişiminde sıfırlanmaz · secondary gruptan geçerli direct bildirim primary filtresiyle kaybolmaz.
- **Tuzaklar:** `active_group_id/userGroupProvider` primary otoritesi yapılmaz; current preference geçmiş session'a uygulanmaz; “bildirimler yalnız primary” eski kart ifadesi geçersizdir.
- **Model önerisi:** 🔴 Opus

### Faz E2 — Global Timer, Çoklu Grup Presence ve Çoklu Cihaz V3

> Kanonik teknik plan: `docs/GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md` V3.
>
> Delivery A/B uygulanabilir; Delivery C migration'ı WP-337 compatibility gate geçmeden yazılmaz. Gün sınırı, server finalizer, Pomodoro global fazı ve background native auto-start bu fazın dışındadır.

#### WP-336: Tek-grup session attribution ve progression filtresi 🎯
- **Program/Faz:** Faz E2 · WP-329 entegrasyonu · **Ajan:** Codex · **Durum:** [~] Kod/test + staging tamam — cihaz kabulü bekliyor · **Bağımlılık:** WP-329
- **Problem:** `project_group_day/week` session'ı üye olunan bütün gruplara yazıyor; primary UI seçimi grup hedefi/başarımı/leaderboard çift sayımını durdurmaz.
- **Kapsam dışı:** Gün/timezone algoritması · geçmiş XP'yi geri almak · presence'ı primary gruba indirmek · server timer finalizer.
- **SAHİP dosyalar (yaz):** yeni `supabase/migrations/00NN_session_group_attribution.sql` · ilgili `supabase/tests/*.test.sql` · grup metric contract testleri
- **DOKUNMA:** WP-329 preference UI/provider · native timer/bildirim/widget · push · uygulanmış `0010/0053/0063`
- **Adımlar:** one-to-zero/one `study_session_group_attribution` kur · başlangıç anındaki primary'yi preference history'den server-side çöz · cutover öncesini `legacy_multi_group`, sonrasını fail-closed `primary_v1` ayır · yeni ileri migration ile day/week/trigger/cron/catch-up yollarını attribution-aware yap · `raw→seg→camp/alpha/loco` zincirini yalnız attribution grubuyla kur.
- **Veri/Migration etkisi:** Additive ilişki + cutover config + fonksiyon replace; eski session/ödül korunur. Geri alma: flag kapatma + ileri düzeltme, veri silme yok.
- **Ortam/Deploy:** Local replay/pgTAP → staging; production yalnız backup/dry-run/soak ve somut GO.
- **RLS/Güvenlik:** Client attribution seçemez; session/preference history server doğrular; silinen grup için audit snapshot'ı korunur.
- **Edge-case'ler:** offline geç session · çalışma sırasında primary değişimi · cutover sınırı · cron eski günü recompute · grup silinmesi.
- **Kabul (ölçülebilir):** Cutover sonrası bir session en fazla bir gruba gider · secondary day/week/achievement katkısı 0 · cron secondary veriyi geri getirmez · kişisel süre/XP mevcut tek writer ile değişmez · geçmiş ödül geri alınmaz.
- **Kanıt:** Local `0080` replay ve 206 pgTAP PASS · `flutter analyze` temiz · `flutter test --dart-define-from-file=env.json` PASS. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Tuzaklar:** `counts_for_group_progression` canlı read-model alanıdır; tarihsel recompute otoritesi değildir. Eski `0063` düzenlenmez.
- **Model önerisi:** 🔴 Opus

#### WP-337: V3 legacy compatibility ve donuk kontrat kapısı 🔬
- **Program/Faz:** Faz E2 · Delivery C0 · **Ajan:** Codex · **Durum:** [x] Kod/test + aggregate kanıtı tamam (staging GO) · **Bağımlılık:** Yok
- **Problem:** `live_study_runs` index/CHECK/NOT NULL, legacy RPC, Dart enum ve iki native queue sınırı kanıtlanmadan migration yazılırsa ghost lock veya parse hatası oluşur.
- **Kapsam dışı:** Migration/feature/deploy · timer UX refactor · remote mutasyon.
- **SAHİP dosyalar (yaz):** `docs/GLOBAL-TIMER-V3-COMPATIBILITY-EVIDENCE.md` · `app/test/data/global_timer_v3_legacy_contract_test.dart`
- **DOKUNMA:** `supabase/migrations/**` · `study_providers.dart` · Android native kaynaklar · `LiveStudyRun`
- **Adımlar:** 0051 invariant envanteri · local/staging/production salt-okunur `running/paused` count + index/CHECK kanıtı · birleşik active-study index testi · ortak advisory-lock kararı · legacy DTO/InMemory/Supabase yüzeyi · `commandSeq` ile `pendingIntervals` ayrımı · V2 flag/DTO kararları.
- **Veri/Migration etkisi:** Yok; çıktı WP-341'in GO/NO-GO girdisidir.
- **Ortam/Deploy:** Local + redacted salt-okunur staging/production; deploy yok.
- **RLS/Güvenlik:** Yalnız aggregate/schema metadata; UUID/token/secret kanıta girmez.
- **Edge-case'ler:** açık/paused legacy run · eksik CLI history · V2 terminal status'un legacy DTO'ya düşmesi · iki protocol start yarışı.
- **Kabul (ölçülebilir):** G1–G6/H1–H4 PASS/FAIL · ortam başına açık legacy sayısı · hedef tek active index · V2 DTO/flag/lock kararı · migration GO/NO-GO.
- **Kanıt:** `docs/GLOBAL-TIMER-V3-COMPATIBILITY-EVIDENCE.md`; G1–G6/H1–H4 PASS, local/staging/production aggregate `running=0`, `paused=0`; Database Gates `30211293548`/`30211294358` salt-okunur PASS. `flutter analyze` temiz, tam `flutter test` 910 test yeşil (2026-07-26). **Kodda ve remote aggregate'de doğrulandı.**
- **Tuzaklar:** GO yalnız staging V3 terfisi içindir; production migration/flag/stable GO türetmez.
- **Model önerisi:** 🔴 Opus

#### WP-338: Server-derived çoklu grup presence çekirdeği 👥
- **Program/Faz:** Faz E2 · Delivery A backend · **Ajan:** Codex · **Durum:** [~] Kod/test + staging tamam; flag/cihaz kabulü bekliyor · **Bağımlılık:** WP-329; migration sırası WP-328/WP-329 sonrası
- **Problem:** `presence(user_id PK, group_id)` kullanıcıyı yalnız seçili grupta gösterebilir; Flutter heartbeat ölünce görünürlük kaybolur.
- **Kapsam dışı:** Global run · push · session/XP finalizer · gün sınırı · native uplink.
- **SAHİP dosyalar (yaz):** yeni `supabase/migrations/00NN_multi_group_presence_projection.sql` · ilgili pgTAP/RLS testleri
- **DOKUNMA:** client provider/repository (WP-339) · native timer · push · session projectionları (WP-336)
- **Adımlar:** kullanıcı başına `user_live_presence_state` kanonik state/lease · `(group_id,user_id)` projection · start/stop'ta üyelik fan-out · heartbeat yalnız kanonik lease · join/leave/ban cleanup · primary progression flag · kullanıcı-lock'lu idempotent sweeper · eski presence fallback.
- **Veri/Migration etkisi:** Additive tablolar/RPC/RLS/Realtime; rollback new-read flag kapatma, eski tablo korunur.
- **Ortam/Deploy:** Local replay/pgTAP → staging; production ayrı GO.
- **RLS/Güvenlik:** Client projection DML yapamaz; yalnız kendi state RPC'si; aktif aynı grup üyeliği yoksa read yok.
- **Edge-case'ler:** 0/1/2/10 grup · join/leave/ban · primary null · iki heartbeat/sweeper · stale stop.
- **Kabul (ölçülebilir):** Bütün aktif gruplarda tek satır · heartbeat başına projection write 0 · leave/ban read 0 · secondary flag false · iki sweeper tek transition · çapraz grup sızıntısı 0.
- **Tuzaklar:** Yalnız server'ın bildiği state fan-out edilir; Flutter hiç uyanmazsa native start henüz bilinmez.
- **Kanıt:** Local `0081` replay ve 218 pgTAP PASS · deploy guard 51 PASS · `flutter analyze` temiz · `flutter test --dart-define-from-file=env.json` PASS. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🔴 Opus

#### WP-339: Presence client cutover ve seçili-grup bağını kaldırma 🔄
- **Program/Faz:** Faz E2 · Delivery A client · **Ajan:** Codex · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-338
- **Problem:** Publish/watch `userGroupProvider` ve tek `group_id`ye bağlı; auth/grup hazır değilse start presence kayboluyor.
- **Kapsam dışı:** Native outbox · global mirror · push · timer UI refactor.
- **SAHİP dosyalar (yaz):** presence repository interface + Supabase/InMemory/Offline çiftleri · `presence_providers.dart` · `presence_lifecycle.dart` · dar `study_providers.dart` adapter'ı · testler
- **DOKUNMA:** Android notification/widget action/layout · `TimerStateStore` · global coordinator · discovery/primary UI
- **Adımlar:** group parametresiz state/heartbeat API · grup projection subscription · auth-ready pending publish · old/new dual-read telemetry/flags · repository parity · sessiz hata yerine queue-age/error gözlemi.
- **Veri/Migration etkisi:** Yok; WP-338 şeması.
- **Ortam/Deploy:** Local → staging beta; production read switch ayrı kabul.
- **RLS/Güvenlik:** Client fan-out gruplarını seçmez; account switch pending publish'i başka hesaba göndermez.
- **Edge-case'ler:** cold-start auth · cihazlarda farklı selected group · primary üçüncü grup · offline/reconnect · eski client.
- **Kabul (ölçülebilir):** App start bütün gruplarda · selected group projection ownership'i değiştirmez · auth gecikmesinde event kaybı 0 · ağ hatası timer yüzeylerini bozmaz · kill switch çalışır.
- **Kanıt:** `flutter analyze` temiz · V3 lease/fallback/offline kuyruk/contract testleri yeşil. Tam `flutter test` koşumu tek worker'da ilerlemesiz kaldığı için sonlandırıldı; staging + çoklu cihaz kabulü WP-346 ortak QA turunda. **Kodda doğrulandı; cihazda doğrulanmalı.**
- **Tuzaklar:** Sıcak timer yolunda network await yok; notification/widget kodu temizlenmez.
- **Model önerisi:** 🟣 Pro

#### WP-340: Native V2 durable command envelope ve cold-start flush 📦
- **Program/Faz:** Faz E2 · Delivery B · **Ajan:** Codex-2 · **Durum:** [x] Kod/test tamam · **Bağımlılık:** WP-337
- **Problem:** External-command köprüsü ve interval kuyruğu global start/stop intent'ini hesap-bağlı, retry edilebilir command olarak temsil etmiyor.
- **Kapsam dışı:** Native network/credential uplink · server apply · notification/widget UI · remote start.
- **SAHİP dosyalar (yaz):** `TimerStateStore.kt` · `StudyTimerService.kt` yalnız envelope enqueue noktaları · Dart parser/flush adapter · Android/Dart contract testleri
- **DOKUNMA:** notification ID/channel/layout/PendingIntent · `ACTION_STOP_SILENT` · server migration · `TimerExternalCommandStore` yerel köprü semantiği
- **Adımlar:** V2 `kind/schema_version/command_id/account_id/installation_id/action/client_occurred_at/origin/run_id?/expected_run_revision?` · legacy parser uyumu · Android'de tek native envelope üreticisi · Flutter command ID aktarımı/native UUID · unbound account karantinası · UUID kısmi ack · shadow flag.
- **Veri/Migration etkisi:** Yalnız SharedPreferences format evrimi; DB yok.
- **Ortam/Deploy:** Local/unit/instrumentation; remote yok.
- **RLS/Güvenlik:** Secret/token yok; account mismatch fail-closed; action allowlist.
- **Edge-case'ler:** process kill · start-stop-start · logout/account switch · bozuk JSON · legacy+V2 karışık array · disk failure · duplicate.
- **Kabul (ölçülebilir):** Eylem başına tek command ID · legacy interval kaybı/çift session 0 · yanlış hesap gönderimi 0 · widget ≤500 ms ve 8 saat drift baseline değişmez.
- **Tuzaklar:** `commandSeq` distributed sürüm değildir; start'a sahte `runToken` yazılmaz; üçüncü queue açılmaz.
- **Kanıt:** `flutter analyze` temiz; `flutter test --dart-define-from-file=env.json -r compact` 899 test geçti. Hedefsiz Gradle Kotlin çağrısı varyant/ortam validasyonunda kesildi; beta artefakt/cihaz doğrulaması kullanıcı sırasına göre WP-345 sonrasındaki ortak QA turunda, `env.json` ile yapılacak.
- **Model önerisi:** 🔴 Opus

#### WP-341: Global timer V2 server çekirdeği ve compatibility migration 🧠
- **Program/Faz:** Faz E2 · Delivery C backend · **Ajan:** Codex-3 · **Durum:** [~] Kod/test + staging tamam; flag/cihaz kabulü bekliyor · **Bağımlılık:** WP-337 GO + WP-338; migration hattında WP-336/WP-338 sonrası
- **Problem:** Aynı hesabın cihazları arasında kanonik run, kullanıcı-geneli state version ve idempotent command otoritesi yok.
- **Kapsam dışı:** Client native apply · push · server session/XP finalizer · pause/Pomodoro/countdown · production deploy.
- **SAHİP dosyalar (yaz):** yeni `supabase/migrations/00NN_global_timer_v2.sql` · ilgili pgTAP/RLS/concurrency testleri
- **DOKUNMA:** uygulanmış `0051` · legacy Dart model/repository · client/native · push
- **Adımlar:** `live_study_runs` additive V2 alanları/backfill · `status` CHECK genişletme, ikinci state yok · eski index'i birleşik study index ile aynı transaction'da değiştir · `user_timer_state`/command/device tabloları · `command_id→client_request_id` · ortak lock · start/stop/heartbeat/snapshot/ack · run/state version · abandoned/sweeper · presence transaction · V2 flag false.
- **Veri/Migration etkisi:** Additive + tek index replacement + CHECK genişletme; delete yok. Rollback flag kapatma + ileri migration.
- **Ortam/Deploy:** Local full replay/concurrency; staging WP-346; production yok.
- **RLS/Güvenlik:** auth.uid owner · device revoke · direct DML kapalı · result snapshot hesap izolasyonu · rate limit.
- **Edge-case'ler:** legacy açık run · iki protocol yarışı · yeni run rev1/eski rev11 · stale stop · iki sweeper · ghost · aynı command ID iki hesap.
- **Kabul (ölçülebilir):** Bütün protocol'lerde aktif study ≤1 · new-run rev1 kabul · abandoned bloklamaz · hesaplar arası snapshot sızıntısı 0 · heartbeat projection write 0 · iki sweeper tek abandoned/state version.
- **Tuzaklar:** V2-only index yasak; legacy DTO'ya terminal V2 status dönmez; V1 `finalized` üretmez; `_verifiedServerAvailable` açılmaz.
- **Kanıt:** `0082` local şemada uygulandı; 236 pgTAP PASS · deploy guard 51 PASS · `flutter analyze` temiz · `flutter test --dart-define-from-file=env.json` PASS. V2 runtime flag kapalı. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🔴 Opus

#### WP-342: Flutter global coordinator ve shadow publish 🛰️
- **Program/Faz:** Faz E2 · Delivery C shadow · **Ajan:** Codex · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-340 + WP-341
- **Problem:** Server çekirdeği ile local/native timer arasında versioned snapshot, outbox flush ve reconcile katmanı yok.
- **Kapsam dışı:** Native remote apply · push · timer UI · session finalizer.
- **SAHİP dosyalar (yaz):** yeni global timer model/repository/coordinator · Supabase/InMemory çiftleri · WP-340 flush entegrasyonu · testler
- **DOKUNMA:** legacy `LiveStudyRun/LiveRunStatus` ve verified repository · Android notification/widget görünümü
- **Adımlar:** ayrı `GlobalTimerSnapshot` DTO · state/run CAS · auth/account-bound flush · login/cold-start/foreground/network/realtime coordinator · shadow-only divergence · InMemory parity · support telemetry.
- **Veri/Migration etkisi:** Yok; WP-341 RPC.
- **Ortam/Deploy:** Local → staging shadow; native apply kapalı.
- **RLS/Güvenlik:** Account switch isolation; başka hesap snapshot'ı apply edilmez; secret loglanmaz.
- **Edge-case'ler:** commit/response loss · duplicate retry · auth refresh · offline iki start · existing run · local newer start.
- **Kabul (ölçülebilir):** Retry aynı sonuç · snapshot rollback 0 · process-death queue korunur · local start p95 baseline aynı · divergence ölçülebilir.
- **Tuzaklar:** Android Flutter ikinci command producer olmaz; legacy verified yolu açılmaz.
- **Kanıt:** `flutter analyze` temiz · V2 snapshot/idempotency ve push-device contract testleri yeşil. Rollout varsayılanı `disabled`; staging/cihaz kabulü WP-346 ortak turunda. **Kodda doğrulandı; cihazda doğrulanmalı.**
- **Model önerisi:** 🟣 Pro

#### WP-343: Foreground çoklu cihaz mirror ve güvenli remote stop 📱↔️📱
- **Program/Faz:** Faz E2 · Delivery C apply · **Ajan:** Codex · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-342 shadow kabulü
- **Problem:** İki foreground cihaz aynı global çalışmayı göstermiyor; başka cihaz stop'u native yüzeylere güvenle uygulanmıyor.
- **Kapsam dışı:** Background auto-start · FCM · finalizer · Pomodoro/countdown mirror.
- **SAHİP dosyalar (yaz):** coordinator foreground apply · dar Android remote-apply metadata/action alanları · ack/UX · testler
- **DOKUNMA:** normal local start/stop sırası · notification/widget layout · session/XP · push
- **Adımlar:** Realtime→auth snapshot · CAS/account/run doğrulama · foreground start mirror · `ACTION_STOP_SILENT` remote stop · echo suppression · device ack/opt-out · stale stop guard.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Local iki client → staging iki Android; production yok.
- **RLS/Güvenlik:** Aynı auth + kayıtlı device; doğrulanmamış payload native apply edilmez.
- **Edge-case'ler:** aynı anda start · başka cihaz stop · echo · eski stop · opt-out · logout · local start yarışı.
- **Kabul (ölçülebilir):** Foreground start/stop p95≤2 sn · ek session/XP 0 · eski stop yeni run'ı kesmez · notification/widget regression 0.
- **Tuzaklar:** Remote apply sanal kullanıcı tıklaması değildir; silent stop değiştirilmez.
- **Kanıt:** Doğrulanmış V2 snapshot'tan mirror-start/deferred/aynı-run stop kararı; account+device scoped seen/ack; mirror kaynaklı native V2 echo bastırması ve session/XP yazmayan silent stop kod/test ile kapsandı. `flutter analyze` temiz · tam `flutter test --dart-define-from-file=env.json` PASS. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🔴 Opus

#### WP-344: Timer-sync push transport sınıfı 📬
- **Program/Faz:** Faz E2 · Delivery D backend · **Ajan:** Codex-3 · **Durum:** [~] Kod/test + staging tamam; flag/FCM cihaz kabulü bekliyor · **Bağımlılık:** WP-341
- **Problem:** Mevcut push allowlist/preference/quiet-hours/TTL hattı `timer_sync`i sessizce yutar veya yanlış policy uygular.
- **Kapsam dışı:** Client auto-start · remote truth · genel bildirim refactor · production Edge deploy.
- **SAHİP dosyalar (yaz):** yeni push-policy migration · `supabase/functions/dispatch-push/index.ts` timer handler · contract testleri
- **DOKUNMA:** nudge/announcement/update davranışı · Android timer service · client apply
- **Adımlar:** type CHECK + `_push_type_enabled` · unknown-type hata · quiet-hours/cooldown bypass · kısa TTL/high priority/collapse/`exclude_device_id` · minimal payload · retry/expiry telemetry.
- **Veri/Migration etkisi:** Additive policy/outbox alanları; rollback timer push flag.
- **Ortam/Deploy:** Local function test → staging; production ayrı GO.
- **RLS/Güvenlik:** Token yalnız delivery; minimal payload; başka kullanıcı installation'ına fan-out yok.
- **Edge-case'ler:** quiet hours · duplicate/reverse · expired event · token rotate/revoke · unknown type · origin exclusion.
- **Kabul (ölçülebilir):** Delivery satırı oluşur · unknown silent success 0 · origin delivery 0 · TTL/collapse testleri · push fail global commit'i bozmaz.
- **Tuzaklar:** Timer policy normal kullanıcı bildirimi değildir.
- **Kanıt:** Local `0083` replay ve 244 pgTAP PASS · deploy guard 51 PASS · `flutter analyze` temiz · `flutter test --dart-define-from-file=env.json` PASS. Timer-sync rollout flag kapalı. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🟣 Pro

#### WP-345: Background timer sinyali ve app-open reconcile 🔔
- **Program/Faz:** Faz E2 · Delivery D client · **Ajan:** Codex · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-343 + WP-344
- **Problem:** Background/terminated cihaz için timer-sync deferred UX/ack ve güvenli snapshot reconcile yok.
- **Kapsam dışı:** Kotlin auto-FGS · native authenticated uplink · force-stop anlık garantisi.
- **SAHİP dosyalar (yaz):** Flutter FCM timer routing · coordinator tetikleri · deferred notification/ack UX · testler
- **DOKUNMA:** Android normal timer action/layout · server push handler · hot-path başlangıç
- **Adımlar:** payload schema/state version doğrulama · truth olarak uygulamadan signal · app-open auth snapshot + CAS · seen/deferred/failed ack · token/account cleanup · push-yok reconcile.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Staging gerçek FCM + Android lifecycle; production yok.
- **RLS/Güvenlik:** Payload token/private subject yok; auth olmadan state apply yok.
- **Edge-case'ler:** terminated/force-stop/doze · duplicate/reverse · logout · token rotate · FGS restriction.
- **Kabul (ölçülebilir):** Foreground p95≤2 sn · teslim edilen background signal p95≤10 sn · app-open reconcile p95≤2 sn · rollback 0 · force-stop sonrası açılış doğru.
- **Tuzaklar:** FCM server→device'dır; native start uplink'i değildir.
- **Kanıt:** Yalnız minimal v1 `timer_sync` payload'ı kabul edilir; sinyal SharedPreferences'ta defer edilir ve foreground/app-open'ta auth snapshot reconcile'ını tetikler; payload asla state apply etmez, logout'ta silinir. `flutter analyze` temiz · tam `flutter test --dart-define-from-file=env.json` PASS. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🟣 Pro

#### WP-346: V3 staging, çoklu cihaz kabulü ve rollout kapıları 🧪
- **Program/Faz:** Faz E2 · QA/rollout · **Ajan:** — · **Durum:** [~] Staging + beta artefaktı tamam; fiziksel çoklu cihaz/flag rollout bekliyor · **Bağımlılık:** WP-336 + WP-339 + WP-343 + WP-345
- **Problem:** Global/native değişiklikler gerçek Samsung/Pixel/tablet lifecycle ve migration terfisiyle kanıtlanmadan güvenli sayılamaz.
- **Kapsam dışı:** Production/stable · background auto-start · finalizer; bug düzeltmek (ayrı debug WP).
- **SAHİP dosyalar (yaz):** `docs/qa/DEVICE-QA-MATRIX.md` V3 satırları · staging acceptance raporu · gerekli kanıt/manifest
- **DOKUNMA:** Feature kodu
- **Adımlar:** local replay + staging dry-run · flag sıralı açılış · telefon/tablet, Pixel/Samsung, API33–36 · app/widget/notification/lifecycle/offline/auth yarışları · drift/session/RLS/lease/push/batarya ölçümü · rollback tatbikatı · ≥3 gün beta soak.
- **Veri/Migration etkisi:** Yalnız staging terfisi/kanıt; production yok.
- **Ortam/Deploy:** Local → staging → benzersiz beta; production ayrı somut GO.
- **RLS/Güvenlik:** Cross-account command/result/presence abuse matrisi; redacted kanıt.
- **Edge-case'ler:** OEM pil · force-stop · iki hesap · stale push · lease · join/leave · primary değişimi · eski client.
- **Kabul (ölçülebilir):** Timer/widget/notification regresyon 0 · 8 saat ≤±1 sn · ek session/XP 0 · visibility %100 · secondary progression 0 · foreground p95≤2 sn · teslim edilen push p95≤10 sn · P0/P1 0 · soak≥3 gün.
- **Kanıt/durum:** Staging `0084`, `beta-v4402` Android+Windows release ve otomatik kapılar PASS. ADB listesi boş olduğu için cihaz sonucu yok; V3 flag'leri kapalı tutuldu. **Cihazda doğrulanmalı.**
- **Tuzaklar:** Test bug'ı bu WP'de yamalanmaz; yeni debug WP/beta gerekir. Production GO türetilmez.
- **Model önerisi:** 🔴 Opus

#### WP-347: Grup attribution yapılandırması RLS güvenlik düzeltmesi 🔒
- **Program/Faz:** Faz E2 · release-blocking debug · **Ajan:** Codex · **Durum:** [x] Kod/test + staging terfisi tamam · **Bağımlılık:** WP-336
- **Problem:** `group_progression_attribution_config` doğrudan client yetkileri geri alınmış olsa da RLS kapalı oluşturulmuş; güvenlik denetimi bunu kritik bulgu olarak raporluyor.
- **SAHİP dosyalar (yaz):** `supabase/migrations/0084_group_progression_attribution_config_rls.sql` · `supabase/tests/011_session_group_attribution.test.sql` · `tooling/release/deploy-contract.json` · bu WP kartı.
- **Kapsam dışı:** `0080`i değiştirmek · client policy vermek · timer/notification/widget kodu · production deploy.
- **Kabul:** RLS açık; `anon/authenticated` doğrudan select/insert/update/delete yapamaz; mevcut SECURITY DEFINER trigger/resolver zinciri attribution testinde çalışır; local replay/pgTAP yeşil.
- **Geri alma:** Veri silmeden yeni ileri migration ile yalnız policy/RLS davranışı düzeltilir; `0084` uygulanmışsa geriye dosya değiştirilmez.
- **Kanıt:** Local `0084` replay/246 pgTAP PASS · deploy guard 56 PASS · Database Gates [30211582040](https://github.com/manil-max/online-study-room/actions/runs/30211582040) staging `0073→0084` apply, migration-list ve push post-check PASS. **Kodda ve staging'de doğrulandı; cihazda doğrulanmalı.**

#### V3 paralel çalışma ve migration sırası

```text
Migration hattı:
WP-328 → WP-329 → WP-336 → WP-338 → WP-341 → WP-344

Kanıt/client/native hattı:
WP-337 → WP-340
WP-338 → WP-339
WP-340 + WP-341 → WP-342 → WP-343
WP-343 + WP-344 → WP-345
hepsi → WP-346
```

> ✅ İlk güvenli paralel dalga: WP-328 + WP-337.
>
> ⚠️ Migration kullanan WP-328/329/336/338/341/344 paralel başlamaz.
>
> ⚠️ `study_providers.dart`/native timer yüzeyindeki WP-339/340/342/343 sahip sınırı teyit edilmeden paralel başlamaz.

---

### Faz F — Kamp ateşi ve görsel işler

Kod/test tamam; mağaza çıkışını **bloklamaz**. Kalan kabul tek QA kuyruğunda.

| WP | İş | Durum | Not |
| --- | --- | --- | --- |
| **WP-295** | Kamp ateşi: oturma yayları + 2 poz | [~] Kod/test tamam | Cihaz ve performans kabulü aşağıdaki QA kuyruğunda |
| **WP-299** | Gündüz/gece gökyüzü + gece uyuma | [~] Kod/test tamam | Cihaz/ürün kabulü aşağıdaki QA kuyruğunda |
| — | Gökyüzü için grup bölgesi | — | **WP-326**'nın saat dilimi alanına dayanır. Enlem/boylam gerekirse **ayrıca** konuşulur (konum izni açar) |

⚠️ **Kare bütçesi:** kamp ateşi sahnesinde `p95 ≤ 16.7 ms · jank ≤ %1`
(`flutter run --profile` + timeline); Android cihaz kabulünde ölçülür.

#### WP-335: l10n hijyeni ve audit kapısı 🧹
- **Program/Faz:** Faz F · kalite kapısı
- **Ajan:** Codex · **Durum:** [~] Kod/test tamam — cihaz kabulü bekliyor · **Bağımlılık:** Yok
- **Problem:** `python scripts/l10n_audit.py` 31 bulguyla kırmızı. Bunların 24'ü WP-295 parametrik önizlemede kullanıcıya görünen sabit metin; 7'si ise kullanıcıya hiç gösterilmeyen gökyüzü/yerleşim invariant hata mesajı.
- **Kapsam dışı:** AR/DE ürünleştirmesi veya RTL (WP-278 ürün kararı) · yasal metin mimarisi · l10n denetimini gevşetmek/genel muafiyet eklemek · kamp ateşi yerleşim davranışını değiştirmek.
- **SAHİP dosyalar (yaz):** `app/lib/wp295_preview.dart` · `app/lib/l10n/app_{en,tr,de,ar}.arb` · `scripts/l10n_audit.py` · `app/test/features/wp295_preview_test.dart` · WP-335 l10n testleri.
- **DOKUNMA (oku, değiştirme):** `app/lib/features/classroom/widgets/campfire_scene.dart` · `app/lib/core/tour/**` · dil seçimi/supported locale politikası (WP-321).
- **Adımlar:**
  - [x] WP-295 önizlemesinin AppBar, chip, denetim etiketi, açıklama ve tooltip metinlerini ARB anahtarlarına taşı; değer ve interpolasyonlar her iki görünür dilde doğru olsun.
  - [x] `sky_phase.dart` ve `campfire_layout.dart`daki yalnız geliştirici/invariant `ArgumentError` mesajlarını, nedenleri yazılı iki **dosya-bazlı** audit muafiyetine al; genel regex veya UI yuvası muafiyeti ekleme.
  - [x] TR + EN önizleme widget testini ve audit sıfır-bulgu kapısını çalıştır; dört katalog anahtar eşliğini koru.
- **Veri/Migration etkisi:** Yok. Geri alma: eklenen ARB anahtarları ve dar muafiyet kayıtları geri alınır; şema/uzak ortam değişmez.
- **Ortam/Deploy:** Yalnız local; release, tag veya remote mutasyon yok.
- **RLS/Güvenlik:** Yok. Ham invariant hata metni kullanıcıya gösterilmez; muafiyet bunu belgelemek içindir.
- **Edge-case'ler:** sayı/değer interpolasyonu · TR/EN uzun metin · 360 px önizleme · geliştirici dışa-aktarım metninin kullanıcı etiketi sayılmaması · DE/AR katalog eşliği.
- **Kabul (ölçülebilir):** `python scripts/l10n_audit.py` **0** ile çıkar · dört ARB katalog anahtar/placeholder eşliği korunur · WP-295 önizlemesi TR ve EN'de başlık, chip ve tüm erişilebilir tooltip'lerle render olur · `flutter analyze` 0 uyarı ve ilgili testler yeşil.
- **Tuzaklar:** İnvariant mesajlarını kataloglamak gereksiz kullanıcı metni üretir; buna karşılık tüm dosyayı muaf tutmak gelecekte gerçek UI metni kaçırır. Yalnız iki dosya, gerekçeli ve dar muaf tutulur.
- **Kanıt:** `python scripts/l10n_audit.py` **0 bulgu** · `flutter analyze` temiz · tam paket **886 test yeşil** · TR+EN widget testinde 360 px mobil yerleşim ve tüm denetim etkileşimleri kapsandı. **Cihazda doğrulanmalı.**
- **Model önerisi:** 🔵 Sonnet

---

### Faz F2 — Stable öncesi seri ürün revizyonu

> **Ürün kararı (2026-07-26):**
>
> - Hesap başına aynı anda **tam olarak bir** birincil grup seçilebilir. Çoklu
>   seçim hiçbir UI/repository/RPC yolunda mümkün değildir.
> - Birincil grup seçimi **Başarımlar** ekranında, kullanıcının katıldığı bütün
>   grupları gösteren tek-seçimli karttan yönetilir.
> - Farklı bir birincil gruba geçiş, son başarılı **açık kullanıcı seçiminden
>   itibaren kayan 24 saat** sonra mümkündür. Takvimde “sonraki 00.00” kuralı
>   kullanılmaz; cihaz saati değil sunucu `now()` değeri otoritedir.
> - Birincil grup; grup görev/hedef/gün-hafta ilerlemesi, grup başarımı ve grup
>   gün sınırı saat dilimini etkiler. **Kişisel XP/kişisel başarımlar, bütün
>   gruplardaki canlı presence, direct grup bildirimleri ve timer-sync sinyali
>   bundan filtrelenmez.**
> - Seri sıra zorunludur: **WP-348 → WP-349 → WP-350 → WP-351**. Aynı anda iki
>   worker açılmaz; `progress.md`, l10n/generated, golden/release metadata ve
>   migration yüzeyleri sıcak olduğu için paralellik kazanım değil risk üretir.

#### WP-348: Başarımlar içinde tek birincil grup + kayan 24 saat kuralı 🏠
- **Program/Faz:** Faz E/F2 · WP-329/WP-336 ürün revizyonu
- **Ajan:** —
- **Durum:** [~] Kod/test tamamlandı; staging yapılandırması ve cihaz kabulü bekliyor
- **Bağımlılık:** WP-329 + WP-336; staging head `0084`.
- **Problem:** Birincil grup seçimi bugün grup detayında dağınık bir eylemdir;
  kullanıcı katıldığı grupları tek yerde kıyaslayamaz. Mevcut server sözleşmesi
  revision yarışı çözüyor ancak seçimler arasında 24 saatlik ürün kuralı yoktur.
  “Birden fazla grupta birincil” ifadesi ayrıca yanlış anlaşılmaya açıktır.
- **Ürün/tasarım sözleşmesi:**
  - Başarımlar ekranının kendi-profil görünümünde, taç/başarım kataloğundan önce
    **“Birincil grup”** kartı yer alır.
  - Kart bütün aktif üyelikleri avatar/ad/bölge ile listeler; radio/check
    davranışıyla yalnız bir satır seçilebilir. Mevcut birincil açıkça işaretlenir.
  - Yardım metni kısa ve dürüsttür: “Grup hedeflerin, grup başarımların ve grup
    günün bu gruba yazılır.” Kişisel XP/başarı/presence için yanlış vaat yoktur.
  - Grup detayındaki **“Birincil yap”** yazma eylemi kaldırılır; aynı tercihi
    değiştiren ikinci bir yüzey bırakılmaz.
  - Kilitliyken diğer gruplar disabled olur; kalan süre ve kesin açılma zamanı
    gösterilir. İlk seçim, aynı grubu yeniden seçme ve otomatik tek-grup
    uzlaştırması ayrı davranır.
- **Kapsam dışı:** Çoklu primary · kişisel başarı motoru/XP ekonomisi · geçmiş
  session retro-attribution · presence/push filtresi · timer UX/refactor ·
  notification/widget/PendingIntent değişikliği.
- **SAHİP dosyalar (yaz):**
  - yeni `supabase/migrations/0085_primary_group_change_cooldown.sql`
  - `supabase/tests/010_primary_group_preference.test.sql` ve deploy/contract testleri
  - `app/lib/data/repositories/group_repository.dart`
  - `app/lib/data/repositories/supabase/supabase_group_repository.dart`
  - `app/lib/data/repositories/in_memory/in_memory_group_repository.dart`
  - `app/lib/data/providers/group_providers.dart`
  - `app/lib/features/profile/achievements_screen.dart`
  - `app/lib/features/profile/social_profile_screen.dart`
  - yeni `app/lib/features/profile/widgets/primary_group_selector_card.dart`
  - `app/lib/features/classroom/widgets/class_detail_screen.dart` (yalnız eski seçim CTA'sını kaldırma)
  - `app/lib/l10n/app_{en,tr,de,ar}.arb`, üretilen l10n ve ilgili Dart/widget testleri
- **DOKUNMA (oku, değiştirme):**
  - uygulanmış `0079_primary_group_preference.sql` ve `0080_session_group_attribution.sql`
  - achievement evaluator/XP ledger · presence/global timer/push kodu
  - `study_providers.dart` · Android native timer · bildirim/widget kaynakları
- **Adımlar:**
  - [x] `0085` ile server-authoritative cooldown read-modelini ekle; ilk açık
    seçim serbest, farklı hedefe sonraki açık seçim `last_explicit_change_at +
    interval '24 hours'` öncesinde reddedilsin.
  - [x] Aynı grubu yeniden seçmeyi idempotent no-op yap; cooldown/revision
    tüketmesin. `automatic_single` ve `membership_reconcile` kullanıcı cooldown'ı
    başlatmasın.
  - [x] RPC aynı kullanıcı advisory lock'u, üyelik doğrulaması ve expected
    revision altında `next_change_allowed_at` döndürsün; istemci saati karar
    vermesin.
  - [x] DTO/repository/provider çiftlerini yeni zamana taşı; Supabase ve
    InMemory davranışı aynı olsun, eski/null kayıtlar güvenli parse edilsin.
  - [x] Başarımlar kartını empty/loading/error/offline/stale-revision ve 1–8
    grup durumlarıyla uygula; seçim öncesi etkiyi açıklayan kısa onay göster.
  - [x] Grup detayındaki mutasyon CTA'sını kaldır; aktif timer sırasında seçim
    yerel timer/bildirim/widget'ı restart etmesin, yeni tercih yalnız sonraki
    session attribution'ına girsin.
- **Veri/Migration etkisi:** `0085` yalnız ileri/additive migration'dır; `0079`
  değiştirilmez. Son açık seçim zamanı mevcut append-only history'den
  deterministik backfill edilir; otomatik nedenler cooldown sayılmaz. Geri alma:
  veri silmeden RPC policy'sini ileri migration ile gevşetmek ve istemcide kartı
  salt-okunur yapmak.
- **Ortam/Deploy:** Local full replay + pgTAP/RLS abuse → staging `0084→0085`;
  production terfisi yalnız WP-351'de.
- **RLS/Güvenlik:** Preference/history yalnız hesap sahibi tarafından okunur;
  client zaman/revision/reason yazamaz. Üye olunmayan grup ve başka kullanıcı
  tercihi RPC/RLS ile reddedilir.
- **Edge-case'ler:** 0 grup · tek grup otomatik primary · çok grup/seçim yok ·
  ilk açık seçim · aynı gruba no-op · 23:59/00:00 · DST/saat dilimi değişimi ·
  cihaz saatini ileri alma · iki cihaz eşzamanlı seçim · offline stale ekran ·
  primary gruptan çıkma/silinme · cooldown sırasında zorunlu uzlaşma · aktif timer.
- **Kabul (ölçülebilir):**
  - DB'de kullanıcı başına primary satırı **≤1**, UI'da seçili grup **≤1**.
  - İlk açık seçim başarılı; farklı ikinci seçim `<24 saat`te server tarafından
    reddedilir, `≥24 saat`te başarılıdır; 00.00 geçmek tek başına kilidi açmaz.
  - Aynı hedef no-op'tur; revision/history/cooldown artışı **0**.
  - İki cihaz yarışında yalnız geçerli revision kazanır; eski cihaz güncel
    tercihi geri alamaz ve her iki cihaz Realtime/refresh sonrası aynı grubu gösterir.
  - Primary değişiminde çalışan kronometre, bildirim ve widget süre kaybı/reset
    olmadan devam eder; kapanan session başlangıç anındaki primary'ye, sonraki
    session yeni primary'ye yazılır.
  - 360 dp Android ve Windows'ta 1–8 grup listesi taşmasız; satır dokunma hedefi
    ≥48 dp, kritik metin kontrastı WCAG AA.
- **Tuzaklar:** Cooldown'ı yalnız Flutter'da kontrol etmek kolay aşılır; `changed_at`
  yerine cihaz zamanı kullanmak saat manipülasyonu üretir; otomatik membership
  reconciliation'ı açık seçim sanmak kullanıcıyı haksız kilitler.
- **Model önerisi:** 🔴 Opus

#### WP-349: Forest Cabin tema kapağını gerçek paletle hizala 🎨
- **Program/Faz:** Tema · Faz F2 görsel doğruluk
- **Ajan:** —
- **Durum:** [~] Kod/test tamamlandı; cihaz kabulü bekliyor
- **Bağımlılık:** WP-348 seri kapısı; teknik olarak bağımsızdır.
- **Problem:** `forest_study` temasının gerçek baskın scaffold/surface rengi
  yeşildir; hazır tema kartı yalnız kahverengi `primary` ve sarı `accent`
  noktalarını gösterdiği için seçilince bambaşka tema açılmış gibi görünür.
- **Kapsam dışı:** Forest Cabin'in çalışan tema renklerini değiştirmek · tema
  motoru/kalıcılık · özel tema sihirbazı · yeni tema eklemek.
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/profile/appearance_screen.dart`
  - hazır tema kartı/swatch widget testleri ve gerekli Windows golden baseline'ı
- **DOKUNMA (oku, değiştirme):**
  - `app/lib/core/theme/theme_presets.dart` içindeki `forest_study` runtime token'ları
  - `app/lib/core/theme/app_theme.dart` · `theme_settings.dart` · l10n
- **Adımlar:**
  - [x] Hazır tema kapağını yalnız primary/accent çifti yerine gerçek
    scaffold/surface alanı baskın, primary/accent küçük vurgu olacak biçimde çiz.
  - [x] Çözümü bütün `ThemePreset` kartlarına semantik tokenlardan uygula;
    `forest_study` için ID'ye özel hard-code ekleme.
  - [x] Selected border/check kontrastını hem açık hem koyu presetlerde doğrula.
- **Veri/Migration etkisi:** Yok. Geri alma tek widget/golden geri dönüşüdür.
- **Ortam/Deploy:** Local; WP-351 stable artefaktına girer.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** açık/koyu tema · çok yakın scaffold/surface tonları · 360 dp
  iki sütun · uzun TR/EN tema adı · seçili/seçili değil · high contrast.
- **Kabul (ölçülebilir):**
  - Forest Cabin kartında yeşil scaffold/surface görsel alanın çoğunluğunu,
    kahverengi ve sarı vurgu alanını oluşturur; tıklandığında açılan temanın
    baskın rengi kapakla eşleşir.
  - Diğer 14 preset aynı token tabanlı önizleme sözleşmesini kullanır.
  - Tema seçme/kalıcılık davranışı değişmez; 360 dp'te overflow 0, kart dokunma
    hedefi ≥48 dp; Windows golden testi birebir geçer.
- **Tuzaklar:** Primary rengini yeşile çevirerek problemi “çözmek” çalışan temayı
  değiştirir; istenen kapak doğruluğudur.
- **Model önerisi:** 🔵 Sonnet

#### WP-350: Telefon için kamp ateşi kompozisyon revizyonu 🔥
- **Program/Faz:** Kamp ateşi · Faz F2 mobil görsel revizyon
- **Ajan:** —
- **Durum:** [~] Kod/test tamamlandı; cihaz kabulü bekliyor
- **Bağımlılık:** WP-349 seri/golden kapısı.
- **Problem:** Masaüstü için ayarlanan perspektif telefonda aynı sabitlerle
  çalışınca ateş fazla yukarıda, hayvanlar büyük ve ateşe yapışık, 8 kişilik arka
  sıra havada, orman ağaçları kalabalık ve alt ışık lekesi geniş görünüyor.
- **Tasarım sözleşmesi:**
  - “Start studying / Çalışmaya başla” sahne üstü metni tamamen kaldırılır.
  - Yalnız telefon sınıfında ateş aşağı alınır, oturma halkası genişletilir,
    hayvan/etiket ölçeği küçültülür ve ön/arka derinlik korunur.
  - Telefon sınıfında arka plan ağaç katmanı geçici olarak çizilmez; gökyüzü,
    ay/güneş, yıldızlar, zemin/açıklık korunur.
  - Ateşin alt sıcak aydınlatma/glow yarıçapı ve opaklığı telefonda azaltılır.
  - Windows/masaüstü kompozisyonu ve mevcut native timer/bildirim/widget
    davranışı birebir korunur.
- **Kapsam dışı:** Yeni hayvan/poz/asset üretmek · presence semantiği · kamp
  ateşinden timer başlatmak · masaüstü yerleşimini yeniden tasarlamak ·
  notification/widget/native timer.
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/classroom/widgets/campfire_scene.dart`
  - `app/lib/features/classroom/widgets/camp_critter.dart`
  - gerekirse yalnız adaptif geometri için `app/lib/features/classroom/widgets/campfire_layout.dart`
  - `app/test/features/campfire_scene_test.dart`
  - `app/test/features/campfire_sky_golden_test.dart` ve yeni mobil 1/4/8 kişi golden'ları
- **DOKUNMA (oku, değiştirme):**
  - `app/lib/data/providers/study_providers.dart`
  - presence/global timer repository/provider'ları
  - `app/lib/core/notifications/**`
  - `app/android/**` bildirim/widget/timer kaynakları
  - kamp ateşi PNG assetleri ve `app/pubspec.yaml`
- **Adımlar:**
  - [x] Platform + logical shortest-side tabanlı test edilebilir telefon viewport
    sınıfı çıkar; dar Windows penceresini yanlışlıkla mobil kompozisyona sokma.
  - [x] Telefon geometri profilinde fire baseline'ı aşağı taşı, ring `rx/ry`
    değerlerini güvenli sınıra kadar büyüt ve critter scale aralığını küçült.
  - [x] 1–8 yerleşimde arka sıranın zemin/ufuk ilişkisini koru; isim/süre
    etiketlerini sahne sınırında clamp et.
  - [x] `GroundedForestPainter`a telefon için ağaçları kapatan açık parametre ekle;
    desktop default'u değişmesin.
  - [x] Glow radius/alpha'yı viewport profiline bağla; alev/kor/taş okunurluğu
    kaybolmadan alt lekeyi küçült.
  - [x] Sıfır çalışan durumundaki metni ve test beklentisini kaldır; çalışan
    sayısı rozeti kalır.
- **Veri/Migration etkisi:** Yok. Geri alma adaptif profil/golden commit'inin
  geri çevrilmesidir.
- **Ortam/Deploy:** Local widget/golden/profile → WP-351 stable.
- **RLS/Güvenlik:** Yok; kullanıcı verisi veya görünürlük kuralı değişmez.
- **Edge-case'ler:** 0/1/4/8 üye · hepsi çalışan/hepsi offline · çok uzun ad ·
  360×640 telefon · büyük yazı ölçeği · landscape telefon · Android tablet ·
  dar Windows pencere · reduce-motion · gündüz/geçiş/gece.
- **Kabul (ölçülebilir):**
  - Telefon 360×640 golden'larında 1/4/8 hayvan ve etiket sahne sınırından en az
    8 dp içeride; havada kalan/ateşle fiziksel çakışan gövde **0**.
  - Telefon profilinde critter kutuları mevcut tabana göre yaklaşık %20–30 daha
    küçük; halka yatay açıklığı yaklaşık %15–25 daha geniş ve ateş merkezi
    sahnenin alt yarısına taşınmış görünür.
  - Telefon ağaç çizimi **0**; “Çalışmaya başla/Start studying” metni **0**;
    glow sahne kısa kenarının yaklaşık %22'sini aşmaz.
  - Masaüstü day/transition/night golden'ları istenmeyen piksel farkı olmadan
    korunur; yeni Android mobil golden'ları strict geçer.
  - Android profile sahnede `p95 ≤16.7 ms`, jank `≤%1`; reduce-motion'da
    sonsuz dekoratif animasyon çalışmaz.
- **Tuzaklar:** Yalnız `scale` küçültmek label/marshmallow anchor'larını bozar;
  width tabanlı breakpoint dar Windows'u etkiler; ağaçları tüm platformlardan
  kaldırmak kabul edilen PC görünümünü bozar.
- **Model önerisi:** 🟣 Pro

#### WP-351: Production migration terfisi + doğrudan stable teslim 🚀
- **Program/Faz:** Release/Ops · Faz F2 kapanış
- **Ajan:** Codex (preflight) → Claude (apply + release)
- **Durum:** [x] **KAPANDI 2026-07-27.** Baseline `0070`e onarıldı, `0071→0085` uygulandı, post-check head `0085` verdi, `v49` stable yayınlandı. Yedek sahip kararıyla muaf. Kanıt ve kök neden analizi Git geçmişindeki WP-351/v49 teslim commitlerindedir. Kalan iş sahipte: cihaz kabulü (bulgular `backlog.md` V49-1…V49-5).
- **Bağımlılık:** WP-348 → WP-349 → WP-350; clean `main`; staging `0085`.
- **Problem:** Son stable'dan beri grup/keşif/primary/V3 altyapısı ve görsel
  revizyonlar birikti. Proje sahibi mağaza öncesi 5 kişilik ekipte testi stable
  kanalında yapmak ve sorun çıkarsa benzersiz hotfix çıkarmak istiyor.
- **Sahip risk kabulü:** Proje sahibi **2026-07-26** tarihinde bu somut teslim
  için beta soak/önce cihaz kabulü kapısını atlayıp doğrudan stable istemiştir.
  Bu istisna otomatik test, staging migration, production backup/dry-run,
  post-check, kanal/backend fail-closed ve rollback hazırlığını kaldırmaz.
- **Kapsam dışı:** Bu WP içinde feature bug'ı düzeltmek · Play/Store submission ·
  V3 global timer flag'lerini açmak · mevcut tag/build kimliğini yeniden kullanmak.
- **SAHİP dosyalar (yaz):**
  - `CHANGELOG.md`
  - `app/assets/release_notes.json`
  - `app/pubspec.yaml`
  - `tooling/release/deploy-contract.json` (yalnız korumalı exact head/SHA penceresi)
  - release preflight/manifest ve redacted deploy/acceptance kanıtları
  - `progress.md` içindeki yalnız WP-351/release gerçeği
- **DOKUNMA (oku, değiştirme):** WP-348/349/350 feature kodu · uygulanmış
  migration'lar · Android signing key · notification/widget/native timer kodu.
- **Adımlar:**
  - [ ] Üç WP'nin ayrık commitlerini, temiz worktree'yi, secret dışı diff'i ve
    bir daha kullanılmamış next stable version/build kimliğini doğrula.
  - [ ] `flutter analyze`, non-golden tam test, Windows strict golden, release
    manifest gate, local full migration replay/pgTAP/RLS/deploy guard çalıştır.
  - [x] Staging'i `0084→0085` protected dry-run/apply/post-check ile terfi et;
    primary cooldown/iki hesap/RLS smoke kanıtını al.
  - [ ] Production `0070→0085` zinciri için hedef project-ref, migration-list,
    salt-okunur session/XP/reward/RLS/cron baseline, backup ve protected dry-run
    kanıtını üret; exact SHA/head GO penceresi dışında apply etme.
  - [ ] Production terfisinden sonra aynı invariantları post-check et. V3
    presence/global timer/timer-sync rollout flag'lerini **kapalı** tut; mevcut
    kronometre/bildirim/widget sıcak yolunu stable'da değiştirme.
  - [ ] Android stable APK + Windows stable MSIX/ZIP artefaktlarını production
    backend manifestiyle üret, benzersiz stable tag/release yayımla ve SHA-256
    değerlerini kaydet.
  - [ ] ADB'de yetkili cihaz varsa veriyi silmeden `install -r` ile güncelle;
    cihaz yoksa kurulum/testi yapılmış gibi yazma, kullanıcıya APK bağlantısı ve
    aşağıdaki 5 hesaplık kabul listesini ver.
  - [ ] Yayın sonrası hata P0/P1 ise rollout/flag kapalı kalır; aynı tag
    değiştirilmez, ayrı debug WP + bir sonraki benzersiz stable hotfix açılır.
- **Veri/Migration etkisi:** Staging `0085`; production tek kanonik zincirle
  `0070→0085`. Remote migration immutable. Rollback şema düşürme değil:
  rollout flag kapalı, additive tablolar korunur, gerekirse ileri migration +
  benzersiz hotfix istemci.
- **Ortam/Deploy:** Local → staging → production stable. Kullanıcının bu karttaki
  açık doğrudan-stable emri somut GO kaydıdır; hedef/SHA/head uyuşmazlığında
  fail-closed durulur.
- **RLS/Güvenlik:** Cross-account primary/preference/history, discovery,
  presence/command/result ve attribution abuse testleri PASS; kanıtta secret,
  UUID/e-posta veya service-role yok.
- **Stable sonrası 5 hesaplık kabul listesi:**
  - [ ] Başarımlar ekranında 0/1/çok grup durumu; yalnız tek primary seçimi.
  - [ ] İlk seçim, aynı gruba no-op, `<24 saat` red ve iki cihaz aynı tercih.
  - [ ] Primary değişirken çalışan timer + bildirim + ana ekran widget sürekliliği.
  - [ ] Yeni session yalnız başlangıçtaki primary grup ilerlemesine yazılır;
    secondary katkı 0, kişisel XP/süre korunur.
  - [ ] Forest Cabin kapağı yeşil ağırlıklı; seçilen tema kapakla eşleşir.
  - [ ] Telefon kamp ateşinde 1/4/8 kişi; metin yok, ateş aşağıda, hayvanlar
    küçük/uzak, halka geniş, ağaç yok, glow küçük.
  - [ ] Grup konumu/saat farkı, keşif arama+bölge+boş kontenjan ve 8 kişi sınırı.
  - [ ] App/widget/bildirimden start-stop, app kapalı/yeniden açılış ve 8 saat
    drift regresyonu.
- **Kabul (ölçülebilir):** Production post-check invariant kaybı 0 · Android ve
  Windows artefaktları aynı stable tag/SHA/backend/head'i taşır · channel/backend
  mismatch 0 · migration head `0085` · release assetleri ve digestleri mevcut ·
  timer/widget/notification otomatik regresyonu 0 · fiziksel test sonucu yalnız
  gerçek cihaz kanıtıyla PASS olarak yazılır.
- **Tuzaklar:** 5 kişilik/pre-market olmak veri kaybı veya timer regresyonunu
  zararsız yapmaz; bu yüzden soak atlanabilse de backup/dry-run/post-check ve
  V3 flag-off kalkanı atlanmaz.
- **Model önerisi:** 🔴 Opus

#### Seri yürütme ve çakışma kararı

```text
WP-348 (migration + Başarımlar primary IA)
  → WP-349 (tema kapağı)
    → WP-350 (mobil kamp ateşi)
      → WP-351 (staging/production/stable)
```

> ⚠️ **Paralel worker açma.** WP-348 migration+l10n/profile, WP-349 theme
> golden, WP-350 campfire golden ve WP-351 release metadata/progress sıcak
> yüzeylerini paylaşıyor. Her WP ayrı commit + yeşil kapı ile sıradakine devreder.

---

### Faz F3 — v49 saha düzeltmeleri (sahip 2. geri bildirim turu)

> **Kaynak:** `backlog.md` 🔴 Yüksek Öncelik → **V49-1 … V49-8** (sahip,
> 2026-07-27, iki turda bildirdi). **v49 sonrası bütün saha yamaları bu fazdadır**;
> sekiz bulgunun tamamı karta bağlandı, hiçbiri yalnız backlog notu olarak kalmadı.
>
> | Bulgu | Kart |
> | --- | --- |
> | V49-1 çoklu cihaz sayaç senkronu | **WP-357** |
> | V49-2 Başarımlar primary grup bloğu + kırmızı rozet | **WP-358** (token) → **WP-359** (IA) |
> | V49-3 kamp ateşi 2. revizyon | **WP-360** |
> | V49-4 tablet yatay düzeni | **WP-361** (envanter; kod ayrı kart) |
> | V49-5 tanıtım turları | **WP-362** |
> | V49-6 sayaç sürerken grupta aktif kalmama | **WP-354** (ölçüm) → **WP-355** (düzeltme) |
> | V49-7 kamp ateşi altındaki gri leke | **WP-356** |
> | V49-8 şifre sıfırlama localhost | **WP-353** |
>
> **Uyumlama notu (planner Adım 0, 2026-07-27):** `git status` temiz, açık dal
> yok, bütün lane'ler `[x] Boşta`, commit edilmemiş worker çıktısı yok. WP-351
> `[x] KAPANDI` ve WP-352 `[~]` kayıtları gerçekle uyumlu; taşınacak kart
> bulunmadı. Zemin doğru olduğu için yeni kartlar doğrudan yazıldı.
>
> **İki karar sahibe bağlı, kod başlamadan gerekir:** WP-360'ta kamp ateşi
> geometri sayıları (önce önizleme) ve WP-361'de tablet yerleşim seçeneği.
> **Bir kart hiç kod yazmaz:** WP-361 (sahibin açık "önce konuşalım" emri).
>
> **Sıra ve çakışma:** aşağıdaki matriste. Özet: dalga 1'de dört kart paralel
> güvenli; presence yüzeyi ve kamp ateşi yüzeyi **tek kişiliktir**.

#### WP-353: Production auth yapılandırması — şifre sıfırlama linkini localhost'tan kurtar 🔑
- **Program/Faz:** Faz F3 · Ops/release · Kaynak: **V49-8**
- **Ajan:** Claude · **Durum:** [x] **KAPANDI 2026-07-27** — cihaz doğrulaması sahipte
- **Kanıt:** Dry-run [30267073437](https://github.com/manil-max/online-study-room/actions/runs/30267073437)
  teşhisi birebir doğruladı: production `site_url = "http://localhost:3000"`,
  `uri_allow_list = ""` (**tamamen boş**), `recovery_template_has_token = false`.
  Apply [30267162778](https://github.com/manil-max/online-study-room/actions/runs/30267162778)
  başarılı; doğrulama adımı PASS. Sonra: `site_url =
  com.manilmax.onlinestudyroom://login-callback`, allowlist üç scheme'i taşıyor,
  joker yok. **Kodda ve sunucuda doğrulandı; cihazda doğrulanmalı.**
- **Açık borç (kapanmadı):** şablon adımı beklendiği gibi free-tier uyarısıyla
  geçti — `{{ .Token }}` eklenemiyor, yani **masaüstü/Windows 6 haneli kod yolu
  hâlâ çalışmıyor.** Android derin bağlantı yolu çalışır. Bu, özel SMTP veya
  ücretli plan gelene kadar açık kalır.
- **Not:** Düzeltme sunucu tarafındadır; kullanıcıların uygulamayı güncellemesi
  **gerekmez**, v49 istemcisinde de geçerlidir.
- **Problem:** Sahip stable v49'da "şifremi unuttum" akışını denedi; e-postadaki
  bağlantı hâlâ `localhost:3000`'e gidiyor. **Kod tarafı doğru:** Android'de
  `resetPasswordForEmail` flavor'a uygun derin bağlantıyı `redirectTo` olarak
  geçiyor ([`supabase_auth_repository.dart:197-202`](app/lib/data/repositories/supabase/supabase_auth_repository.dart:197),
  [`auth_redirect_config.dart:32-38`](app/lib/core/config/auth_redirect_config.dart:32)).
  Eksik olan **production Supabase projesinin auth ayarı**: `Supabase Auth Config`
  workflow'u bugüne kadar yalnız bir kez başarıyla koştu — run
  [30164160511](https://github.com/manil-max/online-study-room/actions/runs/30164160511),
  hedef **staging**. Production `uri_allow_list` redirect scheme'ini tanımadığı
  için Supabase `redirectTo`yu reddedip Site URL'e (`localhost:3000`) düşürüyor.
  WP-287 runbook'u bunu zaten "ayrı ops kapısı" olarak bırakmıştı
  ([`docs/SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md:69-73`](docs/SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md:69)) —
  o kapı hiç açılmadı, bu WP onu kapatır.
- **Kapsam dışı:** Uygulama kodu değişikliği · yeni migration · `supabase config
  push` (repodaki `config.toml` yerel; uzağa basılırsa Site URL'i localhost'a
  çevirir) · başka auth ayarına dokunmak (OTP uzunluğu, JWT, provider) ·
  özel SMTP satın almak/kurmak · staging'i yeniden yamalamak.
- **SAHİP dosyalar (yaz):**
  - `docs/SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md` (production bölümünü "yapıldı" gerçeğine çek)
  - `docs/recovery/ENVIRONMENT-MATRIX.md` (auth config satırı — ortam başına durum)
  - bu WP kartı
- **DOKUNMA (oku, değiştirme):** `.github/workflows/supabase-auth-config.yml`
  (olduğu gibi çalıştırılır, düzenlenmez) · `app/lib/core/config/auth_redirect_config.dart` ·
  `supabase/config.toml` · `tooling/release/deploy-contract.json`.
- **Adımlar:**
  - [ ] `Supabase Auth Config` workflow'unu **`target=production`, `dry_run=true`**
    ile koş; mevcut `site_url` / `uri_allow_list` / `recovery_template_has_token`
    değerlerini kayda al. Bu, kök nedenin gerçekten yapılandırma olduğunun kanıtıdır.
  - [ ] Dry-run `site_url`i localhost/127.0.0.1 gösteriyorsa aynı workflow'u
    **`target=production`, `confirm_production=PRODUCTION`, `dry_run=false`** ile
    koş. Göstermiyorsa **DUR** — teşhis yanlıştır, bulguyu sahibe rapor et ve
    kod yoluna dön (kart yeniden yazılır).
  - [ ] Workflow'un `Verify applied auth config` adımının sert kapısının PASS
    ettiğini doğrula: `site_url` localhost içermiyor · `uri_allow_list` üç
    scheme'i de taşıyor · joker (`*`) yok.
  - [ ] Şablon adımı free-tier uyarısıyla geçtiyse bunu **açık borç** olarak yaz:
    masaüstü/Windows 6 haneli kod yolu özel SMTP gelene kadar çalışmaz. Uyarı
    yerine hata döndüyse gerçek hatayı raporla.
  - [ ] Runbook'taki "Production (AYRI KAPI — bu WP'de yapılmaz)" bölümünü
    gerçek duruma çek; run numarasını ve tarihi kanıt olarak yaz.
- **Veri/Migration etkisi:** Yok — şema veya veri değişmez. **Geri alma:** aynı
  workflow ile eski `site_url`/`uri_allow_list` değerleri geri yazılır; dry-run
  çıktısı bu yüzden apply'dan **önce** alınır ve saklanır.
- **Ortam/Deploy:** **Production auth yapılandırması.** Migration/Edge/secret
  değil; `deploy-contract.json` kapısına girmez ama yine de production
  mutasyonudur — sahibin bu karttaki açık emri somut GO kaydıdır
  (`.agents/AGENTS.md §0.1`). Staging'e yeniden dokunulmaz.
- **RLS/Güvenlik:** Allowlist'e **yalnız** üç uygulama scheme'i girer; joker veya
  üçüncü taraf domain **asla** (open-redirect). `SUPABASE_ACCESS_TOKEN`, project
  ref ve API gövdeleri kullanıcıya/loga yazılmaz. Kullanıcı numaralandırma
  koruması (kayıtlı olmayan e-postada da aynı nötr mesaj) korunur.
- **Edge-case'ler:** beta ile stable aynı telefonda kurulu (scheme suffix'i
  ayırır) · e-posta istemcisi linki önizleme için tüketiyor (tek kullanımlık
  token) · kullanıcı linki masaüstünde açıyor (Android şeması açılmaz → kod
  yolu gerekir, o da free tier'da kapalı) · eski v48 istemcisi.
- **Kabul (ölçülebilir):**
  - Production `config/auth` okumasında `site_url` localhost/127.0.0.1 **içermez**;
    `uri_allow_list` üç scheme'i de içerir ve `*` içermez.
  - Gerçek Android cihazda stable v49: "Şifremi unuttum" → e-posta → linke dokun →
    **uygulama açılır** (tarayıcıda `localhost` hatası **0**) → yeni şifre → yeni
    şifreyle giriş başarılı.
  - Kayıtlı olmayan e-postada da aynı nötr "gönderildi" mesajı görünür.
  - Masaüstü kod yolunun durumu (çalışıyor / free-tier nedeniyle kapalı) yazılı
    olarak raporlanır; "çalışıyor" yalnız gerçek 6 haneli kod alındıysa yazılır.
- **Tuzaklar:** `supabase config push` bu işi **düzeltmez, kırar**. Panelden elle
  düzenlemek kayıt bırakmaz — workflow kullanılır. Free tier şablon reddi bir
  hata değil bilinen sınırdır; onu "başarısız" diye raporlamak da, sessizce
  "tamam" saymak da yanlıştır. Bir de: bu WP staging'i düzeltmez çünkü staging
  zaten düzgün — beta'da çalışıyor olması production'ın çalıştığı anlamına gelmez.
- **Model önerisi:** 🟣 Pro

#### WP-354: Sayaç sürerken grupta "aktif" kalmama — kök neden ayrımı 🔬
- **Program/Faz:** Faz F3 · Teşhis (salt-okunur) · Kaynak: **V49-6**
- **Ajan:** — · **Durum:** [x] **İPTAL** (Faz F4 başlığı, 2026-07-27). Kök neden
  ölçüm yapılmadan koddan bulundu → WP-363/364/367.
- **Problem:** Sayaç başlatıldıktan bir süre sonra kullanıcı grup ekranındaki
  aktif/çalışıyor listesinden düşüyor; kronometre kendi cihazında dönmeye devam
  ediyor. **Kodda doğrulanan zemin:** presence satırını yalnız Flutter
  izolatındaki `PresenceLifecycle` 20 sn'de bir tazeliyor
  ([`presence_lifecycle.dart:39`](app/lib/data/providers/presence_lifecycle.dart:39))
  ve okuma tarafı 70 sn'den eski satırı çevrimdışı sayıyor
  ([`presence_providers.dart:35-40`](app/lib/data/providers/presence_providers.dart:35),
  [`:75-96`](app/lib/data/providers/presence_providers.dart:75)). Native foreground
  service sayacı yaşasa bile Flutter izolatı durur/öldürülürse heartbeat biter.
  **Kritik not:** V3 projection yolu da aynı 70 sn'lik istemci lease'ini yeniliyor
  ([`0081:220`](supabase/migrations/0081_multi_group_presence_projection.sql:220)) —
  yani **V3 flag'lerini açmak bu bulguyu tek başına çözmez**; sweeper aynı eşikte
  offline'a çeker ([`0081:253-274`](supabase/migrations/0081_multi_group_presence_projection.sql:253)).
- **Neden ayrı bir teşhis WP'si:** en az dört farklı mekanizma aynı belirtiyi
  üretir ve düzeltmeleri birbirine benzemez. Ölçmeden yazılan kod yanlış katmanı
  onarır. Ayrılacak hipotezler:
  - **H1 — Yazar tarafı ölü:** Activity/Flutter engine yok edilmiş (FGS yaşıyor),
    Dart heartbeat hiç atmıyor → DB `updated_at` donuyor.
  - **H2 — Yazar tarafı kısılmış:** İzolat yaşıyor ama arka planda `Timer.periodic`
    Doze/App Standby ile geciktiriliyor → `updated_at` 70 sn'yi aşan aralıklarla tazeleniyor.
  - **H3 — Yazım reddediliyor:** `beat()` erken dönüyor (auth `null`, `timer.isRunning`
    false, legacy modda `userGroupProvider` null → `legacy_presence_requires_group`
    [`supabase_presence_repository.dart:72-78`](app/lib/data/repositories/supabase/supabase_presence_repository.dart:72))
    ve hata `catchError((_) {})` ile sessizce yutuluyor
    ([`presence_lifecycle.dart:87-90`](app/lib/data/providers/presence_lifecycle.dart:87)).
  - **H4 — Okuyucu tarafı ölü:** DB satırı tazeleniyor ama izleyen cihazın
    Realtime aboneliği düşmüş; yerel bayatlatma tikeri son satırları 70 sn sonra
    offline gösteriyor ([`presence_providers.dart:106-126`](app/lib/data/providers/presence_providers.dart:106)).
- **Kapsam dışı:** Düzeltme kodu yazmak · presence eşiklerini "denemek için"
  değiştirmek · V3 rollout flag'lerini açmak · migration · native servis
  değişikliği · production'a herhangi bir yazma.
- **SAHİP dosyalar (yaz):**
  - yeni `docs/qa/PRESENCE-LIVENESS-EVIDENCE.md` (ölçüm + hipotez sonuçları + GO/NO-GO)
  - gerekiyorsa yalnız geçici, commit **edilmeyen** enstrümantasyon (kartta belirtilir)
- **DOKUNMA (oku, değiştirme):** `presence_lifecycle.dart` · `presence_providers.dart` ·
  `supabase_presence_repository.dart` · `study_providers.dart` · Android native
  timer/servis · `supabase/migrations/**`.
- **Adımlar:**
  - [ ] Ölçüm düzeneği: A cihazı sayacı başlatır, B cihazı grup ekranını açık
    tutar. Aynı anda **salt-okunur** DB gözlemi: `presence` satırının
    `updated_at`/`status` değeri dakikalık örneklenir (production'da yalnız
    `Database Gates` salt-okunur yolu; ham UUID/e-posta kanıta yazılmaz).
  - [ ] Senaryo matrisi, her biri en az 15 dk: (a) uygulama önde açık ·
    (b) uygulama arkada, ekran açık · (c) ekran kapalı · (d) uygulama görev
    listesinden kapatıldı, FGS bildirimi duruyor · (e) uçak modu 2 dk sonra geri.
  - [ ] Her senaryoda **iki bağımsız gerçeği** ayrı ayrı yaz: (1) DB `updated_at`
    tazeleniyor mu, (2) B cihazı kullanıcıyı aktif görüyor mu. İkisinin ayrışması
    doğrudan H1/H2/H3'ü H4'ten ayırır.
  - [ ] `beat()` erken dönüş nedenlerini ve yutulan yazma hatasını geçici olarak
    gözlemlenebilir yap (log/Sentry breadcrumb); H3'ü kanıtla veya ele.
  - [ ] Kullanıcının düştüğü **ilk an** ile son başarılı `updated_at` arasındaki
    farkı ölç: ~70 sn ise eşik/heartbeat sorunu, çok daha uzunsa okuyucu/Realtime sorunu.
  - [ ] Çıktı: tek kazanan hipotez (veya ölçülmüş kombinasyon) + WP-355 için
    **GO/NO-GO ve önerilen çözüm seçeneği**.
- **Veri/Migration etkisi:** Yok. Salt-okunur; hiçbir ortama yazma yapılmaz.
- **Ortam/Deploy:** Cihaz + salt-okunur staging/production gözlemi. Deploy yok,
  flag açma yok.
- **RLS/Güvenlik:** Yalnız kendi hesaplarının satırları okunur; kanıt dosyasında
  UUID, e-posta, token, service-role **bulunmaz** (redacted).
- **Edge-case'ler:** OEM pil optimizasyonu (Samsung agresif) · Doze · force-stop ·
  iki cihazın saatleri arasında kayma · ağ dalgalanması · aynı hesabın iki cihazı ·
  kullanıcının birden çok grubu (legacy modda yalnız seçili grup satırı yazılır).
- **Kabul (ölçülebilir):**
  - Beş senaryonun her biri için "DB tazeleniyor mu / UI aktif görüyor mu"
    tablosu doldurulmuş, en az iki tekrarla.
  - Belirtiyi üreten mekanizma **tek** hipoteze indirgenmiş ve kanıtla
    gerekçelendirilmiş; indirgenemiyorsa hangi ölçümün eksik kaldığı yazılmış.
  - "Düşme" anı ile son `updated_at` arasındaki gecikme sn cinsinden raporlanmış.
  - WP-355 için önerilen çözüm seçeneği + reddedilen seçenekler gerekçeli yazılmış.
- **Tuzaklar:** Eşiği 70 sn'den büyütmek belirtiyi geciktirir, sorunu çözmez —
  ve gerçekten kapanmış uygulamaları "hâlâ çalışıyor" göstererek yeni bir yalan
  üretir. Emülatörde ölçüm geçersizdir; Doze/OEM pil davranışı gerçek cihazda
  ölçülür. Bir senaryoda çalışıyor olması diğerini kapsamaz.
- **Model önerisi:** 🔴 Opus

#### WP-355: Çalışma sürerken presence sürekliliği — kalıcı düzeltme 🔗
- **Program/Faz:** Faz F3 · Presence çekirdeği · Kaynak: **V49-6**
- **Ajan:** — · **Durum:** [x] **YERİNE GEÇİLDİ → WP-363/364/367** (Faz F4).
- **Bağımlılık:** **WP-354 kanıtı zorunlu.** Teşhis yazılmadan bu WP worker'a
  verilmez; kart kapsamı kazanan hipoteze göre daraltılarak yeniden yazılır.
- **Problem:** Kullanıcı gerçekten çalışırken grup onu çalışmıyor görüyor.
  Bugünkü canlılık tanımı "istemci son 70 sn içinde yazdı mı" — oysa doğru tanım
  "sunucuda açık bir çalışma oturumu var mı". İstemcinin uyanık kalmasına bağlı
  her tasarım Android arka plan kısıtları altında er ya da geç yanlış cevap verir.
- **Çözüm seçenekleri (WP-354 sonucuna göre biri seçilir, hepsi yapılmaz):**
  - **S1 — Sunucu türevli canlılık (H1/H2 kazanırsa; tercih edilen).** Canlılık
    presence heartbeat'inden değil, açık `live_study_runs` satırından türetilir;
    heartbeat yalnız hızlandırıcıdır. İstemci uyumadığı sürece davranış aynı
    kalır, uyuyunca kullanıcı "çalışıyor" kalmaya devam eder. Bedeli: ileri
    migration + terk edilmiş oturum (abandoned) kuralının netleşmesi.
  - **S2 — Native uplink heartbeat (H1 kazanır ve S1 yetmezse).** FGS kendi
    tarafından periyodik olarak sunucuya dokunur. Bedeli yüksek: native'e
    kimlik/ağ katmanı girer, WP-337/340'ın "native uplink yok" sözleşmesini
    değiştirir. **Varsayılan olarak önerilmez.**
  - **S3 — Yazma yolu onarımı (H3 kazanırsa).** Sessiz yutulan hata görünür
    kılınır, `beat()` erken dönüşleri (özellikle legacy `groupId == null`) gerçek
    bir yeniden deneme kuyruğuna bağlanır. Migration gerekmez — en ucuz düzeltme.
  - **S4 — Okuyucu tarafı dayanıklılığı (H4 kazanırsa).** Realtime aboneliği
    kopunca yeniden bağlanma + görünür "bağlantı koptu" durumu; kopuk abonelikle
    beslenen liste kullanıcıları sessizce offline göstermez. Migration gerekmez.
- **Kapsam dışı:** V3 rollout flag'lerini açmak (ayrı kapı, WP-346) · sunucu
  session/XP finalizer yazmak · Pomodoro/countdown semantiği · bildirim/widget
  yüzeyi · gün sınırı · presence eşiğini tek başına büyütüp "çözüldü" demek.
- **SAHİP dosyalar (yaz):** *(seçilen seçeneğe göre daraltılır — bugünkü azami sınır)*
  - `app/lib/data/providers/presence_lifecycle.dart`
  - `app/lib/data/providers/presence_providers.dart`
  - presence repository arayüzü + `supabase/` · `in_memory/` · `offline/` **üç** çifti
  - S1 seçilirse yeni `supabase/migrations/0086_*.sql` + pgTAP testleri
  - ilgili Dart/widget testleri
- **DOKUNMA (oku, değiştirme):** `app/lib/data/providers/study_providers.dart`
  sıcak sayaç yolu · Android native timer/servis/bildirim/widget ·
  `ACTION_STOP_SILENT` · uygulanmış `0081`/`0082` · push dispatcher ·
  `home_shell.dart` gezinti sözleşmesi.
- **Adımlar (S1 seçilirse; diğer seçenekte kart yeniden yazılır):**
  - [ ] Canlılığı açık çalışma oturumundan türeten ileri migration; `0081`
    değiştirilmez, additive okuma modeli eklenir.
  - [ ] "Terk edilmiş oturum" kuralını açıkça tanımla: sunucu bir çalışmayı ne
    zaman kendiliğinden bitmiş sayar (aksi hâlde kullanıcı sonsuza dek çalışıyor görünür).
  - [ ] İstemci okuma yolunu yeni modele bağla; legacy `presence` tablosu
    geri dönüş için korunur, flag ile kapatılabilir olur.
  - [ ] InMemory ve offline repository çiftlerini aynı davranışa taşı (demo/çevrimdışı kırılmaz).
  - [ ] Sessiz yutulan presence yazma hatasını gözlemlenebilir yap (S3'ün ucuz kısmı her hâlükârda alınır).
- **Veri/Migration etkisi:** S1'de additive ileri migration; silme yok. **Geri
  alma:** flag kapatma + legacy okuma yoluna dönüş; production'da yedek olmadığı
  için şema düşürme **yok**, yalnız ileri düzeltme.
- **Ortam/Deploy:** Local replay/pgTAP → staging → **production ayrı ve somut
  sahip GO'su** (`deploy_enabled` varsayılan kapalı; her apply sonrası geri kilitlenir).
- **RLS/Güvenlik:** Canlılık başkasının oturumundan türetilemez; yalnız ortak
  aktif grup üyeleri birbirini görür; istemci canlılık/lease süresi yazamaz.
- **Edge-case'ler:** uygulama öldürüldü ama FGS sürüyor · FGS de öldü · force-stop ·
  uçak modu · aynı hesabın iki cihazı aynı anda · kullanıcı gerçekten durdurdu
  (anında offline olmalı) · saat manipülasyonu · birden çok grup üyeliği · eski istemci.
- **Kabul (ölçülebilir):**
  - Sayaç çalışırken uygulama arkaya alınıp **30 dk** beklendiğinde kullanıcı
    grup ekranında kesintisiz "çalışıyor" görünür; ekran kapalı senaryosunda da aynı.
  - Kullanıcı sayacı **durdurduğunda** karşı cihaz ≤ 30 sn içinde offline görür —
    yani düzeltme "herkesi sonsuza dek aktif göstermek" değildir.
  - Uygulama force-stop edildiğinde tanımlı terk kuralı içinde offline'a düşer;
    "sonsuz çalışıyor" satırı **0**.
  - Kişisel süre/XP/oturum kayıtları değişmez; ek session **0**, çift sayım **0**.
  - `flutter analyze` 0 uyarı; presence birim/contract testleri yeşil; migration
    varsa local replay + pgTAP yeşil.
  - Sayaç, bildirim ve ana ekran widget'ında regresyon **0** (8 saat drift tabanı korunur).
- **Tuzaklar:** Bu yüzey V3 programıyla (WP-338/339/346) **aynı dosyalara**
  dokunur; V49-1 (çoklu cihaz senkronu) için ayrı bir worker aynı anda açılırsa
  çakışır. Eşiği büyütmek düzeltme değildir. Native'e ağ/kimlik sokmak (S2)
  WP-337/340 sözleşmesini değiştirir; ancak ölçüm zorunlu kılarsa seçilir.
- **Model önerisi:** 🔴 Opus

#### WP-356: Kamp ateşinin altındaki gri zemin lekesini kaldır 🔥
- **Program/Faz:** Faz F3 · Kamp ateşi görsel · Kaynak: **V49-7**
- **Ajan:** Claude · **Durum:** [x] Kod/test tamam (`72ccb20`) — cihaz kabulü bekliyor
- **Problem:** Sahip: "kamp ateşinin altındaki gri efekt kalkmalı."
- 🔴 **İlk teşhis eksikti — düzeltildi.** Kart `ground.png`i tek suçlu sayıyordu;
  uygulayınca golden'da leke **durdu**. Asıl kaynak `ClearingPainter`'dı
  (camp_critter.dart): yeşil zeminin üstüne koyu kahve radyal elips + patika
  halkası çizen vektör painter ("Toprak zemin"). `ground.png` yalnız katkı
  veriyordu. **İki kaynak da kaldırıldı.**
- **Yapılan:** PNG yığınından `ground` katmanı ve `stackOrder` kaydı çıkarıldı ·
  sahneden "Toprak açıklık" katmanı kaldırıldı · artık hiçbir yerden
  çağrılmayan `ClearingPainter` sınıfı silindi (54 satır ölü kod bırakılmadı) ·
  `wp295_preview` aynı hizaya çekildi (önizleme uygulamayı yansıtsın) ·
  6 golden yenilendi.
- **Görsel doğrulama:** üretilen golden'lara bakıldı — leke gitti, ateş havada
  kalmadı, taşlar çimenin üstünde oturuyor, sıcak glow korundu. Vektör
  fallback'te (`StoneFirePainter`) karşılık gelen gri leke yok, dokunulmadı.
- **Kanıt:** `flutter analyze` temiz · tam paket **yeşil**. Bu WP sırasında
  ortaya çıkan `kamp telefonu golden · 8 kişi` kararsızlığı toplu golden
  yenilemesiyle örtülmedi; kök nedeni bulunup ayrı commit'te (`6f285a2`)
  düzeltildi (Risk notlarına bakın).
- **Kapsam dışı:** V49-3 kamp ateşi 2. revizyonu (mesafe, gökyüzü kırpma, yeşil
  yükseklik, 8 kişi yerleşimi) — **ayrı ve henüz planlanmamış iş** · yeni asset
  üretmek · alev/duman/köz davranışı · masaüstü kompozisyonunu yeniden tasarlamak ·
  presence semantiği · native timer/bildirim/widget.
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/classroom/widgets/campfire/layered_campfire_fire.dart`
  - gerekirse `app/lib/features/classroom/widgets/campfire/campfire_assets.dart`
    (yalnız `stackOrder`; asset sabitleri silinmez, vektör fallback'i bozmaz)
  - `app/test/features/campfire_scene_test.dart`
  - `app/test/features/campfire_sky_golden_test.dart` + ilgili golden baseline'ları
- **DOKUNMA (oku, değiştirme):** `campfire_scene.dart` · `campfire_layout.dart` ·
  `camp_critter.dart` (vektör `StoneFirePainter` fallback'i) · PNG asset
  dosyalarının kendisi · `app/pubspec.yaml`.
- **Adımlar:**
  - [ ] `ground` katmanını kaldır **veya** opaklığını sahnenin kendi zemini
    baskın kalacak kadar düşür. Önce iki varyantın ekran görüntüsünü üret —
    **sahip seçer, sonra sayı koda ve teste bağlanır** (kozmetik işte önce önizleme).
  - [ ] Vektör fallback yolunda (`StoneFirePainter`) karşılık gelen bir gri leke
    olup olmadığını kontrol et; varsa aynı kararı oraya da uygula, yoksa dokunma.
  - [ ] Gündüz / geçiş / gece üç fazında ve 0/1/4/8 kişide taşın/odunun zeminle
    birleşim yerinin "havada duruyor" görünmediğini doğrula — leke bir gölge
    işlevi görüyor olabilir; kaldırınca ortaya çıkan boşluk kabul kriteridir.
  - [ ] Golden baseline'larını yalnız bu değişikliğin gerektirdiği kadar yenile.
  - [ ] ⚠️ **Önce şunu ayır:** `campfire_sky_golden_test.dart` "kamp telefonu
    golden · 8 kişi" testi **temiz HEAD'de de patlıyor** (WP-352 kanıt notu).
    Bu WP'nin hatası değildir; toplu golden yenilemesiyle **üstü örtülmez** —
    ya gerçek nedeni düzeltilir ya ayrı kart açılıp gerekçesiyle karantinaya alınır.
- **Veri/Migration etkisi:** Yok. **Geri alma:** tek widget + golden commit'inin geri çevrilmesi.
- **Ortam/Deploy:** Yalnız local. Tag/release yok; bir sonraki sürüm kuyruğuna girer.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** PNG yüklenemeyip vektör fallback'e düşme · reduce-motion ·
  gündüz/geçiş/gece · 0 kişi (sönük köz) ve 8 kişi · 360×640 telefon · dar
  Windows penceresi · büyük yazı ölçeği · koyu/açık tema.
- **Kabul (ölçülebilir):**
  - Telefon 360×640 golden'larında ateşin altında sahnenin zemin renginden
    ayrışan koyu/gri elips **yok**; ateş taşları zeminle temas ediyor görünür.
  - Gündüz, geçiş ve gece golden'larının üçünde de aynı sonuç; masaüstü
    kompozisyonunda istenmeyen piksel farkı **0**.
  - Asset yükleme hatası simüle edildiğinde vektör fallback'e düşüş çalışmaya devam eder.
  - `flutter analyze` 0 uyarı · kamp ateşi testleri yeşil · Android profile
    sahnede `p95 ≤ 16.7 ms`, jank `≤ %1` tabanı korunur.
- **Tuzaklar:** Leke aynı zamanda ateşin zemine oturmasını sağlayan gölge olabilir;
  körlemesine silmek ateşi havada bırakır — bu yüzden kaldırma **ve** yumuşatma
  varyantı birlikte önizlenir. `stackOrder` bir doğrulama sözleşmesidir; katmanı
  koddan çıkarıp listede bırakmak (veya tersi) envanter testini kırar. Bu WP
  V49-3 ile aynı dosyalara yakındır: V49-3 için worker açılmışsa **paralel başlama**.
- **Model önerisi:** 🔵 Sonnet

#### WP-357: Çoklu cihaz sayaç senkronu — rollout anahtarı ve flag'li kabul 📱↔️📱
- **Program/Faz:** Faz F3 · V3 rollout · Kaynak: **V49-1**
- **Ajan:** — · **Durum:** [x] **YERİNE GEÇİLDİ → WP-365** (Faz F4; V3 rollout açıldı).
- **Problem:** Sahip tablette sayacı başlattı, telefonda başlamadı. **Kodda
  doğrulandı ve bulgu beklenenden basit çıktı: bu bir hata değil, açılmamış bir
  özellik.** V3 zincirinin rollout anahtarları çalışma zamanında hiçbir yere
  bağlı değil — sabit sabitler:
  `presenceProjectionModeProvider` → `PresenceProjectionMode.legacy`
  ([`presence_providers.dart:20-21`](app/lib/data/providers/presence_providers.dart:20)),
  `globalTimerModeProvider` → `GlobalTimerMode.disabled`
  ([`global_timer_providers.dart:22`](app/lib/data/providers/global_timer_providers.dart:22)).
  Ne `--dart-define`, ne ortam dosyası, ne sunucu tarafı bir switch var; yalnız
  testler `overrideWith` ile açabiliyor. Yani **v49'da çoklu cihaz senkronu
  hiçbir koşulda çalışmaz** ve "flag kapalı olduğu için mi, bozuk olduğu için mi"
  sorusunun cevabı: *kapalı olduğu için.* Ayrıca bugün flag'i açmanın tek yolu
  kodu değiştirip yeni bir build çıkarmaktır — bu da açık/kapalı denemeyi
  sürüm çıkarmaya bağlar.
- **Kapsam dışı:** V3 davranışının kendisini yeniden tasarlamak · WP-336…WP-345
  kodunu değiştirmek · production'da flag açmak (**ayrı ve somut sahip GO'su**) ·
  stable kanala V3 sokmak · sunucu tarafı uzaktan yapılandırma altyapısı kurmak ·
  yeni migration.
- **SAHİP dosyalar (yaz):**
  - `app/lib/core/config/` altında yeni rollout yapılandırması (tek okuma noktası)
  - `app/lib/data/providers/presence_providers.dart` (yalnız mode provider'ının kaynağı)
  - `app/lib/data/providers/global_timer_providers.dart` (yalnız mode provider'ının kaynağı)
  - `docs/recovery/ENVIRONMENT-MATRIX.md` (ortam başına flag durumu)
  - `docs/qa/DEVICE-QA-MATRIX.md` V3 satırları
  - ilgili yapılandırma/contract testleri
- **DOKUNMA (oku, değiştirme):** WP-336…WP-345'in feature kodu · uygulanmış
  `0081`/`0082`/`0083` · native timer/servis · bildirim/widget · `study_providers.dart`
  sıcak sayaç yolu · `tooling/release/deploy-contract.json`.
- **Adımlar:**
  - [ ] Rollout anahtarını **tek** bir yapılandırma noktasından oku; varsayılan
    **kapalı** kalsın ve stable/production yolunda kapalı olduğu **testle kilitlensin**.
  - [ ] Anahtarı ortam/flavor'a bağla: beta+staging'de açılabilir, stable+production
    varsayılanı kapalı. Yanlış eşleşme fail-closed olsun (beta flag'i stable
    artefaktına sızmasın).
  - [ ] Üç kademeyi ayrı ayrı açılabilir yap (presence projection · global timer
    shadow · foreground mirror); hepsini tek anahtara bağlama — biri bozulursa
    diğerleri kapanmasın.
  - [ ] Flag'leri açık bir **beta** artefaktı üret; stable v49'a dokunma.
  - [ ] WP-346'daki cihaz matrisini bu beta ile gerçekten koş (telefon+tablet,
    aynı hesap): başlat/durdur aynası, bildirim/widget regresyonu, 8 saat drift,
    ek session/XP kontrolü.
  - [ ] Sonucu WP-346 kartına kanıt olarak yaz; hata çıkarsa **ayrı debug WP** aç,
    bu kartta yamalama yapma.
- **Veri/Migration etkisi:** Yok — şema `0085`te zaten hazır. **Geri alma:** tek
  yapılandırma değeri kapatılır, yeniden build gerekmeyecek biçimde ortam
  ayrımına bağlıdır; şema düşürülmez.
- **Ortam/Deploy:** Local → **beta/staging**. Production/stable'da açmak bu WP'nin
  kapsamı **değildir**; ayrı karta ve somut sahip GO'suna bağlıdır.
- **RLS/Güvenlik:** Flag yalnız istemci okuma/yazma yolunu seçer; yetki sunucuda
  kalır. Kapalı flag'in açık gibi davranmadığı testle kanıtlanır (ölü anahtar yasağı).
- **Edge-case'ler:** iki cihazda farklı flag durumu (biri v49 stable, biri beta) ·
  aynı hesapta eski istemci · flag açıkken ağ yok · hesap değişimi · flag
  ortasında çalışan sayaç · beta ve stable aynı telefonda kurulu.
- **Kabul (ölçülebilir):**
  - Stable/production yapılandırmasında üç mod da **kapalı** ve bu bir testle kilitli.
  - Beta artefaktında flag'ler açık; tablette başlatılan çalışma telefonda
    **p95 ≤ 2 sn** içinde görünür, birinden durdurmak diğerini durdurur.
  - Ek session **0**, çift XP **0**, bildirim/widget regresyonu **0**, 8 saatte
    sayaç sapması **≤ ±1 sn**.
  - Bir kademe kapatıldığında diğer ikisi çalışmaya devam eder (bağımsızlık kanıtı).
  - Flag kapalıyken davranış bugünkü v49 ile **birebir** aynıdır.
- **Tuzaklar:** Bu kart V49-6 (presence düşmesi) ile **aynı yüzeye** dokunur;
  WP-355 ile paralel çalıştırılamaz. V3'ü açmak V49-6'yı çözmez (projection yolu
  da 70 sn'lik istemci lease'i kullanır) — iki iş birbirinin yerine geçmez.
  "Flag'i açtım, çalıştı" demek için gerçek iki fiziksel cihaz gerekir; tek
  cihazda iki hesap bu testi kapsamaz.
- **Model önerisi:** 🔴 Opus

#### WP-358: Tema-bağımsız uyarı token'ı 🎨⚠️
- **Program/Faz:** Faz F3 · Tema · Kaynak: **V49-2 açık tasarım sorusu**
- **Ajan:** Claude · **Durum:** [x] Kod/test tamam (`636e645`) — cihaz kabulü bekliyor
- **Yapılan:** Yeni `app/lib/core/theme/warning_tokens.dart` — saf ve
  deterministik `resolveWarningColors(background)`; kehribar tabandan başlar ve
  zemine karşı AA sınırını tutturana kadar açıklığı zeminin **ters** yönünde
  iter. Sabit renk yazılmadı. Uyarı bloğu ve Profil sekmesi noktası bu token'ı
  kullanıyor; bekleyen ödül sayısı rozeti kendi rengini koruyor.
- **Kapsanan ikinci yüzey:** Sekme noktası `Badge`in varsayılanı olan
  `colorScheme.error`den besleniyordu — kartla aynı hastalık, kart yazılırken
  fark edilmemişti.
- **Kanıt:** `flutter analyze` temiz · 7 yeni test yeşil: 15 preset'in hepsinde
  dolgu/zemin ≥ 3.0 ve metin/dolgu ≥ 4.5, scaffold zemininde de aynı, ayrıca
  beş kırmızı tonunda (bulgunun kendisi) sınır tutuyor. Test preset sayısını da
  kilitliyor ki yeni tema eklenince sessizce atlanmasın.
- **Problem:** Sahibin açık sorusu: dikkat çekmesi gereken kırmızı rozet, kırmızı
  ağırlıklı tema seçen kullanıcıda arka planda kaybolur. Bugün uyarı yüzeyleri
  doğrudan tema paletinden besleniyor (ör. WP-352 uyarı bloğu `errorContainer`
  kullanıyor, [`primary_group_selector_card.dart:203`](app/lib/features/profile/widgets/primary_group_selector_card.dart:203)).
  Palet kırmızıya kayınca uyarı ile zemin arasındaki kontrast çöküyor.
- **Kapsam dışı:** Yeni tema eklemek · mevcut preset renklerini değiştirmek ·
  tema sihirbazı · Başarımlar ekranının bilgi mimarisi (WP-359) · rozet
  yerleşimlerini eklemek (WP-359).
- **SAHİP dosyalar (yaz):**
  - `app/lib/core/theme/app_theme.dart` (yalnız yeni uyarı token'ları)
  - gerekirse `app/lib/core/theme/theme_presets.dart` (yalnız token türetimi)
  - yeni ortak uyarı rozeti bileşeni + testleri · golden baseline'ları
- **DOKUNMA (oku, değiştirme):** `theme_settings.dart` kalıcılık yolu ·
  `appearance_screen.dart` · l10n · profil/başarım ekranları.
- **Adımlar:**
  - [ ] Uyarı rengini paletten **türetme**; seçili tema ne olursa olsun zemine
    karşı hedef kontrastı tutturan bir uyarı token'ı üret (gerekirse zemine göre
    otomatik açılıp koyulaşan bir çift renk).
  - [ ] Token'ı kullanan tek bir rozet/uyarı bileşeni yaz; her ekran kendi
    kırmızısını icat etmesin.
  - [ ] 15 preset × açık/koyu üzerinde kontrastı **otomatik testle** ölç; sınırın
    altına düşen kombinasyon kalırsa test kırmızı olsun.
  - [ ] Mevcut `errorContainer` kullanan uyarı yüzeyini yeni token'a taşı
    (davranış aynı, yalnız renk kaynağı değişir).
- **Veri/Migration etkisi:** Yok. **Geri alma:** tek tema commit'inin geri çevrilmesi.
- **Ortam/Deploy:** Yalnız local; bir sonraki sürüm kuyruğuna girer.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** kırmızı ağırlıklı preset · özel (kullanıcı yapımı) tema ·
  açık/koyu mod · yüksek kontrast/erişilebilirlik ayarı · renk körlüğü (renk tek
  sinyal olmamalı — ikon/metin de taşımalı) · 360 dp.
- **Kabul (ölçülebilir):**
  - Uyarı rozeti/bloğu ile zemini arasındaki kontrast **15 preset'in hepsinde**
    ve açık/koyu modda **WCAG AA**'yı sağlar; kırmızı ağırlıklı preset dahil.
  - Uyarı, rengin yanında **en az bir renk-dışı sinyal** taşır (ikon veya metin).
  - Tema seçimi/kalıcılığı davranışı değişmez; mevcut tema golden'ları
    istenmeyen fark üretmez.
  - `flutter analyze` 0 uyarı; kontrast testi ve rozet widget testleri yeşil.
- **Tuzaklar:** Sabit `Colors.red` yazmak sorunu koyu temada geri getirir —
  token zemine göre türetilmelidir. `core/theme/**` **sıcak dosyadır**: başka bir
  tema WP'si açıkken bu kart başlatılmaz.
- **Model önerisi:** 🟣 Pro

#### WP-359: Başarımlar bilgi mimarisi — birincil grup bloğunu sağ üste taşı 🏠
- **Program/Faz:** Faz F3 · Başarım/IA · Kaynak: **V49-2**
- **Ajan:** — · **Durum:** [x] **YERİNE GEÇİLDİ → WP-376** (2026-07-28). Ürün
  sözleşmesi aynen uygulandı; kart tarihsel referans olarak duruyor, worker'a
  verilmez.
- **Problem:** WP-348'de eklenen birincil grup kartı `My Achievement Journey`
  başlığının üstünde kocaman bir blok olarak duruyor
  ([`social_profile_screen.dart:186`](app/lib/features/profile/social_profile_screen.dart:186))
  ve sahibin ekranında görüntü kirliliği yaratıyor. Seçim nadir yapılan bir
  ayardır; ekranın ana içeriği başarımlardır.
- **Ürün/tasarım sözleşmesi (sahip, 2026-07-27):**
  - Blok kaldırılır; yerine **sağ üst köşede bir ayar/ikon girişi** gelir. Seçim
    aynı tek-seçimli listeyle, açılan bir yüzeyde yapılır.
  - Birincil grup seçili **değilse** uyarı rozeti **üç yerde birden** görünür:
    Profil sekmesi (bugün var, WP-352) · Başarımlar ekranı · ayar ikonunun üstü.
  - Rozet rengi WP-358 token'ından gelir; ekran kendi kırmızısını tanımlamaz.
  - Seçim yapıldığında üç rozet de kaybolur.
- **Kapsam dışı:** 24 saat cooldown kuralını değiştirmek · birincil grubun
  anlamını/muhasebesini değiştirmek · yeni RPC/migration · masaüstü gezinti
  rozeti altyapısını kurmak (**bilinçli borç**, aşağıda) · başarım kataloğunun
  kendisi.
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/profile/social_profile_screen.dart`
  - `app/lib/features/profile/widgets/primary_group_selector_card.dart`
  - gerekirse yeni bir seçim yüzeyi (sayfa/alt sayfa) dosyası
  - `app/lib/l10n/app_{en,tr,de,ar}.arb` + üretilen l10n
  - `app/test/features/profile/**` ilgili testler
- **DOKUNMA (oku, değiştirme):** `group_providers.dart` · `core/theme/**`
  (WP-358'in token'ı **kullanılır**, tanımlanmaz) · `home_shell.dart` mevcut
  Profil sekmesi noktası (WP-352, korunur) · migration/RPC.
- **Adımlar:**
  - [ ] Kartı ekran gövdesinden çıkar; sağ üste ayar/ikon girişi koy (dokunma
    hedefi ≥ 48 dp, erişilebilirlik etiketi yazılı).
  - [ ] Seçim yüzeyini aç: 1–8 grup, tek seçim, mevcut birincil işaretli,
    cooldown kilidi ve kalan süre görünür (WP-348 sözleşmesi korunur).
  - [ ] Seçim yokken rozeti üç yüzeyde göster; WP-358 token'ını kullan.
  - [ ] Bekleyen ödül sayısı rozetiyle aynı sekmede **yarıştırma** (WP-352
    kararı korunur: iki sinyal çakışmaz).
  - [ ] Boş/yükleniyor/hata/çevrimdışı durumlarında **uydurma uyarı gösterme** —
    olmayan bir kaybı ilan etme (WP-352 provider sözleşmesi).
- **Bilinçli borç — masaüstü rozeti:** `DesktopNavigationPane` bugün hiç rozet
  altyapısı taşımıyor (WP-352 notu). Masaüstünde uyarı yüzeyi ayar ikonunun
  kendisidir; gezinti rozeti istenirse ayrı kart açılır.
- **Veri/Migration etkisi:** Yok. **Geri alma:** tek UI commit'inin geri çevrilmesi.
- **Ortam/Deploy:** Yalnız local.
- **RLS/Güvenlik:** Değişmez; seçim yine server-authoritative RPC üzerinden ve
  yalnız aktif üyelik için yapılır.
- **Edge-case'ler:** 0 grup (rozet **gösterilmez** — seçilecek bir şey yok) ·
  tek grup (otomatik birincil) · 8 grup · cooldown kilitli · seçim sırasında
  çalışan sayaç · başkasının profiline bakarken (kart hiç görünmemeli) ·
  360 dp taşma · uzun grup adı.
- **Kabul (ölçülebilir):**
  - Başarımlar ekranının gövdesinde birincil grup bloğu **yok**; giriş sağ üstte
    tek ikon, dokunma hedefi ≥ 48 dp.
  - Seçim yokken rozet **tam olarak üç** yüzeyde görünür; seçim sonrası **üçü de**
    kaybolur (aynı testte kanıtlanır).
  - Grubu olmayan kullanıcıda rozet **0**; yükleme/hata durumunda rozet **0**.
  - Başkasının profilinde giriş/rozet **0**.
  - 360 dp'de taşma 0; TR ve EN'de kesilme yok; `flutter analyze` 0 uyarı,
    ilgili testler yeşil.
- **Tuzaklar:** Kartı silip yerine hiçbir giriş koymamak seçimi erişilemez yapar
  (WP-348 grup detayındaki eski CTA'yı zaten kaldırmıştı — ikinci bir yüzey yok).
  Rozeti "her zaman göster"e bağlamak, grubu olmayan kullanıcıyı boşuna telaşlandırır.
- **Model önerisi:** 🟣 Pro

#### WP-360: Kamp ateşi 2. revizyon — mesafe, gökyüzü, zemin, 8 kişi 🔥
- **Program/Faz:** Faz F3 · Kamp ateşi · Kaynak: **V49-3**
- **Ajan:** — · **Durum:** [x] **YERİNE GEÇİLDİ → WP-377** (2026-07-28). Sahip
  parametrik önizlemeden halka `1.50` ve gökyüzü `85 px` kırpma seçti; kart
  tarihsel referans olarak duruyor.
- **Problem:** WP-350 sonrası sahne daha iyi ama bitmedi. Sahibin dört maddesi:
  (1) telefonda figürler ateşten **birazcık daha** uzaklaşsın (küçük artış,
  abartılmasın), (2) gökyüzü çok uzun ve boş — üstten kırpılsın, kart da kısalsın,
  (3) yeşil zemin yüksekliği azıcık artsın, (4) 8 kişide en üstteki sıranın ucu
  gökyüzünde kalıyor. **Kodda doğrulanan ayar noktaları:** sahne yüksekliği sabit
  `360` ([`campfire_scene.dart:198`](app/lib/features/classroom/widgets/campfire_scene.dart:198)),
  ufuk/zemin oranı her kişi sayısı için `groundYFactor: 0.66`
  ([`campfire_layout.dart`](app/lib/features/classroom/widgets/campfire_layout.dart:160)),
  halka açıklığı ve 8 kişi yerleşimi `CampfireCountLayout.saved` içindeki
  `horizontalFactor`/`verticalFactor` çiftleri.
- **🔴 Önce önizleme, sonra kod:** Bu kozmetik bir iştir; ilk çıktı kod değil,
  **parametrik önizlemedir**. Dört ayar (sahne yüksekliği · `groundYFactor` ·
  halka açıklığı · critter ölçeği) kaydırılabilir olarak sunulur, sahip 1/4/8
  kişide sayıları seçer, **seçilen sayılar koda ve golden testine bağlanır**.
  Sahip sayı seçmeden kalıcı değer yazılmaz.
- **Kapsam dışı:** Yeni hayvan/poz/asset üretmek · masaüstü kompozisyonunu
  yeniden tasarlamak · gökyüzü faz algoritması (`sky_phase.dart` mantığı) ·
  presence semantiği · kamp ateşinden sayaç başlatmak · bildirim/widget/native.
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/classroom/widgets/campfire_scene.dart`
  - `app/lib/features/classroom/widgets/campfire_layout.dart`
  - `app/lib/features/classroom/widgets/camp_critter.dart` (yalnız ölçek/etiket)
  - `app/lib/wp295_preview.dart` (parametrik önizleme — mevcut yüzey genişletilir)
  - `app/test/features/campfire_scene_test.dart` · `campfire_sky_golden_test.dart` + golden'lar
- **DOKUNMA (oku, değiştirme):** `campfire/` PNG katman dosyaları (WP-356'nın
  yüzeyi) · `study_providers.dart` · presence provider'ları · `core/notifications/**` ·
  `app/android/**` · `app/pubspec.yaml`.
- **Adımlar:**
  - [ ] Dört ayarı parametrik önizlemede kaydırılabilir yap; 1/4/8 kişi ve
    gündüz/geçiş/gece kombinasyonlarını aynı ekranda göster.
  - [ ] Sahibe önizleme çıktısı sun, **sayıları seçtir** (bu kart o noktada durur).
  - [ ] Seçilen değerleri telefon profiline yaz; masaüstü profili değişmesin.
  - [ ] 8 kişi yerleşiminde en üst sıranın **zemin üstünde** kaldığını doğrula —
    bu, zemin yüksekliğiyle birlikte çözülmesi gereken tek bağlı problemdir.
  - [ ] Sahne yüksekliğini kırp; kartın toplam yüksekliğinin azaldığını ölç.
  - [ ] Golden baseline'larını yalnız seçilen değerlerle yenile.
- **Veri/Migration etkisi:** Yok. **Geri alma:** tek geometri+golden commit'i.
- **Ortam/Deploy:** Yalnız local; bir sonraki sürüm kuyruğuna girer.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** 0/1/4/8 üye · hepsi çalışan / hepsi offline · çok uzun ad ·
  360×640 telefon · büyük yazı ölçeği · telefon yatay · Android tablet
  (WP-361 ile kesişir) · dar Windows penceresi · reduce-motion · gündüz/geçiş/gece.
- **Kabul (ölçülebilir):**
  - 8 kişi telefon golden'ında **hiçbir** hayvan/etiket ufuk çizgisinin üstünde
    (gökyüzünde) kalmaz; sahne sınırına en az 8 dp mesafe korunur.
  - Halka açıklığı sahibin seçtiği değere birebir eşittir ve testte sabitlenmiştir
    ("biraz" gibi ifade koda girmez).
  - Kartın toplam yüksekliği ölçülebilir biçimde azalır (önce/sonra dp yazılır).
  - Masaüstü golden'larında istenmeyen piksel farkı **0**.
  - Android profile sahnede `p95 ≤ 16.7 ms`, jank `≤ %1`.
- **Tuzaklar:** `groundYFactor` **her kişi sayısı için ayrı** tanımlı; birini
  değiştirip diğerlerini unutmak 8 kişide bugünkü hatayı sürdürür. Yalnız
  `scale` küçültmek etiket/marshmallow çapalarını bozar (WP-350 dersi). Bu kart
  WP-356 ile aynı dosyalara girer — **ikisi paralel açılmaz**.
- **Model önerisi:** 🟣 Pro

#### WP-361: Tablet ve geniş ekran envanteri + yerleşim önerisi 📐
- **Program/Faz:** Faz F3 · Yerleşim · Kaynak: **V49-4**
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** Yok
- **🔴 Sahip kapısı:** Sahip açıkça yazdı — **"sahiple konuşulmadan koda
  geçilmez."** Bu yüzden bu kart **ürün kodu yazmaz**; envanter + ölçüm + öneri
  üretir. Uygulama kartı sahip kararından sonra açılır.
- **Problem:** Tablet kullanıcıları çoğunlukla cihazı yatay tutuyor; yatayda
  kartlar aşırı genişleyip bozuluyor. **Kodda doğrulandı — sebebi tek satır:**
  geniş ekran yerleşimi **yalnız platforma** bağlı, genişliğe değil.
  `isDesktopWindow` yalnız `TargetPlatform.windows` için `true`
  ([`desktop_window_io.dart:13-15`](app/lib/core/desktop/desktop_window_io.dart:13)),
  `home_shell.dart:101` bu bayrakla masaüstü kabuğuna geçiyor. Yani 1280 dp
  genişliğindeki bir Android tablet, 360 dp telefon kabuğunu esnetilmiş olarak
  alıyor; `DesktopBreakpoints` (640 / 1008 / 1440,
  [`desktop_layout.dart:5-18`](app/lib/core/desktop/desktop_layout.dart:5))
  Android'de **hiç devreye girmiyor**. Ayrıca ana ekran ızgarasının sütun sayısı
  kullanıcı tercihinden geliyor ([`home_screen.dart:131`](app/lib/features/home/home_screen.dart:131)),
  mevcut genişlikten değil — telefon için seçilmiş sütun sayısı yatay tablette
  kartları devasa yapıyor. Kamp ateşi de aynı sınıfa düşüyor: telefon profili
  `shortestSide < 600` istiyor ([`campfire_layout.dart:47`](app/lib/features/classroom/widgets/campfire_layout.dart:47)),
  tablet bu yüzden masaüstü kompozisyonunu alıyor.
- **Kapsam dışı:** Ürün kodu yazmak · yeni kabuk/yerleşim uygulamak · sütun
  tercihini değiştirmek · masaüstü kabuğunu Android'e açmak (bu bir **öneri**
  olabilir, bu kartta **uygulanmaz**) · yeni ekran tasarlamak.
- **SAHİP dosyalar (yaz):**
  - yeni `docs/qa/TABLET-LAYOUT-INVENTORY.md` (envanter + ölçüm + seçenekler + öneri)
  - gerekiyorsa commit **edilmeyen** geçici ölçüm çıktıları
- **DOKUNMA (oku, değiştirme):** tüm ürün kodu — bu kart yalnız okur.
- **Adımlar:**
  - [ ] Genişliğe duyarlı olan ve olmayan yüzeyleri tek tek listele: ana ekran
    ızgarası, sayaç, kamp ateşi, gruplar, istatistik, profil, ayarlar, diyaloglar.
  - [ ] Gerçek tablette dikey ve yatayda ekran görüntüsü al; bozulan her yüzey
    için **neyin** bozulduğunu yaz (kart genişliği, satır uzunluğu, boş alan,
    dokunma hedefi, kesilme).
  - [ ] Okunabilirlik ölçüsü koy: satır başına karakter, kart genişliği dp,
    içerik/boşluk oranı — "bozuk görünüyor" yerine sayı.
  - [ ] En az üç seçenek üret ve maliyet/riskini yaz: (A) mevcut masaüstü
    kabuğunu genişlik tabanlı yapıp Android tablette de kullanmak, (B) yalnız
    içerik genişliğine üst sınır koyup ortalamak (en ucuz), (C) tablete özel
    yerleşim. Her biri için hangi dosyaların SAHİP olacağını çıkar.
  - [ ] Sütun tercihi ile mevcut genişlik arasındaki ilişki için öneri yaz
    (tercihi ezmeden üst sınır uygulamak mümkün mü).
  - [ ] Sahibe **önizleme/ekran görüntüsü ile** sun; kararı al ve uygulama
    kartını (WP-363+) o karara göre yazdır.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Yok; salt inceleme.
- **RLS/Güvenlik:** Yok. Ekran görüntülerinde başka kullanıcı adı/e-postası
  görünüyorsa maskele.
- **Edge-case'ler:** 7"/10"/12" tablet · yatay ve dikey · katlanabilir cihaz ·
  bölünmüş ekran (split-screen) · büyük yazı ölçeği · Android tabletin masaüstü
  moduna benzer geniş ekranı · dar Windows penceresi (yanlışlıkla mobil
  kompozisyona düşmemeli — WP-350 tuzağı).
- **Kabul (ölçülebilir):**
  - Envanterde her ana ekran için "yatay tablette bozuluyor mu / neresi" satırı
    doldurulmuş, ekran görüntüsüyle eşleşmiş.
  - En az üç seçenek, her biri için etkilenen dosya listesi ve tahmini risk
    yazılmış; bir tanesi **gerekçeli olarak önerilmiş**.
  - Sahip kararı alınmış ve uygulama kartının kapsamı yazılabilir hâle gelmiş.
- **Tuzaklar:** Genişlik tabanlı bir kırılma noktasını dikkatsiz eklemek dar
  Windows penceresini mobil kompozisyona düşürür (WP-350'de yaşandı). "Tablet"
  bir cihaz sınıfı değil bir **genişlik**tir; katlanabilir ve bölünmüş ekran aynı
  koddan geçer. Bu kartta koda dokunmak sahip kapısını ihlal eder.
- **Model önerisi:** 🟣 Pro

#### WP-362: Tanıtım turu — hedefleme, konum ve sıra onarımı 🎈
- **Program/Faz:** Faz F3 · Yeni kullanıcı deneyimi · Kaynak: **V49-5**
- **Ajan:** — · **Durum:** [x] **YERİNE GEÇİLDİ → WP-375** (2026-07-28). Teşhisi
  doğru çıktı ve aynen uygulandı; kart tarihsel referans olarak duruyor.
- **Problem:** Sahip: "mantık doğru, uygulama kötü — hedef/konum/sıra ayarları
  tutmuyor." **Kodda doğrulandı, üç ayrı mekanizma:**
  - **Hedef tutmuyor:** Balon hedefi `GlobalKey` ile bulunuyor; hedef widget o an
    monte değilse (koşullu gösterim, kaydırma alanının dışında, henüz yüklenmemiş
    veri) `currentContext` **null** dönüyor ve `_anchorRect` `null` veriyor
    ([`tour_overlay.dart:46-54`](app/lib/core/tour/tour_overlay.dart:46)). Sonuç
    sessizce **ortalanmış, hedefsiz** balon — hata yok, uyarı yok.
  - **Konum tutmuyor:** Hedefin dikdörtgeni **yalnız build anında** ölçülüyor
    ([`:59`](app/lib/core/tour/tour_overlay.dart:59)); kullanıcı kaydırınca ya da
    yerleşim değişince (görsel yüklenmesi, async veri) spot ışığı ve balon eski
    yerde kalıyor. Yeniden ölçen bir dinleyici yok.
  - **Hedefe götürmüyor:** Hedefi görünür kılmak için kaydırma
    (`Scrollable.ensureVisible` benzeri) hiç yok; ekranın altındaki bir hedef
    için tur, boş bir alanı işaret ediyor.
  - **Sıra tutmuyor:** Adımlar sabit bir liste ([`tour_models.dart:44`](app/lib/core/tour/tour_models.dart:44));
    hedefi bulunamayan adım atlanmıyor, ortalanmış balon olarak yine gösteriliyor —
    kullanıcıya sıra bozulmuş gibi geliyor.
- **Kapsam dışı:** Tur **içeriklerini** yeniden yazmak (WP-324 metinleri korunur) ·
  yeni ekranlara tur eklemek · `tour_gate.dart` kuyruk/engel kararları (çalışıyor) ·
  onboarding açılış ekranı · yeni l10n anahtarı.
- **SAHİP dosyalar (yaz):**
  - `app/lib/core/tour/tour_overlay.dart` · `tour_host.dart` · `tour_controller.dart` ·
    `tour_models.dart`
  - `app/test/core/tour/**` ilgili testler
- **DOKUNMA (oku, değiştirme):** `tour_gate.dart` saf karar fonksiyonu ·
  `tour_prefs.dart` kalıcılık anahtarları (sürüm şeması bozulmaz) · ekranların
  tur **içerik** tanımları · `core/navigation/**`.
- **Adımlar:**
  - [ ] Hedef ölçümünü canlı yap: kaydırma/yerleşim değişiminde dikdörtgen
    yeniden hesaplansın, spot ışığı ve balon hedefi takip etsin.
  - [ ] Adım başlarken hedefi görünür alana **kaydır**; kaydırma bitmeden balonu
    yerleştirme.
  - [ ] Hedefi gerçekten bulunamayan adım için açık bir davranış seç ve testle
    kilitle: ya adımı **atla**, ya bilinçli "hedefsiz" olarak işaretlenmişse
    ortala. **Sessiz düşüş kalmasın** — bugünkü asıl hata bu.
  - [ ] Hedefsiz olması *kasıtlı* adımları (genel karşılama) modelde açıkça
    ayır; `anchor == null` ile "anchor vardı ama bulunamadı" aynı şey sayılmasın.
  - [ ] Balon yerleşimini hedef ekranın kenarına/altına yakınken de taşmayacak
    biçimde sınırla (üst/alt otomatik seçim).
  - [ ] Her ekranın turunu boş-veri ve dolu-veri hâlinde ayrı ayrı doğrula.
- **Veri/Migration etkisi:** Yok. Tur sürüm anahtarları (`storageId`) korunur —
  şema değişirse kullanıcılar turu yeniden görür. **Geri alma:** tek commit.
- **Ortam/Deploy:** Yalnız local.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** hedef kaydırma alanının dışında · hedef hiç monte değil ·
  hedef tur sırasında kayboluyor (veri değişti) · klavye açık · büyük yazı
  ölçeği · 360 dp · telefon yatay · tablet (WP-361 ile kesişir) · Windows ·
  reduce-motion · tur ortasında ekran değişimi.
- **Kabul (ölçülebilir):**
  - Her tur adımı için: hedef **görünür alana getirilmiş** ve spot ışığı gerçek
    hedefin üstünde — testte hedef dikdörtgeni ile spot dikdörtgeni örtüşür.
  - Kaydırma sonrası spot/balon hedefi takip eder (kaydır → yeniden ölç testi yeşil).
  - Bulunamayan hedefte davranış **tanımlı ve testli**; sessizce ortalanan balon **0**.
  - Balon 360 dp'de ve büyük yazı ölçeğinde ekran dışına **taşmaz**.
  - Altı ekranın turu boş ve dolu veriyle uçtan uca çalışır; `flutter analyze`
    0 uyarı, tur testleri yeşil.
- **Tuzaklar:** Her karede yeniden ölçmek jank üretir — ölçüm kaydırma/yerleşim
  olayına bağlanmalı, `build`'e değil. Tur sürüm anahtarını gereksiz artırmak
  bütün kullanıcılara turu yeniden açar. `tour_gate.dart` çalışıyor; onu
  "iyileştirmek" için açmak kapsam kaymasıdır.
- **Model önerisi:** 🟣 Pro

#### Faz F3 çakışma matrisi (10 kart)

```text
Dalga 1 (paralel güvenli, 4 worker):
  WP-353 auth ops/doc · WP-354 presence kanıt/doc · WP-356 kamp ateşi PNG · WP-358 tema token

Dalga 2 (dalga 1 kapandıkça):
  WP-357 V3 rollout      ← WP-355 ile seri (aynı presence yüzeyi)
  WP-359 Başarımlar IA   ← WP-358 token'ına bağlı
  WP-360 kamp ateşi rev2 ← WP-356 ile seri (aynı dosyalar)
  WP-361 tablet envanteri (bağımsız, salt-okunur — her an açılabilir)
  WP-362 tanıtım turu    (bağımsız)

Seri kilitler:
  WP-354 → WP-355 → (veya) WP-357     ikisi aynı anda değil
  WP-356 → WP-360
  WP-358 → WP-359
```

> ✅ **Dalga 1'de çakışma yok:** WP-353 yalnız iki doküman, WP-354 yalnız yeni bir
> kanıt dosyası, WP-356 yalnız kamp ateşi PNG katmanı + kendi golden'ları,
> WP-358 yalnız tema token'ı + rozet bileşeni yazar. Ortak SAHİP dosyası yok.
>
> ⚠️ **`core/theme/**` sıcak dosyadır.** WP-358 açıkken başka hiçbir tema işi
> başlatılmaz. WP-359 token'ı yalnız **okur**, tanımlamaz.
>
> ⚠️ **Presence yüzeyi tek kişiliktir.** WP-355 (V49-6 düzeltmesi) ve WP-357
> (V49-1 rollout) aynı provider/repository yüzeyine dokunur, ayrıca WP-338/339/346
> ile ortaktır. **Aynı anda en fazla biri açılır.** Sıra önerisi: önce WP-354
> ölçümü, sonra WP-357 (ucuz, yalnız yapılandırma), sonra WP-355 (mimari).
>
> ⚠️ **Kamp ateşi tek kişiliktir.** WP-356 (gri leke) ve WP-360 (2. revizyon)
> aynı dosyalara ve aynı golden'lara girer; WP-356 kapanmadan WP-360 başlamaz.
>
> ⚠️ **WP-361 koda dokunmaz** (sahip kapısı). Çıktısı bir sonraki uygulama
> kartıdır — WP-363'ten devam eder ve kapsamı sahip kararına göre yazılır.
> Tablet yerleşimi kamp ateşi ve ana ekran ızgarasıyla kesişeceği için, uygulama
> kartı WP-360 kapanmadan başlatılmaz.
>
> 🔴 **Üç büyük program kuralı (`.agents/AGENTS.md §1.2`) korunur:** Faz F3'te
> Tema (WP-358), Başarım (WP-359) ve Saat/sayaç (WP-357/355) kartları vardır;
> **üçü birden aynı anda açılmaz.** Dalga 2'de en fazla iki çalışma hattı.

---

### Faz F4 — Presence şema hatası ve çoklu cihaz senkronu (sahip emri, 2026-07-27)

> 🔴 **Sahip emri (§0.1):** "sayaç başlayınca grupta aktif görünse bile
> başkalarında görünmüyor" **ve** "çoklu cihaz senkronu" — ikisi de çözülüp
> **stable'a** çıkacak, test sahip tarafından stable'da yapılacak. Beta ara adımı
> ve cihaz ön kabulü sahip tarafından açıkça atlanmıştır.
>
> **Kayıt hijyeni:** WP-354 (presence ölçüm kartı) **iptal** — ölçüm yapılmadan
> kök neden koddan bulundu, cihaz gerekmedi. WP-355 ve WP-357'nin yerini
> WP-363/364/365 alır; eski kartlar tarihsel kalır, worker'a verilmez.

#### WP-363: Presence sunucuya hiç yazılmıyor — legacy payload şema uyumsuzluğu 🔴
- **Program/Faz:** Faz F4 · release-blocking bug · **Durum:** [x] Kod/test tamam (`a70c29f`) — v51'de çıktı, cihaz kabulü sahipte
- **Kök neden (kodda doğrulandı, ölçüm gerekmedi):** `Presence.toMap()` payload'a
  **`lease_expires_at`** koyuyor ([`presence.dart:97`](app/lib/data/models/presence.dart:97)),
  ama legacy `public.presence` tablosunda böyle bir kolon **yok** — tablo 0001'de
  `user_id, group_id, status, started_at, today_seconds, subject_id, updated_at`
  ile tanımlı ([`0001:66-74`](supabase/migrations/0001_initial_schema.sql:66)) ve
  hiçbir migration ona kolon eklememiştir (`alter table public.presence` yalnız
  RLS için geçer). `lease_expires_at` yalnız 0081'in projeksiyon tablolarında ve
  0082'de `live_study_runs`'ta vardır. Sonuç: `_writeLegacy` →
  `from('presence').upsert(toMap())` PostgREST'te **bilinmeyen kolon** hatasıyla
  reddediliyor ([`supabase_presence_repository.dart:77`](app/lib/data/repositories/supabase/supabase_presence_repository.dart:77)).
- **Neden kimse fark etmedi:** hata **iki kez** yutuluyor — `PresenceLifecycle.beat()`
  içinde `.catchError((_) {})` ([`presence_lifecycle.dart:87-90`](app/lib/data/providers/presence_lifecycle.dart:87)),
  offline katman ise satırı yerel cache'e yazıp **yerel dinleyicilere anında**
  basıyor ([`offline_first_presence_repository.dart:46-58`](app/lib/data/repositories/offline/offline_first_presence_repository.dart:46)).
  Bu yüzden kullanıcı **kendini** aktif görüyor, karşı taraf hiç görmüyor.
- **Ne zaman girdi:** `80f4bf3` "WP-339: cut over presence to server projections".
  Legacy varsayılan mod olduğu için **v49 ve v50'de presence sunucuya hiç
  yazılmamıştır.** V49-6'nın ("bir süre sonra düşüyor") da aynı kök nedeni budur.
- **SAHİP dosyalar:** `app/lib/data/models/presence.dart` · yeni
  `app/test/data/presence_legacy_payload_test.dart`
- **DOKUNMA:** projeksiyon RPC yolu (`apply_multi_group_presence_state` zaten açık
  parametre kullanır, `toMap` kullanmaz) · offline cache serileştirmesi
  (`_presenceToJson`, ayrı) · migration'lar — **legacy tabloya kolon EKLENMEZ**;
  doğru olan istemcinin var olmayan kolonu yazmayı bırakmasıdır.
- **Kabul (ölçülebilir):** Legacy payload anahtarları legacy tablo kolonlarının
  **alt kümesi** ve bunu kilitleyen test var · iki hesap aynı grupta birbirini
  `≤ 10 sn` içinde "çalışıyor" görür · `flutter analyze` 0 uyarı.
- **Tuzak:** `presence` PK `user_id`, yani kullanıcı başına tek satır; bu düzeltme
  çoklu grup görünürlüğünü çözmez (o WP-365 projeksiyonunun işi).
- **Model önerisi:** 🔴 Opus

#### WP-364: Presence yazma hatası bir daha sessiz kalmasın 🔇
- **Program/Faz:** Faz F4 · dayanıklılık · **Durum:** [x] Kod/test tamam (`0a640b8`) — 5 test yeşil
- **Problem:** WP-363'ün asıl maliyeti hatanın kendisi değil, **iki katmanda
  sessizce yutulmuş** olmasıdır. Aynı sınıf hata yarın yine sessizce döner.
- **SAHİP dosyalar:** `app/lib/data/providers/presence_lifecycle.dart` ·
  `app/lib/data/providers/presence_providers.dart` · ilgili testler
- **Kabul:** Uzak presence yazma hatası gözlemlenebilir ve `readSyncStatus`
  üzerinden okunabilir · koşulsuz `catchError((_) {})` kalmadı · hata timer/UI
  akışını **bozmuyor** (yangına-at-unut korunur).
- **Model önerisi:** 🟣 Pro

#### WP-365: Çoklu cihaz senkronu — V3 rollout'u aç ve stable'a ver 📱↔️📱
- **Program/Faz:** Faz F4 · V3 rollout · **Durum:** [~] **Kısmen kabul edildi (sahip, 2026-07-27).**
  Presence görünürlüğü çalışıyor. Ancak `foregroundMirror` açık olmasına rağmen
  **sayaç değeri/durumu aynalanmıyor**: bir cihazda başlatınca diğeri `00.00.00`
  kalıyor ve ikinci eşzamanlı sayaç başlatılabiliyor (V51-2). Bildirimler de
  senkron değil. Kademe açık ama beklenen aynalamayı üretmiyor.
- **Seçilen kademeler:** presence `shadow`, global timer `foregroundMirror`.
  Presence bilerek `projection` değil: doğrudan geçmek, **eski sürümde kalan**
  ekip üyelerini (yalnız legacy tabloyu okurlar) yeni sürümdekilere görünmez
  yapardı. `shadow` ikisine de yazar, ikisinden de okur. Filo tek sürüme
  geçtiğinde `projection`'a yükseltilebilir.
- **Yan bulgu (`c18e37d`):** Rollout doğrulanırken kamp ateşi golden'ının hâlâ
  kararsız olduğu görüldü; `6f285a2` yeterli değilmiş. Gerçek kök neden
  `MarshmallowPainter.paint()` içinde **duvar saati** okunmasıydı — marşmelov
  kızarma rengi her çizimde değişiyordu. Marşmelov yalnız çalışan üyelerde
  çizildiği için fark çalışan sayısıyla büyüyor ve sadece 8 kişi senaryosu
  toleransı aşıyordu. `now` sahneden aşağı taşındı; izole 3/3 ve tam paket yeşil.
- **Problem:** V3 zinciri (WP-336…WP-345) kodda ve `0085`te hazır ama anahtarlar
  **sabit kodlu kapalı**: `presenceProjectionModeProvider → legacy`,
  `globalTimerModeProvider → disabled`. Çalışma zamanında açılamıyor.
- **Sahip kararı:** Stable'da **açık** gelecek; test stable'da yapılacak.
- **SAHİP dosyalar:** yeni `app/lib/core/config/rollout_config.dart` ·
  `presence_providers.dart` ve `global_timer_providers.dart` (yalnız mode
  provider'larının kaynağı) · ilgili testler
- **DOKUNMA:** WP-336…WP-345 feature kodu · native timer/bildirim/widget ·
  uygulanmış migration'lar.
- **Adımlar:** üç kademeyi (presence projection · global timer · foreground
  mirror) **ayrı ayrı** açılabilir yap · tek okuma noktası · testle kilitle.
- **Kabul (ölçülebilir):** Aynı hesapta iki cihazda başlat/durdur aynası
  `p95 ≤ 2 sn` · ek session **0**, çift XP **0** · bildirim/widget regresyonu
  **0** · bir kademe kapatılınca diğerleri çalışır · kapalı konumda davranış
  bugünküyle birebir aynı.
- **Geri alma:** Uzaktan kapatma yolu **yok** (sunucu tarafı flag altyapısı
  kurulmadı). Sorun çıkarsa geri dönüş = anahtarı kapatan yeni stable hotfix.
  Bu bedel sahip tarafından kabul edilmiştir.
- **Model önerisi:** 🔴 Opus

#### WP-366: v51 stable release 🚀
- **Durum:** [x] **KAPANDI 2026-07-27.** `v51` yayında, **Android + Windows ikisi de** üretildi.
- **Kanıt:** release koşumu [30278738927](https://github.com/manil-max/online-study-room/actions/runs/30278738927) — preflight/android/windows/finalize **tümü success**. Release: https://github.com/manil-max/online-study-room/releases/tag/v51
- **Not:** v50'de üretilemeyen Windows MSIX bu kez çıktı; engel olan golden kararsızlığı `c18e37d` ile kök nedeninden çözüldü.
- **Kapsam:** sürüm/build kimliği, CHANGELOG, release_notes, tag `v51`, Android +
  Windows artefaktı. Migration **yok**, production `0085`te kalır.
- **Kabul:** Preflight/gate PASS · Android APK yayında · Windows MSIX bu kez
  üretilir (golden kararsızlığı `6f285a2` ile düzeldi) · release notlarında V3'ün
  **açık** geldiği ve geri dönüşün hotfix olduğu yazılı.

---

### Faz F5 — v51 saha düzeltmeleri: lease tazeleme ve sayaç komut yayını (sahip emri, 2026-07-27)

> **Sahip emri (2026-07-27):** "*admin tarafı kalsın, saat senkron ve aktiflikten
> düşmeyi çözüp stable'a yolla, emirdir bu, yetki veriyorum.*" → `.agents/AGENTS.md §0.1`.
> Kapsam **V51-1 + V51-2**. V51-3/V51-4 (admin yazışması) bilinçli olarak **dışarıda**.
>
> Kök nedenler koddan doğrulandı (bu turdaki analiz, `backlog.md` V51-1/V51-2
> altında da özetli). İkisi de mimari hata değil, **katmanlar arası bağlantı
> eksiği**: biri sunucuda (lease iki tabloda ayrı yaşıyor), biri istemcide
> (komut kuyruğu yalnız resume'da boşalıyor).

#### WP-367: Presence lease'i projeksiyonda da tazele (V51-1) ⏱️
- **Durum:** [x] **KOD TAMAM + PRODUCTION'A UYGULANDI 2026-07-27.** `0086` üç ortamda da yaşıyor.
  🟢 **Bu düzeltme sunucu taraflıdır: v51 istemcisinde de geçerlidir, güncelleme beklemez.**
  Cihaz kabulü sahipte.
- **Kanıt:** local replay + pgTAP [30287757738](https://github.com/manil-max/online-study-room/actions/runs/30287757738) PASS (yeni `015` yeşil) ·
  staging apply [30287989909](https://github.com/manil-max/online-study-room/actions/runs/30287989909) ·
  production dry-run [30288269106](https://github.com/manil-max/online-study-room/actions/runs/30288269106)
  (bekleyen tam olarak `0086`+`0087`) · production apply
  [30288908244](https://github.com/manil-max/online-study-room/actions/runs/30288908244), post-check head **`0087`**.
  İlk apply denemesi (`30288596263`) push'tan **önce** `migration-list` adımında bağlantı zaman aşımına düştü; hiçbir DDL çalışmadı.
- **SAHİP:** `supabase/migrations/0086_*.sql` · `supabase/tests/*_0086_*.sql` ·
  `docs/recovery/MIGRATION-BASELINE.md`
- **DOKUNMA:** `app/lib/data/providers/presence_*.dart` · `0081`–`0085` (geçmiş migration'lar asla düzenlenmez)
- **Kök neden (kodda doğrulandı):** `heartbeat_multi_group_presence()`
  (`0081:219`) lease'i **yalnız** `user_live_presence_state` üzerinde yeniliyor;
  fonksiyonun kendi yorumu da projeksiyonu bilerek dışarıda bıraktığını yazıyor.
  Ama okuma tarafı `group_live_presence`'ı okuyor ve canlılığı **o satırın**
  `lease_expires_at`'inden türetiyor (`presence_providers.dart:85`). Projeksiyon
  lease'i apply anında +70 sn damgalanıp bir daha hiç tazelenmiyor.
  Shadow birleştirmede projeksiyon satırı legacy satırı **ezdiği** için
  (`supabase_presence_repository.dart:142`) taze `updated_at` de kurtaramıyor.
  70 sn lease + 20 sn okuyucu tik'i = sahibin ölçtüğü **~80 sn**.
- **Yapılacak:** `0086` ileri migration'ı `heartbeat_multi_group_presence()`'ı
  `create or replace` ile yeniden tanımlar; kanonik lease yenilendikten sonra
  aynı işlemde `group_live_presence` satırlarının `lease_expires_at`'ini de
  yeni değere çeker (mevcut `(user_id, group_id)` indeksi kullanılır).
  Fan-out/üyelik semantiği **değişmez**: satır eklenmez, silinmez, yalnız
  süresi uzatılır.
- **Kabul:**
  - pgTAP: aktif kullanıcı için heartbeat sonrası **hem** kanonik **hem**
    projeksiyon satırının `lease_expires_at`'i `clock_timestamp()`'ten büyük.
  - pgTAP: `status = 'offline'` kullanıcıda heartbeat hâlâ
    `presence_state_not_active` fırlatır (davranış korunur).
  - pgTAP: heartbeat projeksiyon satır **sayısını** değiştirmez.
  - Cihazda: sayaç 3 dakika kesintisiz çalışırken hem başlatan cihazda hem
    başka kullanıcıda "aktif çalışanlar" ve kamp ateşi görünür kalır.
- **Risk:** Production migration. `0085` → `0086`, üç ortam sırayla. Yedek yok
  (sahip muafiyeti); bu yüzden migration **yalnız fonksiyon gövdesi** değiştirir,
  tablo/kolon/politika dokunmaz — geri dönüşü `0081` gövdesini geri koyan yeni
  bir migration'dır.

#### WP-368: Sayaç komutunu başlatma anında yayınla (V51-2) 📱↔️📱
- **Durum:** [x] **KOD TAMAM 2026-07-27.** Cihaz kabulü sahipte (v52 gerekir).
- 🔴 **Planlarken bilinmeyen ikinci engel çıktı ve aynı dalgada kapatıldı:**
  `global_timer_v2_runtime_config.v2_enabled` `0082`'de **`false` tohumlanmış** ve
  hiçbir ortamda açılmamıştı. `apply_global_timer_command` ilk işi olarak bu
  bayrağa bakıp `global_timer_v2_disabled` fırlatıyor (`0082:217`), istemci de
  hatayı yutuyordu. Yani istemci düzeltmesi **tek başına hiçbir şey
  değiştirmezdi.** `0087` bayrağı açar; kill switch tek `UPDATE` ile geri alınır,
  sürüm gerektirmez.
- **Kanıt:** `flutter analyze` temiz · `flutter test` **953/953** ·
  yeni `app/test/data/global_timer_command_publish_test.dart` 4/4 yeşil ve
  düzeltme geri alındığında **4'ün 3'ü kırmızı** (git stash ile doğrulandı) ·
  pgTAP `016` yeşil.
- **SAHİP:** `app/lib/data/providers/study_providers.dart` (yalnız start/stop
  komut yayını) · `app/test/data/global_timer_command_publish_test.dart`
- **DOKUNMA:** `supabase/migrations/**` · `app/android/**` · presence yolları
- **Kök neden (kodda doğrulandı):** Başlatma komutu sunucuya gitmiyor, cihazda
  `timer_pending_intervals` kuyruğunda bekliyor. Kuyruğu boşaltan `flushShadow()`
  tek yerden çağrılıyor — `_syncBackgroundTimerState` (`study_providers.dart:704`),
  yani **soğuk açılış ve uygulama öne gelme**. Başlatmanın ardından çağıran yok.
  Sonuç: A'da başlatılan koşu sunucuya hiç yazılmıyor → B açıldığında snapshot
  boş → `00.00.00`, ve B kendi sayacını başlatabiliyor (sunucu A'dan habersiz).
  İkinci sayaç ayrı bir hata değil, aynı hatanın sonucu.
- **İkincil yarış (aynı kartta kapanır):** `start()` içinde `bindActiveAccount`
  ve `TimerForegroundService.start` **ikisi de** `unawaited`. Bind yetişmezse
  native zarfı boş `account_id` ile yazıyor, adapter onu kalıcı karantinaya
  alıyor (`flushShadow` `command.accountId != user.id` ile atlıyor) — o komut
  bir daha asla gönderilmiyor. Kartta bind → native start sırası determinize edilir.
- **Kapsam dışı (bilinçli):** `device_id` push kaydına bağlıdır ve öyle
  kalacaktır — `global_timer_commands.device_id` `push_devices(id)`'ye **FK**
  (`0082:95`), istemci kendi kimliğini uyduramaz. Push kaydı yoksa senkron
  çalışmaz; bu tasarım gereğidir, ayrı kart konusudur.
  Native yalnız kronometre + `work` fazı için komut üretir (`StudyTimerService.kt:136`);
  bu da V1 sözleşmesi olarak korunur (varsayılan mod `stopwatch`).
- **Kabul:**
  - Birim test: start sonrası kuyruk boşaltma **tam bir kez** tetiklenir ve
    native yazımı tamamlandıktan **sonra** çalışır (yarış testi).
  - Birim test: bind, native start'tan **önce** tamamlanır → zarf hesap bağlı
    yazılır, karantinaya düşmez.
  - Birim test: stop sonrası da yayın tetiklenir.
  - Yayın hatası (ağ/RLS) sayacı durdurmaz, istisna yukarı sızmaz.
  - Cihazda: A'da başlat → B'yi aç → B aynı geçen süreyi aynalar; B'de ikinci
    sayaç başlatılamaz (mirrorStart `deferred` yolu).
- **Risk:** `start()` sıcak yolu. FGS başlatma bir prefs yazımı kadar gecikir;
  bildirim/widget sırası korunur.

#### WP-369: v52 stable release 🚀
- **Durum:** [x] **KAPANDI 2026-07-27.** `v52` yayında, **Android + Windows ikisi de** üretildi.
- **Kanıt:** release koşumu [30289549858](https://github.com/manil-max/online-study-room/actions/runs/30289549858) —
  preflight/android/windows/finalize **tümü success**.
  Release: https://github.com/manil-max/online-study-room/releases/tag/v52
  Artefaktlar: `app-release.apk` · `odak-kampi-windows-stable.msix` ·
  `odak-kampi-windows-stable.zip` (+ sha dosyaları, `release-manifest.json`).
- **Kapı durumu:** production `deploy_enabled`/`release_enabled` apply ve release
  bitince **yeniden `false`'a kilitlendi**; guard testleri bu durumu doğruluyor.
- **Bağımlılık:** WP-367 + WP-368 yeşil. ✅
- **Kapsam:** sürüm/build kimliği, CHANGELOG, release_notes, tag `v52`.
  **Migration taşır (`0086`)** — v51'den farkı budur; production apply GO'su ayrı adımdır.
- **Kabul:** preflight/gate PASS · üç ortam `0086` · Android artefaktı yayında ·
  release notunda "aktiflikten düşme" ve "çoklu cihaz sayaç aynalama" maddeleri yazılı.

#### WP-370: Timer-sync teslim zinciri ve foreground reconcile 📱↔️📱
- **Durum:** [x] **KAPANDI 2026-07-27.** `0088` staging (`30296764464`) ve
  production'a (`30297435093`) uygulandı, ikisinde de post-check head `0088`.
  v53 ile stable'a çıktı. **Cihaz kabulü sahipte.** Kod incelemesinde çıkan
  yaşam döngüsü kusuru WP-371'de düzeltildi.
- **Kök neden:** `0083` timer-sync outbox/FCM policy'sini kurmuştu fakat
  `enqueue_timer_sync_push` hiçbir gerçek V2 start/stop yolundan çağrılmıyordu;
  runtime flag de kapalıydı. Böylece A'daki state değişimi B'ye sinyal üretmiyor,
  B ancak açılış/resume'da snapshot okuyabiliyordu.
- **Yapılan:** `0088`, yalnız çağıran kullanıcının kendi hesabına yazabilen ve
  `authenticated` execute izni olmayan internal helper ekler. `apply_global_timer_command`
  başarılı start/stop sonrası bu helper ile origin cihaz hariç timer-sync outbox
  oluşturur; adopt/stale/duplicate/heartbeat sinyal üretmez. Timer-sync runtime
  flag'i aynı migration ile açılır. İstemci foreground'dayken 5 sn auth'lu snapshot
  reconcile çalıştırır; FCM gecikse/kaybolsa bile iki açık cihaz birleşir. Payload
  hiçbir zaman state olarak uygulanmaz; yalnız güncel snapshot'ı tetikler.
- **Güvenlik:** Helper `auth.uid() == recipient_id`, run ownership ve aktif origin
  device doğrular; `PUBLIC`, `anon` ve `authenticated` için execute revoke edilir.
  Uygulama tarafından service-role kullanımı veya geniş yeni RPC izni yoktur.
- **Kanıt:** `flutter analyze` temiz · hedefli Flutter testleri 11/11 yeşil ·
  local reset + pgTAP 18 dosya / 270 test PASS (evidence
  `20260727T184216581Z-local-baseline`). Yeni `017` start/stop outbox, origin
  exclusion, revision/state-version ve gecikmiş stop'un yeni sinyal üretmemesini
  doğrular.
- **Kabul:** staging apply sonrası outbox/delivery/dispatch kaydı · iki kayıtlı
  Android cihazda A start/stop → B p95 ≤10 sn mirror start/stop · FCM kapalı/kaçmış
  foreground senaryosunda B ≤5 sn içinde snapshot reconcile · eski FCM sinyali
  güncel snapshot dışında state uygulamaz.

#### WP-371: Snapshot turunu yaşam döngüsüne bağla 🔋
- **Durum:** [x] Kapandı (2026-07-27). WP-370 incelemesinde bulundu.
- **SAHİP:** `app/lib/data/providers/study_providers.dart` ·
  `app/test/data/global_timer_command_publish_test.dart`
- **Kök neden:** WP-370'in 5 sn'lik snapshot turu `build()` içinde
  `Timer.periodic` ile kurulup hiçbir yaşam döngüsü olayına bağlanmamıştı. Kod
  yorumu "uygulama foreground'dayken" diyor, davranış bunu uygulamıyordu: sayaç
  çalışırken native foreground servis süreci canlı tuttuğu için ekran kapalıyken
  de saatlerce 5 sn'de bir auth'lu snapshot RPC'si dönerdi (~720 istek/saat/cihaz,
  pil + kota). Arka planda turun ürün değeri yok — ayna arayüzü görünmüyor ve o
  pencerede senkronu zaten timer-sync FCM taşıyor.
- **Yapılan:** `AppLifecycleListener`'a `onHide`/`onPause` eklendi; ikisi de turu
  iptal eder. `onResume` hem turu yeniden kurar hem mevcut tek seferlik
  `_syncBackgroundTimerState()` uzlaştırmasını çalıştırır.
  `_startGlobalTimerForegroundRefresh` artık dispose sonrası tur kurmaz.
- **Kanıt:** `flutter analyze` temiz · **955/955** Flutter testi yeşil · yeni
  regresyon testi `onHide`/`onPause` kaldırılınca **kırmızıya döndü**
  (`Expected: <1> Actual: <2>`), yani gerçekten kapan. Test hem arka planda
  turun durduğunu hem de öne dönünce **resume'un tek seferlik uzlaştırmasının
  ötesinde** periyodik turun geri geldiğini ölçer.
- **Kabul:** analyze temiz · tam süit yeşil · düzeltme geri alınınca test kırmızı.

#### WP-372: v53 stable release 🚀
- **Durum:** [x] **KAPANDI 2026-07-27.** `v53` yayında, **Android + Windows ikisi de** üretildi.
- **SAHİP:** `app/pubspec.yaml` · `CHANGELOG.md` · `app/assets/release_notes.json` ·
  `tooling/release/**` · `tooling/supabase/guard.tests.ps1`
- **Kapsam:** sürüm/build kimliği (`1.0.53+53`), CHANGELOG, release_notes, tag `v53`.
- **Kanıt:** release run
  [30297781192](https://github.com/manil-max/online-study-room/actions/runs/30297781192)
  — preflight · android · windows/build · finalize_android · release_status ·
  finalize_complete hepsi **success**. Artefaktlar: `app-release.apk`,
  `odak-kampi-windows-stable.msix`, `odak-kampi-windows-stable.zip`, sha256
  toplamları ve `release-manifest.json`.
  Release: https://github.com/manil-max/online-study-room/releases/tag/v53
- **Dürüstlük notu:** release notu, **v52'nin eşitleme vaadinin tutmadığını**
  açıkça yazıyor. Kapsam sınırı da yazılı: Android + kronometre, iki cihazda da
  v53 ve push kaydı şart; Pomodoro/geri sayım/Windows dahil değil.
- **Kabul:** preflight/gate PASS · üç ortam `0088` · Android + Windows artefaktı
  yayında · production kapısı apply ve release sonrası yeniden `false`
  kilitlendi (76 guard testi yeşil).

#### WP-373: Çoklu cihaz sayaç senkronu — istemci↔sunucu komut sözleşmesi 📱↔️📱
- **Durum:** [~] Kod tamamlandı — **staging apply + gerçek cihaz kabulü bekliyor.**
- **SAHİP:** `app/android/.../timer/TimerStateStore.kt` ·
  `app/android/.../timer/StudyTimerService.kt` ·
  `app/lib/core/background/timer_v2_command_outbox.dart` ·
  `app/lib/data/providers/global_timer_providers.dart` ·
  `app/lib/data/providers/study_providers.dart` ·
  `supabase/migrations/0089_global_timer_lease_sweeper.sql` ·
  `supabase/tests/018_global_timer_command_contract.test.sql` ·
  `app/test/core/timer_v2_origin_contract_test.dart` ·
  `app/test/core/timer_v2_command_outbox_test.dart` · `tooling/release/**` ·
  `tooling/supabase/guard.tests.ps1`

- **Teşhis (sahip production sorgusuyla mühürlendi, 2026-07-27):**
  `select result_code, count(*) from public.global_timer_commands group by 1`
  → **0 satır.** `notification_outbox where notification_type='timer_sync'`
  → **0 satır.** Yani WP-341'den beri **tek bir komut bile** sunucuya ulaşmadı;
  RPC exception atınca transaction geri sardığı için audit satırı bile yazılmadı.
  Bu, "v52/v53 bozdu" değil — özellik **hiç çalışmamış**.

- **🔴 Kök neden 1 — `origin` sözlüğü uyuşmuyor (her `start` reddediliyordu).**
  Sunucu `('app','widget','notification','recovery')` bekliyor
  (`0082:277-280`), istemci ham `dart_app` / `native_widget` /
  `native_notification` gönderiyordu. Aradaki çeviri repoda **hiç yoktu**;
  `global_timer_providers.dart:72` değeri olduğu gibi payload'a koyuyordu.
  Sonuç: `invalid_global_timer_origin`, `catch (_)` ile yutuluyor, zarf kuyrukta
  kalıyor ve her turda yeniden patlıyordu (kuyruk sonsuza kadar büyüyordu).
- **🔴 Kök neden 2 — durdurma hiç yayınlanmıyordu.** Uygulama içi Durdur
  `ACTION_STOP_SILENT` → `handleStop(recordInterval = false)` yolunu kullanır;
  V2 zarfı o bloğun **içindeydi**, yani en sık kullanılan durdurma hiçbir zaman
  sinyal üretmiyordu. Bildirim/widget Durdur'u zarf üretiyordu ama
  `expected_run_revision` **hep null**'dı (native hiç göndermiyordu) → sunucu
  `stop_run_revision_required` atıyordu.
- **🔴 Kök neden 3 — kira ne yenileniyor ne süpürülüyordu.** Hiçbir istemci
  `heartbeat` göndermiyordu ve `expire_global_timer_v2_leases` (0082'de yazılı)
  hiçbir cron'a bağlı değildi. Koşu sonsuza dek `running` kalıyor, ayna cihaz
  ölü bir koşuyu gösteriyordu.

- **Neden 955 test yeşilken bu kaçtı:** pgTAP sunucuyu **kendi uydurduğu**
  `'app'` değeriyle çağırıyordu (`013:55`, `017:37`); Dart testleri
  `flushShadow()`'u komple stub'lıyordu
  (`global_timer_command_publish_test.dart:41`); InMemory repo payload'ı hiç
  doğrulamıyordu. Her uç kendi içinde tutarlıydı, **aralarını tutan tek bir
  iddia yoktu.** Dahası `timer_v2_command_outbox_test.dart` arızayı "excludes
  silent stop" başlığıyla **doğru davranış diye kayda geçirmişti.**

- **Yapılan (istemci):**
  - `TimerStateStore.canonicalV2Origin` — tek çeviri noktası, tanınmayan origin
    `null` döner ve komut üretilmez (fail-closed). `global_timer_mirror` böylece
    kendiliğinden dışarıda kalır (echo start yok).
  - Zarf şeması **2 → 3**. Cihazlarda birikmiş `dart_app` taşıyan eski kayıtlar
    `discard` olup kuyruktan düşer; uygulanamayacak komut sonsuza dek denenmez.
  - V2 stop zarfı `recordInterval`'dan **ayrıldı**; `run_id` +
    `expected_run_revision` yeni `KEY_V2_RUN_ID` / `KEY_V2_RUN_REVISION`
    köprüsünden okunur (Dart, apply başarılı olunca yazar; `writeIdle` siler).
    Kimlik yoksa zarf hiç yazılmaz.
  - `flushShadow` artık `prefs.reload()` yapar. **WP-368'in "başlatma anında
    yayınla" düzeltmesi bu eksik yüzünden fiilen no-op'tu** — kuyruğu native
    yazar, Dart'ın prefs'i önbelleklidir; yayını yalnız broadcast yolu
    kurtarıyordu.
  - 60 sn'lik `heartbeat` turu (yaşam döngüsüne bağlı **değil** — ekran
    kapalıyken de kirayı tazelemeli). 60 istek/saat = snapshot turunun 1/12'si.
- **Yapılan (sunucu):** `0089` — `expire_global_timer_v2_leases(200)` dakikalık
  pg_cron job'ı. Şema/kolon/politika/grant değişmez, satır eklenmez.
  Geri alma: tek `cron.unschedule`.

- **Kanıt:** `flutter analyze` **0 uyarı** · tam Flutter süiti yeşil ·
  local `db reset` + **tam pgTAP replay** `0089` ile yeşil (yeni `018` dahil) ·
  76 deploy guard + 8 release preflight testi yeşil ·
  **regresyon kapanı kanıtlandı:** `canonicalV2Origin`'deki `dart_app -> app`
  çevirisi geri alınınca `timer_v2_origin_contract_test.dart` kırmızıya döndü
  (`Expected: contains 'dart_app' / Actual: Set:['app','widget',...]`).
- **Sözleşme kapanı:** `timer_v2_origin_contract_test.dart` üç ucu (Kotlin
  üretici · Dart sabit · migration allowlist) **birbirine karşı** ölçer;
  `018_global_timer_command_contract.test.sql` sunucu ucunda eski istemci
  sözlüğünün reddedildiğini kayda geçirir.

- **Bilinen sınırlar (kapsam dışı, bilerek):**
  - Senkron yalnız **Android + kronometre/çalışma fazı**. Pomodoro, geri sayım
    ve Windows V2 komutu üretmez (Windows'ta push cihaz kaydı da yok).
  - Ayna cihaz koşuyu **yerel olarak** durdurur, sunucudaki koşuyu kapatmaz;
    koşunun sahibi başlatan cihazdır (`docs/…PLAN.md §16.4`).
  - Aynalama yalnız **Flutter tarafı ayakta iken** uygulanır. Uygulama arka
    plandayken gelen FCM ayrı isolate'e düşer ve `TimerSyncSignal.pendingKey`
    hiçbir yerde okunmaz → cihaz açılana kadar bildirim/widget'ta sayaç
    başlamaz. "Cihaz uykudayken de başlasın" ayrı bir iş (native FCM → FGS
    köprüsü); sahibe soruldu, Tur 1 kabulünden sonra karar verilecek.
- **Kabul:** analyze temiz · tam süit yeşil · local pgTAP replay yeşil ·
  düzeltme geri alınınca sözleşme testi kırmızı. **Cihaz kabulü sahipte:**
  iki cihazda da bu sürüm + staging/production apply şart.


#### WP-374: Geri bildirim yazışması — sohbet düzeni ve yöneticinin kullanıcıya giden yolu 💬
- **Durum:** [x] Kod/test tamam — cihaz kabulü bekliyor. Kaynak: **V51-3 + V51-4**
- **SAHİP:** `app/lib/features/profile/feedback_tickets_screen.dart` ·
  `app/lib/features/admin/tabs/admin_reports_tab.dart` ·
  `app/lib/l10n/app_{en,tr,de,ar}.arb` ·
  `app/test/features/feedback_conversation_wp374_test.dart`

- 🔴 **backlog.md'deki V51-4 kök nedeni YANLIŞTI — koddan çürütüldü.**
  Kart "admin panelinde yazışma ekranı hiç yok" diyordu. Oysa `Yanıt yaz`
  eylemi **WP-317/318'den beri var** (`admin_reports_tab.dart:209`,
  `showFeedbackTicketConversation`), sohbet diyaloğu admin-farkında yazılmış
  (`feedback_tickets_screen.dart:176` `adminIsSuperAdminProvider`), RPC admin
  rolünü `is_super_admin()`'den türetiyor ve RLS süper-admin'e tüm mesajları
  açıyor (`0074:41-53`). Sunucu ve istemci tarafı eksiksizdi.
- **Gerçek mekanizma:** bilet kartında iki eylem yan yanaydı — `İç Notlar` ve
  `Yanıt yaz`. `İç Notlar` diyaloğu bir metin kutusu + gönder düğmesiyle **tıpkı
  bir sohbet gibi** görünüyor ama `feedback_ticket_notes`'a yazıyor; o tablo
  yalnız yöneticinindir. Yönetici oraya yazıp kendi notlarını okuyunca
  "sadece kendi mesajlarım görünüyor" tablosu birebir oluşuyor. Bu bir RLS ya
  da sorgu hatası değil, **ayırt edilemeyen iki yüzey**.
- **V51-3 (sohbet sırası) gerçek ve düzeltildi.** Veri sırası zaten doğruydu
  (`order('created_at')` artan), eksik olan sunumdu: diyalogda hiçbir
  `ScrollController` yoktu, görünen pencere en eskide takılı kalıyordu — sahibin
  "yeni mesaj üste ekleniyor" dediği görüntü tam olarak budur.

- **Yapılan:**
  - Yazışma diyaloğuna `ScrollController` + `_scrollToBottom()`: ilk yüklemede
    animasyonsuz, yeni mesaj gönderilince animasyonlu sona kaydırma. Diyalog
    hem kullanıcı hem yönetici tarafında **aynı** olduğu için tek düzeltme iki
    yüzeyi birden kapatır.
  - Yönetici bilet kartında `Yanıt yaz` **iç notların önüne** alındı ve
    `primaryContainer` ile vurgulandı; ikonu `forum_outlined` oldu. `İç Notlar`
    ikonu `lock_outline` ile kapalı bir yüzey olduğunu gösteriyor.
  - İç not diyaloğunun başına yeni `adminIcNotlarGizli` metni eklendi:
    "Bu notları yalnız yöneticiler görür. Kullanıcıya yazmak için Yanıt yaz
    kullanın." Dört katalog (EN/TR/DE/AR) eşlendi.

- **Kanıt:** `flutter analyze` **0 uyarı** · 4 yeni test + mevcut geri bildirim
  ve admin testleri yeşil · **regresyon kapanı kanıtlandı:** `_scrollToBottom`
  çağrısı kaldırılınca test kırmızıya döndü
  (`Found 0 widgets with text "Mesaj 30"`), geri konunca yeşil.
- **Veri/Migration etkisi:** Yok. Sunucu tarafı hiç değişmedi.
- **Kabul:** 30 mesajlık yazışma açılınca **en yeni** balon görünür, en eski
  görünmez · gönderilen mesaj görünür alanda kalır · yönetici kartında
  `Yanıt yaz` iç notlardan önce · iç not diyaloğu gizliliğini yazar.
- **Cihaz kabulü sahipte:** yönetici hesabıyla bir bilete `Yanıt yaz`'dan
  yazıp kullanıcı hesabında görünmesini doğrula.


#### WP-375: Tanıtım turu — hedefleme, konum ve sıra onarımı 🎈
- **Durum:** [x] Kod/test tamam — cihaz kabulü bekliyor. Kaynak: **V49-5** (eski
  kart WP-362; bu kart onun yerine geçer, WP-362 tarihsel kalır)
- **SAHİP:** `app/lib/core/tour/tour_overlay.dart` · `app/lib/core/tour/tour_host.dart` ·
  `app/test/core/tour/tour_anchor_wp375_test.dart` ·
  `app/test/features/tours/app_tours_test.dart` (yalnız yeni zorunlu parametre)

- **Sahibin ifadesi:** "mantık doğru, uygulama kötü — hedef/konum/sıra ayarları
  tutmuyor." Kodda **üç ayrı mekanizma** doğrulandı, üçü de düzeltildi:
  1. 🔴 **Konum tutmuyordu.** Hedef dikdörtgeni yalnız `build` anında
     ölçülüyordu (eski `tour_overlay.dart:59`). Kullanıcı kaydırınca ya da
     yerleşim değişince spot ışığı ve balon eski yerde kalıyordu; yeniden
     ölçen hiçbir dinleyici yoktu.
  2. 🔴 **Hedefe götürmüyordu.** `Scrollable.ensureVisible` benzeri bir çağrı
     repoda hiç yoktu. Ekranın altındaki bir hedef için tur, boş bir alanı
     işaret ediyordu — hedef monte olduğu için hata da vermiyordu.
  3. 🔴 **Sıra tutmuyordu.** Hedefi ilan edilmiş ama bulunamayan adım
     **sessizce ortalanmış** balona dönüşüyordu. Kullanıcı bunu "sıra bozuldu"
     diye okuyor; log yok, uyarı yok.

- **Yapılan:**
  - `TourOverlay` `StatelessWidget` → `StatefulWidget`. Ölçüm artık **olaya**
    bağlı: adım değişimi · gövdeden gelen `ScrollNotification` · `didChangeMetrics`
    (klavye, döndürme, pencere). Her karede ölçüm **yok** — kartın uyardığı jank
    tuzağına düşülmedi.
  - `TourHost` gövdeyi `NotificationListener<ScrollNotification>` ile sarar ve
    bir `ValueNotifier` üzerinden yeniden ölçüm sinyali verir. Tur çalışmıyorken
    sinyal üretilmez.
  - Adım başlarken hedef `Scrollable.ensureVisible(alignment: 0.5)` ile görünür
    alana getirilir; balon **kaydırma bittikten sonra** yerleştirilir.
    Kaydırılabilir ata yoksa çağrı anında tamamlanır (masaüstü/sabit ekranlar).
  - **Bulunamayan hedefin davranışı tanımlandı ve testle kilitlendi:**
    `kTourAnchorResolveFrames = 20` kare boyunca aranır (async veriyle gelen
    kart ilk karelerde monte değildir), sonra adım **atlanır**. Tek adımlıysa
    tur biter ve görüldü işaretlenir. `anchor == null` (kasıtlı "genel
    karşılama") bu yoldan **ayrı** tutulur — atlanmaz, ortada gösterilir.
  - Ölçüm zinciri `scheduleFrame()` ile açıkça kare ister; aksi hâlde hiçbir şey
    çizilmiyorken post-frame zinciri sessizce duruyordu (bu, düzeltmeyi ilk
    yazışta gerçekten ısırdı).

- **Kanıt:** `flutter analyze` **0 uyarı** · 5 yeni test + mevcut tur testleri
  (14 iddia) yeşil · **regresyon kapanı iki koldan kanıtlandı:**
  yeniden ölçüm sinyali kesilince "kaydırma sonrası takip" kırmızı;
  `ensureVisible` + atlama kaldırılınca **dört test birden** kırmızı.
- **Kapsam dışı (bilinçli):** tur **içerikleri** (WP-324 metinleri korundu) ·
  `tour_gate.dart` kuyruk kararları · `tour_prefs.dart` anahtar şeması
  (`storageId` korundu → kimse turu yeniden görmez) · yeni ekrana tur ekleme.
- **Veri/Migration etkisi:** Yok. **Geri alma:** tek commit.
- **Kabul:** hedef görünür alana getirilir · kaydırma sonrası spot/balon hedefi
  takip eder · bulunamayan hedefte davranış tanımlı ve testli, sessizce
  ortalanan balon **0** · 360 dp'de taşma **0**.
- **Cihaz kabulü sahipte:** Ayarlar → "Tanıtım turlarını sıfırla" ile altı
  ekranın turunu boş ve dolu veriyle tekrar aç.


#### WP-376: Başarımlar bilgi mimarisi — birincil grup bloğunu sağ üste taşı 🏠
- **Durum:** [x] Kod/test tamam — cihaz kabulü bekliyor. Kaynak: **V49-2**
  (eski kart WP-359; bu kart onun yerine geçer, WP-359 tarihsel kalır)
- **SAHİP:** `app/lib/features/profile/social_profile_screen.dart` ·
  `app/lib/features/profile/widgets/primary_group_selector_card.dart` ·
  yeni `app/lib/features/profile/widgets/primary_group_entry.dart` ·
  `app/test/features/profile/primary_group_entry_wp376_test.dart`

- **Problem:** WP-348'de eklenen birincil grup kartı `Başarım Yolculuğum`
  başlığının hemen altında kocaman bir blok olarak duruyordu
  (`social_profile_screen.dart:186`). Seçim nadir yapılan bir ayardır; ekranın
  ana içeriği başarımlardır.
- **Yapılan:**
  - Kart gövdeden çıkarıldı. Yerine **sağ üstte** `PrimaryGroupAppBarAction`
    (`IconButton`, dokunma hedefi ≥ 48 dp, `primaryGroupTitle` tooltip'i).
  - Seçim artık `showPrimaryGroupSelector()` ile açılan alt sayfada yapılıyor;
    aynı tek-seçimli liste, aynı cooldown kilidi ve aynı sunucu-otoriter RPC —
    WP-348 sözleşmesi hiç değişmedi. `PrimaryGroupSelectorCard` bir `embedded`
    bayrağı aldı, alt sayfada dış `Card` kabuğu çizilmiyor.
  - Seçim yokken uyarı **üç yüzeyde**: Profil sekmesi (WP-352, `home_shell.dart`
    — dokunulmadı) · Başarımlar ekranındaki tıklanabilir şerit
    (`PrimaryGroupMissingBanner`) · ayar ikonunun üstündeki rozet. Üçü de tek
    kaynaktan beslenir: `primaryGroupSelectionMissingProvider`.
  - Rozet rengi **WP-358 token'ından** (`warningColorsOn`) gelir; ekran kendi
    kırmızısını tanımlamaz. Kırmızı ağırlıklı temada kaybolma sorunu tekrarlamaz.
  - Şerit ve rozet seçim yapılınca **birlikte** kaybolur; grubu olmayan
    kullanıcıda ve yükleme/hata sırasında **hiç** görünmez (olmayan bir kaybı
    ilan etmeyiz — WP-352 provider sözleşmesi korundu).
- **Neden ayrı dosya:** `SocialProfileScreen` çok sayıda oyunlaştırma/ödül
  provider'ına bağlı; giriş bileşenlerini `primary_group_entry.dart`e almak
  onları yalnız grup provider'larıyla test edilebilir kıldı. Ekranın yapısı
  ayrıca **kaynak düzeyinde** kilitlendi (kart gövdeye geri konursa test düşer).
- **Kanıt:** `flutter analyze` **0 uyarı** · 7 yeni test · `test/features/profile`
  süitinin tamamı (105 iddia) yeşil · **regresyon kapanı kanıtlandı:** rozet
  koşulu etkisizleştirilince test kırmızıya döndü.
- **Bilinçli borç (WP-359'dan devralındı):** `DesktopNavigationPane` rozet
  altyapısı taşımıyor; masaüstünde uyarı yüzeyi ayar ikonunun kendisidir.
- **Veri/Migration etkisi:** Yok. **Geri alma:** tek UI commit'i.
- **Kabul:** gövdede birincil grup bloğu **yok** · giriş sağ üstte tek ikon ·
  seçim yokken rozet + şerit görünür, seçimle **ikisi de** kaybolur · grubu
  olmayan kullanıcıda rozet **0** · başkasının profilinde giriş/şerit **0**.


#### WP-377: Kamp ateşi — gece/gündüz saatleri, gökyüzü kırpması ve halka 🔥
- **Durum:** [x] Kod/test tamam — cihaz kabulü bekliyor. Kaynak: **sahip notu
  2026-07-28** (eski kart WP-360; bu kart onun yerine geçer)
- **SAHİP:** yeni `app/lib/core/time_engine/solar_anchors.dart` ·
  `app/lib/features/classroom/widgets/campfire_layout.dart` ·
  `app/lib/features/classroom/widgets/campfire_scene.dart` ·
  `app/test/core/time_engine/solar_anchors_test.dart` ·
  `app/test/features/campfire/campfire_wp377_{layout,preview}_test.dart` ·
  `app/test/features/campfire_{sky_golden,scene,layout}_test.dart` · goldens

- 🔴 **Gece/gündüz gerçekten bozuktu (sahip "kontrol et" dedi, kanıtlandı).**
  `kDefaultSkyAnchors` yıl boyu **sabitti**: 05:30 · 06:30 · 18:30 · 19:30.
  NOAA gündoğumu denklemiyle İstanbul'a karşı ölçüldü — sapma **±2,5 saat**:
  | tarih | sahne | gerçek | fark |
  |---|---|---|---|
  | 21 Haz | 19:30'da gece | güneş 20:40'ta batıyor | **1s50d erken** |
  | 15 Oca | 06:30'da gündüz | güneş 08:27'de doğuyor | **1s57d erken** |
  | 21 Ara | 18:30'a kadar gündüz | güneş 17:39'da battı | **51d geç** |
- **Çözüm:** `solarSkyAnchors()` — gün sayısından güneş deklinasyonu (Cooper),
  oradan gündoğumu (zenit 90.833°) ve sivil alacakaranlık (96°) yay yarıları.
  Aynı günlerde sapma **±13 dakikaya** düşüyor.
  **Konum izni yok:** eski WP-300 (enlem/boylam) sahip kararıyla iptal edilmişti;
  enlem (39°) ve güneş öğleni (13:05) birer sabittir. Boylamı saat diliminden
  türetmek İstanbul'da ~1 saat hata verirdi (UTC+3 merkezi 45°D, İstanbul 29°D) —
  bilinçle yapılmadı. Kutup enlemlerinde sıra fail-closed korunur.

- **Sahip seçimi (parametrik önizleme üzerinden, `campfire_wp377_preview.png`):**
  - Gökyüzü **üstten 85 px** kırpıldı: yükseklik `360 → 275`. Zemin bandı
    (122.4 px) korunarak `groundYFactor` `0.66 → 0.5549` oldu — yani kısalan tek
    şey gökyüzü; hayvanlar aşağıdan kırpılmıyor.
  - Telefon halkası `1.20 → 1.50`. 8 kişide isimler üst üste biniyordu.
  - **"Ona göre marşmelov çubuğu uzasın" (sahip):** `stickReachFactor` bir
    **orandır**; halka genişleyince hayvan–ateş mesafesi büyür ve sabit oran
    çubuğu ateşten uzaklaştırır. Yeni `campfireStickReach()` oranı halka
    ölçeğine bölerek **mutlak boşluğu** sabitler; `ringScale == 1` (masaüstü)
    hiçbir şeyi değiştirmez.
- **Önizleme neden golden değil:** sahnedeki canlı süre etiketleri `SecondTicker`
  üzerinden duvar saatini okur; 9 hücrelik karede koşumlar arası fark %0.5'lik
  toleransı aşıp önizlemeyi kararsız bir "test" yapıyordu. Dosya artık
  karşılaştırmaz, yalnız **yazar** — bir iddia değil, sahibin bakacağı çıktı.
  Üç ardışık koşumda kararlı.
- **Kanıt:** `flutter analyze` **0 uyarı** · tam süit **1002/1002** yeşil ·
  13 yeni test · `solar_anchors_test.dart` modeli **gerçek güneş saatlerine**
  karşı ölçer ve sabit çıpaların aynı testi geçemediğini ayrıca kayda geçirir ·
  kamp ateşi golden'ları yeni kompozisyonla tazelendi.
- **Kayıt hijyeni:** kompozisyon sayıları artık üç yerde dağınık değil,
  `campfire_layout.dart`teki üç sabitte; testler o sabitleri okur.

#### WP-378: Duyuru sinyalini profil ve ayarlara taşı 🔔
- **Durum:** [x] Kod/test tamam — cihaz kabulü bekliyor. Kaynak: **sahip notu
  2026-07-28**
- **SAHİP:** yeni `app/lib/features/profile/widgets/unread_announcement_dot.dart` ·
  `app/lib/core/navigation/home_shell.dart` ·
  `app/lib/features/profile/profile_screen.dart` ·
  `app/lib/features/profile/settings_screen.dart` ·
  `app/test/features/profile/announcement_signal_wp378_test.dart`

- **Sahip:** "duyurular kısmına bir şey gelirse profil ve ayarlarda da bildirim
  yönlendirmesi olsun, sanırım şu an yok."
- **Kodda doğrulandı — kısmen vardı.** Nokta `settings_screen.dart`teki
  **Duyurular satırında** duruyordu (WP-304). Ama zincirin üstteki iki halkası
  yoktu: Profil sekmesi ve Profil'deki **Ayarlar satırı** hiçbir şey
  göstermiyordu. Yani kullanıcı Ayarlar'ı açmadan yeni duyuruyu fark etmiyordu —
  sahibin tarifi birebir bu.
- **Yapılan:** `_UnreadDot` ortak `UnreadAnnouncementDot`e çıkarıldı ve üç yüzey
  de aynı kaynağı (`unreadAnnouncementCountProvider`) okuyacak biçimde bağlandı.
  Renk `colorScheme.primary` — duyuru bir **uyarı değil**, yeni içerik; uyarı
  token'ıyla karıştırılmadı.
- **Öncelik kuralı korundu (WP-352):** aynı sekmede iki sinyal yarışmaz. Sıra:
  bekleyen ödül **sayısı** > eksik birincil grup **uyarısı** (kayıp) >
  okunmamış duyuru **noktası** (içerik).
- **Kanıt:** `flutter analyze` **0 uyarı** · 8 yeni test · tam süit yeşil ·
  **regresyon kapanı kanıtlandı:** sekmedeki nokta koşulu etkisizleştirilince
  test kırmızıya döndü. Testler ayrıca üç yüzeyin **tek kaynağı** okuduğunu
  kaynak düzeyinde kilitler — biri kendi sayacını türetirse "okundu" yüzeyler
  arasında ayrışır ve nokta hiç sönmez.


---

## PLAN 2 — MAĞAZA HAZIRLIĞI

> 🧾 **WP kartları bu fazlar başlarken açılır** (güncel son numara WP-351;
> yeni kartlar WP-352'den devam eder).
> Sebep: mağaza işlerinin çoğu **ops**, kod değil; SAHİP dosya sınırı ve kabul
> kriteri ancak hesap doğrulaması ve Faz G kararı netleşince yazılabilir.
> Bugünden geçerli iki eski kart: **WP-276** (hesap silme kanıtı → Faz I2) ve
> **WP-277** (staging ops kabul kanıtı).

### Faz G — Kimlik: isim ve logo 🔴 *erken karar, geç uygulama*

Sahip: *"logo ve isim tekrar düşünülmeli, hem TR hem English."* Bu karar **her
mağaza görselini, mağaza kaydını ve MSIX kimliğini** etkiler.

- **Değişebilir:** görünen uygulama adı, logo, mağaza başlığı, uygulama içi marka
- **Değişmesi pahalı:** Android `applicationId` — değişirse **yeni uygulama** olur, mevcut kullanıcılar güncelleme alamaz
- **Değişmesi pahalı:** MSIX `Identity Name` — Partner Center'da rezerve edilen adla **birebir** eşleşmeli, sonradan değişmez

### Faz H — Microsoft Store (önce burası)

Play doğrulaması sürerken buraya çıkmak mantıklı: Windows sürümü zaten üretiliyor
ve Microsoft'un incelemesi genelde daha hızlı.

- **H1.** Partner Center'da uygulama adını rezerve et (Faz G'den sonra)
- **H2.** MSIX kimliğini Store'un verdiği `Identity Name`/`Publisher` ile hizala — şu anki paket kendi imzamızla üretiliyor, Store'a öyle gitmez
- **H3.** Yaş derecelendirme anketi · kategori · gizlilik politikası URL'i
- **H4.** Mağaza görselleri: ekran görüntüleri (TR + EN) · açıklama · tanıtım videosu
- **H5.** Windows cihaz QA'sı (`docs/QA-WINDOWS.md`, `docs/WINDOWS-VM-QA.md`)
- **H6.** İlk gönderim → geri bildirim → düzeltme turu

### Faz I — Google Play

- **I1.** 🔴 **AAB.** Play `.apk` kabul etmiyor. Release hattı sadece APK üretiyor — bundle çıktısı eklenecek
- **I2.** 🔴 **Hesap silme kanıtı.** Akış uygulama içinden **ve** webden erişilebilir olmalı, uçtan uca kanıtlanmalı (istek → 14 gün → kalıcı silme → yetkisiz çağrı reddi → rollback). Kodu var, kanıtı yok
- **I3.** **Gizlilik politikası + Kullanım şartları canlı HTTPS adreste** → **GitHub Pages** (K7). Metinler `docs/legal/` içinde hazır, hiçbir yerde yayınlanmıyor. Data Safety formu bunsuz doldurulamaz
- **I4.** **Data Safety formu** — envanter `docs/play-store/DATA-SAFETY.md`'de satır satır hazır
- **I5.** İçerik derecelendirme anketi + mağaza görselleri (TR + EN)
- **I6.** Kullanıcı içeriği beyanı (raporlama/engelleme/moderasyon) cihaz smoke testi
- **I7.** İmzalama anahtarı yedeği + rollback planı yazılı olarak
- **I8.** Kademeli yayın: %10 → %25 → %50 → %100 (her kademe ≥ 24 saat)

Kapı listesi: [`docs/play-store/PLAY-RELEASE-GATE.md`](docs/play-store/PLAY-RELEASE-GATE.md)

### Faz J — Yayın sonrası

- Çökme/hata takibi (Sentry var), ilk 72 saat gözlem
- Mağaza yorumlarına yanıt akışı — Faz B'deki döngüyle birleşir
- İlk güncelleme turu

---

## PLAN 3 — LANSMAN TURU (Faz K–N) 🚀

> **Kaynak:** `docs/LANSMAN-TARTISMA-NOTU.md` (v54 cihaz bulguları + sahip revizeleri +
> mağaza engelleri + sahip kararları F1–F5/G1–G6/H1–H8) ve
> `docs/RAKIPANALIZI-DEGERLENDIRME.md` (rakip yorum analizinden alınacaklar).
> Sahip emri 2026-07-28: *"bu dediklerin ve bizim konuştuklarımızı planlayalım, hepsini
> WP'ler halinde yaz."*
>
> **Sıra sözleşmesi (sahip kararı H8):** Faz K + L **yayından önce** kapanır.
> Faz M mağaza işidir. Faz N yayından sonradır ve ilk sürümü **geciktirmez**.
>
> **Kart derinliği:** Faz K ve L kartları tam (SAHİP/DOKUNMA/kabul/tuzak).
> Faz M ve N kartları **kısa** tutuldu — repo geleneği: mağaza/ops kartları o faz
> başlarken tam açılır (PLAN 2 notu), yoksa hesap ve mağaza gerçeği netleşmeden
> yazılan kabul kriteri uydurma olur.
>
> 🔴 **Tartışma notundaki bir tespit yanlıştı, burada düzeltiliyor.** Not, sahibin
> gözlemine dayanarak "kullanıcı engelleme diye bir şey yok" (B5) diyordu. Koda
> bakıldı: **var.** `0038_ugc_moderation.sql` (`user_blocks`, `ugc_reports`,
> `block_user`/`unblock_user`/`report_ugc` RPC'leri), `features/safety/**` (engelle
> diyaloğu, engellenenler ekranı, şikâyet sayfası), çağrı yerleri
> `class_chat_card.dart:217,228` ve `social_profile_screen.dart:120,128`, admin
> tarafında `admin_reports_tab.dart`. Sahip bunları **bulamadı** — asıl kusur
> keşfedilebilirlik ve F2 kararına uymayan davranış. WP-389/390 buna göre daraltıldı.

---

### Faz K — v54 cihaz bulguları ve UI borcu *(yayın öncesi, kod)*

#### WP-379: Ayna cihazda Durdur global koşuyu durdurur 📱↔️📱
- **Program/Faz:** PLAN 3 · Faz K (kaynak: tartışma notu A1 + sahip kararı F1)
- **Ajan:** Codex-2
- **Durum:** [~] Kod tamamlandı — cihaz kabulü bekliyor
- **Problem:** Telefondan başlatılan koşu tablette aynalanıyor; **tabletten** Durdur
  denince yalnız tablet duruyor, telefon çalışmaya devam ediyor ve tablet ikinci bir
  oturum açabiliyor. Kök neden `study_providers.dart:1548`: ayna durumunda `stop()`
  sunucuya komut göndermeden `_finish()` çağırıyor; `_finish()` ayna bayrağını da
  temizlediği için cihaz "boşta" sayılıyor. Mimari belge §16.4 doğru davranışı zaten
  tarif ediyor, o yol hiç bağlanmamış.
- **Kapsam dışı:** "Bu cihazda gizle" diye ikinci bir düğme **yok** (sahip kararı F1).
  Presence/lease mimarisi değişmez. Yeni migration yazılmaz.
- **SAHİP dosyalar (yaz):**
  - `app/lib/data/providers/study_providers.dart`
  - `app/lib/data/providers/global_timer_providers.dart`
  - `app/lib/features/classroom/widgets/study_timer_card.dart` (onay diyaloğu)
  - `app/test/data/global_timer_*`, `app/test/data/study_providers_*`
- **DOKUNMA (oku, değiştirme):** `app/android/**/timer/**` (WP-380 sahibi),
  `supabase/migrations/**`, `app/lib/core/navigation/**`
- **Adımlar:**
  - [ ] Ayna durumunda `stop()` → mevcut V2 stop komut yolu (`expected_run_revision`
        dolu) kullanılır; `_finish()` yalnız sunucu onayından sonra çağrılır.
  - [ ] Durdur'dan önce onay: *"Bu, diğer cihazdaki sayacı da durduracak."* İptal
        edilirse hiçbir yerel durum değişmez.
  - [ ] Origin cihaz durunca gerekçeyi gösterir: *"Diğer cihazda 21:14'te durduruldu."*
  - [ ] Sunucu reddederse (revision uyuşmazlığı) ayna cihaz **durmuş gibi yapmaz**;
        hata gösterir ve aynalamaya devam eder.
  - [ ] İkinci oturum: ayna cihaz stop komutu onaylanmadan yeni koşu başlatamaz.
- **Veri/Migration etkisi:** Yok. Mevcut `global_timer_commands` stop yolu kullanılır.
  Geri alma = commit revert.
- **Ortam/Deploy:** local. Sunucu değişmediği için staging/production kapısı açılmaz.
- **RLS/Güvenlik:** Yeni yüzey yok; stop komutu zaten `auth.uid()` doğruluyor.
- **Edge-case'ler:** ağ yokken ayna Durdur (kuyruğa alınır, kullanıcıya "bağlanınca
  durdurulacak" denir mi yoksa reddedilir mi — uygulayıcı karar verir, kartta gerekçesini
  yazar) · origin cihaz kapalıyken · her iki cihazda aynı anda Durdur · gün sınırını aşan koşu.
- **Kabul (ölçülebilir):**
  - İki cihaz: aynadan Durdur → origin cihaz **≤ 5 sn** içinde durur ve gerekçe metnini gösterir.
  - Aynadan Durdur sonrası ayna cihaz **yeni oturum açamaz**; sunucuda tek `finalize` üretilir
    (çift XP yok).
  - Onay diyaloğunda İptal → hiçbir cihazda durum değişmez.
  - 🔴 **İki uçlu sözleşme testi zorunlu:** istemcinin gönderdiği stop zarfı ile sunucunun
    beklediği şema tek testte karşılaştırılır. (WP-373 dersi: tek uçlu testler senkronun
    yıllarca ölü kalmasını gizledi.)
- **Tuzaklar:** `_finish()`'in ayna bayrağını temizlemesi bu hatanın ikinci yarısı —
  yalnız komut göndermek yetmez. `origin` sözlüğü sunucu tarafında
  `('app','widget','notification','recovery')`; ham `dart_app` göndermek sessiz ret üretir.
- **Model önerisi:** 🔴 Opus

#### WP-380: Widget ve bildirimde boş sayaç biçimi ⏱️
- **Program/Faz:** PLAN 3 · Faz K (kaynak: A8)
- **Ajan:** Codex-2 · **Durum:** [~] Kod/test tamamlandı · cihaz kabulü bekliyor
- **Problem:** Boştayken statik `"00:00:00"` yazılıyor, koşarken Android `Chronometer`
  devreye girip bir saatin altında `MM:SS` basıyor → başlangıçta `00:00:00` → `00:01`
  sıçraması. Sahip: "çirkin, doğrudan `00:00` olsun."
- **Kapsam dışı:** **Uygulama içi sayaç `HH:MM:SS` kalır** (sahip açıkça söyledi).
  Bir saat üstü `H:MM:SS` davranışı da değişmez.
- **SAHİP dosyalar:** `app/android/app/src/main/kotlin/**/widgets/StudyWidgetProviders.kt`,
  `app/android/app/src/main/kotlin/**/timer/StudyTimerService.kt`, ilgili Kotlin testi
- **DOKUNMA:** `app/lib/**` (uygulama içi sayaç bu koddan beslenmiyor), `WP-379` dosyaları
- **Adımlar:**
  - [x] `StudyWidgetProviders.kt:95` ve `StudyTimerService.kt:471` boş metni `"00:00"` yap.
  - [x] Duraklatılmış/geri yüklenmiş durumlarda da aynı biçim kullanılıyor mu, tara.
- **Otomatik kanıt:** `:app:testLocalDebugUnitTest` — `IdleTimerDisplayFormatTest` 1/1 yeşil (2026-07-28). `flutter analyze` paylaşılan Flutter derleme kuyruğunda bitiş çıktısı alınamadı; bu WP Dart dosyasına dokunmaz.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** local.
- **Kabul:** Widget ve bildirim boştayken `00:00` gösterir · başlat → ilk saniyede
  sıçrama yok · 1 saati geçince `1:00:00` · uygulama içi sayaç `00:00:00` olarak kalır
  (regresyon testi).
- **Tuzaklar:** İki dosyada iki ayrı literal var; biri unutulursa widget ile bildirim
  birbirinden farklı davranır.
- **Model önerisi:** 🔵 Sonnet

#### WP-381: Tanıtım turu onarımı ve kart düzenleme ipucu 🎈
- **Program/Faz:** PLAN 3 · Faz K (kaynak: A6, B1, H2)
- **Ajan:** Codex-4 · **Durum:** [~] Geliştiriliyor
- **Problem:** (a) Ana ekran turunda "kartları düzenle" adımında **Skip yazısı ile edit
  butonu üst üste** geliyor; aynı çakışma gruplar turunda da var. (b) Ekran tanıtan
  çapasız adımlar ekranın ortasına düşüyor, karartılmış üst şerit garip duruyor.
  (c) Sayaç yanıltıcı: "1 of 2" → "2 of 2" → kamp ateşinde "1 of 1" diye yeniden başlıyor.
  (d) Profil turu tamamen gereksiz. (e) İstatistiklerde today/week adımı gereksiz.
  (f) Kart düzenleme moduna ilk girişte hiçbir yönlendirme yok.
- **Kapsam dışı:** **Tur metinleri sahibe ait** — WP yalnız yerleri, çapaları ve sırayı
  hazırlar, metin yer tutucu kalır. `settings_screen.dart`'a **girilmez** (WP-383 sahibi).
- **SAHİP dosyalar:** `app/lib/features/tours/**`, `app/lib/core/tour/**`,
  `app/lib/features/onboarding/**` (son adıma SSS yönlendirmesi — F5),
  `app/lib/features/home/**` içinde yalnız kart düzenleme ipucu balonu,
  `app/test/features/tour*`, `app/test/features/onboarding*`
- **DOKUNMA:** `app/lib/features/profile/settings_screen.dart`, `app/lib/features/stats/**`,
  `app/lib/l10n/**` generated
- **Adımlar:**
  - [ ] Skip/edit çakışması: Skip'i çakışmayan bir konuma al veya adım süresince hedef
        düğmeyi maskeleme kuralını değiştir. Her iki turda da düzelt.
  - [ ] Çapasız adımlar **o sekmenin alt bar ikonuna** çapalanır (H2 kararı); sahte
        karartılmış şerit kaldırılır.
  - [ ] Gruplar bölgesi **tek dizi** olur; kamp ateşi adımı silinir → sayaç "of 2".
  - [ ] Profil turu silinir. İstatistiklerdeki today/week adımı silinir.
  - [ ] Onboarding son adımına **SSS'ye git** yönlendirmesi (WP-388'e bağımlı;
        WP-388 yoksa yer tutulur, bağlantı sonradan bağlanır).
  - [ ] Kart düzenleme moduna **ilk girişte tek ipucu balonu** (H2: tam tur değil);
        kalıcı bayrakla bir kez gösterilir.
- **Veri/Migration etkisi:** Yok (SharedPreferences bayrağı).
- **Kabul:** Ana ekran turunda hiçbir adımda iki tıklanabilir öğe üst üste gelmez
  (widget testiyle geometrik çakışma kontrolü) · adım sayacı tek dizide monoton
  ilerler ve toplam sayı gerçek adım sayısına eşittir · profil turu hiçbir yerden
  tetiklenmez · kart düzenleme ipucu ikinci girişte çıkmaz.
- **Tuzaklar:** Tur adımı silmek sayaç toplamını elle güncellemeyi gerektiriyorsa,
  toplam **türetilmiş** olmalı; sabit sayı bırakılırsa bir sonraki değişiklikte aynı
  hata döner. Kabul kriteri bunu test eder.
- **Model önerisi:** 🟣 Pro

#### WP-382: Kamp ateşi kompozisyon revizesi 🔥
- **Program/Faz:** PLAN 3 · Faz K (kaynak: A3 + sahip onayı A3-son)
- **Ajan:** Codex-5 · **Durum:** [x] Tamamlandı (`49ca29f`)
- **Problem:** Kırpma beğenildi, iki düzeltme kaldı: (1) ateşin kendisi **biraz aşağı**
  inecek, (2) aynı taraftaki alt/üst hayvanın **dikey arası açılacak** — şu an alttakinin
  ismi üsttekinin üstüne biniyor.
- **Kapsam dışı:** Gece/gündüz saatleri (A2, sahip henüz test etmedi), hayvan varlıkları,
  halka geometrisi.
- **SAHİP dosyalar:** `app/lib/features/classroom/widgets/campfire_scene.dart`,
  `app/test/features/classroom/campfire_*`
- **DOKUNMA:** `app/lib/core/theme/**`, WP-379/381 dosyaları
- **Adımlar:**
  - [x] 🔴 **Önce önizleme** (`gorsel-is-once-onizleme-sonra-kod`): ateş kaydırması ve
        dikey ayrım için 3–4 aday, etiketli tek PNG ızgarası, `SendUserFile` ile sahibe.
  - [x] Sahip `+45 px` ateş ve `%25` dikey ayrım seçti → adlandırılmış sabit olarak koda girildi ve **teste bağlandı**.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** local.
- **Kabul:** Sahibin seçtiği sayılar adlandırılmış sabitler olarak kodda · en kalabalık
  senaryoda (dolu grup) aynı taraftaki iki isim etiketi **çakışmaz** (geometrik test) ·
  golden üretiliyorsa göze bakılır.
- **Tuzaklar:** Önizleme karesinde gömülü font yüklenmezse etiketler kutu çıkar;
  `RepaintBoundary` zemini yakalamaz → `ColoredBox` ile sar; canlı süre etiketi varsa
  `matchesGoldenFile` kullanma, yalnız yaz.
- **Model önerisi:** 🟣 Pro

#### WP-383: Ayarlar bilgi mimarisi, tanıtım sıfırlama ve istatistik delta düğmesi 🧭
- **Program/Faz:** PLAN 3 · Faz K (kaynak: B4, B7, F5)
- **Ajan:** Codex-4 · **Durum:** [~] Kod/test tamamlandı — cihaz kabulü bekliyor
- **Problem:** (a) Ayarlar sırası sahibin istediği gibi değil: en üstte **Görünüm**,
  altında **Bildirimler**, hesap işleri **daha aşağıda**, **Hakkında + Legal en altta**.
  (b) "Tanıtım turlarını sıfırla" yalnız ekran turlarını siliyor; ilk açılış tanıtımı
  ayrı bayrakta (`onboarding.completed_v1.<userId>`) olduğu için sahip **sil-yükle**
  yapmak zorunda kalıyor. `OnboardingNotifier.reset()` zaten yazılmış, çağıran yok.
  (c) İstatistiklerde tarih aralığı düğmelerinin sağındaki değişim/delta düğmesi
  neredeyse tek bir şeyi etkiliyor ve varsayılanı kapalı → kaldırılacak.
- **Kapsam dışı:** Ayarlar içindeki hiçbir ekranın **içeriği** değişmez, yalnız sıra.
  SSS satırı bu WP'de eklenmez (WP-388 ekler).
- **SAHİP dosyalar:** `app/lib/features/profile/settings_screen.dart`,
  `app/lib/features/stats/stats_screen.dart` (+ delta düğmesinin widget'ı),
  `app/test/features/profile/settings_*`, `app/test/features/stats/*`
- **DOKUNMA:** `app/lib/features/tours/**`, `app/lib/features/onboarding/**`
  (WP-381 sahibi — buradan yalnız `reset()` **çağrılır**, dosyaları değiştirilmez)
- **Adımlar:**
  - [x] Ayarlar bölümleri yeniden sıralanır; sıra **testle kilitlenir** (bir sonraki
        eklemede sessizce bozulmasın).
  - [x] Sıfırlama düğmesi `TourController.resetAll()` **ve** `OnboardingNotifier.reset()`
        çağırır; metni "tanıtımları sıfırla" olarak netleşir.
  - [x] Delta düğmesi ve yalnız ona bağlı ölü kod kaldırılır.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** local.
- **Kabul:** Ayarlar bölüm sırası testte sabit · sıfırlama sonrası **hem** ekran turları
  **hem** ilk açılış tanıtımı yeniden çıkar (sil-yükle gerekmez, sahip cihazda doğrular) ·
  istatistik ekranında delta düğmesi yok, kalan düğmeler aynı hizada.
- **Tuzaklar:** Delta düğmesine bağlı state başka yerde okunuyorsa ölü provider kalır;
  `analyze` bunu yakalamaz, elle taranmalı.
- **Model önerisi:** 🔵 Sonnet

#### WP-384: Özel tarih aralığında sürüklenebilir takvim uçları 📅
- **Program/Faz:** PLAN 3 · Faz K (kaynak: B8 + H2 kararı "yapılacak")
- **Ajan:** Codex-4 · **Durum:** [x] Tamamlandı (`fc9af60`)
- **Problem:** Custom aralık seçilince takvim açılıyor; iki uç kahverengi, aradaki günler
  mavi. Tarih şu an yalnız sağ üstteki edit düğmesinden giriliyor. Sahip **uçtaki işareti
  tutup sürükleyerek** aralığı ayarlamak istiyor.
- **Kapsam dışı:** Takvimin görsel dili, edit düğmesinin kaldırılması (ikisi bir arada durur).
- **SAHİP dosyalar:** `app/lib/features/stats/widgets/**` içindeki aralık seçici,
  `app/test/features/stats/*`
- **DOKUNMA:** `app/lib/features/stats/stats_screen.dart` (WP-383 sahibi) → **WP-383'ten
  sonra başlar**
- **Adımlar:**
  - [x] Uçlara sürükleme hedefi (dokunma alanı ≥ 44 px) eklendi.
  - [x] Sürükleme sırasında canlı önizleme; bırakınca aralık uygulanır.
  - [x] Uçlar geçilirse (başlangıç > bitiş) uçlar yer değiştirir, hata verilmez.
- **Veri/Migration etkisi:** Yok.
- **Kabul:** Uç sürüklenince aralık **bırakma anında** uygulanır · uçlar takasında çökme yok ·
  gelecek tarih sınırı korunur · klavye/erişilebilirlik yolu (edit düğmesi) çalışmaya devam eder.
- **Tuzaklar:** Takvim kaydırma jesti ile sürükleme jesti çakışır; hangi jestin kazandığı
  açıkça çözülmeli yoksa takvim kaydırılamaz hale gelir.
- **Model önerisi:** 🟣 Pro

#### WP-385: Başarım açıklamaları 🏅
- **Program/Faz:** PLAN 3 · Faz K (kaynak: B3, D9; metinler H1-son.5 gereği bende)
- **Ajan:** Codex-6 · **Durum:** [x] Kod/test tamamlandı · commit `ce7212f`
- **Problem:** Bazı başarımlarda nasıl kazanıldığı yazmıyor; kullanıcı ne yapacağını
  bilmiyor. Sahip metni ben yazacağım, sahip düzeltecek.
- **Kapsam dışı:** Başarım koşullarının **kendisi** değişmez; yalnız açıklama metni ve
  ilerleme ifadesi eklenir.
- **SAHİP dosyalar:** başarım katalog yüzeyi (`app/lib/features/profile/widgets/achievement_showcase.dart`
  — kod okunarak netleşti), `app/lib/l10n/app_tr.arb` + `app_en.arb`,
  `app/test/core/stats/achievement_*`
- **DOKUNMA:** `app/lib/core/stats/achievement_ledger_engine.dart` kazanım mantığı,
  `supabase/migrations/**`
- **Adımlar:**
  - [ ] Her başarım için tek cümlelik koşul metni (TR + EN), sayısal eşik dahil.
  - [ ] Metin ile **gerçek eşik** arasında sözleşme testi: katalogdaki eşik değişirse
        metin güncellenmediyse CI kırmızı.
- **Veri/Migration etkisi:** Yok (l10n).
- **Kabul:** Açıklaması olmayan başarım kalmaz (test sayar) · TR/EN eksik anahtar yok ·
  eşik-metin sözleşme testi yeşil.
- **Kanıt:** `achievement_catalog_contract_test.dart` + `achievement_showcase_test.dart` **16/16** yeşil ·
  `flutter analyze` 0 bulgu.
- **Tuzaklar:** l10n generated dosyaları sıcak yüzey — bu WP açıkken başka WP arb'ye girmemeli.
- **Model önerisi:** 🔵 Sonnet

#### WP-386: Sürüm notu ayrımı ve sözleşme testi 📝
- **Program/Faz:** PLAN 3 · Faz K (kaynak: B6 + H2 kararı)
- **Ajan:** Codex-6 · **Durum:** [~] Kod tamamlandı — otomatik test geçiyor
- **Problem:** Güncelleme bildiriminde kullanıcıya `migration` gibi teknik satırlar
  sızıyor. Kullanıcının gördüğü metin tamamen kullanıcı dilinde olmalı, iç değişiklikler
  ayrı dosyada kalmalı.
- **Kapsam dışı:** Sürüm çıkarma hattı, tag politikası, güncelleyici akışı.
- **SAHİP dosyalar:** sürüm notu kaynağı (`app/lib/features/updater/release_notes_*`
  ve beslediği veri dosyası), `tooling/release/` içinde yeni sözleşme testi
- **DOKUNMA:** `tooling/release/deploy-contract.json`, `guard.tests.ps1`,
  `release-preflight.tests.ps1` (sürüm kapısı — bu WP'nin işi değil)
- **Adımlar:**
  - [x] Kullanıcıya giden notlar ile teknik günlük iki ayrı kaynağa ayrılır.
  - [x] Sözleşme testi: kullanıcı metninde `migration`, `WP-`, `RPC`, `SQL`, `00NN`
        gibi kelimeler geçerse **CI kırmızı**.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** local + CI.
- **Kabul:** Yasak kelime içeren bir taslak eklendiğinde test kırmızı düşer (negatif test
  zorunlu) · v54 notu yeni biçimde yeniden yazılır ve yeşil geçer.
- **Tuzaklar:** Testin yalnız yeşil tarafını yazmak işe yaramaz — kırmızıya düştüğü
  kanıtlanmalı.
- **Kanıt:** Release-notes contract yeşil + yasak kelimeli negatif taslak kırmızı ·
  `flutter analyze` 0 bulgu · `release_notes_test.dart` 7/7 yeşil · tam paket
  eşzamanlı Flutter derleme kilidi nedeniyle tamamlanamadı.
- **Model önerisi:** 🔵 Sonnet

---

### Faz L — Moderasyon ve destek *(Play şartı, yayın öncesi)*

> Bu fazın dört kartı `supabase/migrations/**` sıcak yüzeyine giriyor. **Migration
> numaraları peşin ayrıldı ve kartlar bu sırayla çalışır:** WP-387 → `0090`,
> WP-388 → `0091`, WP-389 → `0092`, WP-391 → `0093`. Aynı anda iki migration WP'si açılmaz.

#### WP-387: Tek destek kutusu — tür alanı ve admin bildirimi 📬
- **Program/Faz:** PLAN 3 · Faz L (kaynak: A4, F4, C1)
- **Ajan:** Codex · **Durum:** [~] Kod/test tamamlandı — staging + cihaz kabulü bekliyor
- **Problem:** Üç ihtiyaç aynı yere düşüyor: geri bildirim (var), SSS'de olmayan soru
  (gelecek), kullanıcı şikâyeti (var ama ayrı tabloda). Ayrıca **yeni geri bildirim
  gelince admin'e bildirim gitmiyor** — yönetici panele girmeden haberi olmuyor.
- **Kapsam dışı:** SSS ekranı (WP-388), şikâyet giriş noktaları (WP-390), admin panelin
  masaüstü yerleşimi (Faz N).
- **SAHİP dosyalar:**
  - `supabase/migrations/0090_support_inbox.sql` (yeni)
  - `supabase/tests/0NN_support_inbox.test.sql` (yeni)
  - `app/lib/features/admin/tabs/admin_moderation_tab.dart` + destek/rapor listesi
  - geri bildirim repo/provider'ları
- **DOKUNMA:** `app/lib/features/safety/**` (WP-389/390), `0091+` migration'ları
- **Adımlar:**
  - [x] `feedback_tickets`'a **tür alanı** (`feedback | question | report`) eklenir;
        mevcut satırlar `feedback` olarak backfill edilir.
  - [x] Mevcut `ugc_reports` ile ilişki kurulur (rapor bileti kutuda görünür) —
        tablo **birleştirilmez**, çift kayıt riski yerine referans verilir.
  - [x] Yeni bilet düşünce **admin'e push** üreten tetikleyici (mevcut
        `notification_outbox` yolu kullanılır, yeni taşıma yazılmaz).
  - [x] Admin panelinde tek liste + tür filtresi.
- **Veri/Migration etkisi:** `0090` — kolon ekleme + backfill + tetikleyici.
  **Geri alma:** tetikleyiciyi düşür, kolon `not null` değilse bırakılabilir; ileri
  migration ile geri alınır.
- **Ortam/Deploy:** local → staging → **production ayrı GO** (Faz M'de).
- **RLS/Güvenlik:** Kullanıcı yalnız kendi biletini görür; admin okuması
  `is_super_admin()` üzerinden. Tür alanı istemciden geliyorsa **sunucuda doğrulanır**.
- **Edge-case'ler:** aynı kişinin arka arkaya bilet açması (hız sınırı), silinen
  kullanıcıya ait bilet, admin'in kendi biletini açması.
- **Kabul:** Yeni bilet → admin cihazına bildirim **≤ 60 sn** · üç tür de tek listede
  filtreleniyor · pgTAP: yetkisiz kullanıcı başkasının biletini okuyamaz · mevcut
  biletler kayıpsız `feedback` olarak görünür.
- **Tuzaklar:** Bildirim tetikleyicisi `SECURITY DEFINER` yolundan çıkmalı; RLS altında
  çalışan tetikleyici sessizce hiç bildirim üretmez.
- **Kanıt:** Local `0090` reset + 20 SQL dosyasında **291 pgTAP PASS** · hedefli
  `flutter analyze` temiz · 16 Flutter test yeşil. **Kodda doğrulandı;
  staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🔴 Opus

#### WP-388: SSS ekranı — sunucudan beslenen, giriş öncesi erişilebilir ❓
- **Program/Faz:** PLAN 3 · Faz L (kaynak: B2, F3, D listesi)
- **Ajan:** Codex · **Durum:** [~] Kod/test tamamlandı — cihaz kabulü bekliyor
- **Problem:** Ayarlar'da yalnız "bize yaz" var. Sahip hazır soru-cevap istiyor;
  kullanıcı sormadan cevabı bulsun. İçerik **sunucudan** gelmeli ki sürüm çıkarmadan
  düzeltilebilsin (sahip kararı F3).
- **Kapsam dışı:** Web sitesi **yok** — ekran uygulamanın içinde. Soru→SSS terfi akışı
  admin tarafında WP-387'nin listesine yaslanır.
- **SAHİP dosyalar:**
  - `supabase/migrations/0091_faq.sql` (yeni) + pgTAP
  - `app/lib/features/support/**` (yeni dizin)
  - `app/lib/features/profile/settings_screen.dart` içinde **yalnız** SSS satırı
    (WP-383 kabulünden sonra)
  - `app/lib/l10n/app_tr.arb`, `app_en.arb`
- **DOKUNMA:** `0090`/`0092` migration'ları, `features/safety/**`
- **Adımlar:**
  - [x] `faq_entries` tablosu (soru, cevap, dil, sıra, yayın bayrağı); **anon okuma**
        açık (giriş yapmadan erişim şartı), yazma yalnız admin.
  - [x] SSS ekranı + arama; **gömülü yedek metin** (ağ yoksa uygulamayla gelen kopya).
  - [x] Giriş ekranında SSS bağlantısı ("giremiyorum" en çok gereken madde).
  - [x] "Sorum burada yok" → soru gönderme; **hız sınırı** (F3 şartı) sunucuda.
  - [x] Başlangıç içeriği: tartışma notu **D listesi** (widget nasıl eklenir · bildirimden
        kontrol · pil optimizasyonu · çoklu cihaz ne yapar/yapmaz · birincil grup · dürtme ·
        seri kuralları · XP · başarımlar · grup seni ne kadar görüyor) + rakip analizinden
        üç madde (gün ne zaman biter · internetsiz ne olur · elle eklenen süre sayılır mı).
- **Veri/Migration etkisi:** `0091` — yeni tablo + RLS + anon select grant.
  **Geri alma:** tablo düşürülür, istemci gömülü yedeğe düşer.
- **RLS/Güvenlik:** 🔴 `anon` **yalnız yayınlanmış satırları** okur. Taslak cevaplar
  sızmamalı. Soru gönderme anon'a **kapalı** (spam kapısı) — giriş isteyecek.
- **Edge-case'ler:** ağ yok · dil eksik (TR yoksa EN'e düş) · çok uzun cevap · hız
  sınırına takılan kullanıcıya net mesaj.
- **Kabul:** Uçak modunda SSS **boş ekran göstermez** · giriş yapmadan açılır · TR+EN
  dolu · pgTAP: anon yayınlanmamış satırı okuyamaz · aynı kullanıcı N dakikada M'den
  fazla soru gönderemez (test).
- **Tuzaklar:** Anon grant'i geniş yazmak tüm tabloyu açar. Gömülü yedek metnin
  sunucudakiyle **ayrışması** kaçınılmaz — yedek "son çare" olarak işaretlenmeli.
- **Kanıt:** Local `0091` ile 21 SQL dosyasında **297 pgTAP PASS** · hedefli SSS widget
  testi yeşil. **Staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🔴 Opus

#### WP-389: Engellemeyi F2 kararına uydur 🚫
- **Program/Faz:** PLAN 3 · Faz L (kaynak: B5/C1 + sahip kararı F2)
- **Ajan:** Codex · **Durum:** [~] Kod/test tamamlandı — cihaz kabulü bekliyor
- **Problem:** 🔴 **Engelleme yok değil, yanlış davranıyor ve bulunamıyor.** Mevcut:
  `0038_ugc_moderation.sql` (`user_blocks` + `block_user`/`unblock_user`),
  `features/safety/blocked_users_screen.dart`, `block_user_action.dart`; çağrı yerleri
  yalnız sohbet (`class_chat_card.dart:228`) ve sosyal profil
  (`social_profile_screen.dart:128`). Sahip hiçbirini bulamadı.
  F2 kararına göre üç sapma var:
  1. **Kamp ateşi engellenen kişiyi tamamen siliyor** (`campfire_scene.dart:111-116`
     `where !blocked.contains`). Karar: *kimlik gizlenir, sayı gizlenmez* → isimsiz nötr
     siluet kalmalı.
  2. **Sıralamada** "Engellenen kullanıcı" satırı yok.
  3. **Dürtme engellemeyi kontrol etmiyor** (`supabase_nudge_repository.dart` içinde
     blok kontrolü yok) → iki yönlü kesme eksik.
- **Kapsam dışı:** Şikâyet (WP-390), grup yasağı (WP-391). Engelleme **üyeliği kesmez**
  (F2 İstisna 2). Grup yöneticisi ve admin **muaf** (F2 İstisna 1).
- **SAHİP dosyalar:**
  - `supabase/migrations/0092_block_enforcement.sql` (yeni) + pgTAP
  - `app/lib/features/classroom/widgets/campfire_scene.dart` — ⚠️ WP-382 ile aynı dosya
  - sıralama/liderlik yüzeyi (`features/stats/widgets/class_stats_view.dart` çevresi)
  - `app/lib/data/repositories/supabase/supabase_nudge_repository.dart`
  - `app/lib/features/safety/**`
- **DOKUNMA:** `0090`/`0091`/`0093`
- **Adımlar:**
  - [x] Dürtme RPC'si engellemeyi **sunucuda** kontrol eder (iki yönlü).
  - [x] Kamp ateşinde engellenen kişi silinmez; isimsiz siluet, tıklanamaz, dürtülemez.
  - [x] Sıralamada "Engellenen kullanıcı" satırı; sayılar değişmez.
  - [x] Grup yöneticisi ve admin muafiyeti sunucuda uygulanır.
  - [x] Engelleme girişi **keşfedilebilir** olur: üye listesinde ve kamp ateşi detay
        sayfasında da menü.
- **Veri/Migration etkisi:** `0092` — dürtme ve ilgili RPC'lere blok kontrolü.
  **Geri alma:** ileri migration ile kontrolü kaldır.
- **RLS/Güvenlik:** 🔴 İstemcide gizlemek yetmez; dürtme/etkileşim **sunucuda** reddedilmeli.
- **Edge-case'ler:** karşılıklı engelleme · engellenen kişi grup yöneticisiyse ·
  engelleyip aynı gruba sonradan katılma · engel kaldırılınca eski durumun geri gelmesi.
- **Kabul:** Engellenen kişi dürtme gönderemez ve alamaz (pgTAP, iki yön) · kamp ateşinde
  siluet olarak **görünür**, üye sayısı değişmez · sıralamada satır durur, grup toplamı
  aynı kalır · yönetici engellenen üyeyi hâlâ görür ve çıkarabilir · engelleme menüsü
  en az üç yüzeyden erişilebilir.
- **Tuzaklar:** ⚠️ **WP-382 ile aynı dosya** (`campfire_scene.dart`) → **WP-382 kabulünden
  sonra başlar.** Grup toplamlarını istemcide filtrelemek cihazdan cihaza farklı rakam üretir.
- **Kanıt:** Local `0092` reset + 22 SQL dosyasında **307 pgTAP PASS** · hedefli Flutter
  analyze temiz · kamp ateşi widget testi yeşil. **Staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🔴 Opus

#### WP-390: Şikâyet akışını tamamla ve görünür kıl 🚩
- **Program/Faz:** PLAN 3 · Faz L (kaynak: C1, F2 "eksik yarı")
- **Ajan:** Codex-5 · **Durum:** [~] Kod/test tamamlandı — staging + cihaz smoke kabulü bekliyor
- **Problem:** Şikâyet altyapısı **var** (`ugc_reports`, `report_ugc` RPC,
  `features/safety/report_sheet.dart`, `admin_reports_tab.dart`) ama yalnız sohbet ve
  sosyal profilden erişiliyor; grup ve grup adı şikâyeti yok, kullanıcı şikâyetinin
  akıbetini görmüyor, admin'e bildirim WP-387'ye kadar gitmiyordu.
- **Kapsam dışı:** Otomatik moderasyon, içerik tarama (C9 ayrı WP).
- **SAHİP dosyalar:** `app/lib/features/safety/report_sheet.dart`,
  `app/lib/features/admin/tabs/admin_reports_tab.dart`, ek giriş noktaları
- **DOKUNMA:** `supabase/migrations/**` (şema değişikliği gerekiyorsa WP-387'nin
  `0090`'ına eklenir, yeni numara alınmaz), `features/classroom/widgets/campfire_scene.dart`
- **Adımlar:**
  - [x] Şikâyet girişi: kullanıcı · grup · grup adı/açıklaması · sohbet mesajı.
  - [x] Şikâyet sonrası kullanıcıya **ne olacağı** yazılır ("Raporu inceleyeceğiz.").
  - [x] Admin panelinde durum değişimi `admin_audit_log`'a düşer (server-authoritative RPC).
  - [ ] Play'in istediği kanıt için akış ekran görüntüleriyle belgelenir (cihaz smoke kabulünde).
- **Veri/Migration etkisi:** Tercihen yok.
- **Kabul:** Dört yüzeyden de şikâyet açılabilir · şikâyet admin listesinde ≤ 60 sn
  görünür · durum değişimi denetim kaydına düşer · UGC beyanı için cihaz smoke testi
  belgelenir (I6).
- **Tuzaklar:** Şikâyet kutusunu serbest metne açmak kişisel veri toplar; alan sınırlı
  ve kategori seçmeli olmalı.
- **Model önerisi:** 🟣 Pro

#### WP-391: Grup yasağı, yasak listesi ve davet kodu sıfırlama 🔒
- **Program/Faz:** PLAN 3 · Faz L (kaynak: G2, G3, G5-son)
- **Ajan:** Codex · **Durum:** [~] Kod/test tamamlandı — cihaz kabulü bekliyor
- **Problem:** Grup yöneticisi birini çıkarabiliyor ama **geri gelmesini engelleyemiyor**;
  sızan davet kodunun da çaresi yok. Sahip kararı G5-son: **yasak koşulsuzdur**, yalnız
  grup yöneticisi koyar/kaldırır; davet linki veya onay akışı yasağı delmez.
- **Kapsam dışı:** Davet linki (Faz N) · yeni üye onay akışı (Faz N) · uygulama geneli
  yasak (bu grup düzeyinde bir yetki).
- **SAHİP dosyalar:**
  - `supabase/migrations/0093_group_bans.sql` (yeni) + pgTAP
  - grup yönetim ekranları (`features/classroom/**` içindeki üye yönetimi)
  - grup repo/provider'ları
- **DOKUNMA:** `0090`–`0092`, `features/safety/**`
- **Adımlar:**
  - [x] `group_bans` tablosu + **katılma RPC'sinde sunucu tarafı kontrol** (istemcide
        düğme gizlemek yetmez — G2 şartı).
  - [x] Üye yönetiminde çıkarma ve yasaklama ayrı eylemler (kick ≠ ban).
  - [x] Grup ayarlarında **yasak listesi + kaldırma** (G2 şartı: öfkeyle verilen yasak
        ertesi gün geri alınmak istenir).
  - [x] **Davet kodu sıfırlama** — eski kod geçersizleşir; 🔴 içerideki kimseyi atmaz,
        arayüzde bu açıkça yazılır (G3).
- **Veri/Migration etkisi:** `0093` — yeni tablo + katılma RPC değişikliği.
  **Geri alma:** kontrolü kaldıran ileri migration; tablo veri kaybı olmadan kalır.
- **RLS/Güvenlik:** Yasak koyma/kaldırma yalnız grup yöneticisi (`SECURITY DEFINER`
  içinde doğrulanır). Yasaklı kullanıcı yasak listesini göremez.
- **Edge-case'ler:** yasaklı kişi geçerli davet koduyla dener · yönetici kendini
  yasaklamaya çalışır · son yönetici yasaklanırsa grup sahipsiz kalır · yasaklı kişi
  gruptayken yasaklanırsa aynı işlemde çıkarılır.
- **Kabul:** pgTAP: yasaklı kullanıcı geçerli kodla **katılamaz** · yasak kaldırılınca
  katılabilir · yönetici olmayan yasak koyamaz · kod sıfırlandığında eski kod reddedilir,
  mevcut üyeler etkilenmez · yönetici kendini yasaklayamaz.
- **Tuzaklar:** Yasağı yalnız istemcide uygulamak (düğme gizleme) G2'nin açık ihlali.
  Kod sıfırlamayı yasağın alternatifi gibi sunmak sahibin kararına aykırı.
- **Model önerisi:** 🔴 Opus
- **Kanıt:** `tooling/supabase/local.ps1 test` → 320 pgTAP PASS
  (`.artifacts/deploy-evidence/20260728T125452790Z-local-test`) ·
  `flutter test test/data/group_repository_test.dart --dart-define-from-file=env.json` → 23 PASS ·
  hedefli `flutter analyze` → 0 sorun. **Cihazda doğrulanmalı:** yasakla/çıkar ayrımı,
  yasak listesinden kaldırma ve davet kodu yenileme akışı.

#### WP-392: Görünen ad ve grup adı süzgeci 🧼
- **Program/Faz:** PLAN 3 · Faz L (kaynak: C9 + H2 kararı "eklenir")
- **Ajan:** Codex · **Durum:** [~] Kod/test tamamlandı — cihaz kabulü bekliyor
- **Problem:** Görünen ad ve grup adı herkese açık; küfür/istismar süzgeci yok. Tek
  ekran görüntüsü mağaza şikâyetine dönebilir.
- **Kapsam dışı:** Sohbet içeriği taraması, otomatik ceza, yapay zekâ moderasyonu.
- **SAHİP dosyalar:** süzgeç fonksiyonu (mevcut ad güncelleme RPC'sinin içine),
  `supabase/tests/**`, ilgili istemci hata mesajı + l10n
- **DOKUNMA:** `0090`–`0093` (bu WP kendi migration numarasını Faz L sonunda alır)
- **Adımlar:**
  - [x] TR + EN yasaklı kelime listesi (sunucuda, veri olarak — kod değişmeden güncellenir).
  - [x] Ad değiştirme ve grup kurma/yeniden adlandırma yollarında **sunucuda** reddedilir.
  - [x] Kullanıcıya neden reddedildiği anlaşılır biçimde söylenir (listeyi sızdırmadan).
- **Veri/Migration etkisi:** Yeni migration (numara Faz L sırasında). **Geri alma:** kontrolü kaldır.
- **RLS/Güvenlik:** 🔴 Yalnız istemci kontrolü işe yaramaz — API doğrudan çağrılabilir.
- **Edge-case'ler:** boşluk/harf oyunları (`a_m_k`), Türkçe karakter varyantları,
  meşru kelimenin yanlış eşleşmesi (aşırı agresif liste kullanıcıyı bloke eder).
- **Kabul:** pgTAP: listedeki kelime reddedilir, varyantı da reddedilir, meşru ad kabul
  edilir · istemci hata mesajı TR+EN · mevcut adlar **geriye dönük silinmez** (yalnız
  değişiklikte kontrol).
- **Tuzaklar:** Liste çok agresifse gerçek isimler reddedilir; "Çiğdem" gibi meşru
  adlarda yanlış pozitif testi zorunlu.
- **Model önerisi:** 🟣 Pro
- **Kanıt:** `tooling/supabase/local.ps1 baseline` → 328 pgTAP PASS
  (`.artifacts/deploy-evidence/20260728T130124880Z-local-baseline`) ·
  `flutter test test/data/group_repository_test.dart --dart-define-from-file=env.json` → 24 PASS ·
  hedefli `flutter analyze` → 0 sorun. **Cihazda doğrulanmalı:** profil ve grup adı
  düzenlemede reddetme metninin TR/EN görünümü.

---

### Faz M — Mağaza altyapısı *(ops ağırlıklı; kartlar faz başlarken tam açılır)*

> Bunların çoğu kod değil hesap/ops işi ve **sahibin adımlarına bağlı** (alan adı satın
> alma, Play Console formları). Kısa kart = başlık + bağımlılık + kabul çekirdeği.

- **WP-393 — Ürün politikaları (yazılı karar metni) 📜.** Rakip analizinden çıkan dört
  politika `docs/`'a yazılır ve KALITE-PROGRAMI'na bağlanır: (1) **regresyon politikası**
  — görünen düzen değişirse eski düzen seçenek kalır; (2) **ücret politikası** — sayaç,
  gruplar, istatistik, bildirimler kalıcı ücretsiz ve reklamsız; (3) **zorlama yok** —
  uygulama engelleme, mola cezası, kolektif ceza asla eklenmez; (4) **dağıtım** — açılışta
  yalnız Türkiye (takvim sınırı `Europe/Istanbul` sabit). *Kod yok, WP-401'in metni buna
  dayanır.* 🔵
- **WP-394 — Alan adı zemini: dört sayfa + `assetlinks.json` 🌐.** Gizlilik politikası,
  kullanım şartları, hesap silme, destek sayfaları GitHub Pages'te yayına alınır.
  **Bağımlılık: sahip alan adını alır ve DNS panelini açar.** 🟣
- **WP-395 — Özel SMTP 📧.** Supabase yerleşik göndericisi saatte birkaç mesajla sınırlı;
  ilk kalabalıkta kayıt e-postaları düşer. **Lansman ön koşulu.** Masaüstündeki 6 haneli
  kod yolu da buna bağlı. **Bağımlılık: WP-394 (DNS kayıtları).** 🔴
- **WP-396 — Play AAB hattı 📦.** Release hattı yalnız APK üretiyor; Play `.aab` istiyor.
  `play` flavor zaten güncelleyiciyi kapatıyor (WP-128), o taraf temiz. 🟣
- **WP-397 — İzin hazırlığı: bildirim + pil optimizasyonu 🔋.** Xiaomi/Samsung'da arka
  plan sayacının en büyük düşmanı; kullanıcı kendi bulamaz. Onboarding'de anlatılır,
  SSS'de (WP-388) karşılığı olur. 🟣
- **WP-398 — Çökme/ANR raporlaması 🛰️.** `sentry_flutter` bağımlılıkta var; gerçekten
  rapor düşüyor mu, sembolize mi, doğrulanır. Mağazada körlük pahalı (H2 kararı: eklenir). 🔵
- **WP-399 — Uygulama içi puanlama istemi ⭐.** Play in-app review; birkaç başarılı
  oturumdan sonra **bir kez**. Erken puan toplamanın en ucuz yolu (H2 kararı). 🔵
- **WP-400 — Hesap silme uçtan uca kanıt 🗑️.** Kodu var, kanıtı yok: istek → 14 gün →
  kalıcı silme → yetkisiz çağrı reddi. WP-276'nın devamı, web tarafı WP-394'e bağlı. 🟣
- **WP-401 — Play listeleme paketi 🏪.** İkon, öne çıkan görsel, ekran görüntüleri
  (TR+EN), açıklama metni, Data Safety formu, içerik derecelendirme, **13+ yaş beyanı**,
  **yalnız TR+EN dil beyanı**, "reklam yok / uygulama içi satın alma yok" beyanı.
  Açıklama metni rakip acısından yazılır: *çevrimdışı çalışır · bilgisayarda da var ·
  reklamsız ve ücretsiz · elle eklenen süre de sayılır · davetle kurulan sakin gruplar.*
  🔴 **Açık soru:** tablet ekran görüntüsü isteniyor ama tablet yerleşimi parked.
  **Bağımlılık:** isim + logo kararı (sahipte), WP-393. 🟣
- **WP-402 — Kapalı test turu ve kademeli yayın 🚀.** 12 test kullanıcısı / 14 gün
  (sahip kabul etti) → %10 → %25 → %50 → %100. Foreground service tanıtım videosu
  (sahip çekecek, sona bırakıldı) bu kartın ön koşulu. 🟣

---

### Faz N — Yayın sonrası ilk dalga *(rakip analizinden; yayını geciktirmez)*

> Kaynak: `docs/RAKIPANALIZI-DEGERLENDIRME.md` §2 (ucuz ve gerçekten alınacaklar) +
> §4 (orta vadeli boşluklar) + G6'nın "sonra olur" listesi. Kartlar sırası geldiğinde açılır.

- **WP-403 — Tepkiler (emoji) 👏.** Şu an yalnız dürtme var; kodda `reaction` hiç geçmiyor.
  Rakipte de eksik ve doğrudan isteniyor (§2.1.3 #8).
- **WP-404 — Kamp ateşinde mola pozu 😴.** `onBreak` şu an yalnız detay sayfasındaki
  noktada görünüyor (`campfire_scene.dart:745`); sahnedeki hayvan değişmiyor. Altyapı hazır.
- **WP-405 — Odak sırasında sessizlik 🔕.** "Sayaç açıkken bildirimleri kes" — doğrudan
  istek (§2.1.2/12), bildirim tercihleri altyapısı var.
- **WP-406 — Seviye/lig görünümü 🎖️.** Ham sıralama yerine kademe. Aynı taşla iki kuş:
  hem talep (#5), hem "sıralama yavaş olanı kaçırıyor" baskısının çözümü.
- **WP-407 — Oturum bazlı kırılım 📊.** "Bugün 6 saat" yerine "3 oturuş: 2s · 1s40 · 2s20" (#19).
- **WP-408 — Manuel oturum rozeti ✍️.** Kazanım eşit kalır (`0063` doğru karar), ama
  `source='manual'` oturum grup katkı listesinde ve geçmişte **işaretlenir**. Şu an hiçbir
  yerde ayırt edilmiyor (`0001:57`) → public grup sıralamasında görünmez avantaj.
- **WP-409 — Sınav geri sayımı (D-Day) ⏳.** Araç yığınına girmeden tek istisna;
  TR/YKS bağlamının merkezinde, neredeyse bedava.
- **WP-410 — Davet linki 🔗.** Alan adı + `assetlinks.json` sonrası yarım günlük iş.
  Kurulum sonrası grup taşıma için ücretsiz hazır çözüm yok (Firebase Dynamic Links
  Ağustos 2025'te kapandı) → link bir sayfa açar, grup adı ve kod açıkça yazar.
- **WP-411 — Masaüstü admin yerleşimi 🖥️.** Panel Windows'ta **zaten açılıyor**
  (`settings_screen.dart:138`, `features/admin` altında platform kontrolü yok);
  eksik olan geniş ekran yerleşimi — uyarlama, yeni ürün değil.
- **Ayrıca sıraya:** yeni üye onay akışı (G5-son: yasaktan bağımsız anahtar) · arkadaş
  listesi · çalışma dışı kategoriler · ders klasörleri · sohbette görsel + alıntı ·
  hesap e-postası değiştirme.

---

### PLAN 3 çakışma matrisi

> ✅ **Aktif lane yok** — beş lane de boşta, v54 yayında. Yeni WP'ler serbest başlar.

| Kısıt | Kural |
|---|---|
| `campfire_scene.dart` | WP-382 → **sonra** WP-389. Aynı anda açılmaz. |
| `settings_screen.dart` | WP-383 → **sonra** WP-388 (yalnız SSS satırı ekler). WP-381 hiç girmez. |
| `stats_screen.dart` / stats widget'ları | WP-383 → **sonra** WP-384. |
| `supabase/migrations/**` | Sıra sabit: WP-387 `0090` → WP-388 `0091` → WP-389 `0092` → WP-391 `0093` → WP-392. Aynı anda iki migration WP'si yok. |
| `app/lib/l10n/*.arb` | WP-385 açıkken başka WP arb'ye girmez. |
| `android/**/timer/**` | WP-380 sahibi; WP-379 yalnız Dart tarafında kalır. |

**Paralel çalışılabilir üçlü (çakışmasız):** WP-379 (Dart sayaç) · WP-380 (Kotlin widget) ·
WP-385 (l10n/başarım). Sonraki dalga: WP-381 · WP-383 · WP-382.

### PLAN 3 — sahipte duran, plan dışı bağımlılıklar

1. **Uygulama ismi + logo** → WP-401 ve Faz M'nin tamamı buna bağlı (PLAN 2 · Faz G).
2. **Alan adı satın alma** (Porkbun · `.com` · WHOIS gizli) → WP-394, WP-395, WP-410.
3. **Play Console:** uygulamayı oluştururken **Google'ın imzalama anahtarını üretmesine
   izin ver** (sahip kararı H5) + kapalı test şartına bak.
4. **Tur metinleri** (WP-381 yer tutucuları doldurur).
5. **Foreground service tanıtım videosu** → WP-402.

---

## PLAN 4 — v56 SAHA TURU 🔧

> **Kaynak:** sahibin v55 cihaz testi (2026-07-28) + `docs/MODERASYON-PLANI.md` Faz A.
> Ham notlar ve gerekçeler: **`docs/V56-PLAN.md`**. Açık soru yok, plan uygulamaya hazır.
> **Migration head** tur başında `0094`, tur sonunda `0100`.
> 🔴 **Turun bir numaralı kuralı (v55 dersi):** yeni l10n anahtarı yazan her WP
> **dört dili birden** yazar — TR + EN + **DE + AR**. v55'te 13 kırmızı testin
> birinci nedeni buydu.

### Faz O — v55 saha bulguları: bozuk olanlar *(yayın öncesi, kod)*

#### WP-412: Tarih aralığı seçicide gün hücresi tarihin tamamını yazıyor 📅
- **Program/Faz:** PLAN 4 · Faz O (kaynak: sahip cihaz testi, ekran görüntüsü)
- **Ajan:** Lane E · **Durum:** [x] Kod + otomatik test tamam · `Cihazda doğrulanmalı`
- **Problem:** `draggable_date_range_picker.dart:445` gün hücresine `'$day'` yazıyor.
  `day` bir `DateTime`; Dart bunu `2026-07-01 00:00:00.000` olarak metne çeviriyor.
  40×40 dairenin içine sığmayınca taşıyor, hücreler üst üste biniyor, takvim okunmuyor.
  Sahip "çalışmıyor da" dedi — dokunma hedefleri taşan metnin altında kaldığı için.
- **Kapsam dışı:** Sürükleme mantığı, aralık takas davranışı, tema. Yalnız hücre metni.
- **SAHİP dosyalar (yaz):** `app/lib/features/stats/widgets/draggable_date_range_picker.dart`,
  `app/test/features/stats/**`
- **DOKUNMA:** `stats_period_bar.dart`, `personal_stats_view.dart` (Lane D/C okuyabilir)
- **Adımlar:**
  - [ ] `'$day'` → `'${day.day}'`.
  - [ ] Aynı hatanın başka hücrede olup olmadığını tara (`_HandleBody` uç etiketi
        `formatMediumDate` kullanıyor — **o doğru**, uç göstergesi tam tarih göstermeli).
  - [ ] Düzeltme sonrası sürükleme elle denenir; hâlâ tutmuyorsa ayrı bulgu olarak kartla.
- **Migration/Ortam:** Yok · local.
- **Kabul:** Widget testi hücre metninin **yalnız gün sayısı** olduğunu doğrular
  (`find.text('1')` bulunur, `find.textContaining('2026')` bulunmaz) · aralık sürükleme
  bırakıldığı anda uygulanır · iki uç birbirini geçince takas eder, çökmez.
- **Tuzaklar:** Ekran görüntüsüne değil **metin eşitliğine** test yaz. Uç etiketiyle
  hücre etiketini karıştırma; ikisi farklı biçim kullanmalı.
- **Model önerisi:** Sonnet
- **DoD kanıtı (2026-07-28, Lane E):**
  - Düzeltme: `draggable_date_range_picker.dart:447` artık `'${day.day}'`; tek satır,
    yanına neden yorumu yazıldı. Taranan diğer metin üreten yerler: hücre anahtarı
    `toIso8601String` (metin değil, `ValueKey`), `_CalendarGrid` haftagünü etiketleri
    (`narrowWeekdays`), başlık (`formatMonthYear`) — hepsi doğru. `_HandleBody`
    `formatMediumDate` kullanmaya **devam ediyor**, bilerek dokunulmadı.
  - Test (metin eşitliği, ekran görüntüsü değil):
    `gün hücresi yalnız gün sayısını yazar` — `cellText('2026-07-01') == '1'`,
    `'2026-07-09' == '9'`, `'2026-07-31' == '31'`; `GridView` içinde
    `find.text('1')` **findsOneWidget**, `find.textContaining('2026')` ve
    `find.textContaining(':')` **findsNothing**.
    `uç göstergeleri tam tarihi yazmaya devam eder` — uç etiketi `Jul` + gün içerir ve
    çıplak `'5'`e indirgenmemiştir (uç göstergesinin kısalmasına karşı kilit).
  - Regresyon kanıtı: düzeltme geçici olarak `'$day'`e geri alındığında paket
    **kırmızı** düştü (4 +1 -1 → hücre testi), geri konunca **5/5 yeşil**.
  - Mevcut üç test (44px hedef, uç takası, gelecek sınırı) değişmeden yeşil — sürükleme
    ve takas davranışına dokunulmadı.
  - `flutter analyze lib/.../draggable_date_range_picker.dart test/.../draggable_date_range_picker_test.dart`
    → **No issues found**. (Repo genelinde o an 7 hata vardı; hepsi Lane D'nin
    `lib/campfire_preview.dart` dosyasında, bu WP ile ilgisiz.)
  - Kalan kapı: sahibin cihazında takvimin okunur olduğu ve **sürüklemenin gerçekten
    tuttuğu** — sahip "çalışmıyor da" demişti; taşan metin kalkınca dokunma hedefleri
    açıldı, ama fiziksel doğrulama sahipte. Hâlâ tutmuyorsa ayrı bulgu kartı açılır.

#### WP-413: Engelleme yaptırımının eksik yüzeyleri 🚫
- **Program/Faz:** PLAN 4 · Faz O (kaynak: sahip cihaz testi)
- **Ajan:** Lane E · **Durum:** [x] Kod + otomatik test tamam · `Cihazda doğrulanmalı`
- **Problem:** `0092` engelleme yaptırımı dürtme ve kamp ateşini kapsıyor ama
  engellenen kişi **istatistik/liderlik tablolarında adıyla görünüyor** ve
  **profili açılabiliyor**. Yaptırım yüzey yüzey eklendiği için kapsam dışı yüzeyler kaldı.
- ✅ **Kamp ateşi kapsam dışı — cihazda doğrulandı.** Engellenen kişi orada
  "Engellenen kullanıcı" etiketiyle görünüyor; bu **doğru davranış**: sahneden
  silinmiyor, anonimleşiyor, katılımcı sayısı bozulmuyor.
- **Kapsam dışı:** Kamp ateşi davranışı · engelleme UI'ı · grup yasağı (`0093`, ayrı mekanizma).
- **SAHİP dosyalar (yaz):** `supabase/migrations/0095_*.sql`, grup/istatistik agregasyon
  RPC'leri, `app/lib/data/repositories/supabase/**` (ilgili okuma yolları),
  `supabase/tests/**` pgTAP
- **DOKUNMA:** `campfire_scene.dart` (Lane D sahibi), `features/admin/**` (Lane B sahibi)
- **Adımlar:**
  - [ ] Süzgeç **sunucuda** uygulanır, istemcide değil — istemci süzgeci atlanabilir ve
        yeni yüzey eklendiğinde sessizce kaçar.
  - [ ] Kapsanan yüzeyler: istatistik/liderlik tabloları · sosyal profil erişimi ·
        kullanıcı arama sonuçları · grup üye listeleri.
  - [ ] Engellenen kişinin profili doğrudan ID ile açılmaya çalışılırsa reddedilir.
  - [ ] Kamp ateşinin anonimleştirme davranışına **regresyon testi** — ileride
        yanlışlıkla "tamamen gizle"ye çevrilmesin.
- **Migration/Ortam:** `0095` · local → staging → production (sahip GO'su ile).
- **RLS/Güvenlik:** Yeni yüzey açılmıyor; mevcut okuma yolları daraltılıyor.
- **Kabul:** Her yüzey için **iki uçlu test** (A→B ve B→A) · engellenen kişi tabloda
  görünmez · profili ID ile bile açılmaz · kamp ateşi anonim etiketi korunur ·
  328+ pgTAP yeşil.
- **Tuzaklar:** Grup istatistikleri sunucu RPC'sinden geliyor (`docs/recovery/`
  MIGRATION-BASELINE) — süzgeci RPC'nin **içine** koy, dışına sarma.
- **Model önerisi:** 🔴 Opus
- **DoD kanıtı (2026-07-28, Lane E) — `0095_block_visibility_enforcement.sql`:**
  - **Süzgeç sunucuda, üç katman.** (1) `is_blocked_pair(a,b)` iki yönlü tek
    doğruluk kaynağı, null-safe. (2) `can_see_user_sessions` engelli çifti
    reddediyor — bu **tek** değişiklik `study_sessions` (0010),
    `gamification_profiles` / `user_achievements` /
    `achievement_metric_progress` (0024) ve `profiles` (0036) politikalarını
    birden daraltıyor, yani sosyal profil ekranını besleyen her tablo kapanıyor
    ve profil **doğrudan id ile bile** açılmıyor. `group_daily_totals` SECURITY
    INVOKER olduğu için kendiliğinden daraldı. (3) SECURITY DEFINER RPC'ler
    RLS'i atladığından süzgeç **RPC gövdesinin içine** kondu:
    `group_contribution_breakdown`, `group_leaderboard_series`,
    `group_alpha_scores`. Dışına sarma yok, istemci süzgeci yok.
  - 🔴 **Kamp ateşi korundu — ama düz "profiles hide" bunu kırıyordu.**
    `watchMembers` üye adlarını `profiles`ten okuyordu; RLS engelleneni
    reddedince kişi **sahneden tamamen düşüyor** ve katılımcı sayısı bozuluyordu.
    Bu yüzden `group_member_directory(gid)` eklendi: satırı **döndürür**,
    yalnız kimliği (ad `''`, avatar `null`, hayvan `null`) boşaltır ve
    `is_blocked = true` işaretler → kişi sahnede kalır, anonimleşir, sayı
    bozulmaz. Üye listesi de aynı kaynaktan besleniyor.
  - **Yan etki kapatıldı:** `profiles` engelleneni reddedince "Engellenen
    kullanıcılar" yönetim ekranı kimi engellediğini gösteremez hâle geliyordu.
    `blocked_user_directory()` yalnız **çağıranın kendi** engellediklerini
    gerçek adıyla döndürür; sosyal yüzey açmaz (pgTAP karşı yönü de doğruluyor).
  - **İstemci okuma yolları:** `supabase_group_repository.watchMembers` →
    `group_member_directory` RPC'si; `supabase_moderation_repository.fetchBlockedProfiles`
    → `blocked_user_directory` RPC'si (RPC'siz sunucuda maskeli-id yedeği duruyor).
    Repo arayüzü değişmedi → `in_memory` ikizleri olduğu gibi geçerli.
  - **Kanıt — pgTAP `024_block_visibility_enforcement.test.sql`, 17 iddia, hepsi
    iki uçlu (A→B ve B→A):** engel yokken üye görünür (taban) · engelleyen
    görünürlüğü kaybeder · profil id ile okunamaz (iki yön) · katkı tablosu ·
    liderlik serisi · alpha sıralaması · günlük grup toplamı — engellenen kişi
    yok · engelleyen **kendi** oturumunu görmeye devam eder · üye dizini hâlâ
    **2 satır** döndürür (sayı korunur) · engellenenin kimliği `'|NULL|NULL|true'`
    (anonim, gizli değil) · engellenmeyenin adı bozulmaz · engellenenler dizini
    yalnız kendi engellerini ve gerçek adı verir.
  - **Kanıt — Flutter `test/features/safety/block_visibility_wp413_test.dart`:**
    kamp ateşi regresyon kilidi. Engellenen üye sahneden **silinmiyor**
    (`b-<id>` gövde anahtarı duruyor), adı "Engellenen kullanıcı" oluyor;
    ikinci test engel kaldırılınca gerçek adın döndüğünü kanıtlıyor (etiketin
    gerçekten engelden geldiğini gösterir). İleride biri "tamamen gizle"ye
    çevirirse bu iki test kırmızı düşer.
  - **Yerel replay:** `local.ps1 baseline` → `0001→0095` uygulandı, **25 pgTAP
    dosyası / 345 test PASS**. `guard.tests.ps1` **75/75**.
    `flutter analyze` (değişen üç Dart dosyası) **No issues found**; ilgili
    Flutter paketleri (blocked_users, moderation_block_filter, campfire_scene,
    classroom_screen + yeni dosya) **yeşil**.
  - **Kapsam notları:** "kullanıcı arama sonuçları" yüzeyi **yok** — uygulamada
    kullanıcı araması bulunmuyor (gruba davet koduyla / herkese açık grup
    keşfiyle giriliyor, `discover_groups_by_tz` kullanıcı değil grup döndürür).
    Muafiyet olarak yalnız mevcut `is_super_admin()` OR'u korundu; yeni muafiyet
    eklenmedi. Grup yasağı (`0093`) ayrı mekanizma, dokunulmadı.
  - 🔴 **Tur sonu için not:** `local_migration_head` `0094`→`0095` taşındı ve
    `001_schema_contract.test.sql` head pini de birlikte güncellendi.
    `release-preflight.tests.ps1` bu noktada **beklendiği gibi kırmızıdır**:
    sürüm kapısı yerel head ile staging/production head'inin eşit olmasını
    şart koşuyor, ortamlar hâlâ `0094`. Tur sonunda apply `0100`e çıkınca yeşile
    döner. **Sözleşmenin staging/production `migration_head` alanlarına
    dokunulmadı** — orası apply kanıtı, uydurulmaz.
  - **Kalan kapı:** iki hesapla cihaz doğrulaması — engelledikten sonra
    liderlik tablosunda kişi yok, profili açılmıyor, kamp ateşinde "Engellenen
    kullanıcı" olarak duruyor ve katılımcı sayısı değişmiyor.
  - **Migration:** `0095` **uygulanmadı** (LOCAL KALIR). Rollback talimatı
    dosyanın başlığında.

#### WP-423: Şikâyet ve destek sorusuna foto eki 📎
- **Program/Faz:** PLAN 4 · Faz O (kaynak: sahip isteği — "bildir kısmına foto eklenebilsin")
- **Ajan:** Lane E · **Durum:** [x] Kod + otomatik test tamam · `Cihazda doğrulanmalı`
- **Problem:** Şikâyet ve SSS/destek sorusu yalnız metin kabul ediyor. Sahip ikisine de
  foto eklemek istiyor.
- **İyi haber:** Altyapı kısmen var — `submitFeedback` zaten `attachmentBytes` /
  `attachmentExt` alıyor (`admin_repository.dart:143`), `avatars` bucket'ı ve storage
  politikaları mevcut (`0002`). Sıfırdan sistem kurulmuyor, uzatılıyor.
- **Kapsam dışı:** Video, çoklu dosya, düzenleme. **Tek foto, tek ek.**
- **SAHİP dosyalar (yaz):** `supabase/migrations/0096_*.sql` (rapor ekleri için bucket +
  politika), `app/lib/features/safety/report_sheet.dart`,
  `app/lib/data/repositories/**/moderation_repository*`, destek/SSS soru formu
- **DOKUNMA:** `features/admin/**` (Lane B eki **okur**, yükleme yolunu yazmaz),
  `features/settings/**` (Lane C sahibi)
- **Adımlar:**
  - [ ] Rapor ekleri için ayrı bucket — `avatars` **public**, rapor eki **public olmamalı**.
  - [ ] Boyut ve MIME doğrulaması **sunucuda** zorlanır (istemci sınırı yeterli değil).
  - [ ] Ek yükleme başarısızsa şikâyet yine de gönderilir; ek opsiyoneldir.
  - [ ] Admin tarafında eke erişim yalnız super-admin (Lane B'nin WP-425'i görüntüler).
- **Migration/Ortam:** `0096` · local → staging → production.
- **RLS/Güvenlik:** 🔴 Foto ekinin kendisi kötüye kullanım aracıdır — public bucket'a
  koyma, imzalı URL kullan, boyut/tür sunucuda sınırla.
- **Kabul:** 5 MB üstü ve resim olmayan dosya sunucuda reddedilir · ek olmadan şikâyet
  gönderilebilir · ek yalnız super-admin tarafından açılabilir · pgTAP politika testi.
- **Tuzaklar:** `avatars` bucket'ını yeniden kullanma — public okuma politikası var,
  şikâyet eki oraya konursa herkese açılır.
- **Model önerisi:** 🔴 Opus
- **DoD kanıtı (2026-07-28, Lane E) — `0096_report_attachments.sql`:**
  - 🔴 **`avatars` yeniden kullanılmadı.** Ayrı ve **public olmayan**
    `report_attachments` bucket'ı kuruldu. pgTAP iki bucket'ın `public`
    bayrağının farklı olduğunu ayrıca doğruluyor.
  - **Boyut ve MIME sunucuda, iki kapıda.** (1) Bucket'ın kendisi
    `file_size_limit = 5242880` ve
    `allowed_mime_types = {image/jpeg,image/png,image/webp}` taşıyor → Storage
    API reddediyor. (2) `assert_report_attachment_allowed(path)` yolu ayrıca
    doğruluyor: yol `auth.uid()/` ile başlamalı, obje bucket'ta gerçekten var
    olmalı, `storage.objects.metadata` boyut/MIME yeniden ölçülüyor. Yani
    bucket ayarı atlansa bile uydurma yol kabul edilmiyor.
  - **İmzalı URL:** ek okuma politikası **yalnız `is_super_admin()`**. İmzalı
    URL de bu SELECT politikasından geçtiği için başka kimse (şikâyet eden
    dahil) üretemiyor. Lane B'nin WP-425'i eki buradan görüntüler; şikâyete
    bağlı destek bileti aynı `attachment_path`i taşıyor.
  - **Ek opsiyonel.** `assert_report_attachment_allowed(null)` sessizce geçiyor;
    istemci yükleme başarısızsa `null` yolluyor ve şikâyet yine gidiyor
    (`uploadReportAttachment` `StorageException`u yutup `null` döndürüyor).
  - **0090 sözleşmesi korundu.** İlk taslak `report_ugc`'yi `0038` gövdesi
    üzerine kurmuştu; `019_support_inbox` pgTAP'i bunu **yakaladı** (şikâyet
    biletine bağlanmıyordu). Gövde `0090` üzerine taşındı: her şikâyet hâlâ
    `ticket_type='report'` biletine bağlanıyor, `invalid_type` kontrolü ve
    `btrim`/snapshot kırpma normalizasyonu duruyor.
  - **İmza değişikliği:** iki RPC de eski imzasıyla birlikte dursaydı çağrı
    belirsizleşirdi; eski imzalar `drop` edilip varsayılan parametreli yenileri
    kuruldu. Eski istemciler (v55) eki hiç göndermediği için varsayılan `null`
    ile aynen çalışmaya devam eder.
  - **İstemci:** `report_sheet.dart` ve SSS soru formuna (`faq_screen.dart`)
    galeri seçici + önizleme + kaldır düğmesi. Ortak yükleyici
    `data/repositories/supabase/report_attachment_upload.dart`. Repository
    üçlüleri (abstract + `supabase/` + `in_memory/`) birlikte güncellendi.
  - **Yeni l10n anahtarı YOK** — mevcut dört dilli anahtarlar yeniden
    kullanıldı (`profileEkranGoruntusuEkleOpsiyonel`,
    `profileDosyaBoyutu5mbdanKucuk`, `profileResimSecilemedi`, `coreKapat`;
    dördü de TR/EN/DE/AR'da doğrulandı). Böylece `*.arb` sıcak dosyasına hiç
    girilmedi. ⚠️ Lane C WP-420'de `report_issue_dialog.dart`ı siliyor; bu
    anahtarları "kullanılmıyor" diye budarsa şikâyet/SSS formu kırılır —
    budamadan önce bu dört anahtarın yeni kullanıcısı olduğu görülmeli.
  - **Kanıt — pgTAP `025_report_attachments.test.sql`, 16 iddia:** bucket public
    değil · 5 MB sınırı bucket üstünde · yalnız resim MIME'ları · avatars'tan
    ayrı · okuma politikası super-admin şartlı · yükleme yalnız kendi klasörüne ·
    ek opsiyonel · 6 MB `attachment_too_large` · PDF `attachment_type_not_allowed` ·
    başkasının klasörü `attachment_not_owned` · olmayan yol `attachment_missing` ·
    eksiz şikâyet gönderilir · geçerli resim kabul edilir ve satıra yazılır ·
    bağlı destek bileti aynı eki taşır · destek sorusu da aynı kapıdan geçer.
  - **Kanıt — Flutter `test/features/safety/report_attachment_wp423_test.dart`:**
    bucket sabiti `avatars` değil · eksiz şikâyet gönderilebiliyor · ek
    repository katmanına taşınıyor · şikâyet sayfasındaki ek düğmesi görünür,
    **etkin** (ölü anahtar değil) ve ek seçilmeden gönderim çalışıyor.
  - **Yerel replay:** `0001→0096` uygulandı, **26 pgTAP dosyası / 361 test PASS**.
    `flutter analyze` (değişen altı yol) **No issues found**.
    Tüm Flutter paketi: 1052 test, **tek kırmızı Lane A'nın açık işinden**
    (`timer_v2_command_outbox_test.dart`, `StudyTimerService.kt` kaynağını okuyor
    ve Lane A o dosyayı şu an düzenliyor) — bu WP ile ilgisiz.
  - **Commit notu:** sahip önceliğiyle bu WP **iki commit**: `0096` migration'ı
    Lane B'nin `0097`'sini bekletmemek için erken ayrıldı (`4fc0f61`), istemci
    tarafı ikinci commit'te. "WP başına tek commit" kuralından bilinçli sapma.
  - **Kalan kapı:** cihazda — galeriden foto seç, şikâyeti gönder; 5 MB üstü ve
    resim olmayan dosyada sunucu reddi; ek olmadan gönderimin çalıştığı; ekin
    yalnız super-admin hesabında açılabildiği.
  - **Migration:** `0096` **uygulanmadı** (LOCAL KALIR). Rollback dosya başlığında.

### Faz P — Sayaç senkron güveni *(v55 saha bulguları)*

#### WP-414: Bildirim ve widget'tan Durdur ayna cihaza gitmiyor ⏱️
- **Program/Faz:** PLAN 4 · Faz P (kaynak: sahip cihaz testi)
- **Ajan:** Lane A · **Durum:** [~] Kod/test tamamlandı — cihaz kabulü bekliyor
- **Problem:** WP-379 uygulama içi Durdur'u ayna cihaza taşıdı ✅. Ama **bildirimden**
  ve **Android ana ekran widget'ından** Durdur denince diğer cihaz durmuyor.
  Senkron yolu yalnız Dart/UI katmanına bağlanmış; native aksiyon yolları aynı
  SSOT'a yazmıyor. WP-373 teşhisiyle aynı aile: `expected_run_revision` native
  tarafta doldurulmuyorsa sunucu `stop_run_revision_required` atıyor ve zarf
  kuyrukta zehir olarak kalıyor.
- **Kapsam dışı:** Pomodoro/geri sayım · Windows · yeni migration.
- **SAHİP dosyalar (yaz):** `app/android/app/src/main/kotlin/**/timer/**`,
  `app/android/app/src/main/kotlin/**/widgets/**`,
  `app/lib/data/providers/global_timer_providers.dart`,
  `app/lib/data/providers/study_providers.dart`, ilgili Kotlin + Dart testleri
- **DOKUNMA:** `supabase/migrations/**` · `features/admin/**` · `features/settings/**`
- **Adımlar:**
  - [ ] Üç giriş noktası (uygulama içi · bildirim · widget) **tek ortak yola** bağlanır.
  - [ ] Native taraf `expected_run_revision`'ı dolduruyor mu, doğrula.
  - [ ] `origin` sözlüğü sunucuda `('app','widget','notification','recovery')` —
        ham `native_widget` / `native_notification` göndermek sessiz ret üretir.
  - [ ] Reddedilen zarf kuyrukta **kalıcı zehir olmamalı**; sınırlı deneme sonrası düşer ve loglanır.
- **Migration/Ortam:** Yok · local.
- **Kabul:**
  - Bildirimden Durdur → ayna cihaz **≤ 5 sn** içinde durur.
  - Widget'tan Durdur → ayna cihaz **≤ 5 sn** içinde durur.
  - 🔴 **Üç giriş noktasının her biri için ayrı sözleşme testi** — istemcinin ürettiği
    zarf ile sunucunun beklediği şema tek testte karşılaştırılır. Biri koparsa kırmızı düşer.
- **Tuzaklar:** WP-373 dersi — tek uçlu testler senkronun yıllarca ölü kalmasını gizledi.
  pgTAP kendi uydurduğu `'app'` değerini kullanmasın, istemcinin gerçekten gönderdiğini kullansın.
- **DoD kanıtı:** ✅ Kodda doğrulandı — uygulama içi / bildirim / widget Durdur
  yolları ayrı canonical origin ile aynı native V2 kuyruğuna yazılıyor; üç ayrı
  iki-uçlu sözleşme testi Kotlin üretici → Dart canonical kümesi → migration
  allowlist → pgTAP çağrısını ölçüyor. `flutter test …global_timer_deferred_stop…
  …timer_v2_stop_entry_contract… …timer_v2_origin_contract…`: **12/12 yeşil**.
  ⏳ Cihazda doğrulanmalı — bildirim ve widget Durdur ile ayna cihazın ≤5 sn'de
  durması.
- **Model önerisi:** 🔴 Opus

#### WP-415: Çevrimdışı biten koşu ayna cihazda hayalet koşu doğuruyor 👻
- **Program/Faz:** PLAN 4 · Faz P (kaynak: sahip cihaz testi — en ciddi bulgu)
- **Ajan:** Lane A · **Durum:** [~] Kod/test tamamlandı — `0101` + cihaz kabulü bekliyor
- **Problem:** İki belirti, muhtemelen tek kök:
  1. Çevrimdışı başlatılan koşu, çevrimiçi olunca ayna cihazda **0'dan** saymaya
     başlıyor (kapatınca düzeliyor, toplam süre doğru).
  2. 🔴 Çevrimdışı **başlatılıp durdurulan** koşu, çevrimiçi olunca ayna cihazda
     **aktif koşu olarak canlanıyor** (`00:01`'den sayıyor) — kullanıcı ona hiç
     dokunmadığı hâlde. Dahası origin cihazda Durdur'a basınca *"diğer cihazdaki
     duracak"* uyarısı çıkıyor; yani sistem ayna cihazı gerçekten koşuyor sanıyor.
  Muhtemel neden: kuyruk yalnız `start` olayını taşıyor, `stop` ya taşınmıyor ya da
  zaman damgası karşılaştırılmadan uygulanıyor; bitmiş koşu "en son komut = start"
  olarak yeniden oynatılıyor.
- **Kapsam dışı:** Çevrimdışı açılış gecikmesi (5 sn) — izlenecek, bu turda WP değil.
- **SAHİP dosyalar (yaz):** WP-414 ile aynı küme (bu yüzden aynı lane)
- **Adımlar:**
  - [x] Çevrimdışı biriken komutlar **sıra + zaman damgası** ile uygulanıyor.
  - [x] Bitmiş koşu yeniden oynatıldığında aktif koşu **doğmuyor**: native, sunucu
        kimliği gelmeden `stop` niyetini kaybetmiyor; flush start kabulünden sonra
        aynı koşuya revision'lı CAS-stop gönderiyor.
  - [x] Bayat komut eşiği: 24 saati geçen `start` ve ona bağlı terminal niyet
        oynatılmadan kuyruktan düşüyor.
- **Migration/Ortam:** Yok (sunucu tarafı gerekirse `0101`, Lane B bitince) · local.
- **Kabul:**
  - 🔴 Senaryo testi: çevrimdışı başlat → çevrimdışı durdur → çevrimiçi ol →
    ayna cihazda **aktif koşu yok**, toplam süre eşit.
  - Çevrimdışı başlat → çevrimiçi ol (koşu sürerken) → ayna cihaz **0'dan değil**,
    doğru geçmiş süreden devam eder.
  - Çift `finalize` üretilmez (çift XP yok).
- **Tuzaklar:** "Kapatınca düzeliyor" belirtisi hatayı küçük gösteriyor — düzelten şey
  yeniden okuma, kök neden duruyor. Belirtiyi değil kökü düzelt.
- **DoD kanıtı:** ✅ Kodda doğrulandı —
  `global_timer_deferred_stop_test.dart` 2/2: offline `start → stop` çevrimiçi
  flush'ta `start`, ardından doğru `run_id/revision` ile `stop` çağrısı yapıyor ve
  kuyruk boşalıyor; 24 saatlik bayat çift hiç RPC üretmeden atılıyor. Birleşik
  sözleşme koşumu **12/12 yeşil**; ilgili Dart analizinde **0 sorun**.
  ⏳ Cihazda doğrulanmalı — iki Android cihazda hayalet koşu yok, çift finalize/XP
  yok. ⏳ `0101` gerekir — mevcut `0082` RPC'si `p_client_occurred_at` değerini
  yalnız audit'e yazıyor, `effective_started_at`ı sunucu saatiyle kuruyor; bu yüzden
  çevrimdışı sürmekte olan koşunun ayna cihazda doğru geçmiş süreden başlaması bu
  kapsamda (migration yasak) tamamlanamaz.
- **Model önerisi:** 🔴 Opus

### Faz Q — Arayüz ve içerik *(v55 saha bulguları)*

#### WP-416: Kamp ateşi düzeni + mobil parametrik önizleme 🔥
- **Program/Faz:** PLAN 4 · Faz Q (kaynak: sahip cihaz testi)
- **Ajan:** Lane D · **Durum:** [x] Kod+test tamam · cihaz kabulü bekliyor
- **Problem:** Sahip: *"kamp ateşi olmamış, yeşil kısmın yüksekliği çok az, isimler
  üst üste biniyor, şu anki px boyutu 2 katına çıkmalı."* Ayrıca PC'de olduğu gibi
  **mobil için de değer ayarlayabileceği bir önizleme ekranı** istiyor.
- 🔴 **Sıra kuralı (sahip kalıcı tercihi): önce önizleme, sonra kod.** Ama sahip bu
  turda dışarıda; **verdiği başlangıç değeri var: yeşil alan yüksekliği 2×.**
  Ajan 2×'i uygular **ve** önizleme aracını teslim eder; sahip döndüğünde ince ayarı
  araçtan yapar, seçtiği sayı teste bağlanır.
- **Kapsam dışı:** Hayvan asset'leri (tasarımcıda) · tablet yatay düzeni.
- **SAHİP dosyalar (yaz):** `app/lib/features/**/campfire_scene.dart` ve kamp ateşi
  widget'ları, mobil önizleme ekranı, ilgili düzen testleri
- **DOKUNMA:** `features/stats/**` (Lane E) · `features/settings/**` (Lane C) ·
  `supabase/**`
- **Adımlar:**
  - [ ] PC'deki ayar ekranının mobil karşılığı: yeşil alan yüksekliği · isim yazı boyutu ·
        satır aralığı · hayvan boyutu **parametrik**.
  - [ ] Yeşil alan yüksekliği **2×** uygulanır (sahibin verdiği başlangıç değeri).
  - [ ] En kalabalık grupta isim çakışması ve alt sıra ayak kesilmesi giderilir.
- **Migration/Ortam:** Yok · local.
- **Kabul:** Kalabalık senaryoda (8+ kişi) düzen testi isim çakışması bulmaz ·
  alt sıradaki hayvan `ClipRRect` ile kesilmez · sahibin seçtiği sayılar testte
  **sabit değer** olarak durur.
- **Tuzaklar:** v55'te dikey kelepçe alt sınırda `box * (1 - anchor)` düşmüyordu ve
  4+ kişide ayaklar kesiliyordu — aynı hesabı bozma. Yatayda `box / 2` iki uçtan düşülür.
- **Model önerisi:** Sonnet
- **DoD kanıtı (2026-07-28):**
  - **Yeşil alan 2×:** telefon bandı `68,5 px → 137 px`. Sahne yüksekliği (275)
    **değişmedi** — kısalan yalnız gökyüzü; kart telefonda aynı yeri kaplıyor.
    Türetme tek yerde: `campfireHorizonY` / `campfireGreenAreaHeight` /
    `campfireGroundYFactorForGreenArea` (`campfire_layout.dart`). Masaüstü bandı
    `93,3 px` ile **aynen** duruyor (sahip v55'te onaylamıştı) — çıpa artık
    profil başına ayrı: `kCampfireGroundYFactor` / `kCampfirePhoneGroundYFactor`.
  - **Dikey kelepçe korundu:** alt sınırda `box * (1 - anchor)`, üst sınırda
    `box * anchor` düşülüyor; hesap **değiştirilmedi**. Test bir adım ileri
    gidiyor: 8 kişide gövde alt kenara **dayanmıyor** bile (kelepçe artık
    devreye girmiyor), yani ayak kesilmesi kaynağında kalktı.
  - **Parametrik önizleme:** `app/lib/campfire_preview.dart` — **gerçek**
    `CampfireScene`'i çizer (wp295 önizlemesi sahneyi taklit ediyordu, bu
    etmiyor). Dört kol: yeşil alan yüksekliği (60–200 px) · isim yazı boyutu
    (8–18) · satır aralığı (0,60–2,00) · hayvan boyutu (0,60–1,60). Sahip
    seçtiği kombinasyonu ekrandaki `greenArea=… · labelFont=… · seatSpread=… ·
    critterScale=…` satırından kopyalayıp gönderir; sayı doğrudan
    `CampfireTuning` sabitine ve teste girer.
    Çalıştırma: `flutter run -t lib/campfire_preview.dart --dart-define-from-file=env/local.json`
  - **Kollar tek sözleşmede:** `CampfireScene`'in beş ayrı `preview*` alanı
    `CampfireTuning` nesnesinde toplandı; önizleme, üretim ve golden aynı yolu
    kullanıyor.
  - **Yan bulgu (düzeltildi):** grup 8'den kalabalıksa (`0071` öncesinden kalma
    gruplar) sahne `seats[i]` ile `RangeError` atıp çöküyordu; artık fazlalık
    çizilmiyor, ekran ayakta kalıyor.
  - **Test:** `test/features/campfire/campfire_wp416_layout_test.dart` (12 test:
    2× bandı · masaüstü regresyonu · px↔oran çevrimi · 6 ve 8 kişide isim
    çakışması yok · alt sıra kelepçeye dayanmıyor · dört kolun sahneyi
    gerçekten sürdüğü · önizleme aracı). Kamp ateşi paketi **47/47 yeşil**;
    `campfire_phone_1/4/8` golden'ları yeni kompozisyonla yenilendi.
  - **Kanıt etiketi:** `Cihazda doğrulanmalı` — 2× sahibin verdiği başlangıç
    değeridir, ince ayar önizleme aracından gelecek.
- **Commit:** `WP-416`
- 🔴 **v56 sahip düzeltmesi (2026-07-28, merdiven karesi üzerinden):** *"yeşili
  **üste** uzat, sen alta yeşil koyup hepsini yukarı çıkarıyorsun; ateşi ve
  hayvanları biraz aşağı indir, yeşil 150 px olsun."*
  - **Kök neden:** ufuk, ateşin **türeviydi** (`horizon = fireY + 18 − ry·0.82`).
    Bu bağ yüzünden yeşili büyütmenin tek yolu tüm kompozisyonu yukarı
    kaydırmaktı — sahibin şikâyeti tam olarak buydu, ayar hatası değil **model**
    hatasıydı.
  - **Düzeltme:** ufuk artık yalnız zemin çıpasından türüyor; yeni
    `ringDropPixels` kolu ateşi + oturma halkasını ufka göre **aşağı** itiyor ve
    yeşil alanı hiç oynatmıyor (`campfireFireY`). İki kol birbirinden bağımsız.
  - **Seçilen sayılar:** yeşil alan **150 px**, düşürme **40 px**
    (`kCampfirePhoneGreenAreaHeight` / `kCampfirePhoneRingDropPixels`).
    Masaüstü profilinde düşürme `0` — v55 kompozisyonu aynen duruyor.
  - **Test:** `campfire_wp416_layout_test.dart` içinde `v56 · yeşil yukarı,
    kompozisyon aşağı` grubu (3 test): düşürme ufku **hiç** oynatmıyor · ateşi
    tam verilen kadar itiyor · sahnede 8 kişide ufuk sabitken gövdeler tam 40 px
    aşağı iniyor. Kelepçe testi 40 px'te de yeşil (ayak kesilmesi yok). Kamp
    ateşi paketi **29/29**, `flutter analyze` temiz, telefon golden'ları
    yenilendi.
  - **Önizleme:** araca beşinci kol eklendi (`ring-drop`, 0–70 px); kopyalanan
    satır artık `ringDrop=…` da taşıyor.
  - **Kanıt etiketi:** `Cihazda doğrulanmalı`.
- **Commit (v56):** `WP-416 v56`

#### WP-417: Tanıtım turu sadeleştirme 🎯
- **Program/Faz:** PLAN 4 · Faz Q (kaynak: sahip cihaz testi)
- **Ajan:** Lane D · **Durum:** [x] Kod+test tamam · cihaz kabulü bekliyor
- **Problem:** Sahip ana ekran turunu beğenmedi: *"sadece edit kısmını gösterelim."*
  İstatistiklerdeki period tanıtımı için **önceki isteğini geri aldı:** kaldırılacak.
- **Kapsam dışı:** İpucu (coach mark) sistemi mimarisi · tur sıfırlama düğmesi.
- **SAHİP dosyalar (yaz):** tur tanım dosyaları, `app/lib/l10n/*.arb` (tur metinleri),
  tur testleri
- **DOKUNMA:** `campfire_scene.dart` (WP-416 açıkken **girme**, aynı lane sıralı ilerler)
- **Adımlar:**
  - [ ] Ana ekran turu: yalnız **edit** adımı kalır, diğer adımlar çıkar.
  - [ ] İstatistikler: period tanıtımı **tamamen kaldırılır**.
  - [ ] Kaldırılan adımların l10n anahtarları da temizlenir (ölü anahtar bırakma).
- **Migration/Ortam:** Yok · local.
- **Kabul:** Tur adım sayısı testte sabitlenir · hiçbir adımda iki tıklanabilir öğe
  çakışmaz · çevrilmemiş anahtar raporu boş.
- **Tuzaklar:** 🔴 Anahtar silerken **dört dilden birden** sil; birinde kalırsa
  çevrilmemiş/artık anahtar raporu kırmızı düşer.
- **Model önerisi:** Sonnet
- **DoD kanıtı (2026-07-28):**
  - **Ana ekran:** tur tek adıma indi (`home.v1` → yalnız `edit`). Genel bakış
    adımı kalktı. 🔴 **Yorum kararı:** ana ekranda Home turu biter bitmez
    zincirlenen **Sayaç turu** da kaldırıldı (`AppTours.timer` silindi) — sahip
    *"sadece edit kısmını gösterelim"* dediğinde cihazda gördüğü ikinci balon
    buydu; biri kalsaydı istek yarım karşılanırdı. Geri istenirse tek kart.
  - **İstatistikler:** dönem tanıtımı **tamamen** kalktı — `AppTours.stats`,
    `stats_screen`'deki `TourHost` ve `_periodTourAnchor` birlikte silindi.
  - **Ölü anahtar yok:** `tourHomeOverview` · `tourTimerOverview` ·
    `tourTimerMissing` · `tourStatsOverview` · `tourStatsEmpty` **dört dilden
    birden** silindi (TR/EN/DE/AR); katalog eşliği testi yeşil. Ana ekrandaki
    ölü `_dashboardTourAnchor` da kaldırıldı.
  - **Adım sayısı testte sabit:** `app_tours_test.dart` artık dört tur bekliyor
    (`home.v1 · groups.v1 · campfire.v1 · profile.v1`) ve ana ekran turunun tek
    adım + `edit` kimliği olduğunu doğruluyor; yeni bir tur sessizce eklenirse
    ya da silinenler geri gelirse test kırılır. Balon taşma/yerleşim testleri
    (TR+EN, 360 px) korunuyor.
  - **Test:** `test/features/tours` + `test/core/tour` + `test/features/home` +
    `test/features/stats` → **49/49 yeşil**; `test/l10n` 28/28 yeşil.
  - **Kanıt etiketi:** `Cihazda doğrulanmalı` (tur ilk açılışta görünür).
- **Commit:** `WP-417`

#### WP-418: Başarım açıklamalarını ölçülebilir yaz 🏅
- **Program/Faz:** PLAN 4 · Faz Q (kaynak: sahip cihaz testi)
- **Ajan:** Lane D · **Durum:** [x] Kod+test tamam · cihaz kabulü bekliyor
- **Problem:** Sahip iki başarımı **anlamadı**: *Source of Inspiration* (dürttükten
  sonra kaç dakika içinde derse başlaması gerekiyor?) ve *Lokomotif* ("o gün içinde
  ilk çalışmaya başlayan mı? ben de anlamadım"). Açıklamalar koşulu söylemiyor.
- **Kapsam dışı:** Başarım koşullarını **değiştirmek**. Yalnız açıklama metni;
  koşul koddan okunup düz dille yazılır.
- **SAHİP dosyalar (yaz):** başarım tanımları, `app/lib/l10n/*.arb`, başarım testleri
- **DOKUNMA:** tur dosyaları (WP-417 açıkken sıraya gir) · `features/settings/**`
- **Adımlar:**
  - [ ] *Source of Inspiration*: dürtme sonrası **pencere kaç dakika** — koddan oku, yaz.
  - [ ] *Lokomotif*: koşulu düz Türkçe/İngilizce ile yaz.
  - [ ] Tarama: koşulu ölçülebilir yazılmamış **başka başarım kalmasın**.
- **Migration/Ortam:** Yok · local.
- **Kabul:** Her başarımın açıklaması eşiğini/penceresini içerir · boş veya belirsiz
  açıklama testte kırılır · dört dilde tam.
- **Tuzaklar:** Açıklamayı plandan değil **koddan** yaz — eşik kodda ne diyorsa o.
  (WP kartı iddialarının koddan doğrulanması kuralı.)
- **Model önerisi:** Sonnet
- **DoD kanıtı (2026-07-28) — hepsi koddan okundu, plandan değil:**
  - 🔴 **Source of Inspiration'ın cevabı: pencere diye bir şey yok.** Metrik
    `0025_achievements_social_metrics.sql:162` →
    `select count(*) from nudges where sender_id = p_user_id`. Yani sayılan şey
    **gönderdiğin dürtme sayısı**; karşı tarafın çalışmaya başlaması koşul
    değil, dolayısıyla dakika sınırı da yok. Eski metin ("dürtmenin ardından
    5 üyenin başlamasını sağla") **olmayan bir kuralı vaat ediyordu** — sahibin
    sorusunun kaynağı buydu. Yeni metin: *"Arkadaşlarına 5 kez dürtme gönder."*
  - 🔴 **Lokomotif'in koşulu: 15 dakikalık takip penceresi.**
    `0059_campfire_dynamic_threshold.sql` `loco` CTE →
    `follower.a between leader.a and least(leader.z, leader.a + interval '15 minutes')`.
    Bir olay = **sen** başladıktan sonraki 15 dk içinde (ve sen hâlâ çalışırken)
    başlayan **farklı** bir grup arkadaşı; grup-gün başına farklı kişi sayılır.
    "Çalışmaya ilk başlayan üye ol" hiç doğru değildi. Yeni metin: *"Sen
    başladıktan sonraki 15 dakika içinde 5 kez bir grup arkadaşın da çalışmaya
    başlasın."*
  - **Tarama iki yanlış metin daha buldu:**
    - **Kamp Ateşi** "en az 3 grup üyesi aktifken" diyordu; eşik `0059`'dan beri
      **dinamik**: `greatest(2, ceil(N/2))`. Metin artık "grubunun en az yarısı
      (en az 2 kişi)" diyor.
    - **Takım Oyuncusu** "grubunun günlük hedefine katkı sağla" diyordu; metrik
      (`0025:167`) aslında **aktif grup üyesiyken çalıştığın farklı gün sayısı**
      — grubun hedefe ulaşması hiç hesaba girmiyor. Hem kademe metni hem kural
      cümlesi düzeltildi.
    - **Alfa Kurt** "birinci ol" diyordu; `alpha` CTE **tek başına** birinciliği
      şart koşuyor (`count(*) over(partition by seconds) = 1`), beraberlikte
      kimse almıyor. Metne yazıldı.
  - **Dört dil tam:** sekiz metin (5 kademe koşulu + 2 kısa açıklama + Takım
    Oyuncusu kuralı) TR/EN/DE/AR **birlikte** güncellendi; placeholder eşliği ve
    katalog eşliği testleri yeşil.
  - **Test:** `test/core/stats/achievement_catalog_contract_test.dart` altı yeni
    testle genişletildi — her kademe metni **dört dilde** kendi eşiğini sayıyla
    yazıyor (eşik 1 olanlar hariç: diller orada "bir/واحد" diyor) · İlham
    Kaynağı metni dönüşüm vaadine dönerse kırmızı · Lokomotif metninde `15`
    yoksa kırmızı · Kamp Ateşi'nde sabit `3` geri gelirse kırmızı · Takım
    Oyuncusu'nda "hedefe katkı" geri gelirse kırmızı · Alfa Kurt'ta "tek başına"
    düşerse kırmızı. `test/core/stats` + showcase + `test/l10n` → **45/45 yeşil**.
  - ⚠️ **Kapsam dışı bırakılan bir kalıntı (Lane C'ye not):** kilitli gizli
    başarım kartlarının tamamı `profileBuGizliBasariminKosulu` metnini
    gösteriyor ("bu gizli başarımın koşulu henüz etkin değil"). Bu cümle yalnız
    **Mola Düşmanı** için doğru (`0052`: "backfill tanımlıdır, çalışmaz"), diğer
    gizli başarımlar için yanıltıcı. Ayrımı yapmak `achievement_showcase.dart`
    içinde kod değişikliği ister; o dosya **WP-421 ile Lane C'nin `features/
    profile/**` kümesinde**, bu yüzden dokunulmadı. Tek satırlık düzeltme:
    kilitli-gizli yüzeyinde `profileGizliBirBasarimAcmak` kullanmak.
  - **Kanıt etiketi:** `Kodda doğrulandı` (metin değişikliği; cihazda okunması
    yeterli).
- **Commit:** `WP-418`

### Faz R — Destek, ayarlar ve rozet *(v55 saha bulguları)*

#### WP-419: Sürüm notları ekranı — teknik kart ve beta sızıntısı 📋
- **Program/Faz:** PLAN 4 · Faz R (kaynak: sahip ekran görüntüsü)
- **Ajan:** Lane C · **Durum:** [x] Kod + otomatik test tamam — `Cihazda doğrulanmalı`
- **Problem:** İki ayrı sorun, ekran görüntüsüyle doğrulandı:
  1. 🔴 **"Build diagnostics" kartı son kullanıcıya açık** — Channel, Version,
     Backend project-ref, Commit SHA, Migration head normal kullanıcının gördüğü
     ekranın en üstünde. **v55'te yarım kalmış düzeltme:** sürüm notu *gövdeleri*
     temizlendi ama bu kart kapsam dışı kaldı; test maddesi de yalnız gövdeye
     baktığı için hatayı kaçırdı.
  2. **Stable kanalda beta sürümler listeleniyor** — `beta-v4402` "Beta" rozetiyle
     stable kullanıcıya görünüyor, liste bu yüzden uzuyor.
- **Kapsam dışı:** Sürüm notu **içeriğinin** yeniden yazımı · güncelleme akışı.
- **SAHİP dosyalar (yaz):** sürüm notları ekranı, `app/lib/features/settings/**`
  (Hakkında girişi), ilgili testler
- **DOKUNMA:** `features/stats/**` · `features/admin/**` · `campfire_scene.dart`
- **Adımlar:**
  - [x] Diagnostics kartı sürüm notlarından **çıkar**, **Ayarlar → Hakkında** altına taşınır.
  - [x] Hakkında'da varsayılan yalnız `1.0.55`; üstüne dokununca commit / migration head /
        backend açılır. Destekte "sürümün ne?" cevaplanabilir kalır.
  - [x] Stable kanalda yalnız stable sürümler listelenir.
  - [x] Liste son N sürümle sınırlanır, gerisi "daha fazla" ile açılır.
- **Migration/Ortam:** Yok · local.
- **Kabul:** 🔴 Sürüm notları ekranının **tamamında** `commit`, `migration head`,
  `backend`, project-ref metni **geçmez** (v55 testinin kapsamı gövdeden tüm ekrana
  genişletilir) · stable kanal testinde beta rozetli kart bulunmaz.
- **Tuzaklar:** Kartı silme, **taşı** — destek yazışmasında sürüm bilgisi gerekiyor.
- **Model önerisi:** Sonnet
- **DoD kanıtı (2026-07-28, Lane C · `Kodda doğrulandı`):**
  - **Taşındı, silinmedi.** `BuildIdentityCard` artık katlanır: kapalıyken yalnız
    sürüm adı (`1.0.55`), dokununca kanal / tam sürüm+build / backend /
    commit / migration başı açılır. Yeni ev: **Ayarlar → Hakkında ve yasal →
    Hakkında** (`features/profile/about_screen.dart`).
  - 🔴 **DoD gövdeyle sınırlanmadı.** Yeni kapı ekranın **tamamını** tarıyor:
    `visibleTexts()` bütün `Text` + `SelectableText` widget'larını toplar,
    "daha fazla"yla gizli kartları da açar ve
    `commit|migration|backend|project-ref|supabase` regex'i arar. Kaynak
    uydurulmuyor — gerçek `assets/release_notes.json` okunuyor, yani üretim
    içeriği denetleniyor. v55'in `release-notes-contract.ps1` kapısı yalnız JSON
    gövdelerine bakıyordu; kart ayrı widget olduğu için altından geçmişti.
  - **Beta sızıntısı:** `ReleaseNotesService.loadVisibleNotes(channel:)` stable
    kullanıcıya yalnız stable notları verir; beta kanalı iki zinciri de görür.
    İki yönlü test var (stable'da `Beta` rozeti bulunmaz, beta'da her ikisi de).
  - **Liste sınırı:** `kReleaseNotesInitialCount = 5`, gerisi
    `release-notes-show-more` düğmesiyle açılır; sayım testi tembel liste
    tuzağına karşı viewport'u 1080×12000'e büyütür.
  - **l10n:** `aboutTitle`, `aboutSubtitle`, `updaterDahaFazlaSurum` — **dört
    dilde birden** (TR/EN/DE/AR). `buildTaniBasligi` yeniden kullanıldı, ölü
    anahtar bırakılmadı.
  - **Test:** `flutter analyze` 0 uyarı · `release_notes_test.dart` 11/11 ·
    `about_screen_test.dart` 3/3 · `settings_screen_test.dart` +
    `wp294_l10n_debt_test.dart` + `wp85_l10n_test.dart` 18/18 yeşil.
  - **Cihazda doğrulanmalı:** Ayarlar → Hakkında'da sürümün göründüğü ve
    dokununca teknik satırların açıldığı; sürüm notlarında beta kartı kalmadığı.

#### WP-420: Feedback ekranı yeniden düzeni 💬
- **Program/Faz:** PLAN 4 · Faz R (kaynak: sahip cihaz testi)
- **Ajan:** Lane C · **Durum:** [x] Kod + otomatik test tamam — `Cihazda doğrulanmalı`
- **Problem:** Sahip destek sistemini uçtan uca denedi, **çalışıyor** ✅ ama düzen bozuk:
  mobilde konu + açıklama + **3 buton alt alta** (Geri bildirimlerim, İptal, Gönder) +
  klavye açık → yazdığı metin görünmüyor. Ayrıca mesajlaşmada **yeni mesajlar üste**
  ekleniyor (alışılmışın dışında).
- **Kapsam dışı:** Bilet durum makinesi · admin tarafı yazışma (Lane B'de değil, zaten çalışıyor).
- **SAHİP dosyalar (yaz):** geri bildirim gönderme ve liste ekranları,
  `app/lib/features/settings/**`, `app/lib/l10n/*.arb`, ilgili testler
- **DOKUNMA:** `features/admin/**` (Lane B) · `features/safety/report_sheet.dart` (Lane E)
- **Adımlar:**
  - [x] Ayarlardaki ad: **"Send feedback" → "Feedback"**.
  - [x] İçinde **iki sekme**: *Gönder* · *Geri bildirimlerim* (liste, **tarih sıralı,
        en yeni en üstte**).
  - [x] Gönderme formunda **iki buton, yan yana**: İptal · Gönder. (Üçüncü buton
        sekmeye taşındığı için kalkar.)
  - [x] Klavye açıkken yazılan metin görünür kalır.
  - [x] Mesajlaşmada **yeni mesaj alta** eklenir.
- **Migration/Ortam:** Yok · local.
- **Kabul:** Dar mobil ekranda klavye açıkken metin alanı görünür (widget testi) ·
  mesaj sırası testte sabit (yeni mesaj sonda) · liste tarih sıralı · dört dil tam.
- **Tuzaklar:** Sabit alt şerit için `Scaffold.bottomSheet` **kullanma** — gövdeyi örter,
  yer ayırmaz. Doğrusu `Column` + `Expanded`. Test üretimdeki kabuk yapısını taklit
  etmezse hatayı kaçırır.
- **Model önerisi:** Sonnet
- **DoD kanıtı (2026-07-28, Lane C · `Kodda doğrulandı`):**
  - **Diyalog gitti, ekran geldi.** `ReportIssueDialog` silindi; yerine
    `features/profile/feedback_screen.dart` — `DefaultTabController` + iki sekme
    (*Gönder* · *Geri bildirimlerim*). Ayarlardaki ad **"Geri bildirim"**.
  - **Tuzağa girilmedi:** alt şerit `Scaffold.bottomSheet` değil,
    `Column` + `Expanded(ListView)` + `SafeArea` şerit. Klavye testi
    `viewInsets.bottom = 900px (300dp)` verip **şeridin metin alanının üstüne
    binmediğini** ve ikisinin de klavye çizgisinin üstünde kaldığını ölçüyor;
    `bottomSheet`'e dönülürse bu iddia düşer.
  - **Koşum üretim kabuğunu taklit ediyor:** `FeedbackScreen` kendi
    `Scaffold`'uyla doğrudan `home:`e konuyor (v55'te WP-374 koşumu bunu
    yapmadığı için hata kaçmıştı).
  - 🔴 **Yol boyunca çıkan gerçek kusur:** form `authStateProvider`'ı yalnız
    `read` ediyordu. Riverpod 3 auto-dispose'ta dinleyicisiz provider her
    `read`'de yeniden kurulur ve yükleme durumunda döner → gönderim "giriş
    yapmalısın" ile sessizce reddediliyordu. `build` içinde `watch` eklendi ve
    profil yokken Gönder devre dışı. Testte önce kırmızı düştü, sonra yeşil.
  - **Sıralama:** bilet listesi en yeni en üstte (`fetchMyFeedbackTickets` iki
    repoda da `created_at desc`), yazışmada yeni mesaj altta (WP-374 kazanımı,
    `feedback_conversation_wp374_test` hâlâ yeşil). Gönderim sonrası ekran
    ikinci sekmeye geçip yeni kaydı en üstte gösteriyor — testte sabit.
  - **l10n:** `feedbackTitle`, `feedbackTabCompose` — dört dilde birden.
    `profileGeriBildirimGonder` katalogda bırakıldı (EN'deki çok satırlı `@`
    blokları yüzünden silmek dosyayı baştan biçimlendirmeyi gerektiriyor; dört
    dil eşliği bozulmasın diye dokunulmadı).
  - **Test:** `flutter analyze` 0 uyarı · `feedback_screen_wp420_test.dart` 4/4 ·
    biletler + WP-374 yazışma + ayarlar + l10n borç kapısı ile birlikte 21/21.
  - **Cihazda doğrulanmalı:** Dar telefonda klavye açıkken yazılan metnin
    görünürlüğü ve iki düğmenin yan yana durduğu.

#### WP-421: Rozet zinciri ve gecikmesi 🔴
- **Program/Faz:** PLAN 4 · Faz R (kaynak: sahip cihaz testi)
- **Ajan:** Lane C · **Durum:** [x] Kod + otomatik test tamam — `Cihazda doğrulanmalı`
- **Problem:** Sahip: *"profil + ayarlarda kırmızı ya da başka nokta yoktu, kendim
  girip gördüm, sadece bildirim geliyor."* Başarımlarda da aynı: push düşüyor ama
  **başarımlar ekranında rozet yok**. Sonradan (~2 dk) rozet düştü → **gecikme** var.
- **Kapsam dışı:** Push altyapısı · bildirim içeriği.
- **SAHİP dosyalar (yaz):** rozet/okunmamış sayaç sağlayıcıları,
  `app/lib/features/profile/**`, `app/lib/features/settings/**`, başarım ekranı, testler
- **DOKUNMA:** `features/admin/**` · `features/safety/**` · `supabase/migrations/**`
- **Adımlar:**
  - [x] Rozet zinciri: **Profil → Ayarlar → Feedback → Başarımlar**. Her seviye gösterir.
  - [x] Push ile rozet **aynı olaydan** beslenir; rozet push'u beklemez.
  - [x] Okununca zincir temizlenir (üst seviyeler de).
  - [x] Yeni mesajda WhatsApp/Instagram gibi renkli rozet (sahip isteği).
- **Migration/Ortam:** Muhtemelen yok. Sunucu tarafı gerekirse `0101` — **Lane B'nin
  `0100`'ü commit'lendikten sonra** numarayı al.
- **Kabul:** Okunmamış mesaj/başarım varken zincirdeki **her seviye** rozet gösterir ·
  okununca hepsi temizlenir · rozet push'tan bağımsız görünür (çevrimdışıyken de).
- **Tuzaklar:** Riverpod 3 auto-dispose — dinleyicisiz provider her `read`'de yeniden
  build olur ve regresyon testini sessizce etkisizleştirir. Repoda yerleşik kalıp var, kullan.
- **Model önerisi:** Sonnet
- **DoD kanıtı (2026-07-28, Lane C · `Kodda doğrulandı`):**
  - **Rozet hiç yoktu — eklendi.** Okunmamış yönetici yanıtı için yeni sayaç:
    `AdminRepository.fetchUnreadTicketReplyCount` **çift repo** (supabase +
    in_memory) ve `unreadFeedbackReplyCountProvider`. Migration gerekmedi:
    `0074` RLS'i kullanıcıya kendi biletinin mesajlarını zaten açıyor.
    Supabase yolu önce kendi bilet id'lerini alıyor — RLS super-admin'e her şeyi
    açtığı için "gördüğüm her şey benimdir" varsayımı yanlış sayı üretirdi.
  - **Zincirin dört halkası:** Profil → Ayarlar satırı (`settings-row-reply-badge`) ·
    Ayarlar → Geri bildirim satırı (`feedback-row-reply-badge`) · Geri bildirim →
    "Geri bildirimlerim" sekmesi (`feedback-tab-reply-badge`) · Profil →
    Başarımlar kartı bekleyen ödül rozeti (`achievements-pending-badge`).
    Hepsi **tek kaynaktan** okuyor; kaynak sözleşmesi testte kilitli.
  - **Renkli rozet:** `UnreadMessageBadge` — sayı taşıyan dolu rozet, rengi
    `colorScheme.primary` (yeni içerik, uyarı değil; `warning_tokens` ayrı yüzey).
    Sekmede metnin **üstüne** binen `Badge` kullanıldı: yan yana Row dar
    telefonda 106 px taşıyordu (testte yakalandı).
  - 🔴 **Gecikmenin kök nedeni push değil önbellekti.** Başarım/ödül
    sağlayıcıları yalnız oturum bitişi ve ödül toplamada tazeleniyordu; bu
    yüzden rozet ~2 dk sonra düşüyordu. `SocialProfileScreen.initState` artık
    açılışta dördünü de invalidate ediyor.
  - **Okununca temizlenir:** `markTicketMessagesRead` sonrası
    `unreadFeedbackReplyCountProvider` invalidate edilir → üst seviyelerdeki
    rozetler de söner (testte açıp kapatınca sıfırlandığı doğrulanıyor).
  - 🔴 **Auto-dispose tuzağına karşı açık kapı:** sağlayıcı bilinçli olarak
    `autoDispose` **değil** ve sayan bir sahte repo ile "dinleyicisiz iki okuma =
    tek sunucu çağrısı" testte sabitlendi. `autoDispose`'a çevrilirse kırmızı düşer.
  - **Push bağımsızlığı:** rozet yüzeyleri ve sağlayıcı push servisine hiç
    referans vermiyor (kaynak sözleşmesi testi bunu da tutuyor).
  - **Test:** `flutter analyze` 0 uyarı · `badge_chain_wp421_test.dart` 10/10 ·
    profil + ayarlar + geri bildirim + başarım vitrini paketleri 150/150 yeşil.
  - **Cihazda doğrulanmalı:** Yönetici yanıt yazdığında rozetin dört seviyede de
    belirmesi, okununca sönmesi ve başarım rozetinin gecikmeden düşmesi.

#### WP-422: SSS giriş ekranında yerleşim ve etiket ❓
- **Program/Faz:** PLAN 4 · Faz R (kaynak: sahip cihaz testi)
- **Ajan:** Lane C · **Durum:** [x] Kod + otomatik test tamam — `Cihazda doğrulanmalı`
- **Problem:** Giriş ekranında SSS bağlantısı yanlış yerde ve etiketi Türkçe kullanıcı
  için tanıdık değil.
- **Kapsam dışı:** SSS içeriği · SSS arama · çevrimdışı yedek içerik (v55'te çalışıyor).
- **SAHİP dosyalar (yaz):** giriş/kayıt ekranı, `app/lib/l10n/*.arb`, ilgili test
- **Adımlar:**
  - [x] Etiket: "Frequently asked questions **(SSS)**".
  - [x] Konum: **Sign up'ın altında, en altta**.
- **Migration/Ortam:** Yok · local.
- **Kabul:** Giriş ekranı yerleşim testi · **oturum açmadan** SSS erişimi korunur
  (v55 kazanımı, regresyon olmasın) · dört dil tam.
- **Model önerisi:** Sonnet
- **DoD kanıtı (2026-07-28, Lane C · `Kodda doğrulandı`):**
  - **Konum:** SSS bağlantısı kayıt geçişinin **altına, en sona** taşındı
    (`auth-faq-link`). Yerleşim testi hem "Kayıt ol"un hem "Şifremi
    unuttum"un altında olduğunu ölçüyor.
  - 🔴 **Yol boyunca çıkan ikinci kusur:** bağlantı `if (!_isRegister)` bloğunun
    içindeydi — **kayıt modunda hiç görünmüyordu**. Yani hesap açmaya çalışıp
    takılan kullanıcı yardıma ulaşamıyordu. Artık iki modda da duruyor, testte
    sabit.
  - **Etiket:** kısaltma eklendi — TR "Sıkça sorulan sorular (SSS)",
    EN "Frequently asked questions (FAQ)", DE "Häufig gestellte Fragen (FAQ)",
    AR "الأسئلة الشائعة (FAQ)". Dört dil de testte tek tek doğrulanıyor.
  - **Regresyon koruması:** oturum açmadan SSS ekranının açıldığı (v55 kazanımı)
    ayrı testte tutuluyor.
  - **Test:** `flutter analyze` 0 uyarı · `auth_faq_link_wp422_test.dart` 5/5 ·
    SSS ekranı + auth katalog + l10n borç kapısı ile birlikte 21/21 yeşil.
  - **Cihazda doğrulanmalı:** Giriş ekranında bağlantının en altta görünmesi.

### Faz S — Moderasyon admin tarafı (Faz A) *(docs/MODERASYON-PLANI.md)*

> Bu beş WP **aynı dosyalara** (`features/admin/**`) ve **ardışık migration'lara**
> dokunuyor. Tek lane, sıralı ilerler. Paralelleştirilemez.

#### WP-424: Şikâyet kuyruğunda kimlik okunabilirliği 👤
- **Program/Faz:** PLAN 4 · Faz S · **Ajan:** Lane B · **Durum:** [~] Kod/test tamamlandı · cihaz kabulü bekliyor
- **Problem:** `admin_moderation_tab.dart:76` ham UUID gösteriyor. Kim şikâyet etti,
  kim şikâyet edildi **okunmuyor**. Sahip: *"admin panelinde direkt ID yazmak zor değil mi?"*
- **Kural:** **gösterilen ad · işlem yapılan ID · loglanan ikisi birden.** Adlar değişir
  ve tekrar eder; ad üzerinden işlem yapmak yanlış kişiyi cezalandırmanın en yaygın yolu.
  Desen repoda zaten var: `admin_audit_logs` hem `target_user_id` hem `target_user_email`
  saklıyor (`0020:7`) — kuyruğa uygulanmamış sadece.
- **SAHİP dosyalar (yaz):** `app/lib/features/admin/**`,
  `app/lib/data/repositories/**/admin*`, `**/moderation*`, admin testleri
- **DOKUNMA:** `features/settings/**` (Lane C) · `features/safety/**` (Lane E) ·
  `campfire_scene.dart` (Lane D)
- **Adımlar:**
  - [ ] Ad + avatar göster; hem şikâyet eden hem edilen için.
  - [ ] ID kartın altında **kopyalanabilir** küçük metin olarak kalır.
- **Migration/Ortam:** Yok (mevcut RLS ile okunuyor) · local.
- **Kabul:** Kuyruk testinde ham UUID **başlıkta görünmez** · ad çözülemezse
  "Silinmiş kullanıcı" gösterilir, boş kalmaz.
- **DoD kanıtı (2026-07-28):** `ModerationQueueCard` şikâyet eden ve edilenin
  adını/avatarını gösterir; işlem kimliği başlıkta değil, küçük kopyalanabilir
  metindir. Çözülemeyen profil için yerelleştirilmiş "Silinmiş kullanıcı" yedeği
  vardır. TR/EN/DE/AR anahtarları eklendi; hedefli widget testi (2/2) ve
  `flutter analyze --no-pub` geçti. **Kodda doğrulandı · Cihazda doğrulanmalı.**
- **Model önerisi:** Sonnet

#### WP-425: Şikâyet detay ekranı — tam içerik, bağlam, geçmiş 🔍
- **Program/Faz:** PLAN 4 · Faz S · **Ajan:** Lane B · **Durum:** [~] Kod/test tamamlandı · cihaz kabulü bekliyor
- ⏳ **WP-424'ten sonra** · **WP-423 (`0096`) commit'lenmeden migration numarası alma**
- **Problem:** Sahip: *"bildirse bile ben şu an göremiyorum ne yapmış."* Kuyrukta
  içerik kopyası 3 satırda kesiliyor, bağlam yok, kişinin geçmişi yok. Tek mesaj
  bağlamsız çoğu zaman karar verilemez.
- **SAHİP dosyalar (yaz):** `supabase/migrations/0097_*.sql`, `features/admin/**`,
  admin repo + pgTAP
- **Adımlar:**
  - [ ] Tam `content_snapshot` (kesme yok).
  - [ ] **Bağlam:** şikâyet edilen mesajın çevresindeki ±5 mesaj.
  - [ ] **Geçmiş:** bu hedefe daha önce kaç şikâyet, hangi yaptırımlar.
  - [ ] Şikâyetçinin serbest açıklaması (`details`).
  - [ ] WP-423 eki varsa imzalı URL ile gösterilir (yalnız super-admin).
- **Migration/Ortam:** `0097` · local → staging → production.
- **RLS/Güvenlik:** Bağlam sorgusu **yalnız super-admin**; RPC `is_super_admin()` doğrular.
- **Kabul:** pgTAP: super-admin olmayan bağlam RPC'sini çağıramaz · detayda tam metin
  görünür · geçmişi olmayan hedefte boş durum düzgün.
- **DoD kanıtı (2026-07-28):** `admin_ugc_report_detail` SECURITY DEFINER RPC'si
  önce `is_super_admin()` doğrular; tam snapshot, serbest açıklama, mesaj hedefi için
  en çok ±5 bağlam satırı, hedef rapor sayısı/yaptırım geçmişi ve private ek yolu
  döner. Kart ayrıntıya açılır, metin kesilmeden seçilebilir. `026` pgTAP güvenlik/
  bağlam senaryosunu kapsar; kullanıcı emri gereği migration **uygulanmadı**. Hedefli
  Flutter widget testi 2/2 ve analiz geçti. **Kodda doğrulandı · Cihazda doğrulanmalı.**
- **Model önerisi:** 🔴 Opus

#### WP-426: Basamaklı yaptırım ⚖️
- **Program/Faz:** PLAN 4 · Faz S · **Ajan:** Lane B · **Durum:** [ ] Başlamadı
- ⏳ **WP-425'ten sonra**
- **Problem:** 🔴 Elimizdeki tek yaptırım `ban_duration: '876000h'` — **100 yıl**
  (`admin-user-actions/index.ts:99`). Uyarı yok, geçici susturma yok, süreli askı yok.
  Uygunsuz isim koyan birine karşı tek seçenek kalıcı yasak. Pratikte olan: ceza
  ağır olduğu için hiçbir şey yapılmaz, kuyruk birikir, moderasyon fiilen çalışmaz.
- **Sahip kararı (2026-07-28):** basamaklar **24 saat · 7 · 14 · 30 gün** + kalıcı.
- **SAHİP dosyalar (yaz):** `supabase/migrations/0098_*.sql`,
  `supabase/functions/admin-user-actions/**`, `supabase/functions/admin-operations/**`,
  `features/admin/**`, pgTAP
- **Adımlar:**
  - [ ] Basamaklar: **Uyar** · **Adı sıfırla** · **Sustur 24 saat** ·
        **Askıya al 7 / 14 / 30 gün** · **Kalıcı**.
        `ban_duration` saat kabul ediyor: `24h` / `168h` / `336h` / `720h`.
  - [ ] Hepsi karttan **tek tık**, gerekçe **zorunlu**, `admin_audit_logs`'a yazılır.
  - [ ] Her yaptırım **tek tıkla geri alınabilir**.
  - [ ] "Adı sıfırla" uygunsuz kullanıcı adı **ve grup adı** için ortak yol — grubu
        tamamen silmeye gerek kalmaz.
- **Migration/Ortam:** `0098` · local → staging → production.
- **RLS/Güvenlik:** Yaptırım RPC'leri `is_super_admin()` doğrular; `authenticated`'a kapalı.
- **Kabul:** Her basamak için pgTAP · süre dolunca yasak **kendiliğinden** kalkar ·
  geri alma denetim kaydına ayrı satır yazar · gerekçesiz işlem reddedilir.
- **Tuzaklar:** Süreli banı istemcide zamanlayıcıyla çözme — sunucu tarafında süre dolmalı.
- **Model önerisi:** 🔴 Opus

#### WP-427: Aynı hedefe gelen şikâyetleri tekilleştir 🔢
- **Program/Faz:** PLAN 4 · Faz S · **Ajan:** Lane B · **Durum:** [ ] Başlamadı
- ⏳ **WP-426'dan sonra**
- **Problem:** Aynı kişi 10 kişi tarafından şikâyet edilirse kuyrukta 10 ayrı kart
  çıkıyor. Spam dalgasında kuyruk kullanılamaz hâle gelir.
- **SAHİP dosyalar (yaz):** `supabase/migrations/0099_*.sql`, `features/admin/**`, pgTAP
- **Adımlar:**
  - [ ] Aynı hedef + aynı içerik → tek kart, **"8 şikâyet"** rozetiyle.
  - [ ] Karttan tek işlemle hepsi çözülür/reddedilir.
  - [ ] Farklı sebeplerle gelen şikâyetler kartta ayrı ayrı listelenir.
- **Migration/Ortam:** `0099` · local → staging → production.
- **Kabul:** 10 şikâyet → 1 kart + sayaç · tek işlem hepsinin durumunu değiştirir ·
  pgTAP agregasyon testi.
- **Model önerisi:** Sonnet

#### WP-428: İçerik şikâyetinde admin'e push 🔔
- **Program/Faz:** PLAN 4 · Faz S · **Ajan:** Lane B · **Durum:** [ ] Başlamadı
- ⏳ **WP-427'den sonra**
- **Problem:** Push tetikleyicisi `feedback_tickets` üzerinde (`0090:196`),
  `ugc_reports` üzerinde **değil**. Destek kutusundan gelen şikâyet bildirim atıyor,
  **sohbetten gelen içerik şikâyeti sessizce kuyrukta bekliyor.** Sekme açılmadan haber olmuyor.
- 🔴 **Bu bir mağaza uyum maddesi, kozmetik değil.** Apple App Store 1.2 kullanıcı
  içeriği olan uygulamalardan şikâyetlere **24 saat içinde işlem** istiyor; bildirim
  gelmeden bu garanti edilemez. Google Play UGC politikası da benzer şart koyuyor.
- **SAHİP dosyalar (yaz):** `supabase/migrations/0100_*.sql`, pgTAP
- **Adımlar:**
  - [ ] `_enqueue_support_ticket_admin_push` eşdeğeri `ugc_reports` insert'üne bağlanır.
  - [ ] `event_key` tekilliği korunur (aynı şikâyet iki kez bildirilmez).
  - [ ] WP-427 tekilleştirmesiyle uyumlu: 10 şikâyet → 10 push **değil**.
- **Migration/Ortam:** `0100` · local → staging → production.
- **Kabul:** Yeni içerik şikâyeti → admin cihazına **≤ 60 sn** bildirim · pgTAP outbox
  testi · aynı şikâyet tekrar bildirilmez.
- **Model önerisi:** Sonnet

### PLAN 4 lane dağılımı ve çakışma matrisi

> Beş lane **aynı anda** başlar. Tek dal `main`; her WP **ayrı commit**, yalnız kendi
> SAHİP yolları stage'lenir. Claim'i hemen commit et, ağacı geri ver.
> **Tarihsel PLAN 4 tablosudur; PLAN 5 worker'ları bu eski Lane A–E adlarını
> claim etmez veya Aktif Çalışma Kaydı'na geri getirmez.**

| Lane | WP zinciri | Migration | Başlangıç |
|---|---|---|---|
| **A** — Sayaç senkronu | WP-414 → WP-415 | yok | 🟢 hemen |
| **B** — Moderasyon admin | WP-424 → 425 → 426 → 427 → 428 | 0097–0100 | 🟢 hemen (424 migration'sız) |
| **C** — Destek/ayarlar/rozet | WP-419 → 420 → 421 → 422 | yok | 🟢 hemen |
| **D** — Görsel ve içerik | WP-416 → 417 → 418 | yok | 🟢 hemen |
| **E** — Bozuk düzeltmeler | WP-412 → WP-413 → WP-423 | 0095, 0096 | 🟢 hemen |

| Kısıt | Kural |
|---|---|
| `supabase/migrations/**` | Sıra **sabit**: WP-413 `0095` → WP-423 `0096` → WP-425 `0097` → WP-426 `0098` → WP-427 `0099` → WP-428 `0100`. Aynı anda iki migration WP'si **yok**. |
| Lane B ↔ Lane E | WP-425 `0097`'yi almadan önce **WP-423'ün `0096` commit'i** görünmeli. Tek cross-lane bekleme budur. |
| `features/settings/**` | Yalnız **Lane C**. Sırası: WP-419 → 420 → 421. Başka lane girmez. |
| `features/admin/**` | Yalnız **Lane B**. |
| `features/safety/report_sheet.dart` | Yalnız **Lane E** (WP-423). Lane B eki **okur**, yükleme yolunu yazmaz. |
| `campfire_scene.dart` | Yalnız **Lane D** (WP-416). |
| `android/**/timer/**` + `global_timer_providers.dart` | Yalnız **Lane A**. |
| `features/stats/**` | Yalnız **Lane E** (WP-412). |
| `app/lib/l10n/*.arb` | Dört lane de dokunur. Kural: **kısa ve atomik** düzenle, **hemen commit et**, açık bırakma. 🔴 **Her anahtar dört dilde birden** (TR/EN/DE/AR) — v55'te 13 kırmızı testin birinci nedeni buydu. |
| Migration head pini | `deploy-contract.json`'dan türetiliyor (v55'te kalıcı kapatıldı). Yine de tur sonunda `guard.tests` + `release-preflight.tests` yeşil mi, doğrula. |

**Tur sonu teslim ölçütü:** `flutter analyze` temiz · tüm Flutter testleri yeşil ·
yerel replay `0001→0100` + pgTAP PASS · çevrilmemiş anahtar raporu `{}` ·
staging apply → production apply (sahip GO'su ile) → v56 stable.

---

## PLAN 5 — v57 ÜRÜN GÜVENİ VE MAĞAZA ÖNCESİ SON BÜYÜK TUR

> **Durum:** 🟢 Uygulamaya hazır · dört Codex ajan zinciri A–D.
> **Ürün kaydı:** `docs/V56-SAHIP-GERI-BILDIRIM-RAPORU.md`
> **Birleşik brief:** `docs/V57-YAPILACAKLAR.md`
> **Rakip doğrulaması:** `docs/RAKIPANALIZI-DEGERLENDIRME.md`
> **Ürün sahibi kapsam kararı:** Sayaç/feedback/güvenlik kök sorunları kısa
> yamayla değil mimari incelemeyle çözülür. İlk mağaza runtime'ı TR+EN ve yalnız
> 1×1 Başlat/Durdur widget'ıdır. Store listeleme/submission ürün sahibindedir.
>
> **Lane devralma notu:** Kartlardaki tarihsel Ajan E/F/G/H adları sırasıyla yeni
> A/D/B/C'ye devredilmiştir. Worker yalnız Aktif Çalışma Kaydı'ndaki dört canlı
> A–D zincirini izler; tarihsel lane başlığı açmaz.

### 5.0 Faz ve bağımlılık haritası

| Faz | Ajan / zincir | Başlama | Sert bekleme |
|---|---|---|---|
| 0 — güvenli kapı | WP-429 | ✅ tamam | — |
| A — timer + ders + görev | A · WP-432→433→448→449→451 | WP-432 hemen | WP-449, D/WP-445'i bekler |
| B — feedback + ayarlar/yüzey | B · WP-435→438→459→461 | A/WP-432 sonrası | WP-459, WP-436'yı bekler |
| C — moderasyon + final QA | C · WP-439→443→464→467 | B/WP-435 sonrası | WP-465 öncesi A/B/D çıkış kapıları |
| D — grup + stats/seri | D · WP-444→447→453→455 | C/WP-442 sonrası | WP-453, A/WP-449'u; WP-455, WP-451'i okur |

**Kanonik migration rezervasyonu:** `0101` WP-431 · `0102` WP-432 · `0103`
WP-435 · `0104` WP-439 · `0105` WP-441 · `0106` WP-442 · `0107` WP-444 ·
`0108` WP-445 · `0109` WP-449 · `0110` WP-453 · `0111` WP-464. Her kart uygulama anında en yüksek migration'ı
yeniden ölçer. Önceki rezervasyon gerçekten gereksiz çıkarsa kart bunu testle
kanıtlar, migration oluşturmaz ve sıradaki kart mevcut en yüksek numara + 1'i
alır; boş/uydurma migration yazılmaz.

**Çakışma matrisi:**

| Yüzey | Tek sahibi / sıra |
|---|---|
| Timer Dart + Android native + `study_providers.dart` | yalnız A |
| Feedback tickets/messages | yalnız B |
| Moderation/admin safety | yalnız C |
| Group/nudge/chat membership | yalnız D |
| Task recurrence ve görev UI | yalnız E |
| Stats/streak/goal | yalnız F |
| Settings/auth/l10n/navigation/widget katalog | yalnız G |
| Campfire + final QA belgeleri | yalnız H |
| `supabase/migrations/**` | ortak kilit; yukarıdaki sıra |
| `app/lib/main.dart`, `pubspec.yaml`, navigation, l10n generated, manifest | ortak sıcak-dosya kilidi |
| Tam `flutter test`, local replay, beta cihaz matrisi | tek koşucu; finalde H |

### Faz 0 — Emniyet

#### WP-429 — v56 sonrası deploy/release kapılarını fail-closed kilitle

- **Durum:** [x] Kod + otomatik test tamam · commit `b6b47a9`.
- **Problem:** v56 apply/release sonrası staging ve production kapıları açık
  kalmıştı; yeni bir workflow yanlışlıkla remote mutation veya release
  başlatabilirdi.
- **SAHİP:** `tooling/release/deploy-contract.json`,
  `tooling/supabase/guard.tests.ps1`.
- **Sonuç:** Dört bayrak `false`; hold gerekçeleri güncel. DB/tag/release yok.
- **Kanıt:** deploy guard 75/75; release preflight 8/8.
- **Kural:** Gelecekte kapı ancak hedef SHA/head/project-ref, güncel test/QA ve
  somut sahip GO'suyla açılır; iş bitince aynı turda yeniden kapanır.

### Faz A — Sayaç tek gerçeği ve çoklu cihaz

#### WP-430 — Sayaç olay kaydı, durum makinesi ve yeniden üretim kanıtı

- **Durum / bağımlılık:** [~] **Kod + otomatik test tamam** · Ajan A · commit
  `WP-430` · uçuş kaydının saha çıktısı `Cihazda doğrulanmalı` (Ajan H WP-466).
- **Problem:** Bildirimden ayna durdurma, aralıklı sync, olası kendiliğinden
  başlama ve “8 saat görünüp session yazmama” aynı kökten mi bilinmiyor.
- **SAHİP:** `docs/qa/V57-TIMER-EVIDENCE.md` (yeni),
  `app/lib/core/observability/timer_diagnostic_journal.dart` (yeni),
  `app/lib/core/observability/observability_service.dart`,
  `app/lib/data/providers/global_timer_providers.dart`,
  `app/lib/data/providers/study_providers.dart`,
  `app/android/**/timer/TimerStateStore.kt`,
  `app/android/**/timer/StudyTimerService.kt`,
  `app/test/data/global_timer_*`, `app/test/core/timer_v2_*`,
  salt-okunur inceleme için timer Dart/native/SQL.
- **Uygulama:** start/stop/reconcile/lease/notification/widget/cold-start
  olaylarını tek zaman çizelgesinde tanımla; `account_id`, `run_id`,
  `run_revision`, `state_version`, `origin_device_id`, `command_id`, terminal
  neden ve session sonucu için dönen/TTL sınırlandırılmış, PII'siz yerel
  flight-recorder kur; telemetry kapalıyken cihaz dışına çıkarma; dört hata için
  önce kırmızı test/tekrar üretim senaryosu yaz.
- **Kabul:** “hangi olay otorite, hangi kopya projection” tek diyagramda; hiçbir
  local görünüm server kabulü olmadan yeni aktif run yaratamıyor; görünür ghost
  ile kaydedilmiş session ayrımı kanıtlanıyor; her transition
  `reason + outcome + state_version/queue_age` bırakıyor, ham hesap/run/subject
  kimliği ve mesaj içeriği bırakmıyor.
- **Tuzak:** “bazen oluyor” bulgusunu yok sayma; log eklemek çözüm değildir.
- **Model:** Opus.
- **Sonuç (2026-07-30):** Dört semptomun **tek kökü** kanıtlandı: *kanonik koşu
  kimliğini (`timer_v2_run_id`) yalnız koşuyu başlatan cihaz öğrenir; ayna cihaz
  koşuyu gösterir ama kimliğini edinmez.* Kimliksiz cihazın hiçbir yüzeyi koşuya
  dokunamaz ve **hata da vermez** → S01 (ayna Durdur sessizce düşer), S03 (uzak
  durdurma öğrenilmez), S04 (gece boyu büyüyen, oturumsuz hayalet süre) aynı
  kusurun üç görünümü. S02 komşu kusur: dış komutların ve aynalanan koşuların
  **yaşı** hiçbir yerde ölçülmüyordu.
- **Yeni bulgular (kaynak düzeyinde, daha önce kayıtlı değil):**
  1. `TimerExternalCommand.at` alanı var ama **hiçbir üretici onu yazmıyor** →
     WP-233'ün "app-kapalı Durdur ölü zamanı kesmesin" koruması fiilen ölü;
     oturum sonu uygulamanın açıldığı ana kayıyor (hayalet sürenin 2. kaynağı).
  2. `timer_sync_pending_v1` **yaz-ve-unut**: FCM arka plan isolate'i yazıyor,
     `_stream` isolate'e özel olduğu için ana isolate görmüyor ve diskteki
     değeri okuyan **hiçbir tüketici yok**.
  3. Ayna benimseme koşunun **yaşını/kirasını hiç sorgulamıyor**;
     `GlobalTimerRun` modelinde `lease_expires_at` alanı yok ve
     `_global_timer_v2_snapshot` kirayı süzmüyor (yalnız raporluyor).
  4. Ayna kapanışı (`_finish`) hiçbir oturum yazmıyor ve yazan başka yol da yok.
- **Ne yapıldı:** Otorite/projeksiyon haritası tek diyagramda
  (`docs/qa/V57-TIMER-EVIDENCE.md`); PII'siz, 240 kayıtlık halka tamponlu, 72 sa
  TTL'li **yerel uçuş kaydı** `TimerDiagnosticJournal` (kimlikler tuzlanmış
  12-hex özet, metin kapalı slug sözlüğü, ağ yok); on iki geçiş noktasına
  `reason + outcome + state_version/queue_age` enstrümantasyonu; telemetri açıksa
  yalnız slug+tamsayı çıkaran `ObservabilityService.timerTransition`.
- **Hayalet/oturum ayrımı:** `run_terminal.outcome` artık üç değerli —
  `applied` · `ghost_no_session` · `local_only`; `elapsed_seconds` (görünen) ile
  `session_recorded.elapsed_seconds` (yazılan) farkı hayaletin büyüklüğü.
- **Değişen dosyalar:** `docs/qa/V57-TIMER-EVIDENCE.md` (yeni),
  `app/lib/core/observability/timer_diagnostic_journal.dart` (yeni),
  `app/lib/core/observability/observability_service.dart`,
  `app/lib/data/providers/global_timer_providers.dart`,
  `app/lib/data/providers/study_providers.dart`,
  `app/test/core/observability/timer_diagnostic_journal_test.dart` (yeni),
  `app/test/data/global_timer_v57_repro_test.dart` (yeni).
- **Kanıt:** `flutter analyze` 0 uyarı · journal sözleşmesi 11/11 · tekrar üretim
  paketi 11/11 · mevcut timer/observability regresyonu 51/51 · notifier widget
  testleri 31/31. Native/SQL kaynak dosyasına **dokunulmadı** (salt-okunur
  inceleme); migration yazılmadı, kilit alınmadı.
- **🔴 Tekrar üretim testleri bilerek bugünün KUSURLU davranışını sabitler.**
  Her testin başında `KIRMIZI HEDEF (WP-4NN)` satırı hangi iddianın ters
  çevrilmesi gerektiğini yazar. WP-431/432 bu dosyayı **silmez**, iddiaları
  düzeltilmiş sözleşmeyle değiştirir.
- **Devredilen kararlar:** K1–K8 → `docs/qa/V57-TIMER-EVIDENCE.md` §5
  (K1/K2/K3 → WP-431 · K4/K5/K6 → WP-432 · K7 → WP-431/433 · K8 → WP-433+WP-466).

#### WP-431 — Kanonik timer komut protokolü, offline niyet ve hayalet-run onarımı

- **Durum / bağımlılık:** [~] **Kod + otomatik test tamam** · Ajan A ·
  `0101` yazıldı, migration kilidi bırakıldı · ⏳ **yerel replay bekliyor**
  (Docker motoru bu hostta kalkmadı) · cihaz kabulü Ajan H WP-466.
- **Problem:** Kaynak cihaz stop olduktan sonra ayna cihaz çalışıyor kalabiliyor;
  offline terminal niyet/geçmiş başlangıç süresi ve lease uzlaşması yanlış
  görsel run üretebiliyor.
- **SAHİP:** `app/lib/data/models/global_timer.dart`,
  `app/lib/data/repositories/global_timer_repository.dart`,
  `app/lib/data/repositories/supabase/supabase_global_timer_repository.dart`,
  `app/lib/data/repositories/in_memory/in_memory_global_timer_repository.dart`,
  `app/lib/data/providers/global_timer_providers.dart`,
  `app/lib/core/background/timer_v2_command_outbox.dart`,
  `app/lib/core/background/timer_foreground_service.dart`,
  `app/lib/data/providers/study_providers.dart`,
  `app/android/**/MainActivity.kt`, `app/android/**/widgets/TimerActionReceiver.kt`,
  `app/android/**/widgets/TimerWidgets.kt`,
  `app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/**`,
  `supabase/migrations/0101_*`, `supabase/tests/*global_timer*`, ilgili testler.
- **DOKUNMA:** notification hedef politikası WP-432'dir; eski `0082/0087/0088/
  0089` değiştirilmez.
- **Uygulama:** native state'te açık `controller_role=source|mirror`; mirror için
  `run_id/revision/state_version` atomik saklama; app/bildirim/widget stop'un tek
  karar fonksiyonundan CAS komutu üretmesi; mirror stop'un yerel interval/session
  üretmemesi; source stop'un mevcut finalize semantiğini koruması. Hesap-geneli
  tek aktif run invariant'ı; stale komut reddi; offline start zamanının server
  kabulünde en fazla 24 saat ve gelecek-zaman sınırıyla korunması; `0088`deki
  timer-sync enqueue gövdesinin yeni RPC'de kaybolmaması; terminal stop'un bütün
  projection'larda üstün gelmesi; lease expiry'nin session uydurmaması.
- **Yaşam döngüsü:** logout/hesap değişimi eski hesabın prefs/queue/mirror
  durumunu yeni hesaba taşımaz; boot yalnız doğrulanabilir source local run'ı
  restore eder, stale mirror'ı server doğrulaması olmadan diriltmez; auth/network/
  stale/invalid-schema hataları retry/quarantine/terminal olarak ayrılır.
- **RLS/rollback:** RPC yalnız auth.uid hesabını değiştirir; duplicate command
  tek sonuç; ileri rollback/degrade yolu ve flag kapatma kanıtı.
- **Kabul:** aynı komut 20 kez teslimde tek terminal sonuç; mirror notification/
  widget stop tek server CAS ve **0 ek session/XP** üretir; stop sonrası hiçbir
  restart/cold-start/realtime olayı eski run'ı canlandıramaz; kaydedilen süre ile
  iki cihaz görünümü ±1 sn sözleşmesinde; A hesabından çıkıp B'ye girince A
  timer'ı restore olmaz; bozuk queue diğer sağlam komutları silmez.
- **Test:** hedefli Flutter + native contract + local replay/pgTAP.
- **Model:** Opus.
- **Kök neden (WP-430'dan):** *Kimliği olmayan cihazın hiçbir yüzeyi koşuya
  dokunamıyor ve hata da vermiyordu.* Ayna cihaz koşuyu gösteriyor ama sunucunun
  kimlik biletini (`timer_v2_run_id`) hiç edinmiyordu.
- **Onarım — dört ayak:**
  1. **Rol native tarafta görünür oldu.** `TimerStateStore.KEY_CONTROLLER_ROLE`
     (`source`|`mirror`). Rol eskiden yalnız Dart `state.isGlobalTimerMirror`
     alanındaydı; bildirim/widget Durdur'u native'de çalıştığı için onu
     göremiyordu. Karar artık **girişten değil rolden** türer: `planTimerStop()`
     uygulama içi + bildirim + widget için tek karar noktası.
  2. **Kimlik bileti aynaya da verilir.** `mirrorStart` artık
     `timer_v2_run_id` + `revision` + rol yazar; başarılı ayna Durdur'unda bilet
     **tüketilir** (yoksa `_finish()` ölü koşuya ikinci, zehirli stop üretirdi).
  3. **Hayalet koşu doğmadan kesilir.** Kira farkındalığı (`lease_expired`,
     `0101`de sunucu hesaplar), 12 saatlik yaş sınırı, yeni `needsReconcile`
     direktifi, ekranda duran ölü aynanın kapatılması ve **soğuk açılışta ayna
     diriltmeme** (native `ACTION_DISCARD_PROJECTION` — sunucuya komut GİTMEZ,
     koşunun sahibi başka cihaz olabilir).
  4. **Sessiz yutma bitti.** `classifyGlobalTimerFailure` →
     `retry` | `quarantine` | `terminal`; zehirli zarf kuyruktan düşer, geçici
     hata kaydı korur.
- **Bulunan ek kusurlar (kartta yazılı değildi):**
  * Ayna cihazda bildirim Durdur'u `appendPendingInterval` çağırıyor ve Dart
    açılışta bunu **uydurma bir oturum** olarak yazıyordu.
  * Yerel modu `countdown` olan ayna cihazda `mode == "stopwatch"` kapısı
    durdurma komutunu sessizce düşürüyordu.
  * `effective_started_at` HER ZAMAN `clock_timestamp()` idi: çevrimdışı
    başlatılıp saatler sonra flush edilen koşu başlangıcını flush anına
    kaydırıyordu.
- **`0101` içeriği:** hesap-geneli tek aktif v2 koşusu (kısmi unique index +
  ön temizlik), snapshot'ta `lease_expired`, çevrimdışı başlangıcın kabulü ve
  ≤24 saat/gelecek-yok kırpması, `client_clock_skew_rejected`. `0088`in
  timer-sync enqueue gövdesi birebir korundu; `0082/0087/0088/0089`'a
  dokunulmadı. Head pinleri: `deploy-contract.local_migration_head` → `0101`,
  `001_schema_contract` → 101/`0101`. **staging/production head `0100`'de
  bırakıldı — kapılar kapalı.**
- **Değişen dosyalar:** `supabase/migrations/0101_global_timer_controller_contract.sql`
  (yeni), `supabase/tests/019_global_timer_controller_contract.test.sql` (yeni),
  `supabase/tests/001_schema_contract.test.sql`,
  `tooling/release/deploy-contract.json` (yalnız local head),
  `app/lib/data/models/global_timer.dart`,
  `app/lib/data/providers/global_timer_providers.dart`,
  `app/lib/data/providers/study_providers.dart`,
  `app/lib/core/background/timer_foreground_service.dart`,
  `app/android/**/timer/TimerStateStore.kt`,
  `app/android/**/timer/StudyTimerService.kt`, `app/android/**/MainActivity.kt`,
  `app/test/data/global_timer_controller_contract_test.dart` (yeni),
  `app/test/data/global_timer_v57_repro_test.dart`,
  `docs/qa/V57-TIMER-EVIDENCE.md`.
- **Kanıt:** `flutter analyze` 0 uyarı · WP-431 sözleşmesi 14/14 · tekrar üretim
  paketi 14/14 (kırmızı hedefler ters çevrildi, **silinmedi**) · tam
  `flutter test` 1212'den 1211 yeşil (tek kırmızı Ajan G WP-457 l10n yüzeyi).
  ⏳ **Yerel replay/pgTAP çalıştırılamadı** — Docker motoru bu hostta kalkmadı.
- **Kalan kabul maddeleri:** "aynı komut 20 kez → tek terminal sonuç",
  "0 ek session/XP", RLS ve rollback kanıtı `019_*.test.sql` içinde YAZILI ama
  replay yeşili olmadan **kanıtlanmış sayılmaz**. Cihaz matrisi Ajan H WP-466.

#### WP-432 — Bildirim aksiyon hedefleme ve cihaz-kapsamlı test bildirimi

- **Durum / bağımlılık:** [~] Kod tamamlandı · WP-431 `b78ed1f` sonrası.
- **Problem:** Bir cihazdaki notification STOP'un kaynağa gitmemesi ve
  “bildirim testi”nin hesabın bütün cihazlarına ulaşması aynı target sözlüğünün
  belirsizliğini gösteriyor.
- **SAHİP:** timer notification listener/service/receiver yolları,
  `app/lib/core/notifications/**timer**`,
  `app/android/**/timer/**`, timer-sync payload/Edge tetikleyiciyle ilgili
  mevcut dosyalar, `app/lib/data/models/push_notification.dart`, push repository
  arayüzü + Supabase/InMemory, push providers,
  `supabase/migrations/0102_*` ve pgTAP/testler.
- **DOKUNMA:** announcement/update genel hesap politikası; feedback/moderation
  payload'larını bu WP'ye göre tek-cihaza indirme.
- **Uygulama:** timer komutu hesap-geneli olup origin hariç gerekli cihazlara
  yönelir; cihaz self-test bildirimi yalnız isteği başlatan cihaz token'ına
  gider; `request_push_self_test(p_device_id)` cihaz sahipliği/aktifliği
  doğrular; outbox/delivery açık `target_device_id` veya eşdeğer güvenli hedef
  taşır; payload türü/şema sürümü/target açık; duplicate FCM idempotent.
- **Kabul:** A cihazında start → B notification STOP → A+B en geç 10 sn terminal;
  self-test A'dan → yalnız A; token yok/eskimiş/çift teslim fallback'leri görünür.
- **Yapılan:** `0102_push_device_targeting.sql`, outbox'a isteğe bağlı
  `target_device_id` ekler. Delivery tetikleyicisi hedef varsa yalnız o etkin cihazı
  seçer; hedef yoksa timer-sync için mevcut origin-hariç davranış korunur.
  `request_push_self_test(p_device_id)` yalnız `auth.uid()` sahibi ve etkin cihazı
  kabul eder. Flutter repository/provider çağrısı bu server kimliğini taşır;
  Supabase ve InMemory sözleşmeleri birlikte güncellendi.
- **Kanıt:** `flutter analyze` 0 sorun · hedefli push testleri 11/11 yeşil ·
  yeni `020_push_device_targeting.test.sql` iki cihaz, yabancı/eskimiş hedef ve
  timer-sync origin ayrımını kapsar. Local replay/pgTAP wrapper'ı çalıştırılamadı:
  deploy contract local head `0101`, repo head `0102`; ortak release sözleşmesine
  bu WP'nin SAHİP kapsamı dışında olduğu için dokunulmadı. Etiket:
  **Kodda doğrulandı**; cihazda A→B stop ve A-yalnız self-test **Cihazda doğrulanmalı**.
- **Tuzak:** `origin_device_id` ile “komutu başlatan cihaz” ve “bildirimi görmek
  isteyen cihaz” rollerini karıştırma.
- **Model:** Opus.

#### WP-433 — Timer iki-cihaz otomatik matrisi ve cihaz kabul paketini hazırla

- **Durum / bağımlılık:** [~] Kod + otomatik test tamam · WP-432 `398d002`.
- **SAHİP:** timer integration testleri, `docs/qa/V57-TIMER-EVIDENCE.md`,
  `docs/qa/DEVICE-QA-MATRIX.md` içindeki yalnız timer satırları.
- **Senaryolar:** A start/B stop; B start/A stop; app açık/arka plan/terminated;
  notification/widget/app aksiyonu; internet kes-yeniden bağlan; duplicate ve
  sıra dışı komut; force-stop; reboot; 23:59–00:01; iki cihazda farklı uygulama
  yaşam döngüsü.
- **Kabul:** ghost aktif görünüm 0; duplicate session 0; terminalden sonra
  yeniden canlanma 0; kayıp stop niyeti 0; hedefleme hatası 0. Donanım gerektiren
  satırlar “Cihazda doğrulanmalı” olarak WP-466'ya açık teslim edilir.
- **Kanıt:** 29/29 hedefli Flutter testi yeşil · `flutter analyze` 0 sorun.
  `V57-TIMER-EVIDENCE.md` otomatik sözleşme→fiziksel kabul eşlemesini; cihaz QA
  matrisi A/B yönleri, app/bildirim/widget, yaşam döngüsü, ağ, reboot, gün sınırı
  ve A-yalnız self-test satırlarını içerir. Etiket: **Kodda doğrulandı**;
  iki fiziksel cihaz kanıtı **Cihazda doğrulanmalı** (WP-466).
- **Tuzak:** yalnız tek emülatör veya yalnız happy-path ile kapatma.
- **Model:** Opus.

### Faz B — Feedback konuşması ve okunmamış gerçeği

#### WP-434 — Feedback uçtan uca veri akışı ve konuşma kimliği denetimi

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam · Ajan B · 2026-07-30.
- **Problem:** Mesaj yanlış bilete düşüyor, kayboluyor veya iki yüzeyde farklı
  okunmuş görünüyor olabilir; önce tekil olay akışı kanıtlanmalı.
- **SAHİP:** `docs/qa/V57-FEEDBACK-EVIDENCE.md` (yeni), feedback model/repository/
  provider ve ekran testleri.
- **DOKUNMA:** production code/migration yok.
- **Kodda doğrulanan başlangıç:** ilk mesaj `feedback_tickets.message`,
  devamı `feedback_ticket_messages`, admin yanıt sinyali ayrıca
  `announcements` içinde; rozet bu iki kanalı ayrı sayabiliyor ve konuşma açıkken
  yeni mesajı canlı izlemiyor.
- **Uygulama:** create ticket → user message → admin reply → user reply →
  read/archive/reopen akışında ticket/message/user bağlarını ve realtime
  abonelik yaşam döngüsünü izle; yanlış-thread ve drop için kırmızı test kur.
- **Kabul:** tek mesajın tek kalıcı `message_id` ve tek `ticket_id`si var;
  optimistic geçici kimlik server kimliğiyle tekilleşir; refresh/relogin sonrası
  aynı sıra görülür.
- **Sonuç (denetim):** olay zinciri tek çizelgede yazıldı; dört sözleşme bagı
  (tek `message_id`/`ticket_id`, çapraz-bilet sızıntısı yok, katılımcı sınırı,
  yeniden fetch aynı sıra) regresyon testine bağlandı. Dokuz bulgu
  `B1…B9` olarak sahiplendirildi:
  **B1** biletin ilk mesajı kanonik dizide yok → yazışmada "henüz yanıt yok";
  **B2** gönderim idempotent değil (istemci komut kimliği yok);
  **B3** sıra imleci yok, sıra yalnız `created_at`;
  **B4** tek admin yanıtı iki kanal ürettiği için rozeti **2** artırıyor;
  **B5** okundu yalnız mesaj kanalını kapatıyor, rozet **1**'de asılı kalıyor;
  **B6** yazışma açıkken canlılık yok; **B7** okundu = "fetch edildi";
  **B8** Supabase/InMemory yan etki sapması kusuru testlerde görünmez yapıyordu;
  **B9** push'un `feedback_ticket` yolu ölü (tap payload'ı yönlenmiyor → WP-437
  değerlendirmesi).
- **⚠️ Kart düzeltmesi:** WP-435 karttaki `mark_support_thread_read` RPC'si
  **repoda yok** (supabase/app taramasında sıfır eşleşme); gerçek yol
  `mark_feedback_ticket_messages_read` + duyuru okuma kaydıdır.
- **Kanıt:** `docs/qa/V57-FEEDBACK-EVIDENCE.md` (yeni) ·
  `app/test/features/feedback_flow_wp434_test.dart` (yeni, 10 test).
  `flutter analyze` 0 uyarı; feedback/rozet/admin test kümesi 42/42 yeşil.
  Ürün kodu ve migration **değişmedi**. Etiket: `Kodda doğrulandi`.
- **Model:** Opus.

#### WP-435 — Feedback konuşması için server-authoritative tek gerçek

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam · Ajan B · `355f1dd` · 2026-07-30. Migration `0103` local replay bekliyor.
- **SAHİP:** `feedback_ticket*.dart`, `admin_repository.dart`,
  Supabase/InMemory admin repository, admin providers,
  `supabase/migrations/0103_*`, `supabase/tests/*feedback*`.
- **Uygulama:** ilk mesajı tek sefer kanonik mesaj dizisine backfill; istemci
  `client_message_id` ile idempotent insert; ticket-membership/RLS; server
  ordering cursor; kişi bazlı latest-message/read-watermark projection;
  archive/reopen durumlarının mesaj geçmişini taşımaması; realtime + refresh aynı
  reducer. `mark_support_thread_read` ilişkili eski feedback-announcement
  işaretini de kapatır; yeni admin yanıtı rozet için iki olay üretmez.
- **Kabul:** iki cihaz aynı mesajı eşzamanlı gönderse bile istemci command-id
  başına tek satır; kullanıcı yalnız kendi ticket'ını, admin yetkili kapsamı
  görür; başka ticket'a payload enjekte etme RLS ile reddedilir.
- **Rollback:** eklemeli şema; eski istemci uyumluluğu; flag/degrade planı.
- **Model:** Opus.

#### WP-436 — Okunmamış watermark ve rozet zinciri

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam · Ajan B · `7d191b6` · 2026-07-30.
- **SAHİP:** support providers, unread/badge provider'ları, feedback/profile
  rozet widget'ları ve testleri.
- **DOKUNMA:** `settings_screen` bağlantısı WP-459; core navigation G kilidinde.
- **Uygulama:** unread = karşı tarafın `message_seq > last_read_seq` gerçeği;
  ekranı gerçekten görünür/açık görmek read ack üretir; fetch etmek tek başına
  okundu saymaz; profile/settings rozetleri aynı provider'dan.
- **Canlılık:** Konuşma açıkken Supabase stream/realtime yeni mesajı aynı thread'e
  ekler; yeniden fetch başka ticket'ın listesini mevcut konuşmaya yazamaz.
- **Kabul:** bütün mesajlar görülünce iki rozet ≤1 sn'de 0; yeni karşı taraf
  mesajında ikisi de 1 artar; kullanıcının kendi mesajı unread üretmez; restart,
  ikinci cihaz ve archive sonrası geri gelmez.
- **Tuzak:** iki ayrı local boolean/cache oluşturma.
- **Model:** Opus.

#### WP-437 — Kullanıcı ve admin feedback deneyimini yeniden düzenle

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam · Ajan B · WP-436 `7d191b6` sonrası · 2026-07-30.
- **SAHİP:** `app/lib/features/profile/feedback_screen.dart`,
  `feedback_tickets_screen.dart`, feedback konuşma ekranı, feedback'e özel admin
  görünümü olarak `features/admin/tabs/admin_reports_tab.dart` ve testleri.
- **Uygulama:** bilet listesinde son mesaj/tarih/durum/unread; konuşmada sabit
  thread bağlamı, gönderiliyor/başarısız/yeniden dene; adminde kullanıcı,
  kategori, zaman çizgisi, ek ve yanıt bağlamı okunur.
- **Kabul:** yanlış bilet başlığı altında mesaj çizilemez; başarısız mesaj
  kaybolmaz veya sahte gönderildi görünmez; uzun metin/küçük ekran/text scale
  taşmaz; yükleme/boş/hata/offline durumları vardır.
- **Model:** Sonnet.

#### WP-438 — Feedback E2E ve rozet kapanış kapısı

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam · Ajan B · 2026-07-30. Kanıt: `docs/qa/V57-FEEDBACK-EVIDENCE.md §5`; cihaz satırları C/WP-465-466'da.

- **SAHİP:** feedback integration/widget/contract testleri ve evidence belgesi.
- **Kabul matrisi:** kullanıcı→admin→kullanıcı 20 tur; iki ticket eşzamanlı;
  iki cihaz; reconnect/relogin; duplicate retry; archive/reopen; attachment;
  unread profile/settings. Yanlış thread 0, kayıp mesaj 0, sahte gönderildi 0,
  okunduktan sonra kalan rozet 0.
- **Teslim:** otomatik kanıt + cihazda doğrulanacak satırlar Ajan H WP-465/466'ya.
- **Model:** Opus.

### Faz C — Moderasyon ve UGC güvenliği

#### WP-439 — Mesaj/profil/grup/grup-adı rapor hedef sözleşmesi

- **Durum / bağımlılık:** [x] **Sözleşme + migration dilimi kod ve otomatik test
  tamam** (Ajan C) · B/WP-435 `355f1dd` sonrası migration sırası alındı.
  `0104` bu hostta gerçek replay koşulamadığı için **Replay bekliyor**.
- **Koşulan denetim (Kodda doğrulandı):** Grup detay ekranındaki iki ayrı bayrak
  düğmesi (`report-group-action` ve `report-group-name-action`) aynı
  `('group', group.id)` çiftini gönderiyordu; `0038`'in
  `unique (reporter_id, target_type, target_id, reason)` kısıtı ikisini tek satıra
  çöktürüyordu — grup adı şikâyeti görünmez oluyordu. Mesaj raporu ise grup
  bağlamı taşımıyordu, sunucu ortak üyelik/görünürlük doğrulayamıyordu.
  Profil raporu tarihsel `user` türünü yazıyordu.
- **Bu commit'te yapılan:** `ReportTarget` / `ReportTargetType` değer nesnesi
  (`message|profile|group|group_name`, değişmez kimlik, `caseKey = tür:kimlik`,
  mesajda zorunlu `contextGroupId`, ipucu 200 karaktere kırpılır);
  `ModerationRepository.reportUgc` artık serbest metin çifti değil hedef alıyor;
  Supabase + InMemory çiftleri ve dört çağrı yeri taşındı; `p_snapshot` artık
  “kanıt” değil doğrulanmamış istemci ipucu olarak adlandırıldı.
- **Migration diliminde yapılan (`0104`):** `report_ugc` artık hedefi sunucuda
  yeniden okur — mesajda `p_context_group_id` mesajın gerçek grubuyla ve
  raporlayanın aktif üyeliğiyle doğrulanır, kanonik snapshot server'da üretilir,
  istemci metni yalnız `client_hint` olarak ayrı saklanır. `moderation_cases`
  tablosu + kısmi tekil indeks ile hedef başına tek açık vaka; `group_name`
  sunucuda ayrı tür olarak açıldı ve grup-adı düğmesi `ReportTarget.groupName`e
  çevrildi; Supabase deposundaki fail-closed kapı kaldırıldı. Kanıt alanları
  update trigger'ı ile değişmez; 365 günlük `evidence_retention_until` yazılır.
  Vaka kapandıktan sonra **aynı** raporlayan aynı sebeple tekrar rapor ederse
  satır yeni açık vakaya taşınır ve `open`'a döner — aksi hâlde tekil kısıt
  yüzünden şikâyet kuyrukta hiç görünmezdi.
- **Migration durumu:** `0104` **Replay bekliyor** — bu hostta Docker motoru
  kalkmadığı için local `supabase db reset`/pgTAP koşulamadı. `deploy-contract.json`
  ilerletilmedi (`0101`), staging/production kapalı.
- **Sınır açıklaması (Ajan D'ye):** `showReportSheet` imzası değiştiği için mevcut
  dört çağrı yeri **mekanik olarak** taşındı:
  `class_chat_card.dart`, `class_detail_screen.dart` (x2),
  `social_profile_screen.dart`. Yeni UI girişi eklenmedi, davranış
  değiştirilmedi; mesaj-rapor girişi tasarımı WP-446'da Ajan D'dedir.
- **WP-440'a not:** admin kuyruğu eski `user` satırlarını `profile` olarak
  göstermeli (`ReportTargetType.fromWire` alias'ı hazır).
- **Kanıt:** `flutter analyze` 4 dosya 0 uyarı · hedefli `flutter test` 30/30
  yeşil (`test/data/report_target_contract_test.dart`, `report_sheet_details`,
  `moderation_block_filter`, `test/features/safety/**`) · pgTAP
  `supabase/tests/029_moderation_report_target_contract.test.sql` 15 iddia
  (replay bekliyor). Etiket: **Kodda doğrulandı** · cihaz kabulü WP-443/WP-466.
- **Problem:** Kullanıcı grup sohbetindeki tek mesajı seçip raporlayamıyor;
  adminin gördüğü bağlam hedef türüne göre tutarlı değil.
- **SAHİP:** moderation models/repository/provider, `features/safety/**`,
  `supabase/migrations/0104_*`, moderation/report pgTAP, ilgili testler.
- **Uygulama:** hedef türleri `message|profile|group|group_name`; immutable hedef
  kimliği + güvenli snapshot + report reason/detail. İstemci snapshot'ı kanıt
  sayılmaz; RPC hedefi, ortak aktif grup üyeliğini ve görünürlüğü doğrulayıp
  kanonik snapshot'ı server'da üretir. `moderation_cases` ile açık vaka başına
  hedef tekilliği; kapanan vakadan sonraki rapor yeni vaka; tekrar politikası,
  RLS ve admin-only ayrıntı.
- **Kabul:** rapor hedefi yanlış tür/ID ile başka içeriğe bağlanamaz; raporlayan
  kişi karşı tarafın gizli/e-posta verisini göremez; mesaj silinse bile gerekli
  kanıt retention politikasınca korunur.
- **DOKUNMA:** grup sohbetindeki UI entry Ajan D WP-446.
- **Model:** Opus.

#### WP-440 — Admin kuyruğu kartı, durum çipi ve sabit yerleşim

- **Durum / bağımlılık:** [x] **Kod + otomatik test tamam** (Ajan C) · WP-439 `e240e91`.
- **Koşulan denetim (Kodda doğrulandı):** Ekran `Supabase.instance.client` ile
  doğrudan konuşuyordu: `ugc_reports` select, `class_messages` + `profiles`
  okumaları ve **doğrudan tablo UPDATE'i** ile durum yazımı. Vaka sözleşmesi
  (`admin_ugc_report_groups` / `admin_set_ugc_report_group_status`) hiç
  kullanılmıyordu; kuyruk vaka başına değil rapor başına satır gösteriyordu.
- **Bu commit'te yapılan:** `AdminModerationRepository` (yeni, Ajan B'nin
  `admin_repository.dart`ından ayrı) + Supabase/InMemory çiftleri +
  `admin_moderation_providers.dart`; ekran `ConsumerWidget`e döndü ve artık
  hiçbir tabloya dokunmuyor. `ModerationCase` + `ModerationCaseStatus` modeli
  WP-439'un `caseKey` sözleşmesini sürdürüyor; eski
  `moderation_queue_report.dart` kaldırıldı.
- **Kabul kanıtı:** kart yüksekliği dört durumda birebir aynı (ölçüldü, tek
  değer); 320 dp ve 600 dp × metin ölçeği 1.3'te taşma yok; çip
  `Semantics(button)` etiketli; üç nokta yalnız kimlik kopyalama taşıyor;
  sunucu hatası şeride düşüyor ve kuyruk çökmüyor.
- **Geri alma kararı:** “yanlışlıkla close geri alınabilir” geçici şeride değil
  **kalıcı duruma** bağlandı: kapatılan vaka kuyruktan düşmüyor, çipi etkin
  kalıyor ve tek dokunuşla `İnceleniyor`a dönüyor (test edildi). Sunucu RPC'si
  `open` yazamıyor; `open` menüde ölü seçenek olarak durmuyor ve istemci
  fail-closed reddediyor. Tam `open` restorasyonu WP-441 `0105` dilimine yazıldı.
- **Kartın karşılanmayan maddesi:** `risk`, `atanan admin` ve `SLA` şemada
  **yok** (WP-441 severity/SLA migration'ı getirecek). Sahte rozet basmak yerine
  meta satırı gerçek olan iki değeri gösteriyor: bekleme süresi + rapor sayısı.
- **l10n:** yeni `.arb` anahtarı eklenmedi, sıcak kilit alınmadı.
- **Kanıt:** hedefli `flutter analyze` 0 uyarı · `flutter test` 47/47 yeşil
  (admin + moderasyon + güvenlik). Etiket: **Kodda doğrulandı** · cihaz kabulü
  WP-443/WP-466.
- **SAHİP:** `features/admin/tabs/admin_moderation_tab.dart`,
  yeni ayrı admin-moderation repository arayüzü + Supabase/InMemory/provider,
  `features/admin/widgets/moderation_queue_card.dart` ve testleri.
- **Kod borcu:** Mevcut ekranın doğrudan
  `Supabase.instance.client.from(...)` okuma/yazmaları kaldırılır; mevcut
  `admin_ugc_report_groups()` ve `admin_set_ugc_report_group_status()` vaka
  sözleşmesi üzerinden kullanılır/geliştirilir. Feedback'in
  `admin_repository.dart` dosyası paylaşılmaz.
- **Uygulama:** kartta hedef, raporlayan, kategori, risk, zaman, atanan admin,
  SLA ve mevcut durum; `Open / Under review / Closed` seçimi doğrudan durum
  çipinden; üç nokta yalnız ikincil eylemler; detail timeline.
- **Kabul:** durum seçenekleri arasında kart yüksekliği/tipografisi sıçramaz;
  320–600 dp, text scale 1.3 ve uzun isimde taşma yok; klavye/ekran okuyucu
  label'ları var; yanlışlıkla close geri alınabilir.
- **Model:** Sonnet.

#### WP-441 — Basamaklı yaptırım, karantina, önem ve kötü niyetli rapor

- **Durum / bağımlılık:** [x] **Kod + otomatik test tamam** (Ajan C) · WP-440
  `30559d7`, WP-439 migration `7726627`. `0105` bu hostta gerçek replay
  koşulamadığı için **Replay bekliyor**.
- **Koşulan denetim (Kodda doğrulandı):** `admin-user-actions` Edge Function'ında
  `warn_user` **hiçbir şey yapmıyordu** — yönetici uyardığını sanıyor, kullanıcıya
  hiçbir kayıt ya da bildirim gitmiyordu. `mute_24h` ise 24 saatlik **auth ban**
  kuruyordu: "yalnız yazma kısıtı" diye sunulan basamak kullanıcıyı uygulamadan
  tamamen atıyordu. Aksiyonlar vaka kimliği, idempotency anahtarı ve durum
  taşımıyordu; auth çağrısı başarılı olup audit insert'i düşerse kayıt kaybolur,
  yönetici tekrar denediğinde ikinci ceza uygulanırdı. `revoke_sanction` hangi
  yaptırımı kaldırdığını bilmeden ban'ı topluca siliyordu. Karantina, severity,
  SLA ve kötü niyetli rapor sayacı hiç yoktu.
- **Bu commit'te yapılan:** `0105` ile `moderation_sanctions` defteri (iki fazlı
  `pending → applied|failed`, tekil `idempotency_key`, hedef başına **tek aktif
  kısıt** kısmi indeksi), `admin_begin/finish/revoke_moderation_sanction` ve
  `admin_reconcile_moderation_sanctions`; audit satırı kapanışla **aynı
  transaction'da** yazılır. Susturma artık auth ban değil: `class_messages`
  insert politikasına `moderation_is_muted` eklendi, okuma açık kaldı. Uyarı
  gerçekten iletiliyor (kalıcı satır + `notification_outbox`). Vakaya
  `severity`/`sla_due_at` ve geri alınabilir karantina alanları eklendi;
  `class_messages` select politikası karantinayı sunucuda uyguluyor (yazar ve
  admin görmeye devam eder). `admin_ugc_report_groups` artık `moderation_cases`
  üzerinden okuyor ve `case_id`/`severity`/`sla_due_at`/`quarantined` döndürüyor;
  vakaya bağlanmamış tarihsel satırlar ikinci kolda korunuyor.
  `admin_set_ugc_report_group_status` `open`'ı da yazıyor (WP-440 kod borcu).
  İstemci tarafında `ModerationAction`/`ModerationSanction` sözleşmesi, depo
  çiftleri, yaptırım sayfası, karantina menüsü ve önem/SLA rozetleri eklendi.
- **Sınır:** Otomatik yaptırım yok — severity yalnız sıralama/SLA içindir,
  hiçbir rapor kendiliğinden ceza doğurmaz. Ajan B'nin `admin_repository.dart`
  ve kullanıcı sekmesi değiştirilmedi; ortak `app_*.arb`'a yalnız 19 admin
  moderasyon anahtarı eklendi.
- **Kanıt:** `flutter analyze` 8 hedef 0 uyarı · hedefli `flutter test` 73/73
  yeşil (`test/features/admin/**`, `report_target_contract`, `safety/**`,
  `moderation_block_filter`, `report_sheet_details`) · `python
  scripts/l10n_audit.py` C yüzeyinde temiz (kalan tek bulgu A'nın
  `study_providers.dart` satırı) · pgTAP `030_*` 19 iddia (replay bekliyor).
  Etiket: **Kodda doğrulandı** · cihaz kabulü WP-443/WP-466.
- **SAHİP:** moderation repository/provider, admin action UI,
  `supabase/migrations/0105_*`, `supabase/tests/*moderation*`.
- **Uygulama:** no-action; kullanıcıya gerçekten iletilen warn; adı sıfırla;
  24 saat yalnız-yazma mute (okuma açık, auth ban değil); 24 saat/7/14/30 gün
  suspend; kalıcı ban; her birinin geri alma yolu. Her aksiyon vaka kimliği,
  actor, reason ve idempotency key taşır; auth işlemi başarılı/audit başarısız
  yarım durumunu uzlaştıran action-state kurulur. Yüksek riskli içeriği review
  bitene kadar geri alınabilir karantina; severity/SLA; kötü niyetli rapor sayacı.
- **RLS:** istemci yaptırım yazamaz; yalnız yetkili admin RPC; audit append-only;
  hedef kullanıcı başka raporların kimliğini göremez.
- **Kabul:** yaptırım iki kez uygulanınca tek aktif sonuç; süre dolunca doğru
  geri açılma; karantina görünürlüğü server policy ile; “rapor geldi = otomatik
  suçlu” yok.
- **Model:** Opus.

#### WP-442 — İtiraz, kanıt saklama ve denetim zinciri

- **Durum / bağımlılık:** [x] **Kod + otomatik test tamam** (Ajan C) · WP-441
  `27609c6`. `0106` bu hostta gerçek replay koşulamadığı için **Replay bekliyor**.
- **Koşulan denetim (Kodda doğrulandı):** WP-441 sonrası yaptırım uygulanıyordu
  ama kullanıcı tarafında **hiçbir yüzey yoktu**: kişi kararın nedenini,
  süresini ya da itiraz yolunu göremiyordu. `admin_audit_logs` yalnız
  `action`+`reason` tutuyordu — eski/yeni değer yoktu, vaka ve itiraz hiç
  kaydedilmiyordu. Kanıt (`canonical_snapshot`) süresiz duruyordu ve raporlayan
  kendi satırında sunucunun ürettiği kanıt gövdesini okuyabiliyordu; `0104`
  kanıtı tamamen dondurduğu için saklama süresi dolsa bile imha edilemiyordu.
- **Bu commit'te yapılan:** `0106` ile `moderation_audit_events` append-only
  zinciri (actor/zaman/eski/yeni/gerekçe; `update`, `delete` **ve** `truncate`
  tetikleyiciyle kapalı) ve vaka/yaptırım/itiraz tetikleyicileri.
  `moderation_appeals`: yaptırım başına **tek** itiraz, `submit_moderation_appeal`
  yalnız hedefin kendisine açık (başkasının yaptırımının varlığı sızmaz),
  `admin_decide_moderation_appeal` yaptırımı uygulayan yöneticiyi
  `appeal_conflict_of_interest` ile reddediyor ve karar idempotent (`overturned`
  yaptırımı yalnız bir kez kaldırır). Kanıt tarafında `evidence_hash` (sha256) +
  `evidence_redacted_at`, açık itirazda saklama süresinin ileri atılması,
  `moderation_purge_expired_evidence` ile içerik imhası (imza kalır) ve
  `ugc_reports` üzerinde sütun bazlı okuma kısıtı — kanıt gövdesi hiçbir normal
  kullanıcıya açık değil. İstemcide `ModerationAppeal` sözleşmesi, kullanıcı
  tarafında "Hesabındaki kısıtlar" bölümü + itiraz sayfası, yönetici tarafında
  itiraz kuyruğu ve çıkar çatışması notu eklendi.
- **Sınır:** Kullanıcı girişi güvenlik ekranının (Ayarlar → Engellenen
  kullanıcılar) üstündedir; ayarlarda ayrı bir "Güvenlik" girişi B/WP-459'un
  yüzeyidir, C oraya dokunmadı — WP-465'e devredilir.
- **Kanıt:** `flutter analyze` 0 uyarı · hedefli `flutter test` 93/93 yeşil
  (`test/features/admin/**`, `test/features/safety/**`,
  `report_target_contract`, `moderation_block_filter`, `report_sheet_details`) ·
  `python scripts/l10n_audit.py` C yüzeyinde temiz · pgTAP `031_*` 18 iddia
  (replay bekliyor). Etiket: **Kodda doğrulandı** · cihaz kabulü WP-443/WP-466.
- **SAHİP:** moderation appeal/evidence/audit model-repository ekranları,
  `supabase/migrations/0106_*`, pgTAP ve testler.
- **Uygulama:** kullanıcıya yaptırım nedeni/süresi ve itiraz yolu; itirazı aynı
  kararı veren admin dışında inceleyebilme; evidence hash/snapshot retention;
  her durum/yaptırım değişikliği actor/time/old/new/reason ile append-only.
- **Kabul:** geçmiş audit değiştirilemez/silinemez; itiraz sonucu yaptırımı
  idempotent kaldırır veya onar; yetkisiz kullanıcı evidence okuyamaz.
- **Model:** Opus.

#### WP-443 — Moderasyon abuse, RLS ve uçtan uca kabul kapısı

- **Durum / bağımlılık:** [x] 2026-07-31 · WP-442.
- **SAHİP:** moderation contract/integration testleri ve
  `docs/qa/V57-MODERATION-EVIDENCE.md`.
- **Matris:** mesaj/profil/grup/ad raporu; duplicate; blocked users; silinmiş
  içerik; yüksek risk; karantina; yaptırım/expiry; itiraz; malicious reporter;
  iki admin race; normal kullanıcı admin RPC denemesi.
- **Kabul:** RLS kaçışı 0; kayıp audit 0; aynı eylemde çift yaptırım 0; yüksek
  risk açık kuyruğa SLA ile düşer; kapatılan kart filtrelerde tutarlı.
- **Sonuç (2026-07-31):** `supabase/tests/035_moderation_abuse_matrix.test.sql`
  (29 iddia) + `docs/qa/V57-MODERATION-EVIDENCE.md`. Matrisin sekiz senaryosu
  `026`–`031`'de zaten kilitliydi; `035` eksik dördünü (profil raporu, silinmiş
  içerik, çok-raporlayan yüksek risk, yaptırım süresi) ve iki yeni invaryantı
  (iki admin yarışı, kötü niyetli raporlayan sayacı) ekledi.
- **🔴 Matrisin bulduğu gerçek açık:** `report_ugc`'nin profil dalı görünürlüğü
  `can_see_user_sessions` ile ölçüyordu; o yardımcı `0095`'ten beri
  `is_blocked_pair` içerir ve engel **simetriktir**. Yani taciz eden kişi
  kurbanını engellediği anda kendi profilini/adını **raporlanamaz** yapıyordu —
  ve mesaj dalı etkilenmediği için delik tam olarak uygunsuz ad/avatar
  şikâyetlerini yutuyordu. `0110_moderation_report_block_immunity.sql` rapor
  yoluna `moderation_can_report_profile` kapısını koydu: ortak grup şartı aynen
  duruyor, engel kontrolü rapor yolundan çıktı. Kapsam dar tutuldu —
  `can_see_user_sessions` değişmedi ve `035` bunu ayrıca iddia ediyor.
- **RLS kaçışı 0 nasıl ölçüldü:** tek tek `throws_ok` yerine `pg_proc`
  süpürmesi — her `public.admin_*` fonksiyonu `is_super_admin` taşımak
  zorunda. Yeni bir admin RPC'de kapı unutulursa iddia düşer; yanına "küme boş
  değil" koruması (≥ 15) kondu.
- **Model:** Opus.

### Faz D — Grup işlemleri ve dürtme

#### WP-444 — Kişi bazlı yalnız dürtme sessize alma

- **Durum / bağımlılık:** [x] TAMAMLANDI · Faz 1 `b61038e` · Faz 2 bu commit (migration `0107` + pgTAP `032` + susturma yönetim ekranı). Kapılar açıldı: C/WP-442 `f93859d` migration sırasını bıraktı, B `a9e2a7e` ile sekiz l10n anahtarını açtı.
- **Faz 2 kanıtı (Ajan D, 2026-07-30):** `0107_nudge_mutes.sql` — `nudge_mutes` tablosu (yalnız kendi tercihini okuyan RLS), okunamaz `nudge_suppressed_attempts` (policy yok = deny all), `mute_nudges_from`/`unmute_nudges_from`/`nudge_mute_directory` RPC'leri ve `send_nudge`'ın susturma dalı. Yan kanal kapalı: satır yazılmadığı için `0066`'daki `nudges_enqueue_push` AFTER INSERT trigger'ı tetiklenmez (realtime + outbox susar), cooldown penceresi bastırılmış denemeleri de saydığı için ikinci deneme aynı `nudge_cooldown` hatasını alır. Blok muafiyeti (grup sahibi/süper admin) susturmaya bilinçli olarak uygulanmaz. UI: `features/safety/muted_nudges_screen.dart` — engelleme listesinden ayrı ekran, kapsam açıklaması boş listede de görünür. Test: nudge yüzeyi 14 + ekran 3 = **17/17 yeşil**, hedefli analyze temiz. pgTAP `032_nudge_mute_contract.test.sql` (14 assert) yazıldı; bu hostta Docker kalkmadığı için **Replay bekliyor**. Ayarlar → Güvenlik girişi B/WP-459 kapsamında bağlanacak.
- **Faz 1 kanıtı (Ajan D, 2026-07-30):** `NudgeRepository` susturma sözleşmesi + `NudgeMute` modeli + iki repository implementasyonu + `mutedNudgeSenderIdsProvider` / `nudgeMutesProvider` + bildirim dinleyicisinde ikinci katman süzgeç. Yan kanal kapalı: susturulmuş alıcıya gönderimde dönen satır ve cooldown davranışı normal durumla aynı. Test: `nudge_mute_test.dart` (6) + `nudge_repository_test.dart` (3) + `nudge_notification_listener_test.dart` (5) = 14/14 yeşil; analyze nudge yüzeyinde 0 uyarı. Kanıt etiketi: **Kodda doğrulandı**.
- **Faz 2 tasarım kararı (sabit):** `nudge_mutes(user_id, muted_sender_id, created_at)` + `mute_nudges_from` / `unmute_nudges_from` / `nudge_mute_directory` RPC'leri; `send_nudge` susturulmuş alıcı için **satır/realtime/outbox üretmez**, fakat gönderene normal bir satır döndürür ve cooldown penceresini yine işler (bastırılmış deneme kaydı) — aksi hâlde "ikinci dürtme hemen kabul edildi" farkı tercihi ifşa ederdi.
- **SAHİP:** nudge model/repository/provider/notification service,
  kişi/grup etkileşim ayarı UI'si, `supabase/migrations/0107_*`,
  `supabase/tests/*nudge*`, ilgili testler.
- **Uygulama:** `muted_sender_id` hesap-kapsamlı tercih; engellemeden bağımsız;
  kullanıcı geri açabilir; server `send_nudge` muted alıcıya nudge satırı,
  realtime olayı **ve** outbox üretmez. Gönderen bu tercihi okuyamaz.
- **Kabul:** susturulan kişi mesaj/profil/grup açısından engellenmez, yalnız
  dürtmesi gelmez; diğer kişiler gelir; ikinci cihazda tercih eşit; saldırgan
  istemci RPC ile bypass edemez.
- **Model:** Opus.

#### WP-445 — Gruptan çıkış için idempotent, anlık ve geri bildirimli işlem

- **Durum / bağımlılık:** [x] TAMAMLANDI · bu commit · WP-444 `a84a799` + migration kilidi C/WP-442 `f93859d` ile açıldı; `0108` alındı.
- **Kanıt (Ajan D, 2026-07-30):** `0108_leave_group_command.sql` — `leave_group(p_group_id, p_command_id)` yalnız `auth.uid()` ile çalışır; `group_leave_commands` idempotency tablosu ve kullanıcı+grup bazlı `pg_advisory_xact_lock` sayesinde aynı anahtar işi tekrar yapmaz. Çıkış soft-delete'tir (`0008`), böylece `0079`'daki `group_members_primary_group_reconcile` trigger'ı `left_at` UPDATE'inde ateşlenir ve birincil grup uzlaşması aynı işlemde olur; `group_live_presence` satırı da aynı işlemde silinir (ayrılan kişi kamp ateşinde asılı kalmaz). Sahiplik değişmezi: `groups.created_by` gruptan çıkamaz (`owner_must_transfer_or_delete`), son yönetici için ayrı güvenlik ağı var; UI zaten sahibe düz çıkış yerine silme yolunu gösteriyor. İstemci: `GroupLeaveOutcome` (`left`/`alreadyLeft`) — çevrimdışı retry sahte hata göstermez; `_LeaveGroupTile` meşgul koruması, 10 sn timeout ve **aynı anahtarla** retry sunar. Kart iyimser liste silmeyi öneriyordu; kabul kriteri "başarısızlıkta sahte çıkmış görünmez" ağır bastığı için satır ancak sunucu onayından sonra kaldırılıyor, görünür geri bildirim meşgul göstergesiyle veriliyor. Test: repository 6 + widget 2 + grup yüzeyi regresyonu = **67/67 yeşil**, hedefli analyze temiz. pgTAP `033_leave_group_command.test.sql` (11 assert) yazıldı; bu hostta Docker kalkmadığı için **Replay bekliyor**.
- **SAHİP:** group repository/provider,
  `features/classroom/widgets/class_detail_screen.dart` içindeki üyelik/çıkış UI,
  `supabase/migrations/0108_*`, group pgTAP ve testleri.
- **Uygulama:** `leave_group(group_id, command_id)` RPC'si `auth.uid()` ve server
  zamanı kullanır; idempotency key; ilk tapta buton busy/disabled;
  optimistic list removal + server doğrulaması; timeoutta açık retry; primary
  group uzlaşması, presence ve son-admin/owner kuralları atomik. Grup sahibi
  sahipsiz grup bırakamaz; devretme/silme yolu açık.
- **Kabul:** 20 hızlı tap tek leave; ≤1 sn görünür geri bildirim; başarı sonrası
  app restart beklemeden grup kaybolur; başarısızlıkta sahte çıkmış görünmez;
  ikinci cihaz üyeliği tutarlı.
- **Tuzak:** yalnız `Future` bekletip butonu aktif bırakma; membership delete ile
  block/ban kavramlarını karıştırma.
- **Model:** Opus.

#### WP-446 — Grup bilgi sadeleştirmesi, kavram ayrımı ve mesajı raporla UI'si

- **Durum / bağımlılık:** [x] 2026-07-31 — WP-445; rapor UI bağı için WP-439.
- **SAHİP:** `features/classroom/widgets/class_chat_card.dart`,
  `features/classroom/widgets/class_detail_screen.dart`,
  `features/classroom/classroom_screen.dart`, grup sohbet/üyelik testleri.
- **Uygulama:** alt “Grup bilgileri → davet kodu” tekrarını kaldır; davet kodu
  tek kanonik yerde kalsın; başka kullanıcının mesajında 48 dp görünür eylem
  menüsüne Raporla ekle (uzun basma tek keşif yolu olmasın); sessize
  alma/kişiyi engelleme/gruptan çıkarma/grup yasağı/guruptan çıkma metin ve
  davranış olarak ayrı.
- **Kabul:** davet kodu yinelenmez; her eylem doğru kapsamı açıklar; message
  report WP-439 target kimliğiyle açılır; admin yetkisi olmayan kick/ban göremez.
- **Model:** Sonnet.
- **Sonuç (2026-07-31):** `classroom_screen.dart` içindeki `_GroupManagementTile`
  paneli (63 satır) tamamen kaldırıldı; davet kodunun tek kanonik yeri artık
  `ClassDetailScreen` → Bilgiler kartı. İki kopya **eşdeğer değildi**: alttaki
  yalnız kopyalıyordu, detaydaki ayrıca *kodu yenileyebiliyordu* — yani
  "tekrar" değil, eksik bir ikinci kopyaydı.
  Sohbette başkasının mesajına görünür 48 dp `more_vert` düğmesi eklendi; uzun
  basma ikinci yol olarak korundu. Eylem sayfasındaki Bildir/Engelle satırları
  artık kapsam alt metni taşıyor (`safetyReportKapsam`, `safetyBlockKapsam`).
  **Bulunan hata:** grup yasağı düğmesi `safetyBlock` ("Engelle") metnini
  kullanıyordu ve onay diyaloğu çıkarmayla birebir aynı cümleyi gösteriyordu;
  yönetici "kişiyi engelliyorum" sanıp geri dönüşü olmayan bir grup yasağı
  koyabilirdi. Yasak artık `classroomUyeyiYasakla` + `Icons.gavel_outlined`,
  ayrı başlık/mesaj ve kapsam cümlesiyle geliyor.
  8 yeni l10n anahtarı (EN+TR). Test:
  `test/features/classroom/group_action_scope_wp446_test.dart` (6 test) —
  **gerçek** in-memory grup + iki ek üye ile kurulur; boş üye listesi ya da
  yalnız-kurucu satırı yüzünden iddiaların boşa düşmesi engellendi.
  Mutasyonla doğrulandı (`classroomUyeyiYasakla` → `safetyBlock` ⇒ kırmızı).
  Kapılar: `flutter test` 1346/1346, `flutter analyze lib test` temiz,
  `l10n_audit.py` OK 1474.

#### WP-447 — Grup yarış koşulu ve güvenlik kabul matrisi

- **Durum / bağımlılık:** [x] 2026-07-31 — WP-446.
- **SAHİP:** group/nudge/chat integration testleri ve QA belgesi.
- **Matris:** 20× leave tap, offline leave/retry, iki cihaz, primary group,
  last-admin, ban/block/mute, muted nudge, message report, restart.
- **Kabul:** duplicate mutation 0; gecikmiş “sonradan çıkmış” görünüm 0; muted
  nudge bypass 0; kavramlar arası istenmeyen yan etki 0.
- **Model:** Opus.
- **Sonuç (2026-07-31):** matris iki uçtan kuruldu —
  `app/test/data/group_race_matrix_wp447_test.dart` (17 senaryo) ve
  `supabase/tests/036_group_departure_matrix.test.sql` (26 iddia); kanıt belgesi
  `docs/qa/V57-GROUP-RACE-MATRIX.md`. pgTAP 536 → 562.
  **Bulunan hata 1 (ciddi):** WP-445 çıkışı RPC'ye taşıdı ama ESKİ KAPIYI
  kapatmadı. `members_update_self` politikası (`0008`) authenticated her
  istemcinin `group_members` satırına doğrudan `left_at` yazmasına izin
  veriyordu; bu yol advisory lock'u, komut anahtarını, presence temizliğini ve
  **sahiplik kontrolünü** atlıyor. Grup sahibi kendini çıkarabiliyordu → sahipsiz
  grupta davet kodu yenilenemez, üye çıkarılamaz, grup silinemez. Aynı boşluk
  istemcide de vardı (`removeMember` hiçbir şey sormuyordu).
  `0111_group_membership_departure_guard.sql`: `before update of left_at`
  trigger'ı iki değişmezi yazma yolundan bağımsız kılar — sahip çıkışı her
  yoldan reddedilir, kendi çıkışı yalnız `leave_group` RPC'sinden geçer
  (transaction-local bayrak). Yöneticinin başkasını çıkarması, ban ve yeniden
  katılım bozulmadı; üçü de testte ölçülüyor.
  **Bulunan hata 2:** bellek-içi `watchUserGroups`/`watchMembers`/
  `watchPrimaryGroupPreference` hiç kapanmayan bir controller üzerinde
  `async*` + `await for` kullanıyordu; `subscription.cancel()` hiç
  tamamlanmıyor, iptal eden test 30 sn'de zaman aşımına düşüyordu. İki cihazlı
  senaryonun bugüne dek yazılmamış olmasının sebebi muhtemelen buydu.
  **Bulunan hata 3:** model eşzamanlılıkta sunucudan ayrışıyordu — komut anahtarı
  `await`ten sonra kaydediliyordu, 20 eşzamanlı tapte 19'u `already_left`
  dönüyordu (sunucuda advisory lock hepsine `left` verir). Anahtar artık senkron
  ayrılıyor.
  İki mutasyonla doğrulandı (sahip muhafızı kaldır, anahtar kaydını geri al ⇒
  2 kırmızı). Kapılar: `flutter test` 1364/1364, `flutter analyze lib test`
  temiz, guard.tests 75/75, release-preflight 8/8.
  **Dağıtım:** `0111` *replay bekliyor* — yerel head 0111, staging/production
  head **0100** (değişmedi), dağıtım kapıları kapalı.

### Faz E — Ders seçimi ve görevler

#### WP-448 — Son seçilen dersin hesap/cihaz yaşam döngüsünde korunması

- **Durum / bağımlılık:** [x] Ajan A · `WP-448` · WP-433 tamam. Ajan E bu karta yazmaz.
- **SAHİP:** `app/lib/data/providers/study_providers.dart`, timer/task subject
  seçim UI'si, yeni selected-subject persistence testleri.
- **Uygulama:** kullanıcı özel ders seçince değiştirilene/silinene kadar,
  hesap-kapsamlı cihaz-yerel `selected_study_subject.<userId>` tercihiyle koru;
  “Genel” seçimi de kalıcı; silinen/erişilemeyen derste tek sefer açıklamalı
  fallback; logout/hesap değişiminde sızıntı yok. `_kActiveSubject` yalnız aktif
  koşu snapshot'ıdır, kalıcı tercih olarak yeniden kullanılmaz; global mirror
  koşusunun server subject'i yerel tercihle ezilmez.
- **Kabul:** restart ve ekranlar arası geçişte ders kalır; aynı hesapta beklenen
  sync politikası belgeli; başka hesap önceki seçimi görmez.
- **Model:** Sonnet.

#### WP-449 — Her N günde sabit fazlı tekrarlanan görev motoru

- **Durum / bağımlılık:** [~] Dart katmanı `3f97e8b`; sunucu ayağı **WP-472 ile kapandı** (`0109` + `034` + `user_task_rpc_contract_wp472_test`, 2026-07-31 denetimiyle doğrulandı). Kalan tek şey cihaz kabulü → WP-466.
- **🔴 Açık eksik (denetim, 2026-07-31):** `supabase_user_task_repository`
  `upsert_user_task(p_interval_days, p_anchor_date)` ve
  `set_user_task_completion(p_occurrence_day)` çağırıyor; bu parametreler hiçbir
  migration'da tanımlı değil (`0048` tek tanım). Gerçek Supabase oturumunda görev
  oluşturma bu hâliyle çalışmaz, `intervalDays`/`anchorDate` sunucuya gidip gelmez.
  Testler yalnız `InMemoryUserTaskRepository`'yi sürdüğü için boşluk otomatik
  kanıtla görünmüyor. ✅ **WP-472 ile kapandı (2026-07-31):** `0109` +
  `034_user_task_recurrence_contract` + `user_task_rpc_contract_wp472_test`.
- **SAHİP:** `user_task.dart`, task repository arayüzü + Supabase/InMemory,
  providers, `core/tasks/**`, `supabase/migrations/0109_*`,
  `supabase/tests/*task*`, ilgili testler.
- **Uygulama:** `interval_days >= 1`, sabit `anchor_date`, Europe/Istanbul gün
  sınırı; tamamlama yalnız o occurrence'ı kapatır; sonraki tarih
  `anchor + k*N`, tamamlanma zamanından kaymaz. Fizik→kimya→biyoloji gibi üç
  ayrı 3-günlük görev farklı anchorlarla dönüşebilir.
- **Kabul:** 1-gün mevcut davranış korunur; 3-gün görev bugün tamamlanınca yarın
  gelmez, sabit üçüncü günde gelir; offline/clock change/23:59/00:01/undo ve
  duplicate completion deterministik.
- **RLS:** kullanıcı yalnız kendi görevini/occurrence'ını değiştirir.
- **Model:** Opus.

#### WP-450 — Görev bilgi mimarisi, satırdan tamamlama ve geri alma

- **Durum / bağımlılık:** [~] `42e0ac7` ile indi · WP-449'un sunucu eksiği WP-472/`0109` ile kapandı (doğrulandı). Kalan tek şey cihaz kabulü → WP-466.
- **Kanıt (2026-07-31):** bölüm modeli + görev IA testleri dahil hedefli koşum
  44/44 yeşil, `flutter analyze` temiz. B'nin `4e6995b` ile açtığı yedi
  `taskList*` anahtarı kullanılıyor; bu commit arb'ye yazmadı.
- **SAHİP:** `features/clock/tasks_screen.dart`,
  `features/home/widgets/tasks_card.dart`, göreve özel widget/model view
  dosyaları ve testleri.
- **Uygulama:** “Bugün”, “Tekrarlanan”, “Diğer” anlaşılır bölümleri; tüm satır
  tap tamamlar, ikincil düzenle/sil kontrolü tap ile çakışmaz; snackbar/inline
  undo aynı occurrence'ı geri getirir; loading double-tap koruması.
- **Kabul:** 48 dp; screen reader state; yanlış tap undo; uzun başlık/text scale
  taşmaz; completed bölümünden geri alma; offline pending görünür.
- **Model:** Sonnet.

#### WP-451 — Görev/başarım/grup ilerlemesi görev tarafı kabul matrisi

- **Durum / bağımlılık:** [x] 2026-07-31 — WP-450 (WP-449'un sunucu eksiği WP-472/`0109` ile kapandı).
- **SAHİP:** task/subject integration tests ve QA belgesi.
- **Matris:** 1/2/3/7 gün cadence, DST bağımsız İstanbul günü, offline, undo,
  silinen ders, iki cihaz, duplicate tap, task completion'ın achievement/group
  projection etkisi.
- **Kabul:** occurrence kaybı/çifti 0; cadence drift 0; undo sonrası ilerleme
  uzlaşması doğru; Ajan F WP-455'in okuyacağı fixture açık.
- **Model:** Opus.
- **Sonuç (2026-07-31):** `app/test/data/task_progress_matrix_wp451_test.dart`
  (15 senaryo) + `docs/qa/V57-TASK-PROGRESS-MATRIX.md`. Sunucu eşi WP-472'de
  açılan `034` (21 iddia). Matris: 1/2/3/7 gün cadence, faz izolasyonu, İstanbul
  gün sınırı (23:59 / 00:01), eski DST geçiş tarihleri, çevrimdışı yazma hatası,
  hızlı çift tap, undo→redo, `operationId` replay ve çelişki, iki cihaz, silinen
  ders, çalışma süresi izolasyonu.
  **Bulunan hata testte çıktı (kodda değil):** ilk yazdığım "geç tamamlama fazı
  kaydırmaz" testi, fazı `completionDay`e kaydıran mutasyonu YAKALAMADI. Sebep
  yapısal — tamamlama yalnız döngü günlerinde mümkün olduğu için
  "anchor = tamamlama günü" ile "anchor + k*N" ileriye doğru **aynı kafesi**
  üretiyor; iki farklı uygulama gözlemlenebilir aynı sonucu veriyordu. Yani
  kartın *cadence drift 0* kriteri hiç bağlanmamıştı. Fark ancak kafes dışı bir
  `completionDay` varken (eski/bozuk kayıt, saat oynaması) görünür; yeni test o
  durumu kuruyor ve mutasyon tekrar uygulandığında kırmızıya döndü.
  Kapılar: `flutter test` 1379/1379, `flutter analyze lib test` temiz.

### Faz F — İstatistik ve seri

#### WP-452 — Sürüklenebilir iki uçlu tarih aralığı

- **Durum / bağımlılık:** [~] KOD + OTOMATİK TEST TAMAM · Ajan F · cihaz kabulü bekliyor.
- **SAHİP:** `features/stats/widgets/draggable_date_range_picker.dart`,
  `stats_period_bar.dart`, stats period provider ve ilgili testler.
- **Uygulama:** iki görünür handle ve yalnız handle sürükleme; sıradan gün/track
  tap'i başlangıç veya bitişi sessizce değiştirmez. Başlangıç/bitiş
  çaprazlanma politikası deterministik; klavye/ekran okuyucu için açıkça seçilen
  endpoint'e ait ayrı erişilebilir eylem bulunur. `PersonalStatsView` içindeki
  ikinci stock `showDateRangePicker` kaldırılır/aynı tek seçiciye bağlanır.
- **Kabul:** 14–30 aralığında 21'e basmak/sürüklemek 14–21 üretir; başlangıcı
  istemeden 21 yapmaz; minimum/maksimum/tek gün/RTL/text scale davranır.
- **Tuzak:** kullanıcı yalnız eski noktaya tıklama semantiğini istemiyor; sırf
  açıklama tooltip'i ekleyip bırakma.
- **Kanıt (2026-07-30):** picker testleri 11/11, `test/features/stats` 33/33 ve
  hedefli analyze temiz. Tam `flutter test` WP-452 dışındaki
  `timer_diagnostic_journal_test` ile `timer_background_reconcile_test` yüzünden
  1146 testte 2 hata verdi; cihazda sürükleme doğrulanmalı.
- **Model:** Sonnet.

#### WP-453 — Hedef tamamlamasına dayalı server-authoritative seri motoru

- **Durum / bağımlılık:** [x] 2026-07-31 — FAZ 1 + FAZ 2 tamam. (Kart `0110` diyordu; o numarayı WP-443 aldı, sunucu ayağı **`0112`**.)
- **Problem:** Seri uygulamayı açmakla veya kısmi çalışmayla ilerlememeli.
- **SAHİP:** goal/streak model/repository/provider, `core/stats/**streak/goal**`,
  kişisel/grup progression RPC'leri, `supabase/migrations/0110_*`, pgTAP/testler.
- **Semantik:** Gün N hedef tamamlandı → streak artar. Gün N+1 tamamlanmadı →
  streak korunur/grace. Gün N+2 tamamlanmadan önce tamamlanırsa eski seriden
  devam eder; iki ardışık hedef günü kaçarsa sıfırlanır. Bu tek seferlik joker
  değil, her tek kaçırmada tekrar uygulanır. Gün hesabı Europe/Istanbul/grup
  bölgesi kanonuna uyar.
- **Parity:** Önce saf Dart durum makinesi/fixture; sonra aynı fixture SQL
  projection'a. `tamamla-boş-tamamla-boş-tamamla = streak 3`. Mevcut tüketilen
  bakiye modeli `streak_freezes` ile otomatik tek-gün grace karıştırılmaz.
  Geçmiş manuel session seri sonucunu değiştiriyorsa kullanıcı etkisini görür;
  sessiz geriye dönük değişim yapılmaz.
- **Kabul:** sadece app open, timer start veya kısmi süre artış üretmez; duplicate
  goal event çift artış üretmez; kişisel ve grup serisi ayrı ledger/key kullanır.
- **Faz 1 kanıtı (2026-07-30):** `goal_completion_v1` JSON parity fixture +
  saf Dart projection + salt-okunur repository + InMemory adapter. Hedefli
  test 11/11, hedefli analyze temiz. `0110`, Supabase adapter/provider ve pgTAP
  yazılmadı; WP-449 şeması sonrası aynı fixture SQL'e uygulanacak.
- **Faz 2 sonucu (2026-07-31):** `0112_goal_streak_projection.sql`
  (`goal_progress_events` + `record_goal_completion` + `goal_streak_projection`),
  `supabase/tests/037_goal_streak_projection.test.sql` (25 iddia, pgTAP 562 →
  587), `SupabaseGoalStreakRepository`, `goal_streak_providers.dart` ve
  `app/test/data/goal_streak_parity_wp453_test.dart` (8 test).
  **Sunucu-otoritesi nerede:** `record_goal_completion` istemcinin "tamamladım"
  iddiasını kabul etmez; `study_sessions`'tan günün toplamını okuyup hedefle
  karşılaştırır ve altındaysa `false` döner, satır yazmaz. Gelecek güne yazma
  `goal_day_in_future` ile reddedilir (cihaz saatini ileri almak işe yaramaz).
  Çift artış uygulama katmanında değil ŞEMADA engelli:
  `unique (scope_type, scope_id, event_kind, goal_day)`.
  `app_opened` / `timer_started` / `partial_progress` kayıtta durur ama
  projeksiyona girmez — kartın birincil şikâyeti buydu.
  **İki uç bağlandı:** parity testi fixture'daki her vaka adının `037` içinde
  geçtiğini ve Dart RPC parametre adlarının `0112` imzasıyla birebir olduğunu
  doğrular; iki mutasyonla sınandı (SQL parametre adını değiştir, pgTAP'ten vaka
  adını sil ⇒ 2 kırmızı).
  Kapılar: `flutter test` 1387/1387, `flutter analyze lib test` temiz,
  guard.tests 75/75, release-preflight 8/8. **`0112` replay bekliyor**; yerel
  head 0112, staging/production **0100** (değişmedi).
- **Model:** Opus.

#### WP-454 — Üç alev durumu ve kişisel/grup ayrımı

- **Durum / bağımlılık:** [x] 2026-07-31 — WP-453 (Faz 2 `0112` ile kapandı).
- **SAHİP:** streak/goal UI, kişisel ve grup hedef kartları,
  `core/stats/progression_visuals.dart`, ilgili widget/golden testleri.
- **Durumlar:** (1) bugün hedef tamamlandı: canlı alev; (2) bugün henüz süre var:
  sönük/gri alev; (3) dün kaçtı, bugün tamamlanmazsa seri bitecek: alev üzerinde
  okunabilir grace işareti (`=` yalnız erişilebilirlikte de anlaşılırsa).
- **Kabul:** durum yalnız server projection'dan; kişisel ve grup renk/çerçeve/
  label ile ayırt edilir, yalnız renge dayanmaz; küçük kartta işaret okunur;
  dark/light ve text scale golden'ları.
- **Model:** Sonnet.
- **Sonuç (2026-07-31):** `features/stats/widgets/goal_streak_flame.dart` +
  `app/test/features/stats/goal_streak_flame_wp454_test.dart` (12 test, 3
  golden). Durum yalnız `GoalStreakProjection.state`ten okunur; widget tarih/saat
  bilmiyor. Kapsam ayrımı üç katmanlı: renk + çerçeve biçimi (kişisel yuvarlak,
  grup köşeli 2px) + rozet metni; ekran okuyucu "Grup · 5 · Bugün tamamlanmazsa
  seri bitecek" gibi tek cümle duyar. Grace rengi bilerek kırmızı DEĞİL (v49
  sahip notu: kırmızı rozet kırmızı temada kayboluyor). 6 yeni l10n anahtarı.
- **🔴 Golden'ların sınırı (mutasyonla ölçüldü, tahmin değil):** renk/boşluk/tema
  değişikliğinde üç golden de kırmızıya döner, ama **İKON değişikliğini hiçbiri
  görmez** — `flutter test` gerçek MaterialIcons fontunu yüklemez, glifler boş
  kutu çizilir, yani `warning_amber_rounded` ile `local_fire_department`
  golden'da birebir aynıdır. Kartın "yalnız renge dayanmaz" kabulünü bu yüzden
  golden değil, `Icon.icon` alanını doğrudan okuyan `her durum ayrı ikon taşır`
  testi taşıyor. Bu uyarı test dosyasının başına da yazıldı; ikisini karıştırıp
  golden'a güvenen biri ayrımı sessizce kaybeder.
  Kapılar: `flutter test` 1399/1399, analyze temiz, l10n OK 1480.

#### WP-455 — Seri ve bütün ilerleme kabul matrisi

- **Durum / bağımlılık:** [x] 2026-07-31 — WP-454 + WP-451 fixture.
- **SAHİP:** stats/streak/goal/achievement/group progression testleri ve
  `docs/qa/V57-PROGRESSION-EVIDENCE.md`.
- **Matris:** tamamlandı/kısmi/açıldı; tek kaçırma/iki kaçırma; tekrar grace;
  kişisel/grup farklı hedef; iki cihaz; 23:59/00:01; manual/native/pomodoro/
  countdown session; task completion/undo.
- **Kabul:** yanlış artış 0, çift XP/reward 0, kişisel-grup sızıntısı 0,
  UI/server state farkı 0.
- **Model:** Opus.
- **Sonuç (2026-07-31):** `app/test/data/progression_matrix_wp455_test.dart`
  (34 test) + `supabase/tests/038_progression_matrix.test.sql` (20 iddia,
  pgTAP 587 → 607) + `docs/qa/V57-PROGRESSION-EVIDENCE.md` (27 satırlık
  matris). Yeni migration YOK; head `0112`de kalır.
  **Yalnız sunucuda kanıtlanabilen satırlar** `038`e düştü: kişisel ve grup
  FARKLI hedeflerle aynı günde farklı sonuç verir (alpha 5400 sn ile 180 dk
  kişisel hedefi geçemez, grup 9000 sn ile 120 dk hedefini geçer), grup hedefi
  üye toplamıdır, gün sınırı kapsamın saat dilimine göre kesilir (23:59/00:01),
  `live`/`manual` eşit sayılır ve hedefe TAM eşitlik kabul edilir.
  Mutasyonla sınandı: grace kaldırma ⇒ 7 kırmızı, kapsam türünü düşürme ⇒
  1 kırmızı (bkz. evidence §3 — o mutasyonu neden tek testin yakaladığı).
- **🔴 Kapanmayan kabul — sahip kararı bekliyor:** `UI/server state farkı 0`
  SAĞLANMIYOR. Repo'da üç ayrı `seri` tanımı var ve aynı geçmişte farklı sayı
  veriyorlar: `goal_streak_projection` (`0112`) **3**,
  `_achievement_metrics.streak_days` (`0025` gövdesi) **1**,
  `currentStreakWithFreezes` (`gamification.dart`) bakiyeye göre **1 veya 3**
  — üstelik tüketilebilir `streak_freezes` bakiyesinden düşerek, ki WP-453
  kartı bu karışımı açıkça yasaklıyordu. Bugün sahada çelişki görünmüyor çünkü
  `GoalStreakFlame`in `lib/` içinde çağrı yeri yok; alev bir ekrana
  yerleştirilmeden önce kapatılmalı. **Kapatmadım** çünkü tek anlamlı yön
  `streak_days`i grace'li yapmaktır ve `fire_streak` XP kademeleri
  (7/30/150/365/730/1000) o metrikten beslendiği için değişiklik mevcut
  kullanıcıların kademesini geriye dönük yükseltir — ekonomi kararı.
  İki uçta da ayrışmayı pinleyen birer test var; hizalandığında kasten
  kırmızıya dönerler. Ayrıntı: `docs/qa/V57-PROGRESSION-EVIDENCE.md` §4.

### Faz G — Ayarlar, hesap, dil ve yayın yüzeyleri

#### WP-456 — Hakkında ile Versiyon ve Güncellemeleri birleştir

- **Durum / bağımlılık:** [x] TAMAMLANDI · `cfb9536` · Ajan G.
- **SAHİP:** settings menü bağlantıları, `features/profile/about_screen.dart`,
  `features/updater/release_notes_screen.dart`, updater/release notes testleri,
  l10n sıcak kilidi.
- **Uygulama:** tek “Hakkında ve Güncellemeler” girişi; sürüm/build, güncelleme
  kontrolü, release notes, yasal/destek bağlantıları hiyerarşik tek sayfa;
  dağıtım kanalına göre sideload güncelleme güvenliği korunur.
- **Kabul:** iki yinelenen ayar yok; mevcut updater işlevi kaybolmaz; Play
  kanalında yasak self-update yolu görünmez. About/release-notes testleri CI
  tuzağına karşı hem `env.json` define'lı hem define'sız hedefli koşar.
- **Kanıt:** `env.json` tanımlı About/Settings/Release Notes 22/22; tanımsız
  About/Release Notes 19/19; Play ağ çağrısı/self-update 0 ve test 1/1;
  updater/dağıtım regresyonu 18/18; değişen Dart/test dosyalarında hedefli
  analyze 0 bulgu. Ortak tam analyze ve l10n audit, diğer aktif lane'lerin
  sahip dosyaları nedeniyle kırmızı; bu WP dosyalarında raporlanan bulgu 0.
- **Model:** Sonnet.

#### WP-457 — İlk mağaza runtime'ını yalnız Türkçe ve İngilizceye sınırla

- **Durum / bağımlılık:** [~] KOD + HEDEFLİ OTOMATİK TEST TAMAM · Ajan G ·
  WP-456 `cfb9536` · commit hazırlanıyor.
- **SAHİP:** `app/l10n.yaml`, `core/l10n/app_locale.dart`, system localization,
  dil seçimi UI, generated l10n ve testleri; DE/AR kaynaklarını repo içinde
  generator dışı dormant konuma taşıma.
- **Uygulama:** yalnız resolver değil, `AppLocalizations.supportedLocales` ve
  release generator girdisi de tam `[en,tr]`; mevcut DE/AR `.arb` içerikleri
  silinmez, dormant arşivde korunur; eski tercihi de/ar olan kullanıcı EN
  fallback alır; native widget/notification fallback EN.
- **Kabul:** yeni/upgrade kurulumda runtime DE/AR'a geçemez;
  `supportedLocales == [en,tr]`; TR/EN eksiksiz; l10n audit yeşil; hardcoded
  Türkçe 0.
- **Tuzak:** resolver bugün zaten TR/EN diye işi bitmiş sanma; generated liste
  iş öncesinde dört dili içeriyordu.
- **Kanıt:** DE/AR `.arb` kaynakları generator dışı dormant arşivde; temiz
  generator listesi tam `[en,tr]`; eski `german`/`arabic` tercihleri ve sistem
  locale'leri EN'e düşüyor. Define'lı hedefli test 58/58, define'sız 12/12;
  tam analyze temiz; native audit 66 EN/TR anahtar + varsayılan EN temiz.
  Genel l10n audit'in tek kalan bulgusu Ajan D'nin sahip olduğu
  `class_detail_screen.dart:90`; Ajan G dosyalarında hardcoded kullanıcı metni 0.
- **Model:** Sonnet.

#### WP-458 — Güvenli e-posta değiştirme ve yeniden doğrulama

- **Durum / bağımlılık:** [x] KOD + OTOMATİK TEST TAMAM · Ajan G · bu commit ·
  WP-457 `c671011`.
- **SAHİP:** `data/repositories/auth_repository.dart`,
  Supabase/InMemory auth repository, `features/profile/account_settings_screen.dart`,
  auth/account testleri, gerekirse deep-link mevcut auth yüzeyi.
- **Uygulama:** repository'de güvenli `changeEmail(currentPassword, newEmail)`
  benzeri tek sözleşme; eski doğrulamasız `updateEmail` UI yolu bırakılmaz.
  Hassas işlem öncesi recent-login/şifre ile yeniden doğrulama;
  yeni e-postaya Supabase doğrulama; pending/confirmed/expired/cancelled açık;
  eski e-posta doğrulanmadan aniden kaybolmaz; provider kullanıcı bilgisini
  refresh eder. Projenin auth sağlayıcısı desteklemiyorsa özel “kod uydurma”
  yapılmaz; platformun güvenli doğrulama akışı kullanılır.
- **Kabul:** yanlış şifre/expired session/reused link reddedilir; başarı
  relogin/restart sonrası kalır; başka hesap verisi sızmaz; hata Türkçe ve
  eyleme dönük.
- **Kanıt:** eski `updateEmail` yolu yok; Supabase şifre reauth → `updateUser`
  sırası, `emailRedirectTo`, provider `newEmail` pending alanı ve uygulama içinde
  özel OTP üretmeme kaynak sözleşmesiyle kilitli. Pending/confirmed ayrı sonuç;
  expired/cancelled/reused link sağlayıcı tarafından reddedilir ve UI eski
  adresin doğrulamaya kadar geçerli kaldığını açıklar. 45/45 hedefli test yeşil;
  hedefli analyze 0 bulgu.
- **Model:** Opus.

#### WP-459 — Ayarlar ve profil rozetlerini tek feedback gerçeğine bağla

- **Durum / bağımlılık:** [x] `59fde3e` ile tamamlandı (kart denetimde güncellendi, 2026-07-31).
- **SAHİP:** settings/profile feedback menü tile'ları, navigation rozet bağlantısı
  ve testleri; l10n/navigation sıcak kilidi.
- **Uygulama:** ayrı cache/boolean kaldır; iki yüzey WP-436 provider'ını izler;
  screen visibility/read ack dışında rozet sıfırlanmaz.
- **Kabul:** feedback WP-438'in bütün rozet senaryoları profile/settings ve tab
  seviyesinde aynı sayıyı gösterir.
- **Model:** Sonnet.

#### WP-460 — Alt sekmelerde gereksiz üst başlık/boşluğu kaldır

- **Durum / bağımlılık:** [x] `a619044` ile tamamlandı (kart denetimde güncellendi, 2026-07-31).
- **SAHİP:** `core/navigation/home_shell.dart` ve ilgili ev/araçlar/gruplar/
  stats/profile ekranları (`home_screen.dart`, `clock_screen.dart`,
  `classroom_screen.dart`, `stats_screen.dart`, `profile_screen.dart`) +
  test/golden.
- **Uygulama:** yalnız başlık tekrar eden 100px sınıfı alanları kaldır; grup
  değiştir ve kart düzenle gibi gerçek eylemleri kompakt içerik toolbar/
  floating/inline yere taşı; safe area korunur.
- **Kabul:** her sekmede ilk anlamlı içerik belirgin biçimde yukarı gelir; eylem
  kaybolmaz; back/scroll/navigation state kırılmaz; 320–600 dp ve desktop
  davranışı testli.
- **Model:** Sonnet.

#### WP-461 — Yayında yalnız 1×1 Başlat/Durdur widget'ını göster

- **Durum / bağımlılık:** [x] `9989d88` ile tamamlandı · cihaz kabulü C/WP-465'te.
- **Kanıt (2026-07-31):** katalog + manifest iki uçlu sözleşme testi; test
  `AndroidManifest.xml`'i gerçekten okuyup `published` bayrağıyla karşılaştırıyor,
  iki taraf ayrışırsa düşüyor. Dormant beş sağlayıcı silinmedi, yalnız
  `android:enabled="false"` ile yayından düştü; geri açmak tek nitelik.
- **SAHİP:** Android widget receiver/provider config, `res/xml/*widget_info.xml`,
  manifest entries, `features/android_widgets/**`,
  `features/clock/clock_widgets_screen.dart` ve testler.
- **Uygulama:** Flutter katalog allowlist'i ve Android manifest receiver listesi
  yalnız kabul edilen 1×1 `TimerWidgetProvider`ı yayınlar;
  diğer beş widget kod/asset'i revizyon için repoda dormant tut; kurulu eski
  instance/upgrade davranışı güvenli; yanlış receiver export/permission yok.
- **Kabul:** temiz kurulum picker'ında tek Odak widget'ı; start/stop cold-start
  çalışır; diğer beş yeni eklenemez; mevcut kullanıcıda crash/boot loop yok.
- **Tuzak:** beş widget'ı silme veya yeniden tasarlama.
- **Model:** Opus.

### Faz H — Kamp ateşi, gözlemlenebilirlik ve final kapı

#### WP-462 — Kamp ateşi 4/8 kişi kompozisyon düzeltmesi

- **Durum / bağımlılık:** [!] Kompozisyon kodu `78e15cb` ile indi · 🔴 **golden'lar kırmızı**, WP-471 kapatacak.
- **🔴 Kart düzeltmesi (denetim, 2026-07-31):** aşağıdaki "44/44 yeşil · golden'lar
  güncellendi" satırı **doğru değildi.** Tam koşumda `campfire_sky_golden_test`
  beş golden'da düşüyor: `campfire_sky_day/transition/night`,
  `campfire_phone_4`, `campfire_phone_8` — fark %1.70–%6.44, tolerans %0.5
  (`flutter_test_config.dart`). Bu platform rasterı payının çok üstünde, yani
  gerçek bir kompozisyon farkı; toleransı yükseltmek yasak.
  Ayrıca WP-462 üç kez commit'lendi: `50be50a` preview golden'larını değiştirdi,
  `5fc8249` aynı dosyaları aynen geri aldı (net sıfır), kompozisyon kodu ise
  `78e15cb`tedir. İki preview golden hâlâ commit edilmemiş üçüncü bir varyantta.
- **SAHİP:** `features/classroom/widgets/campfire_scene.dart`,
  `campfire_layout.dart`, `widgets/campfire/**`, campfire test/golden/assets.
- **Uygulama:** dört kişide isim-hayvan çakışmasını kaldır; üst sırayı gerektiği
  kadar yukarı; mevcut `ringDropPixels` gibi ateş ve bedenleri birlikte taşıyan
  kola güvenmeden ayrı `fireOnlyYOffset` ile **yalnız ateşi** biraz aşağı;
  mevcut iki `pair` yerine dört bağımsız dairesel seat; öndeki hayvanları “iki
  çift masa” görünümünden çıkar; sekiz kişiyi ayrı değerlerle tune/test et.
- **Kabul:** isim bounding-box ile hayvan/fire overlap 0; hayvan clipping 0;
  320/360/412/600 dp, text scale, 1/4/8 kişi; animasyon golden'ında kare sabit.
- **Otomatik kanıt:** ~~hedefli kamp ateşi paketi 44/44 yeşil; golden'lar yeni
  kompozisyon için güncellendi.~~ **Geçersiz** — yukarıdaki kart düzeltmesine bakın.
  Hedefli paket yeşil olabilir; `campfire_sky_golden_test` o pakette değildi.
- **Tuzak:** eski dikey clamp hatasını geri getirme; ateşi indirirken hayvanı
  birlikte kaydırma. Golden kırmızıysa doğru yol `test/features/failures/`
  altındaki görüntüye bakmaktır — toleransı yükseltmek değil.
- **Model:** Sonnet.

#### WP-463 — Çökme, donma ve sessiz hata gözlemlenebilirliği

- **Durum / bağımlılık:** [x] WP-462; `main.dart` sıcak kilidi alındı ve bırakıldı.
- **SAHİP:** mevcut logging/error boundary/bootstrap yüzeyleri, gerekiyorsa
  `main.dart`/`pubspec.yaml`, privacy/redaction testleri,
  `docs/qa/V57-OBSERVABILITY.md`.
- **Uygulama:** Flutter async/platform/native kritik error capture; timer,
  feedback, leave ve moderation için correlation ID + sonuç sınıfı; PII, token,
  message body ve secret redaction; offline buffer/limit ve opt-out/privacy
  politikası. Sağlayıcı eklemek için credential commit edilmez.
- **Kabul:** kontrollü hata testte yakalanır; kullanıcı eylemi başarısızsa sessiz
  başarı görünmez; redaction testi sır/PII bulmaz; crash sağlayıcısı hazır değilse
  local structured log + entegrasyon kapısı açıkça belgeli.
- **Kanıt:** hedefli observability testi (6 test) ve analiz yeşil; QA/sağlayıcı
  kapısı `docs/qa/V57-OBSERVABILITY.md` içinde. Cihazda gerçek sağlayıcı kabulü
  credential ve cihaz oturumu gerektirdiğinden bu WP'de çalıştırılmadı.
- **Model:** Opus.

#### WP-464 — Hesap silme hardening, scheduler ve veri yaşam döngüsü kabulü

- **Durum / bağımlılık:** [x] 2026-07-31 — Faz 1 (`0113`), Faz 2 (`0114`) ve
  staging aktivasyonu tamam. WP-463/WP-442 kapalı.
- **Staging koşu kanıtı (kartın kapanma şartı):** apply run `30660596728`
  (post-check `local|remote|file = 0114`), aktivasyon run `30661167492`.
  Sağlık: `configuration_status: "configured"`, uçtan uca
  `{"processed":0,"dry_run":true,"message":"no due jobs"}`. `0114`'ün
  backfill'i ilk kez gerçek veriyle koştu ve geçti. Tek seferlik GO tüketildi,
  `deploy_enabled` tekrar `false` (`ec77347`); production HOLD'da (`0100`).
- **SAHİP:** `supabase/functions/purge-accounts/**`,
  `supabase/migrations/0113_*` (rezervasyon `0111`'di; uygulama anında en
  yüksek migration `0112` olduğu için kartın kendi kuralıyla +1 alındı),
  Deno/integration testleri, hesap-silme retention ve Play gate belgeleri.
- **Faz 1 kanıtı:** `docs/qa/V57-ACCOUNT-PURGE-EVIDENCE.md`;
  `supabase/tests/039_account_purge_scheduler.test.sql` (28 iddia).
- **🔴 Kök bulgu (kodda doğrulandı):** purge zamanlayıcısı **hiç yoktu** —
  `purge-accounts` yazılmıştı ama onu çağıran ne cron ne workflow vardı, yani
  14 günü dolan istek hiçbir şeye dönüşmüyordu (regresyon değil, WP-113'ten
  beri ölü). `0113` `0069` deseniyle bağladı.
- **Faz 2 — blokaj çözüldü (`0114`):** `public` → `auth.users` arasında 7 adet
  `not null` + `on delete restrict` FK `deleteUser`'ı düşürüyordu; en genişi
  `feedback_ticket_messages.sender_id` (`0074`, `sender_role` 'user' de
  olabiliyor → **destek biletine tek mesaj yazmış sıradan kullanıcı bile
  silinemiyordu**). Sahip kararı (2026-07-31): *"takma kimlikle korunsun,
  set null + hash"* → `HESAP-SILME-RETENTION-KARARI.md` §5.6'ya kaydedildi.
  `0114` yedi tabloya `*_hash` (not null) ekledi, FK'leri `on delete set null`
  yaptı, tetikleyicilerle hash'i canlı tutuyor. Hash `0113`
  `account_purge_audit.user_hash` ile aynı inşa. Sözleşme: `040` (12 iddia,
  gerçek silme ile uçtan uca), `039` §7 çevrildi.
- **İstemci null güvenliği:** sütunlar nullable olunca 4 model çökerdi;
  `senderId`/`adminId`/`createdBy` `String?` yapıldı. `feedback_tickets_screen`
  içindeki `own: senderId == user?.id` karşılaştırması da düzeltildi — iki
  taraf da NULL olunca başkasının mesajı "benim" gibi hizalanıyordu.
- **Kapsam ayrımı (bilinçli):** kullanıcının **kendi** içeriği (kendi bileti ve
  o biletteki mesajları, itirazı, raporu) `cascade` ile silinmeye devam eder;
  korunan yalnız *başkasının kaydındaki* aktör izidir.
- **Kodda doğrulanan açıklar:** purge scheduler repoda yok; worker claim'i
  atomik değil; update sonucunu doğrulamadan purge'a devam edebiliyor; storage
  yalnız ilk 100 nesneyi tarıyor; ara hata yollarının bir bölümü sessiz.
- **Uygulama:** `FOR UPDATE SKIP LOCKED`/eşdeğer atomik claim RPC; claim
  kazanamayan worker durur; storage pagination; her ara yazım/storage hatası
  kontrolü; idempotent retry/terminal state; privacy-safe immutable audit;
  moderation kanıtını retention kararına göre pseudonymize ederek koru; staging
  scheduler/workflow çağrısı ve gerçek run kanıtı.
- **Matris:** app içi talep, web yolu, recent reauth, idempotent tekrar,
  aktif grup/timer/task/feedback/report/audit/attachment, anonimleştirme-retention,
  yeniden kayıt, concurrent iki worker, transient failure→retry, >100 avatar/
  storage nesnesi ve iki cihaz token iptali.
- **Kabul:** kullanıcı hesabı erişilemez; silinmesi gereken veri kalmaz;
  tutulması yasal/güvenlik gereği olan audit açık politikayla anonim/korumalı;
  duplicate talep/worker zarar vermez; staging scheduler kanıtı olmadan kapanmaz.
  Bu kart ürün sahibi retention kararını uydurmaz ve production kullanıcı silmez.
- **Model:** Opus.

#### WP-465 — PLAN 5 entegrasyon, tam regresyon ve eski veri güveni

- **Durum / bağımlılık:** [~] Otomatik kapı ayağı bitti (2026-07-31, HEAD
  `f39f6c8`, head `0114`, v56 sonrası 80 commit). Bağımlılıkların yedisi de
  `[x]` ve gösterdikleri `docs/qa/*` kanıtları dosya olarak doğrulandı.
  **Cihaz satırları bu karta ait değil** — WP-438 kartının kendisi
  "cihaz satırları C/WP-465-466'da" diyor; gerçek donanım matrisi WP-466.
- **Kanıt:** `docs/qa/V57-FULL-REGRESSION.md`.
- **Kapılar (gerçek çıktı):** analyze temiz · `flutter test` 1433/1433 ·
  CI ubuntu ayağı (golden hariç) 1399/1399 · CI windows ayağı (yalnız golden)
  34/34 · pgTAP `Files=44, Tests=647 PASS` (0001→0114 sıfırdan replay) ·
  guard 75/75 · preflight 8/8 · l10n 1480 + native 66 · Android APK
  (`--flavor local`) · Windows Release exe · gizli dosya taraması temiz.
- **🔴 Sayı korunumu (kartın asıl istediği):** 1399 + 34 = **1433**, yani
  golden tag ayrımı hiçbir testi dışarıda bırakmıyor ve
  `--dart-define-from-file` hiçbir testi sessizce atlatmıyor. pgTAP tarafında
  yereldeki `plan()` toplamı 647, CI'ın koştuğu 647 — hiçbir dosya erken
  kesilmemiş. `@Skip`/`solo:` yok; tek `skip:` eşleşmesi bir UI etiketi.
- **Bulgular:** kritik/ağır **0**; hiçbir sahip kartı yeniden açılmadı. İki
  **P2 kapı kusuru** (ürün kusuru değil, bu yüzden burada düzeltilmedi →
  WP-467 backlog + kapı kilidi):
  1. `app/integration_test/v8_critical_flows_test.dart` **hiçbir CI kapısında
     koşmuyor** (`flutter test` yalnız `test/` koşar; yalnız elle çalıştırılan
     `windows_local_dev.ps1` çağırıyor). Testin kendisi sağlam — bu turda
     cihazda koşturuldu, 1/1 geçti. `flutter analyze` dosyayı kapsadığı için
     derleme çürümesi sessiz kalmaz; kaçan yalnız davranışsal regresyon.
  2. `scripts/windows_fast_smoke.ps1` **hard-fail etmiş uygulamaya da PASS
     diyor** — ampirik gösterildi: "Secure configuration could not be verified
     / `invalid_version_build`" ekranındaki uygulama için de PASS bastı.
     Yalnız "görünür pencere oluştu mu" ölçüyor; ekran görüntüsü üretiyor ama
     karar ona bakmıyor.
  P3'ler: dört `env.*.example.json` şablonunda bayat `MIGRATION_HEAD`
  (yayın bundan etkilenmiyor, `release.yml` değeri sözleşmeden üretir);
  flavor'sız `flutter build apk` beta'ya düşüp yanıltıcı hata veriyor;
  a11y için ayrılmış test yok. Ayrıca `app/analyze_out.txt` (izlenen, eski
  UTF-16 analyze hata dökümü, hiçbir referansı yok) **kaldırıldı**.
- **SAHİP:** entegrasyon hataları için yalnız koordinasyon; ilgili ürün dosyası
  ilgili ajan tarafından düzeltilir. H tam kalite/test/QA kayıtlarını yazar.
- **Kapılar:** `flutter analyze`; CI ile aynı
  `flutter test --dart-define-from-file=env.json`; l10n audit; Android build;
  guard/preflight; migration `0001→HEAD` local replay + bütün pgTAP; gizli dosya
  taraması; upgrade fixtures.
- **Regresyon:** eski hesap/session/task/group/feedback/moderation verisi;
  notification/widget cold-start; logout/login; offline; dark/light; a11y;
  Windows temel smoke. Testlerin toplam sayısını önceden pinleyip sessiz atlanan
  test kabul etme.
- **Kabul:** kritik/ağır açık 0; bütün kapılar gerçek çıktıyla yeşil; kırmızı
  bulgu sahip ajanın kartını yeniden açar.
- **Model:** Opus.

#### WP-466 — Staging beta ve gerçek cihaz matrisi

- **Durum / bağımlılık:** [x] 2026-08-01 — **staging apply ayağı bitti**:
  dry-run `30660392697` (tam 14 migration `0101`-`0114` listeledi), apply
  `30660596728`, post-check `local|remote|file = 0114`. Tek seferlik GO
  tüketildi ve kapı yeniden kilitlendi (`ec77347`). Purge aktivasyonu da
  yapıldı (`30661167492`, sağlık `configured`).
  **Sahip kararı (2026-08-01):** v57 için kalan beta-v5701, fiziksel cihaz
  matrisi ve 3 günlük soak adımları iptal edildi. Bu tek seferlik muafiyet
  sonraki sürümlere taşınmaz. `release_enabled` stable GO gelene kadar `false`.
- **SAHİP:** staging apply/beta artefakt hazırlığı ve `docs/qa/DEVICE-QA-MATRIX.md`
  kanıtları. Production yok.
- **Uygulama:** exact SHA/head/project-ref doğrula; staging dry-run/apply; beta
  kanalının staging'e bağlı olduğunu fail-closed doğrula; benzersiz beta APK;
  Samsung + mümkünse Pixel/ikinci cihaz; iki hesap/iki cihaz senaryoları.
- **Matris:** timer WP-433; feedback WP-438; moderation/group; tasks/streak;
  date picker; settings/email; widget cold-start; update eski veriyi koruyor;
  force-stop/reboot/internet kaybı/23:59–00:01.
- **Kabul:** kritik/ağır 0; cihaz, OS, beta tag/SHA, migration head, APK SHA-256
  ve sonuç redacted kayda yazılı; en az 3 gün beta soak production önkoşulu.
- **Yetki:** beta kabul adayı mevcut repo politikası kapsamında; production yok.
- **Model:** Opus.

#### WP-467 — v57 release-ready raporu, açıkların tekilleştirilmesi ve kapı kilidi

- **Durum / bağımlılık:** [x] 2026-08-01 — v57 stable yayımlandı. Exact SHA
  `3d1960f552165a8b8f0101f2ed357c583fd5ebe6`; staging ve production `0116`,
  release run `30700647563`; deploy/release kapıları yeniden kilitli.
- **SAHİP:** progress proje gerçekleri, v57 QA/release-ready belgesi,
  deploy contract'ın kapalı olduğunun salt-okunur/guard kanıtı.
- **Uygulama:** bütün WP commitleri ve kabul durumları; kalan P2/P3 backlog;
  release notes taslağı; rollback/degrade; production apply sırası; açık sahip
  GO'sunda tam olarak istenecek SHA/head/project-ref metni.
- **Kabul:** `deploy_enabled=false` ve `release_enabled=false` staging/production;
  guard/preflight yeşil; “release-ready” ile “yayınlandı” ayrımı açık.
- **Yapma:** production migration, stable tag/release, Store submission veya
  kapı açma. Bunlar ürün sahibinin yeni somut emrini bekler.
- **Model:** Opus.

### 5.K — Kapı onarımı (2026-07-31 denetiminden doğdu, ürün WP'lerinden önce gelir)

> Bu beş kart yeni özellik getirmez. v57 turu boyunca hiçbir commit CI görmedi;
> aşağıdakiler kapıları yeşile alır ve turun bıraktığı sessiz borcu kapatır.
> **Faz 1 (468–471) bitmeden Faz 3 ürün zinciri başlamaz.**

#### WP-468 — l10n kapısını yeşile al

- **Durum / bağımlılık:** [x] 2026-07-31 · `5ee1ab2` — l10n Gate yeşil (audit 1480 anahtar).
- **SAHİP:** `app/lib/data/providers/study_providers.dart`, `app_en.arb`, `app_tr.arb`.
- **Uygulama:** `study_providers.dart:1750` içindeki gömülü TR metin
  (`'Seçili ders artık erişilebilir değil; Genel seçildi.'`) l10n anahtarına taşınır.
  Metin WP-448 ile girdi ve `scripts/l10n_audit.py`'yi kırmızıya düşürdü.
  Provider katmanında `BuildContext` yoksa metin çağıran yüzeye taşınır ya da
  anahtar kimliği döndürülür; arb'ye TR **ve** EN birlikte yazılır.
- **Kabul:** `python scripts/l10n_audit.py` FAIL 0. Dört katalog anahtar/placeholder
  eşliği korunur. Gate'in kendi "gömülü metin ekleyince kırmızıya döner" adımı geçer.
- **Model:** Opus.

#### WP-469 — Migration head pinini üç yerde birden hizala

- **Durum / bağımlılık:** [x] 2026-07-31 · `16c7cc3` — guard.tests 75/75, preflight yerel head `0112` bildiriyor.
- **SAHİP:** `tooling/release/deploy-contract.json`,
  `supabase/tests/001_schema_contract.test.sql`, `tooling/supabase/guard.tests.ps1`.
- **Uygulama:** repo/local head `0108`e ilerledi (`0102`…`0108` v57 turunda yazıldı)
  fakat pin iki yerde `0101`de kaldı. Üçü birlikte güncellenir.
  🔴 **staging/production `migration_head` `0100`de KALIR** — bu WP yalnız *local*
  head'i doğru bildirir, hiçbir ortama apply yetkisi vermez ve
  `deploy_enabled`/`release_enabled` dördü de `false` kalır.
- **Kabul:** `./tooling/supabase/guard.tests.ps1` 75/75 · `release-preflight.tests.ps1` 8/8.
  Database Gates ilk adımı yeşil.
- **Tuzak:** aynı hata iki turda tekrar etti; head'i tek yerde ilerletmek kapıyı kırar.
- **Model:** Opus.

#### WP-470 — `admin_repository_test`'i yeni feedback konuşma sözleşmesine hizala

- **Durum / bağımlılık:** [x] 2026-07-31 · `1da65f0` — tam süit 1433/1433.
- **SAHİP:** `app/test/data/admin_repository_test.dart` ve gerekirse
  `in_memory_admin_repository.dart`.
- **Uygulama:** WP-435 biletin gövdesini konuşmanın ilk mesajı yaptı; test hâlâ
  `['user','admin']` bekliyor, gerçek `['user','user','admin']`. **Önce hangisinin
  doğru olduğuna karar verilir:** bilet gövdesi ayrı bir ilk mesaj olarak
  görünmeli mi? Karar ne olursa olsun tek gerçek kalır — ya test yeni sözleşmeye
  hizalanır, ya repository çift kayıt üretmeyi bırakır. Testi beklentiyi
  gevşeterek yeşile almak yasak.
- **Kabul:** `flutter test test/data/admin_repository_test.dart` yeşil ve feedback
  yüzeyinin tamamı (WP-434…438 testleri) yeşil kalır.
- **Model:** Opus.

#### WP-471 — Kamp ateşi golden'larını gerçek görüntüye bakarak kapat

- **Durum / bağımlılık:** [x] `00fd27a` ile tamamlandı (kart denetimde güncellendi, 2026-07-31).
- **SAHİP:** `app/test/features/goldens/campfire_*`, `campfire_sky_golden_test.dart`,
  gerekirse `campfire_layout.dart`.
- **Uygulama:** beş golden kırmızı (`sky_day/transition/night`, `phone_4`, `phone_8`),
  fark %1.70–%6.44. Önce `test/features/failures/` altındaki fark görüntülerine
  **bakılır**: WP-462 kompozisyonu kasıtlı mı değişti, yoksa `78e15cb` bir
  regresyon mu getirdi? Kasıtlıysa golden yenilenir; regresyonsa kod düzeltilir.
  Commit edilmemiş iki preview golden (`campfire_wp377/wp382_preview.png`) da bu
  WP'de karara bağlanır — körlemesine commit edilmez.
- **Kabul:** `campfire_sky_golden_test` + campfire paketi yeşil; `flutter test`
  tamamında golden kaynaklı kırmızı 0.
- **Tuzak:** 🔴 `_kMaxPlatformRasterDiff` (%0.5) **yükseltilemez** — sınır platform
  rasterı payı içindir, ürün değişikliğini gizlemek için değil.
- **Doğrulama (2026-07-31):** kart "beş golden kırmızı" diyordu; koda bakıldı,
  `00fd27a` bunu zaten kapatmış. `campfire_sky_golden_test` yerelde 6/6 yeşil ve
  ubuntu CI'da da geçiyor (tolerans yükseltilmeden, `_kMaxPlatformRasterDiff`
  hâlâ %0.5). İki preview PNG commit'li ve o testler bilinçli olarak
  `matchesGoldenFile` **kullanmıyor** — iddia değil, sahibe bakış karesi
  üretiyorlar; dolayısıyla kırmızıya düşemezler. `failures/` klasörü
  gitignore'da, commit'li artık yok.
- **Model:** Opus.

#### WP-472 — Görev tekrarı için sunucu sözleşmesi (`0109`) ve iki uçlu test

- **Durum / bağımlılık:** [x] 2026-07-31 · WP-469 (head pini) · WP-449/450 kodu indi.
- **SAHİP:** `supabase/migrations/0109_*`, `supabase/tests/034_*`,
  `supabase_user_task_repository.dart`, ilgili sözleşme testi.
- **Uygulama:** `user_tasks` tablosuna `interval_days` + `anchor_date`;
  `upsert_user_task` `p_interval_days`/`p_anchor_date`, `set_user_task_completion`
  `p_occurrence_day` alır; `list_user_tasks` iki kolonu döndürür. Occurrence günü
  sunucuda İstanbul günü ve sabit fazla doğrulanır. Eski satırlar için
  `interval_days = 1`, `anchor_date` geriye dönük `due_at ?? created_at` günü.
  Sahadaki v56 istemcileri kırılmamalı → yeni parametreler **varsayılanlı**.
- **Kabul:** 🔴 **iki uçlu sözleşme testi zorunlu** — Dart'ın gönderdiği RPC
  parametre adları ile migration'daki imza tek kaynaktan karşılaştırılır.
  Bu test olmadan WP kapanmaz; aynı sessiz kopukluk timer-sync'te bir kez
  sahaya çıktı. pgTAP: fixed-phase occurrence, off-cycle red, idempotency.
- **Sonuç (2026-07-31):** `0109_user_task_recurrence_interval` indi. Eski
  `upsert_user_task`/`set_user_task_completion` imzaları **düşürüldü** — yeni
  varsayılanlı sürümün yanında durmaları PostgREST'in adlandırılmış çağrıyı
  çözememesi (`42725 function is not unique`) demekti. Faz tutarlılığı iki
  tablo kısıtıyla da kilitlendi. `034_user_task_recurrence_contract` 21 iddia
  ekliyor (dongü günü kabul, döngü dışı red, occurrence/olay günü uyumsuzluğu,
  tekrar teslim idempotansı, komut kimliği çakışması, `p_occurrence_day`
  göndermeyen v56 istemcisi). İki uçlu test `user_task_rpc_contract_wp472_test`
  — Dart'ın gönderdiği parametre kümesini `SupabaseUserTaskRepository`nin kendi
  `upsertParams`/`completionParams` fonksiyonundan, SQL imzasını ise migration
  dizininden okur. Mutasyonla doğrulandı: imzadan `p_anchor_date` çıkarıldığında
  3 test kırmızıya döndü.
- **Model:** Opus.

#### WP-473 — Bekleyen migration'ları gerçekten replay et

- **Durum / bağımlılık:** [x] 2026-07-31.
- **SAHİP:** `.github/workflows/database-gates.yml` koşumu ve kanıt kaydı.
- **Uygulama:** `0102`…`0109` ve pgTAP `029`…`034` bu hostta hiç koşmadı — Docker
  motoru kalkmıyor, hepsi **"Replay bekliyor"** etiketiyle teslim edildi.
  Database Gates workflow'unun *local replay* job'ı (`local.ps1 baseline`)
  `workflow_dispatch` ile koşturulur; bu job remote'a dokunmaz.
- **Kabul:** `0001→0109` temiz replay yeşil; pgTAP toplamı ve yeni assert sayısı
  kayda yazılır. Kırmızı çıkan migration sahibine döner.
- **Yapma:** staging/production apply, tag, release. Kapılar kapalı kalır.
- **Model:** Opus.

### 5.Z — Çekirdek yeşil olduktan sonra, v57 release blocker olmayan park alanı

Bu fikirler rakip analizinde değerlidir ancak yukarıdaki P0/P1 zincirini
geciktirmeyecek ve ajanlar WP-467 sonrası kendiliğinden başlamayacaktır:

- sıralamayı gizleme / yalnız kişisel mod;
- manuel girilmiş süre rozeti;
- sohbet yanıtla ve resim paylaşımı;
- grup davet linki ve üye onayı;
- ders klasörleri ve ders bazlı oturum dökümü;
- D-Day kartı;
- masaüstü admin iş akışını büyütme;
- gerçek AMOLED siyah tema;
- ders dışı odak kategorileri.

### 5.X — Bilinçli kapsam dışı

- Store listing, ekran görüntüsü, açıklama ve submission ürün sahibinde.
- DE/AR dosyaları silinmez ama ilk mağaza runtime'ında sunulmaz.
- Kabul edilmeyen beş widget yeniden tasarlanmaz; yalnız picker'dan çekilir.
- Büyük tablet/desktop yeniden tasarımı, voice/video room ve aylık e-posta
  sağlayıcısı bu turda yok.
- Sayaç, feedback ve güvenlikte “şimdilik if ekle” sınıfı semptom yaması yok;
  karttaki invariant ve kanıt kurulmadan iş tamamlanmaz.

---

## ✅ Kapanan Kararlar

| Karar | Sonuç |
| --- | --- |
| Diller | **Sadece TR + EN.** DE/AR dil seçeneğinden kalkar, `.arb` dosyaları kalır |
| Aylık e-posta raporu | **İptal.** Kod dursun, kurulum yapılmayacak (domain + SPF/DKIM + sağlayıcı gerekiyordu) |
| Tema sihirbazı sadeleştirmesi | **Gerek yok.** Tek gerçek sorun his adımıydı, v49'da çözüldü |
| **K1** Yanıt kanalı | **Çift yönlü** — kullanıcı admin yanıtına geri yazabilir |
| **K2** Şifre değiştirme | Klasik üç alan + "Şifremi unuttum"; mevcut şifre **gerçekten** doğrulanır. Google/passkey girişi zaten yok (`passkeys` ölü bağımlılık) → özel durum ekranı gerekmiyor |
| **K3** Tanıtım turu | Yalnız **ilk açılışta**, ekrana basınca sonraki balona geçer |
| **K4** Gün sınırı backfill | **Konusuz kaldı** — gün toplamları saklanmıyor, her sorguda hesaplanıyor |
| **K5** Çoklu grup | **Birincil grup** — kullanıcı seçer; görev/hedef/grup progression yalnız onu sayar. Canlı presence bütün aktif üyeliklerde görünür; direct grup bildirimleri ve timer-sync sinyalleri primary ile filtrelenmez |
| **K6** İsim + logo | ⏸️ Plan 2 başlamadan konuşulacak |
| **K7** Gizlilik URL'i | **GitHub Pages** — bedava, HTTPS hazır, `docs/legal/*.md`'den yayınlanır |
| **K8** Yurtdışı gün sınırı | **Birincil grubun bölgesi** belirler; grubu olmayan cihaz saat dilimini kullanır. Gruplara bölge alanı + üye sınırı 8 + keşifte yakınlık sıralaması |
| Üye sınırı | **8 kişi** — `0071` staging'e uygulandı; beta cihaz kabulü bekliyor |

---

## ⚠️ Risk ve Tuzak Notları

- 🔴 **`l10n Gate` v55 boyunca kırmızıydı ve kimse bakmadı.** v56 entegrasyonunda
  fark edildi: son beş koşum üst üste `failure`, dizeler WP-379/388/390'dan geliyor,
  yani **v55 bu kapı kırmızıyken yayınlandı**. Katalog eşliği doğruydu — sorun
  kaynak koddaki l10n'dan geçmeyen 11 Türkçe literal'di; İngilizce/Almanca/Arapça
  cihazda Türkçe metin görünüyordu. Ders: yeşil sanılan bir kapının gerçekten yeşil
  olduğu `gh run list --workflow=...` ile **doğrulanmadan** sürüm çıkarılmaz.
  Yerel karşılığı: `python scripts/l10n_audit.py` (katalog eşliği + hardcoded tarama).
  Katalog anahtarlarını saymak yetmez — audit ayrı bir şeye bakar.
- 🔴 **`AFTER ROW` tetikleyicisinde `count(*)` ile tekilleştirme yapma.** AFTER
  tetikleyicileri **deyim sonunda** çalışır; çok satırlı tek `INSERT`'te her
  tetikleme anında bütün satırlar zaten görünürdür. WP-428'in `count(*) = 1`
  koşulu bu yüzden hiçbir satırda tutmadı ve push **hiç** üretilmedi. Tek satırlık
  insert'lerde çalıştığı için üretimde fark edilmezdi. Doğru biçim: "en eski açık
  kayıt ben miyim" (`order by created_at, id limit 1`) — deyim gruplamasından bağımsız.
- 🔴 **pgTAP'ta olmayan fonksiyon uydurmak sessizce geçer.** `hasnt_table_privilege`
  diye bir fonksiyon **yok** (yerleşik `has_table_privilege` 3 argüman alır, `ok()`
  içine sarılır); `throws_like` SQLSTATE argümanı **almaz**, o `throws_ok`'a aittir.
  Yanlış imza "function ... does not exist" ile düşer ama dosya `plan(6)` dediği
  için hata **"Bad plan: planned 6 but ran 1"** olarak görünür — asıl sebep
  ekranın yukarısında kalır. pgTAP çıktısında önce `ERROR:` satırını ara.
- **Sürüm disiplini.** Sürüm sahibin onayıyla çıkar; düzeltmeler birikir, tek sürümde çıkar.
- **Migration drift kapandı.** Repo/local, staging ve production `0085`te hizalı (WP-351, 2026-07-27). Drift'in gerçek sebebi head farkı değil, production'ın **boş CLI migration geçmişiydi** — şema doğruyken `db push` 0001'den başlıyordu. Yeni bir ortam eklenirse ilk iş `migration list`in Remote sütununu okumaktır; boşsa push denenmez.
- **Yedeksiz production.** PITR ve günlük yedek **yok** (Free plan). Sahip bunu kalıcı olarak kabul etti; `deploy-contract.json` içinde `backup_requirement: "waived"` olarak kayıtlı. Sonucu: production'da geri alma yolu yoktur, yalnız ileri migration ile düzeltilir. Repo **PUBLIC** olduğu için CI'da `db dump` alıp artifact'a koymak asla seçenek değildir.
- **Geri kilitleme kuralı.** Terfi biten her production apply'dan sonra `deploy_enabled` yeniden `false` yapılır. Sözleşmede `true` bulmak, açık bir GO'nun sürdüğü anlamına gelir — bulursan doğrula.
- **V3 rollout flag'leri kapalı.** WP-328…WP-346 zinciri kodda ve `0085`te var ama varsayılan kapalı. v49'daki çoklu cihaz senkron bulgusu (V49-1) önce buna karşı ayrılmalı: flag kapalı olduğu için mi çalışmıyor, yoksa açıkken de mi bozuk.
- ✅ **Çözüldü: `kamp telefonu golden · 8 kişi` kararsızlığı (`6f285a2`).**
  Kök neden: golden harness reduce-motion kurmuyordu, sahne alev fazını (`t`)
  canlı tutuyordu ve **3+ çalışan** varken `CampfireActivity.high` köz
  parçacıklarını da çiziyordu. Parçacık yeri `t`'ye bağlı olduğu için yakalanan
  kare koşuma göre değişiyordu. Yalnız 8 kişi senaryosu bu eşiği geçiyor (4 kişi
  çalışıyor); 1 kişi `empty`, 4 kişi ve gökyüzü senaryoları `low` kalıyor. Bu,
  "izole geçer, tam pakette düşer" davranışını ve Windows CI'daki sınırda
  (%0.50) farkı birlikte açıklıyor. Düzeltme kareyi sabitledi
  (`MediaQuery.disableAnimations`); **tolerans değiştirilmedi.** Kırmızı-yeşil
  kanıt: aynı tam paket koşumu artık `All tests passed!`.
  🔴 **Ders:** animasyonlu bir sahnenin golden'ı, kare sabitlenmeden çekilirse
  test sessizce kumar olur. Yeni golden ekleyen WP animasyonu kapatmalıdır.
- **Presence canlılığı istemciye bağlıdır (V49-6).** "Çalışıyor" bilgisi
  sunucudaki oturumdan değil, istemcinin son 70 sn içinde yazdığı satırdan
  türetiliyor. Flutter izolatı durursa native sayaç yaşasa bile kullanıcı grupta
  offline görünür. **V3 flag'lerini açmak bunu çözmez** — projection yolu da aynı
  70 sn'lik istemci lease'ini yeniliyor (`0081`). Ölçüm WP-354, düzeltme WP-355.
- **Sayaç sıcak yolu donuktur.** WP-340–345 normal local start/stop sırasını, notification ID/channel/layout/PendingIntent'leri, widget görünümünü ve `ACTION_STOP_SILENT` davranışını yeniden tasarlamaz. Global senkron additive envelope + shadow + feature flag ile gelir; WP-346 gerçek cihaz regresyon kapısı geçmeden varsayılan açılmaz.
- **l10n kapısı temiz.** WP-335, 24 gerçek WP-295 kullanıcı metnini kataloğa taşıdı; 7 kullanıcı-dışı invariant mesajını dar ve gerekçeli muafiyetle ayırdı. Yeni UI metni ekleyen WP'ler audit sıfır-bulgu kuralını korumalıdır.
- **Geri alınamaz işler.** Hesap silme purge'ü bu sınıfta — yedek + staging provası + rollback betiği olmadan production'a dokunulmaz. *Gün sınırı artık bu sınıfta değil* (toplamlar saklanmıyor).
- **Ölü anahtar riski.** WP-319'daki sahte “mevcut şifre” koruması düzeltildi; benzer ayarlar yeni işlerde sözleşme testiyle engellenmeli.
- **MSIX kimliği** Partner Center'da rezerve edilen adla eşleşmezse paket reddedilir; sonradan düzeltmek yeni uygulama demektir.
- **Saat dilimi offset olarak saklanmaz** — hep IANA adı (`America/New_York`). Türkiye'de yaz saati olmadığı için bu hata bugüne kadar hiç görünmedi.

---

## Test için bekleyenler

> **Tek QA kuyruğu budur.** Buradaki WP'lerin kodu ve otomatik testleri bitti;
> worker'a verilmez. Cihaz, staging veya ürün kabulünde hata bulunursa ayrı WP açılır.

| WP | Ortam | Bekleyen kabul |
| --- | --- | --- |
| **WP-475** Başarım ünvanı | Production `0116` | Otomatik test tamam. v57 fiziksel cihaz kabulü 2026-08-01 sahip kararıyla muaf; production terfisi exact GO bekliyor. |
| **WP-476** Dürtme odak koruması | Production `0116` | Otomatik test tamam. v57 iki-cihaz kabulü 2026-08-01 sahip kararıyla muaf; production terfisi exact GO bekliyor. |
| **WP-295** Kamp ateşi oturma/poz | Windows + Android profile | Seçilen 1–8 kişi yerleşimleri ve marshmallow erişimi görsel olarak doğru; Android profile'da `p95 ≤ 16.7 ms`, jank `≤ %1` |
| **WP-349** Forest Cabin tema kapağı | Windows + Android | Hazır tema kartı baskın scaffold/surface paletini doğru yansıtıyor; açık/koyu preset seçimi, 360 dp iki sütun ve 48 dp dokunma hedefi gerçek cihazda doğrulanmalı. **Cihazda doğrulanmalı.** |
| **WP-350** Telefon kamp ateşi | Android + Windows | Telefonda 1/4/8 kişi, düşük ateş, geniş halka, küçük hayvanlar/etiketler, ağaçsız arka plan ve küçük glow; masaüstü kompozisyonu korunuyor. Android profile `p95 ≤16.7 ms`, jank `≤%1` cihazda doğrulanmalı. **Cihazda doğrulanmalı.** |
| **WP-335** l10n hijyeni | Android + Windows | TR/EN WP-295 önizlemesinde başlık, durum çipi, denetimler ve tooltip'ler doğal; 360 px'te sahne + kaydırılabilir kontrol alanı taşmasız. **Cihazda doğrulanmalı.** |
| **WP-299** Gündüz/gece gökyüzü | Android + Windows | Yerel saate göre geçişler, zemin/gökyüzü birleşimi ve gece uyuma pozu gerçek cihazda doğal görünüyor |
| **WP-315** Grup üye sınırı 8 | Staging + beta | Grup kurma/katılma akışında 8 sınırı çalışıyor; dokuzuncu üye sunucuda reddediliyor |
| **WP-316** Geri bildirim eki | Staging cihaz | Ekli bilet görseli `≤ 3 sn` açılıyor; eksiz bilette çip yok, yükleme hatası görünür |
| **WP-317** Admin ↔ kullanıcı yazışması | Staging + beta | Çift yönlü mesaj `≤ 5 sn`, push/duyuru izi ve başka kullanıcının bileti için RLS reddi |
| **WP-318** Bilet arşivi | Staging + beta | Varsayılan liste yalnız aktif; arşiv görünümü/geri alma eksiksiz; satır silinmiyor |
| **WP-319 / 319-G** Şifre akışı | İki Android cihaz | Mevcut şifre doğrulaması, Android recovery linki ve diğer cihaz oturumunun kapanması. Windows kod yolu özel SMTP/ücretli plan gelene kadar bloklu |
| **WP-320** Ayarlar IA | Android + Windows | Hesap/dışa aktarma/silme aynı grupta, yasal metinler sonda; 360 px'te taşma yok |
| **WP-321** Yalnız TR + EN | Android + Windows | Listede iki dil; cihaz dili DE iken güvenli EN fallback ve kayıtlı eski tercihte çökme yok |
| **WP-323** Tanıtım turu motoru | Android + Windows | İlk açılış, atla, sıfırla ve izin/güncelleme diyaloğu varken erteleme gerçek cihazda çalışıyor |
| **WP-325** Oturum günü damgası | Staging `0084` | Öncesi/sonrası gün toplamı birebir; bölge değişimi geçmişi oynatmıyor; indeks planı kanıtlı |
| **WP-326** Grup saat dilimi | Staging `0084` + beta | IANA adı, New York yerel gece yarısı, cihaz fallback'i ve DST davranışı doğru |
| **WP-327** Grup bölgesi + saat farkı | Staging `0084` + beta | Açık grup kartı/bilgi ekranı, aynı bölgede farkın gizlenmesi, New York ve +5:30 farklarının doğruluğu |
| **WP-328** Keşif sıralaması + arama/filtre | Staging `0084` + Android + Windows | Kullanıcı bölgesine göre sıralama, bölge filtresi, boş kontenjan filtresi ve sayfalama gerçek cihazda doğrulanmalı. **Cihazda doğrulanmalı.** |
| **WP-329/348** Birincil grup | Staging + iki Android cihaz | WP-348 kod/test tamam; staging terminal yapılandırması eksik olduğundan remote dry-run/apply bekliyor. Ardından tek seçim, kayan 24 saat server kuralı, iki cihaz stale-revision reddi, üyelikten çıkış/silmede uzlaşma ve timer/bildirim/widget regresyonu doğrulanmalı. **Cihazda doğrulanmalı.** |
| **WP-336** Tek-grup session attribution | Staging `0084` + iki Android cihaz | Yeni session yalnız başlangıçtaki primary gruba yazılır; secondary day/week/achievement katkısı ve cron geri yazımı 0, kişisel süre/XP korunur. **Cihazda doğrulanmalı.** |
| **WP-343** Foreground mirror + remote stop | Staging + iki Android cihaz | Aynı hesapta foreground start/stop p95≤2 sn; ek session/XP 0; eski stop yeni yerel run'ı kesmez; bildirim/widget regresyonu 0. **Cihazda doğrulanmalı.** |
| **WP-345** Timer-sync signal + app-open reconcile | Staging FCM + Android lifecycle | Data-only sinyal p95≤10 sn; açılış reconcile p95≤2 sn; terminated/doze/logout/force-stop sonrasında payload state uygulamaz, snapshot doğru state'i getirir. **Cihazda doğrulanmalı.** |
| **WP-379** Ayna Durdur global koşuyu kapatır | İki Android cihaz + FCM | Aynadan onaylı Durdur → kaynak cihaz ≤5 sn'de durur ve gerekçeyi gösterir; iptal değişiklik yapmaz; revision/ağ reddinde ayna açık kalır; ek session/XP 0. Commit: `bekleyen`. **Cihazda doğrulanmalı.** |
| **WP-416** Kamp ateşi yeşil alanı 2× + mobil önizleme | Android telefon | Yeşil alan iki katı (137 px) görünüyor; 8 kişide isim çakışması ve alt sıra ayak kesilmesi yok; sahip `lib/campfire_preview.dart` aracından dört kolu (yeşil alan · isim boyutu · satır aralığı · hayvan boyutu) ayarlayıp seçtiği satırı gönderir — seçilen sayılar teste sabit değer olarak girer. Commit: `41544e0`. **Cihazda doğrulanmalı.** |
| **WP-419** Derleme tanısı Hakkında'ya taşındı | Android | Ayarlar → Hakkında'da varsayılan yalnız sürüm görünüyor, dokununca kanal/backend/commit/migration başı açılıyor; sürüm notları ekranının hiçbir yerinde teknik kimlik ve beta rozetli kart yok. **Cihazda doğrulanmalı.**
| **WP-420** Geri bildirim ekranı yeniden düzeni | Android telefon | Dar telefonda klavye açıkken yazılan metin görünür kalıyor; İptal/Gönder yan yana; *Gönder* ve *Geri bildirimlerim* sekmeleri; yeni mesaj altta. **Cihazda doğrulanmalı.**
| **WP-421** Rozet zinciri + başarım gecikmesi | İki Android cihaz + FCM | Yönetici yanıt yazınca rozet Profil → Ayarlar → Geri bildirim sekmesinde beliriyor, okununca hepsi sönüyor; başarım rozeti push'u beklemeden düşüyor. **Cihazda doğrulanmalı.**
| **WP-422** Giriş ekranı SSS bağlantısı | Android | Bağlantı kayıt geçişinin altında en altta, etiket "(SSS)" taşıyor, kayıt modunda da görünüyor ve oturum açmadan açılıyor. **Cihazda doğrulanmalı.**
| **WP-417** Tanıtım turu sadeleştirme | Android + Windows | Ana ekranda yalnız "kartları düzenle" balonu çıkıyor (genel bakış + sayaç turu yok); istatistiklerde hiç tur açılmıyor. Commit: `d0751a0`. **Cihazda doğrulanmalı.** |
| **WP-418** Başarım açıklamaları | Android + Windows (okuma) | Sahip katalogda İlham Kaynağı ve Lokomotif metinlerini okuyup koşulu anladığını onaylar. Commit: `b030094`. **Kodda doğrulandı.** |
| **WP-380** Widget ve bildirimde boş sayaç biçimi | Android widget + bildirim | Boştayken `00:00`; başlatınca ilk saniyede sıçrama yok; bir saati geçince `1:00:00`; uygulama içi sayaç `00:00:00` kalır. Commit: `bekleyen`. **Cihazda doğrulanmalı.** |

**Ortam sırası:** v56 terfisiyle local, staging ve production `0100`de
(2026-07-28). Yukarıdaki tarihsel kartlarda şema borcu yoktur; kalan borç
**gerçek cihaz kabulü** ve v57 saha bulgularıdır.

## 🗄️ Tarihsel kayıt

Tamamlanan ayrıntılı WP kartları ve eski beta dalga planı yalnız git
geçmişindedir (`docs/archive/` 2026-07-27'de kaldırıldı). Canlı dosyada
tekrar tutulmaz.

- **WP-300** enlem/boylam yaklaşımı iptal edildi; yerini konum izni istemeyen **WP-326** aldı.
- **WP-301** eski `metric_day` backfill yaklaşımı iptal edildi; yerini kayıt anı damgası **WP-325** aldı.
- Eski iki-beta/dalga sırası tarihsel kayıttır; güncel sıra Yol Haritası + Aktif Çalışma Kaydı'dır.

## 🔧 Seri Fix Kuyruğu

> **Sahip kararı (2026-07-27, revize):** Kuyruk v49 *sonrasına* bırakılmıyor.
> v49 henüz yayımlanmadığı için **Hotfix WP-1 · WP-352 v49 kapsamına alındı** —
> sonradan ayrı hotfix turu açmamak için. Sıradaki maddeler v49 çıktıktan sonra
> değerlendirilir. `Hotfix WP-n` etiketi kuyruk sırasıdır, kanonik numara her
> zaman yanında verilir ve `Son WP numarası` ile birlikte ilerler.

### Hotfix WP-1 · WP-352 — Birincil grup seçilmemişse görünür uyarı 🏠
- **Program/Faz:** Faz F2 devamı · WP-329/WP-336/WP-348 ürün açığı
- **Ajan:** Claude
- **Durum:** [~] Kod/test tamamlandı; v49 kapsamında, cihaz kabulü bekliyor
- **Bağımlılık:** Yok. WP-348 birincil grup kartı yerinde
  (`social_profile_screen.dart` kendi-profil/Başarımlar görünümü).
- **Problem (2026-07-27 sahip gözlemi + kod doğrulaması):** Çoklu üyelikte açık
  seçim yoksa `reconcile_user_primary_group` bilinçli olarak
  `primary_group_id = NULL` bırakıyor
  ([`0079_primary_group_preference.sql:126-128`](supabase/migrations/0079_primary_group_preference.sql:126)).
  Cutover sonrası her oturuma `group_id = NULL` attribution satırı yazılıyor
  ([`0080_session_group_attribution.sql:50-84`](supabase/migrations/0080_session_group_attribution.sql:50))
  ve `groups_for_session_progression` `a.group_id is not null` filtresi yüzünden
  **hiçbir grup döndürmüyor** ([`0080:127-155`](supabase/migrations/0080_session_group_attribution.sql:127)).
  Sonuç: grup başarımı, grup görev/hedef ve grup gün-hafta ilerlemesi sessizce
  durur. Grup liderlik tablosu ham `study_sessions` topladığı için
  ([`0040_group_contribution_breakdown.sql:8`](supabase/migrations/0040_group_contribution_breakdown.sql:8))
  kullanıcı **UI'da normal görünür** — kaybın hiçbir işareti yok.
  `PrimaryGroupSelectorCard` bugün hiç uyarı göstermiyor; `primaryGroupNotSelected`,
  `primaryGroupCurrent` ve `primaryGroupOther` l10n anahtarları **hiçbir kod
  yolundan çağrılmıyor** (ölü string).
- **Etki alanı:** Yalnız 0079 kurulurken zaten 2+ grupta olan hesaplar (bugün
  sahip + bir hesap). Yeni kullanıcı ilk gruba katıldığında `automatic_single`
  ile otomatik atanır ve ikinci gruba katılmak mevcut birincili bozmaz
  ([`0079:122-124`](supabase/migrations/0079_primary_group_preference.sql:122)).
  Ayrıca 3+ gruptayken birincil gruptan ayrılmak veya birincil grubun silinmesi
  aynı NULL durumuna düşürür — uyarı bu yolları da kapsar.
- **Yapılan:**
  - `primaryGroupSelectionMissingProvider` (`group_providers.dart`): üyelik var
    + `primaryGroupId == null` → `true`. Yükleme/hata durumunda `false`; olmayan
    bir kayıp ilan edilmez.
  - `PrimaryGroupSelectorCard` içinde `errorContainer` renkli uyarı bloğu
    (`ValueKey('primary-group-missing-warning')`). Metin mevcut
    `primaryGroupNotSelected` anahtarından okunur — **yeni string yazılmadı**,
    WP-348'den kalan ölü anahtar bağlandı. Uyarı seçimi engellemez.
  - Mobil kabukta Profil sekmesine nokta (`home_shell.dart`
    `_profileTabIcon`). Bekleyen ödül sayısı varsa mevcut sayı rozeti korunur;
    iki sinyal aynı sekmede yarışmaz.
  - `app/test/features/profile/primary_group_missing_warning_test.dart`:
    3 widget + 4 provider senaryosu.
- **Kapsam dışı:** Migration, RPC, cooldown kuralı, otomatik birincil atama,
  yeni l10n anahtarı.
- **Bilerek yapılmadı — masaüstü nokta.** `DesktopNavigationPane` bugün hiç
  badge altyapısı taşımıyor (`DesktopNavItem` yalnız `IconData`); bekleyen ödül
  rozeti de masaüstünde yok. Rozet eklemek paylaşılan gezinti widget'ının
  sözleşmesini değiştirir ve v49 teslimi için gereksiz risktir. Masaüstünde
  uyarı yüzeyi kartın kendisidir. Rozet istenirse ayrı kart açılır.
- 🔴 **Kapanan karar (sahip, 2026-07-27): geçmiş yetim oturumlar telafi
  edilmeyecek.** Attribution `after insert` + `on conflict (session_id) do
  nothing` olduğu için
  ([`0080:86-89`](supabase/migrations/0080_session_group_attribution.sql:86))
  `primary_group_id` NULL'ken yazılmış oturumlar seçim sonrası da hiçbir grup
  projeksiyonuna girmez. Bu kabul edildi; backfill/yeniden atama WP'si
  **açılmayacak**. Bu kart yalnız bundan sonrasını korur.
- **Sahip yollar:** `app/lib/features/profile/widgets/primary_group_selector_card.dart`,
  `app/lib/data/providers/group_providers.dart`,
  `app/lib/core/navigation/home_shell.dart`,
  `app/test/features/profile/primary_group_missing_warning_test.dart`,
  `progress.md` (yalnız bu kart).
- **Ortak/riskli yüzey:** `home_shell.dart` paylaşılan gezinti yüzeyidir; nokta
  dışında hiçbir gezinti davranışı değiştirilmedi. Mevcut bekleyen-ödül rozeti
  regresyon testi (`widget_test.dart`) yeşil kaldı.
- **Kabul (DoD):** ✅ 7/7 yeni test yeşil · ✅ `flutter analyze` temiz (0 sorun) ·
  ✅ tam paket 926 test, tek hata `campfire_sky_golden_test.dart` "kamp telefonu
  golden · 8 kişi" ve o **temiz HEAD'de de patlıyor** (bu WP'den bağımsız,
  mevcut sorun) · ⏳ cihaz kabulü: 2 gruplu hesapta uyarı + nokta görülüyor,
  seçim sonrası ikisi de kayboluyor.

## 🗺️ Faz F4 — v57 sahip geri bildirimi (WP-477…WP-488)

> **Kaynak:** `docs/V57-SAHIP-GERI-BILDIRIM-RAPORU.md` (1 Ağustos 2026, ham kayıt
> V57-N01…N12). Bu faz o raporun **teşhis edilmiş** karşılığıdır: her kart
> belirtiyi değil, kodda doğrulanmış kök nedeni taşır.
>
> 🔴 **Faz açılırken kapı durumu:** migration head üç ortamda da `0116`;
> production/stable deploy kapıları `deploy-contract.json` içinde fail-closed.
> Bu fazın hiçbir kartı kapı açmaz. Yeni migration (WP-485) `0117` olur ve
> **head üç yerde birden** ilerletilir (`deploy-contract.json` ·
> `supabase/tests/001_schema_contract.test.sql` · `tooling/supabase/guard.tests.ps1`).
> Yerel replay bu hostta Docker kalkmadığı için koşamaz; kart `Replay bekliyor`
> etiketiyle teslim edilir, kanıt Database Gates workflow'unun local replay
> job'ından alınır.

### Fazın üç sistemik bulgusu (tek tek yama değil, sınıf hatası)

1. **l10n kapısı veri katmanını hiç görmüyor.** `scripts/l10n_audit.py` prose
   taramasını bilinçli olarak **widget yuvalarıyla** sınırlar (`UI_SLOT`:
   `Text(`, `title:`, `tooltip:` …) ve ayrıca `PROSE_RE` yalnız **büyük harfle
   başlayan** cümleyi yakalar. Repository/provider katmanındaki kullanıcıya
   dönen hata metinleri bu ağın tamamen dışındadır: ölçüm, `app/lib` içinde
   (l10n çıktısı ve yorumlar hariç) **28 dosyada 217 gömülü Türkçe literal**
   buldu. V57-N01 ve V57-N08'in dil yarısı bu boşluğun iki örneğidir.
2. **Üç ayrı "seri" tanımı aynı geçmişte farklı sayı veriyor.** Bu WP-455
   kartında zaten `Kapanmayan kabul` olarak duruyordu; sahip artık kararı verdi
   (chess.com modeli), yani karar kapandı, iş açıldı.
3. **Bitmiş backend + hiç bağlanmamış UI.** Aynı desen üç yerde: `GoalStreakFlame`
   (`lib/` içinde çağrı yeri yok), `muteNudgesFrom` (yalnız testlerden çağrılıyor),
   `feedback_ticket_messages` realtime yayını (tabloya hiç eklenmemiş). Üçünde de
   testler yeşil, çünkü testler InMemory/widget katmanını sürüyor; **kablo yok**.

---

#### WP-477 — Veri katmanı hata metinlerini l10n'a bağla ve kapıyı genişlet

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam (`Cihazda doğrulanmalı`).
- **Belirti (V57-N01, V57-N08 dil yarısı):** İngilizce arayüzde "Aynı kişiye 20
  dakikada bir dürtme gönderebilirsin." ve "Bu kişi şu an çalışıyor; odağını
  bölmemek için dürtme kapalı." Türkçe çıkıyor.
- **Kök neden (kodda doğrulandı):** metinler l10n kataloğunda değil, repository
  sabitleri:
  [`nudge_repository.dart:14`](app/lib/data/repositories/nudge_repository.dart:14)
  (`nudgeCooldownMessage()`),
  [`nudge_repository.dart:18`](app/lib/data/repositories/nudge_repository.dart:18)
  (`kNudgeRecipientStudyingMessage`),
  [`nudge_repository.dart:71`](app/lib/data/repositories/nudge_repository.dart:71)
  (120 karakter uyarısı) ve
  [`supabase_nudge_repository.dart:129-156`](app/lib/data/repositories/supabase/supabase_nudge_repository.dart:129)
  `_friendlyMessage` / `_friendlyMuteMessage` dallarının tamamı.
- **🔴 Kök nedenin kökü — kapı bu sınıfı taramıyor:** `scripts/l10n_audit.py`
  `UI_SLOT` düzenli ifadesiyle yalnız widget yuvalarına bakar; repository
  sabitleri hiç okunmaz. Ayrıca `PROSE_RE` büyük harf şartı yüzünden
  `'hedef serisi'` ([`goal_card.dart:220`](app/lib/features/home/widgets/goal_card.dart:220))
  ve `'grup serisi'` ([`group_goal_card.dart:280`](app/lib/features/home/widgets/group_goal_card.dart:280))
  gibi **`Text(` içindeki** küçük harfli literaller de kaçıyor. Yani kapı iki
  ayrı nedenle kör.
- **Ölçüm:** 28 dosya, 217 gömülü TR literal. En yoğunu
  `supabase_group_repository.dart` (29), `supabase_auth_repository.dart` (25),
  `in_memory_group_repository.dart` (24), `supabase_admin_repository.dart` (22).
- **Yapılacak:**
  1. Hata metinlerini `AppException` alt sınıflarında **kod** (`nudge_cooldown`,
     `recipient_is_studying`, …) olarak taşı; metne çeviriyi **sunum katmanı**
     yapsın. Repository `BuildContext`/`AppLocalizations` almaz — katman ihlali
     olur; bu yüzden çeviri `NudgeException.code → l10n` eşlemesiyle
     `class_detail_screen` tarafında yapılır.
  2. `nudgeCooldownMessage()` sayıyı metne gömüyor; l10n anahtarı
     placeholder'lı (`{minutes}`) olmalı, aksi hâlde `kNudgeCooldown` değişince
     EN katalog geride kalır.
  3. `l10n_audit.py`: prose taramasına **veri katmanı** kapsamı ekle
     (`app/lib/data/**`, `app/lib/core/**` içinde `throw`/`return` ile kullanıcıya
     dönen literaller) ve `PROSE_RE`'nin büyük harf şartını kaldır/gevşet.
     Yanlış pozitif patlamasını önlemek için muafiyetler
     `LITERAL_EXEMPTIONS`'a **gerekçesiyle** yazılır.
  4. Kapıyı **kasten kırık girdiyle sına**: bir dosyaya gömülü TR metin ekle,
     denetimin kırmızıya döndüğünü göster, sonra geri al. (Kapı "yeşil
     sanılmaz, doğrulanır".)
- **Kapsam:** Yalnız **dürtme** yüzeyinin metinleri bu kartta çevrilir. Kalan
  ~200 literal kapı tarafından **raporlanır** ve muafiyet listesine gerekçeyle
  alınır; hepsini bir kartta çevirmek 28 dosyaya dokunur ve regresyon riski
  faydayı aşar. Sırayla temizlenmesi WP-486 ve sonrasına bırakılır.
- **Sahip yollar:** `app/lib/data/repositories/nudge_repository.dart`,
  `app/lib/data/repositories/supabase/supabase_nudge_repository.dart`,
  `app/lib/data/repositories/in_memory/in_memory_nudge_repository.dart`,
  `app/lib/features/classroom/widgets/class_detail_screen.dart` (yalnız hata
  gösterimi), `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_tr.arb`,
  `scripts/l10n_audit.py`, ilgili testler.
- **Kabul (DoD):** EN dilde üç dürtme hatası da İngilizce · `{minutes}`
  placeholder iki katalogda da var · genişletilmiş `l10n_audit.py` kasten
  eklenen gömülü metinle **kırmızı** döner (kanıt turda gösterilir) ·
  `flutter analyze` temiz · tam test paketi yeşil.
- **Sonuç (2026-08-01):** `NudgeException` artık metin değil `NudgeErrorCode`
  taşıyor (11 kod + günlüğe ayrılmış `detail`); çeviri tek noktada,
  `core/l10n/nudge_error_text.dart` eşlemesinde. `nudgeCooldownMessage()` ve
  `kNudgeRecipientStudyingMessage` sabitleri kalktı; süre artık
  `nudgeErrorCooldown` anahtarının `{minutes}` placeholder'ından, `kNudgeCooldown`
  değerinden besleniyor. Yedi yeni l10n anahtarı (TR+EN), üç ölü anahtar
  (`commonKendineDurtmeGonderemezsin`, `commonBuGruptaDurtmeGonderme`,
  `commonDurtmeNotuEnFazla`) ilk kez bağlandı.
- **Kapı genişletmesi ölçümlü:** `INTERNAL_PREFIXES` (`app/lib/data/repositories/`
  blanket muafiyeti) **kaldırıldı** — kapının kör noktası buydu. Yerine üç
  değişiklik: (1) `PROSE_RE`'nin büyük harf şartı kalktı, (2) yeni
  `data_layer_violations` taraması (`throw …Exception('…')` / `return` / `=>`,
  `app/lib/data/**` + `app/lib/core/**`), (3) `DATA_LAYER_DEBT` sayım kilidi —
  18 dosya × 379 literal gerekçeli olarak kilitlendi; dosyaya **yeni** metin
  eklemek kapıyı kırmızıya düşürür, borç azalınca sayıyı düşürmek zorunlu
  (cırcır). Kalan borç kapı yeşilken bile çıktıda raporlanıyor.
- **Kapı kasten kırıldı (üç senaryo, hepsi `exit=1`):** (a) veri katmanına
  gömülü TR metin → `hardcoded TR literal: nudge_repository.dart:90`,
  (b) `Text('gunluk gorev ozeti')` küçük harfli metin → `hardcoded UI prose`,
  (c) sicildeki dosyaya yeni literal → `TR literal debt grew 29 -> 30`.
  Enjeksiyonlar geri alındı; çalışma ağacı temiz.
- **Ölçüm:** `flutter test` **1555/1555 yeşil** (öncesi 1514; +41'in 9'u bu
  kartın yeni `nudge_error_l10n_test.dart` dosyası) · `flutter analyze` 0 uyarı ·
  `python scripts/l10n_audit.py` OK (1494 anahtar, borç 379/18 dosya) · commit
  `78d570f`.
- **Kapsam dışı bırakılan, açıkça kalan borç:** `goal_card.dart` ·
  `group_goal_card.dart` · `study_timer_card.dart` içindeki `'hedef serisi'` /
  `'grup serisi'` metinleri kapı tarafından **ilk kez görüldü**; WP-481 o
  rozetleri yeniden yazacağı için muafiyete gerekçeyle alındı ve WP-481 bitince
  o üç satır silinecek. `commonAyniKisiyiTekrarDurtmek` anahtarı placeholder'sız
  olduğu için kullanılmadı; **önceden de ölüydü**, silinmedi (§2: başkasının ölü
  kodu ayrı WP).

#### WP-478 — Ünvan seçimi ekrandan çıkınca kayboluyor (profil önbelleği tazelenmiyor)

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam (`Cihazda doğrulanmalı`).
  WP-479 bundan sonra.
- **Belirti (V57-N02 birinci yarısı):** Ünvan seçiliyor, grup listesinde doğru
  görünüyor, ama Başarımlar ekranına tekrar girince "No title selected" yazıyor.
- **Kök neden (kodda doğrulandı):** Ünvan sunucuya **yazılıyor**, istemci
  önbelleği **tazelenmiyor**.
  [`supabase_auth_repository.dart:436-457`](app/lib/data/repositories/supabase/supabase_auth_repository.dart:436)
  `updateTitle` satırı günceller ve `_current`'ı yeniler, ama
  `authStateChanges()` akışı **yalnız iki yerde** yayın yapıyor: ilk okuma
  ([`:44-45`](app/lib/data/repositories/supabase/supabase_auth_repository.dart:44))
  ve auth durumu değişimi
  ([`:61-62`](app/lib/data/repositories/supabase/supabase_auth_repository.dart:61)).
  Profil mutasyonlarının hiçbiri yeni değer yaymaz. `authStateProvider` bu
  akıştan beslendiği için
  ([`auth_providers.dart:43`](app/lib/data/providers/auth_providers.dart:43)),
  `AchievementsScreen` ekranı `ref.watch(authStateProvider).value` ile **bayat
  profili** okur ([`achievements_screen.dart:14`](app/lib/features/profile/achievements_screen.dart:14))
  ve `SocialProfileScreen.initState` `_selectedTitleId`'yi o bayat profilden
  kurar ([`social_profile_screen.dart:68`](app/lib/features/profile/social_profile_screen.dart:68)).
- **🔴 Bu tek bir alanın hatası değil.** Aynı yayınsız desen `updateDisplayName`
  (`:410`), `updateDailyGoal` (`:422`), `updateAnimal` (`:432`),
  `updateMonthlyReportOptIn` (`:467`) ve avatar (`:497`) için de geçerli. Bugün
  görünmemelerinin sebebi ilgili ekranların yerel `setState` tutması; ünvan
  farklı çünkü **iki ayrı ekran** aynı gerçeği okuyor.
- **Neden mevcut testler yakalamadı:** `initState`'teki tazeleme listesi
  başarım/gamification/ödül sağlayıcılarını içeriyor ama **profil sağlayıcısını
  içermiyor** ([`social_profile_screen.dart:70-80`](app/lib/features/profile/social_profile_screen.dart:70));
  InMemory repository ise `_current`'ı doğrudan döndürdüğü için testte fark
  görünmez.
- **Yapılacak:** `SupabaseAuthRepository`'ye profil mutasyonlarından sonra
  yayın yapan tek bir nokta ekle (broadcast controller ya da `_emit(_current)`)
  ve `updateTitle` dahil altı mutasyonu ona bağla. Ekran tarafında ek `invalidate`
  ile **maskeleme yapılmaz** — kök neden repository katmanındadır.
- **Kapsam dışı:** Ünvan seçici yerleşimi (WP-479), yeni l10n anahtarı,
  migration, `0115` ünvan-doğrulama trigger'ı.
- **Sahip yollar:** `app/lib/data/repositories/supabase/supabase_auth_repository.dart`,
  `app/lib/data/repositories/in_memory/in_memory_auth_repository.dart`,
  `app/test/data/auth_profile_emission_test.dart` (yeni).
- **Kabul (DoD):** Yeni test: `updateTitle` çağrısından sonra
  `authStateChanges()` **yeni** profili yayar (altı mutasyon için ayrı iddia) ·
  mutasyon kanıtı: yayını kaldır ⇒ test kırmızı · cihazda ünvan seçilip ekrandan
  çıkılıp girildiğinde ünvan duruyor.
- **Sonuç (2026-08-01):** `SupabaseAuthRepository`ye `_profileMutations`
  broadcast kanalı ve `_emitProfile()` eklendi; altı mutasyonun (`displayName`,
  `dailyGoal`, `animal`, `title`, `monthlyReportOptIn`, `avatar`) hepsi
  **yazma başarılı olduktan sonra** yayın yapıyor. `authStateChanges()` artık
  iki kaynağı birleştiriyor: oturum olayları (`_sessionProfiles()`, eski
  `async*` gövdesi aynen) + profil mutasyonları. Ekranlara `invalidate`
  eklenmedi — kök neden repository katmanındaydı.
- **`InMemoryAuthRepository` değişmedi:** zaten her mutasyonda `_controller.add`
  yapıyor. Boşluk yalnız Supabase uygulamasındaydı; testlerin bunu görmemesinin
  sebebi de buydu. Bu yüzden yeni test **gerçek PostgREST kablosunu** sürüyor
  (`supabase_wire_harness`), InMemory sahteyi değil.
- **Mutasyon kanıtı:** altı `_emitProfile()` çağrısı kaldırıldığında yeni testin
  **3'ü kırmızı**; dördüncü ("başarısız mutasyon yayın yapmaz") doğru biçimde
  yeşil kalıyor çünkü yokluk iddia ediyor. Kod geri alındı.
- **Ölçüm:** yeni `app/test/data/auth_profile_emission_test.dart` **4 test** ·
  tam paket **1570/1570 yeşil** (öncesi 1566) · `flutter analyze` 0 uyarı · l10n OK.
- **🔴 Yol boyu bulunan, düzeltilmeyen kusur (bildiriliyor, silinmedi):**
  `_sessionProfiles()` `await for` içinde askıdayken akışın `cancel()`i **hiç
  tamamlanmıyor** — `async*` üreticisi kaynak bir olay daha üretmedikçe
  çözülmüyor. Bu WP-478 **öncesinde de** vardı (akış doğrudan o üreticiydi) ve
  üretimde görünmüyor çünkü Riverpod iptali beklemiyor. Yeni `onCancel` bu
  cancel'ı bilerek **beklemiyor** ve gerekçesi kodda yazılı; kalıcı çözümü ayrı
  bir WP'dir.

#### WP-479 — Ünvan seçici: alt sayfa yerine butona bağlı menü, kaymayan yerleşim

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam (`Cihazda doğrulanmalı`).
  WP-478'den sonra yapıldı.
- **Belirti (V57-N02 ikinci yarısı):** Uzun bir ünvan seçilince "Choose title"
  butonu alt satıra kayıyor ve gereksiz yer kaplıyor.
- **🔴 Sahip kararı (bağlayıcı, tartışmaya kapalı):** Seçici **alttan açılan kart
  (bottom sheet) OLMAYACAK.** Ders seçimindeki gibi, **butonun bulunduğu yerde**
  açılan seçenek listesi olacak.
- **Kök neden (kodda doğrulandı):**
  1. Bugün seçici gerçekten bir alt sayfadır:
     [`achievement_showcase.dart:603-651`](app/lib/features/profile/widgets/achievement_showcase.dart:603)
     `_showTitlePicker` → `showModalBottomSheet`.
  2. Kayma `Wrap` yüzünden:
     [`achievement_showcase.dart:559-600`](app/lib/features/profile/widgets/achievement_showcase.dart:559)
     ünvan `Chip`'i ile `OutlinedButton.icon` aynı `Wrap` içinde; chip genişleyince
     buton bir sonraki `run`'a düşer ve kart yükselir.
- **Yapılacak:** `showModalBottomSheet` çağrısını, tetikleyen butona bağlı
  `MenuAnchor`/`PopupMenuButton` yüzeyine çevir; referans olarak **ders seçme**
  yüzeyi alınır (`showClockStyleMenu(iconContext, ref)` deseni
  [`study_timer_card.dart`](app/lib/features/classroom/widgets/study_timer_card.dart:270)
  içinde zaten kullanılıyor — aynı `Builder(iconContext)` kalıbı gerekir, yoksa
  menü doğru yere değil ekranın köşesine açılır). Yerleşimde `Wrap` yerine
  chip'i `Flexible` + `TextOverflow.ellipsis` ile sınırlayan tek satırlık `Row`
  kullan; ünvan ne kadar uzun olursa olsun buton yer değiştirmez.
- **Kapsam dışı:** Ünvan listesinin içeriği/sıralaması, "kazanılmamış ünvan"
  kuralı, `profileRemoveTitle` davranışı.
- **Sahip yollar:** `app/lib/features/profile/widgets/achievement_showcase.dart`,
  `app/test/features/profile/title_picker_test.dart` (yeni/güncel).
- **Kabul (DoD):** Testte `showModalBottomSheet` **çağrılmadığı** doğrulanır
  (bu, sahip kararının otomatik bekçisidir; yalnız "menü açıldı" demek kararı
  korumaz) · en uzun ünvan adıyla buton konumu değişmiyor (golden ya da konum
  iddiası) · dar telefon genişliğinde taşma yok · analyze temiz.
- **Sonuç (2026-08-01):** `showModalBottomSheet` **kalktı**; yerine
  `showAnchoredMenu<String>` (ders seçimindeki `showClockStyleMenu` ile aynı
  kalıp) ve tetikleyen buton `Builder(buttonContext)` ile sarmalandı — bu
  sarmalayıcı olmadan menü ekranın köşesinde açılıyor. "Ünvanı kaldır" menü
  değeri boş dize sentinel'i; `null` "kullanıcı menüyü kapattı" ile karışırdı.
- **Yerleşim:** `Wrap` → tek satırlık `Row`. Ünvan chip'i `Expanded` içinde,
  etiketi `maxLines: 1` + ellipsis; buton satırın sonunda **sabit** duruyor.
  Menü öğelerinin adları da ellipsis'li.
- **Mutasyon kanıtı (iki ayrı iddia):** (a) menüden önce bir alt sayfa açılacak
  olsa `NavigatorObserver` bekçisi **2 testi** kırmızıya düşürüyor — yani sahip
  kararı gerçekten korunuyor, "menü açıldı" demekle yetinilmedi; (b) `Row`
  tekrar `Wrap` yapılınca **4 testin hepsi** kırmızı. Kod her iki denemede de
  geri alındı.
- **Ölçüm:** yeni `app/test/features/profile/title_picker_test.dart` **4 test** ·
  mevcut `achievement_showcase_test` anahtarları (`profile-title-*`,
  `remove-profile-title`) korunduğu için o dosya değişmeden geçiyor · tam paket
  **1574/1574 yeşil** (öncesi 1570) · `flutter analyze` 0 uyarı · l10n OK.
- **Not:** `achievement_showcase.dart` deponun **CRLF** dosyalarından biri;
  düzenleme satır sonlarını korudu, `git diff` yalnız 132/102 satır (gerçek
  değişiklik), dosya geneli yeniden yazılmadı.

#### WP-480 — Görev tekrar metinleri seçilen aralığı söylesin

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam (`Cihazda doğrulanmalı`).
- **Belirti (V57-N03):** Görevde "kaç günde bir yenilensin" seçiliyor ama metin
  hâlâ "Refresh every day" diyor; açıklama eski.
- **Kök neden (kodda doğrulandı):** WP-449/450 N-günlük tekrarı getirdi
  (`upsert_user_task(p_interval_days, …)`, sunucu sözleşmesi `0109`/WP-472),
  ama üç yüzey de **sabit günlük** metni gösteriyor:
  [`tasks_screen.dart:746-747`](app/lib/features/clock/tasks_screen.dart:746)
  (anahtarın başlığı + `taskListDailyRefreshHint` alt metni),
  [`tasks_screen.dart:568`](app/lib/features/clock/tasks_screen.dart:568)
  (liste satırı) ve
  [`tasks_card.dart:296`](app/lib/features/home/widgets/tasks_card.dart:296)
  (ana ekran kartı). Aralık alanı yalnız anahtar açıkken ayrı bir `TextField`
  olarak beliriyor ([`tasks_screen.dart:754-765`](app/lib/features/clock/tasks_screen.dart:754));
  yani veri N gün, metin 1 gün.
- **Ek kusur:** `taskListDailyRefreshHint` "gece yarısı İstanbul'da yeniden
  aktif olur" diyor — bu N=1 için doğru, N>1 için **yanlış bilgi**.
- **Yapılacak:** Aralığa göre çoğullanan l10n anahtarları (`{days}` placeholder,
  `=1` özel hâli ile). Üç yüzey de aynı anahtardan beslenir; metin üretimi tek
  saf fonksiyona toplanır ki dördüncü bir yüzey eklendiğinde tekrar ayrışmasın.
- **Sahip yollar:** `app/lib/features/clock/tasks_screen.dart`,
  `app/lib/features/home/widgets/tasks_card.dart`, `app/lib/l10n/app_en.arb`,
  `app/lib/l10n/app_tr.arb`, ilgili testler.
- **Kabul (DoD):** N=1, N=2, N=7 için üç yüzeyde de metin aralığı doğru söylüyor ·
  ipucu metni N>1'de "her gece yarısı" iddiasında bulunmuyor · iki katalogda
  placeholder eşliği var (`l10n_audit.py` yeşil) · testler yeşil.
- **Sonuç (2026-08-01):** İki çoğullu l10n anahtarı açıldı —
  `taskListRepeatSummary` ve `taskListRepeatHint` (ikisi de `{days}` +
  `=1` özel hâli, TR+EN). Metin üretimi `core/tasks/task_deadline.dart`
  içindeki iki saf fonksiyona toplandı (`taskRecurrenceSummary`,
  `taskRecurrenceHint`); dosya zaten `taskDueDateLabel`/`taskRemainingShort`
  ailesini taşıyordu.
- **Düzenleyici artık canlı izliyor:** aralık alanına yazıldıkça anahtarın
  başlığı ve alt metni tazeleniyor (`onChanged` → `setState`). Gönderim ve metin
  aynı `_draftIntervalDays` getter'ından okuyor; iki ayrı yerde ayrıştırılırsa
  etiket ile kaydedilen değer birbirinden kayardı.
- **🔴 Kartla kod arasında bir sapma bulundu (durdurmayı gerektirmedi, bildiriliyor):**
  Kart `tasks_card.dart:296`yı "sabit günlük metin gösteren üçüncü yüzey" diye
  yazıyor, ama o satır **zaten** `intervalDays > 1` dalını taşıyordu; aynısı
  `tasks_screen.dart:497` rozeti için de geçerli. Yani metin üç değil **iki**
  yüzeyde yanlıştı: düzenleyici anahtarı (başlık + ipucu) ve liste satırı alt
  metni. Ana ekran kartı yine de ortak fonksiyona bağlandı (kartın "üç yüzey de
  aynı anahtardan beslenir" maddesi).
- **Kapsam dışı bırakıldı:** `_RecurrenceBadge` (liste satırındaki dar etiket)
  kısa sözcük dağarcığını (`Her 3 günde bir` / `Günlük`) koruyor; uzun özet
  cümlesi ikon yanındaki rozete sığmıyor ve mevcut `tasks_ia_wp450_test`
  iddiasını gereksiz yere kırardı.
- **Ölçüm:** yeni `app/test/features/clock/task_recurrence_text_test.dart`
  **7 test** (6 saf fonksiyon + 1 düzenleyiciyi gerçekten süren widget testi;
  saf fonksiyon doğru olup yüzeyin onu çağırmaması tam olarak bu fazın
  "bitmiş backend + bağlanmamış UI" deseni) · tam paket **1581/1581 yeşil**
  (öncesi 1574) · `flutter analyze` 0 uyarı · l10n OK (1496 anahtar).

#### WP-481 — Seri göstergesi: chess.com modeli, daima görünür, kişisel + grup

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam (`Cihazda doğrulanmalı`).
  **WP-455'in açık kabulünü kapatır** (yalnız görsel kanonikleşme; ekonomi ayrı).
- **🔴 Sahip kararı (bağlayıcı, V57-N04 + V57-N05):**
  1. Rozet **her zaman görünür**, seri 0 iken bile.
  2. Üç durum: (a) sıfırlanmış → **gri soluk alev + "0"**; (b) duraklatma →
     **pause işareti** (dün kaçtı, bugün de kaçarsa 0); (c) bugünün hedefi
     tamam → **renkli ateş**.
  3. **Koruma hakkı sınırsızdır.** Gün atlayarak 100 günde 50 kez hedefi tutturan
     kullanıcı 50 seriye sahiptir.
  4. **Aynı model grup hedefinde de geçerlidir.**
- **İyi haber — motor zaten var ve sahibin kuralıyla birebir:**
  [`goal_streak_projection.dart:51-69`](app/lib/core/stats/goal_streak_projection.dart:51)
  iki günlük boşluğu seriyi bozmadan geçirir (`inDays > 2` ⇒ sıfırla) ve beş
  durum üretir: `completedToday` · `pendingToday` · `atRisk` · `expired` ·
  `empty`. Sunucu karşılığı `0112`, yazıcısı yalnız `record_goal_completion`.
  Rozet widget'ı da yazılmış:
  [`goal_streak_flame.dart`](app/lib/features/stats/widgets/goal_streak_flame.dart:19)
  (WP-454, 12 test + 3 golden).
- **🔴 Kök neden: hiçbiri bağlı değil.** `GoalStreakFlame`in `app/lib` içinde
  **tek bir çağrı yeri yok**; `goalStreakProjectionProvider` yalnız kendi tanım
  dosyasında geçiyor. Ekranlar bunun yerine eski, **grace'siz** motoru okuyor:
  [`currentStreakProvider`](app/lib/data/providers/study_providers.dart:161) →
  [`currentStreak()`](app/lib/core/stats/study_stats.dart:212), ki o "tutturamadığın
  gün sıfırlanır" der. Sahibin istediği duraklatma bu motorda **yok**.
- **Görünürlük kapısı:** [`study_timer_card.dart:289`](app/lib/features/classroom/widgets/study_timer_card.dart:289)
  `if (streak > 0)` — sahibin "hiç seri yokken bile görünsün" maddesinin tam
  karşılığı. Grup tarafında `group_goal_card.dart:86` `currentStreak(const [], …)`
  ile besleniyor, yani grup serisi de eski motordan.
- **Yapılacak:**
  1. `study_timer_card` sol üst rozetini `GoalStreakFlame` +
     `goalStreakProjectionProvider(GoalStreakScope.personal(userId))` ile besle;
     `if (streak > 0)` kapısını **kaldır** (`empty`/`expired` durumu gri alev + 0).
  2. Aynısını grup hedef kartına `GoalStreakScope.group(...)` ile uygula.
  3. `currentStreakProvider`'ı bu iki yüzeyden **çıkar**; iki motorun aynı ekranda
     yaşamasına izin verme.
  4. `pendingToday` (dün tamam, bugün henüz yapılmadı) sahibin üç durumunda
     adlandırılmamıştır. **Karar: canlı/renkli alev** — seri yaşıyor ve risk
     yok; `atRisk` (pause) yalnız dün kaçırıldığında gösterilir. Bu ayrım
     testle sabitlenir, yoruma bırakılmaz.
- **🔴 Kapatılması gereken çelişki (WP-455'ten devralındı):** Repo'da üç seri
  tanımı aynı geçmişte farklı sayı veriyor — `goal_streak_projection` (`0112`)
  **3**, `_achievement_metrics.streak_days` (`0025` gövdesi) **1**,
  `currentStreakWithFreezes` (`gamification.dart`) bakiyeye göre **1 veya 3**.
  Sahip kararı artık nettir: **kanonik olan grace'li projeksiyondur ve koruma
  hakkı sınırsızdır**, yani tüketilebilir `streak_freezes` bakiyesi bu modelde
  anlamsızdır. ⚠️ `streak_days`i grace'li yapmak `fire_streak` XP kademelerini
  (7/30/150/365/730/1000) besleyen metriği değiştirir ve mevcut kullanıcıların
  kademesini **geriye dönük yükseltir**. Bu bir ekonomi kararıdır; kart bu
  kartın içinde **uygulanmaz**, ayrı bir migration WP'sine ayrılır. Bu kart
  yalnız **görselin kanonik projeksiyondan okunmasını** sağlar — böylece ekranda
  tek gerçek kalır.
- **Sahip yollar:** `app/lib/features/classroom/widgets/study_timer_card.dart`,
  `app/lib/features/home/widgets/group_goal_card.dart`,
  `app/lib/features/home/widgets/goal_card.dart`,
  `app/lib/features/stats/widgets/goal_streak_flame.dart` (yalnız gerekiyorsa),
  ilgili widget/golden testleri.
- **Kabul (DoD):** Seri 0 iken rozet **görünür** ve gri alev + "0" gösterir ·
  `atRisk`'te pause işareti çıkar · `completedToday`'de renkli ateş · gün
  atlayarak 50 kez hedef tutturan senaryo **50** verir (sahibin örneği birebir
  test edilir) · aynı üç durum grup kapsamında da doğrulanır · `currentStreak()`
  bu iki yüzeyin hiçbirinden çağrılmıyor (grep iddiası testle sabitlenir) ·
  ⚠️ golden'lar **ikon değişimini göremez** (WP-454 notu: `flutter test` gerçek
  MaterialIcons fontunu yüklemez), bu yüzden durum→ikon ayrımı `Icon.icon`
  alanını doğrudan okuyan testle taşınır.
- **Sonuç (2026-08-01):** Yeni `GoalStreakBadge` (provider'a bağlı sarmalayıcı,
  `goal_streak_flame.dart`) **üç yüzeye** kondu: `study_timer_card` sol üst
  rozeti, `goal_card` (iki yerleşim) ve `group_goal_card` (iki yerleşim).
  `if (streak > 0)` kapısı kalktı, rozet artık daima görünüyor; kapsam/akış
  hazır değilken bile boş projeksiyonla gri alev + "0" çiziliyor.
- **İki motor ayrımı kapandı:** `currentStreakProvider` bu üç yüzeyin
  hiçbirinden okunmuyor (kaynak dosyaları tarayan test bunu sabitliyor).
  `study_timer_card`taki `_StreakChip` (45 satır) öksüz kaldığı için silindi.
- **Sahip kararının görsel karşılığı:** `empty`/`expired` → gri soluk alev
  (eskiden gece ikonuydu, "seri yok" demiyordu) · `atRisk` → **pause** işareti
  (eskiden uyarı üçgeni) · `completedToday` → renkli ateş · `pendingToday` →
  **canlı** turuncu alev (eskiden griydi ve "sıfırlanmış" ile karışıyordu);
  kartın kararı gereği pause yalnız dün kaçırılınca gösteriliyor.
- **Sahibin sayısal örneği testte:** gün atlayarak 100 günde 50 kez hedef
  tutturan senaryo `projectGoalStreak` üzerinden **50** veriyor (koruma
  sınırsız). Aynı üç durum grup kapsamında da doğrulanıyor.
- **🔴 Ekonomiye DOKUNULMADI (kapsam dışı, bilerek):** `_achievement_metrics.streak_days`,
  `fire_streak` XP kademeleri ve `currentStreakWithFreezes` **değişmedi**; hiçbir
  migration yazılmadı. Grace'li metriğe geçmek mevcut kullanıcıların kademesini
  geriye dönük yükseltirdi; bu ayrı bir ekonomi WP'sidir. `git diff` bu turda
  gamification/migration dosyası içermiyor.
- **WP-477 borcu kapandı:** `'hedef serisi'` / `'grup serisi'` gömülü metinleri
  rozetle birlikte kalktı; `l10n_audit.py`deki üç geçici muafiyet **silindi**.
- **Golden notu:** `goal_streak_flame_light/dark.png` yeniden üretildi (renk
  değişimi görünüyor); ikon değişimi goldende görünmez, o yüzden `Icon.icon`
  testi kanıt. `compact_scale` goldeni değişmedi çünkü taşıdığı iki durumun
  rengi aynı kaldı.
- **Dar kart taşması:** `dashboard_cards_render_test` minik boyutta 39 px taşma
  gösterdi (rozet eski çipten geniş); kapsam etiketi erişilebilirlik için
  kaldırılmadı, bunun yerine minik yerleşimde `FittedBox(scaleDown)` kullanıldı.
- **Ölçüm:** yeni `app/test/features/stats/goal_streak_surface_wp481_test.dart`
  **9 test** · tam paket **1590/1590 yeşil** (öncesi 1581) · `flutter analyze`
  0 uyarı · l10n OK.

#### WP-482 — Ana ekran widget'ı çoklu cihaz senkronunu almıyor (tanı, salt-okunur)

- **Durum / bağımlılık:** [ ] Bekliyor · **Sahibin iki cihazını gerektirir.**
  Bu kart **kod yazmaz**; çıktısı teşhis ve düzeltme kartının kapsamıdır.
- **Belirti (V57-N06):** "Bildirimde çift cihazda çalışıyor ama Android ana ekran
  widget'ında olmuyor; o senkronu bozdu."
- **Neden önce tanı:** V56-S01 turunda "kısa yama" denemesi üç ayrı yüzde geri
  gelmişti (WP-431 notları). Belirti iki farklı arızayla uyumlu ve ikisi ayrı
  düzeltme ister; ölçmeden yazmak yanlış yeri onarır.
- **Kodda bulunan üç somut şüpheli (hepsi doğrulandı, hiçbiri henüz kanıt değil):**
  1. **Widget, Dart'ın yazdığı anahtarların hiçbirini okumuyor.**
     `_syncTimerWidget()` `timer_elapsed` / `timer_status` / `timer_action`
     alanlarını yazıyor
     ([`study_providers.dart:2556-2600`](app/lib/data/providers/study_providers.dart:2556)),
     ama `TimerWidgetProvider.onUpdate` bu üç anahtarı **hiç kullanmıyor**;
     durumu tamamen native store'dan türetiyor
     ([`StudyWidgetProviders.kt:65-107`](app/android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/StudyWidgetProviders.kt:65)).
     Yani Dart tarafındaki her "widget'ı tazele" çağrısı timer widget'ı için
     **ölü yazımdır**; widget yalnız `flutter.timer_active_started_at_ms`
     anahtarını ve `TimerWidgets.updateAll` broadcast'ini görür.
  2. **Kronometre yalnız stopwatch modunda akıyor.**
     [`StudyWidgetProviders.kt:86`](app/android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/StudyWidgetProviders.kt:86)
     `if (isRunning && mode == "stopwatch")`; countdown/pomodoro'da widget
     çalışırken bile `00:00` gösterir. Ayna koşusu modu zorla `stopwatch`
     yapıldığı için ([`study_providers.dart:1155`](app/lib/data/providers/study_providers.dart:1155))
     bu dal ayna cihazda kapanır — ama **kaynak** cihazda pomodoro ile çalışan
     kullanıcı için açıktır.
  3. **Widget eylemi yalnız kuyruğa yazıyor.** Widget düğmesi native'e gider
     ([`TimerActionReceiver.kt:23`](app/android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/TimerActionReceiver.kt:23)),
     `appendV2Command(... origin="widget")` zarfı **kalıcı kuyruğa** yazılır
     ([`TimerStateStore.kt:220-278`](app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/TimerStateStore.kt:220)),
     ve sunucuya **Dart flush'ı** taşır. Uygulama süreci ölüyken (widget'tan
     başlatma tipik olarak böyledir) komut cihazda bekler; karşı cihaz Flutter
     motoru uyanana kadar hiçbir şey görmez. `canonicalV2Origin("native_widget")`
     = `"widget"` olduğu için zarf üretiliyor — yani **origin çevirisi sağlam**,
     şüphe taşıma katmanında.
- **İstenen ölçüm (iki cihaz, her adımda journal + `pending_intervals` dökümü):**
  A→B ayna başlatma; B widget'ından durdurma; A widget'ından durdurma;
  uygulama süreci kapalıyken widget'tan başlatma; pomodoro modunda widget
  görünümü; ayna cihazda widget metni. Her satır için: widget ne gösterdi,
  `timer_active_started_at_ms` var mıydı, zarf kuyruğa yazıldı mı, sunucuya
  ne zaman gitti.
- **Kapsam:** Salt-okunur. Kod değişikliği, migration ve yeni test **yok**;
  çıktı `docs/qa/` altında kanıt dosyası + hangi şüphelinin doğrulandığı.
- **Sahip yollar:** `docs/qa/V57-WIDGET-SYNC-EVIDENCE.md` (yeni), `progress.md`
  (yalnız bu kart).
- **Kabul (DoD):** Üç şüpheliden her biri için **doğrulandı / elendi** kararı ve
  onu veren gözlem · belirti tekrar üretildi ya da üretilemediği kaydedildi ·
  düzeltme kartının kapsamı tek cümleyle yazıldı.

#### WP-483 — Dürtme susturmanın grup yüzeyinde tetikleyicisi yok (ölü özellik)

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam (`Cihazda doğrulanmalı`).
- **Belirti (V57-N07):** "Muted kısmı var ayarlarda ama grupta mute işaretini
  bulamadım; eklememiş de olabilirsin."
- **Kök neden (kodda doğrulandı — sahip haklı, gerçekten eklenmemiş):**
  `muteNudgesFrom` arayüzde tanımlı
  ([`nudge_repository.dart:61`](app/lib/data/repositories/nudge_repository.dart:61)),
  iki repository'de de uygulanmış, **ama `app/lib` içinde hiçbir yerden
  çağrılmıyor** — tek çağıranlar `app/test/data/nudge_mute_test.dart` ve
  `app/test/data/group_race_matrix_wp447_test.dart`. Ayarlardaki ekran yalnız
  **listeler ve susturmayı kaldırır**
  ([`muted_nudges_screen.dart:91`](app/lib/features/safety/muted_nudges_screen.dart:91)
  `unmuteNudgesFrom`). `safetyMuteNudges` ("Dürtmesini sustur" / "Mute nudges")
  l10n anahtarının da **hiçbir kod yolundan** çağrısı yok — ölü string.
- **Sonuç:** Kullanıcının birini susturmasının **hiçbir yolu yoktur**; ayarlardaki
  liste tanımı gereği hep boştur. WP-444 sunucuyu, RLS'i, yan-kanal korumasını
  ve testleri yazdı; tetikleyiciyi yazmadı ve testler InMemory katmanı sürdüğü
  için boşluk yeşil göründü (bu fazın 3. sistemik bulgusu).
- **Yapılacak:** Grup üye satırına ve dürtme bildirimi yüzeyine "Dürtmesini
  sustur" eylemi ekle; mevcut `safetyMuteNudges` anahtarını kullan (yeni string
  yazma). Susturulmuş üye satırında **görünür bir işaret** olsun — sahip "mute
  işaretini bulamadım" derken göstergeyi de kastediyor.
- **🔴 Yan kanal kuralı korunur:** WP-444 sözleşmesine göre susturulmuş alıcıya
  gönderim **başarılı görünür**; gönderen tercihi okuyamaz. Susturma işareti
  yalnız **susturan kişinin kendi** ekranında görünür, gönderende asla.
- **Sahip yollar:** `app/lib/features/classroom/widgets/class_detail_screen.dart`,
  `app/lib/features/notifications/notification_center_screen.dart`,
  `app/lib/features/safety/muted_nudges_screen.dart`, ilgili testler.
- **Kabul (DoD):** Grup üye satırından susturma yapılabiliyor · susturulan üye
  işaretli görünüyor · ayarlardaki liste yeni kaydı gösteriyor · gönderen
  tarafında hiçbir fark yok (yan-kanal iddiası test edilir) · `muteNudgesFrom`
  artık `lib/` içinden çağrılıyor (bu, "ölü özellik" regresyonunun bekçisidir).
- **Sonuç (2026-08-01):** Grup üye satırına `_MuteNudgeButton` eklendi;
  susturma/geri alma aynı düğmede. Susturulmuş üyenin **görünür işareti** dolu
  `Icons.notifications_off` + `colorScheme.error` tonu, tooltip da
  `safetyUnmuteNudges`e dönüyor. `mutedNudgeSenderIdsProvider` ve
  `nudgeMutesProvider` işlem sonrası tazeleniyor, yani ayarlardaki liste anında
  yeni kaydı gösteriyor. **Yeni l10n anahtarı yazılmadı** — kartın istediği gibi
  mevcut `safetyMuteNudges` / `safetyUnmuteNudges` / `safetyNudgesMuted`
  anahtarları kullanıldı; `safetyMuteNudges` ilk kez bir kod yolundan çağrılıyor.
- **Ölü özellik kapandı:** `grep muteNudgesFrom app/lib` artık tanımların yanında
  gerçek bir **çağrı yeri** gösteriyor
  ([class_detail_screen.dart:1169](app/lib/features/classroom/widgets/class_detail_screen.dart:1169));
  eskiden yalnız iki test dosyası çağırıyordu.
- **Yan kanal korundu:** Susturma tercihi hesap kapsamlı olduğu için karşı
  tarafın ekranında hiçbir işaret çıkmıyor; test bunu ikinci bir izleyiciyle
  (susturulan üyenin kendi görünümü) doğruluyor. Gönderim yolu hiç değişmedi.
- **Ölçüm:** yeni `app/test/features/classroom/nudge_mute_trigger_test.dart`
  **4 test** (biri gerçek çağrıyı sayan spy repository ile) · tam paket
  **1563/1563 yeşil** (öncesi 1559) · `flutter analyze` 0 uyarı ·
  `python scripts/l10n_audit.py` OK.
- **Kapsam notu:** Kartın "dürtme bildirimi yüzeyi" maddesi uygulanmadı çünkü
  **uygulamada gelen dürtmeleri listeleyen bir ekran yok** — `receivedNudgesProvider`
  yalnız `nudge_notification_listener` tarafından tüketiliyor, dürtme sistem
  bildirimi olarak çıkıyor. `notification_center_screen` bir tercih ekranıdır,
  kişi listesi taşımaz; ayarlardaki susturulanlar listesine giriş zaten
  `settings_screen.dart:292`de var. Eylem bu yüzden tek gerçek yüzeye (grup üye
  satırı) kondu.

#### WP-484 — Çalışan üyeyi dürtme denemesi sessiz kalıyor

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam (`Cihazda doğrulanmalı`).
  WP-477'den sonra yapıldı.
- **Belirti (V57-N08 davranış yarısı):** "Bir kere çıktı, daha çıkmadı. Her
  denediğinde araya bir delay koyup uyarıyı göstermek lazım."
- **Kök neden (kodda doğrulandı):** İki farklı yol var ve ikincisi sessiz.
  1. **Sunucu reddi:** yerel presence bayatken düğme etkin kalır, çağrı gider,
     `recipient_is_studying` döner ve SnackBar çıkar
     ([`class_detail_screen.dart:1056-1057`](app/lib/features/classroom/widgets/class_detail_screen.dart:1056)).
     Sahibin **bir kez** gördüğü uyarı budur.
  2. **İstemci kapısı:** presence güncellenince düğme `onPressed: null` olur
     ([`class_detail_screen.dart:914-919`](app/lib/features/classroom/widgets/class_detail_screen.dart:914)).
     Devre dışı `IconButton` dokunmaya **hiç tepki vermez**; açıklama yalnız
     `tooltip`tedir ([`:906-908`](app/lib/features/classroom/widgets/class_detail_screen.dart:906))
     ve tooltip mobilde **uzun basmayla** çıkar. Kullanıcı dokunur, hiçbir şey
     olmaz. "Daha çıkmadı" bu.
- **Yapılacak:** Düğmeyi devre dışı bırakmak yerine **etkin bırak ve dokununca
  açıklamayı göster**; metin mevcut `classroomStudyingNudgeUnavailable`
  anahtarından okunur (EN karşılığı katalogda var, doğrulandı — yeni string
  gerekmez). Tekrarlı dokunuşta SnackBar kuyruğu şişmesin diye sahibin istediği
  gecikme: aynı alıcı için kısa bir bastırma penceresi (`ScaffoldMessenger`
  `hideCurrentSnackBar` + üye başına son gösterim zamanı). Sunucuya **çağrı
  yapılmaz** — kapı istemcide kalır, aksi hâlde spam koruması boşa çıkar.
- **Kapsam dışı:** Sunucu tarafı `recipient_is_studying` kuralı (`0116`),
  cooldown süresi, dürtme dönüşüm metriği.
- **Sahip yollar:** `app/lib/features/classroom/widgets/class_detail_screen.dart`,
  `app/test/features/classroom/nudge_studying_feedback_test.dart` (yeni).
- **Kabul (DoD):** Çalışan üyenin dürtme düğmesine dokunmak **her seferinde**
  görünür açıklama veriyor · art arda dokunuşta uyarı üst üste yığılmıyor ·
  bastırma penceresi dolunca uyarı **tekrar** çıkıyor (yalnız "bir kez göster"
  regresyonu bu iddiayla kapanır) · çalışmayan üyede davranış değişmedi.
- **Sonuç (2026-08-01):** Dürtme düğmesi satır içinde kurulan `IconButton`
  olmaktan çıkıp kendi durumunu taşıyan `_NudgeButton`a dönüştü (üye kimliğiyle
  `ValueKey`). `onPressed` artık yalnız **oturum yokken** null; çalışan üyede
  düğme etkin ve dokununca `classroomStudyingNudgeUnavailable` SnackBar olarak
  çıkıyor. Sunucuya çağrı yok — kapı istemcide kaldı.
- **Bastırma penceresi sabit süre değil, uyarının kendi ömrü.** `_notice` alanı
  ekrandaki `ScaffoldFeatureController`ı tutuyor; `notice.closed` tamamlanınca
  temizleniyor. Böylece "yığılmasın" ile "her seferinde çıksın" aynı mekanizmadan
  geliyor ve testte sahte saat gerekmiyor (uyarı kapanınca aynı üyeye tekrar
  dokunmak yeniden gösteriyor).
- **Mutasyon kanıtı:** `onPressed`'e `|| widget.isRecipientStudying` geri
  eklendiğinde (eski davranış) yeni testin **3'ü birden kırmızı** oluyor; kod
  geri alındı ve çalışma ağacı temiz bırakıldı.
- **Ölçüm:** yeni `app/test/features/classroom/nudge_studying_feedback_test.dart`
  **4 test** · tam paket **1559/1559 yeşil** (öncesi 1555) · `flutter analyze`
  0 uyarı · `python scripts/l10n_audit.py` OK.
- **Test tuzağı kayda geçti:** `ScaffoldMessenger` görünürlük sayacını ancak
  giriş animasyonu bitince kuruyor. Tek büyük `pump(6 sn)` ile atlanırsa sayaç
  hiç kurulmaz ve test "uyarı kapanmadı" diye yanlış yere düşer; önce
  `pump(750 ms)`, sonra `pump(5 sn)` gerekiyor.

#### WP-485 — Yönetici konuşması: realtime yok, push yok, bildirim çok geç

- **Durum / bağımlılık:** [x] Kod + kapılar tamam · **`Replay bekliyor`** ·
  `Cihazda doğrulanmalı`. Migration `0117`. WP-486 bundan sonra.
- **Belirti (V57-N09 sistem yarısı + V57-N10):** Yönetici mesaj gönderiyor, mesaj
  karşıya gidiyor ama **kendi ekranında görünmüyor**; ne karşı tarafa ne de
  yöneticiye bildirim düşüyor; düşen bildirimler de **çok geç** geliyor.
- **🔴 N10 ayrı bir arıza değil, aynı kökün üçüncü yüzü.** "Geç geliyor" denen
  şey gecikme değil, **yokluk**tur: canlı yayın olmadığı için mesaj ancak ekran
  yeniden veri çektiğinde (sekme değişimi, ekran açılışı, uygulama yeniden
  başlatma) görünür. Kullanıcı bunu "geç geldi" diye okur. Ayrı kart açılmaz;
  bu kartın kabulüne **gecikme ölçümü** eklenir.
- **Kök neden 1 — tablo realtime yayınında değil (kodda doğrulandı):**
  `watchTicketMessages` Supabase `.stream()` kullanıyor
  ([`supabase_admin_repository.dart:459-477`](app/lib/data/repositories/supabase/supabase_admin_repository.dart:459)),
  yani WAL olaylarına bağlıdır. Ama `public.feedback_ticket_messages`
  **`supabase_realtime` publication'ına hiç eklenmemiş**: `0074` tabloyu ve
  RLS'i kuruyor, `alter publication` satırı yok; `0103` ve `0114` de eklemiyor.
  Karşılaştırma için `feedback_tickets` **eklenmiş**
  ([`0018_admin_feedback.sql:176`](supabase/migrations/0018_admin_feedback.sql:176)),
  `nudges` eklenmiş ([`0016_nudges.sql:118`](supabase/migrations/0016_nudges.sql:118)).
  Sonuç: akış yalnız **ilk okumayı** verir, sonra hiç güncellenmez. Gönderen
  kendi mesajını görmez; karşı taraf ekranı yeni açtığı için ilk okumada görür.
  Belirtinin ikisi de tek nedenden çıkar.
- **Kök neden 2 — mesaj için push outbox tetikleyicisi yok (kodda doğrulandı):**
  `0066` push zincirinde yalnız iki üretici var: `nudges_enqueue_push`
  ([`0066:325`](supabase/migrations/0066_push_notification_delivery.sql:325)) ve
  `announcements_enqueue_push` ([`0066:376`](supabase/migrations/0066_push_notification_delivery.sql:376)).
  `feedback_ticket_messages` için hiçbir tetikleyici yok, dolayısıyla **iki yönde
  de** bildirim doğmaz. Bu bir teslim hatası değil, eksik yüzeydir.
- **Yapılacak (`0117`):**
  1. `alter publication supabase_realtime add table public.feedback_ticket_messages;`
     — mevcut migration'lardaki koşullu (`if not exists … where pubname`) kalıbı
     izle, aksi hâlde tekrar apply patlar.
  2. `feedback_ticket_messages` için `after insert` push tetikleyicisi: alıcı
     **karşı taraftır** (kullanıcı yazdıysa yönetici(ler), yönetici yazdıysa
     bilet sahibi). Gönderene kendi mesajının push'u **gitmez**.
  3. 🔴 `0116` dersini tekrarla: bildirim gövdesi **data-only** kalır;
     `android.notification` bloğu eklenirse mesaj bozulur ve yanına içeriksiz
     ikinci bildirim düşer.
  4. Head'i **üç yerde birden** `0117`e al: `tooling/release/deploy-contract.json`,
     `supabase/tests/001_schema_contract.test.sql`, `tooling/supabase/guard.tests.ps1`.
- **Neden istemci yaması yeterli değil:** Gönderim sonrası elle `refetch` etmek
  gönderenin ekranını düzeltir ama **alıcının** ekranı yine donuk kalır ve
  bildirim hâlâ doğmaz. Kök neden sunucudadır.
- **Sahip yollar:** `supabase/migrations/0117_feedback_message_realtime_push.sql`,
  `supabase/tests/001_schema_contract.test.sql`,
  `tooling/release/deploy-contract.json`, `tooling/supabase/guard.tests.ps1`,
  `supabase/tests/039_feedback_message_push.test.sql` (yeni),
  `app/test/data/admin_repository_test.dart` (gerekirse).
- **Kabul (DoD):** pgTAP: tablo publication üyesi · mesaj insert'i **karşı taraf
  için** outbox satırı doğuruyor, gönderen için doğurmuyor · üç head pini hizalı
  (`guard.tests.ps1` yeşil) · `Replay bekliyor` etiketi ve Database Gates local
  replay job kanıtı · cihazda: yönetici mesajı kendi ekranında **anında**
  görünüyor, karşı tarafa bildirim düşüyor · **gecikme ölçülür**: mesaj
  gönderiminden karşı cihazda görünmesine kadar geçen süre kaydedilir (V57-N10
  yalnız bu ölçümle kapanır; "artık hızlı" demek kanıt değildir).
- **Sonuç (2026-08-01):** `0117_feedback_message_realtime_push.sql` üç şey
  yapıyor: (1) tabloyu `supabase_realtime` publication'ına ekliyor (0016/0018
  ile aynı koşullu `duplicate_object` kalıbı, tekrar apply patlamaz);
  (2) `notification_outbox` tip kısıtını `feedback_message` ile genişletiyor
  (0083 kalıbı: adı ne olursa olsun eski CHECK düşürülüp yenisi adlandırılmış
  eklenir); (3) `after insert` tetikleyicisi ekliyor.
- **Yön ayrımı tetikleyicinin özü:** kullanıcı yazdıysa alıcılar `app_admins`,
  yönetici yazdıysa bilet sahibi. `recipient.user_id is distinct from
  new.sender_id` filtresi, yöneticinin aynı zamanda bilet sahibi olduğu
  durumu da kapatıyor — gönderen kendi mesajının push'unu almıyor.
- **Sessiz bir ikinci arıza yakalandı:** `_push_type_enabled` bilinmeyen tipte
  `invalid_push_notification_type` fırlatıyor. Yalnız tetikleyici eklenseydi
  `claim_push_deliveries` her turda patlar ve **hiçbir** bildirim gitmezdi.
  Fonksiyon yeni tiple birlikte yeniden tanımlandı. `feedback_message` için
  ayrı cihaz bayrağı **bilerek** açılmadı: bu bir yayın değil, kullanıcının
  kendi açtığı biletin yanıtıdır; duyuru bayrağına bağlanırsa duyuruları
  kapatan kullanıcı destek yanıtını da kaçırır. Sessiz saatler yine geçerli.
- **Edge Function'a dokunulmadı.** `dispatch-push` bilinmeyen tipleri genel
  daldan (`payload.title` / `payload.body`) üretiyor, bu yüzden yük o iki alanı
  taşıyor. `0116` dersi korundu: **data-only**, `android.notification` bloğu
  eklenmedi.
- **Head üç yerde:** `deploy-contract.json` `local_migration_head` → `0117`;
  `001_schema_contract.test.sql` → 117 / `0117`; `guard.tests.ps1` gerekçe notu.
  🔴 Staging ve production head'leri **bilerek `0116`da bırakıldı** — `0117`
  hiçbir ortama uygulanmadı ve bu kart hiçbir kapı açmıyor. Dört deploy/release
  bayrağı `false`.
- **Kapılar:** `guard.tests.ps1` **75/75** · `release-preflight.tests.ps1`
  **8/8** (beta senaryosu "yerel head 0117 staging 0116'nın önünde" diyerek
  doğru biçimde fail-closed düşüyor) · `flutter test` **1590/1590** ·
  `flutter analyze` 0 uyarı · l10n OK.
- **🔴 `Replay bekliyor`:** Docker bu hostta kalkmıyor, yerel pgTAP replay
  koşulamadı. Kanıt Database Gates workflow'unun local replay job'ından alınır.
- **Test dosyası adı kartla farklı:** kart `039_feedback_message_push.test.sql`
  diyordu ama 039–042 aradan geçen WP'lerle dolmuş; dosya
  `supabase/tests/043_feedback_message_push.test.sql` olarak açıldı (**10 pgTAP
  iddiası**: publication üyeliği, tip kısıtı, `_push_type_enabled`, iki yönde
  alıcı doğruluğu, gönderene gitmeme ve yük alanları).
- **🔴 CI iki gerçek kusur yakaladı — "Replay bekliyor" boşuna değildi:**
  (1) test mesaj satırını **doğrudan** insert ediyordu ve `client_message_id`
  NOT NULL kısıtına takıldı; o kolon `0074`te değil `0103`te eklenmiş. Ham
  insert `message_seq` sözleşmesini de atlıyordu, yani test üretimdeki yazma
  yolunu hiç sınamıyordu. Test artık bilet açılışında `0103` seed
  tetikleyicisini, yanıtta `send_feedback_ticket_message` RPC'sini sürüyor.
  (2) `plan(9)` ile 10 iddia koşuluyordu (`lives_ok` sayılmamıştı). **Migration
  `0117` her iki turda da değişmedi; kusur yalnızca testteydi.**
- **İstemci değişmedi:** `watchTicketMessages` zaten `.stream()` kullanıyor
  ([supabase_admin_repository.dart:463](app/lib/data/repositories/supabase/supabase_admin_repository.dart:463));
  akış tablo yayına girer girmez çalışacak. Gönderim sonrası elle `refetch`
  eklenmedi — kök neden sunucudaydı, istemci yaması alıcının ekranını yine
  donuk bırakırdı.

#### WP-486 — Yönetici yüzeyi: arayüz ve akış revizyonu

- **Durum / bağımlılık:** [ ] Bekliyor · **WP-485 kapandıktan sonra.** Sistem
  hatası dururken arayüz düzeltmek kanıtı bulandırır.
- **Sahip talebi (V57-N09 ikinci yarısı, aynen):** "Admin tarafında iyileştirmeler
  var ama hâlâ sorunlar var; arayüzden tut sisteme kadar bunlarda daha iyi
  profesyonelleşmemiz lazım, detaylı titiz bir çalışma lazım."
- **Neden ayrı kart:** Bu bir hata değil, kalite talebidir; WP-485'in kabulüne
  karıştırılırsa ikisi de gecikir.
- **İlk adım kod değil envanter.** Yönetici yüzeyi bugün yedi sekme
  (`admin_dashboard` · `admin_users` · `admin_groups` · `admin_reports` ·
  `admin_moderation` · `admin_announcements` · `admin_audit_log`) + tek kart
  widget'ı taşıyor. Envanter her sekme için: ne yapıyor, hangi veriyi hangi
  yoldan okuyor, hata/boş/yükleniyor durumu var mı, dar ekranda ne oluyor,
  yıkıcı eylem onay istiyor mu.
- **Bilinen somut girdi (bu fazda ölçüldü):** `supabase_admin_repository.dart`
  **22**, `admin_repository.dart` **10**, `supabase_admin_moderation_repository.dart`
  **10**, `in_memory_admin_moderation_repository.dart` **12** gömülü Türkçe
  literal taşıyor — yönetici yüzeyi bu fazın l10n boşluğunun en yoğun bölgesi
  (WP-477 kapsamı yalnız dürtmeyi çevirdi, burası bilerek bırakıldı).
- **Kapsam:** Envanter + sahibin seçtiği düzeltme sırası. Kart **önce çıktı
  üretir, sonra kod yazar**; kozmetik kararlar için sahibe önizleme gider,
  seçilen değerler teste sabit değer olarak girer.
- **Sahip yollar:** `docs/qa/V57-ADMIN-INVENTORY.md` (yeni), ardından sahibin
  seçtiği `app/lib/features/admin/**` yolları.
- **Kabul (DoD):** Envanter yedi sekmeyi de kapsıyor · her satırda "sorun mu,
  tercih mi" ayrımı var · sahip sırayı seçti · seçilen ilk iş için ayrı kabul
  ölçütü yazıldı.

#### WP-487 — Grup üye satırı: ünvan satırı şişirmesin

- **Durum / bağımlılık:** [x] Kod + otomatik test tamam (`Cihazda doğrulanmalı`).
  WP-484 ve WP-483'ten sonra, ayrı commit.
- **Belirti (V57-N11):** Ünvan eklendikten sonra bir üye listede dört satır
  kaplayabiliyor (`ad1 / ad2 / ünvan1 / ünvan2`).
- **Kök neden (kodda doğrulandı):** Satırdaki **hiçbir metnin** satır sınırı yok.
  `title: Text(m.displayName)` sarmalayıcısız
  ([`class_detail_screen.dart:880-887`](app/lib/features/classroom/widgets/class_detail_screen.dart:880));
  alt metin ise `Column` içinde ikinci bir sarmalanabilir `Text`
  ([`class_detail_screen.dart:959-980`](app/lib/features/classroom/widgets/class_detail_screen.dart:959)).
  Uzun ad 2 satıra, uzun ünvan 2 satıra çıkar → 4 satır. Grup sahibinde
  `classroomYonetici` **ayrı bir üçüncü** `Text` olarak eklendiği için aynı üye
  **5 satıra** çıkabilir.
- **Ölçüm notu:** `ListTile` yüksekliği içeriğe göre büyüdüğü için liste
  satırları farklı yükseklikte olur; sahibin "güzel durmuyor" dediği şey bu
  düzensizliktir, yalnız uzunluk değil.
- **Yapılacak:** Ad tek satır + `TextOverflow.ellipsis`. Ünvan ve "Yönetici"
  **tek bir alt satırda** birleşsin (ünvan `Flexible` + ellipsis, yönetici
  işareti kısa ve sabit genişlikte). Satır yüksekliği ad/ünvan uzunluğundan
  **bağımsız** olsun. Ünvanı tamamen okumak isteyen zaten satıra dokununca
  profil kartını açıyor (`SocialProfileDialog.show`) — bilgi kaybı yok.
- **Kapsam dışı:** Ünvan seçimi (WP-478/479), avatar, taç göstergesi, dürtme ve
  yönetici eylem düğmeleri.
- **Sahip yollar:** `app/lib/features/classroom/widgets/class_detail_screen.dart`,
  `app/test/features/classroom/member_row_layout_test.dart` (yeni).
- **Kabul (DoD):** Çok uzun ad + çok uzun ünvan + yönetici işareti bir arada
  iken satır **iki satırı aşmıyor** · listedeki bütün satırlar aynı yükseklikte ·
  ad ve ünvan ellipsis ile kesiliyor, taşma (overflow) uyarısı yok · dar telefon
  genişliğinde ve büyük yazı tipi ölçeğinde de geçerli.
- **Sonuç (2026-08-01):** Ad `maxLines: 1` + ellipsis. `_memberSubtitle` artık
  `Column` değil tek `Row`: ünvan `Flexible` + ellipsis, "Yönetici" ise yazı
  tipi ölçeğiyle büyüyen `maxWidth` sınırı içinde tek satır. Üstelik iki dallı
  `isOwner ? … : …` çağrısı tek çağrıya indi (iki dal aynı şeyi yapıyordu).
- **Satır yüksekliği uyumu için `null` alt satır kaldırıldı.** `ListTile`
  yüksekliği `subtitle`ın **varlığına** göre seçiliyor; ünvansız üyeye `null`
  dönmek o satırı 56 dp, ünvanlıyı 72 dp yapıyordu. Artık gösterilecek bir şey
  yoksa boş bir alt satır dönüyor ve bütün satırlar aynı yükseklikte.
- **Mutasyon kanıtı (ölçümlü):** ad `maxLines`'ı kaldırılınca yükseklikler
  `[72.0, 72.0, 104.0]` oluyor ve iki test kırmızıya dönüyor; düzeltmeyle üçü
  de **72.0**. Sahibin "güzel durmuyor" dediği düzensizlik tam olarak bu 32 dp.
- **Ölçüm:** yeni `app/test/features/classroom/member_row_layout_test.dart`
  **3 test** (360 dp normal ölçek + 320 dp / 1.6× ölçek) · tam paket
  **1566/1566 yeşil** (öncesi 1563) · `flutter analyze` 0 uyarı · l10n OK.

#### WP-488 — Ana ekran üst şeridini kaldır; düzenlemeyi uzun basmaya taşı

- **Durum / bağımlılık:** [x] Kod + kapılar tamam · **`Replay bekliyor`** ·
  `Cihazda doğrulanmalı`. Migration `0118` (`0117` WP-485'e gitti).
- **🔴 Sahip kararı (bağlayıcı, V57-N12):** Üst şerit ve düzenle butonu
  **kalkacak**, ilk kart doğrudan üstten başlayacak. Yerine **yeni buton
  konmayacak**. Giriş yolu uzun basmadır; keşfedilebilirlik tanıtım turu + SSS
  ile sağlanır.
- **Kök neden (kodda doğrulandı):** Şerit `buildTabActionBar` ile kuruluyor
  ([`home_screen.dart:300-333`](app/lib/features/home/home_screen.dart:300)) ve
  görüntüleme modunda **tek** eylem taşıyor: düzenle simgesi
  ([`:325-331`](app/lib/features/home/home_screen.dart:325)). `buildTabActionBar`
  zaten "eylem yoksa `null` dön" sözleşmesine sahip
  ([`tab_action_bar.dart:14-22`](app/lib/core/navigation/tab_action_bar.dart:14)),
  yani tek eylemi kaldırmak şeridi **kendiliğinden** yok eder ve gövde üst güvenli
  alanı kendisi taşır. Sahibin gördüğü boşluk bu 48 px'lik şerit + durum çubuğu
  payıdır.
- **Uzun basma zaten var:** Kart uzun basınca düzenleme moduna giriliyor
  ([`home_screen.dart:780-781`](app/lib/features/home/home_screen.dart:780)
  `onLongPress` / `onSecondaryTap` → `_setEditing(true)`), yani sahibin "menü
  açılıyor zaten" tespiti doğru; yeni etkileşim yazılmayacak.
- **🔴 Kaldırmanın iki sessiz sonucu — ikisi de bu kartın kapsamındadır:**
  1. **Tanıtım turu balonunun çapası kayboluyor.** `AppTours.home(...)` adımı
     `editAnchor` ile o butona bağlı
     ([`home_screen.dart:113`](app/lib/features/home/home_screen.dart:113));
     buton gidince balon çapasız kalır. `TourStep.anchor` **nullable** ve
     `null` iken balon ekranın ortasında hedefsiz gösteriliyor
     ([`tour_models.dart:19-21`](app/lib/core/tour/tour_models.dart:19)) — sahibin
     "tanıtım turunda ana ekrana yazsak yeter" dediği şey tam olarak budur.
     Adım metni "kartlara uzun bas" davranışını **açıkça** söylemeli; eski metin
     butonu tarif ediyorsa yeniden yazılır. `AppTours.home` imzasından
     `editAnchor` düşer.
  2. **Boş pano hâli.** Hiç kart yokken `_EmptyDashboard(onEdit: …)` gövdenin
     içinde kendi eylemini taşıyor
     ([`home_screen.dart:136`](app/lib/features/home/home_screen.dart:136)),
     yani kullanıcı kartsız durumda **kilitlenmiyor**. Bu yol korunur; aksi
     hâlde ilk açılışta çıkış yolu kalmaz.
- **Düzenleme modu şeridi KALIR.** Kaldırılan yalnız **görüntüleme** modundaki
  şerittir. Düzenlemede Bitti / yukarı topla / sıfırla / kart ekle eylemleri
  yerinde durur; onlar uzun basmayla erişilemez.
- **Masaüstü ayrı yüzeydir.** `home_screen.dart:240-286` masaüstü/geniş ekran
  şeridi ayrı bir daldır ve orada uzun basma birincil etkileşim değildir; **bu
  kart masaüstü şeridine dokunmaz**. Sahibin isteği telefon ana ekranı içindir.
- **SSS satırı:** `faq_entries` sunucudan besleniyor ve `0091` içinde
  migration ile seed ediliyor
  ([`0091_faq.sql:64`](supabase/migrations/0091_faq.sql:64)); yeni soru da aynı
  yolla, **TR ve EN birlikte**, `on conflict` güvenli biçimde eklenir. Yalnız
  TR eklemek EN kullanıcıda eksik SSS bırakır.
- **Sahip yollar:** `app/lib/features/home/home_screen.dart`,
  `app/lib/features/tours/app_tours.dart`, `app/lib/l10n/app_en.arb`,
  `app/lib/l10n/app_tr.arb`,
  `supabase/migrations/0118_faq_home_edit.sql` (numara uygulama anında
  doğrulanır), `supabase/tests/001_schema_contract.test.sql`,
  `tooling/release/deploy-contract.json`, `tooling/supabase/guard.tests.ps1`,
  ilgili widget/tur testleri.
- **Kabul (DoD):** Telefon ana ekranında görüntüleme modunda **hiç app bar
  kurulmuyor** (`buildTabActionBar` `null` döndüğü testle sabitlenir — "boşluk
  küçüldü" demek yetmez) · ilk kart üst güvenli alanın hemen altından başlıyor ·
  düzenleme modunda dört eylem hâlâ erişilebilir · uzun basma düzenlemeye
  giriyor · tanıtım turu adımı çapasız gösteriliyor ve metni uzun basmayı
  söylüyor · boş pano hâlinde çıkış yolu duruyor · masaüstü şeridi değişmedi ·
  SSS satırı TR + EN eklendi, head üç yerde hizalı, `Replay bekliyor` etiketi.
- **Sonuç (2026-08-01):** Telefon `buildTabActionBar` çağrısının görüntüleme
  modundaki **tek** eylemi kaldırıldı; sözleşme gereği `null` dönüyor ve şerit
  hiç kurulmuyor. Yerine yeni buton **konmadı**. Test bunu "boşluk küçüldü"
  diye değil, `find.byType(AppBar) == findsNothing` ile ölçüyor; ilk kartın
  üstü ölçülüyor ve eski 48 dp şeridin altında olmadığı doğrulanıyor.
- **Tanıtım turu:** `AppTours.home` imzasından `editAnchor` düştü, adım artık
  **çapasız** (balon ekranın ortasında hedefsiz çiziliyor). Metin davranışı
  değiştiği için tur sürümü `v1 → v2`: kullanıcı yeni yolu bir kez daha görür.
- **🔴 Metin uzunluğu bir kapıya takıldı ve kısaltıldı.** İlk yazım
  ("Düzenleme moduna girmek için herhangi bir karta uzun bas; sonra kart
  ekleyebilir…") `app_tours_test` balon taşma iddiasını düşürdü: testte gerçek
  font yüklenmediği için her glif `fontSize` genişliğinde sayılıyor ve 288 px'e
  iki satır ≈ 40 karakter sığıyor. Son metin: TR "Karta uzun bas: düzenleme
  açılır." · EN "Press and hold a card to edit."
- **Kapsam dışı bırakılanlar korundu:** Düzenleme modu şeridi (Bitti / yukarı
  topla / sıfırla / kart ekle) **yerinde**; masaüstü dalına dokunulmadı; boş
  pano kendi eylemini taşımaya devam ediyor. Öksüz kalan `_editTourAnchor`
  `GlobalKey`i (kendi enkazım) silindi.
- **Migration `0118_faq_home_edit.sql`:** SSS satırı **TR + EN birlikte**.
  `0091` tabloyu benzersiz kısıtsız kurduğu için `on conflict do nothing` bu
  satırları korumaz; idempotenslik `where not exists` ile sağlandı ve pgTAP
  testi tekrar apply'ın kopya üretmediğini de ölçüyor.
- **Head üç yerde `0118`:** `deploy-contract.json` `local_migration_head` ·
  `001_schema_contract.test.sql` (118 / `0118`) · `guard.tests.ps1` notu.
  Staging/production **`0116`da** bırakıldı; dört bayrak `false`.
- **Etkilenen mevcut test düzeltildi:** `edit_mode_sticky_panel_test` düzenleme
  moduna düzenle butonuna dokunarak giriyordu; uzun basmaya çevrildi.
- **Ölçüm:** yeni `app/test/features/home/home_action_bar_wp488_test.dart`
  **7 test** + `supabase/tests/044_faq_home_edit.test.sql` **4 pgTAP iddiası**
  (kart `039` demişti; 039–043 dolu olduğu için 044) · tam paket
  **1597/1597 yeşil** (öncesi 1590) · `flutter analyze` 0 uyarı · l10n OK ·
  `guard.tests.ps1` 75/75 · `release-preflight.tests.ps1` 8/8.
- **🔴 `Replay bekliyor`:** Docker bu hostta kalkmıyor; `0118`in pgTAP kanıtı
  Database Gates workflow'unun local replay job'ından alınır.

### Faz F4 sırası

**Şimdi verilebilir (bağımsız, çakışmayan):** WP-477 · WP-478 · WP-480 · WP-481 ·
WP-485 · WP-487 · WP-488.

**Beklemeli:** WP-479 (WP-478'den sonra — aynı dosya) · WP-483 ve WP-484
(WP-477'den sonra; üçü de `class_detail_screen.dart`'a dokunduğu için
WP-487 · WP-483 · WP-484 **art arda**, asla aynı anda) · WP-486 (WP-485'ten
sonra) · WP-482 (sahibin iki cihazı hazır olunca).

🔴 **Sıcak dosya:** `class_detail_screen.dart` bu fazda **üç** kart tarafından
sahiplenilir (WP-483 · WP-484 · WP-487). Tek ajan modelinde lane kilidi yok, ama
bu üç kart aynı commit'e karışırsa hangi düzeltmenin neyi bozduğu okunamaz —
her biri ayrı commit, sırayla.

**Migration:** yalnız iki kart üretir — WP-485 (`0117`, realtime + push) ve
WP-488 (SSS satırı; numara uygulama anında en yüksek olan). İkisi de head'i
**üç yerde birden** ilerletir ve `Replay bekliyor` etiketiyle teslim edilir.
Hiçbir F4 kartı production/stable kapısı açmaz.

## Bekleyen Uygulanabilir WP'ler

### WP-276 — Hesap silme staging ops ve kabul kanıtı
- **Durum:** [ ] Bekliyor · **Bağımlılık:** Kurtarma release güveni; production için ayrıca somut GO.
- **Amaç:** Sentetik staging hesapta request/cancel/purge, 14 günlük grace simülasyonu, yetkisiz çağrı, retry/terminal hata ve rollback runbook'unu kanıtlamak.
- **Sınır:** Gerçek kullanıcı hesabı, production purge, yeni feature/migration kapsam dışıdır.
- **Sahip yollar:** `docs/qa/ACCOUNT-DELETION-STAGING.md`, `docs/play-store/PLAY-RELEASE-GATE.md`, redacted staging kanıtı ve yalnız gerekli testler.

### WP-277 — Başarım, görev ve grup ilerlemesi kabul matrisi
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-271 cihaz/release güveni; WP-276 ile paralel backend ops yok.
- **Amaç:** Beş süre kaynağında istatistik/XP/başarım/grup sonucunu, pending reward/claim'i, iki cihazı ve İstanbul gün sınırını sentetik staging kanıtıyla sınıflandırmak.
- **Sınır:** Yeni ekonomi kuralı, migration/backfill ve production claim kapsam dışıdır; bulunmuş hata ayrı WP olur.

## Kapanan / Tekilleştirilen Kayıtlar

| Kayıt | Canlı durum |
|---|---|
| WP-269–275, 280–285 | **Kapandı (2026-07-24).** Kod/test kanıtı + proje sahibinin v45 stable ve beta-v4308 üzerindeki cihaz testi; bekleyen cihaz kabulü kalmadı |
| WP-271 | Staging gerçek push/retry ve timer action davranışı sahip testinde sorunsuz; ölçümlü matris kaydı istenirse yeni WP açılır |
| WP-225, 226, 258 | Tarihsel tamamlanmış işler; ayrıntı arşiv+git'te |
| WP-266/267/268 | Eski ayrıntılar arşivde; açık push/timer kabulü WP-271 ve QA matrisinde |
| WP-278 | **Kapandı:** ürün yalnız TR + EN; DE/AR `.arb` dosyaları geri dönüş için repoda kalır |
| WP-279 | **Kapandı:** aylık e-posta raporu iptal; canlı sağlayıcı/domain kurulmayacak |
| WP-286–294, 296–298, 302–314 | **Kapandı.** Kod/test ve sahip cihaz kabulü tamam; ayrıntılar tarihsel arşiv+git'te |

## Worker'a Verilecek Kısa Komutlar

Yalnız **Bekleyen Uygulanabilir WP'ler** ve Yol Haritası'nda `[ ] Bekliyor` olan
kartlar worker'a verilir. 🔴 **Güncel ürün sırası artık Faz F4'tür**
(v57 sahip geri bildirimi, WP-477…WP-488); sıra ve çakışma kuralları o fazın
**Faz F4 sırası** başlığındadır. Aşağıdaki F3 dalgaları tarihsel kayıttır
(v49 sonrası sekiz
sahip bulgusunun tamamı).

**Dalga 1 — şimdi, dört worker'a aynı anda verilebilir:**

1. ✅ **WP-353** — KAPANDI (production auth yamalandı; cihaz doğrulaması sahipte).
2. **WP-354** — Sayaç sürerken grupta "aktif" kalmama: kök neden ayrımı, salt-okunur. **Sahibin iki cihazını gerektirir.**
3. ✅ **WP-356** — Kod/test tamam (`72ccb20`), v50'de çıktı.
4. ✅ **WP-358** — Kod/test tamam (`636e645`), v50'de çıktı.

**Dalga 2 — dalga 1 kapandıkça, aynı anda en fazla iki hat:**

5. **WP-357** — V3 rollout anahtarı + flag'li iki cihaz kabulü. *(presence yüzeyi: WP-355 ile aynı anda değil)*
6. **WP-359** — Başarımlar IA; primary grup bloğunu sağ üste taşı. *(WP-358'e bağlı)*
7. **WP-360** — Kamp ateşi 2. revizyon. *(WP-356'dan sonra; önce sahibe önizleme)*
8. **WP-361** — Tablet/geniş ekran envanteri. *(kod yazmaz; her an açılabilir, çıktısı sahip kararı)*
9. **WP-362** — Tanıtım turu hedefleme/konum/sıra onarımı.
10. **WP-355** — Presence sürekliliği kalıcı düzeltmesi. *(yalnız WP-354 kanıtından sonra, kapsamı daraltılarak)*

WP-348…WP-351 zinciri kapandı; yeniden verilmez. WP-346 fiziksel V3 kabulü
olarak parkta kalır — WP-357 onu **besler**, yerine geçmez. Faz F3'ün hiçbir
kartı production/stable'da V3 flag'i açmaz.

`Test için bekleyenler` tablosundaki hiçbir kayıt yeniden worker'a verilmez.

> Her worker önce Aktif Çalışma Kaydı'nı okur, kendi lane'ini claim eder ve SAHİP yolları çakışıyorsa başlamaz. Production/stable hiçbir WP'nin örtük parçası değildir.
