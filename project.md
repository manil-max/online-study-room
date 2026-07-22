# PROJECT.md — Online Çalışma Sınıfı (Teknik Referans)

> Bu doküman projenin **teknik referans kaynağıdır**. Mimari, veri modeli, güvenlik ve
> alınan kararları içerir. Özellik istekleri ve yapılacaklar → `backlog.md`.
> İlerleme takibi → `progress.md`. Ajan kuralları → `.agents/AGENTS.md`.
> **Kalite programı (vizyon + teknik + kalite kapıları) → `docs/KALITE-PROGRAMI.md` (kanonik).**
>
> Son güncelleme: 2026-07-22

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
| Windows masaüstü | Adaptif desktop shell + ayrı always-on-top Compact Focus | Mobil EXE kopyası değil; klavye/fare/pencere ürünü |
| Yerel veri / cache | **Drift (SQLite)** | Pro hedef: sorgulanabilir sağlam yerel depo (KALITE-PROGRAMI §5.1) |
| Arka plan yürütme | **flutter_foreground_task + Kotlin foreground service** | Canlı sayaç/widget app kapalıyken (v8) |
| Hata izleme | **Sentry** | Crash + performans (pro) |
| Sunucu mantığı | **Supabase Edge Functions + pg_cron** | Server-authoritative XP/başarı, tutarlı hesap |

> Pro seviye tam yığın denetimi (tut/ekle/değiştir), platform sınırları ve AI katmanı: **`docs/KALITE-PROGRAMI.md` §5–6.**

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

### Ortam topolojisi

| Kanal | Android kimliği | Backend | Veri |
|---|---|---|---|
| Local/debug | geliştirme kimliği | Supabase CLI + Docker | Seed/sentetik |
| Beta | ayrı `.beta` application id + Beta adı/işareti | Ayrı staging Supabase | Test hesapları |
| Stable | kalıcı production application id/imza | Production Supabase | Gerçek kullanıcı |

Tek kaynak kod ve tek `supabase/migrations/` zinciri kullanılır. Beta/stable farkı flavor/env/release manifestinden gelir; beta hiçbir koşulda production backend'e bağlanmaz. Ayrıntı: `docs/ORTAM-MIGRATION-YONETISIMI.md`.

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
- **feedback_tickets** — `id`, `user_id`, `kind`, `subject`, `message`, `status`, zaman damgaları;
  WP-32 ile isteğe bağlı `attachment_path` eklenmesi planlandı. Ekler public URL değil,
  private `feedback-attachments` Storage bucket'ındaki dosya yoluyla ilişkilendirilir.
- **admin_audit_log** — WP-33 ile planlandı; süper-admin işlemlerinin yapanı, hedefi,
  türü, gerekçesi, sonucu ve zamanı için append-only denetim kaydı.
- **admin_announcements / announcement_reads** — WP-34 ile planlandı; tüm kullanıcılara
  veya belirli gruba uygulama içi duyuru ve okundu bilgisi. İlk fazda push/e-posta yoktur.
- **user_progression / achievement_progress** — WP-35 ile planlandı; XP, taç/rütbe,
  kuşanılmış rozetler ve çok kademeli başarı ilerlemesi. Görünür profil vitrini yalnız ortak
  aktif grup üyelerine açılır.
