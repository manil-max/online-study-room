# progress.md — İlerleme Takibi

> Son güncelleme: 2026-07-17
> Sistem: İş Paketi (WP) tabanlı, **Kalite Programı**. Kanonik program: `docs/KALITE-PROGRAMI.md`.
> Planlama: `.agents/skills/planner/SKILL.md` · Uygulama: `.agents/skills/worker/SKILL.md` · Kurallar: `.agents/AGENTS.md`.
> **"Tamamlandı" = kod DEĞİL; kullanıcı beklentisini karşılayan + cihazda güvenilir çalışan iş.** İş durum merdiveni (8 aşama) ve kanıt etiketleri (`Kodda doğrulandı` / `Cihazda doğrulanmalı` / `Ürün kararı gerekiyor`) için bkz. AGENTS.md §0.

---

## Proje Gerçekleri (ajan referansı)

- **Framework:** Flutter ^3.12 · Riverpod 3.3 · Supabase 2.15 · fl_chart
- **Uygulama kökü:** `app/` — Flutter komutları yalnız burada çalışır.
- **Repo katmanı çift:** Her arayüz `supabase/` ve `in_memory/` repository'leriyle desteklenir.
- **Migration'lar:** `supabase/migrations/` — yerelde `0001–0036` vardır. Canlı ortamda dosyanın bulunması deploy kanıtı değildir; özellikle `0034–0036` SQL + Edge secret/deploy doğrulaması bekler. Yeni migration mevcut en yüksek numaradan (`0036`) devam eder.
- **Gün sınırı:** `Europe/Istanbul`
- **RLS helper'ları:** `is_group_member(gid)`, `can_see_user_sessions(target)`, `is_group_admin(gid)`, `is_super_admin()`
- **Dashboard:** 6 sütunlu 2D matris, 19 kart türü, `grid_reflow.dart` motoru.
- **Tema:** Hazır paletler + özel palet slotları; görünür tüm yüzeyler palette bağlanmalıdır, sabit gri renk eklenmez.
- **Navigasyon hedefi:** Ana Sayfa / Saat / Gruplar / İstatistikler / Profil. Ana Sayfa günlük kullanım alanıdır; diğer alanların verisi kendi sekmelerinde eksiksiz bulunur.
- **Release:** Stable/Beta kanalı GitHub Releases ile çalışır. Yerel `v29` ve `beta-v29` tag'leri WP-104 commitini (`ff369e3`) gösterir; mevcut `main` WP-105–109'u da içerdiği halde `1.0.29+29` taşır. Bir sonraki dağıtımda versionCode mutlaka artırılır; Play production ayrı kalite kapısından geçer.
- **Kalite kapıları:** Her WP DoD'siz kapanmaz; stable release kalite kapısından geçer (AGENTS.md §3). Server-authoritative XP, RLS/sosyal profil, platform sınırları → `docs/KALITE-PROGRAMI.md`.
- **Son WP numarası:** 164 (analitik teslim düzeltmesi). **Sıradaki boş numara WP-165.**
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
- **Faz/WP:** — (bu oturum: 32-sütun grid + core test kapsamı + worker/planner skill güncellemesi)
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** — (main)
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-14 (planner uyumlama)
- **Not:** Bu oturum işleri commit'lendi: grid 32-sütun `141ed2a`, core testleri `da7bdd6`, skill docs `1afba2d`. ⚠️ WP-65 karar dokümanı (`docs/AYLIK-RAPOR-KARAR.md`) önceki Claude oturumunda yazıldı ama **COMMIT'LENMEDİ** (untracked); kararı WP-69 zaten uyguladı → ürün API/DNS kararı bekliyor.

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** — (main)
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-17 (Europe/Istanbul)
- **Not:** Play Store production programı WP-110–124 olarak planlandı; kanonik belgeler hizalandı. `OPTIMIZATIONS.md` kapsam dışı bırakıldı.

### Grok Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** main
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-18 (Europe/Istanbul)
- **Not:** WP-151–154 park. Sırada 155+QA+Play.


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

> Bu tablo ajanların tek bakışta durum ve bağımlılık görmesi içindir. `[~] Test için bekliyor` satırlarının kanonik kabul kanıtı aşağıdaki **Test için bekleyenler** bölümündedir; eski ayrıntılı uygulama kartları yalnız tarihsel bağlamdır ve yeniden uygulanmaz. Yeni kod işi olarak yalnız `[ ] Bekliyor` satırları claim edilir.

| WP | Durum | Kısa kapsam | Bağımlılık |
|---|---|---|---|
| WP-104 | [x] Tamamlandı | Presence bayatlama (updatedAt) + stop oturum kaydı sırası | ürün kabulü 2026-07-18 |
| WP-105 | [x] Tamamlandı | XP oturum bitince kabuk lifecycle tetik | ürün kabulü 2026-07-18 |
| WP-106 | [x] Tamamlandı | watchMembers Map + 0034 active index | 0034 uygulandı ✓ |
| WP-107 | [x] Tamamlandı | Manuel oturum İstanbul gün sınırı + UTC yazım | ürün kabulü 2026-07-18 |
| WP-108 | [~] Edge deploy bekliyor | Aylık rapor retry + cron URL (0035) | 0035 uygulandı; **Edge deploy + cron** kaldı |
| WP-109 | [x] Tamamlandı | Güvenlik 0036 (IDOR/profiles) | 0036 uygulandı ✓ |
| WP-110 | [x] Tamamlandı | Play flavor + installer izolasyonu | kod+test; AAB WP-122 |
| WP-111 | [~] Console/URL bekliyor | Legal merkez + politikalar + telemetri | kod ✓; canlı gizlilik HTTPS URL host |
| WP-112 | [x] Tamamlandı | 0037 hesap silme RPC | 0037 uygulandı ✓ |
| WP-113 | [~] Edge deploy bekliyor | purge-accounts Edge (hesap silme worker) | 0037 ✓; **functions deploy + CRON** kaldı |
| WP-114 | [x] Tamamlandı | Hesap silme UI + web bilgilendirme | ürün kabulü 2026-07-18 |
| WP-115 | [x] Tamamlandı | 0038 UGC şema/RPC | 0038 uygulandı ✓ |
| WP-116 | [x] Tamamlandı | report sheet + moderation repo | WP-125 ile bağlandı |
| WP-117 | [x] Tamamlandı | Admin UGC kuyruk sekmesi | ürün kabulü 2026-07-18 |
| WP-118 | [x] Tamamlandı | TimerActionReceiver exported=false | ürün kabulü 2026-07-18 |
| WP-119 | [~] Console bekliyor | DATA-SAFETY.md | Play Console Data Safety formu |
| WP-120 | [ ] Bekliyor | Store listing varlıkları (ekran görüntüsü vb.) | ürün/tasarım |
| WP-121 | [~] Play ops bekliyor | PROD-DEPLOY-RUNBOOK + RLS-SMOKE | Edge deploy sonrası canlı ops |
| WP-122 | [~] Play build bekliyor | PLAY-BUILD-RUNBOOK (AAB play flavor) | AAB üret + versionCode |
| WP-123 | [ ] Bekliyor | Cihaz QA matrisi (P0 kanıt) | fiziksel cihaz |
| WP-124 | [~] Play GO bekliyor | PLAY-RELEASE-GATE şablonu | son kapı: GO imzası |
| WP-125 | [x] Tamamlandı | UGC Rapor + Engel UI giriş noktaları (sohbet/profil) | ürün kabulü 2026-07-18 |
| WP-126 | [x] Tamamlandı | Engellenen kullanıcı mesaj/presence filtreleme | ürün kabulü 2026-07-18 |
| WP-127 | [~] Edge deploy bekliyor | purge-accounts sonsuz retry düzeltmesi | WP-113 ile deploy |
| WP-128 | [x] Tamamlandı | Play flavor DISTRIBUTION_CHANNEL zorlaması | kod+test; AAB smoke WP-122 |
| WP-129 | [x] Tamamlandı | Engellenen kullanıcılar ekranı (unblock UI) | ürün kabulü 2026-07-18 |
| WP-130 | [x] Tamamlandı | Rapor sheet detay alanı | ürün kabulü 2026-07-18 |
| WP-131 | [x] Tamamlandı | Analyze/lint sertleştirme (0 issue) | — |
| WP-132 | [~] Console bekliyor | DATA-SAFETY.md gerçek veri envanteri | Play Console formu |
| WP-133 | [x] Tamamlandı | Widget & dinamik panel analizi → 134–137 | analiz uygulandı |
| WP-134 | [~] Cihaz kontrolü bekliyor | 1×1 widget Chronometer her boyutta | telefonda widget/saat testi |
| WP-135 | [~] Cihaz kontrolü bekliyor | Toggle commit + idle sıfırlama (TimerStateStore) | telefonda 20 tur start/stop |
| WP-136 | [~] Cihaz kontrolü bekliyor | Reconcile SSOT / engine-scope broadcast | telefonda çift yönlü senkron |
| WP-137 | [~] Cihaz kontrolü bekliyor | Dinamik panel P2 (usesChronometer + Mola/Durdur) | telefonda bildirim davranışı |
| WP-138 | [x] Tamamlandı | Sürüm notları v28/v29 + taslak v30 (TR/EN) | ürün kabulü 2026-07-18 |
| WP-139 | [x] Tamamlandı | l10n parity + hardcoded/admin + native string denetim | ürün kabulü 2026-07-18 |
| WP-140 | [x] Tamamlandı | Erişilebilirlik (tooltip/Semantics/48dp) | ilk tur; TalkBack cihaz smoke opsiyonel |
| WP-141 | [x] Tamamlandı | Tema-bağlama / sabit renk denetimi | ürün kabulü 2026-07-18 |
| WP-142 | [~] Analiz teslim | Performans & başlangıç profili | docs/perf |
| WP-143 | [~] Analiz teslim | Güvenlik derin denetim 2 | docs/security |
| WP-144 | [~] Analiz teslim | Offline-first dayanıklılık | docs/sync |
| WP-145 | [~] Analiz teslim | Test kapsam boşluğu | docs/test |
| WP-146 | [~] Test için bekliyor | Istanbul/DST gün-sınırı sertleştirme | birim test |
| WP-147 | [~] Test için bekliyor | Hata durumları + yenile (kayıt/ders/stats) | cihaz |
| WP-148 | [~] Test için bekliyor | Regresyon süpürme raporu | docs/debug |
| WP-149 | [~] WP-156’ya bağlandı | Streak+heatmap → analitik kart | WP-156 |
| WP-150 | [~] WP-156’ya devredildi | Stats derinleştirme → büyük plan | WP-156 |
| WP-151 | [~] Test için bekliyor | Onboarding 4 adım skip/izin/grup | Cihazda doğrulanmalı |
| WP-152 | [~] Test için bekliyor | Veri dışa aktarma JSON | Cihazda doğrulanmalı |
| WP-153 | [~] Test için bekliyor | Akıllı hatırlatma seri/haftalık | Cihazda doğrulanmalı |
| WP-154 | [~] Test için bekliyor | Level/quest/cosmetics + 0043 | SQL Editor + cihaz |
| WP-155 | [ ] Bekliyor (Track D) | Ek dil paketleri + RTL | C sonrası |
| WP-156 | [~] Plan uygulandı (flag kapalı) | İstatistik & Gruplar analitik plan | docs/features |
| WP-157 | [~] Test için bekliyor | Grafik primitives gauge/stacked/radar/area | `2c7bc91` |
| WP-158 | [~] Test için bekliyor | Analytics grid shell + prefs + flag | `5f8f1d5` |
| WP-159 | [~] Test için bekliyor | 22 kart registry (kişisel sarmalayıcılar) | `8d4fff9` |
| WP-160 | [~] Test için bekliyor | goalGauge/streak/compare/insight | `8d4fff9` |
| WP-161 | [~] Test için bekliyor | 0040/0041 RPC + grup kartları | SQL Editor |
| WP-162 | [~] Test için bekliyor | Kart ekle/çıkar + Stats flag entegrasyon | `4b4d711` |
| WP-163 | [~] Test için bekliyor | AnalyticsPeriod year/custom/kıyas | UI bar kısmi |
| WP-164 | [~] Test için bekliyor | Analitik teslim düzeltmesi (ızgara/reflow/veri/0042) | `Cihazda doğrulanmalı` |

> **2026-07-14 proje denetimi:** Serbest sürükle-bırak ızgara, canlı grup hedefi ve saat stilleri **zaten kodda uygulanmış** (backlog stale idi; geçici WP-72/73/75 iptal).
>
> **2026-07-17 ürün/cihaz QA kapanışı:** WP-76/77/78/79/80/81, WP-84–89, WP-92/93/94/95/97, WP-100, WP-103 — kullanıcı cihaz/ürün testleri bitti → **Tamamlanan**.
>
> **Kalan gerçek açık işler:**
> - **Ürün kararı (kod değil, senin kararın):** WP-66 hesap silme retention · WP-67 grafik türleri · WP-69 aylık rapor için DNS + Resend API key.
> - **Yeni öncelik:** Play Store production programı **WP-110–124**. Park: WP-104–109 cihaz/canlı ops + WP-110–119/121–122/124 test/ops.

> **Planlama notu:** WP-39 iptal; WP-48/49/50 kaldırıldı; geçici WP-72/73/74/75 (2026-07-14) zaten-yapılmış/yanlış açıldığı için iptal edildi. Sorun çıkarsa ayrı debug/release WP'si açılır.

> **Küresel dil programı ortak sözleşmesi:** İngilizce şablon/varsayılan (`en`), Türkçe ikinci dil (`tr`). Yalnız sistem dil kodu `tr` ise Türkçe; diğer her locale İngilizce. Üretilen l10n kodu elle düzenlenmez/commit edilmez. Tüm WP'lerde migration/RLS etkisi yok; sır/PII çeviri dosyasına girmez; gün sınırı `Europe/Istanbul` kalır. Aynı anda en fazla iki çalışma hattı açılır.

> **Çakışma matrisi:** ✅ Wave 1: WP-82 + WP-83. Wave 2: WP-84 + WP-88 (WP-83 sonrası). Wave 3: WP-85 + WP-86. Wave 4: WP-87 tek başına veya bitmiş WP-88'in ardından ikinci ayrık hat. Wave 5: WP-89 tek seri kapı. ARB dosyalarına yalnız WP-82 (seed), sonra WP-84, en son WP-89 yazar; UI worker'ları ARB'yi salt okunur kullanır.

#### Tarihsel uygulama kartı — WP-103 (kodlandı; yeniden claim etme) 💥
- **Program/Faz:** Debug · Faz 0 (kararlılık) · **Ajan:** Grok · **Durum:** [x] Tamamlandı (cihaz/ürün kabulü 2026-07-17) · **Model:** 🔴 Opus (yayın + native FGS riski)
- **Problem:** beta-v19'dan (commit `a2688de`, WP-76) beri **Android 10–13 çalıştıran her cihazda** kronometreyi başlatmak da durdurmak da uygulamayı çökertiyor ("Odak Kampı ile ilgili bir sorun oluştu" dialogu). Kök neden: [AndroidManifest.xml](app/android/app/src/main/AndroidManifest.xml) servisi yalnızca `foregroundServiceType="specialUse"` beyan ediyor, ama [StudyTimerService.kt](app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt) `startForegroundCompat` içinde API 29–33 dalı hâlâ `FOREGROUND_SERVICE_TYPE_DATA_SYNC` geçiyor. Android, tip manifestin alt kümesi değilse `IllegalArgumentException` fırlatır; servis `startForegroundService` borcunu ödeyemeden ölür → yakalanamayan `RemoteServiceException` ile süreç öldürülür. S23 (Android 14+, SPECIAL_USE dalı) etkilenmez → cihaz farkı tam buradan. Not 20 + A51 (ikisi de final Android 13) etkilenir.
- **Kapsam dışı:** Presence bayatlama açığı ve durdurmada oturum-kaydı sağlamlaştırma (→ WP-104). Bildirim tasarımı/panel içeriği değişmez. Yeni foreground service türü mimarisi tasarlanmaz — yalnız tip beyanı hizalanır.
- **SAHİP dosyalar (yaz):**
  - `app/android/app/src/main/AndroidManifest.xml`
  - `app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt`
  - `app/pubspec.yaml` (yalnız `version:` bump)
- **DOKUNMA (oku, değiştirme):** `app/lib/**` (Dart akışı doğru, dokunulmaz), `app/lib/data/providers/presence*` (WP-104 sahibi), diğer native receiver/widget dosyaları.
- **Adımlar:**
  - [ ] **Çözüm (önerilen — Seçenek A):** Manifestte servisi `android:foregroundServiceType="dataSync|specialUse"` yap. Böylece API 29–33 dalı DATA_SYNC (0x01) geçer → `dataSync|specialUse` (0x40000001) alt kümesi ✓; API 34+ dalı SPECIAL_USE geçer → alt küme ✓. İki izin (`FOREGROUND_SERVICE_DATA_SYNC` + `FOREGROUND_SERVICE_SPECIAL_USE`) zaten beyanlı.
  - [ ] `<property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" …>` olduğu gibi kalır (specialUse hâlâ beyanlı olduğu için Play Console gereksinimi korunur).
  - [ ] API 33 emülatörde tekrar-üretim → düzeltme öncesi çökme + `not a subset of foregroundServiceType attribute` logcat imzasını doğrula; düzeltme sonrası başlat/durdur çökmesiz + bildirim akıyor.
  - [ ] Android 15 (API 35) cihaz/emülatörde regresyon: kod SPECIAL_USE dalına girer, dataSync 6-saat sınırı çalışan tipe uygulandığı için etkilenmez — doğrula.
  - [ ] `flutter analyze` 0, tam `flutter test` yeşil (Dart değişmedi, native değişiklik testleri etkilemez ama regresyon için çalıştır).
  - [ ] `version:` bump + imzalı release APK + GitHub Release (stable). Sürüm önerisi `1.0.29+29` / tag `v29` — **Ürün kararı**.
- **Veri/Migration etkisi:** Yok. Geri alma bu iki dosyanın commitidir.
- **RLS/Güvenlik:** Yok. Sır yok. Foreground servis kullanıcı-başlatımlı görünür sayaç olarak kalır.
- **Edge-case'ler:** API ≤28 (tip parametresiz `startForeground`), API 29–33 (DATA_SYNC), API 34 (SPECIAL_USE), API 35 (SPECIAL_USE + dataSync cap muafiyeti); uygulama-kapalı bildirim/widget Durdur (getForegroundService yolu da aynı `startForegroundCompat`'i çağırır — düzeltme oradaki çökmeyi de kapatır); mola başlat/bitir yolları da aynı compat'ı kullanır.
- **Kabul (ölçülebilir):** Android 13 gerçek cihazda (Not 20 veya A51, ya da API 33 emülatör) başlat→arka plan→aç→durdur döngüsü **0 çökme**; sayaç bildirimi görünür ve süre akar; logcat'te `IllegalArgumentException`/`RemoteServiceException` yok. Android 14+ (S23) regresyonsuz. `flutter analyze` 0. Stable APK GitHub Release'de yayınlanır ve aile cihazlarında doğrulanır (`Cihazda doğrulanmalı`).
- **Tuzaklar:** **Seçenek B (alternatif):** manifesti specialUse-only bırakıp API 29–33 dalında tipsiz `startForeground(id, notification)` çağırmak — pre-14 cihazlar runtime tip gerektirmediği için bu da çalışır; ama bazı OEM bildirim yüzeyleri tipi kullandığından Seçenek A tercih edilir. · specialUse `<property>`'yi silme (Play Console reddeder). · Yalnız kodu düzeltip manifesti unutmak (ya da tersi) → yine uyumsuzluk. · Android 15'te dataSync beyanının 6-saat cap getireceği yanılgısı — cap çalışan tipe uygulanır, kod 15'te SPECIAL_USE kullanır.
- **Dal önerisi:** `wp103-fgs-tip-cokme`

> **Çakışma matrisi (WP-103):** ✅ Aktif dosya yazan lane yok (tüm lane'ler Boşta; Codex lane'i WP-99 için stale-aktif ama parkta ve SAHİP yüzeyi `timer_notification.xml`/l10n — bu WP native FGS tipine dokunur, kesişim yok). `AndroidManifest.xml` sıcak dosya ama şu an ona giren aktif WP yok. WP-104 aynı çökme akışının Dart tarafını sağlamlaştırır; ayrı SAHİP yüzeyi (presence/study_providers) → **paralel güvenli**, yalnız aynı cihaz QA turunda birlikte doğrulanması önerilir.

#### Tarihsel uygulama kartı — WP-104 (kodlandı; yeniden claim etme) 🩹
- **Program/Faz:** Debug · **Ajan:** Grok · **Durum:** [~] Test için bekliyor · **Model:** 🟣 Pro
- **Problem:** WP-103'teki çökmenin iki veri yan-hasarı, çökme düzelse de latent kalır: (1) Yerel yazılan presence nesneleri `updatedAt=null` üretilip offline cache'e öyle saklanıyor ([offline_cache_store.dart:204](app/lib/data/repositories/offline/offline_cache_store.dart:204)); [applyPresenceStaleness](app/lib/data/providers/presence_providers.dart:62) `updatedAt==null` satırları **hiç bayatlatmıyor** → çöken/kapanan cihazın kendi ekranında "hâlâ çalışıyor" kalıcı görünebilir. (2) Uygulama-içi Durdur'da `_recordSession` ağ çağrısı, native durdurma komutundan sonra yarışır ([study_providers.dart:734](app/lib/data/providers/study_providers.dart:734)); süreç erken ölürse oturum süresi kaydedilmeden kaybolur (native `STOP_SILENT` bilerek kuyruğa yazmaz).
- **Kapsam dışı:** FGS tip düzeltmesi (→ WP-103). Presence heartbeat aralığı/eşik değerleri değişmez. Yeni tablo/kolon yok.
- **SAHİP dosyalar (yaz):**
  - `app/lib/data/repositories/offline/offline_cache_store.dart`
  - `app/lib/data/providers/presence_providers.dart` (yalnız staleness mantığı, gerekirse)
  - `app/lib/data/providers/study_providers.dart` (yalnız `stop()` sıralaması, gerekirse)
  - ilgili testler (`test/**presence**`, `test/**timer**`)
