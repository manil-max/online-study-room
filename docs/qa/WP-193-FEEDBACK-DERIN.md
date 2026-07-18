# WP-193 / WP-195a — Feedback teşhis (GERÇEK kök neden)

| Alan | Değer |
|---|---|
| Tarih | 2026-07-18 (WP-195a güncelleme) |
| Beta URL | `https://jiphfrpzvkpzubbkhrwb.supabase.co` |
| Proje ref | **`jiphfrpzvkpzubbkhrwb`** |
| Aşama | **Kök neden net** · sahip: **0046 SQL** canlıya uygula + cihaz smoke |

---

## 0. GERÇEK kök neden (cihaz kanıtı) — WP-195a

| | |
|---|---|
| **Detay kodu** | **`42704` · `column "role" does not exist`** |
| **Nereden** | AFTER INSERT trigger `on_new_feedback` → `notify_admins_on_feedback()` |
| **Dosya (eski)** | `0029_admin_panel_fixes.sql` satır ~49: `where role = 'super_admin'` |
| **Şema gerçeği** | `app_admins` (0018): yalnız `user_id`, `created_at` — **`role` kolonu YOK** |
| **Etki** | Her `feedback_tickets` INSERT → trigger patlar → **transaction rollback** |
| **Değildi** | PostgREST şema önbelleği (PGRST205), RLS 42501, yanlış proje (birincil) |

**Düzeltme (repo):** `supabase/migrations/0046_fix_feedback_trigger.sql`  
- `create or replace function notify_admins_on_feedback()` — `where role…` **kaldırıldı**  
- `security definer` + `set search_path = public`  
- `notify pgrst, 'reload schema'`

### Sahip aksiyonu (zorunlu)

1. Dashboard proje = `jiphfrpzvkpzubbkhrwb` teyit  
2. SQL Editor’da **`0046_fix_feedback_trigger.sql`** çalıştır  
3. Cihazda feedback gönder → başarı; **42704 yok**

```sql
-- Hızlı doğrulama: fonksiyon tanımında "role" kalmamalı
select pg_get_functiondef('public.notify_admins_on_feedback()'::regprocedure);
```

---

## 1. Eski hipotezler (ikincil / hâlâ kontrol et)

| Hipotez | Ne zaman |
|---|---|
| Yanlış proje SQL | Tablo NULL / migration o projede yok |
| Schema cache PGRST205 | Tablo var, REST eski — 0045 NOTIFY |
| RLS 42501 | Oturum/policy — trigger’dan bağımsız |

### 1.1 Proje ref

| Kontrol | Beklenen |
|---|---|
| Dashboard ref | `jiphfrpzvkpzubbkhrwb` |
| `env.json` SUPABASE_URL | `https://jiphfrpzvkpzubbkhrwb.supabase.co` |

### 1.2 Tablo

```sql
select to_regclass('public.feedback_tickets') as table_ok;
```

### 1.3 Policy smoke

```sql
select has_table_privilege('authenticated', 'public.feedback_tickets', 'insert');
```

---

## 2. Cihaz: Detay kodları (WP-193 UI)

Snackbar:

```text
Detay: <code> <message>
```

| Detay | Anlam | Aksiyon |
|---|---|---|
| **`42704` … `role` does not exist** | **Bozuk trigger (0029)** | **0046 uygula** |
| `42P01` / relation does not exist | Tablo yok | 0044/0045/0046 bu projede |
| `PGRST205` / schema cache | Önbellek | NOTIFY / 0045–0046 |
| `42501` / permission denied / RLS | Oturum/RLS | session; policy |

---

## 3. Kod / migration envanteri

| Dosya | Ne |
|---|---|
| `admin_repository.dart` | Dar `schema_missing`; `feedbackErrorDisplay` (WP-193) |
| `report_issue_dialog.dart` | Detay snackbar (WP-193) |
| `0045_feedback_reload.sql` | Ensure + NOTIFY (önbellek) |
| **`0046_fix_feedback_trigger.sql`** | **Trigger role fix (asıl onarım)** |

---

## 4. Kanıt etiketleri

| İddia | Etiket |
|---|---|
| 42704 + role trigger kodda/dokümanda | `Kodda doğrulandı` |
| 0046 uygulandı + insert başarılı | `Cihazda doğrulanmalı` (sahip) |
| Önceki “önbellek birincil” hipotezi | **Yanlış / ikincil** — 42704 ile çürütüldü |
