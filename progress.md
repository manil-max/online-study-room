# progress.md — Canlı Durum

> Son güncelleme: **2026-07-26** · Saat dilimi: **Europe/Istanbul**
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

- **Migration gerçeği (2026-07-28, v55 sonrası):** repo/local **`0094`** ·
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
- **Stable/production:** **v53** yayında (WP-370/371: timer-sync teslim zinciri
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
- **Beta/staging:** **`beta-v4402`** son beta; Android APK + Windows MSIX/ZIP mevcut, release run `30212796092` bütünüyle PASS. Staging veritabanı `0085`te. Fiziksel cihaz bağlı olmadığı için beta cihaz kabulü yapılmadı; **V3 rollout flag'leri kapalıdır** — v49'da bildirilen çoklu cihaz senkron bulgusu (V49-1) önce bu flag durumuna karşı ayrılmalı.
- **Release ilkesi:** Android beta/stable artefaktı Android işi başarılı olunca yayımlanır. Windows bağımsız sürer ve başarılı olursa aynı release'e eklenir; Windows hatası Android güncellemesini geri çekmez.
- **Sürüm sırası:** kod/testi biten işler tek QA kuyruğunda birikir; yeni beta/stable yalnız sahip onayıyla çıkar. Eski beta dalga kararları git geçmişindedir.
- **Yönetim varsayılanı:** Production `deploy_enabled/release_enabled` kapalıdır ve her terfiden sonra yeniden kapatılır. Stable yalnız protected `production` Environment, exact SHA/head/project-ref GO ve reviewer kanıtıyla ilerler.
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md` ve `docs/KALITE-PROGRAMI.md` geçerlidir. Tek çalışma dalı `main`; her WP ayrı commit; production varsayılmaz.
- **Aktif tur:** **Faz F4 kapandı, v51 çıktı ve sahip cihazda denedi.**
  🟢 Görünürlük düzeldi: bir cihazda başlatılan çalışma artık diğer cihazda ve
  başka kullanıcılarda görünüyor (WP-363 + WP-365 **cihazda kabul edildi**).
  🔴 Dört yeni bulgu: `backlog.md` **V51-1…V51-4** (≈80 sn sonra aktiflikten
  düşme · sayaç değerlerinin eşitlenmemesi · admin yazışmasında ters sıra ·
  yazışmada karşı tarafın mesajlarının görünmemesi). **Dördünün de kök nedeni
  koddan bulundu** (bkz. `backlog.md`). Sahip emriyle **Faz F5** açıldı:
  V51-1 + V51-2 düzeltilip v52 stable çıkacak; V51-3/V51-4 (admin yazışması)
  sahip kararıyla beklemede. Öncesi: Öncesi: v49 sonrası saha düzeltmeleri (Faz F3). WP-348 → WP-351 zinciri kapandı (stable v49 çıktı). Sahip iki turda toplam **sekiz** bulgu bildirdi (`backlog.md` V49-1…V49-8) ve **hepsi karta bağlandı: WP-353…WP-362.** Backlog'da plansız kalan v49 bulgusu yok.
- **Son WP numarası:** **WP-378** (2026-07-28). WP-373 çoklu cihaz sayaç
  senkronunu kurdu, WP-374…WP-378 birikmiş düzeltme turuydu, **v54 çıktı**.
  🔴 **Yeni kartlar WP-379'dan devam eder — bkz. `PLAN 3 — LANSMAN TURU`.**
- **Önceki not (WP-372, 2026-07-27).** V52'de komutun A→server yolu kapanmıştı; server→B timer-sync teslim zinciri WP-370 (`0088`) ile kuruldu, WP-371 turu yaşam döngüsüne bağladı, WP-372 v53 stable'ı çıkardı.
- ✅ **Ortam gerçeği uzlaştırıldı (WP-351, 2026-07-27):** üç ortam da `0085`; production CLI geçmişi artık gerçek. Deploy kapısı yeniden kilitli.

## ⚡ Aktif Çalışma Kaydı

### Gemini Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Claude Lane
- **Durum:** [x] Boşta
- **Faz/WP:** — · PLAN 3 Faz K + Faz L kapandı, **v55 yayında**
- **SAHİP yollar:** —
- **Son not (2026-07-28, v55 teslim turu):** Beş paralel zincir on dört WP'yi
  (WP-379…WP-392) tek turda indirdi. Çakışma **olmadı** — `*.arb`,
  `settings_screen.dart`, `stats_period_bar.dart`, `campfire_scene.dart` ve
  migration numaraları sırayla ilerledi. 🔴 Ama paket **kırmızı teslim edildi**:
  1000 test geçerken 13 düşüyordu. Dört kök neden ve hepsi kapatıldı:
  (1) DE/AR katalog eşliği — WP-387/388/390/392 TR+EN yazıp DE/AR'ı atlamıştı,
  on beş anahtarın Almanca/Arapça çevirisi yazıldı;
  (2) WP-379'un **kendi** testleri — Riverpod 3 auto-dispose tuzağı, dinleyicisiz
  `authStateProvider` yükleme durumundayken dispose oluyordu (repoda yerleşik
  kalıp zaten vardı, ajan kullanmamıştı);
  (3) WP-374 koşumu — sekme üretimde `Scaffold` body'sinde ama koşum doğrudan
  `home:`e koyuyordu; WP-387'nin eklediği `FilterChip` Material bulamayınca
  bütün liste patlıyordu (üretim sağlamdı);
  (4) 🔴 **gerçek ürün kusuru** — kamp ateşinde dikey kelepçe gövdenin çıpasını
  sınırlıyor, alt sınırda `box * (1 - anchor)` düşülmüyordu (yatayda `box / 2`
  iki uçtan da düşülmüş). WP-382 ateşi 45 px aşağı alınca telefonda 4+ kişide en
  öndeki hayvanın ayakları `ClipRRect` ile kesiliyordu. Sahibin seçtiği
  kompozisyon değerleri değişmedi.
  Ayrıca turun başında `flutter analyze` 7 uyarı veriyordu ve migration head
  pini üst üste **dördüncü** kez unutulmuştu; yerel head artık sabit sayı değil,
  `deploy-contract.json`'dan türetiliyor — tuzak kalıcı olarak kapandı.
  **Teslim:** yerel replay 0001→0094 + 328 pgTAP PASS · analyze temiz ·
  1013/1013 test yeşil · staging apply `30363917376` · production apply
  `30364331158` (ikisinde de post-check `0094`) · v55 stable.
- **Önceki not (2026-07-28, PLAN 3 planlaması):** Sahip v54'ü iki cihazda test etti; sekiz başlıkta geri
  bildirim verdi ve üstüne mağaza turunu konuştuk. Tartışma
  `docs/LANSMAN-TARTISMA-NOTU.md`'de karara bağlandı, rakip yorum analizi
  `docs/RAKIPANALIZI-DEGERLENDIRME.md`'de koda karşı doğrulandı. İkisi birden
  **PLAN 3 — LANSMAN TURU** olarak WP'lere bölündü (WP-379…WP-411).
- **Teşhis (2026-07-27, sahip production sorgusuyla mühürlendi):** V2 sayaç
  senkronu **hiç çalışmadı** — WP-341'den beri tek bir komut bile sunucuya
  ulaşmadı. `select ... from global_timer_commands` → 0 satır;
  `notification_outbox where notification_type='timer_sync'` → 0 satır.
  🔴 **Kök neden 1 — `origin` sözlüğü uyuşmuyor.** Sunucu
  `('app','widget','notification','recovery')` bekliyor (`0082:277-280`), istemci
  `dart_app` / `native_widget` / `native_notification` gönderiyor
  (`StudyTimerService.kt:136`, `study_providers.dart:755`). Aradaki çeviri
  repoda **yok**; `global_timer_providers.dart:72` ham değeri payload'a koyuyor.
  Her `start` RPC'si `invalid_global_timer_origin` fırlatıyor, exception
  `global_timer_providers.dart:75` içinde yutuluyor. Transaction geri sardığı
  için audit satırı bile yazılmıyor — bu yüzden yıllardır görünmez kaldı.
  🔴 **Kök neden 2 — stop hiç yayınlanmıyor.** Uygulama içi Durdur
  `ACTION_STOP_SILENT` → `handleStop(recordInterval=false)` → V2 zarfı hiç
  üretilmiyor (`StudyTimerService.kt:232`). Bildirim/widget Durdur zarf üretiyor
  ama `expected_run_revision` **hep null** (`StudyTimerService.kt:257-262`) →
  sunucu `stop_run_revision_required` atıyor, zarf kuyrukta kalıcı zehir oluyor.
  🔴 **Neden testler yeşildi:** pgTAP kendi uydurduğu `'app'` değerini kullanıyor
  (`013:55`, `017:37`), Dart testleri `flushShadow()`'u komple stub'lıyor
  (`global_timer_command_publish_test.dart:41`), InMemory repo payload'ı hiç
  doğrulamıyor. Sözleşmeyi iki uçtan tutan **tek bir test yoktu**.
  ➡️ WP-370/WP-371 (FCM teslimat + yaşam döngüsü) doğru yazılmış ama
  **tetikleyeni olmayan** zincirdi; v52/v53 bu duvarın arkasında kaldı.
- **Önceki not (2026-07-27, WP-371 + teslim):** Sahip emriyle Codex'in `0838f8e` teslim
  zinciri incelendi. SQL tarafı sağlam: helper `authenticated`'a kapalı,
  `auth.uid()` doğruluyor, origin cihaz teslimden çıkarılıyor, yalnız `applied`
  start/stop sinyal üretiyor, planlayıcı origin cihazı `deferred` bırakıyor.
  🔴 Tek kusur: 5 sn'lik tur "foreground" diye yazılmış ama yaşam döngüsüne
  bağlı değildi — sayaç çalışırken native servis süreci canlı tuttuğu için ekran
  kapalıyken de dönerdi. WP-371 turu `onHide`/`onPause`'da durdurup `onResume`'da
  yeniden başlatır; regresyon testi düzeltme geri alınınca kırmızıya döndü.
  🔴 İkinci bulgu: `local_migration_head` `0088`'e taşınmış ama `guard.tests.ps1`
  ve `release-preflight.tests.ps1` `0087`'ye sabitli kalmıştı — CI bu haliyle
  kırmızı düşerdi (geçen turda tam olarak buradan düşmüştü). İkisi de taşındı.
  **Teslim:** staging apply `30296764464` → production apply `30297435093`
  (ikisinde de post-check `0088`) → v53 stable `30297781192` (dört iş de yeşil,
  Android + Windows artefaktları yayında) → production kapısı yeniden HOLD.
  **Cihaz kabulü sahipte: eşitleme için iki cihazda da v53 şart.**
- **Önceki not (2026-07-27, Faz F5):** Sahip emriyle V51-1 + V51-2 düzeltildi ve
  v52 stable çıktı. Admin yazışması (V51-3/V51-4) sahip kararıyla dışarıda kaldı.
  - **WP-367** ~80 sn düşme: heartbeat lease'i yalnız kanonik satırda
    yeniliyordu, okuyucular projeksiyon satırının lease'ine bakıyordu. `0086`
    ikisini aynı işlemde eşitliyor. **Sunucu taraflı → v51 istemcisinde de geçerli.**
  - **WP-368** sayaç eşitlemesi: komut yalnız resume'da yayınlanıyordu; artık
    başlat/durdur anında yayınlanıyor ve bind→native→yayın zinciri sıralı.
    🔴 Planda olmayan ikinci engel: `v2_enabled` hiçbir ortamda açılmamıştı,
    sunucu her komutu reddediyordu — `0087` ile açıldı. İstemci düzeltmesi tek
    başına hiçbir şey değiştirmezdi.
  - **Cihaz kabulü sahipte.** Aktiflikten düşme v51'de de test edilebilir;
    sayaç eşitlemesi v52 ister.
- **Önceki not (2026-07-27, Faz F3 dalga 1):** Sahibin seçtiği üç kart yapıldı ve
  **v50 stable** çıkarıldı.
  - **WP-353** production auth: dry-run teşhisi doğruladı (`site_url =
    localhost:3000`, allowlist **boş**), apply PASS. Düzeltme sunucu tarafında,
    **v49 istemcisinde de geçerli** — güncelleme beklemeden çalışır. Masaüstü
    6 haneli kod yolu free-tier şablon kilidi yüzünden açık borç kaldı.
  - **WP-356** kamp ateşi: ilk teşhis eksikti (`ground.png` tek suçlu sanıldı);
    asıl kaynak `ClearingPainter` çıktı, ikisi de kaldırıldı, ölü sınıf silindi.
  - **WP-358** uyarı token'ı: renk artık zeminden türetiliyor; 15 preset ×
    kontrast testiyle kilitli. Sekme noktası da aynı hastalıktaydı, o da düzeldi.
  - **Açık:** WP-354 presence ölçümü sahibin iki cihazını gerektiriyor; WP-357
    (çoklu cihaz senkronu) ajan tarafından tek başına kanıtlanamaz — anahtar
    mekanizması yazılabilir ama iki fiziksel cihaz kanıtı sahipte. Sahip
    isterse V3 flag'leri **açık bir beta** çıkarılır (beta ayrı applicationId,
    stable'ı riske atmaz).
- **Son not (2026-07-27 02:20):** WP-351 production 0085 apply + v49 stable release tamamlandı, lane bırakıldı. Kalan iş sahipte: cihaz kabulü.
  - **Kök neden:** production'ın Supabase CLI migration geçmişi boştu (tarihsel migration'lar SQL Editor'den uygulanmış), bu yüzden `db push` 0001'den başlayıp 0010'da düşürülen `study_sessions.group_id` üzerinde patlıyordu. Şema sağlamdı, yalnız geçmiş tablosu boştu.
  - **Çözüm:** dar `repair-baseline-0070` yolu — 0001-0070'i yalnız `applied` işaretler, şemaya DDL göndermez. `migration repair` repo genelinde yasak kalır; sadece bu yol `AllowBaselineRepair` + production + CI + allowlist'li sürüm kapılarından geçer.
  - **Yedek:** sahip kararı ile muaf (`production.backup_requirement: "waived"`). Free plan projesinde PITR/backup yok, geri dönüş yolu olmadan uygulandı. Bir daha backup sorulmayacak. Repo PUBLIC olduğu için CI'da `db dump` alıp artifact'a koymak asla seçenek değil.
  - **Kanıt:** baseline repair [30222267119](https://github.com/manil-max/online-study-room/actions/runs/30222267119) · apply + post-check head 0085 [30222414307](https://github.com/manil-max/online-study-room/actions/runs/30222414307) · release [30222542841](https://github.com/manil-max/online-study-room/actions/runs/30222542841) (android+windows+finalize hepsi yeşil).
  - **Sürüm:** `v49` → `2e19cfb` (WP-352 fix dahil). APK SHA-256 `0628cff960430fb9850eb90f276ce9c6a274d68b96159ef64b15a384de65c935`.
  - **Açık risk:** production şeması `0085`e çıktı ama 5 kişilik ekipteki herkes v49'a güncellemedi. Sahip kendi cihazında v49'u denedi ve çökme bildirmedi; **v48 istemcisinin `0085` şemasıyla davranışı hâlâ doğrulanmadı**. Ekipten biri eski sürümde kalıyorsa önce onu güncelle.
- **v49 cihaz geri bildirimi alındı (2026-07-27):** sahip beş bulgu bildirdi (çoklu cihaz sayaç senkronu, Achievement Journey primary-group bloğu, kamp ateşi 2. revizyon, tablet yatay düzeni, tanıtım turları). Ham not `backlog.md` 🔴 Yüksek Öncelik başındadır; WP'ye bölünmesi sahiple birlikte yapılacak.
- **Doküman temizliği (2026-07-27, sahip emri):** `docs/archive/` dizini, üç senior review turu, v46 sahip geri bildirimi ve kapanmış iki recovery kabul notu repodan kaldırıldı (13 dosya, ~11k satır). Evrensel saat işinde **yalnız nihai plan + C0 uyumluluk kanıtı** kaldı. Hepsi git geçmişinde; kalan md'lerde kırık iç bağlantı yok.

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not (2026-07-28):** WP-392 kod/test tamam (`local` head `0094`): güncellenebilir TR/EN terim verisi profil ve grup adını sunucuda denetliyor; istemci anlaşılır hata gösteriyor. 24 Flutter grup repo testi, 328 pgTAP ve hedefli analiz yeşil. Cihaz kabulü bekliyor.

### Codex-2 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not (2026-07-28):** WP-380 kod/test tamam; `:app:testLocalDebugUnitTest` yeşil. Android widget/bildirim cihaz kabulü bekliyor.

### Codex-3 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-344 `0083` local replay, 244 pgTAP ve uygulama kalite kapılarıyla kod/test tamamlandı; timer-sync rollout flag kapalıdır. Staging/cihaz kabulü V3 zincirinin ortak QA turunda yapılacak.

### Codex-4 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-384 `fc9af60` ile tamamlandı: iki uç sürüklenir, canlı önizlenir ve kesişince takas edilir; 7 hedefli Flutter testi ve analiz yeşil.

### Codex-6 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-385 `ce7212f` ile tamamlandı: görünür katalog artık ledger’daki ilk gerçek kademe eşiğini TR/EN tam koşul cümlesiyle gösterir; 12 başarımın eşik–metin sözleşmesi testte kilitli.

### Codex-5 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not (2026-07-28):** WP-382 `49ca29f`, WP-387 `c97924f`, WP-390 `2757450`
  ile kapandı. 🔴 Lane aktif bırakılmıştı (worker sözleşmesi ihlali); v55
  turunda kapatıldı.

### Grok Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

## 🗺️ Yol Haritası — sırada ne var

> **İki plan, sırayla: PLAN 1 (Ürün & Kod, Faz A–F) → PLAN 2 (Mağaza, Faz G–J).**
> Tek istisna: **isim + logo kararı** Plan 2'ye ait ama Plan 1 bitmeden verilmeli —
> mağaza görselleri, MSIX kimliği ve uygulama içi marka ona bağlı.

### Şu anki gerçek durum

| Konu | Durum |
| --- | --- |
| Sürüm | **`v55` yayında** — PLAN 3 lansman turu (Faz K + Faz L, WP-379…WP-392, on dört iş paketi tek sürümde). Sahip 2026-07-28'de tümünü tek mesajla onayladı. Production şeması `0089`→`0094`. Sürüm penceresi tag alındıktan sonra yeniden **HOLD**'a alınır |
| Cihaz kabulü | 🟡 **v55 sahipte** — on dört maddelik test listesi verildi (sayaç 2, arayüz 6, destek 2, moderasyon 4). Dört madde ikinci hesap/cihaz ister. v54'ten devreden tek açık test: kamp ateşi gece/gündüz saatleri (A2) |
| Sürüm politikası | 🔴 Sahip onayı olmadan yeni sürüm çıkmaz |
| Otomatik doğrulama | `2e19cfb` release koşumu (`30222542841`) preflight/android/windows/finalize tümü PASS |
| l10n audit | **0 bulgu**: WP-335, WP-295 önizleme metinlerini katalogladı; 7 kullanıcı-dışı invariant mesajı dar ve gerekçeli muafiyetle ayrıldı |
| Migration | Repo/local **`0094`** · staging **`0094`** · production **`0094`** — üç ortam hizalı. Staging apply run `30363917376`, production apply run `30364331158`, ikisinde de post-check `0094` |
| Yedek | 🔴 **Yok.** Free plan; PITR ve günlük yedek kapalı. Sahip kararıyla muaf; geri dönüş yolu yok |
| Beta | **`beta-v4402`** son beta; Android APK + Windows MSIX/ZIP hazır, V3 flag'leri kapalı |
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
- **Durum:** [x] **KAPANDI 2026-07-27.** Baseline `0070`e onarıldı, `0071→0085` uygulandı, post-check head `0085` verdi, `v49` stable yayınlandı. Yedek sahip kararıyla muaf. Kanıt ve kök neden analizi Aktif Çalışma Kaydı → Claude Lane son notundadır. Kalan iş sahipte: cihaz kabulü (bulgular `backlog.md` V49-1…V49-5).
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
| **WP-380** Widget ve bildirimde boş sayaç biçimi | Android widget + bildirim | Boştayken `00:00`; başlatınca ilk saniyede sıçrama yok; bir saati geçince `1:00:00`; uygulama içi sayaç `00:00:00` kalır. Commit: `bekleyen`. **Cihazda doğrulanmalı.** |

**Ortam sırası:** tamamlandı — local, staging ve production `0085`te (WP-348 →
WP-351, 2026-07-27). Yukarıdaki kartların hepsinde şema borcu kapandı; kalan
tek borç **gerçek cihaz kabulü**. V3 rollout flag'leri hâlâ kapalıdır.

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
kartlar worker'a verilir. Güncel ürün sırası **Faz F3**'tür (v49 sonrası sekiz
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
