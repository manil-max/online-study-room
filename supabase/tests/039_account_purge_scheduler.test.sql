-- 039_account_purge_scheduler.test.sql
-- WP-464: hesap silme purge zincirinin sunucu sozlesmesi.
--
-- En onemli iddia en basta: ZAMANLAYICI VAR MI. `purge-accounts` Edge
-- function'i WP-113'ten beri repoda duruyordu ama onu cagiran hicbir sey
-- yoktu; kullanicinin silme istegi 14 gun sonra hicbir seye donusmuyordu.
-- `0113` o halkayi bagladi ve bu dosyanin ilk testi tam olarak onu olcuyor --
-- cunku bir daha sessizce kopmasin.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'

-- Bu dosyaya ozel iki ek kullanici: "vakti gelmemis" ve "terminal failed"
-- vakalari icin ayri kimlik gerekiyor (kullanici basina tek aktif istek
-- kisiti var).
insert into auth.users (id, email, raw_user_meta_data)
values
  ('10000000-0000-0000-0000-0000000000c1', 'fixture-c1@example.invalid', '{}'::jsonb),
  ('10000000-0000-0000-0000-0000000000c2', 'fixture-c2@example.invalid', '{}'::jsonb)
on conflict (id) do nothing;

\set gamma '10000000-0000-0000-0000-0000000000c1'
\set delta '10000000-0000-0000-0000-0000000000c2'

select plan(28);

-- ===========================================================================
-- 1. EKSIK HALKA: zamanlayici
-- ===========================================================================
select ok(
  exists (select 1 from cron.job where jobname = 'account-purge-worker'),
  '🔴 purge worker cron job KAYITLI (WP-464 oncesi hicbir zamanlayici yoktu)'
);
select is(
  (select command from cron.job where jobname = 'account-purge-worker'),
  'select public._request_scheduled_account_purge()',
  'cron job dogru fonksiyonu cagiriyor'
);
select ok(
  to_regprocedure('public._request_scheduled_account_purge()') is not null,
  'zamanlayicinin cagirdigi fonksiyon gercekten var'
);

-- ===========================================================================
-- 2. Yetki yuzeyi
-- ===========================================================================
select ok(
  not has_function_privilege(
    'authenticated', 'public.claim_account_deletion_jobs(integer,integer,integer)', 'execute'
  ),
  'claim RPC istemciye kapali'
);
select ok(
  not has_table_privilege('authenticated', 'public.account_purge_audit', 'select')
    and not has_table_privilege('authenticated', 'public.account_purge_audit', 'insert'),
  'denetim tablosu istemciye tamamen kapali'
);
select ok(
  not has_table_privilege('authenticated', 'public.account_purge_runtime_config', 'select'),
  'calisma zamani yapilandirmasi (secret tasiyor) istemciye kapali'
);

-- ===========================================================================
-- 3. Atomik claim
-- ===========================================================================
-- alpha: vakti gelmis; gamma: vakti GELMEMIS; delta: terminal failed.
insert into public.account_deletion_requests
  (id, user_id, status, requested_at, purge_after, attempt_count, idempotency_key)
values
  ('40000000-0000-0000-0000-000000000001', :'alpha', 'scheduled',
   now() - interval '15 days', now() - interval '1 day', 0, 'k-alpha'),
  ('40000000-0000-0000-0000-000000000003', :'gamma', 'scheduled',
   now(), now() + interval '10 days', 0, 'k-gamma'),
  ('40000000-0000-0000-0000-000000000004', :'delta', 'failed',
   now() - interval '30 days', now() - interval '5 days', 5, 'k-delta');

select is(
  (select count(*)::int from public.claim_account_deletion_jobs(10)),
  1,
  'yalniz vakti gelmis ve deneme hakki kalan is claim edilir'
);
select is(
  (select status from public.account_deletion_requests
   where id = '40000000-0000-0000-0000-000000000001'),
  'processing',
  'claim edilen is ayni ifadede processing olur'
);
select ok(
  (select claimed_at is not null from public.account_deletion_requests
   where id = '40000000-0000-0000-0000-000000000001'),
  'claim lease damgasi yazilir'
);

-- 🔴 Ikinci worker ayni isi GORMEZ. Gercek `for update skip locked` yarisini
-- tek transaction'da kuramayiz (iki ayri oturum gerekir); burada olculen
-- mantiksal esdegeri: claim edilmis is artik uygun aday degildir. Kilit
-- davranisinin kendisi `skip locked` ifadesinin varliginda durur ve asagida
-- ayrica denetleniyor.
select is(
  (select count(*)::int from public.claim_account_deletion_jobs(10)),
  0,
  'claim edilmis is ikinci worker tarafindan tekrar alinmaz'
);
select ok(
  (select prosrc like '%for update skip locked%'
   from pg_proc where proname = 'claim_account_deletion_jobs'),
  'claim gercekten `for update skip locked` kullaniyor (yaris korumasi)'
);

