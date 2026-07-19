# Başarım Canlı İlerleme + Topla-Ödül + Ölü Başarı Fix + Günlük Görev + Grup PP — PLAN (v3.1)

> Kaynak: kullanıcı isteği 2026-07-19 (Minik Kuş). İlk plan: Claude. v2: Codex tur-1 bulguları sonrası Claude revizyonu. v3: Codex tur-2 şema/rollout denetimi. **v3.1: Claude tur-2 saha-riskleri sonrası verified-session client/native entegrasyonu ayrı WP'ye bölündü ve ölçümlü aktivasyon kapısı eklendi.**
> Kanon: `.agents/AGENTS.md` + `docs/KALITE-PROGRAMI.md`; format: `.agents/skills/planner/SKILL.md`.
> **Bu dosya yalnız plandır; kod içermez.** Worker migration numarasını claim anında `progress.md` ve `supabase/migrations/` üzerinden yeniden doğrular (şu an en yüksek `0046`).
> Kanıt etiketleri: `Kodda doğrulandı` · `Cihazda doğrulanmalı` · `Ürün kararı gerekiyor`.

> **v3.2 ürün kararı (2026-07-20):** Verified-only XP ve başarı kuralı iptal edildi. Manuel süre ekleme, uygulama içi sayaç ve native/widget sayacı aynı kazanım yolundadır. `0063_equal_study_sources.sql`, bu belgenin verified-only/7-gün/canary kısımlarını ileriye dönük olarak geçersiz kılar; eski metin karar geçmişidir.

## 1. Yönetici özeti ve GO durumu

V3.1, v3'ün doğru ana kararlarını korur: ayrı `achievement_rewards`, append-only `xp_ledger`, gerçek claim, saat başı 50 XP'nin ambient kalması, sunucu metriği, Europe/Istanbul gün sınırı, sweep-line/two-pointer, görevlerin buluta taşınması ve migration/ARB serileştirmesi. WP-216 yalnız server/data expansion'dır; kırılgan timer/native köprüsü ve saha ölçümü yeni WP-220'de ayrı kalite kapısından geçer.

V2'deki üç bloklayıcı hata v3'te yapısal olarak giderildi:

1. **`study_sessions.group_id` yoktur.** 0010 bu kolonu ve tarihsel grup bağlamını bilinçli olarak kaldırmıştır. Grup başarımı bundan sonra doğrulanmış canlı oturumun immutable grup bağlamından hesaplanır; eski kayıtlar yalnız konservatif legacy-proxy kurallarıyla değerlendirilir.
2. **`source='live'` kanıt değildir.** Eski client uyumluluğu için bu etiket bir süre yazılabilir; ancak yalnız sunucunun oluşturduğu `live_run_id` + çalışma segmentleri başarı için güvenilir kaynaktır. İstemci verified bağ üretmez.
3. **Server-first davranış kırılması yoktur.** Reward tablosu ve claim-capable uygulama önce expansion olarak iner; otomatik ödülden pending'e geçiş en son, hesap-bazlı capability kapısıyla aktive edilir.

**Plan GO:** Toplam 13 WP (WP-208–220) uygulanabilir ve sıra/rollback sınırları nettir. **Production GO değildir:** her WP'nin staging, otomatik test, gerçek cihaz QA ve ürün kabul kapısı ayrıca geçilir. WP-219, WP-220'nin gerçek saha eşiklerini en az 7 ardışık gün sağlamadan aktive edilemez.

---

## 2. Kodda doğrulanan mevcut gerçekler

- `xp_ledger` append-only'dir; `event_key` UNIQUE ve `trg_xp_ledger_apply` yalnız `AFTER INSERT` çalışarak XP'yi bankalar (`0024:55–65`, `0024:186–213`).
- `_award_achievement_tier` ledger'a doğrudan insert eder; mevcut `process_achievement_event` eşik geçince bunu çağırır (`0024:322–350`, `:619–625`).
- `user_achievements.progress` gerçek metrik değil tier numarasıdır; showcase bunu progress gibi gösterir (`0024:191–200`, `achievement_showcase.dart`).
- `alpha_wolf`, `campfire_hours`, `locomotive`, `secret_break_enemy` server değerlendirmesinde sabit 0'a bağlıdır (`0025/0027/0033`).
- `study_sessions.group_id`, `0010_drop_session_group_id.sql:31` ile kaldırılmış; 0010:29–30 tarihsel orijinal grup bilgisinin kaybolduğunu açıkça kabul etmiştir. Modelde de `groupId` yoktur.
- Mevcut grup istatistiği `study_sessions ⨝ group_members` ve üyelik penceresiyle türetilir (`0011:34–39`). Yeniden katılım `joined_at=now()` ile eski pencereyi ezer (`0012:117–121`). Dolayısıyla geçmiş grup bağlamı eksiksiz yeniden kurulamaz.
- Session insert/update doğrudan kullanıcı satırına açıktır; model `source` değerini istemciden yollar. `0012`, `end_time >= start_time` ve duration üst sınırının bir kısmını `NOT VALID` constraint ile zaten eklemiştir; v3 bunu tekrar etmez, güçlendirir.
- Timer her çalışma fazını ayrı `study_sessions` aralığı olarak kaydeder; presence içinde seçili `group_id` hâlâ vardır. Bu, ileriye dönük server-issued grup bağlamı için kullanılabilir.
- Native `TimerStateStore` başlangıç/bitiş/konu ve pending interval saklar; server-issued run tokenı saklamaz. Uygulama/Flutter kapalıyken widget veya bildirimden native başlayan sayaç mevcut mimaride authenticated start RPC çağırıp `live_run_id` alamaz; Dart daha sonra yalnız pending interval'i normal session'a uzlaştırır. Bu yüzden bu başlangıçlar ek bir güvenli native-auth tasarımı olmadan verified sayılamaz (`TimerStateStore.kt`, `StudyTimerService.kt`, `TimerActionReceiver.kt`, `study_providers.dart:_reconcileBackgroundTimer`).
- Android FGS'nin eski API≤13 çökme yolu mevcut kodda düzeltilmiştir: manifest/service API 29–33 için `dataSync`, API 34+ için `specialUse` kullanır ve start hataları yakalanır. WP-220 bu düzeltmeyi yeniden tasarlamaz; yeni run/outbox köprüsünün aynı regresyonu geri getirmediğini gerçek cihazda kanıtlar (`AndroidManifest.xml`, `StudyTimerService.kt`).
- GitHub updater diyaloğu kapatılabilir ve Play kanalında updater devre dışıdır; mevcut uygulamada eski sürümü gerçekten zorlayan bir minimum-version mekanizması yoktur (`updater_service.dart`, `updater_dialog.dart`). Aktivasyon güvenliği yalnız “güncelle” mesajına bırakılamaz.
- `nav_index.dart` yalnız `kHomeTabIndex` içerir; diğer sekme sabitleri yoktur. Tap-to-top planı bu dosyayı değiştirmeden hardcode'suz uygulanamaz.
- Görevler prefs tabanlıdır; cloud isimli repo gerçekte prefs kullanır. Grup tablosunda avatar alanı yoktur.
- Kök `AGENTS.md` ve `CLAUDE.md` artık ince işaretçidir; tek `main` kuralı çelişkisiz biçimde `.agents/AGENTS.md`'den gelir.

---

## 3. Kilitli mimari kararlar

