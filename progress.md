# progress.md — İlerleme Takibi

> Son güncelleme: 2026-07-20 (kurtarma programı + ortam/migration yönetişimi planlandı)
> Sistem: İş Paketi (WP) tabanlı, **Kalite Programı**. Kanonik program: `docs/KALITE-PROGRAMI.md`.
> Planlama: `.agents/skills/planner/SKILL.md` · Uygulama: `.agents/skills/worker/SKILL.md` · Kurallar: `.agents/AGENTS.md`.
> **"Tamamlandı" = kod DEĞİL; kullanıcı beklentisini karşılayan + cihazda güvenilir çalışan iş.** İş durum merdiveni (8 aşama) ve kanıt etiketleri (`Kodda doğrulandı` / `Cihazda doğrulanmalı` / `Ürün kararı gerekiyor`) için bkz. AGENTS.md §0.

---

## Proje Gerçekleri (ajan referansı)

- **Framework:** Flutter ^3.12 · Riverpod 3.3 · Supabase 2.15 · fl_chart
- **Uygulama kökü:** `app/` — Flutter komutları yalnız burada çalışır.
- **Repo katmanı çift:** Her arayüz `supabase/` ve `in_memory/` repository'leriyle desteklenir.
- **Migration'lar:** `supabase/migrations/` — yerelde `0001–0064` pinli CLI/Docker ile boş DB'de tekrar kuruluyor ve 80 gerçek SQL testi geçiyor. Production'da history tablosu yok; 0051/0053/0060/0062 driftli, 0063/0064 production'a uygulanmamış ve freeze altında. Kör history repair listesi boştur; ayrıntı `docs/recovery/MIGRATION-BASELINE.md`.
- **Gün sınırı:** `Europe/Istanbul`
- **RLS helper'ları:** `is_group_member(gid)`, `can_see_user_sessions(target)`, `is_group_admin(gid)`, `is_super_admin()`
- **Dashboard:** 6 sütunlu 2D matris, 19 kart türü, `grid_reflow.dart` motoru.
- **Tema:** Hazır paletler + özel palet slotları; görünür tüm yüzeyler palette bağlanmalıdır, sabit gri renk eklenmez.
- **Navigasyon hedefi:** Ana Sayfa / Saat / Gruplar / İstatistikler / Profil. Ana Sayfa günlük kullanım alanıdır; diğer alanların verisi kendi sekmelerinde eksiksiz bulunur.
- **Release gerçeği:** Stable tag `v39` (`c6843a5`), beta tag `beta-v41` (`e6234a6`), HEAD `2d757eb`. Beta-v41 sonrası 13 yerel commit vardır; uygulama hâlâ `1.0.41+41` taşıdığı için sürüm/commit ayrımı bozuk. WP-227/230 düzeltecek.
- **Kalite kapıları:** Her WP DoD'siz kapanmaz; stable release kalite kapısından geçer (AGENTS.md §3). Server-authoritative XP, RLS/sosyal profil, platform sınırları → `docs/KALITE-PROGRAMI.md`.
- **Son WP numarası:** **234** (WP-221–224 geçmişte kullanılmış; kurtarma WP-225–232 planlandı; WP-233/234 beta-v4202 saha bulguları). **Sıradaki boş numara WP-235.**
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

