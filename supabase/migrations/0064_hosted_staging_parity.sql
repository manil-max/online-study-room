-- 0064_hosted_staging_parity.sql
-- WP-229: fresh hosted staging cron ve internal RPC izin parity onarımı.
--
-- 0063 staging'e uygulandıktan sonra linked pgTAP, pg_cron'un 0052 sonrasında
-- kurulması nedeniyle 0051 retention job'ının eksik kaldığını ve hosted default
-- privileges'ın bazı internal SECURITY DEFINER RPC'lere explicit EXECUTE
-- verdiğini gösterdi. Tarihsel migration'lar değiştirilmeden ileri onarılır.
--
-- Geri alma (Rollback): Bu güvenlik sıkılaştırması geri alınmaz. Yalnız bu
-- migration'ın eklediği cron job'ları kaldırmak gerekirse job adına göre
-- cron.unschedule(jobid) çalıştırılır; kazanılmış session/ledger/reward silinmez.

do $migration$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron')
     or to_regclass('cron.job') is null then
    raise exception 'pg_cron_required_before_0064';
  end if;

  if not exists (
    select 1 from cron.job where jobname = 'verified-session-rollout-retention'
  ) then
    perform cron.schedule(
      'verified-session-rollout-retention',
      '17 1 * * *',
      'select public.prune_verified_session_rollout()'
    );
  end if;
end
$migration$;

-- monthly-report-collector bilinçli olarak burada kurulmaz: Edge Function/GUC
-- owner ops kararı ayrı backlog kapısıdır ve WP-229 kabulünü genişletmez.

revoke all on function public.break_enemy_metric(uuid)
  from public, anon, authenticated;
revoke all on function public.project_break_enemy_metric(uuid)
  from public, anon, authenticated;
revoke all on function public._equal_source_effective_end(timestamptz, timestamptz, integer)
  from public, anon, authenticated;
revoke all on function public._sync_equal_source_rewards(uuid, text, bigint, text, jsonb)
  from public, anon, authenticated;
revoke all on function public._study_session_project_break_enemy()
  from public, anon, authenticated;
revoke all on function public.project_group_day(uuid, date)
  from public, anon, authenticated;
revoke all on function public.finalize_group_day(uuid, date)
  from public, anon, authenticated;
revoke all on function public.catch_up_group_days()
  from public, anon, authenticated;
revoke all on function public.refresh_group_metrics_for_session(uuid, timestamptz, timestamptz)
  from public, anon, authenticated;
revoke all on function public._study_session_project_group_metrics()
  from public, anon, authenticated;
revoke all on function public.project_group_week(uuid, date)
  from public, anon, authenticated;
revoke all on function public.finalize_group_week(uuid, date)
  from public, anon, authenticated;
revoke all on function public.catch_up_group_weeks()
  from public, anon, authenticated;
revoke all on function public.prepare_equal_source_reconciliation(integer, uuid)
  from public, anon, authenticated;
revoke all on function public.apply_equal_source_reconciliation(uuid)
  from public, anon, authenticated;
revoke all on function public.prune_verified_session_rollout()
  from public, anon, authenticated;

grant execute on function public.prepare_equal_source_reconciliation(integer, uuid)
  to service_role;
grant execute on function public.apply_equal_source_reconciliation(uuid)
  to service_role;

notify pgrst, 'reload schema';