### MK-1 — Claim ayrı `achievement_rewards` tablosudur

- `xp_ledger` şeması ve `AFTER INSERT` XP trigger'ı değişmez; ledger yalnız banklanmış XP'dir.
- Pending ödül `achievement_rewards` içinde tutulur. Zorunlu korumalar:
  - `UNIQUE(user_id, achievement_id, tier)` ve `UNIQUE(event_key)`;
  - `event_key`, `(user_id, achievement_id, tier)` üçlüsünden server-generated kanonik değerdir; istemci/helper serbest metin vermez;
  - `tier > 0`, `xp_amount > 0`;
  - `pending ⇒ claimed_at IS NULL`, `claimed ⇒ claimed_at IS NOT NULL`;
  - FK'ler ve server-managed `earned_at`.
- Ödülün XP değeri **kazanıldığı anda** reward satırında sabitlenir; claim güncel sözlükten yeniden fiyatlandırmaz ve istemci XP göndermez.
- Claim transaction'ı aynı kilit altında `pending→claimed` ve ledger insert yapar. Ledger insert/postcondition başarısızsa status update de rollback olur.
- `_record_pending_reward` SECURITY DEFINER helper'ının `PUBLIC`, `anon`, `authenticated` execute yetkileri açıkça revoke edilir. Yalnız kontrollü server zinciri çağırır.
- `claim_all_rewards` set-based ve bounded'dır: çağrı başına en fazla 100 satır; kalan sayı/cursor döner. Uzun, sınırsız transaction yoktur.
- Legacy veri için “göç yok” değil, **preflight reconciliation vardır**: `user_achievements`, `selected_badges`, `gamification_profiles.xp` ve `xp_ledger` farkları raporlanır. Otomatik düzeltme ayrı onay olmadan yapılmaz.
- Saat başı 50 XP doğrudan ledger'a auto-banked kalır; reward inbox'a girmez. **WP-219 contract aktivasyonundan sonra tüm hesaplarda yalnız server-verified segment toplamı bu XP'yi üretir.** Manual/legacy-unverified çalışma normal istatistiğe girer ama kritik XP üretmez. Bu güvenlik kuralı capability ile opt-out edilemez; capability yalnız reward'ın pending/auto sunumunu seçer.

### MK-2 — Progress self-only projeksiyondur

`user_achievements` ortak aktif grup üyelerince okunabildiği için kilitli/gizli başarım progress'i buraya eklenmez. Yeni self-only tablo kullanılır:

`achievement_metric_progress(user_id, achievement_id, metric_value, source_version, updated_at)`

- SELECT yalnız `auth.uid()`; doğrudan write yok, server projector yazar.
- `tier`/`unlocked_at` yalnız claimed ledger projeksiyonunda kalır.
- Kümülatif metrikler artar; streak gibi güncel metrikler düşebilir. Genel `greatest(old,new)` kuralı kullanılmaz.
- Değer değişmediyse update yapılmaz (`IS DISTINCT FROM`) ve gereksiz realtime fırtınası oluşmaz.
- UI gerçek değer/sonraki eşik oranını bu self-only sözleşmeden okur; çift repository paritesi zorunludur.

### MK-3 — Güvenilir canlı oturum = server-issued segment

Başarı için `source='live'` yeterli değildir. Yeni doğrulanmış akış:

- `live_study_runs`: server başlatır; kullanıcı, seçili `group_id_snapshot` (grup sonradan silinse de audit bağını koruyan immutable UUID), server `started_at`, durum ve idempotency anahtarı. Snapshot start RPC'de mevcut grup + aktif üyelik üzerinden doğrulanır; direct DML yoktur.
- `live_study_segments`: work başlangıç/bitiş segmentlerini server zamanıyla tutar. Start/pause/resume/finish RPC'leri tek açık segment ve tek aktif run kuralını uygular.
- `study_sessions.live_run_id UNIQUE NULLABLE FK`, finalized session'ı `live_study_runs.group_id_snapshot` içindeki başlangıçta doğrulanmış **tek** grup bağlamına bağlar. `study_sessions` kullanıcıya ait kalır; kaldırılmış `group_id` kolonu geri getirilmez ve ayrı redundant context tablosu kurulmaz.
- Finalize RPC, segment toplamından `study_sessions` satırı üretir ve `live_run_id` ile doğrular. Aynı run ikinci session üretemez.
- Eski client'ın direct `source='live'` satırı geçici olarak istatistik uyumu için kabul edilebilir ama `live_run_id IS NULL` kalır ve achievement açısından unverified'dır. Direct DML için `live_run_id IS NULL` RLS/CHECK zorunludur; istemci verified bağ üretemez. Verified run/session/segment immutable'dır.
- Timer offline başlarsa çalışma kaybolmaz, normal istatistiğe manual/unverified olarak yazılır; server tokenı olmadığı için achievement veya saatlik XP'ye girmez. UI bunu sessizce “verified live” göstermemelidir.
- Uygulama açıkken Dart'ın başlattığı akış start RPC'den aldığı run kimliğini native state/outbox'a taşır; app-kill sonrası native Stop aynı kimlikle idempotent finalize edebilir. **Flutter kapalıyken widget/bildirimden saf-native start** ise mevcut güven sınırında sunucu tokenı alamaz ve stat-only/unverified kalır. Bu plan native katmana access token kopyalamaz, önceden dağıtılmış run tokenı uydurmaz ve native startı kanıtsız biçimde verified ilan etmez. Başlangıç kökeni saha ölçümünde ayrı raporlanır.
- Grup başarıları yalnız verified segment + immutable group context kullanır. Gelecekte tek session'ın birden fazla gruba yazılması yoktur; seçili grup start anında sabitlenir.

WP-216 server/data sözleşmesi, WP-217/218/220 için **sert bloktur**; WP-220 client/native saha kanıtı da WP-219 için sert bloktur.

### MK-4 — Legacy retro konservatif ve denetlenebilirdir

Geçmiş gerçek grup bağlamı kaybolduğu için “eksiksiz presence retro” iddiası yasaktır.

- Legacy grup session'ı yalnız başlangıç anında **tam bir** surviving üyelik penceresiyle eşleşiyorsa proxy gruba atanır. Sıfır veya birden fazla eşleşme varsa otomatik ödülden hariç tutulur ve raporlanır.
- Yeniden katılım öncesi kaybolan pencere geri üretilemez; bu durum false-negative doğurabilir ve raporda açıkça yazılır.
- Legacy Mola Düşmanı yalnız `source='live'`, zaman/süre constraint'lerini sağlayan, çakışma/anomali filtresinden geçen kayıtlarla hesaplanır. Bu yine “legacy proxy”dir; verified değildir.
- Kullanıcıya vaat edilen tanım “eldeki doğrulanabilir kayıtlara göre retro”dur. Hariç tutulan belirsiz satır otomatik XP üretmez.
- Backfill profil açılışında çalışmaz. `achievement_backfill_jobs` tablosunda cursor, source version, durum ve hata tutulur; batch rerunnable/idempotent'tir.
- Late-arrival/invalidation için yalnız per-user timestamp checkpoint kullanılmaz. `achievement_metric_dirty(scope_type, scope_id, istanbul_day)` bucket'ları etkilenen kullanıcı/grup/günü bounded yeniden hesaplatır.

### MK-5 — Metrik tanımları

