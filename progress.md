# progress.md — İlerleme Takibi

> Son güncelleme: 2026-07-12
> Sistem: İş Paketi (WP) tabanlı, **Kalite Programı**. Kanonik program: `docs/KALITE-PROGRAMI.md`.
> Planlama: `.agents/skills/planner/SKILL.md` · Uygulama: `.agents/skills/worker/SKILL.md` · Kurallar: `.agents/AGENTS.md`.
> **"Tamamlandı" = kod DEĞİL; kullanıcı beklentisini karşılayan + cihazda güvenilir çalışan iş.** İş durum merdiveni (8 aşama) ve kanıt etiketleri (`Kodda doğrulandı` / `Cihazda doğrulanmalı` / `Ürün kararı gerekiyor`) için bkz. AGENTS.md §0.

---

## Proje Gerçekleri (ajan referansı)

- **Framework:** Flutter ^3.12 · Riverpod 3.3 · Supabase 2.15 · fl_chart
- **Uygulama kökü:** `app/` — Flutter komutları yalnız burada çalışır.
- **Repo katmanı çift:** Her arayüz `supabase/` ve `in_memory/` repository'leriyle desteklenir.
- **Migration'lar:** `supabase/migrations/` — yerelde `0001–0023` vardır. Canlı şemada `0001–0019` etkileri doğrulandı; `0020–0023` SQL Editor'da sırasıyla uygulanır. `0022` ve `0023` tekrar-çalıştırılabilir (idempotent).
- **Gün sınırı:** `Europe/Istanbul`
- **RLS helper'ları:** `is_group_member(gid)`, `can_see_user_sessions(target)`, `is_group_admin(gid)`, `is_super_admin()`
- **Dashboard:** 6 sütunlu 2D matris, 19 kart türü, `grid_reflow.dart` motoru.
- **Tema:** Hazır paletler + özel palet slotları; görünür tüm yüzeyler palette bağlanmalıdır, sabit gri renk eklenmez.
- **Navigasyon hedefi:** Ana Sayfa / Saat / Gruplar / İstatistikler / Profil. Ana Sayfa günlük kullanım alanıdır; diğer alanların verisi kendi sekmelerinde eksiksiz bulunur.
- **Release:** Stable/Beta kanalı GitHub Releases ile çalışır. **v7 yayında (özellik sürümü).** İlk kalite-kapılı stable önerisi: **v8 "Güven Sürümü"** (`Ürün kararı gerekiyor`).
- **Kalite kapıları:** Her WP DoD'siz kapanmaz; stable release kalite kapısından geçer (AGENTS.md §3). Server-authoritative XP, RLS/sosyal profil, platform sınırları → `docs/KALITE-PROGRAMI.md`.
- **Son WP numarası:** 45
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
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-12 19:10 (Europe/Istanbul)
- **Not:** WP-38 kullanıcı tarafından onaylandı ve kapatıldı.

### Claude Lane
- **Durum:** [x] Boşta
- **Faz/WP:** — · **Aşama:** — · **SAHİP yollar:** — · **Ortak/riskli yüzey:** — · **Dal:** — · **Son güncelleme:** 2026-07-12 19:10 (Europe/Istanbul) · **Not:** Kullanıcı talimatıyla WP-37 Codex'e devredildi; çalışma çıktısı yok.

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **Aşama:** —
- **SAHİP yollar:** —
- **Ortak/riskli yüzey:** —
- **Dal:** — (ana dal `main`)
- **Başlangıç:** —
- **Son güncelleme:** 2026-07-12 22:52 (Europe/Istanbul)
- **Not:** Yönetici istisnasıyla V8-A cihaz QA'sı ertelenerek WP-43 kod/otomatik-test aşaması tamamlandı: analyze 0, 259 test ve debug APK geçti. V8-A kabulü bu istisnayla geçilmiş sayılmaz.

---

## Kalite Programı — Faz/Program Sırası

