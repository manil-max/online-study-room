# WP-226 — Local Migration Baseline ve History Uzlaşması

> Yakalama: 2026-07-20 (Europe/Istanbul)
>
> Local head: `0063` · Production: salt-okunur karşılaştırma
>
> Sonuç: **local replay + SQL test kapısı hazır; production repair/deploy yapılmadı**

## 1. Güvenlik sınırı

- Bu WP yalnız `online-study-room-local` Docker projesinde çalıştı.
- Production'a migration, `migration repair`, backfill, projection/finalizer,
  DDL/DML, deploy veya veri yazımı yapılmadı.
- Kullanıcının isteğiyle doğrudan kurtarma migration'ları ertelendi. Aşağıdaki
  onarım maddeleri yalnız aday/NO-GO kaydıdır; çalıştırılabilir production komutu
  değildir.
- `supabase db reset --linked`, `db push`, remote seed ve kör history repair
  wrapper tarafından sunulmaz.

## 2. Sabit araç zinciri

| Bileşen | Sabitlenen/doğrulanan |
|---|---|
| Supabase CLI | `2.109.1`, root `package.json` + `pnpm-lock.yaml` |
| Paket yöneticisi | `pnpm 11.9.0` |
| Node | `24.14.0` bundled runtime; CLI alt sınırı Node 20 |
| Docker Desktop | `4.82.0`; engine `29.6.1` |
| Local PostgreSQL | Supabase image `17.6.1.143`, major `17` |
| Production PostgreSQL | WP-225 baseline `17.6.1.127`, aynı major |

Kurulum/tekrar kapısı:

```powershell
pnpm install --frozen-lockfile
.\tooling\supabase\local.ps1 baseline
```

Script Docker'ı yalnız local için başlatır ve sırasıyla local start, local reset,
pgTAP çalıştırır. Node PATH'te yoksa Codex bundled runtime'ını bulabilir veya
`-NodePath C:\...\node.exe` verilebilir.

