# WP-184 — Feedback "sunucu hazır değil" (PostgREST şema önbelleği)

| Alan | Değer |
|---|---|
| Tarih | 2026-07-18 |
| Aşama | Kod tamamlandı — **sahip aksiyonu + cihaz QA bekliyor** |
| Kök neden | `0044_feedback_ensure.sql` tabloyu kuruyor; `NOTIFY pgrst, 'reload schema'` yok → PostgREST REST API `feedback_tickets`'ı önbellekte görmeyebilir |
| Düzeltme | `supabase/migrations/0045_feedback_reload.sql` (0044 idempotent gövde + NOTIFY) |

---

## 1. Semptom (cihaz)

Kullanıcı geri bildirim gönderince:

> **Geri bildirim sunucusu henüz hazır değil**

Kod eşlemesi (`Kodda doğrulandı`):

- `admin_repository.dart` → `schema_missing` (mesajda `schema cache` / relation missing)
- UI: `feedbackUserMessageForCode('schema_missing')`

---

## 2. Beta bağlandığı Supabase projesi

**`app/env.json` → `SUPABASE_URL`:**

```
https://jiphfrpzvkpzubbkhrwb.supabase.co
```

Proje ref (hostname): **`jiphfrpzvkpzubbkhrwb`**

> Bu URL gizli anahtar değildir; anon key değildir. Yalnız proje kimliği.

---

## 3. Sahip aksiyonu (zorunlu — cihaz düzeltmesi buradan)

### (a) Aynı proje mi?

SQL Editor / CLI ile migration çalıştırdığın Supabase projesi, beta APK'nın bağlandığı
proje ile **aynı** olmalı:

| Kontrol | Beklenen |
|---|---|
| Dashboard URL | `https://supabase.com/dashboard/project/jiphfrpzvkpzubbkhrwb` |
| `env.json` `SUPABASE_URL` | `https://jiphfrpzvkpzubbkhrwb.supabase.co` |
| Farklı projeye SQL attıysan | REST hâlâ eski/boş şema → `schema_missing` devam eder |

**Teyit:** Dashboard sol üst proje adı/ref = `jiphfrpzvkpzubbkhrwb`. Değilse **doğru projeye geç**.

### (b) 0045'i o projede çalıştır

1. Supabase Dashboard → **SQL Editor** (proje: `jiphfrpzvkpzubbkhrwb`)
2. Repo dosyası: `supabase/migrations/0045_feedback_reload.sql` içeriğini yapıştır → **Run**
3. Hata yoksa: tablo/policy ensure + `NOTIFY pgrst, 'reload schema'` tetiklenir
4. Alternatif (CLI, doğru proje linkliyse):

```bash
# projeyi doğrula, sonra
supabase db push
# veya yalnız dosyayı SQL Editor ile uygula
```

### (c) Hızlı smoke (SQL)

```sql
select to_regclass('public.feedback_tickets') as table_ok;
-- table_ok = feedback_tickets

-- İsteğe bağlı: API grant
select has_table_privilege('authenticated', 'public.feedback_tickets', 'insert');
```

### (d) Cihaz doğrulama

1. Beta (aynı `SUPABASE_URL`) ile giriş
2. Profil → Geri bildirim / hata bildir
3. **Beklenen:** başarı snackbar; artık "sunucu hazır değil" yok
4. SQL: `select * from feedback_tickets order by created_at desc limit 5;`

---

## 4. Neden 0044 yetmedi?

| Adım | 0044 | 0045 |
|---|---|---|
| `create table if not exists feedback_tickets` | ✓ | ✓ |
| RLS / policy / grant / storage | ✓ | ✓ |
| `NOTIFY pgrst, 'reload schema'` | **yok** | **var** |

PostgREST şema önbelleği migration anında yenilenmezse REST endpoint tabloyu
"yok" sanır; istemci bunu `schema cache` metniyle `schema_missing`e map'ler.

---

## 5. Geri alma

- `NOTIFY` geri alınamaz; zararsız.
- Tablo/policy silmek üretimde tehlikeli — yapma.
- İstemci mesaj eşlemesi değiştirilmedi (sadece sunucu önbellek).

---

## 6. Kanıt etiketleri

| İddia | Etiket |
|---|---|
| 0045 idempotent + NOTIFY dosyada | `Kodda doğrulandı` |
| Cihazda feedback gönderimi düzeldi | `Cihazda doğrulanmalı` (sahip: 0045 apply + beta smoke) |
| env URL = `jiphfrpzvkpzubbkhrwb` | `Kodda doğrulandı` (`app/env.json`) |
