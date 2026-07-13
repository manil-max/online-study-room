-- =====================================================================
-- 0028_xp_reset_general_launch.sql — GENEL YAYIN / herkese açık çıkış öncesi XP temiz sayfa
--
-- ⚠️ BUNU YALNIZCA genel sürüme çıkmadan hemen önce SQL Editor'da çalıştır.
-- Beta test sırasında GEREKMEZ (0027 eşik + saat XP yeter).
--
-- Yaptığı iş:
--   • xp_ledger tamamen silinir
--   • gamification_profiles.xp → 0, crown_rank → bronze_beginner
--   • user_achievements silinir (rozetler de taze başlar)
--
-- Geri alma (Rollback): Geri alınamaz (ledger append-only geçmişi silinir).
-- =====================================================================

-- Ledger (trigger profile xp'yi güncelleyebilir; önce ledger temizle)
truncate table public.xp_ledger;

-- Rozet ilerlemeleri
truncate table public.user_achievements;

-- Cüzdan sıfır
do $$
begin
  perform set_config('app.allow_xp_write', 'on', true);
  update public.gamification_profiles
  set xp = 0,
      crown_rank = 'bronze_beginner',
      selected_badges = coalesce(selected_badges, '{}');
exception
  when undefined_table then null;
  when others then
    -- allow bayrağı yoksa en azından denemeyi logla
    raise notice 'gamification_profiles reset skipped: %', sqlerrm;
end $$;