> Kaynak: `docs/KALITE-PROGRAMI.md`. Bunlar program dilimleridir; planner tetiklenince WP'lere bölünür. Aynı anda en fazla **iki çalışma hattı**; Saat/Tema/Başarım aynı anda AÇILMAZ.

| Sıra | Program/Faz | Kapsam | Durum | Not |
|---|---|---|---|---|
| 1 | **Faz 0A** | Tek kaynak & tamamlanma denetimi (envanter, P0/P1/P2 bug, migration/Edge Function canlı durum) | Planlandı | Yeni özellik üretmez |
| 2 | **Faz 0B** | Test & gözlemlenebilirlik temeli (integration test, native test planı, Sentry) | Planlandı | — |
| 3 | **V8-A** | Sayaç–bildirim–widget tek doğruluk kaynağı (foreground service, canlı `Chronometer`) | Planlandı | native + cihaz QA |
| 4 | **V8-B** | Genel senkronizasyon denetimi (canonical projection, idempotency) | Planlandı | — |
| 5 | **V8-C** | Küçük IA: İstatistik sırası + Gruplar sırası/kamp ateşi + animasyon | Planlandı | düşük risk, golden test |
| 6 | **V8 beta → soak → stable** | Kalite kapısı | Planlandı | `Ürün kararı`: sürüm no |
| 7 | **Saat programı** | Saat 1–5 (motor → IA → alarm → kronometre/timer → StandBy/widget) | Planlandı | tek başına program |
| 8 | **Tema Stüdyosu** | Token motoru + 12+ tema ailesi + katmanlı editör | Planlandı | Saat ile eşzamanlı açılmaz |
| 9 | **Başarım & Sosyal Profil 3.0** | Tek motor, server-authoritative XP ledger, herkese açık profil RLS | Planlandı | güvenlik ağırlıklı |
| 10 | **Windows masaüstü** | WP-27/28 (aşağıda) | Planlandı | — |

## Planlanan İş Paketleri

> Burada yalnız başlanmamış, WP'ye bölünmüş işler bulunur. Sıra, bağımlılık ve ürün önceliğine göre korunur.

| WP | Durum | Kısa kapsam | Bağımlılık |
|---|---|---|---|
| WP-38 | Bekliyor | Faz 0A · Canlı backend durum matrisi (kod yok) | — |
| WP-40 | Kabul bekliyor | V8-A · Native timer state store + foreground service | — |
| WP-41 | Kabul bekliyor | V8-A · Canlı chronometer bildirim (Başlat/Durdur) | WP-40 |
| WP-42 | Kabul bekliyor | V8-A · Widget paritesi + olay bazlı stats besleme | WP-40 |
| WP-43 | Kabul bekliyor | V8-B · Genel senkronizasyon denetimi | WP-40, WP-42 (yönetici istisnası: cihaz QA ertelendi) |
| WP-44 | Bekliyor | V8-C · İstatistik grup sırası (düşük risk, bağımsız) | — |
| WP-45 | Bekliyor | V8-C · Gruplar sırası + kamp ateşi + animasyon (bağımsız) | — |
| WP-27 | Bekliyor | Windows desktop shell ve responsive layout | — |
| WP-28 | Bekliyor | Windows dağıtım, installer ve desktop polish | WP-27 |

> **Dağıtım notu:** WP-39 iptal edildi. **WP-40** V8-A'nın temelidir; WP-41/42 ondan sonra, ikisi `study_providers` timer-sync'i paylaştığı için birbirleriyle paralel değildir. WP-43, V8-A'dan sonra başlar. WP-44 ve WP-45 ayrık dosyalarda bağımsız yürütülebilir.

> ✅ Çakışma kontrolü: WP-37 ve WP-38 yalnız kendi yeni doc dosyalarına yazar (`docs/DENETIM-FAZ0A.md` vs `docs/BACKEND-DURUM.md`), `app/**` ve `supabase/**`'a dokunmaz → **paralel güvenli**, aktif lane yok.