- **study_reminders** — WP-36 ile planlandı; cihazda yerel, tekrar eden çalışma
  hatırlatıcıları ve sessiz saat tercihleri. İlk fazda hesaplar arası sync veya FCM yoktur.

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
| Supabase production | Mevcut plana bağlı | Gerçek kullanıcı ortamı |
| Supabase staging | Free planda ikinci aktif proje kotası varsa ücretsiz; ücretli organizasyonda güncel fiyat yeniden kontrol edilir | Beta/test ortamı; inactivity pause kabul edilir |
| Local Supabase | Ücretsiz | Docker + pinli Supabase CLI; geliştirme/reset burada |
| Android dağıtımı | Ücretsiz | APK sideload + GitHub Releases |
| Windows dağıtımı | Ücretsiz | Stable hedefi Microsoft Store MSIX; Store imzalama ve güncelleme dağıtımını yönetir. GitHub MSIX/ZIP yalnız QA/beta/portable'dır. |
| Windows güncellemesi | Ücretsiz | Store stable güncellemesini yönetir; GitHub updater Store paketinde kapalı kalır. |

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
| 0007 | `group_daily_totals.sql` | İlk grup günlük toplam RPC'si |
| 0008 | `membership_lifecycle.sql` | `group_members.left_at` + `is_group_member` güncelleme + UPDATE politikaları |
| 0009 | `session_visibility.sql` | `can_see_user_sessions` helper |
| 0010 | `drop_session_group_id.sql` | `study_sessions.group_id` DROP (sıra: politika → index → kolon) |
| 0011 | `group_daily_totals_v2.sql` | RPC v2 (üyelik pencereli join) |
| 0012 | `group_join_hardening.sql` | Grup katılımı/RLS sertleştirmesi |
| 0013 | `presence_membership_hardening.sql` | Presence yazma RLS'i |
| 0014 | `profile_animal.sql` | Profil hayvanı alanı |
| 0015 | `class_chat.sql` | Sınıf mesajlaşma tablosu ve politikaları |
| 0016 | `nudges.sql` | Dürtme verisi ve erişim politikaları |
| 0017 | `gamification_profiles.sql` | Oyunlaştırma profil alanları |
| 0018 | `admin_feedback.sql` | Süper-admin, geri bildirim ticket'ları ve admin RPC'leri |
| 0019 | `feedback_attachments.sql` | Private geri bildirim görsel eki + Storage RLS |
| 0020 | `super_admin_operations.sql` | Admin audit ve sunucu-güvenli kullanıcı işlemleri |
| 0021 | `admin_operations.sql` | Grup moderasyonu, duyurular ve iç rapor notları |
| 0022 | `social_profile_progression.sql` | XP/taç, aşamalı başarı ve profil vitrini RLS'i |
| 0023 | `notification_center.sql` | Bildirim merkezi tercih/veri desteği |
| 0024–0028 | `achievements_*.sql`, `crown_*.sql`, `xp_reset_*.sql` | Server-authoritative XP ledger, sosyal metrik, taç kademeleri ve genel açılış reset'i |
| 0029 | `admin_panel_fixes.sql` | Admin paneli veri/işlem düzeltmeleri |
| 0030 | `monthly_report_infrastructure.sql` | Aylık rapor işleri ve cron altyapısı |
| 0031 | `user_study_summary.sql` | Kullanıcı çalışma özeti |
| 0032 | `public_group_discovery.sql` | Güvenli public grup keşif/katılım RPC ve RLS'i |
| 0033 | `study_hour_xp_50.sql` | Saat başına 50 XP olay sözleşmesi |
| 0034 | `group_members_active_index.sql` | Aktif grup üyeliği partial index'i |
| 0035 | `cron_report_url_fix.sql` | Rapor cron URL/secret sözleşmesi |
| 0036 | `security_hardening.sql` | Edge/RPC/profil erişimi güvenlik sertleştirmesi |

> **Deploy gerçeği (2026-07-20):** Yerelde `0001–0063` vardır. Kullanıcı production'da `0062` dahil SQL'lerin “Success” döndüğünü bildirdi; bu CLI history, fonksiyon gövdesi, cron veya veri invariant kanıtı değildir. `0063` production'a uygulanmamıştır ve kurtarma freeze'i boyunca uygulanmaz. WP-225/226, gerçek remote şema ile `supabase_migrations.schema_migrations` geçmişini uzlaştıracaktır. Yeni migration mevcut en yüksek yerel numaradan devam eder; herhangi bir remote'a uygulanmış dosya geriye dönük değiştirilmez.

---

## 9. Karar Günlüğü

