Set-StrictMode -Version Latest

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Get-DeployContract {
  param([string]$RepoRoot = (Get-RepoRoot))

  $path = Join-Path $RepoRoot 'tooling\release\deploy-contract.json'
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Deploy contract is missing: $path"
  }
  return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-LocalMigrationHead {
  param([string]$RepoRoot = (Get-RepoRoot))

  $files = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'supabase\migrations') -Filter '*.sql' -File)
  if ($files.Count -eq 0) {
    throw 'No local migration files were found.'
  }

  $versionFiles = foreach ($file in $files) {
    if ($file.Name -notmatch '^(\d{4})_[a-z0-9_]+\.sql$') {
      throw "Invalid migration filename: $($file.Name)"
    }
    [pscustomobject]@{ Version = $Matches[1]; File = $file }
  }

  $versions = @($versionFiles | ForEach-Object Version)
  $duplicates = @($versions | Group-Object | Where-Object Count -gt 1)
  if ($duplicates.Count -gt 0) {
    throw "Duplicate migration version: $($duplicates[0].Name)"
  }

  $latest = $versionFiles | Sort-Object Version | Select-Object -Last 1
  $firstLine = Get-Content -LiteralPath $latest.File.FullName -TotalCount 1 -Encoding UTF8
  if ($firstLine -ne "-- $($latest.File.Name)") {
    throw "Latest migration header mismatch: $($latest.File.Name)"
  }
  return $latest.Version
}

function Get-GitHead {
  param([string]$RepoRoot = (Get-RepoRoot))

  $head = (& git -C $RepoRoot rev-parse HEAD 2>$null | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[0-9a-f]{40}$') {
    throw 'Unable to resolve the exact git commit SHA.'
  }
  return $head
}

function Protect-DeployText {
  param(
    [AllowNull()][string]$Text,
    [string[]]$SensitiveValues = @()
  )

  if ($null -eq $Text) { return '' }
  $safe = $Text
  foreach ($value in $SensitiveValues) {
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      $safe = $safe.Replace($value, '[REDACTED]')
    }
  }

  $patterns = @(
    '(?im)^.*["'']?(?:ANON_KEY|PUBLISHABLE_KEY|JWT_SECRET|SECRET_KEY|SERVICE_ROLE_KEY|S3_PROTOCOL_ACCESS_KEY_ID|S3_PROTOCOL_ACCESS_KEY_SECRET|SUPABASE_ACCESS_TOKEN|SUPABASE_DB_PASSWORD|STAGING_SUPABASE_ANON_KEY|PRODUCTION_SUPABASE_ANON_KEY|SENTRY_DSN|STORE_PASSWORD|KEY_PASSWORD)["'']?\s*[=:].*$',
    '(?i)sb_(?:secret|service_role)_[A-Za-z0-9._-]+',
    '(?i)(?:SUPABASE_ACCESS_TOKEN|SUPABASE_DB_PASSWORD|SERVICE_ROLE_KEY)\s*[=:]\s*[^\s]+',
    '(?i)postgres(?:ql)?://[^\s:@/]+:[^\s@/]+@',
    '(?i)Bearer\s+[A-Za-z0-9._-]+',
    'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'
  )
  foreach ($pattern in $patterns) {
    $safe = [regex]::Replace($safe, $pattern, '[REDACTED SECRET FIELD]')
  }
  return $safe
}

function Assert-SafeSupabaseArguments {
  param([Parameter(Mandatory)][string[]]$Arguments)

  $joined = ($Arguments -join ' ').ToLowerInvariant()
  $denied = @(
    '^db\s+reset.*--linked',
    '^db\s+reset.*--db-url',
    '^migration\s+repair',
    '\btruncate\b',
    '\bdrop\b',
    '\bdelete\b'
  )
  foreach ($pattern in $denied) {
    if ($joined -match $pattern) {
      throw "Denied Supabase command: $($Arguments[0..([Math]::Min(1, $Arguments.Count - 1))] -join ' ')"
    }
  }
}