### WP-40: V8-A · Native Timer State Store + Foreground Service ⏱️
- **Program/Faz:** V8-A (KALITE-PROGRAMI §8.1) — **V8'in temeli, ilk yapılır**
- **Ajan:** Codex
- **Durum:** [~] Otomatik test geçti — cihaz QA / ürün kabulü bekliyor
- **Problem:** Sayaç app kapalıyken güvenilir değil; tek gerçek zaman kaynağı ve foreground service yok (B4/B5).
- **Kapsam dışı:** Bildirim UI (→WP-41), widget (→WP-42), senkron denetimi (→WP-43).
- **SAHİP dosyalar (yaz):**
  - `app/lib/data/providers/study_providers.dart` (timer state alanları + servis köprüsü)
  - `app/lib/core/notifications/timer_external_command_store.dart` + yeni `app/lib/core/background/*`
  - `app/android/app/src/main/kotlin/**/` (foreground service Kotlin + boot receiver)
  - `app/android/app/src/main/AndroidManifest.xml`, `app/pubspec.yaml` (flutter_foreground_task)
- **DOKUNMA:** `core/theme/**`, `features/clock/**`, widget provider'ları (WP-42), diğer feature'lar.
- **Adımlar:**
  - [x] State modeli: mode/status/startedAt/accumulatedSeconds/targetSeconds/phase/cycle/subjectId/commandSeq/lastUpdatedAt.
  - [x] Foreground service (ongoing, start/stop) + izinler (`FOREGROUND_SERVICE`+tip, `WAKE_LOCK`).
  - [x] Boot receiver (`RECEIVE_BOOT_COMPLETED`) → aktif sayaç restore.
  - [x] Komut kuyruğu (sürüm/sequence) `timer_external_command_store` üstüne.
- **Veri/Migration etkisi:** Yok (yerel state).
- **RLS/Güvenlik:** Yok; sır yok.
- **Kabul (ölçülebilir):** Kod tamamlandı; `flutter analyze`, 254 test ve Android debug APK geçti. App kapalıyken 8 saatte ≤ ±1 sn, force-stop dışı lifecycle ve reboot sonrası restore için **cihaz kanıtı bekleniyor** (`Cihazda doğrulanmalı`).
- **Tuzaklar:** Sıcak dosyalar (pubspec/manifest/study_providers) → başka WP ile aynı anda GİRİLMEZ. OEM pil kısıtı testi.
- **Model önerisi:** 🔴 Opus

### WP-41: V8-A · Canlı Chronometer Bildirim (Başlat/Durdur) 🔔
- **Program/Faz:** V8-A · **Bağımlılık: WP-40 (kabul sonrası)**
- **Ajan:** Codex
- **Durum:** [~] Otomatik test geçti — cihaz QA / ürün kabulü bekliyor
- **Problem:** Bildirimde canlı `HH:MM:SS` + Başlat/Durdur, app açmadan yönetim (istek 1).
- **Kapsam dışı:** Widget (→WP-42), state store (WP-40).
- **SAHİP dosyalar (yaz):** `app/lib/core/notifications/timer_notification_service.dart`, ilgili notification receiver Kotlin.
- **DOKUNMA:** `study_providers.dart` (WP-40 sahibi — yalnız oku), widget (WP-42).
- **Adımlar:** [x] dar görünüm (HH:MM:SS + tek durum + Başlat/Durdur); [x] native `Chronometer` (usesChronometer); [x] butonlar Flutter açmadan sıralı native komut kaydına yazar. Geniş görünümdeki Sıfırla / +1 dk, timer state eylemi olarak ayrı UI kapsamıdır.
- **Kabul (ölçülebilir):** Kod/test/Android build geçti. 20 ardışık Başlat/Durdur (app kapalı), canlı akan saat ve bildirim/uygulama paritesi için cihaz videosu bekleniyor (`Cihazda doğrulanmalı`).
- **Tuzaklar:** Bildirim son görünümü OEM'e bağlı — hedef ulaşılabilir ama piksel garanti değil. `study_providers` timer-sync WP-40 kapsamında; buraya taşırsan WP-42 ile çakışır.
- **Model önerisi:** 🔴 Opus

