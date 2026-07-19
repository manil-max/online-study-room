-- 0056_six_tier_economy.sql
-- beta-v42 · 6 kademeli ekonomi (WP-A/WP-B) — client `achievement_ledger_engine.dart`
-- ve `progression_visuals.dart` ile birebir ayna.
--
-- Kapsam:
--   1) `_recalc_crown_rank` → 6 taç rütbesi + yeni XP eşikleri
--      (0/20k/75k/200k/500k/1M → bronz/gümüş/altın/elmas/zümrüt/immortal).
--   2) 11 kademeli başarımın `tiers` JSONB + `max_tier=6` güncellemesi
--      (yeni eşik/XP; kaynak: docs/features/BETA-v41-KADEME-XP-KARARLARI.md §3–4).
--   3) Gizli başarım XP güncellemeleri (§3); `secret_1337` (1337 Elite) **tam silme**.
--   4) Mevcut profillerin taçlarını yeni eşiklere hizalama — **XP korunur, reset yok**.
--
-- Önemli sözleşme kararları:
--   • Zaten `xp_ledger`'a yazılmış ödüller **yeniden fiyatlanmaz** (append-only).
--     Yeni tuple değerleri yalnız BUNDAN SONRA geçilen kademelerde geçerlidir.
--     Eşiği düşen kademeler (ör. team_player t5 1000→600, campfire t4 500→300)
--     ileride bir kez ödüllenir; idempotency `event_key` ile korunur.
--   • Taç id anlamı kayıyor: eski `platinum_scholar` ve `ruby_master` artık
--     4. kademe Elmas (`diamond_owl`) rengine düşer; `_recalc_crown_rank` taçları
--     XP'den yeniden türettiği için eski id'ler otomatik yenilenir.
--   • `secret_1337` FK tutan tüm çocuk tablolardan temizlenir, etkilenen
--     kullanıcıların XP'si kalan ledger toplamından yeniden hesaplanır (1337 XP
--     geri alınır), sonra sözlük satırı silinir.
--
-- process_achievement_event / _achievement_metrics BURADA DEĞİŞMEZ (claim
-- birleştirme WP-C, perfect_month 28/30 WP-D, campfire dinamik eşik WP-E).
--
-- Geri alma (Rollback): 0027'deki 5 kademeli `_recalc_crown_rank` ve 0024'teki
-- `tiers` seed'lerine dönülür; silinen `secret_1337` ve XP'si geri gelmez (ileri-yönlü).

-- ---------------------------------------------------------------------
-- 1) 6 kademeli taç eşikleri
-- ---------------------------------------------------------------------
create or replace function public._recalc_crown_rank(p_xp integer)
returns text
language sql
immutable
as $$
  select case
    when p_xp >= 1000000 then 'immortal_legend'
    when p_xp >= 500000 then 'emerald_sage'
    when p_xp >= 200000 then 'diamond_owl'
    when p_xp >= 75000 then 'gold_achiever'
    when p_xp >= 20000 then 'silver_learner'
    else 'bronze_beginner'
  end;
$$;

-- ---------------------------------------------------------------------
-- 2) Kademeli başarım tuple'ları (6 kademe) — client ile birebir
-- ---------------------------------------------------------------------
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
  '[{"tier":1,"threshold":4,"unit":"weekend_goal_days","xp":150},{"tier":2,"threshold":8,"unit":"weekend_goal_days","xp":450},{"tier":3,"threshold":20,"unit":"weekend_goal_days","xp":1000},{"tier":4,"threshold":50,"unit":"weekend_goal_days","xp":3000},{"tier":5,"threshold":100,"unit":"weekend_goal_days","xp":10000},{"tier":6,"threshold":250,"unit":"weekend_goal_days","xp":25000}]'::jsonb
  where id = 'weekend_goal_days';

update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":1,"unit":"perfect_months","xp":2000},{"tier":2,"threshold":3,"unit":"perfect_months","xp":4000},{"tier":3,"threshold":6,"unit":"perfect_months","xp":8000},{"tier":4,"threshold":12,"unit":"perfect_months","xp":16000},{"tier":5,"threshold":24,"unit":"perfect_months","xp":32000},{"tier":6,"threshold":36,"unit":"perfect_months","xp":64000}]'::jsonb
  where id = 'perfect_month';

update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":7,"unit":"group_day_first","xp":1000},{"tier":2,"threshold":30,"unit":"group_day_first","xp":2500},{"tier":3,"threshold":90,"unit":"group_day_first","xp":7500},{"tier":4,"threshold":180,"unit":"group_day_first","xp":15000},{"tier":5,"threshold":360,"unit":"group_day_first","xp":30000},{"tier":6,"threshold":720,"unit":"group_day_first","xp":60000}]'::jsonb
  where id = 'alpha_wolf';

update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":10,"unit":"group_goal_contrib","xp":50},{"tier":2,"threshold":30,"unit":"group_goal_contrib","xp":200},{"tier":3,"threshold":100,"unit":"group_goal_contrib","xp":800},{"tier":4,"threshold":300,"unit":"group_goal_contrib","xp":2500},{"tier":5,"threshold":600,"unit":"group_goal_contrib","xp":8000},{"tier":6,"threshold":1000,"unit":"group_goal_contrib","xp":20000}]'::jsonb
  where id = 'team_player';

