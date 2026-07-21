-- rollback_0065_reprice.sql — WP-255 XP yeniden fiyatlandırmasının TAM GERİ ALIMI
--
-- ⚠️ Bu dosya `supabase/migrations/` ALTINDA DEĞİLDİR ve otomatik uygulanmaz.
--    Yalnız 0065 geri alınmak istenirse, elle çalıştırılacak hazır betiktir.
--
-- NEDEN YEDEK GEREKMİYOR
-- ----------------------
-- 0065 kullanıcıya özgü hiçbir veriyi YOK ETMEZ. Yaptığı tek şey, beş başarımın
-- kademe XP'lerini sabit A değerlerinden sabit B değerlerine taşımaktır. Eski
-- değerler kullanıcı verisi değil, git'te kayıtlı SABİTLERDİR (0056_six_tier_economy.sql).
-- Bu yüzden geri alım, silinmiş bir şeyi kurtarmayı değil, aynı sabitleri geri
-- yazmayı gerektirir — ve o sabitler aşağıda birebir duruyor.
--
-- Türetilen alanlar da kayıpsızdır:
--   * gamification_profiles.xp  = sum(xp_ledger.xp_amount)  → defterden yeniden hesaplanır
--   * crown_rank                = _recalc_crown_rank(xp)     → xp'den türer
--
-- TEK NÜANS: 0065 öncesinde bir profilin `xp` değeri defter toplamından SAPMIŞSA
-- (tarihsel drift), geri alım o sapmayı korumaz; doğru toplamı yazar. Bu, veri
-- kaybı değil normalizasyondur — pgTAP zaten "profile XP equals append-only
-- ledger total" invaryantını şart koşuyor.
--
-- KAPSAM DIŞI: 0065 sonrasında KAZANILAN yeni kademeler bu betikle eski fiyata
-- çekilir (sözlük eski değere döndüğü için tutarlı kalır). Oturum, başarım
-- sahipliği, ödül geçmişi ve grup verisi HİÇ ETKİLENMEZ.

begin;

do $rollback$
declare
  v_ledger integer := 0;
  v_pending integer := 0;
  v_profiles integer := 0;