### WP-42: V8-A · Widget Paritesi + Olay Bazlı Stats Besleme 📲
- **Program/Faz:** V8-A · **Bağımlılık: WP-40; WP-41 ile paralel DEĞİL** (`study_providers` paylaşımı → serileştir)
- **Ajan:** Codex
- **Durum:** [~] Otomatik test geçti — cihaz QA / ürün kabulü bekliyor
- **Problem:** Yalnız timer widget besleniyor; stats/leaderboard placeholder (B4).
- **Kapsam dışı:** Bildirim (WP-41), senkron canonical projection (WP-43 sağlar; burada tüketilir).
- **SAHİP dosyalar (yaz):** `app/lib/features/android_widgets/android_widget_service.dart`, `app/android/app/src/main/kotlin/**/widgets/*` (Chronometer RemoteViews), yeni widget besleme pipeline.
- **DOKUNMA:** `study_providers.dart` timer-sync (WP-40/41 — dar okuma), notification (WP-41).
- **Adımlar:** timer widget native `Chronometer`; Başlat/Durdur app açmadan; stats/leaderboard **olay bazlı** besleme (session ekl/düzenle/sil, sync, grup değişimi, gün sınırı, manuel refresh); light/dark + dynamic color; boş-durum.
- **Kabul (ölçülebilir):** Boş durumda anlamlı metin var; oturum, senkronizasyon ve grup/membership akışlarında olay bazlı yenileme var; 48 dp dokunma alanı ile light/dark ve Android 12+ dynamic color kaynakları eklendi. `flutter analyze`, 254 test ve Android debug APK geçti (`Kodda doğrulandı`). Oturum sonrası ≤ 5 sn ve cihaz videosu / ürün kabulü `Cihazda doğrulanmalı`.
- **Tuzaklar:** Saniyede bir Flutter yeniden çizme YOK; periyodik <15 dk garanti değil → native Chronometer + olay bazlı.
- **Model önerisi:** 🔴 Opus

### WP-43: V8-B · Genel Senkronizasyon Denetimi 🔄
- **Program/Faz:** V8-B (KALITE-PROGRAMI §8.2) · **Bağımlılık: WP-40, WP-42 (kabul sonrası; yönetici istisnasıyla cihaz QA ertelendi)**
- **Ajan:** Codex
- **Durum:** [~] Otomatik test geçti — cihaz QA / ürün kabulü bekliyor
- **Problem:** Aynı metrik farklı ekranlarda tekrar/farklı hesaplanıyor; idempotency, tek gün-sınırı yardımcısı, invalidation standardı yok.
- **Kapsam dışı:** Native timer (WP-40), widget UI (WP-42) — buradan yalnız canonical projection tüketilir.
- **SAHİP dosyalar (yaz):** `app/lib/core/stats/*` (canonical projection), `app/lib/data/repositories/offline/*` (outbox/idempotency), ilgili provider invalidation standardı.
- **DOKUNMA:** `study_providers.dart` timer state (WP-40 — oku), widget service (WP-42 — oku).
- **Adımlar:** [x] istatistik tüketici envanteri; [x] tek `Europe/Istanbul` gün-sınırı yardımcısı; [x] session streaminden canonical projection; [x] offline outbox + gecikmiş realtime snapshot reconciliation; [x] session kimliğiyle idempotent upsert; [x] widget snapshot canonical projection'dan. Çoklu-cihaz çakışmasında sunucu snapshot'ı + bekleyen yerel outbox birleşimi kullanılır; manuel widget yenileme mevcut native eylemle son snapshot'ı yeniden çizer.
- **Kabul (ölçülebilir):** 23:59–00:01 Istanbul sınırı ve duplicate session/outbox reconciliation otomatik testlerle geçti. `flutter analyze` 0 sorun, 259 test ve Android debug APK `Kodda doğrulandı`. UI ≤ 1 sn, widget ≤ 5 sn, iki gerçek cihaz çakışması ve cihaz videosu / ürün kabulü `Cihazda doğrulanmalı`.
- **Tuzaklar:** V8-A ile `study_providers`/widget çakışması → V8-A kabulünden SONRA başla.
- **Model önerisi:** 🔴 Opus

