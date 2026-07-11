# progress.md — İlerleme Takibi

> Son güncelleme: 2026-07-12
> Sistem: İş Paketi (WP) tabanlı. Planlama: `.agents/skills/planner/SKILL.md` · Uygulama: `.agents/skills/worker/SKILL.md`.

---

## Proje Gerçekleri (ajan referansı)

- **Framework:** Flutter ^3.12 · Riverpod 3.3 · Supabase 2.15 · fl_chart
- **Uygulama kökü:** `app/` — Flutter komutları yalnız burada çalışır.
- **Repo katmanı çift:** Her arayüz `supabase/` ve `in_memory/` repository'leriyle desteklenir.
- **Migration'lar:** `supabase/migrations/` — yerelde `0001–0021` vardır. Canlı şemada `0001–0019` etkileri doğrulandı; `0020–0021`, aktif admin çalışmasının parçasıdır ve tamamlanmadan üretime uygulanmaz.
- **Gün sınırı:** `Europe/Istanbul`
- **RLS helper'ları:** `is_group_member(gid)`, `can_see_user_sessions(target)`, `is_group_admin(gid)`, `is_super_admin()`
- **Dashboard:** 6 sütunlu 2D matris, 19 kart türü, `grid_reflow.dart` motoru.
- **Tema:** Hazır paletler + özel palet slotları; görünür tüm yüzeyler palette bağlanmalıdır, sabit gri renk eklenmez.
- **Navigasyon hedefi:** Ana Sayfa / Saat / Gruplar / İstatistikler / Profil. Ana Sayfa günlük kullanım alanıdır; diğer alanların verisi kendi sekmelerinde eksiksiz bulunur.
- **Release:** Stable/Beta kanalı GitHub Releases ile çalışır.
- **Son WP numarası:** 36
- **Geliştirme ortamı:**
  - Proje: `C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room`
  - Flutter: `C:\src\flutter` · Android SDK: `C:\Android\Sdk`
  - JDK: `C:\Program Files\Android\Android Studio\jbr`
  - Web test: `flutter run -d chrome --web-port=5005 --dart-define-from-file=env.json`
  - GitHub: `manil-max/online-study-room` (public)

---

## ⚡ Aktif İş Paketleri

> Bu bölüm yalnız şu anda kodlanan WP'leri içerir. Bir WP tamamlanınca kartı buradan ve planlananlar listesinden kaldırılır, doğrudan **Tamamlanan İş Paketleri** bölümüne tek kez eklenir.

### Gemini Lane
- **Sorumlu:** Gemini
- **Durum:** [~] Aktif — WP-35 uygulanacak
- **Aktif WP:** WP-35
- **Kapsam:** Sosyal profil, XP, taç ve aşamalı başarılar 🏆.
- **Not:** `0020_super_admin_operations.sql` ve `0021_admin_operations.sql` bu işin parçasıdır; tamamlanma ve doğrulama olmadan üretime uygulanmaz.

### Claude Lane

- **Sorumlu:** Claude
- **Durum:** [x] Boşta
- **Aktif WP:** —

### Codex Lane

- **Sorumlu:** Codex
- **Durum:** [x] Boşta
- **Aktif WP:** —

---

## Planlanan İş Paketleri

> Burada yalnız başlanmamış işler bulunur. Sıra, bağımlılık ve ürün önceliğine göre korunur.

| WP | Durum | Kısa kapsam | Bağımlılık |
|---|---|---|---|
| WP-27 | Bekliyor | Windows desktop shell ve responsive layout | — |
| WP-28 | Bekliyor | Windows dağıtım, installer ve desktop polish | WP-27 |
| WP-36 | Bekliyor | Beş sekmeli bilgi mimarisi, dolu Gruplar/İstatistikler ve Bildirim Merkezi | WP-34, WP-35 |

### WP-27: Windows Desktop Shell ve Responsive Layout

