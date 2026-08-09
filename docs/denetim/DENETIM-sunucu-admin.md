# Denetim — Edge Function'lar, admin paneli, veri dışa aktarma

**Tarih:** 2026-08-09 · **Yapan:** alt denetçi (salt okunur) · **Kapsam:**
`supabase/functions/**` (6 fonksiyon + `_shared`, test hariç 1902 satır), zamanlanmış işler
(`cron.schedule` çağıran 12 migration), admin paneli (`app/lib/features/admin/**`
+ `supabase_admin_repository.dart`, `supabase_admin_moderation_repository.dart`),
veri dışa aktarma (`supabase_data_export_repository.dart`), aktivasyon
workflow'ları.

**Yöntem:** belge okunmadı, iddia sayıldı. `progress.md`, `docs/**` ve kod
yorumları kanıt kabul edilmedi; her bulgu `dosya:satır` ile koddan doğrulandı.
Bulunan her şey `git log --oneline -130` ile kontrol edildi — Edge Function
dizinine bugün **hiç** commit atılmamış (en yeni: `94d8da2` WP-549), yani
aşağıdakiler bugün düzeltilmiş şeyler değil.

**Kapsam dışı (lider zaten denetledi):** RLS, politika, definer fonksiyon
EXECUTE yetkileri — `docs/denetim/DENETIM-veritabani.md`. `0124`ün
production'a uygulanmamış olması ve hesap silmenin canlıda çalışmaması da
bilinen ve açık; burada tekrar edilmedi.

---

## Özet

**KANAMA: 2 · RİSK: 6 · TEMİZLİK: 5**

**Sır sızıntısı: YOK.** Altı fonksiyonun her hata yolu tek tek okundu; hiçbir
`console.*` veya HTTP yanıtı service_role anahtarı, cron secret, dispatch
secret, FCM özel anahtarı veya Resend anahtarı taşımıyor. Aksine: sırla ilgili
üç yerde bilinçli maskeleme var (`purge-accounts/index.ts:242`,
`dispatch-push/index.ts:394`, `production-purge-activation.yml:99`
`::add-mask::`).

En kötü üç madde:
1. **Aylık rapor e-postası hiç gönderilmiyor** — `send-report` fonksiyonunu
   çağıran hiçbir cron, workflow veya istemci yok. Kullanıcıya varsayılan
   AÇIK bir anahtar gösteriliyor.
2. **"Askıya Al" düğmesi 100 yıllık ban kuruyor** — süre etiketi yok, yaptırım
   kaydı yok, kendiliğinden dolmuyor.
3. **Dört Edge Function hiçbir workflow'da deploy edilmiyor** — canlıdaki
   kodun bu repodaki kod olduğunun kanıtı yok.

---

## KANAMA

### K1 — Aylık rapor e-postası hiç gönderilmiyor; kuyruk her ay doluyor, boşaltan yok

**Belirti:** Kullanıcı ayarlarda "aylık rapor" anahtarını görüyor (varsayılan
AÇIK), `collect-reports` her ayın 2'sinde kuyruğa satır yazıyor, ama o kuyruğu
işleyip e-postayı gönderen `send-report` fonksiyonunu **hiçbir şey çağırmıyor**.

**Kanıt:**
- `supabase/functions/send-report/index.ts:1` — fonksiyon var, 163 satır, Resend
  entegrasyonu tam.
- `supabase/migrations/0035_cron_report_url_fix.sql:41` — kurulan tek cron
  (`monthly-report-collector`) `/functions/v1/collect-reports` çağırıyor.
  Repodaki 12 dosyadaki `cron.schedule` çağrılarının **hiçbiri** `send-report` demiyor.
- `.github/workflows/**` — `send-report`'a giden tek bir `curl` veya
  `functions deploy` yok (tek geçtiği yerler yorum satırı:
  `production-purge-activation.yml:88`, `staging-purge-activation.yml:86`).
- `app/lib/**` — `functions.invoke` çağrılarının beşi de admin fonksiyonlarına;
  `send-report`'a istemci çağrısı yok.
