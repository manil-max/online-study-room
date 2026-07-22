# progress.md — İlerleme Takibi

> Son güncelleme: 2026-07-22 (bildirim güveni ve Android canlı sayaç programı eklendi)
> Sistem: İş Paketi (WP) tabanlı, **Kalite Programı**. Kanonik program: `docs/KALITE-PROGRAMI.md`.
> Planlama: `.agents/skills/planner/SKILL.md` · Uygulama: `.agents/skills/worker/SKILL.md` · Kurallar: `.agents/AGENTS.md`.
> **"Tamamlandı" = kod DEĞİL; kullanıcı beklentisini karşılayan + cihazda güvenilir çalışan iş.** İş durum merdiveni (8 aşama) ve kanıt etiketleri (`Kodda doğrulandı` / `Cihazda doğrulanmalı` / `Ürün kararı gerekiyor`) için bkz. AGENTS.md §0.

---

## Proje Gerçekleri (ajan referansı)

- **Framework:** Flutter ^3.12 · Riverpod 3.3 · Supabase 2.15 · fl_chart
- **Uygulama kökü:** `app/` — Flutter komutları yalnız burada çalışır.
- **Repo katmanı çift:** Her arayüz `supabase/` ve `in_memory/` repository'leriyle desteklenir.
- **Migration'lar:** `supabase/migrations/` — yerelde `0001–0065` pinli CLI/Docker ile tekrar kuruluyor. Production migration history zinciri yoktur; yeni production şema işi WP-232 yönetişim kapısından geçer. Ayrıntı: `docs/recovery/MIGRATION-BASELINE.md` ve `docs/recovery/PRODUCTION-BASELINE.md`.
- **Gün sınırı:** `Europe/Istanbul`
- **RLS helper'ları:** `is_group_member(gid)`, `can_see_user_sessions(target)`, `is_group_admin(gid)`, `is_super_admin()`
- **Dashboard:** 6 sütunlu 2D matris, 19 kart türü, `grid_reflow.dart` motoru.
- **Tema:** Hazır paletler + özel palet slotları; görünür tüm yüzeyler palette bağlanmalıdır, sabit gri renk eklenmez.
- **Navigasyon hedefi:** Ana Sayfa / Saat / Gruplar / İstatistikler / Profil. Ana Sayfa günlük kullanım alanıdır; diğer alanların verisi kendi sekmelerinde eksiksiz bulunur.
- **Release gerçeği:** Stable `v43` (`1.0.43+43`, commit `fa771ce`) ve beta `beta-v4301` yayınlandı. v43 GitHub Release Android APK yanında Windows MSIX/ZIP taşır; Windows Store paketi henüz yoktur.
- **Kalite kapıları:** Her WP DoD'siz kapanmaz; stable release kalite kapısından geçer (AGENTS.md §3). Server-authoritative XP, RLS/sosyal profil, platform sınırları → `docs/KALITE-PROGRAMI.md`.
- **Son WP numarası:** **267**. WP-265 bildirim adli raporu; WP-266 güvenilir push çekirdeği; WP-267 Android canlı sayaç programıdır. **Sıradaki boş numara WP-268.**
- **Ortam sözleşmesi:** local=Supabase CLI/Docker, beta=ayrı staging Supabase, stable=production Supabase. Ayrıntı: `docs/ORTAM-MIGRATION-YONETISIMI.md`.
- **Geliştirme ortamı:**
  - Proje: `C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room`
  - Flutter: `C:\src\flutter` · Android SDK: `C:\Android\Sdk`
  - JDK: `C:\Program Files\Android\Android Studio\jbr`
  - Web test: `flutter run -d chrome --web-port=5005 --dart-define-from-file=env.json`
  - GitHub: `manil-max/online-study-room` (public)

---

## ⚡ Aktif Çalışma Kaydı (çakışma koordinasyon yüzeyi)

> **Bu bölüm paralel ajanların TEK paylaşılan gerçeğidir.** Her ajan görevi alır almaz (kod yazmadan önce) kendi lane'ini doldurur; başlamadan önce tüm lane'leri okuyup çakışma ön-kontrolü yapar (AGENTS.md §1). Çakışma varsa başlamaz, kullanıcıyı gerekçeyle uyarır.
> Bir WP tamamlanınca (cihaz QA + kabul) kartı buradan/plandan kaldırılır, **Tamamlanan İş Paketleri**ne tek kez eklenir.

