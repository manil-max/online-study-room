-- 0033_study_hour_xp_50.sql
-- Çalışma saati XP 10 → 50
--
-- Ürün: her tamamlanan 1 saat çalışma = 50 XP (başarım kademe ödüllerine ek).
-- 0027'de oran 10 idi; event_key `uid|study_hour_xp|h_N` ile idempotent.
--
-- Bu migration:
--   1) process_achievement_event içindeki saat XP'yi 50 yapar
--   2) achievements_dict.study_hour_xp açıklamasını günceller
--   3) Daha önce 10 XP almış saatler için bir kerelik +40 top-up yazar
--      (event_key: uid|study_hour_xp_v50_topup|h_N) — çift ödül yok
--
-- Geri alma (Rollback):
--   process_achievement_event'i 0027 metnine döndür; top-up satırlarını
--   event_key like '%|study_hour_xp_v50_topup|%' ile silmek ledger'ı bozar
--   (append-only) — pratikte geri alma yeni migration ile oran 10'a indirilir,
--   top-up silinmez.

-- ---------------------------------------------------------------------
-- 1) Sözlük satırı
-- ---------------------------------------------------------------------
insert into public.achievements_dict (
  id, category, name, description, max_tier, icon_key, is_secret, tiers
) values (
  'study_hour_xp',
  'system',
  'Çalışma saati',
  'Her tamamlanan 1 saat çalışma için 50 XP',
  1,
  'schedule',
  false,
  '[{"tier":1,"threshold":1,"unit":"hours","xp":50}]'::jsonb
)
on conflict (id) do update set
  category = excluded.category,
  name = excluded.name,
  description = excluded.description,
  max_tier = excluded.max_tier,
  icon_key = excluded.icon_key,
  is_secret = excluded.is_secret,
  tiers = excluded.tiers;