- Karşı taraf: `app/lib/features/notifications/notification_permissions_screen.dart:60,88`
  kullanıcıya anahtarı gösteriyor; `supabase/migrations/0030_monthly_report_infrastructure.sql:7`
  `monthly_report_opt_in boolean default true` — yani **herkes opt-in**.

**Etki:** `email_job_queue` her ay opt-in kullanıcı sayısı kadar `pending`
satırla büyüyor ve hiç tüketilmiyor. Kullanıcı açtığı anahtarın karşılığında
hiçbir zaman e-posta almıyor. `docs/play-store/DATA-SAFETY.md:30` bu akışı
"var" diye beyan ediyor — beyan ile kod aynı şeyi söylemiyor.

**Öncelik:** KANAMA

---

### K2 — Admin panelindeki "Askıya Al" düğmesi 100 yıllık, kaydı olmayan ban kuruyor

**Belirti:** Kullanıcılar sekmesindeki düğme "Askıya Al" diyor, süre sormuyor,
süre göstermiyor. Sunucuda `suspend_user` → `876000h` (≈100 yıl).

**Kanıt:**
- `supabase/functions/admin-user-actions/index.ts:266` —
  `suspend_user: '876000h'`, `suspend_permanent` ile **aynı değer**.
- `app/lib/features/admin/tabs/admin_users_tab.dart:205` — düğme `'suspend_user'`
  gönderiyor, gerekçe dışında hiçbir süre parametresi yok.
- Aynı switch dalı `moderation_sanctions` tablosuna **hiçbir satır yazmıyor**
  (satır 269-274): sadece `auth.admin.updateUserById`. Yani Moderasyon
  sekmesinde bu ban görünmez, `moderation_active_sanction` onu bilmez,
  `admin_revoke_moderation_sanction` onu geri alamaz.

**Etki:** Admin "geçici askı" sandığı işlemle kullanıcıyı kalıcı olarak
dışarıda bırakıyor. Kendiliğinden dolmuyor (100 yıl), yaptırım listesinde
görünmüyor, tek çıkış yolu aynı sekmedeki "Askıyı Kaldır" düğmesini bulmak.
WP-441 yaptırım basamağı (24s/7g/14g/30g, geri alınabilir, denetim izli) tam
olarak bu sorunu çözmek için yazılmış ama eski dal hâlâ canlı ve hâlâ UI'dan
çağrılıyor.

**Öncelik:** KANAMA

---

## RİSK

### R1 — Bir uyarıyı geri almak, ilgisiz kalıcı yasağı da kaldırıyor

**Belirti:** `moderation_revoke` hangi yaptırım geri alınırsa alınsın hedef
kullanıcının auth ban'ını **koşulsuz** siliyor.