**Lane şablonu** (doldurulacak alanlar): Durum · Faz/WP · Aşama (8-merdiven) · SAHİP yollar · Ortak/riskli yüzey · Başlangıç · Son güncelleme · Not. *(Branch yok — herkes `main`'de; AGENTS.md §1.5.)*

### Gemini Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** — (main)
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-14 (Europe/Istanbul)
- **Not:** WP-83 tamamlandı, envanter ve sözlük oluşturuldu.

### Stable yol haritası (tarihsel)
> v43 2026-07-21'de yayınlandı. Yeni stable öncesi açık uygulama/ortam işleri kendi WP kartlarındaki kapılardan yürür; Windows Store public yayını WP-262'de ayrıca açık kullanıcı GO ister.

### Claude Lane
- **Durum:** [x] Boşta
- **Faz/WP:** — (WP-245–258 v43 ile yayınlandı)
- **Aşama:** —
- **SAHİP yollar:** —
- **WP-250 kök neden (settling modeli):** `stop()` oturumu DB'ye yazarken (yerel cache emit + ağ RTT'si) Flutter bir kare çizer; o karede `recorded` yeni oturumu İÇERİR ama sayaç hâlâ `isRunning` olduğu için canlı süre de eklenir → toplam **oturumun tamamı kadar** şişer (1 sa → 2 sa). Kartın "dondurma" mekanizması bu zehirli sayıyı yakalayıp gün boyu kilitliyordu (WP-239 yamasının kapatamadığı delik). **Fix:** ekran artık kendi gösterdiği sayıyı geri okumaz; notifier `isStopping` + `settlingSeconds/Baseline/Day` yayınlar, UI `max(recorded, baseline+settling) + live` hesaplar → kayıt yerleşmeden de yerleştikten de AYNI sayı. `_frozenTotal/_frozenOnDay/_lastDisplayedTotal` silindi. Ek: `stop()` kayıttan önce native ile uzlaşır (bildirimden durdurup sonra uygulamadan durdurma → hayalet süre) ve aralığı yalnız `state.startedAt` hâlâ aynı koşuysa yazar. Uzlaşma **serileştirilmiş sarmalayıcıyla** çağrılır — `_reconcileBackgroundTimerImpl`'i doğrudan çağırmak WP-241/243 yarışını geri açıyordu (eşzamanlı iki tur aynı kuyruğu iki kez kaydeder).
- **WP-251 kök neden:** bekleyen aralık kuyruğu "hepsi başarılıysa anahtarı komple sil" mantığıyla temizleniyordu → (a) tek kayıt hata alınca başarılı olanlar kuyrukta kalıp sonraki açılışta TEKRAR yazılıyordu (DB'de çift oturum, her açılışta bir kopya daha), (b) toptan silme, reconcile sürerken native'in eklediği YENİ aralığı da siliyordu (oturum kaybı). **Fix:** native her kayda UUID basar, Dart onu `study_sessions.id` olarak kullanır (repo zaten `upsert(onConflict:id)`), kuyruktan yalnız işlenen kayıtlar taze okumayla düşürülür.
- **GERÇEK kök neden (tetkik sonucu — v39 stable karşılaştırmasıyla bulundu):** **D1 (P0):** native FGS verified koşusu olmayan HER başlatmayı `liveRunToken=""` yazar (`StudyTimerService` `.orEmpty()`); Dart adoption+restore `""`ı gerçek token sanar (`clearLiveRun: fgLiveRunToken == null` → "" null değil) → `verification=verified` → `stop()` `finalizeLiveRun("")` → RPC/repo StateError → `_finalizeVerifiedRun` rethrow → **`_finish()` HİÇ çalışmaz** (sayaç durmaz, oturum yazılmaz). Özellik zaten kapalı (`_verifiedServerAvailable=false`) ama enkazı stop yolunda canlıydı; stable v39'da bu yol YOK. **D2 (P0):** `stop()` reentrant değildi — kayıt/RTT penceresinde her ek Durdur AYNI aralığı tekrar kaydediyordu (çift/çoklu sayım). **D3 (P1):** Dart µs vs native ms `startedAt` farkı her echo'da gereksiz adoption tetikleyip D1'i taşıyordu. **Fix:** WP-245 `_normalizeRunToken` (""→null, token okunan her yer) + WP-246 `_stopInFlight` kilidi + `stop()` try/finally garantili `_finish` (D4) + WP-247 adoption `startedAt` ms karşılaştırması. **Neden testler kaçırdı:** testler `timer_active_live_run_token` anahtarını hiç yazmıyordu (null→statisticsOnly yolu); cihaz native hep "" yazar (verified yolu). Yeni testler `token: ''` fikstürü kullanıyor.
- **WP-253 kararı ve gerekçesi (uygulandı):** Rozet **kaldırıldı** (plandaki Seçenek 1). Gerekçe: ateş ikonu uygulamada iki farklı metriği anlatıyordu — sayaç kartı ve grup hedefi başlığında `currentStreak(goalSeconds)` = **hedef tutturma serisi**, sıralama satırlarında ise `studyStreak` = **üst üste en az 1 sn çalışılan gün**. Grup tarafında hedef serisi hesaplanamaz (herkesin günlük hedefi bilinmez — gerekçe `study_stats.dart:245-246`), yani rozeti "düzeltmek" mümkün değildi. Kaldırınca ateş ikonu her yerde tek anlama geldi. **Plandan sapma (bilerek):** plan yalnız `class_stats_view.dart`'ı işaret ediyordu; aynı rozet `leaderboard_card.dart`'ta (ana sayfa sıralaması, hem satırda hem tooltip'te) da vardı — ikisini birden kaldırmayınca çelişki sürecekti. `leaderboard_card` başlığındaki `groupStreak` ateşi KORUNDU (o gerçekten hedef serisi).
- **WP-253 manuel ekleme koruması:** yalnız **bugün + sayaç çalışıyor** engellenir (`isManualAddBlocked`). Geçmiş günde manuel oturum `23:59:59`'da bittiği için canlı oturumla fiziksel olarak kesişemez → o akış serbest (geniş yasak meşru kullanımı kırardı). Guard butona değil `addManualSessionFlow`'a kondu; akış iki ekrandan çağrılıyor (`study_timer_card.dart` + `session_history_screen.dart`), tek butonu kapatmak deliği kapatmazdı. Karar saf fonksiyona ayrıldı → widget'sız test edilebiliyor. 4 dilde yeni l10n anahtarı (`profileSayacCalisirkenEklenemez`).
- **WP-254 kök neden:** `study_sessions.start/end` ve `chat_messages.created_at` DB'den `DateTime.parse('…Z')` ile **UTC DateTime** olarak geliyor; ekranlar bunlara doğrudan `.hour/.minute` uygulayıp basıyordu → Türkiye kalıcı UTC+3 olduğu için **tam 3 saat geri** (16:00 çalışma → 13:00 yazıyordu). İki gösterim yeri vardı: `session_history_screen.dart` `_hm` ve `class_chat_card.dart` `_formatMessageTime`. Üçüncü bir yansıma: oturum düzenleme diyaloğuna `initialDate: session.start` (UTC) veriliyordu → gece yarısına yakın oturumlarda tarih seçici bir **önceki günü** açıyordu. **Fix:** `istanbul_calendar.dart`'a `istanbulWallClock` + `istanbulHm` eklendi, üç çağrı yeri buna bağlandı. **`.toLocal()` bilerek KULLANILMADI** — ürün cihaz TZ'sinden bağımsız İstanbul takvimiyle çalışır; `.toLocal()` yurt dışındaki kullanıcıda yeni bir tutarsızlık üretirdi.
- **WP-255 (XP yeniden fiyatlandırma) — neden geriye dönük:** `xp_ledger` append-only; `xp_amount` kazanım anında DONAR. Yalnız `achievements_dict` güncellenirse mevcut kullanıcılar eski/düşük XP'de kalır, yeni kullanıcılar yükseği alır — **aynı emeğe iki fiyat**. `0065` bu yüzden 4 katmanı birden düzeltir: (1) sözlük, (2) kazanılmış `xp_ledger.xp_amount`, (3) **bekleyen** `achievement_rewards.xp_amount` (henüz "Topla" denmemişler; `claimed` satırlara dokunulmaz — onların XP'si zaten defterde ve (2) ile düzeldi, ikisini birden değiştirmek çift sayım olurdu), (4) `gamification_profiles.xp = sum(ledger)` + `_recalc_crown_rank`. Yeni fiyat SQL'e elle ikinci kez yazılmaz, sözlükten okunur. **Tüm değişiklikler artıştır → hiçbir kullanıcının XP'si düşmez, taç geri gitmez.** Emsal: `0056_six_tier_economy.sql §4`. Üçlü kilit: istemci sözlüğü ↔ `progression_economy_v2.json` ↔ migration (`progression_economy_contract_test.dart`), + pgTAP'e "defter sözlükle uyuşmalı" invaryantı eklendi (yarım uygulanmış reprice'ı yakalar).
- **WP-255 deploy kapıları (WP-255 sırasında bulundu ve düzeltildi):** `deploy-contract.json` head'leri `0065`'e yükseltildi (local + staging); **production bilerek `0064`'te bırakıldı** — `0065` production'a ancak staging QA + beta doğrulaması sonrası ayrı GO ile taşınır. ⚠️ **Ayrıca:** v42 stable yayını için açılan production `deploy_enabled`/`release_enabled` manuel override'ı hâlâ **açık** duruyordu (yayın `94947fc` ile bitmişti); bu yüzden `guard.tests.ps1` WP-249'dan beri **kırıktı** (production'ın kapalı olmasını bekliyor). Kapı kapatıldı, guard testleri yeniden yeşil (**36 passed**). Bir sonraki stable için bilinçli olarak yeniden açılmalı.
- **Yerel migration kanıtı (WP-255, 2026-07-21):** `pnpm db:baseline` eşdeğeri çalıştırıldı (Node yerelde kurulu değil → `-NodePath` ile Codex'in Node v24.14.0'ı). Boş DB'ye **0001→0065 tam zincir** uygulandı, `0065` hatasız geçti (`NOTICE: WP-255 reprice: ledger=0 pending=0 profiles=0` — boş test DB'sinde beklenen), pgTAP **82 test PASS**. Kanıt: `.artifacts/deploy-evidence/20260721T134314427Z-local-baseline`. `001_schema_contract.test.sql` migration sayacı 64→65 güncellendi. **Not:** Docker Desktop bayat soket dosyaları (`AppData/Local/Docker/run`) yüzünden açılmıyordu; klasör `run.stale-*` olarak yeniden adlandırıldı, Docker temizini oluşturdu.
- **Staging apply kanıtı (WP-255, 2026-07-21):** `remote.ps1 -Environment staging -Action apply` → `0065` uygulandı, staging head artık `0065`. **`NOTICE: WP-255 reprice: ledger=5 pending=0 profiles=1`** — 5 kazanılmış kademe yeni fiyata çekildi, bekleyen ödül yoktu, 1 profil XP+taç yeniden hesaplandı. Kanıt: `.artifacts/deploy-evidence/20260721T142751083Z-staging-apply`. **pgTAP post-check kısmen düştü:** 001/002/003 **ok** (WP-255 için eklediğim iki invaryant gerçek staging verisinde geçti), `004` **deadlock** ile yarıda kesildi — `Tests: 33 Failed: 0`, yani hiçbir assertion yanlış sonuç vermedi; canlı DB'de eşzamanlı işlem çakışması (`achievement_metric_progress` / `project_break_enemy_metric`). 0065 bu tabloya dokunmuyor. **Tekrar koşulmadı — açık madde.**
- **Production yedek durumu (WP-258):** Supabase **ücretsiz planda backup/PITR YOK** — kullanıcı ücretli plana geçmek istemedi. Bu yüzden genel bir "geri dönüş yedeği" mevcut değil. **0065 için özel durum:** migration kullanıcıya özgü hiçbir veriyi yok etmez; yalnız beş başarımın kademe XP'lerini sabit A değerlerinden sabit B değerlerine taşır. Eski değerler kullanıcı verisi değil, git'te kayıtlı **sabitlerdir** (`0056_six_tier_economy.sql`). Türetilen alanlar (`gamification_profiles.xp` = sum(ledger), `crown_rank` = xp'den) yeniden hesaplanabilir. Bu nedenle geri alım **deterministiktir** ve hazır betik yazıldı: `docs/recovery/sql/rollback_0065_reprice.sql` (migrations altında DEĞİL → otomatik uygulanmaz). **Tek nüans:** 0065 öncesi bir profilin `xp`'si defter toplamından sapmışsa geri alım sapmayı korumaz, doğru toplamı yazar (pgTAP zaten bu invaryantı şart koşuyor). **Kalan gerçek risk:** 0065 dışındaki bir sorunda (ör. ilgisiz bir veri kaybı) dönülecek yedek yok.
- **CI uzak-veritabanı yolu ilk kez kullanıldı (WP-258) — iki altyapı bulgusu:** ① **Secret'lar hiç oluşturulmamıştı.** `SUPABASE_ACCESS_TOKEN` ve `SUPABASE_DB_PASSWORD` ne repo ne de ortam seviyesinde vardı (mevcut secret'lar 2026-06-26'dan, APK imzalama + uygulama tarafı). Şimdiye kadarki tüm uzak işler yerel "owner" script'leriyle yapıldığı için CI yolu bugüne dek hiç koşmamış. İlk `production-apply` denemesi bu yüzden `CI requires SUPABASE_ACCESS_TOKEN` ile düştü — **production'a hiçbir şey yazılmadan**. Kullanıcı ikisini de `production` + `staging` ortamlarına ekledi. ② ⚠️ **`production` ortamında koruma kuralı YOK** (`gh api .../environments` → `protection_rules` boş). `tooling/README.md` "required reviewer ve deployment protection rule zorunlu" diyor ama kurulmamış; yani `production-apply` tetiklendiği an **kimse onaylamadan** yazılıyor. Beklenen "Approve and deploy" adımı hiç çıkmadı. Production'a yazmayı o an engelleyen tek şey token'ın eksikliğiydi. **Kullanıcıya soruldu, karar bekliyor — açık madde.**
- 🔴 **PRODUCTION MIGRATION ZİNCİRİ YOK (WP-258'de sahada doğrulandı):** `production-apply` denendi → `db push` **0001'den** başlamaya çalıştı ve `ERROR: column "group_id" does not exist` ile durdu. Kanıt (`02-migration-list-before.log`): production'ın "remote" sütunu **0001'den 0065'e kadar TAMAMEN BOŞ**. Sebep zaten belgeliymiş: `docs/recovery/PRODUCTION-BASELINE.md` §63 — *"`supabase_migrations.schema_migrations` relation'ı production'da yoktur"*. Zincir onarımı **WP-232** kapsamında, hâlâ açık. **Production DEĞİŞMEDİ** (migration transaction'ı geri alındı, veri kaybı yok). **Ders:** production'a yönelik herhangi bir migration işleminden önce `PRODUCTION-BASELINE.md` okunmalı — bu tur o okunmadan tetiklendi. **Çözüm:** 0065 production'a zincir üzerinden değil, elle uygulanacak: `docs/recovery/sql/apply_0065_production_manual.sql` (BEGIN/COMMIT + doğrulama sorgusu, staging'dekiyle aynı SQL). `deploy-contract` production head'i `0064`'e geri alındı.
- **v43 stable yayınlandı (2026-07-21):** `1.0.43+43`, release `v43`, commit `fa771ce`. Manifest: kanal `stable`, backend `jiphfrpzvkpzubbkhrwb`, **migrationHead `0065`** (veritabanıyla uyumlu), APK sha256 `da13ac5718108e70e414a0466e97fd4796a2ef921bf4523c1b4f49a34d74fcfa`. Windows MSIX/ZIP de aynı release'de. **Production reprice doğrulandı:** `marathon_total` kademe 1 = **1500 XP**, **42** kazanılmış defter satırı yeni fiyatta, defter toplamı 128214. **İlk tag denemesi düştü** (`Migration head mismatch: local=0065 expected=0064`) — sözleşmedeki production head'i zincir üzerinden gitmediği için 0064'e çekmiştim; 0065 elle uygulanıp doğrulandığı için doğru değer 0065, düzeltilip yeniden etiketlendi.
- **Cihaz QA — v43 (BEKLİYOR):** ① başarımlarda Maratoncu kademe 1 = 1500 XP, toplam XP yükselmiş, taç DÜŞMEMİŞ; ② çalışma kayıtları + sohbet saatleri doğru (16:00 → 16:00); ③ oturum düzenleme gece yarısına yakın kayıtta doğru günü açıyor; ④ 1 sa çalış→Durdur = 1 sa, zıplama yok; ⑤ sıralama satırlarında ateş yok, grup hedefi satırında var; ⑥ sayaç çalışırken bugüne manuel ekleme uyarı veriyor, geçmiş gün serbest.
- **Cihaz QA listesi:** ✅ **KAPANDI (2026-07-21, kullanıcı cihazda doğruladı).** ①–⑦ maddelerinin tamamı (WP-233 bildirimden başlat/durdur, WP-234 başarım ilerleme + taç, WP-239/250 çift sayım, WP-237 grafik eksenleri, WP-250 ölü zaman, WP-251 kuyruk kopyası, WP-250 pomodoro faz geçişi) ve WP-253 UX maddeleri sorunsuz. **Tek açık bulgu:** oturum/sohbet saatleri 3 saat geri gösteriliyordu → WP-254 ile düzeltildi, cihazda henüz bakılmadı.
- **Dal:** `main`
- **Başlangıç:** 2026-07-20 17:20 (Europe/Istanbul)
- **Son güncelleme:** 2026-07-21 (Europe/Istanbul) — WP-250 (settling modeli) + WP-251 (kuyruk idempotency) kod tamam; plan ve denetim: `docs/WP-250-253-SAYAC-DUZELTME-PLANI.md`.
- **WP-233/234:** Kod tamam (analyze temiz, 636 test geçti) — cihaz doğrulaması bekleniyor (stable öncesi şart).
- **Not:** beta-v4202 cihaz QA saha bulguları. Çakışma yok (diğer tüm lane'ler boşta). WP-229/230 kartları park bölümünde, diriltilmiyor — kurallara göre cihaz bug'ı için ayrı debug WP açıldı.
- **Önceki tur:** Codex'ten devralınan WP-229/230 staging kabul kapısı tamamlandı; iki kart da **Test için bekleyenler**e taşındı (cihaz QA bekliyor). Staging kabul adayı: git `1a46ace`, migration head `0064`, beta artefakt `1.0.42-beta.2+4202`. Production mutasyonu yok, `deploy_enabled: false` korunuyor. **WP-231 kullanıcı kabulü olmadan başlatılmadı.**

- **Not (Claude arşivi — önceki tur):** beta-v41 turu kapandı (WP-221/222/223/224 cihazda doğrulandı). Kalan ekonomi/kademe/alpha WP'leri sırayla yürüyor (beta-v42). Bitmiş (kod+test, cihaz QA bekliyor):
  - **WP-J** görev sırası daily-üstte + optimistic UI (`sortUserTasksByDue` daily-first, `userTasksProvider`→AsyncNotifier, ekle/tamamla/sil optimistic, hata→geri al+snackbar). Commit `54a2c84`.
  - **WP-A+B** 6 kademeli ekonomi (eşli). Renkler: 4=Elmas `#38BDF8`, 5=Zümrüt `#17E4A0`, 6=Immortal `#B02E42` (platin kalktı). Taç 6 rütbe + eşik `[0,20k,75k,200k,500k,1M]`. Client `progression_visuals`+`achievement_ledger_engine` tüm tuple/XP; `secret_1337` tamamen silindi. l10n: `coreZumrutTac`/`coreImmortal`/`coreImmortalTac` eklendi (Immortal: EN Immortal, TR Ölümsüz, DE Unsterblich, AR الخالد). Sunucu **migration `0056_six_tier_economy.sql`**: dict tuple/max_tier=6, `_recalc_crown_rank` 6 rütbe, secret_1337 FK-temiz silme + etkilenen XP geri hesap, taç XP-korumalı hizalama. **process_achievement_event DEĞİŞMEDİ** (claim=WP-C, perfect_month=WP-D, campfire=WP-E). analyze temiz, tüm testler yeşil. **Production'da uygulandığı kullanıcı tarafından bildirildi; WP-225/226 semantik audit yapacak.**
  - Yol: stale WP-222 goal-dialog testi de düzeltildi (`Clock`→`Hours`).
  - **WP-C** claim inbox birleştirme (saha #4). Migration **`0057_route_awards_to_inbox.sql`** production'da user-reported uygulanmış; semantik/ödül zinciri kabulü yoktur ve WP-229 kapsamındadır.
  - **WP-D** Kusursuz Ay **28/30 kuralı** (§3 ek kural; sabit eşik 28). `0058` production'da user-reported uygulanmış; WP-225/226 doğrulayacak.
  - **WP-E** Kamp Ateşi dinamik eşik. `0059` production'da user-reported uygulanmış; WP-225/226 doğrulayacak, eşit-kaynak onarımı WP-229'da.
  - **WP-F** alpha hesap düzeltme + üretim projeksiyonu. `0060` production'da user-reported Success döndürdü; migration kritik cron/catch-up hatalarını notice ile yutabileceği için gerçek çalışma WP-225/226'da doğrulanacak.
  - K/L kodu repoda; kabul kanıtı yoktur. Tüm production terfisi artık `docs/ORTAM-MIGRATION-YONETISIMI.md` ve WP-225–232 kapısına tabidir.

### Codex Lane
- **Durum:** [~] Aktif
- **Faz/WP:** Bildirim Güven Programı · WP-265 (adli mimari inceleme ve yol haritası)
- **Aşama:** Planlanıyor / salt-okunur inceleme
- **SAHİP yollar:** `docs/NOTIFICATION-SYSTEM-AUDIT-2026-07.md`, `progress.md`, `backlog.md`, `project.md`
- **Ortak/riskli yüzey:** Yalnız dokümantasyon; bildirim/push/timer kodu rapor tamamlanana kadar salt-okunur
- **Dal:** `main`
- **Başlangıç:** 2026-07-22 (Europe/Istanbul)
- **Son güncelleme:** 2026-07-22 (Europe/Istanbul)
- **Not:** Kullanıcı talimatıyla önce geçmiş+mevcut kod+resmî platform kaynakları tam incelenecek; rapor/WP planı commit edilmeden uygulama koduna dokunulmayacak.

### Codex-2 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** — (`main`)
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-20 14:00 (Europe/Istanbul)
- **Not:** WP-230 kod ve otomatik doğrulama tamamlandı; cihaz/staging kabulü park bölümünde.

### Grok Lane
- **Durum:** [x] Boşta
- **Faz/WP:** — (bu oturum: 32-sütun grid + core test kapsamı + worker/planner skill güncellemesi)
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** — (main)
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-18 (Europe/Istanbul)
- **Not:** 1.0.34+34 + notes + test listesi. 🔴 timer/widget/FGS/XP/dashboard motor yok. Push yok.


---

## Kalite Programı — Faz/Program Sırası

> Kaynak: `docs/KALITE-PROGRAMI.md`. Bunlar program dilimleridir; planner tetiklenince WP'lere bölünür. Aynı anda en fazla **iki çalışma hattı**; Saat/Tema/Başarım aynı anda AÇILMAZ.

| Sıra | Program/Faz | Kapsam | Durum | Not |
|---|---|---|---|---|
| 1 | **Faz 0A** | Tek kaynak & tamamlanma denetimi | Kapandı (ürün) | WP-37/38 arşiv |
| 2 | **Faz 0B** | Test & gözlemlenebilirlik (integration + Sentry) | Kapandı (ürün) | WP-46/47 arşiv; sorun→debug |
| 3 | **V8-A** | Sayaç–bildirim–widget tek doğruluk | Tamamlandı | WP-40–42/51 |
| 4 | **V8-B** | Genel senkronizasyon | Tamamlandı | WP-43 |
| 5 | **V8-C** | IA / kamp ateşi polish | Kapandı (ürün) | WP-44/45; sorun→debug |
| 6 | **V8 beta → soak → stable** | Kalite kapısı | Kapandı (ürün) | v8 yayımlandı; soak ürün kararıyla atlandı; WP-48/49/50 açık iş değil |
| 7 | **Saat programı** | Alarm/timer/StandBy/widget | Tamamlandı (ürün) | WP-58/59/60; sorun→debug |
| 8 | **Tema Stüdyosu** | Token + atmosfer aileleri | Tamamlandı | WP-54/55 + 15 aile polish |
| 9 | **Başarım & Sosyal Profil 3.0** | Ledger + taç her yerde | Tamamlandı | 0028 = **stable tag öncesi** |
| 10 | **Windows masaüstü** | Shell → IA → MSIX | Tamamlandı (ürün 2026-07-14) | WP-27/52/53/28/70/71 — cihaz smoke sorun→debug |
| 11 | **Proje Kurtarma** | Ortam izolasyonu + migration güveni + süre/XP/istatistik onarımı | Açık — en yüksek öncelik | WP-225–232 · production freeze |

## WP Durum Dizini ve Açık Planlar

> Bu tablo yalnız **aktif planlanmış** WP'leri gösterir. Tamamlanmış/test edilmiş tarihsel WP kartları (WP-23…207) arşivde: [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md) + git geçmişi. Yeni kod işi olarak yalnız `[ ] Bekliyor` satırları claim edilir.

| WP | Durum | Kısa kapsam | Bağımlılık |
|---|---|---|---|
| WP-227 | [x] Cihaz QA GEÇTİ | Beta/stable flavor + staging/production backend izolasyonu + fail-closed | ← WP-226 |
| WP-228 | [x] Cihaz QA GEÇTİ | Local/staging otomasyonu + production manual approval gate | ← WP-227 · apply kanıtı WP-229 kabul head'i sonrası |
| WP-229 | [x] Cihaz QA GEÇTİ | Eşit süre kaynakları ve reward/projection zinciri için güvenli ileri migration | ← WP-226, WP-227 · staging head `0064`, 80/80 PASS |
| WP-230 | [x] Cihaz QA GEÇTİ | 6 kademe/20k ekonomi + XP bar/metin + sürüm manifesti istemci onarımı | ← WP-227 · beta `1.0.42-beta.2+4202` @ `1a46ace` |
| WP-233 | [x] Cihaz QA GEÇTİ | 🔴 P1: bildirimden başlatılan sayaç uygulama içinden durdurulamıyor | beta-v4202 saha bulgusu · `stop()` native SSOT ile uzlaşıyor · regresyon testi |
| WP-234 | [x] Cihaz QA GEÇTİ | Biriken-olmayan başarımlarda yanıltıcı ilerleme + taç kademe görünürlüğü | beta-v4202 saha bulgusu · kişisel rekor çubuğu kalktı + taç kademe sayfası |
| WP-231 | [ ] Bekliyor | İstatistik dönem semantiği + toplam/realtime refresh + grup tutarlılığı (kapsam daraldı) | ← WP-229, WP-230 · 2 madde iptal, 1 madde WP-239'a |
| WP-232 | [ ] Bekliyor | Staging QA/soak + backup/dry-run + kontrollü production recovery release | ← WP-225–231 |
| WP-235 | [x] Cihaz QA gerekmez | 2 kırık achievement_lifecycle testi — Riverpod 3 auto-dispose + WP-223 invalidate guard | ✅ 639 test yeşil, artık kırık test yok |
| WP-236 | [ ] Planlandı (Faz B) | Leaderboard History: dönem-bazlı sıralama yarışı (today=14g, week=8h) + canlı birinci + alpha/leader wolf | stable sonrası |
| WP-237 | [x] Cihaz QA GEÇTİ | Grafik ekseni cilası: x her gün etiketi + eksik Y ekseni ölçekleri | ✅ chart_axis util + 3 grafik; 645 test yeşil |
| WP-238 | [ ] Planlandı (Faz B) | Home "Eğilim" dönem seçici → tek döngü buton (7/14/30/90/180/360, tıkla-ilerle) | stable sonrası |
| WP-239 | [x] Cihaz QA GEÇTİ | Sayaç durdurma çift-sayım bug'ı (freeze yarışı) DÜZELTİLDİ; invalidation tekilleştirme → Faz B | ✅ freeze artık recorded zamanlamasından bağımsız |
| WP-240 | [x] Yayınlandı | Faz A beta yayını: `beta-v4203` = `1.0.42-beta.3+4203` (staging, prerelease) | ✅ push+tag; CI build |
| WP-241 | [x] Cihaz QA GEÇTİ | 🔴 Sayaç reconcile YARIŞI: ard arda start/stop'ta native broadcast reconcile'ları sıra-dışı çalışıp state'i bozuyor (sayaç donması/çift sayım/durmama). beta-v4203 cihaz bulgusu | WP-233'ün asıl kök nedeni buymuş |
| WP-249 | [x] Yayınlandı | v42 stable release hazırlığı (CHANGELOG + release_notes + deploy-contract) | commit `94947fc` |
| WP-250 | [x] Cihaz QA GEÇTİ | 🔴 P0: Durdurma çift-sayımı — DB yazımı (RTT) sırasında canlı süre ikinci kez sayılıyordu (1 sa → 2 sa) ve dondurma hatayı gün boyu kilitliyordu | ✅ settling modeli; freeze mekanizması tamamen kaldırıldı; 3 yeni regresyon testi (fix'siz düşüyor) |
| WP-251 | [x] Cihaz QA GEÇTİ | 🔴 P1: Native aralık kuyruğu — kısmi hatada başarılı kayıtlar tekrar yazılıyordu (DB'de çift oturum) + toptan silme reconcile sırasında eklenen aralığı kaybediyordu | ✅ native UUID + id-bazlı kısmi silme; repo zaten idempotent (`upsert onConflict:id`) |
| WP-252 | [ ] Onay bekliyor | Pomodoro arka planda ölüyor: native ExactAlarm + otomatik faz geçişi (uygulama kapalıyken mola/bitiş) | ürün onayı şart · sahiplik kuralı (3 sn pay) zorunlu · plan hazır |
| WP-253 | [x] Cihaz QA GEÇTİ | UX: sıralama satırlarındaki üye seri rozeti KALDIRILDI (ateş ikonu artık her yerde tek anlam = hedef serisi) + manuel eklemede "bugün & sayaç çalışıyor" koruması | tek WP-253 commit'i · 4 yeni test, kırmızı-yeşil ispatı yapıldı · analyze 0 issue · 661 test yeşil |
| WP-254 | [x] Kod tamam — cihaz QA bekliyor | 🔴 Saat gösterimi 3 saat geri: DB damgaları UTC parse edilip ham `.hour` ile basılıyordu (oturum geçmişi + sohbet); düzenleme diyaloğu gece yarısında yanlış günü açıyordu | ✅ `istanbulHm`/`istanbulWallClock` tek kaynak; 6 yeni test, fix'siz 5'i düşüyor; 667 test yeşil |
| WP-255 | [x] Yayınlandı | XP yeniden fiyatlandırma (marathon_total, steel_will, day_hero, fire_streak, locomotive) + **geriye dönük** düzeltme: kazanılmış defter satırları, bekleyen ödüller ve profil XP/taç yeniden hesaplanır | `0065` staging ve production'da doğrulandı; v43'te 42 defter satırı yeni fiyatla doğrulandı |
| WP-256 | [x] Yayınlandı | beta-v4301 yayın hazırlığı: `1.0.43-beta.1+4301` (CHANGELOG + release_notes + pubspec) | Staging `0065` sonrası `beta-v4301` olarak yayınlandı; ardından v43 stable çıktı |
| WP-257 | [x] Yayınlandı | beta-v4301 (`1.0.43-beta.1+4301`) — staging `0065` uygulandıktan SONRA etiketlendi; CI build 9dk43sn başarılı | staging apply: `ledger=5 pending=0 profiles=1` |
| WP-258 | [x] **YAYINLANDI** | v43 stable (`1.0.43+43`) — Android APK + Windows MSIX/ZIP; production `0065` ELLE uygulandı ve doğrulandı | release `v43` · commit `fa771ce` · manifest migrationHead=0065, backend production · APK sha256 `da13ac57…` · production: marathon kademe1=1500 XP, **42 defter satırı** yeni fiyatta |

### WP-259: Windows QA Temeli ve Yerel İki-Sürüm Provası 🧪
- **Program/Faz:** Windows Store ürünleştirme · Faz 1
- **Ajan:** Codex
- **Durum:** [~] Test için bekliyor — hızlı smoke + local başlangıç + Windows navigasyon otomatik testi geçti; temiz VM/ikinci-PC QA açık
- **Problem:** CI paket üretse de temiz Windows'ta kurulum→update→uninstall kanıtı doldurulmuş değildir; ana PC'deki test-imzalı paket test hedefi değildir.
- **Kapsam dışı:** Store hesabı, public Store submission, üretim backend/migration.
- **SAHİP dosyalar (yaz):** `scripts/windows_fast_smoke.ps1`, `docs/QA-WINDOWS.md`, `scripts/windows_smoke_screenshot.ps1`, Windows QA test/kanıt dosyaları.
- **DOKUNMA:** `app/pubspec.yaml`, `app/lib/features/updater/**`, `.github/workflows/windows-release.yml`, `supabase/**`.
- **Adımlar:** Her geliştirme turunda ≤10 sn görünür pencere + yeni screenshot kanıtı veren smoke; Windows Sandbox/temiz VM prosedürü; staging test hesabıyla iki artan QA MSIX; W-01…W-06/W-10…W-22 koşumu; redacted video/screenshot kanıtı.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Local + staging; Store/public/production deploy yok.
- **RLS/Güvenlik:** Secret/token/gerçek kullanıcı verisi kanıta girmez; QA paketi production endpoint'e bağlanmaz.
- **Edge-case'ler:** eski test paketi, yarım update, SHA uyuşmazlığı, sleep/resume, çoklu monitör, offline→online.
- **Kabul:** `N→N+1` update sonrası giriş/yerel tercih/oturum korunur; uninstall temiz; üç DPI matrisinde overflow 0; P0/P1 0.
- **Tuzaklar:** Ana PC paketini kaldırmak, ZIP'i update kanıtı saymak, production hesabıyla test.
- **Model önerisi:** 🟣 Pro.

### WP-260: Store Kimliği, Paketleme ve Kanal Ayrımı 🏪
- **Program/Faz:** Windows Store ürünleştirme · Faz 2
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-259 QA geçer; Partner Center hesabı ve `Odak Kampı` adı kullanıcı tarafından açılır/rezerve edilir.
- **Problem:** Test publisher'lı MSIX Store kimliği değildir; Store stable paketinde GitHub sideload updater erişilemez olmalıdır.
- **Kapsam dışı:** Public rollout, yeni feature, App Installer/direct-download kanalı.
- **SAHİP dosyalar (yaz):** `app/pubspec.yaml`, `app/lib/core/config/distribution_channel.dart`, `app/lib/features/updater/**`, `.github/workflows/windows-release.yml`, Store packaging/test dosyaları, `docs/WINDOWS-RELEASE-GATE.md`.
- **DOKUNMA:** Android flavor/manifestleri, `supabase/**`, feature/theme/navigation kodu.
- **Adımlar:** Store identity/publisher'ı Partner Center'dan al; Store package/CI guard'ını bağla; Store build'de GitHub API/download/install yolunu unreachable test et; provenance manifesti üret.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Local/CI validation; private/public Store submission yok.
- **RLS/Güvenlik:** Partner Center anahtarları secret store'da; PFX yok; stable Store paketi yalnız production backend tuple'ıyla derlenir.
- **Edge-case'ler:** yanlış publisher, stable↔staging veya beta↔production, Store build'de gizlenmiş ama çağrılabilir updater.
- **Kabul:** identity/publisher birebir; Store build updater network hit=0; kanal/backend fail-closed; manifest SHA+commit+head taşır.
- **Tuzaklar:** Test publisher'ını taşımak, Store/GitHub package'lerini aynı identityde karıştırmak.
- **Model önerisi:** 🔴 Opus.

### WP-261: Windows Marka, Kapak ve Store Listeleme Paketi 🎨
- **Program/Faz:** Windows Store ürünleştirme · Faz 2
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-259 QA tabanı; WP-260 ile paralel yürüyebilir.
- **Problem:** Eski ikon dışında Store kapak/hero, ekran görüntüsü, açıklama ve listing varlığı yoktur.
- **Kapsam dışı:** Uygulama feature değişikliği, tema motoru, public Store yayın.
- **SAHİP dosyalar (yaz):** `app/assets/branding/windows/**`, `app/windows/runner/resources/app_icon.ico`, yeni Store listing brief/asset dosyaları, görsel golden'lar.
- **DOKUNMA:** `app/lib/core/theme/**`, navigation, `app/pubspec.yaml`, CI/packaging.
- **Adımlar:** Görsel yön onayı; yeni icon/hero; 4–6 anonim Windows screenshot; TR/EN listing metni; 100–200% DPI görsel QA.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Yerel render/golden; Store public yok.
- **RLS/Güvenlik:** Screenshot'ta e-posta/token/özel grup/gerçek kullanıcı verisi 0.
- **Edge-case'ler:** Start/Settings/Store ikon tutarsızlığı, dar ekran taşması, yalnız 1× DPI'da iyi görünen logo.
- **Kabul:** Required asset set tamam; 4–6 screenshot anonim ve overflow 0; ürün sahibi tasarım kabulü.
- **Tuzaklar:** Rastgele görseli application icon yapmak veya eski test build görselini Store materyali saymak.
- **Model önerisi:** 🟣 Pro + görsel üretim.

### WP-262: Private Audience Pilot ve Public Store GO Kapısı 🚦
- **Program/Faz:** Windows Store ürünleştirme · Faz 3
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-259/260/261 ürün kabulü.
- **Problem:** Public yayından önce gerçek Store imza/kurulum/update davranışı yalnız seçili hesaplarda kanıtlanmalıdır.
- **Kapsam dışı:** Yeni feature, production DB/migration, açık kullanıcı GO olmadan public listing/rollout.
- **SAHİP dosyalar (yaz):** `docs/QA-WINDOWS.md`, Store submission/provenance kanıtları, `docs/WINDOWS-RELEASE-GATE.md`.
- **DOKUNMA:** Uygulama feature kodu, `supabase/**`, WP-260 kabulünden sonra sabit Store kimliği.
- **Adımlar:** Private Audience grubu; staging test hesaplarıyla Store install/update/auto-update/cold-start QA; 72 saat pilot; public GO paketi.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Store Private Audience; public Store yalnız somut kullanıcı GO sonrası.
- **RLS/Güvenlik:** Sadece test hesapları/staging; secret/production verisi yok.
- **Edge-case'ler:** unlisted ile private karışması, flight rollback, Store cache, eski test paketi.
- **Kabul:** Seçili hesap dışı listing/indirme 0; iki Store build arasında update/veri korunumu kanıtlı; 72 saatte P0/P1=0.
- **Tuzaklar:** Private pilotu public GO saymak veya production hesabıyla yürütmek.
- **Model önerisi:** 🔴 Opus.

### WP-263: Profil Özetinde Gizli Rozet Rengini Koru 🟣
- **Program/Faz:** Debug · Profil vitrin güvenilirliği
- **Ajan:** Codex
- **Durum:** [x] Otomatik test geçti · cihazda doğrulanmalı
- **Problem:** Profil kartındaki seçili rozetler, gizli ve açılmış rozet için kanonik mor rengi yerine yalnız kademe rengini kullanır; birinci kademe gizli rozet turuncu görünür.
- **Kapsam:** Profil özeti `badgeVisualColor` ile tam başarımlar ekranının gizli-rozet kuralını kullanır; widget testi bu ayrımı korur.
- **Kapsam dışı:** Başarım verisi, seçili rozet sırası, tema altyapısı, migration ve remote ortamlar.
- **SAHİP yollar:** `app/lib/features/profile/widgets/gamification_card.dart`, `app/test/features/profile/gamification_card_declutter_test.dart`, `progress.md`
- **Veri/Migration:** Yok.
- **Kabul:** Seçili, açılmış gizli rozet mor; normal seçili rozet kademe rengiyle kalır; hedef widget testi ve `flutter analyze` geçer.
- **Model önerisi:** 🟢 fast.

### WP-264: Tools Saat/Dünya/Kronometre Sadeleştirmesi 🧹
- **Program/Faz:** Ürün sadeleştirme · Tools IA
- **Ajan:** Codex
- **Durum:** [x] Otomatik test geçti · cihazda doğrulanmalı
- **Problem:** Kullanılmayan Saat, Dünya ve Kronometre pencereleri Tools şeridini kalabalıklaştırıyor.
- **Kapsam:** Üç giriş ve karşılık gelen Tools gövdeleri kaldırılır; Tools Alarm ile açılır ve Timer/Görevler korunur.
- **Kapsam dışı:** Yatay StandBy; sayaç, alarm, timer ve Android bildirim motorları; World/Stopwatch kaynak dosyalarının fiziksel silinmesi.
- **SAHİP dosyalar (yaz):** `app/lib/features/clock/clock_screen.dart`, `app/lib/core/navigation/home_shell.dart` (yalnız stale yorum), `app/test/features/clock_screen_test.dart`, `app/test/features/tap_to_top_contract_test.dart`, `progress.md`
- **DOKUNMA:** `app/lib/core/notifications/**`, `app/android/**`, `app/lib/data/providers/study_providers.dart`, `app/lib/features/clock/stopwatch_screen.dart`, `app/lib/features/clock/world_clock_screen.dart`
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Yalnız local; remote/production işlemi yok.
- **RLS/Güvenlik:** Etki yok.
- **Kabul:** Tools şeridinde yalnız Alarm/Timer/Görevler bulunur; dikey açılış Alarm'dır; mobil yatay görünüm StandBy kalır; analyze ve tam test paketi geçer.
- **Tuzaklar:** Kronometre UI girişini kaldırırken çalışma sayacı/FGS bildirim servisini yanlışlıkla silmek.
- **Model önerisi:** 🟢 fast.

### WP-265: Bildirim Sistemi Adli İnceleme ve Kabul Sözleşmesi 🔬
- **Program/Faz:** Bildirim Güven Programı · Faz 0
- **Ajan:** Codex
- **Durum:** [x] Rapor/plan tamamlandı
- **Problem:** Dürtme/güncelleme/duyuru teslimi ile Samsung dinamik panel denemeleri parça parça değiştirilmiş; gerçek push, local notification ve foreground-service yüzeyleri aynı kavram gibi ele alınmıştır.
- **Kapsam:** Mevcut kod, migration, geçmiş commit/rapor ve resmî Android/Samsung/Firebase/Supabase kaynaklarından kanıtlı durum analizi; kök neden, hedef mimari, test/rollback/deploy kapıları ve WP planı.
- **Kapsam dışı:** Uygulama kodu, Firebase/Supabase kurulumu, remote migration/Edge deploy, production mutation.
- **SAHİP dosyalar (yaz):** `docs/NOTIFICATION-SYSTEM-AUDIT-2026-07.md`, `docs/KALITE-PROGRAMI.md`, `progress.md`, `backlog.md`, `project.md`
- **Kabul:** Push taşıma eksikliği ve custom `RemoteViews`/Live Update uyumsuzluğu kod+resmî kaynakla kanıtlanır; 10 sn self-test, cihaz matrisi ve somut aktivasyon kapıları tanımlanır.
- **Rapor:** [`docs/NOTIFICATION-SYSTEM-AUDIT-2026-07.md`](docs/NOTIFICATION-SYSTEM-AUDIT-2026-07.md)
- **Model önerisi:** 🔴 Opus / frontier-high.

### WP-266: Güvenilir Push Çekirdeği ve 10 Saniyelik Self-Test 📲
- **Program/Faz:** Bildirim Güven Programı · Faz 1
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-265
- **Problem:** Projede FCM SDK/token registry/server sender/outbox/delivery gözlemi yok; uygulama kapalıyken dürtme, duyuru ve güncelleme ulaşamaz.
- **Kapsam:** Android FCM yaşam döngüsü; güvenli cihaz kaydı; transactional outbox + per-device delivery; dürtme enqueue; Supabase Edge FCM HTTP v1 dispatcher; retry/invalid-token cleanup; preference sync; Bildirim Sağlığı ve local/remote self-test; in-memory/fake karşılıkları.
- **Kapsam dışı:** iOS/APNs, web push, pazarlama segmentasyonu, production deploy/release, Samsung canlı sayaç görünümü.
- **SAHİP dosyalar (yaz):** `app/pubspec.*`, `app/lib/core/notifications/**`, yeni push config/repository/provider/model dosyaları ve in-memory/Supabase aynaları, bildirim merkezi/l10n/testler, `supabase/migrations/0066_*`, `supabase/functions/dispatch-push/**`, `supabase/tests/**`, ilgili env/deploy sözleşmeleri, rapor ve `progress.md`.
- **DOKUNMA:** Native alarm/timer FGS sınıfları, achievement/XP zinciri, remote'a uygulanmış migration'lar, production.
- **Veri/Migration etkisi:** Yeni ileri migration; push tokenları client direct-DML'e kapalı, service-only teslim tablosu; domain `nudges` satırları korunur.
- **Ortam/Deploy:** Önce local/fake; staging Firebase/Supabase aktivasyonu ayrı kapı; production yalnız beta soak + açık kullanıcı GO.
- **Kabul:** Foreground/background/terminated dürtme tek teslim; duplicate 0; remote self-test p95 ≤10 sn; logout/token refresh/iki cihaz/RLS/retry senaryoları kanıtlı; config yokken app fail-closed ve regresyonsuz.
- **Tuzaklar:** Yerel test bildirimini push kanıtı saymak; service account'ı istemciye koymak; notification+local presentation duplicate'i; beta/stable token karışması.
- **Model önerisi:** 🔴 Opus / frontier-high.

### WP-267: Android Standard/Promoted Canlı Sayaç ⏱️
- **Program/Faz:** Bildirim Güven Programı · Faz 2
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-265; seri sıra WP-266 sonrası
- **Problem:** Varsayılan custom `RemoteViews`, boş content title ve kapalı native chronometer Android Live Update şartlarını ihlal ediyor; Samsung Now Bar yalnız OEM best-effort olmasına rağmen ürün/teknik sınır ayrışmamış.
- **Kapsam:** AndroidX promoted ongoing API; manifest izni; standard ongoing chronometer/title/actions; monochrome small icon; promotable/can-post diagnostic; custom panelden kontrollü geri dönüş; source-contract/native compile/cihaz matrisi.
- **Kapsam dışı:** Timer state/FGS lifecycle/session/XP yeniden mimarisi, Samsung private/undocumented API, piksel-aynı OEM görünüm garantisi.
- **SAHİP dosyalar (yaz):** `app/android/app/build.gradle.kts`, Android manifest, `StudyTimerService.kt`, timer notification kaynakları/ikonları/native testler, diagnostic bridge ve ilgili Flutter health UI/testleri, rapor ve `progress.md`.
- **DOKUNMA:** `TimerStateStore` sözleşmesi, `START_NOT_STICKY`, FGS type matrisi, pending interval idempotency, Supabase/achievement zinciri.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Local compile/build; Samsung/Pixel beta cihaz QA; public/stable release yok.
- **Kabul:** Running notification custom content view içermez; promotable karakteristikleri sağlar; eski Android'de standard fallback ve app-closed action çalışır; 8 saat sapma ≤±1 sn; API 29–33/34+ FGS crash 0.
- **Tuzaklar:** Now Bar'ı garanti etmek; görünüm değişikliğiyle FGS lifecycle'a dokunmak; yalnız Flutter testini cihaz kanıtı saymak.
- **Model önerisi:** 🔴 Opus / frontier-high.

### WP-229: Eşit Süre Kaynakları ve Ödül Zinciri Onarımı ⚖️
- **Program/Faz:** Kurtarma Faz 4A
- **Ajan:** Codex
- **Durum:** [x] Cihaz QA geçti
- **Problem:** `0051–0062` verified-only projeksiyonları manuel/sayaç/native kaynakları ayırıyor; mevcut `0063` veri yeniden hesaplama ve ödül üretiminde güvenli kabul edilemiyor.
- **Kapsam dışı:** Taç görseli/istatistik UI, production deploy, history rewrite.
- **SAHİP dosyalar (yaz):** Audit `0063`ün hiçbir remote'a uygulanmadığını kanıtlarsa yeniden tasarlanan `0063_*`; aksi halde yeni ileri migration (numara audit sonucu), `supabase/tests/**`, başarım/study repository server sözleşmeleri ve in_memory aynaları, `docs/recovery/EQUAL-SOURCES-RECONCILIATION.md`, `progress.md`.
- **DOKUNMA:** Remote'a uygulanmış `0051–0062`; production; bağımsız UI/theme/navigation.
- **Adımlar:**
  - [x] `0063`ü production adayı olmaktan çıkar; remote geçmişini kanıtla. Hiç uygulanmadıysa dosyayı güvenli/idempotent yeniden tasarla, uygulandıysa immutable bırakıp ileri migration yaz.
  - [x] Tüm geçerli `study_sessions` kaynaklarını kişisel/grup/XP/başarıma eşitle.
  - [x] Alfa/Kamp/Lokomotif/Lider Kurt/Mola Düşmanı progress→candidate→pending→claim zincirini tamamla.
  - [x] Recompute'i shadow/audit→diff→bounded apply yap; session/ledger/claimed reward silme.
  - [x] Cron/finalizer'ı Europe/Istanbul gün/hafta sınırlarında gerçek PostgreSQL fixture'larıyla test et.
- **Veri/Migration etkisi:** Yeni ileri migration; append-only ledger ve session korunur. Geri alma fonksiyon/trigger yönlendirmesini önceki sürüme alır, kazanılmış ledger/claim silmez.
- **Ortam/Deploy:** Local→staging; production WP-232'ye kadar yok.
- **RLS/Güvenlik:** XP server-authoritative; kullanıcı yalnız kendi session DML; private progress self-only; idempotent unique keys.
- **Edge-case'ler:** Gece yarısı, üyelik penceresi, eşit lider, çoklu grup, duplicate/retry, offline outbox, uzun geçmiş ve timeout.
- **Kabul:** Aynı süreyi beş giriş yoluyla ekleyen fixture aynı tüm metrik/XP sonucunu verir; session/duration/ledger/claimed reward kaybı 0; ikinci projection/claim çift XP üretmez; günlük ve haftalık reward zinciri uçtan uca yeşil.
- **Tuzaklar:** Başarı dönmüş migration içinde veri silmek; dormant candidate bırakmak; kritik exception'ı notice ile yutmak.
- **Model önerisi:** 🔴 Opus / frontier-max

### WP-230: Ekonomi, Taç ve Sürüm Gerçeği Onarımı 👑
- **Program/Faz:** Kurtarma Faz 4B
- **Ajan:** Codex-2
- **Durum:** [x] Cihaz QA geçti
- **Problem:** Eski beta istemci 5 kademe/25k, DB 6 kademe/20k kullanıyor; XP etiketi ile bar farklı matematik gösteriyor; aynı `1.0.41+41` farklı kodları temsil ediyor.
- **Kapsam dışı:** Yeni ekonomi tasarlamak, mevcut XP'yi yeniden fiyatlamak, production deploy.
- **SAHİP dosyalar (yaz):** achievement/economy client katalogları, profile/gamification card-showcase, ilgili l10n ARB+generated, `app/pubspec.yaml`, release manifest/notları, contract fixture/testleri, `progress.md`.
- **DOKUNMA:** Production DB, uygulanmış migration'lar, stats/repository akışı.
- **Adımlar:**
  - [x] Onaylı bütün threshold/XP tuple'larını tek fixture üzerinden client/server testlerine bağla.
  - [x] Taçları `[0,20k,75k,200k,500k,1M]` ve 6 görsel kademeye hizala.
  - [x] Bar etiketi ve doluluk aynı paydayı/semantiği göstersin; erişilebilir açıklama ekle.
  - [x] Verified-only metin/ikon/not kalıntılarını ürün sözleşmesine göre temizle.
  - [x] Beta/stable benzersiz version/build + commit/backend/migration manifesti üret.
- **Veri/Migration etkisi:** Yok; DB tuple doğrulaması salt-okunur/staging contract.
- **Ortam/Deploy:** Beta staging build; production yok.
- **RLS/Güvenlik:** XP istemciden yazılmaz; UI yalnız server profile/ledger gerçeğini gösterir.
- **Edge-case'ler:** Eski crown rank id normalize, max rank, threshold sınırları, claim sonrası refresh, eski client uyumluluğu.
- **Kabul:** 11 kademeli başarım + secret XP + crown fixture client/server birebir; 12.500 XP yeni eşikte %62,5 gösterir ve etiketle tutarlıdır; aynı build numarası iki artefakta çıkamaz; verified-only kullanıcı metni 0.
- **Tuzaklar:** Barı değiştirip etiketi bırakmak; local katalogla DB dictionary'yi ayrı güncellemek.
- **Model önerisi:** 🟣 Pro / frontier-high

### WP-231: İstatistik Dönemi ve Realtime Güveni 📊
- **Program/Faz:** Kurtarma Faz 5
- **Ajan:** Codex
- **Durum:** [~] Otomatik test geçti — cihazda doğrulanmalı
- **Problem:** “Hafta” son 7 gün sanılıyor; Pazartesi reseti veri kaybı gibi görünüyor. Oturum bitiminden sonra kişisel/grup toplam güncellemesi ayrıca cihazda güvenilir değil.
- **Kapsam dışı:** Ham geçmişi değiştirmek, achievement economy, production migration.
- **SAHİP dosyalar (yaz):** `app/lib/core/stats/**`, stats period/provider/view dosyaları, relevant study repository/cache refresh yolu, ilgili l10n/testler, `docs/recovery/STATS-CONTRACT.md`, `progress.md`.
- **DOKUNMA:** Achievement UI, migration zinciri (gerekirse ayrı bağımlı WP aç), release config.
- **Adımlar:**
  - [~] ~~“Bu hafta (Pzt–bugün)” ile “Son 7 Gün”ü ayrı dönem yap~~ → **KULLANICI İPTAL (2026-07-20)**: mevcut week UI'ı korunacak; leader wolf ile hizalı (Pazar 23:59 sonrası o haftanın birincisi). Ellenmeyecek.
  - [~] ~~Günlük ortalama paydasını görünür dönem sözleşmesiyle test et~~ → **KULLANICI İPTAL (2026-07-20)**.
  - [→] Session stop/manual add sonrası cache+remote+summary invalidation yolunu tekilleştir → **WP-239'a TAŞINDI** (sayaç çift-sayım bug'ıyla aynı kök).
  - [x] Pending/offline/realtime reconnect ve iki cihaz yenilenmesini test et.
  - [x] 20 Temmuz Pazartesi fixture'ında bugün/hafta/son7/ay sonuçlarını golden/widget testle.
- **Veri/Migration etkisi:** Beklenmiyor; yalnız okuma/projeksiyon. Şema ihtiyacı çıkarsa durup ayrı WP planlanır.
- **Ortam/Deploy:** Local→staging beta.
- **RLS/Güvenlik:** Grup stats yalnız ortak aktif üyelik penceresi; cross-user raw session açılmaz.
- **Edge-case'ler:** Pazartesi, ay/yıl başlangıcı, İstanbul DST geçmişi, cihaz TZ, 90 günlük hot window, offline cache stale snapshot.
- **Kabul:** Oturum bitiminden sonra görünür kişisel toplam ≤1 sn, grup toplam ≤5 sn; 20 Temmuz fixture'ında bugün=34dk, takvim haftası=34dk, son7 dünkü 10 saati içerir, ay=43saat fixture sonucu; üyeler kaybolmuş gibi görünmez.
- **Tuzaklar:** Veri kaybı sanıp session backfill yapmak; kişisel/grup farklı tarih yardımcıları.
- **Model önerisi:** 🟣 Pro / frontier-high

### WP-232: Staging Kanıtı ve Kontrollü Production Recovery 🚦
- **Program/Faz:** Kurtarma Faz 6
- **Ajan:** —
- **Durum:** [ ] Bekliyor
- **Problem:** Kod/test tamamlanması production güveni değildir; bütün zincir tek release adayı üzerinde kanıtlanmalı.
- **Kapsam dışı:** Yeni özellik, kabul edilmemiş ekonomi/UX değişikliği, onaysız production deploy.
- **SAHİP dosyalar (yaz):** `docs/recovery/RELEASE-GATE.md`, QA kanıt manifestleri, release notes/manifest, `progress.md`; production komutları yalnız GO sonrası.
- **DOKUNMA:** Kabul adayı dışındaki feature kodu; uygulanan migration dosyaları.
- **Adımlar:**
  - [ ] Staging'i temiz kanonik zincir+seed ile kur; migration/RLS/invariant/reconciliation testlerini çalıştır.
  - [ ] Samsung gerçek cihazda manual/kronometre/countdown/Pomodoro/native, kill/reboot/offline/iki cihaz ve claim senaryolarını kanıtla.
  - [ ] Beta artefaktını ≥3 gün soak et; P0/P1=0, gözlemlenen veri drift=0 kapısı uygula.
  - [ ] Production backup + exact dry-run + etki/rollback/post-check paketini kullanıcıya sun; somut GO bekle.
  - [ ] GO sonrası migration→stable artefakt terfisi→post-check→24/72 saat gözlem; sorun halinde belgeli recovery.
- **Veri/Migration etkisi:** Yalnız kabul edilmiş ileri migration'lar; production adımı ayrı onaylı ve denetlenebilir.
- **Ortam/Deploy:** Staging zorunlu; production son kapı.
- **RLS/Güvenlik:** Abuse suite yeşil; secrets redacted; release artefaktı doğru backend/channel imzalı.
- **Edge-case'ler:** Staging pause, kısmi deploy, eski beta client, rollback sonrası yeni ledger, ağ kesintisi, cron gecikmesi.
- **Kabul:** Tüm otomatik test+local SQL+staging RLS yeşil; gerçek cihaz matrisi kanıtlı; ≥3 gün soak; kullanıcı GO; production sonrası session/XP/reward invariant farkı 0 ve P0/P1=0.
- **Tuzaklar:** Beta kodunu yeniden derleyip farklı commit'i stable yapmak; migration ile app'i yanlış sırada çıkarmak.
- **Model önerisi:** 🔴 Opus / frontier-high

### WP-235: İki Kırık achievement_lifecycle Testi 🧪
- **Program/Faz:** Saha turu 2 (beta-v4202)
- **Durum:** [ ] Planlandı
- **Problem (TEŞHİS TAMAM):** `app/test/data/achievement_lifecycle_test.dart` iki testi `main`'de kırık — WP-233/234 ile ilgisiz, temiz HEAD'de de kırık.
  - **Test 1 "runAchievementSessionCompletedSync process çağırır" → 30 sn timeout (takılıyor):** Kök neden **Riverpod 3 auto-dispose**. `runAchievementSessionCompletedSync` içinde `gamificationProfileProvider(userId).future` bekleniyor; dinleyici tutulmadığı için StreamProvider future'ı asla tamamlanmıyor. Probe testiyle kanıtlandı: `container.listen(gamificationProfileProvider(id), …)` eklenince tüm zincir çözülüyor. → **Test harness hatası** (üretim kodu doğru; app'te UI dinliyor).
  - **Test 2 "lifecycle … debounce sonrası process tetikler" → "Cannot use Ref … after disposed":** Kök neden **WP-223 (beta-v41, commit 1831358)**. `AchievementProgressLifecycle._schedule()` debounce callback'i `async` yapıldı ve `await runAchievementSessionCompletedSync` **sonrasına** `_ref.invalidate(pendingAchievementRewardSummaryProvider/…)` eklendi. 800ms debounce ateşlerken provider/container dispose olmuşsa `_ref` kullanımı patlar. → **Kısmen gerçek üretim bug'ı**: `_schedule` guard'sız; gerçek app'te kullanıcı 800ms içinde sekme değiştirir/çıkış yaparsa aynı hata sessizce oluşur (zone error).
- **SAHİP dosyalar:** `app/lib/data/providers/gamification_providers.dart` (guard), `app/test/data/achievement_lifecycle_test.dart` (listener), `progress.md`.
- **Adımlar:**
  - [ ] `AchievementProgressLifecycle`'a `_disposed`/mounted bayrağı; `_schedule` callback'inde her async gap sonrası guard (`if (_disposed) return;`) — invalidate'ten önce.
  - [ ] Test 2'ye lifecycle debounce'u bitene kadar container'ı canlı tutan bekleme; Test 1'e `gamificationProfileProvider` listener'ı (auto-dispose tuzağı).
  - [ ] Her iki test fix'siz kırık → fix'le yeşil olduğunu doğrula.
- **Kabul:** `flutter test test/data/achievement_lifecycle_test.dart` yeşil; tam suite yeşil (halihazırda 636 geçiyor + bu 2).
- **Model önerisi:** 🟣 Pro

### WP-236: Leaderboard History — Dönem-Bazlı Sıralama Yarışı 🏆
- **Program/Faz:** Saha turu 2 (beta-v4202)
- **Durum:** [ ] Planlandı
- **Problem:** İstatistikler/Gruplar → "Leaderboard History" grafiği (`LeaderboardRankChart`) **kümülatif** toplam sıralaması gösteriyor; bu yüzden `today` ve `week` seçenekleri **aynı** görünüyor (ikisi de `chartDays=7`, `stats_period.dart:74-75`). Kullanıcı her dönemin **kendi içinde** yarışını istiyor:
  - `today` → her düğüm bir GÜN; o günün kendi sıralaması (ör. 13 → A B C, 14 → B A C).
  - `week` → her düğüm bir HAFTA; o haftanın sıralaması (1. hafta → A B, 2. hafta → B A).
  - Bu grafikten **alpha wolf** (günlük birinci) + **leader wolf** (haftalık birinci = Pazar 23:59 kesinleşen) takip edilecek.
  - Canlı: içinde bulunulan gün/haftanın **anlık** birincisi grafikte belirtilsin; kesinleşme gün sonu 23:59 (gün) / Pazar 23:59 (hafta) — o ana kadar canlı değişebilir.
- **Pencere (kullanıcı kararı 2026-07-20):** today → **son 14 gün**; week → **son 8 hafta** (Pzt–Paz bucket'lar).
- **SAHİP dosyalar:** `app/lib/features/stats/widgets/leaderboard_rank_chart.dart`, `class_stats_view.dart` (trendDays→dönem tipi geçişi), `app/lib/core/stats/**` (haftalık grupla­ma yardımcıları, Europe/Istanbul + Pzt-Paz), ilgili l10n/testler.
- **DOKUNMA:** week UI/period semantiği (WP-231 kapsamı, kullanıcı korudu), migration, achievement economy.
- **Adımlar:**
  - [ ] `LeaderboardRankChart`'a `bucket` modu (day|week); kümülatif yerine bucket-içi toplam → bucket sıralaması. Pencere: 14 gün / 8 hafta.
  - [ ] Haftalık bucket = Pzt–Paz, Europe/Istanbul; leader wolf ile aynı sınır ([[group-stats-rpc-aggregation]]).
  - [ ] Aktif (bitmemiş) bucket için "canlı birinci" işareti; kapanmış bucket sabit.
  - [ ] X ekseni etiketi: gün no (today) / hafta etiketi (week). (WP-237 ile hizalı.)
  - [ ] Golden/widget test: 3 üye, gün-gün ve hafta-hafta sıralama değişimi.
- **Kabul:** today ve week görünür şekilde farklı; her bucket bağımsız sıralama; aktif bucket canlı birinci; alpha/leader wolf grafikte okunur.
- **Model önerisi:** 🔴 Opus / frontier-high

### WP-237: Grafik Ekseni Cilası 📐
- **Program/Faz:** Saha turu 2 (beta-v4202)
- **Durum:** [ ] Planlandı
- **Problem:** Birden çok grafikte (a) X ekseni yer olmasına rağmen 2–3 gün atlıyor, (b) Y ekseni ölçeği hiç yok.
  - `leaderboard_rank_chart.dart`: X `step=(window.length/4).ceil()` → 7 günde her 2. gün.
  - `daily_line_chart.dart`: X `days.length>10 && i%3!=0` atlar; **Y ekseni kapalı** (`leftTitles showTitles:false`) — grup trend + home "Eğilim" bundan etkilenir.
  - `daily_bar_chart.dart`: X `dense && i%3!=0`; **Y ekseni kapalı** (`leftTitles:false`) — home grup trend kartı.
- **SAHİP dosyalar:** `app/lib/features/stats/widgets/{leaderboard_rank_chart,daily_line_chart,daily_bar_chart}.dart` + taramada çıkan diğer grafik widget'ları, ilgili testler.
- **Adımlar:**
  - [ ] X etiket adımı: genişliğe göre uyarlanır; yer varken **her gün**; dar seride minimum çakışmasız adım (etiket genişliği hesabıyla, sabit %25 değil).
  - [ ] Y ekseni: eksik olan çizgi/çubuk grafiklerine sade dakika/saat ölçeği + hafif yatay grid; tema-güvenli renk.
  - [ ] Tüm grafik widget'larını tara (stats + home + widget); eksik Y / seyrek X listesini kapat.
  - [ ] Dar boyutlarda taşma/örtüşme yok; widget testleri.
- **Kabul:** Yer olan her seride her günün numarası; ölçeksiz grafik kalmaz; overflow testi temiz.
- **Model önerisi:** 🟣 Pro

### WP-238: "Eğilim" Dönem Seçici → Tek Döngü Buton 🔘
- **Program/Faz:** Saha turu 2 (beta-v4202)
- **Durum:** [ ] Planlandı
- **Problem:** Home "Eğilim" kartı (`line_chart_card.dart`) 14/30/90 `SegmentedButton` kullanıyor; yer sınırlı ve yalnız 3 seçenek. Kullanıcı: tek buton, her tıkta sıradaki değere döngüsel geçiş; seçenekler **7 / 14 / 30 / 90 / 180 / 360** (bu sırada).
- **SAHİP dosyalar:** `app/lib/features/home/widgets/line_chart_card.dart`, gerekirse ortak küçük "cycle chip" widget'ı, l10n (gün etiketleri), testler.
- **Adımlar:**
  - [ ] Segment/dropdown yerine tek basılabilir çip; state 6 değer arasında döngü; etiket seçili günü gösterir (ör. "30 gün").
  - [ ] `lastNDays` 180/360 için performans/doğruluk kontrolü (hot window 90 gün — [[group-stats-rpc-aggregation]] sınırı; 180/360 için veri kaynağı teyidi).
  - [ ] Compact + geniş yerleşimde tek kontrol; a11y label.
  - [ ] Widget testi: tıkla → sıradaki değer; 360'tan sonra 7'ye sarar.
- **Kabul:** Tek buton, sıralı döngü, 6 seçenek; dar boyutta taşma yok.
- **Açık nokta:** 180/360 gün verisi yalnız 90 günlük sıcak pencereden besleniyorsa eksik çizer — veri kaynağı WP sırasında netleşecek.
- **Model önerisi:** 🟣 Pro

### WP-239: Sayaç Durdurma Çift-Sayım + Invalidation Tekilleştirme ⏱️
- **Program/Faz:** Saha turu 2 (beta-v4202)
- **Durum:** [ ] Planlandı
- **Problem (kök neden bulundu):** 1 saat kayıtlı + 1 saat canlı kronometre (UI 2 saat) iken **Durdur**'a basınca bir an **3 saat** gösteriyor; kronometreyi kapat-aç düzeltiyor.
  - Kaynak: `study_timer_card.dart:125-136`. Durdurma anında `ref.listen` şunu yazıyor: `_frozenTotal = ref.read(todayRecordedSecondsProvider) + extra`. Ama `stop()` içindeki `_recordSession`/`addSession` offline-first cache'e senkron yazıp `userSessionsProvider` stream'ini state değişmeden ÖNCE emit ederse, `recorded` **zaten `extra`'yı içeriyor** → bir daha eklenince çift sayım (2s→3s). Kapat-aç `_frozenTotal`'ı sıfırladığı için düzeliyor.
  - Yani UI, "stop sonrası recorded ne zaman güncellenir" belirsizliğini bir freeze hack'iyle tahmin ediyor ve yarışı kaybediyor. **Bu tam da WP-231'den taşınan "invalidation tekilleştir" maddesi.**
- **"Invalidation tekilleştir" ne demek (kullanıcı sorusu):** Oturum durunca/manuel eklenince veri UI'a birden çok bağımsız yoldan yansıyor: (1) offline-first repo cache yazımı, (2) remote (Supabase) yazımı, (3) `userSessionsProvider` stream emit, (4) `userStudySummaryProvider` (lifetime/RPC özet) ayrı fetch, (5) presence.todaySeconds / gamification summary. Bunlar farklı anlarda güncelleniyor (kimi stream, kimi manuel `invalidate`, kimi hiç). Dağınıklık → "durdurdum ama toplam eski/yanlış" ve bu çift-sayım. **Tekilleştir** = stop/manual-add sonrası tüm bu tazelemeleri tek noktadan, tanımlı sırayla tetikleyen ortak bir yol; UI'ın freeze gibi tahmin hack'lerine ihtiyacı kalmaz.
- **SAHİP dosyalar:** `app/lib/data/providers/study_providers.dart` (stop/record + ortak refresh yolu), `app/lib/features/classroom/widgets/study_timer_card.dart` (freeze mantığını sadeleştir/kaldır), `app/lib/core/stats/study_stats.dart` (resolveTodayDisplayTotal), ilgili testler.
- **DOKUNMA:** Native FGS reconcile ([[native-dart-timer-sync-only-on-resume]]), achievement economy, migration.
- **Adımlar:**
  - [ ] Stop/manual-add sonrası tek "session persisted" refresh yolu; recorded/summary/presence deterministik sırayla güncellenir.
  - [ ] Freeze hack'ini ya kaldır ya da recorded'ın canlı süreyi zaten içerdiği durumu çift saymayacak şekilde düzelt (extra'yı yalnız recorded henüz içermiyorsa ekle).
  - [ ] Regresyon testi: 1s recorded + 1s canlı → stop → tam olarak 2s (3s asla); kapat-aç gerekmeden.
  - [ ] Manuel ekleme sonrası da toplam ≤1 sn içinde doğru.
- **Kabul:** Durdurmada anlık toplam doğru (çift sayım yok); kapat-aç gerektirmez; stop/manual-add refresh tek yoldan.
- **İlişki:** WP-231'in kalan realtime/reconnect maddeleri ayrı kalır; bu WP yalnız stop/manual-add refresh + freeze bug'ı.
- **Model önerisi:** 🔴 Opus / frontier-high

> **Çakışma/seri yürütme:** WP-225→226→227→228 zorunlu seri. Sonra en fazla iki lane: WP-229 (server/migration) ve WP-230 (client/economy) paralel olabilir; ortak fixture/l10n/migration sahipliği önceden netleştirilir. WP-231 ikisi kabul edilince, WP-232 en son başlar. `supabase/migrations/**` aynı anda tek lane'dir.

> **Açık ops işleri (kod dışı — bu tabloda değil, kanonik takip başka dosyada):** Play production programı (NO-GO), Edge deploy'lar (hesap silme purge CRON, aylık rapor cron), Data Safety/legal URL Console adımları → [`backlog.md`](backlog.md) + [`docs/PLAY-STORE-HAZIRLIK-TARAMASI.md`](docs/PLAY-STORE-HAZIRLIK-TARAMASI.md).
> Tarihsel `[x]`/`[~]` WP kartları (WP-104…207) ve eski dalga/çakışma notları arşive taşındı (2026-07-19 temizlik).



---

## Test için bekleyenler (park)

> Cihaz/ürün kabulü bekleyen tamamlanmış kod. Bu bölüm aktif çalışma değildir; başka WP'yi engellemez.

- **WP-264 — Tools Saat/Dünya/Kronometre sadeleştirmesi** · Tools şeridi Alarm/Timer/Görevler olarak sadeleştirildi ve dikey açılış Alarm'a alındı; mobil yatay StandBy ile stopwatch/world motor dosyaları ve Android sayaç/bildirim servisleri korunmuştur. Hedef testler ve `flutter analyze` temiz; tam Flutter paketi **670/670 PASS**. **Cihazda doğrulanmalı:** dikey Tools üç girişi, yatay StandBy ve çalışan sayaç bildiriminin etkilenmediği kontrol edilir.

- **WP-263 — Profil özetindeki gizli rozet rengi** · Tam başarımlar ekranıyla aynı `badgeVisualColor` kuralı profil vitrinine bağlandı; seçili, açılmış gizli rozet artık mor (`#A855F7`), normal rozet kademe renginde kalır. Hedef widget testi, `flutter analyze` ve tüm Flutter paketi **670/670 PASS**. **Cihazda doğrulanmalı:** gizli rozeti seçip Profil kartında açık/koyu temada rengini ve erişilebilir etiketini kontrol et. Remote/production mutasyonu yok.

- **WP-231 — İstatistik Dönemi ve Realtime Güveni** · Grup günlük toplam akışı geçici RPC/Realtime hatasında cache'i gösterip 2 sn sonra yeniden bağlanır; yeniden gelen snapshot ikinci cihazın toplamını günceller. 20 Temmuz 2026 Pazartesi Istanbul fikstürü bugün/hafta=34 dk, son 7 gün=10 sa 34 dk, ay=43 saati kilitler. Kanıt: `wp231_stats_contract_test.dart` + offline reconnect testi; `flutter analyze` 0, tam Flutter paketi **669/669 PASS**. **Cihazda doğrulanmalı:** iki gerçek cihazla ağ kes→geri gel, bir cihazda oturum bitirirken diğerinin kişisel/grup toplamının cache'ten eski veri göstermeden güncellenmesi; grup için ≤5 sn, kişisel için ≤1 sn hedefi.

- **WP-259 — Windows QA Temeli ve Yerel İki-Sürüm Provası** · Güvenli pencere-yakalamalı hızlı smoke gerçek makinede ≤1 sn PASS; `windows_local_dev.ps1 -BuildOnly` local InMemory manifestiyle taze Windows release derledi ve özgün `env.json`u geri yükledi; gerçek Windows hedefindeki girişli entegrasyon testi Ana Sayfa→Gruplar→Profil geçişini PASS verdi. Commit'ler: `da4830b`, `95e554c`, `bd1c221`, `e313545`, `756fb10`. **Temiz VM/ikinci PC'de doğrulanmalı:** staging QA MSIX ile N→N+1 kurulum/güncelleme, uninstall, 100/125/150% DPI ve W-01…W-06/W-10…W-22; prosedür: [`docs/WINDOWS-VM-QA.md`](docs/WINDOWS-VM-QA.md). Ana PC Windows 11 Home olduğundan Sandbox burada kullanılamaz; Store/public/production mutasyonu yapılmadı.

- **WP-229 — Eşit süre kaynakları ve ödül zinciri (staging kabulü GEÇTİ)** · Staging apply `8a9bc4d` başarılı: hosted staging parity onarımı (`pg_cron` önkoşulu allowlist'li bootstrap ile), `0053–0063` ardından immutable ileri `0064`; remote head `0064`, linked pgTAP/RLS/invariant **80/80 PASS**. Reconciliation `79e6f74`: staging batch 0 kullanıcı/0 diff, apply sonrası session/duration/ledger/XP/claimed delta ve XP mismatch **0**; yerel non-empty prova (2 kullanıcı/2 session) aynı kayıpsız sonucu verdi. Production'a **hiçbir yazma yapılmadı** (`deploy_enabled: false`). · **Cihazda doğrulanmalı:** beş giriş yolunun (manuel/kronometre/geri sayım/Pomodoro/native-widget) aynı süreyi aynı kişisel+grup+XP+başarım sonucuna yazması; claim zinciri çift XP üretmemesi; 23:59→00:01 İstanbul gün sınırı.

- **WP-230 — Ekonomi/taç/sürüm gerçeği + staging beta artefaktı** · `flutter analyze` 0 sorun, **635/635** test yeşil, tooling testleri **39** (35 deploy guard + 4 beta build). Gerçek staging anahtarıyla beta APK üretildi ve kimliği doğrulandı: `1.0.42-beta.2+4202`, git `1a46ace`, head `0064`, backend `rskiuyjabyzelqododpa`, paket `com.manilmax.online_study_room.beta`, targetSdk 36, **APK Signature v2 doğrulandı**, sha256 `6a59769d…`. Kanıt: `.artifacts/deploy-evidence/20260720T124704399Z-staging-beta-build/`. `app/env.json` bit-aynı korundu (`local_env_preserved: true`), anahtar yalnız süreç belleğinde kaldı, kanıt log'larında sır yok, `.artifacts/` gitignore'da. · **Cihazda doğrulanmalı:** Samsung'da beta yan yana kurulum, 6 kademe/20k ekonomi + XP barı/etiketi tutarlılığı, claim sonrası refresh, cold-start widget/bildirim.
  - **Yayınlandı (2026-07-20):** `beta-v4202` tag'i atıldı, protected `Release APK` workflow'u yeşil geçti. GitHub prerelease: `app-beta-release.apk`, sha256 `ec8910a7…`, commit `d016a5d`, backend `rskiuyjabyzelqododpa`, head `0064`. Workflow'daki `Protected release gate` ve `Kanal/backend fail-closed guard` adımları geçti — GitHub Environment/secret kurulumu doğrulanmış oldu. Kurulan yapılandırma: `staging`/`production` Environment'ları, environment-scoped `*_SUPABASE_URL`/`*_SUPABASE_ANON_KEY`, repo-level `*_SUPABASE_PROJECT_REF`.
  - ⚠️ **Yayın metni düzeltmesi:** `d016a5d`'te yayınlanan release body'si beta'nın "ayrı uygulama olarak yan yana kurulacağını ve eski beta'nın silinmesi gerektiğini" söylüyor; bu **yanlıştır** — beta `beta-v41` öncesinden beri `.beta` applicationId kullanıyor, yani yerinde güncellenir. Kaynak metin `c28b077`'de düzeltildi; 4202'nin uygulama içi notları bu hatayı taşır, sonraki betada temizdir.
  - ⚠️ **Sürüm gerçeği bulgusu:** `1.0.42-beta.1+4201` **iki farklı kod** için üretilmişti (`753a605` sha `d9077aef…` ve `bd60064` sha `79e6b456…`) — WP-230'un yasakladığı durumun ta kendisi. Bu yüzden kabul adayı `beta.2+4202`'ye ilerletildi; 4201 artefaktları kabul adayı **değildir**, dağıtılmamalıdır.

- **WP-229 — Eşit Süre Kaynakları ve Ödül Zinciri Onarımı** · Kod + local otomatik test tamamlandı (fresh `0001–0064` replay; 80/80 pgTAP; DB lint hata 0; Flutter source-contract 2/2; birleşik `flutter analyze` 0). 0063 yalnız izole staging'e uygulanıp immutable oldu; linked suite'in bulduğu hosted cron/grant/fixture parity açığı ileri 0064 ile kapatıldı. `live_run_id`/verified immutable guard'ı koruyarak manual/kronometre/countdown/Pomodoro/native-widget session'larını aynı duration/kişisel/grup/XP/başarım zincirine alır. `duration_seconds` kanoniktir; +3 saat timestamp drift fixture'ı hayalet süre üretmez. Alfa/Kamp/Lokomotif/Lider Kurt/Mola Düşmanı candidate→pending→claim, ikinci claim/apply no-op, aktif yazıda stale reconciliation fail-closed ve session/duration/ledger/claimed kaybı 0 kanıtlandı. **Staging/owner QA'da doğrulanmalı:** 0064 protected apply; küçük prepared batch diff inceleme→bounded apply; linked pgTAP/RLS; gerçek cihazda beş giriş rotası ve claim; production WP-232 somut GO'suna kadar yok. Rapor: [`docs/recovery/EQUAL-SOURCES-RECONCILIATION.md`](docs/recovery/EQUAL-SOURCES-RECONCILIATION.md).

- **WP-230 — Ekonomi, Taç ve Sürüm Gerçeği Onarımı** · Kod + otomatik test tamamlandı (`flutter analyze` 0; tüm Flutter test paketi exit 0; hedef ekonomi/UI/manifest testleri 37/37; JSON/YAML parse temiz). Tek fixture 11 ana kademeli başarım + haftalık uzantı + gizli XP + `[0,20k,75k,200k,500k,1M]` taçlarını istemci ve uygulanmış server migration gerçeğine bağlar. 12.500 XP etiketi/barı `%62,5`; altı görsel kademe ve erişilebilir semantik hizalı; kullanıcıya görünen verified-only metin/ikon kalmadı. Beta `1.0.42-beta.1+4201`, stable `1.0.42+42`; artefakt manifesti version/build + commit/backend/migration head + SHA-256 üretir. Production/migration/remote değişikliği yok. **Cihaz/staging QA'da doğrulanmalı:** 360/600/1200 px ve ekran okuyucuda taç/XP yerleşimi; staging beta artefaktında tanı kartı+release manifest doğruluğu; stable artefakt kimliğinin beta ile çakışmadığı release dry-run. WP-229 migration kabulü bitmeden beta/stable release yapılmaz. Commit: bu WP commit'i.

- **WP-228 — Güvenli Deploy Otomasyonu ve Agent Kapıları** · Kod + otomatik test tamamlandı (`flutter analyze` 0; 632/632 Flutter; local 0001–0063 replay + 34/34 pgTAP; 18/18 deploy guard; PowerShell/YAML parse ve secret scan temiz). Tek-komut local rerun; zaten çalışan stack no-op'u ve yarım/orphan stack'in yalnız local volume temizliğiyle recovery'si kanıtlandı. Local/staging/production hedef doğrulaması, stale-link ve destructive-command reddi, exact SHA/head, protected production environment + makine-okunur backup checklist + birebir GO, merkezi deploy HOLD contract'ı ve redacted evidence manifestleri hazır. Commit: bu WP commit'i. **Staging/owner QA'da doğrulanmalı:** ayrı staging projesi ile GitHub `staging`/`production` Environment+secret/required-reviewer kurulumu; WP-229 kabul head'i sonrası `staging-apply` akışında list→dry-run→push→linked pgTAP→aynı commit/head beta APK raporu. Mevcut `0063` HOLD nedeniyle staging/production apply ve beta/stable release fail-closed kapalı; production write yok. Rehber: [`tooling/README.md`](tooling/README.md).

- **WP-227 — Beta/Stable Ortam İzolasyonu** · Kod + otomatik test tamamlandı (`flutter analyze` 0; 631/631 Flutter; 34/34 hedef test; local/beta/stable Android APK + Windows beta debug build). Beta+production ve stable+staging build'leri exit 1 ile reddedildi; application id/ad/auth scheme/provider authority ayrımı APK'da doğrulandı. Commit: bu WP commit'i. **Staging/cihazda doğrulanmalı:** owner ayrı staging projesi/parolası/`STAGING_*` secret'larını kurar; `0063` HOLD nedeniyle remote migration/seed WP-228+229 sonrasına bırakılır; sonra stable+beta yan-yana auth/cache/widget/deep-link/tanı kartı QA. Production write yok. Rapor: [`docs/recovery/ENVIRONMENT-MATRIX.md`](docs/recovery/ENVIRONMENT-MATRIX.md).

- **WP-L — Lider Kurt haftalık başarımı (beta-v42)** · Kod + otomatik test tamamlandı (`flutter analyze`, 617 test). `0062` production'da user-reported uygulanmış olsa da eşit-kaynak/finalizer/reward kabulü yoktur; WP-229 staging doğrulamasına bağlandı. Eşik/XP: `1/4/12/26/52/104` ve `2500/6000/15000/30000/60000/120000`.

- **WP-219R — Süre kaynağı eşitliği (beta-v42)** · Kod + otomatik test tamamlandı (`flutter analyze`, 617 test) fakat audit `0063`ün reward/recompute güvenliğini kabul etmedi. **Production'a uygulanmaz; WP-229 tarafından yeni ileri migration olarak yeniden tasarlanacak.**

- **WP-221 — Grup avatar storage trigger fix (beta-v41 · plan WP-H)** · Kod tamamlandı (`flutter analyze` temiz) · **Cihazda/staging'de doğrulanmalı:** migration `0054` uygulandıktan sonra grup fotoğrafı ilk yükleme + değiştirme + silme hatasız (eski hata: "direct deletions from storage tables is not allowed"); eski avatar nesnesi değişimden sonra Storage API ile temizleniyor; üye-olmayan private erişim reddi ve admin-olmayan yazma reddi korunuyor (QA 3.1–3.3).
- **WP-222 — "Clock"→"Hours" saat birimi etiketi (beta-v41 · plan WP-I)** · Kod tamamlandı (`flutter analyze` temiz) · **Cihazda doğrulanmalı:** "Manuel süre ekle" ve "Günlük hedef" diyaloglarında saat alanı EN'de "Hours" (eski: "Clock"); DE "Stunden", AR "ساعات"; alarm/saat ekranlarındaki "Clock" etiketi değişmemiş.
- **WP-223 — Başarımlar poll + pull-to-refresh kaldırma (beta-v41 · plan WP-G, madde 1+10)** · Kod tamamlandı (`flutter analyze` temiz, reward_toast + pull-to-refresh testleri yeşil) · **Cihazda doğrulanmalı:** Başarımlar sayfası artık ~4 sn'de bir zıplamıyor/yenilenmiyor; scroll konumu korunuyor; aşağı-çek-yenile jesti hiçbir sekmede yok; oturum bitince ödül banner'ı/badge yine görünüyor (olay bazlı, poll yok); claim sonrası liste güncelleniyor. Not: `app_pull_to_refresh.dart` widget'ı korundu (uygulamada kullanılmıyor; istenirse tek sayfaya geri takılabilir).

- **WP-209 — Reward inbox expansion** · Kod + otomatik test tamamlandı (`flutter analyze`, 563 test) · Commit: bu WP commit'i · **Cihazda/staging'de doğrulanmalı:** 0047 dry-run/rollback rehearsal, self-RLS ve direct-DML abuse testi, iki cihaz aynı reward claim yarışı, injected pending sonrası `gamification_profiles.xp = SUM(xp_ledger.xp_amount)` reconciliation kanıtı. Auto-award ve saatlik 50 XP regresyonu staging'de ayrıca doğrulanacak.
- **WP-212 — Cloud görev altyapısı** · Kod + otomatik test tamamlandı (`flutter analyze`, 561 test) · Commit: bu WP commit'i · **Cihazda/staging'de doğrulanmalı:** 0048 dry-run/rollback rehearsal, self-RLS/direct-DML abuse, iki cihazda toggle/undo LWW, 23:59→00:01 İstanbul günlük projection, prefs→cloud göçünü ağ kesintisinden sonra idempotent tekrar deneme.
- **WP-214 — Private grup avatarı** · Kod + otomatik test tamamlandı (`flutter analyze`, 562 test) · Commit: bu WP commit'i · **Cihazda/staging'de doğrulanmalı:** 0049 dry-run/rollback rehearsal; private grupta üye olmayan SELECT reddi; public keşifte authenticated signed URL; admin olmayan upload/delete reddi; JPEG/PNG/WebP ve 2 MB sınırı; avatar değişiminde eski object ve grup siliminde tüm object cleanup; 360/600/1200 px ile gerçek cihaz picker/cache yenileme görünümü.
- **WP-208 — Private başarım metriği + Kusursuz Ay 28/30** · Kod + otomatik test tamamlandı (`flutter analyze`, 570 test) · Commit: bu WP commit'i · **Cihazda/staging'de doğrulanmalı:** 0050 dry-run/rollback rehearsal; self-RLS ile başka kullanıcının secret progress verisinin reddi ve doğrudan DML reddi; projector aynı-değer no-op/current streak düşüşü; legacy audit belirsiz/excluded sayımları; eski 28-gün claim/ledger kazanımının korunması ve XP reconciliation.
- **WP-210 — Claim/progress başarım UI** · Kod + otomatik test tamamlandı (`flutter analyze`, 574 test) · Commit: bu WP commit'i · **Cihazda/staging'de doğrulanmalı:** capability kaydı sonrası injected pending ödülün ≤1 sn görünmesi; tekli/toplu claim yarışında ikinci XP artışı olmaması; server yanıtı öncesi XP/rozet animasyonu başlamaması; claim sonrası profil/reward yenilenmesi; offline retry; reduce-motion ve 360/600/1200 px gerçek cihaz görsel/erişilebilirlik kontrolü.
- **WP-211 — Reward banner/badge + kanonik tab indeksleri** · Kod + otomatik test tamamlandı (`flutter analyze`, 582 test) · Commit: bu WP commit'i · **Cihazda doğrulanmalı:** pending reward'ın ≤5 sn içinde mobil banner+Profil badge'de görünmesi ve claim sonrası kaybolması; banner kapatıldığında badge'in kalması; taç yükselişi kutlamasının tek sefer çalışması/reduce-motion; desktop banner yerleşimi; Android cihaz kısayollarının Ana Sayfa/Gruplar/İstatistik sekmelerine doğru gitmesi.
- **WP-213 — Günlük görev UI + 00:00 yenileme** · Kod + otomatik test tamamlandı (`flutter analyze`, 586 test) · Commit: bu WP commit'i · **Cihazda doğrulanmalı:** günlük ekle→bugün tamamla/geri al→İstanbul 00:00'da yeniden aktif; uygulama arka planda geceyi geçince resume refresh; offline hata/retry ve yeniden bağlanma; iki cihaz toggle/undo görünümü; 360 px ve klavye açık editör erişilebilirliği.
- **WP-215 — Beş ana sekmede tap-to-top** · Kod + otomatik test tamamlandı (`flutter analyze`, 587 test) · Commit: bu WP commit'i · **Cihazda doğrulanmalı:** Saat/Gruplar/Profil ve İstatistik kişisel+grup listelerinde offset>0 iken aynı taba yeniden basınca ≤300 ms'de 0; boş/build-öncesi/zaten-top no-op; Home davranışı ve nested grup kartı jestleri regresyonsuz.
- **WP-216 — Server-issued verified live session expansion** · Kod + otomatik test tamamlandı (`flutter analyze`, 596 test) · Commit: bu WP commit'i · **Staging/cihazda doğrulanmalı:** 0051 dry-run/rollback rehearsal; direct DML ile non-null `live_run_id` ve verified update/delete reddi; iki cihaz tek aktif run; üyelik değişimi/grup silimi sonrası immutable snapshot; start/pause/resume/finalize cevap kaybı ve retry; eski client normal session + mevcut XP regresyonu; 30 günlük rollout retention/cron ve reconciliation.
- **WP-220 — Verified timer/native shadow köprüsü** · Kod + otomatik test tamamlandı (`flutter analyze`, 601 test, `compileStableDebugKotlin`) · Commit: bu WP commit'i · **Cihazda/sahada doğrulanmalı:** Dart start→app-kill→native Stop tek verified session; reordered/duplicate pause-resume-finalize outbox; offline ve widget/bildirim saf-native başlangıçların stat-only mesajı; build readiness; shadow agregaları; Samsung gerçek cihaz + Android 8–13 ve API 34+ FGS/widget/bildirim/force-stop/reboot senaryoları. XP ekonomisi shadow modda değişmemeli.
- **WP-217 — Mola Düşmanı verified motoru** · Kod + otomatik sınır testleri tamamlandı (`flutter analyze`) · Commit: bu WP commit'i · **Staging'de doğrulanmalı:** 0052 syntax/RLS; exact 270 dk, pencere sınırı, çakışan/gece yarısı segmentleri; event/backfill p95; timeout cursor ilerletmeme; ikinci projector çalıştırmasında duplicate candidate olmaması. Bounded retro job tanımı production'da çalıştırılmadı.

## Tamamlanan İş Paketleri

> Ürün/cihaz kabulü almış WP'ler. Ayrıntılı tarihsel kartlar (WP-23…207) + "Son Teslim Notları" arşive taşındı → [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md). Planner yeni tamamlananı buraya **tek satır** ekler.

- **WP-225 — Production Freeze ve Adli Baseline** · Tamamlandı 2026-07-20 · Production write olmadan CLI + 5 salt-okunur SQL paketiyle history/schema/function/trigger/policy/cron ve session/XP/reward baseline'ı çıkarıldı. Hedef hesap session/XP kaybı 0; 0053 projection drift'i, cron run=0/retention absent, eski 25k istemci ve uygulanmamış 0063 kanıtlandı. Rapor: [`docs/recovery/PRODUCTION-BASELINE.md`](docs/recovery/PRODUCTION-BASELINE.md).
- **WP-226 — Supabase CLI ve Migration Baseline** · Tamamlandı 2026-07-20 · Docker Desktop + pinli `supabase@2.109.1`, PG17 local config, production-parity extension/DML grant bootstrap, sentetik seed ve güvenli local wrapper kuruldu. Boş DB'de 0001–0063 tekrar replay edildi; 34 pgTAP RLS/XP/source-parity + Flutter analyze 0 + 617/617 test geçti. Production history repair listesi bilinmeyen/partial satırlar nedeniyle bilinçli olarak boş; production write yok. 0063 sonrası stale verified-weekly lint borcu WP-229'a devredildi. Rapor: [`docs/recovery/MIGRATION-BASELINE.md`](docs/recovery/MIGRATION-BASELINE.md).

---

> **📦 Arşiv (2026-07-19 token optimizasyonu):** progress.md 1599→~138 satıra indirildi (2. tur: tamamlanmış/test-bekleyen WP-104…207 index satırları + eski dalga/çakışma notları temizlendi). Tarihsel WP kartları + Play detayı + park/Tamamlanan detayları + Son Teslim Notları [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md)'de. **Canlı durum bu dosyadadır** (Proje Gerçekleri + Aktif Çalışma Kaydı + aktif WP Durum Dizini). Bir WP'nin tarihsel ayrıntısı gerekirse arşivden okunur.
