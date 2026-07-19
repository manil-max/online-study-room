-- 0060_verified_projection_production.sql
-- beta-v42 · WP-F — Verified grup projeksiyonunu ÜRETİMDE çalıştır (saha #9).
--
-- Sorun: Alfa Kurt hep 0'dı çünkü alpha_wins yalnız **finalized** günleri sayar
-- (0053: `where finalized_at is not null`) ve günleri finalize eden gece görevi
-- (`catch_up_verified_group_days`) üretimde çalışmıyordu (pg_cron kapalı) →
-- pratikte hiçbir gün finalize olmuyordu. Metrik projeksiyonu (real-time trigger)
-- zaten çalışıyor ama finalize olmadan alpha toplanmıyor.
--
-- Çözüm:
--   1) pg_cron'u aç (guarded; plan/izin yoksa migration patlamaz).
--   2) Gece finalizer job'ını zamanla (idempotent; 0053 ile aynı ad/zaman).
--   3) Mevcut backlog için bir kerelik anlık catch-up (best-effort).
--
-- GÜVENLİK: Bu akış yalnız `group_achievement_daily`, `achievement_metric_progress`
-- (idempotent greatest) ve `achievement_reward_candidates` (on conflict do nothing)
-- yazar. **`xp_ledger`'a YAZMAZ** → çift-XP / XP-kaybı riski yoktur. Verified
-- metriğin XP ödülüne dönüşmesi (candidate→pending reward) ayrı, release-gated
-- WP-219 kapsamıdır; bu migration yalnız metriği/finalize'ı üretimde açar
-- (progress görünür + grup sıralaması alpha göstergesi WP-K çalışır).
--
-- Not (izah): Alfa = bir grup-gününde verified toplam süresi **tek başına en
-- yüksek** olan üye o gün 1 alpha-win alır (beraberlikte kimse almaz); başarım =
-- finalized günlerdeki win toplamı.
--
-- Geri alma (Rollback): `cron.unschedule('verified-group-day-finalizer')`.
-- pg_cron extension'ı bırakmak ayrı ops kararıdır; veri geri alınmaz.

-- 1) pg_cron (guarded — bazı planlarda/izinlerde başarısız olabilir).
do $$
begin
  create extension if not exists pg_cron;
exception
  when others then
    raise notice 'pg_cron etkinlestirilemedi (%). Dashboard > Database > Extensions ile acilabilir.', sqlerrm;
end $$;

-- 2) Gece finalizer job'ı (21:05 Europe/Istanbul sunucu saatinden bağımsız; cron
--    UTC/örnek zamanı — 0053 ile aynı). Idempotent: varsa yeniden kurmaz.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if not exists (
      select 1 from cron.job where jobname = 'verified-group-day-finalizer'
    ) then
      perform cron.schedule(
        'verified-group-day-finalizer',
        '5 21 * * *',
        'select public.catch_up_verified_group_days()'
      );
    end if;
  end if;
exception
  when others then
    raise notice 'finalizer job zamanlanamadi (%).', sqlerrm;
end $$;

-- 3) Mevcut backlog için bir kerelik anlık finalize (best-effort, idempotent).
--    Zaten finalize olmuş günleri atlar; bugünü (kapanmamış) dokunmaz.
do $$
begin
  perform public.catch_up_verified_group_days();
exception
  when others then
    raise notice 'anlik catch-up basarisiz (%); gece finalizer job ile tamamlanir.', sqlerrm;
end $$;