**Kanıt:** `supabase/functions/admin-user-actions/index.ts:87-91`
```
if (revoked?.target_user_id) {
  const { error: authError } = await supabaseAdmin.auth.admin
    .updateUserById(revoked.target_user_id, { ban_duration: 'none' })
```
Koşul yalnız "geri alınan satırın hedefi var mı". Geri alınan yaptırımın
`warn`, `mute_24h` veya `name_reset` olması — yani auth tarafına hiç
dokunmamış olması — kontrol edilmiyor (bu üç aksiyonun auth'a dokunmadığı aynı
dosyada satır 139-143'te yazılı).

**Etki:** Kullanıcıya önce Kullanıcılar sekmesinden `suspend_user` /
`soft_delete_user` (100 yıllık ban) uygulanmışsa, sonra Moderasyon sekmesinden
o kullanıcının eski bir **uyarısını** geri almak yasağı da kaldırır.
`soft_delete_user` durumunda `user_metadata.deleted = true` kalır ama kullanıcı
tekrar giriş yapabilir hale gelir.

**Öncelik:** RİSK

---

### R2 — Uzlaştırma yorumu yalan söylüyor: auth ban duruyor, kayıt geri alınamaz oluyor

**Belirti:** `0105`teki yorum "kullanıcı yarım durumda cezalı kalmaz" diyor.
Kod bunu yapmıyor.

**Kanıt:**
- `supabase/migrations/0105_moderation_enforcement_ladder.sql:351-354` (yorum):
  *"Auth tarafı başarılı olup kapanış çağrısı düşerse satır pending kalır.
  Uzlaştırma: ... kullanıcı yarım durumda cezalı kalmaz"*.
- `supabase/migrations/0105_moderation_enforcement_ladder.sql:355-369` (kod):
  `admin_reconcile_moderation_sanctions()` yalnızca `moderation_sanctions`
  satırını `pending` → `failed` yapıyor. Auth tarafına **hiçbir çağrı yok** —
  zaten SQL fonksiyonu `auth.admin` API'sini çağıramaz.
- Akış: `supabase/functions/admin-user-actions/index.ts:135-138` auth ban'ı
  uyguluyor, satır 148-155 kapanış RPC'sini çağırıyor. Kapanış düşerse ban
  uygulanmış, satır `pending` kalmış olur.
- `supabase/migrations/0105_moderation_enforcement_ladder.sql:336` —
  `admin_revoke_moderation_sanction` yalnız `state in ('pending','applied')`
  satırını geri alır. Uzlaştırma satırı `failed` yaptıktan sonra geri alma
  `sanction_not_revocable` ile düşer.

**Etki:** Geçici bir RPC hatası, kullanıcıyı 30 güne kadar banlı bırakıyor;
yaptırım kaydı "başarısız" göründüğü için moderasyon yolundan geri alınamıyor.
Tek çıkış Kullanıcılar sekmesindeki `unsuspend_user`.

**Öncelik:** RİSK

---

### R3 — Push kirası (90 sn) dakikalık cron'dan kısa; timeout'suz FCM çağrısı çift bildirim üretebilir

**Belirti:** Aynı teslim iki farklı worker tarafından gönderilebilir.

**Kanıt:**
- `supabase/functions/dispatch-push/index.ts:376-380` — `p_limit: 50`,
  `p_lease_seconds: 90`; teslimler **sırayla** (`for ... await`) gönderiliyor
  (satır 400-430).
- `supabase/functions/dispatch-push/index.ts:248` ve `:106` — FCM ve OAuth
  `fetch` çağrılarında `AbortSignal` / timeout **yok**. Deno `fetch`inin
  varsayılan zaman aşımı yoktur.
- `supabase/migrations/0069_push_dispatch_retry_health.sql:62-66` — cron
  `'* * * * *'`, yani **her dakika** yeni bir dispatcher tetikleniyor.
- `supabase/migrations/0083_timer_sync_push_policy.sql:164` — claim sorgusu
  `(d.status = 'processing' and d.lease_until < now())` satırlarını yeniden
  alıyor.
- `supabase/migrations/0066_push_notification_delivery.sql:646-654` —
  `complete_push_delivery` `claimed_by = p_worker_id` şartını arıyor, tutmazsa
  `delivery_claim_mismatch` atıyor.

**Etki:** Döngü 90 saniyeyi aşarsa (FCM yavaşlığı veya tek bir asılı bağlantı
yeter) ikinci worker aynı teslimleri claim eder ve **ikinci kez FCM'e
gönderir**; birinci worker'ın tamamlama çağrısı da `delivery_claim_mismatch`
ile düşer ve teslim `failed` sayılır. Kullanıcı aynı dürtmeyi/duyuruyu iki kez
görür. Sonsuza kadar asılı kalma da mümkün: hiçbir dış çağrıda sınır yok.

**Öncelik:** RİSK

---

### R4 — Altı Edge Function'ın dördü hiçbir workflow'da deploy edilmiyor

**Belirti:** Repoda okunan kodun canlıda çalışan kod olduğunun kanıtı yok.

**Kanıt:** `functions deploy` geçen tüm satırlar:
- `.github/workflows/production-push-activation.yml:98` → `dispatch-push`
- `.github/workflows/staging-push-activation.yml:98` → `dispatch-push`
- `.github/workflows/production-purge-activation.yml:112` → `purge-accounts`
- `.github/workflows/staging-purge-activation.yml:110` → `purge-accounts`

`admin-operations`, `admin-user-actions`, `collect-reports`, `send-report` —
**hiçbiri**. CI (`.github/workflows/ci.yml:122`) altısını da `deno check`ten
geçiriyor, yani "tip denetiminden geçti" iddiası doğru; ama o dördü canlıya
yalnız elle `supabase functions deploy` ile gitmiş olabilir ve o elin ne zaman
kalktığı bilinmiyor.

**Etki:** Bu denetimin admin fonksiyonlarıyla ilgili tüm bulguları "repodaki
kod" için geçerli. Canlıdaki sürüm daha eski olabilir (K2, R1 gibi bulgular
canlıda daha kötü hâliyle duruyor olabilir) veya daha yeni olabilir (repoda
olmayan bir yama canlıda olabilir — ki bu daha kötüsü). Tip denetim kapısı
deploy edilmeyen kodu ölçüyor.

