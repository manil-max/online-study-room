# Play Data Safety — kanıta dayalı envanter (WP-119 / WP-132)

**Uygulama:** Odak Kampı (`com.manilmax.online_study_room`)  
**Tarih:** 2026-07-17  
**Amaç:** Google Play Console → App content → Data safety formunu **satır satır** doldurmak.  
**Kural:** Her iddia bir migration / tablo / RPC / istemci dosyasına dayanır. Uydurma alan yok.

**Aktarım:** Tüm sunucu trafiği HTTPS (Supabase).  
**Hesap gerekli:** Evet (e-posta/şifre Auth).  
**Çocuklara yönelik değil:** 13 yaş altı hedef kitle yok (ürün kararı / listing ile hizala).  
**Yaklaşık konum / hassas konum:** **Toplanmıyor** (kod ve şemada location API yok).

---

## 1. Özet tablo (Console satırları)

| Veri türü (Play kategorisi) | Toplanıyor mu | Paylaşılıyor mu | Amaç | Opsiyonel mi | Şifreli aktarım | Silme yolu | Kanıt |
|---|---|---|---|---|---|---|---|
| **E-posta adresi** (Kimlik) | Evet | Hayır (üçüncü taraf pazarlama yok). İşleyici: Supabase Auth | Hesap oluşturma / oturum | Hayır (hesap için zorunlu) | Evet HTTPS | Hesap silme isteği → 14g grace → hard-delete (Auth user) | `auth.users`; `0037` `request_account_deletion` |
| **Ad / görünen ad** (Kişisel bilgi) | Evet | Yalnız grup üyeleri / RLS izinli görünümler | Profil, sohbet, kamp ateşi | Hayır (profil alan) | Evet | Hard-delete ile `profiles` cascade | `profiles.display_name` (`0001`) |
| **Fotoğraf** (avatar) | Evet (kullanıcı yüklerse) | Üye görünürlüğü / public storage URL | Profil | Evet (yükleme opsiyonel) | Evet | purge-accounts avatar storage scrub + cascade | `profiles.avatar_url`; `0002_avatars_storage`; purge-accounts |
| **Kullanıcı kimliği (UUID)** | Evet | Grup/sohbet/presence satırlarında üyelere | Çekirdek özellik | Hayır | Evet | Auth delete cascade | Tüm `user_id` FK’ler |
| **Uygulama etkileşimi — çalışma oturumu** | Evet (süre, konu, zaman) | Grup üyeleri (RLS `can_see_user_sessions` vb.) | Çalışma istatistiği, başarım/XP sunucu | Hayır (özellik kullanımı) | Evet | Hesap silme hard-delete | `study_sessions` / özet tablolar; gamification ledger |
| **Uygulama etkileşimi — presence** | Evet (durum, started_at, updated_at) | Aynı grup üyeleri | Kamp ateşi canlılığı | Hayır (özellik) | Evet | Cascade / presence satırı | `presence` (`0001`) |
| **Mesajlar (UGC)** | Evet (`class_messages.body`) | Grup üyeleri | Sınıf sohbeti | Evet (yazmazsa yok) | Evet | Soft scrub `[silindi]` purge; hard-delete cascade | `0015_class_chat.sql`; purge-accounts |
| **UGC rapor içeriği** | Evet (reason, optional details ≤500, snapshot) | Super-admin moderasyon; reporter kendi satırı | Güvenlik / UGC politika | Evet (kullanıcı raporlarsa) | Evet | Hesap silme cascade; admin resolve | `ugc_reports` (`0038`); `report_ugc` RPC |
| **Engel listesi** | Evet (`user_blocks`) | Hayır (yalnız engelleyen görür) | Güvenlik / engelleme | Evet | Evet | Cascade | `user_blocks`; `block_user` / `unblock_user` (`0038`) |
| **Topluluk kuralları kabulü** | Evet (sürüm + zaman) | Hayır | UGC uyum | Rapor öncesi zorunlu | Evet | Cascade | `community_terms_acceptances` (`0038`) |
| **Geri bildirim / hata raporu (in-app)** | Evet (ticket metni, ek) | Super-admin | Destek | Evet | Evet | Ürün/admin politikası + hesap silme | feedback tabloları (önceki migration’lar) |
| **E-posta iş kuyruğu (aylık rapor)** | Evet (job satırları; opt-in) | E-posta sağlayıcı (Resend vb. — ops deploy) | Aylık çalışma raporu | Evet (`monthly_report_opt_in`) | Evet | purge iptal / abandon; hesap silme | `email_job_queue`; `profiles.monthly_report_opt_in`; `0030`/`0035` |
| **Hesap silme isteği meta** | Evet (status, purge_after, attempt) | Hayır | Yasal silme boru hattı | Kullanıcı tetikler | Evet | Cascade on Auth delete (satır gidebilir) | `account_deletion_requests` (`0037`) |
| **Çökme / performans telemetrisi** | Koşullu (Sentry) | Sentry (DSN yapılandırılmışsa) | Kararlılık | **Evet — opt-out** | Evet HTTPS | Tercihi kapat → yeni olay yok | `TelemetryPreference` default **açık**; Legal Center switch; `observability_service.dart` |
| **Cihaz veya diğer kimlikler (reklam ID vb.)** | Hayır (tasarım) | — | — | — | — | — | Reklam SDK yok |
| **Yaklaşık / hassas konum** | **Hayır** | — | — | — | — | — | Location permission / API yok |
| **Takvim / rehber / mikrofon** | Hayır (ürün kapsamı dışı) | — | — | — | — | — | Manifest’te bu amaçla eklenmez |
| **Bildirim / alarm izinleri (Android)** | İzin durumu (sistem); içerik yerel | Hayır | Alarm, sayaç, hatırlatıcı | Kullanıcı verir/geri alır | n/a yerel | İzin kapatma | Exact alarm / FGS / bildirim kanalları (ürün) |

