# PROJECT.md — Online Çalışma Sınıfı (Teknik Referans)

> Bu doküman projenin **teknik referans kaynağıdır**. Mimari, veri modeli, güvenlik ve
> alınan kararları içerir. Özellik istekleri ve yapılacaklar → `backlog.md`.
> İlerleme takibi → `progress.md`. Ajan kuralları → `.agents/AGENTS.md`.
>
> Son güncelleme: 2026-07-10

---

## 1. Vizyon ve Amaç

Küçük bir grubun (ör. 3–5 kişi) birlikte kullanacağı, **YPT (Yeolpumta) benzeri ortak online
çalışma uygulaması**. Kullanıcılar aynı "sınıfa" katılır, birbirlerinin **canlı çalışma
durumunu** görür, çalışma sürelerini takip eder ve **detaylı istatistiklerle** kıyaslar.

**Temel motivasyon:** Birlikte çalışma hissi, motivasyon ve sağlıklı dayanışma/rekabet.

**Kapsam sınırı:** Kapalı, özel bir kullanıcı grubu için. Büyük ölçeklenebilirlik öncelik
değildir; sadelik, güvenilirlik ve iyi kullanıcı deneyimi önceliklidir.

---

## 2. Hedef Kullanıcılar ve Platformlar

**Kullanıcılar:** Küçük, sabit bir grup.

**Platformlar:**
- **Android** — telefon ve tablet (birincil mobil hedef)
- **Windows** — masaüstü
- **iOS** — kapsam dışı

---

## 3. Teknoloji Yığını

| Katman | Seçim | Gerekçe |
|---|---|---|
| Uygulama (UI) | **Flutter (Dart)** | Tek kod tabanı → Android + Windows |
| Backend | **Supabase (Free tier)** | Auth + Postgres + Realtime + Storage |
| State management | **Riverpod 3.3** | Test edilebilir, modern |
| Grafikler | **fl_chart** | Esnek grafik kütüphanesi |
| Android widget | **home_widget** paketi | Native Android widget'ını Flutter'dan beslemek |
| Windows widget | Always-on-top mini Flutter penceresi | Basit ve kontrollü |
| Yerel veri / cache | ❓ **Drift** veya **Hive** | Çevrimdışı destek (ileride) |

---

## 4. Sistem Mimarisi

```
┌─────────────────────────────────────────────────────────┐
│  Flutter Uygulaması (Android telefon/tablet · Windows)    │
│  • UI katmanı (sınıf · profil · istatistik · canlı)       │
│  • Riverpod ile durum yönetimi                            │
│  • Yerel cache (çevrimdışı dayanıklılık)                  │
│  • Widget besleme (home_widget / Windows mini pencere)    │
└──────────────────┬────────────────────────────────────────┘
                   │ HTTPS (REST) + WebSocket (Realtime)
┌──────────────────▼────────────────────────────────────────┐
│  Supabase (Backend-as-a-Service)                          │
│  • Auth        → e-posta/şifre giriş                      │
│  • Postgres    → kullanıcı, grup, oturum, ders verisi     │
│  • Realtime    → canlı "kim çalışıyor" (presence)         │
│  • Storage     → profil fotoğrafları                      │
│  • RLS         → satır seviyesi güvenlik (veri izolasyonu)│
└────────────────────────────────────────────────────────────┘
```

