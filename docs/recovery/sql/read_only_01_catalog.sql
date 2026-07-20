-- WP-225 production şema/nesne envanteri (salt-okunur).
-- Fonksiyon gövdeleri veya kullanıcı verisi dışarı dökülmez; tanımlar hash'lenir.

begin isolation level repeatable read read only;
set local statement_timeout = '90s';
set local lock_timeout = '5s';
set local idle_in_transaction_session_timeout = '90s';

-- 0051-0062 için beklenen tablo/görünüm varlıkları.
with expected(kind, schema_name, object_name, expected_state) as (
  values
    ('table', 'public', 'live_study_runs', 'present'),
    ('table', 'public', 'live_study_segments', 'present'),
    ('table', 'public', 'verified_session_runtime_config', 'present'),
    ('table', 'public', 'verified_session_rollout_daily', 'present'),
    ('table', 'public', 'achievement_reward_candidates', 'present'),
    ('view',  'public', 'break_enemy_legacy_proxy_audit', 'present'),
    ('table', 'public', 'group_achievement_daily', 'present'),
    ('view',  'public', 'group_metric_legacy_proxy_audit', 'present'),
    ('table', 'public', 'group_achievement_weekly', 'present')
)
select
  e.kind,
  e.schema_name,
  e.object_name,
  e.expected_state,
  case
    when c.oid is null then 'absent'
    when c.relkind in ('r', 'p') then 'table'
    when c.relkind = 'v' then 'view'
    when c.relkind = 'm' then 'materialized_view'
    else c.relkind::text
  end as actual_state,
  c.relrowsecurity as rls_enabled
from expected e
left join pg_namespace n on n.nspname = e.schema_name
left join pg_class c on c.relnamespace = n.oid and c.relname = e.object_name
order by e.kind, e.object_name;

-- Kritik tablo kolonları. Bu çıktı migration'ın yalnız dosyada değil şemada
-- bulunup bulunmadığını kanıtlar.
with expected(schema_name, table_name, column_name) as (
  values
    ('public', 'study_sessions', 'live_run_id'),
    ('public', 'live_study_runs', 'group_id_snapshot'),
    ('public', 'live_study_runs', 'session_id'),
    ('public', 'live_study_segments', 'ended_at'),
    ('public', 'verified_session_runtime_config', 'shadow_mode'),
    ('public', 'group_achievement_daily', 'finalized_at'),
    ('public', 'group_achievement_weekly', 'finalized_at'),
    ('public', 'group_achievement_weekly', 'verified_seconds'),
    ('public', 'group_achievement_weekly', 'total_seconds')
)
select
  e.schema_name,
  e.table_name,
  e.column_name,
  case when c.column_name is null then 'absent' else 'present' end as actual_state,
  c.data_type,
  c.udt_name,
  c.is_nullable
from expected e
left join information_schema.columns c
  on c.table_schema = e.schema_name
 and c.table_name = e.table_name
 and c.column_name = e.column_name
order by e.table_name, e.column_name;

-- Mevcut kritik kolonların ayrıntılı dökümü.
select
  n.nspname as schema_name,
  c.relname as table_name,
  a.attname as column_name,
  format_type(a.atttypid, a.atttypmod) as data_type,
  a.attnotnull as not_null,
  pg_get_expr(d.adbin, d.adrelid) as default_expression
from pg_attribute a
join pg_class c on c.oid = a.attrelid
join pg_namespace n on n.oid = c.relnamespace
left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
where n.nspname = 'public'
  and c.relname in (
    'study_sessions', 'live_study_runs', 'live_study_segments',
    'verified_session_runtime_config', 'verified_session_rollout_daily',
    'achievement_reward_candidates', 'group_achievement_daily',
    'group_achievement_weekly', 'gamification_profiles', 'xp_ledger',
    'achievement_rewards', 'achievement_metric_progress'
  )
  and a.attnum > 0
  and not a.attisdropped
order by c.relname, a.attnum;

-- Constraint tanımlarının kendisi yerine hash'i alınır.
select
  n.nspname as schema_name,
  c.relname as table_name,
  con.conname as constraint_name,
  con.contype as constraint_type,
  md5(pg_get_constraintdef(con.oid, true)) as definition_md5
from pg_constraint con
join pg_class c on c.oid = con.conrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname in ('public', 'storage')
  and c.relname in (
    'study_sessions', 'live_study_runs', 'live_study_segments',
    'achievement_reward_candidates', 'group_achievement_daily',
    'group_achievement_weekly', 'achievement_rewards', 'xp_ledger'
  )
order by n.nspname, c.relname, con.conname;

