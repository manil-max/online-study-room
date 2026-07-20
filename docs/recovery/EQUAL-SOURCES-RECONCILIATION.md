# WP-229 — Eşit Süre Kaynakları ve Güvenli Reconciliation

> Durum: **Kod + local PostgreSQL kapıları geçti; staging apply/owner QA bekliyor.**
> Production: **NO-GO.** WP-232 backup, dry-run, staging soak ve somut kullanıcı
> GO'su olmadan bu migration veya reconciliation production'da çalıştırılmaz.

## Karar ve kanıt sınırı

WP-225/226 adli baseline'ı production'da `group_achievement_weekly.verified_seconds`
kolonunun bulunduğunu, `total_seconds` kolonunun ve 0063 projector sentinel'larının
bulunmadığını kanıtladı. Dolayısıyla önceki `0063_equal_study_sources.sql` taslağı
hiçbir remote'a uygulanmamış yayımlanmamış dosyadır ve aynı numarada yeniden
tasarlanmıştır. Uygulanmış `0051–0062` dosyaları değiştirilmedi.

Yeni 0063 şu korumaları taşır:

- `study_sessions` tek süre gerçeğidir; `source` ve `live_run_id` kazanım
  ayrıcalığı yaratmaz.
- Manuel, uygulama kronometresi, countdown/Pomodoro ve native/widget rotaları aynı
  session süresiyle kişisel metrik, saat XP'si, grup metriği ve başarım sonucunu
  üretir.
- Süre hesabında `duration_seconds` kanoniktir. Tarihsel `end_time-start_time`
  +3 saat drift'i grup/Break Enemy sürelerine hayalet saat eklemez.
- Server-finalized satırların `live_run_id` audit bağı ve 0051 immutable guard'ı
  korunur. Eşit ödül, audit bağını silmek veya verified satırı client DML'ine
  açmak anlamına gelmez.
- Alfa Kurt, Kamp Ateşi, Lokomotif, Lider Kurt ve Mola Düşmanı
  `progress → candidate → pending → claim → append-only ledger` zincirinden geçer.
  Candidate, reward ve ledger unique anahtarları retry'da çift XP'yi engeller.
- Eski verified-only trigger/cron/fonksiyon girişleri kaldırılır; rollout retention
  audit işi korunur. Kritik cron kurulumu hata verirse migration fail eder, exception
  `NOTICE` ile yutulmaz.
- Migration session, live-run, projection, metric progress, reward veya ledger
  satırı silmez ve otomatik toplu backfill çalıştırmaz.

## Shadow → diff → bounded apply

Reconciliation iki ayrı server-only adımdır:

1. `prepare_equal_source_reconciliation(limit, after_user_id)` en fazla 500 kullanıcıyı
   salt-okunur tarar. Kaynak sayısı, session/süre toplamı, mevcut ve shadow Break
   metriği ile etkilenen grup-gün/hafta sayısını private audit tablolarına yazar.
2. Operatör prepared run/diff'i inceler. Aynı run daha sonra
   `apply_equal_source_reconciliation(run_id)` ile uygulanır.
3. Apply başlamadan önce session count, toplam duration, ledger count/XP ve claimed
   reward count yeniden karşılaştırılır. Uygulama aktifken bu baseline değiştiyse
   işlem fail-closed olur; yeni prepare gerekir.
4. Apply yalnız hazırlanan kullanıcı batch'ini idempotent upsert/project eder.
   Kapalı gün/haftalar Europe/Istanbul sınırında finalize edilir; açık dönem yalnız
   project edilir.
5. Apply sonunda aynı append-only invariant'lar ve
   `gamification_profiles.xp = SUM(xp_ledger.xp_amount)` tekrar doğrulanır. Fark
   varsa transaction rollback olur.
6. Uygulanmış run ikinci kez çağrılırsa `0` döner; yeni XP veya reward üretmez.

Private tablolar ve iki operasyon fonksiyonu `authenticated`/`anon` rollerine
kapalıdır. Yalnız migration owner/service role çalıştırabilir. UUID/e-posta/session
satırı evidence dosyasına çıkarılmaz; staging kanıtında yalnız aggregate ve run id
redacted biçimde tutulur.

## Local kabul kanıtı

Pinli Supabase CLI ve PostgreSQL 17 üzerinde:

- boş DB'de `0001–0063` replay + sentetik seed geçti;
- 4 pgTAP dosyasında **80/80** test geçti;
- RLS abuse, internal RPC erişimi, live-run immutability sentinel'ı geçti;
- beş giriş rotası aynı `4 saat`, aynı Break Enemy, aynı grup günlük/haftalık süre
  ve aynı `200 XP` sonucunu verdi;
- +3 saat hatalı `end_time` fixture'ı `duration_seconds=16200` olarak kaldı;
- server-finalized native fixture aynı XP/reward sonucunu üretirken `live_run_id`
  audit bağı ve client mutation koruması kaldı;
- 11 kapalı İstanbul günü ve kapalı ISO haftalarında Alfa/Kamp/Lokomotif/Lider
  Kurt candidate→pending→claim zinciri geçti;
- ikinci claim ve ikinci reconciliation apply `0` XP/işlem üretti;
- aktif session yazısı hazırlanmış run'ı apply öncesinde fail-closed geçersiz kıldı;
- session/duration/ledger/claimed reward kaybı `0`;
- `supabase db lint --local --level error`: hata `0`;
- Flutter source-contract testi: `2/2` geçti.

Evidence kökü `.artifacts/deploy-evidence/` altındadır ve git'e alınmaz.

## Staging terfi kapısı

Staging apply yalnız WP-228 protected akışıyla yapılır:

1. Ayrı staging project ref ve DB secret GitHub `staging` Environment içinde
   bulunur; beta/stable hedef doğrulaması fail-closed geçer.
2. Exact commit SHA ve migration head `0063` doğrulanır.
3. `migration list` + dry-run temizdir; remote reset kullanılmaz.
4. 0063 apply sonrasında linked pgTAP/RLS suite çalışır.
5. Önce küçük bir prepared batch incelenir; baseline değişmediyse bounded apply
   yapılır. Sonraki batch cursor ile hazırlanır.
6. Aynı commit/head'e bağlı beta artefaktında beş süre rotası ve claim akışı gerçek
   cihazda doğrulanır.

Staging project/GitHub Environment henüz owner tarafından kurulmadıysa WP burada
`Staging/owner QA` durumunda park edilir; bu eksik production'a geçiş izni değildir.

## Rollback

Rollback veri silmez. Yeni ileri migration:

- session trigger'larını geçici olarak önceki güvenli projector sürümüne yönlendirir;
- source-neutral finalizer cron'larını durdurur veya önceki fonksiyona yönlendirir;
- yeni prepare/apply çağrılarını revoke eder;
- mevcut session/live_run bağlarını, metric progress'i, candidate/pending/claimed
  reward'ları ve XP ledger'ını aynen bırakır.

Kazanılmış ledger/claim geri alınmaz. Reconciliation sırasında invariant fail'i
transaction rollback ile otomatik geri döner; partial apply kabul edilmez.
