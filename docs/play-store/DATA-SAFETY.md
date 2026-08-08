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
| **Fotoğraf** (avatar) | Evet (kullanıcı yüklerse) | Üye görünürlüğü / public storage URL | Profil | Evet (yükleme opsiyonel) | Evet | purge-accounts storage scrub — `avatars` (§4.1) + cascade | `profiles.avatar_url`; `0002_avatars_storage`; purge-accounts |
| **Kullanıcı kimliği (UUID)** | Evet | Grup/sohbet/presence satırlarında üyelere | Çekirdek özellik | Hayır | Evet | Auth delete cascade | Tüm `user_id` FK’ler |
| **Uygulama etkileşimi — çalışma oturumu** | Evet (süre, konu, zaman) | Grup üyeleri (RLS `can_see_user_sessions` vb.) | Çalışma istatistiği, başarım/XP sunucu | Hayır (özellik kullanımı) | Evet | Hesap silme hard-delete | `study_sessions` / özet tablolar; gamification ledger |
| **Uygulama etkileşimi — presence** | Evet (durum, started_at, updated_at) | Aynı grup üyeleri | Kamp ateşi canlılığı | Hayır (özellik) | Evet | Cascade / presence satırı | `presence` (`0001`) |
| **Mesajlar (UGC)** | Evet (`class_messages.body`) | Grup üyeleri | Sınıf sohbeti | Evet (yazmazsa yok) | Evet | Soft scrub `[silindi]` purge; hard-delete cascade | `0015_class_chat.sql`; purge-accounts |
| **UGC rapor içeriği** | Evet (reason, optional details ≤500, snapshot, opsiyonel foto ek) | Super-admin moderasyon; reporter kendi satırı (ekini geri okuyamaz) | Güvenlik / UGC politika | Evet (kullanıcı raporlarsa) | Evet | Hesap silme cascade (`ugc_reports`) + purge-accounts `report_attachments` scrub (§4.1) | `ugc_reports` (`0038`/`0096`); `report_ugc` RPC |
| **Engel listesi** | Evet (`user_blocks`) | Hayır (yalnız engelleyen görür) | Güvenlik / engelleme | Evet | Evet | Cascade | `user_blocks`; `block_user` / `unblock_user` (`0038`) |
| **Topluluk kuralları kabulü** | Evet (sürüm + zaman) | Hayır | UGC uyum | Rapor öncesi zorunlu | Evet | Cascade | `community_terms_acceptances` (`0038`) |
| **Geri bildirim / hata raporu (in-app)** | Evet (ticket metni, ek) | Super-admin | Destek | Evet | Evet | Hesap silme cascade (`feedback_tickets`) + purge-accounts `feedback_attachments` scrub (§4.1) | feedback tabloları (önceki migration’lar); `0072` |
| **E-posta iş kuyruğu (aylık rapor)** | Evet (job satırları; opt-in) | E-posta sağlayıcı (Resend vb. — ops deploy) | Aylık çalışma raporu | Evet (`monthly_report_opt_in`) | Evet | purge iptal / abandon; hesap silme | `email_job_queue`; `profiles.monthly_report_opt_in`; `0030`/`0035` |
| **Hesap silme isteği meta** | Evet (status, purge_after, attempt) | Hayır | Yasal silme boru hattı | Kullanıcı tetikler | Evet | Cascade on Auth delete (satır gidebilir) | `account_deletion_requests` (`0037`) |
| **Çökme / performans telemetrisi** | Koşullu (Sentry) | Sentry (DSN yapılandırılmışsa) | Kararlılık | **Evet — opt-out** | Evet HTTPS | Tercihi kapat → yeni olay yok | `TelemetryPreference` default **açık**; Legal Center switch; `observability_service.dart` |
| **Cihaz veya diğer kimlikler** | **EVET** — push cihaz kimliği + FCM jetonu | Hayır (Firebase/FCM işleyici) | Bildirim gönderimi (dürtme, duyuru, sayaç senkronu) | Bildirim izni verilirse | Evet HTTPS | Hesap silme cascade (`user_id` FK) | `push_devices.installation_id` + `push_devices.fcm_token` (`0066_push_notification_delivery.sql:6-12`) |
| **Reklam kimliği** | Hayır | — | — | — | — | — | Reklam SDK yok |
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
| 4. Planlı purge | `account-purge-worker` cron (saatlik) → `purge-accounts`: kullanıcı klasörlü storage (§4.1, sayfalı), grup ownership + silinen grubun avatarı, sohbet scrub, `auth.admin.deleteUser`, PII'siz denetim izi | `0113_account_purge_scheduler.sql` + `supabase/functions/purge-accounts/index.ts` |
| 5. Retry | `attempt_count < 5` seçilir; ≥5 terminal `failed` (WP-127) | aynı Edge |
| 6. Cascade | Auth user silinince FK `on delete cascade` ile çoğu satır gider | `0037`/`0038` FK |