function Get-StagingPrerequisiteSql {
  param([Parameter(Mandatory)][ValidateSet('inspect', 'bootstrap')][string]$Action)

  if ($Action -eq 'bootstrap') {
    return 'create extension if not exists pg_cron;'
  }

  return @'
select json_build_object(
  'pg_cron_available', exists(select 1 from pg_available_extensions where name = 'pg_cron'),
  'pg_cron_installed', exists(select 1 from pg_extension where extname = 'pg_cron'),
  'cron_job_relation', to_regclass('cron.job') is not null,
  'migration_0052_applied', exists(select 1 from supabase_migrations.schema_migrations where version = '0052'),
  'migration_0053_applied', exists(select 1 from supabase_migrations.schema_migrations where version = '0053')
)::text as prerequisite_state;
'@
}

function Assert-StagingPrerequisiteAction {
  param(
    [Parameter(Mandatory)][ValidateSet('inspect', 'bootstrap')][string]$Action,
    [Parameter(Mandatory)][ValidateSet('staging', 'production')][string]$Environment,
    [Parameter(Mandatory)][string]$ProjectRef,
    [Parameter(Mandatory)][string]$StagingProjectRef,
    [Parameter(Mandatory)][string]$ProductionProjectRef,
    [Parameter(Mandatory)][string]$Sql
  )

  if ($Environment -ne 'staging') {
    throw 'Prerequisite inspection/bootstrap is staging-only.'
  }
  if ($ProjectRef -ne $StagingProjectRef -or $ProjectRef -eq $ProductionProjectRef) {
    throw 'Prerequisite target must be the isolated staging project ref.'
  }

  $allowedSql = Get-StagingPrerequisiteSql -Action $Action
  if ($Sql -cne $allowedSql) {
    throw 'Prerequisite SQL is not on the exact staging allowlist.'
  }
}

function Get-StagingPushDispatchPostCheckSql {
  return @'
do $$
begin
  if to_regclass('cron.job') is null then
    raise exception 'push_dispatch_cron_relation_missing';
  end if;
  if not exists (
    select 1 from cron.job where jobname = 'push-dispatch-retry-worker'
  ) then
    raise exception 'push_dispatch_retry_worker_missing';
  end if;
  if to_regprocedure('public.get_push_dispatch_queue_health()') is null then
    raise exception 'push_dispatch_queue_health_missing';
  end if;
end;
$$;

select * from public.get_push_dispatch_queue_health();
'@
}

function Assert-StagingPushDispatchPostCheck {
  param(
    [Parameter(Mandatory)][ValidateSet('staging', 'production')][string]$Environment,
    [Parameter(Mandatory)][string]$ProjectRef,
    [Parameter(Mandatory)][string]$StagingProjectRef,
    [Parameter(Mandatory)][string]$ProductionProjectRef,
    [Parameter(Mandatory)][string]$Sql
  )

  if ($Environment -ne 'staging') {
    throw 'Push dispatch post-check is staging-only.'
  }
  if ($ProjectRef -ne $StagingProjectRef -or $ProjectRef -eq $ProductionProjectRef) {
    throw 'Push dispatch post-check target must be the isolated staging project ref.'
  }

  $allowedSql = Get-StagingPushDispatchPostCheckSql
  if ($Sql -cne $allowedSql) {
    throw 'Push dispatch post-check SQL is not on the exact staging allowlist.'
  }
}

