-- 0057_route_awards_to_inbox.sql
-- beta-v42 · WP-C — Claim inbox birleştirme (saha bulgusu #4).
--
-- Sorun: `process_achievement_event` çalışma/seri/sosyal başarımlarında eşik
-- geçilince `_award_achievement_tier` ile **doğrudan XP bankalıyordu** (oto-terfi).
-- Kullanıcı ödülü "Topla" ile almak istiyor; grup-verified başarımlar zaten
-- candidate→inbox akışında. Hedef: **hepsi inbox'tan geçsin.**
--
-- Çözüm: Award bloğu artık `_create_pending_achievement_reward` çağırır — XP
-- BANKALANMAZ, yalnız `achievement_rewards` içine `pending` satır yazılır. XP
-- yalnız `claim_achievement_reward` / `claim_all_achievement_rewards` ile verilir.
--
-- Çift-XP / XP-kaybı guard'ları (QA 1.3–1.7):
--   • `_create_pending_achievement_reward` (0047) beklenen XP'yi sözlükten
--     doğrular (0056 yeni değerleri), aynı kademe zaten ledger'da bankalıysa
--     (beta-v40 oto-award) **pending yaratmaz** → geriye dönük çift ödül yok,
--     yalnız ileriye etki.
--   • `unique(user, achievement, tier)` → aynı kademe için tek pending.
--   • claim yolu bankalamadan önce ledger event_key'i tekrar kontrol eder.
--
-- Saat XP (study_hour_xp, 50/saat) pasif ödüldür; inbox'a taşınmaz, doğrudan
-- bankalanır (her saati "topla" demek anlamsız).
--
-- secret_1337 sözlükten kaldırıldığı için (0056) döngüde işlenmez; ilgili case
-- da temizlendi.
--
-- Geri alma (Rollback): 0033'teki `_award_achievement_tier` çağrılı gövdeye
-- dön. Oluşmuş pending satırları silinmez; claim edilebilir kalır.

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
  v_reward_id uuid;
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
        -- Doğrudan XP bankalamaz: inbox'a pending ödül yazar (WP-C).
        -- Zaten bankalıysa (beta-v40 oto-award) veya pending varsa null döner.
        v_reward_id := public._create_pending_achievement_reward(
          v_uid,
          v_def.id,
          v_tier_n,
          v_xp,
          format('%s progress=%s %s', v_def.id, v_progress, coalesce(v_unit, ''))
        );
        if v_reward_id is not null then
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

  -- Saat XP: her tamamlanan tam saat → 50 XP (pasif, doğrudan; idempotent).
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

  -- `awarded`: bu çağrıda inbox'a EKLENEN pending ödüller (XP henüz bankalanmadı;
  -- kullanıcı "Topla" ile alır). `total_xp` yalnız bankalanmış XP'yi yansıtır.
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

notify pgrst, 'reload schema';
