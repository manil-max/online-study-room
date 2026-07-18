# WP-168 — Feedback “gönderilemedi” tanı + onarım

| Alan | Değer |
|---|---|
| Tarih | 2026-07-18 |
| Semptom | Ayarlar → Geri bildirim gönder → Gönder → **“Geri bildirim gönderilemedi.”** (ek eksiz düz mesaj da) |
| Etiket | `Kodda doğrulandı` (istemci + migration statik) · **canlı SQL / cihaz: sahip** |
| DOKUNMA | Timer / widget / FGS · admin feedback **okuma** akışı |

---

## 1. Semptom ve istemci yolu

```
SettingsScreen._openReportDialog
  → ReportIssueDialog._submit
    → adminRepository.submitFeedback(userId: profile.id, …)
      → SupabaseAdminRepository:
           storage (opsiyonel) + feedback_tickets INSERT + select().single()
```

| Katman | Gözlem (`Kodda doğrulandı`) |
|---|---|
| Dialog | `on AdminException` / `catch (_)` → **jenerik** l10n (eski: gerçek hata yutuluyordu) |
| Repo | `PostgrestException` → `AdminException('Geri bildirim gönderilemedi: ${e.message}')` |
| Regresyon | İstemci submit yolu WP-69/140’tan beri mantıken aynı; **istemci regressiyonu değil**, sunucu/RLS/oturum reddi olasılığı yüksek |

---

## 2. Sunucu sözleşmesi (migration statik)

### 0018 `feedback_tickets` insert policy

```sql
-- feedback_tickets_insert
with check (user_id = auth.uid() and status = 'open')
```

- `auth.uid()` **null** (anon / süresi dolmuş JWT) → RLS reddi → PostgrestException.
- İstemci `user_id` ≠ `auth.uid()` → aynı.
- `status` her zaman `'open'` (kodda sabit) → check OK.

### 0019 ekler

- Kolon: `attachment_path text`
- Bucket: `storage.buckets id = 'feedback_attachments'` (private)
- Storage INSERT: path `auth.uid()/<file>`

Ek **yokken** insert yolu `attachment_path` anahtarını göndermez (null-aware map) → 0019 şart değil düz mesaj için.

---

## 3. Canlı doğrulama (SQL Editor — sahip doldurur)

> Sonuçları bu dosyaya veya release notuna işleyin. `auth.uid()` için **authenticated** oturum gerekir (SQL Editor service role farklı davranır).

```sql
-- 3.1 Tablo + kolon
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'feedback_tickets'
order by ordinal_position;
-- Beklenen: id, user_id, kind, subject, message, status, created_at, updated_at
--           (+ attachment_path eğer 0019 uygulandıysa)

-- 3.2 Policy listesi
select polname, polcmd, pg_get_expr(polqual, polrelid) as using_expr,
       pg_get_expr(polwithcheck, polrelid) as with_check
from pg_policy
join pg_class on pg_class.oid = polrelid
join pg_namespace on pg_namespace.oid = pg_class.relnamespace
where nspname = 'public' and relname = 'feedback_tickets';
-- Beklenen insert: user_id = auth.uid() AND status = 'open'

-- 3.3 GRANT (eksikse INSERT 403/permission denied)
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'feedback_tickets';

-- 3.4 Storage bucket
select id, name, public from storage.buckets where id = 'feedback_attachments';

-- 3.5 (Authenticated kullanıcı JWT ile) duman insert
-- select auth.uid();  -- null ise RLS kesin reddeder
-- insert into public.feedback_tickets (user_id, kind, subject, message, status)
-- values (auth.uid(), 'feedback', 'test', 'wp-168 smoke', 'open')
-- returning id;
```

| Kontrol | Sonuç (sahip) | Not |
|---|---|---|
| Tablo var | ☐ | |
| `attachment_path` | ☐ | 0019 |
| insert policy | ☐ | |
| GRANT authenticated | ☐ | |
| bucket | ☐ | ekli görsel |
| `auth.uid()` cihaz | ☐ | **EN OLASI kök neden** |