function Get-StagingPushRuntimeDiagnosticSql {
  return @'
begin transaction read only;

select json_build_object(
  'kind', 'push_runtime_diagnostic',
  'observed_at', now(),
  'cron_job', coalesce((
    select json_agg(json_build_object(
      'jobid', j.jobid,
      'schedule', j.schedule,
      'database', j.database,
      'username', j.username,
      'active', j.active
    ) order by j.jobid)
    from cron.job j
    where j.jobname = 'push-dispatch-retry-worker'
  ), '[]'::json),
  'cron_runs', coalesce((
    select json_agg(to_jsonb(r) order by r.start_time desc)
    from (
      select
        d.runid,
        d.jobid,
        d.status,
        left(coalesce(d.return_message, ''), 500) as return_message,
        d.start_time,
        d.end_time
      from cron.job_run_details d
      join cron.job j on j.jobid = d.jobid
      where j.jobname = 'push-dispatch-retry-worker'
      order by d.start_time desc
      limit 20
    ) r
  ), '[]'::json),
  'pg_net_catalog', json_build_object(
    'extension_installed', exists(
      select 1 from pg_extension where extname = 'pg_net'
    ),
    'extension_version', (
      select extversion from pg_extension where extname = 'pg_net' limit 1
    ),
    'net_schema_present', exists(
      select 1 from pg_namespace where nspname = 'net'
    ),
    'functions', coalesce((
      select json_agg(json_build_object(
        'name', p.proname,
        'arguments', pg_get_function_identity_arguments(p.oid)
      ) order by p.proname, pg_get_function_identity_arguments(p.oid))
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'net'
    ), '[]'::json),
    'relations', coalesce((
      select json_agg(json_build_object(
        'name', c.relname,
        'kind', c.relkind
      ) order by c.relname)
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'net'
    ), '[]'::json)
  ),
  'runtime_config', (
    select json_build_object(
      'row_count', count(*),
      'base_url_present', coalesce(bool_and(char_length(functions_base_url) > 0), false),
      'base_url_shape_valid', coalesce(bool_and(functions_base_url ~ '^https://[a-z0-9]{20}\.supabase\.co$'), false),
      'secret_present', coalesce(bool_and(char_length(dispatch_secret) > 0), false),
      'secret_length_valid', coalesce(bool_and(char_length(dispatch_secret) >= 48), false),
      'configured_at', max(configured_at)
    )
    from public.push_dispatch_runtime_config
  ),
  'queue_health', coalesce((
    select json_agg(to_jsonb(h))
    from public.get_push_dispatch_queue_health() h
  ), '[]'::json),
  'active_deliveries', coalesce((
    select json_agg(to_jsonb(q) order by q.created_at)
    from (
      select
        left(md5(d.id::text), 12) as delivery_key,
        left(md5(d.outbox_id::text), 12) as outbox_key,
        o.notification_type,
        o.status as outbox_status,
        d.status as delivery_status,
        d.attempts,
        d.available_at,
        d.available_at <= now() as available_now,
        d.lease_until,
        d.lease_until is not null and d.lease_until < now() as lease_expired,
        d.created_at,
        d.updated_at,
        d.sent_at,
        d.last_error_code,
        pd.disabled_at is not null as device_disabled,
        case o.notification_type
          when 'nudge' then pd.nudge_enabled
          when 'announcement' then pd.announcement_enabled
          when 'update' then pd.update_enabled
          when 'self_test' then true
          else false
        end as preference_enabled,
        pd.quiet_hours_enabled,
        pd.quiet_start_minutes,
        pd.quiet_end_minutes
      from public.notification_deliveries d
      join public.notification_outbox o on o.id = d.outbox_id
      join public.push_devices pd on pd.id = d.device_id
      where d.status in ('pending', 'retry', 'processing')
      order by d.created_at
      limit 20
    ) q
  ), '[]'::json)
)::text as push_diagnostic;

rollback;
'@
}

function Assert-StagingPushRuntimeDiagnostic {
  param(
    [Parameter(Mandatory)][ValidateSet('staging', 'production')][string]$Environment,
    [Parameter(Mandatory)][string]$ProjectRef,
    [Parameter(Mandatory)][string]$StagingProjectRef,
    [Parameter(Mandatory)][string]$ProductionProjectRef,
    [Parameter(Mandatory)][string]$Sql
  )

  if ($Environment -ne 'staging') {
    throw 'Push runtime diagnostic is staging-only.'
  }
  if ($ProjectRef -ne $StagingProjectRef -or $ProjectRef -eq $ProductionProjectRef) {
    throw 'Push runtime diagnostic target must be the isolated staging project ref.'
  }
  if ($Sql -cne (Get-StagingPushRuntimeDiagnosticSql)) {
    throw 'Push runtime diagnostic SQL is not on the exact read-only allowlist.'
  }
  if ($Sql -notmatch '(?im)^\s*begin transaction read only;\s*$' -or
      $Sql -notmatch '(?im)^\s*rollback;\s*$') {
    throw 'Push runtime diagnostic must be enclosed in a read-only transaction.'
  }
}