- **Alfa Kurt:** yalnız tamamlanmış İstanbul günleri. Verified gelecekte seçili grup bağlamında gün toplamı en yüksek kullanıcı(lar) kazanır; eşitlikte tüm liderler sayılır. Legacy'de yalnız tekil proxy grup eşleşmesi. Aynı verified run tek gruba aittir.
- **Kamp Ateşi:** aynı verified grup bağlamında en az 3 farklı kullanıcının aktif work segmentlerinin kesiştiği süre; kesişimde bulunan her katılımcıya aynı ortak süre yazılır. Aynı kullanıcı segmentleri önce union; sweep-line O(n log n). Metin “oturum kayıtlarına göre eşzamanlı çalışma” der, tarihsel presence iddiası kurmaz.
- **Lokomotif:** kullanıcının verified run başlangıç anında aynı grupta başka aktif verified work segmenti yoktur; ardından 15 dakika içinde en az 2 farklı üye verified run başlatır. Olay yalnız başlatan kullanıcıya yazılır. “Önceki N dakika” yaklaşımı yoktur; exact interval state kullanılır. Bir başlangıç en fazla bir olaydır.
- **Mola Düşmanı:** herhangi bir kayan 5 saatte toplam verified aktif segment ≥270 dakika. Segment union + two-pointer; tek kademe.
- **team_player:** mevcut “grup günlük hedefine katkı günü” metriği korunur, kullanıcı metni buna hizalanır.
- **Kusursuz Ay:** **Ürün kararı: 28/30.** Bir takvim ayında en az 28 İstanbul günü günlük hedefe ulaşılırsa bir Kusursuz Ay sayılır; eşik sabit 28'dir (30 günlük ayda 28/30). `achievement_dictionary`, server evaluator (`0024:498–509`) ve Dart motoru bu kurala hizalıdır. Daha önce append-only ledger'a banklanmış XP/rozet geri alınmaz; yeniden hesaplanan güncel metrik daha düşük olsa bile geçmiş kazanım grandfathered kalır.
- Manuel/unverified oturum session-türevi achievement ve saatlik XP'ye girmez; yalnız normal çalışma istatistiğine girer. Kazanımdan sonra verified session silme/düzenleme XP iadesi doğurmaz; ledger append-only'dir.

### MK-6 — Canlılık ve performans sözleşmesi

- Kullanıcının kendi doğrulanmış segmenti finalize olduktan sonra self progress ≤5 saniyede görünür.
- Campfire/locomotive gibi başka üyeden etkilenen progress, finalize/start RPC'nin set-based affected-user projeksiyonuyla ≤5 saniyede görünür. Alpha gün kapanışında finalize edilir; “bugün liderim” pending ödül değildir.
- Online evaluator testi: 50 üyeli grup, kullanıcı başına 10.000 oturum ve 2 yıllık sentetik veri; `EXPLAIN (ANALYZE, BUFFERS)` ile event-path p95 ≤750 ms, statement timeout 2 s.
- Backfill batch'i en fazla 25 kullanıcı veya 31 grup-gün bucket işler; p95 ≤5 s. Timeout'ta transaction/batch geri alınır, cursor ilerlemez.
- Pairwise all-history self-join ve her profil açılışında full scan kabul edilmez.
- `0033`teki her event'te `1..total_hours` conflict döngüsü korunmaz. Server projection son banklanan verified saat watermark'ını tutar ve yalnız yeni tam saat aralığını işler; ilk büyük fark bounded batch'e devredilir.

### MK-7 — Expansion/contract rollout

Reward altyapısını eklemek ile otomatik banklamayı kapatmak farklı yayınlardır:

1. WP-209 tablo/RPC/client repository'yi ekler; mevcut auto-award devam eder.
2. WP-208 private progress contract'ını ekler.
3. WP-210 claim-capable UI stable olur; boş inbox desteklenir.
4. WP-216 verified live server/data lifecycle'ını expansion olarak kurar; mevcut session XP davranışı henüz değişmez.
5. WP-220 Dart timer/native outbox entegrasyonunu shadow modda yayınlar. Build/capability, verified başarı/finalize hata oranı, fallback nedeni ve başlangıç kökeni en az 7 ardışık gün ölçülür; eski davranış bu ölçüm süresince devam eder.
6. WP-217/218 metrik motorları ve backfill job'ları kurulur ama production backfill koşmaz; WP-220 ile WP-217/218, WP-216 sonrasında sahiplik izin verdiği ölçüde paralel yürüyebilir.
7. Yalnız WP-220 saha eşikleri sağlanınca WP-219 hesap-bazlı `reward_inbox_enabled_at` capability'si olan kullanıcıları pending modele geçirir ve kontrollü retro job'larını başlatır. Capability yoksa uygun ödül auto-award kalır; **fakat session-türevi ödül uygunluğu ve ambient saat XP herkes için aynı anda verified-only olur.** Eski client istatistik kaydeder ama XP kazanmak için verified-session destekli sürüme güncellenmelidir.

**Hybrid post-cut yoktur:** aktivasyon öncesi ölçüm penceresinde legacy saat XP davranışı aynen sürer; WP-219'dan sonra “achievement yok ama unverified `source='live'` saat XP alsın” istisnası açılmaz. Böyle bir istisna, direct session fabrikasyonuyla sınırsız XP açığını geri getirir. Bu sıra hem eski client'ın görünmeyen pending biriktirmesini engeller hem güvenlik sözleşmesini tek anlamlı tutar.

---

# 4. İş paketleri

> **Gerçek DAG:** `WP-209 → WP-208`; buradan claim UI hattı `WP-210 → WP-211`, güven hattı `WP-216 → {WP-220, WP-217 → WP-218}` olarak ayrılır ve `WP-219` öncesi yeniden birleşir. WP-210 ile WP-216 birbirine bağlı değildir; sahiplik uygunsa paralel yürür.
> **Bağımsız hatlar:** Görev `WP-212→213`; Grup PP `WP-214`; Tap-to-top `WP-211→WP-215` ve dosya çakışması nedeniyle WP-214 sonrası.
> Aynı anda en fazla iki hat. `supabase/migrations/**` tümü sıcak; migration ekleyen hiçbir WP paralel açılmaz. ARB yazarı aynı anda yalnız bir WP'dir.

## WP-209 — Reward inbox expansion: şema + atomik claim, davranış değişmeden 🎁