- **Kapsam:** Windows'ta masaüstüne uygun pencere davranışı, geniş ekran düzeni ve input/klavye iyileştirmeleri.
- **Kabul:** Uygulama farklı masaüstü ölçülerinde taşmadan, mobil akışı bozmadan kullanılabilir.

### WP-28: Windows Dağıtım ve Desktop Polish

- **Kapsam:** Installer, dağıtım akışı, güncelleme/çökme mesajları ve masaüstü son kalite kontrolleri.
- **Kabul:** Windows kullanıcıları kurulabilir, güncellenebilir ve desteklenebilir bir paket alır.

### WP-34: Süper-Admin Paneli, Grup Moderasyonu ve Duyurular 🧭
- **Durum:** [x] Tamamlandı — Gemini
- **Kapsam:** Yönetim ekranında Kullanıcılar, Gruplar, Raporlar, Duyurular ve Denetim sekmeleri; hedefli uygulama içi duyuru, grup moderasyonu ve rapor iç notları.
- **SAHİP dosyalar:** `0021_admin_operations.sql`, `admin-operations` Edge Function, admin model/repository/provider/UI/test dosyaları.
- **Kabul:** Kritik işlemler çift onay + gerekçe + audit olmadan çalışmaz; normal kullanıcı yalnız kendi duyurusunu/raporunu görür.
- **Model seviyesi:** Yüksek — GPT-5.6 Terra high / Claude Sonnet 5 high / Gemini 3.1 Pro high

### WP-35: Sosyal Profil 2.0 + Başarı Yolculuğu 🏆
- **Durum:** [~] Uygulanıyor — Gemini
- **Kapsam:** 60+ aşamalı çalışma/odak/sosyal/eğlenceli başarı; XP, taç rütbeleri, seçilebilir 3 rozet, seri alev efekti ve grup üyesine dokununca açılan sosyal profil vitrini.
- **Veri:** `0022_social_profile_progression.sql` planlanır; yalnız WP başladığında oluşturulur.
- **Kabul:** Başarılar kademe ve ilerleme gösterir; XP taç seviyesine dönüşür; ortak gruptaki üyeler izinli profil, rozet ve seri bilgisini görür.

### WP-36: Beş Sekmeli Bilgi Mimarisi + Bildirim Merkezi

- **Kapsam:** Ana Sayfa / Saat / Gruplar / İstatistikler / Profil; Ana Sayfa'nın yalnız günlük kişisel alan kalması; Ayarlar'daki Ana Sayfa grubunun kaldırılması; hatırlatıcı, alarm/timer, dürtme, duyuru, güncelleme ve sessiz saatleri tek Bildirim Merkezi'nde toplama.
- **Veri:** `0023_notification_center.sql` planlanır; yalnız WP başladığında oluşturulur.
- **Kabul:** Beş alan net ayrışır, Gruplar ve İstatistikler boş kalmaz; bildirim türleri tek yerden yönetilir ve cihaz/izin sınırları açıkça görünür.

---

## Tamamlanan İş Paketleri

> Biten her WP yalnız bu başlık altında tutulur. Buradaki kartlar tekrar aktif veya planlanan iş olarak yazılmaz.

| WP | Tamamlanan kapsam |
|---|---|
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

### Son Teslim Notları

- **WP-26:** Hazır paletler, kalıcı tema ayarları ve üç özel renk slotu eklendi (`bd5a906`).
- **WP-24:** Yerel alarm, preset, etiketli çoklu timer, pause/resume/reset/delete ve alarm bildirim kanalı eklendi (`c47042d`).
- **WP-23:** Clock Center, yatay StandBy görünümü ve ana shell'den Saat erişimi eklendi (`8618d86`).
- **WP-31:** Bağlı e-posta, e-posta değiştirme, güvenli çıkış ve recovery akışı ile `AccountSettingsScreen`/`RecoveryScreen` oluşturuldu.
- **WP-32:** `0019_feedback_attachments.sql`, görsel seçimi ve admin önizlemesi eklendi.
- **WP-33:** Yetkili kullanıcı işlemlerinin güvenli süper-admin temeli tamamlandı.
