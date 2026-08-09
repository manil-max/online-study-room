# Denetim — veritabanı / sunucu yetkilendirme yüzeyi

**Tarih:** 2026-08-09 · **Yapan:** lider · **Kapsam:** `supabase/migrations/**` (124 dosya)
**Yöntem:** belgelere değil **SQL'in kendisine** bakıldı. `progress.md` ve
migration yorumları iddia sayıldı, her iddia ayrıca doğrulandı.

Bu dosya altı alan denetçisinin kapsamadığı yeri tamamlar: **RLS, politika ve
fonksiyon yetkilendirmesi.** Yani "istemci ne okuyabiliyor, ne yazabiliyor".

---

## Özet

**KANAMA: 0 · RİSK: 0 · TEMİZLİK: 1**

Beklediğimden temiz çıktı. Aşağıdaki dört şüpheyi tek tek kovaladım, dördü de
**asılsız** çıktı. Negatif sonuçları da yazıyorum: bir sonraki denetim aynı
yolu baştan taramasın.

---

## Kontrol ettim, SAĞLAM çıktı

### 1. RLS her tabloda açık
77 `create table`, 12'si sonradan düşürülmüş → **65 canlı tablo**. Tabloları
`enable row level security` satırlarıyla eşleştirdim: **RLS'siz canlı tablo
yok**.

### 2. Özel grupların davet kodu SIZMIYOR

Şüphe gerçekti: `0001_initial_schema.sql:148` `groups_select` politikasını
`using (true)` ile açıyor — yani her giriş yapan herkesin grubunu, **davet
kodu dahil** okuyabilirdi.

Ama `0012_group_join_hardening.sql:136-139` bunu **değiştirmiş**:

```sql
create policy groups_select on public.groups
  for select to authenticated
  using (public.is_group_member(id));
```

Yalnız üye olduğun grubu görüyorsun. Sızıntı yok.

### 3. Herkese açık grup keşfi, RLS'i doğru yoldan aşıyor

(2)'nin doğal sorusu: üye olmadığın grubu göremiyorsan keşif nasıl çalışıyor?
Cevap: `discover_public_groups` bir `security definer` RPC
(`0078_discover_groups_by_tz.sql`). Döndürdüğü sütunlar: ad, günlük hedef, üye
sayısı/sınırı, oluşturulma, avatar, saat dilimi. **`invite_code` yok.**
Yani keşif çalışıyor ve kod sızdırmıyor.

### 4. Kullanıcı kendine XP/başarım YAZAMIYOR

- `xp_ledger`: `revoke insert, update, delete … from authenticated, anon`
  (`0024:80`), yalnız `select` verilmiş (`0024:668`).
- `gamification_profiles.xp`: `_guard_gamification_xp_write()` tetikleyicisi
  istemcinin yazımını **geri alıyor** (`new.xp := old.xp`,
  `0043_guard_cosmetics_write.sql:23`).

### 5. RLS'i baypas eden fonksiyonlar istemciye kapalı

213 fonksiyonun **191'i `SECURITY DEFINER`** — yani RLS'i baypas ediyorlar.
36'sında açık bir yetki kontrolü göremedim; **hepsinin `EXECUTE` yetkisi
`revoke` edilmiş**. Yüksek riskli olanları tek tek doğruladım:

| Fonksiyon | Durum |
|---|---|
| `_award_achievement_tier` | revoke edilmiş — çağrılamıyor |
| `_claim_achievement_reward` | revoke edilmiş |
| `_request_scheduled_account_purge` | yalnız `service_role` |
| `claim_account_deletion_jobs` | yalnız `service_role` |
| `_global_timer_v2_snapshot` | `revoke … from public, anon, authenticated` (`0101:324`) |
| `send_feedback_ticket_message` | `authenticated`, ama **yetkilendiriyor**: `auth.uid() is null → session_required`, sonra biletin `user_id`'sini karşılaştırıyor (`0103:130-152`) |

Yani "definer + yetki kontrolü yok + istemci çağırabiliyor" üçlüsünü
sağlayan **tek fonksiyon bulamadım**.

---

## TEMİZLİK — 1 bulgu

### Profil tablosunda iki iç bayrak gereksiz yere herkese açık

- **Belirti:** Giriş yapmış herhangi bir kullanıcı, başka bir kullanıcının
  e-postasının geri döndüğünü (`email_bounced`) ve aylık rapor tercihini
  (`monthly_report_opt_in`) okuyabiliyor.
- **Kanıt:** `0036_security_hardening.sql` `profiles_select … using (true)`;
  sütunlar `0001_initial_schema.sql:15-20` + sonraki `add column` satırları.
  Tabloda **e-posta, telefon veya kimlik bilgisi yok** — sızan şey bu iki
  bayrak.
- **Etki:** Düşük. Kişisel veri değil, ürün içi bir tercih ve teknik bir
  durum bayrağı. Ad/avatar/hedefin görünür olması ürün gereği (liderlik,
  grup listesi, sosyal profil).
- **Öncelik:** `TEMİZLİK`

---

## Ölçmediğim (dürüstçe)

- **Politikaların çalışma zamanı davranışı.** Buradaki her şey SQL metninden
  okundu. Yerel Docker bu makinede kalkmıyor, o yüzden pgTAP koşturulamadı;
  gerçek bir oturumla "başkasının satırını çekebiliyor muyum" denemesi
  yapılmadı.
- **`0124` production'a uygulanmadı.** Bu bilinen ve açık; hesap silme
  canlıda hâlâ çalışmıyor. Bu denetimin konusu değil.
- **Edge Function'ların içi.** Ayrı bir denetçinin alanında.