---

## 4. Kök neden hipotezleri (öncelik)

| # | Hipotez | Kanıt | Olasılık |
|---|---|---|---|
| H1 | Oturum yok / JWT süresi dolmuş → `auth.uid()` null → RLS | Semptom ek bağımsız; profil stream bazen “stale” görünebilir | **Yüksek** |
| H2 | 0018 policy / tablo canlıda eksik | SQL 3.1–3.2 | Orta |
| H3 | GRANT eksik | SQL 3.3 `permission denied` | Orta |
| H4 | 0019 bucket yok (yalnız **ekli** gönderim) | Düz mesaj da fail → tek başına H4 değil | Düşük (düz mesaj) |
| H5 | İstemci bug (subject/kind map) | normalize + kind.dbValue check ile uyumlu | Düşük |

---

## 5. Kod onarımı (bu WP)

| Değişiklik | Dosya |
|---|---|
| `kDebugMode` log: Postgrest `code/message/details/hint`, Storage `statusCode/message` | `supabase_admin_repository.dart` |
| Gönderim öncesi `currentUser` + `currentSession`; mismatch → `AdminException(code: session_required)` | aynı |
| RLS/JWT sınıflandırma → `session_or_rls` + net mesaj | `admin_repository.dart` `classifyFeedbackSubmitError` |
| Dialog: oturum kodlarında **net** mesaj; diğerleri jenerik l10n; debug log | `report_issue_dialog.dart` |
| Unit: classify + AdminException.code | `admin_repository_test.dart` |

**Not:** Canlı insert’in yeşile dönmesi H1’de yeniden giriş / H2–H3’te sahip SQL’ine bağlıdır. İstemci artık hatayı yutmuyor.

---

## 6. Sahip için hazır SQL (eksik policy/grant/bucket)

> Yalnız SQL Editor’de, migration geçmişine göre **bir kez** uygula. Zaten 0018/0019 uygulanmışsa gerekmez.

```sql
-- A) Policy (0018 ile aynı niyet)
drop policy if exists feedback_tickets_insert on public.feedback_tickets;
create policy feedback_tickets_insert on public.feedback_tickets
  for insert to authenticated
  with check (user_id = auth.uid() and status = 'open');

-- B) GRANT (Supabase varsayılanı bozulduysa)
grant select, insert on public.feedback_tickets to authenticated;

-- C) attachment_path + bucket (0019 özeti)
alter table public.feedback_tickets
  add column if not exists attachment_path text;

insert into storage.buckets (id, name, public)
values ('feedback_attachments', 'feedback_attachments', false)
on conflict (id) do nothing;
```

Storage policy tam metni: `supabase/migrations/0019_feedback_attachments.sql`.

---

## 7. Cihaz kabul (sahip / beta)

| # | Adım | Beklenen |
|---|---|---|
| 1 | Girişli hesap, debug build | Ayarlar → Geri bildirim → düz öneri → **DB’de satır** + başarı snackbar |
| 2 | Aynı + ekran görüntüsü | `feedback_attachments` path + ticket `attachment_path` |
| 3 | Oturumu düşür / token expire simülasyonu | **Net** oturum mesajı (jenerik değil); log’da code |
| 4 | Admin kuyruk | Yeni ticket listede (okuma akışı değişmedi) |

---

## 8. Kabul özeti

| Kriter | Durum |
|---|---|
| Gerçek hata `kDebugMode` log’da | Kodda |
| Kök neden bu MD’de | Evet (H1 birincil; canlı teyit sahip) |
| Oturum → net mesaj | Kodda |
| analyze 0 + ilgili test | Bu WP commit’i |
| Feedback DB’ye düşer | **`Cihazda doğrulanmalı`** (+ SQL 0018/19 teyit) |