### WP-44: V8-C · İstatistik Grup Sırası 📊
- **Program/Faz:** V8-C (KALITE-PROGRAMI §8.3) · **Bağımsız — hemen verilebilir**
- **Ajan:** —
- **Durum:** [ ] Bekliyor
- **Problem:** Sıralama en altta; kullanıcı "grup günlük trendi"nin üstüne istiyor (istek 3).
- **Kapsam dışı:** Hesaplama mantığı değişmez (yalnız sıra); gruplar sekmesi (WP-45).
- **SAHİP dosyalar (yaz):** `app/lib/features/stats/widgets/class_stats_view.dart` + yeni golden test.
- **DOKUNMA:** diğer stats widget'ları, `features/classroom/**`.
- **Adımlar:** sıra = grup hedefi → özet → **sıralama** → grup günlük trendi → uzun eğilim → tüm zamanlar → karşılaştırma; golden test.
- **Kabul (ölçülebilir):** golden test yeni sırayı sabitler; analyze 0, test yeşil. `Ürün kararı`: §8.3 tam sıra onayı.
- **Tuzaklar:** V8-B stats hesabını değiştirebilir ama bu yalnız SIRA → düşük risk; V8-B'den önce yapılabilir.
- **Model önerisi:** 🔵 Sonnet

### WP-45: V8-C · Gruplar Sırası + Kamp Ateşi + Animasyon 🔥
- **Program/Faz:** V8-C · **Bağımsız — WP-44 ile paralel güvenli (farklı dosyalar)**
- **Ajan:** —
- **Durum:** [ ] Bekliyor
- **Problem:** Kamp ateşi üste; sıra ateş→hedef→sıralama; toparlanma animasyonu uzun (istek 4).
- **Kapsam dışı:** İstatistik sekmesi (WP-44); grup hedef/trend kartlarının iç mantığı.
- **SAHİP dosyalar (yaz):** `app/lib/features/classroom/classroom_screen.dart`, `app/lib/features/classroom/widgets/campfire_scene.dart` (animasyon süresi).
- **DOKUNMA:** `features/stats/**` (WP-44), group_goal_card/group_trend_card (yalnız yeniden sırala).
- **Adımlar:** sıra = kamp ateşi → grup hedefi → grup sıralaması → trend → yönetim; davet kodu/grup değiştirme kompakt başlığa/açılır alana; animasyon kısalt + `reduce-motion`.
- **Kabul (ölçülebilir):** ilk sahne ≤ 300 ms, tam yerleşim ≤ 700 ms; reduce-motion çalışır; screenshot/golden.
- **Tuzaklar:** Sonsuz/dekoratif animasyon batarya tüketmemeli.
- **Model önerisi:** 🔵 Sonnet

### WP-27: Windows Desktop Shell ve Responsive Layout

- **Kapsam:** Windows'ta masaüstüne uygun pencere davranışı, geniş ekran düzeni ve input/klavye iyileştirmeleri.
- **Kabul:** Uygulama farklı masaüstü ölçülerinde taşmadan, mobil akışı bozmadan kullanılabilir.

### WP-28: Windows Dağıtım ve Desktop Polish

- **Kapsam:** Installer, dağıtım akışı, güncelleme/çökme mesajları ve masaüstü son kalite kontrolleri.
- **Kabul:** Windows kullanıcıları kurulabilir, güncellenebilir ve desteklenebilir bir paket alır.

---

## Tamamlanan İş Paketleri

> Biten her WP yalnız bu başlık altında tutulur. Buradaki kartlar tekrar aktif veya planlanan iş olarak yazılmaz.

| WP | Tamamlanan kapsam |
|---|---|
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

### Son Teslim Notları

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
