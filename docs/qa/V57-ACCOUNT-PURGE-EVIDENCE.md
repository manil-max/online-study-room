# V57 — Hesap silme purge zinciri (WP-464)

Kapsam: hesap silme isteğinin 14 günlük grace sonrası gerçekten veriye
dönüşüp dönüşmediği — zamanlayıcı, atomik claim, çökme kurtarması, storage
sayfalama, ara hata yolları ve PII'siz denetim izi.

Kanıt dosyaları:

| Uç | Dosya | Kapsam |
| --- | --- | --- |
| Sunucu (Faz 1) | `supabase/migrations/0113_account_purge_scheduler.sql` | scheduler + claim + audit + health |
| Sunucu (Faz 2) | `supabase/migrations/0114_account_purge_pseudonymous_actors.sql` | 7 FK `set null` + takma kimlik |
| Worker | `supabase/functions/purge-accounts/index.ts` | sertleştirilmiş Edge function |
| Sözleşme | `supabase/tests/039_account_purge_scheduler.test.sql` | 28 iddia |
| Sözleşme | `supabase/tests/040_pseudonymous_actor_retention.test.sql` | 12 iddia |
| Politika | `docs/HESAP-SILME-RETENTION-KARARI.md` | §4.1 sınıf tablosu + §5.6 **sahip kararı** |

Kapılar: guard 75/75, release preflight 8/8 (head `0113`, staging `0100`
karşısında fail-closed doğrulandı), Database Gates yeşil — `039` gerçek
Postgres'te 28/28. pgTAP **CI'da** koşar; bu hostta Docker motoru kalkmadığı
için yerel replay yapılamadı.

> **Migration head DÖRT yerde pinli**, üç değil. İlk push'ta Database Gates
> tam bu yüzden kırmızı düştü (`have: 113, want: 112`):
>
> | # | Yer | Ne |
> | --- | --- | --- |
> | 1 | `tooling/release/deploy-contract.json` | `local_migration_head` |
> | 2 | `supabase/tests/001_schema_contract.test.sql:15` | head **string**'i |
> | 3 | `supabase/tests/001_schema_contract.test.sql:10` | migration **sayısı** ← atlanan |
> | 4 | `tooling/supabase/guard.tests.ps1` | diskten türetir (elle güncellenmez) |
>
> 2 ve 3 **aynı dosyada ama ayrı iddialar**; head'i güncelleyip sayıyı
> unutmak sessizce geçmez, doğrudan kırmızı düşer.

---

## 1. Kök bulgu — zamanlayıcı hiç yoktu

`purge-accounts` Edge function'ı WP-113'ten beri repoda duruyordu ve doğru
yazılmıştı, ama **onu çağıran hiçbir şey yoktu**. Tüm repo tarandı:
`purge-accounts` yalnızca belgelerde geçiyordu (`progress.md`, `backlog.md`,
`DATA-SAFETY.md`, `PLAY-RELEASE-GATE.md`). Ne `cron.schedule`, ne workflow, ne
başka bir çağrı.

Kullanıcı akışının gerçek hâli:

| Adım | Beklenen | Gerçek (0113 öncesi) |
| --- | --- | --- |
| 1. İstek | `request_account_deletion()` satır yazar | ✅ çalışıyordu |
| 2. Grace | `purge_after = now() + 14 gün` | ✅ çalışıyordu |
| 3. Purge | worker satırı işler | 🔴 **hiç çalışmadı** |
| 4. Sonuç | hesap silinir | 🔴 satır sonsuza dek `scheduled` |

Karşılaştırma: `dispatch-push` aynı ihtiyacı `0069`'da
`cron.schedule('push-dispatch-retry-worker', ...)` ile çözmüştü. Silme için o
adım hiç atılmamıştı. Bu bir regresyon değil — WP-113'ten beri ölüydü.

`0113` zamanlayıcıyı `0069` deseniyle bağlar: saatlik (`15 * * * *`), runtime
config'ten okunan secret, yapılandırma yoksa sessiz çıkış.

---

## 2. Kapatılan yapısal açıklar

