-- 0043: Gamification genişletme (WP-154)
--
-- - cosmetics jsonb (self-read gamification_profiles üzerinden; client INSERT/UPDATE XP yok)
-- - achievements_dict vitrin satırları (ledger process_event eşlemesi sonraki; XP client yazılmaz)
--
-- Geri alma:
--   alter table public.gamification_profiles drop column if exists cosmetics;
--   delete from public.achievements_dict where id in
--     ('quest_daily_login','quest_weekly_hours','cosmetic_frame_bronze');

alter table public.gamification_profiles
  add column if not exists cosmetics jsonb not null default '{}'::jsonb;

comment on column public.gamification_profiles.cosmetics is
  'WP-154: kozmetik bayrakları; authenticated doğrudan yazmamalı (server/DEFINER)';

insert into public.achievements_dict
  (id, category, name, description, max_tier, icon_key, is_secret, tiers)
values
  ('quest_daily_login', 'study', 'Günlük giriş',
   'Bugün en az bir çalışma oturumu',
   1, 'today', false,
   '[{"tier":1,"threshold":1,"unit":"login_day","xp":0}]'::jsonb),
  ('quest_weekly_hours', 'study', 'Haftalık tempo',
   'Bu hafta 5 saat çalış',
   1, 'date_range', false,
   '[{"tier":1,"threshold":5,"unit":"week_hours","xp":0}]'::jsonb),
  ('cosmetic_frame_bronze', 'study', 'Bronz çerçeve',
   'Seviye 3 ile açılır (ücretsiz)',
   1, 'portrait', false,
   '[{"tier":1,"threshold":3,"unit":"level","xp":0}]'::jsonb)
on conflict (id) do nothing;