- **Program/Faz:** Başarım · **Ajan:** — · **Model:** 🔴 Opus · **Bağımlılık:** yok · **Durum:** [ ] Bekliyor
- **Problem:** Claim altyapısı gerekir; fakat server davranışını UI'dan önce çevirmek eski client'ı kırar.
- **Kapsam dışı:** `process_achievement_event` auto→pending aktivasyonu (WP-219), UI (WP-210), metrikler.
- **SAHİP dosyalar:** `supabase/migrations/00NN_achievement_rewards_expand.sql`; yeni `app/lib/data/models/achievement_reward.dart`; yeni `app/lib/data/repositories/achievement_reward_repository.dart`; yeni `app/lib/data/repositories/supabase/supabase_achievement_reward_repository.dart`; yeni `app/lib/data/repositories/in_memory/in_memory_achievement_reward_repository.dart`; yeni `app/lib/data/providers/achievement_reward_provider.dart`; ilgili SQL/Dart testleri.
- **DOKUNMA:** `xp_ledger` tablo/trigger; profil UI; metrik migration'ları.
- **Adımlar:** MK-1 constraints/FK/RLS/revoke; trusted `xp_amount` snapshot; atomik claim; bounded claim-all; account capability kaydı; legacy reconciliation raporu; saat XP'nin bu WP'de mevcut auto-banked davranışını koruyan regresyon testi. `process_achievement_event` bu WP'de auto-award kalır.
- **Veri/Migration:** Expansion-only. Aktivasyon öncesi rollback tabloyu yalnız boşsa kaldırabilir. Aktivasyon sonrası reward satırı drop edilmez; ters sıra WP-219→209 ve pending snapshot/drain gerekir.
- **RLS/Güvenlik:** self select; direct insert/update/delete yok; helper execute revoke; kontrollü `search_path`; `auth.uid()` zorunlu.
- **Edge-case:** iki cihaz claim yarışı, offline retry, 100+ reward pagination, sözlük XP değişimi, ledger/profile legacy farkı.
- **Kabul:** Migration sonrası mevcut XP ve award davranışı değişmez; staging'de injected pending claim edilince ledger/profile tam bir kez artar; ikinci claim 0 artış; reconciliation raporu üretilir; testler yeşil.
- **Tuzak:** Bu WP'de auto-award'ı kapatmak; claim'de güncel sözlük XP'si okumak; helper'ı authenticated'a açmak.

## WP-208 — Private metric progress contract + legacy audit 📐

- **Program/Faz:** Başarım · **Ajan:** — · **Model:** 🔴 Opus · **Bağımlılık:** WP-209 · **Durum:** [ ] Bekliyor
- **Problem:** `progress=tier`; gerçek 26/30 yok ve ortak-okunur tabloda secret progress saklamak gizlilik sızıntısı yaratır. Legacy retro kalitesi bilinmiyor.
- **Kapsam dışı:** Ölü grup metriklerinin uygulaması (WP-217/218), UI (WP-210), pending aktivasyonu (WP-219).
- **SAHİP dosyalar:** `supabase/migrations/00NN_achievement_metric_contract.sql`; yeni `app/lib/data/models/achievement_metric_progress.dart`; `app/lib/data/repositories/achievement_repository.dart`; `app/lib/data/repositories/supabase/supabase_achievement_repository.dart`; `app/lib/data/repositories/in_memory/in_memory_achievement_repository.dart`; `app/lib/data/providers/achievement_provider.dart`; `app/lib/core/stats/achievement_ledger_engine.dart`; ilgili testler.
- **DOKUNMA:** Reward repository/RPC; profil widget'ları; session lifecycle.
- **Adımlar:** MK-2 self-only tablo/RLS/projector; metric dictionary/source_version; streak decrease testleri; unchanged-row no-op; `achievement_backfill_jobs` + dirty bucket şeması; read-only legacy quality/audit RPC ve rapor formatı; 0033 saat döngüsü için verified-hour watermark/bounded catch-up sözleşmesi; **Kusursuz Ay 28/30 kuralını** server evaluator, Dart `achievement_ledger_engine` ve sözlük açıklamasına hizala; 27 gün negatif sınır testi ve önceden claim edilmiş 28-gün kazanımının iade edilmediği grandfather testi.
- **Veri/Migration:** Expansion-only + mevcut evaluator'ın 28/30 kuralına hizalanması; mevcut `user_achievements.progress` geriye uyum için durur ama yeni UI onu metrik saymaz. Daha önce banklanmış ledger/rozet geri alınmaz; yeni hesaplanan metrik source version ile güncellenir. Rollback yeni projection tablolarını yalnız job/pending üretmeden önce kaldırabilir; audit çıktısı saklanır.
- **RLS/Güvenlik:** secret progress yalnız self; client metric yazamaz; SECURITY DEFINER iç sorguları explicit kullanıcı/scope sınırıyla çalışır.
- **Edge-case:** streak 7→0; locked secret; metric null; source_version değişimi; legacy multiple/no-group eşleşmesi.
- **Kabul:** Başka grup üyesi raw API'de secret progress göremez; self gerçek değer görür; streak düşer; aynı değer tekrar yazılmaz; Kusursuz Ay yalnız ayda ≥28 hedef günüyle artar; 27 günle artmaz; eski 28-gün claim'i XP iadesi olmadan korunur; audit belirsiz/excluded satır sayısını verir; testler yeşil.
- **Tuzak:** `user_achievements.metric_progress` kolonu eklemek; tüm metriklere `greatest`; per-profile full scan.

## WP-210 — Claim-capable başarı UI + gerçek progress 🎨

- **Program/Faz:** Başarım · **Ajan:** — · **Model:** 🟣 Pro · **Bağımlılık:** WP-208, WP-209 · **Durum:** [ ] Bekliyor
- **Problem:** Kullanıcı gerçek metriği, sonraki kademeyi ve claim aksiyonunu göremiyor.
- **Kapsam dışı:** Server aktivasyonu/retro; shell banner/nav badge (WP-211).
- **SAHİP dosyalar:** `app/lib/features/profile/widgets/achievement_showcase.dart`; `app/lib/features/profile/social_profile_screen.dart`; gerekirse `app/lib/core/stats/progression_visuals.dart`; `app/lib/l10n/app_tr.arb`; `app/lib/l10n/app_en.arb`; `app/lib/l10n/app_de.arb`; `app/lib/l10n/app_ar.arb`; ilgili widget/golden testleri.
- **DOKUNMA:** `home_shell.dart`, `nav_index.dart`, server migration'ları.
- **Adımlar:** self metric'ten “26/30 · sonraki”; streak; pending “Topla” ve bounded “Tümünü topla”; server sonucu sonrası XP/rozet animasyonu; claim UI/repository hazır olduktan sonra idempotent `reward_inbox_v1` capability kaydı (WP-219 öncesi davranış değiştirmez); en yakın tek başarı şeridi; WP-208'in 28/30 Kusursuz Ay contract'ını kullanıcı metnine doğru yansıt; team_player, ambient saat-XP ve “XP için doğrulanmış kronometre çalışması gerekir” metinleri; WP-211'in “n ödül hazır · Topla” ARB anahtarlarını bu WP üretir.
- **Veri/Migration:** yok.
- **RLS/Güvenlik:** claim yalnız self; başkasının profilinde buton/secret progress yok; optimistic animasyon server başarısından önce kalıcılaşmaz.
- **Edge-case:** boş inbox, 100+ pending, offline/retry, gizli reward silüeti, metric null, reduce-motion.
- **Kabul:** Boş inbox'ta eski uygulama davranışı bozulmaz; staging pending claim sonrası UI ≤1 s güncellenir ve ikinci claim artış yapmaz; 360/600/1200 px taşma yok; WCAG AA/48dp; testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzak:** ARB'yi WP-213 ile paralel yazmak; tier'i progress sanmak; server onayından önce rozet açmak.

## WP-211 — Reward bildirimi + kanonik tab indeksleri 🔔