Supabase'in güncel yerel geliştirme akışı config/migration/seed dosyalarının
commit edilmesini, `db reset` ile boş DB replay'ini ve remote hedeflerde
`--local`/`--linked` ayrımının açık tutulmasını önerir:
[Local development workflow](https://supabase.com/docs/guides/local-development/cli-workflows),
[Database testing](https://supabase.com/docs/guides/local-development/cli/testing-and-linting).

## 3. Replay bulguları

İlk ham replay `0053_group_achievement_metrics.sql` içinde durdu:

```text
ERROR: relation "cron.job" does not exist (SQLSTATE 42P01)
```

Tarihsel `0053` yalnız `cron` şemasını kontrol edip `cron.job` tablosunu
varsayıyor. Production baseline'da `pg_cron 1.6.4` zaten kurulu olduğundan,
tarihsel migration değiştirilmeden production-parity ön koşulu
`supabase/roles.sql` içinde local bootstrap olarak kuruldu. `pgcrypto` ve
`uuid-ossp` da production extension baseline'ıyla aynı yerde sabitlendi.

Yeni CLI'nin deprecated `api.auto_expose_new_tables=true` uyumluluk anahtarı
denendiğinde iç `SECURITY DEFINER` fonksiyonlara anon/authenticated EXECUTE de
verdiği görüldü; güvenli olmadığı için kaldırıldı. Bunun yerine yalnız public
tablolar için SELECT/INSERT/UPDATE/DELETE ve sequence kullanımı default grant
edildi. Fonksiyon erişimi her migration'ın kendi REVOKE/GRANT sözleşmesinde
kaldı. Son kanıt:

- anon `break_enemy_metric(uuid)` execute: `false`
- authenticated `catch_up_group_weeks()` execute: `false`
- authenticated `process_achievement_event(text,jsonb)` execute: `true`

Son durumda birden fazla sıfırdan replay başarıyla bitti:

- local history satırı: `63`
- local head: `0063`
- sentetik seed: `2 profile / 2 session`
- cron: `monthly-report-collector`, `group-achievement-day-finalizer`,
  `group-achievement-week-finalizer` — tekrarsız

## 4. Gerçek SQL test kapısı

`supabase test db` sonucu: **3 dosya, 34 test, PASS**.

| Paket | Kanıt |
|---|---|
| `001_schema_contract` | 63/head 0063, PG17, pg_cron, 0063 kolon/trigger sentinel'ları, 20k gümüş sınırı, cron ve RPC izinleri |
| `002_rls_abuse` | üye görünürlüğü; başka kullanıcı adına insert/update reddi; doğrudan XP mint reddi; non-member/anon izolasyonu |
| `003_progression_and_source_parity` | 1 saat live = 1 saat manual; ikisi de 50 saat XP; retry 0; profile XP = ledger; source-neutral weekly projector iki kullanıcıyı işler |

Bu sonuç `0063`ün local şema davranışını kanıtlar; production'a uygulanma izni
veya production verisinde backfill/recompute güveni vermez.

### Lint ile bulunan ileri-fix borcu

`supabase db lint --local --level error`, 0063 sonrasında kalan eski
`project_verified_group_week(uuid,date)` fonksiyonunun artık var olmayan
`group_achievement_weekly.verified_seconds` kolonuna yazdığını yakaladı
(`42703`). 0063 yeni `project_group_week` fonksiyonunu ve yeni cron'u kuruyor,
eski cron'u kaldırıyor; fakat üç eski weekly verified fonksiyonu düşürmüyor.

Bu ölü/bozuk fonksiyon mevcut local rollerde anon/authenticated tarafından
çağrılamaz ve aktif cron tarafından çağrılmaz. Yine de şema temiz değildir.
Tarihsel `0063` bu WP'de değiştirilmedi; explicit drop/revoke ve regresyonu
WP-229 ileri migration adayına bırakıldı.

## 5. Local ↔ production satır bazlı uzlaşma

Production'da `supabase_migrations.schema_migrations` relation'ı yoktur. Bu
nedenle “remote history boş” ifadesi migration'ların hiç çalışmadığını değil,
SQL Editor uygulamalarının CLI tarafından izlenmediğini gösterir. `0001–0050`
için WP-225 ayrı migration sentinel matrisi üretmedi; nesnelerin genel varlığı
tek tek dosyayı veya dosyanın tamamını kanıtlamaz. Bilmediğimiz satırlar
“uygulandı” sayılmadı.

| Sürüm | Dosya | Local | Production semantik kanıt | Repair kararı |
|---|---|---|---|---|
| 0001 | `initial_schema` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0002 | `avatars_storage` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0003 | `subjects_realtime` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0004 | `group_admin` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0005 | `daily_goal` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0006 | `group_goal` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0007 | `group_daily_totals` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0008 | `membership_lifecycle` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0009 | `session_visibility` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0010 | `drop_session_group_id` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0011 | `group_daily_totals_v2` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0012 | `group_join_hardening` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0013 | `presence_membership_hardening` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0014 | `profile_animal` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0015 | `class_chat` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0016 | `nudges` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0017 | `gamification_profiles` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0018 | `admin_feedback` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0019 | `feedback_attachments` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0020 | `super_admin_operations` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0021 | `admin_operations` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0022 | `social_profile_progression` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0023 | `notification_center` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0024 | `achievements_ledger` | PASS | Ledger/profile invariant canlıda sağlam; dosya bütünü kanıtlanmadı | HOLD |
| 0025 | `achievements_social_metrics` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0026 | `crown_five_tiers` | PASS | Sonraki 0056 tarafından geçersiz kılındı; tarih belirsiz | HOLD |
| 0027 | `crown_thresholds_and_hour_xp` | PASS | Sonraki ekonomi mevcut; dosya bütünü kanıtlanmadı | HOLD |
| 0028 | `xp_reset_general_launch` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0029 | `admin_panel_fixes` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0030 | `monthly_report_infrastructure` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0031 | `user_study_summary` | PASS | Hedef süre aggregate'i canlıda okunuyor; dosya bütünü kanıtlanmadı | HOLD |
| 0032 | `public_group_discovery` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0033 | `study_hour_xp_50` | PASS | Canlı ledger'da saat XP anahtarları var; dosya bütünü kanıtlanmadı | HOLD |
| 0034 | `group_members_active_index` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0035 | `cron_report_url_fix` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0036 | `security_hardening` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0037 | `account_deletion_core` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0038 | `ugc_moderation` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0039 | `user_day_totals_rpc` | PASS | Hedef dönem aggregate'i çalışıyor; dosya bütünü kanıtlanmadı | HOLD |
| 0040 | `group_contribution_breakdown` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0041 | `fix_study_sessions_start_time` | PASS | 48 live satırda -10800 sn timestamp drift var | HOLD / veri kararı WP-229 |
| 0042 | `gamification_expand` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0043 | `guard_cosmetics_write` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0044 | `feedback_ensure` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0045 | `feedback_reload` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0046 | `fix_feedback_trigger` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0047 | `achievement_rewards_expand` | PASS | Reward/ledger invariant canlıda sağlam; dosya bütünü kanıtlanmadı | HOLD |
| 0048 | `user_tasks_cloud` | PASS | History yok; ayrı sentinel audit yok | HOLD |
| 0049 | `group_avatar` | PASS | 0054/0055 son durum sentinel'ları var; bu dosya bütünü belirsiz | HOLD |
| 0050 | `achievement_metric_contract` | PASS | Sonraki metric tabloları mevcut; dosya bütünü belirsiz | HOLD |
| 0051 | `verified_live_sessions` | PASS | **PARTIAL/DRIFT:** çekirdek var; retention cron yok | HOLD |
| 0052 | `break_enemy_metric` | PASS | Kritik tablo/view/fonksiyon/trigger mevcut | HOLD — predecessor belirsiz |
| 0053 | `group_achievement_metrics` | PASS | **PARTIAL/DRIFT:** run-finalized fonksiyon+trigger yok | HOLD |
| 0054 | `group_avatar_cleanup_fix` | PASS | Beklenen fonksiyon/trigger absent | HOLD — predecessor belirsiz |
| 0055 | `group_avatar_read_policy_fix` | PASS | Policy hash doğrulandı | HOLD — predecessor belirsiz |
| 0056 | `six_tier_economy` | PASS | 6 kademe, 20k gümüş, XP invariant doğrulandı | HOLD — predecessor belirsiz |
| 0057 | `route_awards_to_inbox` | PASS | Fonksiyon hash+reward invariant doğrulandı | HOLD — predecessor belirsiz |
| 0058 | `perfect_month_28` | PASS | Fonksiyon/dictionary doğrulandı | HOLD — predecessor belirsiz |
| 0059 | `campfire_dynamic_threshold` | PASS | Fonksiyon/tuple var; 0053 drift'i sonucu eksik | HOLD |
| 0060 | `verified_projection_production` | PASS | **PARTIAL/DRIFT:** cron var, run history 0 | HOLD |
| 0061 | `group_alpha_leaderboard` | PASS | Fonksiyon hash doğrulandı | HOLD — predecessor belirsiz |
| 0062 | `weekly_alpha_wolf` | PASS | **PARTIAL/DRIFT:** şema/job var, run 0 ve kapsam eksik | HOLD |
| 0063 | `equal_study_sources` | PASS + 34 test | **ABSENT:** `verified_seconds` var, `total_seconds` yok | PENDING; applied diye repair etme |

## 6. Migration repair hükmü

Şu anda güvenli çalıştırılabilir `migration repair --status applied` listesi:
**boş**.

Sebep:

1. Production history tablosu tamamen yok; 0001–0050 tek tek kanıtlanmadı.
2. 0051, 0053, 0060 ve 0062 partial/drift.
3. History repair şemayı veya veriyi düzeltmez; yalnız CLI defterini değiştirir.
4. Aradaki partial satırlar varken sonraki dosyaları “applied” işaretlemek kör
   `db push` riskini büyütür.
5. 0063 kesin olarak uygulanmamış ve local lint borcu taşıyor.

İleri yol:

1. WP-227 ile beta→staging, stable→production fail-closed ayrımı.
2. WP-228 ile local/staging otomasyonu ve production manual approval gate.
3. WP-229'da yeni ileri migration: explicit API grants, kaynak-eşit ve
   server-authoritative süre/XP/projection zinciri, stale verified weekly
   fonksiyon temizliği, 0053/cron drift onarımı; tarihsel dosyalar değişmez.
4. WP-232'de backup+restore dry-run ve staging soak sonrasında ayrı kullanıcı
   GO'su olursa semantik post-check ile history repair planı yeniden üretilir.

## 7. Kapanış kararı

WP-226'nın hedefi olan güvenli local baseline hazırdır: boş DB zinciri tekrar
kurulur, sentetik veri yüklenir, gerçek RLS/invariant/progression testleri geçer
ve production farkı satır bazında bilinmeyenleri saklamadan kaydedilir.

Production hâlâ freeze altındadır. Bu rapor bir deploy veya veri onarım onayı
değildir.
