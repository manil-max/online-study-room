# WP-225 — Production Freeze ve Adli Baseline

> Yakalama başlangıcı: 2026-07-20 10:43 (Europe/Istanbul)
> Hedef: `production / read-only`
> Yakalama tamamlanışı: 2026-07-20 12:10 (Europe/Istanbul)
> Durum: **canlı adli baseline tamamlandı — production freeze aktif**
> Kanıt ayrımı: aşağıdaki `Doğrulandı` satırları yerel repo/artefakt kanıtıdır;
> `Bekliyor` satırları canlı Supabase veya bağlı Android cihaz görülmeden doğru
> kabul edilmez.

## 1. Güvenlik sınırı

- Production'da migration, `migration repair`, backfill, RPC/finalizer çağrısı,
  DDL/DML, Edge deploy, secret değişikliği veya release yapılmadı.
- `0063_equal_study_sources.sql` çalıştırılmadı ve production adayı değildir.
- Audit SQL'lerinin her biri `BEGIN ... READ ONLY` ile açılır ve `ROLLBACK` ile
  kapanır. Ham kullanıcı UUID'si, e-posta, oturum satırı veya event key rapora
  dökülmez; yalnız aggregate, invariant ve tanım hash'leri alınır.
- Dashboard/CLI erişim anahtarı, anonim anahtar, DB parolası ve service role
  hiçbir dosyaya veya çıktıya yazılmaz.

## 2. Release ve kaynak kod envanteri

| Kimlik | Commit | Sürüm | Backend kanıtı | Durum |
|---|---|---:|---|---|
| Son stable tag `v39` | `c6843a5da2d0b0bc34905d44b87897fa644df17e` | `1.0.39+39` | Repo tag'i production `env.json` sözleşmesini kullanıyor; artefakt içi provenance yok | Doğrulandı / backend artefakt içinde kanıtlanamıyor |
| Son beta tag `beta-v41` | `e6234a6f5c72d11b0097191f8d9da2a88240c0e1` | `1.0.41+41` | Stable ile aynı production hostuna gidebilen tek env yapısı | Doğrulandı — izolasyon yok |
| Audit başlangıç HEAD | `a088a51d3ba54070d265aa05e2bd25b8b671e6e5` | `1.0.41+41` | `app/env.json` yalnız production hostu içeriyor | Doğrulandı — aynı sürüm/build farklı kodu temsil ediyor |
| `origin/main` | `fb72ed7aebea871a60f7479fcba87bd6d2fbb0b4` | — | Yerel `main` 14 commit ilerideydi | Doğrulandı |

Production hostu: `jiphfrpzvkpzubbkhrwb.supabase.co`. `app/env.json` SHA-256:
`5E8AE5BFEB032509DA39DD22EDB542E670F59CEFEB82E71088CAA95B330C02B7`.
Dosyanın anahtar değeri kaydedilmedi.

### Yerel build çıktıları

Yerel build klasörü kurulu cihazı veya GitHub Release'i temsil etmez ve eskidir:

| Artefakt | Metadata | SHA-256 | Son yazım |
|---|---|---|---|
| `app-beta-release.apk` | `com.manilmax.online_study_room.beta`, `1.0.40-beta+40` | `292B4C9FB13FA391CF0D2C6DFE826B2E8C1E8E2844151D9CC2A994987505051A` | 2026-07-19 19:48 +03 |
| `app-stable-release.apk` | `com.manilmax.online_study_room`, `1.0.23+23` | `5E3948146D3271D8655ADEF845DA29D5AEFD9CCD1A74215CEBB0188DEDC54E8E` | 2026-07-15 14:49 +03 |

Kurulu stable/beta APK sürümü, imza özeti ve APK SHA-256 **Bekliyor**: bu
makinede Android SDK/ADB yok ve bağlı Android cihaz görünmüyor. Tag commit'i ile
kurulu artefaktın aynı olduğu varsayılmayacak.