**Öncelik:** RİSK

---

### R5 — "Şifre sıfırlama e-postası gönder" üretilen bağlantıyı çöpe atıyor

**Belirti:** Admin düğmesi başarı diyor; kodun kullanıcıya bir şey ilettiği
görünmüyor.

**Kanıt:** `supabase/functions/admin-user-actions/index.ts:198-203`
```
const { error } = await supabaseAdmin.auth.admin.generateLink({
  type: 'recovery',
  email: targetUserEmail,
})
if (error) throw error
result = { success: true }
```
`data` (yani üretilen `action_link`) **hiç okunmuyor**, hiçbir yere
yazılmıyor, hiçbir yere gönderilmiyor. UI (`admin_users_tab.dart:183`,
`l10n.adminSifreSifirlamaEpostasiGonder`) kullanıcıya "e-posta gönder"
sözü veriyor.

**Emin değilim:** GoTrue'nun `admin/generate_link` uç noktasının kendi başına
e-posta gönderip göndermediği sürüme bağlı; gönderiyorsa bulgu düşer. Ayrıca
hafızadaki not free-tier'da e-posta şablonunun kilitli olduğunu söylüyor —
bu durumda gönderilse bile ulaşmaz. Cihazda tek denemeyle kapanır.

**Öncelik:** RİSK

---

### R6 — Aylık rapor cron'u YANLIŞ ayı istiyor

**Belirti:** Her ayın 2'sinde koşan cron, geçen ayı değil **içinde bulunulan
ayı** istiyor.

**Kanıt:** `supabase/migrations/0035_cron_report_url_fix.sql:57`
```
'month', to_char((now() at time zone 'Europe/Istanbul') - interval '1 day', 'YYYY-MM')
```
Cron ifadesi `'0 6 2 * *'` (satır 35, `'0 6 2 * *'`) — ayın **2'si**. 2 Eylül eksi 1 gün =
1 Eylül → `'2026-09'`. Geçen ay için `- interval '1 month'` gerekirdi.
Karşılaştırma: fonksiyonun kendi varsayılanı doğru
(`supabase/functions/collect-reports/index.ts:43-49`, `d.setMonth(d.getMonth()-1)`)
— ama cron gövdesi `month` alanını açıkça göndererek o doğru varsayılanı eziyor.

**Etki:** Rapor gönderimi bağlandığı gün, kullanıcılar geçen ayın özeti yerine
1 günlük yeni ayın özetini alır. Bugün K1 yüzünden görünmüyor.

**Öncelik:** RİSK

---

## TEMİZLİK

### T1 — `send-report`'ta `processing` satırını kurtaran yok, Resend çağrısında timeout yok

**Kanıt:**
- `supabase/functions/send-report/index.ts:67-70` — iş `processing` yapılıyor.
- `supabase/functions/send-report/index.ts:46-52` — seçim yalnız
  `['pending','failed']`; `processing` bir daha **hiç** seçilmiyor.
- `supabase/migrations/**` içinde `email_job_queue` için lease/claimed_at
  kolonu veya kurtarma işi yok (`0030` tabloyu kuran tek migration).
- `supabase/functions/send-report/index.ts:98` — Resend `fetch`inde
  `AbortSignal`/timeout yok; 30 iş sırayla dönüyor.

**Etki:** Koşum ortasında düşen fonksiyon (wall-clock, asılı bağlantı) o ana
kadar `processing` yapılmış işleri **kalıcı olarak** öldürür. Karşılaştırma:
`purge-accounts` ve `dispatch-push` bu dersi öğrenmiş, ikisinde de lease
kurtarması var (`0113` `claimed_at`, `0066` `lease_until`); e-posta kuyruğu
öğrenmemiş. K1 yüzünden bugün etkisiz, ama gönderim bağlandığı gün patlar.