function Get-StagingReconciliationSql {
  param([Parameter(Mandatory)][ValidateSet('prepare', 'prepare-inspect', 'apply', 'apply-inspect')][string]$Action)

  if ($Action -eq 'prepare') {
    return @'
do $$
begin
  if exists (
    select 1 from public.equal_source_reconciliation_runs where status = 'prepared'
  ) then
    raise exception 'existing_prepared_reconciliation_run_requires_review';
  end if;
  perform public.prepare_equal_source_reconciliation(10, null);
end;
$$;
'@
  }

  if ($Action -eq 'prepare-inspect') {
    return @'
select json_build_object(
  'status', r.status,
  'batch_limit', r.batch_limit,
  'user_count', r.user_count,
  'diff_count', r.diff_count,
  'baseline_session_count', r.baseline_session_count,
  'baseline_duration_seconds', r.baseline_duration_seconds,
  'baseline_ledger_count', r.baseline_ledger_count,
  'baseline_ledger_xp', r.baseline_ledger_xp,
  'baseline_claimed_reward_count', r.baseline_claimed_reward_count,
  'baseline_xp_mismatch_count', r.baseline_xp_mismatch_count,
  'batch_session_count', coalesce(sum(u.session_count), 0),
  'batch_duration_seconds', coalesce(sum(u.duration_seconds), 0),
  'metric_diff_user_count', coalesce(sum(
    case when u.current_break_metric is distinct from u.shadow_break_metric then 1 else 0 end
  ), 0),
  'affected_group_days', coalesce(sum(u.affected_group_days), 0),
  'affected_group_weeks', coalesce(sum(u.affected_group_weeks), 0)
)::text as reconciliation_prepare_summary
from public.equal_source_reconciliation_runs r
left join public.equal_source_reconciliation_users u on u.run_id = r.id
where r.status = 'prepared'
group by r.id
order by r.created_at desc
limit 1;
'@
  }

  if ($Action -eq 'apply') {
    return @'
do $$
declare
  v_prepared_count integer;
  v_run_id uuid;
begin
  select count(*), (array_agg(id order by created_at))[1]
  into v_prepared_count, v_run_id
  from public.equal_source_reconciliation_runs
  where status = 'prepared';

  if v_prepared_count <> 1 then
    raise exception 'exactly_one_prepared_reconciliation_run_required';
  end if;
  perform public.apply_equal_source_reconciliation(v_run_id);
end;
$$;
'@
  }

  return @'
select json_build_object(
  'status', r.status,
  'batch_limit', r.batch_limit,
  'user_count', r.user_count,
  'diff_count', r.diff_count,
  'applied_user_count', r.user_count,
  'session_count_delta', (select count(*) from public.study_sessions) - r.baseline_session_count,
  'duration_seconds_delta', (select coalesce(sum(duration_seconds), 0) from public.study_sessions) - r.baseline_duration_seconds,
  'ledger_count_delta', (select count(*) from public.xp_ledger) - r.baseline_ledger_count,
  'ledger_xp_delta', (select coalesce(sum(xp_amount), 0) from public.xp_ledger) - r.baseline_ledger_xp,
  'claimed_reward_count_delta', (
    select count(*) from public.achievement_rewards where status = 'claimed'
  ) - r.baseline_claimed_reward_count,
  'xp_mismatch_count', (
    select count(*) from public.gamification_profiles gp
    where gp.xp <> (
      select coalesce(sum(xl.xp_amount), 0)::integer
      from public.xp_ledger xl where xl.user_id = gp.user_id
    )
  )
)::text as reconciliation_apply_summary
from public.equal_source_reconciliation_runs r
where r.status = 'applied'
order by r.applied_at desc
limit 1;
'@
}

function Assert-StagingReconciliationAction {
  param(
    [Parameter(Mandatory)][ValidateSet('prepare', 'prepare-inspect', 'apply', 'apply-inspect')][string]$Action,
    [Parameter(Mandatory)][ValidateSet('staging', 'production')][string]$Environment,
    [Parameter(Mandatory)][string]$ProjectRef,
    [Parameter(Mandatory)][string]$StagingProjectRef,
    [Parameter(Mandatory)][string]$ProductionProjectRef,
    [Parameter(Mandatory)][string]$Sql
  )

  if ($Environment -ne 'staging') {
    throw 'Reconciliation acceptance is staging-only.'
  }
  if ($ProjectRef -ne $StagingProjectRef -or $ProjectRef -eq $ProductionProjectRef) {
    throw 'Reconciliation target must be the isolated staging project ref.'
  }

  $allowedSql = Get-StagingReconciliationSql -Action $Action
  if ($Sql -cne $allowedSql) {
    throw 'Reconciliation SQL is not on the exact staging allowlist.'
  }
}

