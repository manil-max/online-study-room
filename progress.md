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
- **Son WP numarası:** 207 (WP-204/205/206/207 grup renkleri + sayaç bildirimi, git log doğrulandı; stable v39). Başarım/görev/grup-pp programı **WP-208–216 planlandı** (plan v2). **Sıradaki boş numara WP-217.**
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

> Bu tablo yalnız **aktif planlanmış** WP'leri gösterir. Tamamlanmış/test edilmiş tarihsel WP kartları (WP-23…207) arşivde: [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md) + git geçmişi. Yeni kod işi olarak yalnız `[ ] Bekliyor` satırları claim edilir.

| WP | Durum | Kısa kapsam | Bağımlılık |
|---|---|---|---|
| WP-209 | [ ] Bekliyor | **[YAYIN: 1.]** Topla-ödülü-al: ayrı `achievement_rewards` (pending/claim) + claim RPC (server 00NN) | plan v2 · **önce iner** |
| WP-216 | [ ] Bekliyor | **[YAYIN: 2.]** Oturum bütünlüğü sıkılaştırma (sessions RLS + zaman/süre CHECK, source='live') — Codex #4 (server 00NN) | plan v2 · WP-208 ön-koşulu |
| WP-208 | [ ] Bekliyor | **[YAYIN: 3.]** Ölü metrik retro fix (alpha_wolf/campfire/locomotive/break_enemy) + gerçek `metric_progress` sözleşmesi + team_player (server 00NN) | ← WP-209, WP-216 |
| WP-210 | [ ] Bekliyor | Başarım UI: canlı ilerleme (`metric_progress`) + claim/topla animasyon + "az kaldı" + metin netleştirme | ← WP-208 · ARB yazar |
| WP-211 | [ ] Bekliyor | Başarı/taç bildirimi: açılış banner'ı (Clash tarzı) + Brawl Stars nav-nokta işareti | ← WP-209 |
| WP-212 | [ ] Bekliyor | Günlük yenilenen görev: bulut model + tekrar/tamamlama + tombstone çok-cihaz (server 00NN) | plan doc |
| WP-213 | [ ] Bekliyor | Görev UI: günlük tip ekleme + bugünün listesi + 00:00 yenileme | ← WP-212 · ARB yazar |
| WP-214 | [ ] Bekliyor | Grup profil fotoğrafı (groups.avatar_url + avatar_updated_at cache-bust + bucket admin-yazma + discovery güncelle) | plan doc |
| WP-215 | [ ] Bekliyor | Tap-to-top tüm sekmeler (Gruplar/İstatistik/Profil/Araçlar) — navReselect zaten var | plan doc |

> **Açık ops işleri (kod dışı — bu tabloda değil, kanonik takip başka dosyada):** Play production programı (NO-GO), Edge deploy'lar (hesap silme purge CRON, aylık rapor cron), Data Safety/legal URL Console adımları → [`backlog.md`](backlog.md) + [`docs/PLAY-STORE-HAZIRLIK-TARAMASI.md`](docs/PLAY-STORE-HAZIRLIK-TARAMASI.md).
> Tarihsel `[x]`/`[~]` WP kartları (WP-104…207) ve eski dalga/çakışma notları arşive taşındı (2026-07-19 temizlik).



---

## Test için bekleyenler (park)

> Cihaz/ürün kabulü bekleyen tamamlanmış kod. Şu an aktif park kaydı **yok** (WP-134…207 test-bekleyen kartları arşive taşındı → [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md); açık ops işleri için yukarıdaki pointer). Planner yeni park kaydını buraya **tek satır** ekler.

## Tamamlanan İş Paketleri

> Ürün/cihaz kabulü almış WP'ler. Ayrıntılı tarihsel kartlar (WP-23…207) + "Son Teslim Notları" arşive taşındı → [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md). Planner yeni tamamlananı buraya **tek satır** ekler.

---

> **📦 Arşiv (2026-07-19 token optimizasyonu):** progress.md 1599→~138 satıra indirildi (2. tur: tamamlanmış/test-bekleyen WP-104…207 index satırları + eski dalga/çakışma notları temizlendi). Tarihsel WP kartları + Play detayı + park/Tamamlanan detayları + Son Teslim Notları [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md)'de. **Canlı durum bu dosyadadır** (Proje Gerçekleri + Aktif Çalışma Kaydı + aktif WP Durum Dizini). Bir WP'nin tarihsel ayrıntısı gerekirse arşivden okunur.
