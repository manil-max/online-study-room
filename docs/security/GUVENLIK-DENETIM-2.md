# WP-143 — Güvenlik derin denetimi (WP-109 ötesi)

**Tarih:** 2026-07-18 · **Tür:** araştırma · **Kaynak:** `supabase/migrations/0001–0038` statik tarama

## 1. Envanter (statik)

| Metrik | Değer |
|---|---|
| `public` tablolar (create table) | ~26 (profiles, study_sessions, groups, presence, ugc_reports, xp_ledger, …) |
| Migration’larda `enable row level security` | 14 dosyada (çoğu tablo RLS açıyor; doğrulama SQL ile canlıda teyit) |
| `security definer` fonksiyon | ~39 (grep) |
| Definer header penceresinde `search_path` eksik | **0** (statik; 0036–0038 definer’lar `set search_path = public` kullanıyor) |

## 2. RLS matrisi (özet — kod/migration okuma)

| Tablo / alan | SELECT | INSERT | UPDATE | DELETE | Not |
|---|---|---|---|---|---|
| `profiles` | daraltılmış (0036) | trigger | self | cascade | Enumerasyon riski 0036’da hedeflendi |
| `study_sessions` | `can_see_user_sessions` | owner | limited | owner | Server XP ledger ayrı |
| `groups` / `group_members` | üyelik | RPC create/join | admin | leave/soft | 0032 public discovery RPC |
| `presence` | grup üyesi | self | self | — | updatedAt bayatlama istemci |
| `class_messages` | üyelik | üye | — | scrub purge | UGC |
| `ugc_reports` | reporter / super_admin | RPC | admin | revoke client insert | 0038 |
| `user_blocks` | blocker | RPC | — | RPC | 0038 |
| `account_deletion_requests` | own select | RPC only | RPC | cascade | 0037 |
| `xp_ledger` / achievements | self | **DEFINER only** | guard | — | Server-authoritative |
| `email_job_queue` | service | service | cron | — | Edge secrets |

**Canlıda doğrulanmalı:** her tablo için `pg_policies` dump (SQL Editor).

## 3. Bulgular

### Yüksek / açık

| ID | Bulgu | Kanıt | Öneri WP |
|---|---|---|---|
| S1 | **Client `is_super_admin` / admin UI** RLS’ye güvenir; client flag spoof yetersiz korunursa UI sızıntısı (veri RLS ile kesilmeli) | admin tabs Supabase client select | Canlı RLS smoke |
| S2 | **Storage avatars** policy migration’da (`0002`); path `{uid}/` purge ile siliniyor — list/upload policy’nin “yalnız kendi klasörü” olduğunu canlı teyit | purge-accounts + 0002 | Smoke |
| S3 | **Edge purge/send-report** CRON_SECRET — secret yoksa 401; yanlış deploy = sonsuz fail veya açık kapı | `purge-accounts`, 0035/0036 edge | Ops checklist |

### Orta

| ID | Bulgu | Öneri |
|---|---|---|
| M1 | `get_user_monthly_stats` / rapor IDOR 0036’da sertleştirildi — **regresyon testi** yoksa kırılır | Test WP |
| M2 | Public group discovery RPC çıktısında invite code yok (0032 testleri) — UI’nın ekstra select yapmaması | Code review |
| M3 | UGC `content_snapshot` PII içerebilir; admin kuyruk erişimi super_admin | Retention policy |
| M4 | Flutter `env.json` / dart-define — publishable key istemcide normal; **service_role asla client’ta değil** (grep koru) | CI secret scan |

### Düşük

| ID | Bulgu |
|---|---|
| L1 | Eski definer fonksiyonlar yeniden yazılmış (0024–0027 process_achievement); tarihsel kopya okuma kafa karıştırır — tek kanonik son migration |
| L2 | `search_path` statik pencerede 0 eksik; **yalın SQL function body** içinde dinamik SQL yok mu — manuel review |

## 4. IDOR / grant checklist (canlı)

1. User A, B’nin `study_sessions` / `profiles` select → 0 satır (0036).  
2. User A, B’ye ait `ugc_reports` update → fail.  
3. Non-admin `account_deletion_requests` insert → fail (yalnız RPC).  
4. `block_user` self → exception.  
5. Storage: A, B path’ine upload → fail.

## 5. Önerilen düzeltme WP’leri

| WP | Konu |
|---|---|
| **WP-161** | Canlı RLS-SMOKE otomasyonu (SQL + 2 hesap) |
| **WP-162** | Edge secret/deploy doğrulama runbook CI gate |
| **WP-163** | Admin client path audit (hiç service_role) |
| **WP-164** | UGC snapshot retention / redaction |

## 6. Etiketler

- Migration statik: **Kodda doğrulandı**  
- Canlı policy/edge: **Cihazda/canlıda doğrulanmalı**  
- Ürün retention: **Ürün kararı gerekiyor**