function Assert-TargetContract {
  param(
    [Parameter(Mandatory)][ValidateSet('staging', 'production')][string]$Environment,
    [Parameter(Mandatory)][string]$ProjectRef,
    [Parameter(Mandatory)][string]$SupabaseUrl,
    [Parameter(Mandatory)][string]$StagingProjectRef,
    [Parameter(Mandatory)][string]$ProductionProjectRef,
    [string]$RepoRoot = (Get-RepoRoot),
    [switch]$IgnoreLinkedRef
  )

  foreach ($ref in @($ProjectRef, $StagingProjectRef, $ProductionProjectRef)) {
    if ($ref -notmatch '^[a-z0-9]{20}$') {
      throw 'Project refs must be exactly 20 lowercase letters or digits.'
    }
  }
  if ($StagingProjectRef -eq $ProductionProjectRef) {
    throw 'Staging and production project refs must be different.'
  }

  $expectedRef = if ($Environment -eq 'staging') { $StagingProjectRef } else { $ProductionProjectRef }
  if ($ProjectRef -ne $expectedRef) {
    throw "Target mismatch: $Environment does not match the selected project ref."
  }

  try { $uri = [Uri]$SupabaseUrl } catch { throw 'Supabase URL is invalid.' }
  if ($uri.Scheme -ne 'https' -or $uri.Host -ne "$ProjectRef.supabase.co") {
    throw "Target mismatch: URL host does not match the selected $Environment project ref."
  }

  if (-not $IgnoreLinkedRef) {
    $linkedRefPath = Join-Path $RepoRoot 'supabase\.temp\project-ref'
    if (Test-Path -LiteralPath $linkedRefPath) {
      $linkedRef = (Get-Content -LiteralPath $linkedRefPath -Raw -Encoding UTF8).Trim()
      if (-not [string]::IsNullOrWhiteSpace($linkedRef) -and $linkedRef -ne $ProjectRef) {
        throw "Stale CLI link rejected. Linked ref is not the requested $Environment target. Run 'supabase unlink' first."
      }
    }
  }
}

function Assert-ExactReleaseIdentity {
  param(
    [Parameter(Mandatory)][string]$ExpectedGitSha,
    [Parameter(Mandatory)][string]$ExpectedMigrationHead,
    [string]$RepoRoot = (Get-RepoRoot)
  )

  if ($ExpectedGitSha -notmatch '^[0-9a-f]{40}$') {
    throw 'ExpectedGitSha must be the full 40-character commit SHA.'
  }
  $actualSha = Get-GitHead -RepoRoot $RepoRoot
  if ($actualSha -ne $ExpectedGitSha) {
    throw "Commit mismatch: checkout does not match ExpectedGitSha."
  }

  if ($ExpectedMigrationHead -notmatch '^\d{4}$') {
    throw 'ExpectedMigrationHead must be four digits.'
  }
  $actualHead = Get-LocalMigrationHead -RepoRoot $RepoRoot
  if ($actualHead -ne $ExpectedMigrationHead) {
    throw "Migration head mismatch: local=$actualHead expected=$ExpectedMigrationHead."
  }
}