- **Program/Faz:** Başarım/IA · **Ajan:** — · **Model:** 🟣 Pro · **Bağımlılık:** WP-210 · **Durum:** [ ] Bekliyor
- **Problem:** Pending ödül shell'de görünmüyor; `nav_index.dart` diğer tab sabitlerini taşımıyor.
- **Kapsam dışı:** Profil claim listesi; ekran scroll controller'ları (WP-215); push notification.
- **SAHİP dosyalar:** `app/lib/core/navigation/nav_index.dart`; `app/lib/core/navigation/home_shell.dart`; yeni `app/lib/features/profile/widgets/reward_toast.dart`; ilgili testler.
- **DOKUNMA:** ARB (WP-210 anahtarlarını okur); profile showcase; scroll ekranları.
- **Adımlar:** tüm tab indekslerini tek enum/sabit sözleşmeye taşı; pending banner + Profil badge; claim olunca temizlenme; taç yükselişi tek seferlik kutlama; debounce/reduce-motion.
- **Veri/Migration:** yok.
- **RLS/Güvenlik:** yalnız self-only reward stream okunur; shell başka kullanıcının pending sayısını sorgulamaz; client badge yetki kaynağı değildir.
- **Edge-case:** startup'ta çok pending, offline, banner kapalıyken badge, shell restore.
- **Kabul:** Pending ≤5 s içinde banner+badge; claim sonrası ≤5 s içinde ikisi kaybolur; nav sabitleri hardcode içermez; testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzak:** ARB'ye yazmak; badge'i banner local state'ine bağlamak; `nav_index` sıcak yüzeyini WP-215 ile paralel açmak.

## WP-216 — Server-issued live session server/data expansion 🛡️

- **Program/Faz:** Başarım güvenlik kapısı · **Ajan:** — · **Model:** 🔴 Opus · **Bağımlılık:** WP-208 · **Durum:** [ ] Bekliyor
- **Problem:** Client direct DML ile `source='live'` yazabilir; bu etiket güven kanıtı değildir. Kaldırılmış `group_id` yüzünden de güvenilir grup retro/context yoktur. Yeni verified yol eski client'ın normal istatistik kaydını deploy anında kırmamalıdır.
- **Kapsam dışı:** Timer/provider/native entegrasyonu ve saha QA'sı (WP-220); başarım algoritmaları/backfill (WP-217/218); eski veriyi “temiz” ilan etmek.
- **SAHİP dosyalar:** `supabase/migrations/00NN_verified_live_sessions.sql`; `app/lib/data/models/study_session.dart`; `app/lib/data/repositories/study_repository.dart`; `app/lib/data/repositories/supabase/supabase_study_repository.dart`; `app/lib/data/repositories/in_memory/in_memory_study_repository.dart`; ilgili repository/server contract testleri.
- **DOKUNMA:** `app/lib/data/providers/study_providers.dart`; `app/lib/core/background/**`; Android native timer/widget dosyaları; achievement metric/reward migration'ları; profil UI.
- **Adımlar:** MK-3 tablolar/RPC; `study_sessions.live_run_id UNIQUE NULLABLE FK`; start/pause/resume/finalize lifecycle; tek aktif run/segment; start'ta membership doğrula ve tek group context sabitle; finalize idempotent session insert; direct DML'de `live_run_id IS NULL` zorunlu ve legacy source unverified; mevcut 0012 constraint'lerini denetle/güçlendir; verified satır immutability; varsayılanı pasif `minimum_verified_xp_build` config'i; minimal rollout gözlemi için server-managed build/capability/fallback günlük agregası ve 30 günlük retention.
- **Veri/Migration:** Expansion + RLS contract. `study_sessions.group_id` geri gelmez; doğrulanmış bağ yalnız `live_run_id → live_study_runs.group_id_snapshot` join'idir. Snapshot grup silinince cascade olmaz; yalnız audit/metrik kimliğidir. Existing rows legacy-unverified kalır. Rollback yalnız yeni run yoksa; sonrasında verified kayıtlar korunur, eski client compatibility yolu açık kalır.
- **RLS/Güvenlik:** istemci server time, group membership, `live_run_id` veya segment owner yazamaz; helper/RPC grants explicit. `live_run_id IS NULL` satır server açısından unverified işaretlenir; ancak mevcut XP evaluator'ı expansion sırasında değiştirilmez, küresel verified-only ekonomik kesişi yalnız WP-219'dur.
- **Edge-case:** ağ cevabı kaybı, grup değişimi veya grup silinmesi run ortasında, gece yarısı, iki cihazdan aktif run, clock skew, forged capability/fallback telemetry.
- **Kabul:** Direct DML ile non-null `live_run_id` reddedilir; iki cihaz aynı anda iki run açamaz; üye olunmayan group context reddedilir; retry tek session üretir; migration sonrası eski client session kaydı ve mevcut saat XP davranışı değişmez; operational tablo/RPC raw session içeriği, e-posta veya token saklamaz ve 30 günden eski satırlar temizlenir; Supabase+InMemory contract testleri yeşil.
- **Tuzak:** Eski client'ı bir gecede direct insert reddiyle kırmak; yalnız CHECK ile güvenilirlik iddia etmek; istemci `source`una güvenmek; group_id'yi study_sessions'a geri eklemek; verified session update kaçışı.

## WP-220 — Verified timer client/native köprüsü + shadow rollout 📱

- **Program/Faz:** Başarım güvenlik/saha kapısı · **Ajan:** — · **Model:** 🔴 Opus · **Bağımlılık:** WP-216 · **Durum:** [ ] Bekliyor
- **Problem:** Server sözleşmesi tek başına üretim verisi doğurmaz. Mevcut sayaç Flutter→native→outbox hattı kırılgandır; Flutter kapalıyken widget/bildirimden native start server-issued run alamaz. Verified-only XP kesişinden önce gerçek benimseme ve hata oranı bilinmelidir.
- **Kapsam dışı:** Native katmana Supabase access token taşımak; önceden dağıtılmış/uzun ömürlü run tokenı; saf-native startı kanıtsız verified ilan etmek; XP contract aktivasyonu (WP-219); metrik algoritmaları.
- **SAHİP dosyalar:** `app/lib/data/providers/study_providers.dart`; `app/lib/core/background/timer_foreground_service.dart`; `app/lib/core/notifications/timer_external_command_store.dart`; `app/lib/features/classroom/widgets/study_timer_card.dart`; `app/lib/features/classroom/widgets/focus_timer_screen.dart`; `app/lib/features/classroom/widgets/timer_mode_controls.dart`; `app/lib/l10n/app_tr.arb`; `app/lib/l10n/app_en.arb`; `app/lib/l10n/app_de.arb`; `app/lib/l10n/app_ar.arb`; `app/android/app/src/main/kotlin/com/manilmax/online_study_room/MainActivity.kt`; `app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/TimerStateStore.kt`; `app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt`; `app/android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/TimerActionReceiver.kt`; `app/android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/TimerWidgets.kt`; `app/android/app/src/main/res/values/strings.xml`; `app/android/app/src/main/res/values-tr/strings.xml`; ilgili Dart/Kotlin testleri.
- **DOKUNMA:** Supabase migration'ları (WP-216 RPC'sini kullanır); achievement/reward motorları; `app/android/app/src/main/AndroidManifest.xml` (mevcut API≤13 `dataSync` / API34+ `specialUse` sözleşmesi salt doğrulanır; değişiklik gerekirse ayrı replan). WP-210/213 ile ARB yüzeyi kesin seridir.
- **Adımlar:** Dart start RPC sonucu run kimliğini native state'e atomik aktar; pause/resume/stop/finalize retry/outbox idempotency; app-kill sonrası tokenlı native Stop'u finalize et; offline ve saf-native startı normal unverified session olarak koru; kullanıcıya “istatistiğe sayılır, XP/başarıma sayılmaz” geri bildirimi ver; pasif `minimum_verified_xp_build` config'ini okuyup sayaç-öncesi readiness/update mesajını uygula; build + `verified_session_v1` capability kaydı; start origin (`dart_app`, `native_widget`, `native_notification`), verified/fallback/finalize-failure sayaçlarını WP-216'nın minimal günlük agregasına yaz; shadow modda XP davranışını değiştirme.
- **Veri/Migration:** yok. Server sözleşmesi WP-216'dır. Telemetry yalnız build/platform/capability, agregat başarı/hata/fallback nedeni ve başlangıç kökeni taşır; raw süre/içerik, e-posta, access/refresh token yoktur; 30 gün retention.
- **RLS/Güvenlik:** Client telemetry güvenlik kanıtı veya XP otoritesi değildir; verifiedlik yalnız server run/segment zincirindedir. Native depoda auth token saklanmaz. Saf-native başlangıç unverified kalır.
- **Edge-case:** Android 8–13 ve 14+, FGS start kısıtı, app kill/native Stop, widget cold-start, notification action, ağ cevabı kaybı, offline start, pomodoro work/break geçişi, force-stop/reboot, aynı hesabın iki cihazı, eski native state migration'ı.
- **Kabul:** Dart/app start→app-kill→native Stop tek verified session üretir; duplicate/reordered command ikinci session/XP üretmez; offline ve saf-native start kaybolmaz ama unverified görünür; native start oranı ayrı raporlanır; Android ≤13'te mevcut FGS crash'i geri gelmez ve API 34+ service type uyumludur; Samsung gerçek cihaz + en az bir Android ≤13 cihazda widget/bildirim/app-kill senaryoları kanıtlanır; shadow modda mevcut XP ekonomisi değişmez; testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzak:** Android ≤13 regresyonunu yalnız emulator/test ile kapatmak; `source='live'` fallback'ini verified saymak; native'a kullanıcı oturumu/tokenı kopyalamak; telemetry opt-out'lu Sentry örneklemini rollout paydası sanmak.