### Claude Lane
- **Durum:** [~] Aktif
- **Faz/WP:** WP-233 (P1 sayaç bug) + WP-234 (başarım/taç görünüm)
- **Aşama:** Kod tamam (analyze temiz, 636 test geçti) — cihaz doğrulaması bekleniyor
- **SAHİP yollar:** `app/lib/data/providers/study_providers.dart`, `app/lib/features/profile/widgets/achievement_showcase.dart`, `app/lib/features/profile/widgets/gamification_card.dart`, ilgili l10n + testler, `progress.md`
- **Ortak/riskli yüzey:** l10n ARB (yeni anahtar); sayaç SSOT — native/Dart durum senkronu
- **Dal:** `main`
- **Başlangıç:** 2026-07-20 17:20 (Europe/Istanbul)
- **Son güncelleme:** 2026-07-20 17:20 (Europe/Istanbul)
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
- **Durum:** [x] Boşta — WP-229/230 **Claude lane'ine devredildi** (2026-07-20 15:40, oturum limiti)
- **Faz/WP:** —
- **Aşama:** —
- **Devir öncesi SAHİP yollar (arşiv):** `supabase/migrations/0064_*`, `supabase/tests/**`, `tooling/supabase/DeployGuard.psm1`, `tooling/supabase/remote.ps1`, staging owner helper'ları, `tooling/supabase/guard.tests.ps1`, `tooling/release/deploy-contract.json`, `tooling/release/beta-build.ps1`, `tooling/release/beta-build.tests.ps1`, `tooling/release/staging-beta-owner.ps1`, `app/android/app/build.gradle.kts`, `tooling/README.md`, staging/GitHub Environment yapılandırması, `docs/recovery/EQUAL-SOURCES-RECONCILIATION.md`, `docs/recovery/ENVIRONMENT-MATRIX.md`, WP-229/230 kabul kanıtları, `progress.md`
- **Ortak/riskli yüzey:** Supabase CLI ile ayrı staging projesi; `0064` yalnız staging; production mutasyonu kesinlikle yok
- **Dal:** `main`
- **Başlangıç:** 2026-07-20 14:15 (Europe/Istanbul)
- **Son güncelleme:** 2026-07-20 15:20 (Europe/Istanbul)
- **Not:** Staging prerequisite inspect/bootstrap sonrası `0053–0063`, ardından immutable ileri `0064` uygulandı. Exact `8a9bc4d6162e29d46e1c4d3ce8d7ce3c8c965d7c` apply manifesti başarılı; remote head `0064`, linked pgTAP/RLS/invariant 80/80 PASS. WP-229 küçük staging prepare/apply `79e6f7435f10db04b88bf52be1b6e4f9c9d55edf` ile geçti: fresh staging batch'i 0 kullanıcı/0 diff, apply sonrası session/duration/ledger/XP/claimed deltaları ve XP mismatch 0. Yerel non-empty prova 2 kullanıcı/2 session ile aynı kayıpsız sonucu verdi. WP-230 için gerçek public staging key'ini yalnız CLI süreç belleğinde kullanan, mevcut `app/env.json` hash'ini koruyan geçici-manifest beta build'i hazırlanıyor. Production mutasyonu yok; hiçbir gizli değer repoya veya kanıta yazılmadı.

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
| WP-227 | [~] Staging/cihaz QA | Beta/stable flavor + staging/production backend izolasyonu + fail-closed | ← WP-226 |
| WP-228 | [~] Staging/owner QA | Local/staging otomasyonu + production manual approval gate | ← WP-227 · apply kanıtı WP-229 kabul head'i sonrası |
| WP-229 | [~] Cihaz QA (staging GEÇTİ) | Eşit süre kaynakları ve reward/projection zinciri için güvenli ileri migration | ← WP-226, WP-227 · staging head `0064`, 80/80 PASS |
| WP-230 | [~] Cihaz QA (artefakt HAZIR) | 6 kademe/20k ekonomi + XP bar/metin + sürüm manifesti istemci onarımı | ← WP-227 · beta `1.0.42-beta.2+4202` @ `1a46ace` |
| WP-233 | [x] Cihaz QA bekliyor | 🔴 P1: bildirimden başlatılan sayaç uygulama içinden durdurulamıyor | beta-v4202 saha bulgusu · `stop()` native SSOT ile uzlaşıyor · regresyon testi |
| WP-234 | [x] Cihaz QA bekliyor | Biriken-olmayan başarımlarda yanıltıcı ilerleme + taç kademe görünürlüğü | beta-v4202 saha bulgusu · kişisel rekor çubuğu kalktı + taç kademe sayfası |
| WP-231 | [ ] Bekliyor | İstatistik dönem semantiği + toplam/realtime refresh + grup tutarlılığı | ← WP-229, WP-230 |
| WP-232 | [ ] Bekliyor | Staging QA/soak + backup/dry-run + kontrollü production recovery release | ← WP-225–231 |

### WP-229: Eşit Süre Kaynakları ve Ödül Zinciri Onarımı ⚖️
- **Program/Faz:** Kurtarma Faz 4A
- **Ajan:** Codex
- **Durum:** [~] Staging/owner QA
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
- **Durum:** [~] Cihaz/staging QA
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
- **Ajan:** —
- **Durum:** [ ] Bekliyor
- **Problem:** “Hafta” son 7 gün sanılıyor; Pazartesi reseti veri kaybı gibi görünüyor. Oturum bitiminden sonra kişisel/grup toplam güncellemesi ayrıca cihazda güvenilir değil.
- **Kapsam dışı:** Ham geçmişi değiştirmek, achievement economy, production migration.
- **SAHİP dosyalar (yaz):** `app/lib/core/stats/**`, stats period/provider/view dosyaları, relevant study repository/cache refresh yolu, ilgili l10n/testler, `docs/recovery/STATS-CONTRACT.md`, `progress.md`.
- **DOKUNMA:** Achievement UI, migration zinciri (gerekirse ayrı bağımlı WP aç), release config.
- **Adımlar:**
  - [ ] “Bu hafta (Pzt–bugün)” ile “Son 7 Gün”ü ayrı dönem yap; kişisel/grup aynı range yardımcılarını kullansın.
  - [ ] Günlük ortalama paydasını görünür dönem sözleşmesiyle test et.
  - [ ] Session stop/manual add sonrası cache+remote+summary invalidation yolunu tekilleştir.
  - [ ] Pending/offline/realtime reconnect ve iki cihaz yenilenmesini test et.
  - [ ] 20 Temmuz Pazartesi fixture'ında bugün/hafta/son7/ay sonuçlarını golden/widget testle.
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

> **Çakışma/seri yürütme:** WP-225→226→227→228 zorunlu seri. Sonra en fazla iki lane: WP-229 (server/migration) ve WP-230 (client/economy) paralel olabilir; ortak fixture/l10n/migration sahipliği önceden netleştirilir. WP-231 ikisi kabul edilince, WP-232 en son başlar. `supabase/migrations/**` aynı anda tek lane'dir.

> **Açık ops işleri (kod dışı — bu tabloda değil, kanonik takip başka dosyada):** Play production programı (NO-GO), Edge deploy'lar (hesap silme purge CRON, aylık rapor cron), Data Safety/legal URL Console adımları → [`backlog.md`](backlog.md) + [`docs/PLAY-STORE-HAZIRLIK-TARAMASI.md`](docs/PLAY-STORE-HAZIRLIK-TARAMASI.md).
> Tarihsel `[x]`/`[~]` WP kartları (WP-104…207) ve eski dalga/çakışma notları arşive taşındı (2026-07-19 temizlik).



---

## Test için bekleyenler (park)

> Cihaz/ürün kabulü bekleyen tamamlanmış kod. Bu bölüm aktif çalışma değildir; başka WP'yi engellemez.

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