**“Shared” anlamı:** Play formunda “üçüncü taraflarla veri paylaşımı” — burada **Supabase/Sentry hizmet sağlayıcı** işlemci (processor) olarak listelenir; reklam ağı veya veri broker’a satış **yok**.

---

## 2. Hizmet sağlayıcılar (Data processors)

| Sağlayıcı | Rol | Veri | Kanıt |
|---|---|---|---|
| **Supabase** (Auth, Postgres, Storage, Realtime, Edge) | Birincil backend | Hesap, profil, oturum, sohbet, UGC, silme kuyruğu | `supabase/migrations/*`, istemci `supabase_*` repository |
| **Sentry** | Opsiyonel crash/telemetry | Hata **türü**, senkron sayaç/breadcrumb; e-posta/token **gönderilmez** (sanitizasyon) | `app/lib/core/observability/observability_service.dart` |
| **GitHub Releases** | Yalnız **non-Play** sideload (stable/beta flavor) güncelleme | Sürüm meta; Play build’de updater **kapalı** | `DistributionConfig` / WP-110/128 |
| **E-posta API (Resend vb.)** | Aylık rapor (deploy edilmişse) | Opt-in kullanıcı e-postası + rapor özeti | Edge `send-report` / `0030` |

---

## 3. Telemetri (Sentry) — net sözleşme

| Madde | Değer | Kanıt |
|---|---|---|
| Varsayılan (SharedPreferences boş) | **Açık** (`?? true`) | `TelemetryPreference.isEnabled` |
| Kullanıcı kapatabilir mi? | **Evet** — Gizlilik ve yasal merkez anahtarı | `legal_center_screen.dart` |
| Kapalıyken | Yeni Sentry olayı yok | `observability_service` init guard |
| Derleme | DSN yoksa / yapılandırılmamışsa transport fiilen boş | `ObservabilityConfig` |
| PII | Ham hata mesajı / e-posta / token gönderilmez (yorum + sanitizasyon) | `observability_service.dart` notları |

Play form: “Crash logs” / “Diagnostics” → **Collected: Yes (optional)** · **User can request deletion: account deletion + disable telemetry**.

---

## 4. Data deletion (hesap silme)

Kaynak: `0037_account_deletion_core.sql`, `purge-accounts` Edge (WP-113/127), UI WP-114.

| Adım | Ne olur | Kanıt |
|---|---|---|
| 1. İstek | Kullanıcı uygulamadan `request_account_deletion()` | RPC `0037` |
| 2. Grace | `purge_after = now() + interval '14 days'` | `0037` satır ~104 |
| 3. İptal | `purge_after` öncesi `cancel_account_deletion()` | `0037` |
| 4. Planlı purge | Cron + `purge-accounts`: avatar storage, grup ownership, sohbet scrub, `auth.admin.deleteUser` | `supabase/functions/purge-accounts/index.ts` |
| 5. Retry | `attempt_count < 5` seçilir; ≥5 terminal `failed` (WP-127) | aynı Edge |
| 6. Cascade | Auth user silinince FK `on delete cascade` ile çoğu satır gider | `0037`/`0038` FK |

**Public silme bilgisi:** Legal / hesap ayarları metinleri + store “Data deletion” URL’si (LEGAL_BASE_URL canlı olmalı — ürün ops).

---

## 5. UGC (Play “User-generated content”)

| Yüzey | Tablo / UI | Rapor | Engel |
|---|---|---|---|
| Sınıf sohbeti | `class_messages` | Long-press → `report_ugc` (message) | Long-press → `block_user` |
| Kullanıcı / profil | `profiles` | Sosyal profil menü → user | Engelle + Ayarlar listesi unblock |
| Rapor detay | `ugc_reports.details` ≤500 | WP-130 sheet | — |
| Moderasyon | Admin kuyruk (super-admin) | `ugc_reports` status | — |

Kanıt: `0038_ugc_moderation.sql`; `report_sheet.dart`; `blocked_users_screen.dart`; WP-125–130.

---

## 6. Toplanmayan / bilinçli sınırlar

- Reklam kimliği, üçüncü taraf reklam SDK  
- Konum (yaklaşık veya hassas)  
- Kişi listesi, SMS, çağrı kaydı  
- Sağlık / finans özel kategorileri  
- Çocuklara özel veri toplama  

---

## 7. Play Console doldurma kontrol listesi

1. Bu tablodaki her “Evet” satırını Console’da karşılık gelen kategoriye işaretle.  
2. “Data encrypted in transit” → Yes.  
3. “Users can request that data be deleted” → Yes (in-app + scheduled).  
4. Account creation → Required.  
5. UGC → Yes; report/block mevcut (WP-125–129).  
6. Sentry → Diagnostics/Crash optional + user control.  
7. Location → No.  
8. Privacy policy URL → canlı HTTPS (`LEGAL_BASE_URL` / WP-111) — **ops açık**.  

---

## 8. Açık uçlar (kod dışı — Console / ürün)

Aşağıdakiler bu dosyada **iddia edilmez**; `PLAY-RELEASE-GATE.md` TODO’sunda:

- Canlı privacy/terms HTTPS URL’sinin mağaza formuyla birebir aynı metin  
- Content rating anketi cevabı  
- Store listing ekran görüntüleri  
- Production’da 0037/0038 + purge Edge gerçekten deploy mu  

---

*Son güncelleme: WP-132 (2026-07-17). Kod değişikliği yok; yalnız envanter.*
