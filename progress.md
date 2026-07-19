# progress.md — İlerleme Takibi

> Son güncelleme: 2026-07-19 (tarihsel kartlar arşive taşındı — bkz. dosya sonu)
> Sistem: İş Paketi (WP) tabanlı, **Kalite Programı**. Kanonik program: `docs/KALITE-PROGRAMI.md`.
> Planlama: `.agents/skills/planner/SKILL.md` · Uygulama: `.agents/skills/worker/SKILL.md` · Kurallar: `.agents/AGENTS.md`.
> **"Tamamlandı" = kod DEĞİL; kullanıcı beklentisini karşılayan + cihazda güvenilir çalışan iş.** İş durum merdiveni (8 aşama) ve kanıt etiketleri (`Kodda doğrulandı` / `Cihazda doğrulanmalı` / `Ürün kararı gerekiyor`) için bkz. AGENTS.md §0.

---

## Proje Gerçekleri (ajan referansı)

- **Framework:** Flutter ^3.12 · Riverpod 3.3 · Supabase 2.15 · fl_chart
- **Uygulama kökü:** `app/` — Flutter komutları yalnız burada çalışır.
- **Repo katmanı çift:** Her arayüz `supabase/` ve `in_memory/` repository'leriyle desteklenir.
- **Migration'lar:** `supabase/migrations/` — yerelde `0001–0046` vardır. Canlı ortamda dosyanın bulunması deploy kanıtı değildir. Feedback: `0044–0045` + **`0046` (trigger 42704 role fix)**. Yeni migration mevcut en yüksek numaradan (`0046`) devam eder.
- **Gün sınırı:** `Europe/Istanbul`
- **RLS helper'ları:** `is_group_member(gid)`, `can_see_user_sessions(target)`, `is_group_admin(gid)`, `is_super_admin()`
- **Dashboard:** 6 sütunlu 2D matris, 19 kart türü, `grid_reflow.dart` motoru.
- **Tema:** Hazır paletler + özel palet slotları; görünür tüm yüzeyler palette bağlanmalıdır, sabit gri renk eklenmez.
- **Navigasyon hedefi:** Ana Sayfa / Saat / Gruplar / İstatistikler / Profil. Ana Sayfa günlük kullanım alanıdır; diğer alanların verisi kendi sekmelerinde eksiksiz bulunur.
- **Release:** Stable/Beta kanalı GitHub Releases ile çalışır. **beta-v30** = `1.0.30+30` (analitik ızgara toggle, 0039–0043 RPC/gamification, WP-166–168). Onay: `docs/qa/BETA-v30-ONAY-LISTESI.md`. Play production ayrı kalite kapısından geçer.
- **Kalite kapıları:** Her WP DoD'siz kapanmaz; stable release kalite kapısından geçer (AGENTS.md §3). Server-authoritative XP, RLS/sosyal profil, platform sınırları → `docs/KALITE-PROGRAMI.md`.
- **Son WP numarası:** **220** (WP-208–220 planlandı, henüz uygulanmadı; son tamamlanan uygulama WP'si 207, git log doğrulandı; stable v39). **Sıradaki boş numara WP-221.**
- **Release:** **beta-v33** = `1.0.33+33`. Cihaz QA: `docs/qa/BETA-v33-TEST.md`. Canlıda **0046** (feedback trigger) de gerekir.
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
- **Durum:** [x] Boşta
- **Faz/WP:** — (beta-v41 programı sürüyor; WP-221 test için parkta)
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** — (main)
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-19 (Europe/Istanbul)
- **Not:** beta-v41 düzeltme programı. Plan: `docs/features/BETA-v41-TEKNIK-PLAN.md` (WP sırası H→I→G→J→A+B→C→D→E→F→K→L). WP-221 (avatar yükleme fix) + **WP-224** (avatar OKUMA fix) → **cihazda doğrulandı (2026-07-19)**: `0055` canlıya uygulandı, storage okuma testi `true`, uygulamada fotoğraf göründü. WP-224 kök neden: `0049`'daki `group_avatars_member_read` politikası belirsiz `name` kolonu yüzünden `g.name`'e bağlanıyordu (grup adını klasör sanıyordu) → signed URL her grupta reddediliyordu; `0055` politikayı `in (...)` biçimiyle düzeltti (sadece DB, APK gerekmedi). **Saha bulgusu #6 kapandı.**

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** — (main)
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-19 (Europe/Istanbul)
- **Not:** v40 imzalı beta APK ve v39 sonrası cihaz/staging QA listesi hazır; cihaz kanıtı bekliyor. 0053 SQL Editor 42601 düzeltildi (`day`→`metric_day`); catch-up aliasları, finalize projector ve cron tekrar çalıştırılabilirliği sertleştirildi.

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

## WP Durum Dizini ve Açık Planlar

> Bu tablo yalnız **aktif planlanmış** WP'leri gösterir. Tamamlanmış/test edilmiş tarihsel WP kartları (WP-23…207) arşivde: [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md) + git geçmişi. Yeni kod işi olarak yalnız `[ ] Bekliyor` satırları claim edilir.

| WP | Durum | Kısa kapsam | Bağımlılık |
|---|---|---|---|
| WP-209 | [~] Kod tamamlandı — test bekliyor | **[EXPAND 1]** Reward inbox şema + atomik/bounded claim; auto-award davranışı değişmez | plan v3.1 |
| WP-208 | [~] Kod tamamlandı — test bekliyor | **[EXPAND 2]** Self-only gerçek metric progress + Kusursuz Ay 30-gün evaluator contract'ı + legacy audit/job altyapısı | ← WP-209 |
| WP-210 | [~] Kod tamamlandı — test bekliyor | **[CLIENT 3]** Claim-capable UI + gerçek progress/streak + az-kaldı + tüm achievement ARB anahtarları | ← WP-208, WP-209 · ARB yazar |
| WP-211 | [~] Kod tamamlandı — test bekliyor | Reward banner/nav badge + tüm tab indekslerinin kanonik sözleşmesi | ← WP-210 · `core/navigation/**` yazarı |
| WP-216 | [~] Kod tamamlandı — test bekliyor | **[TRUST SERVER 4]** Server-issued live run/segment + immutable grup bağlamı + minimal rollout agregası; eski davranış değişmez | ← WP-208 · WP-217/218/220 ön-koşulu |
| WP-220 | [~] Kod tamamlandı — test bekliyor | **[TRUST CLIENT 5]** Dart timer/native outbox verified köprüsü + stat-only saf-native fallback + shadow telemetry + Android ≤13 QA | ← WP-216 · WP-219 sert ön-koşulu |
| WP-217 | [~] Kod tamamlandı — test bekliyor | Mola Düşmanı verified segment motoru + bounded konservatif legacy retro job tanımı | ← WP-216 |
| WP-218 | [~] Kod tamamlandı — test bekliyor | Alfa/Kamp/Lokomotif exact verified grup motoru + legacy proxy/dirty bucket | ← WP-216, WP-217 |
| WP-219 | [ ] Bekliyor | **[CONTRACT/RELEASE]** Ölçümlü verified-only XP kesişi + capability-bazlı pending + dry-run/canary retro | ← WP-209/210/217/218/220 + cihaz/saha QA |
| WP-212 | [~] Kod tamamlandı — test bekliyor | Günlük görev cloud model + toggle/undo + tombstone + idempotent çok-cihaz ops (server 00NN) | plan v3.1 |
| WP-213 | [~] Kod tamamlandı — test bekliyor | Görev UI: günlük tip ekleme + bugünün listesi + 00:00 yenileme | ← WP-212 · ARB yazar |
| WP-214 | [~] Kod tamamlandı — test bekliyor | Grup profil fotoğrafı: `avatar_path` + private bucket/signed URL + admin RLS + discovery | plan v3.1 |
| WP-215 | [~] Kod tamamlandı — test bekliyor | Tap-to-top: gerçek beş scroll dosyası, WP-211 kanonik tab indeksleri | ← WP-211, WP-214 |

> **Açık ops işleri (kod dışı — bu tabloda değil, kanonik takip başka dosyada):** Play production programı (NO-GO), Edge deploy'lar (hesap silme purge CRON, aylık rapor cron), Data Safety/legal URL Console adımları → [`backlog.md`](backlog.md) + [`docs/PLAY-STORE-HAZIRLIK-TARAMASI.md`](docs/PLAY-STORE-HAZIRLIK-TARAMASI.md).
> Tarihsel `[x]`/`[~]` WP kartları (WP-104…207) ve eski dalga/çakışma notları arşive taşındı (2026-07-19 temizlik).



---

## Test için bekleyenler (park)

> Cihaz/ürün kabulü bekleyen tamamlanmış kod. Bu bölüm aktif çalışma değildir; başka WP'yi engellemez.

- **WP-221 — Grup avatar storage trigger fix (beta-v41 · plan WP-H)** · Kod tamamlandı (`flutter analyze` temiz) · **Cihazda/staging'de doğrulanmalı:** migration `0054` uygulandıktan sonra grup fotoğrafı ilk yükleme + değiştirme + silme hatasız (eski hata: "direct deletions from storage tables is not allowed"); eski avatar nesnesi değişimden sonra Storage API ile temizleniyor; üye-olmayan private erişim reddi ve admin-olmayan yazma reddi korunuyor (QA 3.1–3.3).
- **WP-222 — "Clock"→"Hours" saat birimi etiketi (beta-v41 · plan WP-I)** · Kod tamamlandı (`flutter analyze` temiz) · **Cihazda doğrulanmalı:** "Manuel süre ekle" ve "Günlük hedef" diyaloglarında saat alanı EN'de "Hours" (eski: "Clock"); DE "Stunden", AR "ساعات"; alarm/saat ekranlarındaki "Clock" etiketi değişmemiş.
- **WP-223 — Başarımlar poll + pull-to-refresh kaldırma (beta-v41 · plan WP-G, madde 1+10)** · Kod tamamlandı (`flutter analyze` temiz, reward_toast + pull-to-refresh testleri yeşil) · **Cihazda doğrulanmalı:** Başarımlar sayfası artık ~4 sn'de bir zıplamıyor/yenilenmiyor; scroll konumu korunuyor; aşağı-çek-yenile jesti hiçbir sekmede yok; oturum bitince ödül banner'ı/badge yine görünüyor (olay bazlı, poll yok); claim sonrası liste güncelleniyor. Not: `app_pull_to_refresh.dart` widget'ı korundu (uygulamada kullanılmıyor; istenirse tek sayfaya geri takılabilir).

- **WP-209 — Reward inbox expansion** · Kod + otomatik test tamamlandı (`flutter analyze`, 563 test) · Commit: bu WP commit'i · **Cihazda/staging'de doğrulanmalı:** 0047 dry-run/rollback rehearsal, self-RLS ve direct-DML abuse testi, iki cihaz aynı reward claim yarışı, injected pending sonrası `gamification_profiles.xp = SUM(xp_ledger.xp_amount)` reconciliation kanıtı. Auto-award ve saatlik 50 XP regresyonu staging'de ayrıca doğrulanacak.
- **WP-212 — Cloud görev altyapısı** · Kod + otomatik test tamamlandı (`flutter analyze`, 561 test) · Commit: bu WP commit'i · **Cihazda/staging'de doğrulanmalı:** 0048 dry-run/rollback rehearsal, self-RLS/direct-DML abuse, iki cihazda toggle/undo LWW, 23:59→00:01 İstanbul günlük projection, prefs→cloud göçünü ağ kesintisinden sonra idempotent tekrar deneme.
- **WP-214 — Private grup avatarı** · Kod + otomatik test tamamlandı (`flutter analyze`, 562 test) · Commit: bu WP commit'i · **Cihazda/staging'de doğrulanmalı:** 0049 dry-run/rollback rehearsal; private grupta üye olmayan SELECT reddi; public keşifte authenticated signed URL; admin olmayan upload/delete reddi; JPEG/PNG/WebP ve 2 MB sınırı; avatar değişiminde eski object ve grup siliminde tüm object cleanup; 360/600/1200 px ile gerçek cihaz picker/cache yenileme görünümü.
- **WP-208 — Private başarım metriği + Kusursuz Ay 30 gün** · Kod + otomatik test tamamlandı (`flutter analyze`, 570 test) · Commit: bu WP commit'i · **Cihazda/staging'de doğrulanmalı:** 0050 dry-run/rollback rehearsal; self-RLS ile başka kullanıcının secret progress verisinin reddi ve doğrudan DML reddi; projector aynı-değer no-op/current streak düşüşü; legacy audit belirsiz/excluded sayımları; eski 28-gün claim/ledger kazanımının korunması ve XP reconciliation.
- **WP-210 — Claim/progress başarım UI** · Kod + otomatik test tamamlandı (`flutter analyze`, 574 test) · Commit: bu WP commit'i · **Cihazda/staging'de doğrulanmalı:** capability kaydı sonrası injected pending ödülün ≤1 sn görünmesi; tekli/toplu claim yarışında ikinci XP artışı olmaması; server yanıtı öncesi XP/rozet animasyonu başlamaması; claim sonrası profil/reward yenilenmesi; offline retry; reduce-motion ve 360/600/1200 px gerçek cihaz görsel/erişilebilirlik kontrolü.
- **WP-211 — Reward banner/badge + kanonik tab indeksleri** · Kod + otomatik test tamamlandı (`flutter analyze`, 582 test) · Commit: bu WP commit'i · **Cihazda doğrulanmalı:** pending reward'ın ≤5 sn içinde mobil banner+Profil badge'de görünmesi ve claim sonrası kaybolması; banner kapatıldığında badge'in kalması; taç yükselişi kutlamasının tek sefer çalışması/reduce-motion; desktop banner yerleşimi; Android cihaz kısayollarının Ana Sayfa/Gruplar/İstatistik sekmelerine doğru gitmesi.
- **WP-213 — Günlük görev UI + 00:00 yenileme** · Kod + otomatik test tamamlandı (`flutter analyze`, 586 test) · Commit: bu WP commit'i · **Cihazda doğrulanmalı:** günlük ekle→bugün tamamla/geri al→İstanbul 00:00'da yeniden aktif; uygulama arka planda geceyi geçince resume refresh; offline hata/retry ve yeniden bağlanma; iki cihaz toggle/undo görünümü; 360 px ve klavye açık editör erişilebilirliği.
- **WP-215 — Beş ana sekmede tap-to-top** · Kod + otomatik test tamamlandı (`flutter analyze`, 587 test) · Commit: bu WP commit'i · **Cihazda doğrulanmalı:** Saat/Gruplar/Profil ve İstatistik kişisel+grup listelerinde offset>0 iken aynı taba yeniden basınca ≤300 ms'de 0; boş/build-öncesi/zaten-top no-op; Home davranışı ve nested grup kartı jestleri regresyonsuz.
- **WP-216 — Server-issued verified live session expansion** · Kod + otomatik test tamamlandı (`flutter analyze`, 596 test) · Commit: bu WP commit'i · **Staging/cihazda doğrulanmalı:** 0051 dry-run/rollback rehearsal; direct DML ile non-null `live_run_id` ve verified update/delete reddi; iki cihaz tek aktif run; üyelik değişimi/grup silimi sonrası immutable snapshot; start/pause/resume/finalize cevap kaybı ve retry; eski client normal session + mevcut XP regresyonu; 30 günlük rollout retention/cron ve reconciliation.
- **WP-220 — Verified timer/native shadow köprüsü** · Kod + otomatik test tamamlandı (`flutter analyze`, 601 test, `compileStableDebugKotlin`) · Commit: bu WP commit'i · **Cihazda/sahada doğrulanmalı:** Dart start→app-kill→native Stop tek verified session; reordered/duplicate pause-resume-finalize outbox; offline ve widget/bildirim saf-native başlangıçların stat-only mesajı; build readiness; shadow agregaları; Samsung gerçek cihaz + Android 8–13 ve API 34+ FGS/widget/bildirim/force-stop/reboot senaryoları. XP ekonomisi shadow modda değişmemeli.
- **WP-217 — Mola Düşmanı verified motoru** · Kod + otomatik sınır testleri tamamlandı (`flutter analyze`) · Commit: bu WP commit'i · **Staging'de doğrulanmalı:** 0052 syntax/RLS; exact 270 dk, pencere sınırı, çakışan/gece yarısı segmentleri; event/backfill p95; timeout cursor ilerletmeme; ikinci projector çalıştırmasında duplicate candidate olmaması. Bounded retro job tanımı production'da çalıştırılmadı.

## Tamamlanan İş Paketleri

> Ürün/cihaz kabulü almış WP'ler. Ayrıntılı tarihsel kartlar (WP-23…207) + "Son Teslim Notları" arşive taşındı → [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md). Planner yeni tamamlananı buraya **tek satır** ekler.

---

> **📦 Arşiv (2026-07-19 token optimizasyonu):** progress.md 1599→~138 satıra indirildi (2. tur: tamamlanmış/test-bekleyen WP-104…207 index satırları + eski dalga/çakışma notları temizlendi). Tarihsel WP kartları + Play detayı + park/Tamamlanan detayları + Son Teslim Notları [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md)'de. **Canlı durum bu dosyadadır** (Proje Gerçekleri + Aktif Çalışma Kaydı + aktif WP Durum Dizini). Bir WP'nin tarihsel ayrıntısı gerekirse arşivden okunur.
