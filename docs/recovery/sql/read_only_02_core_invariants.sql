-- WP-225 production oturum/XP/ödül baseline'ı (salt-okunur, PII içermez).

begin isolation level repeatable read read only;
set local statement_timeout = '120s';
set local lock_timeout = '5s';
set local idle_in_transaction_session_timeout = '120s';

-- Ana oturum özeti ve yeniden çalıştırılabilir aggregate fingerprint.
with s as (
  select
    count(*)::bigint as row_count,
    coalesce(sum(duration_seconds), 0)::bigint as duration_seconds,
    min(start_time) as first_start,
    max(end_time) as last_end,
    count(*) filter (where duration_seconds < 0)::bigint as negative_duration_rows,
    count(*) filter (where end_time < start_time)::bigint as reversed_time_rows,
    count(*) filter (
      where abs(duration_seconds - extract(epoch from (end_time - start_time))) > 2
    )::bigint as duration_clock_drift_rows
  from public.study_sessions
)
select
  s.*,
  md5(concat_ws('|', row_count, duration_seconds, first_start, last_end,
                negative_duration_rows, reversed_time_rows,
                duration_clock_drift_rows)) as aggregate_md5
from s;

select
  source,
  count(*)::bigint as row_count,
  coalesce(sum(duration_seconds), 0)::bigint as duration_seconds,
  min(start_time) as first_start,
  max(end_time) as last_end
from public.study_sessions
group by source
order by source;

-- Europe/Istanbul günlük toplamı; kullanıcı kimliği döndürmez.
select
  (start_time at time zone 'Europe/Istanbul')::date as istanbul_day,
  count(*)::bigint as session_count,
  coalesce(sum(duration_seconds), 0)::bigint as duration_seconds
from public.study_sessions
where start_time >= ((((now() at time zone 'Europe/Istanbul')::date - 45)::timestamp)
                     at time zone 'Europe/Istanbul')
group by 1
order by 1;

-- XP ledger ↔ profil uzlaşması. User UUID yalnız iç hesapta kullanılır ve
-- dışarı döndürülmez; hash yalnız değişiklik takibi içindir.
with ledger as (
  select user_id, coalesce(sum(xp_amount), 0)::bigint as ledger_xp
  from public.xp_ledger
  group by user_id
), compared as (
  select
    p.user_id,
    p.xp::bigint as profile_xp,
    coalesce(l.ledger_xp, 0)::bigint as ledger_xp
  from public.gamification_profiles p
  left join ledger l on l.user_id = p.user_id
), summary as (
  select
    count(*)::bigint as profile_count,
    count(*) filter (where profile_xp <> ledger_xp)::bigint as mismatch_user_count,
    coalesce(sum(profile_xp), 0)::bigint as profile_xp_total,
    coalesce(sum(ledger_xp), 0)::bigint as ledger_xp_total,
    md5(coalesce(string_agg(
      md5(user_id::text || '|' || profile_xp || '|' || ledger_xp),
      '' order by user_id
    ), '')) as per_user_reconciliation_md5
  from compared
)
select * from summary;

-- Kimlik veya event_key döndürmeden duplicate/invariant sayıları.
select
  (select count(*) from (
    select event_key from public.xp_ledger group by event_key having count(*) > 1
  ) d)::bigint as duplicate_ledger_event_keys,
  (select count(*) from (
    select user_id, achievement_id, tier
    from public.xp_ledger
    group by user_id, achievement_id, tier
    having count(*) > 1
  ) d)::bigint as duplicate_ledger_user_achievement_tiers,
  (select count(*) from (
    select user_id, achievement_id, tier
    from public.achievement_rewards
    group by user_id, achievement_id, tier
    having count(*) > 1
  ) d)::bigint as duplicate_reward_user_achievement_tiers,
  (select count(*) from public.achievement_rewards r
   where r.status = 'claimed'
     and not exists (
       select 1 from public.xp_ledger x
       where x.event_key = r.claimed_ledger_event_key
     ))::bigint as claimed_reward_without_ledger,
  (select count(*) from public.achievement_rewards r
   where r.status = 'pending'
     and exists (
       select 1 from public.xp_ledger x where x.event_key = r.event_key
     ))::bigint as pending_reward_with_same_ledger_event;

select
  status,
  count(*)::bigint as reward_count,
  coalesce(sum(xp_amount), 0)::bigint as xp_amount
from public.achievement_rewards
group by status
order by status;

-- Ekonomi sözleşmesi kullanıcı verisi değildir; tuple'lar açıkça kaydedilir.
select id, max_tier, tiers
from public.achievements_dict
order by id;

-- 0056 secret_1337 temizliğinin referans sayıları.
select 'achievements_dict' as relation_name, count(*)::bigint as remaining_rows
from public.achievements_dict where id = 'secret_1337'
union all
select 'achievement_rewards', count(*)::bigint
from public.achievement_rewards where achievement_id = 'secret_1337'
union all
select 'achievement_metric_progress', count(*)::bigint
from public.achievement_metric_progress where achievement_id = 'secret_1337'
union all
select 'user_achievements', count(*)::bigint
from public.user_achievements where achievement_id = 'secret_1337'
union all
select 'xp_ledger', count(*)::bigint
from public.xp_ledger where achievement_id = 'secret_1337'
order by relation_name;

rollback;
