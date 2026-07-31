# V57 — Moderasyon kabul kanıtı (WP-443)

**Tarih:** 2026-07-31 · **Kapı:** Database Gates → *Local replay, RLS and
invariant gate* · **Kanıt dosyası:** `supabase/tests/035_moderation_abuse_matrix.test.sql`

Bu belge WP-443'ün abuse/RLS matrisini, matrisin bulduğu açığı ve açığın nasıl
kapatıldığını kayda geçirir. İddiaların hepsi otomatik koşar; burada anlatılan
hiçbir şey "elle denendi" değildir.

> **Uyarı — bu belge kapı değildir.** Kapı `035`tir. Belge yalnız neyin neden
> test edildiğini açıklar. Bir satır burada yazıp `035`te karşılığı yoksa
> kanıt yok demektir.

---

## 1. Matrisin durumu

Kart on iki senaryo istiyordu. Sekizi zaten `026`–`031` içinde kilitliydi;
`035` kalan dördünü ve iki yeni invaryantı ekledi.

| Senaryo | Nerede | Durum |
| --- | --- | --- |
| mesaj raporu | `029` | vardı |
| grup / grup adı raporu | `029` | vardı |
| **profil raporu** | `035` §1 | **yeni** |
| duplicate (aynı hedef tek vaka) | `029` | vardı |
| **blocked users** | `035` §2 | **yeni — açık bulundu** |
| **silinmiş içerik** | `035` §4 | **yeni** |
| yüksek risk (içerik türü) | `030` | vardı |
| **yüksek risk (çok raporlayan)** | `035` §3 | **yeni** |
| karantina | `030` | vardı |
| yaptırım uygula / geri al | `030` | vardı |
| **yaptırım süresi (expiry)** | `035` §5 | **yeni** |
| itiraz | `031` | vardı |
| **kötü niyetli raporlayan** | `035` §7 | **yeni** |
| **iki admin yarışı** | `035` §6 | **yeni** |
| normal kullanıcı admin RPC denemesi | `030` (tek çağrı) → `035` §8 (tüm yüzey) | **genişletildi** |

---

## 2. 🔴 Bulunan açık: engellemek raporlanmaya karşı bağışıklık veriyordu

**Belirti.** `report_ugc`'nin profil dalı hedefin görünürlüğünü
`can_see_user_sessions` ile ölçüyordu. O yardımcı `0095`ten beri
`is_blocked_pair` içerir ve **engel simetriktir**. Sonuç: taciz eden kişi
kurbanını engellediği anda kendi profilini ve adını raporlanamaz hâle
getiriyordu.

**Neden gözden kaçtı.** İki ayrı doğru karar yan yana gelince yanlış oldu:

* `0095` engeli sosyal görünürlüğün tek kaynağı yaptı — oturum, istatistik ve
  profil yüzeyleri için doğru karar;
* `0104` rapor yolunun görünürlük kapısını aynı yardımcıya bağladı — o gün
  makul görünen, fakat raporlamayı "sosyal görünürlük" saymanın hatalı olduğu
  bir kısayol.

Mesaj dalı bu delikten etkilenmiyordu (`is_group_member` bakar). Yani hata tam
olarak **uygunsuz ad/avatar** şikâyetlerini yutuyordu; engellemenin en olası
sebebini.

**Karar.** Bildirim hakkı, bildirilen kişi tarafından geri alınamaz.
`0110_moderation_report_block_immunity.sql` rapor yoluna ayrı bir kapı koydu:

```sql
public.moderation_can_report_profile(p_target uuid)
```

Ortak grup şartı `0095`teki gibi aynen korunur (rastgele yabancı raporlanamaz),
`is_blocked_pair` kontrolü rapor yolundan çıkarılır.

**Kapsam bilinçli olarak dar.** `can_see_user_sessions` değiştirilmedi; engel
oturum/profil/istatistik yüzeylerinde görünürlüğü kesmeye devam eder. `035`
bunu ayrıca iddia eder — düzeltmenin yan etkisi olmadığı da testle bağlıdır:

* `engellenen kullanici engelleyenin profilini YINE DE raporlayabilir`
* `engel sosyal gorunurlugu kesmeye devam eder (can_see_user_sessions bozulmadi)`

---

## 3. Kabul ölçütleri ve nerede ölçüldükleri

| Kart ölçütü | Ölçüm |
| --- | --- |
| **RLS kaçışı 0** | `035` §8: `pg_proc` süpürmesi — `public.admin_*` fonksiyonlarının **hepsi** `is_super_admin` taşımalı. Tek tek `throws_ok` yazmak yeni eklenen bir RPC'yi kaçırır; bu iddia kapısı unutulan ilk fonksiyonda düşer. Yanına "küme boş değil" koruması (≥ 15) kondu ki süpürme sessizce hiçbir şeye bakmasın. |
| **Kayıp audit 0** | `035` §6: uygulanan `suspend_7d` için `admin_audit_logs` satır sayısı tam 1. |
| **Aynı eylemde çift yaptırım 0** | `035` §6: ikinci yönetici aynı yaptırımı kapattığında çağrı idempotent döner, ikinci denetim satırı yazılmaz, hedef başına tek aktif kısıt invaryantı korunur. |
| **Yüksek risk açık kuyruğa SLA ile düşer** | `035` §3: üç ayrı raporlayan → `severity = high`, `sla_due_at <= opened_at + 4h`. |
| **Kapatılan kart filtrelerde tutarlı** | `035` §7: `admin_set_ugc_report_group_status` ile kapatılan vakalar `admin_reporter_abuse_score` sayacına `rejected` olarak yansır. |

---

## 4. Yaptırım süresi — sessiz tuzak

`moderation_sanctions_one_active_idx` yalnız `state in ('pending','applied')`
der; **`expires_at`e bakmaz.** Süresi dolmuş bir kısıt indekste durmaya devam
eder. `admin_begin_moderation_sanction` bu yüzden yeni yaptırım açmadan önce
dolmuş satırı `revoked`a çeker. O adım olmasaydı, süresi dolmuş bir susturması
olan kullanıcıya ikinci yaptırım uygulanmak istendiğinde admin anlaşılır bir
hata yerine ham `23505` görürdü.

`035` §5 bu zinciri uçtan uca sürüyor: uygula → süreyi geçmişe çek → kısıtın
kendiliğinden düştüğünü gör → yeni yaptırımın açılabildiğini gör → dolmuş
satırın silinmeyip `revoked` olarak kayıtta kaldığını gör.

---

## 5. Kanıt dayanıklılığı

`035` §4 hedef mesajı **sildikten sonra** raporların ve
`canonical_snapshot`ın yerinde durduğunu iddia eder. İhlal eden kişi kendi
mesajını silerek kanıtı yok edemez. Kanıt gövdesi aynı anda normal kullanıcıya
kapalı kalır (`0106` sütun grantı; `035` §8 son iddia).

---

## 6. Koşum

```bash
gh workflow run "Database Gates"
```

`035` `pg_prove` sırasına kendiliğinden girer. Beklenen: **29 iddia**, kırmızı 0.

Değişiklikler `0110`u getirdiği için migration head üç yerde birlikte ilerledi:
`tooling/release/deploy-contract.json`, `supabase/tests/001_schema_contract.test.sql`
ve `tooling/supabase/guard.tests.ps1` (yerel head'i dizinden türetir).
**staging/production head `0100`de kaldı** — `0101`–`0110` hiçbir ortama
uygulanmadı, beta preflight bu yüzden hâlâ doğru şekilde fail-closed düşüyor.