**Öncelik:** TEMİZLİK

---

### T2 — E-posta şablonundaki "abonelikten çık" bağlantısı hiçbir yere gitmiyor

**Kanıt:** `supabase/functions/send-report/templates.ts:71`
`https://app.odakkampi.com/unsubscribe?token=${unsubscribeToken}`.
Repoda `unsubscribe` rotasını karşılayan hiçbir şey yok: Edge Function yok,
`scripts/build_legal_site.py` çıktısında (`.github/workflows/legal-site.yml:86`
doğrulanan dört sayfa: `privacy-tr/en`, `data-deletion-tr/en`) yok,
istemcide deep link yok. Buna rağmen her gönderimde
`email_unsubscribe_tokens`'a satır yazılıyor
(`supabase/functions/send-report/index.ts:87-93`).

**Etki:** E-posta gönderimi açıldığı gün, `List-Unsubscribe` başlığı da
mailto'ya düşüyor ve gövdedeki tek bağlantı 404 veriyor. Bugün K1 yüzünden
etkisiz.

**Öncelik:** TEMİZLİK

---

### T3 — Denetim satırı yazılamazsa, yapılmış iş "başarısız" olarak raporlanıyor

**Kanıt:** `supabase/functions/admin-operations/index.ts:125-133` ve
`supabase/functions/admin-user-actions/index.ts:312-323`. Her ikisinde de
`admin_audit_logs` insert'i yıkıcı işlemden **sonra** ve hata durumunda
`throw` ediyor → dış `catch` 400 döner
(`admin-operations/index.ts:139-144`).

**Etki:** Grup silindi / kullanıcı banlandı ama admin "İşlem başarısız"
görüyor. Doğal refleks yeniden denemek; `delete_group` için zararsız, ama
`reset_group_name` yeniden çalışırsa `moderation_name_resets` upsert'i
`ignoreDuplicates` sayesinde korunur — yine de aksiyon-denetim atomikliği yok.

**Öncelik:** TEMİZLİK

---

### T4 — `admin-user-actions` içinde ölü switch dalları

**Kanıt:** `supabase/functions/admin-user-actions/index.ts:207-210`
(`warn_user` → `result = { success: true }`, başka hiçbir şey yapmıyor),
`:212-253` (`reset_user_name`, `restore_user_name`), `:255-268`
(`suspend_24h/7d/14d/30d`, `suspend_permanent`), `:277-285` (`revoke_sanction`).
İstemcide bu adlarla çağrı yok — `app/lib` içinde yalnız
`send_password_reset`, `unsuspend_user`, `suspend_user`, `soft_delete_user`
(`admin_users_tab.dart:183,194,205,215`) geçiyor; geri kalan moderasyon
`moderation_sanction` / `moderation_revoke` yolundan gidiyor.

**Etki:** Ölü kod değil sadece — `warn_user` dalı hiçbir şey yapmadan başarı
dönüyor ve denetim satırı yazıyor. Yeniden bağlanırsa sessiz no-op olur. Aynı
şekilde eski `suspend_*` dalları K2'deki kayıtsız ban davranışını taşıyor.

**Öncelik:** TEMİZLİK

---

### T5 — `is_super_admin` RPC hatası yutuluyor

**Kanıt:** `supabase/functions/admin-operations/index.ts:39` ve
`supabase/functions/admin-user-actions/index.ts:43`:
`const { data: isSuperAdmin } = await supabaseClient.rpc('is_super_admin')` —
`error` alanı okunmuyor.

**Etki:** Güvenlik açısından **doğru yönde**: hata durumunda `data` `null`
olur, `!isSuperAdmin` doğru olur, 403 döner — fail-closed. Ama "yetkin yok" ile
"kontrol koşamadı" ayırt edilemez; RPC'nin EXECUTE yetkisi bir gün düşerse
admin paneli sessizce "Forbidden" der ve neden olduğu görünmez.

**Öncelik:** TEMİZLİK

---

## Kontrol ettim, SAĞLAM çıktı