## 3. Araç ve erişim durumu

| Kontrol | Sonuç |
|---|---|
| Flutter | `3.44.2`, Dart `3.12.2` |
| Android SDK / ADB | Yok; `flutter doctor -v` Android toolchain'i başarısız |
| Supabase CLI | Bundled Node üzerinden geçici/pinli çağrı: `supabase@2.109.1`; login ve project link başarılı |
| Node / npx | Sistem PATH'inde yok; Codex bundled Node `v24.14.0` ve pnpm `11.9.0` ile çalıştırıldı |
| Docker | PATH'te yok |
| Supabase erişimi | CLI doğrulama koduyla oturum açtı; token/DB parolası okunmadı veya rapora yazılmadı |
| Bağlı proje | `jiphfrpzvkpzubbkhrwb` · `online-study-room` · `ap-northeast-1` · `ACTIVE_HEALTHY` · PostgreSQL `17.6.1.127` |
| Dashboard | Kullanıcı doğru production proje başlığında 5 salt-okunur audit paketi + hedef hesap özetini çalıştırdı; sonuçlar JSON olarak doğrulandı |

CLI `migration list --linked` çıktısında yerel `0001–0063` satırlarının tamamının
remote sütunu boştur. Dashboard sorgusu bunun nedenini kesinleştirdi:
`supabase_migrations.schema_migrations` relation'ı production'da **yoktur**.
SQL Editor ile çalıştırılan dosyalar bu nedenle CLI history'ye kaydedilmemiştir;
nesne varlığı migration satırından değil semantik şema kanıtından çıkarılmıştır.
`gen types --linked --schema public` ve Dashboard catalog sorgusu canlı şemaya
erişti ve 0063
sentinel'ını ayırdı: `group_achievement_weekly.verified_seconds` mevcut,
`total_seconds` yoktur. Dolayısıyla **0063 production şemasına uygulanmamıştır**.
0051–0062'nin kritik nesne/hash/cron ve aggregate durumları aşağıdaki matriste
tek tek kaydedilmiştir.

## 4. Yerel migration zinciri parmak izleri

| Dosya | SHA-256 |
|---|---|
| `0051_verified_live_sessions.sql` | `4C54913684DAFEAA57AE60AB4A07B75DE27B3A3F9F8CFC74CE330AA1E8DB8D91` |
| `0052_break_enemy_metric.sql` | `FC42ECE109DA6361D954612E65B2A59A62336F238A3EBF8AB621709B1F4598E4` |
| `0053_group_achievement_metrics.sql` | `F28F543254ACB77EF69A7A3A75BDFE2F6C1E4ED06E01B9B9377E26C5AD123AA7` |
| `0054_group_avatar_cleanup_fix.sql` | `5A97E358D3904F75C8BA75114A371965C9E2DE3DFF9C1FFDA9FA505A308B9CA7` |
| `0055_group_avatar_read_policy_fix.sql` | `882EDB5F2E5F15C5A1B54826EC07114E0E6909A44F845441205DC48A8400985D` |
| `0056_six_tier_economy.sql` | `2F8340070D88AD0B855DE99B6D201F44CD8ED7DC4B30F924BBE238004C0BCC84` |
| `0057_route_awards_to_inbox.sql` | `54936A5EDC456672BFC71243BDAC12261037AB213EB770FD411BB3FFC804CFDA` |
| `0058_perfect_month_28.sql` | `A5BA299D12536C73DD62744DE1D8212B387326DF3688E9E491984F087DA31873` |
| `0059_campfire_dynamic_threshold.sql` | `992CFC45CBF81F3DC0A60E1885DF7B23EEC1829D3877FF7279FCBFE42DE34A43` |
| `0060_verified_projection_production.sql` | `551447E65B2D1A33A420D76803F42365E1A71EDBFE39DC7D15C64201273339EC` |
| `0061_group_alpha_leaderboard.sql` | `E9357F6FE47B0F9B38EB4A741C05265ECC44A3E64B214AE6BB2BCF70739316BE` |
| `0062_weekly_alpha_wolf.sql` | `BC6E8DD8EF76527B12840FBAF40BE6DF851D526B07918385AAEDA827F42E5BB1` |
| `0063_equal_study_sources.sql` (**freeze**) | `6E7FA544E26D5408238F9576B1C67DC55D288FDE3755480C7F06C44D353458A5` |

