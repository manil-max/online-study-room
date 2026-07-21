-- apply_0065_production_manual.sql
-- WP-255 XP yeniden fiyatlandırmasının PRODUCTION'a ELLE uygulanması.
--
-- NEDEN ELLE: production'da `supabase_migrations.schema_migrations` YOKTUR
-- (docs/recovery/PRODUCTION-BASELINE.md §63). Migration zinciri orada hiç
-- çalışmamıştır, bu yüzden `supabase db push` 0001'den başlamaya çalışıp
-- şema sapmasında durur. Zincirin onarımı WP-232 kapsamındadır ve ayrı bir iştir.
--
-- Bu betik `supabase/migrations/0065_reprice_core_economy.sql` ile AYNI SQL'i
-- taşır; tek farkı açık BEGIN/COMMIT ve sonundaki doğrulama sorgusudur.
-- Staging'de aynısı uygulandı: ledger=5 pending=0 profiles=1.
--
-- NASIL: Supabase panel > production projesi > SQL Editor > hepsini yapıştır > Run.
-- Sondaki doğrulama sorgusu 0 DÖNMEZSE COMMIT ETME (ROLLBACK yaz).
--
-- GERİ ALIM: docs/recovery/sql/rollback_0065_reprice.sql

begin;

-- ---------------------------------------------------------------------
-- 1) Sözlük (yeni kazanımların fiyatı)
-- ---------------------------------------------------------------------
update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":50,"unit":"hours","xp":1500},{"tier":2,"threshold":200,"unit":"hours","xp":5000},{"tier":3,"threshold":500,"unit":"hours","xp":15000},{"tier":4,"threshold":1000,"unit":"hours","xp":30000},{"tier":5,"threshold":2500,"unit":"hours","xp":75000},{"tier":6,"threshold":5000,"unit":"hours","xp":150000}]'::jsonb
  where id = 'marathon_total';

update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":60,"unit":"minutes","xp":500},{"tier":2,"threshold":90,"unit":"minutes","xp":1000},{"tier":3,"threshold":120,"unit":"minutes","xp":1500},{"tier":4,"threshold":180,"unit":"minutes","xp":2500},{"tier":5,"threshold":300,"unit":"minutes","xp":7500},{"tier":6,"threshold":480,"unit":"minutes","xp":15000}]'::jsonb
  where id = 'steel_will';

update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":2,"unit":"day_hours","xp":200},{"tier":2,"threshold":4,"unit":"day_hours","xp":500},{"tier":3,"threshold":6,"unit":"day_hours","xp":1000},{"tier":4,"threshold":8,"unit":"day_hours","xp":2500},{"tier":5,"threshold":10,"unit":"day_hours","xp":7500},{"tier":6,"threshold":12,"unit":"day_hours","xp":15000}]'::jsonb
  where id = 'day_hero';

update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":7,"unit":"streak_days","xp":1000},{"tier":2,"threshold":30,"unit":"streak_days","xp":2500},{"tier":3,"threshold":150,"unit":"streak_days","xp":7500},{"tier":4,"threshold":365,"unit":"streak_days","xp":25000},{"tier":5,"threshold":730,"unit":"streak_days","xp":75000},{"tier":6,"threshold":1000,"unit":"streak_days","xp":150000}]'::jsonb
  where id = 'fire_streak';

update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":5,"unit":"locomotive_events","xp":250},{"tier":2,"threshold":15,"unit":"locomotive_events","xp":750},{"tier":3,"threshold":30,"unit":"locomotive_events","xp":1500},{"tier":4,"threshold":100,"unit":"locomotive_events","xp":4500},{"tier":5,"threshold":300,"unit":"locomotive_events","xp":15000},{"tier":6,"threshold":600,"unit":"locomotive_events","xp":30000}]'::jsonb
  where id = 'locomotive';