Negatif sonuçları da yazıyorum ki bir sonraki denetim aynı yolu baştan
taramasın.

### 1. Sır sızıntısı — YOK
Altı fonksiyonun her `console.*` ve her `Response` gövdesi tek tek okundu.
`SUPABASE_SERVICE_ROLE_KEY`, `CRON_SECRET`, `PURGE_CRON_SECRET`,
`PUSH_DISPATCH_SECRET`, `FCM_SERVICE_ACCOUNT_BASE64`, `RESEND_API_KEY` —
hiçbirinin değeri log'a veya yanıta düşmüyor. Üç yerde bilinçli maskeleme var:
`purge-accounts/index.ts:242` (config hatasında `error.message` log'lanıyor,
secret log'lanmıyor), `dispatch-push/index.ts:392-394` (credential ayrıntısı
yerine `provider_auth_failed`), `production-purge-activation.yml:99`
(`::add-mask::` + `$RUNNER_TEMP` env dosyası + `trap rm`).
Tek yorum: `send-report/index.ts:117-118` Resend'in hata gövdesini `error_log`
kolonuna yazıyor; Resend hata gövdesi Authorization başlığını yansıtmaz, ama
bu satır dışarıdan gelen metni doğrudan DB'ye yazan tek yer.

### 2. `service_role` kullanan her fonksiyon çağıranı doğruluyor
- `admin-operations:15-45` ve `admin-user-actions:16-49`: önce anon-key +
  kullanıcı JWT'siyle `auth.getUser()`, sonra **kullanıcının kendi
  client'ıyla** `is_super_admin()`. service_role client yalnız kontrolden
  sonra kullanılıyor. Service_role veya anon anahtarını `Authorization`
  başlığında yollamak işe yaramaz: o JWT'lerde `sub` yoktur, `getUser()`
  düşer → 401.
- `collect-reports:11-25`, `send-report:12-26`, `_shared/purge_policy.ts:38-50`:
  cron secret / service_role Bearer. Üçü de **fail-closed** — env değişkeni
  boşsa hiçbir dal `null` dönmez, 401 döner. `purge_policy.test.ts` bunu
  sözleşmeye bağlamış.
- `dispatch-push:301-305`: sabit zamanlı karşılaştırma (`secureEqual:41-48`),
  uzunluk 0 ise kesin `false` → secret tanımsızken herkes 401 alır.

### 3. Worker RPC'lerinin hiçbiri istemciye açık değil
`claim_push_deliveries`, `complete_push_delivery`, `disable_push_device`,
`enqueue_update_push`, `configure_push_dispatch`,
`get_push_dispatch_queue_health`, `claim_account_deletion_jobs`,
`record_account_purge_outcome`, `get_account_purge_health` — dokuzunun da
`revoke all ... from public, anon, authenticated` + `grant ... to service_role`
satırı var (`0066:716-726`, `0067:65-66`, `0068:12-14`, `0069:44-45,122-123`,
`0070:131-132`, `0083:179-181`, `0113:184-186,234-236,349-350`). Ayrıca
`0066:628` gibi gövde içi `auth.role() is distinct from 'service_role'`
ikinci kapıları var — ikili koruma.

### 4. Admin RPC'lerinin hepsinde `is_super_admin()` kapısı var
`admin_dashboard_summary`, `admin_feedback_tickets`,
`admin_update_feedback_status`, `admin_begin_moderation_sanction`,
`admin_finish_moderation_sanction`, `admin_revoke_moderation_sanction`,
`admin_reconcile_moderation_sanctions`, `admin_set_case_quarantine`,
`admin_reporter_abuse_score`, `admin_ugc_report_groups`,
`admin_set_ugc_report_group_status` — hepsi gövdenin ilk satırında
`if not public.is_super_admin() then raise ... errcode '42501'`.
`authenticated`a verilen EXECUTE yetkisi bu kapıyı geçmiyor.

### 5. Admin yetkisi istemciden manipüle edilemiyor
`is_super_admin()` (`0018:43-56`, `0045:43-56`) `public.app_admins` tablosunu
okuyor. Tabloda RLS açık ve **hiçbir policy yok** — `0018:38-41` dört policy'yi
de bilerek `drop` ediyor. `authenticated` bu tabloyu ne okuyabiliyor ne
yazabiliyor; satır yalnız SQL Editor / service_role ile eklenebiliyor.
İstemcideki `adminIsSuperAdminProvider` (`admin_providers.dart:28-32`)
sadece menüyü gizliyor — gerçek kapı sunucuda.