Bu hash'ler yalnız repodaki dosyayı tanımlar. SQL Editor ile canlıya ne
uygulandığını tek başına kanıtlamaz.

## 5. 0051–0062 canlı kanıt matrisi

| Migration | Beklenen kritik kanıt | Canlı statü |
|---|---|---|
| 0051 | live run/segment tabloları, `study_sessions.live_run_id`, start/pause/resume/finalize RPC, guard trigger, rollout config/cron | **Drift:** tablolar, kolon, lifecycle fonksiyonları ve guard mevcut; 4 run'ın tamamı geçerli/finalized. `verified-session-rollout-retention` cron'u yok. 387/391 session legacy/unlinked; config `shadow_mode=true` |
| 0052 | reward candidate tablosu, break-enemy fonksiyonları/view/trigger | **Doğrulandı:** tablo/view/fonksiyon/segment trigger mevcut; 2 candidate `dormant`, break progress 5 kullanıcıda 0 |
| 0053 | group daily tablo/view/projection/finalizer trigger ve cron | **Kritik drift:** `_verified_group_run_finalized()` ve `live_runs_project_group_metrics` yok; sonraki 0059–0062 bunları kaldırmıyor. Daily projection yalnız 1 grup/1 kullanıcı iken aktif gerçek 3 grup/6 kullanıcı |
| 0054 | `groups_cleanup_avatar_object` trigger+fonksiyonunun **yokluğu** | **Doğrulandı:** ikisi de absent |
| 0055 | `storage.objects.group_avatars_member_read` policy hash'i | **Doğrulandı:** present, MD5 `b3106feb3398820e632c509ed82fec03` |
| 0056 | 6-tier dictionary, `_recalc_crown_rank` hash'i, `secret_1337` referanslarının sıfırı, XP uzlaşması | **Doğrulandı:** 6 kademe; crown `[0,20k,75k,200k,500k,1M]`; `secret_1337` tüm 5 relation'da 0; profil/ledger farkı 0 |
| 0057 | `process_achievement_event` hash'i ve reward/ledger invariant'ı | **Doğrulandı:** fonksiyon MD5 `4d7ee779e0b572165a8b433d81f065fb`; event-key duplicate 0; claimed-without-ledger 0; pending-with-ledger 0 |
| 0058 | perfect-month fonksiyon hash'leri ve dictionary threshold'u | **Doğrulandı:** `_count_perfect_months_28` mevcut; dictionary `1/3/6/12/24/36`, XP `2k/4k/8k/16k/32k/64k` |
| 0059 | `project_verified_group_day` son gövde hash'i ve campfire tuple'ı | **Doğrulandı/işlevsel sonuç driftli:** fonksiyon MD5 `c248ff51501a2717a2ad45181d022264`, dictionary 6-tier; eksik 0053 trigger nedeniyle kapsama eksik |
| 0060 | pg_cron extension, daily finalizer job ve gerçek son koşu statüsü | **Drift:** `pg_cron 1.6.4`, daily job aktif ve doğru fonksiyonu çağırıyor fakat run history 0 |
| 0061 | `group_alpha_scores` fonksiyon hash'i | **Doğrulandı:** present, MD5 `ab3a9827dedcdfaf8847932eb03c7a43` |
| 0062 | weekly tablo/fonksiyonlar/dictionary ve weekly cron son koşusu | **Drift:** şema/fonksiyon/dictionary/job mevcut; job run history 0; weekly projection yalnız 1 grup/1 kullanıcı ve 16 verified saniye |
| 0063 | History; `break_enemy_metric`/`project_group_*` fonksiyonları, `study_sessions_project_*` trigger'ları ve `group_achievement_weekly.total_seconds` sentinel'larının yokluğu | **Uygulanmamış doğrulandı:** remote history boş; canlı tipte `verified_seconds` var, `total_seconds` yok |