## WP-217 — Mola Düşmanı motoru + bounded retro ⏱️

- **Program/Faz:** Başarım metrik · **Ajan:** — · **Model:** 🔴 Opus · **Bağımlılık:** WP-216 · **Durum:** [ ] Bekliyor
- **Problem:** `secret_break_enemy` daima 0; 5 saatlik kayan pencere doğru ve hızlı hesaplanmalı.
- **Kapsam dışı:** Grup metrikleri; production backfill çalıştırma (WP-219).
- **SAHİP dosyalar:** `supabase/migrations/00NN_break_enemy_metric.sql`; `app/lib/core/stats/achievement_ledger_engine.dart` ilgili parite; SQL/Dart perf testleri.
- **DOKUNMA:** Group metric migration; reward activation; UI.
- **Adımlar:** verified segment union + two-pointer; legacy proxy filtreleri; dirty user/day invalidation; projector self progress; job tanımı fakat run yok; source_version; idempotent reward candidate üretimi.
- **Veri/Migration:** metric function/index/job definition. Rollback projector'u önceki source_version'a döndürür; job sonuçları silinmez, inactive işaretlenir.
- **RLS/Güvenlik:** yalnız server verified segmenti ödül adayıdır; legacy proxy ayrı audit etiketi taşır.
- **Edge-case:** tam 270 dk, pencere sınırı, çakışan segment, gece yarısı, timeout/retry.
- **Kabul:** sentetik sınır testleri doğru; ikinci çalıştırma duplicate candidate üretmez; event p95/backfill p95 MK-6 bütçesinde; testler yeşil.
- **Tuzak:** pairwise interval; `duration_seconds`'ı zaman ekseninden kopuk toplamak; timeout'ta cursor ilerletmek.

## WP-218 — Alfa/Kamp Ateşi/Lokomotif grup metriği + konservatif legacy proxy 🔥

- **Program/Faz:** Başarım metrik · **Ajan:** — · **Model:** 🔴 Opus · **Bağımlılık:** WP-216, WP-217 · **Durum:** [ ] Bekliyor
- **Problem:** Üç grup başarımı 0; tarihsel group context eksik; başka üyenin olayı mevcut kullanıcı progress'ini etkiler.
- **Kapsam dışı:** Production reward aktivasyonu/backfill run (WP-219); tarihsel presence iddiası.
- **SAHİP dosyalar:** `supabase/migrations/00NN_group_achievement_metrics.sql`; ilgili SQL perf/contract testleri.
- **DOKUNMA:** WP-216 lifecycle; client UI; reward RPC.
- **Adımlar:** MK-5 exact verified algoritmalar; interval union+sweep-line; affected-user set-based projector; İstanbul gün kapanışı Alpha finalizer (`pg_cron` 00:05 Europe/Istanbul karşılığı + ilk sonraki event/manual refresh idempotent catch-up); legacy tekil proxy attribution/exclusion raporu; group/day dirty bucket; job definitions; team_player metin-contract paritesi.
- **Veri/Migration:** functions/indexes/jobs. Rollback source_version'ı kapatır; claimed ledger geri alınmaz.
- **RLS/Güvenlik:** SECURITY DEFINER scope sınırı; caller keyfi user/group ile başkasına reward yazdıramaz; progress self-only.
- **Edge-case:** tie, 50 üye, rejoin, zero/multiple proxy group, follower start race, segment sınırı, late arrival.
- **Kabul:** Alpha yalnız kapalı gün ve cron kaçsa bile catch-up ile tek kez finalize; Kamp ≥3 exact; Lokomotif exact active-state+15 dk; başka üye olayı etkilenen kullanıcı progress'ine ≤5 s yansır; p95 MK-6 içinde; belirsiz legacy satır XP üretmez; testler yeşil.
- **Tuzak:** `group_members.joined_at`'i eksiksiz tarihçe sanmak; “önceki N dk” boşluk sezgisi; auth.uid-only projector ile initiator'ı güncellememek.

## WP-219R — Süre kaynağı eşitliği ✅

- **Program/Faz:** Başarım contract düzeltmesi · **Durum:** Kod tamamlandı — migration/staging QA bekliyor.
- **Ürün kuralı:** Manuel süre ekleme, uygulama içi sayaç ve native/widget sayacı aynı XP, kişisel başarı ve grup başarımı yolundadır. Kullanıcıya verified/unverified ayrımı gösterilmez.
- **Uygulama:** `0063_equal_study_sources.sql` eski live-run bağlarını oturum satırlarından ayırır; tüm grup/Mola Düşmanı/Lider Kurt projeksiyonlarını üyelik penceresindeki `study_sessions` kaynağına çevirir; eski verified cron'ları kaynak-nötr cron'larla değiştirir ve türetilmiş projeksiyonları yeniden üretir.
- **Veri garantisi:** `study_sessions`, `xp_ledger`, rozetler ve pending ödüller silinmez. Eski live-run tabloları yalnız denetim geçmişi olarak kalır.
- **Cihazda/staging'de doğrulanmalı:** manuel süre, uygulama sayacı ve widget/bildirim başlangıcı aynı kişisel/grup ilerlemesini üretir; tarihsel XP/rozet kaybolmaz; yeni iki cron aktiftir; RLS ile kullanıcı yalnız kendi oturumunu düzenler.

## WP-212 — Günlük görev cloud modeli + çok-cihaz senkron 🗓️

