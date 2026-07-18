# WP-193 — Feedback hâlâ “sunucu hazır değil”: kesin teşhis

| Alan | Değer |
|---|---|
| Tarih | 2026-07-18 |
| Aşama | Kod: hata detayı + dar sınıflandırma · **sahip SQL teyidi bekliyor** |
| Beta URL | `https://jiphfrpzvkpzubbkhrwb.supabase.co` |
| Proje ref | **`jiphfrpzvkpzubbkhrwb`** |

---

## 1. En olası kök neden

SQL Editor / migration’ları **yanlış Supabase projesine** çalıştırılmış olması.

| Kontrol | Beklenen |
|---|---|
| Dashboard sol üst proje ref | `jiphfrpzvkpzubbkhrwb` |
| `app/env.json` → `SUPABASE_URL` | `https://jiphfrpzvkpzubbkhrwb.supabase.co` |
| Farklı projeye 0044/0045 attıysan | Beta REST hâlâ tabloyu görmez → schema_missing |

**Yap:** Dashboard’da açık projenin ref’inin **birebir** `jiphfrpzvkpzubbkhrwb` olduğunu teyit et. Değilse doğru projeye geç.

---

## 2. O projede SQL kontrolleri

### 2.1 Tablo var mı?

```sql
select to_regclass('public.feedback_tickets') as table_ok;
```

| Sonuç | Anlam |
|---|---|
| `feedback_tickets` | Tablo var → 2.2 |
| `NULL` | Tablo **yok** → bu projede `0044` + `0045` çalıştır |

### 2.2 PostgREST önbellek

Tablo varken REST hâlâ hata veriyorsa:

```sql
NOTIFY pgrst, 'reload schema';
```

veya Dashboard → Project Settings → API → restart (varsa).

Dosya: `supabase/migrations/0045_feedback_reload.sql` (ensure + NOTIFY).

### 2.3 Policy / grant smoke

```sql
select has_table_privilege('authenticated', 'public.feedback_tickets', 'insert');
-- true beklenir
```

---

## 3. Cihaz: gerçek hata kodunu oku (WP-193)

Uygulama artık snackbar’da net mesajın **altında**:

```text
Detay: <code> <message>
```

örnekler:

| Detay | Yorum |
|---|---|
| `42P01 relation "feedback_tickets" does not exist` | Tablo yok — yanlış proje veya 0044 yok |
| `PGRST205 … schema cache` | Tablo var, önbellek eski — NOTIFY / 0045 |
| `42501` / `permission denied` / RLS | Oturum/RLS — `schema_missing` **değil** |

**Sahip:** Cihazda feedback dene → snackbar **Detay** satırını bu rapora yapıştır.

---

## 4. Kod değişiklikleri (WP-193)

| Dosya | Ne |
|---|---|
| `admin_repository.dart` | `classifyFeedbackSubmitError` daraltıldı; `feedbackErrorDisplay` |
| `supabase_admin_repository.dart` | AdminException mesajına ham code+message |
| `report_issue_dialog.dart` | Her zaman detaylı snackbar (release dahil) |

### Sınıflandırma (schema_missing yalnız)

- Kod: `42P01`, `PGRST205`
- Mesaj: `schema cache` · `could not find the table` · `relation … does not exist` + `feedback`

`permission denied for relation feedback_*` → **session_or_rls** (artık schema değil).

---

## 5. Kanıt etiketleri

| İddia | Etiket |
|---|---|
| Detay satırı kodda | `Kodda doğrulandı` |
| Cihazda hangi kod çıktı | `Cihazda doğrulanmalı` (sahip: Detay’ı yaz) |
| Proje ref = jiphfrpzvkpzubbkhrwb | `Kodda doğrulandı` (env) / dashboard teyidi sahip |
