-- WP-225 0051-0062 verified/projection baseline'ı (salt-okunur, PII içermez).
-- Bu dosyanın relation-does-not-exist hatası vermesi de ilgili migration
-- nesnesinin canlıda bulunmadığına dair kanıttır; hiçbir düzeltme yapmaz.

begin isolation level repeatable read read only;
set local statement_timeout = '120s';
set local lock_timeout = '5s';
set local idle_in_transaction_session_timeout = '120s';

select
  count(*)::bigint as run_count,
  count(*) filter (where status = 'running')::bigint as running_count,
  count(*) filter (where status = 'paused')::bigint as paused_count,
  count(*) filter (where status = 'finalized')::bigint as finalized_count,
  count(*) filter (where status = 'cancelled')::bigint as cancelled_count,
  count(*) filter (
    where status = 'finalized' and (finalized_at is null or session_id is null)
  )::bigint as invalid_finalized_count,
  count(*) filter (
    where status <> 'finalized' and (finalized_at is not null or session_id is not null)
  )::bigint as invalid_nonfinalized_count
from public.live_study_runs;

select
  count(*)::bigint as segment_count,
  count(*) filter (where ended_at is null)::bigint as open_segment_count,
  count(*) filter (where ended_at < started_at)::bigint as reversed_segment_count,
  coalesce(sum(extract(epoch from (ended_at - started_at)))
    filter (where ended_at is not null), 0)::bigint as closed_segment_seconds
from public.live_study_segments;

select
  count(*)::bigint as session_count,
  count(*) filter (where live_run_id is not null)::bigint as linked_live_run_count,
  count(*) filter (where live_run_id is null)::bigint as unlinked_count,
  count(*) filter (
    where live_run_id is not null and not exists (
      select 1 from public.live_study_runs r where r.id = study_sessions.live_run_id
    )
  )::bigint as orphan_live_run_links
from public.study_sessions;

select
  status,
  count(*)::bigint as candidate_count
from public.achievement_reward_candidates
group by status
order by status;

select
  count(*) filter (where c.status = 'ready' and r.id is null)::bigint
    as ready_candidate_without_reward,
  count(*) filter (where c.status = 'consumed' and r.id is null)::bigint
    as consumed_candidate_without_reward,
  count(*) filter (where c.status = 'dormant')::bigint
    as dormant_candidate_count
from public.achievement_reward_candidates c
left join public.achievement_rewards r
  on r.user_id = c.user_id
 and r.achievement_id = c.achievement_id
 and r.tier = c.tier;

select
  achievement_id,
  source_version,
  count(*)::bigint as progress_rows,
  coalesce(sum(metric_value), 0)::bigint as metric_total
from public.achievement_metric_progress
where achievement_id in (
  'alpha_wolf', 'campfire', 'locomotive',
  'secret_break_enemy', 'alpha_wolf_weekly'
)
group by achievement_id, source_version
order by achievement_id, source_version;

select
  count(*)::bigint as daily_rows,
  count(*) filter (where finalized_at is null)::bigint as daily_unfinalized_rows,
  count(*) filter (where finalized_at is not null)::bigint as daily_finalized_rows,
  coalesce(sum(alpha_wins), 0)::bigint as alpha_wins,
  coalesce(sum(campfire_seconds), 0)::bigint as campfire_seconds,
  coalesce(sum(locomotive_events), 0)::bigint as locomotive_events
from public.group_achievement_daily;

select
  count(*)::bigint as weekly_rows,
  count(*) filter (where finalized_at is null)::bigint as weekly_unfinalized_rows,
  count(*) filter (where finalized_at is not null)::bigint as weekly_finalized_rows,
  coalesce(sum(verified_seconds), 0)::bigint as verified_seconds,
  coalesce(sum(weekly_alpha_wins), 0)::bigint as weekly_alpha_wins
from public.group_achievement_weekly;

select
  singleton,
  minimum_verified_xp_build,
  shadow_mode
from public.verified_session_runtime_config;

rollback;