> 🔴 **Beyandan önce okunacak (WP-464, 2026-07-31).** Adım 4'ün zamanlayıcısı
> `0113`e kadar **hiç yoktu**: `purge-accounts` yazılmıştı ama onu çağıran ne
> cron ne workflow vardı, yani 14 gün dolan istek hiçbir şeye dönüşmüyordu.
> `0113` o halkayı bağladı.
>
> Zincirde ikinci bir kusur daha vardı ve **`0114` ile kapatıldı**: `public`
> şemasından `auth.users`'a giden 7 adet `not null` + `on delete restrict` FK
> `auth.admin.deleteUser`'ı FK ihlaliyle düşürüyordu. En genişi
> `feedback_ticket_messages.sender_id` (`0074`) — `sender_role` 'user' de
> olabildiği için **destek biletine tek mesaj yazmış sıradan kullanıcı bile
> silinemiyordu**. Diğerleri: `admin_audit_logs.admin_id`,
> `announcements.created_by`, `feedback_ticket_notes.admin_id`,
> `group_bans.banned_by`, `moderation_name_resets.reset_by`,
> `moderation_sanctions.actor_id`.
>
> Ürün sahibi kararı (2026-07-31, `HESAP-SILME-RETENTION-KARARI.md` §5.6):
> **kanıt takma kimlikle korunur** — FK'ler `on delete set null`, satırda
> kalıcı `*_hash` (sha256(uid)) sütunu. Hesap silinince ham kimlik gider,
> kanıt satırı atfedilebilir biçimde kalır. Sözleşme:
> `supabase/tests/040_pseudonymous_actor_retention.test.sql`.

**Silme kapsamı (forma yazılacak ayrım):** kullanıcının **kendi** içeriği
(profil, oturumlar, kendi destek biletleri ve o biletlerdeki mesajları, kendi
itiraz/raporları, avatar nesneleri) `cascade` ile **silinir**. Kullanıcının
*başkasına ait* kayıtlarda bıraktığı **aktör izi** (ör. bir admin olarak
başkasının biletine yazdığı yanıt, verdiği ban/yaptırım) satır olarak kalır
ama ham kimlik silinir; geriye yalnız takma kimlik (sha256) kalır.

**Public silme bilgisi:** Legal / hesap ayarları metinleri + store “Data deletion” URL’si (LEGAL_BASE_URL canlı olmalı — ürün ops).

---

### 4.1 Storage silme kapsamı (WP-545) — dört bucket, dört karar

🔴 **Ölçüldü (2026-08-08):** purge WP-545'e kadar dört bucket'ın yalnız
**birini** (`avatars`) temizliyordu. Kullanıcının yüklediği geri bildirim ve
şikâyet fotoğrafları hesap silindikten sonra ham uid'li klasörlerinde
duruyordu; bu sayfa ve yasal metin ise yalnız "avatar" diyordu. Silinen
grupların fotoğrafları da sahipsiz kalıyordu (`0049`'un temizlik
tetikleyicisini `0054` kaldırmış, yerine söz verilen periyodik storage-audit
hiç yazılmamıştı).

| Bucket | Yol anahtarı | Hesap silinince | Gerekçe | Kanıt |
|---|---|---|---|---|
| `avatars` | `<uid>/` | **Silinir** | Kullanıcının kendi profil fotoğrafı | `0002:30`; `USER_OWNED_STORAGE_BUCKETS` |
| `feedback_attachments` | `<uid>/` | **Silinir** | Kullanıcının kendi destek eki; `feedback_tickets` satırı zaten `on delete cascade` (`0018:18`) | `0072:31`; retention kararı §4 adım 1 ("storage avatar + feedback ekleri") |
| `report_attachments` | `<uid>/` | **Silinir** | Kullanıcının kendi şikâyet/soru eki; `ugc_reports.reporter_id` (`0038:40`) ve `feedback_tickets.user_id` **cascade** — eki işaret eden satır zaten gidiyor. Nesneyi bırakmak delil saklamak olmaz, hiçbir satırın işaret etmediği bir fotoğraf bırakırdı. Retention kararı §5.6 kapsam notu: "kendi raporu cascade ile silinmeye devam eder" | `0096:69`; `HESAP-SILME-RETENTION-KARARI.md` §5.6 |
| `group-avatars` | `<group_id>/` | **Yalnız grup da silinirse** | Nesne **grubun** malıdır, yükleyenin değil. Grup devredilirse (aktif üye varsa) fotoğraf grupla birlikte kalır; grup üyesiz kalıp silinirse purge nesneyi grup id'siyle düşürür. Saklama süresi = grubun ömrü | `0049:23` (`groups_avatar_path_format`); `0054` (tetikleyici kaldırıldı) |

**Sözleşme:** `supabase/tests/049_account_purge_storage_scope.test.sql` —
envanteri dört bucket'ta dondurur (yeni bucket eklenirse kırmızı düşer) ve her
bucket'ın yol anahtarını davranışsal olarak ölçer.

**Sınır (dürüst kayıt):** o test veritabanının içinde koşar ve Edge
function'ın TypeScript'ini okuyamaz; "şu bucket gerçekten siliniyor" iddiasını
kod üzerinden kanıtlayan bir kapı henüz yok.

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

*Son güncelleme: WP-545 (2026-08-08) — §4.1 storage silme kapsamı eklendi ve
§1 satırları gerçek purge davranışıyla eşitlendi. Öncesi: WP-132 (2026-07-17).*