- **Program/Faz:** Görevler · **Ajan:** — · **Model:** 🟣 Pro · **Bağımlılık:** yok · **Durum:** [ ] Bekliyor
- **Problem:** Görevler prefs'te; günlük tekrar, cihazlar arası silme/undo ve streak güvenilir değil.
- **Kapsam dışı:** UI (WP-213), görev→XP bağlantısı.
- **SAHİP dosyalar:** `supabase/migrations/00NN_user_tasks_cloud.sql`; `app/lib/data/models/user_task.dart`; `app/lib/data/repositories/user_task_repository.dart`; `app/lib/data/repositories/supabase/supabase_user_task_repository.dart`; `app/lib/data/repositories/in_memory/in_memory_user_task_repository.dart`; `app/lib/data/providers/user_task_providers.dart`; ilgili testler.
- **DOKUNMA:** `tasks_card.dart`, `tasks_screen.dart`, ARB, achievement dosyaları.
- **Adımlar:** `user_tasks` tombstone modeli; parent `UNIQUE(id,user_id)`; `user_task_completions` composite FK ve recurring/non-recurring partial unique; completion satırında `is_completed` ile undo; idempotent `client_operation_id`; server-arrival-order LWW (client clock otorite değil); offline `occurred_at` UTC'den server-side Istanbul günü ve makul skew; prefs→cloud resumable migration; midnight timer + app-resume invalidation; streak projection.
- **Veri/Migration:** iki tablo/RLS/RPC. Rollback data oluşunca drop değildir: client eski okuma moduna alınır, cloud tabloları read-only/snapshot olarak korunur.
- **RLS/Güvenlik:** own rows; completion user_id task sahibine composite FK; RPC auth.uid; task progress XP değildir.
- **Edge-case:** 23:59 offline→00:01 sync, iki cihaz toggle/undo, archive/unarchive, migration yarıda ağ kesilmesi, maxTasks.
- **Kabul:** günlük görev bugün tamamlanır, ertesi İstanbul günü silme olmadan aktif; undo diğer cihaza yayılır; tombstone silme yayılır; telefon değişince korunur; migration idempotent; testler yeşil.
- **Tuzak:** additive union ile undo kaybetmek; client `updated_at`ına güvenmek; tek-seferlik completed için iki kaynak.

## WP-213 — Günlük görev UI + 00:00 yenileme ✅

- **Program/Faz:** Görevler · **Ajan:** — · **Model:** 🔵 Sonnet · **Bağımlılık:** WP-212 · **Durum:** [ ] Bekliyor
- **Problem:** Kullanıcı günlük tipi seçip bugünkü durumunu göremiyor.
- **Kapsam dışı:** DB/RLS; sayaçlı hedef.
- **SAHİP dosyalar:** `app/lib/features/home/widgets/tasks_card.dart`; `app/lib/features/clock/tasks_screen.dart`; `app/lib/l10n/app_tr.arb`; `app/lib/l10n/app_en.arb`; `app/lib/l10n/app_de.arb`; `app/lib/l10n/app_ar.arb`; widget testleri.
- **DOKUNMA:** WP-210 ARB yazarken başlamaz; task repository.
- **Adımlar:** “Günlük yenilenen” seçim; bugün toggle/undo; 🔁 ve minimal streak; midnight/app-resume refresh; offline state/error.
- **Veri/Migration:** yok.
- **RLS/Güvenlik:** UI yalnız repository'nin own-row sözleşmesini kullanır; client gün/user_id türetimi yetki kaynağı değildir.
- **Edge-case:** açık ekran gece yarısı, cihaz TZ farklı, boş liste, mixed recurring/one-time.
- **Kabul:** ekle→bugün görünür→tamamla/geri al→ertesi gün aktif; tekrarsız regresyonsuz; 360px taşma yok; testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzak:** reset job/timer ile kayıt silmek; ARB paralel yazmak.

## WP-214 — Grup profil fotoğrafı, private bucket + signed URL 🖼️

- **Program/Faz:** Sosyal gruplar · **Ajan:** — · **Model:** 🟣 Pro · **Bağımlılık:** yok · **Durum:** [ ] Bekliyor
- **Problem:** Grup avatarı yok; public bucket private grup görselini URL sızıntısına açar.
- **Kapsam dışı:** Üye avatarı, banner, rol-tabanlı çoklu admin.
- **SAHİP dosyalar:** `supabase/migrations/00NN_group_avatar.sql`; `app/lib/data/models/study_group.dart`; `app/lib/data/repositories/group_repository.dart`; `app/lib/data/repositories/supabase/supabase_group_repository.dart`; `app/lib/data/repositories/in_memory/in_memory_group_repository.dart`; `app/lib/data/providers/group_providers.dart`; `app/lib/features/classroom/widgets/class_switcher.dart`; `app/lib/features/classroom/widgets/class_detail_screen.dart`; `app/lib/features/classroom/widgets/group_discovery_screen.dart`; `app/lib/features/classroom/widgets/campfire_scene.dart`; `app/lib/features/stats/widgets/class_stats_view.dart`; ilgili testler.
- **DOKUNMA:** profile avatar akışı salt referans; WP-215 stats dosyası bu WP bitmeden açılmaz; diğer migration'lar.
- **Adımlar:** `avatar_path`+`avatar_updated_at`; private `group-avatars`; SELECT storage RLS public group veya aktif üye, write/delete yalnız `is_group_admin`; versioned `<group_id>/<uuid>.<ext>` path; signed URL; discovery RPC path/timestamp; MIME jpeg/png/webp, ≤2 MB; upload sonrası eski object cleanup; group delete cleanup; fallback/accessibility.
- **Veri/Migration:** path saklanır, expiring signed URL DB'ye yazılmaz. Rollback kolon/object drop değildir; UI/RPC eskiye döner, data snapshot korunur.
- **RLS/Güvenlik:** private grup avatarı public URL değildir; `is_group_admin` yalnız creator modeli; UI kontrolü kozmetik, storage+table RLS esas.
- **Edge-case:** expired signed URL, cache refresh, admin olmayan upload, grup visibility değişimi, orphan object.
- **Kabul:** admin upload tüm yetkili yüzeylerde ≤5 s; private grup avatarı üye olmayana storage RLS ile reddedilir; public keşif authenticated kullanıcıda görünür; yeni path cache'i kırar; testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzak:** signed URL'yi kalıcı kolon yapmak; sabit path; public bucket; eski object biriktirmek.

## WP-215 — Tüm ana sekmelerde tap-to-top ⬆️

