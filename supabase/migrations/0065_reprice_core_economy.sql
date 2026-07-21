-- 0065_reprice_core_economy.sql
-- WP-255: 5 çekirdek başarımın XP'leri yeniden fiyatlandırılır ve düzeltme
-- GERİYE DÖNÜK uygulanır (kazanılmış kademeler de yeni değere yükseltilir).
--
-- Neden geriye dönük: `xp_ledger` append-only bir defterdir ve `xp_amount`
-- kazanım anında dondurulur; yalnız `achievements_dict` güncellenirse mevcut
-- kullanıcılar eski (düşük) XP'de kalır, yeni kullanıcılar yükseği alır —
-- aynı emeğe iki farklı fiyat. Emsal: 0056_six_tier_economy.sql §4.
--
-- Kapsam (yalnız bu 5 kimlik; diğer başarımlar ELLENMEZ):
--   marathon_total  100/500/1500/5000/15000/45000 → 1500/5000/15000/30000/75000/150000
--   steel_will       50/100/250/1000/5000/15000   → 500/1000/1500/2500/7500/15000
--   day_hero         50/150/500/1500/5000/15000   → 200/500/1000/2500/7500/15000
--   fire_streak     100/2000/5000/20000/50000/100000 → 1000/2500/7500/25000/75000/150000
--   locomotive      150/500 → 250/750 (kademe 3-6 değişmedi)
--
-- TÜM DEĞİŞİKLİKLER ARTIŞTIR. Hiçbir kullanıcının XP'si düşmez, dolayısıyla
-- taç kademesi geri gitmez (yalnız yükselebilir).
--
-- İstemci karşılığı: `app/lib/core/stats/achievement_ledger_engine.dart`
-- `kAchievementDictV3` + `app/test/fixtures/progression_economy_v2.json`.
-- Üçü `progression_economy_contract_test.dart` ile birbirine kilitlidir.
--
-- Geri alma (Rollback): Bu migration geri alınmaz. XP geri düşürmek taç
-- kaybettireceği için ürün kararı gerektirir; gerekirse yeni bir ileri
-- migration ile yapılır.

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