-- 0051-0062 kritik fonksiyonları: imza, güvenlik bayrağı ve gövde hash'i.
with expected(function_name, expected_state) as (
  values
    ('_guard_verified_session_update', 'present'),
    ('_live_run_payload', 'present'),
    ('start_verified_live_run', 'present'),
    ('pause_verified_live_run', 'present'),
    ('resume_verified_live_run', 'present'),
    ('finalize_verified_live_run', 'present'),
    ('prune_verified_session_rollout', 'present'),
    ('verified_session_client_config', 'present'),
    ('record_verified_session_rollout', 'present'),
    ('break_enemy_verified_metric', 'present'),
    ('project_break_enemy_metric', 'present'),
    ('_break_enemy_segment_projector', 'present'),
    ('run_break_enemy_backfill_batch', 'present'),
    ('project_verified_group_day', 'present'),
    ('finalize_verified_group_day', 'present'),
    ('catch_up_verified_group_days', 'present'),
    ('_verified_group_run_finalized', 'present'),
    ('_verified_group_segment_dirty', 'present'),
    ('_recalc_crown_rank', 'present'),
    ('process_achievement_event', 'present'),
    ('_count_perfect_months_28', 'present'),
    ('_achievement_metrics', 'present'),
    ('group_alpha_scores', 'present'),
    ('project_verified_group_week', 'present'),
    ('finalize_verified_group_week', 'present'),
    ('catch_up_verified_group_weeks', 'present'),
    ('cleanup_group_avatar_object', 'absent'),
    -- 0063 sentinel'ları: freeze doğruysa production'da bulunmamalı.
    ('break_enemy_metric', 'absent'),
    ('_study_session_project_break_enemy', 'absent'),
    ('project_group_day', 'absent'),
    ('finalize_group_day', 'absent'),
    ('catch_up_group_days', 'absent'),
    ('refresh_group_metrics_for_session', 'absent'),
    ('_study_session_project_group_metrics', 'absent'),
    ('project_group_week', 'absent'),
    ('finalize_group_week', 'absent'),
    ('catch_up_group_weeks', 'absent')
)
select
  e.function_name,
  e.expected_state,
  case when p.oid is null then 'absent' else 'present' end as actual_state,
  coalesce(n.nspname, 'public') as schema_name,
  coalesce(pg_get_function_identity_arguments(p.oid), '') as identity_arguments,
  coalesce(l.lanname, '') as language,
  coalesce(p.prosecdef, false) as security_definer,
  coalesce(p.provolatile::text, '') as volatility,
  case when p.oid is null then null else md5(pg_get_functiondef(p.oid)) end as definition_md5
from expected e
left join pg_proc p
  on p.proname = e.function_name
 and p.pronamespace = 'public'::regnamespace
left join pg_namespace n on n.oid = p.pronamespace
left join pg_language l on l.oid = p.prolang
order by e.function_name, identity_arguments;

-- Kritik policy'ler. qual/with_check ham metni yerine hash döndürülür.
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  md5(coalesce(qual, '')) as qual_md5,
  md5(coalesce(with_check, '')) as with_check_md5
from pg_policies
where (schemaname = 'public' and tablename in (
         'study_sessions', 'live_study_runs', 'live_study_segments',
         'verified_session_runtime_config', 'verified_session_rollout_daily',
         'achievement_reward_candidates', 'group_achievement_daily',
         'group_achievement_weekly', 'gamification_profiles', 'xp_ledger',
         'achievement_rewards', 'achievement_metric_progress'
       ))
   or (schemaname = 'storage' and tablename = 'objects'
       and policyname = 'group_avatars_member_read')
order by schemaname, tablename, policyname;

select
  'storage.objects.group_avatars_member_read' as expected_policy,
  case when exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'group_avatars_member_read'
  ) then 'present' else 'absent' end as actual_state;

-- Kritik trigger'lar. 0054 sonrası groups_cleanup_avatar_object ABSENT olmalı.
with expected(trigger_name, expected_state) as (
  values
    ('study_sessions_guard_verified_update', 'present'),
    ('live_segments_project_break_enemy', 'present'),
    ('live_runs_project_group_metrics', 'present'),
    ('live_segments_project_group_metrics', 'present'),
    ('groups_cleanup_avatar_object', 'absent'),
    -- 0063 sentinel'ları: freeze doğruysa production'da bulunmamalı.
    ('study_sessions_project_break_enemy', 'absent'),
    ('study_sessions_project_group_metrics', 'absent')
)
select
  e.trigger_name,
  e.expected_state,
  case when t.oid is null then 'absent' else 'present' end as actual_state,
  n.nspname as schema_name,
  c.relname as table_name,
  t.tgenabled as enabled,
  case when t.oid is null then null else md5(pg_get_triggerdef(t.oid, true)) end
    as definition_md5
from expected e
left join pg_trigger t on t.tgname = e.trigger_name and not t.tgisinternal
left join pg_class c on c.oid = t.tgrelid
left join pg_namespace n on n.oid = c.relnamespace
order by e.trigger_name;

rollback;