- **Program/Faz:** IA · **Ajan:** — · **Model:** 🔵 Sonnet · **Bağımlılık:** WP-211, WP-214 · **Durum:** [ ] Bekliyor
- **Problem:** Reselect yalnız Home'da çalışır; v2 hardcode yasaklayıp eksik nav sabitlerini değiştirmeyi de yasaklıyordu.
- **Kapsam dışı:** `nav_index.dart`/`home_shell.dart` (WP-211'de tamamlanır); Home davranışı.
- **SAHİP dosyalar:** `app/lib/features/classroom/classroom_screen.dart`; `app/lib/features/profile/profile_screen.dart`; `app/lib/features/clock/clock_screen.dart`; `app/lib/features/stats/widgets/personal_stats_view.dart`; `app/lib/features/stats/widgets/class_stats_view.dart`; ilgili testler.
- **DOKUNMA:** `app/lib/core/navigation/**`; `class_switcher.dart`; achievement showcase.
- **Adımlar:** WP-211 kanonik tab sabitleriyle `navReselectProvider` listen; her gerçek ListView'a controller; stats kişisel/grup iki liste; mounted/hasClients/no-op; ≤300 ms animation.
- **Veri/Migration:** yok.
- **RLS/Güvenlik:** veri erişimi veya yetkilendirme değişmez; yalnız yerel scroll davranışı.
- **Edge-case:** build öncesi tick, boş liste, zaten top, stats alt-tab, nested classroom.
- **Kabul:** Saat/Gruplar/İstatistik kişisel+grup/Profil offset>0 iken reselect ≤300 ms'de 0; Home regresyonsuz; hardcoded indeks yok; testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzak:** yanlış stats dosyasına controller eklemek; WP-214 ile `class_stats_view.dart` paralel yazmak; PrimaryScrollController çakışması.

---

## 5. Çakışma ve yürütme matrisi

- **Migration tek lane:** WP-209, 208, 216, 217, 218, 219, 212, 214 aynı anda açılamaz. WP-220 migration yazmaz. Numara claim anında son migration+1 olarak seçilir.
- **Başarım DAG:** 209→208; sonra client claim `210→211` ile güven server'ı `216` paralel olabilir. 216 sonrasında client/native `220` ve metrik `217→218` paralel olabilir; 210+217+218+220, 219'da birleşir.
- **Production davranış kapısı:** WP-219, WP-210 claim cihaz QA'sı, WP-220 native cihaz+saha QA'sı ve 7 günlük eşik kanıtı olmadan başlamaz.
- **ARB/native metin:** WP-210, WP-213 ve WP-220 aynı anda l10n/native metin yüzeyi açmaz; claim sırasında kesin SAHİP dosyaları yeniden teyit edilir.
- **Navigation:** WP-211 `core/navigation/**` tek yazarıdır; WP-215 sonra yalnız ekran dosyalarına yazar.
- **Stats dosyası:** WP-214 ve WP-215 `class_stats_view.dart` paylaşır; kesin seri: 214→215.
- **İkinci lane:** Başarım hattı açıkken yalnız Görev veya Grup PP/IA hattından biri açılır; aynı anda en fazla iki hat.
- **Git:** tek `main`; branch/merge/push yok (kullanıcı ayrıca istemedikçe); her WP tek ayrık commit, explicit stage, `git add -A` yasak.

## 6. Release/rollback kapıları

- Her migration staging dry-run + rollback rehearsal + RLS abuse testinden geçer.
- Reward activation öncesi claim-capable stable client, WP-220 verified-session cihaz QA'sı ve saha eşikleri zorunludur. GitHub updater'ın kapatılabilir, Play updater'ın devre dışı olduğu hesaba katılır; “minimum build” tek başına zorunlu güncelleme kanıtı değildir.
- Güvenli geçiş penceresi WP-219'dan **öncedir**: WP-220 shadow/soak boyunca eski saat XP ekonomisi sürer. WP-219 kesişinden sonra unverified legacy saat XP için geçici istisna açılmaz.
- Retro önce dry-run raporu üretir: kullanıcı sayısı, reward sayısı, toplam pending XP, legacy excluded/ambiguous satırlar, en büyük tek kullanıcı etkisi.
- Claim sonrası temel invariant: `gamification_profiles.xp = SUM(xp_ledger.xp_amount)`; pending bu toplama girmez.
- Rollback pending/reward veya cloud task/avatar datasını drop etmez. Contract geri alınır, kullanıcı verisi korunur.
- Stable release için Samsung gerçek cihaz, iki cihaz claim yarışı, offline timer, 23:59→00:01 görev ve storage RLS senaryoları kanıtlanır.

---

# DENETÇİ (SENIOR) İÇİN

## Okuma listesi

| İddia | Kaynak |
|---|---|
| Ledger append-only, insert bankalar, max tier | `0024_achievements_ledger.sql:55–65, 164–213, 322–350` |
| Progress=tier | `0024:191–200`, `achievement_showcase.dart` |
| Ölü metrikler | `0025_achievements_social_metrics.sql`, `0033_study_hour_xp_50.sql` |
| `group_id` kaldırıldı ve tarihsel kayıp kabul edildi | `0010_drop_session_group_id.sql:2–5, 28–31`; `study_session.dart`; `supabase_study_repository.dart:135–139` |
| Grup stats üyelik penceresi | `0011_group_daily_totals_v2.sql:34–39` |
| Rejoin joined_at ezer | `0012_group_join_hardening.sql:117–121` |
| Mevcut session constraint'leri | `0012_group_join_hardening.sql:155–168` |
| Client source/live yazıyor | `study_session.dart:47–56`; `supabase_study_repository.dart:18–31`; `study_providers.dart:_recordSession` |
| Saf-native start server run tokenı taşımıyor | `TimerStateStore.kt`; `StudyTimerService.kt`; `TimerActionReceiver.kt`; `study_providers.dart:_reconcileBackgroundTimer` |
| Mevcut updater zorunlu değil | `updater_service.dart`; `updater_dialog.dart` |
| Nav sabitleri eksik | `app/lib/core/navigation/nav_index.dart` |
| Gerçek scroll dosyaları | `classroom_screen.dart`, `profile_screen.dart`, `clock_screen.dart`, `personal_stats_view.dart`, `class_stats_view.dart` |

## Kapsam bütünlüğü

| Kullanıcı isteği | WP |
|---|---|
| Canlı gerçek progress + streak + rozet | 208 + 210 + metrik 217/218 |
| Gerçek claim, toplamazsa ilerleme sürer | 209 + 219 + UI 210/211 |
| Saat başı 50 XP ambient, yalnız verified süre | 209/208/216/220/219 regresyon+rollout kriteri |
| Alfa/Kamp/Lokomotif/Mola fix | 217 + 218 |
| Konservatif retro | 208 audit + 217/218 motor + 219 kontrollü run |
| Session fabrikasyonu kapatma | 216 server contract + 220 client/native köprü + 219 activation |
| Zorunlu-güncelleme ekonomik riski / saha ölçümü | 216 minimal operational schema + 220 shadow/QA + 219 eşik kapısı |
| Kusursuz Ay/team_player metni, az kaldı | 210 |
| Clash banner + Brawl nav badge | 211 |
| Günlük görev cloud/00:00/streak/undo | 212 + 213 |
| Grup avatarı | 214 |
| Tap-to-top | 211 + 215 |

## Plan dışı bilinçli sınırlar

- Tarihsel gerçek presence veya kaybolmuş `group_id` geri üretilemez; legacy sonuç “proxy”dir.
- Offline veya saf-native başlayıp hiç server tokenı almayan çalışma achievement/saatlik XP üretmez; normal çalışma istatistiğini kaybetmez. Native-auth/proof tasarımı ayrı gelecek kapsamdır.
- Claim edilmiş append-only XP, sonradan session silinince geri alınmaz.
- Rol-tabanlı çoklu grup admini, görev sayaç hedefi, push notification ve foto moderasyonu ayrı kapsamdır.

Bu v3.1'de teknik davranış, güvenlik sınırı, rollout, rollback ve Kusursuz Ay'ın **28/30** ürün semantiği kapalıdır. Production mutasyonu yine ilgili WP'nin staging/cihaz/saha kanıtı ve ürün kabulünden sonra yapılır.