function Assert-ProductionApproval {
  param(
    [Parameter(Mandatory)][string]$ExpectedGitSha,
    [Parameter(Mandatory)][string]$ExpectedMigrationHead,
    [Parameter(Mandatory)][string]$ProjectRef,
    [AllowEmptyString()][string]$BackupEvidence,
    [AllowEmptyString()][string]$Confirmation,
    [AllowEmptyString()][string]$GitHubActions,
    [AllowEmptyString()][string]$ApprovalEnvironment
  )

  if ($GitHubActions -ne 'true' -or $ApprovalEnvironment -ne 'production') {
    throw 'Production apply is CI-only and requires the protected production environment.'
  }
  if ([string]::IsNullOrWhiteSpace($BackupEvidence)) {
    throw 'Production apply requires the machine-readable backup checklist JSON.'
  }
  try { $backup = $BackupEvidence | ConvertFrom-Json } catch {
    throw 'Production backup evidence must be valid checklist JSON.'
  }
  foreach ($field in @('backup_id', 'captured_at_utc', 'restore_strategy', 'session_baseline_evidence', 'xp_reconciliation_evidence', 'post_check_plan')) {
    if (-not $backup.PSObject.Properties.Name.Contains($field) -or [string]::IsNullOrWhiteSpace([string]$backup.$field)) {
      throw "Production backup checklist field is missing: $field"
    }
  }
  try { [DateTimeOffset]::Parse([string]$backup.captured_at_utc) | Out-Null } catch {
    throw 'Production backup checklist captured_at_utc is invalid.'
  }
  $expectedConfirmation = "PRODUCTION GO:$ExpectedGitSha`:$ExpectedMigrationHead`:$ProjectRef"
  if ($Confirmation -cne $expectedConfirmation) {
    throw 'Production GO confirmation does not match the exact commit, migration head and project ref.'
  }
}

function New-EvidenceDirectory {
  param(
    [Parameter(Mandatory)][string]$Kind,
    [string]$EvidenceRoot,
    [string]$RepoRoot = (Get-RepoRoot)
  )

  if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $EvidenceRoot = Join-Path $RepoRoot '.artifacts\deploy-evidence'
  }
  $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
  $safeKind = $Kind -replace '[^a-zA-Z0-9_.-]', '-'
  $path = Join-Path $EvidenceRoot "$stamp-$safeKind"
  New-Item -ItemType Directory -Path $path -Force | Out-Null
  return (Resolve-Path -LiteralPath $path).Path
}

function Write-DeployJson {
  param(
    [Parameter(Mandatory)][object]$Value,
    [Parameter(Mandatory)][string]$Path
  )

  $json = $Value | ConvertTo-Json -Depth 12
  [IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

function Invoke-EvidenceCommand {
  param(
    [Parameter(Mandatory)][string]$Executable,
    [Parameter(Mandatory)][string[]]$Arguments,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [Parameter(Mandatory)][string]$Label,
    [string[]]$SensitiveValues = @(),
    [switch]$SupabaseCommand
  )

  if ($SupabaseCommand) {
    Assert-SafeSupabaseArguments -Arguments $Arguments
  }

  $previousPreference = $ErrorActionPreference
  try {
    # Windows PowerShell converts native stderr records into non-terminating
    # ErrorRecord objects. Keep collecting them, then trust the process exit
    # code; otherwise pnpm-hosted reruns stop on harmless CLI progress output.
    $ErrorActionPreference = 'Continue'
    $raw = (& $Executable @Arguments 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
  }
  $safe = Protect-DeployText -Text $raw -SensitiveValues $SensitiveValues
  $logPath = Join-Path $EvidenceDirectory "$Label.log"
  [IO.File]::WriteAllText($logPath, $safe, [Text.UTF8Encoding]::new($false))
  if (-not [string]::IsNullOrWhiteSpace($safe)) {
    Write-Host $safe.TrimEnd()
  }
  if ($exitCode -ne 0) {
    throw "Command failed ($exitCode): $Label. See sanitized evidence log."
  }
  return $safe
}

Export-ModuleMember -Function Get-RepoRoot, Get-DeployContract, Get-LocalMigrationHead, Get-GitHead, Protect-DeployText, Assert-SafeSupabaseArguments, Get-StagingPrerequisiteSql, Assert-StagingPrerequisiteAction, Get-StagingPushDispatchPostCheckSql, Assert-StagingPushDispatchPostCheck, Get-StagingPushRuntimeDiagnosticSql, Assert-StagingPushRuntimeDiagnostic, Get-StagingReconciliationSql, Assert-StagingReconciliationAction, Assert-TargetContract, Assert-ExactReleaseIdentity, Assert-ProductionApproval, New-EvidenceDirectory, Write-DeployJson, Invoke-EvidenceCommand