**Katmanlı uygulama yapısı:**
- **Presentation** (UI / ekranlar / widget'lar)
- **Application/State** (Riverpod provider'ları, use-case'ler)
- **Data** (repository'ler, Supabase client, modeller, yerel cache)

---

## 5. Veri Modeli

- **profiles** — `id` (auth user), `display_name`, `avatar_url`, `daily_goal_minutes`
  (varsayılan 360), `created_at`
- **groups** (sınıf) — `id`, `name`, `invite_code`, `created_by`, `daily_goal_minutes`
  (varsayılan 360), `created_at`
- **group_members** — `group_id`, `user_id`, `role` (admin/member), `joined_at`,
  `left_at` (nullable — soft-delete)
- **subjects** (ders) — `id`, `user_id`, `name`, `color`
- **study_sessions** — `id`, `user_id`, `subject_id?`, `start_time`, `end_time`,
  `duration_seconds`, `source` (`live`|`manual`), `date`
  > ⚠️ `group_id` **kaldırıldı** (migration 0010). Grup istatistiği `study_sessions ⨝ group_members` join'iyle hesaplanır.
- **presence** (Realtime) — `user_id`, `group_id`, `status` (`studying`/`break`/`offline`),
  `current_subject_id?`, `started_at`
  > ⚠️ Presence'taki `group_id` **korunuyor** — dokunma.

**İstatistikler ayrı tabloda tutulmaz**; `study_sessions` üzerinden sorgu/agregasyonla üretilir.

---

## 6. Güvenlik

- **RLS (Row Level Security) zorunlu:** Her kullanıcı yalnızca kendi grubunun verisine erişir.
- **SECURITY DEFINER helper'ları:**
  - `is_group_member(gid)` — aktif üyelik kontrolü (`left_at is null`)
  - `can_see_user_sessions(target)` — oturum görünürlüğü (ortak grup üyeliği)
  - `is_group_admin(gid)` — admin kontrolü (`groups.created_by`)
- **Anahtar yönetimi:** `anon key` istemcide, `service_role key` **asla** istemciye/repoya.
- **Gizli değerler** `--dart-define-from-file=env.json` ile, repoya commit edilmez.

---

## 7. Maliyet ve Dağıtım

**Hedef: 0 TL.**

| Kalem | Maliyet | Not |
|---|---|---|
| Flutter SDK | Ücretsiz | Açık kaynak |
| Supabase Free tier | Ücretsiz | Küçük grup için yeter |
| Android dağıtımı | Ücretsiz | APK sideload + GitHub Releases |
| Windows dağıtımı | Ücretsiz | Doğrudan exe |
| Otomatik güncelleme | Ücretsiz | GitHub Releases + in-app update |

---

## 8. Migration'lar

| # | Dosya | İçerik |
|---|---|---|
| 0001 | `initial_schema.sql` | profiles, groups, group_members, subjects, study_sessions, presence + trigger + RLS + Realtime |
| 0002 | `avatars_storage.sql` | Avatars Storage bucket |
| 0003 | `subjects_realtime.sql` | Subjects Realtime publication |
| 0004 | `group_admin.sql` | Admin işlemleri RLS |
| 0005 | `daily_goal.sql` | `profiles.daily_goal_minutes` |
| 0006 | `group_goal.sql` | `groups.daily_goal_minutes` |
| 0008 | `membership_lifecycle.sql` | `group_members.left_at` + `is_group_member` güncelleme + UPDATE politikaları |
| 0009 | `session_visibility.sql` | `can_see_user_sessions` helper |
| 0010 | `drop_session_group_id.sql` | `study_sessions.group_id` DROP (sıra: politika → index → kolon) |
| 0011 | `group_daily_totals_v2.sql` | RPC v2 (üyelik pencereli join) |
| 0013 | `presence_membership_hardening.sql` | Presence yazma RLS'i |

> Not: 0007 ve 0012 atlanmış (iptal edilen/kullanılmayan migration'lar).

---

## 9. Karar Günlüğü

| Tarih | Karar |
|---|---|
| Haz 20 | Proje başlatıldı. Stack: Flutter + Supabase. Giriş: e-posta/şifre. iOS kapsam dışı. |
| Haz 21 | Avatar'lar public Supabase Storage bucket'ında. Profil çekimi başarısızsa kullanıcı dışarı atılmaz. |
| Haz 21 | Mola butonu KALDIRILDI — sade Başlat/Durdur. Durum: çalışıyor / çevrimdışı. |
| Haz 21 | 4 sekme: Ana Sayfa / Sınıflar / İstatistik / Profil. Çoklu sınıf + admin. |
| Haz 21 | Dersler (ad+renk, kişiye özel), günlük hedef, seri (türetilir). |
| Haz 21 | Dashboard tam özelleştirilebilir, sayaç varsayılan Ana Sayfa'da. |
| Haz 22 | Koyu tema varsayılan, 5 seçilebilir palet. |
| Haz 26 | Dashboard 6 sütunlu 2D matris (akış ızgarası kaldırıldı). |
| Haz 26 | `study_sessions.group_id` KALDIRILDI — oturum yalnızca kullanıcıya ait. |
| Haz 26 | Soft-delete: `group_members.left_at` (hard delete yerine). |
| Tem 10 | Kamp ateşi canlı ekran (düz liste yerine). Sayaç: kronometre + geri sayım + pomodoro. |
| Tem 11 | Android dış sayaç kontrolleri (bildirim/widget) uygulamayı öne getirmeden dayanıklı yerel komut akışına gider; Flutter açılışta bu durumu uzlaştırır. One UI dinamik panelinin görünümü sistem kontrolündedir, işlevsel kalıcı bildirim desteklenmeyen cihazlar için geri dönüştür. |
