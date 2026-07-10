# progress.md — İlerleme Takibi

> Son güncelleme: 2026-07-10
> Sistem: İş Paketi (WP) tabanlı. Planlama → `.agents/skills/planner/SKILL.md`, Uygulama → `.agents/skills/worker/SKILL.md`.

---

## Proje Gerçekleri (ajan referansı)

- **Framework:** Flutter ^3.12 · Riverpod 3.3 · Supabase 2.15 · fl_chart
- **Uygulama kökü:** `app/` — tüm flutter komutları burada çalışır
- **Migration'lar:** `supabase/migrations/` (son: `0013`) — sıralı, elle uygulanır
- **Repo katmanı çift:** her arayüz `supabase/` + `in_memory/` altında
- **Gün sınırı:** `Europe/Istanbul`
- **RLS helper'ları:** `is_group_member(gid)`, `can_see_user_sessions(target)`, `is_group_admin(gid)`
- **Dashboard:** 6 sütunlu 2D matris, 19 kart türü, `grid_reflow.dart` motoru
- **Tema:** 5 palet, koyu varsayılan, `AppTheme` palet-parametreli
- **Son WP numarası:** 16 (WP-1 aktif, WP-2..WP-16 plan kuyruğunda)
- **Geliştirme ortamı:**
  - Proje: `C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room`
  - Flutter: `C:\src\flutter` · Android SDK: `C:\Android\Sdk`
  - JDK: `C:\Program Files\Android\Android Studio\jbr`
  - Web test: `flutter run -d chrome --web-port=5005 --dart-define-from-file=env.json`
  - GitHub: `manil-max/online-study-room` (public)

---

## ⚡ Aktif İş Paketleri

