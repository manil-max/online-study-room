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
- **Son WP numarası:** 36
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

**Lane şablonu** (doldurulacak alanlar): Durum · Faz/WP · Aşama (8-merdiven) · SAHİP yollar · Ortak/riskli yüzey · Dal · Başlangıç · Son güncelleme · Not.

### Gemini Lane
- **Durum:** [x] Boşta
- **Faz/WP:** — · **Aşama:** — · **SAHİP yollar:** — · **Ortak/riskli yüzey:** — · **Dal:** — · **Son güncelleme:** 2026-07-12

### Claude Lane
- **Durum:** [x] Boşta
- **Faz/WP:** — · **Aşama:** — · **SAHİP yollar:** — · **Ortak/riskli yüzey:** — · **Dal:** — · **Son güncelleme:** 2026-07-12

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** — · **Aşama:** — · **SAHİP yollar:** — · **Ortak/riskli yüzey:** — · **Dal:** — · **Son güncelleme:** 2026-07-12

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
| WP-27 | Bekliyor | Windows desktop shell ve responsive layout | — |
| WP-28 | Bekliyor | Windows dağıtım, installer ve desktop polish | WP-27 |

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

### Son Teslim Notları

- **WP-36:** Ayarlar'daki "Ana Sayfa" grubu kaldırıldı (sayaç anahtarı "Gruplar" grubuna taşındı); dürtme, hatırlatıcı, alarm/timer, duyuru, güncelleme ve sessiz saatleri tek yerden yöneten `NotificationCenterScreen` eklendi. `0023_notification_center.sql` (study_reminders + announcement_reads, RLS owner-only), çift `NotificationRepository`, yerel hatırlatıcı planlama servisi ve sessiz-saat mantığı; dürtme dinleyicisi ve güncelleme bildirimi tercihlere saygı gösterir. Gruplar/İstatistik sekmeleri zaten dolu doğrulandı.

- **WP-26:** Hazır paletler, kalıcı tema ayarları ve üç özel renk slotu eklendi (`bd5a906`).
- **WP-24:** Yerel alarm, preset, etiketli çoklu timer, pause/resume/reset/delete ve alarm bildirim kanalı eklendi (`c47042d`).
- **WP-23:** Clock Center, yatay StandBy görünümü ve ana shell'den Saat erişimi eklendi (`8618d86`).
- **WP-31:** Bağlı e-posta, e-posta değiştirme, güvenli çıkış ve recovery akışı ile `AccountSettingsScreen`/`RecoveryScreen` oluşturuldu.
- **WP-32:** `0019_feedback_attachments.sql`, görsel seçimi ve admin önizlemesi eklendi.
- **WP-33:** Süper-admin Edge function ve RLS logları oluşturuldu, arayüz testleri düzenlendi.
- **WP-34:** Süper-Admin çoklu sekme (Dashboard, Users, Groups, Reports, Announcements, Audit Log), duyurular ve grup moderasyonu eklendi.
- **WP-35:** Sosyal Profil vitrini (SocialProfileDialog), Başarı Yolculuğu, 60+ kademeli başarı kural motoru, güvenli Supabase upsert/senkronizasyon ve `0022` migration düzeltmesi eklendi.