| # | Açık | Eski davranış | 0113 / worker |
| --- | --- | --- | --- |
| 1 | Zamanlayıcı yok | işler hiç başlamıyordu | `account-purge-worker` cron |
| 2 | Claim atomik değil | `select` + `update`, sonuç okunmuyordu → iki worker aynı kullanıcıyı silebilirdi | tek ifadede `for update skip locked` |
| 3 | Çökmüş worker | satır `processing`de asılı, **bir daha hiç** seçilmiyordu | lease dolunca yeniden claim |
| 4 | Sınırsız retry | (3'ün sonucu) sonsuz döngü riski | kurtarma `attempt_count`'u artırır |
| 5 | Storage 100 sınırı | `list(uid, {limit:100})`, gerisi sessizce kalıyordu | sayfalı `purgeAvatars` |
| 6 | Sessiz ara hatalar | e-posta kuyruğu / storage / grup devri / sohbet scrub hiç kontrol edilmiyordu | `must()` her adımda |
| 7 | Tamamlanma izi yok | cascade istek satırını siliyordu, kanıt kalmıyordu | `account_purge_audit` (sha256 uid) |

### 2.1 Sonsuz döngü neden ayrı bir açık

Lease kurtarmasını eklemek tek başına yeni bir hata sınıfı açıyordu: sert
çökme (timeout/OOM) Edge function'ın `catch` bloğunu **hiç çalıştıramaz**,
yani normal hata yolu `attempt_count`'u artıramaz. Kurtarma da artırmasaydı
aynı iş saatte bir, ebediyen yeniden claim edilir ve `p_max_attempts`
güvenliği hiç devreye girmezdi. Bu yüzden claim, **yalnız bayat satırı
kurtarırken** sayacı artırır; normal yola dokunmaz.

---

## 3. Gizlilik — denetim izi

`docs/HESAP-SILME-RETENTION-KARARI.md` §4.1 satır F: *"Admin audit: ≥ 1 yıl
meta (uid hash), PII yok"*. `account_purge_audit` bunu birebir uygular:

- `user_hash` = `encode(sha256(convert_to(uid::text,'UTF8')),'hex')` — ham
  uid, e-posta veya ad **hiçbir sütunda yok**.
- Aynı uid aynı hash → "bu hesap silindi mi" sorusu hukuki talepte
  cevaplanabilir kalır.
- Append-only: `update`/`delete` satır tetiği + `truncate` statement tetiği
  (`0106` desenindeki gibi), `42501` ile reddeder.
- İstemciye tamamen kapalı; okuma bile yok.

> Not: `text::bytea` cast'i PostgreSQL'de **yoktur**. İlk taslak
> `p_user_id::text::bytea` yazıyordu; bu migration'ı apply anında
> "cannot cast type text to bytea" ile düşürürdü. `0106`'daki
> `convert_to(..., 'UTF8')` deyimine çevrildi.

---

## 4. Sözleşme (`039`, 28 iddia)

| Bölüm | İddia | Ne ölçüyor |
| --- | --- | --- |
| 1 | 3 | cron job kayıtlı, doğru fonksiyonu çağırıyor, fonksiyon var |
| 2 | 3 | claim RPC / audit / secret taşıyan config istemciye kapalı |
| 3 | 7 | yalnız vakti gelen claim edilir, ikinci worker alamaz, `skip locked` gerçekten var, vakti gelmemiş ve terminal işler atlanır |
| 4 | 3 | lease dolan iş kurtarılır, kurtarma açıkça bildirilir, sayaç artar |
| 5 | 7 | denetim izi yazılır, PII taşımaz, deterministik hash, geçersiz sonuç reddedilir, append-only |
| 6 | 3 | `not_configured` / `configured` ayrımı, tamamlanan silme sayılır |
| 7 | 2 | 🔴 **kapanmamış blokaj** (§5) |

`plan(28)` dosyadaki iddia sayısıyla eşitlendi — bu turda `plan(26)` yazılmıştı
ve commit öncesi saydırılarak yakalandı.

### 4.1 pgTAP'ta zaman ve görünürlük tuzakları

İki iddia ilk yazımda **sessizce yanlış** olurdu:

1. **`now()` transaction boyunca sabittir.** Claim her seferinde
   `claimed_at = now()` yazdığı için "lease doldu" durumu kısa lease ile
   kurulamaz (`now() < now()` yanlıştır). Her kurtarma denemesinden önce satır
   geriye tarihleniyor.
2. **Aynı ifadede yazıp okuma.** `record_account_purge_outcome` VOLATILE; aynı
   `select`in `where`inden çağrılırsa eklediği satır o ifadenin anlık
   görüntüsünde görünmez — dahası tablo boş olduğu için qual hiç
   değerlendirilmez ve fonksiyon **çalışmaz bile**. Yazma `lives_ok` ile ayrı
   ifadeye alındı.

---

## 5. Faz 2 — blokaj çözüldü (`0114`, sahip kararı uygulandı)

`public` şemasından `auth.users`'a giden **7** adet `not null` +
`on delete restrict` FK, `auth.admin.deleteUser`'ı FK ihlaliyle düşürüyordu:

| Tablo · sütun | Migration | Kimi kapsar |
| --- | --- | --- |
| `feedback_ticket_messages.sender_id` | `0074` | 🔴 **sıradan kullanıcı** (`sender_role` 'user' olabilir) |
| `group_bans.banned_by` | `0093` | ban atmış grup admini |
| `moderation_sanctions.actor_id` | `0105` | yaptırım uygulamış moderatör |
| `moderation_name_resets.reset_by` | `0098` | isim sıfırlamış moderatör |
| `admin_audit_logs.admin_id` | `0020` | admin |
| `announcements.created_by` | `0021` | duyuru yazmış admin |
| `feedback_ticket_notes.admin_id` | `0021` | not yazmış admin |

En ağırı ilk satır: destek biletine **tek mesaj** yazmış sıradan bir kullanıcı
silinemiyordu. Admin uçnoktası değil, geniş bir kitle.

**Sahip kararı (2026-07-31):** *"takma kimlikle korunsun, set null + hash."*
`HESAP-SILME-RETENTION-KARARI.md` §5.6'da kayıtlı. `0114` bunu uygular; her
tablo için aynı desen:

1. `<sütun>_hash` takma kimlik sütunu eklenir, mevcut satırlar doldurulur
2. hash **not null** yapılır → kanıt her zaman atfedilebilir kalır
3. kimlik sütunu nullable yapılır
4. FK `on delete set null` olarak yeniden kurulur (adıyla değil **yapısıyla**
   bulunur; isimler üretilmiş olabilir)
5. tetikleyici hash'i canlı tutar

Hash, `0113` `account_purge_audit.user_hash` ile **aynı inşadır** — operasyon
"bu hesap silindi mi" ile "bu yaptırımı kim verdi" sorularını PII olmadan
eşleştirebilsin diye. `040` bunu ayrı bir iddiayla sabitler.

### 5.1 Tetikleyicideki ince tuzak

`on delete set null` kimlik sütununu NULL'larken satırı **UPDATE eder** ve
hash tetikleyicisini ateşler. Tetikleyici koşulsuz hesaplasaydı hash'i tam da
korunması gereken anda ezerdi. Bu yüzden yalnız kimlik **doluyken** yeniden
hesaplar; NULL'a düşerken mevcut hash'e dokunmaz. `040`'ta bu ayrı bir
iddiadır (`takma kimlik silme sonrası DEĞİŞMEDEN durur`).

### 5.2 Uçtan uca kanıt ve kapsam ayrımı

`040` gerçek bir silme yapar: aktör `auth.users`'tan **silinir**, kanıt satırı
**kalır**, `sender_id` NULL olur, `sender_hash` değişmez.

Senaryo bilerek "başkasının biletine yanıt vermiş kullanıcı" üzerine kurulu.
Çünkü bilet **sahibi** silindiğinde `feedback_tickets.user_id` zaten
`on delete cascade` olduğu için bilet ve tüm mesajları komple gider — bu
doğrudur, kendi içeriğidir. Takma kimliğin korunması yalnız aktör ile içerik
sahibi **farklı** olduğunda gözlenebilir. Aynı ayrım `DATA-SAFETY.md`'ye de
yazıldı: *kendi içeriği silinir, başkasının kaydındaki aktör izi takma
kimlikle kalır.*

### 5.3 İstemci tarafı (null güvenliği)

Sütunlar nullable olunca 4 Dart modeli çökerdi (`map['...'] as String`):
`FeedbackTicketMessage.senderId`, `FeedbackTicketNote.adminId`,
`AdminAuditLog.adminId`, `Announcement.createdBy` → hepsi `String?` yapıldı.

İki çağrı yeri düzeltildi:

- `feedback_tickets_screen.dart` → `own: message.senderId == user?.id` idi.
  Silinen gönderici NULL, oturum açılmamışsa `user?.id` de NULL → `null ==
  null` **doğru** çıkar ve başkasının mesajı "benim" gibi hizalanırdı. Artık
  açık `!= null` şartı var.
- `admin_reports_tab.dart` → silinen admin için mevcut `adminUgcDeletedUser`
  ("Silinmiş kullanıcı") etiketi gösteriliyor; yeni l10n anahtarı eklenmedi.

---

## 6. Kapanmayan ikinci kalem — staging koşu kanıtı

Kart: *"staging scheduler kanıtı olmadan kapanmaz"*. Staging `0100`'de ve
`deploy_enabled=false` (WP-429 fail-closed); release preflight bunu bu turda
da doğruladı. Gerçek koşu kanıtı sahibin GO'sunu ve migration apply'ını
gerektirir. Apply sonrası doğrulama tek çağrı:

```sql
select * from public.get_account_purge_health();
```

`configuration_status` **`not_configured`** dönerse cron kurulu olsa bile
worker hiçbir şey yapmıyordur — `account_purge_runtime_config` satırı
service-role ile yazılmalıdır. Yapılandırılmamış kuyruk sıfır hata üretir ve
"sağlıklı" görünür; bu ayrım staging turunda tek uyarıdır.