-- ---------------------------------------------------------------------
-- 2) Geriye dönük düzeltme
--    (a) kazanılmış defter satırları, (b) henüz "Topla" denmemiş bekleyen
--    ödüller, (c) etkilenen profillerin XP + taç kademesi.
--    Yeni fiyat sözlükten okunur → tek doğru kaynak, elle tekrar yazılmaz.
-- ---------------------------------------------------------------------
do $reprice$
declare
  v_affected integer := 0;
  v_pending integer := 0;
  v_profiles integer := 0;
begin
  perform set_config('app.allow_xp_write', 'on', true);

  -- (id, tier) → yeni xp; yalnız kapsamdaki 5 başarım.
  create temporary table _reprice_map on commit drop as
    select
      d.id as achievement_id,
      (t->>'tier')::integer as tier,
      (t->>'xp')::integer as xp
    from public.achievements_dict d
    cross join lateral jsonb_array_elements(d.tiers) as t
    where d.id in (
      'marathon_total', 'steel_will', 'day_hero', 'fire_streak', 'locomotive'
    );

  -- Etkilenen kullanıcıları ÖNCE topla: hem defterde hem bekleyen ödülde
  -- değeri değişecek olanlar (profil yeniden hesabı bu kümeye uygulanır).
  create temporary table _reprice_users on commit drop as
    select distinct user_id from (
      select l.user_id
        from public.xp_ledger l
        join _reprice_map m
          on m.achievement_id = l.achievement_id and m.tier = l.tier
       where l.xp_amount is distinct from m.xp
      union
      select r.user_id
        from public.achievement_rewards r
        join _reprice_map m
          on m.achievement_id = r.achievement_id and m.tier = r.tier
       where r.status = 'pending' and r.xp_amount is distinct from m.xp
    ) s;

  -- (a) kazanılmış defter satırları
  update public.xp_ledger l
     set xp_amount = m.xp
    from _reprice_map m
   where m.achievement_id = l.achievement_id
     and m.tier = l.tier
     and l.xp_amount is distinct from m.xp;
  get diagnostics v_affected = row_count;

  -- (b) bekleyen (henüz toplanmamış) ödüller — claim edilince yeni değer
  --     bankalanır. 'claimed' satırlara DOKUNULMAZ: onların XP'si zaten
  --     deftere yazıldı ve (a) ile düzeltildi; ikisini birden değiştirmek
  --     çift sayım riski taşır.
  update public.achievement_rewards r
     set xp_amount = m.xp
    from _reprice_map m
   where m.achievement_id = r.achievement_id
     and m.tier = r.tier
     and r.status = 'pending'
     and r.xp_amount is distinct from m.xp;
  get diagnostics v_pending = row_count;

  -- (c) profil XP'si her zaman defterin toplamıdır; taç ondan türetilir.
  update public.gamification_profiles g
     set xp = coalesce(
           (select sum(xp_amount) from public.xp_ledger l where l.user_id = g.user_id),
           0
         )::integer,
         crown_rank = public._recalc_crown_rank(
           coalesce(
             (select sum(xp_amount) from public.xp_ledger l where l.user_id = g.user_id),
             0
           )::integer
         ),
         updated_at = now()
   where g.user_id in (select user_id from _reprice_users);
  get diagnostics v_profiles = row_count;

  raise notice 'WP-255 reprice: ledger=% pending=% profiles=%',
    v_affected, v_pending, v_profiles;
end
$reprice$;


-- ---------------------------------------------------------------------
-- DOĞRULAMA: hiçbir kazanılmış defter satırı sözlükle çelişmemeli.
-- Sonuç 0 olmalı. Değilse: rollback;
-- ---------------------------------------------------------------------
select count(*) as mismatched_rows
from public.xp_ledger l
join public.achievements_dict d on d.id = l.achievement_id
cross join lateral jsonb_array_elements(d.tiers) as t
where d.id in ('marathon_total','steel_will','day_hero','fire_streak','locomotive')
  and (t->>'tier')::integer = l.tier
  and (t->>'xp')::integer is distinct from l.xp_amount;

commit;