## 6. Canlı veri baseline sonuçları

CLI table-stats tahmininin ardından Dashboard sorguları kesin aggregate'ları aldı.
Ham session/ledger/reward satırı değiştirilmedi. Global uzun manuel kayıtların tek
bir test kullanıcısında claim deneyi için bilerek üretildiğini kullanıcı doğruladı;
incident/backfill adayı değildir.

| Invariant | Sonuç | Statü |
|---|---:|---|
| `study_sessions` satır / toplam saniye / aggregate MD5 | `391` / `1,129,188` / `ce845a82546ee076ea15abce4622dd4e` | Doğrulandı — global, test hesapları dahil |
| Negatif süre / ters zaman | `0 / 0` | Doğrulandı |
| Duration–wallclock farkı | 48 live satırda tam `-10,800 sn`; 6 kullanıcı, 13–18 Temmuz | **UTC/İstanbul timestamp drift**; duration kaybı değil fakat overlap/day projection riski |
| Profil XP toplamı / ledger XP toplamı / uyuşmayan kullanıcı | `80,514 / 80,514 / 0` | Doğrulandı |
| Duplicate ledger/reward | event key `0`, reward tuple `0`; tekrar eden 5 user-tier grubunun tamamı idempotent anahtarlı `study_hour_xp` | Doğrulandı — çift XP kanıtı yok |
| Reward/candidate | claimed `2` (`30,000 XP`), pending `1` (`2,500 XP`), candidate dormant `2`; orphan invariant `0` | Doğrulandı |
| Daily projection kapsamı | 1 satır / 1 grup / 1 kullanıcı; gerçek aktif 3 grup / 6 kullanıcı | **Kritik eksik** |
| Weekly projection kapsamı | 1 satır / 1 grup / 1 kullanıcı / 16 verified sn | **Kritik eksik** |
| Cron | daily+weekly aktif/doğru command fakat run `0`; retention absent | **Drift** |

### Hedef production hesabı (`xp=12,500`, tek eşleşme)

UUID raporlanmadan alınan kişisel aggregate:

| Dönem | Kesin süre |
|---|---:|
| Lifetime | `156,814 sn` = **43 sa 33 dk 34 sn** |
| Temmuz | `156,709 sn` = **43 sa 31 dk 49 sn** |
| Son 7 gün | `107,230 sn` = **29 sa 47 dk 10 sn** |
| 19 Temmuz | `36,005 sn` = **10 sa 00 dk 05 sn** |
| 20 Temmuz / takvim haftası | `2,188 sn` = **36 dk 28 sn** |

Hedef hesapta uzun manuel kayıt yoktur; lifetime `117 live + 56 manual = 173`
session'dır. “Hafta” ekranının Pazartesi başlayan takvim haftası olması nedeniyle
20 Temmuz Pazartesi günü `today` ile aynı görünmesi veri kaybı değildir. Kullanıcının
ilk gördüğü ~34 dakika ile sorgu anındaki 36:28 farkı arada eklenen 120 saniyelik
manuel kayıtla tutarlıdır. “Son 7 Gün” ayrı bir ürün dönemi olarak WP-231'de
görünür yapılacaktır.

### Adli hüküm

1. Hedef hesabın session ve XP gerçeği korunmuştur; production backfill/delete
   yapılmaz.
