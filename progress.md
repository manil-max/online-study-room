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
- **Son WP numarası:** 207 (WP-204/205/206/207 grup renkleri + sayaç bildirimi, git log doğrulandı; stable v39). **Sıradaki boş numara WP-208.**
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
- **Faz/WP:** WP-207 · üye grafik renk çakışması düzeltmesi · stable v39 yayın
- **Aşama:** Yayınlandı — gerçek cihaz QA / ürün kabulü bekliyor
- **SAHİP yollar:** `app/lib/features/stats/widgets/member_chart_colors.dart`, `app/lib/features/stats/widgets/class_stats_view.dart`, `app/lib/features/stats/widgets/leaderboard_rank_chart.dart`, ilgili testler, `app/pubspec.yaml`, `app/assets/release_notes.json`, `CHANGELOG.md`, `progress.md`
- **Ortak/riskli yüzey:** `app/pubspec.yaml`, `CHANGELOG.md`, `progress.md`
- **Dal:** main
- **Başlangıç:** 2026-07-19 (Europe/Istanbul)
- **Son güncelleme:** 2026-07-19 (Europe/Istanbul)
- **Not:** Android stable `v39` yayınlandı (c6843a5); GitHub APK + SHA-256 oluşturdu. Renkler grup üye sayısına göre tekil dağıtılır; cihazda görsel kabul bekliyor.

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
| WP-154 | [~] Test için bekliyor | Level/quest/cosmetics + 0042 | SQL Editor + cihaz |
| WP-155 | [~] Test için bekliyor | ar/de + RTL altyapı | Cihazda doğrulanmalı |
| WP-156 | [~] Plan uygulandı (flag kapalı) | İstatistik & Gruplar analitik plan | docs/features |
| WP-157 | [~] Test için bekliyor | Grafik primitives gauge/stacked/radar/area | `2c7bc91` |
| WP-158 | [~] Test için bekliyor | Analytics grid shell + prefs + flag | `5f8f1d5` |
| WP-159 | [~] Test için bekliyor | 22 kart registry (kişisel sarmalayıcılar) | `8d4fff9` |
| WP-160 | [~] Test için bekliyor | goalGauge/streak/compare/insight | `8d4fff9` |
| WP-161 | [~] Test için bekliyor | 0039/0040 RPC + grup kartları | SQL Editor |
| WP-162 | [~] Test için bekliyor | Kart ekle/çıkar + Stats flag entegrasyon | `4b4d711` |
| WP-163 | [~] Test için bekliyor | AnalyticsPeriod year/custom/kıyas | UI bar kısmi |
| WP-164 | [~] Test için bekliyor | Analitik teslim düzeltmesi (ızgara/reflow/veri/0041) | `Cihazda doğrulanmalı` |
| WP-165 | [~] Ops/cihaz bekliyor | QA runbook + Play sahip checklist | Deploy yok |
| WP-166 | [~] Test için bekliyor | Kalite denetimi + düzeltmeler | Cihazda doğrulanmalı |
| WP-167 | [x] Otomatik test geçti | Timer FakeTimer dispose sızıntısı | kod+test |
| WP-168 | [~] Test için bekliyor | Feedback gönderilemedi tanı+onarım | Cihazda doğrulanmalı |
| WP-169 | [~] Plan onay bekliyor | Günlük/haftalık görev listesi kartı PLAN | `docs/features/GOREV-LISTESI-KART-PLAN.md` · kod yok |
| WP-170 | [~] Test için bekliyor | Stats klasik (ızgara kaldır) | `Cihazda doğrulanmalı` |
| WP-171 | [~] Test için bekliyor | Başarımlar başlık taşması | `Cihazda doğrulanmalı` |
| WP-172 | [~] Test için bekliyor | Gruplar nested scroll | `Cihazda doğrulanmalı` |
| WP-173 | [~] Test için bekliyor | l10n Hours + de/ar (AR kısmi) | `docs/L10N-DUZELTME-2026-07.md` |
| WP-174 | [x] Rapor | UI sweep | `docs/qa/WP-174-UI-SWEEP.md` |
| WP-175 | [~] Plan onay bekliyor | Klasik stats zenginleştirme PLAN | `docs/features/ISTATISTIK-ZENGINLESTIRME-PLAN.md` |
| WP-176 | [x] Otomatik test geçti | 15 kırık test yeşil (shell scroll + notes + achievement) | full test **529** |
| WP-177 | [~] Cihaz/SQL bekliyor | Feedback ensure 0044 + net hata | sahip SQL + beta |
| WP-178 | [~] Test için bekliyor | StatsPeriod year/custom/kıyas | `Cihazda doğrulanmalı` |
| WP-179 | [~] Test için bekliyor | Kişisel sabit bölümler (gauge/area/radar) | `Cihazda doğrulanmalı` |
| WP-180 | [~] Test için bekliyor | Grup donut/seri/gauge | `Cihazda doğrulanmalı` |
| WP-181 | [~] Test için bekliyor | Cila + ölü grid silme | `Cihazda doğrulanmalı` |
| WP-183 | [~] Tag/beta bekliyor | beta-v31: 1.0.31+31 + BETA-v31-TEST | `docs/qa/BETA-v31-TEST.md` |
| WP-184 | [~] Test için bekliyor | Feedback PostgREST schema cache (0045 + NOTIFY) | sahip: 0045 SQL `jiphfrpzvkpzubbkhrwb` |
| WP-185 | [~] Test için bekliyor | Stats period bar declutter (6 chip + compact compare) | cihaz UI |
| WP-186 | [~] Test için bekliyor | Home grid density sabit 32; seçici kaldır | cihaz Home |
| WP-187 | [~] Test için bekliyor | Profil gamification declutter (rozetler kalır) | cihaz Profil |
| WP-188 | [~] Test için bekliyor | Home Görevler kartı (günlük/haftalık) | cihaz Home ekle |
| WP-189 | [~] Tag/beta bekliyor | beta-v32: 1.0.32+32 + BETA-v32-TEST | `docs/qa/BETA-v32-TEST.md` |
| WP-190 | [~] Test için bekliyor | Stats dönem tek yatay satır (scroll) | cihaz stats |
| WP-191 | [~] Test için bekliyor | Grup sıralama üst + gauge boşluk | cihaz grup stats |
| WP-192 | [~] Test için bekliyor | Gerçek taç + taç XP barı | cihaz profil |
| WP-193 | [~] Test için bekliyor | Feedback gerçek hata + dar classify | sahip SQL + cihaz Detay |
| WP-194 | [~] Tag/beta bekliyor | beta-v33: 1.0.33+33 + BETA-v33-TEST | `docs/qa/BETA-v33-TEST.md` |
| WP-195 | [~] Test için bekliyor | 0046 feedback trigger (42704 role) + taç %18 | sahip: 0046 SQL + cihaz |
| WP-196 | [~] Test için bekliyor | Görevler deadline plan + model/repo v2 | cihaz |
| WP-197 | [~] Test için bekliyor | dueAt + sıralama + urgency renk | — |
| WP-198 | [~] Test için bekliyor | Araçlar + Görevler CRUD | cihaz Araçlar |
| WP-199 | [~] Test için bekliyor | Home kartı gör/renk/tik | cihaz Home |
| WP-200 | [~] Test için bekliyor | Görevler cila (gecikti/a11y) | cihaz |
| WP-201 | [x] Yayınlandı | beta-v34: 1.0.34+34 notları + cihaz test listesi | tag `beta-v34` |
| WP-202 | [~] Yayınlandı, cihaz bekliyor | Görevler kartı tasarım cilası (kalan-süre rozeti, ayraçlı liste, başlık sayaç) + **stable v35** rollup | tag `v35` |
| WP-203 | [~] Yayınlandı, cihaz bekliyor | Manuel süre gece-yarısı fix (00:00 kenet kaldırıldı, gelecek-bitiş yok) + istatistik yenileme (personal declutter, eksenli grafikler, radar düz etiket; grup tek hedef, katkı legend, liderlik sıralama çizgi grafiği, tek trend) → **stable v36** | tag `v36` |
| WP-208 | [ ] Bekliyor | Başarım ölü metrik fix (alpha_wolf/campfire/locomotive retroaktif) + team_player gözden geçirme (server 00NN) | `docs/features/BASARIM-GOREV-GRUPPP-PLAN-2026-07.md` |
| WP-209 | [ ] Bekliyor | Topla-ödülü-al: pending reward + claim RPC (server 00NN) | ← WP-208 |
| WP-210 | [ ] Bekliyor | Başarım UI: canlı ilerleme cilası + claim/topla + "az kaldı" + metin netleştirme | ← WP-209 · ARB yazar |
| WP-211 | [ ] Bekliyor | Başarı/taç bildirimi: açılış banner'ı (Clash tarzı) + Brawl Stars nav-nokta işareti | ← WP-209 |
| WP-212 | [ ] Bekliyor | Günlük yenilenen görev: bulut model + tekrar/tamamlama (server 00NN) | plan doc |
| WP-213 | [ ] Bekliyor | Görev UI: günlük tip ekleme + bugünün listesi + 00:00 yenileme | ← WP-212 · ARB yazar |
| WP-214 | [ ] Bekliyor | Grup profil fotoğrafı (groups.avatar_url + group-avatars bucket admin-yazma) | plan doc |
| WP-215 | [ ] Bekliyor | Tap-to-top tüm sekmeler (Gruplar/İstatistik/Profil/Araçlar) — navReselect zaten var | plan doc |

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


---

## Test için bekleyenler (park)

> Cihaz/ürün kabulü bekleyen tamamlanmış kod. **Kanonik park durumu = yukarıdaki WP Durum Dizini'ndeki `[~]` satırları.** Eski ayrıntılı park kartları (WP-134–201 vb.) arşive taşındı → [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md). Planner yeni park kaydını buraya **tek satır** ekler.

## Tamamlanan İş Paketleri

> Ürün/cihaz kabulü almış WP'ler. Ayrıntılı tarihsel kartlar (WP-23…207) + "Son Teslim Notları" arşive taşındı → [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md). Planner yeni tamamlananı buraya **tek satır** ekler.

---

> **📦 Arşiv (2026-07-19 token optimizasyonu):** progress.md 1599→232 satıra indirildi. Tarihsel WP kartları (Tarihsel uygulama kartları WP-103–109/WP-93, Play detay kartları WP-110–124, park detay kartları, Tamamlanan detay kartları, Son Teslim Notları) [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md)'ye taşındı. **Canlı durum bu dosyadadır** (Proje Gerçekleri + Aktif Çalışma Kaydı + WP Durum Dizini). Bir WP'nin tarihsel ayrıntısı gerekirse arşivden okunur.