*(Şu an aktif WP yok. Sıradaki iş Plan Kuyruğu'ndan seçilecek.)*

---

## 🧭 Plan Kuyruğu

> Bu bölüm backlog'daki işlerin uygulanma sırasını ve dosya sahipliğini önden netleştirir. Aktif çalışmaya alınacak iş, buradan seçilip yukarıdaki "Aktif İş Paketleri" bölümüne taşınır.

### Bir Sonraki Sürüm Notu
- Android ana ekran görünen adı `online_study_room` yerine **Odak Kampı** olacak.
- Değişiklik release/update hazırlanırken `app/android/app/src/main/AndroidManifest.xml` içindeki `android:label` üzerinden yapılacak.
- `pubspec.yaml` proje adı şimdilik değiştirilmez; kullanıcıya görünen ad yeterli.

### WP-4: Home Responsive QA
- **Backlog:** Ana Sayfa responsive kart cilası
- **Bağımlılık:** Önce mevcut 2E tamamlandı bilgisi doğrulansın.
- **SAHİP dosyalar:** `app/lib/features/home/widgets/*`, home widget testleri
- **DOKUNMA:** `classroom/*`, `profile/*`, `dashboard_providers.dart`
- **Not:** Bu iş büyük ölçüde tamamlanmış görünüyor; muhtemelen QA/ince düzeltme veya backlog kapatma işi.

### WP-5: Presence Lifecycle
- **Backlog:** Çevrimdışı tespiti, heartbeat/yaşam döngüsü
- **Bağımlılık:** Presence RLS 0013 Supabase'de uygulanmış olmalı.
- **SAHİP dosyalar:** presence provider/repository, app lifecycle entegrasyonu, gerekiyorsa yeni `0015_*` migration
- **DOKUNMA:** timer widget'ları, profil/auth
- **Not:** Yetki kuralı gerekiyorsa mutlaka RLS/RPC ile uygulanır.

### WP-6: Android Surface Extensions
- **Backlog:** Dynamic panel / Live Activities benzeri durum hapı, kilit ekranı widget'ı
- **Bağımlılık:** WP-1 ve WP-2 bitmeli.
- **SAHİP dosyalar:** Android native notification/widget dosyaları, `features/android_widgets/**`
- **DOKUNMA:** classroom/profile/auth
- **Not:** Android sürüm desteği araştırma gerektirir; mümkün değilse fallback persistent notification olur.

### WP-7: Class Chat
- **Backlog:** Sınıf sohbeti
- **Bağımlılık:** Yeni DB tasarımı onaylanmalı.
- **SAHİP dosyalar:** yeni chat migration, chat repository çift implementasyon, class detail chat UI, chat testleri
- **DOKUNMA:** timer, widget native dosyaları, profile/auth
- **Not:** Mesaj okuma/yazma yetkisi RLS ile grup üyeliğine bağlanmalı.

### WP-8: Nudge + Notifications
- **Backlog:** Dürtme sistemi, kapsamlı bildirim sistemi
- **Bağımlılık:** WP-2 bildirim altyapısı; chat yapılırsa WP-7 ile uyum.
- **SAHİP dosyalar:** notification preferences, nudge UI/repository, ilgili migration/RLS
- **DOKUNMA:** timer state machine'e doğrudan müdahale etme
- **Not:** Taciz/spam önlemek için rate limit veya cooldown düşünülmeli.

### WP-9: Gamification
- **Backlog:** Streak freeze, taç/rozet, başarımlar, profil başarı alanı
- **Bağımlılık:** Claude profil hayvan/kamp ateşi değişiklikleri bitmeli.
- **SAHİP dosyalar:** stats saf fonksiyonları, gamification modelleri/repository, profile UI, gerekiyorsa migration
- **DOKUNMA:** Android widget/native, auth recovery
- **Not:** Türetilen istatistik mi tablo mu kararı önceden netleşmeli.

### WP-10: Class Metrics Pack
- **Backlog:** Daha fazla sınıf metriği, grup çizgi grafiği, tüm zamanlar istatistiği, yeni grafik türleri
- **Bağımlılık:** İstenen metrikler seçilmeli.
- **SAHİP dosyalar:** `app/lib/core/stats/*`, stats/dashboard chart widget'ları, gerekiyorsa RPC migration
- **DOKUNMA:** auth/profile/native Android
- **Not:** `study_sessions.group_id` geri getirilmez; grup metrikleri üyelik join'iyle hesaplanır.

### WP-11: Windows Desktop Track
- **Backlog:** Windows build + widget, Windows installer
- **Bağımlılık:** Ana uygulama analyze/test temiz olmalı.
- **SAHİP dosyalar:** Windows runner/config, always-on-top mini pencere, dağıtım notları
- **DOKUNMA:** Android native widget dosyaları
- **Not:** Windows widget gerçek OS widget değil, mini Flutter pencere olarak kalmalı.

### WP-12: Sync & Offline Track
- **Backlog:** Çoklu cihaz senkron testi, çevrimdışı cache
- **Bağımlılık:** Presence/timer akışları stabil olmalı.
- **SAHİP dosyalar:** senkron testleri, cache adapter katmanı, seçilirse Drift/Hive dosyaları
- **DOKUNMA:** mevcut repository sözleşmelerini kırma
- **Not:** Drift/Hive seçimi geri dönüşü zor karar; başlamadan kullanıcı onayı gerekir.

### WP-13: Release Channels
- **Backlog:** Beta/staging test uygulaması
- **Bağımlılık:** Release akışı stabil olmalı.
- **SAHİP dosyalar:** Android product flavors, CI release workflow, updater kanal mantığı
- **DOKUNMA:** release keystore dosyaları; `key.jks` yeniden üretilmez
- **Not:** Build number/tag kuralı korunmalı.

### WP-14: Admin / Reports
- **Backlog:** Admin paneli, otomatik e-posta raporları
- **Bağımlılık:** Admin rol modeli ve e-posta sağlayıcı kararı.
- **SAHİP dosyalar:** admin UI, admin RPC/RLS, rapor üretim servisleri
- **DOKUNMA:** service_role istemciye konmaz
- **Not:** Public repo olduğu için güvenlik tasarımı ayrı gözden geçirilmeli.

### WP-15: Device Integrations
- **Backlog:** Samsung Modes & Routines entegrasyonu
- **Bağımlılık:** Android platform araştırması.
- **SAHİP dosyalar:** Android intent/integration denemeleri, ayarlar entegrasyonu
- **DOKUNMA:** genel timer state machine'i araştırma bitmeden değiştirme
- **Not:** Önce spike olarak yapılmalı; desteklenmezse backlog notu düşülür.

### WP-16: Dashboard Advanced Polish
- **Backlog:** Gelişmiş grid boyutlandırma, canlı grup hedefi, grup yönetimi UI iyileştirme
- **Bağımlılık:** Mevcut 6xN grid ve 2E responsive sonucu doğrulansın.
- **SAHİP dosyalar:** dashboard grid UI, group management UI, ilgili home/profile ekranları
- **DOKUNMA:** classroom timer/campfire dosyaları
- **Not:** Grid boyutlandırma ve canlı grup hedefinin bir kısmı zaten yapılmış olabilir; önce backlog temizlik turu gerekir.

---

## ✅ Son Tamamlananlar (ajan bağlamı için)

> Son 5 iş. Ajan bunları okuyarak "neye dokunma, ne değişti" anlar.
> Daha eski işler aşağıdaki Geçmiş tablosuna düşer.

### WP-3: Auth Recovery — 2026-07-10 ✅
- **Değişen dosyalar:** `data/repositories/auth_repository.dart`, `data/repositories/in_memory/in_memory_auth_repository.dart`, `data/repositories/supabase/supabase_auth_repository.dart`, `features/auth/auth_screen.dart`, `test/data/auth_repository_test.dart`, `test/widget_test.dart`
- **Ne yapıldı:** Auth repository arayüzüne `sendPasswordResetEmail` eklendi. Supabase implementasyonu `resetPasswordForEmail` çağırıyor; in-memory implementasyon hesap var/yok bilgisi sızdırmadan geçerli e-posta kabul ediyor. Giriş ekranına `Şifremi unuttum` akışı ve kayıt sonrası e-posta doğrulama bilgi mesajı eklendi.
- **Dokunma:** `classroom/*`, `home/*`, Android widget/native dosyaları, Supabase migration dosyaları.
- **Not:** Supabase Confirm email ayarı repo dışından açık olmalı; uygulama session dönmeyen kayıt cevabını doğrulama mesajı olarak ele alıyor.
- **Test:** `flutter analyze` temiz. `flutter test --concurrency=1 --dart-define-from-file=env.json` tüm testler geçti.

### WP-2: Persistent Notification + Background Timer — 2026-07-10 ✅
- **Değişen dosyalar:** `app/lib/core/notifications/timer_notification_service.dart`, `app/lib/data/providers/study_providers.dart`, `app/lib/main.dart`, `app/android/app/src/main/AndroidManifest.xml`, `app/android/app/build.gradle.kts`, `app/pubspec.yaml`, `app/pubspec.lock`, `app/test/core/timer_notification_service_test.dart`, `app/test/features/timer_state_machine_test.dart`, `app/test/widget_test.dart`
- **Ne yapıldı:** `flutter_local_notifications` ile Android kalıcı sayaç bildirimi eklendi. Sayaç çalışırken bildirim chronometer gösterir ve `Durdur` aksiyonu uygulama açıkken timer state machine'e bağlanır. Aktif timer başlangıcı/modu/fazı/konusu `SharedPreferences` ile saklanır; uygulama yeniden açılınca timer kaldığı yerden wall-clock süreyle devam eder. Android 13+ `POST_NOTIFICATIONS` izni ve desugaring config eklendi.
- **Dokunma:** `profile/*`, `auth_repository*`, `home/*`, `presence_providers.dart`, Supabase migration dosyaları.
- **Kalan:** Ayrı `Başlat`/manuel `Mola` bildirim aksiyonları eklenmedi; mevcut ürün kararında mola manuel buton değil, pomodoro fazı olarak çalışıyor.
- **Test:** `flutter analyze` temiz. `flutter test --dart-define-from-file=env.json` tüm testler geçti. `flutter build apk --debug --dart-define-from-file=env.json` geçti.

### WP-1: Android Widget Foundation — 2026-07-10 ✅
- **Commit:** `616a92d`
- **Değişen dosyalar:** `app/pubspec.yaml`, `app/pubspec.lock`, `app/android/app/src/main/AndroidManifest.xml`, yeni `app/lib/features/android_widgets/android_widget_service.dart`, yeni Android widget provider/layout/xml dosyaları, yeni `app/test/features/android_widget_service_test.dart`
- **Ne yapıldı:** `home_widget` eklendi. Timer, günlük/haftalık istatistik ve grup leaderboard için Android ana ekran widget altyapısı kuruldu. Flutter tarafında native widget verisini yazan izole servis/provider eklendi.
- **Dokunma:** `classroom/*`, `profile/*`, `auth_repository*`, `study_providers.dart`, `supabase/migrations/0014_profile_animal.sql`
- **Kalan:** Timer widget başlat/durdur aksiyonları ve arka plan kontrolü WP-2'ye bırakıldı.
- **Test:** WP-1 özel test + WP-1 özel analyze temiz; `flutter build apk --debug --dart-define-from-file=env.json` geçti. Global analyze/test Claude'un aktif debug/test değişiklikleri nedeniyle bu committe bekletildi.

### Kamp Ateşi — Ormanda Hayvanlı Sahne (eski 2G, yeniden tasarım) — 2026-07-10 ✅
- **Değişen dosyalar:** `classroom/widgets/campfire_scene.dart` (baştan yazıldı), yeni
  `classroom/widgets/camp_critter.dart` (tüm çizimler), yeni `core/animals/camp_animal.dart`,
  yeni `profile/widgets/camp_animal_picker.dart`, `profile/settings_screen.dart` (+"Kamp ateşi" grubu),
  `data/models/profile.dart` (+`animal`), `data/repositories/auth_repository.dart` + `in_memory/` +
  `supabase/` (+`updateAnimal`), yeni `supabase/migrations/0014_profile_animal.sql`.
- **Ne yapıldı:** Gece ormanında **45° taşlı kamp ateşi** sahnesi (hepsi `CustomPainter`, ek paket yok).
  Tüm grup üyeleri ateş çevresinde **elipse** dizilir: üst yaydakiler **alevin ARKASINDA** (küçük/soluk),
  alt yaydakiler **ÖNÜNDE** (büyük) → gerçek derinlik. Her üye **kendi kütüğünde oturan elle çizilmiş
  tombul hayvan** (Party Animals ruhu; 12 tür, ortak gövde + türe göre kulak/renk/kuyruk/gaga). **Çalışan**
  üye gerçekçi bir **dalda marşmelov** kızartır; marşmelov **oturum süresine göre kademeli pişer**
  (çiğ→altın→kızarmış→koyu + kömür lekesi/buhar, ~40dk). İsim/süre en üst katmanda (alev arkasında bile
  okunur). Orman arka plan: ay+yıldız+katmanlı çam silüetleri (kenarlarda yoğun)+zemin açıklığı. Sahne
  yüksekliği 480px. Nefes animasyonu; çevrimdışı uyur/soluk. **Hayvan seçimi** Ayarlar→Kamp ateşi
  (`profiles.animal`, 0014 — **kullanıcı çalıştırdı**). Seçilmeyene `userId` hash'iyle deterministik varsayılan.
- **Dokunma:** `home/*`, `dashboard_card.dart`, `study_providers.dart`, timer widget'ları.
- **Test:** `camp_animal` birim testleri + `campfire_scene_test.dart` geçiyor; `flutter analyze` temiz.
  (Not: sahne, test render'ından PNG'ye çekilip görsel doğrulandı.)

### Eksiksiz Sayaç/Zamanlayıcı (eski 2H) — 2026-07-10 ✅
- **Değişen dosyalar:** `classroom/widgets/study_timer_card.dart`, `focus_timer_screen.dart`, `clock_style.dart`, `data/providers/study_providers.dart`, yeni `timer_mode_controls.dart`
- **Ne yapıldı:** `StudyTimerNotifier` mod-duyarlı state machine — `TimerMode` (stopwatch/countdown/pomodoro) + `TimerPhase` (work/rest). Geri sayım süre seçici, Pomodoro döngü sayacı + otomatik mola. Her faz bitiminde `_recordSession` ile oturum kaydı. Tam ekran odak moduyla uyumlu.
- **Dokunma:** `home/*`, `profile/*`, `supabase/migrations/*`, `presence_providers.dart`
- **Test:** 2 timer testi, toplam 135+ test geçiyor

### Ayarlar ve Grup Yönetimi Overhaul (eski 2I) — 2026-07-10 ✅
- **Değişen dosyalar:** `profile/settings_screen.dart`, `profile/profile_screen.dart`, `profile/appearance_screen.dart`, yeni `profile/widgets/*`, `core/prefs/*`
- **Ne yapıldı:** Ayarlar ekranı genişletilebilir Görünüm, Ana Sayfa, Sayaç ve Bildirimler gruplarına ayrıldı. Ana Sayfa sıfırlama düzenleme modunun AppBar'ına taşındı.
- **Dokunma:** `classroom/*`, `presence_providers.dart`, `dashboard_card.dart`, `study_timer_card.dart`

### Presence RLS Hardening — 2026-07-10 ✅
- **Değişen dosyalar:** yeni `supabase/migrations/0013_presence_membership_hardening.sql`
- **Ne yapıldı:** Kullanıcı yalnız aktif üyesi olduğu gruba `presence` insert/update atabilir (`is_group_member(group_id)` ile). Kullanıcı Supabase SQL Editor'da çalıştırmalı.
- **Dokunma:** `classroom/*`, timer widget'ları, `study_providers.dart`, `home/*`, `profile/*`

### Kart Responsive Adaptasyonu (eski 2E) — 2026-07-10 ✅
- **Değişen dosyalar:** `home/widgets/` altındaki 16 kart, yeni `home/widgets/card_scaffold.dart`
- **Ne yapıldı:** `CardScaffold` ortak iskelet (başlık + gövde, yetmezse scroll). Grafik kartları hücre yüksekliğini dolduruyor. `HourActivityChart` yeniden yazıldı. heatmap/rhythm'e dikey+yatay scroll. Dar ende ellipsis koruması. 45 render testi eklendi.
- **Dokunma:** `classroom/*`, `dashboard_card.dart`, `dashboard_providers.dart`

---

## 📋 Geçmiş (özet tablo)

| Tarih | Ne | Önemli Notlar |
|---|---|---|
| Tem 10 | 6×N 2D matris refactor (R1–R8) | `grid_reflow.dart` occupancy motoru, `DashboardCardConfig(x,y,w,h)`, eski format göçü |
| Tem 10 | Çoklu grup mimarisi (§1: 1A–1E) | `study_sessions.group_id` DROP, `group_members.left_at` soft-delete, migration 0008–0011, `can_see_user_sessions` RPC, "Eski Grup Üyesi" etiketi |
| Haz 26 | Auth refresh token düzeltmesi | Bozulmuş refresh token'da yerel oturum temizlenip giriş ekranına dönülüyor |
| Haz 22 | Tema/renk paleti (FAZ 3.12) | 5 palet (Lacivert/Mor/Zümrüt/Gün Batımı/Okyanus), koyu/açık/sistem, `AppTheme` palet-parametreli |
| Haz 22 | Zengin & etkileşimli UI (FAZ 3.11) | 19 dashboard kart türü, etkileşimli donut, grup hedefi (0006 migration), çizgi grafik, ısı haritası, scatter, rekorlar, renk-kodlu tablo, yerinde düzenleme modu |
| Haz 22 | İstatistik zenginleştirme (FAZ 3.10) | Donut grafik, sınıf günlük trend çubuğu |
| Haz 21 | Çalışma kayıtları iyileştirme (FAZ 3.9) | Geçmiş günler katlanabilir özet, saat aralığı gösterimi |
| Haz 21 | Ana Sayfa esnek dashboard (FAZ 3.8) | 4 sekme navigasyon, kart ekle/çıkar/sürükle, `dashboardLayoutProvider` kalıcı |
| Haz 21 | Profesyonel sayaç (FAZ 3.7) | Dropdown ders seçici, tam ekran odak modu, 3 saat stili (sade/halka/renk geçişi) |
| Haz 21 | Çoklu sınıf + admin (FAZ 3.6) | Sınıf değiştirici, 3-nokta menü, admin işlemleri, aktif sınıf kalıcılığı, 0004 migration |
| Haz 21 | Dersler + günlük hedef + seri (FAZ 3.5) | `subjects` tablo, `daily_goal_minutes`, `currentStreak` saf hesaplama, 0003+0005 migration |
| Haz 21 | İstatistikler (FAZ 3) | Günlük/haftalık/aylık, hafta içi/sonu, serbest tarih aralığı, fl_chart grafikler, leaderboard |
| Haz 21 | Canlı çalışma (FAZ 2) | Presence (studying/offline), sayaç başlat/durdur, canlı üye listesi, manuel giriş |
| Haz 21 | Supabase entegrasyonu | 0001 migration, çift repo (in_memory + supabase), `env.json`, oturum kalıcılığı |
| Haz 21 | Hesap + sınıf (FAZ 1) | Auth (e-posta/şifre), profil (ad + avatar), sınıf oluştur/katıl, davet kodu |
| Haz 20 | Planlama + ortam kurulumu (FAZ 0) | Flutter 3.44, Android SDK 36, proje iskeleti, dokümanlar |

---

## Önemli Mimari Kararlar

| Karar | Detay |
|---|---|
| `study_sessions.group_id` kaldırıldı | Oturum yalnızca kullanıcıya ait. Grup istatistiği `study_sessions ⨝ group_members` join'iyle hesaplanır |
| Soft-delete (group_members) | `left_at timestamptz` — üye çıkınca satır silinmez, `left_at=now()` yazılır. Geçmiş veri korunur |
| Presence `group_id` korunuyor | `presence` tablosundaki `group_id` kaldırılMADI — dokunma |
| Mola butonu kaldırıldı | Kullanıcı kararı: sade Başlat/Durdur. Durum: çalışıyor / çevrimdışı |
| Dashboard 6 sütun matris | `kGridColumns = 6`, `rowH = cellW` (kare hücre), `Stack + AnimatedPositioned` |
| İstatistikler türetilir | `study_sessions`'tan hesaplanır, ayrı istatistik tablosu yok |
| Avatar public bucket | `avatars` bucket public, URL'e `?v=<ts>` cache kırıcı |
| Re-join upsert | PK `(group_id,user_id)` → ayrılıp dönen üye için upsert (`left_at=null, joined_at=now()`) |