select is(
  (select status from public.account_deletion_requests
   where id = '40000000-0000-0000-0000-000000000003'),
  'scheduled',
  'vakti gelmemis is claim edilmedi'
);
select is(
  (select status from public.account_deletion_requests
   where id = '40000000-0000-0000-0000-000000000004'),
  'failed',
  'deneme hakki bitmis terminal is bir daha claim edilmez'
);

-- ===========================================================================
-- 4. Cokmus worker kurtarmasi
-- ===========================================================================
-- 🔴 WP-464 oncesi bu satir SONSUZA DEK kayipti: claim yalniz
-- scheduled/failed seciyordu, `processing`de asili kalan is bir daha hic
-- gorulmuyordu. Lease suresi dolunca yeniden claim edilebilmeli.
--
-- NOT: pgTAP dosyasi TEK transaction'dir ve `now()` transaction boyunca
-- SABITTIR. "Lease doldu" durumu bu yuzden beklemeyle degil satiri geriye
-- tarihleyerek kurulur. Claim her seferinde `claimed_at = now()` yazdigi icin
-- her kurtarma denemesinden ONCE yeniden bayatlatmak gerekir; kisa lease
-- (`p_lease_seconds => 0`) ise ise yaramaz, cunku `now() < now()` yanlistir.
update public.account_deletion_requests
set claimed_at = now() - interval '2 hours',
    updated_at = now() - interval '2 hours'
where id = '40000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.claim_account_deletion_jobs(10)),
  1,
  'lease suresi dolan processing isi yeniden claim edilir'
);

-- Yukaridaki claim `claimed_at`i tekrar now()'a cekti; ikinci kurtarma icin
-- yeniden bayatlat.
update public.account_deletion_requests
set claimed_at = now() - interval '2 hours',
    updated_at = now() - interval '2 hours'
where id = '40000000-0000-0000-0000-000000000001';

select ok(
  (select recovered_from_stale
   from public.claim_account_deletion_jobs(10)
   limit 1),
  'kurtarilan is bunu acikca bildirir (sessiz yeniden deneme degil)'
);

-- 🔴 Sonsuz dongu korumasi. Sert cokme (timeout/OOM) Edge function'in `catch`
-- blogunu HIC calistiramaz, yani normal hata yolu sayaci artiramaz. Kurtarma
-- da artirmasaydi lease mekanizmasi ayni isi saatte bir ebediyen yeniden
-- claim eder, `p_max_attempts` guvenligi hic devreye girmezdi.
select is(
  (select attempt_count from public.account_deletion_requests
   where id = '40000000-0000-0000-0000-000000000001'),
  2,
  'her cokme kurtarmasi deneme sayacini artirir (sinirsiz retry yok)'
);

-- ===========================================================================
-- 5. Denetim izi: PII yok, degistirilemez
-- ===========================================================================
-- Yazma AYRI ifadede olmali. `record_account_purge_outcome` VOLATILE'dir ve
-- ayni SELECT'in icinden cagrilirsa ekledigi satir o ifadenin anlik
-- goruntusunde GORUNMEZ; dahasi tablo bos oldugu icin qual hic
-- degerlendirilmez ve fonksiyon calismaz bile. `lives_ok` hem yazar hem tek
-- iddia sayilir.
select lives_ok(
  format(
    $$select public.record_account_purge_outcome(%L, %L, 'completed', 1, null, now())$$,
    '40000000-0000-0000-0000-000000000001',
    :'alpha'
  ),
  'tamamlanma izi yazilabilir (cascade istek satirini silse bile kalir)'
);

select is(
  (select outcome from public.account_purge_audit
   where request_id = '40000000-0000-0000-0000-000000000001'),
  'completed',
  'denetim satiri sonucu completed olarak tasir'
);

select ok(
  (select bool_and(
     char_length(user_hash) = 64 and user_hash <> :'alpha'
   ) from public.account_purge_audit),
  'denetim satiri ham uid tasimaz: yalniz 64 haneli sha256'
);

-- Ayni kullanici ayni hash: hukuki bir talepte "bu hesap silindi mi"
-- sorusu cevaplanabilir kalmali.
select is(
  (select count(distinct user_hash)::int from public.account_purge_audit),
  1,
  'ayni uid ayni hash uretir (deterministik takma kimlik)'
);

select throws_ok(
  format(
    $$select public.record_account_purge_outcome(null, %L, 'deleted_maybe')$$,
    :'alpha'
  ),
  'P0001',
  'account_purge_audit_invalid_outcome',
  'tanimsiz sonuc degeri kabul edilmez'
);

