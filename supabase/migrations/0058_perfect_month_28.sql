-- 0058_perfect_month_28.sql
-- beta-v42 · WP-D — Kusursuz Ay kuralı 30 → 28 gün (saha kararı §3).
--
-- Kural: "bir takvim ayında 30 gün" yerine **ay içinde ≥28 hedef-tamamlanan gün**
-- (en fazla 2 kaçırma). Blazing Fire kesintisiz seri; Kusursuz Ay ay-içi toplamdır.
-- Şubat/29-günlük ay dahil eşik sabit 28. Client `achievement_ledger_engine`
-- (computeMetrics ≥28) ile ayna; metric source_version `perfect_month_28_v1`.
--
-- Geçmiş kazanılmış perfect_month korunur (append-only ledger; projeksiyon
-- kümülatif greatest → değer düşmez). process_achievement_event (WP-C, 0057)
-- yeni eşiği pending ödül olarak inbox'a yazar.
--
-- Geri alma (Rollback): `_achievement_metrics` wrapper'ını `_count_perfect_months_30`
-- çağrısına döndür; kazanılmış aylar geri alınmaz.

-- 28-gün sayacı (0050'deki 30-gün sürümünün kopyası, eşik 28).
create or replace function public._count_perfect_months_28(p_user_id uuid)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  with goal as (
    select greatest(coalesce(p.daily_goal_minutes, 360), 1) * 60 as seconds
    from public.profiles p
    where p.id = p_user_id
  ),
  day_totals as (
    select
      (s.start_time at time zone 'Europe/Istanbul')::date as day,
      sum(s.duration_seconds)::bigint as seconds
    from public.study_sessions s
    where s.user_id = p_user_id
      and s.duration_seconds > 0
    group by 1
  ),
  month_totals as (
    select date_trunc('month', d.day)::date as month_start,
           count(*) filter (where d.seconds >= coalesce(g.seconds, 21600))
             as goal_days
    from day_totals d
    cross join (select coalesce(max(seconds), 21600) as seconds from goal) g
    group by 1
  )
  select count(*)::integer
  from month_totals
  where goal_days >= 28;
$$;

revoke all on function public._count_perfect_months_28(uuid)
  from public, anon, authenticated;

-- Wrapper'ı 28-gün sayacına bağla (0050 gövdesi; yalnız perfect_months kaynağı değişir).
create or replace function public._achievement_metrics(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_metrics jsonb;
  v_perfect_months integer;
begin
  v_metrics := public._achievement_metrics_legacy_v1(p_user_id);
  v_perfect_months := public._count_perfect_months_28(p_user_id);
  v_metrics := jsonb_set(
    v_metrics,
    '{perfect_months}',
    to_jsonb(coalesce(v_perfect_months, 0)),
    true
  );
  perform public._project_achievement_metrics(p_user_id, v_metrics);
  return v_metrics;
end;
$$;

revoke all on function public._achievement_metrics(uuid)
  from public, anon, authenticated;

-- Metric sözleşme sürümü (client aynası: perfect_month_28_v1).
update public.achievement_metric_definitions
set source_version = 'perfect_month_28_v1', updated_at = now()
where achievement_id = 'perfect_month';

-- Kullanıcıya görünen açıklama.
update public.achievements_dict
set description = 'Aynı takvim ayında en az 28 ayrı günde günlük hedefe ulaş (en fazla 2 kaçırma)'
where id = 'perfect_month';

notify pgrst, 'reload schema';