### 6. Veri dışa aktarma yalnız kendini veriyor
`supabase_data_export_repository.dart` altı sorgunun altısında da
`.eq('user_id', userId)` / `.eq('id', userId)` var ve `userId` çağıran taraftan
oturumdan geliyor (`data_export_screen.dart:52,65` → `user.id`). Başkasının
id'si elle verilse bile RLS düşürür — çift koruma. Dışa aktarma bir Edge
Function değil, service_role hiç devreye girmiyor.

### 7. Yaptırım yolu idempotent
`admin-user-actions:99-109` — `admin_begin_moderation_sanction`
`idempotency_key` üzerinden mevcut kaydı döndürüyor
(`0105:199-206`), edge tarafı `if (opened.state !== 'pending') return` ile
auth işini ikinci kez koşmuyor. `admin_finish_moderation_sanction` de
`state <> 'pending'` ise kaydı olduğu gibi döndürüyor (`0105:263-268`).
Eski `mute_24h` çağrısı için anahtar dakika kovasından türetiliyor
(`admin-user-actions:65-69`) — aynı dakikadaki tekrarlar tek yaptırım.

### 8. Hesap silme kuyruğunun claim'i atomik ve kurtarmalı
`purge-accounts:296-300` → `claim_account_deletion_jobs` (`0113`), `for update
skip locked` + aynı ifadede `processing` yazımı, lease 1800 sn, çökmüş worker
kurtarması var. Ara adımların hepsi `must()` ile kontrol ediliyor
(`purge-accounts:81-86`) — sessiz yutma yok. `dry_run` hiçbir satır claim
etmiyor. Denetim izi PII'siz (sha256 uid, `0113` §2). Storage sayfalaması
`MAX_PAGES` ile sınırlı, sonsuz döngü riski yok
(`purge-accounts:156-173`).

### 9. Push dispatch'te `enqueue_update` girdi doğrulaması var
`dispatch-push:353-374` — kanal beyaz listesi (`beta`/`stable`), `event_key`
zorunlu, `build_number` tamsayı ve ≥1; `enqueue_update_push` `on conflict
(event_key) do nothing` ile çift duyuru üretmiyor (`0100:27` deseni).
`health` çağrısı hiçbir teslim claim etmiyor ve token/payload döndürmüyor
(`dispatch-push:317-324`).

### 10. Aktivasyon workflow'ları sırrı disk/log'a bırakmıyor
`production-push-activation.yml:80-92` ve `production-purge-activation.yml:93-106`:
`umask 077`, `$RUNNER_TEMP` altında env dosyası, `trap 'rm -f' EXIT`,
`::add-mask::`, `set -euo pipefail`; hiçbir adımda `set -x` yok.
`--fail-with-body` yanıtları `jq -e` ile sınanıyor, ham yanıt ekrana
basılmıyor. Ayrıca purge kendi `PURGE_CRON_SECRET`'ini kullanıyor,
`CRON_SECRET`'i ezmiyor (`_shared/purge_policy.ts:29-35`) — rapor cron'u
sessizce 401 almıyor.

### 11. Runtime config tabloları istemciye kapalı
`push_dispatch_runtime_config` (`0067:24-26`) ve
`account_purge_runtime_config` (`0113:253-256`): RLS açık,
`revoke all ... from anon, authenticated`, yalnız `service_role`.
Secret'ı yazan RPC'ler `auth.role() <> 'service_role'` kapısını taşıyor
(`0067:38-41`) ve URL/secret format kontrolü yapıyor (`0067:43-50`).

### 12. CORS `*` ama zararsız
Altı fonksiyonun hepsinde `Access-Control-Allow-Origin: '*'`. Kimlik
çerezle değil `Authorization` başlığıyla taşındığı ve
`Access-Control-Allow-Credentials` verilmediği için tarayıcıdan
başkasının oturumuyla çağrı yapılamıyor. Bulgu değil.