- **DOKUNMA (oku, değiştirme):** native `**/*.kt`, `AndroidManifest.xml` (WP-103 sahibi), `presence.dart` modeli mümkünse salt-okunur.
- **Adımlar:**
  - [ ] Yerel presence yazımında `updatedAt`'i `DateTime.now()` ile doldur (cache'e null yazma) → böylece bayatlama eşiği yerel satırlara da uygulanır. Alternatif: `applyPresenceStaleness` içinde `updatedAt==null` satırları için güvenli bir varsayım (ör. yerel kullanıcı için timer state'ten türet) — hangisi seçilirse WP'de gerekçelendir.
  - [ ] `stop()` içinde oturum kaydını (`_recordSession`) native durdurma komutundan **önce** ya da en azından çökmeye dayanıklı sırada çalıştır; app-içi durdurmada süre kaybı olmadığını testle kanıtla.
  - [ ] `flutter analyze` 0; presence staleness + timer stop testleri yeşil (null updatedAt bayatlama senaryosu dahil).
- **Veri/Migration etkisi:** Yok. Geri alma bu istemci commitidir.
- **RLS/Güvenlik:** Yok. Server-authoritative oturum kaydı korunur (yalnız çağrı sırası sağlamlaştırılır).
- **Edge-case'ler:** Çevrimdışı yazım (kuyruk), grup henüz yüklenmemiş, çoklu cihaz aynı kullanıcı, uygulama öldürülmesi Durdur'un tam ortasında.
- **Kabul (ölçülebilir):** Yerel kullanıcı sayacı durdurunca kendi ekranında ≤ eşik (70 sn) içinde "çalışıyor" temizlenir; app-içi Durdur'da oturum süresi %100 kaydedilir (test); `flutter analyze` 0, ilgili + tam test yeşil.
- **Tuzaklar:** `updatedAt`'i yerelde doldurmak, gerçekten bayat bir satırı taze göstermemeli (yalnız yerel-kaynaklı satır için); sunucudan gelen satırların `updated_at`'i her zaman kazanmalı. Oturum kayıt sırasını değiştirirken çift kayıt (native kuyruk + Dart) üretmemek.
- **Dal önerisi:** `wp104-presence-oturum-saglamlik`

> **Çakışma matrisi (WP-104):** ✅ WP-103 ile ortak SAHİP dosyası yok (WP-103 = native+manifest+pubspec; WP-104 = Dart presence/study/cache). `study_providers.dart` sıcak ama şu an ona giren aktif lane yok. Paralel güvenli; ürün isterse önce WP-103 stable'a çıkar, WP-104 bir sonraki yayına eklenir.

---

> **OPTIMIZATIONS.md kaynağı (2026-07-17, Grok taraması):** Aşağıdaki WP-105…109, `OPTIMIZATIONS.md`'deki bulgulardan **koda karşı doğrulanmış** olanlardır. Doğrulama (Claude): B1 gerçek/yüksek etki; B3 perf gerçek ama crash şiddeti abartılı (`ids` `rows`'tan türediği için `firstWhere` her zaman eşleşir); B4 mekanik gerçek ama cihaz-TZ'ye bağlı. Düşük değerli perf maddeleri (R8 ticker gate, R9 summary debounce, R11 ölü `watchGroupSessions`) küçük kullanıcı tabanı için ** WP açılmadı**; ileride tek "temizlik" WP'sinde toplanabilir. B5/B8 migration deploy durumuna bağlı; S1 süre hard-cap **ürün kararı** ister (KALITE-PROGRAMI §11'e taşınmalı).

#### Tarihsel uygulama kartı — WP-105 (kodlandı; yeniden claim etme) 🏆
- **Program/Faz:** Başarım · Debug · **Ajan:** Grok · **Durum:** [~] Test için bekliyor · **Model:** 🟣 Pro
- **Problem:** Kullanıcı çalışmayı bitirdiğinde saatlik 50 XP ve başarılar sunucu ledger'ına **yalnızca profil/başarım ekranı açılırsa** yazılıyor. Tek tetik `gamificationProgressSyncProvider` ve o `FutureProvider.autoDispose` — yalnız [gamification_card.dart:19](app/lib/features/profile/widgets/gamification_card.dart:19) ve [social_profile_screen.dart:47](app/lib/features/profile/social_profile_screen.dart:47) izliyor. `notifySessionCompletedForAchievementsProvider` ([achievement_provider.dart:71](app/lib/data/providers/achievement_provider.dart:71)) tanımlı ama **hiçbir yerden çağrılmıyor** (grep ile doğrulandı). 0033'te XP DB trigger'ı değil, istemci-çağrılı `process_achievement_event` RPC'sidir → profili hiç açmayan kullanıcı XP/rozet kaybeder, "neden XP yok?" şikayeti buradan.
- **Kapsam dışı:** XP formülü/başarım kuralları değişmez (server-authoritative korunur). Confetti/animasyon yeniden tasarlanmaz. `study_providers.dart` sayaç mantığına dokunulmaz (WP-104 territoryi).
- **SAHİP dosyalar (yaz):**
  - `app/lib/data/providers/gamification_providers.dart` (autoDispose kaldır / keep-alive tetik)
  - `app/lib/core/navigation/home_shell.dart` (oturum tamamlanınca tek-sefer `session_completed` tetiği — presence_lifecycle gibi kabuk-ömürlü)
  - ilgili testler (`test/**gamification**`, `test/**achievement**`)
- **DOKUNMA (oku, değiştirme):** `app/lib/data/providers/study_providers.dart` (WP-104), `supabase/migrations/**` (0033 doğru, dokunulmaz), profil UI dosyaları (izleme zaten var).
- **Adımlar:**
  - [ ] Oturum listesi değişince (yeni tamamlanmış oturum) `process_achievement_event('session_completed')` çalışacak **kabuk-ömürlü** bir tetik ekle — profil ekranından bağımsız. Ör: HomeShell'de `ref.listen(userSessionsProvider, ...)` ile debounce'lu tek sefer çağrı, veya sync provider'ı `keepAlive` yapıp kabukta izle.
  - [ ] Idempotency korunur (`event_key` aynı oturum için iki kez XP vermez — 0033 zaten sağlıyor); mükerrer tetik güvenli olmalı.
  - [ ] Çevrimdışı/kimlik-hazır-değil durumunda sessiz geç (mevcut catch deseni).
  - [ ] `flutter analyze` 0; oturum-bitti→XP testi (profil açılmadan ledger'a yazıldığını doğrula) yeşil.
- **Veri/Migration etkisi:** Yok (0033 mevcut RPC'yi kullanır). Geri alma bu istemci commitidir.
- **RLS/Güvenlik:** Server-authoritative; istemci XP hesaplamaz, yalnız olayı tetikler. `process_achievement_event` authenticated'a grant'lı (0033).
- **Edge-case'ler:** Aynı anda birden çok oturum, hızlı ardışık start/stop, çevrimdışı kuyruk sonrası flush, cold start restore, kullanıcı yokken tetik.
- **Kabul (ölçülebilir):** Bir oturum tamamlandıktan sonra **profil ekranı hiç açılmadan** ≤ birkaç sn içinde `process_achievement_event` çağrılır ve saatlik XP ledger'a yazılır (test + Supabase kanıtı); aynı oturum iki kez XP vermez; `flutter analyze` 0, ilgili + tam test yeşil.
- **Tuzaklar:** Tetiği her stream tick'inde çalıştırıp RPC spam'i üretmek (B10 ile aynı tuzak → debounce/coalesce); `study_providers.dart`'a girip WP-104 ile çakışmak; autoDispose'u kaldırırken bellek sızıntısı yaratmak.
- **Dal önerisi:** `wp105-xp-oturum-tetik`

#### Tarihsel uygulama kartı — WP-106 (kodlandı; yeniden claim etme) 🧹
- **Program/Faz:** Debug/Perf · **Ajan:** Grok · **Durum:** [~] Test için bekliyor · **Model:** 🔵 Sonnet
- **Problem:** (R3/B3) [supabase_group_repository.dart:153](app/lib/data/repositories/supabase/supabase_group_repository.dart:153) `watchMembers` her profil için `rows.firstWhere(... )` (O(n·m), `orElse` yok). Crash pratikte imkânsız (`ids` `rows`'tan türer) ama gelecekteki bir değişiklikte StateError riski + gereksiz CPU. (R12) `group_members(group_id) WHERE left_at IS NULL` üzerinde partial index yok; RLS helper'ları ve `group_daily_totals` bu filtreyi sık kullanıyor.
- **Kapsam dışı:** watchMembers'ın davranış/semantiği değişmez (aynı liste, aynı `isActive`). Başka repository metodları refaktör edilmez.
- **SAHİP dosyalar (yaz):**
  - `app/lib/data/repositories/supabase/supabase_group_repository.dart`
  - `supabase/migrations/0034_group_members_active_index.sql` (yeni)
  - ilgili repository testi
- **DOKUNMA (oku, değiştirme):** diğer repository'ler, `in_memory` eşdeğeri (davranış zaten aynı).
- **Adımlar:**
  - [ ] `rows`'u bir kez `Map<userId, row>`'a çevir; profil eşleştirmesini map'ten yap; eşleşmezse güvenli fallback (`isActive=false`, StateError yok).
  - [ ] `create index concurrently if not exists idx_group_members_active on public.group_members (group_id) where left_at is null;` migration'ı ekle (geri alma: `drop index`).
  - [ ] `flutter analyze` 0; üye listesi testinde aynı çıktı + eksik-profil senaryosunda crash yok.
- **Veri/Migration etkisi:** Yalnız index ekleme (semantik yok); `concurrently` ile kilit-suz. Geri alma: `drop index if exists idx_group_members_active`.
- **RLS/Güvenlik:** Etki yok; index yalnız performans.
- **Edge-case'ler:** Boş grup, soft-left üye, silinmiş profil, realtime ara durum.
- **Kabul (ölçülebilir):** Üye listesi öncekiyle bit-aynı; `EXPLAIN` membership/`group_daily_totals` sorgularında index kullanımı; `flutter analyze` 0, test yeşil. Migration kullanıcı tarafından SQL Editor'da uygulanır (Proje Gerçekleri kuralı).
- **Tuzaklar:** `concurrently`'yi transaction içinde çalıştırmak (Postgres reddeder); `isActive` fallback'ini yanlış kurup aktif üyeyi pasif göstermek.
- **Dal önerisi:** `wp106-uyeler-map-index`

#### Tarihsel uygulama kartı — WP-107 (kodlandı; yeniden claim etme) 🕛
- **Program/Faz:** Debug · **Ajan:** Grok · **Durum:** [~] Test için bekliyor · **Model:** 🟣 Pro (TZ + hot model dosyası)
- **Problem:** [manual_session_dialog.dart:21](app/lib/features/profile/widgets/manual_session_dialog.dart:21) `manualSessionRange` aralığı **cihaz yerel saatiyle** (`DateTime.now()`, `DateTime(y,m,d,…)`) kuruyor; [study_session.dart:52](app/lib/data/models/study_session.dart:52) `toMap` `start.toIso8601String()`'i `.toUtc()` olmadan yazıyor. Ürün gün sınırı `Europe/Istanbul` (`StudySession.day => istanbulDay(start)`). Cihaz TZ ≠ İstanbul veya gece 00:00 civarı manuel giriş yanlış takvim gününe düşebilir → "bugün" toplamı/streak/heatmap kayması.
- **Kapsam dışı:** Canlı sayaç kaydı (`_recordSession`) gerçek instant kullanır, ayrı ele alınmaz. Gün-sınırı motoru (`istanbul_calendar.dart`) yeniden yazılmaz.
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/profile/widgets/manual_session_dialog.dart`
  - `app/lib/data/models/study_session.dart` (yalnız `toMap` UTC yazımı — **sıcak model dosyası, dikkat**)
  - ilgili testler (manuel aralık + gün sınırı, TZ mock)
- **DOKUNMA (oku, değiştirme):** `istanbul_calendar.dart`, canlı sayaç akışı, repository katmanı.
- **Adımlar:**
  - [ ] Manuel aralığı İstanbul wall-clock ile kur (cihaz TZ'sinden bağımsız gün/saat).
  - [ ] `toMap`'te `start`/`end`'i `toUtc().toIso8601String()` ile yaz (Postgres timestamptz round-trip tutarlı). Canlı yol da bundan geçtiği için instant'ların bozulmadığını doğrula.
  - [ ] `flutter analyze` 0; cihaz TZ = America/New_York mock'uyla gece-yarısı manuel girişin doğru İstanbul gününe düştüğünü testle.
- **Veri/Migration etkisi:** Yok (yazım formatı; mevcut satırlar timestamptz olarak zaten instant tutar). Geri alma bu istemci commitidir.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Gece 23:00–01:00 arası giriş, cihaz TZ İstanbul dışı, DST geçişleri, süre > günün geçen kısmı (mevcut 00:00 kenetleme korunmalı).
- **Kabul (ölçülebilir):** TZ-mock testinde manuel oturum her zaman seçilen İstanbul gününe düşer; `toMap` UTC üretir; canlı sayaç süreleri regresyonsuz; `flutter analyze` 0, test yeşil.
- **Tuzaklar:** `toUtc` değişikliğinin canlı sayaç/istatistik hesabını kaydırması (instant korunur, ama testle kanıtla); yalnız dialog'u düzeltip `toMap`'i unutmak; hedef kitle çoğu İstanbul TZ olduğu için düşük pratik şiddet — öncelik buna göre.
- **Dal önerisi:** `wp107-manuel-oturum-tz`

#### Tarihsel uygulama kartı — WP-108 (kodlandı; yeniden claim etme) 📧
- **Program/Faz:** Ops/Backend · **Ajan:** Grok · **Durum:** [~] Test için bekliyor · **Model:** 🔵 Sonnet · **Bağımlılık:** Özelliğin canlı olup olmadığı ürün kararı (WP-69 DNS/Resend key)
- **Problem:** (B2) `supabase/functions/send-report/index.ts` ilk hatada job'u `status='failed'` yapıyor ama sonraki cron yalnız `.eq('status','pending')` seçiyor → `retry_count` anlamsız, geçici Resend/API hatasında o ayın raporu kalıcı kaçar. (B8) `0030_monthly_report_infrastructure.sql` cron `http://localhost:54321/...` URL kullanıyor → prod'da collector hiç tetiklenmez.
- **Kapsam dışı:** Rapor içeriği/tasarımı, DNS/Resend kurulumu (WP-69 ürün kararı). Yeni tablo yok.
- **SAHİP dosyalar (yaz):**
  - `supabase/functions/send-report/index.ts`
  - `supabase/migrations/0035_cron_report_url_fix.sql` (yeni — cron URL'yi prod fonksiyon URL'sine güncelle)
  - `supabase/functions/collect-reports/index.ts` (gerekirse)
- **DOKUNMA (oku, değiştirme):** app/lib (istemci etkisi yok), diğer edge fonksiyonlar.
- **Adımlar:**
  - [ ] Job seçimini `status in ('pending','failed') and retry_count < 3` yap (veya failed'i tekrar pending'e al); retry mantığını test/log ile doğrula.
  - [ ] Cron `net.http_post` URL'sini gerçek prod fonksiyon URL'siyle değiştir (proje ref'i kullanıcıdan alınır; sırrı migration'a gömme, `current_setting`/secret kullan).
  - [ ] Yayın öncesi sıralama: cron/secret ayarı yapılmadan fonksiyon davranışı değişirse mail akışı kırılabilir — S2 ile birlikte sıralı yürüt.
- **Veri/Migration etkisi:** Cron tanımı güncellenir; geri alma eski cron URL'sine dönüştür. Kullanıcı SQL Editor'da uygular.
- **RLS/Güvenlik:** URL/secret migration'a düz gömülmez; §8 S2 ile birlikte ele alınır.
- **Edge-case'ler:** Job zaten abandoned, retry_count sınırı, Resend rate limit, cron çift tetik.
- **Kabul (ölçülebilir):** Geçici hata sonrası job sonraki cron'da yeniden denenir (retry_count artar, 3'te durur); prod cron doğru URL'yi çağırır (log kanıtı). **Önkoşul:** özellik canlıya alınacaksa; değilse bu WP ertelenir.
- **Tuzaklar:** Prod URL/secret'i migration'a plaintext yazmak; retry'ı sonsuz döngüye açmak; S2 auth'u düzeltmeden URL'yi public bırakmak.
- **Dal önerisi:** `wp108-aylik-rapor-ops`

#### Tarihsel uygulama kartı — WP-109 (kodlandı; yeniden claim etme) 🛡️
- **Program/Faz:** Güvenlik · Play Store öncesi · **Ajan:** Grok · **Durum:** [~] Test için bekliyor · **Model:** 🔴 Opus (güvenlik + sıralama riski) · **Bağımlılık:** WP-108 ile ops sırası (S2)
- **Problem:** `OPTIMIZATIONS.md §8`: (S2) rapor Edge Function'ları yalnız Authorization varlığını kontrol ediyor + service_role env → public ise Critical. (S3) `get_user_monthly_stats` SECURITY DEFINER + authenticated → IDOR (başkasının istatistiği). (S4) `profiles_select using (true)` → enumeration. (B7) `regenerateInviteCode`/bazı update'ler 0 satırda sessiz başarı (RLS admin değilse "yenilendi" sanılır).
- **Kapsam dışı:** S1 istemci süre hard-cap (ürün max-süre kararı ister → KALITE-PROGRAMI §11). Büyük RLS yeniden tasarımı.
- **SAHİP dosyalar (yaz):**
  - `supabase/functions/send-report/index.ts`, `supabase/functions/collect-reports/index.ts` (cron secret doğrulaması)
  - `supabase/migrations/0036_security_hardening.sql` (yeni — S3 self/admin guard, S4 profiles_select daraltma)
  - `app/lib/data/repositories/supabase/supabase_group_repository.dart` (B7 `.select().single()` / count kontrolü)
- **DOKUNMA (oku, değiştirme):** UI dosyaları (profiles_select daraltması UI bağımlılığını kırmamalı — önce grep).
- **Adımlar:**
  - [ ] **S2 (önce):** Edge fonksiyonlarına cron/shared-secret doğrulaması ekle; **cron job'u secret ile güncelledikten SONRA** deploy et (yoksa mail ölür — WP-108 ile sıralı).
  - [ ] **S3:** `get_user_monthly_stats`'e self-or-admin guard (SQL).
  - [ ] **S4:** `profiles_select using (true)`'yu daralt (grup üyeliği/görünürlük bazlı); önce UI'nın hangi profilleri okuduğunu grep'le, kırılan yer varsa RPC'ye taşı.
  - [ ] **B7:** `regenerateInviteCode` ve benzeri update'lere `.select().single()`/etkilenen-satır kontrolü ekle; RLS reddinde kullanıcıya hata göster.
  - [ ] `flutter analyze` 0; RLS/edge davranış testleri (yetkisiz erişim reddedilir, yetkili geçer).
- **Veri/Migration etkisi:** RLS politikaları + fonksiyon guard'ları. Geri alma her politika için ayrı `drop/replace`. Kullanıcı SQL Editor'da sırayla uygular.
- **RLS/Güvenlik:** Bu WP'nin özü. Değişiklikler mevcut meşru akışları kırmamalı; her kısıtlama testle doğrulanır.
- **Edge-case'ler:** Süper admin, grup admini vs üye, kendi profili vs başkası, davet kodu yenileme yetkisiz, public grup keşfi (WP-92/93) profiles_select'e bağımlıysa dikkat.
- **Kabul (ölçülebilir):** Yetkisiz kullanıcı başkasının aylık istatistiğini/profil enumerasyonunu **alamaz** (test); yetkisiz davet-kodu yenileme sessiz başarı vermez; meşru akışlar regresyonsuz; `flutter analyze` 0. Play Store öncesi güvenlik kapısı.
- **Tuzaklar:** `profiles_select` daraltmasının kamp ateşi/üye listesi/keşif UI'sını kırması (WP-92/93 ile kesişim — önce grep); S2'yi cron secret'i ayarlamadan deploy edip maili öldürmek; DEFINER fonksiyonda guard'ı yanlış kurup admini kilitlemek.
- **Dal önerisi:** `wp109-guvenlik-sertlestirme`

> **Çakışma matrisi (WP-105…109):** ✅ Aktif dosya yazan lane yok. SAHİP kesişimleri: WP-105 (gamification/home_shell) · WP-106 (group_repository + migration 0034) · WP-107 (manual dialog + study_session model) · WP-108 (edge functions + migration 0035) · WP-109 (edge functions + migration 0036 + group_repository). ⚠️ **WP-106 ↔ WP-109** ikisi de `supabase_group_repository.dart`'a yazar → **serileştir** (biri bitince diğeri). ⚠️ **WP-108 ↔ WP-109** ikisi de `send-report`/`collect-reports` edge fonksiyonlarına dokunur + S2 ops sıralaması → **serileştir, S2 cron secret'ten sonra**. Diğerleri paralel güvenli. Migration numaraları 0034/0035/0036 sırayla; aynı anda iki migration WP'si açılırsa numara çakışmasına dikkat.

### WP-93: Global Grup Keşfi ve Katılım Deneyimi 🌍
- **Program/Faz:** Sosyal gruplar · Play Store öncesi ürün yüzeyi · **Ajan:** Codex · **Durum:** [x] Tamamlandı (cihaz/ürün kabulü 2026-07-17) · **Bağımlılık:** WP-92 otomatik kalite kapısı
- **Problem:** Kullanıcılar açık grupları bulup tek eylemle katılamıyor; grup oluştururken görünürlük seçemiyor.
- **Kapsam dışı:** WP-92 dışı yetkilendirme, öneri algoritması, herkese açık üye/sosyal profil, yeni navigation sekmesi.
- **SAHİP dosyalar (yaz):** `app/lib/features/classroom/classroom_screen.dart`, `app/lib/features/classroom/widgets/class_switcher.dart`, `app/lib/features/classroom/widgets/class_detail_screen.dart`, yeni `app/lib/features/classroom/widgets/group_discovery_*.dart`, ilgili widget testleri, `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_tr.arb`.
- **DOKUNMA (oku, değiştirme):** `supabase/**`, `app/lib/data/repositories/**`, `app/lib/core/navigation/**`, generated l10n dosyaları.
- **Adımlar:**
  - [x] Gruplar yüzeyine “Grupları keşfet” girişi, arama, sayfalı liste, üye sayısı/50, hedef ve açık rozetini ekle.
  - [x] Oluşturma akışına private (davet kodu gerekir) / public (herkes katılabilir) seçimi ile anlaşılır gizlilik açıklaması ekle; yönetici mevcut grubun ayarını değiştirebilsin.
  - [x] Katıl/katıldın/dolu/private’a döndü/ağ hatası durumlarını bağla; başarılı katılımda aktif grup seçilir ve UI ≤1 sn güncellenir.
  - [x] EN/TR ARB metinlerini ekle; 360/600/1200 px ve dar Windows’ta taşma olmadan erişilebilir hedefler/semantics doğrula.
- **Otomatik kanıt:** `flutter analyze --no-pub` 0 bulgu; `python scripts/l10n_audit.py` (974 Flutter EN/TR anahtarı eş, görünür Türkçe literal 0); keşif widget testleri 6/6 (EN/TR, güvenli liste/katılım, 360/600/1200 px); tam `flutter test` 425/425; Android release APK (59.2 MB) ve Windows release EXE üretildi.
- **Canlı durum:** Kullanıcı, `0032_public_group_discovery.sql` migration'ını Supabase'e uyguladığını doğruladı. Önceki WP-92 cihaz RLS kanıtı henüz yoktur.
- **Veri/RLS/Geri alma:** Yeni şema yok; WP-92 API’sini tüketir. Geri alma UI commitidir; grup görünürlüğü verisi korunur.
- **RLS/Güvenlik:** İstemci keşif sonucundaki herhangi bir kimlikten üyelik/oturum/profil çıkarımı yapmaz; hata mesajı private grup bilgisi ifşa etmez.
- **Edge-case'ler:** Son kontenjan, zaten üye, arama sonucu yok, yavaş ağ, ekran döndürme, EN uzun etiketler, TalkBack/Narrator, grup public→private değişirken açık ekran.
- **Kabul (ölçülebilir):** EN/TR widget testlerinde public/private açıklaması, boş/dolu/zaten-üye/ağ-hata durumları; 360/600/1200 logical px ve dar Windows’ta overflow 0; katılım sonrası aktif grup seçimi; `flutter analyze` 0, ilgili + tam test yeşil, Android/Windows release build. Samsung/Pixel gerçek Supabase’de oluştur→keşfet→katıl→ayrıl→private’a al cihaz videosu ve ürün kabulü gerekir.
- **Tuzaklar:** Davet kodunu keşif kartında göstermek; grup listesine üye listesi ekleyerek sosyal profil RLS’ini atlamak; yalnız Türkçe metin eklemek; UI’yı RPC dışı doğrudan tablo sorgusuna bağlamak.
- **Dal:** main/lane · **Model:** 🔴 Opus

> **Çakışma matrisi (global gruplar):** ✅ Aktif lane yok. WP-92 ve WP-93 aynı `group_repository`/classroom/l10n yüzeylerine dolaylı bağımlıdır, bu yüzden paralel değil seridir. WP-92 bitmeden WP-93 başlamaz; Android/l10n cihaz QA paketleri parkta olduğundan çakışma sayılmaz.

---

## Play Store Production Programı — WP-110–124

> **Kaynak:** `docs/PLAY-STORE-HAZIRLIK-TARAMASI.md` + 2026-07-17 resmî Google Play politika kontrolü. Amaç APK üretmek değil; politika, veri, güvenlik, cihaz ve operasyon kanıtlarıyla Play production için savunulabilir bir GO kararı üretmektir.
>
> **Uygulayıcı sözleşmesi:** Kullanıcı bu paketleri Grok 4.5'e verecek. Grok her WP'de önce `.agents/skills/worker/SKILL.md`, `.agents/AGENTS.md`, `docs/KALITE-PROGRAMI.md` ve kendi WP kartını eksiksiz okur; lane claim eder; yalnız SAHİP dosyalara yazar; her WP'yi ayrı commitler; push/tag/Play deploy yapmaz (kullanıcı ayrıca istemedikçe).

### WP-110: Play Dağıtım Kanalı ve APK Updater İzolasyonu 🏪
- **Program/Faz:** Play Store · Faz A — Politika bloklayıcıları
- **Ajan:** — (atanınca lane doldurur)
- **Durum:** [ ] Bekliyor
- **Problem:** Stable ve beta Android build'leri aynı ana manifestten `REQUEST_INSTALL_PACKAGES` alıyor; Flutter updater GitHub Releases APK'sını indirip `open_filex` ile kurulum ekranı açıyor. Bu davranış Play build'inde kalırsa self-update/installer politikası nedeniyle ret riski doğar. Play artefaktının sideload artefaktından kod ve merged manifest düzeyinde ayrılması gerekir.
- **Kapsam dışı:** Exact alarm, full-screen intent, FGS ve pil optimizasyon izinlerinin ürün gerekçesi (WP-118); store listing/Console formu (WP-120); Play'e gerçek yükleme (WP-124).
- **SAHİP dosyalar (yaz):**
  - `app/android/app/build.gradle.kts`
  - `app/android/app/src/main/AndroidManifest.xml`
  - `app/android/app/src/{stable,beta,play}/AndroidManifest.xml` (gereken source-set overlay'leri)
  - `app/lib/core/config/distribution_channel.dart` (yeni)
  - `app/lib/features/updater/updater_service.dart`
  - `app/lib/features/updater/updater_dialog.dart`
  - `.github/workflows/release.yml` (yalnız Android varyant/build matrisi)
  - `app/test/features/updater/**`, yeni distribution-channel testleri
- **DOKUNMA (oku, değiştirme):** `core/time_engine/**`, alarm/native FGS dosyaları (WP-118); `app/pubspec.yaml` mümkünse dokunma; Windows updater davranışı ve `windows-release.yml` korunur.
- **Adımlar:**
  - [ ] Mevcut `stable`/`beta` GitHub-sideload davranışını envanterle; yeni `play` product flavor'ını aynı kalıcı `applicationId=com.manilmax.online_study_room` ile ekle. `play` ve `stable` aynı anda kurulamaz; bu bilinçli olarak aynı ürün kimliğidir.
  - [ ] `REQUEST_INSTALL_PACKAGES` iznini `main` manifestten çıkar; yalnız GitHub-sideload source setlerinde (`stable`/`beta`) ekle. `play` merged manifestinde izin olmadığını otomatik test/CI ile doğrula.
  - [ ] Derleme zamanı `DistributionChannel.play/githubStable/githubBeta/windows` sözleşmesi kur. Play build'inde GitHub APK check/download/install yolu çağrılamaz; “Güncelleme” tercihi ölü anahtar bırakmadan gizlenir veya yalnız mağaza tarafından yönetildiğini açıklar.
  - [ ] `open_filex`, APK indirme, SHA indirme ve unknown-sources kontrolünün Play build kod yolundan erişilemediğini test et. Windows MSIX updater ve GitHub beta/stable davranışı regresyonsuz kalır.
  - [ ] CI'da Play komutunu tekilleştir: `flutter build appbundle --flavor play --release --dart-define-from-file=env.json` + zorunlu distribution define/guard. Yanlış define ile Play bundle üretimini fail-fast yap.
  - [ ] `aapt2 dump permissions` veya `apkanalyzer manifest permissions` kontrolünü workflow'a ekle; Play AAB/APK'de `REQUEST_INSTALL_PACKAGES` görülürse build kırılır.
  - [ ] Release dokümanında GitHub APK ile Play AAB'nin amaç/komut/izin farkını yaz; aynı versionCode'un iki kez yüklenemeyeceğini belirt.
- **Veri/Migration etkisi:** Yok. Geri alma: play flavor/overlay ve distribution config commitini geri almak; kullanıcı verisi etkilenmez.
- **RLS/Güvenlik:** Play build harici APK çalıştırmaz. İndirme URL'si/installer intent'i Play kanalında unreachable olmalı; yalnız UI gizleme yeterli değildir.
- **Edge-case'ler:** Windows; web; debug profile; beta package suffix; Play build yanlış define; GitHub API kesintisi; eski sideload kurulumun Play build ile aynı imza/applicationId üzerinden güncellenmesi.
- **Kabul (ölçülebilir):** `playRelease` merged manifestinde `REQUEST_INSTALL_PACKAGES` = 0; Play build'de APK indirme/kurma ağ isteği = 0; stable/beta testinde updater hâlâ çalışır; Windows testleri yeşil; `flutter analyze` 0, ilgili ve tam test paketi yeşil; imzasız/debug release üretilmez.
- **Tuzaklar:** İzni yalnız runtime'da kullanmamak ama manifestte bırakmak; `play` flavor'a farklı applicationId vererek yanlışlıkla ikinci ürün oluşturmak; Windows updater'ı kırmak; yalnız butonu gizleyip arka plan update check'ini açık bırakmak.
- **Bağımlılık/çakışma:** İlk Android sıcak-dosya WP'sidir. WP-118, `AndroidManifest.xml` nedeniyle WP-110 commitinden sonra başlar.
- **Dal:** `main` (ayrı lane; branch/push yok)
- **Model önerisi:** 🔴 Grok 4.5 — Gradle/flavor/politika çapraz yüzeyi

### WP-111: Gizlilik Politikası, Kullanım Koşulları ve Topluluk Kuralları 📜
- **Program/Faz:** Play Store · Faz A — Hukuk/gizlilik temeli
- **Ajan:** —
- **Durum:** [ ] Bekliyor
- **Problem:** Play Console ve uygulama içinde canlı gizlilik politikası yok; UGC için kullanıcıların içerik üretmeden önce kabul edeceği kullanım/topluluk kuralları bulunmuyor. Sentry, Supabase, avatar, sohbet, çalışma verisi, silme ve retention açıkça anlatılmalı.
- **Kapsam dışı:** Avukat görüşü yerine geçmek; Data Safety formunu göndermek (WP-119); hesap silme backend'i (WP-112/113); UGC enforcement (WP-115/116).
- **SAHİP dosyalar (yaz):**
  - `docs/legal/PRIVACY-POLICY.{tr,en}.md` (yeni)
  - `docs/legal/TERMS-OF-USE.{tr,en}.md` (yeni)
  - `docs/legal/COMMUNITY-GUIDELINES.{tr,en}.md` (yeni)
  - `docs/legal/DATA-RETENTION-SCHEDULE.md` (yeni)
  - `app/web/legal/**` veya onaylı statik site kaynağı
  - `app/lib/features/profile/legal_center_screen.dart` (yeni)
  - `app/lib/features/profile/settings_screen.dart` (yalnız Hukuk ve Gizlilik girişi)
  - `app/lib/core/observability/observability_service.dart` (yalnız tercih/consent davranışı)
  - `app/lib/l10n/app_{en,tr}.arb`, ilgili legal/telemetry testleri
- **DOKUNMA (oku, değiştirme):** Auth/deletion repository'leri (WP-112–114); chat/group repository'leri (WP-115/116); generated l10n dosyaları elle düzenlenmez.
- **Adımlar:**
  - [ ] Geliştirici/uygulama adı, iletişim kanalı, veri türleri, amaçlar, işleyiciler (Supabase/Sentry), aktarım güvenliği, retention, silme, çocuk/hedef kitle, kullanıcı hakları ve politika değişiklik tarihini TR/EN yaz.
  - [ ] Politika URL'sini aktif, herkese açık, giriş istemeyen, coğrafi engeli olmayan HTTPS sayfa olarak yayınlanabilir hale getir; PDF veya düzenlenebilir ortak doküman kullanma. Nihai domain/URL `Ürün kararı gerekiyor`.
  - [ ] UGC kurallarında yasak içerik/davranış, raporlama, engelleme, moderasyon, itiraz ve yaptırım sürecini tanımla; içerik üretiminden önce kabul edilecek sürüm numarası belirle.
  - [ ] Ayarlar'a “Gizlilik ve yasal” merkezi ekle; politika/koşullar/topluluk kuralları ve telemetri tercihi erişilebilir olsun. Telemetri varsayılanı ürün/hukuk kararıyla açıkça gösterilsin; değişiklik sonraki açılışta Sentry init davranışını gerçekten etkilesin.
  - [ ] Uygulama içi metin ile web metninin sürüm/tarih/hash eşleşmesini test et; bozuk URL için kullanıcıya güvenli hata ve kopyalanabilir adres sun.
  - [ ] Account deletion ve retention bölümlerine WP-112–114 tamamlanmadan “yakında” gibi yanıltıcı kesinlik yazma; belgeyi ilgili WP sonunda nihai davranışla güncelleme kapısı koy.
- **Veri/Migration etkisi:** Yok. Yerel telemetri tercihi SharedPreferences'ta; rollback legal ekran commitidir, yayımlanmış politika geçmişi silinmez.
- **RLS/Güvenlik:** Politika sayfasında Supabase URL/anon key dışında sır yok; service role, DSN dışı secret, kullanıcı örneği/PII bulunmaz.
- **Edge-case'ler:** İnternetsiz açılış; URL 404; dil fallback; telemetry build flag kapalı; kullanıcı koşulları kabul etmemiş; politika sürümü değişmiş.
- **Kabul (ölçülebilir):** Play Console'a verilebilir canlı HTTPS URL 200 döner; uygulamada ≤3 dokunuşta açılır; TR/EN içerik parity kontrolü geçer; telemetri kapalı yeniden açılışta Sentry init/event = 0; TalkBack sırası doğru; 360 px'te overflow 0; analyze/test yeşil.
- **Tuzaklar:** Yalnız repo Markdown'ını “canlı URL” saymak; Sentry'yi “anonim” diye kesinlemek; retention ile gerçek pipeline'ı çeliştirmek; UGC kurallarını kabul enforcement olmadan tamamlandı saymak.
- **Bağımlılık/çakışma:** WP-114 ve WP-116 da `settings_screen`/ARB'ye gireceği için bu WP önce tamamlanır; sonra iki UI WP'si seri uygulanır.
- **Dal:** `main`
- **Model önerisi:** 🔴 Grok 4.5 — hukuk metni/veri akışı tutarlılığı

### WP-112: Hesap Silme Veri Sözleşmesi ve Migration 0037 🧾
- **Program/Faz:** Play Store · Faz A — Account deletion backend R1
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Ürün kararı gerekiyor:** `docs/HESAP-SILME-RETENTION-KARARI.md` §0 önerilen varsayılanları (14 gün, isteğe bağlı export, mesaj silme, admin audit) kullanıcı onaylamadan kodlama başlamaz.
- **Problem:** Auth hesabı açılabiliyor ancak kullanıcı silme isteği, geri alma penceresi, purge tarihi ve retention durumu için sunucu sözleşmesi yok. Doğrudan `auth.admin.deleteUser` çağrısı storage, grup sahipliği ve denetim kayıtlarında veri kaybı/engel yaratabilir.
- **Kapsam dışı:** Hard-delete Edge/cron (WP-113); Flutter/web UI (WP-114); genel UGC block/report (WP-115).
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/0037_account_deletion_core.sql` (yeni; başlamadan en yüksek migration tekrar kontrol edilir)
  - `docs/HESAP-SILME-RETENTION-KARARI.md` (yalnız onaylanan karar/durum)
  - `docs/play-store/ACCOUNT-DELETION-DATA-MAP.md` (yeni)
  - SQL/RLS smoke test dosyaları veya doğrulama sorguları
- **DOKUNMA (oku, değiştirme):** `0036` ve eski migration'lar değiştirilmez; Flutter Auth/UI; Edge functions.
- **Adımlar:**
  - [ ] Tüm `auth.users` FK'lerini, `on delete` davranışlarını, storage path'lerini, grup creator/admin durumunu, feedback/audit retention'ını canlıdan bağımsız yerel şema üzerinden çıkar; hard-delete ön koşul grafiği üret.
  - [ ] `account_deletion_requests` durum makinesi tasarla: `requested → scheduled → processing → completed|failed|canceled`; `requested_at`, `purge_after`, deneme sayısı, PII'siz hata kodu ve idempotency alanları.
  - [ ] Doğrudan tablo DML'ini revoke et; `request_account_deletion`, `cancel_account_deletion`, `my_account_deletion_status` SECURITY DEFINER RPC'lerini yalnız `auth.uid()` için yaz. Günde 1 istek, server time ve 14×24 saat/kararlaştırılan süre sunucuda hesaplanır.
  - [ ] Request sırasında `monthly_report_opt_in=false`, presence pasif ve bildirim/rapor işleri yeni queue üretmeyecek şekilde sözleşme kur. Grace süresinde veri saklandığını açıkça modelle; soft-delete'i hard-delete diye raporlama.
  - [ ] Grup kurucusu için güvenli kuralı uygula: aktif başka admin varsa deterministik devir; yoksa en eski aktif üyeye açık auditli devir veya boş grubu silme. Başka üyelerin mesaj/oturum verisini cascade ile yanlışlıkla silme.
  - [ ] Mesaj retention kararı, feedback +90 gün ve audit hash ≥1 yıl kurallarını tablo/iş akışına dönüştür; e-posta/display name gibi PII audit'e kopyalanmaz.
  - [ ] Migration başlığında açıklama/rollback yaz; rollback bekleyen istekleri listeleyip güvenli biçimde cancel etmeden tablo/kolon drop etmez.
- **Veri/Migration etkisi:** Yeni `0037`; prod'a WP-121 dışında uygulanmaz. Rollback ayrıntısı migration üst bilgisinde ve data-map'te zorunlu.
- **RLS/Güvenlik:** Kullanıcı yalnız kendi isteğini görür/oluşturur/iptal eder; super-admin normal select ile toplu PII alamaz; service role yalnız WP-113 worker'ında. RPC `search_path` sabit, grant en dar rolde.
- **Edge-case'ler:** İkinci istek; grace bitişiyle eşzamanlı cancel; hesap zaten silinmiş; grup tek admin; açık feedback; storage object yok; monthly job processing; timezone (süre `timestamptz`, İstanbul yalnız kullanıcı metni).
- **Kabul (ölçülebilir):** Yetkisiz kullanıcı başka UID isteğini okuyamaz/değiştiremez; aynı istek idempotent; purge tarihi server-side deterministik; grup üyelerinin verisi korunur; SQL smoke matrisi owner/other/admin/anon için geçer; rollback dry-run başarılı.
- **Tuzaklar:** Client timestamp'e güvenmek; `profiles` bayrağını doğrudan update'e açmak; Auth user'ı migration içinde silmek; CASCADE ile grup üyelerinin içeriğini yok etmek; migration 0037 numarasını paralel worker ile çakıştırmak.
- **Bağımlılık/çakışma:** Migration sıcak yüzey. WP-115'in 0038'i bundan sonra; aynı anda başlamaz.
- **Dal:** `main`
- **Model önerisi:** 🔴 Grok 4.5 — Auth/RLS/destructive lifecycle

### WP-113: Hard-Delete Edge Pipeline, Storage Temizliği ve Cron 🧨
- **Program/Faz:** Play Store · Faz A/B — Account deletion backend R2
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-112 otomatik test geçti
- **Problem:** Süresi dolan hesapların storage, ilişkisel veri, Auth ve üçüncü taraf işlemciler boyunca güvenli/idempotent hard-delete işlemini yapan service-role pipeline yok.
- **Kapsam dışı:** Kullanıcı UI/web sayfası (WP-114); genel backend deploy (WP-121); yasal retention kararı değiştirme.
- **SAHİP dosyalar (yaz):**
  - `supabase/functions/account-deletion/index.ts` (kullanıcı status/request bridge gerekiyorsa)
  - `supabase/functions/purge-accounts/index.ts` (yeni)
  - `supabase/functions/_shared/auth.ts` veya yalnız bu fonksiyonlara ait dar auth helper
  - `supabase/functions/**/account_deletion*_test.ts`
  - gerekirse **0037'yi değiştirmeden** yeni `0038_account_deletion_scheduler.sql`; bu durumda WP-115 migration numarası yeniden belirlenir
  - `docs/play-store/ACCOUNT-DELETION-RUNBOOK.md`
- **DOKUNMA (oku, değiştirme):** Flutter; chat/moderation UI; mevcut 0030–0037 migration dosyaları; production secrets.
- **Adımlar:**
  - [ ] `purge_after <= now()` ve state `scheduled|failed(retryable)` kayıtlarını `FOR UPDATE SKIP LOCKED`/eşdeğer tek-worker sözleşmesiyle claim et; aynı kullanıcı iki kez işlenemez.
  - [ ] Sıra: yeni e-posta/job üretimini kes → pending queue'ları iptal/anonimleştir → avatar/feedback storage object'lerini listele-sil → retention kararına göre sosyal/mesaj/support verisini scrub/sil → FK preflight → `auth.admin.deleteUser` → PII'siz tamamlanma auditi.
  - [ ] Grup ownership devrini WP-112 sözleşmesine göre doğrula; başka kullanıcıların grubu/mesajı yanlışlıkla cascade olmamalı. Her destructive adım öncesi hedef UID ve kaynak sayısı doğrulanır.
  - [ ] CRON endpoint yalnız `CRON_SECRET` veya Supabase doğrulanmış service context kabul eder; CORS wildcard/auth bypass yok. Secret loglanmaz; response yalnız sayım ve sabit hata kodu taşır.
  - [ ] Retry/backoff ve poison record davranışı ekle; kısmi storage silme sonrası tekrar koşum güvenli olmalı. `completed` durumuna yalnız Auth user gerçekten yoksa geç.
  - [ ] Sentry/harici işlemci için app'in gerçekten gönderdiği tanımlayıcıları denetle; PII gönderilmiyorsa “silme çağrısı yok” kanıtını, gönderiliyorsa sağlayıcı deletion yolunu runbook'a yaz.
  - [ ] Staging'de sahte hesapla request→grace override→purge provası; production'da önce dry-run/limit=1 ve kullanıcı onayı olmadan destructive koşum yok.
- **Veri/Migration etkisi:** Scheduler migration gerekirse mevcut en yüksek numara +1. Geri alma cron unschedule + Edge deploy rollback; silinmiş kullanıcı geri getirilemez, bu nedenle staging ve iki aşamalı prod onayı zorunlu.
- **RLS/Güvenlik:** Service role yalnız Edge secret store; istemci/repo/env örneğine girmez. Admin manuel purge gerekçe + audit ister; ham e-posta loglanmaz.
- **Edge-case'ler:** Storage 404; Auth delete geçici hata; FK restrict; cron iki kez; cancel tam claim anında; kullanıcı başka cihazda aktif; feedback retention devam ediyor; grup tek sahibi.
- **Kabul (ölçülebilir):** Aynı test hesabına 3 tekrar çağrıda tek tamamlanma; Auth/profile/session/avatar/outbox verisi beklenen son durumda; başka üyelerin satır kaybı 0; failed iş retry olur, PII logu 0; unauthorized invoke 401/403; staging dry-run ve rollback runbook'u kanıtlı.
- **Tuzaklar:** Önce Auth'u silip storage path sahipliğini kaybetmek; tüm bucket'ı silmek; `service_role`'ü Flutter'a koymak; cron secret yanlışken canlı job'u kesmek; tamamlanmamış işi completed işaretlemek.
- **Bağımlılık/çakışma:** Edge/migration yüzeyi WP-115 ve WP-121 ile seri. WP-114, WP-113 API sözleşmesi sabitlenince paralel başlayabilir.
- **Dal:** `main`
- **Model önerisi:** 🔴 Grok 4.5 — destructive/idempotent backend

### WP-114: Uygulama İçi ve Web Hesap Silme Deneyimi 🗑️
- **Program/Faz:** Play Store · Faz A — Account deletion client/web
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-111 legal URL + WP-112 sözleşme; WP-113 API contract
- **Problem:** Kullanıcı Ayarlar'dan hesabını silemiyor; uygulamayı kaldırmış kullanıcı için de çalışan web silme talep yolu yok. İstek öncesi yeniden doğrulama, geri alma ve cihaz-yerel veri temizliği gerekir.
- **Kapsam dışı:** Hard-delete algoritması (WP-113); genel privacy metni (WP-111); admin moderasyon.
- **SAHİP dosyalar (yaz):**
  - `app/lib/data/repositories/auth_repository.dart`
  - `app/lib/data/repositories/{supabase,in_memory}/in_memory_auth_repository.dart` ve `supabase_auth_repository.dart`
  - `app/lib/data/models/account_deletion_status.dart` (yeni)
  - `app/lib/data/providers/auth_providers.dart` (yalnız deletion provider'ları)
  - `app/lib/features/profile/account_settings_screen.dart`
  - `app/lib/features/auth/account_deletion_pending_screen.dart` (yeni)
  - `app/lib/features/auth/auth_gate.dart` (yalnız pending routing)
  - `app/lib/core/prefs/local_account_wipe.dart` (yeni)
  - `app/web/account-deletion/**` veya onaylı public web istemcisi
  - `app/lib/l10n/app_{en,tr}.arb`, ilgili unit/widget/integration testleri
- **DOKUNMA (oku, değiştirme):** Migration/Edge (WP-112/113); `settings_screen.dart` (WP-111 tamamlandıktan sonra yalnız mevcut AccountSettings girişini kullan); admin UI.
- **Adımlar:**
  - [ ] Auth repository'ye request/cancel/status ve güvenli re-auth sözleşmesi ekle; Supabase + InMemory birlikte uygulanır. Yanlış parola ve hesap enumeration kullanıcıya genel hata verir.
  - [ ] Hesabım ekranında tehlikeli bölge oluştur: veri özeti, 14 gün/kararlaştırılan süre, kalıcı sonuç, mesaj/support retention, web yolu ve “Önce verilerimi indir” seçeneği açıkça görünür.
  - [ ] Silme öncesi şifre veya magic-link re-auth; ardından ikinci ekranda açık onay metni. Tek tap ile destructive istek yok; butonlar ≥48 dp ve TalkBack açıklamalı.
  - [ ] Request başarılıysa timer/notification/widget snapshot, offline outbox, cached profile/session, yerel token/tercihler ve alarm/preset kapsamını veri haritasına göre temizle; server request başarılı olmadan yerel veriyi yok etme.
  - [ ] Pending hesap tekrar giriş yaparsa normal HomeShell yerine deletion-pending ekranı aç; purge tarihi, politika linki ve “Silme isteğini geri al” göster. Cancel başarılıysa normal profile dön.
  - [ ] Public HTTPS web sayfası uygulama indirmeden talep başlatmalı: email/magic-link ile kimlik doğrulama veya Google'ın kabul ettiği açık destek formu. Sayfa Odak Kampı/geliştirici adını, işlem süresini ve talep durumunu gösterir; kullanıcıyı uygulamayı yeniden kurmaya zorlamaz.
  - [ ] Play Console Account deletion URL'si olacak nihai adresi test et; web formunda rate limit, CSRF/state ve enumeration koruması ekle.
- **Veri/Migration etkisi:** Yeni şema yok; WP-112/113 tüketilir. Local wipe geri alınamaz ama server request cancel edilebilir; bu ayrım kullanıcıya anlatılır.
- **RLS/Güvenlik:** Re-auth token/parola loglanmaz; web anon endpoint doğrudan UID kabul etmez; cancel yalnız aktif auth sahibinden.
- **Edge-case'ler:** Çevrimdışı request; request başarılı/response kayıp; çoklu cihaz; sosyal login yok/şifre unutuldu; web magic-link başka cihaz; purge anında cancel; local wipe kısmi hata.
- **Kabul (ölçülebilir):** Ayarlar'dan ≤4 adımda doğrulanmış talep; yanlış parola ile request=0; pending route normal uygulamaya erişemez; cancel sonrası hesap ≤2 sn'de aktif; web URL anonim tarayıcıda 200 ve uygulama kurmadan talep alınabilir; local PII anahtarları testte 0; TR/EN ve 360 px overflow testi yeşil.
- **Tuzaklar:** Sadece e-posta gönderip in-app yolu eksik bırakmak; soft suspend'i “silindi” diye göstermek; local wipe'ı server onayından önce yapmak; web formunda kayıtlı e-posta sızdırmak.
- **Bağımlılık/çakışma:** ARB/auth sıcak yüzeyi nedeniyle WP-111'den sonra; WP-116 ile aynı anda ARB düzenlenmez.
- **Dal:** `main`
- **Model önerisi:** 🔴 Grok 4.5 — auth UX + web güvenliği

### WP-115: UGC Raporlama, Engelleme ve Moderasyon Backend'i 🛡️
- **Program/Faz:** Play Store · Faz A — UGC compliance R1
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-112/113 migration sırası kesinleşmiş olmalı
- **Problem:** Sınıf mesajı, profil/avatar, grup adı ve dürtme kullanıcı üretimi içerik/etkileşimdir; içerik/kullanıcı raporlama, block listesi, şart kabulü ve moderasyon durumu için server-authoritative temel yok.
- **Kapsam dışı:** Kullanıcı UI (WP-116); admin queue UI (WP-117); hukuk metni yazma (WP-111).
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/0038_ugc_safety.sql` veya o anda geçerli en yüksek+1
  - `supabase/functions/moderate-content/index.ts` (yeni; yalnız admin işlemi gerekiyorsa)
  - `docs/play-store/UGC-MODERATION-RUNBOOK.md`
  - SQL/RLS/Edge testleri
- **DOKUNMA (oku, değiştirme):** Flutter repository/UI; önceki migration'lar; account deletion edge.
- **Adımlar:**
  - [ ] `user_blocks`, `ugc_reports`, `ugc_terms_acceptance`, `moderation_actions` tablolarını ve `class_messages.moderation_state/hidden_at` alanlarını tasarla. Target türleri enum/check ile `message|user|profile|avatar|group` sınırında tutulur.
  - [ ] `block_user/unblock_user/report_ugc/accept_ugc_terms` RPC'lerini yaz; reporter yalnız kendi raporunu oluşturur/durum özetini görür, hedef reporter kimliğini asla görmez. Kendini block/report, aynı hedef spam ve serbest metin uzunluğu sınırlandırılır.
  - [ ] Mesaj SELECT/RPC görünürlüğünde blocker'ın blocked kullanıcı içeriğini görmemesini; nudge gönderiminde iki yönde block kontrolünü; sosyal profil/public discovery'de güvenli placeholder/filtre davranışını RLS veya güvenli RPC ile uygula.
  - [ ] Chat/UGC insert'i için güncel topluluk kuralı kabulini server-side zorunlu yap; yalnız UI checkbox yeterli değildir. Kural sürümü değişince yeniden kabul gerekir.
  - [ ] Admin moderation action'ları (hide message, restore, warn metadata, suspend handoff) service-role/`is_super_admin()` + audit ile sınırla. Rapor snapshot'ında token/e-posta yok; gerekli içerik minimum tutulur.
  - [ ] Rate limit: raporlayan kullanıcı/hedef/IP yerine auth user temelli makul pencere; kritik yasa dışı içerik raporu rate limit yüzünden tamamen engellenmez, abuse ayrı işaretlenir.
  - [ ] Retention: reddedilmiş/çözülen rapor ve evidence süresi legal schedule ile uyumlu; hesap silmede reporter/target hash/anonimleştirme yolu WP-112/113'e bağlanır.
- **Veri/Migration etkisi:** Yeni migration; WP-121'de staging/prod. Rollback policy/RPC/trigger drop sırası + yeni kolonların güvenli bırakılması.
- **RLS/Güvenlik:** Rapor hedefi reporter'ı göremez; grup admini platform moderation verisine erişemez; super-admin erişimi auditli; direct table write revoke.
- **Edge-case'ler:** Silinmiş mesaj; hedef hesap pending deletion; iki yönlü block; aynı mesaj 20 kez rapor; grup private'a döner; moderator kendi içeriğini inceler; realtime hidden update.
- **Kabul (ölçülebilir):** Owner/other/admin/anon RLS matrisi geçer; blocked sender mesaj/nudge görünürlüğü beklendiği gibi; terms kabulü olmayan insert server'da reddedilir; aynı rapor idempotent/coalesced; reporter kimliği hedef sorgusunda 0 alan; rollback dry-run başarılı.
- **Tuzaklar:** Mevcut feedback ticket'ı UGC report sanmak; yalnız client filtrelemek; `using(true)` admin policy; rapora gereksiz profil/e-posta snapshot'ı koymak.
- **Bağımlılık/çakışma:** Migration/Edge sıcak yüzey; WP-113 sonrası seri. WP-116 ve WP-117 bu sözleşme sabitlenince farklı UI yüzeylerinde paralel olabilir.
- **Dal:** `main`
- **Model önerisi:** 🔴 Grok 4.5 — RLS/moderasyon güvenliği

### WP-116: Kullanıcı UGC Güvenlik Arayüzleri ve Topluluk Kabulü 🚩
- **Program/Faz:** Play Store · Faz A — UGC compliance R2
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-111 + WP-115
- **Problem:** Kullanıcı mesajı, kullanıcıyı, profili/avatarı veya grubu uygulama içinden raporlayamıyor; engellenen kullanıcıları yönetemiyor; UGC öncesi topluluk kuralları kabul edilmiyor.
- **Kapsam dışı:** Admin inceleme (WP-117); backend/RLS (WP-115); genel feedback bug formu.
- **SAHİP dosyalar (yaz):**
  - `app/lib/data/repositories/moderation_repository.dart` (yeni)
  - `app/lib/data/repositories/{supabase,in_memory}/supabase_moderation_repository.dart`, `in_memory_moderation_repository.dart`
  - `app/lib/data/providers/moderation_providers.dart`
  - `app/lib/features/safety/**` (report sheet, block list, terms gate)
  - `app/lib/features/classroom/widgets/class_chat_screen.dart`
  - `app/lib/features/classroom/widgets/group_discovery_screen.dart` ve grup detail/menu yüzeyi (yalnız report action)
  - `app/lib/features/profile/social_profile_screen.dart`, `widgets/social_profile_dialog.dart` (yalnız report/block)
  - `app/lib/features/profile/settings_screen.dart` (yalnız Engellenen kullanıcılar girişi)
  - `app/lib/l10n/app_{en,tr}.arb`, ilgili testler
- **DOKUNMA (oku, değiştirme):** Admin UI/repository (WP-117); migration/Edge; auth deletion UI (WP-114 ile seri ARB/settings).
- **Adımlar:**
  - [ ] İlk mesaj/grup adı/avatar upload'ından önce güncel community rules modalı + açık kabul; reddedilirse içerik üretimi kilitli, okuma erişimi ürün kararına göre sürer.
  - [ ] Mesaj uzun basma/menüsünde “Mesajı bildir” ve “Kullanıcıyı engelle”; profil/grup menüsünde hedefe uygun report türü. Kendi içeriğinde report/block gösterme.
  - [ ] Rapor sebebi kontrollü enum + isteğe bağlı sınırlı açıklama; başarı mesajı, duplicate durumu ve acil güvenlik yönlendirmesi. Reporter'a moderator/target PII gösterme.
  - [ ] Block sonrası ilgili mesaj/nudge/profil yüzeyi anında provider invalidation ile güncellensin; “Engellenen kullanıcılar” ekranında unblock. Server RLS sonucu ile client optimistik durum uzlaştırılsın.
  - [ ] Silinmiş/modere edilmiş içerik için nötr placeholder; içerik snapshot'ını cihaz loguna/telemetriye gönderme.
  - [ ] TR/EN, TalkBack, klavye/Narrator, koyu/açık tema, 48 dp hedef ve destructive unblock/report confirmation testleri.
- **Veri/Migration etkisi:** WP-115 API tüketilir; repository çift implementasyon zorunlu. Rollback UI commitidir, server block/report verisi korunur.
- **RLS/Güvenlik:** UI gizleme yetki sayılmaz; tüm write server RPC. Hata metni hedef hesabın varlığını/cezasını ifşa etmez.
- **Edge-case'ler:** Realtime'da mesaj rapor sırasında silinir; offline; duplicate tap; blocked user aynı grupta; kendi profili; grup private olur; terms version değişir.
- **Kabul (ölçülebilir):** Mesaj/profil/grup için report yolu ≤3 dokunuş; block sonrası içerik ≤1 sn'de görünmez; uygulama yeniden açılınca block kalıcı; terms kabulü yokken server insert 0; 360/600/1200 px overflow 0; TR/EN widget ve repository testleri + analyze/tam test yeşil.
- **Tuzaklar:** Feedback formuna yönlendirip bağlamsal report hedefi göndermemek; yalnız listeden gizlemek; block'u grup üyeliğini silmek sanmak; moderator kararını reporter'a ayrıntılı ifşa etmek.
- **Bağımlılık/çakışma:** WP-114 ile `settings_screen`/ARB sıcak yüzeyini paylaşır; seri çalışır. WP-117 ile SAHİP kesişimi yoksa paralel güvenli.
- **Dal:** `main`
- **Model önerisi:** 🔴 Grok 4.5 — çok yüzeyli güvenlik UX'i

### WP-117: Admin UGC Moderasyon Kuyruğu ve Audit Merkezi 🧑‍⚖️
- **Program/Faz:** Play Store · Faz A — UGC compliance R3
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-115
- **Problem:** Raporlar gelse bile adminin önceliklendirme, evidence görme, içerik gizleme/geri alma, kullanıcı yaptırımı ve audit akışı yoksa moderasyon “etkili ve sürekli” değildir.
- **Kapsam dışı:** Genel kullanıcı raporlama UI (WP-116); yeni süper-admin kimlik modeli; otomatik AI moderasyonu.
- **SAHİP dosyalar (yaz):**
  - `app/lib/data/repositories/admin_repository.dart`
  - `app/lib/data/repositories/{supabase,in_memory}/supabase_admin_repository.dart`, `in_memory_admin_repository.dart`
  - `app/lib/features/admin/tabs/admin_moderation_tab.dart` (yeni)
  - `app/lib/features/admin/admin_screen.dart` (yalnız tab ekleme)
  - `app/lib/data/models/ugc_report*.dart`, moderation action DTO'ları
  - admin provider/test dosyaları; gerekli admin l10n girdileri
- **DOKUNMA (oku, değiştirme):** `moderation_repository.dart` kullanıcı tarafı (WP-116); migration/RLS/Edge (WP-115 sözleşmesi); genel feedback tabı korunur.
- **Adımlar:**
  - [ ] Open/in-review/resolved/rejected filtreli kuyruk; severity, target type, created time, duplicate count; pagination ve refresh.
  - [ ] Evidence ekranında yalnız gerekli içerik snapshot'ı; reporter kimliği rol gerektirmedikçe maskeli. Canlı içerik değişmiş/silinmişse snapshot/current farkını göster.
  - [ ] Hide/restore message, group/profile escalation, user suspend handoff; her işlem gerekçe, confirmation, actor, timestamp ve before/after audit üretir.
  - [ ] Aynı rapora iki admin eşzamanlı işlem yaparsa optimistic lock/version ile biri güvenli conflict alır; son-yazma sessizce kazanmaz.
  - [ ] Yanlış pozitif geri alma ve itiraz notu; destructive hard delete bu WP'de yok.
  - [ ] Empty/error/offline/unauthorized durumları; admin olmayan kullanıcı navigation ile erişse bile server 403.
- **Veri/Migration etkisi:** WP-115 contract tüketilir; yeni migration yok. Rollback UI/repository commitidir, audit verisi silinmez.
- **RLS/Güvenlik:** `is_super_admin()` + Edge auth; grup admini erişemez; raw service role yok; report detail log/Sentry'ye gitmez.
- **Edge-case'ler:** Target silinmiş; reporter hesabı siliniyor; duplicate reports; moderator kendi raporu; network action sonucu kayıp; stale version.
- **Kabul (ölçülebilir):** Admin report'u ≤2 sn'de açar; hide action sonrası kullanıcı görünürlüğü ≤2 sn; admin olmayan select/action 0/403; iki eşzamanlı aksiyonda tam bir başarı + bir conflict; her aksiyon için tek audit; widget/repository testleri ve analyze yeşil.
- **Tuzaklar:** Feedback ve UGC raporlarını tek status enumuyla bozmak; reporter e-postasını listeye koymak; client-side admin kontrolüne güvenmek; audit'i update edilebilir yapmak.
- **Bağımlılık/çakışma:** WP-116 ile ortak SAHİP yoksa paralel; `app_en/tr.arb` ortaksa sırala veya WP-117 admin metinlerini ayrı commit sonrası rebase değil lane koordinasyonuyla ekle.
- **Dal:** `main`
- **Model önerisi:** 🔴 Grok 4.5 — admin/auth/audit

### WP-118: Android Kısıtlı İzinler, FGS ve Alarm Play Uyumu ⏰
- **Program/Faz:** Play Store · Faz A/C — Android policy + reliability
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-110 (`AndroidManifest.xml` sıcak yüzeyi)
- **Problem:** `USE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, `FOREGROUND_SERVICE_SPECIAL_USE`, `dataSync`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` ve exported timer receiver Play incelemesi/platform sürümleri açısından kanıt/fallback gerektiriyor. Mevcut “form doldururuz” yaklaşımı tek başına yeterli değil.
- **Kapsam dışı:** Installer izni (WP-110); Console form gönderimi (WP-120); store metni; yeni saat özelliği.
- **SAHİP dosyalar (yaz):**
  - `app/android/app/src/main/AndroidManifest.xml` + `src/play/AndroidManifest.xml`
  - `app/android/app/src/main/kotlin/com/manilmax/online_study_room/ExactAlarmHelper.kt`
  - `app/android/app/src/main/kotlin/com/manilmax/online_study_room/alarm/**`
  - `app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt`
  - `app/android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/TimerActionReceiver.kt`
  - `app/lib/core/time_engine/{clock_permissions,exact_alarm_permission,alarm_scheduler}.dart`
  - `app/lib/core/notifications/native_alarm_bridge.dart`
  - izin ayar ekranı ve ilgili native/Dart/integration testleri
- **DOKUNMA (oku, değiştirme):** Gradle/flavor/updater (WP-110 tamamlanmış sözleşme); account/UGC; server migrations.
- **Adımlar:**
  - [ ] Her izni feature→API→Play eligibility matrisiyle belgeleyip merged Play manifestten doğrula. Kullanılmayan izin/servis/type kaldırılır; paket var diye izin tutulmaz.
  - [ ] Play için güvenli varsayılan: `USE_EXACT_ALARM` yalnız Play Console'da core alarm/timer use case onayına dayanıyorsa kalır; aksi `SCHEDULE_EXACT_ALARM` + kullanıcı special access + inexact fallback. İki izni gereksiz birlikte tutma.
  - [ ] FSI için Android 14+ `canUseFullScreenIntent` kontrolü, ayar yönlendirmesi ve reddedilince heads-up/normal alarm bildirimi fallback'i. Alarm yine yönetilebilir; ekran kilidi bypass iddiası yok.
  - [ ] `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` Play manifestinden kaldırma/uygunluk kararı; doğrudan exemption intent'i yerine kullanıcı eğitimli genel battery settings yolu. Reddetme timer'ı tamamen kilitlemez.
  - [ ] FGS `specialUse` gerekçesini kullanıcı başlatmalı, görünür, durdurulabilir sayaçla hizala. API 29–33'te policy'ye uymayan `dataSync` runtime type kullanımı yerine güvenli legacy start tasarımını değerlendir; API 34–36 specialUse deklarasyonu + property tutarlı.
  - [ ] `flutter_foreground_task` servisinin gerçekten kullanılıp kullanılmadığını kanıtla; ölü ikinci FGS ise manifest/paket yüzeyini daralt. Paket kaldırılacaksa `pubspec.yaml` ayrı sıcak commit/claim gerektirir.
  - [ ] `TimerActionReceiver` dış uygulama intent'ine kapatılır (`exported=false` veya signature permission + doğrulama); widget/notification PendingIntent kontrolleri regresyonsuz.
  - [ ] API 33/34/35/36 testleri: izin ilk kurulum, ret, geri alma, reboot, timezone, force-stop dışı process death, 3 paralel timer, full-screen açık/kapalı.
- **Veri/Migration etkisi:** Yok. Geri alma manifest/native commitidir; kullanıcı alarm verisi korunur.
- **RLS/Güvenlik:** Exported receiver spoofing kapalı; permission intent'leri explicit/package-scoped; secret yok.
- **Edge-case'ler:** OEM ayar intent'i bulunmaz; izin sonradan geri alınır; alarm tam izin değişiminde; Android 13/14 davranış farkı; Play/Sideload manifest farkı; reboot.
- **Kabul (ölçülebilir):** Play manifestinde yalnız kanıtlı izinler; dış adb broadcast timer state değiştiremez; exact/FSI reddinde uygulama çökmez ve fallback alarm oluşur; API33 + Samsung/Pixel API34–36 cihaz matrisinde P0=0; 8 saat timer sapması ≤±1 sn; analyze/test/release build yeşil.
- **Tuzaklar:** Saat özelliği var diye otomatik “core alarm app” kabul etmek; manifestten izni kaldırıp kodu fallback'siz bırakmak; dataSync'i uzun sayaç etiketi olarak savunmak; OEM ayar ekranını garanti sanmak.
- **Bağımlılık/çakışma:** WP-110 sonrası tek başına Android sıcak lane. WP-122 AAB bundan sonra.
- **Dal:** `main`
- **Model önerisi:** 🔴 Grok 4.5 — native/policy/OEM riski

### WP-119: Veri Envanteri, Data Safety ve Sentry Beyan Paketi 🔐
- **Program/Faz:** Play Store · Faz A — Disclosure evidence
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-111, WP-114, WP-116, WP-118 davranışları sabit
- **Problem:** Data Safety yalnız tahminle doldurulamaz; uygulama, SDK, server, storage ve build flag'lerinin gerçek veri gönderimi tür/amaç/opsiyonellik/silme bazında kanıtlanmalı.
- **Kapsam dışı:** Play Console'a kullanıcı adına submit; hukuk görüşü; yeni veri toplama özelliği.
- **SAHİP dosyalar (yaz):**
  - `docs/play-store/DATA-INVENTORY.md`
  - `docs/play-store/DATA-SAFETY-ANSWERS.csv`
  - `docs/play-store/SDK-DATA-MATRIX.md`
  - `docs/play-store/PRIVACY-CONSISTENCY-CHECK.md`
  - gerekirse yalnız test/konfig doğrulaması için observability testleri
- **DOKUNMA (oku, değiştirme):** Ürün kodu; Console; secrets. Davranış eksikliği bulunursa ayrı debug WP açılır, bu evidence WP'sinde gizlice düzeltilmez.
- **Adımlar:**
  - [ ] E-posta, isim, avatar, session/subject, presence, chat, group, XP, feedback attachment, notification preference, offline cache/outbox, Sentry ve e-posta raporunu kaynak→amaç→saklama→silme→işleyici bazında çıkar.
  - [ ] “Collected”ı cihaz dışına iletim olarak değerlendir; yalnız yerel SharedPreferences verisini yanlışlıkla collected sayma, fakat backup/sync davranışını doğrula.
  - [ ] Supabase/Sentry/image_picker/home_widget ve diğer SDK'ların gerçek konfigürasyonunu incele. `sendDefaultPii=false`, traces=0 ve controlled breadcrumbs kanıtını testle; release build'de `SENTRY_ENABLED`/DSN durumunu kaydet.
  - [ ] Her veri türü için collected/shared, required/optional, purpose, encryption in transit, ephemeral, deletion mechanism cevaplarını CSV'ye koy; bilinmeyeni “hayır” varsayma.
  - [ ] Privacy policy, in-app disclosure, account deletion ve Data Safety cevapları arasında otomatik/manuel consistency checklist çalıştır.
  - [ ] Closed/open/production track'in Data Safety kapsamında, yalnız internal-only artefaktın istisna olabileceğini runbook'a yaz.
- **Veri/Migration etkisi:** Yok; read-only audit.
- **RLS/Güvenlik:** Kanıt dosyasına kullanıcı verisi, DSN token, env değerleri veya service role girmez; yalnız alan adı/boolean/veri sınıfı.
- **Edge-case'ler:** Sentry buildde kapalı ama eski Play artefaktında açık; farklı flavor veri davranışı; avatar kullanıcı seçimine bağlı; silme grace dönemi; third-party processor alt işleyicileri.
- **Kabul (ölçülebilir):** Kod/SDK envanterindeki her ağ veri yolu bir Data Safety satırına bağlı; privacy-vs-form çelişkisi 0; bilinmeyen cevap 0 veya açık Console doğrulama maddesi; release konfig testleri yeşil; iki kişi/ajan çapraz review checklist'i tamamlanmış.
- **Tuzaklar:** Supabase'i “shared”/“processor” ayrımını kanıtsız yorumlamak; yalnız permission listesine bakmak; Sentry build flag'ini kullanıcı opt-out sanmak; eski aktif track artefaktını unutmak.
- **Bağımlılık/çakışma:** Doküman-only; ürün davranışları sabitlenmeden başlanmaz.
- **Dal:** `main`
- **Model önerisi:** 🔴 Grok 4.5 — veri sınıflandırma doğruluğu

### WP-120: Store Listing, App Content Formları ve Reviewer Erişimi 📝
- **Program/Faz:** Play Store · Faz A/D — Console readiness
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-111 + WP-119
- **Problem:** Mağaza metni/görselleri, hedef kitle, içerik derecelendirme, app access ve kısıtlı izin beyanları olmadan AAB teknik olarak doğru olsa bile review tamamlanamaz.
- **Kapsam dışı:** Formları/production rollout'u kullanıcı onayı olmadan göndermek; yanıltıcı alarm/çocuk/gizlilik iddiası.
- **SAHİP dosyalar (yaz):**
  - `docs/play-store/STORE-LISTING.{tr,en}.md`
  - `docs/play-store/APP-CONTENT-ANSWERS.md`
  - `docs/play-store/REVIEWER-GUIDE.md`
  - `docs/play-store/PERMISSION-DECLARATIONS.md`
  - `store-assets/android/**` (ikon/feature graphic/screenshot kaynakları ve redacted çıktılar)
- **DOKUNMA (oku, değiştirme):** App/manifest; Play Console canlı state; kullanıcı secret'ı. Demo hesap parolası repoya yazılmaz.
- **Adımlar:**
  - [ ] Ad ≤30, kısa ≤80, uzun ≤4000 karakter sınırlarında TR/EN listing; yalnız gerçekten çalışan özellik/izin davranışı. “Varsayılan alarm uygulaması” veya “kesin çalışır” gibi kanıtsız iddia yok.
  - [ ] 512×512 ikon, 1024×500 feature graphic, telefon/tablet ekran görüntüleri; beta etiketi, gerçek e-posta, token, grup davet kodu ve kullanıcı PII'si temizlenir.
  - [ ] App access için ayrı reviewer hesabı + önceden dolu güvenli test grubu/oturumu; şifre secret manager/Console alanında, repo dışında. 60 sn timer, alarm, chat, report/block ve hesap silme yollarını adım adım yaz.
  - [ ] Ads, target audience, content rating, Data Safety, account deletion URL, privacy URL, news/health/financial/government formlarına WP-119 kanıtına bağlı cevap paketi hazırla.
  - [ ] Hedef kitle kararı: Families hedeflenmiyorsa chat/sosyal yapıyla uyumlu 13+/16+ seçim ve nötr yaş beyanı; gerçekte uygulanmayan age gate iddiası yok.
  - [ ] FGS her type için işlev, ertelenme/kesinti etkisi ve tetikleme videosu; exact alarm ve FSI için core functionality/fallback açıklaması. Console onayı yoksa WP-118 safe manifest yolu kullanılır.
  - [ ] Yeni kişisel geliştirici hesabı olup olmadığını kaydet; WP-124'te 12 tester/14 gün şartını koşullandır.
- **Veri/Migration etkisi:** Yok.
- **RLS/Güvenlik:** Reviewer hesabı en az yetkili; admin/service role verilmez; assetlerde PII yok.
- **Edge-case'ler:** Reviewer lokali EN; alarm izni reddedilmiş; boş yeni hesap; public group yok; tablet screenshot zorunluluğu; Console soruları değişmiş.
- **Kabul (ölçülebilir):** Tüm zorunlu listing/form alanları cevaplı; metin limitleri otomatik doğrulanmış; asset boyutları birebir; reviewer akışı temiz kurulumda ≤10 dk tamamlanır; permission videoları erişilebilir URL; secret repo taraması 0 bulgu.
- **Tuzaklar:** Store metninde özelliği abartmak; kapalı beta package'ını policy dışı sanmak; demo hesabına admin vermek; Console formunu repo tahminiyle “tamamlandı” işaretlemek.
- **Bağımlılık/çakışma:** WP-118 permission gerçekleri ve WP-119 veri cevapları değişirse bu kart yeniden review olur.
- **Dal:** `main`
- **Model önerisi:** 🟣 Grok 4.5 — içerik/Console kontrolü

### WP-121: Production Migration, Edge Deploy ve RLS Operasyon Kapısı 🗄️
- **Program/Faz:** Play Store · Faz B — Backend/ops
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** 0034–0038/hesap+UGC migrations ve Edge kodları tamam
- **Problem:** Yerel migration/Edge dosyası canlı deploy kanıtı değildir. 0034 index, 0035 cron, 0036 güvenlik ve yeni hesap/UGC şemaları uygulanmadan Play kullanıcıları eski güvenlik/ops davranışına düşer.
- **Kapsam dışı:** Yeni ürün özelliği; kullanıcı onayı olmadan destructive SQL; Play upload.
- **SAHİP dosyalar (yaz):**
  - `docs/BACKEND-DURUM.md`
  - `docs/play-store/PROD-DEPLOY-RUNBOOK.md`
  - `docs/play-store/RLS-SMOKE.sql` (read-only/transaction rollback güvenli test)
  - gerekirse deployment scriptleri; mevcut migration içerikleri değiştirilmez
- **DOKUNMA (oku, değiştirme):** App; migration geçmiş dosyaları; production secrets değerleri; canlı SQL kullanıcı açıkça koştur demeden çalıştırılmaz.
- **Adımlar:**
  - [ ] Canlı `schema_migrations`, tablo/kolon/policy/function/index ve Edge version envanterini al; secrets değerini göstermeden var/yok doğrula.
  - [ ] 0034→0035→0036→0037→0038 sırasını ve `CONCURRENTLY`/transaction kısıtını runbook'ta ayır. Her adım öncesi backup/rollback ve sonrasında verification query.
  - [ ] `CRON_SECRET`, functions base URL, service role GUC/secret ve Resend bağımlılığını fail-closed sırada kur; önce secret/job, sonra auth isteyen Edge deploy; mail hattını yanlış sırayla kesme.
  - [ ] Edge `collect-reports`, `send-report`, account deletion ve moderation fonksiyonlarını deploy edip unauthorized/authenticated/admin/cron çağrı matrisiyle test et.
  - [ ] RLS smoke: profiles ortak grup görünürlüğü, monthly stats self/admin, private/public group, chat, report reporter privacy, block, deletion owner-only.
  - [ ] SQL/Edge sonrası gerçek test hesaplarında regresyon; service role ve token terminal çıktısında redakte.
- **Veri/Migration etkisi:** Canlı değişiklik ancak kullanıcı açık komutuyla. Her migration'ın rollback/forward-fix planı; destructive rollback yerine veri koruyan forward-fix öncelikli.
- **RLS/Güvenlik:** En kritik kapı; anon/authA/authB/groupAdmin/superAdmin/service test matrisi. Secret hiçbir MD/log/commit'e girmez.
- **Edge-case'ler:** Migration kısmen uygulanmış; index zaten var; cron extension yok; Edge eski version; secret mismatch; test account ortak grupta değil; realtime policy cache.
- **Kabul (ölçülebilir):** Yerel/canlı migration farkı 0; zorunlu Edge versionları eşleşir; unauthorized çağrılar 401/403; RLS matrix expected sonuç %100; cron dry-run tek job üretir; rollback/forward-fix komutları gözden geçirilmiş.
- **Tuzaklar:** “Dosya var”ı deploy saymak; SQL Editor'a tüm dosyaları tek transaction yapıştırmak; secret'ı kanıt ekranına almak; live testte gerçek kullanıcı verisi kullanmak.
- **Bağımlılık/çakışma:** Tek ops lane; başka migration/Edge worker aktifken başlamaz.
- **Dal:** `main` (doküman/script commit; canlı deploy ayrı kullanıcı yetkisi)
- **Model önerisi:** 🔴 Grok 4.5 — production güvenliği

### WP-122: Play AAB, Target API 36, İmza ve Artefakt Doğrulama 📦
- **Program/Faz:** Play Store · Faz C — Build/release engineering
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-110 + WP-118
- **Problem:** Play APK yerine AAB, güncel target API, Play App Signing/upload key ve versionCode ister. Mevcut `v29` tag'i WP-104'te; HEAD WP-105–109'u aynı `+29` ile taşıdığı için yeni build numarası zorunlu.
- **Kapsam dışı:** Production rollout (WP-124); backend deploy (WP-121); mağaza metni (WP-120).
- **SAHİP dosyalar (yaz):**
  - `app/android/app/build.gradle.kts` (yalnız compile/target/signing gerekiyorsa)
  - `app/pubspec.yaml` (yalnız onaylı version bump)
  - `.github/workflows/play-release.yml` (yeni)
  - `docs/play-store/PLAY-BUILD-RUNBOOK.md`
  - release artefakt checksum/provenance çıktıları (binary commit edilmez)
- **DOKUNMA (oku, değiştirme):** Keystore/key.properties içeriği; GitHub sideload workflow'u WP-110 sözleşmesi dışında; app feature kodu.
- **Adımlar:**
  - [ ] Güncel Flutter/AGP/SDK ile effective compileSdk/targetSdk'i build çıktısı ve merged manifestten doğrula. 31 Ağustos 2026 yeni app/update hedefi için API 36 hazırlığını tamamla; API yükseltme regresyonlarını listele.
  - [ ] Yeni Play adayında versionCode >29 belirle; sürüm numarası ürün kararıdır. Mevcut v29 tag'ini yeniden taşımak/overwrite etmek yasak.
  - [ ] Play App Signing stratejisi: mevcut release key ile upload key ilişkisi, encrypted iki yedek ve kurtarma sahibi. Keystore'u yeniden üretme/repoya koyma.
  - [ ] `flutter build appbundle --flavor play --release --dart-define-from-file=env.json` üret; AAB `bundletool` validate, 64-bit ABI, package ID, min/target, version, izinler, debuggable=false, signature/upload cert fingerprint doğrula.
  - [ ] Obfuscation kullanılacaksa symbols mapping'i private artefakt olarak sakla; Sentry release `version+build` ile eşleşsin.
  - [ ] CI secret'ları yalnız ephemeral key.properties oluşturur; log redaction; artefakt SHA-256/provenance. Play manifest installer permission kontrolü tekrar.
  - [ ] Internal track için upload edilebilir aday üret ama kullanıcı istemeden Console upload/tag/push yapma.
- **Veri/Migration etkisi:** Yok.
- **RLS/Güvenlik:** Secrets repo/log dışında; signing key kalıcı; artifact SBOM/dependency lisans ve secret scan.
- **Edge-case'ler:** API36 build tool eksik; Play App Signing ilk enrollment; aynı versionCode; yanlış flavor; beta suffix; key alias yanlış; AAB local install için bundletool gerekir.
- **Kabul (ölçülebilir):** AAB validate PASS; package ID doğru; versionCode >29; targetSdk 36; 64-bit mevcut; debuggable false; `REQUEST_INSTALL_PACKAGES` yok; imza fingerprint beklenen; analyze + tam test + Play release build yeşil; SHA-256 kayıtlı.
- **Tuzaklar:** APK yüklemeye çalışmak; v29 tag'ini force etmek; debug key; targetSdk'i varsaymak; env.json'u artefakta/commit'e dahil etmek.
- **Bağımlılık/çakışma:** `build.gradle`/`pubspec` sıcak; tek başına. WP-123 bu AAB'yi test eder.
- **Dal:** `main`
- **Model önerisi:** 🔴 Grok 4.5 — signing/SDK/release riski

### WP-123: Play Kritik Cihaz QA, Erişilebilirlik ve Pre-Launch Kapısı 🧪
- **Program/Faz:** Play Store · Faz C — Gerçek cihaz kanıtı
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-114/116/118/121/122
- **Problem:** Otomatik test native/OEM, gerçek Supabase, Play install ve kullanıcı yolculuğunun kanıtı değildir. WP-103–109 park maddeleri de aynı aday üzerinde kapatılmalıdır.
- **Kapsam dışı:** Bulunan P0/P1'i bu WP içinde plansız düzeltmek; production rollout.
- **SAHİP dosyalar (yaz):**
  - `docs/play-store/QA-PLAY-ANDROID.md`
  - `app/integration_test/play_critical_flows_test.dart` ve support fixture'ları
  - `docs/play-store/PRE-LAUNCH-REPORT.md`
  - test kanıt indeksleri (PII redakte; büyük video repo dışında)
- **DOKUNMA (oku, değiştirme):** Ürün kodu. Bug çıkarsa yeni debug WP açılır; bu QA kartı yalnız kanıt/sonuç yazar.
- **Adımlar:**
  - [ ] Cihaz matrisi: Android 13/API33; API34; API35; API36; fiziksel Samsung One UI + Pixel/AOSP. Play Internal'dan kurulum ve update; sideload build ile karıştırma.
  - [ ] Timer/FGS: 20 notification/widget start-stop, 30 dk kilit, process death, reboot, battery restriction, 8 saat epoch sapma; crash/logcat ve çift session 0.
  - [ ] Alarm: exact izni kabul/ret/revoke, FSI kabul/ret, timezone/time change, reboot, 3 timer, fallback notification; uygulama kapalı.
  - [ ] Veri: offline 10 dk→sync, iki cihaz, İstanbul 23:59→00:01, presence ≤70 sn, XP profil açmadan, 0034–0038 RLS gerçek hesaplarla.
  - [ ] Account deletion: in-app/web request, wrong re-auth, pending login, cancel, staging fast-forward hard purge, local wipe ve başka grup üyelerinin veri korunumu.
  - [ ] UGC: terms, message/profile/group report, block/unblock, admin hide/restore, reporter privacy.
  - [ ] A11y/perf: TalkBack, font %200, 48 dp, kontrast, reduce motion, tablet/fold layout; cold start, jank, ANR, battery gözlemi.
  - [ ] Play Pre-launch report/Firebase Test Lab sonuçlarını çalıştır; permission/policy crawler erişimi için reviewer hesabı.
- **Veri/Migration etkisi:** Test hesapları/fixtures; gerçek kullanıcı verisi yok. QA sonunda test data cleanup runbook'u.
- **RLS/Güvenlik:** Kanıtlarda e-posta/token/invite code redakte; test service role cihazda yok.
- **Edge-case'ler:** OEM alarm kısıtı; ağ captive portal; Play Protect; app update sırasında timer; silme cron gecikmesi; reviewer locale EN.
- **Kabul (ölçülebilir):** P0=0, açık P1=0 veya yazılı ürün waiver; crash/ANR 0; tüm zorunlu satırlarda cihaz/build/tarih/PASS/video yolu; pre-launch critical issue 0; analyze/tam test/AAB aynı committe; Samsung+Pixel kanıtı mevcut.
- **Tuzaklar:** Emülatörü OEM kanıtı saymak; farklı commit APK test etmek; FAIL'i checkbox ile kapatmak; PII'li video commit etmek.
- **Bağımlılık/çakışma:** Ürün koduna yazmaz; bulgu yeni numaralı debug WP açar ve WP-124'ü bloklar.
- **Dal:** `main` (QA docs/tests)
- **Model önerisi:** 🔴 Grok 4.5 — entegrasyon/kanıt yönetimi

### WP-124: Internal/Closed Test, Soak, GO/NO-GO ve Staged Rollout 🚀
- **Program/Faz:** Play Store · Faz D — Release gate
- **Ajan:** —
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-119–123 PASS
- **Problem:** Teknik AAB'nin production'a basılması release değildir; tester şartı, feedback/telemetry, rollback, staged rollout ve yayın sonrası doğrulama kapısı gerekir.
- **Kapsam dışı:** Kullanıcı açıkça istemeden Play Console submit/rollout/push/tag; açık P0 ile risk kabulü.
- **SAHİP dosyalar (yaz):**
  - `docs/play-store/PLAY-RELEASE-GATE.md`
  - `docs/play-store/CLOSED-TEST-PLAN.md`
  - `docs/play-store/SOAK-REPORT.md`
  - `docs/play-store/PLAY-ROLLBACK.md`
  - `docs/VERSIONS.md`, `CHANGELOG.md`, `app/assets/release_notes.json` (yalnız GO adayı kesinleşince)
- **DOKUNMA (oku, değiştirme):** Ürün kodu; Console kullanıcı onayı olmadan; mevcut tag'leri force etme.
- **Adımlar:**
  - [ ] Geliştirici hesabı türü/tarihini doğrula. 13 Kasım 2023 sonrası kişisel hesapsa en az 12 tester'ın 14 gün kesintisiz closed test opt-in şartını zorunlu planla; değilse bile proje kalite kapısı olarak ≥3 gün gerçek kullanım soak uygula.
  - [ ] Önce Internal track: 5–20 güvenilir hesap, reviewer guide, feedback kanalı, crash/ANR, timer/alarm/account deletion/UGC görev listesi.
  - [ ] Closed track boyunca build değişirse hangi kanıtların yeniden başlayacağını/korunacağını yaz; tester opt-in continuity ve gerçek kullanım geri bildirimini kaydet.
  - [ ] GO matrisi: legal URL, account deletion, UGC, Data Safety, permissions, backend deploy, AAB, device QA, pre-launch, signing backup, reviewer account, rollback; her satır kanıt linkli.
  - [ ] Rollback Play'de düşük versionCode APK değildir: dağıtımı durdur, bilinen iyi davranıştan daha yüksek versionCode forward-fix. Server migration için forward-fix/feature disable; destructive down migration yok.
  - [ ] Production kullanıcı onayı sonrası staged rollout: öneri %10→%25→%50→%100; her aşama en az 24 saat veya yeterli aktif cihaz. Halt: herhangi P0, crash-free eşiği altı, ANR artışı, deletion/moderation güvenlik hatası.
  - [ ] Yayın sonrası 24/72 saat: install/update, login, timer, alarm, sync, deletion web URL, UGC report queue, Edge cron, Sentry PII audit; “Yayın sonrası doğrulandı” ancak bunlardan sonra.
  - [ ] GO'da version/release notes tek kaynaklarını güncelle; tag/push/Console eylemi kullanıcı açık emriyle ayrı adım.
- **Veri/Migration etkisi:** Yeni migration yok; canlı rollout/ops etkisi yüksek. Rollback planı zorunlu.
- **RLS/Güvenlik:** Reviewer/tester hesapları sınırlı; secrets repo dışı; security regression otomatik NO-GO.
- **Edge-case'ler:** 12 tester'dan biri opt-out; Console review ek bilgi ister; FGS/FSI declaration reddi; staged rolloutta yalnız OEM crash; server forward-fix gerekir.
- **Kabul (ölçülebilir):** Zorunlu tüm gate satırları PASS+kanıt; yeni kişisel hesapta 12/12 tester ≥14 kesintisiz gün; soak P0=0/P1=0 veya waiver; rollback artefakt/runbook hazır; production ancak kullanıcı “GO” dediğinde; 72 saat sonrası doğrulama tamam.
- **Tuzaklar:** Closed test'i “isteğe bağlı” saymak; Internal-only Data Safety istisnasını closed track'e taşımak; %100 tek adım rollout; eski APK'yı rollback sanmak; ürün sahibi onayı olmadan tag/push.
- **Bağımlılık/çakışma:** Programın son seri kapısıdır; açık debug WP varken başlamaz.
- **Dal:** `main`
- **Model önerisi:** 🔴 Grok 4.5 — release/operasyon koordinasyonu

### Play Programı Dalga ve Çakışma Matrisi

| Dalga | Çalışabilecek WP'ler | Seri kısıt / gerekçe |
|---|---|---|
| 1 | WP-110 + WP-111 | Ayrık Android dağıtım ve legal/UI yüzeyi; aktif lane yok |
| 2 | WP-112 | Migration 0037 ve retention kararı tek başına |
| 3 | WP-113 + WP-114 hazırlığı | Edge ve Flutter ayrık; WP-114 API contract sabitlenince |
| 4 | WP-115 | Sonraki migration; account deletion migration/Edge ile seri |
| 5 | WP-116 + WP-117 | Kullanıcı/admin UI ayrık; ARB ortaksa sırala |
| 6 | WP-118 | Manifest/native sıcak yüzey; WP-110 sonrası tek başına |
| 7 | WP-119 + WP-121 hazırlığı | Evidence read-only; canlı ops kullanıcı yetkisi ister |
| 8 | WP-120 + WP-122 | Store içerik ve AAB ayrık; build.gradle yalnız WP-122 |
| 9 | WP-123 | Tek aday commit üzerinde cihaz/pre-launch kanıtı |
| 10 | WP-124 | Son GO/NO-GO, closed test ve rollout |

> ✅ **Aktif-lane kontrolü (2026-07-17):** Gemini, Claude, Codex ve Grok uygulama lane'leri boşta; yalnız bu planner doküman lane'i aktiftir. Parktaki WP-103–109 çakışma sayılmaz. `OPTIMIZATIONS.md` kullanıcıya ait dirty dosyadır ve bu program commitine alınmaz.
>
> ⚠️ **Ürün kararları:** (1) WP-66 §0 retention varsayılanları, (2) legal site domain/iletişim kimliği, (3) hedef kitle 13+/16+, (4) Play Console'da alarmı core functionality olarak savunma veya safe fallback, (5) geliştirici hesap türü/tarihi. Bunlar planı engellemez; ilgili WP başlamadan kullanıcı onayı gerekir.

## Test için bekleyenler

### WP-154: Gamification genişletme (kod+test) 🏆
- **Özet:** level=√(xp/50)+1 türetilmiş; görevler görüntü; kozmetik free L3; 0043 cosmetics+dict; client XP yazmaz.
- **Migration:** 0043 SQL Editor
- **Kanıt:** `Kodda doğrulandı` · **`Cihazda doğrulanmalı`**
- **Commit:** (bu)

### WP-153: Akıllı hatırlatıcılar (kod+test) 🔔
- **Özet:** Seri koruma (20:00) + haftalık özet (Pazar 18:00) opt-in; sessiz saat; idempotent schedule; FGS/timer dokunulmadı.
- **Test:** smart_reminder_scheduler_test · analyze 0
- **Kanıt:** `Kodda doğrulandı` · **`Cihazda doğrulanmalı`**
- **Commit:** (bu commit)

### WP-152: Veri dışa aktarma (kod+test) 📦
- **Özet:** Self-only JSON export; hot/year/all; share_plus; InMemory+Supabase; Ayarlar girişi.
- **Test:** data_export_test 3 geçti · analyze 0
- **Kanıt:** `Kodda doğrulandı` · **`Cihazda doğrulanmalı`** (paylaşım sheet, offline hata)
- **Commit:** (bu commit)

### WP-151: Onboarding (kod+test) 👋
- **Özet:** 4 adım atlanabilir; bildirim izni (red OK); grup oluştur/katıl/atla; prefs `onboarding.completed_v1`.
- **Test:** analyze 0 · onboarding_test 3 geçti.
- **Kanıt:** `Kodda doğrulandı` · **`Cihazda doğrulanmalı`** (ilk login, skip, izin red, grup).
- **Commit:** (bu commit)


> Kod/otomatik test bitti; **cihaz QA veya ürün demo’su** bekleniyor.
> Bu bölüm **aktif çalışma değildir** — ajan claim etmez, diğer WP’leri engellemez.
> Kabul gelince kart buradan çıkar → **Tamamlanan**’a gider. Bug çıkarsa ayrı debug WP açılır.

### WP-164: Analitik teslim düzeltmesi (kod+otomatik test) 📊
- **Özet:** Gerçek 6 sütun x/y/w/h ızgara + `grid_reflow`; düzenleme (ekle/sil/sürükle/boyut/sıfırla); dönem year/custom + kıyas toggle; placeholder yasak (subjectStacked, leaderboard history, member donut, yıl aralığı `get_user_day_totals`); çift `AnalyticsQueryRepository`; migration **0042** `start_time` düzeltmesi; flag default kapalı.
- **DOKUNMA:** Timer/widget/FGS, `dashboard_layout_*`, `group_daily_totals` sözleşmesi.
- **Test:** `flutter analyze` 0 · `flutter test test/features/stats/` yeşil · reflow/period/aggregate widget testleri.
- **Migration:** `0042_fix_study_sessions_start_time.sql` → SQL Editor (CREATE OR REPLACE). RLS plan: `docs/features/ANALYTICS-RLS-TEST-PLAN.md`.
- **Kanıt:** `Kodda doğrulandı` · **`Cihazda doğrulanmalı`** (flag on: ızgara sürükle-boyut, dönem/kıyas, gerçek grup kartları; flag off: eski StatsPeriodBar + Personal/Class birebir; TalkBack 48dp).
- **Dal:** main · Push yok.

### WP-156: İstatistik & Gruplar analitik PLANI (docs) 📊
- **Özet:** Özelleştirilebilir stats/grup ızgarası, 18+ kart, grafik seti, RPC/RLS, faz WP-157–163. WP-150 devredildi; WP-149 kart.
- **Teslim:** `docs/features/ISTATISTIK-GRUPLAR-ANALITIK-PLAN.md` · `DATA-APP-ARASTIRMA.md`
- **Kanıt:** `Kodda doğrulandı` (mevcut altyapı okuma) · **Ürün kararı / Claude checklist onayı bekliyor**
- **Sonraki:** Onaysız kod/migration yok.

### WP-140: Erişilebilirlik geçişi (kod tamam) ♿
- **Özet:** İkon-only tooltip/Semantics; min 48dp; overflow; izin kartı ikon+renk.
- **Commit:** `e5f8b55` · docs: `docs/a11y/ERISILEBILIRLIK-DENETIM.md`
- **DOKUNMA:** timer/widget/FGS (WP-134–137)
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı` (TalkBack, textScale 1.3)
- **Bağımlılık:** WP-123 pre-launch

### WP-141: Tema-bağlama denetimi (kod tamam) 🎨
- **Özet:** İhlal Colors → colorScheme; palet/alarm/lap meşru işaretli.
- **Commit:** `812307f` · docs: `docs/a11y/TEMA-BAGLAMA-DENETIM.md`
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı` (light/dark)
- **Bağımlılık:** WP-123 kontrast

### WP-138: Sürüm notları v28/v29 + taslak v30 (kod/docs tamam) 📝
- **Özet:** `release_notes.json` + CHANGELOG senkron; forLocale/asset test. **v30 build 30 taslak** — numara release kapısında kesinleşir (pubspec 1.0.29+29).
- **Commit:** `c6529c1`
- **Dil:** MaterialApp.locale → Localizations → forLocale; non-tr → EN, EN boş → TR. Sapma yok.
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı` (Ayarlar → Yenilikler, TR/EN)

### WP-139: l10n denetim (kod/docs tamam) 🌐
- **Özet:** ARB EN/TR parity 100%; admin hardcoded ARB; native 66/66; `docs/l10n/L10N-DENETIM.md`.
- **Commit:** (bu commit)
- **Native sınır:** bildirim/widget = sistem dili, app dili değil.
- **Kanıt:** `Kodda doğrulandı` · analyze 0

### WP-134: 1×1 widget Chronometer görünür (kod tamam) ⏱️
- **Özet:** Compact GONE kaldırıldı; 1 hücre minSize; saat üstte mini düğme altta.
- **Commit:** `479b2a8` · **S:** S5 (1×1 görünür) S6 (akış)
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı`

### WP-135: Toggle atomikliği + TimerStateStore (kod tamam) 🔁
- **Özet:** Tüm yazımlar `commit()`; idle=00:00:00; pending commit.
- **Commit:** `e8aba1f` · **S:** S3/S4 20 tur
- **Test:** `timer_state_store_semantics_test` PASS
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı`

### WP-136: Reconcile SSOT (kod tamam) 🔄
- **Özet:** STATE_CHANGED engine-scope; pending clear yarışı; ms türevi.
- **Commit:** `833c0f7` · **S:** S1/S2/S11
- **Test:** `timer_reconcile_ssot_test` PASS
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı`

### WP-137: Dinamik panel P2 (kod tamam) 🔔
- **Özet:** Default standard usesChronometer + Mola/Durdur; `timer_panel_expanded` flag default false. FGS tip/NOT_STICKY dokunulmadı.
- **Commit:** `1f4f4d6` · **S:** S12 + bildirim akış; terfi bonus
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı` (Samsung/Pixel/Xiaomi)

### WP-133: Widget & Dinamik Panel kararlılık ANALİZİ (docs) 📐
- **Özet:** Kök neden (1×1 compact Chronometer GONE, stop `apply()` asimetri, reconcile yalnız resume, panel sarkacı WP-76→80→v23), SSOT önerisi, ürün P1/P2/P3, faz WP-134–139, cihaz matrisi.
- **Teslim:** `docs/widget-panel/WIDGET-DINAMIK-PANEL-ANALIZ.md` · `docs/widget-panel/GECMIS-DENEME-OTOPSISI.md`
- **Commit:** `cfc3e50`
- **Kanıt:** `Kodda doğrulandı` (salt okuma) · **Claude checklist onayı bekleniyor** · uygulama WP claim etme
- **Sonraki:** Checklist imzası → WP-134+

### WP-129: Engellenen kullanıcılar / unblock UI (kod tamam) 🚫
- **Özet:** Ayarlar → Engellenen kullanıcılar; `fetchBlockedProfiles` (in_memory+supabase); unblock + provider invalidate.
- **Commit:** `ed234b8`
- **Test:** `blocked_users_test` 2/2 PASS.
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı`.

### WP-130: Rapor sheet detay alanı (kod tamam) 📝
- **Özet:** Opsiyonel details ≤500; other vurgusu; `p_details` yolu.
- **Commit:** `fde7e0a` (ARB anahtarları tree’de)
- **Test:** `report_sheet_details_test` 2/2 PASS.
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı` (canlı ugc_reports.details).

### WP-131: Analyze 0 issue (kod tamam) 🧹
- **Özet:** group_repository type checks, updater_dialog mounted, unused import.
- **Commit:** `b832626`
- **Kanıt:** `Kodda doğrulandı` — `flutter analyze` → No issues found.

### WP-132: DATA-SAFETY envanter (docs tamam) 📋
- **Özet:** `docs/play-store/DATA-SAFETY.md` kanıt tablosu; `PLAY-RELEASE-GATE.md` Console TODO.
- **Commit:** `30e89bc`
- **Kanıt:** `Kodda doğrulandı` (docs) / `Console'da doğrulanmalı`.

### WP-125: UGC Rapor + Engel UI giriş noktaları (kod tamam) 🛡️
- **Özet:** Sohbet peer long-press → Bildir (`showReportSheet` / `report_ugc`) + Engelle (onay + `block_user`). Sosyal profil AppBar menüsü (user target). ARB `safety*` + `blockedUserIdsProvider`.
- **Commit:** `a59e331`
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı` (iki hesap: long-press menü, rapor sheet, engel snackbar).
- **DOKUNMA yapılmadı:** 0038, admin kuyruk, purge Edge.

### WP-126: Engellenen içerik filtreleme (kod tamam) 🙈
- **Özet:** `blockedUserIdsProvider` ile sohbet mesajları ve kamp ateşi üye/presence listesi engellenenleri gizler; block sonrası invalidate.
- **Commit:** `caa3b69`
- **Test:** `moderation_block_filter_test` 2/2 PASS.
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı` (A engeller B → mesaj/presence kaybolur).

### WP-127: purge-accounts retry terminal (kod tamam) 🔁
- **Özet:** Fetch `attempt_count < 5`; hata sonrası `<5` → `scheduled`, `>=5` → terminal `failed`. `last_error_code` sınıflı. deleteUser cascade completed notu.
- **Commit:** `1f890c0`
- **Kanıt:** `Kodda doğrulandı` / `Canlıda doğrulanmalı` (Edge deploy + cron dry-run).
- **DOKUNMA yapılmadı:** hesap silme UI, diğer Edge.

### WP-128: Play flavor kanal zorlaması (kod tamam) 🏪
- **Özet:** `DistributionConfig.resolve`: `FLUTTER_APP_FLAVOR=play` → her zaman `play`, `allowsSideloadUpdates=false` (define unutulsa/yanlış github* olsa bile). play meta-data + birim testler.
- **Commit:** `ee5428f`
- **Test:** `distribution_channel_test` 9/9 PASS.
- **Kanıt:** `Kodda doğrulandı` / `Cihazda/CI doğrulanmalı` (`--flavor play` define’sız AAB smoke).

### WP-110: Play dağıtım kanalı + updater izolasyonu (kod tamam) 🏪
- **Özet:** `play` flavor; `REQUEST_INSTALL_PACKAGES` yalnız stable/beta; Play’de `checkForUpdate` ağ çağrısı yok; CI `DISTRIBUTION_CHANNEL`.
- **Komut:** `flutter build appbundle --flavor play --release --dart-define=DISTRIBUTION_CHANNEL=play --dart-define-from-file=env.json`
- **Beklenen:** merged play manifest installer izni 0; stable/beta updater çalışır (`Cihazda/CI doğrulanmalı`).

### WP-104: Presence bayatlama + stop oturum sırası (kod tamam) 🩹
- **Özet:** Cache/local presence `updatedAt` damgası; null aktif satır offline; `stop()` önce `_recordSession` sonra `_finish`.
- **Dosyalar:** `offline_cache_store.dart`, `presence_providers.dart`, `study_providers.dart`, ilgili testler.
- **Test:** presence + offline_first + timer_state_machine (WP-104 senaryoları dahil) yeşil.
- **Beklenen:** Cihazda sayaç durunca presence ≤70s “çalışıyor” temizlenir; app-içi Durdur süre kaybı yok.
- **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı`.

### WP-105: XP oturum bitince tetik (kod tamam) 🏆
- **Özet:** `achievementProgressLifecycleProvider` HomeShell’de; debounce 800ms + session count/sum coalesce.
- **Commit:** `46bdf60`
- **Test:** `achievement_lifecycle_test` yeşil.
- **Beklenen:** Profil açmadan oturum sonrası XP; `Cihazda doğrulanmalı` + Supabase ledger.

### WP-106: watchMembers Map + index (kod tamam) 🧹
- **Özet:** Map eşleştirme; migration `0034_group_members_active_index.sql`.
- **Beklenen:** SQL Editor’da 0034 uygula (`CONCURRENTLY` tek statement).

### WP-107: Manuel oturum İstanbul gün sınırı + UTC yazım (kod tamam) 🕛
- **Commit:** `110ec21`
- **Özet:** Manuel oturum duvar saati `Europe/Istanbul` takviminde kurulur; repository payload'ı UTC ISO-8601 yazar.
- **Beklenen:** İstanbul dışı cihaz TZ'sinde 23:59→00:01 sınırı doğru güne düşer; Supabase satırı UTC `Z` ile saklanır (`Cihazda/canlıda doğrulanmalı`).

### WP-108: Aylık rapor retry + cron (kod tamam) 📧
- **Commit:** `5b45fd0`
- **Özet:** `pending|failed` + `retry_count<3`; 0035 cron URL `app.settings.*`; edge `CRON_SECRET` / service_role.
- **Ops:** `CRON_SECRET` Edge secret; `app.settings.supabase_url`, `service_role_key`, `cron_secret` GUC; functions deploy.

### WP-109: Güvenlik sertleştirme (kod tamam) 🛡️
- **Özet:** 0036 monthly stats self/admin; profiles_select daraltma; group update/delete select doğrulama.
- **Beklenen:** 0036 SQL Editor; meşru grup/chat/kamp ateşi profil okuma regresyonu.

### WP-101: Saat XP 50 + stable v27 ⭐

- **Program/Faz:** XP ekonomi + release · **Aşama:** Kod + tag · **Kanıt:** `Kodda doğrulandı` / `Canlı SQL uygulanmalı`
- **Uygulandı:** Her tamamlanan 1 saat çalışma **50 XP** (eskiden 10). `kStudyHourXp=50` + `0033_study_hour_xp_50.sql` (RPC, sözlük, eski 10 XP saatlere +40 top-up).
- **Stable:** tag `v27` / `1.0.27+27` (main: WP-100 senkron + WP-99 bildirim/tercih).
- **ZORUNLU:** Supabase SQL Editor → `0033_study_hour_xp_50.sql` uygula; yoksa sunucu 10 XP vermeye devam eder.
- **Cihazda:** güncelleme + profil/başarım aç; 1 saat → +50 XP.

### WP-99: Tercih Kalıcılığı, Açılış Bildirimi ve Manuel Dil Seçimi 🔧

- **Program/Faz:** Debug · **Aşama:** Otomatik test geçti · **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı`
- **Uygulandı:** Aylık e-posta anahtarı kaydetme sürerken yerel değeri korur ve başarısız yazmada geri alır. Başlangıç anından önce oluşturulan dürtmeler sessizce temel alınır; yalnızca sonradan gelen yeni dürtmeler bir kez bildirilir. Ayarlar'a Sistem varsayılanı/Türkçe/İngilizce uygulama dili seçimi eklendi; seçim kalıcıdır ve ortak süre kısaltmalarına uygulanır.
- **Doğrulama:** Tercih, açılış dürtmesi ve dil kalıcılığı testleri; EN/TR V8 gezinme testi; `flutter analyze` 0 bulgu; tüm Flutter testleri 433/433; l10n audit 1002 Flutter ve 66 Android anahtarında temiz; yerel beta APK derlendi.
- **Cihazda doğrulanmalı:** beta-v26'da aylık e-posta anahtarını kapatıp sayfaya dön; eski dürtmeler varken cold start yap; sonra açık uygulamada yeni dürtme gönder. Ayarlar'dan Türkçe/İngilizce seç, metinleri ve `sa/dk/sn` / `h/m/s` sürelerini doğrula; uygulamayı yeniden açıp seçimin korunduğunu kontrol et.
- **Veri/RLS/Geri alma:** Migration/RLS etkisi yok. Aylık tercih mevcut profil alanını kullanır; geri alma bu istemci commitidir.

### WP-98: Türkçe Süre Kısaltmaları ve beta-v25 🔤

- **Program/Faz:** Debug · **Aşama:** Otomatik test geçti · **Kanıt:** `Kodda doğrulandı` / `Cihazda doğrulanmalı`
- **Uygulandı:** Ortak süre biçimleyici artık uygulamanın sistem/per-app dilini kullanır: Türkçe `4sa 5dk` / `40sn`; İngilizce `4h 5m` / `40s`. Bu, grafikleri, istatistik/özet/hedef/leaderboard kartlarını ve saniyeli sayaç özetlerini tek noktadan kapsar.
- **Doğrulama:** Türkçe ve İngilizce kısaltmalar için birim testleri; `flutter analyze` 0 bulgu; tüm Flutter testleri 430/430.
- **Cihazda doğrulanmalı:** beta-v25'te Android uygulama dilini Türkçe ve İngilizce yaparak Ana Sayfa/İstatistikler'de her iki biçimi de kontrol et.
- **Veri/RLS/Geri alma:** Veri, migration veya RLS etkisi yok. Geri alma, ortak süre biçimleme commitini geri almaktır.

## Tamamlanan İş Paketleri

> Biten her WP yalnız bu başlık altında tutulur. Buradaki kartlar tekrar aktif veya planlanan iş olarak yazılmaz.

| WP | Tamamlanan kapsam |
|---|---|
| WP-103 | 🔴 Android ≤13 FGS tip (dataSync|specialUse) + v29 — cihaz/ürün kabulü 2026-07-17 |
| WP-100 | Senkron kök fix: local emit, pull-to-refresh timeout, presence race — cihaz/ürün kabulü 2026-07-17 |
| WP-97 | Eski One UI sayaç satırı, pull-to-refresh, beta ayrımı, beta-v24 — cihaz/ürün kabulü 2026-07-17 |
| WP-95 | Başarım ayrıntılarında tam cümleli koşullar — cihaz/ürün kabulü 2026-07-17 |
| WP-94 | EN bağlam düzeltmeleri ve sade sayaç bildirimi — cihaz/ürün kabulü 2026-07-17 |
| WP-93 | Global grup keşfi ve katılım arayüzü — cihaz/ürün kabulü 2026-07-17 |
| WP-92 | Global açık/özel grup sözleşmesi, RLS ve çift repository — cihaz/ürün kabulü 2026-07-17 |
| WP-89 | EN/TR entegrasyon, audit, build ve cihaz QA — cihaz/ürün kabulü 2026-07-17 |
| WP-88 | Native Android EN/TR kaynak göçü — cihaz/ürün kabulü 2026-07-17 |
| WP-87 | Flutter göç C — saat, masaüstü, core ve veri etiketleri — cihaz/ürün kabulü 2026-07-17 |
| WP-86 | Flutter göç B — ana sayfa, sınıf ve istatistikler — cihaz/ürün kabulü 2026-07-17 |
| WP-85 | Flutter göç A — hesap, profil, admin, bildirim, güncelleme — cihaz/ürün kabulü 2026-07-17 |
| WP-84 | Kanonik app_en.arb / app_tr.arb kataloğu — cihaz/ürün kabulü 2026-07-17 |
| WP-81 | Android beta-v20 — bildirim teslimi + dinamik panel düzeltmeleri — cihaz/ürün kabulü 2026-07-17 |
| WP-80 | Dinamik panel uygunluk hata düzeltmesi — cihaz/ürün kabulü 2026-07-17 |
| WP-79 | Bildirim açılışta toplu teslim hata düzeltmesi — cihaz/ürün kabulü 2026-07-17 |
| WP-78 | Android beta-v19 — imzalı APK ve GitHub prerelease — cihaz/ürün kabulü 2026-07-17 |
| WP-77 | İzin yönetimi — dört Android iznini geri alma ve rehberi — cihaz/ürün kabulü 2026-07-17 |
| WP-76 | Dinamik panel — canlı kontrol paneli — ürün kabulü 2026-07-17 · **şerh:** OEM Live terfisi garanti değil; P2 kontrol bildirimi + senkron 1×1 widget WP-134–137 |
| WP-91 | Stats dönem-senkron başlık order testi — sabit 7/30 gün beklentisi güncel `7 gün · Hafta` sözleşmesine hizalandı; hedef test geçti; kapanış 2026-07-14 |
| WP-82 | Flutter l10n çekirdeği + sistem dili resolver'ı — `en` varsayılan, yalnız `tr*` için Türkçe; gen-l10n, 4/4 hedef test, analyze, 395/395 tam test, Windows release build+smoke geçti; kapanış 2026-07-14 |
| WP-90 | Depo kalite kapısı temizliği — 4 analiz bulgusu ve 2 eski/kırılgan test düzeltildi; `flutter analyze` 0, tam test 395/395; kapanış 2026-07-14 |
| WP-83 | EN/TR Metin Envanteri ve Ürün Dili Sözlüğü — `docs/L10N-SOZLUK.md` ve `docs/L10N-ENVANTER.md` oluşturuldu; kapanış 2026-07-14 |
| WP-71 | Windows Desktop UI R3 · custom WinUI pane + density + navy fix — `8dd0573`; kapanış 2026-07-14 |
| WP-70 | Windows performans tabanı · release RAM/başlangıç ölçümü (p95 WS 85.9 MB) — `340b589`; kapanış 2026-07-14 |
| WP-69 | Aylık Çalışma Raporu altyapısı (Cron + Edge Function + Settings toggle) — `3782fc1`; canlı gönderim için **DNS/API key ürün sahibinde** |
| WP-68 | Android Widget R2 · responsive sayaç/hedef/sıralama — `6a2637b`; kapanış 2026-07-14 (Samsung/Pixel smoke sorun→debug) |
| WP-67 | İstatistik Görselleştirme R2 · grafik kataloğu briefi — teslim; kapanış 2026-07-14 |
| WP-66 | Hesap silme & veri saklama politikası · karar dokümanı — kapanış 2026-07-14 |
| WP-64 | Çoklu cihaz senkron QA + kurtarma provası · şablon/matris — kapanış 2026-07-14 |
| WP-63 | Android Widget R2 · ürün sözleşmesi/brief — teslim; kapanış 2026-07-14 |
| WP-62 | Kamp Ateşi R2 · katmanlı PNG sahne + performanslı animasyon — kod+test; kapanış 2026-07-14 |
| WP-61 | Kamp Ateşi R2 · görsel yön + PNG asset sözleşmesi — ürün onayı 2026-07-14 |
| WP-53 | Windows Desktop Design 2.0 · ekran-içi IA (5 ekran, DesktopDensity, master-detail) — `0bd23f4`; kapanış 2026-07-14 |
| WP-28 | Windows MSIX + imza + update + release QA hattı — `a395484`; kapanış 2026-07-14 |
| WP-27 | Windows desktop shell + Compact Focus — base QA; kapanış 2026-07-14 |
| WP-58 | Saat Merkezi R1 · Epoch + Exact Alarm — ürün kapanış 2026-07-13 (cihaz smoke sorun→debug) |
| WP-59 | Saat Merkezi R2 · Alarm 2.0 + Multi-timer — ürün kapanış 2026-07-13 |
| WP-60 | Saat Merkezi R3 · Dünya/Krono/StandBy + hub — ürün kapanış 2026-07-13 |
| WP-52 | Adaptif dashboard 6/8/12/16 — kod+test; ürün kapanış 2026-07-13 (Windows resize ayrı) |
| WP-45 | V8-C · Gruplar/kamp ateşi polish — ürün kapanış 2026-07-13 |
| WP-46 | Faz 0B · Integration test + Android QA matrisi — ürün kapanış 2026-07-13 |
| WP-47 | Faz 0B · Sentry + senkron gözlemlenebilirlik — ürün kapanış 2026-07-13 |
| WP-40 | V8-A · Native timer state store + foreground service — beta-v8 cihaz QA + ürün kabulü |
| WP-41 | V8-A · Canlı chronometer bildirim R1/R2 (beta-v11–v15 hattı) — ürün kabulü 2026-07-13 |
| WP-42+51 | V8-A · Native sayaç servisi + widget/bildirim app-kapalı + Grok in-app start fix — ürün kabulü 2026-07-13 |
| WP-54 | Tema Stüdyosu R1 · Token motoru + 12 hazır tema — ürün kabulü 2026-07-13 |
| WP-55 | Tema Stüdyosu R2 · Katmanlı editör UI — ürün kabulü 2026-07-13 |
| WP-56 | Başarım 3.0 R1 · Server-authoritative ledger + wire-up + XP eşik/saat — ürün kabulü 2026-07-13 |
| WP-57 | Başarım 3.0 R2 · Oyunlaştırılmış profil/rozet UI + polish — ürün kabulü 2026-07-13 |
| WP-43 | V8-B · Genel senkronizasyon denetimi (canonical projection, idempotency) — beta-v8 cihaz QA + ürün kabulü |
| WP-44 | V8-C · İstatistik grup sırası (sıralama üste) — beta-v8 cihaz QA + ürün kabulü |
| WP-37 | Faz 0A · Repo ve doküman gerçeği denetimi |
| WP-1 | Android Widget Foundation |
| WP-2 | Persistent Notification + Background Timer |
| WP-3 | Auth Recovery (ilk temel akış) |
| WP-4 | Home Responsive QA |
| WP-5 | Presence Lifecycle |
| WP-6 | Android Surface Extensions |
| WP-7 | Class Chat |
| WP-8 | Nudge + Notifications |
| WP-9 | Gamification |
| WP-10 | Class Metrics Pack |
| WP-11 | Windows Desktop Track |
| WP-12 | Sync & Offline Track |
| WP-13 | Release Channels |
| WP-14 | Güvenli Admin ve Geri Bildirim Temeli |
| WP-15 | Device Integrations Spike ve zengin kısayollar |
| WP-16 | Dashboard Advanced Polish |
| WP-17 | Android Canlı Sayaç Yüzeyleri |
| WP-18 | Grup Ekranı Hiyerarşisi ve Ayar Sadeleştirmesi |
| WP-19 | Device Integrations Settings Hook |
| WP-20 | Özelleştirilebilir Saat Stilleri |
| WP-21 | Gelişmiş Grid Boyutlandırma |
| WP-22 | Canlı Grup Hedefi Animasyonu |
| WP-23 | Clock Center + Landscape StandBy |
| WP-24 | Alarm + Çoklu Timer Temeli |
| WP-25 | Android 3 Tuşlu Navigasyon Safe Area QA |
| WP-26 | Tema Paleti ve Özel Slotlar |
| WP-29 | Stable/Beta App Icon & Branding Refresh |
| WP-30 | Release Notes, Updater Dialog ve Settings Hook |
| WP-31 | Hesabımı Yönet Merkezi ve çalışan şifre sıfırlama |
| WP-32 | Geri bildirim ekran görüntüsü eki |
| WP-33 | Güvenli süper-admin kullanıcı işlemleri |
| WP-34 | Süper-Admin Paneli, Grup Moderasyonu ve Duyurular |
| WP-35 | Sosyal Profil 2.0 + Başarı Yolculuğu |
| WP-36 | Beş Sekmeli IA Sadeleştirmesi + Bildirim Merkezi |
| WP-38 | Faz 0A · Canlı Backend Durum Matrisi |

### Ayrıntılı tamamlanan kartlar

> Üstteki özet satırlarının kanıt ve teslim ayrıntılarıdır. Açık işler bu bölüme taşınmaz.

### WP-41: V8-A · Canlı Chronometer Bildirim (Başlat/Durdur) 🔔
- **Program/Faz:** V8-A · **Bağımlılık: WP-40 (tamamlandı)**
- **Ajan:** Claude (Codex'ten devir — Codex WP-47'de; kullanıcı talimatı)
- **Durum:** [x] **Tamamlandı** (2026-07-13) — ürün kabulü · kod+beta hattı (v11–v15) + in-app start hotfix
- **Problem:** Bildirimde canlı `HH:MM:SS` + Başlat/Durdur, app açmadan yönetim (istek 1).
- **Kapsam dışı:** Widget (→WP-42), state store (WP-40).
- **SAHİP dosyalar (yaz):** `app/lib/core/notifications/timer_notification_service.dart`, ilgili notification receiver Kotlin.
- **DOKUNMA:** `study_providers.dart` (WP-40 sahibi — yalnız oku), widget (WP-42).
- **Adımlar:** [x] dar görünüm (HH:MM:SS + tek durum + Başlat/Durdur); [x] native `Chronometer` (usesChronometer); [x] butonlar Flutter açmadan sıralı native komut kaydına yazar. Geniş görünümdeki Sıfırla / +1 dk, timer state eylemi olarak ayrı UI kapsamıdır.
- **Kabul (ölçülebilir):** Kod/test/Android build geçti. 20 ardışık Başlat/Durdur (app kapalı), canlı akan saat ve bildirim/uygulama paritesi için cihaz videosu bekleniyor (`Cihazda doğrulanmalı`).
- **Tuzaklar:** Bildirim son görünümü OEM'e bağlı — hedef ulaşılabilir ama piksel garanti değil. `study_providers` timer-sync WP-40 kapsamında; buraya taşırsan WP-42 ile çakışır.
- **Model önerisi:** 🔴 Opus
- **Kök neden (Claude, beta-v8 QA):** İki ayrı bildirim var — (a) FGS'in zorunlu statik bildirimi (`timer_foreground_service`, kronometre/buton yok), (b) WP-41 zengin bildirimi (`study_timer_ongoing`, importance LOW). LOW olan altta/silik kaldığı için kullanıcı statik olanı görüp "değişmemiş" diyor. Ayrıca kullanıcının cihazında **hem stable hem beta kurulu** → 2 bildirim gözlemi bundan (teşhis kirli). Temiz teşhis için stable durdurulmalı. **Asıl mimari boşluk WP-42 ile ortak (aşağıda).**

- **Cihaz QA turu 2 (beta-v10, 2026-07-13):** ÇEKİRDEK ÇALIŞIYOR ✅ — tek bildirim, saniye saniye akan `HH:MM:SS`, app tamamen kapalıyken Durdur işleniyor ve süre doğru kaydediliyor. Kullanıcı **2 revizyon** istedi (ekran görüntüsü: HyperOS "Live notifications" panelinde native Kronometre uygulaması `00:05.32` Lap/Stop ile üstte, bizimki `00:00:10` + "Odak Kampı çalışıyor" alt satırıyla altta):
  - **R1 — Gövde yazısı kaldır:** Bildirimde hâlâ görünen "Odak Kampı çalışıyor" alt satırı kalksın; saat uygulaması gibi yalnız akan süre + buton kalsın. **Plan:** `timer_foreground_service.dart` içindeki 3 `notificationText: 'Odak Kampı çalışıyor'` (start→updateService, start→startService, `_TimerTask._refreshNotification`) boş string `''` yapılır. Bazı OEM boş text'i yok saymazsa tek boşluk `' '` denenir. Kanıt: cihazda alt satır görünmez.
  - **R2 — Durdur kalıcı toggle (Durdur↔Başlat):** Durdur'a basınca bildirim **kaybolmasın**; süre kaydedilsin (işlev doğru) ama buton **Başlat**'a dönsün, kullanıcı app açmadan tekrar başlatabilsin. **Plan:** (1) Harici komut modeline `'start'` eklenir (`timer_external_command_store.dart`; `command` alanı `start`/`stop`, `at` ikisi için var). (2) FGS mod bayrağı prefs `timer_fg_mode` = `running`/`idle`. (3) Durdur handler: stop komutu yaz (`at=now`) + `sendDataToMain` → **`stopService` YOK**; bunun yerine `updateService(title: '00:00:00', notificationButtons: [Başlat id=timer_start])`, mode=`idle`; `onRepeatEvent` idle iken tazelemeyi durdurur (süre donar). (4) Başlat handler (`id=timer_start`): start komutu yaz (`at=now`), `timer_active_started_at=now`, mode=`running`, buton→Durdur; `onRepeatEvent` yeniden akıtır + `sendDataToMain`. (5) Ana isolate `study_providers._processPendingExternalCommand` artık `'start'`i de işler → `startedAt=at` ile yeni oturum başlatır (server-authoritative session insert; `sequence` ile idempotent); `'stop'` zaten var. **Ürün kararı (R2-a):** Sayaç idle iken FGS canlı kalır → bildirim sürekli görünür (pil/politika bedeli). Öneri: idle iken bildirim `ongoing`/sticky olmasın (kullanıcı kaydırıp atabilsin); tam durdurma app içinde zaten var. Alternatif = idle'da FGS'i durdurup normal (ongoing olmayan) `flutter_local_notifications` bildirimi + native `BroadcastReceiver` (app-kapalı Başlat) — ama çift-sistem karmaşasını geri getirir; bu geçiş asıl olarak WP-51 native yeniden yazımında yapılır. **Önerilen: Option A (FGS canlı toggle).**
  - **Not (yan gözlem):** Kullanıcı "ana uygulamanın bildirim iznini kapattım ama hâlâ çıkıyor" dedi — bu beklenen: `dataSync` foreground service'in zorunlu bildirimi POST_NOTIFICATIONS iznine bağlı değildir (servis çalıştıkça görünür). Ayrı bug değil; R2 idle davranışıyla birlikte kullanıcıya kapatma yolu (ongoing kaldırma) sunulur.
  - **Tasarım isteği (native saat/dinamik panel görünümü) → yeni WP-51'e ayrıldı** (native `Chronometer`/`ProgressStyle`/Live Updates gerektirir; flutter_foreground_task text-update ile yaklaşık; gerçek native kronometre için Kotlin bildirim). R1/R2 önce, WP-51 sonra.
  - **Kabul (R1/R2, ölçülebilir):** Cihazda (a) bildirimde gövde yazısı yok, yalnız süre+buton; (b) Durdur→süre kaydedilir + bildirim `00:00:00` + **Başlat** olur; (c) Başlat→app açmadan yeni oturum başlar, süre akar; (d) 10 ardışık Durdur/Başlat (app kapalı) oturum sayımını bozmaz. `Cihazda doğrulanmalı`.

- **Uygulama (beta-v11, 2026-07-13, Claude):** R1+R2 kodlandı. **Plandan sapma (daha sağlam):** Tek-atımlık komut store yerine, app-kapalı Durdur her tamamlanan çalışma aralığını `timer_pending_intervals` **kuyruğuna** yazar (last-write-wins komut modeli arka arkaya Durdur→Başlat'ta ilk oturumu kaybederdi — kabul (d) bunu men eder). Değişen dosyalar: `timer_foreground_service.dart` (gövde yazısı `''`; `_runningButtons`/`_idleButtons`; `_pauseToIdle`→kuyruğa aralık + idle + Başlat butonu, `stopService` YOK; `_resumeToRunning`→`timer_active_started_at=now` + running + Durdur; `timer_fg_mode` bayrağı); `study_providers.dart` (`_reconcileBackgroundTimer`→kuyruğu **server-authoritative** `_recordSession` ile yaz + FGS moduna göre sayacı uzlaştır, auth hazır değilse kuyruğu koru; `_syncBackgroundTimerState` = reconcile + widget komutu; dispose-sonrası `ref` yarışları için `_disposed`/guard'lar). Widget'ın tek-atımlık `timer_external_command` yolu (WP-42) korundu. **Test:** yeni `timer_background_reconcile_test.dart` (idle→oturum+dur; Durdur→Başlat→eski oturum+yeni çalışır; 5 çift→5 oturum). `flutter analyze` 0 + **286 test** yeşil + **beta-v11 APK `1.0.10+11` (`app-beta-release.apk`, 64 MB) PASS**. `Kodda doğrulandı` — cihaz videosu bekliyor.
  - **Ürün kararı (R2-a, açık):** Idle'da FGS canlı kaldığı için bildirim görünür kalır (flutter_foreground_task bildirimi doğası gereği `ongoing`/kaydırılamaz). Tam "kaydırıp atma" ancak WP-51 native yeniden yazımıyla gelir. Beta-v11'de idle = `00:00:00`+Başlat (temiz), ama swipe-dismiss yok. Kullanıcı onayı bekliyor.

### WP-42 (+WP-51 birleşik): V8-A · Native Sayaç Servisi — Widget/Bildirim App-Kapalı Kontrol 📲
- **Program/Faz:** V8-A · **Bağımlılık: WP-41 (kod bitti)** · **Kullanıcı kararı: WP-42 + WP-51 tam native olarak birleştirildi**
- **Ajan:** Claude (Codex'ten devir — kullanıcı talimatı)
- **Durum:** [x] **Tamamlandı** (2026-07-13) — native servis ürün kabulü · WP-51 birleşik
- **Uygulama (beta-v12, 2026-07-13, Claude):** Sayaç bildirimi + widget'ı **native Kotlin `StudyTimerService`** yönetir (flutter_foreground_task timer yolundan çıkıldı). Yeni/değişen: `timer/StudyTimerService.kt` (foreground servis: ACTION_START/STOP/STOP_SILENT/TOGGLE, native `Chronometer` bildirim, `timer_pending_intervals` kuyruğu, idle=00:00:00+Başlat kaydırılabilir), `widgets/TimerActionReceiver.kt` (widget düğmesi → servis), `widgets/StudyWidgetProviders.kt` (Chronometer `_ms` epoch anahtarından, Başlat/Durdur durum metni), `widgets/TimerWidgets.kt` (native widget tazeleme), `MainActivity.kt` (method channel `…/timer`: Dart→native start/stop, native→Dart `reconcile` + runtime receiver), `AndroidManifest.xml` (servis kaydı). Dart: `timer_foreground_service.dart` method-channel köprüsüne indirildi; `study_providers.dart` FGS task-data callback yerine `reconcile` method-channel handler + `timer_active_started_at_ms` yazımı. **Server-authoritative kayıt WP-41 reconcile'ıyla korundu** (native yalnız aralık kuyruğa yazar). `flutter analyze` 0 + **286 test** + **beta-v12 release+debug APK PASS** (Kotlin derlendi). `Kodda doğrulandı`.
- **Problem:** Yalnız timer widget besleniyor; stats/leaderboard placeholder (B4).
- **Kapsam dışı:** Bildirim (WP-41), senkron canonical projection (WP-43 sağlar; burada tüketilir).
- **SAHİP dosyalar (yaz):** `app/lib/features/android_widgets/android_widget_service.dart`, `app/android/app/src/main/kotlin/**/widgets/*` (Chronometer RemoteViews), yeni widget besleme pipeline.
- **DOKUNMA:** `study_providers.dart` timer-sync (WP-40/41 — dar okuma), notification (WP-41).
- **Adımlar:** timer widget native `Chronometer`; Başlat/Durdur app açmadan; stats/leaderboard **olay bazlı** besleme (session ekl/düzenle/sil, sync, grup değişimi, gün sınırı, manuel refresh); light/dark + dynamic color; boş-durum.
- **Kabul (ölçülebilir):** Boş durumda anlamlı metin var; oturum, senkronizasyon ve grup/membership akışlarında olay bazlı yenileme var; 48 dp dokunma alanı ile light/dark ve Android 12+ dynamic color kaynakları eklendi. `flutter analyze`, 254 test ve Android debug APK geçti (`Kodda doğrulandı`). Oturum sonrası ≤ 5 sn ve cihaz videosu / ürün kabulü `Cihazda doğrulanmalı`.
- **Tuzaklar:** Saniyede bir Flutter yeniden çizme YOK; periyodik <15 dk garanti değil → native Chronometer + olay bazlı.
- **Model önerisi:** 🔴 Opus
- **Kök neden (Claude, beta-v8 QA):** Widget ekleniyor + yazı gösteriyor ama Başlat/Durdur "işlevsiz". Sebep WP-41 ile **ORTAK**: widget/bildirim butonu `flutter.timer_external_command` prefs'ine komut yazıyor ama bunu **yalnız uygulama açık/onResume/soğuk açılış işliyor** (`study_providers._processPendingExternalCommand`, satır 448). Uygulama kapalıyken komutu tüketen canlı isolate YOK — FGS task handler (`_TimerTask`) yalnız heartbeat atıyor. → Butonlar app kapalıyken **ölü anahtar**. Gerçek düzeltme: FGS task handler'ın komut store'unu okuyup start/stop + bildirim + widget'ı ana isolate olmadan yürütmesi (arka plan komut işleme). WP-40/41/42 bu çekirdeği ertelemiş; kod-tamam kapatılmış ama app-kapalı buton gereksinimi karşılanmıyor.

### WP-51: V8-A · Dinamik Panel / Native Kronometre Bildirim Tasarımı ✨
- **Program/Faz:** V8-A polish (Saat programına köprü) · **Ajan:** Claude · **Durum:** [x] **Tamamlandı** (2026-07-13) — WP-42 ile birleşik native; OEM Live Panel ayrı polish · **Bağımlılık:** WP-41 R1/R2
- **Problem:** Kullanıcı bildirimin **native saat uygulaması gibi** görünmesini istiyor — cihazın dinamik panelinde (HyperOS "Live notifications" / Samsung "Now Bar" / Android 16 "Live Updates") büyük akan saat, dinamik ada terfisi. Şu an flutter_foreground_task her saniye **başlık metnini** güncelliyor (gerçek native `Chronometer` değil) ve dinamik panele terfi etmiyor.
- **Kök gerçek (teknik kısıt):** `flutter_foreground_task` bildirim yapıcısı `setUsesChronometer(true)`, `setWhen(base)`, `setCategory(CATEGORY_STOPWATCH)`, custom `RemoteViews` ve Android 16 `Notification.ProgressStyle` (Live Updates) **desteklemez**. Dinamik panele terfi büyük ölçüde OEM'e ve doğru bildirim kategorisi/şablonuna bağlıdır.
- **Kapsam:** (1) OEM araştırması: HyperOS/Samsung/Pixel dinamik panel terfi kuralları + Android 16 `ProgressStyle`/Live Updates API + `CATEGORY_STOPWATCH`. (2) Native Kotlin foreground bildirimi: `NotificationCompat.setUsesChronometer(true)` + `setWhen(startBase)` (native akan saat — saniyede Flutter update YOK), kategori/şablon, PendingIntent aksiyon butonları → app-kapalı işleyen `BroadcastReceiver` (R2 komut/at mantığını buna taşır). (3) FGS bu native bildirimi kullanır (flutter_foreground_task yerine kendi FGS'imiz veya bildirim override). (4) Cihaz kanıtı (dinamik panelde görünüm + app-kapalı buton).
- **Kapsam dışı:** Sayaç iş mantığı (WP-40/41), widget (WP-42), iOS Live Activity (ayrı WP).
- **SAHİP dosyalar (yaz):** `app/lib/core/background/timer_foreground_service.dart`, `app/lib/core/notifications/**`, yeni `app/android/app/src/main/kotlin/**/notifications/*` (native bildirim + BroadcastReceiver).
- **DOKUNMA:** widget native (WP-42), `study_providers` timer-sync (dar okuma).
- **Kabul (ölçülebilir):** Desteklenen OEM'de bildirim dinamik panele terfi eder + native akan saat gösterir (saniyede Flutter update yok); aksiyon butonları app-kapalı çalışır; desteklemeyen OEM'de düz ama temiz canlı bildirime düşer. `Cihazda doğrulanmalı`.
- **Tuzaklar:** Dinamik panel terfisi OEM garantisi değildir — hedef ulaşılabilir, piksel/panel garanti değil; graceful fallback şart. **Model:** 🔴 Opus

### WP-54: Tema Stüdyosu R1 (Token Motoru ve Hazır Temalar) 🎨
- **Program/Faz:** Tema Stüdyosu (KALITE-PROGRAMI §8.5)
- **Ajan:** Grok
- **Durum:** [x] **Tamamlandı** (2026-07-13) — ürün kabulü · token motoru + 12 preset
- **Problem:** Sabit renk kullanımının sonlandırılıp, `docs/TEMA-MIMARISI.md` 5 katmanlı ThemeExtension altyapısı.
- **Kapsam dışı:** Tema seçme ekranı (→ WP-55).
- **SAHİP dosyalar:**
  - `app/lib/core/theme/theme_tokens.dart` (5 extension + context.appColors…)
  - `app/lib/core/theme/theme_presets.dart` (12 sanat ailesi)
  - `app/lib/core/theme/app_theme.dart` (fromPreset motoru)
  - `app/lib/core/theme/theme_settings.dart` (familyId kalıcı)
  - `app/lib/main.dart` (family wiring)
- **Adımlar:**
  - [x] AppColors / AppTypography / AppShapes / AppAtmosphere / AppMotion
  - [x] 12 preset (Campfire…Material You)
  - [x] `AppTheme.fromPreset` + eski AppPalette köprüsü + palette→family migrate
  - [x] ThemeSettings.familyId prefs; setPalette family hizalar
  - [x] Material bileşen temaları token’dan (Card/AppBar/Nav/Input…)
  - [~] Uygulama geneli `Colors.x` tarama: motor hazır; tek tek widget göçü kademeli (WP-55/sonraki). Yeni kod `context.appColors` kullanmalı.
- **Veri/Migration:** Yerel prefs `theme_family`. Geri alma: family yoksa palette migrate.
- **Kabul:** Analyze 0 + 7 unit/widget test PASS — `Kodda doğrulandı`. 12 ailenin görsel beta’sı — `Cihazda doğrulanmalı`.
- **Dal:** — (main) · **Model:** Grok

### WP-55: Tema Stüdyosu R2 (Katmanlı Tema Editörü UI) 🎛️
- **Program/Faz:** Tema Stüdyosu
- **Ajan:** Grok
- **Durum:** [x] **Tamamlandı** (2026-07-13) — ürün kabulü · Tema Stüdyosu UI
- **Problem:** 12 temadan seçim + canlı önizleme + mood.
- **Kapsam dışı:** PRO hex stüdyo; sunucu `user_preferences` JSON (yerel prefs familyId yeterli R2).
- **SAHİP:** `theme_studio_screen.dart` + `appearance_screen` glue
- **Adımlar:**
  - [x] Huni: Tema → Mood → Şekil (önizleme) → Uygula
  - [x] Canlı Dashboard + Sayaç önizlemesi (preset renkleri)
  - [x] `setFamily` / `setMode` — restart yok
  - [x] Görünüm ekranından giriş kartı
  - [x] Widget test PASS
- **Kabul:** Anında tema — `Kodda doğrulandı`. Cihaz görsel — `Cihazda doğrulanmalı`.

### WP-56: Başarım 3.0 R1 (Server-Authoritative Motor ve SQL) 🏆
- **Program/Faz:** Başarım 3.0 (KALITE-PROGRAMI §8.6)
- **Ajan:** Grok
- **Durum:** [x] **Tamamlandı** (2026-07-13) — ürün kabulü · ledger+wire-up · SQL 0024–0027
- **Problem:** İstemci taraflı (hileye açık) başarı hesaplamalarının `docs/BASARIM-MIMARISI.md`'deki Server-Authoritative ledger sistemine geçirilmesi.
- **Kapsam dışı:** Profil vitrini ve rozet çizimleri (→ WP-57).
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/0024_achievements_ledger.sql`
  - `app/lib/data/providers/achievement_provider.dart` + `gamification_providers.dart` (wire-up)
  - `app/lib/data/repositories/supabase/supabase_gamification_repository.dart` (istemci XP yazımı kapalı)
  - (+ motor/repo/model/test)
- **DOKUNMA (oku, değiştirme):**
  - `docs/BASARIM-MIMARISI.md` · `study_providers.dart` (Claude — yalnız okuma)
- **Adımlar:**
  - [x] `xp_ledger` + RPC + dict seed + B7 RLS
  - [x] İstemci API dual repo
  - [x] **Wire-up:** `gamificationProgressSyncProvider` → `process_achievement_event` (istemci `AchievementEngine` yazımı kaldırıldı)
  - [x] Supabase `updateProfile` yalnız streak_freezes + selected_badges; `updateUserAchievements` no-op
  - [x] Profil kartı + Başarılar ekranı sync izliyor
  - [x] Birim test: ledger 8 + wire-up 1 = 9 PASS
- **Veri/Migration etkisi:** `0024` canlıya **kullanıcı uyguladı**. Geri alma: migration başı notu.
- **RLS/Güvenlik:** Ledger/RPC only; istemci XP yolu kapalı.
- **Edge-case'ler:** Idempotent event_key. Grup/sosyal metrik R1=0. `secret_break_enemy` veri yok.
- **Kabul:** Çift XP yok — `Kodda doğrulandı`. Beta: profil/başarılar aç → oturum sonrası XP artışı; ikinci açılışta çift artmama — `Cihazda doğrulanmalı`.
- **Uygulama notu (2026-07-13, Grok wire-up):** Eski client write kaldırıldı. Oturum biterken otomatik tetik profil/başarılar ekranı + oturum listesi değişimi ile (study_providers'a yazılmadı).
- **Dal:** — (main) · **Model:** Grok

### WP-57: Başarım 3.0 R2 (Oyunlaştırılmış Profil ve Rozet UI) 🏅
- **Program/Faz:** Başarım 3.0
- **Ajan:** Grok
- **Durum:** [x] **Tamamlandı** (2026-07-13) — ürün kabulü · vitrin/taç/confetti + polish
- **Problem:** Kullanıcının kilitli (????) veya açılmış başarımlarını görebileceği, taç/XP çubuğu bulunan sosyal profil vitrini.
- **Kapsam dışı:** Backend ledger motoru (WP-56).
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/profile/widgets/achievement_showcase.dart`
  - `app/lib/features/profile/social_profile_screen.dart`
  - glue: `social_profile_dialog.dart`, `achievements_screen.dart`, `gamification_card.dart`
- **DOKUNMA (oku):** `achievement_provider` / gamification stream (WP-56)
- **Adımlar:**
  - [x] XP seviye barı + taç etiketleri (`crownLabelTr` / `xpBarMetrics`)
  - [x] Gizli rozet: kilitliyken `?????` + siyah siluet; açıkken gerçek ad
  - [x] Confetti (CustomPainter, pubspec yok) — yeni ödülde post-frame ≤ 250 ms arm
  - [x] SocialProfileScreen (tam) + Dialog (kompakt) + AchievementsScreen yönlendirme
  - [x] Vitrin 3 rozet pin (kendi profil); başkasında salt-okunur
  - [x] Widget test 4 PASS
- **Veri/Migration etkisi:** Yok.
- **RLS/Güvenlik:** Başka kullanıcı okuma mevcut `can_see_user_sessions` stream’lerine bağlı; e-posta gösterilmez.
- **Kabul:** Gizli kilit UI + confetti arm — `Kodda doğrulandı`. Cihazda gizli başarım açılışı görsel QA — `Cihazda doğrulanmalı`.
- **Dal:** — (main) · **Model:** Grok

### WP-52: Adaptif Dashboard Grid ve Cihaz Yoğunluğu 🧩
- **Program/Faz:** Ana Sayfa + Windows/tablet adaptasyonu · **Ajan:** Codex · **Durum:** [x] Tamamlandı (2026-07-13) — ürün kapanışı · **Bağımlılık:** WP-27 base shell
- **Problem:** Dashboard veri modeli ve render motoru sabit `6×N`; tablet ve geniş Windows alanında kartlar gereğinden büyük kalıyor, aynı anda daha az bilgi gösteriliyor. Kullanıcı cihaz başına daha verimli bir grid istiyor.
- **Kapsam dışı:** Dashboard kartlarının iç veri/grafik mantığını yeniden yazmak, layout'u Supabase ile cihazlar arasında senkronlamak, tema motoru, Windows shell/MSIX.
- **SAHİP dosyalar (yaz):** `app/lib/features/home/dashboard_card.dart`, `dashboard_providers.dart`, `home_screen.dart`, `app/lib/core/grid/grid_reflow.dart`, `app/lib/features/profile/settings_screen.dart` (yalnız Ana Sayfa grid ayarı), ilgili grid/dashboard/settings testleri.
- **DOKUNMA:** `supabase/**`, repository/provider veri kaynakları, `core/theme/**`, `core/navigation/**`, `app/pubspec.yaml`, notification/widget dosyaları.
- **Adımlar:**
  - [x] Cihaz-yerel `DashboardGridDensity` tercihi: **6 / 8 / 12 / 16**; kullanıcı yoğunluğu açıkça seçer, eski `automatic` tercihi güvenli biçimde 6 sütuna göçer.
  - [x] Sabit `kGridColumns=6` bağımlılığını config/reflow/render/drag/resize/backdrop boyunca parametreleştir; kart içerik boyutu aktif sütun oranına göre seçilir.
  - [x] Her sütun yoğunluğu için ayrı yerel layout profili (`6/8/12/16`) sakla. Bir profil ilk açıldığında mevcut düzenden deterministik ölçekle + reflow ile üretilir; geri dönünce önceki profil aynen gelir.
  - [x] Mevcut `dashboard_layout` 6-sütun kaydını kayıpsız v2 profile göçür; migration tamamlanana dek eski anahtarı rollback yedeği olarak koru.
  - [x] Ayarlar'da doğrudan açıklamalı seçim + anlık uygulama; reset yalnız aktif yoğunluk profilini sıfırlar.
  - [x] Düzenleme modunda tek eylemle dikey boşlukları yukarı topla; kartların `x/w/h` değerlerini koru, yalnız `y` değerlerini çakışmasız minimuma indir ve aktif profile kaydet.
  - [~] 6/8/12/16 profil/geçiş/migration/provider, yukarı toplama motoru ve ayarlar widget testleri PASS; `flutter analyze`, tüm 283 test ve Windows release build PASS. Gerçek telefon/tablet/Windows resize/görsel QA bekliyor.
- **Veri/Migration etkisi:** Sunucu/migration yok. Yalnız `SharedPreferences`; layout hesap değil cihaz bazlıdır. Geri alma = v2 profillerini yok sayıp korunan eski `dashboard_layout` anahtarına dönmek.
- **RLS/Güvenlik:** Yeni ağ/veri yetkisi yok; kullanıcı içeriği veya sır eklenmez.
- **Edge-case'ler:** 6↔8↔12↔16 tekrar geçişi, eksik/bozuk profil, kartın yeni sütun sınırını aşması, dar split-screen/tablet rotation, %200 ölçek, boş dashboard, aktif drag sırasında ayar değişimi.
- **Kabul (ölçülebilir):** 20 ardışık 6→8→12→16→6 geçişinde kart kaybı/çakışma 0; aynı profile dönüşte encode listesi birebir aynı; eski 6-grid kullanıcı düzenindeki kart sayısı/relatif sıra korunur; 600/800/1200/1440 logical px'te overflow 0; telefon, tablet ve Windows gerçek cihaz ekran görüntüsü; analyze + tüm testler yeşil. `Cihazda doğrulanmalı`.
- **Tuzaklar:** Tek layout'u her geçişte tekrar ölçekleyip yuvarlama drift'i üretmek; yüksek sütun yoğunluğunu dar ekranda zorlamak; kart içeriğini okunamayacak 1 hücreye indirmek; desktop için ikinci dashboard veri modeli kurmak.
- **Model önerisi:** 🔴 Opus
- **Kod kanıtı (2026-07-13):** R2 dahil `flutter analyze` PASS; grid/dashboard odak testleri 20/20 PASS; tüm testler 283/283 PASS; `flutter build windows --release --dart-define-from-file=env.json` PASS (`online_study_room.exe`).

### WP-45: V8-C · Gruplar Sırası + Kamp Ateşi + Animasyon 🔥
- **Program/Faz:** V8-C · **Bağımsız — WP-44 ile paralel güvenli (farklı dosyalar)**
- **Ajan:** Claude
- **Durum:** [x] Tamamlandı (2026-07-13) — ürün kapanışı
- **Problem:** Kamp ateşi üste; sıra ateş→hedef→sıralama; toparlanma animasyonu uzun (istek 4).
- **Kapsam dışı:** İstatistik sekmesi (WP-44); grup hedef/trend kartlarının iç mantığı.
- **SAHİP dosyalar (yaz):** `app/lib/features/classroom/classroom_screen.dart`, `app/lib/features/classroom/widgets/campfire_scene.dart` (animasyon süresi).
- **DOKUNMA:** `features/stats/**` (WP-44), group_goal_card/group_trend_card (yalnız yeniden sırala).
- **Adımlar:** [x] sıra = kamp ateşi → grup hedefi → trend → yönetim (davet kodu alttaki açılır "Grup bilgileri" paneline, ad+sohbet/ayarlar kompakt başlığa taşındı; grup değiştir zaten AppBar'da); [x] toparlanma animasyonu 560→420 ms; [x] `reduce-motion` desteği (sonsuz alev/ember/nefes döngüsü durur + yerleşim anında).
- **Kabul (ölçülebilir):** ✅ Yerleşim 420 ms (≤ 700 ms hedefi); reduce-motion davranışsal testle doğrulandı (pumpAndSettle artık oturuyor = sonsuz animasyon durdu); analyze 0, 261 test yeşil (`Kodda doğrulandı`). "İlk sahne ≤ 300 ms" ve görsel akıcılık `Cihazda doğrulanmalı`.
- **Tuzaklar:** Sonsuz/dekoratif animasyon batarya tüketmemeli → reduce-motion'da durur.
- **Model önerisi:** 🔵 Sonnet
- **Not (`Ürün kararı gerekiyor`):** §8.3 "Gruplar" sırasında **grup sıralaması** kartı geçiyor ama bu sekmede sıralama kartı yok (leaderboard İstatistikler sekmesinde). Ayrı sıralama kartı eklemek kapsam dışı + stats'ı çoğaltır; eklensin mi, kullanıcı kararı. Mevcut kartlarla ulaşılabilir sıra: ateş → hedef → trend → yönetim.
- **Cihaz QA turu 1 (beta-v8, 2026-07-12):** Sıra ✅ (kamp ateşi üstte). Sorun: sahne çok uzundu, üst/altta gereksiz boşluk → **düzeltildi** (`_SceneFrame` 480→360, kompozisyon orantılı sıkıştı; commit `11df506`). Yeni beta ile **cihazda yeniden doğrulanmalı**; boyut değeri gerekirse ince ayar (`Cihazda doğrulanmalı`).

### WP-46: Faz 0B · V8 Integration Test ve Android QA Matrisi 🧪
- **Program/Faz:** Faz 0B (KALITE-PROGRAMI §7, §9) · **Ajan:** Codex · **Durum:** [x] Tamamlandı (2026-07-13) — ürün kapanışı
- **Problem:** Native arka plan/OEM/iki cihaz davranışı ölçülebilir ve tekrarlanabilir değil.
- **Kapsam dışı:** Timer/widget ürün kodu, Sentry (→ WP-47), yayın kararı/dağıtım.
- **SAHİP dosyalar (yaz):** `app/integration_test/v8_critical_flows_test.dart`, `app/test/features/v8_critical_flows_test.dart`, `app/test/support/v8_test_*`, `docs/QA-V8-ANDROID.md`, `app/pubspec.yaml` (integration_test SDK).
- **DOKUNMA:** `app/lib/data/providers/study_providers.dart`, `app/lib/features/android_widgets/**`, `app/android/**`, `app/lib/main.dart`.
- **Adımlar:** [x] session insert/update/delete + Istanbul 23:59–00:01 smoke testi; [x] gerçek Android integration binding'i; [x] Samsung/Pixel cold-start, force-stop, kilit, reboot, pil optimizasyonu, widget/bildirim ve iki cihaz matrisi; [x] video/sonuç şablonu.
- **Veri/Migration etkisi:** Yok; geri alma = test/doküman dosyalarını kaldırma.
- **RLS/Güvenlik:** Test hesabı/RLS izolasyonu; service-role ve gizli değer kanıta girmez.
- **Edge-case'ler:** İzin reddi, widget yok, yanlış saat dilimi, beta/stable paket çakışması.
- **Kabul:** 11 cihaz senaryosu matrise yazıldı; 23:59–00:01 smoke testi, gerçek integration binding Windows koşumu, analyze 0, 263 test ve Android debug APK `Kodda doğrulandı`. Samsung/Pixel kanıtları ve gerçek Android `flutter test -d <cihaz> integration_test/v8_critical_flows_test.dart` koşumu `Cihazda doğrulanmalı`.
- **Tuzaklar:** Emulator OEM/foreground-service kanıtı değildir. **Dal:** `wp46-v8-qa-harness` · **Model:** 🔴 Opus

### WP-47: Faz 0B · Sentry ve Senkron Gözlemlenebilirliği 📡
- **Program/Faz:** Faz 0B (KALITE-PROGRAMI §5.1, §7) · **Ajan:** Codex · **Durum:** [x] Tamamlandı (2026-07-13) — ürün kapanışı · **Bağımlılık:** WP-46 kod aşaması (yönetici istisnası)
- **Problem:** Crash, foreground restore ve outbox/realtime gecikmesi üretimde ölçülemiyor.
- **Kapsam dışı:** Kullanıcı davranış analitiği, PII, server-authoritative başarı motoru.
- **SAHİP dosyalar (yaz):** `app/lib/core/observability/**`, `app/lib/main.dart`, `app/pubspec.yaml`, `app/lib/data/providers/study_providers.dart` (yalnız restore breadcrumb), `app/lib/data/repositories/offline/offline_first_study_repository.dart` (yalnız outbox/realtime breadcrumb), `app/windows/flutter/generated_plugin_registrant.cc`, `app/windows/flutter/generated_plugins.cmake`, `app/test/core/observability/**`, `docs/OBSERVABILITY-V8.md`.
- **DOKUNMA:** `core/theme/**`, `supabase/migrations/**`, timer/widget ürün mantığı.
- **Adımlar:** [x] Sentry ortam/opt-out başlatma; [x] PII içermeyen timer-restore/outbox/realtime breadcrumb'ları; [x] telemetry kapalı hata yolu testi ve release kontrol listesi.
- **Veri/Migration etkisi:** Yok; geri alma = telemetry kapatma/paket kaldırma.
- **RLS/Güvenlik:** DSN dışı gizli yok; e-posta/token/ham session gönderilmez.
- **Edge-case'ler:** DSN/ağ yok, SDK init hatası, debug-beta-stable ayrımı.
- **Kabul:** Telemetry kapalıyken SDK hiç başlatılmaz; bilinen hata ham metin yerine yalnız türüyle yakalanır; timer restore/outbox/realtime breadcrumb'ları yalnız int/bool taşır. `flutter analyze` 0, 23 ilgili test ve Android debug APK `Kodda doğrulandı`. Gerçek beta DSN ile breadcrumb/opt-out kanıtı ve ürün kabulü `Cihazda doğrulanmalı`.
- **Tuzaklar:** `pubspec.yaml`/`main.dart` sıcak dosyadır; aktif çakışma temizlenmeden başlanmaz. **Dal:** `wp47-observability` · **Model:** 🔴 Opus

### WP-58: Saat Merkezi R1 (Zaman Motoru ve Exact Alarm Altyapısı) ⚙️
- **Program/Faz:** Saat (KALITE-PROGRAMI §8.4) · **Ajan:** Grok
- **Durum:** [x] Tamamlandı (2026-07-13) — ürün kapanışı
- **Problem:** Epoch motor + `SCHEDULE_EXACT_ALARM` + reboot/timezone dayanıklılığı.
- **SAHİP:** `app/lib/core/time_engine/**`, `ExactAlarmHelper.kt`, `AlarmReceiver.kt`, `AndroidManifest` izinleri, `alarm_notification_service.dart`, modeller
- **Adımlar:**
  - [x] Epoch clock / stopwatch / countdown saf motor
  - [x] AlarmScheduler (tekrar, skip-next, crescendo eğrisi)
  - [x] Exact alarm izin kanalı + exact/inexact schedule mode
  - [x] BOOT/TIMEZONE AlarmReceiver iskeleti
  - [x] AlarmRule + TimerInstance epoch alanları (skip/antiSnooze/crescendo/endsAt)
- **Kabul:** Unit test motor 14 PASS — `Kodda doğrulandı`. Reboot/exact izin cihaz — `Cihazda doğrulanmalı`.

### WP-59: Saat Merkezi R2 (Alarm 2.0 ve Çoklu Timer UI) ⏰
- **Program/Faz:** Saat · **Ajan:** Grok
- **Durum:** [x] Tamamlandı (2026-07-13) — ürün kapanışı
- **Adımlar:**
  - [x] Alarm editör: gün chip, hafta içi/her gün, anti-snooze, crescendo, erteleme
  - [x] Skip next + sıradaki alarm özeti
  - [x] AlarmRingingScreen (crescendo haptic + matematik anti-snooze)
  - [x] Exact alarm izin banner (denied)
  - [x] Multi-timer: preset şeridi, +1/+5 dk, renk, epoch ticker, bildirim planı
- **Kabul:** Widget test empty/list/editor PASS — `Kodda doğrulandı`. 3 paralel timer + alarm ses cihaz — `Cihazda doğrulanmalı`.

### WP-60: Saat Merkezi R3 (Dünya Saati, Kronometre ve StandBy Modu) 🌍
- **Program/Faz:** Saat · **Ajan:** Grok
- **Durum:** [x] Tamamlandı (2026-07-13) — ürün kapanışı
- **Adımlar:**
  - [x] WorldClockScreen gündüz/gece gradient + offset etiketi + şehir kataloğu
  - [x] StopwatchScreen lap analizi (en hızlı yeşil / en yavaş kırmızı) + kopyala
  - [x] StandBy: gece kırmızı ton + BurnInOffset (dakikada kayma) + sıradaki alarm
  - [x] ClockScreen hub IA: Saat · Dünya · Alarm · Timer · Kronometre · Odak (StudyTimerCard yalnız Odak)
- **Kabul:** Burn-in unit ≥10px / 60 periyot; clock hub widget PASS — `Kodda doğrulandı`. Landscape StandBy cihaz — `Cihazda doğrulanmalı`.



### Son Teslim Notları

- **Ürün kapanış / yayın 2026-07-13:** WP-52/45/46/47/58/59/60 ve V8-A/B/C cihaz QA’sı bekleyen kalemler **Tamamlanan**’a alındı; v8 yayımlandı. WP-48/49/50, doğrudan yayın/soak'ı atlama kararıyla silindi. Yeni yayın sorunu ayrı debug/release WP'sidir. Windows: WP-27/53/28 açık.
- **beta-v18 polish:** Taç avatarları sıralama/aktif/chat/istatistik/profilde; profilde Başarılar → Çalışma kayıtları üstünde; Widget/izinler Ayarlar’da; tap-to-top Ana Sayfa; 15 atmosfer tema.
- **WP-41/42/51 + Grok timer hotfix (2026-07-13):** Native `StudyTimerService`, app-kapalı Başlat/Durdur, chronometer bildirim, beta-v13–v15 rötuşları; in-app start idle race fix (`94945ac`). Ürün sahibi kapatma kararı.
- **WP-54–57 (2026-07-13):** Tema Stüdyosu + Başarım 3.0 ledger/UI; taç 0/2.5k/10k/25k/75k; saat +10 XP; profil/tap/taç polish. SQL 0025–0027 canlı uygulama kullanıcının; 0028 genel yayın sıfırlaması.

- **WP-58/59/60 Saat Merkezi (2026-07-13, Grok):** Epoch time engine; Alarm 2.0 UI; multi-timer; dünya/kronometre/StandBy hub.
- **Saat P0 reliability (2026-07-13, Grok):** Native `AlarmManager` + `AlarmRingActivity` (USAGE_ALARM MediaPlayer 30sn crescendo, kilit ekranı, anti-snooze math, dismiss/snooze); boot/timezone mirror reschedule; multi-timer endsAt native schedule; device TZ (artık sabit Istanbul değil); analyze 0; 23 test PASS. Cihaz reboot/OEM/ses hâlâ `Cihazda doğrulanmalı`.

- **WP-37:** `docs/DENETIM-FAZ0A.md` ile WP-1–36'nın kanıtlanabilir aşamaları, özellik envanteri, P0/P1/P2 listesi, risk/v8 blocker kaydı ve belge tutarsızlığı önerileri teslim edildi. `app/` diff'i boş; canlı backend teyidi WP-38'de kalır.

- **WP-38:** Canlı Supabase durumunu denetlemek için yerel migration listesi, Edge Function envanteri ve doğrulama SQL sorguları `docs/BACKEND-DURUM.md` olarak eklendi. Blocker RLS (B7) kullanıcı kararına bırakıldı.

- **WP-36:** Ayarlar'daki "Ana Sayfa" grubu kaldırıldı (sayaç anahtarı "Gruplar" grubuna taşındı); dürtme, hatırlatıcı, alarm/timer, duyuru, güncelleme ve sessiz saatleri tek yerden yöneten `NotificationCenterScreen` eklendi. `0023_notification_center.sql` (study_reminders + announcement_reads, RLS owner-only), çift `NotificationRepository`, yerel hatırlatıcı planlama servisi ve sessiz-saat mantığı; dürtme dinleyicisi ve güncelleme bildirimi tercihlere saygı gösterir. Gruplar/İstatistik sekmeleri zaten dolu doğrulandı.

- **WP-26:** Hazır paletler, kalıcı tema ayarları ve üç özel renk slotu eklendi (`bd5a906`).
- **WP-24:** Yerel alarm, preset, etiketli çoklu timer, pause/resume/reset/delete ve alarm bildirim kanalı eklendi (`c47042d`).
- **WP-23:** Clock Center, yatay StandBy görünümü ve ana shell'den Saat erişimi eklendi (`8618d86`).
- **WP-31:** Bağlı e-posta, e-posta değiştirme, güvenli çıkış ve recovery akışı ile `AccountSettingsScreen`/`RecoveryScreen` oluşturuldu.
- **WP-32:** `0019_feedback_attachments.sql`, görsel seçimi ve admin önizlemesi eklendi.
- **WP-33:** Süper-admin Edge function ve RLS logları oluşturuldu, arayüz testleri düzenlendi.
- **WP-34:** Süper-Admin çoklu sekme (Dashboard, Users, Groups, Reports, Announcements, Audit Log), duyurular ve grup moderasyonu eklendi.
- **WP-35:** Sosyal Profil vitrini (SocialProfileDialog), Başarı Yolculuğu, 60+ kademeli başarı kural motoru, güvenli Supabase upsert/senkronizasyon ve `0022` migration düzeltmesi eklendi.
