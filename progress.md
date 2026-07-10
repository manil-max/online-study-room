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
- **Son WP numarası:** 0 (WP sistemi yeni başlıyor, ilk WP → WP-1)
- **Geliştirme ortamı:**
  - Proje: `C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room`
  - Flutter: `C:\src\flutter` · Android SDK: `C:\Android\Sdk`
  - JDK: `C:\Program Files\Android\Android Studio\jbr`
  - Web test: `flutter run -d chrome --web-port=5005 --dart-define-from-file=env.json`
  - GitHub: `manil-max/online-study-room` (public)

---

## ⚡ Aktif İş Paketleri

*(Şu an aktif WP yok. Planlayıcı ajan backlog'dan seçip buraya yazacak.)*

---

## ✅ Son Tamamlananlar (ajan bağlamı için)

> Son 5 iş. Ajan bunları okuyarak "neye dokunma, ne değişti" anlar.
> Daha eski işler aşağıdaki Geçmiş tablosuna düşer.

### Kamp Ateşi Canlı Ekran (eski 2G) — 2026-07-10 ✅
- **Değişen dosyalar:** `classroom/classroom_screen.dart`, yeni `classroom/widgets/campfire_scene.dart`
- **Ne yapıldı:** `CustomPainter` ile canlı ateş animasyonu (radial parıltı + 4 katman titreşen alev + kıvılcım parçacıkları + odun kütükleri). Çalışan üyeler ateş çevresinde sıcak halka, mola/çevrimdışı alttaki karanlık vinyet şeridinde. Avatar dokununca detay alt sayfası. Ateş çalışan sayısıyla büyür (`intensity`). Eski `_LiveMembers`/`_MemberTile` listesi kaldırıldı.
- **Dokunma:** `study_timer_card.dart`, `focus_timer_screen.dart`, `home/*`, `profile/*`
- **Test:** 2 widget testi (`campfire_scene_test.dart`), 79 test geçiyor

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