begin
  perform set_config('app.allow_xp_write', 'on', true);

  -- 1) Sözlüğü 0056'daki değerlere geri al
  update public.achievements_dict set max_tier = 6, tiers =
    '[{"tier":1,"threshold":50,"unit":"hours","xp":100},{"tier":2,"threshold":200,"unit":"hours","xp":500},{"tier":3,"threshold":500,"unit":"hours","xp":1500},{"tier":4,"threshold":1000,"unit":"hours","xp":5000},{"tier":5,"threshold":2500,"unit":"hours","xp":15000},{"tier":6,"threshold":5000,"unit":"hours","xp":45000}]'::jsonb
    where id = 'marathon_total';

  update public.achievements_dict set max_tier = 6, tiers =
    '[{"tier":1,"threshold":60,"unit":"minutes","xp":50},{"tier":2,"threshold":90,"unit":"minutes","xp":100},{"tier":3,"threshold":120,"unit":"minutes","xp":250},{"tier":4,"threshold":180,"unit":"minutes","xp":1000},{"tier":5,"threshold":300,"unit":"minutes","xp":5000},{"tier":6,"threshold":480,"unit":"minutes","xp":15000}]'::jsonb
    where id = 'steel_will';

  update public.achievements_dict set max_tier = 6, tiers =
    '[{"tier":1,"threshold":2,"unit":"day_hours","xp":50},{"tier":2,"threshold":4,"unit":"day_hours","xp":150},{"tier":3,"threshold":6,"unit":"day_hours","xp":500},{"tier":4,"threshold":8,"unit":"day_hours","xp":1500},{"tier":5,"threshold":10,"unit":"day_hours","xp":5000},{"tier":6,"threshold":12,"unit":"day_hours","xp":15000}]'::jsonb
    where id = 'day_hero';

  update public.achievements_dict set max_tier = 6, tiers =
    '[{"tier":1,"threshold":7,"unit":"streak_days","xp":100},{"tier":2,"threshold":30,"unit":"streak_days","xp":2000},{"tier":3,"threshold":150,"unit":"streak_days","xp":5000},{"tier":4,"threshold":365,"unit":"streak_days","xp":20000},{"tier":5,"threshold":730,"unit":"streak_days","xp":50000},{"tier":6,"threshold":1000,"unit":"streak_days","xp":100000}]'::jsonb
    where id = 'fire_streak';

  update public.achievements_dict set max_tier = 6, tiers =
    '[{"tier":1,"threshold":5,"unit":"locomotive_events","xp":150},{"tier":2,"threshold":15,"unit":"locomotive_events","xp":500},{"tier":3,"threshold":30,"unit":"locomotive_events","xp":1500},{"tier":4,"threshold":100,"unit":"locomotive_events","xp":4500},{"tier":5,"threshold":300,"unit":"locomotive_events","xp":15000},{"tier":6,"threshold":600,"unit":"locomotive_events","xp":30000}]'::jsonb
    where id = 'locomotive';

  -- 2) Defter + bekleyen ödüller: yeni fiyat sözlükten okunur (artik ESKI deger)
  create temporary table _rollback_map on commit drop as
    select d.id as achievement_id, (t->>'tier')::integer as tier, (t->>'xp')::integer as xp
    from public.achievements_dict d
    cross join lateral jsonb_array_elements(d.tiers) as t
    where d.id in ('marathon_total','steel_will','day_hero','fire_streak','locomotive');

  create temporary table _rollback_users on commit drop as
    select distinct user_id from (
      select l.user_id from public.xp_ledger l
        join _rollback_map m on m.achievement_id = l.achievement_id and m.tier = l.tier
       where l.xp_amount is distinct from m.xp
      union
      select r.user_id from public.achievement_rewards r
        join _rollback_map m on m.achievement_id = r.achievement_id and m.tier = r.tier
       where r.status = 'pending' and r.xp_amount is distinct from m.xp
    ) s;

  update public.xp_ledger l set xp_amount = m.xp
    from _rollback_map m
   where m.achievement_id = l.achievement_id and m.tier = l.tier
     and l.xp_amount is distinct from m.xp;
  get diagnostics v_ledger = row_count;

  update public.achievement_rewards r set xp_amount = m.xp
    from _rollback_map m
   where m.achievement_id = r.achievement_id and m.tier = r.tier
     and r.status = 'pending' and r.xp_amount is distinct from m.xp;
  get diagnostics v_pending = row_count;

  -- 3) Profil XP + taç
  update public.gamification_profiles g
     set xp = coalesce((select sum(xp_amount) from public.xp_ledger l where l.user_id = g.user_id), 0)::integer,
         crown_rank = public._recalc_crown_rank(
           coalesce((select sum(xp_amount) from public.xp_ledger l where l.user_id = g.user_id), 0)::integer),
         updated_at = now()
   where g.user_id in (select user_id from _rollback_users);
  get diagnostics v_profiles = row_count;

  raise notice 'ROLLBACK 0065: ledger=% pending=% profiles=%', v_ledger, v_pending, v_profiles;
end
$rollback$;

-- Doğrulama: hiçbir defter satırı sözlükle çelişmemeli.
select count(*) as mismatched_rows
from public.xp_ledger l
join public.achievements_dict d on d.id = l.achievement_id
cross join lateral jsonb_array_elements(d.tiers) as t
where d.id in ('marathon_total','steel_will','day_hero','fire_streak','locomotive')
  and (t->>'tier')::integer = l.tier
  and (t->>'xp')::integer is distinct from l.xp_amount;

-- Sonuç 0 değilse COMMIT ETME.
commit;