2. `12,500/25,000` metni ve ~%16.7 bar eski 5-tier istemci hesabıdır; canlı DB
   20k eşiğindedir. Kurulu beta artefaktının repo HEAD olmadığı kanıtlanmıştır.
3. Kaynak eşitliği production'da yoktur: verified-only grup/break projeksiyonları
   aktiftir ve 0063 uygulanmamıştır.
4. Grup kullanıcılarının kaybolması ham üyelik/session kaybı değil; eksik 0053
   trigger/fonksiyon + hiç koşmamış cron + verified-only kapsama bağlı projection
   eksikliğidir.
5. History repair, projection recompute ve eşit-kaynak migration'ı backup/local/
   staging kanıtı olmadan production'da çalıştırılmaz.

## 7. Backup ve uygulanabilir recovery yolu

CLI backup envanteri `backups=null`, `pitr_enabled=false`, `walg_enabled=true`
döndürdü. Bu, CLI tarafından seçilebilir backup bulunmadığını ve PITR'ın kapalı
olduğunu doğrular; WAL-G backend bayrağı tek başına geri yüklenebilir kullanıcı
backup'ı kanıtı değildir. Dashboard planı henüz görülmediği için gerçek plan
**Bekliyor**. Güncel Supabase
dokümantasyonuna göre Free projelerde otomatik indirilebilir backup ve PITR yoktur;
regular CLI `db dump` ile harici yedek önerilir. Pro/Team/Enterprise projelerde
günlük backup vardır; PITR ayrıca etkinleştirilen ücretli bir eklentidir.

Production mutasyonundan önce zorunlu recovery paketi:

1. Dashboard'dan gerçek plan, Database Backups ve PITR durumu görüntülenir.
2. Free ise kimlik bilgileri loglanmadan `supabase db dump`/`pg_dump` ile schema
   ve data export alınır; dosya repo dışında tutulur, SHA-256 ve restore provası
   staging/local üzerinde kaydedilir.
3. Ücretli günlük backup/PITR varsa en erken/son restore noktası kaydedilir;
   yine de migration öncesi mantıksal export ve restore provası yapılır.
4. Restore doğrudan production üstüne denenmez. Yeni local/staging projeye restore
   provası başarılı olmadan WP-232 production GO paketi oluşmaz.

`supabase db dump --linked` denemesi Docker olmadığı için başlamadı; oluşan dosya
0 bayttı ve kanıt/yedek sayılmadı. Production'dan veri export edilmedi.

Kaynaklar: [Supabase Database Backups](https://supabase.com/docs/guides/platform/backups),
[Supabase Production Checklist](https://supabase.com/docs/guides/deployment/going-into-prod).

## 8. Tekrar çalıştırma sırası

SQL Editor'da yalnız production proje başlığı doğrulandıktan sonra, dosyalar ayrı
ayrı ve sırayla çalıştırılır:

1. `read_only_00_preflight.sql`
2. `read_only_01_catalog.sql`
3. `read_only_02_core_invariants.sql`
4. `read_only_03_projection_invariants.sql`
5. `read_only_04_history_and_cron.sql`

2026-07-20'de beş paket sırayla ve `transaction_read_only=on` kanıtıyla
çalıştırıldı; hedef hesap için ek anonim aggregate sorgusu alındı. Her sonuç
aggregate/hash olarak bu rapora işlendi. Bir dosya
relation/permission hatası verirse düzeltme çalıştırılmaz; hata nesnenin
`ABSENT/UNREADABLE` kanıtı olarak kaydedilir. Özellikle
`catch_up_verified_group_days()`, `catch_up_verified_group_weeks()` ve hiçbir
projection/finalizer RPC'si bu audit sırasında çağrılmaz.

## 9. Freeze tabelası

**NO-GO:** WP-225 sonucu WP-226 local replay/history uzlaşmasına devredildi.
WP-232 kullanıcı GO kapısına kadar `0063`, production migration/history repair,
projection recompute/backfill ve stable release yoktur.