-- ---------------------------------------------------------------------
-- 2) process_achievement_event: başarım + 50 XP / saat
--    (0027 gövdesi; saat XP 10 → 50)
-- ---------------------------------------------------------------------
create or replace function public.process_achievement_event(
  p_event_type text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_metrics jsonb;
  v_awarded jsonb := '[]'::jsonb;
  v_def record;
  v_tier jsonb;
  v_progress integer;
  v_threshold integer;
  v_xp integer;
  v_tier_n integer;
  v_unit text;
  v_ok boolean;
  v_total_xp integer := 0;
  v_rank text := 'bronze_beginner';
  v_secrets jsonb;
  v_hours integer;
  v_h integer;
  v_hour_key text;
  v_hour_id uuid;
  v_hour_xp_total integer := 0;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_event_type not in (
    'session_completed', 'manual_refresh', 'profile_opened', 'nudge_sent'
  ) then
    raise exception 'unknown event_type: %', p_event_type;
  end if;

  v_metrics := public._achievement_metrics(v_uid);
  v_secrets := v_metrics->'secrets';

  for v_def in
    select * from public.achievements_dict
    where category is distinct from 'system'
      and id is distinct from 'study_hour_xp'
    order by id
  loop
    v_progress := case v_def.id
      when 'marathon_total' then (v_metrics->>'total_hours')::integer
      when 'steel_will' then (v_metrics->>'max_session_minutes')::integer
      when 'day_hero' then (v_metrics->>'max_day_hours')::integer
      when 'fire_streak' then (v_metrics->>'streak_days')::integer
      when 'weekend_goal_days' then (v_metrics->>'weekend_goal_days')::integer
      when 'perfect_month' then (v_metrics->>'perfect_months')::integer
      when 'alpha_wolf' then 0
      when 'team_player' then coalesce((v_metrics->>'group_goal_contrib')::integer, 0)
      when 'campfire_hours' then 0
      when 'inspiration' then coalesce((v_metrics->>'nudge_starts')::integer, 0)
      when 'locomotive' then 0
      when 'secret_night_owl' then case when (v_secrets->>'night_owl')::boolean then 1 else 0 end
      when 'secret_dawn' then case when (v_secrets->>'dawn')::boolean then 1 else 0 end
      when 'secret_404' then case when (v_secrets->>'m404')::boolean then 1 else 0 end
      when 'secret_pi' then case when (v_secrets->>'pi')::boolean then 1 else 0 end
      when 'secret_matrix' then case when (v_secrets->>'matrix')::boolean then 1 else 0 end
      when 'secret_1337' then case when (v_secrets->>'leet')::boolean then 1 else 0 end
      when 'secret_nye' then case when (v_secrets->>'nye')::boolean then 1 else 0 end
      when 'secret_last_second' then case when (v_secrets->>'last_second')::boolean then 1 else 0 end
      when 'secret_no_limits' then case when (v_secrets->>'no_limits')::boolean then 1 else 0 end
      when 'secret_break_enemy' then 0
      else 0
    end;

    for v_tier in
      select * from jsonb_array_elements(v_def.tiers)
    loop
      v_tier_n := (v_tier->>'tier')::integer;
      v_threshold := (v_tier->>'threshold')::integer;
      v_xp := (v_tier->>'xp')::integer;
      v_unit := v_tier->>'unit';

      if v_progress >= v_threshold then
        v_ok := public._award_achievement_tier(
          v_uid,
          v_def.id,
          v_tier_n,
          v_xp,
          format('%s progress=%s %s', v_def.id, v_progress, coalesce(v_unit, ''))
        );
        if v_ok then
          v_awarded := v_awarded || jsonb_build_array(
            jsonb_build_object(
              'achievement_id', v_def.id,
              'tier', v_tier_n,
              'xp', v_xp,
              'name', v_def.name,
              'is_secret', v_def.is_secret
            )
          );
        end if;
      end if;
    end loop;
  end loop;

  -- Saat XP: her tamamlanan tam saat → 50 XP (idempotent)
  v_hours := coalesce((v_metrics->>'total_hours')::integer, 0);
  if v_hours > 0 then
    for v_h in 1..v_hours loop
      v_hour_key := v_uid::text || '|study_hour_xp|h_' || v_h::text;
      insert into public.xp_ledger (
        user_id, achievement_id, tier, xp_amount, reason, event_key
      ) values (
        v_uid,
        'study_hour_xp',
        1,
        50,
        format('Çalışma saati #%s', v_h),
        v_hour_key
      )
      on conflict (event_key) do nothing
      returning id into v_hour_id;
      if v_hour_id is not null then
        v_hour_xp_total := v_hour_xp_total + 50;
        v_hour_id := null;
      end if;
    end loop;
  end if;

  select coalesce(xp, 0), coalesce(crown_rank, 'bronze_beginner')
    into v_total_xp, v_rank
  from public.gamification_profiles
  where user_id = v_uid;

  return jsonb_build_object(
    'event_type', p_event_type,
    'awarded', v_awarded,
    'total_xp', coalesce(v_total_xp, 0),
    'crown_rank', coalesce(v_rank, 'bronze_beginner'),
    'study_hour_xp_granted', v_hour_xp_total,
    'metrics', v_metrics
  );
end;
$$;

revoke all on function public.process_achievement_event(text, jsonb) from public;
grant execute on function public.process_achievement_event(text, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 3) Eski 10 XP saat satırları için bir kerelik +40 (10→50 net)
--    Yalnız xp_amount=10 ve klasik event_key biçimi.
-- ---------------------------------------------------------------------
insert into public.xp_ledger (
  user_id, achievement_id, tier, xp_amount, reason, event_key
)
select
  l.user_id,
  'study_hour_xp',
  1,
  40,
  format('Saat XP 10→50 üstü (%s)', l.event_key),
  l.user_id::text
    || '|study_hour_xp_v50_topup|'
    || split_part(l.event_key, '|h_', 2)
from public.xp_ledger l
where l.achievement_id = 'study_hour_xp'
  and l.xp_amount = 10
  and l.event_key like '%|study_hour_xp|h_%'
  and position('|study_hour_xp_v50_topup|' in l.event_key) = 0
on conflict (event_key) do nothing;
