-- 0119_global_timer_lease_recovery_grace.sql
--
-- A 150-second heartbeat lease measures controller freshness, not whether the
-- user's study run is still open. Android may keep the native foreground timer
-- alive while suspending the Dart isolate that sends heartbeats. Treating the
-- first missed lease as an explicit stop made mirrors disappear mid-session.
--
-- Keep the short lease as a sync-delay signal. Only transition to the terminal
-- `abandoned` state after a bounded 12-hour recovery grace. Explicit CAS stop
-- remains immediate and unchanged.

create or replace function public.expire_global_timer_v2_leases(
  p_limit integer default 100
)
returns integer
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_run public.live_study_runs%rowtype;
  v_state public.user_timer_state%rowtype;
  v_count integer := 0;
  v_now timestamptz := clock_timestamp();
begin
  if auth.role() is distinct from 'service_role'
     and current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  if p_limit is null or p_limit not between 1 and 500 then
    raise exception 'invalid_global_timer_sweeper_limit';
  end if;

  for v_run in
    select *
    from public.live_study_runs
    where protocol_version = 2
      and status = 'running'
      and lease_expires_at <= v_now - interval '12 hours'
    order by lease_expires_at, id
    limit p_limit
    for update skip locked
  loop
    perform pg_advisory_xact_lock(hashtextextended(v_run.user_id::text, 216));
    select * into v_state
    from public.user_timer_state
    where user_id = v_run.user_id
    for update;

    update public.user_timer_state
    set state_version = state_version + 1,
        current_run_id = case
          when current_run_id = v_run.id then null
          else current_run_id
        end,
        updated_at = v_now
    where user_id = v_run.user_id
    returning * into v_state;

    update public.live_study_runs
    set status = 'abandoned',
        ended_at = v_now,
        lease_expires_at = null,
        run_revision = run_revision + 1,
        user_state_version = v_state.state_version,
        updated_at = v_now
    where id = v_run.id
      and status = 'running'
      and lease_expires_at <= v_now - interval '12 hours';

    if found then
      update public.user_live_presence_state
      set status = 'offline',
          started_at = null,
          subject_id = null,
          lease_expires_at = null,
          state_version = state_version + 1,
          updated_at = v_now
      where user_id = v_run.user_id
        and status <> 'offline';
      delete from public.group_live_presence
      where user_id = v_run.user_id;
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.expire_global_timer_v2_leases(integer)
  from public, anon, authenticated;
grant execute on function public.expire_global_timer_v2_leases(integer)
  to service_role;

notify pgrst, 'reload schema';