-- SQLSTATE verilen throws_ok'ta repo konvansiyonu 4 argumandir
-- (sql, errcode, errmsg, aciklama) -- bkz. 002/005.
select throws_ok(
  $$update public.account_purge_audit set outcome = 'failed'$$,
  '42501',
  'account_purge_audit_append_only',
  'denetim satiri degistirilemez (append-only)'
);
select throws_ok(
  $$delete from public.account_purge_audit$$,
  '42501',
  'account_purge_audit_append_only',
  'denetim satiri silinemez (append-only)'
);

-- ===========================================================================
-- 6. Saglik gorunumu
-- ===========================================================================
-- Yapilandirilmamis kuyruk sifir hata uretir ve "saglikli" gorunur; bu ayrim
-- staging kanit turunda tek uyaridir.
select is(
  (select configuration_status from public.get_account_purge_health()),
  'not_configured',
  'yapilandirma yokken saglik acikca not_configured der'
);

insert into public.account_purge_runtime_config (singleton, functions_base_url, cron_secret)
values (true, 'https://example.invalid', 'secret')
on conflict (singleton) do update
  set functions_base_url = excluded.functions_base_url,
      cron_secret = excluded.cron_secret;

select is(
  (select configuration_status from public.get_account_purge_health()),
  'configured',
  'yapilandirma yazilinca saglik configured olur'
);
select is(
  (select purged_last_30d from public.get_account_purge_health()),
  1,
  'saglik son 30 gunde tamamlanan silmeyi sayar'
);

-- ===========================================================================
-- 7. BILINEN BLOKAJ — sahip retention karari bekliyor (WP-464 kapanmadi)
-- ===========================================================================
-- 🔴 `public` semasindan auth.users'a giden YEDI adet `not null` +
-- `on delete restrict` FK var:
--   admin_audit_logs.admin_id (0020) · announcements.created_by (0021) ·
--   feedback_ticket_notes.admin_id (0021) ·
--   feedback_ticket_messages.sender_id (0074) · group_bans.banned_by (0093) ·
--   moderation_name_resets.reset_by (0098) ·
--   moderation_sanctions.actor_id (0105)
--
-- Sonuc: bu satirlardan birine dokunmus hesap `auth.admin.deleteUser` ile
-- SILINEMEZ; FK ihlali purge'u dusurur, is 5 denemeyi yakar ve terminal
-- `failed` olur.
--
-- En agiri `feedback_ticket_messages`: `sender_role` HEM 'admin' HEM 'user'
-- olabiliyor, yani destek biletine tek mesaj yazmis SIRADAN bir kullanici da
-- silinemez. Bu bir admin ucnoktasi degil, genis bir kitle.
--
-- `0113` zamanlayiciyi bagladigi icin bu isler artik SESSIZCE hic kosmuyor
-- olmaktan cikip GORUNUR sekilde basarisiz olacak (audit + health). Kullanici
-- acisindan sonuc hala "hesap silinmedi" -- Play veri guvenligi beyaniyla
-- celisir ve WP-464 bu yuzden KAPANMIYOR.
--
-- Bu bir politika sorusudur, kod hatasi degil: kanit korunacaksa FK'ler
-- `set null` + takma kimlik (hash) olmali, korunmayacaksa `cascade`.
-- `docs/HESAP-SILME-RETENTION-KARARI.md` §5 onay kutulari BOS ve §4.1 sinif
-- tablosunda bu siniflarin cogu hic yok -> karar verilmemis. Kart "urun
-- sahibi retention kararini uydurmaz" dedigi icin burada yalniz SABITLENIYOR;
-- karar uygulaninca bu iddialar kasten kirilir.
select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where c.contype = 'f'
      and c.confdeltype = 'r'
      and c.confrelid = 'auth.users'::regclass
      and n.nspname = 'public'
      and t.relname = 'feedback_ticket_messages'
  ),
  '🔴 destek bileti mesaji yazmis SIRADAN kullanici hala silinemez (0074 restrict FK)'
);

-- Alt sinir olarak yazildi: yeni bir restrict FK eklenirse test yesil kalir
-- ama BIRI bile duzeltilirse kirmiziya doner -- istenen davranis bu.
select ok(
  (select count(*)
   from pg_constraint c
   join pg_class t on t.oid = c.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   where c.contype = 'f'
     and c.confdeltype = 'r'
     and c.confrelid = 'auth.users'::regclass
     and n.nspname = 'public') >= 7,
  '🔴 hesap silmeyi blokleyen restrict FK sinifi duruyor (>= 7, sahip karari bekliyor)'
);

select * from finish();
rollback;