update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":10,"unit":"campfire_hours","xp":100},{"tier":2,"threshold":50,"unit":"campfire_hours","xp":400},{"tier":3,"threshold":150,"unit":"campfire_hours","xp":1500},{"tier":4,"threshold":300,"unit":"campfire_hours","xp":5000},{"tier":5,"threshold":600,"unit":"campfire_hours","xp":12000},{"tier":6,"threshold":1000,"unit":"campfire_hours","xp":25000}]'::jsonb
  where id = 'campfire_hours';

update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":5,"unit":"nudge_starts","xp":100},{"tier":2,"threshold":20,"unit":"nudge_starts","xp":400},{"tier":3,"threshold":50,"unit":"nudge_starts","xp":1200},{"tier":4,"threshold":150,"unit":"nudge_starts","xp":4000},{"tier":5,"threshold":500,"unit":"nudge_starts","xp":15000},{"tier":6,"threshold":1000,"unit":"nudge_starts","xp":30000}]'::jsonb
  where id = 'inspiration';

update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":5,"unit":"locomotive_events","xp":150},{"tier":2,"threshold":15,"unit":"locomotive_events","xp":500},{"tier":3,"threshold":30,"unit":"locomotive_events","xp":1500},{"tier":4,"threshold":100,"unit":"locomotive_events","xp":4500},{"tier":5,"threshold":300,"unit":"locomotive_events","xp":15000},{"tier":6,"threshold":600,"unit":"locomotive_events","xp":30000}]'::jsonb
  where id = 'locomotive';

-- ---------------------------------------------------------------------
-- 3) Gizli başarım XP güncellemeleri (tek kademe; threshold=1)
--    last_second (1500) ve matrix (1111) değişmedi — tutarlılık için yine yazılır.
-- ---------------------------------------------------------------------
update public.achievements_dict set tiers = '[{"tier":1,"threshold":1,"unit":"secret_night_owl","xp":2000}]'::jsonb where id = 'secret_night_owl';
update public.achievements_dict set tiers = '[{"tier":1,"threshold":1,"unit":"secret_dawn","xp":2500}]'::jsonb where id = 'secret_dawn';
update public.achievements_dict set tiers = '[{"tier":1,"threshold":1,"unit":"secret_404","xp":5000}]'::jsonb where id = 'secret_404';
update public.achievements_dict set tiers = '[{"tier":1,"threshold":1,"unit":"secret_pi","xp":3147}]'::jsonb where id = 'secret_pi';
update public.achievements_dict set tiers = '[{"tier":1,"threshold":1,"unit":"secret_break_enemy","xp":2500}]'::jsonb where id = 'secret_break_enemy';
update public.achievements_dict set tiers = '[{"tier":1,"threshold":1,"unit":"secret_last_second","xp":1500}]'::jsonb where id = 'secret_last_second';
update public.achievements_dict set tiers = '[{"tier":1,"threshold":1,"unit":"secret_no_limits","xp":5000}]'::jsonb where id = 'secret_no_limits';
update public.achievements_dict set tiers = '[{"tier":1,"threshold":1,"unit":"secret_matrix","xp":1111}]'::jsonb where id = 'secret_matrix';
update public.achievements_dict set tiers = '[{"tier":1,"threshold":1,"unit":"secret_nye","xp":3000}]'::jsonb where id = 'secret_nye';

-- ---------------------------------------------------------------------
-- 4) secret_1337 (1337 Elite) tam silme + etkilenen XP geri hesaplama
--    FK tutan tüm çocuk tablolar temizlenir; ledger silindiği için etkilenen
--    kullanıcıların profil XP'si kalan ledger toplamından yeniden yazılır.
-- ---------------------------------------------------------------------
do $s1337$
begin
  perform set_config('app.allow_xp_write', 'on', true);

  create temporary table _s1337_users on commit drop as
    select distinct user_id from public.xp_ledger where achievement_id = 'secret_1337';

  delete from public.achievement_rewards where achievement_id = 'secret_1337';
  delete from public.achievement_reward_candidates where achievement_id = 'secret_1337';
  delete from public.achievement_metric_progress where achievement_id = 'secret_1337';
  delete from public.achievement_metric_definitions where achievement_id = 'secret_1337';
  delete from public.user_achievements where achievement_id = 'secret_1337';
  delete from public.xp_ledger where achievement_id = 'secret_1337';

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
  where g.user_id in (select user_id from _s1337_users);

  delete from public.achievements_dict where id = 'secret_1337';
end
$s1337$;

-- ---------------------------------------------------------------------
-- 5) Mevcut tüm taçları yeni eşiklere hizala (XP korunur; reset yok)
-- ---------------------------------------------------------------------
do $crown$
begin
  perform set_config('app.allow_xp_write', 'on', true);
  update public.gamification_profiles g
  set crown_rank = public._recalc_crown_rank(coalesce(g.xp, 0)),
      updated_at = now()
  where g.crown_rank is distinct from public._recalc_crown_rank(coalesce(g.xp, 0));
exception
  when undefined_table then null;
end
$crown$;

notify pgrst, 'reload schema';