| Tarih | Karar |
|---|---|
| **Tem 20** | **Stable/beta ve backend izolasyonu.** Beta ayrı staging Supabase'e, stable production Supabase'e bağlanır; local geliştirme Docker/CLI üzerindedir. Tek migration zinciri local→staging→production terfi eder. Production deploy; staging+cihaz+soak+backup+dry-run ve somut kullanıcı GO olmadan yapılmaz. Mevcut `0063` freeze altındadır; kurtarma WP-225–232 ile yürür. |
| **Tem 20** | **Süre kaynağı ürün sözleşmesi.** Manuel giriş, kronometre, geri sayım, Pomodoro ve native/widget sayaç istatistik/XP/başarım/grup açısından eşittir. “Bu hafta” takvim haftası olarak açık etiketlenir; ayrıca “Son 7 Gün” sağlanır. Taç eşikleri `[0,20k,75k,200k,500k,1M]` kanondur. |
| **Tem 22** | **Windows stable dağıtım kararı.** Microsoft Store MSIX ana kanaldır; Store paketi Microsoft tarafından imzalanır ve güncellenir. Public Store yayını öncesinde Windows Sandbox/VM yerel QA ve seçili Microsoft hesaplarıyla Private Audience pilotu zorunludur. GitHub Releases beta/QA amacıyla korunur; public Store paketi GitHub'dan kendi kendine güncelleme denemez. |
| **Tem 17** | **Google Play production programı WP-110–124 olarak planlandı.** Play build'i GitHub APK self-update/`REQUEST_INSTALL_PACKAGES` davranışından ayrılır; hesap silme, UGC güvenliği, yasal metinler, kısıtlı izin uygunluğu, Data Safety, backend deploy, target API 36 AAB ve gerçek cihaz/track kanıtları tamamlanmadan production GO verilmez. Her submission/rollout ayrıca açık kullanıcı onayı ister. |
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
| Tem 11 | V5 yönü: Odak Kampı, varsayılan Saat uygulamasının pratik yerini alabilecek bir “Clock Center” fazına genişletilecek. İlk dilim yatay StandBy/focus görünümü ve yerel alarm/çoklu timer temeli; sleep/snore gibi hassas özellikler açık izinli ayrı faza bırakılır. |
| Tem 11 | Windows sürümü yalnız mobil layout'un EXE build'i olarak kalmayacak; geniş ekranda sol navigation rail/sidebar ve masaüstü odaklı responsive düzen hedeflenecek. Dağıtım/installer/pencere state'i ayrı desktop polish fazında ele alınacak. |
| Tem 11 | Sürüm notları tek kaynak prensibiyle yönetilecek: GitHub release, repo MD/JSON, uygulama içi tek seferlik “Yenilikler” pop-up'ı ve Ayarlar’daki geçmiş notlar aynı sürüm verisine dayanacak. Update bildirimi ilk fazda local/best-effort olacak; gerçek push ayrı karar ister. |
| Tem 11 | Geri bildirim görselleri yalnız private Storage bucket'ta tutulacak; ticket'ta public URL değil dosya yolu bulunacak, erişim RLS ve kısa ömürlü imzalı URL ile sağlanacak. |
| Tem 11 | Süper-adminin Auth kullanıcı yönetimi gerektiren işlemleri yalnız Edge Function üzerinden yapılır; service-role anahtarı Flutter istemcisine veya repoya konmaz. Şifre yalnız reset e-postasıyla kullanıcı tarafından belirlenir; tüm kritik işlemler gerekçe ve denetim kaydı üretir. |
| Tem 11 | WP-26 ile tema yalnız primary/accent seçimi olmayacak; tüm uygulama yüzeyleri ThemeExtension renk tokenlarıyla yönetilecek. Sabit gri/surface renkleri ana UI'dan temizlenecek, özel çizim ve semantik renkler belgeli istisna kalacak. |
| Tem 11 | Ana navigasyon beş sekmeye genişletilecek: Ana Sayfa / Saat / Gruplar / İstatistikler / Profil. Ana Sayfa günlük kişisel çalışma alanıdır; Saat, grup, analiz ve profil verilerinin asıl evi kendi sekmeleridir. |
| Tem 11 | Sosyal profil/başarı sistemi XP-taç, kademeli rozetler ve ortak grup üyeleriyle sınırlı profil vitrini kullanır. Kritik XP/başarı ilerlemesi istemciye güvenilmeden hesaplanır; seri efekti hareket azaltma tercihini destekler. |
| **Tem 12** | **Kalite pivotu.** Amaç "çalışsın" değil birinci sınıf kalite. İki "tamamlandı" tanımından yalnız (2) geçerli; 8-aşamalı iş merdiveni + kanıt etiketleri benimsendi. Klasik özellik yol haritası yerine **kalite programı** (`docs/KALITE-PROGRAMI.md`). |
| **Tem 12** | **Server-authoritative ilerleme.** XP/başarı istemcide hesaplanıp yazılamaz; append-only XP ledger + idempotent achievement event + benzersiz ödül anahtarı + Edge Function/pg_cron. `0022`'nin geniş açık RLS'i düzeltilecek: sosyal profil yalnız ortak aktif grup üyesine görünür, e-posta gizli, adminlik erişimi otomatik genişletmez. |
| **Tem 12** | **Çok-ajanlı çakışma protokolü.** Paralel 3–4 ajan: her ajan görevi alır almaz `progress.md` Aktif Çalışma Kaydı'na SAHİP yol/ortak yüzeyini işler; başlamadan tüm kaydı okuyup çakışma ön-kontrolü yapar; risk varsa başlamaz, kullanıcıyı gerekçeyle uyarır. Saat/Tema/Başarım aynı anda açılmaz. |
| **Tem 12** | **Platform sınırları belgelendi.** Bildirim görünümü OEM'e bağlı; home widget < 15 dk periyodik güncelleme garanti değil → canlı süre native `Chronometer`, state receiver/service, stats widget'ları olay bazlı. Native temel (foreground service, exact alarm, boot receiver) v8/Saat'te eklenip cihazda kanıtlanır. |
| **Tem 12** | **WP-39 iptal edildi.** CI/PR auto-merge kurulmayacak; kalite kapısı her WP'nin yerel `analyze` + `test` doğrulaması ve gerçek cihaz QA'sıdır. |
| **Tem 13** | **Windows ürün yönü.** Flutter/Riverpod/Supabase çekirdeği korunur; Windows'ta adaptif sol rail, desktop içerik iskeleti, klavye/fare/Narrator/high-contrast ve ayrı Compact Focus yüzeyi kullanılır. Stable dağıtım önerisi MSIX/Microsoft Store; imza/identity kalıcıdır. Ayrıntı: `docs/WINDOWS-URUN-PLANI.md`, WP-27/28. |
| **Tem 13** | **Adaptif dashboard yoğunluğu.** Sabit 6×N yerine cihaz-yerel 6/8/12/16 sütun profilleri planlandı. Layout Supabase ile senkronlanmaz; telefon/tablet/Windows profilleri birbirini bozmaz. Yoğunluk başına ayrı profil, geri dönüşte yuvarlama drift'ini önler. Sıra: WP-52 grid motoru → WP-53 gerçek Windows ekran-içi IA → WP-28 paketleme. |
| **Tem 14** | **Küresel dil varsayılanı.** Flutter'ın resmî ARB/l10n altyapısında şablon dil `en`, ikinci dil `tr` olacaktır. Açılış resolver'ı yalnız sistem dil kodu `tr` ise Türkçe seçer; diğer tüm diller İngilizceye düşer. Uygulama kapalıyken çalışan Android yüzeyleri ARB okuyamayacağından Android `values`/`values-tr` kaynaklarıyla aynı EN/TR sözleşmesini izler; dil tercihi kullanıcı verisine yazılmaz. |
| **Tem 15** | **Global grup erişim modeli.** Yeni gruplar varsayılan `private`; yalnız davet kodu ile katılım sürer. Adminin açtığı `public` gruplar güvenli özet RPC’siyle keşfedilir ve sunucu tarafında atomik kapasite kontrolüyle katılınır. Başlangıç üye sınırı Clash tarzı 50’dir. Public keşif, davet kodunu, üye listesini, çalışma/presence verisini veya sosyal profili üyelik öncesinde açmaz; bunlar mevcut ortak-aktif-üyelik RLS’i altında kalır. |
| **Tem 19** | **Başarım iyileştirme v3.1 plan kararı.** Pending ödül ayrı `achievement_rewards` tablosunda, XP ledger literal append-only kalır; auto→pending geçişi claim-capable client sonrası hesap-bazlı capability ile yapılır. `study_sessions.group_id` geri getirilmez: XP'ye sayılan canlı çalışma server-issued run/segment ve immutable tek grup context ile doğrulanır; direct client `source='live'` kanıt sayılmaz. Server verified-session expansion WP-216, Dart/native sayaç köprüsü ve shadow saha ölçümü WP-220'dir. Flutter kapalı saf-native start güvenli server tokenı alamadığı için stat-only kalır; native'a auth token taşınmaz. Saat başı 50 XP ambient kalır; verified-only kesişi ancak ≥7 günlük benimseme/başarı eşikleri sonrası WP-219'da tek seferde açılır, post-cut unverified XP istisnası yoktur. Manual/unverified süre normal istatistikte kalır. Gerçek/secret progress self-only projection'dadır. Kayıp tarihsel grup bağlamı eksiksiz retro sayılmaz; yalnız konservatif proxy + audit/dry-run kullanılır. **Ürün kararı: Kusursuz Ay 28/30 kuralıdır; sabit eşik 28 İstanbul hedef günüdür.** WP-208 server+Dart evaluator'ı bu kurala geçirilir; önceki append-only XP/rozet geri alınmaz. Grup avatarı private bucket + RLS + signed URL olarak planlanır. |
